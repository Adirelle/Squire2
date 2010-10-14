--[[
Squire2 - One-click smart mounting.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addon = Squire2
local L, Debug = addon.L, addon.Debug

local AceConfigDialog = LibStub('AceConfigDialog-3.0')

local checkbuttons = {}
local panelButton

local CheckButton_OnClick, CheckButton_OnEnter, CheckButton_OnLeave

local MACRO_NAME, MACRO_ICON = "Squire2", 251

function addon:InitializeConfig()
	
	for i = 1, NUM_COMPANIONS_PER_PAGE do
		local button = _G["SpellBookCompanionButton"..i];
		local checkbutton = CreateFrame("CheckButton", nil, button, "UICheckButtonTemplate")
		checkbutton:SetPoint("CENTER", button, "BOTTOMRIGHT", -4, 4)
		checkbutton:SetScale(0.5)
		checkbutton:SetScript('OnClick', CheckButton_OnClick)
		checkbutton:SetScript('OnEnter', CheckButton_OnEnter)
		checkbutton:SetScript('OnLeave', CheckButton_OnLeave)
		checkbuttons[i] = checkbutton
	end
	
	LibStub('AceConfig-3.0'):RegisterOptionsTable("Squire2", addon.GetOptions)

	panelButton = CreateFrame("Button", nil, SpellBookCompanionsFrame, "UIPanelButtonTemplate")
	panelButton:SetText("Squire2")
	panelButton:SetPoint("RIGHT", SpellBookFrameCloseButton, "LEFT", 4, 0)
	panelButton:SetSize(70, 22)
	panelButton:Hide()
	panelButton:SetScript('OnClick', function() AceConfigDialog:Open("Squire2") end)
	
	return self:SpellBook_UpdateCompanionsFrame()
end

function addon:SpellBook_UpdateCompanionsFrame()
	if SpellBookCompanionsFrame.mode ~= 'MOUNT' then
		for i, checkbutton in pairs(checkbuttons) do
			checkbutton:Hide()
		end
		panelButton:Hide()
		return
	end
	for i, checkbutton in ipairs(checkbuttons) do
		local button = checkbutton:GetParent()
		if button.creatureID then
			Debug("Update checkbutton", i, button.creatureID, button.spellID, self.db.char.mounts[button.spellID])
			checkbutton:SetChecked(self.db.char.mounts[button.spellID])
			checkbutton:Show()
		else
			checkbutton:Hide()
		end
	end
	panelButton:Show()
end

--------------------------------------------------------------------------------
-- Handlers of the mount checkbuttons
--------------------------------------------------------------------------------

function CheckButton_OnClick(self)
	local id = tonumber(self:GetParent().spellID)
	Debug("Click checkbutton", i, id, id and addon.db.char.mounts[id])
	if id then
		addon.db.char.mounts[id] = not addon.db.char.mounts[id]
	end
end

function CheckButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(format(L["Use %s"], GetSpellInfo(self:GetParent().spellID)),1,1,1)
	GameTooltip:AddLine(L["Check this to let Squire2 use this mount."], 0.1, 1, 0.1)
	GameTooltip:Show()
end

function CheckButton_OnLeave(self)
	if GameTooltip:GetOwner() == self then
		GameTooltip:FadeOut()
	end
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
					desc = L['Create and pick up the Squire2 macro'],
					type = 'execute',
					func = function()
						local index = GetMacroIndexByName(MACRO_NAME)
						if index == 0 then
							index = CreateMacro(MACRO_NAME, MACRO_ICON, "/click Squire2Button", 0)
						end
						PickupMacro(index)
					end,
					order = 10,
				},
				keybinding = {
					name = L["Squire2 binding"],
					desc = L["Select a binding to use Squire2 without a macro"],
					type = 'keybinding',
					get = function() return GetBindingKey(SQUIRE2_BINDING) end,
					set = function(_, value)
						SetBinding(value, SQUIRE2_BINDING)
						SaveBindings(GetCurrentBindingSet())
					end,
					order = 11,
				},
				autoDismount = {
					name = L['Dismount automatically'],
					desc = L['Check this to have Squire2 automatically dismount you.'],
					type = 'toggle',
					get = function() return addon.db.profile.autoDismount end,
					set = function(_, value) addon.db.profile.autoDismount = value end,
					order = 20,
				},
				safeDismount = {
					name = L['Safe dismount'],
					desc = L['Check this to prevent Squire2 from automatically dismounting you when you are flying.'],
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
					},
					order = 40,
				},
				combatAction = {
					name = L['Combat action'],
					desc = L['Drag an drop any action there to define the action to do it in combat instead of mounting. Right-click to clear.'],
					type = 'input',
					control = 'ActionSlot',
					order = 50,
					get = function() return addon.db.char.combatAction end,
					set = function(_, value) addon.db.char.combatAction = value end,
					validate = function(_, value)
						return (value ~= "macro:Squire2") or L["Infinite recursion is bad"]
					end
				},
			}
		}
	end
	return options
end

