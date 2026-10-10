-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: слой совместимости с админ-системами
-- Приоритет: SAM -> ULX/ULib -> стандартные проверки GMod.
--
--   SlashMoon.Admin.RegisterPermission("slashmoon_menu", "superadmin", "Открытие меню")
--   SlashMoon.Admin.HasPermission(ply, "slashmoon_menu")
--   SlashMoon.Admin.GetRank(ply)
-- ========================================================

SlashMoon.Admin = SlashMoon.Admin or {}
local Admin = SlashMoon.Admin

Admin.Category = "SlashMoon"
Admin.Permissions = Admin.Permissions or {} -- [name] = { default = "superadmin", description = "" }
Admin.Registered = Admin.Registered or {}   -- [system][name] = true

-- Уровни доступа по умолчанию (используются, если админ-система не установлена)
local LEVELS = { user = 0, admin = 1, superadmin = 2 }

--- Определяет активную админ-систему.
-- @return string "sam" | "ulx" | "default"
function Admin.GetSystem()
    if SlashMoon.Compat.Has("sam") then return "sam" end
    if SlashMoon.Compat.Has("ulx") then return "ulx" end
    return "default"
end

local function NormalizeLevel(level)
    level = string.lower(tostring(level or "superadmin"))
    if LEVELS[level] == nil then level = "superadmin" end
    return level
end

-- Регистрация права в конкретной админ-системе
local function RegisterInSystem(system, name, info)
    Admin.Registered[system] = Admin.Registered[system] or {}
    if Admin.Registered[system][name] then return end

    local ok
    if system == "sam" then
        ok = SlashMoon.SafeCall(function()
            sam.permissions.add(name, Admin.Category, info.default)
        end)
    elseif system == "ulx" then
        if SERVER and isfunction(ULib.ucl.registerAccess) then
            local groups = ULib.ACCESS_SUPERADMIN or "superadmin"
            if info.default == "admin" then
                groups = ULib.ACCESS_ADMIN or "admin"
            elseif info.default == "user" then
                groups = ULib.ACCESS_ALL or "user"
            end
            ok = SlashMoon.SafeCall(ULib.ucl.registerAccess, name, groups, info.description or "", Admin.Category)
        else
            ok = true -- на клиенте ULib получает права с сервера
        end
    else
        ok = true
    end

    if ok then Admin.Registered[system][name] = true end
end

--- Регистрирует право доступа во всех доступных админ-системах.
-- @param name string уникальное имя права (например, "slashmoon_menu")
-- @param defaultLevel string "superadmin" | "admin" | "user" — кому доступно по умолчанию
-- @param description string|nil описание для админ-системы
function Admin.RegisterPermission(name, defaultLevel, description)
    local info = {
        default = NormalizeLevel(defaultLevel),
        description = description or name,
    }
    Admin.Permissions[name] = info

    -- Если админ-системы уже загружены — регистрируем сразу, иначе это сделает хук ниже.
    if Admin.Ready then
        RegisterInSystem(Admin.GetSystem(), name, info)
    end
end

--- Регистрирует все накопленные права в активной админ-системе.
function Admin.RegisterAll()
    local system = Admin.GetSystem()
    for name, info in pairs(Admin.Permissions) do
        RegisterInSystem(system, name, info)
    end
end

-- Админ-системы (особенно ULib) грузятся после нашего autorun, поэтому регистрация откладывается.
hook.Add("Initialize", "SlashMoon.Admin.Register", function()
    Admin.Ready = true
    Admin.RegisterAll()
end)

-- SAM может пересоздать список прав после загрузки рангов.
hook.Add("SAM.LoadedRanks", "SlashMoon.Admin.RegisterSAM", function()
    if Admin.Registered.sam then table.Empty(Admin.Registered.sam) end
    Admin.RegisterAll()
end)

-- Проверка по стандартным флагам GMod
local function DefaultCheck(ply, level)
    if level == "user" then return true end
    if level == "admin" then return ply:IsAdmin() end
    return ply:IsSuperAdmin()
end

--- Проверяет, есть ли у игрока право.
-- Консоль сервера (NULL) всегда имеет все права.
-- @param ply Player
-- @param name string имя права
-- @return boolean
function Admin.HasPermission(ply, name)
    if SERVER and ply == NULL then return true end
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    local info = Admin.Permissions[name]
    local level = info and info.default or "superadmin"
    local system = Admin.GetSystem()

    if system == "sam" and isfunction(ply.HasPermission) then
        local ok, res = pcall(ply.HasPermission, ply, name)
        if ok then return res == true end
    elseif system == "ulx" then
        local ok, res = pcall(ULib.ucl.query, ply, name, true)
        if ok and res ~= nil then return res == true end
    end

    return DefaultCheck(ply, level)
end

--- Возвращает ранг (usergroup) игрока с учетом админ-системы.
function Admin.GetRank(ply)
    if not IsValid(ply) then return "user" end

    if Admin.GetSystem() == "sam" and isfunction(ply.sam_getrank) then
        local ok, rank = pcall(ply.sam_getrank, ply)
        if ok and isstring(rank) and rank ~= "" then return rank end
    end

    return ply:GetUserGroup() or "user"
end

--- Является ли игрок администратором (admin или выше).
function Admin.IsAdmin(ply)
    if SERVER and ply == NULL then return true end
    return IsValid(ply) and ply:IsAdmin()
end

--- Является ли игрок суперадмином.
function Admin.IsSuperAdmin(ply)
    if SERVER and ply == NULL then return true end
    return IsValid(ply) and ply:IsSuperAdmin()
end

--- Возвращает всех игроков, имеющих право.
function Admin.GetPlayersWithPermission(name)
    local out = {}
    for _, ply in ipairs(player.GetHumans()) do
        if Admin.HasPermission(ply, name) then out[#out + 1] = ply end
    end
    return out
end

-- ========================================================
-- Админ-команды (клиент): единый вызов для SAM и ULX
--   SlashMoon.Admin.RunCommand("kick", ply, "причина")
-- Поддерживаемые действия: pm, goto, bring, return, kick, ban
-- ========================================================
Admin.CommandMap = {
    sam = { prefix = "sam", pm = "pm", ["goto"] = "goto", bring = "bring", ["return"] = "return", kick = "kick", ban = "ban" },
    ulx = { prefix = "ulx", pm = "psay", ["goto"] = "goto", bring = "bring", ["return"] = "return", kick = "kick", ban = "ban" },
}

--- Можно ли выполнить админ-действие (установлена ли подходящая админ-система).
function Admin.CanRunCommand(action)
    local map = Admin.CommandMap[Admin.GetSystem()]
    return map ~= nil and map[action] ~= nil
end

if CLIENT then
    --- Выполняет админ-команду через активную админ-систему.
    -- @param action string pm | goto | bring | return | kick | ban
    -- @param target Player
    -- @return boolean выполнена ли команда
    function Admin.RunCommand(action, target, ...)
        local system = Admin.GetSystem()
        local map = Admin.CommandMap[system]
        if not map or not map[action] then
            chat.AddText(Color(255, 80, 80), "[SlashMoon] ", color_white,
                "Для этого действия нужна админ-система (SAM или ULX).")
            return false
        end

        local targetArg = target
        if IsValid(target) and target:IsPlayer() then
            if target:IsBot() then
                targetArg = target:Nick()
            elseif system == "ulx" then
                targetArg = "$" .. target:SteamID()
            else
                targetArg = target:SteamID()
            end
        end

        RunConsoleCommand(map.prefix, map[action], tostring(targetArg), ...)
        return true
    end
end

-- Базовые права ядра
Admin.RegisterPermission("slashmoon_menu", "superadmin", "Открытие панели конфигурации SlashMoon")
Admin.RegisterPermission("slashmoon_config", "superadmin", "Изменение настроек и модулей SlashMoon")
