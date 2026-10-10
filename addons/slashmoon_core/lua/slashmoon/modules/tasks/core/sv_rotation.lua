-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Движок Ротации и Генерации Раунда (Fixed v2)
-- ========================================================
-- ВАЖНО: BuildRoundRotation() сохраняет результат в SlashMoon.Tasks.RoundTasks,
--         а НЕ в MapConfig.tasks (чтобы не уничтожать оригинальный конфиг карты).
--         SpawnAll() читает из SlashMoon.Tasks.RoundTasks.
-- ========================================================
if not SERVER then return end

SlashMoon.Tasks.RoundCount = 0
SlashMoon.Tasks.RoundTasks = nil  -- Таски текущего раунда (отдельно от MapConfig)

local function GetAliveSurvivorsCount()
    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        if SlashMoon.Tasks.Game.IsSurvivor(ply) then count = count + 1 end
    end
    return math.max(count, 1)
end

-- ── Установка длительностей фаз ────────────────────────────────────────
-- Прямая запись в SlashMoon.Phase.Config (вместо несуществующего SN_Lib.Phase.SetDurations)
local function SetPhaseDurations(taskDur, escapeDur)
    if SlashMoon.Phase and SlashMoon.Phase.Config then
        SlashMoon.Phase.Config.TASK_DURATION   = taskDur
        SlashMoon.Phase.Config.ESCAPE_DURATION = escapeDur
    else
        SlashMoon.Debug("[Ротация] ВНИМАНИЕ: SlashMoon.Phase.Config не доступен!")
    end
end

function SlashMoon.Tasks.BuildRoundRotation(cfg)
    SlashMoon.Tasks.RoundCount = SlashMoon.Tasks.RoundCount + 1
    cfg = cfg or table.Copy(SlashMoon.Tasks.MapConfig or {})
    local rotSettings = cfg.rotation or {}
    
    local survCount = GetAliveSurvivorsCount()
    local newTasks = {}

    -- 1. Проверка на "Чистое Выживание"
    local pattern = rotSettings.survival_pattern or { false, false, true }
    local patternIdx = ((SlashMoon.Tasks.RoundCount - 1) % #pattern) + 1
    
    if pattern[patternIdx] then
        if SlashMoon.Tasks.Registry["survival"] then
            newTasks["survival"] = table.Copy(cfg.tasks["survival"] or {})
            newTasks["survival"]._taskType = "survival"
            
            SetPhaseDurations(rotSettings.survival_duration or 540, rotSettings.escape_duration or 90)
            
            -- СОХРАНЯЕМ В RoundTasks, А НЕ В cfg.tasks!
            SlashMoon.Tasks.RoundTasks = newTasks
            cfg.tasks = newTasks
            SlashMoon.Debug(string.format("[Ротация] Раунд #%d -> ЧИСТОЕ ВЫЖИВАНИЕ", SlashMoon.Tasks.RoundCount))
            return
        end
    end

    -- 2. Обычный раунд
    SetPhaseDurations(rotSettings.task_duration or 600, rotSettings.escape_duration or 120)

    -- 3. Динамический сбор заданий из Реестра
    for taskID, taskDef in pairs(SlashMoon.Tasks.Registry) do
        local rules = taskDef.rotation
        if not rules then continue end
        
        local taskKey = taskID .. "_1"
        -- Читаем базовый конфиг из ОРИГИНАЛЬНОГО MapConfig (не из RoundTasks!)
        local baseCfg = (cfg.tasks and cfg.tasks[taskID]) or {}

        if survCount < (rules.minSurvivors or 1) then continue end
        if baseCfg.enabled == false then continue end

        -- Per-map chance is exposed as an editor-friendly percentage. The
        -- task's static chance remains a 0..1 fallback for legacy tasks.
        local mapChance = tonumber(baseCfg.chance)
        if mapChance ~= nil and math.random(0, 100) > math.Clamp(mapChance, 0, 100) then continue end
        if mapChance == nil and rules.chance and math.random() > rules.chance then continue end

        -- DEBUG: Проверяем что конфиг загружен
        if taskID == "generator" then
            local genPosCount = baseCfg.generator_positions and #baseCfg.generator_positions or 0
            SlashMoon.Debug(string.format("[Ротация] generator: позиций=%d, конфиг существует=%s", 
                genPosCount, tostring(cfg.tasks and cfg.tasks[taskID] ~= nil)))
        end

        newTasks[taskKey] = table.Copy(baseCfg)
        newTasks[taskKey]._taskType = taskID

        if rules.calculateRequired then
            newTasks[taskKey].required = rules.calculateRequired(survCount)
        end
    end

    -- СОХРАНЯЕМ В RoundTasks, А НЕ В cfg.tasks!
    SlashMoon.Tasks.RoundTasks = newTasks
    cfg.tasks = newTasks
    SlashMoon.Debug(string.format(
        "[Ротация] Раунд #%d | Выживших: %d | Заданий: %d",
        SlashMoon.Tasks.RoundCount, survCount, table.Count(newTasks)))
end

-- Хук старта раунда (для автономного режима)
MODULE:Hook("SN_RoundStart", "SN_Tasks_GenerateRound", function()
    SlashMoon.Tasks.SpawnWithProcgen()
end)
