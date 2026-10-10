-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Workbench Entity (Server — Crafting System)
-- Верстак для компоновки предметов в новые
-- ========================================================
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- === СЕТЕВЫЕ СТРОКИ ===
util.AddNetworkString("SN_Workbench_Open")
util.AddNetworkString("SN_Workbench_Craft")
util.AddNetworkString("SN_Workbench_Cancel")
util.AddNetworkString("SN_Workbench_Progress")
util.AddNetworkString("SN_Workbench_Result")
util.AddNetworkString("SN_Workbench_PinRecipe")
util.AddNetworkString("SN_Workbench_PinnedRecipe")
util.AddNetworkString("SN_Workbench_RequestPinnedRecipe")

-- === НАСТРОЙКИ ===
local WORKBENCH_RANGE      = 80    -- Дистанция E-взаимодействия
local WORKBENCH_CANCEL_DIST = 150  -- Дистанция отмены крафта
local CRAFT_TICK_INTERVAL   = 0.1  -- Интервал обновления прогресса

-- ========================================================
-- РЕЕСТР РЕЦЕПТОВ
-- ========================================================
SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Recipes = {}

local function GetActiveRecipes()
    local recipes = {}
    for taskID, state in pairs(SlashMoon.Tasks.ActiveState or {}) do
        if string.StartWith(taskID, "delivery") and not state.done and not state.failed and state.recipe then
            recipes[#recipes + 1] = state.recipe
        end
    end
    return recipes
end

local function SendPinnedRecipe(ply)
    local recipe = ply.SN_PinnedRecipe

    net.Start("SN_Workbench_PinnedRecipe")
        net.WriteBool(recipe ~= nil)
        if recipe then
            net.WriteString(recipe.id)
            net.WriteString(recipe.nameKey or "")
            net.WriteString(recipe.result or "")
            net.WriteUInt(math.min(#recipe.ingredients, 255), 8)
            for _, ingredient in ipairs(recipe.ingredients) do
                net.WriteString(ingredient)
            end
        end
    net.Send(ply)
end

local function FindActiveRecipe(recipeID)
    for _, recipe in ipairs(GetActiveRecipes()) do
        if recipe.id == recipeID then return recipe end
    end
end

-- ========================================================
-- ИНИЦИАЛИЗАЦИЯ СУЩНОСТИ
-- ========================================================
function ENT:Initialize()
    if util.IsValidModel("models/props_lab/workspace004.mdl") then
        self:SetModel("models/props_lab/workspace004.mdl")
    else
        self:SetModel("models/props_interiors/Furniture_Couch02a.mdl")
    end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)   -- Включаем E-взаимодействие

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    -- Анти-спам использования
    self.NextUse = 0

    -- NW2 переменные для клиентской синхронизации
    self:SetNW2Bool("SN_Workbench", true)
    self:SetNW2Bool("SN_Crafting", false)
    self:SetNW2Entity("SN_Crafter", NULL)
    self:SetNW2String("SN_RecipeResult", "")

    -- Внутреннее состояние крафта
    self.CraftPlayer    = NULL
    self.CraftRecipe    = nil
    self.CraftStartTime = 0
    self.CraftEndTime   = 0
    self.CraftTimerName = nil
    self.RefundedItems  = {}
end

function ENT:OnTakeDamage() end

-- ========================================================
-- ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: СПИСОК ДОСТУПНЫХ РЕЦЕПТОВ
-- Проверяет рюкзак игрока на наличие всех ингредиентов
-- ========================================================
function SlashMoon.Tasks.GetCraftableRecipes(ply)
    if not IsValid(ply) then return {} end

    ply.SN_Backpack = ply.SN_Backpack or {}
    local craftable = {}

    for _, recipe in ipairs(GetActiveRecipes()) do
        -- Подсчёт необходимых ингредиентов
        local needed = {}
        for _, ing in ipairs(recipe.ingredients) do
            needed[ing] = (needed[ing] or 0) + 1
        end

        -- Подсчёт имеющихся ингредиентов в рюкзаке (с учётом стаков)
        local available = {}
        for _, item in ipairs(ply.SN_Backpack) do
            local parsed = SlashMoon.Tasks.ParseItemEntry(item)
            available[parsed.baseClass] = (available[parsed.baseClass] or 0) + parsed.count
        end

        -- Проверка: каждого ингредиента хватает?
        local canCraft = true
        for ingClass, count in pairs(needed) do
            if (available[ingClass] or 0) < count then
                canCraft = false
                break
            end
        end

        table.insert(craftable, {
            id          = recipe.id,
            nameKey     = recipe.nameKey,
            result      = recipe.result,
            ingredients = recipe.ingredients,
            craftTime   = recipe.craftTime,
            canCraft    = canCraft,
        })
    end

    return craftable
end

-- ========================================================
-- ОТПРАВКА СПИСКА РЕЦЕПТОВ КЛИЕНТУ
-- ========================================================
local function SendRecipesToClient(ply, workbench)
    local recipes = SlashMoon.Tasks.GetCraftableRecipes(ply)

    net.Start("SN_Workbench_Open")
        net.WriteEntity(workbench)
        net.WriteUInt(#recipes, 8)
        for _, r in ipairs(recipes) do
            net.WriteString(r.id)
            net.WriteString(r.nameKey)
            net.WriteString(r.result)
            net.WriteFloat(r.craftTime)
            net.WriteBool(r.canCraft)

            -- Ингредиенты
            net.WriteUInt(#r.ingredients, 8)
            for _, ing in ipairs(r.ingredients) do
                net.WriteString(ing)
            end
        end

        -- Рюкзак игрока (только чтение)
        ply.SN_Backpack = ply.SN_Backpack or {}
        local backpackCount = math.min(#ply.SN_Backpack, 255)
        net.WriteUInt(backpackCount, 8)
        for i = 1, backpackCount do
            net.WriteString(ply.SN_Backpack[i])
        end
    net.Send(ply)
end

-- ========================================================
-- УДАЛЕНИЕ ИНГРЕДИЕНТОВ ИЗ РЮКЗАКА
-- С учётом количества (например, 2x mat_scrap + 1x mat_wire)
-- ========================================================
local function RemoveIngredients(ply, recipe)
    ply.SN_Backpack = ply.SN_Backpack or {}

    -- Подсчёт необходимых ингредиентов
    local needed = {}
    for _, ing in ipairs(recipe.ingredients) do
        needed[ing] = (needed[ing] or 0) + 1
    end

    -- Удаление из рюкзака с учётом стаков
    -- Стратегия: проходим по рюкзаку, уменьшаем счётчики в стаках
    local removed = {}
    for ingClass, needCount in pairs(needed) do
        local remaining = needCount

        for i = #ply.SN_Backpack, 1, -1 do
            if remaining <= 0 then break end

            local item = ply.SN_Backpack[i]
            local parsed = SlashMoon.Tasks.ParseItemEntry(item)

            if parsed.baseClass == ingClass then
                if parsed.count <= remaining then
                    -- Забираем весь стак целиком
                    table.insert(removed, item)
                    table.remove(ply.SN_Backpack, i)
                    remaining = remaining - parsed.count
                else
                    -- Забираем часть из стака
                    local newCount = parsed.count - remaining
                    table.insert(removed, ingClass .. ":" .. remaining)
                    ply.SN_Backpack[i] = ingClass .. ":" .. newCount
                    remaining = 0
                end
            end
        end
    end

    return removed
end

-- ========================================================
-- ВОЗВРАТ ИНГРЕДИЕНТОВ (ОТМЕНА КРАФТА)
-- ========================================================
local function RefundIngredients(ply, items)
    if not IsValid(ply) then return end
    ply.SN_Backpack = ply.SN_Backpack or {}
    for _, item in ipairs(items) do
        table.insert(ply.SN_Backpack, item)
    end
    SlashMoon.Tasks.SyncInventory(ply)
end

-- ========================================================
-- ОТМЕНА КРАФТА НА ВЕРСТАКЕ
-- ========================================================
local function CancelCraft(workbench, reason)
    if not workbench or not workbench.CraftRecipe then return end

    local ply = workbench.CraftPlayer
    local refundedItems = table.Copy(workbench.RefundedItems or {})

    if workbench.CraftTimerName then
        MODULE:RemoveTimer(workbench.CraftTimerName)
        workbench.CraftTimerName = nil
    end

    -- Возврат ингредиентов
    if IsValid(ply) and #refundedItems > 0 then
        RefundIngredients(ply, refundedItems)
    end

    -- Сброс состояния
    workbench.CraftPlayer    = NULL
    workbench.CraftRecipe    = nil
    workbench.CraftStartTime = 0
    workbench.CraftEndTime   = 0
    workbench.RefundedItems  = {}

    if IsValid(workbench) then
        workbench:SetNW2Bool("SN_Crafting", false)
        workbench:SetNW2Entity("SN_Crafter", NULL)
        workbench:SetNW2String("SN_RecipeResult", "")
    end

    -- Уведомление клиента об отмене
    if IsValid(ply) then
        net.Start("SN_Workbench_Result")
            net.WriteBool(false)
            net.WriteString(reason or "cancelled")
        net.Send(ply)
    end

    SlashMoon.Debug("[Верстак] Крафт отменён: " .. (reason or "unknown"))
end

-- ========================================================
-- ЗАВЕРШЕНИЕ КРАФТА
-- ========================================================
local function FinishCraft(workbench)
    if not IsValid(workbench) then return end
    local ply = workbench.CraftPlayer
    local recipe = workbench.CraftRecipe

    if not IsValid(ply) or not recipe then
        CancelCraft(workbench, "invalid")
        return
    end

    -- Выдача результата
    local added = SlashMoon.Tasks.GiveItem(ply, recipe.result)
    if not added then
        CancelCraft(workbench, "give_failed")
        return
    end

    -- Звук успеха
    ply:EmitSound("items/ammo_pickup.wav")

    -- Сброс состояния
    workbench.CraftPlayer    = NULL
    workbench.CraftRecipe    = nil
    workbench.CraftStartTime = 0
    workbench.CraftEndTime   = 0
    workbench.CraftTimerName = nil
    workbench.RefundedItems  = {}

    workbench:SetNW2Bool("SN_Crafting", false)
    workbench:SetNW2Entity("SN_Crafter", NULL)
    workbench:SetNW2String("SN_RecipeResult", "")

    -- Уведомление клиента об успехе
    net.Start("SN_Workbench_Result")
        net.WriteBool(true)
        net.WriteString(recipe.result)
    net.Send(ply)

    local resultData = SlashMoon.Tasks.GetItemData(recipe.result)
    SlashMoon.Tasks.SendLocalizedChat(ply, "sn.workbench.craft_success", resultData.nameKey or resultData.name)

    SlashMoon.Debug("[Верстак] " .. ply:Nick() .. " скрафтил " .. recipe.result)
end

-- ========================================================
-- ЗАПУСК КРАФТА
-- ========================================================
local function StartCraft(ply, workbench, recipeId)
    if not IsValid(ply) or not IsValid(workbench) then return end
    if not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end
    if ply:GetNW2Bool("KillerMaskEquiped", false) then return end
    if ply:GetPos():DistToSqr(workbench:GetPos()) > WORKBENCH_RANGE * WORKBENCH_RANGE then return end

    -- Проверка: верстак уже занят?
    if workbench:GetNW2Bool("SN_Crafting", false) then
        -- Если тот же игрок — игнорируем
        if workbench:GetNW2Entity("SN_Crafter") == ply then return end

        net.Start("SN_Workbench_Result")
            net.WriteBool(false)
            net.WriteString("busy")
        net.Send(ply)
        return
    end

    -- Поиск рецепта по ID
    local recipe = nil
    for _, r in ipairs(GetActiveRecipes()) do
        if r.id == recipeId then recipe = r break end
    end
    if not recipe then return end

    -- Проверка ингредиентов (повторная, на случай изменений инвентаря)
    local craftable = SlashMoon.Tasks.GetCraftableRecipes(ply)
    local canCraft = false
    for _, cr in ipairs(craftable) do
        if cr.id == recipeId and cr.canCraft then
            canCraft = true
            break
        end
    end

    if not canCraft then
        net.Start("SN_Workbench_Result")
            net.WriteBool(false)
            net.WriteString("missing_ingredients")
        net.Send(ply)
        return
    end

    -- Удаление ингредиентов из рюкзака
    local removed = RemoveIngredients(ply, recipe)
    SlashMoon.Tasks.SyncInventory(ply)

    -- Установка состояния крафта
    workbench.CraftPlayer    = ply
    workbench.CraftRecipe    = recipe
    workbench.CraftStartTime = CurTime()
    workbench.CraftEndTime   = CurTime() + recipe.craftTime
    workbench.RefundedItems  = removed

    workbench:SetNW2Bool("SN_Crafting", true)
    workbench:SetNW2Entity("SN_Crafter", ply)
    workbench:SetNW2String("SN_RecipeResult", recipe.result)

    -- Таймер прогресса
    local timerName = "SN_Workbench_Craft_" .. workbench:EntIndex()
    workbench.CraftTimerName = timerName

    MODULE:Timer(timerName, CRAFT_TICK_INTERVAL, 0, function()
        if not IsValid(workbench) then
            MODULE:RemoveTimer(timerName)
            if IsValid(ply) and #removed > 0 then RefundIngredients(ply, removed) end
            return
        end
        if not IsValid(ply) then
            CancelCraft(workbench, "player_left")
            return
        end

        -- Проверка: игрок жив?
        if not ply:Alive() then
            CancelCraft(workbench, "player_died")
            return
        end

        -- Проверка: игрок рядом?
        if ply:GetPos():Distance(workbench:GetPos()) > WORKBENCH_CANCEL_DIST then
            CancelCraft(workbench, "player_too_far")
            return
        end

        -- Расчёт прогресса
        local now = CurTime()
        local progress = math.Clamp((now - workbench.CraftStartTime) / recipe.craftTime, 0, 1)

        -- Отправка прогресса клиенту
        net.Start("SN_Workbench_Progress")
            net.WriteFloat(progress)
        net.Send(ply)

        -- Завершение крафта
        if progress >= 1 then
            MODULE:RemoveTimer(timerName)
            FinishCraft(workbench)
        end
    end)

    SlashMoon.Debug("[Верстак] " .. ply:Nick() .. " начал крафт: " .. recipe.id)
end

-- ========================================================
-- СЕТЕВЫЕ ОБРАБОТЧИКИ (КЛИЕНТ → СЕРВЕР)
-- ========================================================

-- Запрос крафта
MODULE:Receive("SN_Workbench_Craft", function(len, ply)
    if not IsValid(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "workbench_craft", 0.5) then return end

    local workbench = net.ReadEntity()
    local recipeId  = net.ReadString()

    if not IsValid(workbench) or workbench:GetClass() ~= "sn_workbench" then return end
    if ply:GetPos():DistToSqr(workbench:GetPos()) > WORKBENCH_RANGE * WORKBENCH_RANGE then return end

    StartCraft(ply, workbench, recipeId)
end)

-- Отмена крафта
MODULE:Receive("SN_Workbench_Cancel", function(len, ply)
    if not IsValid(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "workbench_cancel", 0.5) then return end

    local workbench = net.ReadEntity()

    if not IsValid(workbench) or workbench:GetClass() ~= "sn_workbench" then return end

    -- Только текущий крафтер может отменить
    if workbench:GetNW2Entity("SN_Crafter") ~= ply then return end

    CancelCraft(workbench, "player_cancelled")
end)

MODULE:Receive("SN_Workbench_PinRecipe", function(len, ply)
    if not IsValid(ply) then return end
    if not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "workbench_pin_recipe", 0.25) then return end

    local recipeID = net.ReadString()
    if #recipeID > 128 then return end

    if recipeID == "" then
        ply.SN_PinnedRecipe = nil
        SendPinnedRecipe(ply)
        return
    end

    local recipe = FindActiveRecipe(recipeID)
    if not recipe then return end

    ply.SN_PinnedRecipe = {
        id = recipe.id,
        nameKey = recipe.nameKey,
        result = recipe.result,
        ingredients = table.Copy(recipe.ingredients),
    }
    SendPinnedRecipe(ply)
end)

MODULE:Receive("SN_Workbench_RequestPinnedRecipe", function(len, ply)
    if not IsValid(ply) then return end
    SendPinnedRecipe(ply)
end)

-- ========================================================
-- E-ВЗАИМОДЕЙСТВИЕ (ОТКРЫТИЕ ВЕРСТАКА)
-- Стандартный ENT:Use — надёжнее, чем PlayerButtonDown
-- ========================================================
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if not SlashMoon.Tasks.Game.IsSurvivor(activator) then return end
    if activator:GetNW2Bool("KillerMaskEquiped", false) then return end

    -- Анти-спам
    if CurTime() < self.NextUse then return end
    self.NextUse = CurTime() + 0.5

    -- Если верстак занят другим игроком — не открываем
    if self:GetNW2Bool("SN_Crafting", false) and self:GetNW2Entity("SN_Crafter") ~= activator then
        net.Start("SN_Workbench_Result")
            net.WriteBool(false)
            net.WriteString("busy")
        net.Send(activator)
        return
    end

    SendRecipesToClient(activator, self)
end

-- ========================================================
-- ОЧИСТКА ПРИ УДАЛЕНИИ СУЩНОСТИ
-- ========================================================
function ENT:OnRemove()
    -- Отменяем активный крафт
    if self.CraftRecipe then
        CancelCraft(self, "workbench_removed")
    end
end

MODULE:Hook("SN_Game_RoundEnd", "SN_Workbench_ClearPinnedRecipes", function()
    for _, ply in ipairs(player.GetAll()) do
        ply.SN_PinnedRecipe = nil
        SendPinnedRecipe(ply)
    end
end)
