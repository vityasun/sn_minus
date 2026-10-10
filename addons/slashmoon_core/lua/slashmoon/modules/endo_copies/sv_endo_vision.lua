-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("endo_copies")

-- sv_endo_copy_vision.lua
if CLIENT then return end

local VISION_RANGE        = 460   -- дальность конуса, юниты
local VISION_ANGLE_DEG    = 20    -- половинный угол конуса в градусах
local VISION_TICK         = 0.15  -- как часто проверяем (не каждый тик — ради перфа)
local VISION_EYE_FALLBACK = 60    -- запасной оффсет по Z, если bone не нашёлся
local VISION_HOLD         = 0.5   -- сколько клиент держит подсветку после последнего детекта

local VISION_COS = math.cos(math.rad(VISION_ANGLE_DEG))

util.AddNetworkString("endo_copy_spotted")


local ownerSpotted = {}

MODULE:Hook("SetupPlayerVisibility", "endo_copy_vision_pvs", function(ply, viewent)
    local spotted = ownerSpotted[ply]
    if not spotted then return end

    local now = CurTime()
    for target, exp in pairs(spotted) do
        if IsValid(target) and now <= exp and target:Alive() then
            -- viewent:TestPVS дёшево пропускает уже видимых — не дублируем.
            if not IsValid(viewent) or not viewent:TestPVS(target) then
                AddOriginToPVS(target:GetPos())
            end
        end
    end
end)

-- Сброс при очистке карты / смене раунда.
MODULE:Hook("PostCleanupMap", "endo_copy_vision_pvs_reset", function()
    table.Empty(ownerSpotted)
end)

-- Точные имена глазных костей в endo02.mdl (найдены через fhi_endo_list_bones).
-- Усредняем L и R, чтобы конус детекта выходил из центра лица — так же,
-- как визуальный луч в cl_endo_beamcone.lua. Это важно: точка старта детекта
-- и точка старта света должны совпадать, иначе "вижу свет, но не детектит"
-- или наоборот.
local EYE_BONE_PAIR = { "bip_eyelid_0_L", "bip_eyelid_0_R" }

local EYE_BONE_FALLBACK = {
    "eyes", "Eyes", "eye", "ValveBiped.Bip01_Head1", "Head", "head", "bip_head",
}

local function GetCopyEyeOrigin(copy)
    -- ВАЖНО: SetupBones() НЕ вызываем — это клиентский метод, на сервере
    -- его нет (будет "attempt to call method 'SetupBones' (a nil value)").
    -- На сервере кости доступны сразу после SetModel (ENT:Initialize в
    -- init.lua копии уже выставил модель и кости развёрнуты).

    local lBone = copy:LookupBone(EYE_BONE_PAIR[1])
    local rBone = copy:LookupBone(EYE_BONE_PAIR[2])
    if lBone and rBone then
        local lPos = copy:GetBonePosition(lBone)
        local rPos = copy:GetBonePosition(rBone)
        if lPos and rPos then
            return (lPos + rPos) * 0.5
        end
    end

    for _, boneName in ipairs(EYE_BONE_PAIR) do
        local bone = copy:LookupBone(boneName)
        if bone then
            local pos = copy:GetBonePosition(bone)
            if pos and pos ~= copy:GetPos() then return pos end
        end
    end

    for _, boneName in ipairs(EYE_BONE_FALLBACK) do
        local bone = copy:LookupBone(boneName)
        if bone then
            local pos = copy:GetBonePosition(bone)
            if pos and pos ~= copy:GetPos() then return pos end
        end
    end

    return copy:GetPos() + Vector(0, 0, VISION_EYE_FALLBACK)
end

-- =====================================================================
--  DEBUG — визуализация конуса обзора через debugoverlay
-- =====================================================================
--  Встроенного debugoverlay.Cone в GMod НЕТ — есть только Line, Cross,
--  Sphere, Box, Axis. Этот хелпер собирает wireframe конуса вручную.
--
--  ents.FindInCone — это сферический сектор: пересечение сферы радиуса
--  range и конуса с half-angle α вокруг dir. Граница — окружность на
--  сфере: центр в pos+dir*(range*cosα), радиус range*sinα.
--
--  Включается кон-командой endo_vision_debug (toggle, superadmin only).
--  Рисуется каждый тик детекта:
--    жёлтый wireframe — объём конуса
--    зелёная линия    — пойманный выживший (in cone + LOS clear)
--    красная линия+X  — выживший в конусе, но за стеной (blocked)
--    серая линия      — выживший рядом, но вне угла конуса
--
--  debugoverlay.* с сервера виден ВСЕМ клиентам (broadcast). Если не
--  видно — попробуй developer 1 в консоли.

local visionDebug = false

MODULE:Command("endo_vision_debug", function(ply, cmd, args)
    if IsValid(ply) and not SlashMoon.Admin.HasPermission(ply, "slashmoon_endo_debug") then return end
    visionDebug = not visionDebug
    local msg = visionDebug and "ВКЛ" or "ВЫКЛ"
    SlashMoon.Log("[endo_vision] Debug overlay: ", msg)
    if IsValid(ply) then ply:ChatPrint("[endo_vision] Debug: " .. msg) end
end)

local function DrawConeWireframe(pos, dir, range, cosHalf, duration, color)
    dir = dir:GetNormalized()
    local halfAngle = math.acos(math.Clamp(cosHalf, -1, 1))
    local sinHalf = math.sin(halfAngle)

    -- Центр окружности-основания (на сфере, вдоль dir) и её радиус
    local baseCenter = pos + dir * (range * cosHalf)
    local baseRadius = range * sinHalf

    -- Два перпендикуляра к dir для построения окружности
    local up    = math.abs(dir.z) < 0.99 and Vector(0, 0, 1) or Vector(1, 0, 0)
    local right = dir:Cross(up):GetNormalized()
    local perp  = right:Cross(dir):GetNormalized()

    -- Ось конуса
    debugoverlay.Line(pos, pos + dir * range, duration, color, false)

    -- 8 образующих (от вершины к краю основания)
    local spokes = 8
    for i = 0, spokes - 1 do
        local a = (i / spokes) * math.pi * 2
        local edge = baseCenter
            + right * (baseRadius * math.cos(a))
            + perp  * (baseRadius * math.sin(a))
        debugoverlay.Line(pos, edge, duration, color, false)
    end

    -- Окружность основания (16 сегментов)
    local ringSegs = 16
    local prev
    for i = 0, ringSegs do
        local a = (i / ringSegs) * math.pi * 2
        local p = baseCenter
            + right * (baseRadius * math.cos(a))
            + perp  * (baseRadius * math.sin(a))
        if prev then
            debugoverlay.Line(prev, p, duration, color, false)
        end
        prev = p
    end

    -- Крест в вершине (точка глаз)
    debugoverlay.Cross(pos, 8, duration, Color(255, 255, 0), false)
end

local function DoVisionCheck()
    -- Накапливаем пойманных по owner, чтобы отправить ОДНО сообщение
    -- на owner за тик (даже если у него несколько копий детектят).
    local ownerCaught = {}

    for _, copy in ipairs(ents.FindByClass("endo_copy")) do
        if not IsValid(copy) then continue end
        if copy.GetCopyHP and copy:GetCopyHP() <= 0 then continue end -- мёртвая копия не "видит"

        local owner = copy.GetOwnerPlayer and copy:GetOwnerPlayer()
        if not IsValid(owner) or not owner:Alive() then continue end

        local eyePos = GetCopyEyeOrigin(copy)
        local dir    = copy.GetVisionDirSafe and copy:GetVisionDirSafe() or copy:GetAngles():Forward()

        -- DEBUG: рисуем wireframe конуса + проверяем ВСЕХ ближайших
        -- выживших, чтобы показать не только пойманных, но и тех, кто
        -- в конусе но за стеной (красный) или вообще вне угла (серый).
        if visionDebug then
            local dur = VISION_TICK + 0.05
            DrawConeWireframe(eyePos, dir, VISION_RANGE, VISION_COS, dur, Color(255, 220, 0))

            for _, target in ipairs(ents.FindInSphere(eyePos, VISION_RANGE)) do
                if not IsValid(target) or not target:IsPlayer() then continue end
                if target == owner then continue end
                if not target:Alive() or not target:IsSurvivor() then continue end
                if target:Team() == TEAM_SPECTATOR then continue end

                local targetEye = target:EyePos()
                local toTarget  = targetEye - eyePos
                local dist      = toTarget:Length()
                if dist > VISION_RANGE or dist < 1 then continue end

                local dot    = dir:Dot(toTarget / dist)
                local inCone = dot >= VISION_COS

                if not inCone then
                    -- Вне угла конуса — серая линия
                    debugoverlay.Line(eyePos, targetEye, dur, Color(120, 120, 120), false)
                    continue
                end

                -- В конусе — проверяем стену
                local tr = util.TraceLine({
                    start  = eyePos,
                    endpos = targetEye,
                    filter = { copy, owner, target },
                    mask   = MASK_BLOCKLOS_AND_NPCS,
                })
                if tr.Hit and tr.Entity ~= target then
                    -- Заблокирован стеной — красная линия до стены + крест
                    debugoverlay.Line(eyePos, tr.HitPos, dur, Color(255, 50, 50), false)
                    debugoverlay.Cross(tr.HitPos, 8, dur, Color(255, 50, 50), false)
                end
                -- Если в конусе и LOS чистый — зелёную линию нарисует
                -- основной цикл ниже (чтобы не дублировать).
            end
        end

        for _, target in ipairs(ents.FindInCone(eyePos, dir, VISION_RANGE, VISION_COS)) do
            if not IsValid(target) or not target:IsPlayer() then continue end
            if target == owner then continue end
            if not target:Alive() then continue end
            if not target:IsSurvivor() then continue end -- маньяка этим не палим
            if target:Team() == TEAM_SPECTATOR then continue end

            -- Проверка на стены — FindInCone геометрию не учитывает.
            local tr = util.TraceLine({
                start  = eyePos,
                endpos = target:EyePos(),
                filter = { copy, owner, target },
                mask   = MASK_BLOCKLOS_AND_NPCS,
            })
            if tr.Hit and tr.Entity ~= target then continue end -- закрыт стеной

            -- DEBUG: зелёная линия — выживший пойман (in cone + LOS clear)
            if visionDebug then
                debugoverlay.Line(eyePos, target:EyePos(), VISION_TICK + 0.05, Color(0, 255, 0), false)
            end

            ownerCaught[owner] = ownerCaught[owner] or {}
            ownerCaught[owner][target] = true  -- dedupe (если 2 копии одного owner поймали одного выжившего)
        end
    end

    -- Отправляем одно нет-сообщение per owner. Если у owner ничего не поймано
    -- в этом тике — не шлём ничего: клиент сам снимет подсветку по истечении
    -- VISION_HOLD с прошлого обновления.
    local now = CurTime()
    local expire = now + VISION_HOLD

    for owner, set in pairs(ownerCaught) do
        local list = {}
        for target in pairs(set) do
            list[#list + 1] = target
        end
        if #list > 0 then
            -- Обновляем серверный трекинг для PVS — те же expire, что у клиента.
            ownerSpotted[owner] = ownerSpotted[owner] or {}
            for _, target in ipairs(list) do
                ownerSpotted[owner][target] = expire
            end

            net.Start("endo_copy_spotted")
            net.WriteTable(list)
            net.WriteFloat(VISION_HOLD)
            net.Send(owner)
        end
    end

    -- Чистим истёкших/умерших/ушедших из ownerSpotted — иначе PVS будет
    -- вечно добавлять позиции мёртвых/дисконнектнувшихся. Делаем здесь,
    -- а не отдельным Think-таймером — VISION_TICK достаточно частый.
    for owner, spotted in pairs(ownerSpotted) do
        if not IsValid(owner) or not owner:Alive() then
            ownerSpotted[owner] = nil
            continue
        end
        for target, exp in pairs(spotted) do
            if not IsValid(target) or now > exp or not target:Alive() then
                spotted[target] = nil
            end
        end
        if table.IsEmpty(spotted) then
            ownerSpotted[owner] = nil
        end
    end
end

MODULE:Timer("endo_copy_vision_tick", VISION_TICK, 0, DoVisionCheck)
