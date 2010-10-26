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

local L = addon.L

local _, playerClass = UnitClass('player')

local LibMounts, LMversion = LibStub("LibMounts-1.0")
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
	eventHandler:RegisterEvent('SPELLS_CHANGED')
	hooksecurefunc('SpellBook_UpdateCompanionsFrame', function(...) return self:SpellBook_UpdateCompanionsFrame(...) end)

	if playerClass == "DRUID" then
		hooksecurefunc(self, "SPELLS_CHANGED", self.UPDATE_SHAPESHIFT_FORMS)
		eventHandler:RegisterEvent('UPDATE_SHAPESHIFT_FORMS')
	end

	if IsLoggedIn() then
		self:SPELLS_CHANGED("OnEnable")
	end

	self:SetupMacro()
end
eventHandler:RegisterEvent('ADDON_LOADED')

function addon:LoadConfig()
	local success, msg = LoadAddOn('Squire2_Config')
	assert(success, "Could not load Squire2 configuration module: "..(msg and _G["ADDON_"..msg] or "unknown reason"))
	return success
end

function addon:OpenConfig()
	if self:LoadConfig() then
		return self:OpenConfig()
	end
end

function addon:SpellBook_UpdateCompanionsFrame()
	if SpellBookCompanionsFrame.mode == 'MOUNT' then
		if self:LoadConfig() then
			return self:SpellBook_UpdateCompanionsFrame()
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
-- Chat commands and binding labels
----------------------------------------------

BINDING_HEADER_SQUIRE2 = "Squire2"
_G["BINDING_NAME_CLICK Squire2Button:LeftButton"] = L["Use Squire2"]

SLASH_SQUIRE1 = "/squire2"
SLASH_SQUIRE2 = "/squire"
SLASH_SQUIRE3 = "/sq"
SLASH_SQUIRE4 = "/sq2"
function SlashCmdList.SQUIRE()
	addon:OpenConfig()
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

function addon:SPELLS_CHANGED(event)
	wipe(knownSpells)
	self:COMPANION_LEARNED(event, "MOUNT")
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
addon.COMPANION_UNLEARNED = addon.COMPANION_LEARNED

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
local mounts = mountsByType[mountType]
	if not mounts then
		mounts = LibMounts:GetMountList(mountType)
		mountsByType[mountType] = mounts
	end
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

local baseDismountTest = "[mounted] dismount; [@vehicle,exists] leavevehicle"
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

	local flyingForm = 33943 -- Flight form
	local movingForms = {
		783, -- Travel form
		1066, -- Aquatic form
		flyingForm
	}
	addon.mountSpells = movingForms

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
		-- Select Swift Flight form or Flight form
		flyingForm = knownSpells[40120] and 40120 or 33943
		movingForms[3] = flyingForm
		Debug('UPDATE_SHAPESHIFT_FORMS', dismountTest)
	end

	local origGetActionForMount = GetActionForMount
	function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		local actionType, actionData = origGetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if actionType and actionData then
			return actionType, actionData
		end
		local enabled = addon.db.char.mounts
		if mountType == AIR and enabled[flyingForm] then
			return 'spell', knownSpells[flyingForm] -- One of the flying form
		end
		if mountType == WATER and enabled[1066] then
			return 'spell', knownSpells[1066] -- Aquatic Form
		end
		if isOutdoors and enabled[783] then
			return 'spell', knownSpells[783] -- Travel Form
		elseif select(5, GetTalentInfo(2, 6)) == 2 and enabled[768] then -- Feral Swiftness
			return 'spell', knownSpells[768] -- Cat Form
		end
	end

elseif playerClass == 'SHAMAN' then

	addon.mountSpells = { 2645 } -- Ghost Wolf
	dismountTest = baseDismountTest.."; [stance] cancelform"

	local origGetActionForMount = GetActionForMount
	function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		local actionType, actionData = origGetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if actionType and actionData then
			return actionType, actionData
		elseif mountType == GROUND and select(5, GetTalentInfo(2, 6)) == 2 and addon.db.char.mounts[2645] then -- Ancestral Swiftness
			return 'spell', knownSpells[2645] -- Ghost Wolf
		end
	end

elseif playerClass == 'HUNTER' then

	addon.mountSpells = { 5118 } -- Aspect of the Cheetah

	local origGetActionForMount = GetActionForMount
	function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		local actionType, actionData = origGetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if actionType and actionData then
			return actionType, actionData
		elseif mountType == GROUND  and addon.db.char.mounts[5118] then
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
	rightbutton = function() return GetMouseButtonClicked() == "RightButton" end,
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
	local groundOnly = groundModifierCheck[addon.db.profile.groundModifier]()
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

-- Debug code
SLASH_TESTSQUIRE1 = "/sq2test"

do
	local function tocoloredstring(value)
		if type(value) == "string" then
			return value
		elseif value == nil then
			return "|cff777777nil|r"
		elseif type(value) == "bool" then
			return format("|cff0077ff%s|r", tostring(value))
		elseif type(value) == "number" then
			return format("|cff7777ff%s|r", tostring(value))
		elseif type(value) == "table" and type(value.GetName) == "function" then
			return format("|cffff7700[%s]|r", tostring(value:GetName()))
		else
			return format("|cff00ff77%s|r", tostring(value))
		end
	end

	local function tocoloredstringall(...)
		if select('#', ...) > 0 then
			return tocoloredstring(...), tocoloredstringall(select(2, ...))
		end
	end

	local function cprint(...)
		local str = strjoin(" ", tocoloredstringall(...)):gsub("= ", "=")
		return print(str)
	end

	function SlashCmdList.TESTSQUIRE()
		cprint('|cffff7700=== Squire2 test ===|r')
		cprint('Version:', GetAddOnMetadata("SQUIRE2", "Version"))
		cprint("Class=", select(2, UnitClass("player")), "Level=", UnitLevel("player"))
		cprint('LibMounts-1.0 version:', LMversion)
		cprint('LibMounts-1.0 data version:', select(2, LibStub('LibMounts-1.0_Data')))
		cprint('LibMounts GetCurrentMountType:', LibMounts:GetCurrentMountType())
		cprint('GetMapInfo=', GetMapInfo(), 'IsFlyableArea=', not not IsFlyableArea())
		cprint('IsFlying=', not not IsFlying(), 'IsSwimming=', not not IsSwimming(), 'IsMoving=', GetUnitSpeed("player") > 0)
		cprint('IsMounted=', not not IsMounted(), 'InVehicle=', not not UnitHasVehicleUI("player"))
		cprint('dismountTest=', dismountTest, 'result=', SecureCmdOptionParse(dismountTest))
		cprint('|cffff7700Mounts:|r')
		for index = 1, GetNumCompanions("MOUNT") do
			local _, name, id, _, active = GetCompanionInfo("MOUNT", index)
			local ground, air, water = LibMounts:GetMountInfo(id)
			cprint('  ', GetSpellLink(id), 'active=', not not active, 'known=', not not knownMounts[id], 'enabled=', not not addon.db.char.mounts[id], 'usable=', not not IsUsableSpell(id), "type=", water and "WATER" or air and "AIR" or ground and "GROUND" or "")
		end
		if addon.mountSpells then
			cprint('|cffff7700Spells:|r')
			for i, id in ipairs(addon.mountSpells) do
				cprint('  ', GetSpellLink(id), 'known=', not not knownSpells[id], 'enabled=', not not addon.db.char.mounts[id])
			end
		end
		cprint('|cffff7700Tests:|r')
		cprint('- GROUND, stationary =>', GetActionForType(GROUND, false, false))
		cprint('- GROUND, moving =>', GetActionForType(GROUND, false, true))
		cprint('- AIR, stationary =>', GetActionForType(AIR, false, false))
		cprint('- AIR, moving =>', GetActionForType(AIR, false, true))
		cprint('- AIR, stationary, ground modifier =>', GetActionForType(AIR, true, false))
		cprint('- AIR, moving, ground modifier =>', GetActionForType(AIR, true, true))
		cprint('- WATER, stationary =>', GetActionForType(WATER, false, false))
		cprint('- WATER, moving =>', GetActionForType(WATER, false, true))
		cprint('- WATER, stationary, ground modifier =>', GetActionForType(WATER, true, false))
		cprint('- WATER, moving, ground modifier =>', GetActionForType(WATER, true, true))
		cprint('- combat action:', GetCombatAction())
		cprint('- actual action:', ResolveAction())
	end
end
