-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("movement")


local MELEE_CFG = {
    wchica   = { damage = { min = 25, max = 37 }, cooldown = 3.1 },
    endo02   = { damage = { min = 23, max = 35 }, cooldown = 2.6 },
    wbonnie  = { damage = { min = 31, max = 43 }, cooldown = 3.8 },
    wfreddy  = { damage = { min = 29, max = 47 }, cooldown = 3.5 },
    wfoxy    = { damage = { min = 14, max = 31 }, cooldown = 3.3 },
    mangle   = { damage = { min = 24, max = 36 }, cooldown = 2.8 },
    toychica = { damage = { min = 20, max = 30 }, cooldown = 1.5 },
}

local MELEE_HIT_SIZE = {
    Min = Vector(-14, -14, -10),
    Max = Vector( 14,  14,  10)
}

-- Хелпер для проверки, является ли игрок аниматроником
local function IsAnimatronic(p)
    if not IsValid(p) or not p:IsPlayer() then return false end
    local animTeam = TEAM_PILLS or 2700
    return p:Team() == animTeam
end

local function MeleeHitPlayer(ply, ent, cfg, wepClass)
    if not IsValid(ply) or not IsValid(ent) then return end
    if not IsAnimatronic(ply) then return end
    if IsValid(ply:GetEntityInUse()) then return end
    if cooldown.Exists(ply, "kill") then return end

    local startPos = ply:GetShootPos()
    local aimDir   = ply:GetAimVector()
    local traceEnd = startPos + aimDir * 110

    -- Лаг-компенсация (только на сервере)
    if SERVER then
        ply:LagCompensation(true)
    end

    -- Сначала пытаемся попасть тонкой линией
    local tr = util.TraceLine({
        start  = startPos,
        endpos = traceEnd,
        filter = ply,
        mask   = MASK_SHOT_HULL,
    })

    -- Если линия не попала — пробуем широкий куб
    if not IsValid(tr.Entity) then
        tr = util.TraceHull({
            start  = startPos,
            endpos = traceEnd,
            mins   = MELEE_HIT_SIZE.Min,
            maxs   = MELEE_HIT_SIZE.Max,
            filter = ply,
            mask   = MASK_SHOT_HULL,
        })
    end

    if SERVER then
        ply:LagCompensation(false)
    end

    ent:PillGesture("melee", 2, 1, 0.1, 0.7)

    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and (wepClass == nil or wep:GetClass() == wepClass) then
        wep:HandleAnimation("attack", 1, true)
    end
    if tr.Hit then
        ply:EmitSound("bonnie_punch.mp3")
    end
    cooldown.Set(ply, "kill", cfg.cooldown)
    cooldown.Send(ply, "kill")

    local target = tr.Entity
    -- Цель должна быть живым игроком-выжившим (не аниматроником)
    if not (IsValid(target) and target:IsPlayer() and target:Alive() and not IsAnimatronic(target)) then
        AnimatronicBreakProp(ply, ent)
        return
    end

    -- Замедление аниматроника после удара
    local ft = ent.formTable
    if ft and ft.moveSpeed then
        local sWalk = math.floor(ft.moveSpeed.walk   * 0.70)
        local sRun  = math.floor(ft.moveSpeed.walk   * 0.70)
        local sDuck = math.floor(ft.moveSpeed.ducked * 0.70)
        ent:SetSpeed(sWalk, sRun, sDuck, ft.jumpPower or 250)

        MODULE:Timer("melee_slow_" .. ply:EntIndex(), cfg.cooldown, 1, function()
            if not IsValid(ent) then return end
            SlashMoon.Movement.RestoreAnimSpeed(ply)
        end)
    end

    local rolledDamage = math.random(cfg.damage.min, cfg.damage.max)

    local dmg = DamageInfo()
    dmg:SetAttacker(ply)
    dmg:SetInflictor(ent)
    dmg:SetDamage(rolledDamage)
    dmg:SetDamageType(DMG_CLUB)
    target:TakeDamageInfo(dmg)

    if target:Health() < 1 then
        target:SetHealth(1)
    end

    return target
end

-- =====================================================

MODULE:Hook("PostGamemodeLoaded", "addon_melee_overrides", function()
    if engine.ActiveGamemode() ~= "fazbearshunt" then return end
    -- StartBleeding / StopBleeding принадлежат гейммоду: оборачиваем их один раз,
    -- обертки пропускают свою логику, когда модуль выключен
    if SERVER and StartBleeding and StopBleeding and not MODULE.BleedingWrapped then
        MODULE.BleedingWrapped = true

        local _oldStartBleeding = StartBleeding
        function StartBleeding(ply, dealer)
            if not IsValid(ply) then return end

            -- Запускаем оригинальные бесконечные таймеры урона и крови
            _oldStartBleeding(ply, dealer)
            if not MODULE:IsEnabled() then return end
            
            -- Извне глушим их ровно через 7 секунд
            local steamID = ply:SteamID()
            MODULE:Timer("FoxyBleedTimeout_" .. steamID, 7, 1, function()
                if IsValid(ply) then
                    StopBleeding(ply)
                end
            end)
        end

        local _oldStopBleeding = StopBleeding
        function StopBleeding(ply)
            if not IsValid(ply) or not ply:IsPlayer() then return end
            
            -- Вызываем оригинальную очистку таймеров foxy.lua
            _oldStopBleeding(ply)
            
            -- Удаляем таймер авто-стопа, если игрок умер или отключился раньше
            local steamID = ply:SteamID()
            if timer.Exists("FoxyBleedTimeout_" .. steamID) then
                MODULE:RemoveTimer("FoxyBleedTimeout_" .. steamID)
            end
        end
    end

    pills.editPillTable("pill_wchica2", "attack", {
        mode = "trigger",
        func = function(ply, ent)
            MeleeHitPlayer(ply, ent, MELEE_CFG.wchica)
        end
    })

    pills.editPillTable("pill_endo02", "attack", {
        mode = "trigger",
        func = function(ply, ent)
            -- Нельзя бить игрока, которого сейчас держишь захватом
            if IsValid(ply._endoHoldingPlayer) then return end
            MeleeHitPlayer(ply, ent, MELEE_CFG.endo02, "v_endo")
        end
    })

    pills.editPillTable("pill_wbonnie2", "attack", {
        mode = "trigger",
        func = function(ply, ent)
            MeleeHitPlayer(ply, ent, MELEE_CFG.wbonnie, "v_bonnie")
        end
    })

    pills.editPillTable("pill_wfreddy2", "attack", {
        mode = "trigger",
        func = function(ply, ent)
            if IsValid(ply:GetEntityInUse()) then return end
            MeleeHitPlayer(ply, ent, MELEE_CFG.wfreddy, "v_freddy")
        end
    })

    pills.editPillTable("pill_wfoxy2", "attack", {
        mode = "trigger",
        func = function(ply, ent)
            if IsValid(ply:GetEntityInUse()) then return end

            -- Вызываем удар и получаем жертву, если попали
            local hitTarget = MeleeHitPlayer(ply, ent, MELEE_CFG.wfoxy, "v_foxy")
            
            -- Если удар успешно нанёс урон и функция кровотечения доступна на сервере
            if SERVER and IsValid(hitTarget) and StartBleeding then
                StartBleeding(hitTarget, ply)
            end
        end
    })

    pills.editPillTable("pill_mangle", "attack", {
        mode = "trigger",
        func = function(ply, ent)
            if ply:GetNWBool("_MangleHooked") or ply:GetNWBool("_MangleHookReady") then return end
            MeleeHitPlayer(ply, ent, MELEE_CFG.mangle, "v_mangle")
        end
    })

    pills.editPillTable("pill_toychica", "attack", {
        mode = "trigger",
        func = function(ply, ent)
            if ply:GetNWBool("tchica_holding") then return end
            MeleeHitPlayer(ply, ent, MELEE_CFG.toychica, "v_toychica")
        end
    })
end)

-- =====================================================
-- Перехватываем SetDefaultSpeed для наших аниматроников.
-- =====================================================
if SERVER then
    local MANAGED_PILLS = {
        pill_wchica2   = true,
        pill_endo02    = true,
        pill_wbonnie2  = true,
        pill_wfreddy2  = true,
        pill_wfoxy2    = true,
        pill_mangle    = true,
        pill_toychica  = true,
        pill_plushtrap = true,
    }

    MODULE:Hook("PillApply", "fh_melee_override_setdefaultspeed", function(ply, ent)
        if not (ent.formTable and MANAGED_PILLS[ent.formTable.name]) then return end

        ent.SetDefaultSpeed = function(self)
            SlashMoon.Movement.RestoreAnimSpeed(ply)
        end
    end)
end
