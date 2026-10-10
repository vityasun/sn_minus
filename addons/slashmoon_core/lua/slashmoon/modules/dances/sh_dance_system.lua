-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- Система танцев/эмоций (основана на wOS Dance System)
-- ========================================================

if SERVER then
    util.AddNetworkString("wOS_Dance_Play")
    util.AddNetworkString("wOS_Dance_Stop")
    util.AddNetworkString("wOS_Dance_Sync")
    util.AddNetworkString("wOS_Dance_Stop_Request")
end
SlashMoon.Dances = SlashMoon.Dances or {}
SlashMoon.Dances.Animations = SlashMoon.Dances.Animations or {}
SlashMoon.Dances.Categories = SlashMoon.Dances.Categories or {}

-- Функция для регистрации категорий
function SlashMoon.Dances.RegisterCategory(id, data)
    SlashMoon.Dances.Categories[id] = data
end

-- Регистрируем категории
SlashMoon.Dances.RegisterCategory("gesture", { name = "Жесты", type = "gesture" })
SlashMoon.Dances.RegisterCategory("dance", { name = "Танцы", type = "dance" })
SlashMoon.Dances.RegisterCategory("stand", { name = "Стойки", type = "stand" })

-- Сами анимации
SlashMoon.Dances.Animations = {
    ["robot"] = { name = "Робот", seq = "taunt_robot", cat = "dance", loop = false },
    ["dance"] = { name = "Танец GMod", seq = "taunt_dance", cat = "dance", loop = false },
    ["muscle"] = { name = "Секси", seq = "taunt_muscle", cat = "dance", loop = false },
    ["Ifudoudou"] = { name = "Ifudoudou", seq = "dance_coronation", cat = "dance", music = 'sn/anim/dance_ifudoudou_loop.ogg' },
    ["ador"] = { name = "Low Cortisol", seq = "dance_lowcortisol", cat = "dance", music = 'sn/anim/dance_lowcortisol_loop.mp3' },
    ["uma"] = { name = "Umapyoi", seq = "dance_Umapyoicenter", cat = "dance", music = 'sn/anim/dance_umapyoidensetsu.mp3', loop = false },
    ["Miku"] = { name = "miku", seq = "dance_miku_01", cat = "dance", music = 'sn/anim/dance_miku_01_loop.mp3' },
    ["Caramella"] = { name = "Caramella Dance", seq = "dance_mmd_caramell", cat = "dance", music = 'sn/anim/dance_caramell.ogg' },
    ["5x30"] = { name = "5x30", seq = "dance_fivexthirty", cat = "dance", music = 'sn/anim/dance_fivexthirty.mp3' },
    ["Headlock1sho"] = { name = "Headlock1sho", seq = "dance_headlock1shot", cat = "dance", music = 'sn/anim/dance_headlock1shot.mp3' },
    ["Canijoin"] = { name = "Canijoin", seq = "dance_canijoin", cat = "dance", music = 'sn/anim/dance_canijoin.mp3' },
    ["triodance"] = { name = "Triodance", seq = "dance_triodance", cat = "dance", music = 'sn/anim/dance_triodance.mp3' },
    ["kona01"] = { name = "Hero's Come Back!!", seq = "dance_kona_d01", cat = "dance", music = 'sn/anim/dance_d01.mp3' },
    ["kona02"] = { name = "I Can't Wait", seq = "dance_kona_d02", cat = "dance", music = 'sn/anim/dance_d02.mp3' },
    ["rabit"] = { name = "Rabbit Hole", seq = "dance_mikurabbithole", cat = "dance", music = 'sn/anim/dance_rabbitholeloop.mp3' },
    ["dance_chess"] = { name = "Chess is this serious", seq = "dance_chess", cat = "dance", music = 'sn/anim/dance_chessphonk.mp3' },
    ["Motion"] = { name = "Motion", seq = "dance_motion", cat = "dance", music = 'sn/anim/dance_prettyboy.mp3' },
    ["Imissq"] = { name = "I Miss The Quiet", seq = "dance_missthequiet", cat = "dance", music = 'sn/anim/dance_missthequiet_loop.mp3' },
    ["dcmb"] = { name = "Don't come back", seq = "dance_dontcomeback", cat = "dance", music = 'sn/anim/dance_dontcomeback.mp3' },
    ["kurse"] = { name = "Kurse", seq = "dance_kurse", cat = "dance", music = 'sn/anim/dance_kurse.mp3' },
    ["test"] = { name = "test", seq = "dance_fib", cat = "dance", music = 'sn/anim/test.mp3' },
}

SlashMoon.Dances.DefaultFree = {
    ["robot"] = true,
    ["dance"] = true,
    ["muscle"] = true,
    ["ador"] = true,
    ["uma"] = true,
    ["Miku"] = true,
}

-- Проверка, является ли анимация бесплатной
function SlashMoon.Dances.IsFree(animID)
    if SlashMoon.Dances.DefaultFree[animID] then return true end

    local data = SlashMoon.Dances.Animations[animID]
    if not data then return false end

    -- Бесплатна только если явно указано free = true
    return data.free == true
end

-- Проверка доступа игрока к анимации (Бесплатные + Инвентарь из БД)
function SlashMoon.Dances.HasDance(ply, animID)
    if not animID or animID == "" then return false end

    -- 1. Бесплатные анимации доступны всем
    if SlashMoon.Dances.IsFree(animID) then
        return true
    end

    -- Без экономики хаба (модуль выключен) платных анимаций нет — доступно всё
    if not SlashMoon.Modules.IsEnabled("hub") then
        return true
    end

    if not IsValid(ply) then return false end

    -- 2. Проверка инвентаря на сервере
    if SERVER then
        return istable(ply.SN_Inventory) and ply.SN_Inventory[animID] == true
    end

    -- 3. Проверка инвентаря на клиенте (поддержка SlashMoon.Hub.Inventory и LocalPlayer().SN_Inventory)
    if CLIENT then
        if SlashMoon.Hub and istable(SlashMoon.Hub.Inventory) and SlashMoon.Hub.Inventory[animID] == true then
            return true
        end
        if istable(ply.SN_Inventory) and ply.SN_Inventory[animID] == true then
            return true
        end
    end

    return false
end

-- === ИСПРАВЛЕНИЕ: Регистрация ActMod анимаций (по умолчанию ПЛАТНЫЕ / ИНВЕНТАРНЫЕ) ===
function SlashMoon.Dances.RegisterActModAnimation(id, data)
    if not isstring(id) or not istable(data) or not isstring(data.seq) then return false end

    data.mode = "actmod"
    data.cat = data.cat or "dance"
    data.loop = data.loop ~= false
    data.rate = data.rate or 1
    data.cycle = data.cycle or 0
    data.repeatCycle = data.repeatCycle == nil and data.cycle or data.repeatCycle
    data.free = data.free == true -- По умолчанию FALSE (требует покупки / промокода)
    
    if data.movement then
        data.movement.type = data.movement.type or 3
        data.movement.speed = data.movement.speed or 100
        data.movement.static = data.movement.static or data.seq
        data.movement.walk = data.movement.walk or data.movement.static
    end
    
    SlashMoon.Dances.Animations[id] = data
    SlashMoon.Dances.SeqLookup = SlashMoon.Dances.SeqLookup or {}
    SlashMoon.Dances.SeqLookup[data.seq] = id
    return true
end

function SlashMoon.Dances.RegisterActModEntry(id, entry)
    if not isstring(id) or not istable(entry) or not istable(entry.Config) then return false end

    local config = entry.Config
    local custom = istable(entry.Custom) and entry.Custom.Anim or {}
    local sounds = istable(entry.Sounds) and entry.Sounds.Start or nil
    local repeatSound = istable(entry.Sounds) and entry.Sounds.Repeat or nil
    local data = {
        name = config.Name or id,
        seq = config.Anim,
        duration = custom.Time1 or config.Duration,
        repeatDuration = custom.Time2,
        cycle = custom.Cycle or config.Cycle or 0,
        repeatCycle = custom.Cycle or config.Cycle or 0,
        rate = config.Rate or 1,
        loop = config.Repeat ~= false,
        music = sounds and sounds.Sound,
        repeatMusic = repeatSound and repeatSound.Sound,
        free = config.Free == true, -- По умолчанию FALSE
        cat = "dance",
        movement = entry.Movement and {
            type = entry.Movement.Type,
            speed = entry.Movement.Speed,
            static = entry.Movement.Motion and entry.Movement.Motion.Static,
            walk = entry.Movement.Motion and entry.Movement.Motion.Walk
        }
    }
    return SlashMoon.Dances.RegisterActModAnimation(id, data)
end

-- Add manual registrations below this line. Nothing is auto-discovered.
-- Example:
-- SlashMoon.Dances.RegisterActModAnimation("gato_nightmail", {
--     name = "Nightmail",
--     seq = "amod_gatopack_nightmail",
--     duration = 7.2,
--     music = "music/nightmail.ogg"
-- })

-- Load manual registrations after the registry function and base table exist.
SlashMoon.IncludeFile("slashmoon/modules/dances/sh_actmod_animations.lua", "sh")

-- Кеш для быстрого поиска по seq (имени анимации в движке)
SlashMoon.Dances.SeqLookup = SlashMoon.Dances.SeqLookup or {}
for id, data in pairs(SlashMoon.Dances.Animations) do
    SlashMoon.Dances.SeqLookup[data.seq] = id
end
