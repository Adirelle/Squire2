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
if AdiDebug then
	Debug = AdiDebug:GetSink(addonName)
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
	eventHandler:RegisterEvent('SPELLS_CHANGED')
	eventHandler:RegisterEvent('PLAYER_ENTERING_WORLD')
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

local function NOOP() end

function addon:LoadConfig()
	self.LoadConfig, self.OpenConfig, self.SpellBook_UpdateCompanionsFrame = NOOP, NOOP, NOOP
	local success, msg = LoadAddOn('Squire2_Config')
	assert(success, "Could not load Squire2 configuration module: "..(msg and _G["ADDON_"..msg] or "unknown reason"))
end

function addon:OpenConfig()
	self:LoadConfig()
	return self:OpenConfig()
end

function addon:SpellBook_UpdateCompanionsFrame()
	if SpellBookCompanionsFrame.mode == 'MOUNT' then
		self:LoadConfig()
		return self:SpellBook_UpdateCompanionsFrame()
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

local MACRO_NAME, MACRO_ICON, MACRO_BODY = "Squire2", [[Interface\Icons\Ability_Mount_RidingHorse]], "/click [button:2] Squire2Button RightButton; Squire2Button"
local function GetMacroIconIndex(texture)
	for index = 1, GetNumMacroIcons() do
		if GetMacroIconInfo(index) == texture then
			return index
		end
	end
	return 1
end
function addon:SetupMacro(create)
	local index = GetMacroIndexByName(MACRO_NAME)
	if index == 0 then
		if create then
			return CreateMacro(MACRO_NAME, GetMacroIconIndex(MACRO_ICON), MACRO_BODY, 0)
		end
	else
		return EditMacro(index, MACRO_NAME, GetMacroIconIndex(MACRO_ICON), MACRO_BODY)
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
	local numId = tonumber(id)
	if numId then
		local name = GetSpellInfo(numId)
		Debug('Spell #', numId, 'name:', name)
		t[id] = name or false
		if numId ~= id then
			t[numId] = name
		end
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
end
function addon:PLAYER_ENTERING_WORLD(event)
	return self:SPELLS_CHANGED(event)
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
local mounts = mountsByType[mountType]
	if not mounts then
		mounts = LibMounts:GetMountList(mountType)
		mountsByType[mountType] = mounts
	end
	local oldestTime, oldestId
	for index = 1, GetNumCompanions("MOUNT") do
		local id, _, active = select(3, GetCompanionInfo("MOUNT", index))
		if active then
			mountHistory[id] = time()
		end
		if addon.db.char.mounts[id] and IsUsableSpell(id) and mounts[id] then
			local lastTime = (mountHistory[id] or random(0, 1000))
			if not oldestTime or lastTime < oldestTime then
				oldestTime, oldestId = lastTime, id
			end
		end
	end
	return oldestId
end

local dismountMacro = "/dismount [mounted]\n/leavevehicle [@vehicle,exists]"
local dismountTest = "[mounted][@vehicle,exists]"
local canShapeshift = (playerClass == "DRUID" or playerClass == "SHAMAN")

local function SetButtonAction(actionType, actionData, prefix, suffix)
	if not prefix then prefix = "" end
	if not suffix then suffix = "" end
	if actionType and actionData then
		if actionType == 'spell' then
			actionData = spellNames[actionData] or actionData
		elseif actionType == 'item' then
			actionData = tonumber(actionData) and GetItemInfo(tonumber(actionData)) or actionData
		end
		addon.button:SetAttribute(prefix..actionType..suffix, actionData)
		if actionType == 'macrotext' then
			actionType = 'macro'
		end
		addon.button:SetAttribute(prefix..'type'..suffix, actionType)
	else
		addon.button:SetAttribute(prefix..'type'..suffix, nil)
	end
	Debug('SetButtonAction', actionType, actionData, prefix, suffix)
end

local function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
	if not isMoving and not inCombat then
		local id = ChooseMount(mountType)
		if id then
			Debug('GetActionForMount => spell', spellNames[id] or id)
			return 'spell', id
		end
	end
	if mountType ~= AIR and isMoving and addon.db.char.movingAction then
		local actionType, actionData = strsplit(':', addon.db.char.movingAction)
		if actionType and actionData then
			Debug('GetActionForMount (moving) =>', actionType, actionData)
			return actionType, actionData
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

	local baseDismountTest, baseDismountMacro = dismountTest, dismountMacro
	local t = {}
	function addon:UPDATE_SHAPESHIFT_FORMS()
		-- Select Swift Flight form or Flight form
		flyingForm = knownSpells[40120] and 40120 or 33943
		movingForms[3] = flyingForm
		-- Test existing forms for "mount-like" ones
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
			local test = format("[form:%s]", table.concat(t, "/"))
			dismountTest = baseDismountTest..test
			dismountMacro =  baseDismountMacro.."\n/cancelform "..test
		else
			dismountTest, dismountMacro = baseDismountTest, baseDismountMacro
		end
		Debug('UPDATE_SHAPESHIFT_FORMS', dismountTest, dismountMacro)
	end

	local origGetActionForMount = GetActionForMount
	function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		local actionType, actionData = origGetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if actionType and actionData then
			return actionType, actionData
		end
		if mountType == AIR then
			return 'spell', addon.db.char.mounts[flyingForm] and IsUsableSpell(flyingForm) and knownSpells[flyingForm] -- Any flying form
		elseif mountType == WATER then
			return 'spell', addon.db.char.mounts[1066] and knownSpells[1066] -- Aquatic Form
		elseif mountType == GROUND then
			if isOutdoors and addon.db.char.mounts[783] and knownSpells[783] then
				return 'spell', 783 -- Travel Form
			elseif select(5, GetTalentInfo(2, 6)) == 2 then -- Feral Swiftness
				return 'spell', knownSpells[768] -- Cat Form
			end
		end
	end

elseif playerClass == 'SHAMAN' then

	addon.mountSpells = { 2645 } -- Ghost Wolf

	dismountTest = dismountTest .. "[form]"
	dismountMacro = dismountMacro .. "\n/cancelform [form]"

	local origGetActionForMount = GetActionForMount
	function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		local actionType, actionData = origGetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if actionType and actionData then
			return actionType, actionData
		elseif mountType == GROUND and (not isMoving or select(5, GetTalentInfo(2, 6)) == 2) then -- Ancestral Swiftness
			return 'spell', addon.db.char.mounts[2645] and knownSpells[2645] -- Ghost Wolf
		end
	end

elseif playerClass == 'HUNTER' then

	addon.mountSpells = { 5118 } -- Aspect of the Cheetah

	local origGetActionForMount = GetActionForMount
	function GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		local actionType, actionData = origGetActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if actionType and actionData then
			return actionType, actionData
		elseif mountType == GROUND and addon.db.char.mounts[5118] then
			return 'spell', addon.db.char.mounts[5118] and knownSpells[5118] -- Aspect of the Cheetah
		end
	end

end

local modifierTests = {
	none = function() return false end,
	any = IsModifierKeyDown,
	control = IsControlKeyDown,
	alt = IsAltKeyDown,
	shift = IsShiftKeyDown,
	rightbutton = function() return GetMouseButtonClicked() == "RightButton" end,
}

local function TestModifier(name)
	local modifier = addon.db.profile[name]
	return name and modifierTests[name]()
end

local function GetMacroCast(actionType, actionData)
	if not actionData then return end
	if actionType == 'spell' then
		return spellNames[actionData] or actionData
	elseif actionType == 'item' then
		return GetItemInfo(actionData) or actionData
	end
end

local function GetMacroForAction(actionType, actionData)
	local cast = GetMacroCast(actionType, actionData)
	if cast then
		return "/cast "..cast
	elseif actionType == 'macrotext' then
		return actionData
	end
end

local PrependUnshiftMacro
do
	local commands = {}
	function PrependUnshiftMacro(actionType, actionData)
		wipe(commands)
		local noflying = GetCVarBool('autoDismountFyling') and '' or ',noflying'
		if canShapeshift and not GetCVarBool('autoUnshift') then
			tinsert(commands, '/cancelform [form'..noflying..']')
		end
		if not GetCVarBool('autoDismount') then
			tinsert(commands, '/dismount [mounted'..noflying..']')
		end
		Debug("PrependUnshiftMacro", actionType, actionData, '|', unpack(commands))
		if #commands == 0 then
			return actionType, actionData
		end
		if actionType and actionData then
			local macroForAction = GetMacroForAction(actionType, actionData)
			if macroForAction then
				tinsert(commands, macroForAction)
			else
				-- Sometimes, you can't...
				return actionType, actionData
			end
		end
		Debug("PrependUnshiftMacro =>", unpack(commands))
		return 'macrotext', table.concat(commands, "\n")
	end
end

local GetCombatAction
do
	local t = {}
	function GetCombatAction()
		if addon.db.char.combatAction then
			local actionType, actionData = strsplit(':', addon.db.char.combatAction)
			if actionType and actionData then
				Debug('GetCombatAction (custom)', actionType, actionData)
				return actionType, actionData
			end
		end
		local prefix, suffix = "", ""
		wipe(t)
		if addon.db.profile.autoDismount then
			if addon.db.profile.safeDismount then
				prefix = "/stopmacro [flying]"
			end
			tinsert(t, dismountTest)
			suffix = dismountMacro
		end
		local waterCast = GetMacroCast(GetActionForMount(WATER, true, true))
		local outdoorsCast = GetMacroCast(GetActionForMount(GROUND, true, true, true))
		local indoorsCast = GetMacroCast(GetActionForMount(GROUND, true, true, false))
		if waterCast and waterCast ~= indoorsCast then
			tinsert(t, "[swimming]"..waterCast)
		end
		if outdoorsCast and outdoorsCast ~= indoorsCast then
			tinsert(t, "[outdoors]"..outdoorsCast)
		end
		if indoorsCast then
			tinsert(t, indoorsCast)
		end
		Debug('GetCombatAction', unpack(t))
		if #t > 0 then
			return 'macrotext', strjoin("\n", prefix, "/cast "..table.concat(t, ";"), suffix)
		end
	end
end

local function ExploreActions(groundOnly, isMoving, isOutdoors, primary, secondary, tertiary)
	Debug('ExploreActions', groundOnly, isMoving, isOutdoors, primary, secondary, tertiary)
	if primary == AIR and groundOnly then
		if secondary then
			Debug('ExploreActions, skiping AIR type with groundOnly')
			return ExploreActions(groundOnly, isMoving, isOutdoors, secondary, tertiary)
		else
			return
		end
	end
	local actionType, actionData = GetActionForMount(primary, isMoving, false, isOutdoors)
	if actionType and actionData then
		return actionType, actionData
	end
	if secondary then
		Debug('ExploreActions, trying secondary')
		actionType, actionData = ExploreActions(groundOnly, isMoving, isOutdoors, secondary, tertiary)
		if actionType and actionData then
			return actionType, actionData
		end
	end
	if not isMoving then
		Debug('ExploreActions, trying with moving')
		actionType, actionData = ExploreActions(groundOnly, true, isOutdoors, primary, secondary, tertiary)
		if actionType and actionData then
			return actionType, actionData
		end
	end
	if not isOutdoors then
		Debug('ExploreActions, trying outdoors')
		return ExploreActions(groundOnly, isMoving, true, primary, secondary, tertiary)
	end
end

local commands = {}
local function ResolveAction(button)
	-- In-combat action
	if button == "combat" then
		return GetCombatAction()
	end
	-- Handle dismounting
	local canDismount = SecureCmdOptionParse(dismountTest)
	Debug('canDismount', canDismount)
	if button == "dismount" or TestModifier("dismountModifier") then
		if canDismount then
			return "macrotext", dismountMacro
		else
			return
		end
	elseif canDismount then
		if TestModifier("dismountModifier") or addon.db.profile.autoDismount and not (IsFlying() and addon.db.profile.safeDismount) then
			return "macrotext", dismountMacro
		else
			return
		end
	end
	-- Try to get a mount or a spell
	local primary, secondary, tertiary = LibMounts:GetCurrentMountType()
	local groundOnly = TestModifier("groundModifier")
	local actionType, actionData = ExploreActions(groundOnly, GetUnitSpeed("player") > 0, IsOutdoors(), primary or GROUND, secondary, tertiary)
	return PrependUnshiftMacro(actionType, actionData)
end

function addon:SetupButton(button)
	Debug('SetupButton', button)
	SetButtonAction(ResolveAction(button))
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
		cprint('dismountTest=', dismountTest, 'result=', not not SecureCmdOptionParse(dismountTest))
		cprint('|cffff7700Mounts:|r')
		for index = 1, GetNumCompanions("MOUNT") do
			local _, name, id, _, active = GetCompanionInfo("MOUNT", index)
			local ground, air, water = LibMounts:GetMountInfo(id)
			cprint('  ', GetSpellLink(id), 'active=', not not active, 'enabled=', not not addon.db.char.mounts[id], 'usable=', not not IsUsableSpell(id), "type=", water and "WATER" or air and "AIR" or ground and "GROUND" or "")
		end
		if addon.mountSpells then
			cprint('|cffff7700Spells:|r')
			for i, id in ipairs(addon.mountSpells) do
				cprint('  ', GetSpellLink(id), 'known=', not not knownSpells[id], 'enabled=', not not addon.db.char.mounts[id])
			end
		end
		local isOutdoors = IsOutdoors()
		cprint('|cffff7700Tests:|r')
		-- groundOnly, isMoving, isOutdoors, primary, secondary, tertiary
		cprint('- GROUND, stationary =>', ExploreActions(false, false, isOutdoors, GROUND))
		cprint('- GROUND, moving =>', ExploreActions(false, true, isOutdoors, GROUND))
		cprint('- AIR, stationary =>',  ExploreActions(false, false, isOutdoors, AIR))
		cprint('- AIR, moving =>',  ExploreActions(false, true, isOutdoors, AIR))
		cprint('- AIR, stationary, ground modifier =>',  ExploreActions(true, false, isOutdoors, AIR))
		cprint('- AIR, moving, ground modifier =>',  ExploreActions(true, true, isOutdoors, AIR))
		cprint('- WATER, stationary =>', ExploreActions(false, false, isOutdoors, WATER))
		cprint('- WATER, moving =>', ExploreActions(false, true, isOutdoors, WATER))
		cprint('- WATER, stationary, ground modifier =>', ExploreActions(true, false, isOutdoors, WATER))
		cprint('- WATER, moving, ground modifier =>', ExploreActions(true, true, isOutdoors, WATER))
		cprint('- in-combat action:', ResolveAction("combat"))
		cprint('- out-of-combat action:', ResolveAction("LeftButton"))
		cprint('- actual action:', ResolveAction(InCombatLockdown() and "combat" or "LeftButton"))
	end
end
