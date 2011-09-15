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
L["Action overrides"] = true
L["Any"] = true
L["Bindings"] = true
L["Cancel shapeshift and continue."] = true
L["Cancel shapeshift only."] = true
L["Check this not to dismount/exit vehicle/cancel shapeshift when flying."] = true
L["Check this to let Squire2 use this mount or spell."] = true
L["Combat action"] = true
L["Create the Squire2 macro."] = true
L["Define the action to use in combat instead of anything Squire2 might try."] = true
L["Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available."] = true
L["Dismount and continue."] = true
L["Dismount modifier"] = true
L["Dismount only."] = true
L["Dismount"] = true
L["Do nothing."] = true
L["Drag and drop an action or right-click to clear."] = true
L["Flying mounts can be used in non-fyling area. Check this box to ignore them and use strictly ground mounts."] = true
L["Ground modifier"] = true
L["In a vehicle:"] = true
L["Infinite recursion is bad !"] = true
L["Leave the vehicle."] = true
L["Macro"] = true
L["Moving action"] = true
L["None"] = true
L["On a mount:"] = true
L["Right mouse button"] = true
L["Secure flight"] = true
L["Select a binding to dismount."] = true
L["Select a binding to use Squire2 without a macro."] = true
L["Select a modifier to enforce dismounting, even mid-air."] = true
L["Select a modifier to enforce the use of a ground mount, even in a flyable area."] = true
L["Squire2"] = true
L["Strict ground mounts"] = true
L["Toggle spellbook"] = true
L["Travel forms as mount"] = true
L["Treat travel forms as if they were mounts with regard to dismount settings."] = true
L["Use %s"] = true
L["When already in a vehicle, what should Squire2 do ?"] = true
L["When already on a mount, what should Squire2 do ?"] = true
L["When shapeshifted, what should Squire2 do ?"] = true
L["When shapeshifted:"] = true

-- Squire2.lua
L["Use Squire2"] = true


------------------------ frFR ------------------------
local locale = GetLocale()
if locale == 'frFR' then
L["Action overrides"] = "Surchage des actions"
L["Any"] = "N'importe lequel"
L["Bindings"] = "Raccourcis"
L["Cancel shapeshift and continue."] = "Démorphe et continue."
L["Cancel shapeshift only."] = "Démorphe uniquement."
L["Check this not to dismount/exit vehicle/cancel shapeshift when flying."] = "Cochez ceci pour ne pas démonter/sortir du véhicule/annuler une transformation en volant."
L["Check this to let Squire2 use this mount or spell."] = "Cochez ceci pour que Squire2 utilise cette monture (ou ce sort)."
L["Combat action"] = "Action en combat"
L["Create the Squire2 macro."] = "Crée la macro Squire2."
L["Define the action to use in combat instead of anything Squire2 might try."] = "Définit l'action à utiliser en combat."
L["Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available."] = "Définissez l'action à entreprendre lors de mouvements au lieu des actions par défaut. Cela sera aussi utilisé en combat par défaut."
L["Dismount"] = "Démonter"
L["Dismount and continue."] = "Démonte et continue."
L["Dismount modifier"] = "Modificateur pour démonter"
L["Dismount only."] = "Démonte uniquement."
L["Do nothing."] = "Ne fais rien."
L["Drag and drop an action or right-click to clear."] = "Tirer et déposer une action ou clic-droit pour supprimer."
L["Flying mounts can be used in non-fyling area. Check this box to ignore them and use strictly ground mounts."] = "Les montures volantes peuvent être utilisés dans des zones non-volantes. Cochez cette case pour les ignorer et utiliser des montures strictement terrestres."
L["Ground modifier"] = "Modificateur \"monture au sol\""
L["In a vehicle:"] = "Dans un véhicule :"
L["Infinite recursion is bad !"] = "La récursion infinie, c'est le mal !"
L["Leave the vehicle."] = "Quitte le véhicule."
L["Macro"] = "Macro"
L["Moving action"] = "Action en mouvement"
L["None"] = "Aucun"
L["On a mount:"] = "Sur une monture :"
L["Right mouse button"] = "Bouton droit de la souris"
L["Secure flight"] = "Vol sécurisé."
L["Select a binding to dismount."] = "Choisissez un raccourci pour démonter."
L["Select a binding to use Squire2 without a macro."] = "Choisissez un raccourci pour utiliser Squire2 sans macro."
L["Select a modifier to enforce dismounting, even mid-air."] = "Choisissez une touche pour forcer à descendre de monture, même en plein vol."
L["Select a modifier to enforce the use of a ground mount, even in a flyable area."] = "Choisissez une touche de mofification pour force l'utilisation d'une monture au sol, même dans les zones volantes."
L["Squire2"] = "Squire2"
L["Strict ground mounts"] = "Montures terrestres strictes"
L["Toggle spellbook"] = "Livre de sorts"
L["Travel forms as mount"] = "Formes de voyage = monture"
L["Treat travel forms as if they were mounts with regard to dismount settings."] = "Traite les formes de voyage comme si elles étaient des montures pour les options de démonte."
L["Use %s"] = "Utiliser %s"
L["Use Squire2"] = "Utiliser Squire2"
L["When already in a vehicle, what should Squire2 do ?"] = "Lorsque vous êtes dans un véhicule, que dois faire Squire2 ?"
L["When already on a mount, what should Squire2 do ?"] = "Lorsque vous êtes déjà sur une monture, que dois faire Squire2 ?"
L["When shapeshifted, what should Squire2 do ?"] = "Lorsque vous êtes métamorphosé, que dois faire Squire2 ?"
L["When shapeshifted:"] = "Métamorphosé :"

------------------------ deDE ------------------------
elseif locale == 'deDE' then
L["Action overrides"] = "Überschreibende Aktionen"
L["Any"] = "Beliebig"
L["Bindings"] = "Tastenbelegungen"
L["Cancel shapeshift and continue."] = "Gestalt verlassen und weitermachen."
L["Cancel shapeshift only."] = "Nur Gestalt verlassen."
L["Check this not to dismount/exit vehicle/cancel shapeshift when flying."] = "Verhindert Absitzen/Fahrzeug verlassen/Gestaltwandel während des Fliegens."
L["Check this to let Squire2 use this mount or spell."] = "Anhacken, um Squire2 dieses Reittier benutzen zu lassen."
L["Combat action"] = "Aktion im Kampf"
L["Create the Squire2 macro."] = "Erzeugt das Squire2 Makro."
L["Define the action to use in combat instead of anything Squire2 might try."] = "Bestimmt die Aktion, die im Kampf verwendet werden soll."
L["Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available."] = "Bestimmt die Aktion, die während einer Bewegung verwendet werden soll. Es wird versucht, diese auch im Kampf anzuwenden, falls nichts anderes verfügbar ist."
L["Dismount"] = "Absitzen"
L["Dismount and continue."] = "Absitzen und weitermachen."
L["Dismount modifier"] = "Absitzen Modifikator"
L["Dismount only."] = "Nur Absitzen."
L["Do nothing."] = "Nichts machen."
L["Drag and drop an action or right-click to clear."] = "Drag 'n Drop bestimmt eine Aktion, Rechts-Klick löscht diese."
L["Ground modifier"] = "Bodenmodifikator"
L["In a vehicle:"] = "In einem Fahrzeug:"
L["Infinite recursion is bad !"] = "Unendliche Rekursion ist schlecht!"
L["Leave the vehicle."] = "Das Fahrzeug verlassen."
L["Macro"] = "Makro"
L["Moving action"] = "Aktion während Bewegung"
L["None"] = "Nichts"
L["On a mount:"] = "Auf einem Reittier:"
L["Right mouse button"] = "Rechts-Klick"
L["Secure flight"] = "Sicherer Flug"
L["Select a binding to dismount."] = "Wählt eine Tastenbelegung für das Absitzen aus."
L["Select a binding to use Squire2 without a macro."] = "Wählt eine Tastenbelegung für Squire2 ohne Makrobenutzung aus."
L["Select a modifier to enforce dismounting, even mid-air."] = "Wählt einen Modifikator aus, um das Absitzen (auch während des Fliegens) zu erzwingen."
L["Select a modifier to enforce the use of a ground mount, even in a flyable area."] = "Wählt einen Modifikator aus, der die Benutzung von Bodenreittieren, auch in Flugzonen, erzwingt."
L["Squire2"] = "Squire2"
L["Toggle spellbook"] = "Zauberbuch"
L["Travel forms as mount"] = "Reise-/Wasser-/Fluggestalt wie Reittiere"
L["Treat travel forms as if they were mounts with regard to dismount settings."] = "Behandelt die Reise-/Wasser-/Fluggestalt im Bezug auf das Absitzen wie als ob sie Reittiere wären."
L["Use %s"] = "%s benutzen"
L["Use Squire2"] = "Squire2 benutzen"
L["When already in a vehicle, what should Squire2 do ?"] = "Was soll Squire2 tun, wenn du bereits in einem Fahrzeug bist?"
L["When already on a mount, what should Squire2 do ?"] = "Was soll Squire2 tun, wenn du bereits auf einem Reittier sitzt?"
L["When shapeshifted, what should Squire2 do ?"] = "Was soll Squire2 tun, wenn du bereits die Gestalt gewechselt hast?"
L["When shapeshifted:"] = "Wenn Gestalt gewechselt:"

------------------------ esMX ------------------------
-- no translation

------------------------ ruRU ------------------------
elseif locale == 'ruRU' then
L["Bindings"] = "Бинды" -- Needs review
L["Combat action"] = "Действие в бою" -- Needs review
L["Create the Squire2 macro."] = "Создать макрос Squire2" -- Needs review
L["Dismount"] = "Слезть" -- Needs review
L["Dismount and continue."] = "Слезть и продолжить." -- Needs review
L["Dismount only."] = "Только слезть." -- Needs review
L["Do nothing."] = "Ничего не делать." -- Needs review
L["In a vehicle:"] = "В машине:" -- Needs review
L["Leave the vehicle."] = "Оставить машину." -- Needs review
L["Macro"] = "Макрос" -- Needs review
L["None"] = "Ничего" -- Needs review
L["On a mount:"] = "На маунте:" -- Needs review
L["Right mouse button"] = "Правая кнопка мыши" -- Needs review
L["Squire2"] = "Squire2" -- Needs review
L["Use %s"] = "Использовать %s" -- Needs review
L["Use Squire2"] = "Использовать Squire2" -- Needs review
L["When already in a vehicle, what should Squire2 do ?"] = "Когда вы уже на машине, что должен делать Squire2?" -- Needs review
L["When already on a mount, what should Squire2 do ?"] = "Когда вы уже на маунте, что должен делать Squire2?" -- Needs review

------------------------ esES ------------------------
-- no translation

------------------------ zhTW ------------------------
elseif locale == 'zhTW' then
L["Action overrides"] = "無效動作"
L["Any"] = "任何"
L["Bindings"] = "按鍵綁定"
L["Cancel shapeshift and continue."] = "取消變形並繼續"
L["Cancel shapeshift only."] = "只取消變形"
L["Check this not to dismount/exit vehicle/cancel shapeshift when flying."] = "當飛行時不取消坐騎/離開載具/取消變形"
L["Check this to let Squire2 use this mount or spell."] = "勾選使用此坐騎或法術"
L["Combat action"] = "戰鬥中動作"
L["Create the Squire2 macro."] = "產生Squire2巨集"
L["Define the action to use in combat instead of anything Squire2 might try."] = "設定戰鬥中所使用的動作以取代任何Squire2會嘗試使用的動作"
L["Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available."] = "設定移動中所使用的動作以取代任何Squire2會嘗試使用的動作.如果戰鬥中無其他可用選擇將會使用此設定."
L["Dismount"] = "離開坐騎"
L["Dismount and continue."] = "下坐騎並繼續"
L["Dismount modifier"] = "離開坐騎組合鍵"
L["Dismount only."] = "只下坐騎"
L["Do nothing."] = "什麼都不做"
L["Drag and drop an action or right-click to clear."] = "拖曳設置一個動作或右鍵清除"
L["Ground modifier"] = "地面組合鍵"
L["In a vehicle:"] = "在載具上:"
L["Infinite recursion is bad !"] = "Infinite recursion is bad !" -- Needs review
L["Leave the vehicle."] = "離開載具"
L["Macro"] = "巨集"
L["Moving action"] = "移動時動作"
L["None"] = "無"
L["On a mount:"] = "坐騎上:"
L["Right mouse button"] = "滑鼠右鍵"
L["Secure flight"] = "安全飛行"
L["Select a binding to dismount."] = "選擇一個按鍵設置來離開坐騎"
L["Select a binding to use Squire2 without a macro."] = "選擇一個按鍵設置來使用Squire2而不使用巨集"
L["Select a modifier to enforce dismounting, even mid-air."] = "選擇一個組合鍵以強制離開坐騎,即使是在空中."
L["Select a modifier to enforce the use of a ground mount, even in a flyable area."] = "選擇一個組合鍵以強制使用地面坐騎,即使是在可飛行區域"
L["Squire2"] = "Squire2"
L["Toggle spellbook"] = "切換法術書"
L["Travel forms as mount"] = "將旅行型態視做坐騎"
L["Treat travel forms as if they were mounts with regard to dismount settings."] = "將旅行型態視作為坐騎,並使用相同離開坐騎設定"
L["Use %s"] = "使用%s"
L["Use Squire2"] = "使用Squire2"
L["When already in a vehicle, what should Squire2 do ?"] = "當已經在載具上時,Squire2應該如何?"
L["When already on a mount, what should Squire2 do ?"] = "當已經在坐騎上時,Squire2應該如何?"
L["When shapeshifted, what should Squire2 do ?"] = "當變形中,Squire2應該如何?"
L["When shapeshifted:"] = "當變形中:"

------------------------ zhCN ------------------------
elseif locale == 'zhCN' then
L["Action overrides"] = "无效动作"
L["Any"] = "任何"
L["Bindings"] = "按键绑定"
L["Check this not to dismount/exit vehicle/cancel shapeshift when flying."] = "当飞行时不取消坐骑/离开载具/取消变形"
L["Check this to let Squire2 use this mount or spell."] = "勾选使用此坐骑或法术"
L["Combat action"] = "战斗中动作"
L["Create the Squire2 macro."] = "产生Squire2宏"
L["Define the action to use in combat instead of anything Squire2 might try."] = "设定战斗中所使用的动作以取代任何Squire2会尝试使用的动作"
L["Define the action to use while moving instead of anything Squire2 might try. It will also be used in combat if nothing else is available."] = "设定移动中所使用的动作以取代任何Squire2会尝试使用的动作.如果战斗中无其它可用选择将会使用此设定."
L["Dismount"] = "离开坐骑"
L["Dismount modifier"] = "离开坐骑组合键"
L["Drag and drop an action or right-click to clear."] = "拖曳设置一个动作或右键清除"
L["Ground modifier"] = "地面组合键"
L["Infinite recursion is bad !"] = "Infinite recursion is bad !" -- Needs review
L["Macro"] = "宏"
L["Moving action"] = "移动时动作"
L["None"] = "无"
L["Right mouse button"] = "鼠标右键"
L["Select a binding to dismount."] = "选择一个按键设置来离开坐骑"
L["Select a binding to use Squire2 without a macro."] = "选择一个按键设置来使用Squire2而不使用宏"
L["Select a modifier to enforce dismounting, even mid-air."] = "选择一个组合键以强制离开坐骑,即使是在空中."
L["Squire2"] = "Squire2"
L["Toggle spellbook"] = "切换法术书"
L["Use %s"] = "使用%s"
L["Use Squire2"] = "使用Squire2"

------------------------ koKR ------------------------
-- no translation
end

-- @noloc]]

-- Replace remaining true values by their key
for k,v in pairs(L) do if v == true then L[k] = k end end
