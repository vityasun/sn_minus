-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: серверная конфигурация
-- Состояние модулей и их настройки хранятся в
-- garrysmod/data/slashmoon/config.json и переживают рестарт и смену карты.
--
-- Формат файла:
-- {
--   "version": 1,
--   "modules": {
--     "ping": { "enabled": true, "options": { "cooldown": 30 } }
--   }
-- }
-- ========================================================

SlashMoon.Config = SlashMoon.Config or {}
local Config = SlashMoon.Config

Config.File = "config.json"
Config.Version = 1

--- Загружает конфигурацию с диска.
function Config.Load()
    local data = SlashMoon.Data.ReadJSON(Config.File, nil)
    if not istable(data) then
        data = { version = Config.Version, modules = {} }
    end
    data.modules = istable(data.modules) and data.modules or {}
    Config.Data = data
    return data
end

--- Сохраняет конфигурацию на диск.
function Config.Save()
    Config.Data = Config.Data or Config.Load()
    Config.Data.version = Config.Version
    local ok = SlashMoon.Data.WriteJSON(Config.File, Config.Data, true)
    if ok then
        SlashMoon.Debug("Конфигурация сохранена в data/", SlashMoon.Data.Path(Config.File))
        hook.Run("SlashMoon.ConfigSaved")
    else
        SlashMoon.Warn("Не удалось сохранить конфигурацию!")
    end
    return ok
end

--- Откладывает сохранение (несколько изменений подряд -> одна запись на диск).
function Config.SaveDeferred()
    timer.Create("SlashMoon.Config.Save", 0.25, 1, Config.Save)
end

local function ModuleEntry(id, create)
    Config.Data = Config.Data or Config.Load()
    local entry = Config.Data.modules[id]
    if not entry and create then
        entry = {}
        Config.Data.modules[id] = entry
    end
    return entry
end

--- Возвращает сохраненное состояние модуля (или default, если его нет в файле).
function Config.IsModuleEnabled(id, default)
    local entry = ModuleEntry(id, false)
    if entry and entry.enabled ~= nil then
        return entry.enabled == true
    end
    return default ~= false
end

--- Записывает состояние модуля.
function Config.SetModuleEnabled(id, enabled)
    local entry = ModuleEntry(id, true)
    entry.enabled = enabled == true
    Config.SaveDeferred()
end

--- Возвращает сохраненное значение опции модуля (nil, если не задано).
function Config.GetOption(id, key)
    local entry = ModuleEntry(id, false)
    if entry and istable(entry.options) then
        return entry.options[key]
    end
end

--- Записывает значение опции модуля.
function Config.SetOption(id, key, value)
    local entry = ModuleEntry(id, true)
    entry.options = istable(entry.options) and entry.options or {}
    entry.options[key] = value
    Config.SaveDeferred()
end

-- Если сервер выключается сразу после изменения — дописываем отложенное сохранение
hook.Add("ShutDown", "SlashMoon.Config.Flush", function()
    if timer.Exists("SlashMoon.Config.Save") then
        timer.Remove("SlashMoon.Config.Save")
        Config.Save()
    end
end)

Config.Load()
