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
L["Select a modifier to enforce the use of a ground mount."] = "Choisissez un modification pour forcer l'utilisation d'une monture au sol."
L["Squire2"] = "Squire2"
L["Toggle spellbook"] = "Livre de sorts"
L["Use %s"] = "Utiliser %s"
L["Use Squire2"] = "Utiliser Squire2"

------------------------ deDE ------------------------
-- no translation

------------------------ esMX ------------------------
-- no translation

------------------------ ruRU ------------------------
-- no translation

------------------------ esES ------------------------
-- no translation

------------------------ zhTW ------------------------
-- no translation

------------------------ zhCN ------------------------
-- no translation

------------------------ koKR ------------------------
-- no translation
end

-- @noloc]]

-- Replace remaining true values by their key
for k,v in pairs(L) do if v == true then L[k] = k end end
