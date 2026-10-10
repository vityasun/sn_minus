-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("round_types")

-- ============================================
-- Умный выбор раундов с кулдаунами
-- Не требует редактирования файлов гейммода: подменяет fh.SelectRoundType.
-- ============================================

SlashMoon.RoundSelector = SlashMoon.RoundSelector or {}
local Selector = SlashMoon.RoundSelector

local ROUND_NORMAL, ROUND_SPRINGTRAP, ROUND_BEAR5 = 0, 1, 3
local ROUND_NAMES = { [ROUND_NORMAL] = "Обычный", [ROUND_SPRINGTRAP] = "Springtrap", [ROUND_BEAR5] = "Bear5" }
local HISTORY_FILE = "round_types.json"

Selector.LastSpringtrapRound = Selector.LastSpringtrapRound or 0
Selector.LastBear5Round = Selector.LastBear5Round or 0
Selector.RoundHistory = Selector.RoundHistory or {}

-- ============================================
-- Сохранение/загрузка истории (data/slashmoon/round_types.json)
-- ============================================
local function SaveHistory()
    SlashMoon.Data.WriteJSON(HISTORY_FILE, {
        lastSpringtrap = Selector.LastSpringtrapRound,
        lastBear5 = Selector.LastBear5Round,
        history = Selector.RoundHistory,
    })
end

local function LoadHistory()
    local data = SlashMoon.Data.ReadJSON(HISTORY_FILE)
    if not istable(data) then return end
    Selector.LastSpringtrapRound = tonumber(data.lastSpringtrap) or 0
    Selector.LastBear5Round = tonumber(data.lastBear5) or 0
    Selector.RoundHistory = istable(data.history) and data.history or {}
end

MODULE:Hook("Initialize", "FH_RS_LoadHistory", LoadHistory)

-- ============================================
-- Доступность раундов
-- ============================================
local function GetCurrentRound()
    if fh and fh.GetRoundCount then return fh.GetRoundCount() end
    return 0
end

local function IsAvailable(lastRound, cooldown)
    if lastRound == 0 then return true end
    return (GetCurrentRound() - lastRound) >= cooldown
end

function Selector.IsSpringtrapAvailable()
    return MODULE:IsEnabled() and IsAvailable(Selector.LastSpringtrapRound, MODULE:GetOption("springtrap_cooldown"))
end

function Selector.IsBear5Available()
    return MODULE:IsEnabled() and IsAvailable(Selector.LastBear5Round, MODULE:GetOption("bear5_cooldown"))
end

-- ============================================
-- Логика выбора: Bear5 > Springtrap > обычный
-- ============================================
function Selector.SelectSmart()
    if Selector.IsBear5Available() and math.random(1, 100) <= MODULE:GetOption("bear5_chance") then
        return ROUND_BEAR5
    end
    if Selector.IsSpringtrapAvailable() and math.random(1, 100) <= MODULE:GetOption("springtrap_chance") then
        return ROUND_SPRINGTRAP
    end
    return ROUND_NORMAL
end

function Selector.RecordRound(roundID)
    local current = GetCurrentRound()

    if roundID == ROUND_SPRINGTRAP then
        Selector.LastSpringtrapRound = current
    elseif roundID == ROUND_BEAR5 then
        Selector.LastBear5Round = current
    end

    table.insert(Selector.RoundHistory, { round = current, type = roundID, time = os.time() })
    while #Selector.RoundHistory > 50 do table.remove(Selector.RoundHistory, 1) end

    SaveHistory()
end

-- ============================================
-- Перехват выбора раунда гейммодом
-- ============================================
local function Install()
    if not (fh and fh.SelectRoundType) then return false end
    if Selector.Installed then return true end

    Selector.OriginalSelectRoundType = Selector.OriginalSelectRoundType or fh.SelectRoundType
    local original = Selector.OriginalSelectRoundType

    fh.SelectRoundType = function(forcedID)
        if not MODULE:IsEnabled() then return original(forcedID) end

        local selected = forcedID or Selector.SelectSmart()
        Selector.RecordRound(selected)
        return original(selected)
    end

    Selector.Installed = true
    return true
end

MODULE:Hook("Initialize", "FH_RS_HookRoundSelection", function()
    -- Гейммод может создать fh.SelectRoundType не сразу
    timer.Simple(5, Install)
end)

MODULE:OnDisabled(function()
    if Selector.Installed and fh and Selector.OriginalSelectRoundType then
        fh.SelectRoundType = Selector.OriginalSelectRoundType
    end
    Selector.Installed = false
end)

-- Дополнительная синхронизация на случай, если раунд выбран в обход перехвата
MODULE:Hook("fh_startgame", "FH_RS_SyncHistory", function(roundType)
    local current = GetCurrentRound()
    local last = Selector.RoundHistory[#Selector.RoundHistory]
    if last and last.round == current and last.type == roundType then return end
    Selector.RecordRound(roundType)
end)

-- ============================================
-- Команды для админов
-- ============================================
local function Reply(ply, msg)
    if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
end

local function Allowed(ply, perm)
    return SlashMoon.Admin.HasPermission(ply, perm)
end

MODULE:Command("fh_rs_status", function(ply)
    if not Allowed(ply, "slashmoon_rounds_view") then return end

    local current = GetCurrentRound()
    Reply(ply, table.concat({
        "[Round Selector] Статус:",
        "  Текущий раунд: " .. current,
        "  Springtrap доступен: " .. (Selector.IsSpringtrapAvailable() and "Да" or "Нет") .. " (прошло: " .. (current - Selector.LastSpringtrapRound) .. ")",
        "  Bear5 доступен: " .. (Selector.IsBear5Available() and "Да" or "Нет") .. " (прошло: " .. (current - Selector.LastBear5Round) .. ")",
    }, "\n"))
end)

MODULE:Command("fh_rs_history", function(ply)
    if not Allowed(ply, "slashmoon_rounds_view") then return end

    local lines = { "[Round Selector] Последние 10 раундов:" }
    for i = math.max(1, #Selector.RoundHistory - 9), #Selector.RoundHistory do
        local record = Selector.RoundHistory[i]
        lines[#lines + 1] = "  Раунд " .. record.round .. ": " .. (ROUND_NAMES[record.type] or tostring(record.type))
    end
    Reply(ply, table.concat(lines, "\n"))
end)

MODULE:Command("fh_rs_reset", function(ply)
    if not Allowed(ply, "slashmoon_rounds_manage") then return end

    Selector.LastSpringtrapRound = 0
    Selector.LastBear5Round = 0
    Selector.RoundHistory = {}
    SaveHistory()
    Reply(ply, "[Round Selector] История сброшена")
end)

local function ForceRound(ply, roundID)
    if not Allowed(ply, "slashmoon_rounds_manage") then return end

    if roundID == ROUND_SPRINGTRAP then Selector.LastSpringtrapRound = 0 end
    if roundID == ROUND_BEAR5 then Selector.LastBear5Round = 0 end
    if fh and fh.SelectRoundType then fh.SelectRoundType(roundID) end
    Reply(ply, "[Round Selector] Форсирован раунд: " .. ROUND_NAMES[roundID])
end

MODULE:Command("fh_rs_force_springtrap", function(ply) ForceRound(ply, ROUND_SPRINGTRAP) end)
MODULE:Command("fh_rs_force_bear5", function(ply) ForceRound(ply, ROUND_BEAR5) end)
