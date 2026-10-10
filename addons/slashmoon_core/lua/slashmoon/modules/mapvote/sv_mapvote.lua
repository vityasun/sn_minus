-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("mapvote")

-- ============================================================
-- Ротация карт с "рулеткой" голосования
-- Список карт: garrysmod/data/fh_maplist.txt (одна карта на строку)
-- ============================================================

local CONFIG_FILE     = "fh_maplist.txt"
local HISTORY_FILE    = "fh_mapvote_history.json"

-- Карта недоступна N ротаций после игры (настраивается в админ-панели)
local function MapCooldown()
    return MODULE:GetOption("map_cooldown")
end

util.AddNetworkString("fh_mapvote_start")
util.AddNetworkString("fh_mapvote_result")

-- ============================================================
-- Состояние ротации
-- ============================================================
-- recentMaps: очередь последних MAP_COOLDOWN карт (включая текущую).
-- Формат: { "fh_redforest", "fh_cantina", ... }
-- Индекс 1 — самая последняя (текущая) карта.
local recentMaps = {}

-- ============================================================
-- Сохранение / загрузка / удаление истории
-- ============================================================
local function SaveHistory()
    local data = {
        recentMaps = recentMaps,
        timestamp  = os.time(),
    }
    file.Write(HISTORY_FILE, util.TableToJSON(data))
    SlashMoon.Debug("[FH MapVote] История сохранена: " .. table.concat(recentMaps, ", "))
end

local function LoadHistory()
    if file.Exists(HISTORY_FILE, "DATA") then
        local content = file.Read(HISTORY_FILE, "DATA")
        if content then
            local ok, data = pcall(util.JSONToTable, content)
            if ok and istable(data) and istable(data.recentMaps) then
                recentMaps = data.recentMaps
                SlashMoon.Debug("[FH MapVote] История загружена: " .. table.concat(recentMaps, ", "))
                -- Убеждаемся что текущая карта в истории есть
                local cur = game.GetMap()
                if recentMaps[1] ~= cur then
                    table.insert(recentMaps, 1, cur)
                end
                return
            end
        end
    end

    -- Первый запуск — кладём текущую карту в историю
    recentMaps = { game.GetMap() }
    SlashMoon.Debug("[FH MapVote] История инициализирована: " .. recentMaps[1])
end

local function DeleteHistory()
    if file.Exists(HISTORY_FILE, "DATA") then
        file.Delete(HISTORY_FILE)
        SlashMoon.Debug("[FH MapVote] Файл истории удалён")
    end
end

-- ============================================================
-- Чтение списка карт
-- ============================================================
local function LoadMapList()
    if not file.Exists(CONFIG_FILE, "DATA") then
        local default = table.concat({
            "# Список карт для FazBear Hunt - Map Rotation",
            "# Одна карта на строку. Строки с # игнорируются.",
            "sc_highschool",
            "fhminus_prison_morning_v1",
            "fh_cantina",
            "sc_summercamp",
            "sc_vector",
            "fh_mpd_pool",
            "fh_mallparking",
        }, "\n")
        file.Write(CONFIG_FILE, default)
        SlashMoon.Debug("[FH MapVote] Конфиг создан: garrysmod/data/" .. CONFIG_FILE)
    end

    local content = file.Read(CONFIG_FILE, "DATA")
    if not content then
        SlashMoon.Debug("[FH MapVote] ОШИБКА: не удалось прочитать " .. CONFIG_FILE)
        return {}
    end

    local maps = {}
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:StartWith("#") then
            table.insert(maps, line)
        end
    end

    SlashMoon.Debug("[FH MapVote] Загружено карт: " .. #maps)
    return maps
end

-- ============================================================
-- Доступные карты (исключаем кулдаун)
-- ============================================================
-- recentMaps[1..MAP_COOLDOWN] — заблокированы.
-- Если вся история больше MAP_COOLDOWN — обрезаем при записи,
-- но при чтении проверяем строго первые MAP_COOLDOWN элементов.
local function GetAvailableMaps(mapList)
    -- Строим set заблокированных карт
    local blocked = {}
    for i = 1, math.min(#recentMaps, MapCooldown()) do
        blocked[recentMaps[i]] = true
    end

    local available = {}
    for _, map in ipairs(mapList) do
        if not blocked[map] then
            table.insert(available, map)
        end
    end

    -- Все в кулдауне (карт меньше чем MAP_COOLDOWN) — берём всё кроме текущей
    if #available == 0 then
        SlashMoon.Debug("[FH MapVote] Все карты в кулдауне! Сбрасываем историю...")
        recentMaps = { game.GetMap() }
        SaveHistory()
        for _, map in ipairs(mapList) do
            if map ~= game.GetMap() then
                table.insert(available, map)
            end
        end
        SlashMoon.Debug("[FH MapVote] Доступно после сброса: " .. #available)
    end

    return available
end

-- ============================================================
-- Добавление карты в историю
-- ============================================================
local function PushMap(map)
    -- Кладём новую карту в начало
    table.insert(recentMaps, 1, map)

    -- Обрезаем до MapCooldown() + 1 (держим чуть больше на случай загрузки)
    while #recentMaps > MapCooldown() + 1 do
        table.remove(recentMaps)
    end

    SaveHistory()

    SlashMoon.Debug(string.format("[FH MapVote] -> %s | кулдаун: %s",
        map, table.concat(recentMaps, ", ")))
end

-- ============================================================
-- Смена карты
-- ============================================================
local function DoMapChange(map)
    PushMap(map)

    for _, ply in player.Iterator() do
        ply:ChatPrint("[MapVote] Смена карты → " .. map)
    end

    SlashMoon.Debug("[FH MapVote] Меняем карту на: " .. map)

    timer.Simple(3, function()
        RunConsoleCommand("changelevel", map)
    end)
end

-- ============================================================
-- Запуск голосования
-- ============================================================
local function StartMapVote()
    local mapList   = LoadMapList()
    local available = GetAvailableMaps(mapList)

    if #available == 0 then
        SlashMoon.Debug("[FH MapVote] Нет доступных карт! Проверь " .. CONFIG_FILE)
        return false
    end

    local winner = available[math.random(#available)]

    SlashMoon.Debug("[FH MapVote] Победитель: " .. winner)
    SlashMoon.Debug("[FH MapVote] Кулдаун сейчас: " .. table.concat(recentMaps, ", "))

    -- Отправляем клиентам: все карты для прокрутки, победитель, кулдаун, текущая
    net.Start("fh_mapvote_start")
        net.WriteTable(mapList)
        net.WriteString(winner)
        net.WriteTable(recentMaps)
        net.WriteString(game.GetMap())
    net.Broadcast()

    -- Ждём конца анимации
    timer.Simple(12, function()
        net.Start("fh_mapvote_result")
            net.WriteString(winner)
        net.Broadcast()

        timer.Simple(3, function()
            DoMapChange(winner)
        end)
    end)

    return true
end

-- ============================================================
-- Хуки
-- ============================================================
MODULE:Hook("Initialize", "FH_MapVote_Init", function()
    timer.Simple(2, LoadHistory)
end)

MODULE:Hook("fh_postendgame", "fh_mapvote_check", function()
    local count = fh and fh.GetRoundCount and fh.GetRoundCount() or 0
    if count > 0 and count % MODULE:GetOption("rounds_per_map") == 0 then
        timer.Simple(10, StartMapVote)
    end
end)

-- ============================================================
-- Команды
-- ============================================================
MODULE:Command("fh_force_mapvote", function(ply)
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_mapvote") then
        ply:ChatPrint("[MapVote] Недостаточно прав!")
        return
    end
    SlashMoon.Debug("[MapVote] Принудительный запуск от " .. (IsValid(ply) and ply:Nick() or "Console"))
    local ok = StartMapVote()
    if IsValid(ply) then
        ply:ChatPrint("[MapVote] " .. (ok and "Запущено!" or "Нет доступных карт!"))
    end
end)

MODULE:Command("fh_mapvote_status", function(ply)
    local mapList   = LoadMapList()
    local available = GetAvailableMaps(mapList)
    local lines = {
        "[FH MapVote] Статус:",
        "  Текущая карта : " .. game.GetMap(),
        "  Кулдаун (" .. MapCooldown() .. " ротаций): " .. table.concat(recentMaps, ", "),
        "  Доступно карт : " .. #available .. " / " .. #mapList,
        "  Доступные     : " .. table.concat(available, ", "),
    }
    local msg = table.concat(lines, "\n")
    if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
end)

MODULE:Command("fh_mapvote_reset", function(ply)
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_mapvote") then
        ply:ChatPrint("[MapVote] Недостаточно прав!")
        return
    end
    recentMaps = { game.GetMap() }
    SaveHistory()
    local msg = "[FH MapVote] История сброшена!"
    if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
end)

MODULE:Command("fh_mapvote_delete_file", function(ply)
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_mapvote") then
        ply:ChatPrint("[MapVote] Недостаточно прав!")
        return
    end
    DeleteHistory()
    local msg = "[FH MapVote] Файл истории удалён!"
    if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
end)
