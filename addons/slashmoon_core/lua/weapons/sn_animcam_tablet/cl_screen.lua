-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- sn_animcam_tablet: cl_screen.lua
-- Клиентский рендер экрана планшета.
-- Рендерит EyePos/EyeAngles выбранного игрока-аниматроника в RT текстуру.

local math            = math
local render          = render
local surface         = surface
local cam             = cam
local DrawColorModify = DrawColorModify

-- ============================================================
-- Утилита: ближайшая степень двойки
-- ============================================================
local function findClosestPOT(x)
    local closestOne = math.huge
    local lastOne    = math.huge
    local lastDist   = math.huge
    local curStep    = 1

    while lastOne == closestOne do
        local newPOT  = 2 ^ curStep
        local newDist = x - newPOT
        if newDist < 0 then break end
        if newDist < lastDist then
            closestOne = newPOT
            lastDist   = newDist
        end
        lastOne  = newPOT
        curStep  = curStep + 1
    end
    return closestOne
end

-- ============================================================
-- ConVar'ы
-- ============================================================
local CAM_RES        = CreateClientConVar("sn_animcam_resolution",  1024, true, false, "", 128, 1024)
local CAMUPDATE_TIME = CreateClientConVar("sn_animcam_updatetime",   0.1,  true, false, "Delay between animatronic camera updates", 0.05, 1)
local CAMPIXEL_RATE  = CreateClientConVar("sn_animcam_pixelrate",    0,    true, false, "Pixelation rate (1 = off)", 1)

local CAMRES_W = findClosestPOT(CAM_RES:GetInt())
local CAMRES_H = findClosestPOT(CAM_RES:GetInt())

-- ============================================================
-- Материалы и текстуры
-- ============================================================
local matScreen = Material("models/vondaram/tablet/ekran")
if matScreen:IsError() then
    ErrorNoHalt("[sn_animcam_tablet] Tablet screen texture not found!\n")
end

local TEXTURE_SIZE_X = matScreen:Width()
local TEXTURE_SIZE_Y = matScreen:Height()

local CAMFONT_COLOR      = Color(170, 170, 170, 100)
local BLACK_COLOR        = Color(0, 0, 0, 255)
local CAMHUD_MARGIN_COOF = 0.03
local noiseMat = Material("vondaram/static_noise")

-- ============================================================
-- Render Targets
-- ============================================================
local RtTexture = GetRenderTargetEx(
    "SN_AnimcamTabletScreen",
    TEXTURE_SIZE_X, TEXTURE_SIZE_Y,
    RT_SIZE_NO_CHANGE,
    MATERIAL_RT_DEPTH_SEPARATE,
    bit.bor(2, 256, 512),
    0,
    IMAGE_FORMAT_BGRA8888
)

local RtView

local function createCamViewRT()
    RtView = GetRenderTargetEx(
        "SN_AnimcamRenderView_" .. CAMRES_W .. "_" .. CAMRES_H,
        CAMRES_W, CAMRES_H,
        RT_SIZE_NO_CHANGE,
        MATERIAL_RT_DEPTH_SEPARATE,
        bit.bor(2, 256, 512),
        0,
        IMAGE_FORMAT_BGRA8888
    )
end
createCamViewRT()

cvars.AddChangeCallback("sn_animcam_resolution", function(_, _, newVal)
    local newPOT = findClosestPOT(tonumber(newVal) or 1024)
    CAMRES_W = newPOT
    CAMRES_H = newPOT
    createCamViewRT()
end)

-- ============================================================
-- Пиксель-шейдер
-- ============================================================
local pixel_shader = {
    Materials = { RT = nil, Mat = nil },
    Wait      = 0,
}

local origW, origH = ScrW(), ScrH()
local coofX, coofY = 1, 1

local function calcRes(w, h)
    coofX = origW < w and 1 or origW / w
    coofY = origH < h and 1 or origH / h
end

pixel_shader.RebuildMaterials = function()
    if pixel_shader.Wait > SysTime() then return end
    local w, h = ScrW(), ScrH()

    calcRes(TEXTURE_SIZE_X, TEXTURE_SIZE_Y)

    pixel_shader.Materials.RT = GetRenderTarget(
        "sn_animcam_pixelation_rt", w, h,
        RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_SEPARATE, 1, 0, IMAGE_FORMAT_BGRA8888
    )
    pixel_shader.Materials.Mat = CreateMaterial("sn_animcam_pixelation_material", "UnlitGeneric", {
        ["$basetexture"] = pixel_shader.Materials.RT:GetName()
    })
    pixel_shader.Materials.Mat:SetInt("$flags",
        bit.bor(pixel_shader.Materials.Mat:GetInt("$flags"), 32768)
    )
    pixel_shader.Wait = SysTime() + 1
end

pixel_shader.Draw = function()
    local mat, rt = pixel_shader.Materials.Mat, pixel_shader.Materials.RT
    if not mat or not rt then return pixel_shader.RebuildMaterials() end

    local pixelLevel = CAMPIXEL_RATE:GetFloat()
    if pixelLevel <= 1 then return end

    local w, h = ScrW(), ScrH()
    render.CopyRenderTargetToTexture(render.GetScreenEffectTexture())

    local wDiv, hDiv = math.ceil(w / pixelLevel), math.ceil(h / pixelLevel)
    render.PushRenderTarget(pixel_shader.Materials.RT, 0, 0, wDiv, hDiv)
        render.DrawTextureToScreenRect(render.GetScreenEffectTexture(), 0, 0, wDiv, hDiv)
    render.PopRenderTarget()

    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(pixel_shader.Materials.Mat)

    local filter = TEXFILTER.LINEAR
    render.PushFilterMag(filter)
    render.PushFilterMin(filter)
        surface.DrawTexturedRect(0, 0,
            math.ceil(w * pixelLevel * coofX),
            math.ceil(h * pixelLevel * coofY)
        )
    render.PopFilterMag()
    render.PopFilterMin()
end

MODULE:Hook("OnScreenSizeChanged", "SN_AnimcamPixelSizeChanged", function(_, _, newW, newH)
    pixel_shader.Materials.Mat = nil
    pixel_shader.Materials.RT  = nil
    origW = newW
    origH = newH
    calcRes(TEXTURE_SIZE_X, TEXTURE_SIZE_Y)
end)

-- Цветовая коррекция
local cameraColorMod = {
    ["$pp_colour_addr"]       = 0,
    ["$pp_colour_addg"]       = 0,
    ["$pp_colour_addb"]       = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"]   = 1,
    ["$pp_colour_colour"]     = 0.25,
    ["$pp_colour_mulr"]       = 0,
    ["$pp_colour_mulg"]       = 0,
    ["$pp_colour_mulb"]       = 0,
}

-- Шрифт экрана (фиксированный размер рендер-таргета, без масштабирования)
SlashMoon.UI.RegisterRawFont("SlashMoon.AnimcamMain", { font = "Roboto", size = 33, extended = true })
-- Шрифт экрана (фиксированный размер рендер-таргета, без масштабирования)
SlashMoon.UI.RegisterRawFont("SlashMoon.AnimcamBatteryWarn", { font = "Roboto", size = 22, weight = 700 })

local function drawBattery(battery, w, h)
    if battery <= 0.10 then
        if math.sin(CurTime() * math.pi * 2) < 0 then return end
    end

    local bw      = w * 0.07
    local bh      = bw * 0.45
    local pimpleW = bw * 0.06
    local pimpleH = bh * 0.45
    local margin  = w * 0.018
    local thick   = math.max(1, math.floor(bh * 0.12))

    local bx = w - margin - bw - pimpleW - 30
    local by = h - margin - bh - 50

    local fillColor = battery > 0.25 and Color(100, 220, 100, 200) or (battery > 0.10 and Color(220, 180, 50, 200) or Color(220, 60, 60, 200))
    local fillColorText = battery > 0.25 and Color(0, 0, 0) or (battery > 0.10 and Color(0, 0, 0) or Color(104, 28, 28, 200))

    draw.NoTexture()
    surface.SetDrawColor(0, 0, 0, 120)
    surface.DrawRect(bx, by, bw, bh)

    local innerMargin = thick + 1
    local fillW       = math.max(0, math.floor((bw - innerMargin * 2) * battery))

    if fillW > 0 then
        surface.SetDrawColor(fillColor)
        surface.DrawRect(bx + innerMargin, by + innerMargin, fillW, bh - innerMargin * 2)
    end

    surface.SetDrawColor(170, 170, 170, 180)
    surface.DrawOutlinedRect(bx, by, bw, bh, thick)

    local px = bx + bw
    local py = by + (bh - pimpleH) * 0.5

    surface.SetDrawColor(0, 0, 0, 120)
    surface.DrawRect(px, py, pimpleW, pimpleH)

    surface.SetDrawColor(170, 170, 170, 180)
    surface.DrawOutlinedRect(px, py, pimpleW, pimpleH, thick)

    if battery then
        draw.SimpleText(math.floor(battery * 100) .. "%", "SlashMoon.AnimcamBatteryWarn", bx + bw * 0.5, by + bh - 28, fillColorText, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end

local function drawNoBattery(w, h)
    drawBattery(0, w, h)
    draw.SimpleText(SlashMoon.Tasks.Lang("sn.animcam.no_power"), "SlashMoon.AnimcamMain", w * 0.5, h * 0.5, Color(180, 60, 60, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function drawTablet(animIdx, animName, battery)
    local w, h = ScrW(), ScrH()

    render.DrawTextureToScreen(RtView)
    pixel_shader.Draw()
    DrawColorModify(cameraColorMod)

    surface.SetDrawColor(0, 0, 0, 1)
    surface.SetMaterial(noiseMat)
    surface.DrawTexturedRect(0, 0, w, h)

    draw.NoTexture()
    surface.SetDrawColor(17, 17, 17)
    surface.DrawOutlinedRect(0, 0, w, h, 2)

    surface.SetDrawColor(172, 172, 172, 2)
    surface.DrawOutlinedRect(w * CAMHUD_MARGIN_COOF, h * CAMHUD_MARGIN_COOF, w - 2 * (w * CAMHUD_MARGIN_COOF), h - 2 * (h * CAMHUD_MARGIN_COOF), 2)

    draw.SimpleText("CAM" .. animIdx, "SlashMoon.AnimcamMain", w * 0.955, h * 0.04, CAMFONT_COLOR, TEXT_ALIGN_RIGHT)

    if animName and animName ~= "" then
        draw.SimpleText(animName, "SlashMoon.AnimcamMain", w * 0.955, h * 0.085, CAMFONT_COLOR, TEXT_ALIGN_RIGHT)
    end

    drawBattery(battery, w, h)
end

-- ============================================================
-- Скрытие модели аниматроника и Pill Pack
-- ============================================================
local function collectAnimatronicEnts(animPly)
    local ents = {}
    if not IsValid(animPly) then return ents end

    ents[#ents + 1] = animPly

    -- Оружие игрока
    if animPly.GetWeapons then
        for _, wep in ipairs(animPly:GetWeapons()) do
            if IsValid(wep) then ents[#ents + 1] = wep end
        end
    end
    local activeWep = animPly:GetActiveWeapon()
    if IsValid(activeWep) then ents[#ents + 1] = activeWep end

    -- Поиск Pill Pack и всех его вложенных элементов
    local pill = animPly.GetPill and animPly:GetPill()
    if IsValid(pill) then
        ents[#ents + 1] = pill

        local function collectChildren(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if IsValid(child) then
                    ents[#ents + 1] = child
                    collectChildren(child) -- рекурсивный сбор вложенностей
                end
            end
        end
        collectChildren(pill)
    end

    return ents
end

local function hideEnts(ents)
    local saved = {}
    for _, ent in ipairs(ents) do
        if IsValid(ent) then
            saved[ent] = ent:GetNoDraw()
            ent:SetNoDraw(true) -- Абсолютный SetNoDraw
        end
    end
    return saved
end

local function restoreEnts(saved)
    for ent, wasNoDraw in pairs(saved) do
        if IsValid(ent) then
            ent:SetNoDraw(wasNoDraw)
        end
    end
end

-- Переменная-маркер для хуков отрисовки
local SN_RenderingAnimatronic = nil

-- ============================================================
-- Рендер вида аниматроника в RtView
-- ============================================================
local function renderAnimatronicView(animPly)
    if not IsValid(animPly) then return end

    local ents  = collectAnimatronicEnts(animPly)
    local saved = hideEnts(ents)

    SN_RenderingAnimatronic = animPly -- Включаем блокировку в хуках

    local viewData = {
        origin        = animPly:EyePos(),
        angles        = animPly:EyeAngles(),
        fov           = 90,
        drawviewer    = true,
        drawviewmodel = true,
        w             = CAMRES_W,
        h             = CAMRES_H,
        viewid        = VIEW_MONITOR,
    }

    render.PushRenderTarget(RtView)
        render.Clear(0, 0, 0, 255, true, true)
        render.RenderView(viewData)
    render.PopRenderTarget()

    restoreEnts(saved)
    SN_RenderingAnimatronic = nil -- Отключаем блокировку
end

-- Хуки жесткого подавления отрисовки игрока и его рук во время RenderView
MODULE:Hook("PrePlayerDraw", "SN_AnimcamHidePlayerGlobal", function(ply)
    if SN_RenderingAnimatronic == ply then
        return true -- Запрещаем движку рисовать этого игрока
    end
end)

MODULE:Hook("PreDrawPlayerHands", "SN_AnimcamHideHandsGlobal", function(hands, vm, ply, wep)
    if SN_RenderingAnimatronic == ply then
        return true -- Запрещаем рисовать руки
    end
end)

-- ============================================================
-- Состояние и Рендер
-- ============================================================
local update_tmr   = 0
local skipAmount   = 0
local forcedFrames = 0

local FRAMES_TO_SKIP  = 2
local FRAMES_TO_FORCE = 3

local function drawBlackScreen()
    render.ClearRenderTarget(RtTexture, BLACK_COLOR)
end

function SWEP:renderTexture(shouldRender)
    local screenOn = self:GetScreenOn()
    local battery  = self:GetBattery()

    if not screenOn or self:GetIsHolstering() then
        drawBlackScreen()

        if battery <= 0 then
            render.PushRenderTarget(RtTexture)
                cam.Start2D()
                    local w, h = ScrW(), ScrH()
                    drawNoBattery(w, h)
                cam.End2D()
            render.PopRenderTarget()
        end
        return
    end

    local list    = SlashMoon.Tasks.GetAnimatronics()
    local animIdx = self:GetCurAnim()

    if #list == 0 then
        drawBlackScreen()
        return
    end

    if animIdx > #list then animIdx = #list end
    if animIdx < 1      then animIdx = 1    end

    local animPly = list[animIdx]

    if shouldRender and IsValid(animPly) then
        renderAnimatronicView(animPly)
    end

    if skipAmount > 0 then
        skipAmount = math.max(skipAmount - 1, 0)
        return
    end

    local animName = IsValid(animPly) and animPly:Nick() or "???"

    render.PushRenderTarget(RtTexture)
        cam.Start2D()
            drawTablet(animIdx, animName, battery)
        cam.End2D()
    render.PopRenderTarget()
end

function SWEP:RenderScreen()
    local updateTime = math.Clamp(CAMUPDATE_TIME:GetFloat(), 0.05, 1)
    local isOnKD     = (CurTime() - update_tmr < updateTime) and forcedFrames <= 0

    if not isOnKD then
        if not self:GetIsHolstering() then
            update_tmr   = CurTime()
            forcedFrames = math.max(forcedFrames - 1, 0)
        end
    end

    self:renderTexture(not isOnKD)
    matScreen:SetTexture("$basetexture", RtTexture)
end

-- Сбросы задержек кадров
MODULE:Hook("SN_TabletDeployed", "SN_AnimcamDeployedDelay", function(wep)
    skipAmount   = FRAMES_TO_SKIP
    forcedFrames = FRAMES_TO_FORCE
end)

MODULE:Hook("SN_TabletCamSwitched", "SN_AnimcamSwitchedDelay", function(wep, oldVal, newVal)
    if LocalPlayer():GetActiveWeapon() ~= wep then return end
    if oldVal == newVal then return end
    skipAmount   = FRAMES_TO_SKIP
    forcedFrames = FRAMES_TO_FORCE
end)

MODULE:Hook("SN_TabletScreenToggled", "SN_AnimcamScreenToggleDelay", function(wep, state)
    if LocalPlayer():GetActiveWeapon() ~= wep then return end
    if state then
        skipAmount   = FRAMES_TO_SKIP
        forcedFrames = FRAMES_TO_FORCE
    end
end)
