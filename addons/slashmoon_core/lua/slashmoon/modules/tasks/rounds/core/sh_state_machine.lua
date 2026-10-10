-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Gamemode: Shared State Machine (Localized)
-- ========================================================
SlashMoon.Tasks = SlashMoon.Tasks or {}

-- Константы состояний
SlashMoon.Rounds.STATE_WAITING = 0
SlashMoon.Rounds.STATE_PREPARE = 1
SlashMoon.Rounds.STATE_ACTIVE  = 2
SlashMoon.Rounds.STATE_ENDED   = 3

-- Глобальные геттеры состояния
function SlashMoon.Rounds.GetState()
    return GetGlobal2Int("SN_RoundState", SlashMoon.Rounds.STATE_WAITING)
end

function SlashMoon.Rounds.GetStateTimeLeft()
    return math.max(0, GetGlobal2Float("SN_StateEndTime", 0) - CurTime())
end

function SlashMoon.Rounds.GetStateName(state)
    state = state or SlashMoon.Rounds.GetState()
    if state == SlashMoon.Rounds.STATE_WAITING then return SlashMoon.Tasks.Lang("sn.round.waiting")
    elseif state == SlashMoon.Rounds.STATE_PREPARE then return SlashMoon.Tasks.Lang("sn.round.prepare")
    elseif state == SlashMoon.Rounds.STATE_ACTIVE then return SlashMoon.Tasks.Lang("sn.round.active")
    elseif state == SlashMoon.Rounds.STATE_ENDED then return SlashMoon.Tasks.Lang("sn.round.ended") end
    return "???"
end
