--[[
Squire2 - One-click smart mounting.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addon = LibStub("AceAddon-3.0"):GetAddon("Squire2")
local L, Debug = addon.L, addon.Debug

local checkbuttons = {}
local CheckButton_OnClick, CheckButton_OnEnter, CheckButton_OnLeave

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
	return self:SpellBook_UpdateCompanionsFrame()
end

function addon:SpellBook_UpdateCompanionsFrame()
	if SpellBookCompanionsFrame.mode ~= 'MOUNT' then
		for i, checkbutton in pairs(checkbuttons) do
			checkbutton:Hide()
		end
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
end

function CheckButton_OnClick(checkbutton)
	local id = tonumber(checkbutton:GetParent().spellID)
	Debug("Click checkbutton", i, id, id and addon.db.char.mounts[id])
	if id then
		addon.db.char.mounts[id] = not addon.db.char.mounts[id]
	end
end

function CheckButton_OnEnter(checkbutton)
	GameTooltip:SetOwner(checkbutton, "ANCHOR_BOTTOMLEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(format(L["Use %s"], GetSpellInfo(checkbutton:GetParent().spellID)),1,1,1)
	GameTooltip:AddLine(L["Check this to let Squire2 use this mount."], 0.1, 1, 0.1)
	GameTooltip:Show()
end

function CheckButton_OnLeave(checkbutton)
	if GameTooltip:GetOwner() == checkbutton then
		GameTooltip:FadeOut()
	end
end
