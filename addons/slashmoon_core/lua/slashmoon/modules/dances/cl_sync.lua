-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("dances")

SlashMoon.Dances.CameraAngle = SlashMoon.Dances.CameraAngle or Angle(0, 0, 0)
SlashMoon.Dances.CameraDist = SlashMoon.Dances.CameraDist or 140
SlashMoon.Dances.DanceActive = SlashMoon.Dances.DanceActive or false

-- === ОПТИМИЗАЦИЯ #8 ===
-- Кэшируем ConVar чувствительности один раз,
-- вместо GetConVar("sensitivity") при каждом движении мыши в танце.
local cvSensitivity = GetConVar("sensitivity")

-- === ОПТИМИЗАЦИЯ #9 ===
-- Данные для TraceHull камеры создаются ОДИН раз и переиспользуются.
-- Раньше каждый кадр танца аллоцировались: таблица + 2 вектора + Vector(0,0,60).
local traceData = {
    mins = Vector(-10, -10, -10),
    maxs = Vector(10, 10, 10),
    mask = MASK_SOLID_BRUSHONLY,
}
local CAM_CENTER_OFFSET = Vector(0, 0, 60)

-- ==========================================
-- 1. УСТАНОВКА АНИМАЦИИ
-- ==========================================
MODULE:Hook("CalcMainActivity", "wOS_Dance_Looping_CL", function(ply, vel)
    local danceID = ply:GetNW2String("wOS_Dance_ID", "")
    if danceID == "" then return end

    local animData = SlashMoon.Dances.Animations[danceID]
    if not animData then return end

    if animData.mode == "actmod" then
        local movement = animData.movement
        local seqName = animData.seq
        if movement and movement.type == 3 and ply:GetVelocity():Length2DSqr() > 25 then
            seqName = movement.walk
        elseif movement and movement.static then
            seqName = movement.static
        end
        local seqID = ply:LookupSequence(seqName)
        if seqID and seqID >= 0 then
            ply:SetPlaybackRate(animData.rate or 1)
            return ACT_HL2MP_WALK, seqID
        end
        return
    end

    if not ply:IsOnGround() or ply:Crouching() or vel:Length2DSqr() > 1 then return end

    if animData.loop == false then return end

    local seqID = ply:LookupSequence(animData.seq)
    if seqID and seqID > 0 then
        local target = ply.wOS_SyncTarget
        if IsValid(target) and target:GetNW2String("wOS_Dance_ID", "") == danceID then
            ply:SetCycle(target:GetCycle())
        end
        return ACT_HL2MP_WALK, seqID
    end
end)

MODULE:Hook("UpdateAnimation", "wOS_Dance_SyncFrames", function(ply, vel, maxSeqGroundSpeed)
    -- === ОПТИМИЗАЦИЯ #10: одно чтение NW2 вместо двух ===
    local danceID = ply:GetNW2String("wOS_Dance_ID", "")
    if danceID == "" then return end

    local animData = SlashMoon.Dances.Animations[danceID]
    if animData and animData.mode == "actmod" then
        ply:SetPlaybackRate(animData.rate or 1)
        return true
    end
    if IsValid(ply.wOS_SyncTarget) then
        ply:SetPlaybackRate(0)
        ply:SetCycle(ply.wOS_SyncTarget:GetCycle())
    else
        ply:SetPlaybackRate(1)
    end
end)

-- ==========================================
-- 2. УПРАВЛЕНИЕ ТЕЛОМ (WASD)
-- ==========================================
MODULE:Hook("StartCommand", "wOS_Dance_Control_CL", function(ply, cmd)
    -- === ОПТИМИЗАЦИЯ #10: одно чтение NW2 вместо двух ===
    local danceID = ply:GetNW2String("wOS_Dance_ID", "")
    if danceID == "" then return end

    local animData = SlashMoon.Dances.Animations[danceID]
    local movement = animData and animData.movement
    if cmd:KeyDown(IN_JUMP) or cmd:KeyDown(IN_ATTACK2) then
        cmd:RemoveKey(IN_JUMP)
        cmd:RemoveKey(IN_ATTACK2)
        return
    end

    local ang = cmd:GetViewAngles()
    local speed = 1

    if cmd:KeyDown(IN_FORWARD) then ang.p = math.Clamp(ang.p - speed, -89, 89) end
    if cmd:KeyDown(IN_BACK) then ang.p = math.Clamp(ang.p + speed, -89, 89) end
    if cmd:KeyDown(IN_MOVELEFT) then ang.y = ang.y + speed end
    if cmd:KeyDown(IN_MOVERIGHT) then ang.y = ang.y - speed end

    cmd:SetViewAngles(ang)

    -- === ОПТИМИЗАЦИЯ #11 ===
    -- Условие "not movement or movement.type ~= 3" проверялось ДВАЖДЫ подряд.
    if not movement or movement.type ~= 3 then
        cmd:ClearMovement()
        cmd:RemoveKey(IN_FORWARD)
        cmd:RemoveKey(IN_BACK)
        cmd:RemoveKey(IN_MOVELEFT)
        cmd:RemoveKey(IN_MOVERIGHT)
    end
    cmd:RemoveKey(IN_DUCK)
end)

-- ==========================================
-- 3. ПЕРЕХВАТ МЫШИ (Вращение + Отдаление)
-- ==========================================
MODULE:Hook("InputMouseApply", "wOS_Dance_MouseOrbit", function(cmd, x, y, ang)
    local ply = LocalPlayer()
    if ply:GetNW2String("wOS_Dance_ID", "") == "" then return end

    local sens = cvSensitivity:GetFloat() * 0.012

    SlashMoon.Dances.CameraAngle.p = math.Clamp(SlashMoon.Dances.CameraAngle.p + y * sens, -89, 89)
    SlashMoon.Dances.CameraAngle.y = SlashMoon.Dances.CameraAngle.y - x * sens

    local wheel = cmd:GetMouseWheel()
    if wheel ~= 0 then
        SlashMoon.Dances.CameraDist = math.Clamp(SlashMoon.Dances.CameraDist - (wheel * 5), 40, 200)
    end

    return true
end)

-- ==========================================
-- 4. КАМЕРА ОТ 3-ГО ЛИЦА
-- ==========================================
MODULE:Hook("CalcView", "wOS_Dance_ThirdPerson", function(ply, pos, angles, fov)
    if ply:GetNW2String("wOS_Dance_ID", "") == "" then
        SlashMoon.Dances.DanceActive = false
        return
    end

    if not SlashMoon.Dances.DanceActive then
        SlashMoon.Dances.DanceActive = true
        SlashMoon.Dances.CameraAngle = angles * 1
        SlashMoon.Dances.CameraDist = 140
    end

    -- Переиспользуем таблицу трейса (см. ОПТИМИЗАЦИЯ #9)
    local center = ply:GetPos() + CAM_CENTER_OFFSET
    traceData.start = center
    traceData.endpos = center - (SlashMoon.Dances.CameraAngle:Forward() * SlashMoon.Dances.CameraDist)
    traceData.filter = ply

    local tr = util.TraceHull(traceData)

    return {
        origin = tr.HitPos,
        angles = SlashMoon.Dances.CameraAngle,
        fov = fov,
        drawviewer = true
    }
end)

-- ==========================================
-- 5. СКРЫТИЕ ПРИЦЕЛА И ОРУЖИЯ
-- ==========================================
MODULE:Hook("HUDShouldDraw", "wOS_Dance_HideCrosshair", function(name)
    if name == "CHudCrosshair" or name == "CHudWeaponSelection" then
        local ply = LocalPlayer()
        if IsValid(ply) and ply:GetNW2String("wOS_Dance_ID", "") ~= "" then
            return false
        end
    end
end)

MODULE:Hook("PlayerBindPress", "wOS_Dance_Binds", function(ply, bind, pressed)
    if ply:GetNW2String("wOS_Dance_ID", "") == "" then return end

    -- === ОПТИМИЗАЦИЯ #12 ===
    -- plain-режим string.find (4-й аргумент true): без компиляции Lua-паттерна.
    if string.find(bind, "+jump", 1, true) or string.find(bind, "+attack2", 1, true) then
        if pressed then
            net.Start("wOS_Dance_Stop_Request")
            net.SendToServer()
        end
        return true
    end
    if string.find(bind, "+attack", 1, true) then return true end
    if string.find(bind, "inv", 1, true) or string.find(bind, "slot", 1, true) then return true end
end)

MODULE:Hook("PlayerSwitchWeapon", "wOS_Dance_BlockWep_CL", function(ply, oldWep, newWep)
    if ply:GetNW2String("wOS_Dance_ID", "") ~= "" then return true end
end)
MODULE:Hook("PreDrawViewModel", "wOS_Dance_HideVM", function(vm, ply, wep)
    if ply:GetNW2String("wOS_Dance_ID", "") ~= "" then return true end
end)
MODULE:Hook("PreDrawPlayerHands", "wOS_Dance_HideHands", function(hands, vm, ply, wep)
    if ply:GetNW2String("wOS_Dance_ID", "") ~= "" then return true end
end)

-- ==========================================
-- 6. ФИКС ВИДИМОСТИ ПЕРСОНАЖА ДЛЯ SAM
-- ==========================================
MODULE:Hook("ShouldDrawLocalPlayer", "wOS_Dance_DrawPlayer", function(ply)
    if ply:GetNW2String("wOS_Dance_ID", "") ~= "" then
        return true
    end
end)
