-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: админ-панель конфигурации (сервер)
-- Права:
--   slashmoon_menu   — открыть панель (просмотр)
--   slashmoon_config — включать/выключать модули и менять их настройки
-- ========================================================

SlashMoon.AdminMenu = SlashMoon.AdminMenu or {}
local AdminMenu = SlashMoon.AdminMenu
local Modules = SlashMoon.Modules

util.AddNetworkString("SlashMoon.AdminMenu.Request")
util.AddNetworkString("SlashMoon.AdminMenu.Data")
util.AddNetworkString("SlashMoon.AdminMenu.Apply")

local function SerializeValue(def, value)
    if def.type == "color" and IsColor(value) then
        return { r = value.r, g = value.g, b = value.b, a = value.a }
    end
    return value
end

--- Собирает данные для панели.
function AdminMenu.BuildData(ply)
    local list = {}
    for _, mod in ipairs(Modules.GetSorted()) do
        local options = {}
        for _, def in ipairs(mod.options) do
            options[#options + 1] = {
                key = def.key,
                type = def.type,
                name = def.name or def.key,
                description = def.description,
                min = def.min, max = def.max, decimals = def.decimals,
                default = SerializeValue(def, def.default),
                value = SerializeValue(def, mod:GetOption(def.key)),
            }
        end

        list[#list + 1] = {
            id = mod.id,
            name = mod.name,
            description = mod.description,
            category = mod.category,
            author = mod.author,
            enabled = mod.enabled,
            default = mod.default,
            entities = mod.entities,
            weapons = mod.weapons,
            options = options,
        }
    end

    return {
        version = SlashMoon.Version,
        adminSystem = SlashMoon.Admin.GetSystem(),
        detected = SlashMoon.Compat.GetDetected(),
        configPath = "data/" .. SlashMoon.Data.Path(SlashMoon.Config.File),
        canEdit = SlashMoon.Admin.HasPermission(ply, "slashmoon_config"),
        modules = list,
    }
end

--- Отправляет данные панели игроку.
-- @param open boolean открыть панель (false — только обновить, если она открыта)
-- @param notice string|nil сообщение для уведомления
function AdminMenu.Send(ply, open, notice)
    local data = AdminMenu.BuildData(ply)
    data.open = open == true
    data.notice = notice

    net.Start("SlashMoon.AdminMenu.Data")
    SlashMoon.JSON.NetWrite(data)
    net.Send(ply)
end

--- Открывает панель игроку (с проверкой прав).
function AdminMenu.Open(ply)
    if not IsValid(ply) then return end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_menu") then
        SlashMoon.Notify(ply, Color(255, 80, 80), "Недостаточно прав для открытия панели SlashMoon.")
        return
    end
    AdminMenu.Send(ply, true)
end

--- Обновляет панель у всех, кто может ее открыть.
function AdminMenu.Broadcast(notice, except)
    for _, ply in ipairs(SlashMoon.Admin.GetPlayersWithPermission("slashmoon_menu")) do
        if ply ~= except then AdminMenu.Send(ply, false, notice) end
    end
end

net.Receive("SlashMoon.AdminMenu.Request", function(_, ply)
    if not SlashMoon.Security.CheckRateLimit(ply, "slashmoon_adminmenu_open", 1) then return end
    AdminMenu.Open(ply)
end)

-- Пакет изменений: { modules = { [id] = bool }, options = { [id] = { [key] = value } } }
net.Receive("SlashMoon.AdminMenu.Apply", function(len, ply)
    if len > 512 * 1024 then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "slashmoon_adminmenu_apply", 0.2) then return end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_config") then
        SlashMoon.Notify(ply, Color(255, 80, 80), "Недостаточно прав для изменения настроек SlashMoon.")
        return
    end

    local changes = SlashMoon.JSON.NetRead({})
    local changed = 0

    for id, opts in pairs(istable(changes.options) and changes.options or {}) do
        if isstring(id) and istable(opts) then
            for key, value in pairs(opts) do
                if Modules.SetOption(id, key, value) then changed = changed + 1 end
            end
        end
    end

    for id, enabled in pairs(istable(changes.modules) and changes.modules or {}) do
        if isstring(id) and Modules.SetEnabled(id, enabled == true) then
            changed = changed + 1
        end
    end

    if changed > 0 then
        SlashMoon.Log(ply:Nick(), " (", ply:SteamID(), ") изменил настроек: ", changed)
        hook.Run("SlashMoon.ConfigChanged", ply, changes)
    end

    AdminMenu.Send(ply, false, changed > 0 and ("Сохранено изменений: " .. changed) or "Изменений нет")
    AdminMenu.Broadcast(nil, ply)
end)

-- Управление модулями из консоли сервера
concommand.Add("slashmoon_module", function(ply, _, args)
    if IsValid(ply) and not SlashMoon.Admin.HasPermission(ply, "slashmoon_config") then return end

    local function Reply(msg)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else SlashMoon.Log(msg) end
    end

    local id, state = args[1], args[2]
    if not id then
        for _, mod in ipairs(Modules.GetSorted()) do
            Reply(string.format("%-20s %-4s %s", mod.id, mod.enabled and "ON" or "OFF", mod.name))
        end
        Reply("Использование: slashmoon_module <id> <0|1>")
        return
    end

    if not Modules.List[id] or not Modules.List[id].registered then
        Reply("Модуль не найден: " .. id)
        return
    end

    local enabled = tobool(state)
    if state == nil then enabled = not Modules.IsEnabled(id) end
    Modules.SetEnabled(id, enabled)
    Reply("Модуль " .. id .. ": " .. (Modules.IsEnabled(id) and "включен" or "отключен"))
    AdminMenu.Broadcast()
end, nil, "SlashMoon: список модулей / slashmoon_module <id> <0|1>")
