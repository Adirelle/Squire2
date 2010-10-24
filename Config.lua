--[[
Squire2 - One-click smart mounting.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addon = Squire2
local L, Debug = addon.L, addon.Debug

local AceConfigDialog = LibStub('AceConfigDialog-3.0')

local checkbuttons = {}
local spellbuttons = {}
local panelButton

local CheckButton_Create, SpellButton_Create

function addon:InitializeConfig()
	for i = 1, NUM_COMPANIONS_PER_PAGE do
		checkbuttons[i] = CheckButton_Create(_G["SpellBookCompanionButton"..i])
	end
	if addon.mountSpells then
		for i, id in ipairs(addon.mountSpells) do
			local spellbutton = SpellButton_Create(id)
			if i == 1 then
				spellbutton:SetPoint("TOPLEFT", SpellBookCompanionsModelFrame, "TOPRIGHT", 16, -16)
			else
				spellbutton:SetPoint("TOP", spellbuttons[i-1], "BOTTOM", 0, -8)
			end
			spellbuttons[i] = spellbutton
		end
	end

	LibStub('AceConfig-3.0'):RegisterOptionsTable("Squire2", addon.GetOptions)

	panelButton = CreateFrame("Button", nil, SpellBookCompanionsFrame, "UIPanelButtonTemplate")
	panelButton:SetText("Squire2")
	panelButton:SetPoint("RIGHT", SpellBookFrameCloseButton, "LEFT", 4, 0)
	panelButton:SetSize(70, 22)
	panelButton:Hide()
	panelButton:SetScript('OnClick', function() self:OpenConfig() end)
end

function addon:OpenConfig()
	AceConfigDialog:Open("Squire2")
end

function addon:SpellBook_UpdateCompanionsFrame()
	if SpellBookCompanionsFrame.mode ~= 'MOUNT' then
		panelButton:Hide()
		for i, button in ipairs(checkbuttons) do
			button:Hide()
		end
		for i, button in ipairs(spellbuttons) do
			button:Hide()
		end
		return
	end
	panelButton:Show()
	for i, button in ipairs(spellbuttons) do
		button:Show()
	end
	for i, checkbutton in ipairs(checkbuttons) do
		local id = checkbutton:GetSpellID()
		if id then
			checkbutton:SetChecked(self.db.char.mounts[id])
			checkbutton:Show()
		else
			checkbutton:Hide()
		end
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
	checkbutton:SetScale(0.5)
	checkbutton:SetScript('OnClick', CheckButton_OnClick)
	checkbutton:SetScript('OnEnter', CheckButton_OnEnter)
	checkbutton:SetScript('OnLeave', CheckButton_OnLeave)
	checkbutton.GetSpellID = CheckButton_GetSpellID
	return checkbutton
end

--------------------------------------------------------------------------------
-- Spell buttons
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
		checkbutton:SetChecked(addon.db.char.mounts[self.spellID])
	else
		if not icon:SetDesaturated(true) then
			icon:SetVertexColor(0.5, 0.5, 0.5)
		end
		checkbutton:Hide()
	end
end

function SpellButton_Create(spellID)
	local self = CreateFrame("Frame", nil, SpellBookCompanionsFrame)
	self:Hide()
	self.spellID = spellID
	self:SetSize(37,37)
	self:SetScript('OnEnter', SpellButton_OnEnter)
	self:SetScript('OnLeave', SpellButton_OnLeave)
	self:SetScript('OnShow', SpellButton_OnShow)

	local icon = self:CreateTexture()
	icon:SetAllPoints(self)
	self.icon = icon

	self.checkbutton = CheckButton_Create(self)

	return self
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

local SQUIRE2_BINDING = "CLICK Squire2Button:LeftButton"

local options
function addon.GetOptions()
	if not options then
		options = {
			name = "Squire2",
			type = "group",
			disabled = function() return InCombatLockdown() end,
			args = {
				macro = {
					name = L['Macro'],
					desc = L['Create the Squire2 macro.'],
					type = 'execute',
					func = function() PickupMacro(addon:SetupMacro(true)) end,
					order = 10,
				},
				togleMountSpellbook = {
					name = L['Toggle spellbook'],
					type = 'execute',
					func = function() ToggleSpellBook(BOOKTYPE_MOUNT) end,
					order = 11,
				},
				keybinding = {
					name = L["Squire2 binding"],
					desc = L["Select a binding to use Squire2 without a macro."],
					type = 'keybinding',
					get = function() return GetBindingKey(SQUIRE2_BINDING) end,
					set = function(_, value)
						SetBinding(value, SQUIRE2_BINDING)
						SaveBindings(GetCurrentBindingSet())
					end,
					order = 15,
				},
				autoDismount = {
					name = L['Dismount/exit vehicle/cancel shapeshift'],
					desc = L['Check this to dismount, exit vehicle or cancel shapeshift resp. when on a mount, in a vehicle or shapeshifted.'],
					type = 'toggle',
					get = function() return addon.db.profile.autoDismount end,
					set = function(_, value) addon.db.profile.autoDismount = value end,
					order = 20,
				},
				safeDismount = {
					name = L['... but not when flying'],
					desc = L['Check this not to dismount/exit vehicle/cancel shapeshift when flying.'],
					type = 'toggle',
					get = function() return addon.db.profile.safeDismount end,
					set = function(_, value) addon.db.profile.safeDismount = value end,
					disabled = function() return not addon.db.profile.autoDismount end,
					order = 30,
				},
				groundModifier = {
					name = L['Ground modifier'],
					desc = L['Select a modifier to enforce the use of a ground mount.'],
					type = 'select',
					get = function() return addon.db.profile.groundModifier end,
					set = function(_, value) addon.db.profile.groundModifier = value end,
					values = {
						none = L['None'],
						any = L['Any'],
						control = CTRL_KEY,
						alt = ALT_KEY,
						shift = SHIFT_KEY,
						rightbutton = L["Right mouse button"],
					},
					order = 40,
				},
				combatAction = {
					name = L['Combat action'],
					desc = L['Define the action to use in combat instead of anything Squire2 might try.'],
					usage = L['Drag and drop an action or right-click to clear.'],
					type = 'input',
					control = 'ActionSlot',
					order = 50,
					get = function() return addon.db.char.combatAction end,
					set = function(_, value) addon.db.char.combatAction = value end,
					validate = function(_, value)
						return (value ~= "macro:Squire2") or L["Infinite recursion is bad !"]
					end
				},
				movingAction = {
					name = L['Moving action'],
					desc = L['Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available.'],
					usage = L['Drag and drop an action or right-click to clear.'],
					type = 'input',
					control = 'ActionSlot',
					order = 50,
					get = function() return addon.db.char.movingAction end,
					set = function(_, value) addon.db.char.movingAction = value end,
					validate = function(_, value)
						return (value ~= "macro:Squire2") or L["Infinite recursion is bad !"]
					end
				},
			}
		}
	end
	return options
end

addon:InitializeConfig()
