-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Gamemode: Server Round Controller (Dual Mode)
-- ========================================================
if not SERVER then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Config = SlashMoon.Tasks.Config or {}

-- true  = Работаем как аддон поверх Fazbear's Hunt (Текущий режим)
-- false = Работаем как собственный автономный режим (Будущий режим)
SlashMoon.Tasks.Config.UseFHIntegration = SlashMoon.Tasks.Game.IsFH()

util.AddNetworkString("SN_Round_StateChanged")
util.AddNetworkString("SN_Round_Ended")

-- ========================================================
-- РЕЖИМ 1: Интеграция с Fazbear's Hunt (Текущий)
-- ========================================================
MODULE:Hook("SN_Game_RoundStart", "SN_Tasks_OnStart", function()
    SlashMoon.Debug("[SN Tasks] Раунд начался в режиме " .. SlashMoon.Tasks.Game.GetMode())
    SlashMoon.Debug("[SN Material Debug] SN_Game_RoundStart received: mode=", tostring(SlashMoon.Tasks.Game.GetMode()), " map=", game.GetMap())

    -- SpawnWithProcgen() внутри вызывает:
    --   1. hook.Run("SN_BeforeSpawnTasks") → BuildRoundRotation() (роунд + фазовые длительности)
    --   2. SpawnAll() (спавн сущностей)
    -- НЕ вызываем BuildRoundRotation() отдельно — иначе двойной раунд!
    SlashMoon.Tasks.SpawnWithProcgen()

    -- Фаза управляется sv_phase.lua автоматически через MODULE:Hook("fh_poststartgame")
end)

MODULE:Hook("SN_Game_RoundEnd", "SN_Tasks_OnEnd", function()
    SlashMoon.Debug("[SN Tasks] Раунд завершен. Очищаем задания...")
end)

MODULE:Hook("PostCleanupMap", "SN_Tasks_FH_OnCleanup", function()
    if SlashMoon.Phase and SlashMoon.Phase.CleanupRound then SlashMoon.Phase.CleanupRound() end
end)

-- ========================================================
-- РЕЖИМ 2: Собственная Автономная Машина Состояний (Будущее)
-- ========================================================
local standaloneCfg = SlashMoon.Tasks.Config.Standalone or {}
local PREPARE_TIME = standaloneCfg.prepareTime or 10
local END_TIME     = standaloneCfg.endTime or 10
local MIN_PLAYERS  = standaloneCfg.minPlayers or 1
local stateGeneration = 0

function SlashMoon.Rounds.SetState(newState, duration)
    stateGeneration = stateGeneration + 1
    local oldState = SlashMoon.Rounds.GetState()
    SetGlobal2Int("SN_RoundState", newState)
    SetGlobal2Float("SN_StateEndTime", CurTime() + (duration or 0))

    net.Start("SN_Round_StateChanged")
    net.WriteInt(newState, 4)
    net.WriteFloat(CurTime() + (duration or 0))
    net.Broadcast()

    SlashMoon.Debug(string.format("[State Machine] Смена состояния: %s ➔ %s (%d сек)", SlashMoon.Rounds.GetStateName(oldState), SlashMoon.Rounds.GetStateName(newState), duration or 0))

    if newState == SlashMoon.Rounds.STATE_PREPARE then
        SlashMoon.Rounds.StartPreparePhase()
    elseif newState == SlashMoon.Rounds.STATE_ACTIVE then
        SlashMoon.Rounds.StartActivePhase()
    elseif newState == SlashMoon.Rounds.STATE_ENDED then
        SlashMoon.Rounds.StartEndedPhase()
    end
end

function SlashMoon.Rounds.StartPreparePhase()
    SlashMoon.Tasks.CleanupAll()
    local players = player.GetAll()
    if #players < MIN_PLAYERS then SlashMoon.Rounds.SetState(SlashMoon.Rounds.STATE_WAITING, 0) return end

    table.Shuffle(players)
    local animatronic = players[1]

    for _, ply in ipairs(players) do
        ply:UnSpectate()
        ply:SetNW2Bool("fhi_escaped", false)
        
        if ply == animatronic then
            ply:SetTeam(SlashMoon.Tasks.Game.GetTeam("animatronic"))
            SlashMoon.Tasks.SendLocalizedChat(ply, "sn.round.you_anim")
        else
            ply:SetTeam(SlashMoon.Tasks.Game.GetTeam("survivor"))
            SlashMoon.Tasks.SendLocalizedChat(ply, "sn.round.you_surv")
        end

        ply:Spawn()
        ply:Freeze(true)
    end
end

function SlashMoon.Rounds.StartActivePhase()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then ply:Freeze(false) end
    end

    hook.Run("SN_Game_RoundStart")
end

function SlashMoon.Rounds.StartEndedPhase()
    SlashMoon.Tasks.CleanupAll()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then ply:Freeze(true) end
    end

    local generation = stateGeneration
    MODULE:Timer("SN_StateMachine_EndDelay", END_TIME, 1, function()
        if generation ~= stateGeneration or SlashMoon.Rounds.GetState() ~= SlashMoon.Rounds.STATE_ENDED then return end
        if #player.GetAll() >= MIN_PLAYERS then
            SlashMoon.Rounds.SetState(SlashMoon.Rounds.STATE_PREPARE, PREPARE_TIME)
        else
            SlashMoon.Rounds.SetState(SlashMoon.Rounds.STATE_WAITING, 0)
        end
    end)
end

function SlashMoon.Rounds.CheckWinConditions()
    if SlashMoon.Tasks.Config.UseFHIntegration then return end -- В режиме FH проверки делает сам FH
    if SlashMoon.Rounds.GetState() ~= SlashMoon.Rounds.STATE_ACTIVE then return end

    local aliveSurvivors = 0
    local aliveAnimatronics = 0

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            if SlashMoon.Tasks.Game.IsSurvivor(ply) then
                aliveSurvivors = aliveSurvivors + 1
            elseif SlashMoon.Tasks.Game.IsAnimatronic(ply) then
                aliveAnimatronics = aliveAnimatronics + 1
            end
        end
    end

    if aliveSurvivors == 0 then
        SlashMoon.Rounds.Finish(false, "sn.round.anim_destroyed")
        return
    end

    if aliveAnimatronics == 0 then
        SlashMoon.Rounds.Finish(true, "sn.round.survivors_won")
        return
    end
end

function SlashMoon.Rounds.Finish(survivorsWon, reason)
    if SlashMoon.Rounds.GetState() == SlashMoon.Rounds.STATE_ENDED then return end

    hook.Run("SN_Game_RoundEnd", survivorsWon, reason)
    SlashMoon.Rounds.SetState(SlashMoon.Rounds.STATE_ENDED, END_TIME)
end

-- Автоматический тикер (работает только если отключена интеграция с FH)
MODULE:Timer("SN_StateMachine_Tick", 1, 0, function()
    if not SlashMoon.Tasks.Game.IsStandalone() then return end

    local state = SlashMoon.Rounds.GetState()
    local timeTotalLeft = SlashMoon.Rounds.GetStateTimeLeft()

    if state == SlashMoon.Rounds.STATE_WAITING then
        if #player.GetAll() >= MIN_PLAYERS then SlashMoon.Rounds.SetState(SlashMoon.Rounds.STATE_PREPARE, PREPARE_TIME) end
    elseif state == SlashMoon.Rounds.STATE_PREPARE then
        if timeTotalLeft <= 0 then SlashMoon.Rounds.SetState(SlashMoon.Rounds.STATE_ACTIVE, 0) end
    elseif state == SlashMoon.Rounds.STATE_ACTIVE then
        SlashMoon.Rounds.CheckWinConditions()
    end
end)

-- ── Команды ───────────────────────────────────────────────────────────
MODULE:Command("sn_tasks_force_spawn", function(ply)
    if IsValid(ply) and not SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_manage") then return end
    SlashMoon.Tasks.SpawnWithProcgen()
    if IsValid(ply) then SlashMoon.Tasks.SendLocalizedChat(ply, "sn.task.force_spawn") end
end)

MODULE:Command("sn_tasks_force_clear", function(ply)
    if IsValid(ply) and not SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_manage") then return end
    SlashMoon.Tasks.CleanupAll()
    if IsValid(ply) then SlashMoon.Tasks.SendLocalizedChat(ply, "sn.task.force_clear") end
end)
