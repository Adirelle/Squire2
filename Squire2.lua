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

local MOUNTS_BY_TYPE = {
	[AIR] = LibMounts:GetMountList(AIR),
	[GROUND] = LibMounts:GetMountList(GROUND),
	[WATER] = LibMounts:GetMountList(WATER),
	[LibMounts.AHNQIRAJ] = LibMounts:GetMountList(LibMounts.AHNQIRAJ),
	[LibMounts.VASHJIR] = LibMounts:GetMountList(LibMounts.VASHJIR),
}

local RUNNING_WILD_ID = 87840

-- Unknown at login
local RUNNING_WILD_NAME

-- 0 to only list "normal" mounts, -1 to include Running Wild
local FIRST_ITERATOR_STEP = 0

local tconcat = table.concat

local ACTION_NOOP, ACTION_SMOOTH, ACTION_TOGGLE = 1, 2, 3
addon.ACTION_NOOP, addon.ACTION_SMOOTH, addon.ACTION_TOGGLE = ACTION_NOOP, ACTION_SMOOTH, ACTION_TOGGLE

--------------------------------------------------------------------------------
-- Initializing
--------------------------------------------------------------------------------

local DEFAULTS = {
	profile = {
		groundModifier = "any",
		dismountModifier = "none",
		ifInVehicle = ACTION_NOOP,
		ifMounted = GetCVarBool('autoDismount') and ACTION_SMOOTH or ACTION_NOOP,
		ifShapeshifted = GetCVarBool('autoUnshift') and ACTION_SMOOTH or ACTION_NOOP,
		secureFlight = not GetCVarBool('autoDismountFlying'),
	},
	char = { mounts = { ['*'] = true } },
}

local eventHandler = CreateFrame("Frame")
eventHandler:SetScript('OnEvent', function(_, event, ...) return addon[event](addon, event, ...) end)

function addon:ADDON_LOADED(_, name)
	if name ~= addonName then return end
	eventHandler:UnregisterEvent('ADDON_LOADED')

	self.db = LibStub('AceDB-3.0'):New(addonName.."DB", DEFAULTS, true)

	-- Clean up invalid actions because of buggy AceGUI-3.0-SharedMediaWidgets
	if strmatch(tostring(self.db.char.combatAction), "nil") then
		self.db.char.combatAction = nil
	end
	if strmatch(tostring(self.db.char.movingAction), "nil") then
		self.db.char.movingAction = nil
	end

	local profile = self.db.profile

	-- Upgrade from previous database version
	if profile.autoDismount then
		profile.autoDismount = nil
		profile.ifMounted = ACTION_TOGGLE
		profile.ifShapeshifted = ACTION_TOGGLE
		profile.ifInVehicle = ACTION_TOGGLE
	end
	if profile.safeDismount then
		profile.safeDismount = nil
		profile.secureFlight = true
	end

	eventHandler:RegisterEvent('PLAYER_REGEN_ENABLED')

	self:Initialize()
end
eventHandler:RegisterEvent('ADDON_LOADED')

function addon:Initialize()
	if not self:CanDoSecureStuff('Initialize') then return end

	self.canShapeshift = false

	local button = CreateFrame("Button", "Squire2Button", nil, "SecureActionButtonTemplate")
	button:RegisterForClicks("AnyUp")
	button:SetScript("PreClick", self.ButtonPreClick)
	button:SetScript("PostClick", self.ButtonPostClick)
	self.button = button

	local secondaryButton = CreateFrame("Button", "Squire2SecondaryButton", nil, "SecureActionButtonTemplate")
	secondaryButton:RegisterForClicks("AnyUp")
	self.secondaryButton = secondaryButton

	eventHandler:RegisterEvent('PLAYER_REGEN_DISABLED')
	eventHandler:RegisterEvent('COMPANION_UPDATE')
	eventHandler:RegisterEvent('SPELLS_CHANGED')
	eventHandler:RegisterEvent('PLAYER_ENTERING_WORLD')

	hooksecurefunc('SpellBook_UpdateCompanionsFrame', function(...) return self:SpellBook_UpdateCompanionsFrame(...) end)

	-- Hook UIErrorsFrame_OnEvent to eat errors
	self.orig_UIErrorsFrame_OnEvent = UIErrorsFrame_OnEvent
	UIErrorsFrame_OnEvent = self.UIErrorsFrame_OnEvent

	if playerClass == "DRUID" or playerClass == "SHAMAN" then
		eventHandler:RegisterEvent('UPDATE_SHAPESHIFT_FORMS')
	end

	if IsLoggedIn() then
		self:SPELLS_CHANGED("OnEnable")
	end

	self:SetupMacro()
	self:UpdateMacroTemplate()
end

local UIErrorsFrame = UIErrorsFrame
local catchMessages = false

function addon.ButtonPreClick(_, button)
	if Squire2Button:CanChangeAttribute() and button ~= "dismount" then
		addon:UpdateAction(button)
	end
	catchMessages = true
end

function addon.ButtonPostClick()
	catchMessages = false
end

function addon.UIErrorsFrame_OnEvent(frame, event, ...)
	if catchMessages and event == 'UI_ERROR_MESSAGE' then
		return Debug(event, ...)
	else
		return addon.orig_UIErrorsFrame_OnEvent(frame, event, ...)
	end
end

function addon:PLAYER_REGEN_DISABLED()
	addon:UpdateAction("combat")
end

do
	local pending = {}

	function addon:CanDoSecureStuff(method)
		if InCombatLockdown() then
			if not pending[method] then
				pending[method] = true
				tinsert(pending, method)
			end
			return false
		end
		return true
	end

	function addon:PLAYER_REGEN_ENABLED()
		for i, method in ipairs(pending) do
			self[method](self)
		end
		wipe(pending)
	end
end

----------------------------------------------
-- Config handling
----------------------------------------------

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

function addon:ConfigChanged()
	self:UpdateMacroTemplate()
end

----------------------------------------------
-- Squire2 visible macro
----------------------------------------------

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
	if not self:CanDoSecureStuff("SetupMacro") then return index end
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
_G["BINDING_NAME_CLICK Squire2Button:dismount"] = L["Dismount"]

SLASH_SQUIRE1 = "/squire2"
SLASH_SQUIRE2 = "/squire"
SLASH_SQUIRE3 = "/sq"
SLASH_SQUIRE4 = "/sq2"
function SlashCmdList.SQUIRE()
	addon:OpenConfig()
end

----------------------------------------------
-- Mount iterator (required to handle Running Wild)
----------------------------------------------

local function mountIterator(num, index)
	index = index + 1
	if index == 0 then
		return index, RUNNING_WILD_ID, not not UnitBuff("player", RUNNING_WILD_NAME)
	elseif index <= num then
		local found, _, id, _, active = GetCompanionInfo("MOUNT", index)
		return index, id, active
	end
end

local function IterateMounts()
	return mountIterator, GetNumCompanions("MOUNT"), FIRST_ITERATOR_STEP
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

	-- Worgen's "Running Wild" support
	if not RUNNING_WILD_NAME and knownSpells[RUNNING_WILD_ID] then
		RUNNING_WILD_NAME = spellNames[RUNNING_WILD_ID]
		MOUNTS_BY_TYPE[GROUND][RUNNING_WILD_ID] = true
		FIRST_ITERATOR_STEP = -1
		if not addon.mountSpells then
			addon.mountSpells = {}
		end
		tinsert(addon.mountSpells, RUNNING_WILD_ID)
	end

	self:UPDATE_SHAPESHIFT_FORMS(event)
end

function addon:UPDATE_SHAPESHIFT_FORMS(event)
	local canShapeshift = (playerClass == "DRUID" or playerClass == "SHAMAN") and GetNumShapeshiftForms() > 0
	if canShapeshift and self.Post_UPDATE_SHAPESHIFT_FORMS then
		self:Post_UPDATE_SHAPESHIFT_FORMS(event)
	end
	if canShapeshift ~= self.canShapeshift then
		self.canShapeshift = canShapeshift
		self:UpdateMacroTemplate()
	end
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
		for index, id, active in IterateMounts() do
			if active then
				mountHistory[id] = time()
				return
			end
		end
	end
end

function addon:ChooseMount(mountType)
	local mounts = MOUNTS_BY_TYPE[mountType]
	local oldestTime, oldestId
	for index, id, active in IterateMounts() do
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

----------------------------------------------
-- Internal macro template
----------------------------------------------

local macroTemplate = ""
local noopConditions = ""

local modifierConds = {
	any = "mod",
	control = "mod:ctrl",
	alt = "mod:alt",
	shift = "mod:shift",
	rightbutton = "button:2",
}

local cmds, noopConds, stopConds = {}, {}, {}

local function AddCancelCommand(setting, command, condition, forceDismountCondition)
	if setting == ACTION_SMOOTH then
		-- Smooth transition, cancel before trying to do something else
		tinsert(cmds, 1, command.." ["..condition.."]")
	else
		-- (Overridable) No-op or toggle, include cancelling command
		tinsert(cmds, command.." ["..condition.."]")
		tinsert(noopConds, "["..condition.."]")
		if setting == ACTION_NOOP then
			-- No-op add stop condition
			tinsert(stopConds, "["..condition..forceDismountCondition.."]")
		end
	end
end

function addon:UpdateMacroTemplate()
	local pref = addon.db.profile
	local dismountModifier = pref.dismountModifier and modifierConds[pref.dismountModifier]
	local forceDismountCondition = dismountModifier and (",no"..dismountModifier) or ""
	wipe(cmds)
	wipe(noopConds)
	wipe(stopConds)
	if pref.secureFlight then
		tinsert(stopConds, "[flying"..forceDismountCondition.."]")
	end
	tinsert(cmds, "%ACTION%")
	if self.canShapeshift then
		AddCancelCommand(pref.ifShapeshifted, "/cancelform", "form", forceDismountCondition)
	end
	AddCancelCommand(pref.ifMounted, "/dismount", "mounted", forceDismountCondition)
	AddCancelCommand(pref.ifInVehicle, "/leavevehicle", "@vehicle,exists", forceDismountCondition)
	if #stopConds > 0 then
		tinsert(cmds, 1, "/stopmacro "..tconcat(stopConds, ""))
	end
	macroTemplate = tconcat(cmds, "\n")
	noopConditions = tconcat(noopConds, "")
	Debug("UpdateMacroTemplate: noopConditions=", noopConditions)
	Debug("UpdateMacroTemplate: template=\n"..macroTemplate)
	self:UpdateDismountAction()
end

function addon:UpdateDismountAction()
	if not self:CanDoSecureStuff('UpdateDismountAction') then return end
	local dismountMacro = "/dismount [mounted]\n/leavevehicle [@vehicle,exists]"
	if self.canShapeshift then
		dismountMacro = dismountMacro .. "\n/cancelform [form]"
	end
	self:SetButtonAction(self.button, 'macrotext', dismountMacro, "-dismount")
end

----------------------------------------------
-- Core logic
----------------------------------------------

function addon:SetButtonAction(button, actionType, actionData, suffix)
	if actionType and actionData then
		if actionType == 'spell' then
			actionData = spellNames[actionData] or actionData
		elseif actionType == 'item' then
			actionData = tonumber(actionData) and GetItemInfo(tonumber(actionData)) or actionData
		end
		button:SetAttribute(actionType..suffix, actionData)
		if actionType == 'macrotext' then
			button:SetAttribute('macro'..suffix, nil)
			actionType = 'macro'
		end
		button:SetAttribute('type'..suffix, actionType)
	else
		button:SetAttribute('type'..suffix, nil)
	end
	Debug('SetButtonAction', button, 'action=', actionType, 'param=', actionData, 'suffix=', suffix)
end

function addon:GetActionForMount(mountType, isMoving, inCombat, isOutdoors)
	if not isMoving and not inCombat then
		local id = self:ChooseMount(mountType)
		if id then
			Debug('GetActionForMount => spell', spellNames[id] or id)
			return 'spell', id
		end
	end
	if isMoving and addon.db.char.movingAction and (mountType ~= AIR or not IsFalling()) then
		Debug('GetActionForMount (moving) =>', addon.db.char.movingAction)
		local actionType, actionData = strsplit(':', addon.db.char.movingAction)
		if actionType and actionData then
			return actionType, actionData
		end
	end
	if self.GetAlternateActionForMount then
		return self:GetAlternateActionForMount(mountType, isMoving, inCombat, isOutdoors)
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

	function addon:Post_UPDATE_SHAPESHIFT_FORMS()
		flyingForm = knownSpells[40120] and 40120 or 33943
		movingForms[3] = flyingForm
	end

	function addon:GetAlternateActionForMount(mountType, isMoving, inCombat, isOutdoors)
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
	function addon:GetAlternateActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if mountType == GROUND and (not isMoving or select(5, GetTalentInfo(2, 6)) == 2) then -- Ancestral Swiftness
			return 'spell', addon.db.char.mounts[2645] and knownSpells[2645] -- Ghost Wolf
		end
	end

elseif playerClass == 'HUNTER' then

	addon.mountSpells = { 5118 } -- Aspect of the Cheetah
	function addon:GetAlternateActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if mountType == GROUND and addon.db.char.mounts[5118] then
			return 'spell', addon.db.char.mounts[5118] and knownSpells[5118] -- Aspect of the Cheetah
		end
	end

end

function addon:ExploreActions(groundOnly, isMoving, isOutdoors, primary, secondary, tertiary)
	Debug('ExploreActions', "groundOnly=", groundOnly, "moving=", isMoving, "outdoors=", isOutdoors, "mounts=[", primary, secondary, tertiary, "]")
	if primary == AIR and groundOnly then
		if secondary then
			Debug('ExploreActions, skiping AIR type with groundOnly')
			return self:ExploreActions(groundOnly, isMoving, isOutdoors, secondary, tertiary)
		else
			return
		end
	end
	local actionType, actionData = self:GetActionForMount(primary, isMoving, false, isOutdoors)
	if actionType and actionData then
		return actionType, actionData
	end
	if secondary then
		Debug('ExploreActions, trying secondary')
		actionType, actionData = self:ExploreActions(groundOnly, isMoving, isOutdoors, secondary, tertiary)
		if actionType and actionData then
			return actionType, actionData
		end
	end
	if not isMoving then
		Debug('ExploreActions, trying with moving')
		actionType, actionData = self:ExploreActions(groundOnly, true, isOutdoors, primary, secondary, tertiary)
		if actionType and actionData then
			return actionType, actionData
		end
	end
	if not isOutdoors then
		Debug('ExploreActions, trying outdoors')
		return self:ExploreActions(groundOnly, isMoving, true, primary, secondary, tertiary)
	end
end

function addon:GetMacroCommand(actionType, actionData)
	if actionType and actionData then
		if actionType == 'spell' then
			return "/cast", spellNames[actionData] or actionData
		elseif actionType == 'item' then
			return "/cast", GetItemInfo(actionData) or actionData
		else
			local key = gsub(actionType.."_"..actionData, "%W", "_")
			self:SetButtonAction(self.secondaryButton, actionType, actionData, '-'..key)
			return "/click", self.secondaryButton:GetName().." "..key
		end
	end
end

local cmds = {}
local lastCmdIndex

local function AddActionCommand(cmd, cond, arg)
	if not cmd or not arg then return end
	if lastCmdIndex and cmd == cmds[lastCmdIndex] then
		-- Same command
		if cond == "" and arg == cmds[#cmds] then
			-- Same argument, remove previous entries with same argument but a condition
			-- e.g. "[swimming]Foo;[mod]Bar;Bar" => "[swimming]Foo;Bar"
			local i = #cmds
			while i > lastCmdIndex + 3 and arg == cmds[i] do
				i = i - 3
			end
			cmds[i-1] = ""
			for j = i+1, #cmds do
				cmds[j] = nil
			end
			return
		end
		-- Prepare for a new condition,argument pair
		tinsert(cmds, ";")
	else
		-- New command
		if lastCmdIndex then
			tinsert(cmds, "\n")
		end
		tinsert(cmds, cmd)
		lastCmdIndex = #cmds
		if noopConditions then
			tinsert(cmds, " "..noopConditions..";")
		else
			tinsert(cmds, " ")
		end
	end
	-- Append the condition and argument
	tinsert(cmds, cond)
	tinsert(cmds, arg)
end

function addon:BuildAction(clickedButton)
	wipe(cmds)
	lastCmdIndex = nil
	
	local actionType, actionData
	local isMoving = GetUnitSpeed("player") > 0 or IsFalling()

	-- Add action with ground modifier, if applicable
	local groundModifier = addon.db.profile.groundModifier and modifierConds[addon.db.profile.groundModifier]
	if groundModifier then
		local groundCmd, groundArg = self:GetMacroCommand(self:GetActionForMount(GROUND, isMoving, inCombat, true))
		AddActionCommand(groundCmd, "["..groundModifier.."]", groundArg)
	end

	-- Add modified combat actions
	if clickedButton == "combat" and not addon.db.char.combatAction then
		local waterCmd, waterArg = self:GetMacroCommand(self:GetActionForMount(WATER, true, true, false))
		local outdoorsCmd, outdoorsArg = self:GetMacroCommand(self:GetActionForMount(GROUND, true, true, true))
		AddActionCommand(waterCmd, "[swimming]", waterArg)
		AddActionCommand(outdoorsCmd, "[outdoors]", outdoorsArg)
	end

	-- Add the main action
	if clickedButton == "combat" then
		if addon.db.char.combatAction then
			actionType, actionData = strsplit(':', addon.db.char.combatAction)
		else
			actionType, actionData = self:GetActionForMount(GROUND, true, true, false)
		end
	else
		local primary, secondary, tertiary = LibMounts:GetCurrentMountType()
		actionType, actionData = self:ExploreActions(groundOnly, isMoving, IsOutdoors(), primary or GROUND, secondary, tertiary)
	end
	local mainCmd, mainArg = self:GetMacroCommand(actionType, actionData)
	AddActionCommand(mainCmd, "", mainArg)

	-- Join all
	return tconcat(cmds, "")
end

function addon:UpdateAction(clickedButton)
	local action = self:BuildAction(clickedButton)
	local macro = gsub(macroTemplate, "%%ACTION%%", action)
	self:SetButtonAction(self.button, "macrotext", macro, "")
end

--@alpha@
-- Debug commands

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

local function DumpSettings(t, key, value)
	if key then
		return tostring(key).."=", value, DumpSettings(t, next(t, key))
	end
end

SLASH_TESTSQUIRE1 = "/sq2test"
function SlashCmdList.TESTSQUIRE(cmd)
	cmd = strlower(strtrim(tostring(cmd)))
	cprint('|cffff7700=== Squire2 '..cmd..' ===|r')
	if cmd == "all" or cmd == "" then
		cprint("Locale:", GetLocale(), "BuildInfo:", GetBuildInfo())
		local ehName, ehEnabled = "unknown", "unknown"
		if BugGrabber then
			ehName, ehEnabled = "BugGrabber", true
		elseif Swatter then
			ehName, ehEnabled = "Swatter", type(SwatterData) == "table" and SwatterData.enabled
		elseif geterrorhandler() == _ERRORMESSAGE then
			ehName, ehEnabled = "built-in", GetCVarBool("scriptErrors")
		end
		cprint('Error handler:', ehName, 'enabled=', ehEnabled)
		cprint('Addon version:', GetAddOnMetadata(addonName, "Version"))
		cprint('LibMounts-1.0 version:', LMversion)
		cprint('LibMounts-1.0 data version:', select(2, LibStub('LibMounts-1.0_Data')))
		cprint("Class=", select(2, UnitClass("player")), "Level=", UnitLevel("player"))
		cprint('db.profile:', DumpSettings(addon.db.profile, next(addon.db.profile)))
		cprint('db.char:', DumpSettings(addon.db.char, next(addon.db.char)))
		cprint('autoDismount=', GetCVarBool('autoDismount'), 'autoDismountFyling=', GetCVarBool('autoDismountFyling'), 'autoUnshift=', GetCVarBool('autoUnshift'))
		cprint('LibMounts GetCurrentMountType:', LibMounts:GetCurrentMountType())
		cprint('GetMapInfo=', GetMapInfo(), 'IsFlyableArea=', not not IsFlyableArea())
		cprint('IsFlying=', not not IsFlying(), 'IsSwimming=', not not IsSwimming(), 'IsMoving=', GetUnitSpeed("player") > 0)
		cprint('IsMounted=', not not IsMounted(), 'InVehicle=', not not UnitHasVehicleUI("player"))
	end
	if cmd == "tests" or cmd == "all" then
		local isOutdoors = IsOutdoors()
		cprint('|cffff7700Mount/spell selection:|r')
		-- groundOnly, isMoving, isOutdoors, primary, secondary, tertiary
		cprint('- GROUND, stationary =>', addon:ExploreActions(false, false, isOutdoors, GROUND))
		cprint('- GROUND, moving =>', addon:ExploreActions(false, true, isOutdoors, GROUND))
		cprint('- AIR, stationary =>',  addon:ExploreActions(false, false, isOutdoors, AIR))
		cprint('- AIR, moving =>',  addon:ExploreActions(false, true, isOutdoors, AIR))
		cprint('- AIR, stationary, ground modifier =>',  addon:ExploreActions(true, false, isOutdoors, AIR))
		cprint('- AIR, moving, ground modifier =>',  addon:ExploreActions(true, true, isOutdoors, AIR))
		cprint('- WATER, stationary =>', addon:ExploreActions(false, false, isOutdoors, WATER))
		cprint('- WATER, moving =>', addon:ExploreActions(false, true, isOutdoors, WATER))
		cprint('- WATER, stationary, ground modifier =>', addon:ExploreActions(true, false, isOutdoors, WATER))
		cprint('- WATER, moving, ground modifier =>', addon:ExploreActions(true, true, isOutdoors, WATER))
	end
	if cmd == "macros" or cmd == "all" then
		cprint('|cffff7700Macro building:|r')
		cprint('- internal macro template:\n', macroTemplate)
		cprint('- combat action:\n', addon:BuildAction("combat"))
		cprint('- out of combat action:\n', addon:BuildAction("LeftButton"))
	end
	if cmd == "mounts" or cmd == "all" then
		cprint('|cffff7700Character mounts:|r')
		for index, id, active in IterateMounts() do
			if index > 0 then -- Filter out added mounts
				local ground, air, water = LibMounts:GetMountInfo(id)
				cprint('  ', GetSpellLink(id), 'active=', not not active, 'enabled=', not not addon.db.char.mounts[id], 'usable=', not not IsUsableSpell(id), "type=", 		water and "WATER" or air and "AIR" or ground and "GROUND" or "")
			end
		end
		if addon.mountSpells then
			cprint('|cffff7700Character spells:|r')
			for i, id in ipairs(addon.mountSpells) do
				cprint('  ', GetSpellLink(id), 'known=', not not knownSpells[id], 'enabled=', not not addon.db.char.mounts[id], 'usable=', not not IsUsableSpell(id))
			end
		end
	end
end
--@end-alpha@
