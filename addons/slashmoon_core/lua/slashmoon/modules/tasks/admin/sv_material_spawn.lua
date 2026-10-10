-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Material Spawn System (Server)
-- Спавн материалов на карте: по конфигу или по NavMesh
-- + Команды только для SuperAdmin в команде SlashMoon.TEAM_EDITOR
-- ========================================================
if not SERVER then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.MaterialSpawn = SlashMoon.Tasks.MaterialSpawn or {}

local DEBUG_PREFIX = "[SN Material Debug] "

local function Debug(message, ...)
    local text = select("#", ...) > 0 and string.format(message, ...) or tostring(message)
    SlashMoon.Debug(DEBUG_PREFIX .. text)
end

local function CountConfiguredMaterials(counts)
    local types, total = 0, 0
    for _, count in pairs(counts or {}) do
        types = types + 1
        total = total + math.max(0, tonumber(count) or 0)
    end
    return types, total
end

local function GetEffectiveConfig(roundCfg)
    local globalCfg = SlashMoon.Tasks.MaterialSpawn.Config or {}
    local selected = istable(roundCfg and roundCfg.material_spawn) and roundCfg.material_spawn or {}
    local effective = table.Copy(globalCfg)

    effective.navmesh = table.Copy(globalCfg.navmesh or {})
    effective.navmesh.counts = table.Copy((globalCfg.navmesh and globalCfg.navmesh.counts) or {})

    if selected.mode ~= nil then effective.mode = selected.mode end

    if istable(selected.navmesh) then
        for key, value in pairs(selected.navmesh) do
            if key ~= "counts" then effective.navmesh[key] = value end
        end
        if table.Count(selected.navmesh.counts or {}) > 0 then
            effective.navmesh.counts = table.Copy(selected.navmesh.counts)
        end
    end

    if #((selected.config_positions) or {}) > 0 then
        effective.config_positions = table.Copy(selected.config_positions)
    end

    return effective
end

-- SlashMoon.TEAM_EDITOR — должна быть определена в sh_editor.lua
SlashMoon.TEAM_EDITOR = SlashMoon.TEAM_EDITOR or 2703

-- Проверка доступа: SuperAdmin + команда SlashMoon.TEAM_EDITOR
local function IsAdminEditorAllowed(ply)
    if not IsValid(ply) then return false end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_editor") then return false end
    if ply:Team() ~= SlashMoon.TEAM_EDITOR then return false end
    return true
end

-- ========================================================
-- НАСТРОЙКИ ПО УМОЛЧАНИЮ
-- ========================================================
local DEFAULT_CONFIG = {
    -- Режим: "config" | "navmesh" | "both"
    -- config: спавн по позициям из конфига карты
    -- navmesh: спавн по навмешу (случайные точки)
    -- both: спавн по обоим методам
    mode = "navmesh",

    -- Навмеш настройки
    navmesh = {
        -- Сколько материалов каждого типа спавнить
        counts = {
            mat_scrap       = 8,
            mat_wire        = 6,
            mat_chip        = 4,
            mat_battery     = 5,
            mat_circuit_board = 3,
            mat_transistor  = 3,
            mat_key         = 4,
            mat_plastic     = 5,
            mat_medpack     = 3,
            mat_fuse        = 3,
        },
        -- Минимальное расстояние между одинаковыми предметами
        minDist = 200,
        -- Минимальная дистанция от генераторов/верстаков
        minDistFromObjects = 300,
        -- Z-оффсет при спавне
        zOffset = 10,
    },

    -- Конфиг-режим: позиции из конфига карты
    -- Формат: { { class = "mat_scrap", pos = {x,y,z}, ang = {p,y,r} }, ... }
    config_positions = {},
}

-- Загружаем/сохраняем конфиг
SlashMoon.Tasks.MaterialSpawn.Config = SlashMoon.Tasks.MaterialSpawn.Config or table.Copy(DEFAULT_CONFIG)

local MATSPAWN_FILE = "sn_tasks/material_spawn.json"

function SlashMoon.Tasks.MaterialSpawn.SaveConfig()
    file.CreateDir("sn_tasks")
    local json = util.TableToJSON(SlashMoon.Tasks.MaterialSpawn.Config, true)
    file.Write(MATSPAWN_FILE, json)
end

function SlashMoon.Tasks.MaterialSpawn.LoadConfig()
    Debug("LoadConfig: path=data/%s, exists=%s", MATSPAWN_FILE, tostring(file.Exists(MATSPAWN_FILE, "DATA")))
    if not file.Exists(MATSPAWN_FILE, "DATA") then
        SlashMoon.Tasks.MaterialSpawn.Config = table.Copy(DEFAULT_CONFIG)
        local types, total = CountConfiguredMaterials(SlashMoon.Tasks.MaterialSpawn.Config.navmesh.counts)
        Debug("LoadConfig: using defaults, mode=%s, materialTypes=%d, requested=%d", SlashMoon.Tasks.MaterialSpawn.Config.mode, types, total)
        return
    end

    local json = file.Read(MATSPAWN_FILE, "DATA")
    local data = util.JSONToTable(json)
    if data then
        -- Мержим с дефолтами
        SlashMoon.Tasks.MaterialSpawn.Config = table.Copy(DEFAULT_CONFIG)
        for k, v in pairs(data) do
            SlashMoon.Tasks.MaterialSpawn.Config[k] = v
        end
        local navCfg = SlashMoon.Tasks.MaterialSpawn.Config.navmesh or {}
        local types, total = CountConfiguredMaterials(navCfg.counts)
        Debug("LoadConfig: JSON loaded, mode=%s, materialTypes=%d, requested=%d, fixedPositions=%d", tostring(SlashMoon.Tasks.MaterialSpawn.Config.mode), types, total, #(SlashMoon.Tasks.MaterialSpawn.Config.config_positions or {}))
    else
        Debug("LoadConfig ERROR: invalid JSON, bytes=%d", #(json or ""))
    end
end

-- ========================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ========================================================

-- Найти все позиции объектов, от которых нужно отдаляться
local function GetObjectPositions()
    local positions = {}

    -- Генераторы
    for _, ent in ipairs(ents.FindByClass("sn_generator")) do
        if IsValid(ent) then table.insert(positions, ent:GetPos()) end
    end

    -- Верстаки
    for _, ent in ipairs(ents.FindByClass("sn_workbench")) do
        if IsValid(ent) then table.insert(positions, ent:GetPos()) end
    end

    -- Зарядные станции
    for _, ent in ipairs(ents.FindByClass("sn_charging_station")) do
        if IsValid(ent) then table.insert(positions, ent:GetPos()) end
    end

    -- Машины эвакуации
    for _, ent in ipairs(ents.FindByClass("sn_escape_car")) do
        if IsValid(ent) then table.insert(positions, ent:GetPos()) end
    end

    return positions
end

-- Проверка: достаточно ли далеко от других объектов?
local function IsFarEnough(pos, existingPositions, minDist)
    for _, otherPos in ipairs(existingPositions) do
        if pos:Distance(otherPos) < minDist then
            return false
        end
    end
    return true
end

-- Объединённый список позиций для проверки
local function GetAllSpawnedPositions()
    local allPos = GetObjectPositions()

    -- Уже заспавненные материалы
    for _, ent in ipairs(ents.FindByClass("sn_item_drop")) do
        if IsValid(ent) then table.insert(allPos, ent:GetPos()) end
    end

    return allPos
end

-- ========================================================
-- СПАВН ПО NAVMESH
-- ========================================================
local function SpawnByNavMesh(spawnedEnts, cfg)
    cfg = cfg or SlashMoon.Tasks.MaterialSpawn.Config
    local navCfg = cfg.navmesh or {}
    local counts = navCfg.counts or {}
    local minDist = navCfg.minDist or 200
    local minDistObj = navCfg.minDistFromObjects or 300
    local zOffset = navCfg.zOffset or 10

    -- Получить навличareas
    local areas = navmesh and navmesh.GetAllNavAreas() or {}
    local typeCount, requestedCount = CountConfiguredMaterials(counts)
    Debug("NavMesh start: areas=%d, materialTypes=%d, requested=%d, minDist=%s, objectDist=%s, zOffset=%s", #areas, typeCount, requestedCount, tostring(minDist), tostring(minDistObj), tostring(zOffset))
    if #areas == 0 then
        Debug("NavMesh STOP: map has no NavMesh areas")
        return 0
    end
    if typeCount == 0 then
        Debug("NavMesh STOP: counts table is empty")
        return 0
    end

    local objectPositions = GetObjectPositions()
    local materialPositions = {}  -- Трекинг заспавненных материалов
    local totalSpawned = 0

    for itemClass, count in pairs(counts) do
        count = math.max(0, math.floor(tonumber(count) or 0))
        Debug("NavMesh item: class=%s requested=%d registered=%s", tostring(itemClass), count, tostring(SlashMoon.Tasks.Items and SlashMoon.Tasks.Items[itemClass] ~= nil))
        if count <= 0 then
            Debug("NavMesh item skipped: %s count is zero", tostring(itemClass))
            continue
        end

        -- Проверяем что предмет существует
        if not SlashMoon.Tasks.Items[itemClass] then
            Debug("NavMesh item skipped: %s is not registered in SlashMoon.Tasks.Items", tostring(itemClass))
            continue
        end

        local spawned = 0
        local attempts = 0
        local maxAttempts = count * 20  -- Максимум попыток на предмет
        local rejectedObject = 0
        local rejectedMaterial = 0
        local invalidArea = 0
        local spawnFailures = {}

        while spawned < count and attempts < maxAttempts do
            attempts = attempts + 1

            -- Случайная нав-область
            local area = areas[math.random(#areas)]
            if not area then invalidArea = invalidArea + 1 continue end

            local pos = area:GetRandomPoint()
            pos.z = pos.z + zOffset

            -- Проверка дистанции от объектов
            if not IsFarEnough(pos, objectPositions, minDistObj) then rejectedObject = rejectedObject + 1 continue end

            -- Проверка дистанции от других материалов
            if not IsFarEnough(pos, materialPositions, minDist) then rejectedMaterial = rejectedMaterial + 1 continue end

            -- Спавн
            local ent, reason = SlashMoon.Tasks.SpawnDrop(itemClass, pos)
            if IsValid(ent) then
                table.insert(spawnedEnts, ent)
                table.insert(materialPositions, pos)
                spawned = spawned + 1
                totalSpawned = totalSpawned + 1
            else
                reason = tostring(reason or "invalid_entity")
                spawnFailures[reason] = (spawnFailures[reason] or 0) + 1
            end
        end

        local failures = {}
        for reason, amount in pairs(spawnFailures) do failures[#failures + 1] = reason .. "=" .. amount end
        table.sort(failures)
        Debug("NavMesh result: class=%s spawned=%d/%d attempts=%d/%d rejectedObject=%d rejectedMaterial=%d invalidArea=%d spawnFailures=[%s]", itemClass, spawned, count, attempts, maxAttempts, rejectedObject, rejectedMaterial, invalidArea, table.concat(failures, ", "))
        if spawned < count then
            Debug("NavMesh WARNING: %s did not reach requested count", itemClass)
        end
    end

    return totalSpawned
end

-- ========================================================
-- СПАВН ПО КОНФИГУ (фиксированные позиции)
-- ========================================================
local function SpawnByConfig(spawnedEnts, cfg)
    cfg = cfg or SlashMoon.Tasks.MaterialSpawn.Config
    local positions = cfg.config_positions or {}

    Debug("Config start: positions=%d", #positions)
    if #positions == 0 then
        Debug("Config STOP: config_positions is empty")
        return 0
    end

    local totalSpawned = 0

    for index, spawnInfo in ipairs(positions) do
        local itemClass = spawnInfo.class
        if not itemClass or not SlashMoon.Tasks.Items[itemClass] then
            Debug("Config position #%d skipped: class=%s registered=%s", index, tostring(itemClass), tostring(itemClass and SlashMoon.Tasks.Items[itemClass] ~= nil))
            continue
        end
        if not spawnInfo.pos then
            Debug("Config position #%d skipped: missing pos", index)
            continue
        end

        local pos = Vector(spawnInfo.pos.x, spawnInfo.pos.y, spawnInfo.pos.z)
        local ang = spawnInfo.ang and Angle(spawnInfo.ang.p, spawnInfo.ang.y, spawnInfo.ang.r) or Angle(0, math.random(0, 360), 0)

        local ent, reason = SlashMoon.Tasks.SpawnDrop(itemClass, pos)
        if IsValid(ent) then
            ent:SetAngles(ang)
            table.insert(spawnedEnts, ent)
            totalSpawned = totalSpawned + 1
            Debug("Config position #%d spawned: class=%s entity=%s pos=%s", index, itemClass, tostring(ent), tostring(pos))
        else
            Debug("Config position #%d FAILED: class=%s reason=%s pos=%s", index, itemClass, tostring(reason or "invalid_entity"), tostring(pos))
        end
    end

    return totalSpawned
end

-- ========================================================
-- ГЛАВНАЯ ФУНКЦИЯ СПАВНА
-- ========================================================
function SlashMoon.Tasks.MaterialSpawn.Run(spawnedEnts)
    spawnedEnts = spawnedEnts or {}

    local roundCfg = SlashMoon.Tasks.RoundConfig or SlashMoon.Tasks.MapConfig or {}
    local selectedCfg = roundCfg.material_spawn
    local cfg = GetEffectiveConfig(roundCfg)
    local mode = cfg.mode or "navmesh"
    local total = 0

    local selectedTypes = selectedCfg and selectedCfg.navmesh and table.Count(selectedCfg.navmesh.counts or {}) or 0
    local source = selectedCfg and (SlashMoon.Tasks.RoundConfig and "RoundConfig.material_spawn+global-fallback" or "MapConfig.material_spawn+global-fallback") or "MaterialSpawn.Config"
    local navCfg = cfg.navmesh or {}
    local typeCount, requestedCount = CountConfiguredMaterials(navCfg.counts)
    Debug("Run BEGIN: map=%s mode=%s source=%s hookListSize=%d itemsReady=%s itemRegistrySize=%d", game.GetMap(), tostring(mode), source, #spawnedEnts, tostring(istable(SlashMoon.Tasks.Items)), table.Count(SlashMoon.Tasks.Items or {}))
    local globalTypes, globalRequested = CountConfiguredMaterials(SlashMoon.Tasks.MaterialSpawn.Config and SlashMoon.Tasks.MaterialSpawn.Config.navmesh and SlashMoon.Tasks.MaterialSpawn.Config.navmesh.counts)
    Debug("Run config: selectedTypes=%d effectiveTypes=%d requested=%d fixedPositions=%d globalMode=%s globalTypes=%d globalRequested=%d", selectedTypes, typeCount, requestedCount, #(cfg.config_positions or {}), tostring(SlashMoon.Tasks.MaterialSpawn.Config and SlashMoon.Tasks.MaterialSpawn.Config.mode), globalTypes, globalRequested)

    if mode == "navmesh" then
        total = SpawnByNavMesh(spawnedEnts, cfg)
    elseif mode == "config" then
        total = SpawnByConfig(spawnedEnts, cfg)
    elseif mode == "both" then
        local navCount = SpawnByNavMesh(spawnedEnts, cfg)
        local cfgCount = SpawnByConfig(spawnedEnts, cfg)
        total = navCount + cfgCount
    else
        Debug("Run STOP: unsupported mode=%s", tostring(mode))
    end

    Debug("Run END: spawned=%d trackedEntities=%d worldItemDrops=%d", total, #spawnedEnts, #ents.FindByClass("sn_item_drop"))
    return total
end

-- ========================================================
-- ОЧИСТКА МАТЕРИАЛОВ
-- ========================================================
function SlashMoon.Tasks.MaterialSpawn.Cleanup()
    local count = 0
    for _, ent in ipairs(ents.FindByClass("sn_item_drop")) do
        -- Удаляем только предметы, которые являются материалами (mat_ префикс)
        local itemClass = ent:GetNW2String("ItemClass", "")
        if string.StartWith(itemClass, "mat_") then
            if IsValid(ent) then
                ent:Remove()
                count = count + 1
            end
        end
    end
    SlashMoon.Debug("[MaterialSpawn] Удалено материалов: " .. count)
    return count
end

-- ========================================================
-- ИНТЕГРАЦИЯ С РАУНДАМИ
-- Спавн материалов при старте раунда
-- ========================================================
MODULE:Hook("SN_BeforeSpawnTasks", "SN_MatSpawn_Before", function()
    Debug("Hook SN_BeforeSpawnTasks received")
end)

MODULE:Hook("SN_AfterSpawnTasks", "SN_MatSpawn_After", function(spawnedEnts)
    -- Спавн материалов после заданий (чтобы знать позиции генераторов/верстаков)
    Debug("Hook SN_AfterSpawnTasks received: spawnedEnts=%s size=%d", tostring(spawnedEnts), istable(spawnedEnts) and #spawnedEnts or -1)
    SlashMoon.Tasks.MaterialSpawn.Run(spawnedEnts)
end)

-- Фоллбэк: если хука нет, спавним через таймер
MODULE:Hook("InitPostEntity", "SN_MatSpawn_Init", function()
    Debug("Hook InitPostEntity received: loading global material config")
    SlashMoon.Tasks.MaterialSpawn.LoadConfig()
end)

-- ========================================================
-- КОНСОЛЬНЫЕ КОМАНДЫ
-- ========================================================
MODULE:Command("sn_matspawn_debug", function(ply)
    if IsValid(ply) and not IsAdminEditorAllowed(ply) then return end

    local roundCfg = SlashMoon.Tasks.RoundConfig or SlashMoon.Tasks.MapConfig or {}
    local selectedCfg = roundCfg.material_spawn
    local cfg = GetEffectiveConfig(roundCfg)
    local navCfg = cfg.navmesh or {}
    local types, requested = CountConfiguredMaterials(navCfg.counts)
    local globalNav = SlashMoon.Tasks.MaterialSpawn.Config and SlashMoon.Tasks.MaterialSpawn.Config.navmesh or {}
    local globalTypes, globalRequested = CountConfiguredMaterials(globalNav.counts)
    local afterHooks = hook.GetTable().SN_AfterSpawnTasks or {}

    Debug("===== SNAPSHOT BEGIN =====")
    Debug("map=%s compatibilityMode=%s roundActive=%s", game.GetMap(), tostring(SlashMoon.Tasks.Game and SlashMoon.Tasks.Game.GetMode and SlashMoon.Tasks.Game.GetMode()), tostring(SlashMoon.Tasks.Game and SlashMoon.Tasks.Game.IsRoundActive and SlashMoon.Tasks.Game.IsRoundActive()))
    Debug("MapConfig=%s RoundConfig=%s MaterialSpawn.Config=%s", tostring(SlashMoon.Tasks.MapConfig), tostring(SlashMoon.Tasks.RoundConfig), tostring(SlashMoon.Tasks.MaterialSpawn.Config))
    Debug("selected source=%s mode=%s types=%d requested=%d positions=%d", selectedCfg and (SlashMoon.Tasks.RoundConfig and "RoundConfig+global-fallback" or "MapConfig+global-fallback") or "global", tostring(cfg.mode), types, requested, #(cfg.config_positions or {}))
    Debug("global mode=%s types=%d requested=%d positions=%d", tostring(SlashMoon.Tasks.MaterialSpawn.Config and SlashMoon.Tasks.MaterialSpawn.Config.mode), globalTypes, globalRequested, #(SlashMoon.Tasks.MaterialSpawn.Config and SlashMoon.Tasks.MaterialSpawn.Config.config_positions or {}))
    Debug("NavMesh areas=%d itemRegistry=%d sn_item_drop registered=%s", #(navmesh and navmesh.GetAllNavAreas() or {}), table.Count(SlashMoon.Tasks.Items or {}), tostring(scripted_ents.GetStored("sn_item_drop") ~= nil))
    Debug("hooks: SN_AfterSpawnTasks=%d SN_MatSpawn_After=%s", table.Count(afterHooks), tostring(afterHooks.SN_MatSpawn_After ~= nil))
    Debug("world: itemDrops=%d trackedEnts=%d activeTasks=%d", #ents.FindByClass("sn_item_drop"), #(SlashMoon.Tasks.SpawnedEnts or {}), table.Count(SlashMoon.Tasks.ActiveState or {}))
    for class, count in SortedPairs(navCfg.counts or {}) do
        Debug("selected count: %s=%s registered=%s", tostring(class), tostring(count), tostring(SlashMoon.Tasks.Items and SlashMoon.Tasks.Items[class] ~= nil))
    end
    Debug("===== SNAPSHOT END =====")
end, nil, "Print material spawn diagnostic snapshot")

MODULE:Command("sn_matspawn_mode", function(ply, cmd, args)
    if IsValid(ply) and not IsAdminEditorAllowed(ply) then return end

    local mode = args[1]
    if mode ~= "config" and mode ~= "navmesh" and mode ~= "both" then
        local msg = "Использование: sn_matspawn_mode <config|navmesh|both>"
        if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
        return
    end

    SlashMoon.Tasks.MaterialSpawn.Config.mode = mode
    SlashMoon.Tasks.MaterialSpawn.SaveConfig()

    local msg = "[MaterialSpawn] Режим: " .. mode
    if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
end, nil, "Установить режим спавна материалов (SuperAdmin)")

MODULE:Command("sn_matspawn_run", function(ply, cmd, args)
    if IsValid(ply) and not IsAdminEditorAllowed(ply) then return end

    Debug("Command sn_matspawn_run invoked by %s", IsValid(ply) and (ply:Nick() .. " [" .. ply:SteamID() .. "]") or "server console")
    local spawnedEnts = {}
    local count = SlashMoon.Tasks.MaterialSpawn.Run(spawnedEnts)

    local msg = "[MaterialSpawn] Заспавнено: " .. count .. " предметов"
    if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
end, nil, "Запустить спавн материалов (SuperAdmin)")

MODULE:Command("sn_matspawn_clear", function(ply, cmd, args)
    if IsValid(ply) and not IsAdminEditorAllowed(ply) then return end

    local count = SlashMoon.Tasks.MaterialSpawn.Cleanup()

    local msg = "[MaterialSpawn] Удалено: " .. count .. " материалов"
    if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
end, nil, "Удалить все материалы с карты (SuperAdmin)")

MODULE:Command("sn_matspawn_set_count", function(ply, cmd, args)
    if IsValid(ply) and not IsAdminEditorAllowed(ply) then return end

    local itemClass = args[1]
    local count     = tonumber(args[2])

    if not itemClass or not count then
        local msg = "Использование: sn_matspawn_set_count <класс> <кол-во>"
        if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
        return
    end
    if not SlashMoon.Tasks.Items[itemClass] or not string.StartWith(itemClass, "mat_") then return end

    count = math.Clamp(count, 0, 50)
    SlashMoon.Tasks.MaterialSpawn.Config.navmesh.counts = SlashMoon.Tasks.MaterialSpawn.Config.navmesh.counts or {}
    SlashMoon.Tasks.MaterialSpawn.Config.navmesh.counts[itemClass] = count
    SlashMoon.Tasks.MaterialSpawn.SaveConfig()

    local msg = string.format("[MaterialSpawn] %s: кол-во = %d", itemClass, count)
    if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
end, nil, "Установить кол-во спавна для материала (SuperAdmin)")

-- ========================================================
-- ДОБАВЛЕНИЕ ПОЗИЦИИ ЧЕРЕЗ КОНСОЛЬ
-- ========================================================
MODULE:Command("sn_matspawn_add_pos", function(ply, cmd, args)
    if not IsValid(ply) or not IsAdminEditorAllowed(ply) then return end

    local itemClass = args[1]
    if not itemClass then
        ply:ChatPrint("Использование: sn_matspawn_add_pos <класс_предмета>")
        return
    end
    if not SlashMoon.Tasks.Items[itemClass] or not string.StartWith(itemClass, "mat_") then return end

    local pos = ply:GetPos()
    local ang = ply:GetAngles()

    SlashMoon.Tasks.MaterialSpawn.Config.config_positions = SlashMoon.Tasks.MaterialSpawn.Config.config_positions or {}
    table.insert(SlashMoon.Tasks.MaterialSpawn.Config.config_positions, {
        class = itemClass,
        pos   = { x = pos.x, y = pos.y, z = pos.z },
        ang   = { p = ang.p, y = ang.y, r = ang.r },
    })

    SlashMoon.Tasks.MaterialSpawn.SaveConfig()

    ply:ChatPrint(string.format("[MaterialSpawn] Добавлена позиция для %s (всего: %d)",
        itemClass, #SlashMoon.Tasks.MaterialSpawn.Config.config_positions))
end, nil, "Добавить позицию спавна материала (SuperAdmin)")

-- Загрузка при старте
timer.Simple(2, function()
    Debug("Delayed config load fired")
    SlashMoon.Tasks.MaterialSpawn.LoadConfig()
end)
