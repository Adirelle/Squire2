--[[
Squire2 - One-click smart mounting.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local L = setmetatable({}, {
	__index = function(self, key)
		if key ~= nil then
			--@debug@
			addon.Debug('Missing locale', tostring(key))
			--@end-debug@
			rawset(self, key, tostring(key))
		end
		return tostring(key)
	end,
})
addon.L = L

--------------------------------------------------------------------------------
-- Locales from localization system
--------------------------------------------------------------------------------

-- %Localization: squire2
-- THE END OF THE FILE IS UPDATED BY A SCRIPT
-- ANY CHANGE BELOW THESES LINES WILL BE LOST
-- CHANGES SHOULD BE MADE USING http://www.wowace.com/addons/squire2/localization/

-- @noloc[[

------------------------ enUS ------------------------


-- Config.lua
L["... but not when flying"] = true
L["Action overrides"] = true
L["Any"] = true
L["Bindings"] = true
L["Check this not to dismount/exit vehicle/cancel shapeshift when flying."] = true
L["Check this to dismount, exit vehicle or cancel shapeshift resp. when on a mount, in a vehicle or shapeshifted."] = true
L["Check this to let Squire2 use this mount or spell."] = true
L["Combat action"] = true
L["Create the Squire2 macro."] = true
L["Define the action to use in combat instead of anything Squire2 might try."] = true
L["Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available."] = true
L["Dismount modifier"] = true
L["Dismount"] = true
L["Dismount/exit vehicle/cancel shapeshift"] = true
L["Drag and drop an action or right-click to clear."] = true
L["Ground modifier"] = true
L["Infinite recursion is bad !"] = true
L["Macro"] = true
L["Moving action"] = true
L["None"] = true
L["Right mouse button"] = true
L["Select a binding to dismount."] = true
L["Select a binding to use Squire2 without a macro."] = true
L["Select a modifier to enforce dismounting, even mid-air."] = true
L["Select a modifier to enforce the use of a ground mount."] = true
L["Squire2"] = true
L["Toggle spellbook"] = true
L["Use %s"] = true

-- Squire2.lua
L["Use Squire2"] = true


------------------------ frFR ------------------------
local locale = GetLocale()
if locale == 'frFR' then
L["... but not when flying"] = "... mais pas en vol"
L["Action overrides"] = "Surchage des actions"
L["Any"] = "N'importe lequel"
L["Bindings"] = "Raccourcis"
L["Check this not to dismount/exit vehicle/cancel shapeshift when flying."] = "Cochez ceci pour ne pas démonter/sortir du véhicule/annuler une transformation en volant."
L["Check this to dismount, exit vehicle or cancel shapeshift resp. when on a mount, in a vehicle or shapeshifted."] = "Cochez ceci pour démonter, sortir du véhicule ou annuler une transformation plutôt que de tenter une autre action."
L["Check this to let Squire2 use this mount or spell."] = "Cochez ceci pour que Squire2 utilise cette monture (ou ce sort)."
L["Combat action"] = "Action en combat"
L["Create the Squire2 macro."] = "Crée la macro Squire2."
L["Define the action to use in combat instead of anything Squire2 might try."] = "Définit l'action à utiliser en combat."
L["Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available."] = "Définissez l'action à entreprendre lors de mouvements au lieu des actions par défaut. Cela sera aussi utilisé en combat par défaut."
L["Dismount"] = "Démonter"
L["Dismount modifier"] = "Modificateur pour démonter"
L["Dismount/exit vehicle/cancel shapeshift"] = "Démonter/sortir du véhicule/annuler une transformation"
L["Drag and drop an action or right-click to clear."] = "Tirer et déposer une action ou clic-droit pour supprimer."
L["Ground modifier"] = "Modificateur \"monture au sol\""
L["Infinite recursion is bad !"] = "La récursion infinie, c'est le mal !"
L["Macro"] = "Macro"
L["Moving action"] = "Action en mouvement"
L["None"] = "Aucun"
L["Right mouse button"] = "Bouton droit de la souris"
L["Select a binding to dismount."] = "Choisissez un raccourci pour démonter."
L["Select a binding to use Squire2 without a macro."] = "Choisissez un raccourci pour utiliser Squire2 sans macro."
L["Select a modifier to enforce dismounting, even mid-air."] = "Choisissez une touche pour forcer à descendre de monture, même en plein vol."
L["Select a modifier to enforce the use of a ground mount."] = "Choisissez un modification pour forcer l'utilisation d'une monture au sol."
L["Squire2"] = "Squire2"
L["Toggle spellbook"] = "Livre de sorts"
L["Use %s"] = "Utiliser %s"
L["Use Squire2"] = "Utiliser Squire2"

------------------------ deDE ------------------------
elseif locale == 'deDE' then
L["... but not when flying"] = "... aber nicht während des Fliegens"
L["Action overrides"] = "Überschreibende Aktionen"
L["Any"] = "Beliebig"
L["Bindings"] = "Tastenbelegungen"
L["Check this not to dismount/exit vehicle/cancel shapeshift when flying."] = "Verhindert das Absitzen/Fahrzeug verlassen/Formwechseln während des Fliegens."
L["Check this to dismount, exit vehicle or cancel shapeshift resp. when on a mount, in a vehicle or shapeshifted."] = "Absitzen, Fahrzeug verlassen oder Form wechseln respektive des jeweiligen Zustands."
L["Check this to let Squire2 use this mount or spell."] = "Anhacken lässt Squire2 dieses Reittier benutzen."
L["Combat action"] = "Aktion im Kampf"
L["Create the Squire2 macro."] = "Erzeugt das Squire2 Makro."
L["Define the action to use in combat instead of anything Squire2 might try."] = "Bestimmt die Aktion, die im Kampf verwendet werden soll."
L["Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available."] = "Bestimmt die Aktion, die während einer Bewegung verwendet werden soll. Es wird versucht, diese auch im Kampf anzuwenden, falls nichts anderes verfügbar ist."
L["Dismount"] = "Absitzen"
L["Dismount modifier"] = "Absitzen Modifikator"
L["Dismount/exit vehicle/cancel shapeshift"] = "Absitzen/Fahrzeug verlassen/Gestaltwandeln"
L["Drag and drop an action or right-click to clear."] = "Drag 'n Drop bestimmt eine Aktion, Rechts-Klick löscht diese."
L["Ground modifier"] = "Bodenmodifikator"
L["Infinite recursion is bad !"] = "Unendliche Rekursion ist schlecht!"
L["Macro"] = "Makro"
L["Moving action"] = "Aktion während Bewegung"
L["None"] = "Nichts"
L["Right mouse button"] = "Rechts-Klick"
L["Select a binding to dismount."] = "Wählt eine Tastenbelegung für das Absitzen aus."
L["Select a binding to use Squire2 without a macro."] = "Wählt eine Tastenbelegung für Squire2 ohne Makrobenutzung aus."
L["Select a modifier to enforce dismounting, even mid-air."] = "Wählt einen Modifikator aus, um das Absitzen (auch während des Fliegens) zu erzwingen."
L["Select a modifier to enforce the use of a ground mount."] = "Wählt einen Modifikator aus, um die Benutzung von Bodenreittieren zu erzwingen."
L["Squire2"] = "Squire2"
L["Toggle spellbook"] = "Zauberbuch"
L["Use %s"] = "%s benutzen"
L["Use Squire2"] = "Squire2 benutzen"

------------------------ esMX ------------------------
-- no translation

------------------------ ruRU ------------------------
-- no translation

------------------------ esES ------------------------
-- no translation

------------------------ zhTW ------------------------
elseif locale == 'zhTW' then
L["... but not when flying"] = "...除了飛行時"
L["Action overrides"] = "無效動作"
L["Any"] = "任何"
L["Bindings"] = "按鍵綁定"
L["Check this not to dismount/exit vehicle/cancel shapeshift when flying."] = "當飛行時不取消坐騎/離開載具/取消變形"
L["Check this to dismount, exit vehicle or cancel shapeshift resp. when on a mount, in a vehicle or shapeshifted."] = "勾選以離開現有坐騎,載具或取消變形"
L["Check this to let Squire2 use this mount or spell."] = "勾選使用此坐騎或法術"
L["Combat action"] = "戰鬥中動作"
L["Create the Squire2 macro."] = "產生Squire2巨集"
L["Define the action to use in combat instead of anything Squire2 might try."] = "設定戰鬥中所使用的動作以取代任何Squire2會嘗試使用的動作"
L["Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available."] = "設定移動中所使用的動作以取代任何Squire2會嘗試使用的動作.如果戰鬥中無其他可用選擇將會使用此設定."
L["Dismount"] = "離開坐騎"
L["Dismount modifier"] = "離開坐騎組合鍵"
L["Dismount/exit vehicle/cancel shapeshift"] = "離開坐騎/離開載具/取消變形"
L["Drag and drop an action or right-click to clear."] = "拖曳設置一個動作或右鍵清除"
L["Ground modifier"] = "地面組合鍵"
L["Infinite recursion is bad !"] = "Infinite recursion is bad !"
L["Macro"] = "巨集"
L["Moving action"] = "移動時動作"
L["None"] = "無"
L["Right mouse button"] = "滑鼠右鍵"
L["Select a binding to dismount."] = "選擇一個按鍵設置來離開坐騎"
L["Select a binding to use Squire2 without a macro."] = "選擇一個按鍵設置來使用Squire2而不使用巨集"
L["Select a modifier to enforce dismounting, even mid-air."] = "選擇一個組合鍵以強制離開坐騎,即使是在空中."
L["Select a modifier to enforce the use of a ground mount."] = "選擇一個組合鍵來強制使用地面坐騎"
L["Squire2"] = "Squire2"
L["Toggle spellbook"] = "切換法術書"
L["Use %s"] = "使用%s"
L["Use Squire2"] = "使用Squire2"

------------------------ zhCN ------------------------
-- no translation

------------------------ koKR ------------------------
-- no translation
end

-- @noloc]]

-- Replace remaining true values by their key
for k,v in pairs(L) do if v == true then L[k] = k end end
