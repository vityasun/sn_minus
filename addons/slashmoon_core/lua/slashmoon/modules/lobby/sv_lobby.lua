-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("lobby")

-- ========================================================
-- Режим лобби: "хирургическая" заморозка Fazbear's Hunt
-- Глобальные функции ниже принадлежат гейммоду — модуль временно подменяет
-- их заглушками и возвращает оригиналы при отключении.
-- ========================================================

local GAMEMODE_FUNCS = { "registerNewRound", "startGame", "assignKillers", "endGame" }
local TIMER_FUNCS = { "StartDefaultTimer", "StartGameTimer", "CutBack" }
local originals = {}

local function Stub() return false end

local function Freeze()
    -- 1. Подменяем функции раундов гейммода на пустышки
    for _, name in ipairs(GAMEMODE_FUNCS) do
        local fn = _G[name]
        if isfunction(fn) and fn ~= Stub then
            originals[name] = fn
            _G[name] = Stub
        end
    end

    -- 2. Блокируем систему таймеров гейммода (fh.timer)
    if istable(fh) and istable(fh.timer) then
        for _, name in ipairs(TIMER_FUNCS) do
            if isfunction(fh.timer[name]) and fh.timer[name] ~= Stub then
                originals["timer." .. name] = fh.timer[name]
                fh.timer[name] = Stub
            end
        end
    end

    -- 4. Замораживаем состояния гейммода
    isGameOn = false
    roundActive = false
    roundEnding = false

    SlashMoon.Debug("[Lobby] Гейммод Fazbear's Hunt заморожен для режима лобби")
end

local function Unfreeze()
    for _, name in ipairs(GAMEMODE_FUNCS) do
        if originals[name] then _G[name] = originals[name] end
    end
    if istable(fh) and istable(fh.timer) then
        for _, name in ipairs(TIMER_FUNCS) do
            if originals["timer." .. name] then fh.timer[name] = originals["timer." .. name] end
        end
    end
    originals = {}
end

MODULE:Hook("InitPostEntity", "SN_Lobby_FH_Freeze", function()
    Freeze()

    -- 3. Перехват сетевого пакета: гейммод запускал таймер при заходе 2-го игрока.
    -- MODULE:Receive вернет оригинальный обработчик гейммода при отключении модуля.
    MODULE:Receive("fh_initpostentity", function(len, ply)
        if len ~= 0 or not IsValid(ply) then return end
        if not SlashMoon.Security.CheckRateLimit(ply, "lobby_initpostentity", 2) then return end

        -- Оставляем только то, что нужно клиенту, чтобы не было Lua-ошибок
        net.Start("fh_share_notprefered")
        net.WriteTable(killers and killers.getAllPreferables and killers.getAllPreferables(true) or {})
        net.Send(ply)
    end)
end)

MODULE:OnDisabled(Unfreeze)

-- 5. Безопасность лобби: без урона и суицида
MODULE:Hook("EntityTakeDamage", "SN_Lobby_Godmode", function(target)
    if target:IsPlayer() then return true end
end)

MODULE:Hook("CanPlayerSuicide", "SN_Lobby_NoSuicide", function()
    return false
end)
