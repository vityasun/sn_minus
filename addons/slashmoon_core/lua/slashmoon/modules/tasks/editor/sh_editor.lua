-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Фреймворк Редактора (v3 — Full API + Section Spec)
-- Поддержка: info, markers, list_items, context, custom_markers,
--            cycle_models, on_store, on_change
-- + Доступ только через SlashMoon.TEAM_EDITOR (2703) + право slashmoon_tasks_editor
-- ========================================================
SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Editor = SlashMoon.Tasks.Editor or {}
if SlashMoon.Tasks.Editor._BootstrapLoaded then return end
SlashMoon.Tasks.Editor._BootstrapLoaded = true
SlashMoon.Tasks.Editor.Sections = SlashMoon.Tasks.Editor.Sections or {}

-- ══════════════════════════════════════════════════════════════════════
-- SlashMoon.TEAM_EDITOR — команда редактора (2703)
-- ══════════════════════════════════════════════════════════════════════
SlashMoon.TEAM_EDITOR = SlashMoon.TEAM_EDITOR or 2703

-- Проверка: игрок имеет доступ к редактору (SuperAdmin + команда 2703)
local function IsEditorAllowed(ply)
    if not IsValid(ply) then return false end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_editor") then return false end
    if ply:Team() ~= SlashMoon.TEAM_EDITOR then return false end
    return true
end

-- Проверка: игрок может войти в редактор (SuperAdmin)
local function CanEnterEditor(ply)
    if not IsValid(ply) then return false end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_editor") then return false end
    return true
end

-- Экспортируем для использования в других файлах
SlashMoon.Tasks.Editor.IsEditorAllowed = IsEditorAllowed
SlashMoon.Tasks.Editor.CanEnterEditor = CanEnterEditor

-- ══════════════════════════════════════════════════════════════════════
-- CONFIG HELPERS (nested path access)
-- ══════════════════════════════════════════════════════════════════════
local function NestedGet(root, path)
    local cur = root
    for i = 1, #path do
        if type(cur) ~= "table" then return nil end
        cur = cur[path[i]]
        if cur == nil then return nil end
    end
    return cur
end

local function NestedEnsure(root, path)
    local cur = root
    for i = 1, #path do
        cur[path[i]] = cur[path[i]] or {}
        cur = cur[path[i]]
    end
    return cur
end

local function NestedSet(root, path, val)
    local cur = root
    for i = 1, #path - 1 do
        cur[path[i]] = cur[path[i]] or {}
        cur = cur[path[i]]
    end
    cur[path[#path]] = val
end

-- Экспортируем хелперы для использования в секциях
SlashMoon.Tasks.Editor.NestedGet    = NestedGet
SlashMoon.Tasks.Editor.NestedEnsure = NestedEnsure
SlashMoon.Tasks.Editor.NestedSet    = NestedSet

-- ══════════════════════════════════════════════════════════════════════
-- SECTION REGISTRY
-- ══════════════════════════════════════════════════════════════════════
function SlashMoon.Tasks.Editor.RegisterSection(id, data)
    data.id    = id
    data.order = data.order or 100

    -- Инициализация context (section-local state)
    data.context = data.context or {}

    -- Удаляем старую секцию с таким же id (для hot-reload)
    for i = #SlashMoon.Tasks.Editor.Sections, 1, -1 do
        if SlashMoon.Tasks.Editor.Sections[i].id == id then
            table.remove(SlashMoon.Tasks.Editor.Sections, i)
        end
    end

    table.insert(SlashMoon.Tasks.Editor.Sections, data)
    table.sort(SlashMoon.Tasks.Editor.Sections, function(a, b) return a.order < b.order end)
end

function SlashMoon.Tasks.Editor.GetSections()
    return SlashMoon.Tasks.Editor.Sections
end

-- ══════════════════════════════════════════════════════════════════════
-- EDITOR API OBJECT
-- Каждая секция получает api при вызове info/buttons/markers/list_items
-- ══════════════════════════════════════════════════════════════════════
function SlashMoon.Tasks.Editor.GetAPI(section)
    local cfg = SlashMoon.Tasks.Editor.State.Config

    local api = {}

    -- Config access
    function api.GetConfig(path)
        return NestedGet(cfg, path)
    end

    function api.SetConfig(path, val)
        NestedSet(cfg, path, val)
    end

    function api.EnsureConfig(path)
        return NestedEnsure(cfg, path)
    end

    -- Context (section-local state)
    function api.GetContext(key)
        return section.context[key]
    end

    function api.SetContext(key, val)
        section.context[key] = val
    end

    -- Markers (делегируется в cl_editor.lua)
    function api.PlaceMarker(pos, ang, model, color, label, skin)
        if SlashMoon.Tasks.Editor._PlaceMarker then
            return SlashMoon.Tasks.Editor._PlaceMarker(pos, ang, model, color, label, skin)
        end
    end

    -- Refresh (делегируется в cl_editor.lua)
    function api.RefreshAll()
        if SlashMoon.Tasks.Editor._RefreshAll then
            SlashMoon.Tasks.Editor._RefreshAll()
        end
    end

    function api.RedrawMarkers()
        if SlashMoon.Tasks.Editor._RedrawAllMarkers then
            SlashMoon.Tasks.Editor._RedrawAllMarkers()
        end
    end

    -- Chat helper
    function api.Chat(msg)
        if CLIENT then
            chat.AddText(Color(100, 200, 255), "[SN] " .. msg)
        end
    end

    return api
end

-- ══════════════════════════════════════════════════════════════════════
-- TELEPORT HELPER (для секций)
-- ══════════════════════════════════════════════════════════════════════
function SlashMoon.Tasks.Editor.MakeTeleport(getInfo)
    return function()
        local info = getInfo()
        if not info or not info.pos then return end
        local pos = Vector(info.pos.x, info.pos.y, info.pos.z) + Vector(0, 0, 64)
        local ang = Angle(
            info.ang and info.ang.p or 0,
            info.ang and info.ang.y or 0,
            info.ang and info.ang.r or 0
        )
        net.Start("SN_Editor_Teleport")
        net.WriteVector(pos)
        net.WriteAngle(ang)
        net.SendToServer()
    end
end

-- ══════════════════════════════════════════════════════════════════════
-- SERVER-SIDE NET HANDLERS
-- ══════════════════════════════════════════════════════════════════════
if SERVER then
    util.AddNetworkString("SN_Editor_Open")
    util.AddNetworkString("SN_Editor_Save")
    util.AddNetworkString("SN_Editor_Load")
    util.AddNetworkString("SN_Editor_Clear")
    util.AddNetworkString("SN_Editor_Teleport")

    -- === СОХРАНЕНИЕ (С АНТИ-СПАМОМ) ===
    MODULE:Receive("SN_Editor_Save", function(len, ply)
        if not IsEditorAllowed(ply) then return end
        if not SlashMoon.Security.CheckRateLimit(ply, "editor_save", 2.0) then return end

        local data = net.ReadTable()
        if not istable(data) then return end

        if not SlashMoon.Tasks.NormalizeMapConfig then return end
        data = SlashMoon.Tasks.NormalizeMapConfig(data)

        SlashMoon.Tasks.MapConfig = data
        if not SlashMoon.Tasks.SaveMapConfig() then
            SlashMoon.Tasks.SendLocalizedChat(ply, "sn.editor.save_failed")
            return
        end

        SlashMoon.Tasks.SendLocalizedChat(ply, "sn.editor.saved")
        SlashMoon.Debug(string.format("[SN Editor] Админ %s сохранил конфиг карты.", ply:Nick()))
    end)

    -- === ЗАГРУЗКА (С АНТИ-СПАМОМ) ===
    MODULE:Receive("SN_Editor_Load", function(len, ply)
        if not IsEditorAllowed(ply) then return end
        if not SlashMoon.Security.CheckRateLimit(ply, "editor_load", 2.0) then return end

        SlashMoon.Tasks.LoadMapConfig()

        net.Start("SN_Editor_Open")
        net.WriteBool(true)
        net.WriteTable(SlashMoon.Tasks.MapConfig or {})
        net.Send(ply)

        SlashMoon.Tasks.SendLocalizedChat(ply, "sn.editor.loaded")
    end)

    -- === ОЧИСТКА (С АНТИ-СПАМОМ) ===
    MODULE:Receive("SN_Editor_Clear", function(len, ply)
        if not IsEditorAllowed(ply) then return end
        if not SlashMoon.Security.CheckRateLimit(ply, "editor_clear", 5.0) then return end

        SlashMoon.Tasks.MapConfig = { tasks = {}, rotation = {}, escape_positions = {} }
        SlashMoon.Tasks.SaveMapConfig()
        SlashMoon.Tasks.CleanupAll()
        SlashMoon.Tasks.SyncTasksToClients()

        net.Start("SN_Editor_Open")
        net.WriteBool(true)
        net.WriteTable(SlashMoon.Tasks.MapConfig)
        net.Send(ply)

        SlashMoon.Tasks.SendLocalizedChat(ply, "sn.editor.cleared")
    end)

    -- === ТЕЛЕПОРТ (С АНТИ-СПАМОМ) ===
    MODULE:Receive("SN_Editor_Teleport", function(len, ply)
        if not IsEditorAllowed(ply) then return end
        if not SlashMoon.Security.CheckRateLimit(ply, "editor_teleport", 0.5) then return end

        local pos = net.ReadVector()
        local ang = net.ReadAngle()

        -- Валидация позиции
        if pos.x < -16000 or pos.x > 16000 or pos.y < -16000 or pos.y > 16000 or pos.z < -16000 or pos.z > 16000 then
            return
        end

        ply:SetPos(pos)
        ply:SetEyeAngles(ang)

        if ply:GetObserverMode() ~= OBS_MODE_ROAMING then
            ply:Spectate(OBS_MODE_ROAMING)
            ply:SetPos(pos)
            ply:SetEyeAngles(ang)
        end
    end)

    -- === КОМАНДА ПЕРЕКЛЮЧЕНИЯ РЕДАКТОРА ===
    -- Доступ: только SuperAdmin, переключает в команду SlashMoon.TEAM_EDITOR (2703)
    MODULE:Command("sn_editor", function(ply)
        if not CanEnterEditor(ply) then
            if IsValid(ply) then
                SlashMoon.Tasks.SendLocalizedChat(ply, "sn.editor.access_denied")
            end
            return
        end

        if ply:Team() ~= SlashMoon.TEAM_EDITOR then
            -- Вход в редактор: переключаем в команду SlashMoon.TEAM_EDITOR
            ply.SN_OldTeam = ply:Team()
            ply:StripWeapons()
            ply:Spectate(OBS_MODE_ROAMING)
            ply:SetTeam(SlashMoon.TEAM_EDITOR)
            SlashMoon.Tasks.SendLocalizedChat(ply, "sn.editor.enabled")

            net.Start("SN_Editor_Open")
            net.WriteBool(true)
            net.WriteTable(SlashMoon.Tasks.MapConfig or {})
            net.Send(ply)
        else
            -- Выход из редактора: возвращаем прежнюю команду
            ply:UnSpectate()
            ply:SetTeam(ply.SN_OldTeam or TEAM_SURVIVOR)
            ply:Spawn()
            SlashMoon.Tasks.SendLocalizedChat(ply, "sn.editor.disabled")

            net.Start("SN_Editor_Open")
            net.WriteBool(false)
            net.Send(ply)
        end
    end)
end
