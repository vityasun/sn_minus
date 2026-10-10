-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("lms")

-- ========================================================
-- LMS (Last Man Standing): серверная часть
-- ========================================================

util.AddNetworkString("fhi_lms_start")
util.AddNetworkString("fhi_lms_stop")
util.AddNetworkString("SN_Hub_SetLMS")

local lmsActive = false
local lmsPlayer = nil

SlashMoon.LMS = SlashMoon.LMS or {}

-- Адрес персонального трека игрока или nil, если персональные треки выключены
local function PersonalTrackURL(uid, slot)
    local base = MODULE:GetOption("base_url")
    if not SlashMoon.HTTP.IsValidURL(base) or uid <= 0 or slot <= 0 then return nil end
    if not string.EndsWith(base, "/") then base = base .. "/" end
    return base .. uid .. "_" .. slot .. ".wav"
end

-- Игрок выбирает активный трек (из хаба)
MODULE:Receive("SN_Hub_SetLMS", function(len, ply)
    if not IsValid(ply) or ply:IsBot() or len > 2048 then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "lms_set", 1) then return end

    local url = string.Trim(net.ReadString())
    if url == "" then url = "none" end
    if string.len(url) > 250 then return end

    local slot = 0
    if url ~= "none" then
        local base = MODULE:GetOption("base_url")
        if not SlashMoon.HTTP.IsValidURL(base) then return end
        if not string.EndsWith(base, "/") then base = base .. "/" end

        local uid, parsedSlot = string.match(url, "^" .. string.PatternSafe(base) .. "(%d+)_(%d+)%.wav$")
        parsedSlot = tonumber(parsedSlot)
        if not uid or uid ~= tostring(ply:GetNW2Int("SN_UID", 0)) then return end
        if not parsedSlot or parsedSlot < 1 or parsedSlot > MODULE:GetOption("max_slot") then return end

        slot = parsedSlot
        url = PersonalTrackURL(tonumber(uid), slot)
    end

    if ply:GetNW2String("SN_EquippedLMS", "none") == url
        and ply:GetNW2Int("SN_EquippedLMS_Slot", 0) == slot then return end

    ply:SetNW2String("SN_EquippedLMS", url)
    ply:SetNW2Int("SN_EquippedLMS_Slot", slot)
    SlashMoon.Debug("[LMS] Игрок ", ply:Nick(), " экипировал трек: ", url)

    -- Точка расширения: внешние интеграции могут сохранить выбор игрока
    hook.Run("SlashMoon.LMS.TrackEquipped", ply, url, slot)
end)

local function CountAliveSurvivors()
    local escaped = SlashMoon.PhaseAPI and SlashMoon.PhaseAPI.GetEscapedPlayers and SlashMoon.PhaseAPI.GetEscapedPlayers() or {}
    local count, last = 0, nil

    for ply in pairs(survivors or {}) do
        if IsValid(ply) and ply:Alive() and not escaped[ply] then
            count = count + 1
            last = ply
        end
    end
    return count, last
end

local function IsSurvivor(ply)
    if not IsValid(ply) then return false end
    if ply.IsSurvivor then return ply:IsSurvivor() end
    return ply:Team() == TEAM_SURVIVOR
end

local function StopLMS(reason)
    if not lmsActive then return end
    lmsActive = false
    lmsPlayer = nil

    net.Start("fhi_lms_stop")
    net.Broadcast()
    SlashMoon.Debug("[LMS] Остановлен: ", reason or "unknown")
end

local function StartLMS(ply)
    if not IsValid(ply) or not IsSurvivor(ply) then return end
    if lmsActive and lmsPlayer == ply then return end
    if lmsActive then StopLMS("player_changed") end

    local track = PersonalTrackURL(ply:GetNW2Int("SN_UID", 0), ply:GetNW2Int("SN_EquippedLMS_Slot", 0))
        or MODULE:GetOption("default_track")
    if not isstring(track) or track == "" then return end

    lmsActive = true
    lmsPlayer = ply

    net.Start("fhi_lms_start")
    net.WriteString(track)
    net.WriteEntity(ply)
    net.Broadcast()

    SlashMoon.Debug("[LMS] Запущен для ", ply:Nick(), " | трек: ", track)
end

local function CheckLMS()
    if not isGameOn or not MODULE:IsEnabled() then return end
    local alive, lastAlive = CountAliveSurvivors()

    if alive == 1 then
        StartLMS(lastAlive)
    elseif lmsActive then
        StopLMS(alive == 0 and "no_survivors" or "multiple_survivors")
    end
end

SlashMoon.LMS.Check = CheckLMS
SlashMoon.LMS.Start = StartLMS
SlashMoon.LMS.Stop = StopLMS

local function DelayedCheck()
    timer.Simple(0.3, CheckLMS)
end

-- Если кто-то возродился, выживших стало больше 1 -> выключаем LMS
MODULE:Hook("PlayerSpawn", "fhi_lms_spawn_check", DelayedCheck)

MODULE:Hook("PlayerDeath", "fhi_lms_death_check", function(ply)
    if lmsActive and lmsPlayer == ply then StopLMS("lms_player_died") return end
    DelayedCheck()
end)

MODULE:Hook("SN_Player_Escaped", "fhi_lms_escaped_check", function(ply)
    if lmsActive and lmsPlayer == ply then StopLMS("lms_player_escaped") return end
    DelayedCheck()
end)

MODULE:Hook("OnPlayerChangedTeam", "fhi_lms_team_check", function(ply, oldTeam)
    if oldTeam ~= TEAM_SURVIVOR then return end
    if lmsActive and lmsPlayer == ply then StopLMS("team_changed") return end
    DelayedCheck()
end)

MODULE:Hook("PlayerDisconnected", "fhi_lms_disconnect_check", function(ply)
    if lmsActive and lmsPlayer == ply then StopLMS("disconnected") return end
    DelayedCheck()
end)

MODULE:Hook("fh_postendgame", "fhi_lms_cleanup", function() StopLMS("round_end") end)
MODULE:Hook("fh_poststartgame", "fhi_lms_reset", function() StopLMS("round_start") end)

MODULE:OnDisabled(function() StopLMS("module_disabled") end)
