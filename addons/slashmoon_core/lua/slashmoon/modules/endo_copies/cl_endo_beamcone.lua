-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("endo_copies")

-- =====================================================================
-- Умный рендер конусов Эндоскелета
-- =====================================================================

if not CLIENT then return end

local VISION_RANGE         = 500
local VISION_ANGLE_DEG     = 35
local VISION_EYE_FALLBACK  = 60
local LIGHT_ORIGIN_FWD_OFF = 15

local MAX_PROJECTORS   = 6
local LIGHT_BRIGHTNESS = 1.2
local LIGHT_COLOR      = Color(255, 255, 255)
local LIGHT_SHADOWS    = true  
local LIGHT_NEARZ      = 4

local BEAM_MATERIAL    = Material("sprites/light_glow02_add")
local BEAM_COLOR       = LIGHT_COLOR
local BEAM_MAX_ALPHA   = 18
local BEAM_SEGMENTS    = 8

local EYE_BONE_PAIR = { "bip_eyelid_0_L", "bip_eyelid_0_R" }
local EYE_BONE_FALLBACK = {
    "eyes", "Eyes", "eye", "ValveBiped.Bip01_Head1", "Head", "head", "bip_head",
}

local FLASH_COOKIE
do
    local ok, mat = pcall(Material, "effects/flashlight001")
    if ok and mat and not mat:IsError() then
        local tex = mat:GetTexture("$basetexture")
        if tex then FLASH_COOKIE = tex end
    end
end

-- =====================================================================
--  УМНЫЙ ПУЛ (LAZY INITIALIZATION)
-- =====================================================================
local projectorPool   = nil
local projectorActive = nil
local fallbackCopies  = {}

-- Создает фонарики в видеокарте ТОЛЬКО когда они реально нужны
local function CreateFlashlights()
    if projectorPool then return end
    
    projectorPool = {}
    projectorActive = {}

    for i = 1, MAX_PROJECTORS do
        local pt = ProjectedTexture()
        if FLASH_COOKIE then pt:SetTexture(FLASH_COOKIE) end
        pt:SetNearZ(LIGHT_NEARZ)
        pt:SetFarZ(VISION_RANGE)
        pt:SetFOV(VISION_ANGLE_DEG * 2)
        pt:SetColor(LIGHT_COLOR)
        pt:SetBrightness(0)
        
        -- Тени задаются СТРОГО один раз при создании
        pt:SetEnableShadows(LIGHT_SHADOWS and i == 1)
        
        projectorPool[i]   = pt
        projectorActive[pt] = false
    end
    MODULE.FlashlightPool = projectorPool
    SlashMoon.Debug("[Endo] Фонарики созданы в VRAM.")
end

-- Уничтожает фонарики, освобождая видеопамять, когда копий нет на карте
local function DestroyFlashlights()
    if projectorPool then
        for _, pt in ipairs(projectorPool) do
            if IsValid(pt) then
                pt:SetBrightness(0)
                pt:SetEnableShadows(false)
                pt:Update()
                pt:Remove()
            end
        end
        projectorPool = nil
        projectorActive = nil
        MODULE.FlashlightPool = nil
        SlashMoon.Debug("[Endo] Фонарики удалены из VRAM (простой).")
    end
    fallbackCopies = {}
end

local function GetCopyEyeOrigin(copy)
    -- Без SetupBones() для максимального FPS
    local lBone = copy:LookupBone(EYE_BONE_PAIR[1])
    local rBone = copy:LookupBone(EYE_BONE_PAIR[2])
    if lBone and rBone then
        local lPos = copy:GetBonePosition(lBone)
        local rPos = copy:GetBonePosition(rBone)
        if lPos and rPos then return (lPos + rPos) * 0.5 end
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
--  THINK (ОПТИМИЗИРОВАННЫЙ)
-- =====================================================================
local nextLightUpdate = 0

MODULE:Hook("Think", "endo_copy_flashlight_update", function()
    if CurTime() < nextLightUpdate then return end
    nextLightUpdate = CurTime() + 0.05 -- 20 раз в секунду

    -- 1. Ищем копии на карте
    local allCopies = ents.FindByClass("endo_copy")
    
    -- 2. Если копий нет — уничтожаем фонарики и выходим (0% нагрузки!)
    if #allCopies == 0 then
        if projectorPool then DestroyFlashlights() end
        return
    end

    -- 3. Если копии есть, но фонариков еще нет — создаем их
    if not projectorPool then
        CreateFlashlights()
    end

    local lp = LocalPlayer()
    local camPos = IsValid(lp) and lp:EyePos() or Vector(0, 0, 0)

    local list = {}
    for _, copy in ipairs(allCopies) do
        if not IsValid(copy) then continue end
        if copy.GetCopyHP and copy:GetCopyHP() <= 0 then continue end

        local eyePos = GetCopyEyeOrigin(copy)
        list[#list + 1] = {
            copy    = copy,
            eyePos  = eyePos,
            fwd     = copy.GetVisionDirSafe and copy:GetVisionDirSafe() or copy:GetAngles():Forward(),
            distSqr = camPos:DistToSqr(eyePos),
        }
    end

    table.sort(list, function(a, b) return a.distSqr < b.distSqr end)

    local activeCount = math.min(#list, MAX_PROJECTORS)

    for i = 1, activeCount do
        local pt   = projectorPool[i]
        local data = list[i]

        pt:SetPos(data.eyePos + data.fwd * LIGHT_ORIGIN_FWD_OFF)
        pt:SetAngles(data.fwd:Angle())
        pt:SetBrightness(LIGHT_BRIGHTNESS)
        pt:Update()
        projectorActive[pt] = true
    end

    for i = activeCount + 1, MAX_PROJECTORS do
        local pt = projectorPool[i]
        if projectorActive[pt] then
            pt:SetBrightness(0)
            pt:Update()
            projectorActive[pt] = false
        end
    end

    fallbackCopies = {}
    for i = MAX_PROJECTORS + 1, #list do
        fallbackCopies[#fallbackCopies + 1] = list[i]
    end
end)

MODULE:Hook("PostDrawTranslucentRenderables", "endo_copy_flashlight_fallback", function(_depth, skybox)
    if skybox then return end
    if not fallbackCopies or #fallbackCopies == 0 then return end

    local halfTan = math.tan(math.rad(VISION_ANGLE_DEG))
    render.SetMaterial(BEAM_MATERIAL)

    for _, data in ipairs(fallbackCopies) do
        if not IsValid(data.copy) then continue end
        local origin = data.eyePos
        local fwd    = data.fwd

        for i = 1, BEAM_SEGMENTS do
            local t0 = (i - 1) / BEAM_SEGMENTS
            local t1 = i / BEAM_SEGMENTS
            local d0 = VISION_RANGE * t0
            local d1 = VISION_RANGE * t1
            local w0 = math.max(2, d0 * halfTan)
            local w1 = math.max(2, d1 * halfTan)
            local p0 = origin + fwd * d0
            local p1 = origin + fwd * d1
            local alpha = BEAM_MAX_ALPHA * (1 - t1)

            render.DrawBeam(p0, p1, w0 + w1, 0, 1,
                Color(BEAM_COLOR.r, BEAM_COLOR.g, BEAM_COLOR.b, alpha))
        end
    end
end)

-- Глобальная очистка при дисконнекте/смене карты
MODULE:Hook("ShutDown", "endo_copy_flashlight_shutdown", DestroyFlashlights)
gameevent.Listen("client_disconnect")
MODULE:Hook("client_disconnect", "endo_copy_flashlight_disconnect", DestroyFlashlights)

MODULE:Hook("OnReloaded", "endo_copy_flashlight_reload_safety", DestroyFlashlights)
MODULE:OnDisabled(DestroyFlashlights)
