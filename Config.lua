--[[
Squire2 - One-click smart mounting.
Copyright 2010-2012 Adirelle (adirelle@gmail.com)
All rights reserved.

Contributors :
- Aelorean
--]]

local addon = Squire2
local L, Debug = addon.L, addon.Debug
local ACTION_NOOP, ACTION_SMOOTH, ACTION_TOGGLE = addon.ACTION_NOOP, addon.ACTION_SMOOTH, addon.ACTION_TOGGLE

local AceConfigDialog = LibStub('AceConfigDialog-3.0')
local LibMounts = LibStub("LibMounts-1.0")

local checkbuttons = {}
local spellbuttons = {}
local panelButton
local CheckButton_Create, SpellButton_Create

function addon:InitializeConfig()
	local scrollFrame = MountJournal.ListScrollFrame

	local hook = function() addon:UpdateMountList() end
	hooksecurefunc('MountJournal_UpdateMountList', hook)
	hooksecurefunc(scrollFrame, 'update', hook)

	for i, button in ipairs(scrollFrame.buttons) do
		local checkbutton = CheckButton_Create(button, -18, 18)
		checkbuttons[i] = checkbutton
	end

	LibStub('AceConfig-3.0'):RegisterOptionsTable("Squire2", addon.GetOptions)
	--AceConfigDialog:SetDefaultSize("Squire2", 600, 500)

	panelButton = CreateFrame("Button", "Squire2ConfigButton", MountJournal, "UIPanelButtonTemplate")
	panelButton:SetText("Squire2")
	panelButton:SetSize(90,20)
	panelButton:SetPoint("TOPRIGHT", -2, -22)
	panelButton:SetScript('OnClick', function() self:OpenConfig() end)

	if addon.mountSpells then
		for i, id in ipairs(addon.mountSpells) do
			local spellbutton = SpellButton_Create(id)
			if i == 1 then
				spellbutton:SetPoint("BOTTOMLEFT", MountJournal.MountDisplay, "TOPLEFT", 0, 2)
			else
				spellbutton:SetPoint("LEFT", spellbuttons[i-1], "RIGHT", 4, 0)
			end
			spellbuttons[i] = spellbutton
		end
	end

	return addon:UpdateMountList()
end

function addon:OpenConfig()
	AceConfigDialog:Open("Squire2")
end

function addon:UpdateMountList()
	-- This function is now called every time the MountWindow scrollframe moves/updates.  So, any 'expensive' calls could cause fps lag when scrolling.
	for _, checkbutton in ipairs(checkbuttons) do
		local id = checkbutton:GetSpellID()
		if id and id ~= 0 then
			local ground, air, water = LibMounts:GetMountInfo(id)
			checkbutton.knownMount = ground or air or water
			if checkbutton.knownMount then
				checkbutton:Enable()
				checkbutton:SetChecked(self.db.profile.mounts[id])
			else
				checkbutton:Disable()
				checkbutton:SetChecked(false)
			end
			if not checkbutton:IsShown() then
				checkbutton:Show()
			end
		elseif checkbutton:IsShown() then
			checkbutton:Hide()
		end
	end
end

--------------------------------------------------------------------------------
-- Mount checkbuttons
--------------------------------------------------------------------------------

local CheckButton_OnClick
do
	local function Enable() return true end
	local function Disable() return false end
	local function Toggle(v) return not v end

	function CheckButton_OnClick(self)
		if IsModifierKeyDown() then
			local op = (IsShiftKeyDown() and Enable) or (IsControlKeyDown() and Disable) or Toggle
			for index = 1, GetNumCompanions("MOUNT") do
				local _, _, id = GetCompanionInfo("MOUNT", index)
				addon.db.profile.mounts[id] = op(addon.db.profile.mounts[id])
			end
			addon:UpdateMountList()
		else
			local id = self:GetSpellID()
			if id then
				addon.db.profile.mounts[id] = not addon.db.profile.mounts[id]
			end
		end
	end
end

local function CheckButton_OnEnter(self)
	if GetCVarBool("UberTooltips") then
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
	else
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	end
	GameTooltip:ClearLines()
	if self.knownMount then
		GameTooltip:AddLine(format(L["Use %s"], GetSpellInfo(self:GetSpellID())),1,1,1)
		GameTooltip:AddLine(L["Check this to let Squire2 use this mount or spell."], 0.1, 1, 0.1)
	else
		GameTooltip:AddLine(L["This mount is not listed by LibMounts-1.0. Squire2 cannot use it."], 0.1, 1, 0.1)
	end
	GameTooltip:AddLine(L["Shift+Click to check them all,"])
	GameTooltip:AddLine(L["Alt+Click to invert them all,"])
	GameTooltip:AddLine(L["Ctrl+Click to bring them all and in the darkness bind them."])
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

function CheckButton_Create(button, xOffset, yOffset)
	local checkbutton = CreateFrame("CheckButton", nil, button, "UICheckButtonTemplate")
	checkbutton:SetPoint("CENTER", button, "BOTTOMRIGHT", xOffset, yOffset)
	checkbutton:SetScale(0.85)
	checkbutton:SetScript('OnClick', CheckButton_OnClick)
	checkbutton:SetScript('OnEnter', CheckButton_OnEnter)
	checkbutton:SetScript('OnLeave', CheckButton_OnLeave)
	checkbutton:SetMotionScriptsWhileDisabled(true)
	checkbutton.GetSpellID = CheckButton_GetSpellID
	return checkbutton
end

--------------------------------------------------------------------------------
-- Shape-Changing Ability Buttons+Checkbuttons
--------------------------------------------------------------------------------

local function SpellButton_OnEnter(self)
	if GetCVarBool("UberTooltips") then
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
	else
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	end
	if GameTooltip:SetSpellByID(self.spellID) then
		self.UpdateTooltip = SpellButton_OnEnter
	else
		self.UpdateTooltip = nil
	end
		GameTooltip:Show()
end

local function SpellButton_OnLeave(self)
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
end

local function SpellButton_OnShow(self)
	local name, _, texture = GetSpellInfo(self.spellID)
	local icon, checkbutton = self.icon, self.checkbutton
	icon:SetTexture(texture)
	if GetSpellInfo(name) then
		if not icon:SetDesaturated(false) then
			icon:SetVertexColor(1, 1, 1)
		end
		checkbutton:Show()
		checkbutton:SetChecked(addon.db.profile.mounts[self.spellID])
		else
		if not icon:SetDesaturated(true) then
			icon:SetVertexColor(0.5, 0.5, 0.5)
		end
		checkbutton:Hide()
	end
end

local function SpellButton_OnDragStart(self)
	PickupSpell(self.spellID)
end

function SpellButton_Create(spellID)
	local self = CreateFrame("Button", nil, MountJournal)
	self:Hide()
	self.spellID = spellID
	self:SetSize(37, 37)
	self:SetScript('OnEnter', SpellButton_OnEnter)
	self:SetScript('OnLeave', SpellButton_OnLeave)
	self:SetScript('OnShow', SpellButton_OnShow)

	self:RegisterForDrag("LeftButton", "RightButton")
	self:SetScript('OnDragStart', SpellButton_OnDragStart)

	local icon = self:CreateTexture()
	icon:SetAllPoints(self)
	self.icon = icon
	self.icon:SetTexture(icon)

	self.checkbutton = CheckButton_Create(self, -12, 12)
	self.checkbutton:SetScale(0.5)
	self.checkbutton.knownMount = true

	self:Show()
	return self
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
