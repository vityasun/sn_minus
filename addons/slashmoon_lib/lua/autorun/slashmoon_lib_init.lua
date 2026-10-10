-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: точка входа библиотеки
-- Самостоятельный фреймворк для разработчиков Garry's Mod:
-- ядро, UI-библиотека, слой админ-систем, реестр модулей и панель конфигурации.
-- Модули из любых аддонов (lua/slashmoon/modules/<id>/) подключаются автоматически.
-- ========================================================

SlashMoon = SlashMoon or {}

if SERVER then
    AddCSLuaFile("slashmoon/sh_loader.lua")
end

include("slashmoon/sh_loader.lua")
