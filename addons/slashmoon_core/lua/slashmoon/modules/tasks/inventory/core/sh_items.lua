-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: База Данных Предметов (Localized via SlashMoon.Tasks.Lang)
-- lua/st_tasks/invenyory/core/sh_items.lua
-- Описания предметов, модели энтити по типу/редкости
-- ========================================================
SlashMoon.Tasks = SlashMoon.Tasks or {}

SlashMoon.Tasks.Items = {

    ["weapon_gascan"] = {
        nameKey = "sn.inv.gascan_name",
        name = "Gas Can",
        type = "weapon",
        icon = "materials/sn_task/items/gascan.png",
        unique = true,
        rarity = "common",
        descKey = "sn.inv.desc.gascan",
        description = "A rusty gas can. Fill it up at the generator to keep the lights on.",
    },
    ["sn_animcam_tablet"] = {
        nameKey = "sn.inv.animcam",
        name = "AnimCam",
        type = "weapon",
        icon = "materials/sn_task/items/animcam.png",
        unique = true,
        rarity = "rare",
        descKey = "sn.inv.desc.animcam",
        description = "None.",
    },
    ["weapon_killmask"] = {
        nameKey = "sn.inv.killmask_name",
        name = "Killer Mask",
        type = "weapon",
        unique = true,
        rarity = "epic",
        descKey = "sn.inv.desc.killmask",
        description = "A terrifying mask that transforms the wearer into a relentless killer. All items are dropped upon equipping.",
    },
    ["fh_corpse_scanner"] = {
        nameKey = "sn.inv.scanner_name",
        name = "Corpse Scanner",
        type = "weapon",
        unique = true,
        rarity = "uncommon",
        descKey = "sn.inv.desc.scanner",
        description = "Scans nearby corpses to determine the cause of death. Essential for investigations.",
    },
    ["weapon_fhi_endo_terminal"] = {
        nameKey = "sn.inv.terminal_name",
        name = "Terminal",
        type = "weapon",
        unique = true,
        rarity = "rare",
        descKey = "sn.inv.desc.terminal",
        description = "Endoskeleton programming terminal. Used to interface with and repair animatronic systems.",
    },
    ["weapon_fh_medkit"] = {
        nameKey = "sn.inv.medkit_name",
        name = "Medkit",
        type = "weapon",
        icon = "materials/sn_task/items/medkit.png",
        unique = true,
        rarity = "uncommon",
        descKey = "sn.inv.desc.medkit",
        description = "A portable medical kit. Restores health when used on yourself or a teammate.",
    },
    ["weapon_defibrillator"] = {
        nameKey = "sn.inv.defibrillator",
        name = "Defibrillator",
        type = "weapon",
        icon = "materials/sn_task/items/medkit.png",
        unique = true,
        rarity = "rare",
        descKey = "sn.inv.desc.defibrillator",
        description = "Advanced medical device that can revive fallen teammates from a corpse. Single use per charge.",
    },
    ["weapon_snowball"] = {
        nameKey = "sn.inv.snowball",
        name = "Snowball",
        type = "weapon",
        icon = "materials/sn_task/items/medkit.png",
        unique = true,
        rarity = "common",
        descKey = "sn.inv.desc.snowball",
        description = "A packed snowball. Not very effective, but it's something.",
    },
    ["weapon_taser"] = {
        nameKey = "sn.inv.taser",
        name = "Taser Gun",
        type = "weapon",
        unique = true,
        rarity = "rare",
        retainWhenDepleted = true,
        descKey = "sn.inv.desc.taser",
        description = "A rechargeable stun gun effective against animatronics.",
    },
    ["weapon_banana"] = {
        nameKey = "sn.inv.banana",
        name = "Banana Peel",
        type = "weapon",
        unique = true,
        rarity = "uncommon",
        descKey = "sn.inv.desc.banana",
        description = "A throwable banana peel that makes its target slip.",
    },
    ["weapon_killer_axe"] = {
        nameKey = "sn.inv.killer_axe",
        name = "Killer Axe",
        type = "weapon",
        unique = true,
        rarity = "epic",
        descKey = "sn.inv.desc.killer_axe",
        description = "The killer's melee weapon.",
    },
    ["weapon_pistol"] = {
        nameKey = "sn.inv.pistol",
        name = "Pistol",
        type = "weapon",
        unique = true,
        rarity = "common",
        descKey = "sn.inv.desc.pistol",
        description = "A standard semi-automatic pistol.",
    },
    ["weapon_frag"] = {
        nameKey = "sn.inv.frag",
        name = "Fragmentation Grenade",
        type = "weapon",
        unique = true,
        rarity = "uncommon",
        descKey = "sn.inv.desc.frag",
        description = "A fragmentation grenade.",
    },
    ["weapon_crowbar"] = {
        nameKey = "sn.inv.crowbar",
        name = "Crowbar",
        type = "weapon",
        unique = true,
        rarity = "common",
        descKey = "sn.inv.desc.crowbar",
        description = "A durable melee tool.",
    },

    -- ═══ МАСКИ ═══
    ["weapon_mask"] = {
        nameKey = "sn.inv.mask_name",
        name = "Bonnie Mask",
        type = "weapon",
        equippable = true,
        unique = true,
        icon = "sn/inventory/weap/test.png",
        descKey = "sn.inv.desc.mask",
        description = "A Bonnie animatronic mask. Worn to hide from certain animatronics.",
    },

    -- ═══ ИНСТРУМЕНТЫ (отдельные SWEP помечены equippable) ═══
    ["weapon_wrench"] = {
        nameKey = "sn.inv.wrench",
        name = "Wrench",
        type = "tool",
        icon = "materials/sn_task/items/wrench.png",
        unique = true,
        descKey = "sn.inv.desc.wrench",
        description = "A sturdy wrench for repair work. Required for fixing generators and other machinery.",
    },
    ["weapon_flashlight"] = {
        nameKey = "sn.inv.flashlight",
        name = "Flashlight",
        type = "tool",
        icon = "materials/sn_task/items/flashlight.png",
        unique = true,
        descKey = "sn.inv.desc.flashlight",
        description = "Illuminates dark areas. Batteries drain over time — keep spares handy.",
    },
    ["weapon_multitool"] = {
        nameKey = "sn.inv.multitool",
        name = "Multitool",
        type = "tool",
        icon = "materials/sn_task/items/multitool.png",
        unique = true,
        descKey = "sn.inv.desc.multitool",
        description = "A versatile multi-purpose tool. Can interact with various electronic panels and locks.",
    },
    ["weapon_crapvidcam"] = {
        nameKey = "sn.inv.crapvidcam",
        name = "Camera",
        type = "tool",
        equippable = true,
        icon = "materials/sn_task/items/medkit.png",
        unique = true,
        descKey = "sn.inv.desc.camera",
        description = "A cheap video camera. Useful for surveillance and monitoring animatronic movements.",
    },
    ["item_toolbox"] = {
        nameKey = "sn.inv.toolbox",
        name = "Toolbox",
        type = "tool",
        icon = "materials/sn_task/items/toolbox.png",
        unique = true,
        descKey = "sn.inv.desc.toolbox",
        description = "A heavy toolbox containing various repair instruments. Carrying this makes you slower.",
    },
    ["item_delivery_receiver"] = {
        nameKey = "sn.inv.delivery_receiver",
        name = "Signal Receiver",
        type = "electronic",
        stackable = true,
        descKey = "sn.inv.desc.delivery_receiver",
        description = "A receiver assembled for delivery.",
    },
    ["item_delivery_radio"] = {
        nameKey = "sn.inv.delivery_radio",
        name = "Radio Unit",
        type = "electronic",
        stackable = true,
        descKey = "sn.inv.desc.delivery_radio",
        description = "A radio unit assembled for delivery.",
    },
    ["item_delivery_medical"] = {
        nameKey = "sn.inv.delivery_medical",
        name = "Medical Container",
        type = "consumable",
        stackable = true,
        descKey = "sn.inv.desc.delivery_medical",
        description = "Packed medical supplies ready for delivery.",
    },
    ["item_delivery_food"] = {
        nameKey = "sn.inv.delivery_food",
        name = "Food Package",
        type = "consumable",
        stackable = true,
        descKey = "sn.inv.desc.delivery_food",
        description = "A prepared food package ready for delivery.",
    },
    ["item_delivery_chemicals"] = {
        nameKey = "sn.inv.delivery_chemicals",
        name = "Chemical Canister",
        type = "chemical",
        stackable = true,
        descKey = "sn.inv.desc.delivery_chemicals",
        description = "A sealed chemical canister ready for delivery.",
    },

    -- ═══ РАСХОДНИКИ (type=consumable) ═══
    ["weapon_adrenaline_fix"] = {
        nameKey = "sn.inv.adrenaline",
        name = "Adrenaline",
        type = "consumable",
        equippable = true,
        icon = "materials/sn_task/items/medkit.png",
        unique = true,
        descKey = "sn.inv.desc.adrenaline",
        description = "An adrenaline shot. Temporarily boosts movement speed and reduces fear effects.",
    },
    ["weapon_fanta"] = {
        nameKey = "sn.inv.fanta",
        name = "Fazbear's Fanta",
        type = "consumable",
        equippable = true,
        worldScale = 1.75,
        icon = "materials/sn_task/items/medkit.png",
        unique = true,
        descKey = "sn.inv.desc.fanta",
        description = "Fazbear Entertainment's signature orange drink. Restores a small amount of health.",
    },
    ["mat_battery"] = {
        nameKey = "sn.inv.battery",
        name = "Battery",
        type = "consumable",
        icon = "materials/sn_task/items/battery.png",
        stackable = true,
        descKey = "sn.inv.desc.battery",
        description = "A standard AA battery. Used to power flashlights and electronic devices.",
    },
    ["mat_fuse"] = {
        nameKey = "sn.inv.fuse",
        name = "Fuse",
        type = "consumable",
        icon = "materials/sn_task/items/fuse.png",
        stackable = true,
        descKey = "sn.inv.desc.fuse",
        description = "An electrical fuse. Required for repairing generator fuse boxes.",
    },
    ["mat_medpack"] = {
        nameKey = "sn.inv.medpack",
        name = "Medical Supplies",
        type = "consumable",
        icon = "materials/sn_task/items/medpack.png",
        stackable = true,
        descKey = "sn.inv.desc.medpack",
        description = "Basic medical supplies. Can be combined with wires to craft a medkit.",
    },

    -- ═══ МАТЕРИАЛЫ (type=material) — СТАКИРУЮТСЯ ═══
    ["mat_scrap"] = {
        nameKey = "sn.inv.mat_scrap",
        name = "Scrap Metal",
        type = "material",
        icon = "materials/sn_task/items/scrap.png",
        stackable = true,
        descKey = "sn.inv.desc.scrap",
        description = "Pieces of scrap metal. A versatile crafting material used in many recipes.",
    },
    ["mat_wire"] = {
        nameKey = "sn.inv.mat_wire",
        name = "Wires",
        type = "material",
        icon = "materials/sn_task/items/wire.png",
        stackable = true,
        descKey = "sn.inv.desc.wire",
        description = "Electrical wiring. Essential for crafting tools and medical equipment.",
    },
    ["mat_chip"] = {
        nameKey = "sn.inv.mat_chip",
        name = "Microchip",
        type = "material",
        icon = "materials/sn_task/items/chip.png",
        stackable = true,
        descKey = "sn.inv.desc.chip",
        description = "A small microchip. Can be crafted from a transistor and circuit board.",
    },
    ["mat_plastic"] = {
        nameKey = "sn.inv.mat_plastic",
        name = "Plastic",
        type = "material",
        icon = "materials/sn_task/items/plastic.png",
        stackable = true,
        descKey = "sn.inv.desc.plastic",
        description = "Plastic components. Used in crafting toolboxes and other items.",
    },
    ["mat_key"] = {
        nameKey = "sn.inv.mat_key",
        name = "Key",
        type = "tool",
        icon = "materials/sn_task/items/key.png",
        stackable = true,
        descKey = "sn.inv.desc.key",
        description = "A small key. Used for opening locked containers and crafting toolboxes.",
    },

    -- ═══ ЭЛЕКТРОНИКА (type=electronic) — СТАКИРУЕТСЯ ═══
    ["mat_transistor"] = {
        nameKey = "sn.inv.transistor",
        name = "Transistor",
        type = "electronic",
        icon = "materials/sn_task/items/transistor.png",
        stackable = true,
        descKey = "sn.inv.desc.transistor",
        description = "An electronic transistor. A fundamental component for crafting microchips.",
    },
    ["mat_circuit_board"] = {
        nameKey = "sn.inv.circuit_board",
        name = "Circuit Board",
        type = "electronic",
        icon = "materials/sn_task/items/circuit_board.png",
        stackable = true,
        descKey = "sn.inv.desc.circuit_board",
        description = "A printed circuit board. Used in electronics crafting and servomotor assembly.",
    },
    ["mat_servo"] = {
        nameKey = "sn.inv.servo",
        name = "Servomotor",
        type = "electronic",
        icon = "materials/sn_task/items/servo.png",
        stackable = true,
        descKey = "sn.inv.desc.servo",
        description = "A small servomotor. Crafted from circuit boards and scrap. Used for animatronic repair.",
    },

    -- ═══ ХИМИКАТЫ (type=chemical) — СТАКИРУЮТСЯ ═══
    ["mat_acid"] = {
        nameKey = "sn.inv.acid",
        name = "Acid",
        type = "chemical",
        icon = "materials/sn_task/items/acid.png",
        stackable = true,
        descKey = "sn.inv.desc.acid",
        description = "A corrosive acid. Handle with extreme care. Can dissolve certain materials.",
    },
    ["mat_solvent"] = {
        nameKey = "sn.inv.solvent",
        name = "Solvent",
        type = "chemical",
        icon = "materials/sn_task/items/solvent.png",
        stackable = true,
        descKey = "sn.inv.desc.solvent",
        description = "A chemical solvent. Useful for cleaning electronic components and removing rust.",
    },

    -- ═══ КВЕСТОВЫЕ ПРЕДМЕТЫ (type=quest) ═══
    ["item_keycard_blue"] = {
        nameKey = "sn.inv.keycard_blue",
        name = "Blue Keycard",
        type = "quest",
        icon = "materials/sn_task/items/keycard_blue.png",
        unique = true,
        descKey = "sn.inv.desc.keycard_blue",
        description = "A blue security keycard. Provides access to standard security doors.",
    },
    ["item_keycard_red"] = {
        nameKey = "sn.inv.keycard_red",
        name = "Red Keycard",
        type = "quest",
        icon = "materials/sn_task/items/keycard_red.png",
        unique = true,
        descKey = "sn.inv.desc.keycard_red",
        description = "A red security keycard. Provides access to high-security restricted areas.",
    },
    ["item_blueprint"] = {
        nameKey = "sn.inv.blueprint",
        name = "Blueprint",
        type = "quest",
        icon = "materials/sn_task/items/blueprint.png",
        unique = true,
        descKey = "sn.inv.desc.blueprint",
        description = "A technical blueprint showing the internal layout of animatronic systems.",
    },

    -- ═══ РЕДКИЕ ПРЕДМЕТЫ (type=rare) ═══
    ["item_golden_coin"] = {
        nameKey = "sn.inv.golden_coin",
        name = "Golden Coin",
        type = "rare",
        icon = "materials/sn_task/items/golden_coin.png",
        stackable = true,
        descKey = "sn.inv.desc.golden_coin",
        description = "A rare golden Fazbear token. Collectible — who knows what it might unlock?",
    },
    ["item_artifact"] = {
        nameKey = "sn.inv.artifact",
        name = "Strange Artifact",
        type = "rare",
        icon = "materials/sn_task/items/artifact.png",
        unique = true,
        descKey = "sn.inv.desc.artifact",
        description = "An otherworldly artifact of unknown origin. It hums faintly when held near animatronics.",
    },
}

-- ========================================================
-- ИКОНКИ: Кеш Material() с защитой от мемори-ликов
-- ========================================================
SlashMoon.Tasks._MatCache = SlashMoon.Tasks._MatCache or {}

function SlashMoon.Tasks.GetItemMaterial(class)
    if SERVER then return nil end

    local parts = string.Split(class, ":")
    local baseClass = parts[1]
    local itemDef = SlashMoon.Tasks.Items[baseClass]

    if not itemDef or not itemDef.icon then return nil end

    if not SlashMoon.Tasks._MatCache[itemDef.icon] then
        SlashMoon.Tasks._MatCache[itemDef.icon] = Material(itemDef.icon, "smooth")
    end

    return SlashMoon.Tasks._MatCache[itemDef.icon]
end

-- ========================================================
-- ПАРСЕР ЗАПИСЕЙ ИНВЕНТАРЯ
-- Формат: "class" | "class:метаданные" | "class:стак"
-- ========================================================

-- Разбить запись инвентаря на базовый класс + число
-- Для стакируемых: "mat_scrap:3" → baseClass="mat_scrap", count=3
-- Для канистры: "weapon_gascan:50" → baseClass="weapon_gascan", count=1, fuel=50
-- Для обычных: "weapon_wrench" → baseClass="weapon_wrench", count=1
function SlashMoon.Tasks.ParseItemEntry(entry)
    if not entry then return { class = "", baseClass = "", count = 0 } end

    local parts = string.Split(entry, ":")
    local baseClass = parts[1]
    local meta = parts[2]

    local itemDef = SlashMoon.Tasks.Items[baseClass]

    -- Стакируемый предмет: meta = количество
    if itemDef and itemDef.stackable and meta then
        local count = tonumber(meta) or 1
        return { class = entry, baseClass = baseClass, count = math.max(1, count), fuel = nil }
    end

    -- Канистра: meta = топливо
    if baseClass == "weapon_gascan" and meta then
        return { class = entry, baseClass = baseClass, count = 1, fuel = tonumber(meta) or 0 }
    end

    -- Обычный предмет
    return { class = entry, baseClass = baseClass, count = 1, fuel = nil }
end

-- Собрать запись инвентаря из базового класса + количества
function SlashMoon.Tasks.MakeItemEntry(baseClassC, count)
    local itemDef = SlashMoon.Tasks.Items[baseClassC]
    if itemDef and itemDef.stackable and count and count > 1 then
        return baseClassC .. ":" .. math.max(1, count)
    end
    return baseClassC
end

-- ========================================================
-- МОЖНО ЛИ ЭКИПИРОВАТЬ В ХОТБАР?
-- Только type=weapon допускается
-- ========================================================
function SlashMoon.Tasks.IsEquippable(rawClass)
    if not rawClass then return false end
    local parts = string.Split(rawClass, ":")
    local baseClass = parts[1]
    local itemDef = SlashMoon.Tasks.Items[baseClass]

    if not itemDef then
        -- Неизвестный предмет: экипируем если начинается с weapon_
        return string.StartWith(baseClass, "weapon_")
    end

    return itemDef.type == "weapon" or itemDef.equippable == true
end

-- ========================================================
-- СТАКИРУЕМ ЛИ ПРЕДМЕТ?
-- ========================================================
function SlashMoon.Tasks.IsStackable(rawClass)
    if not rawClass then return false end
    local parts = string.Split(rawClass, ":")
    local baseClass = parts[1]
    local itemDef = SlashMoon.Tasks.Items[baseClass]

    return itemDef and itemDef.stackable == true
end

-- Получить количество из записи инвентаря
function SlashMoon.Tasks.GetStackCount(entry)
    return SlashMoon.Tasks.ParseItemEntry(entry).count
end

-- ========================================================
-- ЦВЕТОВАЯ ПАЛИТРА ПО ТИПУ ПРЕДМЕТА
-- ========================================================
function SlashMoon.Tasks.GetTypeColor(itemType)
    if itemType == "weapon" then
        return Color(150, 50, 255)      -- Фиолетовый
    elseif itemType == "material" then
        return Color(255, 200, 50)      -- Желтый
    elseif itemType == "tool" then
        return Color(50, 200, 255)      -- Голубой
    elseif itemType == "consumable" then
        return Color(50, 255, 100)      -- Зеленый
    elseif itemType == "quest" then
        return Color(255, 140, 50)      -- Оранжевый
    elseif itemType == "rare" then
        return Color(255, 215, 0)       -- Золотой
    elseif itemType == "electronic" then
        return Color(100, 150, 255)     -- Синий
    elseif itemType == "chemical" then
        return Color(200, 100, 255)     -- Фиолетовый (химикаты)
    else
        return Color(150, 50, 255)      -- По умолчанию фиолетовый
    end
end

-- ========================================================
-- ЦВЕТ РЕДКОСТИ ОРУЖИЯ
-- ========================================================
function SlashMoon.Tasks.GetRarityColor(rarity)
    if rarity == "common" then
        return Color(180, 180, 180)     -- Серый
    elseif rarity == "uncommon" then
        return Color(50, 255, 100)      -- Зелёный
    elseif rarity == "rare" then
        return Color(50, 150, 255)      -- Синий
    elseif rarity == "epic" then
        return Color(180, 50, 255)      -- Фиолетовый
    elseif rarity == "legendary" then
        return Color(255, 180, 0)       -- Золотой
    else
        return Color(180, 180, 180)     -- По умолчанию common
    end
end

-- Локализованное название редкости
function SlashMoon.Tasks.GetRarityName(rarity)
    return SlashMoon.Tasks.Lang("sn.rarity." .. (rarity or "common"))
end

-- ========================================================
-- ОПИСАНИЕ ПРЕДМЕТА (локализованное)
-- ========================================================
function SlashMoon.Tasks.GetItemDescription(rawClass)
    if not rawClass or rawClass == "" then return "" end

    local parsed = SlashMoon.Tasks.ParseItemEntry(rawClass)
    local baseClass = parsed.baseClass
    local itemDef = SlashMoon.Tasks.Items[baseClass]

    if not itemDef then return "" end

    -- Локализованное описание через descKey
    if itemDef.descKey then
        local localized = SlashMoon.Tasks.Lang(itemDef.descKey)
        if localized ~= itemDef.descKey then return localized end
    end

    -- Фоллбэк на description
    return itemDef.description or ""
end

-- ========================================================
-- МОДЕЛЬ ЭНТИТИ ДЛЯ ПРЕДМЕТА (мир, когда выброшен)
-- Разные модели по типу и редкости
-- ========================================================
SlashMoon.Tasks.ItemModels = {
    -- ═══ По типу предмета ═══
    types = {
        weapon     = "models/Items/BoxSRounds.mdl",
        material   = "models/props_junk/cardboard_box004a.mdl",
        tool       = "models/props_c17/tools_wrench01a.mdl",
        consumable = "models/props_junk/PopCan01a.mdl",
        quest      = "models/Items/item_item_crate.mdl",
        rare       = "models/Items/Flare.mdl",
        electronic = "models/props_lab/reciever01c.mdl",
        chemical   = "models/props_junk/PropaneCanister001a.mdl",
    },

    -- ═══ Переопределения для оружия по редкости ═══
    -- Более редкое оружие = более «ценная» моделька
    weaponRarity = {
        common    = "models/Items/BoxSRounds.mdl",
        uncommon  = "models/Items/Flare.mdl",
        rare      = "models/Items/item_item_crate.mdl",
        epic      = "models/Items/BoxMRounds.mdl",
        legendary = "models/Items/ducket.mdl",
    },

    -- ═══ Переопределения для конкретных предметов ═══
    specific = {
        ["weapon_gascan"]      = "models/props_junk/metalgascan001a.mdl",
        ["weapon_killmask"]    = "models/props_lab/hgboot.mdl",
        ["weapon_wrench"]      = "models/props_c17/tools_wrench01a.mdl",
        ["weapon_flashlight"]  = "models/Items/Flare.mdl",
        ["weapon_crapvidcam"]  = "models/props_lab/reciever01b.mdl",
        ["item_toolbox"]       = "models/props_c17/tools_wrench01a.mdl",
        ["weapon_snowball"]    = "models/Items/Flare.mdl",
        ["weapon_taser"]       = "models/Items/battery.mdl",
        ["weapon_banana"]      = "models/props/cs_italy/bananna.mdl",
        ["weapon_killer_axe"]  = "models/weapons/w_killer_axe.mdl",
        ["weapon_pistol"]      = "models/weapons/w_pistol.mdl",
        ["weapon_frag"]        = "models/weapons/w_grenade.mdl",
        ["weapon_crowbar"]     = "models/weapons/w_crowbar.mdl",
        ["weapon_defibrillator"] = "models/Items/battery.mdl",
        ["weapon_fh_medkit"]   = "models/Items/healthkit.mdl",
        ["weapon_adrenaline"]  = "models/Items/medkit.mdl",
        ["weapon_fanta"]       = "models/johnmason/food/w_coca_cola_can.mdl",
        ["mat_medpack"]        = "models/props_junk/garbage_plasticbottle002a.mdl",
        ["mat_acid"]           = "models/props_junk/PropaneCanister001a.mdl",
        ["mat_solvent"]        = "models/props_junk/PropaneCanister001a.mdl",
        ["mat_battery"]        = "models/Items/battery.mdl",
        ["mat_transistor"]     = "models/props_lab/reciever01c.mdl",
        ["mat_circuit_board"]  = "models/props_lab/reciever01b.mdl",
        ["mat_servo"]          = "models/props_lab/reciever01c.mdl",
        ["item_delivery_receiver"] = "models/props_lab/reciever01c.mdl",
        ["item_delivery_radio"] = "models/props_lab/reciever01b.mdl",
        ["item_delivery_medical"] = "models/props_junk/garbage_plasticbottle002a.mdl",
        ["item_delivery_food"] = "models/food/hotdog.mdl",
        ["item_delivery_chemicals"] = "models/props_junk/PropaneCanister001a.mdl",
        ["item_golden_coin"]   = "models/Items/ducket.mdl",
        ["item_artifact"]      = "models/Items/Flare.mdl",
        ["item_keycard_blue"]  = "models/Items/item_item_crate.mdl",
        ["item_keycard_red"]   = "models/Items/item_item_crate.mdl",
        ["item_blueprint"]     = "models/props_junk/cardboard_box004a.mdl",
    },
}

-- Получить модель для предмета
function SlashMoon.Tasks.GetItemModel(class)
    local parsed = SlashMoon.Tasks.ParseItemEntry(class)
    local baseClass = parsed.baseClass
    local itemDef = SlashMoon.Tasks.Items[baseClass]
    local models = SlashMoon.Tasks.ItemModels

    -- 1. Специфичная моделька для предмета
    if models.specific[baseClass] then
        return models.specific[baseClass]
    end

    if not itemDef then
        -- Неизвестный предмет: по префиксу
        if string.StartWith(baseClass, "mat_") then
            return models.types.material
        end
        return models.types.weapon
    end

    -- 2. Оружие: модель по редкости
    if itemDef.type == "weapon" then
        local rarity = itemDef.rarity or "common"
        if models.weaponRarity[rarity] then
            return models.weaponRarity[rarity]
        end
    end

    -- 3. По типу предмета
    if models.types[itemDef.type] then
        return models.types[itemDef.type]
    end

    -- 4. Фоллбэк
    return "models/Items/BoxSRounds.mdl"
end

function SlashMoon.Tasks.GetItemWorldScale(class)
    local parsed = SlashMoon.Tasks.ParseItemEntry(class)
    local itemDef = SlashMoon.Tasks.Items[parsed.baseClass]
    return math.Clamp(tonumber(itemDef and itemDef.worldScale) or 1, 0.25, 4)
end

-- Очистка кеша материалов
function SlashMoon.Tasks.ClearMaterialCache()
    table.Empty(SlashMoon.Tasks._MatCache)
end

-- ========================================================
-- GetItemData — безопасная обёртка (работает на обоих реалмах)
-- ========================================================
function SlashMoon.Tasks.GetItemData(rawClass)
    if not rawClass or rawClass == "" then
        return { name = SlashMoon.Tasks.Lang("sn.inv.empty"), type = "misc", icon = nil, mat = nil, count = 0, rarity = "common", description = "" }
    end

    local parsed = SlashMoon.Tasks.ParseItemEntry(rawClass)
    local baseClass = parsed.baseClass

    local baseData = SlashMoon.Tasks.Items[baseClass] or {
        name = SlashMoon.Tasks.Lang(baseClass),
        type = string.StartWith(baseClass, "mat_") and "material" or "weapon",
        icon = nil,
        rarity = "common",
        description = "",
    }

    local data = table.Copy(baseData)

    -- Локализованное название через SlashMoon.Tasks.Lang
    if data.nameKey then
        local localized = SlashMoon.Tasks.Lang(data.nameKey)
        if localized ~= data.nameKey then data.name = localized end
    end

    -- Стак: показываем количество в названии
    data.count = parsed.count
    if parsed.count > 1 and (data.stackable or (data.type == "material" or data.type == "electronic" or data.type == "chemical" or data.type == "consumable")) then
        data.name = data.name .. " x" .. parsed.count
    end

    -- Динамическое название для канистры
    if baseClass == "weapon_gascan" and parsed.fuel then
        local template = SlashMoon.Tasks.Lang("sn.inv.gascan_name")
        data.name = template .. " (" .. parsed.fuel .. "%)"
        data.fuel = parsed.fuel
    end

    -- Редкость (по умолчанию common)
    data.rarity = data.rarity or "common"

    -- Локализованное описание
    if data.descKey then
        local locDesc = SlashMoon.Tasks.Lang(data.descKey)
        if locDesc ~= data.descKey then
            data.description = locDesc
        end
    end
    data.description = data.description or ""

    -- Клиент: добавляем закешированный Material
    if CLIENT then
        data.mat = SlashMoon.Tasks.GetItemMaterial(rawClass)
    end

    return data
end
