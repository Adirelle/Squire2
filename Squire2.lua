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

local GROUND_MOUNTS = {
	STRICT = {},
	ALL = LibMounts:GetMountList(GROUND),
}

local MOUNTS_BY_TYPE = {
	[AIR] = LibMounts:GetMountList(AIR),
	[GROUND] = GROUND_MOUNTS.ALL,
	[WATER] = LibMounts:GetMountList(WATER),
	[LibMounts.AHNQIRAJ] = LibMounts:GetMountList(LibMounts.AHNQIRAJ),
	[LibMounts.VASHJIR] = LibMounts:GetMountList(LibMounts.VASHJIR),
}

do
	-- Build the list of strictly ground mounts
	local ground, air = GROUND_MOUNTS.STRICT, MOUNTS_BY_TYPE[AIR]
	for id in pairs(GROUND_MOUNTS.ALL) do
		ground[id] = not air[id]
	end
end

local RUNNING_WILD_ID = 87840

-- Unknown at login
local RUNNING_WILD_NAME

-- 0 to only list "normal" mounts, -1 to include Running Wild
local FIRST_ITERATOR_STEP = 0

local tconcat = table.concat

local ACTION_NOOP, ACTION_SMOOTH, ACTION_TOGGLE = 1, 2, 3
addon.ACTION_NOOP, addon.ACTION_SMOOTH, addon.ACTION_TOGGLE = ACTION_NOOP, ACTION_SMOOTH, ACTION_TOGGLE

--------------------------------------------------------------------------------
-- Upvalues
--------------------------------------------------------------------------------

local macroTemplate = ""
local noopConditions = ""
local cancelTravelFormCondition
local cancelFormCondition

local modifierConds = {
	any = "mod",
	control = "mod:ctrl",
	alt = "mod:alt",
	shift = "mod:shift",
	rightbutton = "button:2",
}

--------------------------------------------------------------------------------
-- Initializing
--------------------------------------------------------------------------------

local DEFAULTS = {
	profile = {
		groundModifier = "any",
		dismountModifier = "none",
		ifInVehicle = ACTION_NOOP,
		ifMounted = ACTION_SMOOTH,
		ifShapeshifted = ACTION_NOOP,
		secureFlight = true,
		travelFormsAsMounts = false,
		restrictGroundMounts = false,
	},
	char = { mounts = { ['*'] = true } },
}

local eventHandler = CreateFrame("Frame")
eventHandler:SetScript('OnEvent', function(_, event, ...) return addon[event](addon, event, ...) end)

addon.shapeshiftForms = {}
addon.travelForms = {}

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

	eventHandler:RegisterEvent('PLAYER_REGEN_ENABLED')

	self:Initialize()
end
eventHandler:RegisterEvent('ADDON_LOADED')

function addon:Initialize()
	if not self:CanDoSecureStuff('Initialize') then return end

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

	if self.UPDATE_SHAPESHIFT_FORMS then
		eventHandler:RegisterEvent('UPDATE_SHAPESHIFT_FORMS')
	end

	hooksecurefunc('SpellBook_UpdateCompanionsFrame', function(...) return self:SpellBook_UpdateCompanionsFrame(...) end)

	-- Hook UIErrorsFrame_OnEvent to eat errors
	self.orig_UIErrorsFrame_OnEvent = UIErrorsFrame_OnEvent
	UIErrorsFrame_OnEvent = self.UIErrorsFrame_OnEvent

	if IsLoggedIn() then
		self:SPELLS_CHANGED("OnEnable")
	end

	self:SetupMacro()
	self:UpdateMacroTemplate()
	self:UpdateGroundMountList()
end

function addon.UIErrorsFrame_OnEvent(frame, event, ...)
	if addon.catchMessages and event == 'UI_ERROR_MESSAGE' then
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

function addon:UpdateGroundMountList()
	MOUNTS_BY_TYPE[GROUND] = GROUND_MOUNTS[self.db.profile.restrictGroundMounts and "STRICT" or "ALL"]
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
	self:UpdateGroundMountList()
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
-- Squire2 visible macro
----------------------------------------------

local MACRO_NAME, MACRO_ICON, MACRO_BODY = "Squire2", [[Ability_Mount_RidingHorse]], "/click [button:2] Squire2Button RightButton; Squire2Button"

function addon:SetupMacro(create)
	local index = GetMacroIndexByName(MACRO_NAME)
	if not self:CanDoSecureStuff("SetupMacro") then return index end
	if index == 0 then
		if create then
			return CreateMacro(MACRO_NAME, MACRO_ICON, MACRO_BODY, 0)
		end
	else
		return EditMacro(index, MACRO_NAME, MACRO_ICON, MACRO_BODY)
	end
end

----------------------------------------------
-- Secure button stuff
----------------------------------------------

function addon.ButtonPreClick(_, button)
	if addon.button:CanChangeAttribute() and button ~= "dismount" then
		addon:UpdateAction(button)
	end
	addon.catchMessages = true
end

function addon.ButtonPostClick()
	addon.catchMessages = nil
end

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

function addon:UpdateAction(clickedButton)
	local action = self:BuildAction(clickedButton)
	local macro = gsub(macroTemplate, "%%ACTION%%", action)
	self:SetButtonAction(self.button, "macrotext", macro, "")
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

	if self.UPDATE_SHAPESHIFT_FORMS then
		self:UPDATE_SHAPESHIFT_FORMS(event)
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
	Debug('ChooseMount', mountType, '=>', spellNames[oldestId] or oldestId)
	return oldestId
end

----------------------------------------------
-- Macro building
----------------------------------------------

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

function addon:UpdateFormFlags()
	local travelForms, shapeshiftForms = self.travelForms, self.shapeshiftForms
	self.hasShapeshiftForms = #shapeshiftForms > 0
	self.hasTravelForms = #travelForms > 0
	cancelTravelFormCondition, cancelFormCondition = nil, nil
	if addon.db.profile.travelFormsAsMounts then
		if self.hasTravelForms then
			cancelTravelFormCondition = "form:"..table.concat(travelForms, "/")
		end
		if self.hasShapeshiftForms then
			cancelFormCondition = "form:"..table.concat(shapeshiftForms, "/")
		end
	else
		if self.hasTravelForms or self.hasShapeshiftForms then
			self.hasShapeshiftForms = true
			cancelFormCondition = "form"
		end
	end
end

function addon:UpdateMacroTemplate()
	self:UpdateFormFlags()
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
	if cancelFormCondition then
		AddCancelCommand(pref.ifShapeshifted, "/cancelform", cancelFormCondition, forceDismountCondition)
	end
	AddCancelCommand(pref.ifMounted, "/dismount", "mounted", forceDismountCondition)
	if cancelTravelFormCondition then
		AddCancelCommand(pref.ifMounted, "/cancelform", cancelTravelFormCondition, forceDismountCondition)
	end
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
	if cancelTravelFormCondition or cancelFormCondition then
		dismountMacro = dismountMacro .. "\n/cancelform "..(cancelTravelFormCondition or cancelFormCondition)
	end
	self:SetButtonAction(self.button, 'macrotext', dismountMacro, "-dismount")
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
		if not primary then
			if IsSwimming() then
				primary, secondary = WATER, GROUND
			else
				primary = GROUND
			end
		end
		actionType, actionData = self:ExploreActions(groundOnly, isMoving, IsOutdoors(), primary, secondary, tertiary)
	end
	local mainCmd, mainArg = self:GetMacroCommand(actionType, actionData)
	AddActionCommand(mainCmd, "", mainArg)

	-- Join all
	return tconcat(cmds, "")
end

----------------------------------------------
-- Core logic
----------------------------------------------

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
	--[[
	if not isOutdoors then
		Debug('ExploreActions, trying outdoors')
		return self:ExploreActions(groundOnly, isMoving, true, primary, secondary, tertiary)
	end
	--]]
end

----------------------------------------------
-- Class-specific stuff
----------------------------------------------

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
		flyingForm = knownSpells[40120] and 40120 or 33943
		movingForms[3] = flyingForm

		wipe(t)
		for i, id in ipairs(movingForms) do
			t[spellNames[id]] = true
		end

		wipe(self.shapeshiftForms)
		wipe(self.travelForms)
		for index = 1, GetNumShapeshiftForms() do
			local _, name = GetShapeshiftFormInfo(index)
			if t[name] then
				tinsert(self.travelForms, index)
			else
				tinsert(self.shapeshiftForms, index)
			end
		end

		self:UpdateMacroTemplate()
	end

	function addon:GetAlternateActionForMount(mountType, isMoving, inCombat, isOutdoors)
		if mountType == AIR then
			return 'spell', addon.db.char.mounts[flyingForm] and IsUsableSpell(flyingForm) and knownSpells[flyingForm] -- Any flying form
		elseif mountType == WATER then
			return 'spell', addon.db.char.mounts[1066] and knownSpells[1066] -- Aquatic Form
		elseif mountType == GROUND then
			if isOutdoors and addon.db.char.mounts[783] and knownSpells[783] then
				return 'spell', 783 -- Travel Form
			elseif select(5, GetTalentInfo(2, 1)) > 0 then -- Feral Swiftness
				return 'spell', knownSpells[768] -- Cat Form
			end
		end
	end

elseif playerClass == 'SHAMAN' then

	addon.mountSpells = { 2645 } -- Ghost Wolf

	function addon:UPDATE_SHAPESHIFT_FORMS()
		if knownSpells[2645] and #self.travelForms == 0 then
			tinsert(self.travelForms, 1)
			self:UpdateMacroTemplate()
		end
	end

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

----------------------------------------------
-- Debug commands
----------------------------------------------
--@alpha@

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
