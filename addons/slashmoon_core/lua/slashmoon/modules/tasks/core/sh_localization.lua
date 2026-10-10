-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Shared Localization Wrapper
-- Решает проблему: language.GetPhrase() НЕ работает на сервере
-- Сервер напрямую парсит .properties файлы
-- ========================================================
SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks._LangCache = SlashMoon.Tasks._LangCache or {}

if SERVER then
    util.AddNetworkString("SN_LocalizedMessage")
end

-- ── Парсер .properties ────────────────────────────────────────────────
-- Формат: key=value  (строки с # или ! в начале — комментарии)
local function ParseProperties(text)
    local result = {}
    if not text or text == "" then return result end

    for line in string.gmatch(text, "[^\r\n]+") do
        line = string.Trim(line)
        if line == "" then continue end
        if string.StartWith(line, "#") or string.StartWith(line, "!") then continue end

        local eqPos = string.find(line, "=", 1, true)
        if not eqPos then continue end

        local key   = string.Trim(string.sub(line, 1, eqPos - 1))
        local value = string.Trim(string.sub(line, eqPos + 1))
        result[key] = value
    end

    return result
end

local LANG_DIRS = {
    "addons/sn_tasks/resource/localization",
    "addons/test/sn_tasks/resource/localization",
}

local function ReadLanguage(langCode)
    for _, dir in ipairs(LANG_DIRS) do
        local text = file.Read(dir .. "/" .. langCode .. "/sn_tasks.properties", "GAME")
        if text then return text end
    end
end

function SlashMoon.Tasks.LoadPhrases()
    local languages = { "en" }
    if CLIENT then
        local cv = GetConVar("gmod_language")
        local preferred = cv and string.lower(cv:GetString()) or "en"
        if preferred ~= "en" then table.insert(languages, preferred) end
    end

    local merged = {}
    for _, langCode in ipairs(languages) do
        local text = ReadLanguage(langCode)
        for key, value in pairs(ParseProperties(text)) do merged[key] = value end
    end

    SlashMoon.Tasks._LangCache = merged
    if CLIENT then
        for key, value in pairs(merged) do language.Add(key, value) end
    end
end

if CLIENT then
    MODULE:Receive("SN_LocalizedMessage", function()
        local messageType = net.ReadUInt(2)
        local key = net.ReadString()
        local count = net.ReadUInt(4)
        local args = {}
        for i = 1, count do
            args[i] = net.ReadString()
            if string.StartWith(args[i], "sn.") then
                args[i] = SlashMoon.Tasks.Lang(args[i])
            end
        end

        local text = SlashMoon.Tasks.Lang(key, unpack(args))
        if messageType == 1 then
            chat.AddText(color_white, text)
        elseif messageType == 2 then
            notification.AddLegacy(text, NOTIFY_GENERIC, 4)
        else
            chat.AddText(color_white, text)
        end
    end)
else
    function SlashMoon.Tasks.SendLocalized(ply, messageType, key, ...)
        if not IsValid(ply) or not key then return end
        local args = { ... }
        net.Start("SN_LocalizedMessage")
            net.WriteUInt(messageType or 1, 2)
            net.WriteString(key)
            net.WriteUInt(math.min(#args, 15), 4)
            for i = 1, math.min(#args, 15) do
                net.WriteString(string.sub(tostring(args[i]), 1, 256))
            end
        net.Send(ply)
    end

    function SlashMoon.Tasks.SendLocalizedChat(ply, key, ...)
        SlashMoon.Tasks.SendLocalized(ply, 1, key, ...)
    end

    function SlashMoon.Tasks.SendLocalizedNotification(ply, key, ...)
        SlashMoon.Tasks.SendLocalized(ply, 2, key, ...)
    end
end

SlashMoon.Tasks.LoadPhrases()

-- ── SlashMoon.Tasks.Lang(key, ...) — Основная функция локализации ──────────
-- Работает на ОБЕИХ реалмах:
--   CLIENT: language.GetPhrase() (нативная GMod локализация)
--   SERVER: lookup в SlashMoon.Tasks._LangCache (загружено из .properties)
-- Формат аргументов: {1}, {2} и т.д.
function SlashMoon.Tasks.Lang(key, ...)
    if not key or key == "" then return key or "" end

    local phrase

    if CLIENT then
        -- На клиенте — нативная GMod система
        phrase = language.GetPhrase(key)
        -- Если вернулся сам ключ — фраза не найдена
        if phrase == key then
            -- Пробуем кеш (фоллбэк)
            phrase = SlashMoon.Tasks._LangCache[key] or key
        end
    else
        -- На сервере — lookup в кеше
        phrase = SlashMoon.Tasks._LangCache[key] or key
    end

    -- Подстановка аргументов {1}, {2}, ...
    local args = { ... }
    if #args > 0 then
        for i, arg in ipairs(args) do
            phrase = string.gsub(phrase, "{" .. i .. "}", tostring(arg))
        end
    end

    return phrase
end

-- ── Утилита: Получить локализованное название предмета ───────────────
-- Заменяет прямые вызовы language.GetPhrase в sh_items.lua
function SlashMoon.Tasks.GetItemName(rawClass)
    if not rawClass or rawClass == "" then
        return SlashMoon.Tasks.Lang("sn.inv.empty")
    end

    local parts = string.Split(rawClass, ":")
    local baseClass = parts[1]
    local meta = parts[2]

    local baseData = SlashMoon.Tasks.Items and SlashMoon.Tasks.Items[baseClass]
    if baseData then
        -- Пробуем nameKey, потом name (фоллбэк)
        if baseData.nameKey then
            local localized = SlashMoon.Tasks.Lang(baseData.nameKey)
            if localized ~= baseData.nameKey then return localized end
        end
        return baseData.name or baseClass
    end

    -- Нет в базе — пробуем локализацию по class name
    return SlashMoon.Tasks.Lang(baseClass)
end

if CLIENT then
    cvars.AddChangeCallback("gmod_language", function()
        timer.Simple(0, function()
            SlashMoon.Tasks.LoadPhrases()
            hook.Run("SN_Tasks_LanguageChanged")
        end)
    end, "SN_Tasks_LanguageChanged")
end
