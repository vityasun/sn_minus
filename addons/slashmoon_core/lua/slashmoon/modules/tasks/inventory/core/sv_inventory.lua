-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Server Inventory (Optimized Network + Anti-Spam)
-- ========================================================
if not SERVER then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Config = SlashMoon.Tasks.Config or {}
SlashMoon.Tasks.Config.MaxHotbar = SlashMoon.Tasks.Config.MaxHotbar or 3
SlashMoon.Tasks.Config.AlwaysAllowed = SlashMoon.Tasks.Config.AlwaysAllowed or {
    ["sn_empty_hands"] = true,
    ["weapon_empty_hands"] = true,
    ["weapon_physgun"] = true,
    ["gmod_tool"] = true,
    ["gmod_camera"] = true,
    ["weapon_killer_axe"] = true
    ,["sn_corpse_scanner"] = true
    ,["sn_investigation_tablet"] = true
}

-- === НАСТРОЙКИ АНТИ-СПАМА ===
local INV_ACTION_COOLDOWN   = 0.3   -- Кулдаун между действиями с инвентарём
local INV_REQUEST_COOLDOWN  = 1.0   -- Кулдаун запроса синхронизации
local LOOT_REQUEST_COOLDOWN = 1.5   -- Кулдаун обыска трупа
local LOOT_TAKE_COOLDOWN    = 0.5   -- Кулдаун взятия лута
local MAX_BACKPACK_ITEMS    = 255
local MAX_STACK_COUNT       = 9999
local MAX_SYNC_BYTES        = 65535

-- === НАСТРОЙКИ СЕТЕВОЙ ОПТИМИЗАЦИИ ===
local USE_COMPRESSED_SYNC   = true  -- Использовать util.TableToJSON + util.Compress
local SYNC_COMPRESS_LEVEL   = 5     -- Уровень сжатия (1-9)

-- === КЭШИРОВАНИЕ ДАННЫХ ПРЕДМЕТОВ ===
local ItemDataCache = {}
local ItemCacheTimeout = 60  -- Очистка кэша каждые 60 секунд

-- Очистка кэша предметов
MODULE:Timer("SN_Inv_CacheClear", ItemCacheTimeout, 0, function()
    ItemDataCache = {}
end)

util.AddNetworkString("SN_Inv_Sync")
util.AddNetworkString("SN_Inv_RequestSync")
util.AddNetworkString("SN_Inv_Action")
util.AddNetworkString("SN_Inv_RequestLoot")
util.AddNetworkString("SN_Inv_OpenLootUI")
util.AddNetworkString("SN_Inv_TakeLoot")
util.AddNetworkString("SN_Inv_ItemReceived")

local function NotifyItemReceived(ply, class)
    if not IsValid(ply) or not isstring(class) or class == "" then return end
    net.Start("SN_Inv_ItemReceived")
        net.WriteString(class)
    net.Send(ply)
end

-- ========================================================
-- ОПТИМИЗИРОВАННАЯ СИНХРОНИЗАЦИЯ ИНВЕНТАРЯ
-- Вместо net.WriteTable используем JSON + Compress + WriteData
-- ========================================================

function SlashMoon.Tasks.SyncInventory(ply)
    if not IsValid(ply) then return end
    ply.SN_Backpack = ply.SN_Backpack or {}
    ply.SN_Hotbar = ply.SN_Hotbar or {}

    if USE_COMPRESSED_SYNC then
        -- Оптимизированный путь: JSON -> Compress -> net.WriteData
        local data = {
            bp = ply.SN_Backpack,
            hb = ply.SN_Hotbar
        }
        local json = util.TableToJSON(data)
        local compressed = util.Compress(json)
        if not compressed or #compressed > MAX_SYNC_BYTES then
            ErrorNoHalt(string.format("[SN Inventory] Sync payload for %s is too large\n", ply:Nick()))
            return false
        end

        net.Start("SN_Inv_Sync")
        net.WriteBool(true) -- Флаг: сжатые данные
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)
        net.Send(ply)
    else
        -- Fallback: классический net.WriteTable
        net.Start("SN_Inv_Sync")
        net.WriteBool(false)
        net.WriteTable(ply.SN_Backpack)
        net.WriteTable(ply.SN_Hotbar)
        net.Send(ply)
    end
    return true
end

-- ========================================================
-- ДЕЛЬТА-СИНХРОНИЗАЦИЯ (только изменения)
-- Для частых микро-обновлений (например, топливо канистры)
-- ========================================================

util.AddNetworkString("SN_Inv_DeltaUpdate")

function SlashMoon.Tasks.SyncInventoryDelta(ply, updates)
    if not IsValid(ply) then return end
    -- updates = { { type = "hotbar", slot = 1, value = "weapon_gascan:50" }, ... }
    net.Start("SN_Inv_DeltaUpdate")
    net.WriteUInt(#updates, 8)
    for _, upd in ipairs(updates) do
        net.WriteString(upd.type)   -- "hotbar" or "backpack"
        net.WriteUInt(upd.slot or 0, 8)
        net.WriteString(upd.value or "")
    end
    net.Send(ply)
end

-- ========================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ========================================================

local function IsAlreadyInHotbar(ply, class)
    class = string.Split(class or "", ":")[1]
    for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
        if ply.SN_Hotbar and ply.SN_Hotbar[i] then
            local hbClass = string.Split(ply.SN_Hotbar[i], ":")[1]
            if hbClass == class then return true end
        end
    end
    return false
end

local function IsValidHotbarSlot(slot)
    return isnumber(slot) and slot >= 1 and slot <= SlashMoon.Tasks.Config.MaxHotbar
end

local function CanUseInventory(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if SlashMoon.TEAM_EDITOR and ply:Team() == SlashMoon.TEAM_EDITOR then return false end
    if ply.IsSurvivor then
        if not ply:IsSurvivor() then return false end
    elseif ply:Team() ~= TEAM_SURVIVOR then
        return false
    end
    if ply:GetNW2Bool("fhi_escaped", false) or ply:GetNW2Bool("KillerMaskEquiped", false) then return false end
    return true
end

local function CanLootCorpse(ply)
    return SlashMoon.Tasks.Game.CanLootCorpse(ply)
end

-- ══════════════════════════════════════════════════════════════════════
-- UNIQUE ITEM SUPPORT
-- Проверка: есть ли предмет в инвентаре (хотбар + рюкзак)?
-- ══════════════════════════════════════════════════════════════════════
local function IsItemInInventory(ply, baseClass)
    -- Хотбар
    if IsAlreadyInHotbar(ply, baseClass) then return true end

    -- Рюкзак
    if ply.SN_Backpack then
        for _, item in ipairs(ply.SN_Backpack) do
            local bc = string.Split(item, ":")[1]
            if bc == baseClass then return true end
        end
    end

    -- Проверка GMod: HasWeapon (на случай если свеп уже выдан, но ещё не в SN_системе)
    if ply:HasWeapon(baseClass) then return true end

    return false
end

-- Дать патроны для оружия (при дубликате unique предмета)
-- Читает SWEP.Primary.DefaultClip / SWEP.Secondary.DefaultClip
local function GiveAmmoForWeapon(ply, baseClass)
    -- Кэширование данных оружия
    if not ItemDataCache[baseClass] then
        local swepTable = weapons.Get(baseClass)
        if not swepTable then 
            ItemDataCache[baseClass] = { exists = false }
            return 0 
        end
        
        ItemDataCache[baseClass] = {
            exists = true,
            primaryAmmo = swepTable.Primary and swepTable.Primary.Ammo or "none",
            primaryClip = swepTable.Primary and swepTable.Primary.DefaultClip or 0,
            secondaryAmmo = swepTable.Secondary and swepTable.Secondary.Ammo or "none",
            secondaryClip = swepTable.Secondary and swepTable.Secondary.DefaultClip or 0
        }
    end
    
    local cache = ItemDataCache[baseClass]
    if not cache.exists then return 0 end

    local totalGiven = 0

    -- Primary ammo
    if cache.primaryAmmo and cache.primaryAmmo ~= "none" and cache.primaryClip > 0 then
        ply:GiveAmmo(cache.primaryClip, cache.primaryAmmo)
        totalGiven = totalGiven + cache.primaryClip
    end

    -- Secondary ammo
    if cache.secondaryAmmo and cache.secondaryAmmo ~= "none" and cache.secondaryClip > 0 then
        ply:GiveAmmo(cache.secondaryClip, cache.secondaryAmmo)
        totalGiven = totalGiven + cache.secondaryClip
    end

    return totalGiven
end

local function GetWeaponDefinition(baseClass)
    return weapons.Get(baseClass) or {}
end

local function GetAmmoTypes(baseClass)
    local def = GetWeaponDefinition(baseClass)
    local result = {}
    for _, weaponData in ipairs({ def.Primary, def.Secondary }) do
        local ammoName = weaponData and weaponData.Ammo
        local ammoType = isstring(ammoName) and game.GetAmmoID(ammoName) or -1
        if ammoType and ammoType >= 0 then result[ammoType] = true end
    end
    return result
end

local function GetWeaponState(ply, baseClass)
    ply.SN_WeaponStates = ply.SN_WeaponStates or {}
    local state = ply.SN_WeaponStates[baseClass]
    if state then return state end

    local def = GetWeaponDefinition(baseClass)
    local primary = def.Primary or {}
    local secondary = def.Secondary or {}
    local primaryClipSize = tonumber(primary.ClipSize) or -1
    local secondaryClipSize = tonumber(secondary.ClipSize) or -1
    local primaryDefault = math.max(0, tonumber(primary.DefaultClip) or 0)
    local secondaryDefault = math.max(0, tonumber(secondary.DefaultClip) or 0)
    state = {
        clip1 = primaryClipSize > 0 and math.min(primaryClipSize, primaryDefault) or -1,
        clip2 = secondaryClipSize > 0 and math.min(secondaryClipSize, secondaryDefault) or -1,
    }
    ply.SN_WeaponStates[baseClass] = state

    -- Clipless weapons consume reserve ammo. Seed their initial charge once,
    -- without adding to ammo already granted by the original pickup.
    for _, weaponData in ipairs({ primary, secondary }) do
        local clipSize = tonumber(weaponData.ClipSize) or -1
        local defaultClip = tonumber(weaponData.DefaultClip) or 0
        local ammoType = isstring(weaponData.Ammo) and game.GetAmmoID(weaponData.Ammo) or -1
        local initialReserve = clipSize > 0 and math.max(0, defaultClip - clipSize) or defaultClip
        if initialReserve > 0 and ammoType >= 0 then
            ply:SetAmmo(math.max(ply:GetAmmoCount(ammoType), initialReserve), ammoType)
        end
    end

    return state
end

local function CaptureWeaponState(ply, baseClass)
    local wep = ply:GetWeapon(baseClass)
    if not IsValid(wep) then return end
    local state = GetWeaponState(ply, baseClass)
    state.clip1 = wep:Clip1()
    state.clip2 = wep:Clip2()
end

local function PrepareWeaponTransfer(ply, baseClass)
    CaptureWeaponState(ply, baseClass)
    local state = table.Copy(GetWeaponState(ply, baseClass))
    state.transferAmmo = {}

    local def = GetWeaponDefinition(baseClass)
    for _, weaponData in ipairs({ def.Primary, def.Secondary }) do
        local clipSize = tonumber(weaponData and weaponData.ClipSize) or -1
        local ammoType = weaponData and isstring(weaponData.Ammo) and game.GetAmmoID(weaponData.Ammo) or -1
        if clipSize <= 0 and ammoType >= 0 and state.transferAmmo[ammoType] == nil then
            local amount = ply:GetAmmoCount(ammoType)
            state.transferAmmo[ammoType] = amount
            ply:SetAmmo(0, ammoType)
        end
    end

    return state
end

local function ApplyTransferredAmmo(ply, state)
    local total = 0
    for ammoType, amount in pairs(state and state.transferAmmo or {}) do
        amount = math.max(0, math.floor(tonumber(amount) or 0))
        if amount > 0 then
            ply:SetAmmo(ply:GetAmmoCount(ammoType) + amount, ammoType)
            total = total + amount
        end
    end
    return total
end

local function MaterializeInventoryWeapon(ply, baseClass)
    local state = GetWeaponState(ply, baseClass)
    local ammoBefore = {}
    for ammoType in pairs(GetAmmoTypes(baseClass)) do
        ammoBefore[ammoType] = ply:GetAmmoCount(ammoType)
    end

    ply.SN_AllowPickup = true
    local wep = ply:Give(baseClass, true)
    ply.SN_AllowPickup = false
    if not IsValid(wep) then return nil end

    -- Some SWEPs grant ammo in Equip even when bNoAmmo is true.
    local function RestoreReserveAmmo()
        if not IsValid(ply) then return end
        for ammoType, amount in pairs(ammoBefore) do ply:SetAmmo(amount, ammoType) end
    end
    RestoreReserveAmmo()
    timer.Simple(0, RestoreReserveAmmo)
    if state.clip1 ~= nil and state.clip1 >= 0 then wep:SetClip1(state.clip1) end
    if state.clip2 ~= nil and state.clip2 >= 0 then wep:SetClip2(state.clip2) end
    return wep
end

function SlashMoon.Tasks.SpawnDrop(class, pos, weaponState)
    if not isstring(class) or class == "" then
        SlashMoon.Debug("[SN Material Debug] SpawnDrop STOP: invalid class=", tostring(class))
        return nil, "invalid_class"
    end
    if not isvector(pos) then
        SlashMoon.Debug("[SN Material Debug] SpawnDrop STOP: class=", class, " invalid pos=", tostring(pos))
        return nil, "invalid_position"
    end
    local parts = string.Split(class, ":")
    local baseClass = parts[1]
    local meta = parts[2]

    if baseClass == "weapon_gascan" then
        local ent = ents.Create("sn_gascan")
        if not IsValid(ent) then
            SlashMoon.Debug("[SN Material Debug] SpawnDrop FAILED: ents.Create(sn_gascan), class=", class)
            return nil, "entity_create_failed"
        end
        ent:SetPos(pos + Vector(math.random(-10, 10), math.random(-10, 10), 10))
        ent:Spawn()
        if not IsValid(ent) then
            SlashMoon.Debug("[SN Material Debug] SpawnDrop FAILED after Spawn: sn_gascan, class=", class)
            return nil, "entity_spawn_failed"
        end
        local fuel = tonumber(meta) or 50
        ent:SetKnownFuel(fuel)
        return ent
    else
        local ent = ents.Create("sn_item_drop")
        if not IsValid(ent) then
            SlashMoon.Debug("[SN Material Debug] SpawnDrop FAILED: ents.Create(sn_item_drop), class=", class, " scriptedEntity=", tostring(scripted_ents.GetStored("sn_item_drop") ~= nil))
            return nil, "entity_create_failed"
        end
        ent:SetPos(pos + Vector(math.random(-15, 15), math.random(-15, 15), math.random(10, 30)))
        ent:Spawn()
        if not IsValid(ent) then
            SlashMoon.Debug("[SN Material Debug] SpawnDrop FAILED after Spawn: sn_item_drop, class=", class)
            return nil, "entity_spawn_failed"
        end
        ent:SetItem(class)
        if weaponState then ent.SN_WeaponState = table.Copy(weaponState) end
        if ent:GetNW2String("ItemClass", "") ~= class then
            SlashMoon.Debug("[SN Material Debug] SpawnDrop WARNING: SetItem did not set ItemClass immediately, class=", class, " entity=", tostring(ent))
        end
        return ent
    end
end

function SlashMoon.Tasks.GiveItem(ply, class, weaponState)
    if not IsValid(ply) or not isstring(class) or class == "" or #class > 128 then return false, "invalid_item" end
    ply.SN_Backpack = ply.SN_Backpack or {}

    -- ═══ UNIQUE ITEM CHECK ═══
    local parts = string.Split(class, ":")
    local baseClass = parts[1]
    local itemDef = SlashMoon.Tasks.Items[baseClass]

    if itemDef and itemDef.unique and IsItemInInventory(ply, baseClass) then
        -- Предмет уже есть! Даём патроны вместо второго свепа.
        local ammoGiven = weaponState and ApplyTransferredAmmo(ply, weaponState) or GiveAmmoForWeapon(ply, baseClass)

        -- Спец-кейс: канистра — добавляем топливо к существующей
        local fuelAdded = false
        if baseClass == "weapon_gascan" then
            local fuel = tonumber(parts[2]) or 50
            fuel = math.Clamp(fuel, 0, 100)
            for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
                if ply.SN_Hotbar and ply.SN_Hotbar[i] then
                    local hbBase = string.Split(ply.SN_Hotbar[i], ":")[1]
                    if hbBase == "weapon_gascan" then
                        local existingFuel = tonumber(string.Split(ply.SN_Hotbar[i], ":")[2]) or 0
                        existingFuel = math.Clamp(existingFuel, 0, 100)
                        local newFuel = math.Clamp(existingFuel + fuel, 0, 100)
                        fuelAdded = newFuel > existingFuel
                        ply.SN_Hotbar[i] = "weapon_gascan:" .. newFuel
                        local wep = ply:GetWeapon("weapon_gascan")
                        if IsValid(wep) then wep:SetNW2Int("SN_Fuel", newFuel) end
                        break
                    end
                end
            end
        end

        if ammoGiven > 0 then
            local itemData = SlashMoon.Tasks.GetItemData(class)
            SlashMoon.Tasks.SendLocalizedChat(ply, "sn.inv.unique_ammo", itemData.nameKey or itemData.name, ammoGiven)
            SlashMoon.Debug(string.format("[Инвентарь] %s: unique дубликат %s -> +%d патронов", ply:Nick(), baseClass, ammoGiven))
        else
            SlashMoon.Debug(string.format("[Инвентарь] %s: unique дубликат %s -> проигнорирован", ply:Nick(), baseClass))
        end

        SlashMoon.Tasks.SyncInventory(ply)
        if ammoGiven > 0 or fuelAdded then return true end
        return false, "unique_duplicate"
    end

    if weaponState and string.StartWith(baseClass, "weapon_") then
        ApplyTransferredAmmo(ply, weaponState)
        local storedState = table.Copy(weaponState)
        storedState.transferAmmo = nil
        ply.SN_WeaponStates = ply.SN_WeaponStates or {}
        ply.SN_WeaponStates[baseClass] = storedState
    end

    -- ═══ СТАКИРУЕМЫЙ ПРЕДМЕТ ═══
    -- Если предмет stackable — ищем существующую запись в рюкзаке и увеличиваем счётчик
    if itemDef and itemDef.stackable then
        local addCount = 1
        -- Если передали "mat_scrap:3", добавляем 3 штуки
        if parts[2] then
            local metaNum = tonumber(parts[2])
            if metaNum and metaNum > 1 then addCount = math.floor(metaNum) end
        end
        addCount = math.Clamp(addCount, 1, MAX_STACK_COUNT)

        -- Ищем существующий стак в рюкзаке
        for i, item in ipairs(ply.SN_Backpack) do
            local existingParts = string.Split(item, ":")
            local existingBase = existingParts[1]
            if existingBase == baseClass then
                local existingCount = tonumber(existingParts[2]) or 1
                local newCount = math.min(MAX_STACK_COUNT, existingCount + addCount)
                if newCount <= existingCount then return false, "stack_full" end
                ply.SN_Backpack[i] = baseClass .. ":" .. newCount
                SlashMoon.Tasks.SyncInventory(ply)
                SlashMoon.Debug(string.format("[Инвентарь] %s: стак %s +%d = %d", ply:Nick(), baseClass, addCount, newCount))
                NotifyItemReceived(ply, class)
                return true
            end
        end

        -- Нет существующего стака — создаём новую запись
        if #ply.SN_Backpack >= MAX_BACKPACK_ITEMS then return false, "backpack_full" end
        if addCount > 1 then
            table.insert(ply.SN_Backpack, baseClass .. ":" .. addCount)
        else
            table.insert(ply.SN_Backpack, baseClass)
        end
        SlashMoon.Tasks.SyncInventory(ply)
        NotifyItemReceived(ply, class)
        return true
    end

    -- ═══ ОБЫЧНАЯ ВЫДАЧА ═══
    if #ply.SN_Backpack >= MAX_BACKPACK_ITEMS then return false, "backpack_full" end
    table.insert(ply.SN_Backpack, class)
    SlashMoon.Tasks.SyncInventory(ply)
    NotifyItemReceived(ply, class)
    return true
end

-- ========================================================
-- ЗАПРОС СИНХРОНИЗАЦИИ (С АНТИ-СПАМОМ)
-- ========================================================

MODULE:Receive("SN_Inv_RequestSync", function(len, ply)
    if not CanUseInventory(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "inv_request_sync", INV_REQUEST_COOLDOWN) then return end
    SlashMoon.Tasks.SyncInventory(ply)
end)

-- ========================================================
-- ОЧИСТКА ИНВЕНТАРЯ УБИЙЦЫ В МАСКЕ
-- ========================================================

function SlashMoon.Tasks.PurgeKillerInventory(ply)
    if not IsValid(ply) then return end
    local pos = ply:GetShootPos() + ply:GetAimVector() * 40
    local droppedCount = 0

    for _, class in ipairs(ply.SN_Backpack or {}) do
        SlashMoon.Tasks.SpawnDrop(class, pos)
        droppedCount = droppedCount + 1
    end
    ply.SN_Backpack = {}

    for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
        local class = ply.SN_Hotbar[i]
        if class then
            if class ~= "weapon_killer_axe" and class ~= "weapon_killmask" then
                ply.SN_Hotbar[i] = nil
                local baseClass = string.Split(class, ":")[1]
                if ply:HasWeapon(baseClass) then ply:StripWeapon(baseClass) end
                SlashMoon.Tasks.SpawnDrop(class, pos)
                droppedCount = droppedCount + 1
            end
        end
    end

    SlashMoon.Tasks.SyncInventory(ply)

    if droppedCount > 0 then
        SlashMoon.Debug("[Инвентарь] " .. ply:Nick() .. " надел Маску Убийцы. Сброшено предметов: " .. droppedCount)
    end
end

MODULE:Hook("EntityNetworkVariableChanged", "SN_Inv_WatchKillerMask", function(ent, name, oldVal, newVal)
    if name == "KillerMaskEquiped" and newVal == true and ent:IsPlayer() then
        SlashMoon.Tasks.PurgeKillerInventory(ent)
    end
end)

-- ========================================================
-- ПЕРЕХВАТ ОРУЖИЯ (WeaponEquip)
-- ========================================================

MODULE:Hook("WeaponEquip", "SN_Inv_CatchWeapon", function(wep, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    if ply:GetNW2Bool("KillerMaskEquiped", false) then
        local class = wep:GetClass()
        if class ~= "weapon_killer_axe" and class ~= "weapon_killmask" then
            timer.Simple(0, function()
                if IsValid(ply) and IsValid(wep) then
                    ply:StripWeapon(class)
                end
            end)
            return
        end
    end

    if SlashMoon.Tasks.Game.IsAnimatronic(ply) or SlashMoon.Tasks.Game.IsSpectator(ply) then return end

    local class = wep:GetClass()
    if SlashMoon.Tasks.Config.AlwaysAllowed[class] then return end

    timer.Simple(0.05, function()
        if not IsValid(ply) or not IsValid(wep) then return end
        if IsAlreadyInHotbar(ply, class) then return end

        -- ═══ UNIQUE CHECK В WEAPON EQUIP ═══
        -- Если оружие unique и уже есть в рюкзаке — стрипаем дубликат, даём патроны
        local itemDef = SlashMoon.Tasks.Items[class]
        if itemDef and itemDef.unique then
            -- Проверяем рюкзак (без HasWeapon — мы только что получили его)
            local alreadyInBP = false
            if ply.SN_Backpack then
                for _, item in ipairs(ply.SN_Backpack) do
                    if string.Split(item, ":")[1] == class then
                        alreadyInBP = true
                        break
                    end
                end
            end

            if alreadyInBP then
                -- Native Give has already applied this pickup's DefaultClip.
                -- Do not grant it a second time through GiveAmmoForWeapon.
                local ammoGiven = 0
                ply:StripWeapon(class)

                if ammoGiven > 0 then
                    local itemData = SlashMoon.Tasks.GetItemData(class)
                    SlashMoon.Tasks.SendLocalizedChat(ply, "sn.inv.unique_ammo", itemData.nameKey or itemData.name, ammoGiven)
                end
                SlashMoon.Debug(string.format("[Инвентарь] %s: WeaponEquip unique дубликат %s -> стрипнут, +%d патронов", ply:Nick(), class, ammoGiven))
                SlashMoon.Tasks.SyncInventory(ply)
                return
            end
        end

        -- Обычная обработка: прячем в рюкзак
        ply.SN_Backpack = ply.SN_Backpack or {}
        if #ply.SN_Backpack >= MAX_BACKPACK_ITEMS then
            ply:StripWeapon(class)
            SlashMoon.Tasks.SpawnDrop(class, ply:GetShootPos() + ply:GetAimVector() * 40)
            return
        end
        table.insert(ply.SN_Backpack, class)
        CaptureWeaponState(ply, class)
        ply:StripWeapon(class)
        SlashMoon.Tasks.SyncInventory(ply)

        local itemData = SlashMoon.Tasks.GetItemData(class)
        SlashMoon.Tasks.SendLocalizedChat(ply, "sn.inv.received", itemData.nameKey or itemData.name)
        SlashMoon.Debug("[Инвентарь] " .. ply:Nick() .. " получил " .. class .. " -> Спрятано в рюкзак.")
    end)
end)

-- ========================================================
-- ПРОВЕРКА ПАТРОНОВ
-- ========================================================

MODULE:Timer("SN_Inv_AmmoCheck", 0.5, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        if SlashMoon.Tasks.Game.IsAnimatronic(ply) or SlashMoon.Tasks.Game.IsSpectator(ply) then continue end
        if not ply.SN_Hotbar then continue end

        local changed = false
        for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
            local class = ply.SN_Hotbar[i]
            if class then
                local baseClass = string.Split(class, ":")[1]
                local wep = ply:GetWeapon(baseClass)

                if not IsValid(wep) then
                    ply.SN_Hotbar[i] = nil
                    changed = true
                    SlashMoon.Debug("[Инвентарь] " .. ply:Nick() .. ": " .. class .. " удален из хотбара.")
                else
                    local hasAmmoChannel = false
                    local hasAmmo = false
                    for _, channel in ipairs({
                        { ammoType = wep:GetPrimaryAmmoType(), clip = wep:Clip1() },
                        { ammoType = wep:GetSecondaryAmmoType(), clip = wep:Clip2() },
                    }) do
                        if channel.ammoType >= 0 then
                            hasAmmoChannel = true
                            if channel.clip > 0 or ply:GetAmmoCount(channel.ammoType) > 0 then hasAmmo = true end
                        end
                    end
                    local itemDef = SlashMoon.Tasks.Items[baseClass]
                    local retainWhenDepleted = itemDef and itemDef.retainWhenDepleted == true
                    if hasAmmoChannel and not hasAmmo and not retainWhenDepleted and not SlashMoon.Tasks.Config.AlwaysAllowed[baseClass] then
                        ply:StripWeapon(baseClass)
                        ply.SN_Hotbar[i] = nil
                        if ply.SN_WeaponStates then ply.SN_WeaponStates[baseClass] = nil end
                        changed = true
                        local itemData = SlashMoon.Tasks.GetItemData(class)
                        SlashMoon.Tasks.SendLocalizedChat(ply, "sn.inv.depleted", itemData.nameKey or itemData.name)
                    end
                end
            end
        end

        if changed then SlashMoon.Tasks.SyncInventory(ply) end
    end
end)

-- ========================================================
-- ВЫДАЧА ХОТБАРА ПРИ СПАВНЕ
-- ========================================================

MODULE:Hook("PlayerSpawn", "SN_Inv_OnSpawn", function(ply)
    timer.Simple(0.5, function()
        if not IsValid(ply) then return end
        if SlashMoon.Tasks.Game.IsAnimatronic(ply) or SlashMoon.Tasks.Game.IsSpectator(ply) then return end

        ply.SN_Backpack = ply.SN_Backpack or {}
        ply.SN_Hotbar = ply.SN_Hotbar or {}

        for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
            local class = ply.SN_Hotbar[i]
            if class then
                local baseClass = string.Split(class, ":")[1]
                if not ply:HasWeapon(baseClass) then
                    local wep = MaterializeInventoryWeapon(ply, baseClass)

                    if IsValid(wep) and baseClass == "weapon_gascan" then
                        local fuel = tonumber(string.Split(class, ":")[2]) or 0
                        wep:SetNW2Int("SN_Fuel", fuel)
                    end
                end
            end
        end
        SlashMoon.Tasks.SyncInventory(ply)
    end)
end)

-- ========================================================
-- ОЧИСТКА МАТЕРИАЛОВ В КОНЦЕ РАУНДА
-- ========================================================

MODULE:Hook("SN_Game_RoundEnd", "SN_Inv_RoundEnd", function()
    for _, ply in ipairs(player.GetAll()) do
        if ply.SN_Backpack then
            local newBp = {}
            for _, item in ipairs(ply.SN_Backpack) do
                if not string.StartWith(item, "mat_") then table.insert(newBp, item) end
            end
            ply.SN_Backpack = newBp

            for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
                if ply.SN_Hotbar[i] and string.StartWith(ply.SN_Hotbar[i], "mat_") then
                    local baseClass = string.Split(ply.SN_Hotbar[i], ":")[1]
                    if ply:HasWeapon(baseClass) then ply:StripWeapon(baseClass) end
                    ply.SN_Hotbar[i] = nil
                end
            end
            SlashMoon.Tasks.SyncInventory(ply)
        end
    end
end)

-- ========================================================
-- СМЕРТЬ И ОБЫСК ТРУПОВ (С АНТИ-СПАМОМ)
-- ========================================================

local function AttachCorpseLoot(ply, rag)
    if not IsValid(ply) or not IsValid(rag) or not ply.SN_DeathLoot then return false end
    rag.SN_Loot = ply.SN_DeathLoot
    ply.SN_DeathLoot = nil
    ply.SN_LootCarrier = rag
    rag:SetNW2Bool("SN_Lootable", true)
    rag:SetNW2String("SN_CorpseName", ply:Nick())
    return true
end

MODULE:Hook("DoPlayerDeath", "SN_Inv_DeathSave", function(ply)
    if SlashMoon.Tasks.Game.IsFH() then
        -- SN restores the remaining corpse loot itself; prevent FH from giving
        -- the same SWEPs and reserve ammo a second time on defibrillator spawn.
        ply._SupressInventoryBackupLoad = true
    end

    for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
        local class = ply.SN_Hotbar and ply.SN_Hotbar[i]
        if class then CaptureWeaponState(ply, string.Split(class, ":")[1]) end
    end
    local transferStates = {}
    local seenClasses = {}
    for _, class in ipairs(ply.SN_Backpack or {}) do
        local baseClass = string.Split(class, ":")[1]
        if string.StartWith(baseClass, "weapon_") and not seenClasses[baseClass] then
            transferStates[baseClass] = PrepareWeaponTransfer(ply, baseClass)
            seenClasses[baseClass] = true
        end
    end
    for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
        local class = ply.SN_Hotbar and ply.SN_Hotbar[i]
        local baseClass = class and string.Split(class, ":")[1]
        if baseClass and string.StartWith(baseClass, "weapon_") and not seenClasses[baseClass] then
            transferStates[baseClass] = PrepareWeaponTransfer(ply, baseClass)
            seenClasses[baseClass] = true
        end
    end

    ply.SN_DeathLoot = {
        backpack = ply.SN_Backpack or {},
        hotbar = {},
        weaponStates = transferStates,
    }
    for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
        if ply.SN_Hotbar and ply.SN_Hotbar[i] then table.insert(ply.SN_DeathLoot.hotbar, ply.SN_Hotbar[i]) end
    end
    ply.SN_Backpack = {}
    ply.SN_Hotbar = {}
    ply.SN_WeaponStates = {}
    SlashMoon.Tasks.SyncInventory(ply)
    AttachCorpseLoot(ply, ply.SN_LootRagdoll or ply.DeathRagdoll)
end)

MODULE:Hook("SN_Game_RagdollCreated", "SN_Inv_SetupCorpse", function(ply, rag)
    if not IsValid(ply) or not IsValid(rag) then return end
    ply.SN_LootRagdoll = rag
    AttachCorpseLoot(ply, rag)
end)

MODULE:Hook("PlayerSpawn", "SN_Inv_ResetCorpseReference", function(ply)
    ply.SN_LootRagdoll = nil
end)

local function RestoreCorpseInventory(ply)
    if not IsValid(ply) then return end
    local carrier = ply.SN_LootCarrier
    local loot = IsValid(carrier) and carrier.SN_Loot or nil
    if not loot then return end

    ply.SN_Backpack = table.Copy(loot.backpack or {})
    ply.SN_Hotbar = table.Copy(loot.hotbar or {})
    ply.SN_WeaponStates = {}

    for baseClass, state in pairs(loot.weaponStates or {}) do
        ApplyTransferredAmmo(ply, state)
        local storedState = table.Copy(state)
        storedState.transferAmmo = nil
        ply.SN_WeaponStates[baseClass] = storedState
    end

    carrier.SN_Loot = nil
    carrier:SetNW2Bool("SN_Lootable", false)
    ply.SN_LootCarrier = nil
    ply.SN_DefibRestoreHandled = true

    timer.Simple(0.1, function()
        if not IsValid(ply) or not ply:Alive() then return end
        for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
            local class = ply.SN_Hotbar[i]
            local baseClass = class and string.Split(class, ":")[1]
            if baseClass and not ply:HasWeapon(baseClass) then
                MaterializeInventoryWeapon(ply, baseClass)
            end
        end
        SlashMoon.Tasks.SyncInventory(ply)
    end)
end

MODULE:Hook("fh_defibrillator_spawn", "SN_Inv_RestoreAfterDefibrillator", function(ply)
    RestoreCorpseInventory(ply)
end)

MODULE:Hook("PlayerSpawn", "SN_Inv_ClearNonDefibCorpseLoot", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if ply.SN_DefibRestoreHandled then
            ply.SN_DefibRestoreHandled = nil
            return
        end

        local carrier = ply.SN_LootCarrier
        if IsValid(carrier) then
            carrier.SN_Loot = nil
            carrier:SetNW2Bool("SN_Lootable", false)
        end
        ply.SN_LootCarrier = nil
        ply.SN_DeathLoot = nil
    end)
end)

MODULE:Hook("SN_Game_RoundStart", "SN_Inv_ResetForNewRound", function()
    -- In Fazbear's Hunt, fh_poststartgame is also forwarded here, but the
    -- inventory is intentionally persistent across the new game phase.
    if SlashMoon.Tasks.Game.IsFH() then return end

    for _, ply in ipairs(player.GetAll()) do
        for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
            local class = ply.SN_Hotbar and ply.SN_Hotbar[i]
            local baseClass = class and string.Split(class, ":")[1]
            if baseClass and ply:HasWeapon(baseClass) then ply:StripWeapon(baseClass) end
        end
        ply.SN_Backpack = {}
        ply.SN_Hotbar = {}
        ply.SN_WeaponStates = {}
        ply.SN_DeathLoot = nil
        ply.SN_LootCarrier = nil
        ply.SN_DefibRestoreHandled = nil
        SlashMoon.Tasks.SyncInventory(ply)
    end
end)

MODULE:Receive("SN_Inv_RequestLoot", function(len, ply)
    if not CanLootCorpse(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "inv_loot_request", LOOT_REQUEST_COOLDOWN) then return end

    local ent = net.ReadEntity()
    if not IsValid(ent) or (ent:GetClass() ~= "prop_ragdoll" and ent:GetClass() ~= "prop_physics") or not ent:GetNW2Bool("SN_Lootable") then return end
    if ply:GetPos():Distance(ent:GetPos()) > 150 or not ent.SN_Loot then return end

    net.Start("SN_Inv_OpenLootUI")
    net.WriteEntity(ent)
    net.WriteTable(ent.SN_Loot.backpack or {})
    net.WriteTable(ent.SN_Loot.hotbar or {})
    net.Send(ply)
end)

MODULE:Receive("SN_Inv_TakeLoot", function(len, ply)
    if not CanLootCorpse(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "inv_loot_take", LOOT_TAKE_COOLDOWN) then return end

    local ent = net.ReadEntity()
    local itemType = net.ReadString()
    local itemIdx = net.ReadUInt(8)
    local expectedClass = net.ReadString()

    if not IsValid(ent) or (ent:GetClass() ~= "prop_ragdoll" and ent:GetClass() ~= "prop_physics") or not ent:GetNW2Bool("SN_Lootable") then return end
    if not ent.SN_Loot or ply:GetPos():DistToSqr(ent:GetPos()) > 150 * 150 then return end
    if itemType ~= "backpack" and itemType ~= "hotbar" then return end
    local targetTable = ent.SN_Loot[itemType]

    if targetTable and targetTable[itemIdx] and targetTable[itemIdx] == expectedClass then
        local itemClass = targetTable[itemIdx]
        local baseClass = string.Split(itemClass, ":")[1]
        local weaponState = ent.SN_Loot.weaponStates and ent.SN_Loot.weaponStates[baseClass]
        local added = SlashMoon.Tasks.GiveItem(ply, itemClass, weaponState)
        if not added then return end
        table.remove(targetTable, itemIdx)
        if weaponState then ent.SN_Loot.weaponStates[baseClass] = nil end
        if #ent.SN_Loot.backpack == 0 and #ent.SN_Loot.hotbar == 0 then
            ent:SetNW2Bool("SN_Lootable", false)
        end
        hook.Run("SN_Item_PickedUp", ply, itemClass)
        ply:EmitSound("items/ammo_pickup.wav")

        net.Start("SN_Inv_OpenLootUI")
        net.WriteEntity(ent)
        net.WriteTable(ent.SN_Loot.backpack)
        net.WriteTable(ent.SN_Loot.hotbar)
        net.Send(ply)
    end
end)

-- ========================================================
-- ГЛАВНЫЙ ОБРАБОТЧИК ДЕЙСТВИЙ ИНВЕНТАРЯ (С АНТИ-СПАМОМ)
-- ========================================================

MODULE:Receive("SN_Inv_Action", function(len, ply)
    if not CanUseInventory(ply) or len > 4096 then return end

    -- === АНТИ-СПАМ: Дебаунс через SlashMoon.Security.CheckRateLimit ===
    if not SlashMoon.Security.CheckRateLimit(ply, "inv_action", INV_ACTION_COOLDOWN) then return end

    local action = net.ReadString()

    ply.SN_Backpack = ply.SN_Backpack or {}
    ply.SN_Hotbar = ply.SN_Hotbar or {}

    if action == "sort" then
        table.sort(ply.SN_Backpack)

    elseif action == "fast_equip" or action == "drag_bp_to_hb" then
        local class = net.ReadString()
        local targetSlot = action == "drag_bp_to_hb" and tonumber(net.ReadUInt(4)) or 1
        if #class > 128 or not IsValidHotbarSlot(targetSlot) then return end

        -- ═══ ТОЛЬКО ОРУЖИЕ МОЖНО ЭКИПИРОВАТЬ ═══
        if not SlashMoon.Tasks.IsEquippable(class) then
            -- Нельзя экипировать материалы/инструменты/расходники
            SlashMoon.Debug("[Инвентарь] " .. ply:Nick() .. " пытался экипировать не-оружие: " .. class)
            return
        end

        if action == "fast_equip" then
            for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
                if not ply.SN_Hotbar[i] then targetSlot = i; break end
            end
        end

        local idx = nil
        for i, v in ipairs(ply.SN_Backpack) do if v == class then idx = i break end end
        if not idx then return end
        if IsAlreadyInHotbar(ply, class) then return end

        local oldWep = ply.SN_Hotbar[targetSlot]
        local baseClass = string.Split(class, ":")[1]
        local wep
        if not string.StartWith(baseClass, "mat_") then
            wep = MaterializeInventoryWeapon(ply, baseClass)
            if not IsValid(wep) then return end
        end

        if oldWep then
            ply.SN_Backpack[idx] = oldWep
            local oldBase = string.Split(oldWep, ":")[1]
            if ply:HasWeapon(oldBase) then
                CaptureWeaponState(ply, oldBase)
                ply:StripWeapon(oldBase)
            end
        else
            table.remove(ply.SN_Backpack, idx)
        end

        ply.SN_Hotbar[targetSlot] = class

        if IsValid(wep) then
            if baseClass == "weapon_gascan" then
                local fuel = tonumber(string.Split(class, ":")[2]) or 0
                fuel = math.Clamp(fuel, 0, 100)
                wep:SetNW2Int("SN_Fuel", fuel)
            end
        end

    elseif action == "unequip" then
        local slot = tonumber(net.ReadUInt(4))
        if not IsValidHotbarSlot(slot) then return end
        local class = ply.SN_Hotbar[slot]

        if class then
            ply.SN_Hotbar[slot] = nil
            table.insert(ply.SN_Backpack, class)

            local baseClass = string.Split(class, ":")[1]
            if ply:HasWeapon(baseClass) then
                CaptureWeaponState(ply, baseClass)
                ply:StripWeapon(baseClass)
            end
            -- Безопасный выбор пустых рук
            if ply:HasWeapon("sn_empty_hands") then
                ply:SelectWeapon("sn_empty_hands")
            elseif ply:HasWeapon("weapon_empty_hands") then
                ply:SelectWeapon("weapon_empty_hands")
            end
        end

    elseif action == "drag_hb_to_bp" then
        local slot = tonumber(net.ReadUInt(4))
        if not IsValidHotbarSlot(slot) then return end
        local class = ply.SN_Hotbar[slot]
        if class then
            ply.SN_Hotbar[slot] = nil
            table.insert(ply.SN_Backpack, class)

            local baseClass = string.Split(class, ":")[1]
            if ply:HasWeapon(baseClass) then
                CaptureWeaponState(ply, baseClass)
                ply:StripWeapon(baseClass)
            end
            -- Безопасный выбор пустых рук
            if ply:HasWeapon("sn_empty_hands") then
                ply:SelectWeapon("sn_empty_hands")
            elseif ply:HasWeapon("weapon_empty_hands") then
                ply:SelectWeapon("weapon_empty_hands")
            end
        end

    elseif action == "swap_hb" then
        local slot1 = tonumber(net.ReadUInt(4))
        local slot2 = tonumber(net.ReadUInt(4))
        if not IsValidHotbarSlot(slot1) or not IsValidHotbarSlot(slot2) then return end
        local temp = ply.SN_Hotbar[slot1]
        ply.SN_Hotbar[slot1] = ply.SN_Hotbar[slot2]
        ply.SN_Hotbar[slot2] = temp

    elseif action == "drop_world" then
        local dropType = net.ReadString()
        local class = net.ReadString()
        local slot = tonumber(net.ReadUInt(8))
        if #class > 128 then return end

        if dropType == "backpack" then
            if slot < 1 or slot > #ply.SN_Backpack then return end
            if ply.SN_Backpack[slot] == class then
                table.remove(ply.SN_Backpack, slot)
                local baseClass = string.Split(class, ":")[1]
                local state = string.StartWith(baseClass, "weapon_") and PrepareWeaponTransfer(ply, baseClass) or nil
                SlashMoon.Tasks.SpawnDrop(class, ply:GetShootPos() + ply:GetAimVector() * 40, state)
                if state then ply.SN_WeaponStates[baseClass] = nil end
            end
        elseif dropType == "hotbar" then
            if not IsValidHotbarSlot(slot) then return end
            if ply.SN_Hotbar[slot] == class then
                ply.SN_Hotbar[slot] = nil
                local baseClass = string.Split(class, ":")[1]
                if ply:HasWeapon(baseClass) then
                    CaptureWeaponState(ply, baseClass)
                    ply:StripWeapon(baseClass)
                end
                -- Безопасный выбор пустых рук
                if ply:HasWeapon("sn_empty_hands") then
                    ply:SelectWeapon("sn_empty_hands")
                elseif ply:HasWeapon("weapon_empty_hands") then
                    ply:SelectWeapon("weapon_empty_hands")
                end
                local state = string.StartWith(baseClass, "weapon_") and PrepareWeaponTransfer(ply, baseClass) or nil
                SlashMoon.Tasks.SpawnDrop(class, ply:GetShootPos() + ply:GetAimVector() * 40, state)
                if state then ply.SN_WeaponStates[baseClass] = nil end
            end
        end
    end

    SlashMoon.Tasks.SyncInventory(ply)
end)
