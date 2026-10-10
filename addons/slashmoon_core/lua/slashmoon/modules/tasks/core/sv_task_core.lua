-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Server Ядро Заданий (v2 — Fixed + Per-task hooks + PostCleanupMap + Debug)
-- ========================================================
if not SERVER then return end

SlashMoon.Tasks.ActiveState = {}
SlashMoon.Tasks.SpawnedEnts = {}
SlashMoon.Tasks.MapConfig = {}
SlashMoon.Tasks.RoundConfig = nil

util.AddNetworkString("SN_Tasks_SyncList")
util.AddNetworkString("SN_Tasks_RequestSyncList")

local CONFIG_DIR = "sn_tasks/maps"

local function IsFiniteNumber(value)
    return isnumber(value) and value == value and value ~= math.huge and value ~= -math.huge
end

local function NormalizePositions(positions)
    local normalized = {}
    if not istable(positions) then return normalized end
    for _, info in ipairs(positions) do
        local pos = istable(info) and info.pos
        if not istable(pos) or not IsFiniteNumber(pos.x) or not IsFiniteNumber(pos.y) or not IsFiniteNumber(pos.z) then continue end
        local ang = istable(info.ang) and info.ang or {}
        local entry = table.Copy(info)
        entry.pos = { x = pos.x, y = pos.y, z = pos.z }
        entry.ang = {
            p = IsFiniteNumber(ang.p) and ang.p or 0,
            y = IsFiniteNumber(ang.y) and ang.y or 0,
            r = IsFiniteNumber(ang.r) and ang.r or 0,
        }
        if entry.model ~= nil and not isstring(entry.model) then entry.model = nil end
        if isstring(entry.model) then entry.model = string.sub(entry.model, 1, 256) end
        entry.skin = math.max(0, math.floor(tonumber(entry.skin) or 0))
        table.insert(normalized, entry)
    end
    return normalized
end

function SlashMoon.Tasks.NormalizeMapConfig(raw)
    local cfg = istable(raw) and table.Copy(raw) or {}
    cfg.tasks = istable(cfg.tasks) and cfg.tasks or {}
    cfg.rotation = istable(cfg.rotation) and cfg.rotation or {}

    if not istable(cfg.charging_station_positions) and istable(cfg.charging_positions) then
        cfg.charging_station_positions = cfg.charging_positions
    end
    cfg.charging_positions = nil

    for key, value in pairs(cfg) do
        if isstring(key) and string.EndsWith(key, "_positions") then
            cfg[key] = NormalizePositions(value)
        end
    end
    for taskID, taskCfg in pairs(cfg.tasks) do
        if not istable(taskCfg) then
            cfg.tasks[taskID] = nil
            continue
        end
        for key, value in pairs(taskCfg) do
            if isstring(key) and string.EndsWith(key, "_positions") then
                taskCfg[key] = NormalizePositions(value)
            end
        end
    end

    local materialCfg = istable(cfg.material_spawn) and cfg.material_spawn or {}
    cfg.material_spawn = materialCfg
    if materialCfg.mode ~= "config" and materialCfg.mode ~= "navmesh" and materialCfg.mode ~= "both" then
        materialCfg.mode = "navmesh"
    end
    materialCfg.navmesh = istable(materialCfg.navmesh) and materialCfg.navmesh or {}
    materialCfg.navmesh.minDist = math.Clamp(tonumber(materialCfg.navmesh.minDist) or 200, 0, 1000)
    materialCfg.navmesh.minDistFromObjects = math.Clamp(tonumber(materialCfg.navmesh.minDistFromObjects) or 300, 0, 1500)
    materialCfg.navmesh.zOffset = math.Clamp(tonumber(materialCfg.navmesh.zOffset) or 10, -50, 100)
    materialCfg.navmesh.counts = istable(materialCfg.navmesh.counts) and materialCfg.navmesh.counts or {}
    for class, count in pairs(materialCfg.navmesh.counts) do
        if not isstring(class) or not string.StartWith(class, "mat_") or not SlashMoon.Tasks.Items[class] then
            materialCfg.navmesh.counts[class] = nil
        else
            materialCfg.navmesh.counts[class] = math.Clamp(math.floor(tonumber(count) or 0), 0, 50)
        end
    end
    materialCfg.config_positions = NormalizePositions(materialCfg.config_positions)
    for i = #materialCfg.config_positions, 1, -1 do
        local info = materialCfg.config_positions[i]
        if not isstring(info.class) or not string.StartWith(info.class, "mat_") or not SlashMoon.Tasks.Items[info.class] then
            table.remove(materialCfg.config_positions, i)
        end
    end

    local pattern = cfg.rotation.survival_pattern
    if not istable(pattern) or #pattern == 0 then
        cfg.rotation.survival_pattern = { false, false, true }
    else
        for i = 1, #pattern do pattern[i] = pattern[i] == true end
    end

    local numericLimits = {
        task_duration = { 1, 3600 },
        escape_duration = { 1, 1800 },
        survival_duration = { 1, 3600 },
    }
    for key, limits in pairs(numericLimits) do
        local value = tonumber(cfg.rotation[key])
        if value and value == value and value ~= math.huge and value ~= -math.huge then
            cfg.rotation[key] = math.Clamp(math.floor(value), limits[1], limits[2])
        else
            cfg.rotation[key] = nil
        end
    end

    return cfg
end

-- ── Загрузка/Сохранение JSON конфига карты ────────────────────────────
function SlashMoon.Tasks.GetConfigPath()
    return CONFIG_DIR .. "/" .. game.GetMap() .. ".json"
end

function SlashMoon.Tasks.LoadMapConfig()
    if not file.IsDir(CONFIG_DIR, "DATA") then file.CreateDir(CONFIG_DIR) end
    local path = SlashMoon.Tasks.GetConfigPath()

    if file.Exists(path, "DATA") then
        local data = util.JSONToTable(file.Read(path, "DATA") or "{}")
        if data then
            data = SlashMoon.Tasks.NormalizeMapConfig(data)
            SlashMoon.Tasks.MapConfig = data
            
            -- DEBUG: Проверяем что загрузилось
            local taskCount = data.tasks and table.Count(data.tasks) or 0
            local hasGenerator = data.tasks and data.tasks.generator ~= nil or false
            SlashMoon.Debug(string.format("[SN Tasks] Конфиг карты %s загружен. tasks=%d, hasGenerator=%s", 
                game.GetMap(), taskCount, tostring(hasGenerator)))
            
            if hasGenerator and data.tasks.generator.generator_positions then
                SlashMoon.Debug(string.format("[SN Tasks] Generator позиций в конфиге: %d", 
                    #data.tasks.generator.generator_positions))
            end
            return
        end
    end

    SlashMoon.Tasks.MapConfig = { rotation = {}, tasks = {} }
    SlashMoon.Debug("[SN Tasks] Создан пустой конфиг для " .. game.GetMap())
end

function SlashMoon.Tasks.SaveMapConfig()
    if not file.IsDir(CONFIG_DIR, "DATA") then file.CreateDir(CONFIG_DIR) end
    SlashMoon.Tasks.MapConfig = SlashMoon.Tasks.NormalizeMapConfig(SlashMoon.Tasks.MapConfig)
    local path = SlashMoon.Tasks.GetConfigPath()
    local tempPath = CONFIG_DIR .. "/" .. game.GetMap() .. ".tmp.json"
    local json = util.TableToJSON(SlashMoon.Tasks.MapConfig, true)
    if not json then
        ErrorNoHalt("[SN Tasks] Failed to encode map config as JSON\n")
        return false
    end

    file.Write(tempPath, json)
    if file.Read(tempPath, "DATA") ~= json then
        file.Delete(tempPath)
        ErrorNoHalt("[SN Tasks] Failed to write temporary map config: " .. tempPath .. "\n")
        return false
    end

    file.Delete(path)
    file.Rename(tempPath, path)

    -- Some Linux hosts mount garrysmod/data on filesystems where rename can fail.
    if file.Read(path, "DATA") ~= json then
        file.Write(path, json)
        file.Delete(tempPath)
    end

    if file.Read(path, "DATA") ~= json then
        ErrorNoHalt("[SN Tasks] Failed to save map config: " .. path .. "\n")
        return false
    end

    SlashMoon.Debug("[SN Tasks] Конфиг карты сохранен.")
    return true
end

-- ── Спавн всех заданий ────────────────────────────────────────────────
function SlashMoon.Tasks.SpawnAll(cfg)
    SlashMoon.Debug("[SN Material Debug] SpawnAll BEGIN: cfg=", tostring(cfg), " tasks=", tostring(cfg and cfg.tasks and table.Count(cfg.tasks) or -1))
    SlashMoon.Tasks.CleanupAll()

    cfg = cfg or SlashMoon.Tasks.RoundConfig or SlashMoon.Tasks.MapConfig
    if not cfg then
        SlashMoon.Debug("[SN Material Debug] SpawnAll STOP: cfg is nil")
        return
    end

    -- ── Зарядные станции (не привязаны к tasks, отдельный список) ────────
    for _, info in ipairs(cfg.charging_station_positions or {}) do
        local pos = Vector(info.pos.x, info.pos.y, info.pos.z)
        local ang = Angle(
            info.ang and info.ang.p or 0,
            info.ang and info.ang.y or 0,
            info.ang and info.ang.r or 0
        )
        local ent = ents.Create("sn_charging_station")
        if not IsValid(ent) then continue end
        ent:SetPos(pos)
        ent:SetAngles(ang)
        ent:Spawn()
        if not IsValid(ent) then continue end
        ent:Activate()
        table.insert(SlashMoon.Tasks.SpawnedEnts, ent)
    end

    -- ── Верстаки (не привязаны к tasks, отдельный список) ────────────────
    for _, info in ipairs(cfg.workbench_positions or {}) do
        local pos = Vector(info.pos.x, info.pos.y, info.pos.z)
        local ang = Angle(
            info.ang and info.ang.p or 0,
            info.ang and info.ang.y or 0,
            info.ang and info.ang.r or 0
        )
        local ent = ents.Create("sn_workbench")
        if not IsValid(ent) then continue end
        ent:SetPos(pos)
        ent:SetAngles(ang)
        ent:Spawn()
        if not IsValid(ent) then continue end
        ent:Activate()
        table.insert(SlashMoon.Tasks.SpawnedEnts, ent)
    end

    -- Ротация сохраняет таски раунда в SlashMoon.Tasks.RoundTasks
    -- (чтобы не уничтожать оригинальный MapConfig)
    local tasksToSpawn = cfg.tasks or SlashMoon.Tasks.RoundTasks
    if not tasksToSpawn then
        SlashMoon.Debug("[SN Material Debug] SpawnAll STOP: tasksToSpawn is nil, SN_AfterSpawnTasks will NOT run")
        return
    end

    for taskKey, taskData in pairs(tasksToSpawn) do
        local def = SlashMoon.Tasks.Get(taskData._taskType or taskKey)
        if not def or not isfunction(def.spawn) then continue end

        local ok, result = pcall(def.spawn, taskData, SlashMoon.Tasks.SpawnedEnts)
        if ok and istable(result) then
            if result._subtasks then
                result._subtasks = nil
                for subID, subState in pairs(result) do
                    if istable(subState) then
                        subState.done = subState.done or false
                        subState.failed = subState.failed or false
                        SlashMoon.Tasks.ActiveState[subID] = subState
                        SlashMoon.Debug("[SN Tasks] Подзадание: " .. subID)
                    end
                end
            else
                result.done = result.done or false
                result.failed = result.failed or false
                SlashMoon.Tasks.ActiveState[taskKey] = result
                SlashMoon.Debug("[SN Tasks] Задание: " .. taskKey)
            end
        elseif ok then
            -- spawn вернул не таблицу — это не ошибка, просто нет стейта
            SlashMoon.Debug("[SN Tasks] Задание " .. taskKey .. ": spawn вернул не таблицу, пропущено.")
        else
            -- pcall упал — реальная ошибка
            SlashMoon.Warn("[SN Tasks] ОШИБКА спавна " .. taskKey .. ": " .. tostring(result))
        end
    end

    SlashMoon.Tasks.SyncTasksToClients()

    -- Хук: после спавна заданий (для спавна материалов и т.д.)
    SlashMoon.Debug("[SN Material Debug] SpawnAll: firing SN_AfterSpawnTasks, tracked entities=", tostring(#SlashMoon.Tasks.SpawnedEnts))
    hook.Run("SN_AfterSpawnTasks", SlashMoon.Tasks.SpawnedEnts)
    SlashMoon.Debug("[SN Material Debug] SpawnAll END")
end

-- ── Респавн заданий (с procgen hook) ─────────────────────────────────
function SlashMoon.Tasks.SpawnWithProcgen()
    SlashMoon.Debug("[SN Material Debug] SpawnWithProcgen BEGIN: MapConfig=", tostring(SlashMoon.Tasks.MapConfig), " mapTasks=", tostring(SlashMoon.Tasks.MapConfig and SlashMoon.Tasks.MapConfig.tasks and table.Count(SlashMoon.Tasks.MapConfig.tasks) or -1))
    local cfg = table.Copy(SlashMoon.Tasks.MapConfig or {})
    if SlashMoon.Tasks.BuildRoundRotation then SlashMoon.Tasks.BuildRoundRotation(cfg) end
    if SlashMoon.ProcGen and SlashMoon.ProcGen.Apply then SlashMoon.ProcGen.Apply(cfg) end
    SlashMoon.Tasks.RoundConfig = cfg
    local materialCfg = cfg.material_spawn
    SlashMoon.Debug("[SN Material Debug] SpawnWithProcgen config: material_spawn=", tostring(materialCfg), " mode=", tostring(materialCfg and materialCfg.mode), " countTypes=", tostring(materialCfg and materialCfg.navmesh and table.Count(materialCfg.navmesh.counts or {}) or -1), " positions=", tostring(materialCfg and #(materialCfg.config_positions or {}) or -1))
    hook.Run("SN_BeforeSpawnTasks", cfg)
    SlashMoon.Tasks.SpawnAll(cfg)
end

-- ── Очистка ───────────────────────────────────────────────────────────
function SlashMoon.Tasks.CleanupAll()
    for _, ent in ipairs(SlashMoon.Tasks.SpawnedEnts) do
        if IsValid(ent) then ent:Remove() end
    end
    table.Empty(SlashMoon.Tasks.SpawnedEnts)

    for taskID, state in pairs(SlashMoon.Tasks.ActiveState) do
        local def = SlashMoon.Tasks.Get(taskID)
        if def and isfunction(def.cleanup) then
            local ok, err = pcall(def.cleanup, state)
            if not ok then
                SlashMoon.Warn("[SN Tasks] cleanup err " .. taskID .. ": " .. tostring(err))
            end
        end
    end
    table.Empty(SlashMoon.Tasks.ActiveState)
end

-- ── Тик Заданий (Think) — 0.2с как в fh_interactive ──────────────────
-- Используем MODULE:Hook("Think") с кулдауном вместо timer.Create
-- Это даёт более плавное реагирование и не блокирует таймер
local nextThinkCheck = 0
local THINK_INTERVAL = 0.2  -- 0.2с = 5 тиков/сек (как fh_interactive)

MODULE:Hook("Think", "SN_Tasks_Think", function()
    if CurTime() < nextThinkCheck then return end
    nextThinkCheck = CurTime() + THINK_INTERVAL

    local anyChange = false

    for taskID, state in pairs(SlashMoon.Tasks.ActiveState) do
        if state.done or state.failed then continue end

        local def = SlashMoon.Tasks.Get(taskID)
        if not def or not isfunction(def.think) then continue end

        local prevDone, prevFail = state.done, state.failed
        local ok, err = pcall(def.think, state)

        if not ok then
            -- Логируем ошибку think (как fh_interactive)
            SlashMoon.Warn("[SN Tasks] think err " .. taskID .. ": " .. tostring(err))
            continue
        end

        if state.done ~= prevDone or state.failed ~= prevFail then
            anyChange = true
            if state.failed then
                -- Пер-таск хук: failed
                hook.Run("SN_Task_Failed", taskID, state)
                SlashMoon.Warn("[SN Tasks] FAILED: " .. taskID)
            elseif state.done then
                -- Пер-таск хук: done
                hook.Run("SN_Task_Done", taskID, state)
                SlashMoon.Debug("[SN Tasks] DONE: " .. taskID)
            end
        end
    end

    if anyChange then
        SlashMoon.Tasks.SyncTasksToClients()
        SlashMoon.Tasks.CheckAllCompleted()
    end
end)

-- ── Проверка все ли задания выполнены ─────────────────────────────────
function SlashMoon.Tasks.CheckAllCompleted()
    if table.IsEmpty(SlashMoon.Tasks.ActiveState) then return false end

    local allDone = true
    local anyDone = false
    local anyFailed = false

    for _, v in pairs(SlashMoon.Tasks.ActiveState) do
        if not v.done and not v.failed then allDone = false end
        if v.done then anyDone = true end
        if v.failed then anyFailed = true end
    end

    -- Все задания завершены (done или failed)
    if allDone and anyDone then
        hook.Run("SN_Tasks_AllCompleted")
        return true
    end

    -- Все провалены (ни одного done)
    if allDone and anyFailed and not anyDone then
        hook.Run("SN_Tasks_AllFailed")
        return true
    end

    return false
end

-- ── Синхронизация клиенту ─────────────────────────────────────────────
function SlashMoon.Tasks.SyncTasksToClients(ply)
    local safe = {}
    for k, v in pairs(SlashMoon.Tasks.ActiveState) do
        local baseID = string.match(k, "^(.-)_%d+$") or k
        safe[k] = {
            done        = v.done or false,
            failed      = v.failed or false,
            displayKey  = v.displayKey or v.nameKey or "sn.task." .. k .. ".name",
            displayArgs = v.displayArgs,
            displayName = v.displayName or k,
            descriptionKey = v.descriptionKey or "sn.task." .. baseID .. ".hint",
            descriptionArgs = v.descriptionArgs,
        }
    end

    net.Start("SN_Tasks_SyncList")
    net.WriteTable(safe)
    if ply then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

-- Запрос синхронизации с анти-спамом
MODULE:Receive("SN_Tasks_RequestSyncList", function(len, ply)
    if not IsValid(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "task_sync_request", 2.0) then return end
    SlashMoon.Tasks.SyncTasksToClients(ply)
end)

-- ── Хуки жизненного цикла ─────────────────────────────────────────────

-- Загрузка конфига при старте
MODULE:Hook("InitPostEntity", "SN_Tasks_LoadMap", SlashMoon.Tasks.LoadMapConfig)

-- Очистка при конце раунда
MODULE:Hook("SN_Game_RoundEnd", "SN_Tasks_RoundEnd", function()
    SlashMoon.Tasks.RoundTasks = nil  -- Сбрасываем таски раунда
    SlashMoon.Tasks.RoundConfig = nil
    SlashMoon.Tasks.CleanupAll()
    SlashMoon.Tasks.SyncTasksToClients()
end)

-- Очистка при cleanup map (Важный фикс — раньше этого не было!)
MODULE:Hook("PostCleanupMap", "SN_Tasks_CleanupMap", function()
    -- Cleanup всех заданий
    for taskID, state in pairs(SlashMoon.Tasks.ActiveState) do
        local def = SlashMoon.Tasks.Get(taskID)
        if def and isfunction(def.cleanup) then
            pcall(def.cleanup, state)
        end
    end
    -- Перезагрузка конфига
    SlashMoon.Tasks.RoundTasks = nil  -- Сбрасываем таски раунда
    SlashMoon.Tasks.RoundConfig = nil
    SlashMoon.Tasks.LoadMapConfig()
    table.Empty(SlashMoon.Tasks.SpawnedEnts)
    table.Empty(SlashMoon.Tasks.ActiveState)
end)

-- ── Debug Concommand (как fhi_debug в fh_interactive) ────────────────
MODULE:Command("sn_tasks_debug", function(ply)
    if IsValid(ply) and not SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_manage") then return end

    MsgC(Color(255, 215, 0), "═══ SN Tasks Debug ═══\n")
    MsgC(Color(200, 200, 200), string.format("  MapConfig tasks: %d\n", table.Count(SlashMoon.Tasks.MapConfig.tasks or {})))
    MsgC(Color(200, 200, 200), string.format("  ActiveState: %d\n", table.Count(SlashMoon.Tasks.ActiveState)))
    MsgC(Color(200, 200, 200), string.format("  SpawnedEnts: %d\n", #SlashMoon.Tasks.SpawnedEnts))

    for id, st in pairs(SlashMoon.Tasks.ActiveState) do
        local statusStr = st.done and "DONE" or (st.failed and "FAILED" or "ACTIVE")
        local statusCol = st.done and Color(0, 255, 100) or (st.failed and Color(255, 80, 50) or Color(200, 200, 200))
        MsgC(statusCol, string.format("  %s: %s name=%s\n", id, statusStr, tostring(st.displayName)))
    end

    MsgC(Color(255, 215, 0), "═══════════════════════\n")
end)

-- ── Экспорт (как в fh_interactive) ───────────────────────────────────
SlashMoon.Tasks.GetTaskState   = function() return SlashMoon.Tasks.ActiveState end
SlashMoon.Tasks.GetSpawnedEnts = function() return SlashMoon.Tasks.SpawnedEnts end
SlashMoon.Tasks.RespawnTasks   = SlashMoon.Tasks.SpawnAll
