--[[
Squire2 - One-click smart mounting.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addon = Squire2
local L, Debug = addon.L, addon.Debug
local ACTION_NOOP, ACTION_SMOOTH, ACTION_TOGGLE = addon.ACTION_NOOP, addon.ACTION_SMOOTH, addon.ACTION_TOGGLE

local AceConfigDialog = LibStub('AceConfigDialog-3.0')
local LibMounts = LibStub("LibMounts-1.0")

local checkbuttons = {}
local panelButton
local CheckButton_Create
local TimeSpellsLastUpdated

function addon:InitializeConfig()
	local scrollFrame = MountJournal.ListScrollFrame
	local buttons = scrollFrame.buttons
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local numMounts = GetNumCompanions("MOUNT");
	local playerLevel = UnitLevel("player");
	
	local showMounts = 1;
	if ( numMounts < 1 ) then
		showMounts = 0;
	end
	
	for i = 1, #buttons do
		local button = buttons[i]
		local index = i + offset
		if ( index <= numMounts and showMounts == 1 and playerLevel >= 20) then
				button.checkbutton = CheckButton_Create(button)
				checkbuttons[i] = button.checkbutton
		end
	end
	
	LibStub('AceConfig-3.0'):RegisterOptionsTable("Squire2", addon.GetOptions)
	--AceConfigDialog:SetDefaultSize("Squire2", 600, 500)

	if (showMounts and playerLevel >= 20) then
		panelButton = CreateFrame("Button", "Squire2ConfigButton", MountJournal, "MagicButtonTemplate") 
		panelButton:SetText("Squire2") 
		panelButton:SetSize(90,20)
		panelButton:SetPoint("TOPRIGHT",-2, -22)
		panelButton:SetScript('OnClick', function() self:OpenConfig() end)
	end
	
end

function addon:OpenConfig()
	AceConfigDialog:Open("Squire2")
end

function addon:MountJournal_UpdateMountList()
	-- This function is now called every time the MountWindow scrollframe moves/updates.  So, any 'expensive' calls could cause fps lag when scrolling.
	for i, checkbutton in ipairs(checkbuttons) do
		local id = checkbutton:GetSpellID()
		checkbutton:SetChecked(self.db.char.mounts[id])
	end
end

--------------------------------------------------------------------------------
-- Mount checkbuttons
--------------------------------------------------------------------------------

local function CheckButton_OnClick(self)
	local id = self:GetSpellID()
	if id then
		addon.db.char.mounts[id] = not addon.db.char.mounts[id]
	end
end

local function CheckButton_OnEnter(self)
	if GetCVarBool("UberTooltips") then
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
	else
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	end
	GameTooltip:ClearLines()
	GameTooltip:AddLine(format(L["Use %s"], GetSpellInfo(self:GetSpellID())),1,1,1)
	GameTooltip:AddLine(L["Check this to let Squire2 use this mount or spell."], 0.1, 1, 0.1)
	GameTooltip:Show()
end

local function CheckButton_OnLeave(self)
	if GameTooltip:GetOwner() == self then
		GameTooltip:FadeOut()
	end
end

local function CheckButton_GetSpellID(self)
	return tonumber(self:GetParent().spellID)
end

function CheckButton_Create(button)
	local checkbutton = CreateFrame("CheckButton", nil, button, "UICheckButtonTemplate")
	checkbutton:SetPoint("CENTER", button, "BOTTOMRIGHT", -4, 4)
	checkbutton:SetScale(0.85)
	checkbutton:SetScript('OnClick', CheckButton_OnClick)
	checkbutton:SetScript('OnEnter', CheckButton_OnEnter)
	checkbutton:SetScript('OnLeave', CheckButton_OnLeave)
	checkbutton:SetMotionScriptsWhileDisabled(true)
	checkbutton.GetSpellID = CheckButton_GetSpellID
	return checkbutton
end

--------------------------------------------------------------------------------
-- Key binding handling
--------------------------------------------------------------------------------

local SQUIRE2_BINDING = "CLICK Squire2Button:LeftButton"
local DISMOUNT_BINDING = "CLICK Squire2Button:dismount"

local function BindingSet(info, key)
	-- Based on code provided by Phanx
	local binding = info.arg
	if key == "" then key = nil end
	local first, second = GetBindingKey(binding)
	Debug("UpdateBindingKey", "key=",key, "first=", first, "second=", second)
	if first == key then return end
	if first then
		SetBinding(first)
	end
	if second then
		SetBinding(second)
		if key == second then
			second = first
		end
	end
	if key then
		local action = GetBindingAction(key)
		if action and action ~= "" then
			print(KEY_UNBOUND_ERROR:format(action))
		end
		Debug("  SetBinding", key)
		SetBinding(key, binding)
	end
	if second then
		Debug("  SetBinding", second)
		SetBinding(second, binding)
	end
	Debug("  =>", GetBindingKey(binding))
	SaveBindings(GetCurrentBindingSet())
end

local function BindingGet(info)
	return GetBindingKey(info.arg)
end

--------------------------------------------------------------------------------
-- Action handling
--------------------------------------------------------------------------------

local function GetAction(info)
	return addon.db.char[info[#info]]
end

local function SetAction(info, value)
	if not value or strtrim(value) == "" or strmatch(value, "nil") then
		value = nil
	end
	if value ~= addon.db.char[info[#info]] then
		addon.db.char[info[#info]] = value
		addon:ConfigChanged()
	end
end

local function ValidateAction(info, value)
	return (value ~= "macro:Squire2") or L["Infinite recursion is bad !"]
end

--------------------------------------------------------------------------------
-- Handlers of the panel button
--------------------------------------------------------------------------------

function PanelButton_OnHide(self)
	self:SetText("Squire2 >>")
	if self.panel then
		self.panel:Release()
		self.panel = nil
	end
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

local modifierList = {
	none = L['None'],
	any = L['Any'],
	control = CTRL_KEY,
	alt = ALT_KEY,
	shift = SHIFT_KEY,
	rightbutton = L["Right mouse button"],
}

local options
function addon.GetOptions()
	if not options then
		options = {
			name = format("Squire2 %s", GetAddOnMetadata("Squire2", "Version")),
			type = "group",
			disabled = function() return InCombatLockdown() end,
			set = function(info, value) addon.db.profile[info[#info]] = value addon:ConfigChanged() end,
			get = function(info) return addon.db.profile[info[#info]] end,
			args = {
				macro = {
					name = L['Macro'],
					desc = L['Create the Squire2 macro.'],
					type = 'execute',
					func = function() PickupMacro(addon:SetupMacro(true)) end,
					order = 10,
				},
				togleMountSpellbook = {
					name = L['Toggle Mount Journal'],
					type = 'execute',
					func = function() ToggleFrame(MountJournal:GetParent()) end,
					order = 15,
				},
				restrictGroundMounts = {
					name = L['Strict ground mounts'],
					desc = L['Flying mounts can be used in non-fyling area. Check this box to ignore them and use strictly ground mounts.'],
					type = 'toggle',
					order = 16,
				},
				_bindings = {
					name = L["Bindings"],
					type = 'header',
					order = 20,
				},
				keybinding = {
					name = L["Squire2"],
					desc = L["Select a binding to use Squire2 without a macro."],
					type = 'keybinding',
					arg = SQUIRE2_BINDING,
					get = BindingGet,
					set = BindingSet,
					order = 25,
				},
				dismountKeybinding = {
					name = L["Dismount"],
					desc = L["Select a binding to dismount."],
					type = 'keybinding',
					arg = DISMOUNT_BINDING,
					get = BindingGet,
					set = BindingSet,
					order = 30,
				},
				groundModifier = {
					name = L['Ground modifier'],
					desc = L['Select a modifier to enforce the use of a ground mount, even in a flyable area.'],
					type = 'select',
					values = modifierList,
					order = 35,
				},
				dismountModifier = {
					name = L['Dismount modifier'],
					desc = L['Select a modifier to enforce dismounting, even mid-air.'],
					type = 'select',
					values = modifierList,
					order = 37,
				},
				_dismount = {
					name = L['Dismount'],
					type = 'header',
					order = 40,
				},
				ifMounted = {
					name = L['On a mount:'],
					desc = L['When already on a mount, what should Squire2 do ?'],
					type = 'select',
					width = 'double',
					values = {
						[ACTION_NOOP] = L["Do nothing."],
						[ACTION_SMOOTH] = L["Dismount and continue."],
						[ACTION_TOGGLE] = L["Dismount only."],
					},
					order = 45,
				},
				ifShapeshifted = {
					name = L['When shapeshifted:'],
					desc = L['When shapeshifted, what should Squire2 do ?'],
					type = 'select',
					width = 'double',
					values = {
						[ACTION_NOOP] = L["Do nothing."],
						[ACTION_SMOOTH] = L["Cancel shapeshift and continue."],
						[ACTION_TOGGLE] = L["Cancel shapeshift only."],
					},
					hidden = function() return not addon.hasShapeshiftForms end,
					order = 46,
				},
				ifInVehicle = {
					name = L['In a vehicle:'],
					desc = L['When already in a vehicle, what should Squire2 do ?'],
					type = 'select',
					width = 'double',
					values = {
						[ACTION_NOOP] = L["Do nothing."],
						[ACTION_TOGGLE] = L["Leave the vehicle."],
					},
					order = 47,
				},
				secureFlight = {
					name = L['Secure flight'],
					desc = L['Check this not to dismount/exit vehicle/cancel shapeshift when flying.'],
					type = 'toggle',
					width = 'full',
					order = 50,
				},
				travelFormsAsMounts = {
					name = L['Travel forms as mount'],
					desc = L['Treat travel forms as if they were mounts with regard to dismount settings.'],
					type = 'toggle',
					hidden = function() return not addon.hasTravelForms end,
					order = 52,
				},
				_actions = {
					name = L['Action overrides'],
					type = 'header',
					order = 55,
				},
				combatAction = {
					name = L['Combat action'],
					desc = L['Define the action to use in combat instead of anything Squire2 might try.'],
					usage = L['Drag and drop an action or right-click to clear.'],
					type = 'input',
					control = 'ActionSlot',
					get = GetAction,
					set = SetAction,
					validate = ValidateAction,
					order = 60,
				},
				movingAction = {
					name = L['Moving action'],
					desc = L['Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available.'],
					usage = L['Drag and drop an action or right-click to clear.'],
					type = 'input',
					control = 'ActionSlot',
					get = GetAction,
					set = SetAction,
					validate = ValidateAction,
					order = 65,
				},
			}
		}
	end
	return options
end

addon:InitializeConfig()
