-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("hub")

-- ========================================================
-- Хаб: серверная логика (профиль, магазин, промокоды, задания)
-- Внешние сервисы не используются: все хранится в sv.db.
-- Для интеграций есть хуки:
--   SlashMoon.Hub.PlayerLoaded(ply, profile)
--   SlashMoon.Hub.ItemBought(ply, itemID, price)
--   SlashMoon.Hub.BalanceChanged(ply, newBalance, delta, reason)
-- ========================================================

local Hub = SlashMoon.Hub
local DB = Hub.DB
local Security = SlashMoon.Security

for _, name in ipairs({
    "SN_Hub_Open", "SN_Hub_SetAvatar", "SN_Hub_SetBanner", "SN_Hub_SyncInventory",
    "SN_Hub_BuyItem", "SN_Hub_BuyResult", "SN_Promo_Submit", "SN_Promo_Result",
    "SN_Hub_SyncTasks", "SN_Hub_ClaimTask", "SN_Hub_TaskResult", "SN_Hub_RequestTasks",
}) do
    util.AddNetworkString(name)
end

local BUY_ERROR, BUY_OK, BUY_OWNED, BUY_NO_MONEY = 0, 1, 2, 3

local function Today()
    return os.date("%Y-%m-%d")
end

local function SendInventory(ply)
    net.Start("SN_Hub_SyncInventory")
    net.WriteTable(ply.SlashMoonHub.data.inventory)
    net.Send(ply)
end

-- Публикуем профиль в сетевых переменных (их читают табло, LMS и другие модули)
local function PublishProfile(ply)
    local profile = ply.SlashMoonHub
    ply:SetNW2Int("SN_UID", profile.uid)
    ply:SetNW2Int("SN_Balance", profile.balance)
    ply:SetNW2String("SN_EquippedAvatar", profile.avatar)
    ply:SetNW2String("SN_Banner", profile.banner)
    ply.SN_Inventory = profile.data.inventory -- используется модулем dances
    SendInventory(ply)
end

--- Профиль игрока (загружается при входе).
function Hub.GetProfile(ply)
    return IsValid(ply) and ply.SlashMoonHub or nil
end

--- Изменяет баланс и сохраняет профиль.
function Hub.AddBalance(ply, delta, reason)
    local profile = Hub.GetProfile(ply)
    if not profile then return false end
    profile.balance = math.max(0, profile.balance + math.floor(delta))
    DB.Save(ply)
    ply:SetNW2Int("SN_Balance", profile.balance)
    hook.Run("SlashMoon.Hub.BalanceChanged", ply, profile.balance, delta, reason)
    return true
end

--- Выдает предмет в инвентарь.
function Hub.GiveItem(ply, itemID)
    local profile = Hub.GetProfile(ply)
    if not profile or not isstring(itemID) or itemID == "" then return false end
    profile.data.inventory[itemID] = true
    DB.Save(ply)
    ply.SN_Inventory = profile.data.inventory
    SendInventory(ply)
    return true
end

function Hub.HasItem(ply, itemID)
    local profile = Hub.GetProfile(ply)
    return profile ~= nil and profile.data.inventory[itemID] == true
end

-- ========================================================
-- ВХОД ИГРОКА
-- ========================================================
MODULE:Hook("PlayerInitialSpawn", "SN_Hub_Load", function(ply)
    if ply:IsBot() then return end

    local profile = DB.Load(ply)
    if not profile then return end

    PublishProfile(ply)
    hook.Run("SlashMoon.Hub.PlayerLoaded", ply, profile)

    if MODULE:GetOption("open_on_join") then
        timer.Simple(2, function()
            if not IsValid(ply) then return end
            net.Start("SN_Hub_Open")
            net.Send(ply)
        end)
    end
end)

MODULE:Hook("PlayerDisconnected", "SN_Hub_Save", function(ply)
    if ply.SlashMoonHub then DB.Save(ply) end
end)

-- Включение модуля на лету: загружаем профили всех, кто уже на сервере
MODULE:OnEnabled(function()
    for _, ply in ipairs(player.GetHumans()) do
        if not ply.SlashMoonHub and DB.Load(ply) then PublishProfile(ply) end
    end
end)

-- ========================================================
-- АВАТАР И БАННЕР
-- ========================================================
local function AvatarAllowed(ply, avatarID)
    if avatarID == "steam" then return true end
    for _, avatar in ipairs(Hub.AvailableAvatars) do
        if avatar.path == avatarID then
            return not avatar.req_bundle or Hub.HasItem(ply, avatar.req_bundle)
        end
    end
    return false
end

local function BannerAllowed(ply, bannerID)
    for _, banner in ipairs(Hub.AvailableBanners) do
        if banner.id == bannerID then
            return not banner.req_bundle or Hub.HasItem(ply, banner.req_bundle)
        end
    end
    return false
end

MODULE:Receive("SN_Hub_SetAvatar", function(_, ply)
    if not Security.CheckRateLimit(ply, "hub_avatar", 1) or not ply.SlashMoonHub then return end
    local avatarID = net.ReadString()
    if not AvatarAllowed(ply, avatarID) then return end

    ply.SlashMoonHub.avatar = avatarID
    DB.Save(ply)
    ply:SetNW2String("SN_EquippedAvatar", avatarID)
end)

MODULE:Receive("SN_Hub_SetBanner", function(_, ply)
    if not Security.CheckRateLimit(ply, "hub_banner", 1) or not ply.SlashMoonHub then return end
    local bannerID = net.ReadString()
    if not BannerAllowed(ply, bannerID) then return end

    ply.SlashMoonHub.banner = bannerID
    DB.Save(ply)
    ply:SetNW2String("SN_Banner", bannerID)
end)

-- ========================================================
-- МАГАЗИН
-- ========================================================
local function SendBuyResult(ply, code)
    net.Start("SN_Hub_BuyResult")
    net.WriteUInt(code, 4)
    net.Send(ply)
end

MODULE:Receive("SN_Hub_BuyItem", function(_, ply)
    if not Security.CheckRateLimit(ply, "hub_buy", 1) or not ply.SlashMoonHub then return end

    local itemID = net.ReadString()
    local price = Hub.GetPrice(itemID)
    if not price then return SendBuyResult(ply, BUY_ERROR) end

    local dances = SlashMoon.Dances
    if Hub.HasItem(ply, itemID) or (dances and dances.HasDance and dances.Animations[itemID] and dances.HasDance(ply, itemID)) then
        return SendBuyResult(ply, BUY_OWNED)
    end
    if ply.SlashMoonHub.balance < price then return SendBuyResult(ply, BUY_NO_MONEY) end

    Hub.AddBalance(ply, -price, "buy:" .. itemID)
    Hub.GiveItem(ply, itemID)
    SendBuyResult(ply, BUY_OK)
    hook.Run("SlashMoon.Hub.ItemBought", ply, itemID, price)
end)

-- ========================================================
-- ПРОМОКОДЫ (настраиваются опцией модуля)
-- ========================================================
local function ParsePromocodes()
    local out = {}
    for entry in string.gmatch(MODULE:GetOption("promocodes") or "", "[^;]+") do
        local code, kind, value, limit = string.match(entry, "^%s*([%w_%-]+)%s*=%s*(%a+):([%w_%-%.]+):?(%d*)%s*$")
        if code then
            out[string.upper(code)] = { kind = string.lower(kind), value = value, limit = tonumber(limit) }
        end
    end
    return out
end

local function SendPromoResult(ply, status, kind, value)
    net.Start("SN_Promo_Result")
    net.WriteString(status)
    net.WriteString(kind or "")
    net.WriteString(tostring(value or ""))
    net.Send(ply)
end

MODULE:Receive("SN_Promo_Submit", function(_, ply)
    if not Security.CheckRateLimit(ply, "hub_promo", 2) or not ply.SlashMoonHub then return end

    local code = string.upper(string.Trim(net.ReadString()))
    if code == "" or #code > 64 then return end

    local promo = ParsePromocodes()[code]
    if not promo then return SendPromoResult(ply, "invalid") end

    local profile = ply.SlashMoonHub
    if profile.data.promos[code] then return SendPromoResult(ply, "already_used") end
    if promo.limit and DB.GetPromoUses(code) >= promo.limit then return SendPromoResult(ply, "limit_reached") end

    if promo.kind == "balance" then
        Hub.AddBalance(ply, tonumber(promo.value) or 0, "promo:" .. code)
    elseif promo.kind == "item" then
        if Hub.HasItem(ply, promo.value) then return SendPromoResult(ply, "already_have_item") end
        Hub.GiveItem(ply, promo.value)
    else
        return SendPromoResult(ply, "invalid")
    end

    profile.data.promos[code] = true
    DB.Save(ply)
    DB.AddPromoUse(code)
    SendPromoResult(ply, "success", promo.kind, promo.value)
end)

-- ========================================================
-- ЗАДАНИЯ
-- ========================================================
local function TaskByID(id)
    for _, task in ipairs(Hub.Tasks) do
        if task.id == id then return task end
    end
end

-- Сбрасывает дневные счетчики при смене дня
local function RefreshDaily(profile)
    local stats = profile.data.stats
    if stats.day ~= Today() then
        stats.day = Today()
        stats.kills_daily = 0
    end
end

local function TaskState(profile, task)
    local claimed = profile.data.tasks[task.id]
    if task.type == "daily" then
        return { today = claimed == Today() }
    end
    return { all_time = claimed ~= nil }
end

local function SendTasks(ply)
    local profile = ply.SlashMoonHub
    RefreshDaily(profile)

    local completed = {}
    for _, task in ipairs(Hub.Tasks) do completed[task.id] = TaskState(profile, task) end

    net.Start("SN_Hub_SyncTasks")
    net.WriteTable(profile.data.stats)
    net.WriteTable(completed)
    net.Send(ply)
end

MODULE:Receive("SN_Hub_RequestTasks", function(_, ply)
    if not Security.CheckRateLimit(ply, "hub_tasks", 1) or not ply.SlashMoonHub then return end
    SendTasks(ply)
end)

MODULE:Receive("SN_Hub_ClaimTask", function(_, ply)
    if not Security.CheckRateLimit(ply, "hub_claim", 1) or not ply.SlashMoonHub then return end

    local task = TaskByID(net.ReadString())
    local profile = ply.SlashMoonHub
    RefreshDaily(profile)

    local state = task and TaskState(profile, task)
    local done = state and (state.today or state.all_time)
    local progress = task and task.stat and (profile.data.stats[task.stat] or 0) or 0

    local ok = task ~= nil and not done and progress >= (task.req or 0)
    if ok then
        profile.data.tasks[task.id] = task.type == "daily" and Today() or true
        if task.reward.balance then Hub.AddBalance(ply, task.reward.balance, "task:" .. task.id) end
        if task.reward.item then Hub.GiveItem(ply, task.reward.item) end
        DB.Save(ply)
    end

    net.Start("SN_Hub_TaskResult")
    net.WriteBool(ok)
    net.Send(ply)
    if ok then SendTasks(ply) end
end)

-- Статистика убийств: аниматроник (команда 2701) убил выжившего
MODULE:Hook("PlayerDeath", "SN_Hub_TrackKills", function(victim, _, attacker)
    if SlashMoon.Modules.IsEnabled("lobby") then return end
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
    if attacker:Team() ~= 2701 or victim:Team() ~= TEAM_SURVIVOR then return end

    local profile = attacker.SlashMoonHub
    if not profile then return end
    RefreshDaily(profile)
    profile.data.stats.kills_daily = (profile.data.stats.kills_daily or 0) + 1
    profile.data.stats.kills_total = (profile.data.stats.kills_total or 0) + 1
    DB.Save(attacker)
end)

-- ========================================================
-- АДМИН-КОМАНДА: sn_addmoney <ник|SteamID64> <сумма>
-- ========================================================
MODULE:Command("sn_addmoney", function(ply, _, args)
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_hub_money") then return end

    local function Reply(msg)
        if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
    end

    local targetArg, amount = args[1], tonumber(args[2])
    if not targetArg or not amount then
        Reply("Использование: sn_addmoney <ник|SteamID64> <сумма>")
        return
    end

    local target
    for _, p in ipairs(player.GetHumans()) do
        if p:SteamID64() == targetArg or string.find(string.lower(p:Nick()), string.lower(targetArg), 1, true) then
            target = p
            break
        end
    end

    if IsValid(target) then
        Hub.AddBalance(target, amount, "admin")
        Reply("Баланс " .. target:Nick() .. ": " .. Hub.FormatMoney(target.SlashMoonHub.balance))
    elseif string.match(targetArg, "^%d+$") then
        DB.AddBalanceOffline(targetArg, amount)
        Reply("Баланс офлайн-игрока " .. targetArg .. " изменен на " .. amount)
    else
        Reply("Игрок не найден: " .. targetArg)
    end
end, nil, "SlashMoon: изменить баланс игрока в хабе")
