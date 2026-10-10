-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Server Player Statistics Tracker
-- ========================================================
if not SERVER then return end

SlashMoon.Stats = SlashMoon.Stats or {}
SlashMoon.Stats.PlayerData = SlashMoon.Stats.PlayerData or {}

util.AddNetworkString("SN_Stats_RoundEnd")
util.AddNetworkString("SN_Round_Ended")

-- ── Инициализация статистики игрока ───────────────────────────────────
local function InitPlayerStats(ply)
    if not IsValid(ply) then return end
    
    SlashMoon.Stats.PlayerData[ply] = {
        tasksCompleted = 0,
        tasksFailed = 0,
        damageDealt = 0,
        damageTaken = 0,
        timeAlive = 0,
        timeSurvived = 0,
        kills = 0,
        deaths = 0,
        generatorsFueled = 0,
        itemsPickedUp = 0,
        distanceTraveled = 0,
        lastPos = nil,
        escaped = false,
        wasAnimatronic = false,
        startTime = CurTime(),
    }
end

-- ── Сброс статистики всех игроков ─────────────────────────────────────
function SlashMoon.Stats.ResetAll()
    table.Empty(SlashMoon.Stats.PlayerData)
    
    for _, ply in ipairs(player.GetAll()) do
        InitPlayerStats(ply)
    end
    
    SlashMoon.Debug("[Stats] Статистика игроков сброшена")
end

-- ── Получение статистики игрока ───────────────────────────────────────
function SlashMoon.Stats.Get(ply)
    if not IsValid(ply) then return nil end
    return SlashMoon.Stats.PlayerData[ply]
end

-- ── Увеличение счетчика ───────────────────────────────────────────────
function SlashMoon.Stats.Increment(ply, key, amount)
    if not IsValid(ply) then return end
    local stats = SlashMoon.Stats.Get(ply)
    if not stats then return end
    
    stats[key] = (stats[key] or 0) + (amount or 1)
end

-- ── Установка флага ───────────────────────────────────────────────────
function SlashMoon.Stats.SetFlag(ply, key, value)
    if not IsValid(ply) then return end
    local stats = SlashMoon.Stats.Get(ply)
    if not stats then return end
    
    stats[key] = value
end

-- ── Обновление времени выживания ──────────────────────────────────────
function SlashMoon.Stats.UpdateSurvivalTime()
    local now = CurTime()
    
    for _, ply in ipairs(player.GetAll()) do
        if SlashMoon.Tasks.Game.IsSurvivor(ply) then
            local stats = SlashMoon.Stats.Get(ply)
            if stats and stats.startTime then
                stats.timeSurvived = now - stats.startTime
                stats.timeAlive = stats.timeSurvived
            end
        end
    end
end

-- ── Сбор и отправка финальной статистики ──────────────────────────────
function SlashMoon.Stats.SendRoundEndStats()
    SlashMoon.Stats.UpdateSurvivalTime()
    
    local statsTable = {}
    
    for ply, data in pairs(SlashMoon.Stats.PlayerData) do
        if IsValid(ply) then
            table.insert(statsTable, {
                steamID = ply:SteamID(),
                nick = ply:Nick(),
                tasksCompleted = data.tasksCompleted or 0,
                tasksFailed = data.tasksFailed or 0,
                damageDealt = math.floor(data.damageDealt or 0),
                damageTaken = math.floor(data.damageTaken or 0),
                timeSurvived = math.floor(data.timeSurvived or 0),
                kills = data.kills or 0,
                deaths = data.deaths or 0,
                generatorsFueled = data.generatorsFueled or 0,
                itemsPickedUp = data.itemsPickedUp or 0,
                distanceTraveled = math.floor((data.distanceTraveled or 0) / 40), -- в условных "метрах"
                escaped = data.escaped or false,
                wasAnimatronic = data.wasAnimatronic or false,
            })
        end
    end
    
    -- Сортировка по времени выживания (убывание)
    table.sort(statsTable, function(a, b)
        if a.escaped ~= b.escaped then return a.escaped end
        return a.timeSurvived > b.timeSurvived
    end)
    
    net.Start("SN_Stats_RoundEnd")
    net.WriteTable(statsTable)
    net.Broadcast()
    SlashMoon.Stats.LastRoundStats = statsTable
    
    SlashMoon.Debug(string.format("[Stats] Отправлена статистика %d игроков", #statsTable))
end

-- ── Отправка сообщения о завершении раунда ───────────────────────────
function SlashMoon.Stats.SendRoundEnd(survivorsWon, reason)
    net.Start("SN_Round_Ended")
    net.WriteBool(survivorsWon)
    net.WriteString(reason or "")
    net.WriteTable(SlashMoon.Stats.LastRoundStats or {})
    net.Broadcast()
    
    SlashMoon.Debug(string.format("[Stats] Раунд завершён: %s", survivorsWon and "Выжившие победили" or "Аниматроники победили"))
end

-- ── Хуки отслеживания событий ─────────────────────────────────────────

-- Старт раунда - сброс статистики
MODULE:Hook("SN_Game_RoundStart", "SN_Stats_OnRoundStart", function()
    SlashMoon.Stats.LastRoundStats = nil
    SlashMoon.Stats.ResetAll()
end)

-- Задание выполнено
MODULE:Hook("SN_Task_Done", "SN_Stats_OnTaskComplete", function(taskKey)
    for _, ply in ipairs(player.GetAll()) do
        if SlashMoon.Tasks.Game.IsSurvivor(ply) then
            SlashMoon.Stats.Increment(ply, "tasksCompleted", 1)
        end
    end
    SlashMoon.Debug(string.format("[Stats] Выжившим засчитано выполненное задание %s", taskKey))
end)

-- Задание провалено
MODULE:Hook("SN_Task_Failed", "SN_Stats_OnTaskFail", function(taskKey, reason)
    for _, ply in ipairs(player.GetAll()) do
        if SlashMoon.Tasks.Game.IsSurvivor(ply) then
            SlashMoon.Stats.Increment(ply, "tasksFailed", 1)
        end
    end
end)

-- Урон нанесен
MODULE:Hook("EntityTakeDamage", "SN_Stats_OnDamage", function(target, dmg)
    local attacker = dmg:GetAttacker()
    local amount = dmg:GetDamage()
    
    if IsValid(attacker) and attacker:IsPlayer() then
        SlashMoon.Stats.Increment(attacker, "damageDealt", amount)
    end
    
    if IsValid(target) and target:IsPlayer() then
        SlashMoon.Stats.Increment(target, "damageTaken", amount)
    end
end)

-- Смерть игрока
MODULE:Hook("PlayerDeath", "SN_Stats_OnPlayerDeath", function(victim, inflictor, attacker)
    if IsValid(victim) then
        if not victim:GetNW2Bool("fhi_escaped", false) then
            SlashMoon.Stats.Increment(victim, "deaths", 1)
        end
        
        local stats = SlashMoon.Stats.Get(victim)
        if stats and stats.startTime then
            stats.timeSurvived = CurTime() - stats.startTime
        end
    end
    
    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        SlashMoon.Stats.Increment(attacker, "kills", 1)
    end
end)

-- Игрок сбежал
MODULE:Hook("SN_Player_Escaped", "SN_Stats_OnEscape", function(ply)
    if IsValid(ply) then
        SlashMoon.Stats.SetFlag(ply, "escaped", true)
        SlashMoon.Debug(string.format("[Stats] %s сбежал!", ply:Nick()))
    end
end)

-- Генератор заправлен
MODULE:Hook("SN_Task_Done", "SN_Stats_OnGeneratorFueled", function(taskKey, state)
    if not string.StartWith(taskKey, "generator_") then return end
    -- Ищем кто стоял рядом с генератором
    local gen = state.generator
    if not IsValid(gen) then return end
    for _, ply in ipairs(player.GetAll()) do
        if SlashMoon.Tasks.Game.IsSurvivor(ply) then
            if ply:GetPos():Distance(gen:GetPos()) < 200 then
                SlashMoon.Stats.Increment(ply, "generatorsFueled", 1)
                break
            end
        end
    end
end)

-- Предмет подобран
MODULE:Hook("SN_Item_PickedUp", "SN_Stats_OnItemPickup", function(ply, class)
    if IsValid(ply) then
        SlashMoon.Stats.Increment(ply, "itemsPickedUp", 1)
    end
end)

-- Дистанция — считаем каждую секунду
MODULE:Timer("SN_Stats_DistanceTrack", 1, 0, function()
    if not (SlashMoon.Phase and SlashMoon.Phase.State and SlashMoon.Phase.State.active) then return end
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        local stats = SlashMoon.Stats.Get(ply)
        if not stats then continue end
        local curPos = ply:GetPos()
        if stats.lastPos then
            stats.distanceTraveled = (stats.distanceTraveled or 0) + curPos:Distance(stats.lastPos)
        end
        stats.lastPos = curPos
    end
end)

-- Определение роли (аниматроник/выживший)
MODULE:Hook("SN_Game_RoundStart", "SN_Stats_SetRoles", function()
    timer.Simple(1, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                local isAnim = SlashMoon.Tasks.Game.IsAnimatronic(ply)
                SlashMoon.Stats.SetFlag(ply, "wasAnimatronic", isAnim)
            end
        end
    end)
end)

-- Обновление времени выживания каждую секунду
MODULE:Timer("SN_Stats_UpdateSurvivalTime", 1, 0, function()
    if SlashMoon.Rounds.GetState and SlashMoon.Rounds.GetState() == SlashMoon.Rounds.STATE_ACTIVE then
        SlashMoon.Stats.UpdateSurvivalTime()
    end
end)

-- Инициализация для подключившихся игроков
MODULE:Hook("PlayerInitialSpawn", "SN_Stats_OnJoin", function(ply)
    InitPlayerStats(ply)
end)

local lastRoundEndHandled = -math.huge

local function HandleRoundEnd(modeResult, modeReason, fromFH)
    if CurTime() - lastRoundEndHandled < 1 then return end
    lastRoundEndHandled = CurTime()

    -- Определяем победителя по количеству сбежавших
    local escapedCount = 0
    for ply, data in pairs(SlashMoon.Stats.PlayerData) do
        if IsValid(ply) and data.escaped then
            escapedCount = escapedCount + 1
        end
    end
    
    local survivorsWon
    if fromFH then
        survivorsWon = modeResult ~= true
    elseif SlashMoon.Tasks.Game.IsStandalone() then
        survivorsWon = modeResult == true
    else
        survivorsWon = escapedCount > 0
    end
    local reason = isstring(modeReason) and modeReason
        or (survivorsWon and "sn.round.survivors_escaped" or "sn.round.anim_destroyed")
    
    -- СНАЧАЛА отправляем статистику, ПОТОМ — сигнал конца раунда
    SlashMoon.Stats.SendRoundEndStats()
    
    timer.Simple(0.5, function()
        SlashMoon.Stats.SendRoundEnd(survivorsWon, reason)
    end)
end

-- Завершение раунда
MODULE:Hook("SN_Game_RoundEnd", "SN_Stats_OnRoundEnd", function(modeResult, modeReason)
    HandleRoundEnd(modeResult, modeReason, SlashMoon.Tasks.Game.IsFH())
end)

-- Прямой FH fallback: гарантирует отправку экрана в том числе наблюдателям.
MODULE:Hook("fh_postendgame", "SN_Stats_FH_RoundEndFallback", function(killerVictory)
    if not SlashMoon.Tasks.Game.IsFH() then return end
    HandleRoundEnd(killerVictory, killerVictory and "sn.round.anim_destroyed" or "sn.round.survivors_escaped", true)
end)

SlashMoon.Debug("[Stats] Система статистики игроков загружена")
