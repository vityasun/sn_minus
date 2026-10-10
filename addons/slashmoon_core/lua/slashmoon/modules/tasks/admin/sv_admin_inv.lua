-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Admin Inventory Panel (Server)
-- Админка: выдача предметов, создание кастомных предметов
-- + описание, редкость, стакируемость для кастомных
-- + Доступ для Admin и SuperAdmin независимо от команды
-- ========================================================
if not SERVER then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}

-- SlashMoon.TEAM_EDITOR — должна быть определена в sh_editor.lua
SlashMoon.TEAM_EDITOR = SlashMoon.TEAM_EDITOR or 2703

-- Проверка доступа к админке: SuperAdmin + команда SlashMoon.TEAM_EDITOR
local function IsAdminAllowed(ply)
    return IsValid(ply) and SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_admin")
end

-- === Добавляем клиентский файл ===
AddCSLuaFile("sn_tasks/admin/cl_admin_inv.lua")

-- === СЕТЕВЫЕ СТРОКИ ===
util.AddNetworkString("SN_AdminInv_Open")
util.AddNetworkString("SN_AdminInv_GiveItem")
util.AddNetworkString("SN_AdminInv_CreateItem")
util.AddNetworkString("SN_AdminInv_RemoveItem")
util.AddNetworkString("SN_AdminInv_Result")
util.AddNetworkString("SN_AdminInv_PlayerList")
util.AddNetworkString("SN_AdminInv_CustomItems")
util.AddNetworkString("SN_AdminInv_RecipeList")
util.AddNetworkString("SN_AdminInv_CreateRecipe")
util.AddNetworkString("SN_AdminInv_RemoveRecipe")

-- === ХРАНИЛИЩЕ КАСТОМНЫХ ПРЕДМЕТОВ ===
-- Админ может создавать свои предметы в конструкторе
SlashMoon.Tasks.CustomItems = SlashMoon.Tasks.CustomItems or {}
local MAX_CUSTOM_ITEMS = 255
local MAX_CUSTOM_MESSAGE_BITS = 64 * 1024
local MAX_ADMIN_ITEMS = 1024
local MAX_CUSTOM_RECIPES = 64
local MAX_RECIPE_INGREDIENTS = 16
local CUSTOM_RECIPES_FILE = "sn_tasks/custom_delivery_recipes.json"

local function TrimBounded(value, maxLength)
    if not isstring(value) then return "" end
    return string.Trim(string.sub(value, 1, maxLength))
end

local function CustomItemCount()
    return table.Count(SlashMoon.Tasks.CustomItems)
end

-- ========================================================
-- ОТПРАВКА СПИСКА ИГРОКОВ АДМИНУ
-- ========================================================
local function SendPlayerList(ply)
    local players = {}
    for _, p in ipairs(player.GetAll()) do
        table.insert(players, {
            steamID = p:SteamID(),
            name    = p:Nick(),
            team    = p:Team(),
            alive   = p:Alive(),
        })
    end

    net.Start("SN_AdminInv_PlayerList")
        net.WriteUInt(#players, 8)
        for _, pData in ipairs(players) do
            net.WriteString(pData.steamID)
            net.WriteString(pData.name)
            net.WriteUInt(pData.team, 16)
            net.WriteBool(pData.alive)
        end
    net.Send(ply)
end

-- ========================================================
-- ОТПРАВКА СПИСКА КАСТОМНЫХ ПРЕДМЕТОВ
-- ========================================================
local function SendCustomItems(ply)
    local items = {}
    for class, data in pairs(SlashMoon.Tasks.CustomItems) do
        if #items >= MAX_CUSTOM_ITEMS then break end
        table.insert(items, {
            class       = class,
            name        = data.name or class,
            type        = data.type or "material",
            icon        = data.icon or "",
            description = data.description or "",
            rarity      = data.rarity or "common",
            stackable   = data.stackable or false,
        })
    end

    net.Start("SN_AdminInv_CustomItems")
        net.WriteUInt(#items, 8)
        for _, item in ipairs(items) do
            net.WriteString(item.class)
            net.WriteString(item.name)
            net.WriteString(item.type)
            net.WriteString(item.icon)
            net.WriteString(item.description)
            net.WriteString(item.rarity)
            net.WriteBool(item.stackable)
        end
    net.Send(ply)
end

local function SendRecipeList(ply)
    local recipes = {}
    for id, recipe in pairs(SlashMoon.Tasks.CustomDeliveryRecipes or {}) do
        if #recipes >= MAX_CUSTOM_RECIPES then break end
        recipes[#recipes + 1] = {
            id = id,
            name = recipe.nameKey or id,
            result = recipe.result,
            ingredients = recipe.ingredients or {},
            craftTime = recipe.craftTime or 5,
        }
    end
    table.sort(recipes, function(a, b) return a.id < b.id end)

    net.Start("SN_AdminInv_RecipeList")
        net.WriteUInt(#recipes, 8)
        for _, recipe in ipairs(recipes) do
            net.WriteString(recipe.id)
            net.WriteString(recipe.name)
            net.WriteString(recipe.result)
            net.WriteFloat(recipe.craftTime)
            net.WriteUInt(#recipe.ingredients, 5)
            for _, ingredient in ipairs(recipe.ingredients) do net.WriteString(ingredient) end
        end
    net.Send(ply)
end

-- ========================================================
-- ОТПРАВКА РЕЗУЛЬТАТА ОПЕРАЦИИ
-- ========================================================
local function SendResult(ply, success, key, ...)
    net.Start("SN_AdminInv_Result")
        net.WriteBool(success)
        net.WriteString(key or "")
        local args = { ... }
        net.WriteUInt(math.min(#args, 15), 4)
        for i = 1, math.min(#args, 15) do net.WriteString(string.sub(tostring(args[i]), 1, 256)) end
    net.Send(ply)
end

-- ========================================================
-- ПОЛУЧИТЬ ВСЕ ПРЕДМЕТЫ (СТАНДАРТНЫЕ + КАСТОМНЫЕ)
-- ========================================================
function SlashMoon.Tasks.GetAllItems()
    local all = {}
    for class, data in pairs(SlashMoon.Tasks.Items or {}) do
        all[class] = data
    end
    for class, data in pairs(SlashMoon.Tasks.CustomItems or {}) do
        all[class] = data
    end
    return all
end

-- ========================================================
-- ОБРАБОТЧИК: ОТКРЫТИЕ АДМИНКИ
-- ========================================================
util.AddNetworkString("SN_AdminInv_RequestOpen")

MODULE:Receive("SN_AdminInv_RequestOpen", function(len, ply)
    if not IsValid(ply) then return end
    if not IsAdminAllowed(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "admin_inv_open", 1.0) then return end

    -- Отправляем данные: все предметы + игроки + кастомные
    local allItems = SlashMoon.Tasks.GetAllItems()
    local itemList = {}
    for class, data in pairs(allItems) do
        if #itemList >= MAX_ADMIN_ITEMS then break end
        table.insert(itemList, {
            class       = class,
            nameKey     = data.nameKey or "",
            name        = data.name or class,
            descriptionKey = data.descKey or "",
            type        = data.type or "material",
            icon        = data.icon or "",
            unique      = data.unique or false,
            custom      = SlashMoon.Tasks.CustomItems[class] ~= nil,
            description = data.description or "",
            rarity      = data.rarity or "common",
            stackable   = data.stackable or false,
        })
    end

    -- Сортировка: по типу, затем по имени
    table.sort(itemList, function(a, b)
        if a.type ~= b.type then return a.type < b.type end
        return a.name < b.name
    end)

    net.Start("SN_AdminInv_Open")
        net.WriteUInt(#itemList, 16)
        for _, item in ipairs(itemList) do
            net.WriteString(item.class)
            net.WriteString(item.nameKey)
            net.WriteString(item.name)
            net.WriteString(item.type)
            net.WriteString(item.icon)
            net.WriteBool(item.unique)
            net.WriteBool(item.custom)
            net.WriteString(item.description)
            net.WriteString(item.descriptionKey or "")
            net.WriteString(item.rarity)
            net.WriteBool(item.stackable)
        end
    net.Send(ply)

    SendPlayerList(ply)
    SendCustomItems(ply)
    SendRecipeList(ply)
end)

local function NormalizeRecipeID(value)
    value = string.lower(TrimBounded(value, 48))
    value = string.gsub(value, "[^a-z0-9_]", "_")
    value = string.gsub(value, "_+", "_")
    value = string.Trim(value, "_")
    if value == "" then return nil end
    return string.StartWith(value, "custom_delivery_") and value or "custom_delivery_" .. value
end

MODULE:Receive("SN_AdminInv_CreateRecipe", function(len, ply)
    if not IsAdminAllowed(ply) or len > MAX_CUSTOM_MESSAGE_BITS then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "admin_recipe_create", 1.0) then return end

    local id = NormalizeRecipeID(net.ReadString())
    local name = TrimBounded(net.ReadString(), 96)
    local result = TrimBounded(net.ReadString(), 64)
    local craftTime = math.Clamp(net.ReadUInt(8), 1, 60)
    local ingredientCount = math.min(net.ReadUInt(5), MAX_RECIPE_INGREDIENTS)
    local ingredients = {}
    for i = 1, ingredientCount do ingredients[i] = TrimBounded(net.ReadString(), 64) end

    if not id or name == "" or #ingredients == 0 then
        SendResult(ply, false, "sn.admin.recipe_invalid")
        return
    end
    if not SlashMoon.Tasks.CustomDeliveryRecipes[id] and table.Count(SlashMoon.Tasks.CustomDeliveryRecipes or {}) >= MAX_CUSTOM_RECIPES then
        SendResult(ply, false, "sn.admin.recipe_limit")
        return
    end

    local allItems = SlashMoon.Tasks.GetAllItems()
    local resultData = allItems[result]
    if not resultData or resultData.stackable ~= true then
        SendResult(ply, false, "sn.admin.recipe_result_invalid")
        return
    end
    for _, ingredient in ipairs(ingredients) do
        if not allItems[ingredient] then
            SendResult(ply, false, "sn.admin.recipe_ingredient_invalid", ingredient)
            return
        end
    end

    SlashMoon.Tasks.CustomDeliveryRecipes = SlashMoon.Tasks.CustomDeliveryRecipes or {}
    SlashMoon.Tasks.CustomDeliveryRecipes[id] = {
        id = id,
        nameKey = name,
        result = result,
        ingredients = ingredients,
        craftTime = craftTime,
        custom = true,
    }
    SlashMoon.Tasks.SaveCustomDeliveryRecipes()
    SendRecipeList(ply)
    SendResult(ply, true, "sn.admin.recipe_created", name)
end)

MODULE:Receive("SN_AdminInv_RemoveRecipe", function(_, ply)
    if not IsAdminAllowed(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "admin_recipe_remove", 0.5) then return end
    local id = TrimBounded(net.ReadString(), 64)
    if not SlashMoon.Tasks.CustomDeliveryRecipes or not SlashMoon.Tasks.CustomDeliveryRecipes[id] then
        SendResult(ply, false, "sn.admin.recipe_not_found")
        return
    end
    SlashMoon.Tasks.CustomDeliveryRecipes[id] = nil
    SlashMoon.Tasks.SaveCustomDeliveryRecipes()
    SendRecipeList(ply)
    SendResult(ply, true, "sn.admin.recipe_removed", id)
end)

-- ========================================================
-- ОБРАБОТЧИК: ВЫДАЧА ПРЕДМЕТА ИГРОКУ
-- Работает и для стандартных, и для кастомных предметов
-- ========================================================
MODULE:Receive("SN_AdminInv_GiveItem", function(len, ply)
    if not IsValid(ply) then return end
    if not IsAdminAllowed(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "admin_inv_give", 0.3) then return end

    local targetSteamID = net.ReadString()
    local itemClass     = net.ReadString()
    local amount        = math.Clamp(tonumber(net.ReadUInt(8)) or 1, 1, 64)

    -- Найти целевого игрока
    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == targetSteamID then target = p break end
    end

    if not IsValid(target) then
        SendResult(ply, false, "sn.admin.player_not_found")
        return
    end

    -- Проверить, что предмет существует (стандартный или кастомный)
    local allItems = SlashMoon.Tasks.GetAllItems()
    if not allItems[itemClass] then
        SendResult(ply, false, "sn.admin.item_not_found")
        return
    end

    -- Выдать предмет(ы) через SlashMoon.Tasks.GiveItem
    for i = 1, amount do
        SlashMoon.Tasks.GiveItem(target, itemClass)
    end

    local itemData = allItems[itemClass]
    local itemName = itemData.nameKey or itemData.name or itemClass
    SendResult(ply, true, "sn.admin.give_success", target:Nick(), itemName, amount)

    -- Уведомление цели
    SlashMoon.Tasks.SendLocalizedChat(target, "sn.admin.received_item", itemName, amount)

    SlashMoon.Debug("[Admin] " .. ply:Nick() .. " выдал " .. amount .. "x " .. itemClass .. " игроку " .. target:Nick())
end)

-- ========================================================
-- ОБРАБОТЧИК: СОЗДАНИЕ КАСТОМНОГО ПРЕДМЕТА
-- Теперь с описанием, редкостью и стакируемостью
-- ========================================================
MODULE:Receive("SN_AdminInv_CreateItem", function(len, ply)
    if not IsValid(ply) then return end
    if not IsAdminAllowed(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "admin_inv_create", 2.0) then return end
    if len > MAX_CUSTOM_MESSAGE_BITS then return end

    local class       = TrimBounded(net.ReadString(), 64)
    local name        = TrimBounded(net.ReadString(), 128)
    local itemType    = TrimBounded(net.ReadString(), 32)
    local icon        = TrimBounded(net.ReadString(), 256)
    local description = TrimBounded(net.ReadString(), 512)
    local rarity      = TrimBounded(net.ReadString(), 32)
    local stackable   = net.ReadBool()

    -- Валидация
    if not class or class == "" or #class > 64 then
        SendResult(ply, false, "sn.admin.invalid_class")
        return
    end

    -- Префикс: кастомные предметы всегда начинаются с custom_
    if not string.StartWith(class, "custom_") then
        class = "custom_" .. class
    end
    if #class > 64 then
        SendResult(ply, false, "sn.admin.invalid_class")
        return
    end

    -- Запрещаем перезапись стандартных предметов
    if SlashMoon.Tasks.Items[class] and not SlashMoon.Tasks.CustomItems[class] then
        SendResult(ply, false, "sn.admin.class_exists")
        return
    end
    if not SlashMoon.Tasks.CustomItems[class] and CustomItemCount() >= MAX_CUSTOM_ITEMS then
        SendResult(ply, false, "sn.admin.custom_limit")
        return
    end

    -- Валидация типа
    local validTypes = {
        weapon = true, material = true, tool = true,
        consumable = true, quest = true, rare = true,
        electronic = true, chemical = true,
    }
    if not validTypes[itemType] then itemType = "material" end

    -- Валидация редкости
    local validRarities = {
        common = true, uncommon = true, rare = true,
        epic = true, legendary = true,
    }
    if not validRarities[rarity] then rarity = "common" end

    -- Регистрация кастомного предмета
    local customData = {
        name        = name ~= "" and name or class,
        type        = itemType,
        icon        = icon ~= "" and icon or nil,
        description = description ~= "" and description or nil,
        rarity      = rarity,
        stackable   = stackable,
        unique      = not stackable, -- Если не стакируемый = уникальный
        custom      = true,
    }

    SlashMoon.Tasks.CustomItems[class] = customData

    -- Также добавляем в общий реестр (чтобы GetItemData находил)
    SlashMoon.Tasks.Items[class] = customData

    SendResult(ply, true, "sn.admin.item_created", class, name)
    SendCustomItems(ply)

    -- Автосохранение кастомных предметов
    hook.Run("SN_CustomItemChanged")

    SlashMoon.Debug("[Admin] " .. ply:Nick() .. " создал кастомный предмет: " .. class .. " (" .. name .. ")")
end)

-- ========================================================
-- ОБРАБОТЧИК: УДАЛЕНИЕ КАСТОМНОГО ПРЕДМЕТА
-- ========================================================
MODULE:Receive("SN_AdminInv_RemoveItem", function(len, ply)
    if not IsValid(ply) then return end
    if not IsAdminAllowed(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "admin_inv_remove", 1.0) then return end

    local class = net.ReadString()

    if not SlashMoon.Tasks.CustomItems[class] then
        SendResult(ply, false, "sn.admin.item_not_custom")
        return
    end

    -- Удаляем из обоих реестров
    SlashMoon.Tasks.CustomItems[class] = nil
    SlashMoon.Tasks.Items[class] = nil

    SendResult(ply, true, "sn.admin.item_removed", class)
    SendCustomItems(ply)

    -- Автосохранение кастомных предметов
    hook.Run("SN_CustomItemChanged")

    SlashMoon.Debug("[Admin] " .. ply:Nick() .. " удалил кастомный предмет: " .. class)
end)

-- ========================================================
-- КОНСОЛЬНАЯ КОМАНДА: sn_admin_inv
-- ========================================================
MODULE:Command("sn_admin_inv", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not IsAdminAllowed(ply) then
        ply:ChatPrint("[SN Tasks] Только SuperAdmin в команде редактора может использовать эту команду!")
        return
    end

    -- Прямой вызов: отправить данные админу (как при SN_AdminInv_RequestOpen)
    local allItems = SlashMoon.Tasks.GetAllItems()
    local itemList = {}
    for class, data in pairs(allItems) do
        if #itemList >= MAX_ADMIN_ITEMS then break end
        table.insert(itemList, {
            class       = class,
            nameKey     = data.nameKey or "",
            name        = data.name or class,
            type        = data.type or "material",
            icon        = data.icon or "",
            unique      = data.unique or false,
            custom      = SlashMoon.Tasks.CustomItems[class] ~= nil,
            description = data.description or "",
            rarity      = data.rarity or "common",
            stackable   = data.stackable or false,
        })
    end

    table.sort(itemList, function(a, b)
        if a.type ~= b.type then return a.type < b.type end
        return a.name < b.name
    end)

    net.Start("SN_AdminInv_Open")
        net.WriteUInt(#itemList, 16)
        for _, item in ipairs(itemList) do
            net.WriteString(item.class)
            net.WriteString(item.nameKey)
            net.WriteString(item.name)
            net.WriteString(item.type)
            net.WriteString(item.icon)
            net.WriteBool(item.unique)
            net.WriteBool(item.custom)
            net.WriteString(item.description)
            net.WriteString(item.descriptionKey or "")
            net.WriteString(item.rarity)
            net.WriteBool(item.stackable)
        end
    net.Send(ply)

    SendPlayerList(ply)
    SendCustomItems(ply)
    SendRecipeList(ply)
end)

-- Для серверной консоли
MODULE:Command("sn_admin_give", function(ply, cmd, args)
    -- Серверная консоль или SuperAdmin в команде редактора
    if IsValid(ply) and not IsAdminAllowed(ply) then return end

    local targetName = args[1]
    local itemClass  = args[2]
    local amount     = tonumber(args[3]) or 1

    if not targetName or not itemClass then
        if IsValid(ply) then
            ply:ChatPrint("Использование: sn_admin_give <ник> <класс_предмета> [кол-во]")
        else
            SlashMoon.Log("Использование: sn_admin_give <ник> <класс_предмета> [кол-во]")
        end
        return
    end

    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), string.lower(targetName), 1, true) then
            target = p
            break
        end
    end

    if not IsValid(target) then
        if IsValid(ply) then ply:ChatPrint("Игрок не найден: " .. targetName)
        else SlashMoon.Log("Игрок не найден: " .. targetName) end
        return
    end

    local allItems = SlashMoon.Tasks.GetAllItems()
    if not allItems[itemClass] then
        if IsValid(ply) then ply:ChatPrint("Предмет не найден: " .. itemClass)
        else SlashMoon.Log("Предмет не найден: " .. itemClass) end
        return
    end

    amount = math.Clamp(amount, 1, 64)
    for i = 1, amount do
        SlashMoon.Tasks.GiveItem(target, itemClass)
    end

    local msg = string.format("[SN Admin] Выдано %dx %s игроку %s", amount, itemClass, target:Nick())
    if IsValid(ply) then ply:ChatPrint(msg) else SlashMoon.Log(msg) end
    SlashMoon.Tasks.SendLocalizedChat(target, "sn.admin.received_item", allItems[itemClass].nameKey or allItems[itemClass].name or itemClass, amount)
end, nil, "Выдать предмет игроку (SuperAdmin)")

-- ========================================================
-- ПЕРИОДИЧЕСКОЕ ОБНОВЛЕНИЕ СПИСКА ИГРОКОВ
-- (когда админка открыта)
-- ========================================================
MODULE:Hook("Think", "SN_AdminInv_Think", function()
    -- Обновляем список игроков каждые 2 секунды для открытых админок
    -- (оптимизация: только если кто-то запрашивал)
end)

-- ========================================================
-- СОХРАНЕНИЕ/ЗАГРУЗКА КАСТОМНЫХ ПРЕДМЕТОВ
-- ========================================================
local CUSTOM_ITEMS_FILE = "sn_tasks/custom_items.json"

function SlashMoon.Tasks.SaveCustomDeliveryRecipes()
    file.CreateDir("sn_tasks")
    local data = {}
    for id, recipe in pairs(SlashMoon.Tasks.CustomDeliveryRecipes or {}) do
        if #data >= MAX_CUSTOM_RECIPES then break end
        data[#data + 1] = {
            id = id,
            name = recipe.nameKey,
            result = recipe.result,
            ingredients = recipe.ingredients,
            craftTime = recipe.craftTime,
        }
    end
    local json = util.TableToJSON(data, true) or "[]"
    local tempPath = "sn_tasks/custom_delivery_recipes.tmp.json"
    file.Write(tempPath, json)
    if file.Read(tempPath, "DATA") ~= json then
        file.Delete(tempPath)
        SlashMoon.Debug("[Admin] Не удалось записать временный файл рецептов")
        return false
    end
    file.Delete(CUSTOM_RECIPES_FILE)
    file.Rename(tempPath, CUSTOM_RECIPES_FILE)
    if file.Read(CUSTOM_RECIPES_FILE, "DATA") ~= json then
        file.Write(CUSTOM_RECIPES_FILE, json)
        file.Delete(tempPath)
    end
    if file.Read(CUSTOM_RECIPES_FILE, "DATA") ~= json then
        SlashMoon.Debug("[Admin] Не удалось сохранить рецепты доставки: " .. CUSTOM_RECIPES_FILE)
        return false
    end
    return true
end

function SlashMoon.Tasks.LoadCustomDeliveryRecipes()
    SlashMoon.Tasks.CustomDeliveryRecipes = SlashMoon.Tasks.CustomDeliveryRecipes or {}
    local raw = file.Read(CUSTOM_RECIPES_FILE, "DATA")
    local data = raw and util.JSONToTable(raw) or {}
    local allItems = SlashMoon.Tasks.GetAllItems()
    for _, recipe in ipairs(istable(data) and data or {}) do
        local id = NormalizeRecipeID(recipe.id or "")
        local resultData = allItems[recipe.result]
        if not id or not resultData or resultData.stackable ~= true or not istable(recipe.ingredients) then continue end
        local ingredients = {}
        for _, ingredient in ipairs(recipe.ingredients) do
            if #ingredients >= MAX_RECIPE_INGREDIENTS then break end
            if allItems[ingredient] then ingredients[#ingredients + 1] = ingredient end
        end
        if #ingredients == 0 then continue end
        SlashMoon.Tasks.CustomDeliveryRecipes[id] = {
            id = id,
            nameKey = TrimBounded(recipe.name or id, 96),
            result = recipe.result,
            ingredients = ingredients,
            craftTime = math.Clamp(math.floor(tonumber(recipe.craftTime) or 5), 1, 60),
            custom = true,
        }
    end
end

function SlashMoon.Tasks.SaveCustomItems()
    local data = {}
    for class, itemData in pairs(SlashMoon.Tasks.CustomItems) do
        if #data >= MAX_CUSTOM_ITEMS then break end
        table.insert(data, {
            class       = class,
            name        = itemData.name,
            type        = itemData.type,
            icon        = itemData.icon or "",
            description = itemData.description or "",
            rarity      = itemData.rarity or "common",
            stackable   = itemData.stackable or false,
        })
    end

    file.CreateDir("sn_tasks")
    local json = util.TableToJSON(data, true)
    file.Write(CUSTOM_ITEMS_FILE, json)

    SlashMoon.Debug("[Admin] Кастомные предметы сохранены (" .. #data .. ")")
end

function SlashMoon.Tasks.LoadCustomItems()
    if not file.Exists(CUSTOM_ITEMS_FILE, "DATA") then return end

    local json = file.Read(CUSTOM_ITEMS_FILE, "DATA")
    local data = util.JSONToTable(json)
    if not data then return end

    local count = 0
    local loadedClasses = {}
    for _, itemData in ipairs(data) do
        if count >= MAX_CUSTOM_ITEMS then break end
        if itemData.class and itemData.name and itemData.type then
            local class = TrimBounded(itemData.class, 64)
            if not string.StartWith(class, "custom_") or #class > 64 then continue end
            if loadedClasses[class] or SlashMoon.Tasks.CustomItems[class] or (SlashMoon.Tasks.Items[class] and not SlashMoon.Tasks.CustomItems[class]) then continue end
            local customItem = {
                name   = TrimBounded(itemData.name, 128),
                type   = TrimBounded(itemData.type, 32),
                icon   = TrimBounded(itemData.icon or "", 256) ~= "" and TrimBounded(itemData.icon, 256) or nil,
                unique = not (itemData.stackable or false),
                custom = true,
            }

            local validTypes = { weapon = true, material = true, tool = true, consumable = true, quest = true, rare = true, electronic = true, chemical = true }
            local validRarities = { common = true, uncommon = true, rare = true, epic = true, legendary = true }
            if not validTypes[customItem.type] then customItem.type = "material" end
            local rarity = TrimBounded(itemData.rarity or "common", 32)
            customItem.rarity = validRarities[rarity] and rarity or "common"

            -- Новые поля
            if itemData.description and itemData.description ~= "" then
                customItem.description = TrimBounded(itemData.description, 512)
            end
            if itemData.stackable then
                customItem.stackable = true
            end

            SlashMoon.Tasks.CustomItems[class] = customItem
            SlashMoon.Tasks.Items[class] = customItem
            loadedClasses[class] = true
            count = count + 1
        end
    end

    SlashMoon.Debug("[Admin] Загружено кастомных предметов: " .. count)
end

-- Загрузка при старте
MODULE:Hook("Initialize", "SN_AdminInv_LoadCustom", function()
    SlashMoon.Tasks.LoadCustomItems()
end)

-- Фоллбэк: если Initialize уже прошёл
timer.Simple(3, function()
    if table.IsEmpty(SlashMoon.Tasks.CustomItems) then
        SlashMoon.Tasks.LoadCustomItems()
    end
    SlashMoon.Tasks.LoadCustomDeliveryRecipes()
end)

-- Автосохранение при создании/удалении
MODULE:Hook("SN_CustomItemChanged", "SN_AdminInv_AutoSave", function()
    SlashMoon.Tasks.SaveCustomItems()
end)
