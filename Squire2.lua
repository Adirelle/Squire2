--[[
Squire2 - One-click smart mounting.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
_G[addonName] = addon

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
addon.Debug = Debug

--------------------------------------------------------------------------------
-- Want locals ?
--------------------------------------------------------------------------------

local _, playerClass = UnitClass('player')

local LibMounts = LibStub("LibMounts-1.0")
local AIR, GROUND, WATER = LibMounts.AIR, LibMounts.GROUND, LibMounts.WATER

--------------------------------------------------------------------------------
-- Initializing
--------------------------------------------------------------------------------

local DEFAULTS = {
	profile = {
		autoDismount = true,
		safeDismount = true,
		groundModifier = "any",
	},
	char = { mounts = { ['*'] = true } },
}

local eventHandler = CreateFrame("Frame")
eventHandler:SetScript('OnEvent', function(_, event, ...) return addon[event](addon, event, ...) end)

function addon:ADDON_LOADED(_, name)
	if name ~= addonName then return end
	self.db = LibStub('AceDB-3.0'):New(addonName.."DB", DEFAULTS, true)

	local button = CreateFrame("Button", "Squire2Button", nil, "SecureActionButtonTemplate")
	button:RegisterForClicks("AnyUp")
	button:SetScript("PreClick", self.ButtonPreClick)
	self.button = button

	eventHandler:RegisterEvent('PLAYER_REGEN_DISABLED')
	eventHandler:RegisterEvent('COMPANION_UPDATE')
	eventHandler:RegisterEvent('COMPANION_LEARNED')
	self.COMPANION_UNLEARNED = self.COMPANION_LEARNED
	hooksecurefunc('SpellBook_UpdateCompanionsFrame', function(...) return self:SpellBook_UpdateCompanionsFrame(...) end)

	if IsLoggedIn() then
		self:COMPANION_LEARNED('OnEnable', 'MOUNT')
	else
		eventHandler:RegisterEvent('PLAYER_LOGIN')
		self.PLAYER_LOGIN = self.COMPANION_LEARNED
	end

	if playerClass == "DRUID" then
		eventHandler:RegisterEvent('UPDATE_SHAPESHIFT_FORMS')
		if self.PLAYER_LOGIN then
			self.PLAYER_LOGIN = function(self, ...)
				self:COMPANION_LEARNED(...)
				self:UPDATE_SHAPESHIFT_FORMS(...)
			end
		else
			self:UPDATE_SHAPESHIFT_FORMS("OnEnable")
		end
	end
	
	self:SetupMacro()
end
eventHandler:RegisterEvent('ADDON_LOADED')

function addon:SpellBook_UpdateCompanionsFrame()
	if SpellBookCompanionsFrame.mode == 'MOUNT' then
		LoadAddOn('Squire2_Config')
		if self.InitializeConfig then
			self:InitializeConfig()
		end
	end
end

function addon.ButtonPreClick(_, button)
	if not InCombatLockdown() then
		addon:SetupButton(button)
	end
end

function addon:PLAYER_REGEN_DISABLED()
	addon:SetupButton("combat")
end

local MACRO_NAME, MACRO_ICON, MACRO_BODY = "Squire2", 251, "/click [button:2] Squire2Button RightButton; Squire2Button"
function addon:SetupMacro(create)
	local index = GetMacroIndexByName(MACRO_NAME)
	if index == 0 then
		if create then
			return CreateMacro(MACRO_NAME, MACRO_ICON, MACRO_BODY, 0)
		end
	else
		return EditMacro(index, MACRO_NAME, MACRO_ICON, MACRO_BODY)
	end
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
	else
		return id
	end
end})
local knownSpells = setmetatable({}, {__index = function(t,id)
	local name = spellNames[id]
	local isKnown = name and GetSpellInfo(name) or false
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
	if not type or type == 'MOUNT' then
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
				mountHistory[id] = time()
				return
			end
		end
	end
end

----------------------------------------------
-- Core logic
----------------------------------------------

local mountsByType = {}
function ChooseMount(mountType)
	if not mountsByType[mountType] then
		mountsByType[mountType] = LibMounts:GetMountList(mountType)
	end
	local mounts = mountsByType[mountType]
	local oldestTime, oldestId
	for id in pairs(knownMounts) do
		if addon.db.char.mounts[id] and IsUsableSpell(id) and mounts[id] then
			local lastTime = (mountHistory[id] or random(0, 1000))
			if not oldestTime or lastTime < oldestTime then
				oldestTime, oldestId = lastTime, id
			end
		end
	end
	return oldestId
end

local baseDismountTest = "[mounted] dismount; [@player,unithasvehicleui] exitvehicle"
local dismountTest = baseDismountTest

local function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
	if isMoving and addon.db.char.movingAction then
		return strsplit(':', addon.db.char.movingAction)
	elseif not isMoving and not inCombat then
		local id = ChooseMount(mountType)
		Debug('GetActionForMount =>', id)
		if id then
			return 'spell', id
		end
	end
end

if playerClass == 'DRUID' then

	local movingForms = {
		783, -- Travel form
		1066, -- Aquatic form
		33943, -- Flight form
		40120, -- Swift Flight form
	}

	local t = {}
	function addon:UPDATE_SHAPESHIFT_FORMS()
		wipe(t)
		for index = 1, GetNumShapeshiftForms() do
			Debug('GetShapeshiftFormInfo', index, '=>', GetShapeshiftFormInfo(index))
			local _, name = GetShapeshiftFormInfo(index)
			for i, id in pairs(movingForms) do
				if name == spellNames[id] then
					tinsert(t, index)
				end
			end
		end
		if #t > 0 then
			dismountTest = format("%s; [stance:%s] cancelform", baseDismountTest, table.concat(t, "/"))
		else
			dismountTest = baseDismountTest
		end
		Debug('UPDATE_SHAPESHIFT_FORMS', dismountTest)
	end

	local origGetActionForMount = GetActionForMount
	function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		local actionType, actionData = origGetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if actionType and actionData then
			return actionType, actionData
		elseif mountType == GROUND then
			if isOutdoors then
				return 'spell', knownSpells[783] -- Travel Form
			elseif select(5, GetTalentInfo(2, 6)) == 2 then -- Feral Swiftness
				return 'spell', knownSpells[768] -- Cat Form
			end
		elseif mountType == WATER then
			return 'spell', knownSpells[1066] -- Aquatic Form
		elseif mountType == AIR then
			return 'spell', knownSpells[40120] or knownSpells[33943] -- Flight forms
		end
	end

elseif playerClass == 'SHAMAN' then

	dismountTest = baseDismountTest.."; [stance] cancelform"

	local origGetActionForMount = GetActionForMount
	function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		local actionType, actionData = origGetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if actionType and actionData then
			return actionType, actionData
		elseif mountType == GROUND and select(5, GetTalentInfo(2, 6)) == 2 then -- Ancestral Swiftness
			return 'spell', knownSpells[2645] -- Ghost Wolf
		end
	end

elseif playerClass == 'HUNTER' then

	local origGetActionForMount = GetActionForMount
	function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		local actionType, actionData = origGetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if actionType and actionData then
			return actionType, actionData
		elseif mountType == GROUND then
			return 'spell', knownSpells[5118] -- Aspect of the Cheetah
		end
	end

end

local groundModifierCheck = {
	none = function() return false end,
	any = IsModifierKeyDown,
	control = IsControlKeyDown,
	alt = IsAltKeyDown,
	shift = IsShiftKeyDown,
	rightbutton = function(button) return GetMouseButtonClicked() == "RightButton" or button == "RightButton" end,
}

local GetCombatAction
do
	local t = {}
	function GetCombatAction()
		if addon.db.char.combatAction then
			return strsplit(':', addon.db.char.combatAction)
		end
		wipe(t)
		local _, waterSpell = GetActionForMount(WATER, true, true)
		if waterSpell then
			tinsert(t, "[swimming]!"..spellNames[waterSpell])
		end
		local outdoorsAction, outdoorsGroundSpell = GetActionForMount(GROUND, true, true, true)
		local indoorsAction, indoorsGroundSpell = GetActionForMount(GROUND, true, true, false)
		if outdoorsAction == "spell" and outdoorsGroundSpell and outdoorsGroundSpell ~= indoorsGroundSpell then
			tinsert(t, "[outdoors]!"..spellNames[outdoorsGroundSpell])
		end
		if indoorsAction == "spell" and indoorsGroundSpell then
			tinsert(t, "!"..spellNames[indoorsGroundSpell])
		end
		if #t > 0 then
			return 'macrotext', format("/cast %s", table.concat(t, ";"))
		end
	end
end

local function GetActionForType(mountType, groundOnly, isMoving)
	Debug('GetActionForType', mountType, groundOnly and "groundOnly" or "all", isMoving and "moving" or "stationary")
	if mountType and (not groundOnly or mountType ~= AIR) then
		return GetActionForMount(mountType, isMoving, false, IsOutdoors())
	end
end

local function ResolveAction(button)
	if button == "combat" then
		return GetCombatAction()
	end
	-- Handle dismounting
	local dismountAction = SecureCmdOptionParse(dismountTest)
	Debug('dismountAction', dismountAction)
	if button == "dismount" then
		if dismountAction then
			return "macrotext", "/"..dismountAction
		else
			return
		end
	elseif dismountAction then
		if not addon.db.profile.autoDismount or (IsFlying() and addon.db.profile.safeDismount) then
			return
		else
			return "macrotext", "/"..dismountAction
		end
	end
	-- Handle all other actions
	local primary, secondary, tertiary = LibMounts:GetCurrentMountType()
	local groundOnly = groundModifierCheck[addon.db.profile.groundModifier](button)
	local isMoving = GetUnitSpeed("player") > 0
	local actionType, actionData = GetActionForType(primary, groundOnly, isMoving)
	if (not actionType or not actionData) and secondary then
		actionType, actionData = GetActionForType(secondary, groundOnly, isMoving)
		if (not actionType or not actionData) and tertiary then
			actionType, actionData = GetActionForType(tertiary, groundOnly, isMoving)
		end
	end
	return actionType, actionData
end

function addon:SetupButton(button)
	Debug('SetupButton', button)
	local actionType, actionData = ResolveAction(button)
	if actionType and actionData then
		local dataName = actionType
		if actionType == 'spell' then
			actionData = spellNames[actionData] or actionData
		end
		self.button:SetAttribute(actionType, actionData)
		if actionType == 'macrotext' then
			actionType = 'macro'
		end
		self.button:SetAttribute('type', actionType)
	else
		self.button:SetAttribute('type', nil)
	end
	Debug('=>', actionType, actionData)
end

