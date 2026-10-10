-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("hub")

-- ========================================================
-- Хаб: контент (редактируйте этот файл под свой сервер)
-- Материалы sn_hub/* входят в контент-пак сервера.
-- ========================================================

SlashMoon.Hub = SlashMoon.Hub or {}
local Hub = SlashMoon.Hub

-- Аватары (req_bundle — набор, открывающий аватар; nil — бесплатно)
Hub.AvailableAvatars = {
    { path = "sn_hub/avatars/custom_1.png", req_bundle = "bundle_neon" },
    { path = "sn_hub/avatars/custom_2.png", req_bundle = "bundle_forest" },
    { path = "sn_hub/avatars/custom_3.png", req_bundle = nil },
}

-- Баннеры карточки игрока в табло
Hub.AvailableBanners = {
    { id = "none", name = "Без баннера", mat = nil, req_bundle = nil },
    { id = "neon_city", name = "Неоновый город", mat = "sn_hub/banners/neon_city.png", req_bundle = "bundle_neon" },
    { id = "dark_forest", name = "Темный лес", mat = "sn_hub/banners/dark_forest.png", req_bundle = "bundle_forest" },
    { id = "old", name = "Старая пиццерия", mat = "sn_hub/banners/old.png", req_bundle = "promo_old_banner" },
    { id = "factory_moon", name = "Завод под луной", mat = "sn_hub/banners/zavod.png", req_bundle = "factory_moon" },
    { id = "hunter", name = "Охотник", mat = "sn_hub/banners/hunter.png", req_bundle = "banner_hunter" },
    { id = "comeback", name = "Возвращение", mat = "sn_hub/banners/comeback.png", req_bundle = "banner_comeback" },
    { id = "died", name = "Погибший", mat = "sn_hub/banners/died.png", req_bundle = "banner_died" },
    { id = "jpn", name = "Япония", mat = "sn_hub/banners/jpn.png", req_bundle = "banner_jpn" },
}

-- Наборы профиля, которые продаются в магазине (цена — по умолчанию, можно переопределить опцией)
Hub.ProfileBundles = {
    ["bundle_neon"] = { name = "Набор «Неоновый город»", price = 560, banner_id = "neon_city",
        avatar_path = "sn_hub/avatars/custom_1.png", banner_mat = "sn_hub/banners/neon_city.png" },
    ["bundle_forest"] = { name = "Набор «Темный лес»", price = 320, banner_id = "dark_forest",
        avatar_path = "sn_hub/avatars/custom_2.png", banner_mat = "sn_hub/banners/dark_forest.png" },
    ["banner_died"] = { name = "Баннер «Погибший»", price = 560, banner_id = "died",
        avatar_path = "sn_hub/avatars/zaglushka.png", banner_mat = "sn_hub/banners/died.png" },
    ["banner_comeback"] = { name = "Баннер «Возвращение»", price = 560, banner_id = "comeback",
        avatar_path = "sn_hub/avatars/zaglushka.png", banner_mat = "sn_hub/banners/comeback.png" },
}

-- Галерея аниматроников (описание берется из локализации гейммода)
Hub.Characters = {
    { id = "freddy", name = "Фредди", model = "models/speps/pill/oldfreddy.mdl", icon = "sn_hub/chars/freddy.png" },
    { id = "bonnie", name = "Бонни", model = "models/speps/pill/oldbonnie.mdl", icon = "sn_hub/chars/bonnie.png" },
    { id = "chica", name = "Чика", model = "models/speps/pill/oldchica.mdl", icon = "sn_hub/chars/chica.png" },
    { id = "foxy", name = "Фокси", model = "models/speps/pill/oldfoxy.mdl", icon = "sn_hub/chars/foxy.png" },
    { id = "endo", name = "Эндоскелет", model = "models/mountroid/thudner/hw withered pack/endo02.mdl", icon = "sn_hub/chars/minus_endo.png" },
}

-- Задания: type = "onetime" | "daily"; stat — счетчик прогресса; reward = { balance = N, item = "id" }
Hub.Tasks = {
    { id = "reg_reward", title = "Добро пожаловать", desc = "Награда за первый вход на сервер", type = "onetime", req = 0, reward = { balance = 120 } },
    { id = "daily_login", title = "Ежедневный вход", desc = "Заходите на сервер каждый день", type = "daily", req = 0, reward = { balance = 10 } },
    { id = "daily_kills", title = "Охота дня", desc = "Убейте 15 выживших за аниматроника за день", type = "daily", req = 15, stat = "kills_daily", reward = { balance = 20 } },
    { id = "total_kills_100", title = "Опытный охотник", desc = "Убейте 100 выживших за аниматроника", type = "onetime", req = 100, stat = "kills_total", reward = { balance = 240, item = "banner_hunter" } },
}

-- Новости на главной вкладке (сверху — самые новые)
Hub.News = {
    {
        date = "SlashMoon Core 1.0",
        title = "Открытый релиз",
        changes = {
            "+ Сборка SlashMoon выложена в открытый доступ",
            "+ Все модули можно включать и выключать в панели !slashmoon",
            "+ Экономика хаба теперь хранится на самом сервере",
            "Отредактируйте новости в файле модуля hub: sh_hub_content.lua",
        },
    },
}

-- ========================================================
-- Цены
-- ========================================================
local priceCache, priceSource = {}, nil

local function ParsePrices()
    local source = MODULE:GetOption("prices") or ""
    if source == priceSource then return priceCache end
    priceCache = {}
    for id, price in string.gmatch(source, "([%w_%-%.]+)%s*=%s*(%d+)") do
        priceCache[id] = tonumber(price)
    end
    priceSource = source
    return priceCache
end

--- Цена предмета магазина (nil — не продается).
function Hub.GetPrice(itemID)
    local custom = ParsePrices()[itemID]
    if custom then return custom end

    local bundle = Hub.ProfileBundles[itemID]
    if bundle then return bundle.price end

    local dances = SlashMoon.Dances
    if dances and dances.Animations and dances.Animations[itemID] and not dances.IsFree(itemID) then
        return MODULE:GetOption("dance_price")
    end
end

--- Название валюты.
function Hub.Currency()
    return MODULE:GetOption("currency") or "FC"
end

--- Форматирует сумму: "1,250 FC".
function Hub.FormatMoney(amount)
    return string.Comma(math.floor(tonumber(amount) or 0)) .. " " .. Hub.Currency()
end

--- Список серверов для кнопки "Играть": { { name = "", address = "" }, ... }
function Hub.GetServers()
    local out = {}
    for entry in string.gmatch(MODULE:GetOption("servers") or "", "[^;]+") do
        local name, address = string.match(entry, "^%s*(.-)%s*=%s*([%w%.%-:]+)%s*$")
        if name and address then out[#out + 1] = { name = name, address = address } end
    end
    return out
end
