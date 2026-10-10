-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("hub")

-- ========================================================
-- Хаб: локальное хранилище профилей (SQLite сервера, sv.db)
--   uid, баланс, аватар, баннер, инвентарь, статистика, задания, промокоды
-- ========================================================

local Hub = SlashMoon.Hub
Hub.DB = Hub.DB or {}
local DB = Hub.DB

local TABLE = "slashmoon_hub_players"
local PROMO_TABLE = "slashmoon_hub_promos"

sql.Query([[CREATE TABLE IF NOT EXISTS ]] .. TABLE .. [[ (
    uid INTEGER PRIMARY KEY AUTOINCREMENT,
    steamid TEXT UNIQUE NOT NULL,
    balance INTEGER NOT NULL DEFAULT 0,
    avatar TEXT NOT NULL DEFAULT 'steam',
    banner TEXT NOT NULL DEFAULT 'none',
    data TEXT NOT NULL DEFAULT '{}'
)]])
sql.Query("CREATE TABLE IF NOT EXISTS " .. PROMO_TABLE .. " (code TEXT PRIMARY KEY, uses INTEGER NOT NULL DEFAULT 0)")

local function Esc(value)
    return sql.SQLStr(tostring(value))
end

-- Профиль игрока в памяти: ply.SlashMoonHub = { uid, balance, avatar, banner, data = { inventory, stats, tasks, promos } }
local function Normalize(row)
    local data = SlashMoon.JSON.Decode(row.data, {})
    data.inventory = istable(data.inventory) and data.inventory or {}
    data.stats = istable(data.stats) and data.stats or {}
    data.tasks = istable(data.tasks) and data.tasks or {}
    data.promos = istable(data.promos) and data.promos or {}
    return {
        uid = tonumber(row.uid) or 0,
        balance = tonumber(row.balance) or 0,
        avatar = row.avatar or "steam",
        banner = row.banner or "none",
        data = data,
    }
end

--- Загружает (или создает) профиль игрока.
function DB.Load(ply)
    local sid = ply:SteamID64()
    if not sid then return nil end

    local row = sql.QueryRow("SELECT * FROM " .. TABLE .. " WHERE steamid = " .. Esc(sid))
    if not row then
        sql.Query(string.format("INSERT INTO %s (steamid, balance) VALUES (%s, %d)",
            TABLE, Esc(sid), math.floor(MODULE:GetOption("start_balance") or 0)))
        row = sql.QueryRow("SELECT * FROM " .. TABLE .. " WHERE steamid = " .. Esc(sid))
        if not row then
            SlashMoon.Warn("[Hub] Не удалось создать профиль: ", sql.LastError())
            return nil
        end
    end

    local profile = Normalize(row)
    ply.SlashMoonHub = profile
    return profile
end

--- Сохраняет профиль игрока.
function DB.Save(ply)
    local profile = ply.SlashMoonHub
    if not profile then return end
    sql.Query(string.format("UPDATE %s SET balance = %d, avatar = %s, banner = %s, data = %s WHERE uid = %d",
        TABLE, math.floor(profile.balance), Esc(profile.avatar), Esc(profile.banner),
        Esc(SlashMoon.JSON.Encode(profile.data) or "{}"), profile.uid))
end

--- Изменяет баланс офлайн-игрока по SteamID64 (для админ-команд).
function DB.AddBalanceOffline(steamID64, amount)
    sql.Query(string.format("UPDATE %s SET balance = MAX(0, balance + %d) WHERE steamid = %s",
        TABLE, math.floor(amount), Esc(steamID64)))
end

--- Число активаций промокода (глобально).
function DB.GetPromoUses(code)
    return tonumber(sql.QueryValue("SELECT uses FROM " .. PROMO_TABLE .. " WHERE code = " .. Esc(code))) or 0
end

function DB.AddPromoUse(code)
    sql.Query(string.format("INSERT OR IGNORE INTO %s (code, uses) VALUES (%s, 0)", PROMO_TABLE, Esc(code)))
    sql.Query(string.format("UPDATE %s SET uses = uses + 1 WHERE code = %s", PROMO_TABLE, Esc(code)))
end
