-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Server Phase Manager (Task -> Penalty -> Escape)
-- ========================================================
if not SERVER then return end

SlashMoon.Phase = SlashMoon.Phase or {}
SlashMoon.Phase.Config = {
    TASK_DURATION        = 600,
    ESCAPE_DURATION      = 120,
    BUFF_INTERVAL        = 45,
    BUFF_SPEED_MULTI     = 0.67,
    ESCAPE_STAND_TIME    = 3.6,
    ESCAPE_MARKER_RADIUS = 80,
}

local previousState = SlashMoon.Phase.State
if previousState then
    if previousState.timers then
        for name in pairs(previousState.timers) do MODULE:RemoveTimer(name) end
    end
    for ply, speeds in pairs(previousState.baseSpeeds or {}) do
        if IsValid(ply) then
            ply:SetRunSpeed(speeds.run)
            ply:SetWalkSpeed(speeds.walk)
        end
    end
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:SetNW2Bool("fhi_escape_glow", false)
            -- Escape state belongs to one round only. Reset it during the
            -- phase cleanup so it cannot suppress a ragdoll in the next one.
            ply:SetNW2Bool("fhi_escaped", false)
            ply:SetNW2Bool("sn_escaped", false)
            if ply.SN_TasksSuppressedRagdoll then
                ply:SuppressRagdollSpawn(false)
                ply.SN_TasksSuppressedRagdoll = nil
            end
        end
    end
    if previousState.originalHaloCooldown then
        game.ConsoleCommand("halo_cooldown " .. previousState.originalHaloCooldown .. "\n")
    end
    for _, ent in ipairs(previousState.escapeMarkers or {}) do
        if IsValid(ent) then ent:Remove() end
    end
end

SlashMoon.Phase.State = {
    active           = false,
    phase            = "none",
    taskTimeLeft     = 0,
    buffLevel        = 0,
    penaltiesApplied = false,
    baseSpeeds       = {},
    timers           = {},
    escapedPlayers   = {},
    escapedNames     = {},
    escapeMarkers    = {},
    escapeProgress   = {},
    escapeMode       = "none",
    escapeCar        = NULL,
    generation       = 0,
    phaseEndTime     = 0,
}

util.AddNetworkString("fh_phase_update")
util.AddNetworkString("fh_phase_hud_override")
util.AddNetworkString("fhi_escape_marker_spawn")
util.AddNetworkString("fhi_player_escaped")
util.AddNetworkString("fhi_escape_progress")
util.AddNetworkString("fhi_escape_result")
util.AddNetworkString("fhi_escape_glow")
util.AddNetworkString("fh_pause_game_timer")
util.AddNetworkString("fh_timer_cutback")
util.AddNetworkString("fhi_escape_reset")  -- Сброс клиентских маркеров
util.AddNetworkString("SN_Phase_RequestState")

if previousState then
    timer.Simple(0, function()
        net.Start("fhi_escape_glow")
        net.WriteBool(false)
        net.WriteUInt(0, 8)
        net.Broadcast()
        net.Start("fhi_escape_reset")
        net.Broadcast()
        net.Start("fh_phase_hud_override")
        net.WriteBool(false)
        net.Broadcast()
    end)
end

local roundEnding      = false
local _escapeEndCalled = false

local function S() return SlashMoon.Phase.State end
local function C() return SlashMoon.Phase.Config end

local function BroadcastPhase(phase, timeLeft)
    net.Start("fh_phase_update")
    net.WriteString(phase)
    net.WriteFloat(timeLeft)
    net.Broadcast()
end

local function ClearTimers()
    for name in pairs(S().timers) do
        if timer.Exists(name) then MODULE:RemoveTimer(name) end
    end
    table.Empty(S().timers)
end

local function SendPhaseState(ply)
    local state = S()
    if not IsValid(ply) or not state.active or state.phase == "none" then return end

    local timeLeft = state.taskTimeLeft
    if state.phase == "escape" and state.phaseEndTime > 0 then
        timeLeft = math.max(0, state.phaseEndTime - CurTime())
    end

    net.Start("fh_phase_hud_override")
    net.WriteBool(true)
    net.Send(ply)

    net.Start("fh_phase_update")
    net.WriteString(state.phase)
    net.WriteFloat(timeLeft)
    net.Send(ply)
end

local function CreatePhaseTimer(name, delay, repetitions, callback)
    local state = S()
    local generation = state.generation
    if timer.Exists(name) then MODULE:RemoveTimer(name) end
    state.timers[name] = true
    MODULE:Timer(name, delay, repetitions, function()
        if S().generation ~= generation then
            MODULE:RemoveTimer(name)
            return
        end
        callback()
        if repetitions == 1 then S().timers[name] = nil end
    end)
end

-- ── Бафф скорости Аниматроников ───────────────────────────────────────
local function ApplySpeedBuff()
    local state = S(); local cfg = C()
    state.buffLevel = state.buffLevel + 1
    local mult = 1 + cfg.BUFF_SPEED_MULTI * state.buffLevel
    for _, ply in ipairs(SlashMoon.Tasks.Game.GetAnimatronics()) do
        if IsValid(ply) and ply:IsPlayer() and ply:Team() ~= TEAM_SPECTATOR then
            if not state.baseSpeeds[ply] then
                state.baseSpeeds[ply] = { run = ply:GetRunSpeed(), walk = ply:GetWalkSpeed() }
            end
            local b = state.baseSpeeds[ply]
            ply:SetRunSpeed(b.run * mult); ply:SetWalkSpeed(b.walk * mult)
        end
    end
    SlashMoon.Debug(string.format("[Phase] Бафф скорости аниматроников x%d (x%.2f)", state.buffLevel, mult))
end

local function RestoreSpeeds()
    for ply, b in pairs(S().baseSpeeds) do
        if IsValid(ply) then ply:SetRunSpeed(b.run); ply:SetWalkSpeed(b.walk) end
    end
    table.Empty(S().baseSpeeds)
end

-- ── Штрафная Фаза ─────────────────────────────────────────────────────
local function ApplyPenalties()
    local state = S()
    if state.penaltiesApplied then return end
    state.penaltiesApplied = true
    state.phase = "penalty"
    
    local cv = GetConVar("halo_cooldown")
    if cv then
        state.originalHaloCooldown = state.originalHaloCooldown or cv:GetString()
        game.ConsoleCommand("halo_cooldown " .. math.max(30, math.floor(cv:GetInt()/2)) .. "\n")
    end
    
    BroadcastPhase("penalty", state.taskTimeLeft)
    hook.Run("fh_phase_penalty_applied")
    SlashMoon.Debug("[Phase] Включена Штрафная фаза!")
end

-- ── Фаза Заданий ──────────────────────────────────────────────────────
local function StartTaskPhase()
    local state = S(); local cfg = C()
    state.active           = true
    state.phase            = "task"
    state.taskTimeLeft     = cfg.TASK_DURATION
    state.phaseEndTime     = CurTime() + state.taskTimeLeft
    state.buffLevel        = 0
    state.penaltiesApplied = false
    table.Empty(state.baseSpeeds)
    table.Empty(state.escapedPlayers)
    table.Empty(state.escapedNames)
    table.Empty(state.escapeProgress)
    state.escapeMode = "none"
    state.escapeCar = NULL
    state.originalHaloCooldown = nil
    
    -- КРИТИЧНО: Сброс статуса побега у всех игроков при старте раунда
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:SetNW2Bool("fhi_escaped", false)
        end
    end

    if timer.Exists("fh_gamedefault_timer") then MODULE:RemoveTimer("fh_gamedefault_timer") end
    ClearTimers()

    CreatePhaseTimer("fh_phase_task_tick", 1, 0, function()
        local s = S()
        if SlashMoon.Tasks.Game.IsRoundPaused() then return end
        s.taskTimeLeft = s.taskTimeLeft - 1
        BroadcastPhase(s.phase, s.taskTimeLeft)
        if s.taskTimeLeft <= 0 then s.taskTimeLeft = 0; ApplyPenalties() end
    end)
    BroadcastPhase("task", state.taskTimeLeft)
    SlashMoon.Debug("[Phase] Фаза Заданий запущена (" .. state.taskTimeLeft .. " сек).")
end

-- ── Спавн 3D Маркеров Побега ──────────────────────────────────────────
local function SpawnEscapeMarkers()
    local state  = S()
    local cfg = SlashMoon.Tasks.RoundConfig or SlashMoon.Tasks.MapConfig or {}
    local allMarkers = cfg.escape_positions or {}

    for _, e in ipairs(state.escapeMarkers) do if IsValid(e) then e:Remove() end end
    table.Empty(state.escapeMarkers)
    state.escapeMode = "none"
    state.escapeCar = NULL

    if #allMarkers == 0 then
        SlashMoon.Debug("[Phase] ВНИМАНИЕ: На карте нет escape_positions!")
        return
    end

    -- 50% ШАНС: Эвакуационная машина ИЛИ 3D-Зоны
    local useCar = (math.random() <= 0.5)

    if useCar then
        -- Спавним Машину Эвакуации на случайной позиции побега
        local posInfo = allMarkers[math.random(#allMarkers)]
        local car = ents.Create("sn_escape_car")
        if IsValid(car) then
            car:SetPos(Vector(posInfo.pos.x, posInfo.pos.y, posInfo.pos.z))
            car:SetAngles(Angle(posInfo.ang.p, posInfo.ang.y, posInfo.ang.r))
            car:Spawn()
            if IsValid(car) then
                table.insert(state.escapeMarkers, car)
                state.escapeMode = "car"
                state.escapeCar = car
            end
        end

        if state.escapeMode == "car" then
            for _, ply in ipairs(player.GetAll()) do
                SlashMoon.Tasks.SendLocalizedChat(ply, "sn.escape.car_arrived")
            end
            SlashMoon.Debug("[Phase] Режим побега: Эвакуационная машина")
        else
            useCar = false
        end
    end
    if not useCar then
        state.escapeMode = "zone"
        -- Спавним 3D GTA Зоны Побега
        for _, info in ipairs(allMarkers) do
            local ent = ents.Create("prop_dynamic")
            if IsValid(ent) then
                ent:SetModel("models/editor/playerstart.mdl")
                ent:SetPos(Vector(info.pos.x, info.pos.y, info.pos.z))
                ent:SetAngles(Angle(0,0,0))
                ent:Spawn()
                if IsValid(ent) then
                    ent:SetNoDraw(true)
                    ent:SetNWBool("fhi_escape_marker", true)
                    table.insert(state.escapeMarkers, ent)
                end
            end

            net.Start("fhi_escape_marker_spawn")
            net.WriteVector(Vector(info.pos.x, info.pos.y, info.pos.z))
            net.Broadcast()
        end

        for _, ply in ipairs(player.GetAll()) do
            SlashMoon.Tasks.SendLocalizedChat(ply, "sn.escape.zones_activated")
        end
        SlashMoon.Debug("[Phase] Режим побега: 3D-Зоны эвакуации")
    end
end


-- ── Тихая смерть при побеге (без рэгдолла) ───────────────────────────
local function SilentKillPlayer(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    ply:SuppressRagdollSpawn(true)
    ply:StripWeapons()
    ply:KillSilent()
    ply.SN_TasksSuppressedRagdoll = true
    ply:SuppressRagdollSpawn(false)
end

MODULE:Hook("ShouldSpawnRagdoll", "fhi_suppress_escaped_ragdoll", function(ply)
    local state = S()
    if IsValid(ply) and state.active and state.phase == "escape" and state.escapedPlayers[ply] then
        return false
    end
end)

local function AnnounceEscapeResult()
    if _escapeEndCalled or roundEnding then return end
    _escapeEndCalled = true
    roundEnding = true

    local state = S()
    ClearTimers()

    local escaped, notEscaped = {}, {}
    for _, nick in pairs(state.escapedNames) do table.insert(escaped, nick) end

    for _, ply in ipairs(SlashMoon.Tasks.Game.GetSurvivors()) do
        if IsValid(ply) and not state.escapedPlayers[ply] then
            table.insert(notEscaped, ply:Nick())
            SilentKillPlayer(ply)
            local timerName = "fh_phase_spectate_result_" .. ply:SteamID64()
            CreatePhaseTimer(timerName, 0.5, 1, function()
                if IsValid(ply) then
                    SlashMoon.Tasks.Game.SetSpectator(ply, OBS_MODE_ROAMING)
                    SlashMoon.Tasks.Game.RemoveSurvivor(ply)
                end
            end)
        end
    end

    net.Start("fhi_escape_result")
    net.WriteTable(escaped)
    net.WriteTable(notEscaped)
    net.Broadcast()

    if #escaped > 0 then
        CreatePhaseTimer("fh_phase_end_round", 0.5, 1, function() SlashMoon.Tasks.Game.EndRound(true, 8, "escaped") end)
    else
        CreatePhaseTimer("fh_phase_end_round", 0.5, 1, function() SlashMoon.Tasks.Game.EndRound(false, 8, "no_escape") end)
    end
end

local function CompleteEscape(ply)
    local state = S()
    if not state.active or state.phase ~= "escape" or not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end
    if state.escapedPlayers[ply] then return end

    state.escapedPlayers[ply] = true
    state.escapedNames[ply] = ply:Nick()
    state.escapeProgress[ply] = nil
    SlashMoon.Tasks.Game.RemoveSurvivor(ply)

    ply:SetNW2Bool("fhi_escaped", true)
    hook.Run("SN_Player_Escaped", ply)
    hook.Run("fhi_player_escaped_server", ply)

    SilentKillPlayer(ply)

    net.Start("fhi_player_escaped"); net.WriteEntity(ply); net.Broadcast()
    net.Start("fhi_escape_progress"); net.WriteFloat(1); net.Send(ply)

    local anyLeft = false
    for _, candidate in ipairs(SlashMoon.Tasks.Game.GetSurvivors()) do
        if IsValid(candidate) and not state.escapedPlayers[candidate] then
            anyLeft = true
            break
        end
    end
    if not anyLeft then AnnounceEscapeResult() end

    CreatePhaseTimer("fh_phase_spectate_" .. ply:SteamID64(), 0.15, 1, function()
        if IsValid(ply) then
            SlashMoon.Tasks.Game.SetSpectator(ply, OBS_MODE_ROAMING)
        end
    end)
end

-- ── Тик Зон Побега (3.6 сек удержания) ────────────────────────────────
local function StartEscapeMarkerTick()
    if timer.Exists("fh_phase_escape_marker_tick") then MODULE:RemoveTimer("fh_phase_escape_marker_tick") end

    local cfg = C()
    CreatePhaseTimer("fh_phase_escape_marker_tick", 0.1, 0, function()
        local state = S()
        if not state.active or state.phase ~= "escape" or roundEnding then
            MODULE:RemoveTimer("fh_phase_escape_marker_tick"); return
        end

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:IsPlayer() then continue end
            if not SlashMoon.Tasks.Game.IsSurvivor(ply) or state.escapedPlayers[ply] then continue end

            local canEscape = false
            local holdTime = cfg.ESCAPE_STAND_TIME
            if state.escapeMode == "car" then
                local car = state.escapeCar
                canEscape = IsValid(car)
                    and ply:GetPos():DistToSqr(car:GetPos()) <= 180 * 180
                    and ply:KeyDown(IN_USE)
                    and ply:GetEyeTrace().Entity == car
                holdTime = 2.5
            else
                local radiusSqr = cfg.ESCAPE_MARKER_RADIUS * cfg.ESCAPE_MARKER_RADIUS
                for _, marker in ipairs(state.escapeMarkers) do
                    if IsValid(marker) and ply:GetPos():DistToSqr(marker:GetPos()) <= radiusSqr then
                        canEscape = true
                        break
                    end
                end
            end

            if canEscape then
                if not state.escapeProgress[ply] then state.escapeProgress[ply] = CurTime() end
                local progress = math.Clamp((CurTime() - state.escapeProgress[ply]) / holdTime, 0, 1)
                
                net.Start("fhi_escape_progress"); net.WriteFloat(progress); net.Send(ply)

                if progress >= 1 then
                    CompleteEscape(ply)
                end
            else
                if state.escapeProgress[ply] then
                    state.escapeProgress[ply] = nil
                    net.Start("fhi_escape_progress"); net.WriteFloat(0); net.Send(ply)
                end
            end
        end
    end)
end

-- ── Подсветка Выживших для Аниматроников ──────────────────────────────
local function StartEscapeGlowCycle()
    if timer.Exists("fhi_escape_glow_cycle") then MODULE:RemoveTimer("fhi_escape_glow_cycle") end

    local function DoGlow()
        local state = S()
        if not state.active or state.phase ~= "escape" or roundEnding then return end

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then ply:SetNW2Bool("fhi_escape_glow", false) end
        end

        local glowTargets = {}
        for _, ply in ipairs(player.GetAll()) do
            if SlashMoon.Tasks.Game.IsSurvivor(ply) and not state.escapedPlayers[ply] then
                ply:SetNW2Bool("fhi_escape_glow", true)
                table.insert(glowTargets, ply)
            end
        end

        if #glowTargets == 0 then return end

        net.Start("fhi_escape_glow")
        net.WriteBool(true)
        net.WriteUInt(#glowTargets, 8)
        for _, ply in ipairs(glowTargets) do net.WritePlayer(ply) end
        net.Broadcast()

        CreatePhaseTimer("fhi_escape_glow_reset", 8, 1, function()
            for _, ply in ipairs(glowTargets) do
                if IsValid(ply) then ply:SetNW2Bool("fhi_escape_glow", false) end
            end
            net.Start("fhi_escape_glow"); net.WriteBool(false); net.WriteUInt(0, 8); net.Broadcast()
        end)
    end

    DoGlow()
    CreatePhaseTimer("fhi_escape_glow_cycle", 35, 0, DoGlow)
end

-- ── Старт Фазы Побега ────────────────────────────────────────────────
local function StartEscapePhase()
    local state = S(); local cfg = C()
    if not state.active or state.phase == "escape" or roundEnding then return end

    _escapeEndCalled = false
    ClearTimers()
    state.phase = "escape"

    local escapeTime = math.max(1, tonumber(cfg.ESCAPE_DURATION) or 120)
    state.phaseEndTime = CurTime() + escapeTime
    BroadcastPhase("escape", escapeTime)
    
    CreatePhaseTimer("fh_phase_escape_cutback", 0.1, 1, function()
        net.Start("fh_timer_cutback")
        net.WriteFloat(escapeTime)
        net.WriteString("ambient/alarms/klaxon1.wav")
        net.Broadcast()
    end)

    CreatePhaseTimer("fh_phase_escape_end", escapeTime, 1, function()
        if not SlashMoon.Tasks.Game.IsRoundActive() or roundEnding then return end
        AnnounceEscapeResult()
    end)

    hook.Run("fh_phase_escape_start")

    CreatePhaseTimer("fh_phase_escape_activate", 10, 1, function()
        if not state.active or state.phase ~= "escape" or roundEnding then return end
        SpawnEscapeMarkers()
        StartEscapeMarkerTick()
        StartEscapeGlowCycle()
    end)
end

-- ── Поллинг Заданий ───────────────────────────────────────────────────
local function StartTaskPoll()
    if timer.Exists("fh_phase_task_poll") then MODULE:RemoveTimer("fh_phase_task_poll") end
    CreatePhaseTimer("fh_phase_task_poll", 0.5, 0, function()
        local state = S()
        if not state.active or state.phase == "escape" then MODULE:RemoveTimer("fh_phase_task_poll"); return end
        
        -- ПРОВЕРКА ВЫПОЛНЕНИЯ ВСЕХ ТАСКОВ ИЗ НАШЕЙ СИСТЕМЫ SN_TASKS
        if table.IsEmpty(SlashMoon.Tasks.ActiveState) then return end
        for _, v in pairs(SlashMoon.Tasks.ActiveState) do
            if not v.done and not v.failed then return end
        end
        
        StartEscapePhase()
        MODULE:RemoveTimer("fh_phase_task_poll")
    end)
end

-- ── Патч fh.timer ─────────────────────────────────────────────────────
local function PatchFhTimer()
    if not fh or not fh.timer then return end
    local s = S()
    fh.timer.Exists = function() return s.active and (s.phase == "task" or s.phase == "penalty") end
    fh.timer.GetTimeLeft = function() return s.taskTimeLeft end
end

-- ── Хуки Запуска и Очистки ───────────────────────────────────────────
local function StartRoundPhase()
    local state = S()
    state.generation = state.generation + 1
    ClearTimers()
    CreatePhaseTimer("fh_phase_start", 0.5, 1, function()
        PatchFhTimer()
        -- Сначала активируем HUD-оверрайд, ПОТОМ отправляем данные фазы
        -- Иначе клиент получает fh_phase_update когда phaseState.active=false
        net.Start("fh_phase_hud_override"); net.WriteBool(true); net.Broadcast()
        StartTaskPhase()
        StartTaskPoll()
    end)
end

local function CleanupRoundPhase()
    local state = S()
    state.generation = state.generation + 1
    ClearTimers()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:SetNW2Bool("fhi_escape_glow", false)
            if ply.SN_TasksSuppressedRagdoll then
                ply:SuppressRagdollSpawn(false)
                ply.SN_TasksSuppressedRagdoll = nil
            end
        end
    end
    if state.originalHaloCooldown then
        game.ConsoleCommand("halo_cooldown " .. state.originalHaloCooldown .. "\n")
        state.originalHaloCooldown = nil
    end
    for _, e in ipairs(state.escapeMarkers) do if IsValid(e) then e:Remove() end end
    table.Empty(state.escapeMarkers)
    
    RestoreSpeeds()
    state.active           = false
    state.phase            = "none"
    state.taskTimeLeft     = 0
    state.phaseEndTime     = 0
    state.escapeMode       = "none"
    state.escapeCar        = NULL
    table.Empty(state.escapeProgress)
    _escapeEndCalled       = false
    roundEnding            = false  -- КРИТИЧНО: иначе следующий раунд не запустит маркеры
    
    -- Сброс клиентских маркеров и прогресса побега
    net.Start("fhi_escape_glow"); net.WriteBool(false); net.WriteUInt(0, 8); net.Broadcast()
    net.Start("fhi_escape_reset"); net.Broadcast()
    net.Start("fh_phase_hud_override"); net.WriteBool(false); net.Broadcast()
end

MODULE:Hook("SN_Task_Failed", "SN_Phase_OnTaskFailed", function()
    if not S().penaltiesApplied then ApplyPenalties() end
end)

-- ── Сброс статуса побега при спавне игрока ───────────────────────────
MODULE:Hook("PlayerSpawn", "SN_Phase_ResetEscapeStatus", function(ply)
    if IsValid(ply) then
        ply:SetNW2Bool("fhi_escaped", false)
        ply:SetNW2Bool("sn_escaped", false)
    end
end)

local function ResetAllEscapeFlags()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:SetNW2Bool("fhi_escaped", false)
            ply:SetNW2Bool("sn_escaped", false)
        end
    end
end

MODULE:Hook("SN_Game_RoundStart", "SN_Phase_ResetAllEscapeFlags", ResetAllEscapeFlags)
MODULE:Hook("SN_Game_RoundEnd", "SN_Phase_ResetAllEscapeFlagsEnd", ResetAllEscapeFlags)

MODULE:Hook("SN_Game_RoundStart", "SN_Phase_Init", StartRoundPhase)
MODULE:Hook("SN_Game_RoundEnd", "SN_Phase_Cleanup", CleanupRoundPhase)

MODULE:Hook("PlayerInitialSpawn", "SN_Phase_SyncLateJoin", function(ply)
    timer.Simple(2, function()
        SendPhaseState(ply)
    end)
end)

MODULE:Receive("SN_Phase_RequestState", function(len, ply)
    if len > 0 or not IsValid(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "phase_state_request", 2) then return end
    SendPhaseState(ply)
end)

-- ── Функция получения сбежавших игроков ───────────────────────────────
function SlashMoon.Phase.GetEscapedPlayers()
    return S().escapedPlayers or {}
end

-- ── Функция получения текущей фазы ───────────────────────────────────
function SlashMoon.Phase.GetPhase()
    return S().phase or "none"
end

-- Экспорт для обратной совместимости с SlashMoon.PhaseAPI
SlashMoon.PhaseAPI = SlashMoon.PhaseAPI or {}
SlashMoon.PhaseAPI.GetEscapedPlayers = SlashMoon.Phase.GetEscapedPlayers
SlashMoon.PhaseAPI.GetPhase = SlashMoon.Phase.GetPhase

-- Экспорт в SlashMoon.Tasks для доступа из других модулей
SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.GetPhase = SlashMoon.Phase.GetPhase

-- Экспорт
SlashMoon.Phase.StartEscapePhase = StartEscapePhase
SlashMoon.Phase.ApplyPenalties   = ApplyPenalties
SlashMoon.Phase.StartRound       = StartRoundPhase
SlashMoon.Phase.CleanupRound     = CleanupRoundPhase
