-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("endo_copies")

local ANIM_FPS    = 24
local ANIM_FRAMES = 59
local ANIM_DUR    = ANIM_FRAMES / ANIM_FPS  -- ~2.46 сек


if not CLIENT then return end

-- =====================================================================
--  CONSTANTS
-- =====================================================================

local NET_HOVER = "endo_set_hovered"

-- ориг
local CLR_ORIG_NORMAL       = Color(200, 200, 50, 255)
local CLR_ORIG_HOVERED      = Color(255, 200, 0, 255)
local CLR_ORIG_NORMAL_FILL  = Color(200, 200, 50, 180)
local CLR_ORIG_HOVERED_FILL = Color(255, 200, 0, 180)
-- копия
local CLR_NORMAL       = Color(140, 140, 140, 255)
local CLR_HOVERED      = Color(220,  50,  50, 255)
local CLR_NORMAL_FILL  = Color(140, 140, 140, 180)
local CLR_HOVERED_FILL = Color(220,  50,  50, 180)

-- RMB-иконка способности: обычный цвет и цвет флэша при отказе в свитче
local CLR_ABILITY_NORMAL = Color(255, 255, 255)
local CLR_ABILITY_DENIED = Color(220, 40, 40)
local SWITCH_DENIED_FLASH_DUR   = 0.3   -- сколько держим красный флэш
local SWITCH_DENIED_SOUND       = "common/wpn_denyselect.wav"

local PILL_NAME = "pill_endo02"

-- Near-miss cylindrical hitbox (Pass 3 in hover detection)
local HITBOX_RADIUS_CLOSE = 40    -- units at point-blank
local HITBOX_RADIUS_FAR   = 80    -- units at long range
local HITBOX_SCALE_DIST   = 1000  -- distance for full radius scaling

-- Aim assist (CreateMove)
local ASSIST_CONE_DEG     = 15    -- cone half-angle for assist
local ASSIST_STRENGTH     = 0.025  -- max 15 % blend toward copy

-- Register the display name for the HUD button.
-- cl_hud.lua uses:  language.SafeGetPhrase("fazhunt.abilities." .. abilityName)
language.Add("fazhunt.abilities.endo_switch", "Переключение")

-- =====================================================================
--  HELPERS
-- =====================================================================

local function GetLocalPillName()
    local lp   = LocalPlayer()
    if not IsValid(lp) then return nil end
    local pill = lp:GetPill()
    if not IsValid(pill) then return nil end
    return pill:GetPillName()
end

-- Returns an array of endo_copy entities that belong to the local player
local function GetMyCopies()
    local lp = LocalPlayer()
    if not IsValid(lp) then return {} end

    local result = {}
    for _, ent in ipairs(ents.FindByClass("endo_copy")) do
                if IsValid(ent) and ent.GetOwnerPlayer and ent:GetOwnerPlayer() == lp then
            result[#result + 1] = ent
        end
    end
    return result
end

-- =====================================================================
--  OUTLINE RULE (uses halo_module OUTLINE system)
-- =====================================================================

local function RegisterEndoCopyOutlineRule()
    if not OUTLINE or not OUTLINE.RegisterRule then
        -- halo_module not loaded yet, will retry
        return false
    end

    OUTLINE.RegisterRule("endo_copies", {
        priority = 5,
        mode     = OUTLINE_MODE_BOTH,   -- visible through walls

        -- Outline: constant thickness, no distance fade
        outline_color    = CLR_NORMAL,
        outline_width    = 3,
        outline_min_dist = 0,
        outline_max_dist = 0,

        -- Fill = the "orb" silhouette that grows with distance.
        fill_color    = CLR_NORMAL_FILL,
        fill_min_dist = 0,
        fill_max_dist = 3000,

        collect = function(lp, rule)
            if not IsValid(lp) then return {} end
            if not lp:IsAnimatronic() then return {} end
            if GetLocalPillName() ~= PILL_NAME then return {} end

            local copies = GetMyCopies()
            if #copies == 0 then return {} end

            local result = {}
            for _, ent in ipairs(copies) do
                local hov = ent:GetIsHovered()
                local isOrig = ent.GetIsOriginal and ent:GetIsOriginal()

                result[#result + 1] = {
                    ent           = ent,
                    outline_color = hov and (isOrig and CLR_ORIG_HOVERED or CLR_HOVERED)
                                        or (isOrig and CLR_ORIG_NORMAL or CLR_NORMAL),
                    fill_color    = hov and (isOrig and CLR_ORIG_HOVERED_FILL or CLR_HOVERED_FILL)
                                        or (isOrig and CLR_ORIG_NORMAL_FILL or CLR_NORMAL_FILL),
                    mode          = OUTLINE_MODE_BOTH,
                    outline_width = isOrig and 4 or 3,
                    priority      = 5,
                }
            end

            return result
        end,
    })

    return true
end

-- Register after everything is in-game so halo_module is definitely loaded
MODULE:Hook("InitPostEntity", "endo_copies_cl_outlinesetup", function()
    timer.Simple(0, function()
        if not RegisterEndoCopyOutlineRule() then
            timer.Simple(1, RegisterEndoCopyOutlineRule)
        end
    end)
end)

-- =====================================================================
--  ORBS для самого пилл-игрока — те же индикаторы по краю экрана,
--  что и у маньяка через draw_orbs, только видит их сам владелец копий.
-- =====================================================================

MODULE:Hook("HUDPaint", "endo_copies_orbs", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if not lp:IsAnimatronic() then return end
    if GetLocalPillName() ~= PILL_NAME then return end

    local copies = GetMyCopies()
    if #copies == 0 then return end

    local orbData = {}
    for _, ent in ipairs(copies) do
        if not IsValid(ent) then continue end

        local hov    = ent:GetIsHovered()
        local isOrig = ent.GetIsOriginal and ent:GetIsOriginal()

        orbData[ent] = hov and (isOrig and CLR_ORIG_HOVERED or CLR_HOVERED)
                           or (isOrig and CLR_ORIG_NORMAL or CLR_NORMAL)
    end

    if isfunction(draw_orbs) then
        draw_orbs(orbData)
    end
end)

-- =====================================================================
--  SPOTTED SURVIVORS — приём нет-сообщения от sv_endo_vision.lua
--  + OUTLINE-подсветка сквозь стены + орбы по краю экрана.
--  Орбы/контур — того же цвета, что у копий (CLR_HOVERED / CLR_HOVERED_FILL),
--  чтобы визуально "пойманный выживший" читался как одна семья индикаторов.
-- =====================================================================

-- [Player] = CurTime() + hold. Клиент сам снимает подсветку по истечении,
-- сервер в этом тике может ничего не прислать (если выживший вышел из конуса).
local spottedExpire = {}

MODULE:Receive("endo_copy_spotted", function()
    local list = net.ReadTable()
    local hold = net.ReadFloat()
    local exp  = CurTime() + hold
    for _, ply in ipairs(list) do
        if IsValid(ply) then spottedExpire[ply] = exp end
    end
end)

-- Сбрасываем истёкших/умерших/ушедших — иначе орбы будут висеть вечно.
MODULE:Hook("Think", "endo_spotted_cleanup", function()
    local now = CurTime()
    for ply, exp in pairs(spottedExpire) do
        if not IsValid(ply) or now > exp or not ply:Alive() then
            spottedExpire[ply] = nil
        end
    end
end)

local function RegisterSpottedRule()
    if not OUTLINE or not OUTLINE.RegisterRule then
        -- halo_module не загружен — повторим через секунду
        return false
    end

    OUTLINE.RegisterRule("endo_spotted_survivors", {
        priority = 10,                       -- выше, чем у копий (5), чтобы перекрывать
        mode     = OUTLINE_MODE_BOTH,        -- видно сквозь стены

        outline_color    = CLR_HOVERED,      -- тот же красный, что у hovered-копии
        outline_width    = 2,
        outline_min_dist = 0,
        outline_max_dist = 0,                -- без затухания по дистанции

        fill_color       = CLR_HOVERED_FILL,
        fill_min_dist    = 0,
        fill_max_dist    = 4000,

        collect = function(lp, rule)
            if not IsValid(lp) then return {} end
            if not lp:IsAnimatronic() then return {} end
            if GetLocalPillName() ~= PILL_NAME then return {} end

            local now  = CurTime()
            local out  = {}
            for ply, exp in pairs(spottedExpire) do
                if IsValid(ply) and now <= exp and ply:Alive() then
                    out[#out + 1] = {
                        ent           = ply,
                        outline_color = CLR_HOVERED,
                        fill_color    = CLR_HOVERED_FILL,
                        mode          = OUTLINE_MODE_BOTH,
                        outline_width = 4,
                        priority      = 10,
                    }
                end
            end
            return out
        end,
    })

    return true
end

MODULE:Hook("InitPostEntity", "endo_spotted_outline_setup", function()
    timer.Simple(0, function()
        if not RegisterSpottedRule() then
            timer.Simple(1, RegisterSpottedRule)
        end
    end)
end)

-- Орбы просвеченных выживших — отдельный вызов draw_orbs, чтобы не
-- смешивать в одной таблице с орбами копий (draw_orbs может дедупить
-- по ent, а копия и выживший — разные сущности, тут это и не нужно,
-- но логически два семейства индикаторов лучше держать раздельно).
MODULE:Hook("HUDPaint", "endo_spotted_orbs", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if not lp:IsAnimatronic() then return end
    if GetLocalPillName() ~= PILL_NAME then return end

    local now = CurTime()
    local orbData = {}
    for ply, exp in pairs(spottedExpire) do
        if IsValid(ply) and now <= exp and ply:Alive() then
            orbData[ply] = CLR_HOVERED
        end
    end

    if next(orbData) ~= nil and isfunction(draw_orbs) then
        draw_orbs(orbData)
    end
end)

-- =====================================================================
--  HOVER DETECTION
-- =====================================================================

local HOVER_RATE_SEC  = 0.05
local HOVER_ANGLE_DEG = 4.5

local lastSentHover  = NULL
local lastHoverCheck = 0
local lastPlayerPos  = Vector(0, 0, 0)

MODULE:Hook("Think", "endo_copies_hover_detect", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local pos = lp:GetPos()
    if isvector(pos) and isvector(lastPlayerPos) and pos:DistToSqr(lastPlayerPos) > 40000 then
        lastSentHover = NULL
    end
    if isvector(pos) then lastPlayerPos = pos end

    if GetLocalPillName() ~= PILL_NAME then
        if IsValid(lastSentHover) then
            net.Start(NET_HOVER)
            net.WriteEntity(NULL)
            net.SendToServer()
            lastSentHover = NULL
        end
        return
    end

    local now = CurTime()
    if now - lastHoverCheck < HOVER_RATE_SEC then return end
    lastHoverCheck = now

    local eyePos = lp:EyePos()
    local eyeFwd = lp:EyeAngles():Forward()
    local copies = GetMyCopies()

    local hoveredCopy = NULL

    -- Pass 1: TraceLine (close / line-of-sight)
    local tr = util.TraceLine({
        start  = eyePos,
        endpos = eyePos + eyeFwd * 16384,
        filter = lp,
        mask   = MASK_ALL,
    })

    if IsValid(tr.Entity)
    and tr.Entity:GetClass() == "endo_copy"
    and tr.Entity.GetOwnerPlayer
    and tr.Entity:GetOwnerPlayer() == lp then
        hoveredCopy = tr.Entity
    end

    -- Pass 2: Angular proximity (far / through-wall orbs)
    if not IsValid(hoveredCopy) then
        local bestAngle = HOVER_ANGLE_DEG

        for _, ent in ipairs(copies) do
            local toEnt    = (ent:GetPos() + Vector(0, 0, 43) - eyePos):GetNormalized()
            local dot      = math.Clamp(eyeFwd:Dot(toEnt), -1, 1)
            local angleDeg = math.deg(math.acos(dot))

            if angleDeg < bestAngle then
                bestAngle  = angleDeg
                hoveredCopy = ent
            end
        end
    end

    -- Pass 3: Cylindrical near-miss hitbox
    -- Projects each copy center onto the view line and checks
    -- perpendicular distance — wider invisible hitbox.
    if not IsValid(hoveredCopy) then
        local bestPerpDist = 999999
        for _, ent in ipairs(copies) do
            local center   = ent:GetPos() + Vector(0, 0, 43)
            if not isvector(center) then continue end
            local toCenter = center - eyePos
            local proj     = eyeFwd:Dot(toCenter)
            if proj < 0 then continue end  -- behind player

            local closest  = eyePos + eyeFwd * proj
            local perpDist = closest:Distance(center)
            local dist     = eyePos:Distance(center)
            local radius   = Lerp(
                math.Clamp(dist / HITBOX_SCALE_DIST, 0, 1),
                HITBOX_RADIUS_CLOSE,
                HITBOX_RADIUS_FAR
            )

            if perpDist < radius and perpDist < bestPerpDist then
                bestPerpDist = perpDist
                hoveredCopy  = ent
            end
        end
    end

    if hoveredCopy ~= lastSentHover then
        net.Start(NET_HOVER)
        net.WriteEntity(hoveredCopy)
        net.SendToServer()
        lastSentHover = hoveredCopy
    end
end)

-- =====================================================================
--  FOV LERP — narrows while charging teleport
--  Two-layer approach for reliability:
--    1) SetFOV() — sets the player's base FOV (first-person)
--    2) CalcView with low priority — overrides view.fov directly,
--       runs AFTER nocompat.lua's CalcView, so it works in third
--       person too. GMod merges partial CalcView return tables.
-- =====================================================================

local CHARGE_TIME_CL   = 1.0    -- must match server CHARGE_TIME
local CHARGE_FOV_MIN   = 25     -- target FOV at full charge
local smoothEndoFov    = nil    -- current lerped FOV (nil = not active)

MODULE:Hook("Think", "endo_switch_fov_think", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local baseFov = lp:GetInfoNum("fov_desired", 90)

    if GetLocalPillName() ~= PILL_NAME then
        if smoothEndoFov then
            smoothEndoFov = nil
            lp:SetFOV(baseFov, 0.1)
        end
        return
    end

    local chargeStart = lp:GetNW2Float("endo_charge_start", 0)

    if chargeStart > 0 then
        local elapsed  = CurTime() - chargeStart
        local progress = math.Clamp(elapsed / CHARGE_TIME_CL, 0, 1)
        progress = 1 - (1 - progress) * (1 - progress)  -- ease-out

        smoothEndoFov = Lerp(progress, baseFov, CHARGE_FOV_MIN)
    else
        -- Smoothly return to normal after charge ends
        if smoothEndoFov then
            smoothEndoFov = Lerp(FrameTime() * 6, smoothEndoFov, baseFov)
            if math.abs(smoothEndoFov - baseFov) < 0.5 then
                smoothEndoFov = nil
                lp:SetFOV(baseFov, 0.1)
            end
        end
    end

    -- SetFOV as primary method (first-person and CalcView fov param)
    if smoothEndoFov then
        lp:SetFOV(smoothEndoFov, 0.05)
    end
end)

-- CalcView with low priority: runs AFTER nocompat.lua's CalcView (priority 0).
-- Returning only {fov=X} merges with the previous hook's view data,
-- so third-person camera (origin/angles/drawviewer) is preserved.
MODULE:Hook("CalcView", "endo_switch_fov_calcview", function(ply, pos, ang, fov, nearZ, farZ)
    if not smoothEndoFov then return end
    if GetLocalPillName() ~= PILL_NAME then return end
    return { fov = smoothEndoFov }
end, -1)

-- =====================================================================
--  AIM ASSIST — subtly pulls crosshair toward nearest copy
--  CreateMove runs before the engine applies mouse delta, so the
--  player's mouse input is added ON TOP of our adjustment.
--  Max 15 % blend — easily overpowered by intentional mouse movement.
-- =====================================================================

MODULE:Hook("CreateMove", "endo_aim_assist", function(cmd)
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if GetLocalPillName() ~= PILL_NAME then return end

    -- Только при активном заряде (зажат RMB)
    local chargeStart = lp:GetNW2Float("endo_charge_start", 0)
    if chargeStart <= 0 then return end

    local copies = GetMyCopies()
    if #copies == 0 then return end

    local eyePos = lp:EyePos()
    local eyeAng = cmd:GetViewAngles()
    local eyeFwd = eyeAng:Forward()

    local bestCopy  = nil
    local bestAngle = ASSIST_CONE_DEG

    for _, ent in ipairs(copies) do
        local center = ent:GetPos() + Vector(0, 0, 43)
        if not isvector(center) then continue end
        local toEnt    = (center - eyePos):GetNormalized()
        local dot      = math.Clamp(eyeFwd:Dot(toEnt), -1, 1)
        local angleDeg = math.deg(math.acos(dot))

        if angleDeg < bestAngle then
            bestAngle = angleDeg
            bestCopy  = ent
        end
    end

    if not IsValid(bestCopy) then return end

    local center    = bestCopy:GetPos() + Vector(0, 0, 43)
    local targetAng = (center - eyePos):Angle()
    local strength  = (1 - bestAngle / ASSIST_CONE_DEG) * ASSIST_STRENGTH
    local newAng    = LerpAngle(strength, eyeAng, targetAng)

    cmd:SetViewAngles(newAng)
end)

-- =====================================================================
--  HUD — "endo_switch" ability slot
-- =====================================================================
--
--  ABILITY_KEY must be "endo_switch" and MUST match the server side!
--  The server sends cooldown via:  cooldown.Send(ply, "endo_switch")
--  If you change this key, the cooldown timer will stop working.
--  To change the display name, edit the language.Add() call above.
--
--  NOTE: Button order depends on cl_hud.lua's pairs() which has no
--  guaranteed order. Without modifying cl_hud.lua we cannot control
--  the position. The "order" field is set for future compatibility.
--
-- =====================================================================

local ABILITY_KEY = "endo_switch"
local GRAB_KEY    = "grab"
local abilitySyncTimer = 0

local function SyncEndoSwitchAbility()
    if not currentAbilities then return end

    if GetLocalPillName() == PILL_NAME then
        -- Remove the default "grab" ability so ours replaces it
        currentAbilities[GRAB_KEY] = nil

        -- Add the slot if it doesn't exist yet
        if not currentAbilities[ABILITY_KEY] then
            currentAbilities[ABILITY_KEY] = {
                maxTime = 7,
                endTime = 0,
                hidden  = false,
                color   = CLR_ABILITY_NORMAL,
                text    = "RMB",
                order   = 100,
            }
        end
    else
        currentAbilities[ABILITY_KEY] = nil
    end
end

-- Sync ability slot at ~2 Hz
MODULE:Hook("Think", "endo_switch_ability_sync", function()
    local now = CurTime()
    if now - abilitySyncTimer < 0.5 then return end
    abilitySyncTimer = now
    SyncEndoSwitchAbility()
end)

-- Update the cooldown timer when the server confirms an endo_switch use
MODULE:Hook("FH_CooldownReceive", "endo_switch_cooldown_hud", function(name, duration)
    if name ~= ABILITY_KEY then return end
    if not currentAbilities then return end

    if not currentAbilities[ABILITY_KEY] then
        SyncEndoSwitchAbility()
    end

    local slot = currentAbilities[ABILITY_KEY]
    if not slot then return end

    slot.endTime = CurTime() + duration
    slot.maxTime = duration
end)

-- =====================================================================
--  SWITCH DENIED FEEDBACK — сервер шлёт это вместо чат-сообщения, когда
--  свитч невозможен (Эндо/копия в дверном проёме, на лифте, слишком
--  близко к другой копии и т.п.). Вместо текста в чат — красный флэш
--  на иконке RMB-способности на HUD + звук отказа.
-- =====================================================================

local switchDeniedFlashUntil = 0

MODULE:Receive("endo_switch_denied", function()
    switchDeniedFlashUntil = CurTime() + SWITCH_DENIED_FLASH_DUR
    surface.PlaySound(SWITCH_DENIED_SOUND)
end)

-- Каждый кадр подкрашиваем/возвращаем цвет иконки способности — flash
-- живёт тут, а не в SyncEndoSwitchAbility (та трогает color только при
-- создании слота и синкается всего 2 раза в секунду, слишком редко
-- для плавного флэша).
MODULE:Hook("Think", "endo_switch_deny_flash", function()
    if not currentAbilities then return end
    local slot = currentAbilities[ABILITY_KEY]
    if not slot then return end

    slot.color = (CurTime() < switchDeniedFlashUntil)
        and CLR_ABILITY_DENIED
        or CLR_ABILITY_NORMAL
end)

local forceDuckUntil = 0

MODULE:Receive("endo_force_duck", function()
    forceDuckUntil = CurTime() + 1.5
end)

MODULE:Hook("CreateMove", "endo_force_duck", function(cmd)
    if CurTime() < forceDuckUntil then
        cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_DUCK))
    end
end)

local BAR_WIDTH     = 200
local BAR_HEIGHT    = 4
local BAR_Y_OFFSET  = 18
local BAR_COLOR     = Color(255, 255, 255)
local BAR_BG_COLOR  = Color(0, 0, 0, 180)
--  линия под курсором, можно удолить
MODULE:Hook("HUDPaint", "endo_charge_bar", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if GetLocalPillName() ~= PILL_NAME then return end

    local chargeStart = lp:GetNW2Float("endo_charge_start", 0)
    if chargeStart <= 0 then return end

    local progress = math.Clamp((CurTime() - chargeStart) / CHARGE_TIME_CL, 0, 1)

    local cx = ScrW() / 2
    local cy = ScrH() / 2 + BAR_Y_OFFSET
    local bx = cx - BAR_WIDTH / 2
    local by = cy - BAR_HEIGHT / 2

    draw.RoundedBox(BAR_HEIGHT / 2, bx, by, BAR_WIDTH, BAR_HEIGHT, BAR_BG_COLOR)

    if progress > 0 then
        draw.RoundedBox(BAR_HEIGHT / 2, bx, by, BAR_WIDTH * progress, BAR_HEIGHT, BAR_COLOR)
    end
end)

-- ═══════════════════════════════════════════════════════════════════
--  ТЕРМИНАЛ ЗАГРУЗКИ — чёрный экран + печатающийся текст + скан-линии
--  + периодические глитч-импульсы (RGB-шифт, разрывы строк, дрожание,
--  "уехавшая развёртка"). Полностью на surface/draw, никакой VTF —
--  так что никакого шакального сжатия видео-текстуры.
-- ═══════════════════════════════════════════════════════════════════

local switchOverlayEnd   = 0.25
local switchOverlayFade  = 0.12
local switchOverlayStart = 0

-- Шрифт экрана (фиксированный размер рендер-таргета, без масштабирования)
SlashMoon.UI.RegisterRawFont("SlashMoon.EndoTerminal", {
    font      = "Courier New",
    size      = 24,
    weight    = 650,
    antialias = false,
})

-- Строки загрузочного лога — ПОДСТАВНЫЕ под твой скриншот, меняй текст/
-- порядок/теги как угодно, логика отрисовки от содержимого не зависит.
local BOOT_LINES = {
    { tag = "OK",     text = "Initializing Fazbear UNIX 1987.2..." },
    { tag = "OK",     text = "Detecting CPU: endo_Ver_02_CORE" },
    { tag = "OK",     text = "Mounting /sys/firmware/endo_joints..." },
    { tag = "OK",     text = "Initializing BUS Core Subsystem..." },
    { tag = "DEPEND", text = "Dependency failed for Facial_Recognition.service" },
    { tag = "OK",     text = "Searching file: safety_protocols_81-91y.so" },
    { tag = "OK",     text = "Activating jaw_servo. ready for operation..." },
    { tag = "FAILED", text = "Failed to running safety_protocols_81-91y.ASCII" },
    { tag = "WARN",   text = "ERROR Security protocols failed to launch; disconnect the system from the power supply!" },
    { tag = "OK",     text = "Audio drivers detected: Endo_Sound_div.bin" },
    { tag = "OK",     text = "Freeing unused kernel memory: 1300K" },
    { tag = "OK",     text = "Starting Udev Coldplug Plug Devices..." },
    { tag = "OK",     text = "initializing ENDO_AI_matrix... [BSS]" },
}

local TAG_LABEL = {
    OK     = "  OK  ",
    WARN   = " WARN ",
    FAILED = "FAILED",
    DEPEND = "DEPEND",
}

local TAG_COLOR = {
    OK     = Color(80, 230, 140),
    WARN   = Color(255, 60, 60),
    FAILED = Color(255, 60, 60),
    DEPEND = Color(180, 180, 190),
}

local LINE_HEIGHT   = 32
local LINE_REVEAL   = 0.09   -- сек на появление одной новой строки
local TEXT_MARGIN_X = 50
local TEXT_MARGIN_Y = 70

MODULE:Receive("endo_start_switch", function()
    switchOverlayFade = net.ReadFloat()
    switchOverlayStart = CurTime()
    switchOverlayEnd = switchOverlayStart + ANIM_DUR

    MODULE:Unhook("HUDPaint", "DrawKillerInterface")

    MODULE:Timer("endo_switch_hud_restore", ANIM_DUR, 1, function()
        if isfunction(DrawKillerInterface) then
            MODULE:Hook("HUDPaint", "DrawKillerInterface", DrawKillerInterface)
        end
    end)
end)

-- ── Глитч-импульсы: короткие (0.04-0.12с) вспышки искажения, с паузой
-- 0.4-0.9с между ними. Один таймер состояния на весь оверлей.
local nextGlitchTime = 0
local glitchUntil    = 0

local function InGlitchPulse(now)
    if now >= nextGlitchTime and now >= glitchUntil then
        glitchUntil    = now + math.Rand(0.2, 0.10)
        nextGlitchTime = now + math.Rand(0.1, 0.2)
    end
    return now < glitchUntil
end

local function DrawTerminalText(elapsed, jitterX, jitterY, rgbSplit, overlayAlpha)
    local visibleLines = math.min(math.floor(elapsed / LINE_REVEAL), #BOOT_LINES)
    local a = overlayAlpha / 255

    for i = 1, visibleLines do
        local line   = BOOT_LINES[i]
        local color  = TAG_COLOR[line.tag] or color_white
        local prefix = "[" .. (TAG_LABEL[line.tag] or line.tag) .. "] "
        local txt    = prefix .. line.text

        local x = TEXT_MARGIN_X + jitterX
        local y = TEXT_MARGIN_Y + (i - 1) * LINE_HEIGHT + jitterY

        -- RGB-шифт (хроматическая аберрация) во время глитч-импульса —
        -- две смещённые копии текста в красном/голубом под основной.
        if rgbSplit then
            draw.SimpleText(txt, "SlashMoon.EndoTerminal", x - 2, y, Color(255, 0, 0, 140 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(txt, "SlashMoon.EndoTerminal", x + 2, y, Color(0, 255, 255, 140 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        draw.SimpleText(txt, "SlashMoon.EndoTerminal", x, y,
            Color(color.r, color.g, color.b, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- Мигающий курсор после последней строки
    if visibleLines == #BOOT_LINES and math.floor(elapsed * 2) % 2 == 0 then
        local y = TEXT_MARGIN_Y + visibleLines * LINE_HEIGHT
        draw.SimpleText("_", "SlashMoon.EndoTerminal", TEXT_MARGIN_X + jitterX, y + jitterY,
            Color(200, 255, 200, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

MODULE:Hook("HUDPaint", "endo_switch_overlay", function()
    if CurTime() >= switchOverlayEnd then return end

    local now     = CurTime()
    local fade    = switchOverlayFade
    local start   = switchOverlayStart
    local elapsed = now - start

    local alpha = 255
    if now < start + fade then
        alpha = 255 * math.Clamp(elapsed / fade, 0, 1)
    elseif now > switchOverlayEnd - fade then
        alpha = 255 * math.Clamp((switchOverlayEnd - now) / fade, 0, 1)
    end
    alpha = math.Round(alpha)

    local w, h = ScrW(), ScrH()
    local glitching = InGlitchPulse(now)

    -- Чёрный фон
    surface.SetDrawColor(0, 0, 0, 200 * (alpha / (255 * 0.3)))
    surface.DrawRect(0, 0, w, h)

    -- Дрожание всего текста во время глитч-импульса ("уехавший" кадр)
    local jitterX, jitterY = 0, 0
    if glitching then
        jitterX = math.random(-0.01, 0.125)
        jitterY = math.random(-0.02, 0.225)
    end

    DrawTerminalText(elapsed, jitterX, jitterY, glitching, alpha)

    surface.SetDrawColor(0, 0, 0, 60 * (alpha / 255))
    for y = 0, h, 4 do
        surface.DrawRect(0, y, w, 1)
    end

    if glitching then
        local bars = math.random(2, 5)
        for i = 1, bars do
            local y    = math.random(0, h)
            local barH = math.random(0.2, 1)
            local xOff = math.random(-50, 50)
            surface.SetDrawColor(math.random(245, 255), math.random(240, 255), math.random(230, 255), math.random(80, 150))
            surface.DrawRect(xOff, y, w, barH)
        end

        local stretchY = math.random(0, math.max(h - 50, 0))
        local stretchH = math.random(6, 18)
        surface.SetDrawColor(158, 158, 158, 200)
        for i = 0, 3 do
            surface.DrawRect(0, stretchY + i * (stretchH / 3), w, stretchH / 3)
        end
    end
end)

MODULE:Hook("OnReloaded", "endo_switch_hud_restore_safety", function()
    if isfunction(DrawKillerInterface) then
        MODULE:Hook("HUDPaint", "DrawKillerInterface", DrawKillerInterface)
    end
end)


local COPY_SCARE_RADIUS = 250
local COPY_SCARE_SPRINT_RADIUS = 1200
local COPY_SCARE_FOV = 60
local COPY_SCARE_CD = 10
local wasLookingAtCopy = false
local lastCopyScare = 0

MODULE:Hook("Think", "endo_copy_scare_sound", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:IsAnimatronic() then return end
    if not lp:Alive() or lp:Team() == TEAM_SPECTATOR then return end

    local radius = COPY_SCARE_RADIUS
    if lp:IsSprinting() and lp:GetVelocity():LengthSqr() >= lp:GetRunSpeed() then
        radius = COPY_SCARE_SPRINT_RADIUS
    end

    local lookingAtCopy = false

    for _, copy in ipairs(ents.FindByClass("endo_copy")) do
        if not IsValid(copy) then continue end

        local center = copy:GetPos() + Vector(0, 0, 43)
        local toCopy = center - lp:EyePos()
        local dist = toCopy:Length()

        if dist > radius then continue end

        local dot = lp:EyeAngles():Forward():Dot(toCopy:GetNormalized())
        local angle = math.deg(math.acos(math.Clamp(dot, -1, 1)))

        if angle > COPY_SCARE_FOV then continue end

        local tr = util.TraceLine({
            start = lp:EyePos(),
            endpos = center,
            filter = {lp, copy},
            mask = MASK_BLOCKLOS_AND_NPCS,
        })

        if tr.Hit then continue end

        lookingAtCopy = true
        break
    end

    local now = CurTime()
    if lookingAtCopy and not wasLookingAtCopy and now - lastCopyScare >= COPY_SCARE_CD then
        surface.PlaySound("animatron_seen.wav")
        lastCopyScare = now
    end

    wasLookingAtCopy = lookingAtCopy
end)


--шум тест

-- local NOISE_MAX_DIST = 400

-- MODULE:Hook("RenderScreenspaceEffects", "endo_proximity_noise", function()
--     local lp = LocalPlayer()
--     if not IsValid(lp) then return end
--     if GetLocalPillName() ~= PILL_NAME then return end

--     local copies = GetMyCopies()
--     if #copies == 0 then return end

--     local minDist = math.huge
--     for _, copy in ipairs(copies) do
--         if not IsValid(copy) then continue end
--         local d = lp:GetPos():DistToSqr(copy:GetPos())
--         if d < minDist then minDist = d end
--     end

--     minDist = math.sqrt(minDist)
--     if minDist >= NOISE_MAX_DIST then return end

--     local t = 1 - minDist / NOISE_MAX_DIST  -- 0 (далеко) → 1 (вплотную)

--     -- Мерцание яркости и контраста
--     local tab = {}
--     tab["$pp_colour_addr"] = 0
--     tab["$pp_colour_addg"] = 0
--     tab["$pp_colour_addb"] = 0
--     tab["$pp_colour_brightness"] = math.Rand(-0.05, 0.05) * t
--     tab["$pp_colour_contrast"]   = 1 + math.Rand(-0.2, 0.2) * t
--     tab["$pp_colour_colour"]     = 1
--     tab["$pp_colour_mulr"] = 0
--     tab["$pp_colour_mulg"] = 0
--     tab["$pp_colour_mulb"] = 0
--     DrawColorModify(tab)

--     -- Горизонтальные артефакт-линии (статический шум)
--     local lineCount = math.floor(t * 30)
--     surface.SetDrawColor(255, 255, 255, math.floor(t * 60))
--     for _ = 1, lineCount do
--         local y = math.random(0, ScrH())
--         local h = math.random(1, 3)
--         surface.DrawRect(0, y, ScrW(), h)
--     end
-- end)
