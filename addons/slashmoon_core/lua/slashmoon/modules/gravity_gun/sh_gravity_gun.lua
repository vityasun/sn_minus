-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("gravity_gun")


-- =========== КОНФИГУРАЦИЯ ===========
local MAX_CHARGE = 100
local CHARGE_DRAIN = 10
local MIN_CHARGE_TO_GRAB = 10
local HOLD_TIME_LIMIT = 12
local GRAB_DISTANCE = 500

-- =========== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===========
-- Кто кого держит: [держатель] = жертва, [жертва] = держатель
MODULE.Holders = MODULE.Holders or {}
MODULE.Victims = MODULE.Victims or {}

-- =========== ПРОВЕРКА АНИМАТРОНИКОВ (ИСПРАВЛЕНО) ===========
-- Используем метод Player:IsAnimatronic() вместо глобальной функции
local function IsAnimatronic(entity)
    if not IsValid(entity) then return false end
    
    -- 1. Если entity - игрок, используем встроенный метод
    if entity:IsPlayer() then
        return entity:IsAnimatronic(), entity, entity:IsAnimatronic() and "player_animatronic" or nil
    end
    
    -- 2. Проверка через PILL Core
    if entity.GetPillName then
        local pillName = entity:GetPillName()
        if pillName and isstring(pillName) then
            return true, entity, pillName
        end
    end
    
    -- 3. Проверка по классу
    if entity:GetClass() == "pill_costume" then
        return true, entity, "unknown"
    end
    
    return false
end

-- =========== ПРОВЕРКА МОЖНО ЛИ ЗАХВАТИТЬ АНИМАТРОНИКА ===========
local function CanGrabAnimatronic(animEnt, grabberPlayer)
    if not IsValid(animEnt) then return false, "Недействительная сущность" end
    if not IsValid(grabberPlayer) then return false, "Недействительный захватчик" end
    
    -- Получаем тип аниматроника
    local isAnim, ent, pillName = IsAnimatronic(animEnt)
    if not isAnim then return false, "Не аниматроник" end
    
    -- Определяем игрока-владельца аниматроника
    local targetPlayer = animEnt
    if not animEnt:IsPlayer() then
        targetPlayer = animEnt:GetOwner()
        if not IsValid(targetPlayer) or not targetPlayer:IsPlayer() then
            return false, "Нет владельца"
        end
    end
    
    -- 1. ПРОВЕРКА: Нельзя захватить самого себя
    if targetPlayer == grabberPlayer then
        return false, "Нельзя захватить самого себя"
    end
    
    -- 2. ПРОВЕРКА: Нельзя захватить, если target уже кого-то держит (Endo)
    if pillName == "pill_endo02" then
        local endoHolders = _G.playersHoldingRightClick or {}
        for holder, victim in pairs(endoHolders) do
            if holder == targetPlayer and IsValid(victim) then
                return false, "Endo кого-то держит (стальной захват)"
            end
        end
        
        if targetPlayer._endoHoldingPlayer and IsValid(targetPlayer._endoHoldingPlayer) then
            return false, "Endo кого-то держит"
        end
    end
    
    -- 3. ПРОВЕРКА: Нельзя захватить, если target уже взят гравити-ганом
    if SERVER and MODULE.Victims[targetPlayer] then
        return false, "Аниматроник уже захвачен гравити-ганом"
    end
    
    -- 4. ПРОВЕРКА: Нельзя захватить, если grabber уже кого-то держит
    if SERVER and MODULE.Holders[grabberPlayer] then
        return false, "Вы уже кого-то держите"
    end
    
    -- 5. ПРОВЕРКА: Нельзя захватить, если grabber сам захвачен гравити-ганом
    if SERVER and MODULE.Victims[grabberPlayer] then
        return false, "Вас держат гравити-ганом"
    end
    
    -- 6. ПРОВЕРКА ДЛЯ BONNIE - нельзя захватить, если использует "Чужой взгляд"
    if pillName == "pill_wbonnie2" then
        if targetPlayer.fh_target_player and IsValid(targetPlayer.fh_target_player) then
            return false, "Bonnie использует Чужой взгляд"
        end
        
        local bonnieTargets = _G.bonnies_targets or {}
        if bonnieTargets[targetPlayer] then
            return false, "Bonnie использует Чужой взгляд"
        end
    end
    
    -- 7. ПРОВЕРКА ДЛЯ SHADOW FREDDY - нельзя захватить, когда рассеивается
    if pillName == "pill_sfreddy2" then
        if targetPlayer:GetMoveType() == MOVETYPE_NOCLIP then
            return false, "Shadow Freddy рассеивается"
        end
        
        local ent = pills.getMappedEnt(targetPlayer)
        if IsValid(ent) and ent.cloaked then
            return false, "Shadow Freddy рассеивается"
        end
    end
    
    -- 8. ДРУГИЕ ПРОВЕРКИ
    if targetPlayer:GetNWBool("tchica_holding") then
        return false, "Аниматроник кого-то держит"
    end
    
    if targetPlayer:GetNW2Bool("_OUTWORLD_target") then
        return false, "Аниматроник в другом мире"
    end
    
    if _G.stalkTargets and _G.stalkTargets[targetPlayer] then
        return false, "Аниматроник использует способность"
    end
    
    local mapped = pills.getMappedEnt(targetPlayer)
    if IsValid(mapped) then
        if mapped.cloaked or mapped:GetMaterial() == "models/null" then
            return false, "Аниматроник невидим"
        end
    end
    
    if targetPlayer:IsFrozen() or targetPlayer.jumpscaring then
        return false, "Аниматроник в jumpscare"
    end
    
    return true, "Можно захватить"
end

-- =========== СЕРВЕРНАЯ ЧАСТЬ ===========
if SERVER then
    local PlayerData = {}
    
    local function GetPlayerData(ply)
        if not PlayerData[ply] then
            PlayerData[ply] = {
                charge = MAX_CHARGE,
                cooldown = false,
                held_animatronic = nil,
                hold_start = 0,
                is_holding = false,
                is_right_mouse_down = false,
                grab_sound = nil
            }
        end
        return PlayerData[ply]
    end

    -- =========== ЗАХВАТ АНИМАТРОНИКА ===========
    local function GrabAnimatronic(ply, target)
        if not IsValid(ply) or not IsValid(target) then return end
        
        local canGrab, reason = CanGrabAnimatronic(target, ply)
        if not canGrab then
            ply:EmitSound("buttons/button10.wav")
            return
        end
        
        local data = GetPlayerData(ply)
        
        if data.cooldown then
            ply:EmitSound("buttons/button10.wav")
            return
        end
        
        if data.charge < MIN_CHARGE_TO_GRAB then
            ply:EmitSound("buttons/button10.wav")
            return
        end
        
        local targetPlayer = target
        if not target:IsPlayer() then
            targetPlayer = target:GetOwner()
            if not IsValid(targetPlayer) or not targetPlayer:IsPlayer() then
                return
            end
        end
        
        data.held_animatronic = targetPlayer
        data.hold_start = CurTime()
        data.is_holding = true
        
        MODULE.Holders[ply] = targetPlayer
        MODULE.Victims[targetPlayer] = ply
        
        targetPlayer:SetMoveType(MOVETYPE_NONE)
        targetPlayer:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        targetPlayer:SetNWEntity("MyGravityGunHolder", ply)
        targetPlayer:SetNWBool("GrabbedByGravityGun", true)
        
        ply:EmitSound("grab_player.wav")
        data.grab_sound = CreateSound(ply, "weapons/physcannon/superphys_hold_loop.wav")
        if data.grab_sound then
            data.grab_sound:PlayEx(0.3, 100)
        end
        
        ply:ChatPrint("✓ Захватил " .. targetPlayer:Nick() .. "!")
        targetPlayer:ChatPrint("✓ Вас захватили гравити-ганом!")
    end
    
    -- =========== ОТПУСКАНИЕ АНИМАТРОНИКА ===========
    local function ReleaseAnimatronic(ply, launchForce)
        local data = GetPlayerData(ply)
        if not data.is_holding or not IsValid(data.held_animatronic) then return end
        
        local target = data.held_animatronic
        
        if data.grab_sound then
            data.grab_sound:Stop()
            data.grab_sound = nil
        end
        
        target:SetMoveType(MOVETYPE_WALK)
        target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
        target:SetNWEntity("MyGravityGunHolder", NULL)
        target:SetNWBool("GrabbedByGravityGun", false)
        
        MODULE.Holders[ply] = nil
        MODULE.Victims[target] = nil
        
        if ply:Alive() then
            ply:EmitSound("throw_player.wav")
        end
        
        if launchForce and launchForce > 0 then
            local direction = ply:GetAimVector():GetNormalized()
            target:SetVelocity(direction * launchForce)
        end
        
        data.held_animatronic = nil
        data.is_holding = false
        data.cooldown = true
        data.charge = 0
        
        MODULE:Timer("ChargeRecovery_" .. ply:SteamID64(), 1, 0, function()
            if not IsValid(ply) then
                MODULE:RemoveTimer("ChargeRecovery_" .. ply:SteamID64())
                return
            end
            
            local data = GetPlayerData(ply)
            if not data.cooldown then 
                MODULE:RemoveTimer("ChargeRecovery_" .. ply:SteamID64())
                return 
            end
            
            data.charge = math.min(MAX_CHARGE, data.charge + 3)
            
            if data.charge >= MAX_CHARGE then
                data.cooldown = false
                MODULE:RemoveTimer("ChargeRecovery_" .. ply:SteamID64())
            end
        end)
    end
    
    -- При отключении модуля отпускаем всех захваченных
    MODULE:OnDisabled(function()
        for holder in pairs(table.Copy(MODULE.Holders)) do
            if IsValid(holder) then ReleaseAnimatronic(holder, 0) end
        end
        table.Empty(MODULE.Holders)
        table.Empty(MODULE.Victims)
    end)

    -- =========== ХУК ДЛЯ БЛОКИРОВКИ ENDO ЗАХВАТА ===========
    -- takePlayer принадлежит гейммоду и появляется после autorun, поэтому патчим в InitPostEntity
    MODULE:Hook("InitPostEntity", "FH_GravityGun_PatchTakePlayer", function()
        MODULE.OriginalTakePlayer = MODULE.OriginalTakePlayer or _G.takePlayer
        local originalTakePlayer = MODULE.OriginalTakePlayer
        if not originalTakePlayer then return end

        _G.takePlayer = function(ply, ent)
            if not MODULE:IsEnabled() then return originalTakePlayer(ply, ent) end

            if ply:GetNWBool("GrabbedByGravityGun") then
                ply:EmitSound("buttons/button10.wav")
                return
            end
            
            if ply._endoHoldingPlayer and IsValid(ply._endoHoldingPlayer) then
                return
            end
            
            local nearestPlayer = FindNearestPlayer(ply:EyePos(), 125, ply, 75)
            if IsValid(nearestPlayer) then
                if nearestPlayer == MODULE.Victims[ply] then
                    return
                end
            end
            
            return originalTakePlayer(ply, ent)
        end
    end)
    
    MODULE:Hook("FH_HandlePlayerGrab", "BlockEndoGrabWhenGrabbedByGravity", function(endo, target)
        if endo:GetNWBool("GrabbedByGravityGun") then
            endo:ChatPrint("✗ Нельзя использовать стальной захват пока вас держат!")
            endo:EmitSound("buttons/button10.wav")
            return false
        end
        
        local gravityHolder = MODULE.Victims[endo]
        if IsValid(gravityHolder) and gravityHolder == target then
            return false
        end
        
        local endoHolders = _G.playersHoldingRightClick or {}
        if endoHolders[endo] then
            return false
        end
    end)
    
    MODULE:Hook("Think", "AutoReleaseEndoWhenGrabbed", function()
        for endoPlayer, _ in pairs(_G.playersHoldingRightClick or {}) do
            if IsValid(endoPlayer) and endoPlayer:GetNWBool("GrabbedByGravityGun") then
                if _G.endoRelease then
                    _G.endoRelease(endoPlayer, true)
                end
            end
        end
    end)
    
    -- =========== НАЖАТИЕ ПКМ (ЗАХВАТ) ===========
    MODULE:Hook("KeyPress", "FH_GrabAnimatronicPress", function(ply, key)
        if key ~= IN_ATTACK2 then return end
        
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_physcannon" then return end
        
        local data = GetPlayerData(ply)
        data.is_right_mouse_down = true
        
        if data.is_holding then return end
        
        local trace = ply:GetEyeTrace()
        if not trace.Hit then return end
        
        local entity = trace.Entity
        if not IsValid(entity) then return end
        
        -- ИСПРАВЛЕНО: используем метод Player:IsAnimatronic()
        local isAnim = false
        if entity:IsPlayer() then
            isAnim = entity:IsAnimatronic()
        elseif entity.GetPillName then
            isAnim = true
        elseif entity:GetClass() == "pill_costume" then
            isAnim = true
        end
        
        if not isAnim then return end
        
        local dist = ply:GetPos():Distance(entity:GetPos())
        if dist > GRAB_DISTANCE then
            return
        end
        
        GrabAnimatronic(ply, entity)
    end)
    
    -- =========== ОТПУСКАНИЕ ПКМ ===========
    MODULE:Hook("KeyRelease", "FH_ReleaseAnimatronicRelease", function(ply, key)
        if key ~= IN_ATTACK2 then return end
        
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_physcannon" then return end
        
        local data = GetPlayerData(ply)
        data.is_right_mouse_down = false
        
        if data.is_holding then
            ReleaseAnimatronic(ply, 400)
        end
    end)
    
    -- =========== ЛКМ - КИДАНИЕ ===========
    MODULE:Hook("KeyPress", "FH_LaunchAnimatronicLeftClick", function(ply, key)
        if key ~= IN_ATTACK then return end
        
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_physcannon" then return end
        
        local data = GetPlayerData(ply)
        
        if data.is_holding then
            ReleaseAnimatronic(ply, 800)
        end
    end)
    
    -- =========== ОБНОВЛЕНИЕ ПОЗИЦИИ ===========
    MODULE:Hook("Think", "FH_UpdateHeldAnimatronic", function()
        for ply, data in pairs(PlayerData) do
            if not IsValid(ply) then
                if data.is_holding and IsValid(data.held_animatronic) then
                    ReleaseAnimatronic(ply, 0)
                end
                continue
            end
            
            local wep = ply:GetActiveWeapon()
            if not IsValid(wep) or wep:GetClass() ~= "weapon_physcannon" then
                if data.is_holding then
                    ReleaseAnimatronic(ply, 0)
                end
                continue
            end
            
            if data.is_holding and IsValid(data.held_animatronic) then
                local target = data.held_animatronic
                local hold_time = CurTime() - data.hold_start
                
                data.charge = math.max(0, data.charge - CHARGE_DRAIN * FrameTime())
                
                if hold_time >= HOLD_TIME_LIMIT then
                    ReleaseAnimatronic(ply, 400)
                    continue
                end
                
                if data.charge <= 0 then
                    ReleaseAnimatronic(ply, 400)
                    continue
                end
                
                local eyePos = ply:EyePos()
                target:SetEyeAngles((eyePos - target:EyePos()):Angle())
                
                local vectorOffset = 50
                if ply:Crouching() then vectorOffset = 5 end
        
                local offset = (ply:EyeAngles():Forward() * 100)
                local newPos = ((ply:GetPos() + ply:EyePos()) / 2) + offset
        
                local traceData = {}
                traceData.start = ply:EyePos()
                traceData.endpos = newPos
                traceData.filter = {ply, target}
        
                local trace = util.TraceEntity(traceData, target)
        
                if trace.Hit then
                    local safeDistance = trace.Fraction * 50
                    offset = (Vector(0, 0, vectorOffset)) + (ply:EyeAngles():Forward() * safeDistance)
                    newPos = ply:GetPos() + offset
                end
        
                target:SetPos(newPos)
            end
        end
    end)
    
    -- =========== ОЧИСТКА ===========
    MODULE:Hook("PlayerDeath", "FH_ClearGravityGunData", function(victim)
        if MODULE.Holders[victim] then
            ReleaseAnimatronic(victim, 0)
        end
        
        if MODULE.Victims[victim] then
            local holder = MODULE.Victims[victim]
            if IsValid(holder) then
                ReleaseAnimatronic(holder, 0)
            end
        end
    end)
    
    MODULE:Hook("PlayerDisconnected", "FH_ClearGravityGunData", function(ply)
        if MODULE.Holders[ply] then
            ReleaseAnimatronic(ply, 0)
        end
        
        if MODULE.Victims[ply] then
            local holder = MODULE.Victims[ply]
            if IsValid(holder) then
                ReleaseAnimatronic(holder, 0)
            end
        end
    end)
    
    MODULE:Hook("PlayerSwitchWeapon", "FH_ClearOnWeaponSwitch", function(ply, old_wep, new_wep)
        if IsValid(old_wep) and old_wep:GetClass() == "weapon_physcannon" then
            local data = GetPlayerData(ply)
            if data and data.is_holding then
                ReleaseAnimatronic(ply, 400)
            end
        end
    end)
    
    -- =========== БЛОКИРОВКА АТАК И АБИЛОК У ЗАХВАЧЕННОГО ===========
    -- Блокируем все боевые клавиши пока аниматроник держится гравити-ганом
    local BLOCKED_KEYS = {
        IN_ATTACK,   -- ЛКМ (атака / jumpscare)
        IN_ATTACK2,  -- ПКМ (абилка)
        IN_RELOAD,   -- R (доп. абилка)
        IN_USE,      -- E (взаимодействие / абилка)
        IN_ZOOM,     -- Z (часто используется как абилка)
        IN_SPEED,    -- Shift (часто dash/sprint ability)
    }

    MODULE:Hook("KeyPress", "FH_BlockGrabbedAnimKeys", function(ply, key)
        if not MODULE.Victims[ply] then return end  -- не захвачен - пропускаем
        if not ply:IsAnimatronic() then return end         -- только аниматроники

        for _, blocked in ipairs(BLOCKED_KEYS) do
            if key == blocked then
                return false  -- глушим нажатие
            end
        end
    end)

    -- =========== СИНХРОНИЗАЦИЯ ===========
    util.AddNetworkString("FH_SyncGravityGunData")
    
    local function SyncDataToClient(ply)
        local data = GetPlayerData(ply)
        net.Start("FH_SyncGravityGunData")
        net.WriteFloat(data.charge or 100)
        net.WriteBool(data.cooldown or false)
        net.WriteBool(data.is_holding or false)
        net.WriteBool(ply:GetNWBool("GrabbedByGravityGun") or false)
        net.Send(ply)
    end
    
    MODULE:Timer("FH_DataSync", 0.2, 0, function()
        for ply, _ in pairs(PlayerData) do
            if IsValid(ply) then
                SyncDataToClient(ply)
            end
        end
    end)

end

-- =========== КЛИЕНТСКАЯ ЧАСТЬ ===========
if CLIENT then
    local current_charge = 100
    local is_cooldown = false
    local is_holding = false
    local is_grabbed = false
    
    MODULE:Receive("FH_SyncGravityGunData", function()
        current_charge = net.ReadFloat()
        is_cooldown = net.ReadBool()
        is_holding = net.ReadBool()
        is_grabbed = net.ReadBool()
    end)
    
    MODULE:Hook("HUDPaint", "FH_GravityGunHUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_physcannon" then return end
        
        local x = ScrW() - 250
        local y = 100
        local width = 230
        local height = 80
        
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(x, y, width, height)
        
        local border_color = is_cooldown and Color(255, 50, 50) or Color(255, 255, 255)
        surface.SetDrawColor(border_color)
        surface.DrawOutlinedRect(x, y, width, height)
        
        draw.SimpleText("FAZBEAR GRAVITY GUN", "SlashMoon.Small", x + width/2, y + 5, Color(255, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        
        local barWidth = (width - 20) * (current_charge / 100)
        local barColor = is_cooldown and Color(255, 50, 50) or 
                        current_charge > 50 and Color(0, 255, 0) or 
                        current_charge > 20 and Color(255, 255, 0) or 
                        Color(255, 50, 50)
        
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(x + 10, y + 35, width - 20, 20)
        
        surface.SetDrawColor(barColor)
        surface.DrawRect(x + 10, y + 35, barWidth, 20)
        
        local charge_text = is_cooldown and "ВОССТАНОВЛЕНИЕ" or "ЗАРЯД: " .. math.Round(current_charge) .. "%"
        local charge_color = is_cooldown and Color(255, 100, 100) or Color(255, 255, 255)
        
        draw.SimpleText(charge_text, "SlashMoon.Small", x + width/2, y + 45, charge_color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        if is_holding then
            draw.SimpleText("УДЕРЖИВАЕТ АНИМАТРОНИКА", "SlashMoon.Small", x + width/2, y + 60, Color(255, 100, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    end)
end
