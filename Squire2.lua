--[[
Squire2 - One-click smart mounting.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, ns = ...

local addon = LibStub('AceAddon-3.0'):NewAddon(addonName, 'AceEvent-3.0', 'AceHook-3.0')
addon.L = ns.L

--------------------------------------------------------------------------------
-- Debug stuff
--------------------------------------------------------------------------------

local Debug
if tekDebug then
	local frame = tekDebug:GetFrame(addonName)
	local strjoin, tostringall = strjoin, tostringall
	function Debug(...) frame:AddMessage(strjoin(" ", tostringall(...))) end
else
	function Debug() end
end
ns.Debug = Debug
addon.Debug = Debug

--------------------------------------------------------------------------------
-- Want locals ?
--------------------------------------------------------------------------------

local _, playerClass = UnitClass('player')

--------------------------------------------------------------------------------
-- Initializing
--------------------------------------------------------------------------------

local DEFAULTS = {
	profile = {
		autoDismount = true,
		safeDismount = true,
	},
	char = { mounts = { ['*'] = true } },
}

function addon:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New(addonName.."DB", DEFAULTS, true)

	local button = CreateFrame("Button", "Squire2Button", nil, "SecureActionButtonTemplate")
	button:Disable()
	button:RegisterForClicks("AnyUp")
	button:SetScript("PreClick", self.ButtonPreClick)
	self.button = button
end

function addon:SpellBook_UpdateCompanionsFrame()
	if SpellBookCompanionsFrame.mode == 'MOUNT' then
		LoadAddOn('Squire2_Config')
		if self.InitializeConfig then
			self:InitializeConfig()
		end
	end
end

--------------------------------------------------------------------------------
-- Enabling and event handling
--------------------------------------------------------------------------------

function addon:OnEnable()
	self.button:Enable()
	self:RegisterEvent('PLAYER_REGEN_DISABLED')
	self:RegisterEvent('COMPANION_UPDATE')
	self:RegisterEvent('COMPANION_LEARNED')
	self:RegisterEvent('COMPANION_UNLEARNED', 'COMPANION_LEARNED')
	self:SecureHook('SpellBook_UpdateCompanionsFrame')
	self:COMPANION_LEARNED('OnEnable', 'MOUNT')
end

function addon.ButtonPreClick()
	if not InCombatLockdown() then
		addon:SetupButton(false)
	end
end

function addon:PLAYER_REGEN_DISABLED()
	addon:SetupButton(true)
end

----------------------------------------------
-- Known spell cache
----------------------------------------------

local spellNames = setmetatable({}, {__index = function(t, id)
	if type(id) == "number" then
		local name = GetSpellInfo(id)
		Debug('Spell #', id, 'name:', name)
		t[id] = name or false
		return name
	end
end})
local knownSpells = setmetatable({}, {__index = function(t,id)
	local name = spellNames[id]
	local isKnown = name and GetSpellInfo(name) and true or false
	Debug(name, 'is', isKnown and 'known' or 'unknown')
	t[id] = isKnown
	return isKnown
end})

function addon:SPELLS_CHANGED()
	wipe(knownSpells)
end

----------------------------------------------
-- Known mount cache
----------------------------------------------

local knownMounts = {}

function addon:COMPANION_LEARNED(event, type)
	if type == 'MOUNT' then
		Debug(event, type)
		wipe(knownMounts)
		for index = 1, GetNumCompanions("MOUNT") do
			local id = select(3, GetCompanionInfo("MOUNT", index))
			knownMounts[id] = true
		end
	end
end

----------------------------------------------
-- Track used mount history
----------------------------------------------

local mountHistory = {}

function addon:COMPANION_UPDATE(event, type)
	if type == 'MOUNT' then
		Debug(event, type)
		for index = 1, GetNumCompanions("MOUNT") do
			local id, _, active = select(3, GetCompanionInfo("MOUNT", index))
			if active then
				Debug('Action mount:', id)
				mountHistory[id] = true
				return
			end
		end
	end
end

----------------------------------------------
-- Core
----------------------------------------------

local function UseSpell(id)
	return id and (knownMounts[id] or knownSpells[id]) and IsUsableSpell(id) and id
end

local function GetMovingAction() end

if playerClass == 'DRUID' then
	function GetMovingAction(inCombat)
		-- Spell #783: Travel form
		-- Spell #1066: Aquatic form
		-- Spell #33943: Flight form
		-- Spell #40120: Swift Fligh form
		-- Flight Form if OoC in flyable area, else Travel Form
		local form = (not inCombat and IsFlyableArea() and (UseSpell(40120) or UseSpell(33943))) or (knownSpells[783] and 783)
		if form then
			-- Use Aquatic Form if swimming
			if UseSpell(1066) then
				return 'macrotext', format([[/cast [swimming] %s; %s]], spellNames[1066], spellNames[form])
			else
				return 'spell', form
			end
		end
	end

elseif playerClass == 'SHAMAN' then
	function GetMovingAction()
		-- Spell #2645: Ghost Wolf
		-- Talent 2,6: Ancestral Swiftness
		if knownSpells[2645] and select(5, GetTalentInfo(2, 6)) == 2 then
			return 'spell', 2645
		end
	end

elseif playerClass == 'HUNTER' then
	function GetMovingAction()
		-- Spell #5118: Aspect of the Cheetah
		return 'spell', UseSpell(5118)
	end

end

local function GetInCombatAction()
	if addon.db.char.combatActionType then
		return addon.db.char.combatActionType, addon.db.char.combatActionData
	end
	return GetMovingAction(true)
end

local flyingMounts = ns.flyingMounts
function ChooseMount(flying, ignoreHistory)
	Debug('ChooseMount, flying=', flying, 'ignoreHistory=', ignoreHistory)
	local foundSome = false
	for id in pairs(knownMounts) do
		if UseSpell(id) and (not flying or flyingMounts[id]) then
			if addon.db.char.mounts[id] and not mountHistory[id] then
				Debug('=> mount #', id, 'selected')
				return id
			else
				Debug('Skipped mount #', id, ': in history')
				foundSome = true
			end
		end
	end
	if foundSome and not ignoreHistory then
		wipe(mountHistory)
		return ChooseMount(flying, true)
	end
end

local function GetOutOfCombatAction()
	Debug('GetOutOfCombatAction', 'Mounted=', IsMounted(), 'Flying=', IsFlying(), 'FlyableArea=', IsFlyableArea(), 'Speed=', GetUnitSpeed("player"), 'Swimming=', IsSwimming())
	-- Dismount
	if IsMounted() and addon.db.profile.autoDismount and not (IsFlying() and addon.db.profile.safeDismount) then
		return 'macrotext', '/dismount'
	end
	-- Moving action if moving
	if GetUnitSpeed("player") > 0 then
		return GetMovingAction()
	end
	-- If swimming, Abyssal Seahorse in Vashj'ir or moving action
	if IsSwimming() then
		-- Spell #75207: Abyssal Seahorse
		if knownMounts[75207] and GetMapInfo():match('^Vashjir') then
			return 'spell', 75207
		-- Spell #64731: Sea Turtle
		elseif knownMounts[64731] then
			return 'spell', 64731
		else
			return GetMovingAction()
		end
	end
	-- Flying mount in flyable area
	if IsFlyableArea() then
		local mount = ChooseMount(true)
		if mount then
			return 'spell', mount
		end
	end
	-- Ground mount
	local mount = ChooseMount()
	if mount then
		return 'spell', mount
	end
end

function addon:SetupButton(inCombat)
	Debug('SetupButton', inCombat)
	local actionType, actionData
	if inCombat then
		actionType, actionData = GetInCombatAction()
	else
		actionType, actionData = GetOutOfCombatAction()
	end
	Debug('=>', actionType, actionData)
	if actionType and actionData then
		local dataName = actionType
		if actionType == 'macrotext' then
			actionType = 'macro'
		elseif actionType == 'spell' then
			actionData = spellNames[actionData]
		end
		self.button:SetAttribute('type', actionType)
		self.button:SetAttribute(dataName, actionData)
	end
end

