-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("dances")

SlashMoon.Dances = SlashMoon.Dances or {}

-- === ОПТИМИЗАЦИЯ #13 + ЗАЩИТА ===
-- Антиспам net-запроса wOS_Dance_Play: раньше клиент мог флудить сервером
-- (выдача оружия, SelectWeapon, создание таймеров и LookupSequence на каждый пакет).
local PLAY_COOLDOWN = 0.3

-- ==========================================
-- УНИВЕРСАЛЬНАЯ ФУНКЦИЯ ОСТАНОВКИ ТАНЦА
-- ==========================================
function SlashMoon.Dances.StopDance(ply)
    if not IsValid(ply) then return end

    if ply:GetNW2String("wOS_Dance_ID", "") ~= "" then
        ply:SetNW2String("wOS_Dance_ID", "")
        ply:SetNW2Float("wOS_Dance_StartTime", 0)
        ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
        MODULE:RemoveTimer("wOS_Dance_AutoStop_" .. ply:EntIndex())
        MODULE:RemoveTimer("wOS_Dance_Loop_" .. ply:EntIndex())

        -- Возвращаем оружие, которое было до танца (если игрок жив)
        if ply:Alive() and ply.wOS_PreDanceWeapon then
            if ply:HasWeapon(ply.wOS_PreDanceWeapon) then
                ply:SelectWeapon(ply.wOS_PreDanceWeapon)
            end
            ply.wOS_PreDanceWeapon = nil
        end
    end
end

-- ==========================================
-- УНИВЕРСАЛЬНАЯ ФУНКЦИЯ ЗАПУСКА ТАНЦА
-- ==========================================
function SlashMoon.Dances.ForceDance(ply, animID)
    if not IsValid(ply) or not ply:Alive() or ply:InVehicle() then return end

    if ply:GetNW2String("wOS_Dance_ID", "") ~= "" then
        SlashMoon.Dances.StopDance(ply)
    end

    -- === ПРОВЕРКА НА НАБЛЮДАТЕЛЯ (SPECTATOR) ===
    if ply:Team() == TEAM_SPECTATOR or ply:GetObserverMode() ~= OBS_MODE_NONE then
        ply:ChatPrint("Наблюдатели не могут использовать эмоции!")
        return
    end

    -- Проверка на присяд
    if ply:Crouching() or ply:KeyDown(IN_DUCK) then
        ply:ChatPrint("Нельзя использовать эмоции в присяди")
        return
    end

    local animData = SlashMoon.Dances.Animations[animID]
    if not animData then return end

    if not SlashMoon.Dances.HasDance(ply, animID) then
        ply:ChatPrint("У вас нет доступа к этой анимации.")
        return
    end

    local catData = SlashMoon.Dances.Categories[animData.cat]
    local seqID = ply:LookupSequence(animData.seq)

    if not seqID or seqID <= 0 then
        SlashMoon.Debug("[Dances] У модели ", ply:GetModel(), " нет секвенции ", animData.seq)
        return
    end

    -- === ЛОГИКА СМЕНЫ ОРУЖИЯ НА ПУСТЫЕ РУКИ ===
    local activeWep = ply:GetActiveWeapon()
    if IsValid(activeWep) and activeWep:GetClass() ~= "sn_empty_hands" then
        -- Запоминаем текущее оружие, чтобы вернуть его после танца
        ply.wOS_PreDanceWeapon = activeWep:GetClass()
    end

    -- Выдаем пустые руки (если нет) и берем их в руки
    if not ply:HasWeapon("sn_empty_hands") then
        ply:Give("sn_empty_hands")
    end
    ply:SelectWeapon("sn_empty_hands")
    -- ===========================================

    ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)

    ply:SetNW2String("wOS_Dance_ID", animID)
    ply:SetNW2Float("wOS_Dance_StartTime", CurTime())

    if animData.mode == "actmod" then
        ply:ResetSequence(seqID)
        ply:SetCycle(animData.cycle or 0)
        ply:SetPlaybackRate(animData.rate or 1)
    elseif catData.type == "gesture" or animData.loop == false then
        ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, seqID, 0, true)
    else
        ply:SetCycle(0)
    end

    MODULE:RemoveTimer("wOS_Dance_AutoStop_" .. ply:EntIndex())
    MODULE:RemoveTimer("wOS_Dance_Loop_" .. ply:EntIndex())

    if animData.mode == "actmod" and animData.loop then
        local duration = animData.duration or ply:SequenceDuration(seqID)
        local repeatDuration = animData.repeatDuration or duration
        if duration > 0 and repeatDuration > 0 then
            local function resetAnimation()
                if not IsValid(ply) or ply:GetNW2String("wOS_Dance_ID", "") ~= animID then
                    MODULE:RemoveTimer("wOS_Dance_Loop_" .. ply:EntIndex())
                    return
                end
                ply:ResetSequence(seqID)
                ply:SetCycle(animData.repeatCycle or 0)
                ply:SetPlaybackRate(animData.rate or 1)
            end
            MODULE:Timer("wOS_Dance_Loop_" .. ply:EntIndex(), duration / (animData.rate or 1), 1, function()
                resetAnimation()
                if IsValid(ply) and ply:GetNW2String("wOS_Dance_ID", "") == animID then
                    MODULE:Timer("wOS_Dance_Loop_" .. ply:EntIndex(), repeatDuration / (animData.rate or 1), 0, resetAnimation)
                end
            end)
        end
    elseif animData.mode == "actmod" or catData.type == "gesture" or animData.loop == false then
        local duration = ply:SequenceDuration(seqID)
        duration = animData.duration or duration
        MODULE:Timer("wOS_Dance_AutoStop_" .. ply:EntIndex(), duration, 1, function()
            -- Используем новую функцию остановки
            SlashMoon.Dances.StopDance(ply)
        end)
    end
end

-- ==========================================
-- СЕТЕВЫЕ ЗАПРОСЫ
-- ==========================================
MODULE:Receive("wOS_Dance_Play", function(len, ply)
    -- Антиспам: не чаще одного запроса раз в 0.3 сек на игрока
    local now = CurTime()
    if (ply.wOS_NextDanceRequest or 0) > now then return end
    ply.wOS_NextDanceRequest = now + PLAY_COOLDOWN

    local animID = net.ReadString()
    SlashMoon.Dances.ForceDance(ply, animID)
end)

MODULE:Receive("wOS_Dance_Stop_Request", function(len, ply)
    SlashMoon.Dances.StopDance(ply)
end)

-- ==========================================
-- КОНСОЛЬНАЯ КОМАНДА ДЛЯ ТЕСТОВ
-- ==========================================
MODULE:Command("sn_force_dance", function(ply, cmd, args)
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_dances_force") then
        if IsValid(ply) then ply:ChatPrint("Недостаточно прав для этой команды!") end
        return
    end

    local targetName = args[1]
    local animID = args[2]

    if not targetName or not animID then return end

    local target = nil
    local lowerName = string.lower(targetName)
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), lowerName, 1, true) then
            target = p
            break
        end
    end

    if IsValid(target) then
        SlashMoon.Dances.ForceDance(target, animID)
    end
end)

-- ==========================================
-- ХУКИ
-- ==========================================
MODULE:Hook("PlayerSwitchWeapon", "wOS_Dance_BlockWep_SV", function(ply, oldWep, newWep)
    if ply:GetNW2String("wOS_Dance_ID", "") ~= "" then
        -- Разрешаем движку переключить оружие на пустые руки при старте танца
        if IsValid(newWep) and newWep:GetClass() == "sn_empty_hands" then
            return -- Ничего не возвращаем (разрешаем)
        end
        -- Остальные переключения оружия блокируем
        return true
    end
end)

MODULE:Hook("StartCommand", "wOS_Dance_Control_SV", function(ply, cmd)
    -- === ОПТИМИЗАЦИЯ #10: одно чтение NW2 вместо двух ===
    local danceID = ply:GetNW2String("wOS_Dance_ID", "")
    if danceID == "" then return end

    local animData = SlashMoon.Dances.Animations[danceID]
    local movement = animData and animData.movement
    local ang = cmd:GetViewAngles()
    local speed = 2

    if cmd:KeyDown(IN_FORWARD) then ang.p = math.Clamp(ang.p - speed, -89, 89) end
    if cmd:KeyDown(IN_BACK) then ang.p = math.Clamp(ang.p + speed, -89, 89) end
    if cmd:KeyDown(IN_MOVELEFT) then ang.y = ang.y + speed end
    if cmd:KeyDown(IN_MOVERIGHT) then ang.y = ang.y - speed end

    cmd:SetViewAngles(ang)

    -- === ОПТИМИЗАЦИЯ #11: условие проверяется один раз вместо двух ===
    if not movement or movement.type ~= 3 then
        cmd:ClearMovement()
        cmd:RemoveKey(IN_FORWARD)
        cmd:RemoveKey(IN_BACK)
        cmd:RemoveKey(IN_MOVELEFT)
        cmd:RemoveKey(IN_MOVERIGHT)
    end
    cmd:RemoveKey(IN_DUCK)
end)

MODULE:Hook("CalcMainActivity", "wOS_Dance_Looping", function(ply, vel)
    local danceID = ply:GetNW2String("wOS_Dance_ID", "")
    if danceID == "" then return end

    local animData = SlashMoon.Dances.Animations[danceID]
    if not animData then return end

    local catData = SlashMoon.Dances.Categories[animData.cat]
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

    if catData.type == "gesture" or animData.loop == false then return end

    local seqID = ply:LookupSequence(animData.seq)
    if seqID and seqID > 0 then
        return ACT_HL2MP_WALK, seqID
    end
end)

MODULE:Hook("PlayerDeath", "wOS_Dance_Death", function(ply)
    SlashMoon.Dances.StopDance(ply)
end)

-- === ОПТИМИЗАЦИЯ #14 ===
-- Мгновенная очистка при выходе игрока: таймеры и NW2-состояние
-- убираются сразу, а не при следующем срабатывании таймера.
MODULE:Hook("PlayerDisconnected", "wOS_Dance_Cleanup", function(ply)
    SlashMoon.Dances.StopDance(ply)
end)

MODULE:Hook("Move", "wOS_Dance_ActModMovement", function(ply, mv)
    local animData = SlashMoon.Dances.Animations[ply:GetNW2String("wOS_Dance_ID", "")]
    local movement = animData and animData.movement
    if not movement then return end

    if movement.type == 1 or movement.type == 2 then
        local direction = movement.type == 1 and 1 or -1
        mv:SetVelocity(ply:GetForward() * movement.speed * direction)
    end
end)
