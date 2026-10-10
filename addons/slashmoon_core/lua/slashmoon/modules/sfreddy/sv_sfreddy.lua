-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- Реворк Shadow Freddy (ЭКСПЕРИМЕНТАЛЬНО)
-- Логика ниже была отключена авторами в исходной сборке и оставлена
-- закомментированной как заготовка: плюши-ловушки, ускорение за плюши, телепорт.
-- ========================================================

--[[

sound.Add({
    name    = "sfreddy.foot",
    channel = CHAN_STATIC,
    level   = 90,
    volume  = 1.0,
    sound   = {
        ")SHADOWSTEP1.wav",
        ")SHADOWSTEP2.wav",
        ")SHADOWSTEP3.wav",
        ")SHADOWSTEP4.wav"
    }
})

resource.AddFile("sound/SHADOWSTEP1.wav")
resource.AddFile("sound/SHADOWSTEP2.wav")
resource.AddFile("sound/SHADOWSTEP3.wav")
resource.AddFile("sound/SHADOWSTEP4.wav")

util.AddNetworkString("sfr_plushie_count")
util.AddNetworkString("sfr_play_sound")
util.AddNetworkString("fh_net_killer_change")
util.AddNetworkString("fh_net_killer_change_tokens")

local BASE_WALK      = 110
local BASE_RUN       = 250
local BASE_DUCK      = 65
local BASE_JUMP      = 250

local MAX_PLUSHIES   = 5
local PLUSH_BUFF     = 0.20

local SPAWN_COOLDOWN = 15
local MELEE_COOLDOWN = 2.5

local function CountPlushies(ply)
    local count = 0
    for _, ent in ipairs(ents.FindByClass("sfreddy_plushie")) do
        if IsValid(ent) and ent.sfr_owner == ply then
            count = count + 1
        end
    end
    return count
end

local function UpdateStats(ply)
    local puppet = pills.getMappedEnt(ply)
    if not IsValid(puppet) then return end
    if not puppet.formTable or puppet.formTable.name ~= "pill_sfreddy2" then return end

    local count = CountPlushies(ply)
    local mult  = 1 + count * PLUSH_BUFF

    local newWalk = math.floor(BASE_WALK * mult)
    local newRun  = math.floor(BASE_RUN  * mult)
    local newDuck = math.floor(BASE_DUCK * mult)

    puppet.formTable.moveSpeed.walk   = newWalk
    puppet.formTable.moveSpeed.run    = newRun
    puppet.formTable.moveSpeed.ducked = newDuck

    puppet:SetSpeed(newWalk, newRun, newDuck, BASE_JUMP)
    ply:SetSlowWalkSpeed(newWalk)

    net.Start("fh_net_killer_change_tokens")
    net.WriteString("Плюши")
    net.WriteInt(count, 9)
    net.Send(ply)
end

local function SpawnPlushie(ply)
    if not IsValid(ply) then return end

    if not navmesh.IsLoaded() or navmesh.GetNavAreaCount() < 5 then
        net.Start("sfr_play_sound")
        net.WriteString("sfreddyerror.wav")
        net.Send(ply)
        return
    end

    local survivors = {}
    for _, p in player.Iterator() do
        if IsValid(p) and p:IsSurvivor() and p:Alive() then
            table.insert(survivors, p)
        end
    end

    if #survivors == 0 then
        net.Start("sfr_play_sound")
        net.WriteString("sfreddyerror.wav")
        net.Send(ply)
        return
    end

    local target = survivors[math.random(#survivors)]
    local origin = target:GetPos()

    local usedPos = {}
    for _, ent in ipairs(ents.FindByClass("sfreddy_plushie")) do
        if IsValid(ent) and ent.sfr_owner == ply then
            table.insert(usedPos, ent:GetPos())
        end
    end

    local areas = navmesh.GetAllNavAreas()
    table.Shuffle(areas)
    local spawnPos = nil

    for _, area in ipairs(areas) do
        if area:HasAttributes(NAV_MESH_CROUCH) or area:HasAttributes(NAV_MESH_AVOID) or area:IsUnderwater() then continue end
        local pos    = area:GetCenter()
        local distSq = origin:DistToSqr(pos)
        if distSq > 1900^2 then continue end
        if math.abs(origin.z - pos.z) > 200 then continue end
        local tooClose = false
        for _, used in ipairs(usedPos) do
            if used:DistToSqr(pos) < 500^2 then tooClose = true break end
        end
        if tooClose then continue end
        spawnPos = pos
        break
    end

    if not spawnPos then
        net.Start("sfr_play_sound")
        net.WriteString("sfreddyerror.wav")
        net.Send(ply)
        return
    end

    local spawnEnt = ents.Create("sfreddy_plushie")
    if not IsValid(spawnEnt) then return end
    spawnEnt:SetPos(spawnPos)
    spawnEnt:Spawn()
    spawnEnt:Activate()
    spawnEnt.sfr_owner = ply

    net.Start("sfr_play_sound")
    net.WriteString("sfreddyin.mp3")
    net.Send(ply)

    cooldown.Set(ply, "submerge", SPAWN_COOLDOWN)
    cooldown.Send(ply, "submerge")

    -- Отдельно шлём таймер под ключом "Плюши" для худа
    net.Start("fh_cooldown_receive")
    net.WriteString("Плюши")
    net.WriteFloat(SPAWN_COOLDOWN)
    net.Send(ply)

    UpdateStats(ply)
end

local function KillPlushies(ply)
    for _, ent in ipairs(ents.FindByClass("sfreddy_plushie")) do
        if IsValid(ent) and ent.sfr_owner == ply then
            ent:Remove()
        end
    end
end


MODULE:Hook("PostGamemodeLoaded", "sfr_sfreddy_editpilltable", function()
    if engine.ActiveGamemode() ~= "fazbearshunt" then return end

    -- attack
    pills.editPillTable("pill_sfreddy2", "attack", {
        mode = "trigger",
        func = function(ply, ent)
            if ent.cloaked then return end
            if IsValid(ply:GetEntityInUse()) then return end

            local plushCount = CountPlushies(ply)
            local target     = FindNearestPlayer(ent:GetPos(), 130, ply, 75)

            if plushCount == 0 then
                if cooldown.Exists(ply, "kill") then return end
                local jumpscare = performJumpscare(ply, ent, target, 1.6, "sfreddy", 52, "v_freddy")
                if not IsValid(target) or not jumpscare then
                    AnimatronicBreakProp(ply, ent)
                end
            else
                if cooldown.Exists(ply, "sfr_melee") then return end
                if not IsValid(target) then
                    AnimatronicBreakProp(ply, ent)
                    return
                end

                cooldown.Set(ply, "sfr_melee", MELEE_COOLDOWN)
                cooldown.Send(ply, "sfr_melee")

                ent:PillGesture("melee", 2, 1, 0.1, 0.7)

                local wep = ply:GetActiveWeapon()
                if IsValid(wep) and wep:GetClass() == "v_freddy" then
                    wep:HandleAnimation("attack", 1, true)
                end

                ply:EmitSound("bonnie_punch.mp3")

                local dmg = DamageInfo()
                dmg:SetAttacker(ply)
                dmg:SetInflictor(ent)
                dmg:SetDamage(20)
                dmg:SetDamageType(DMG_CLUB)
                target:TakeDamageInfo(dmg)

                if target:Health() < 1 then
                    target:SetHealth(1)
                end
            end
        end
    })

    -- attack2
    local originalTable      = pills.getPillTable("pill_sfreddy2")
    local originalAttack2Func = originalTable and originalTable.attack2 and originalTable.attack2.func

    pills.editPillTable("pill_sfreddy2", "attack2", {
        mode = "trigger",
        func = function(ply, ent)
            if ent.cloaked then
                if originalAttack2Func then
                    originalAttack2Func(ply, ent)
                end
                return
            end

            if cooldown.Exists(ply, "sfr_spawn_plushie") then return end

            if CountPlushies(ply) >= MAX_PLUSHIES then
                net.Start("sfr_play_sound")
                net.WriteString("sfreddyerror.wav")
                net.Send(ply)
                return
            end

            cooldown.Set(ply, "sfr_spawn_plushie", SPAWN_COOLDOWN)
            cooldown.Send(ply, "sfr_spawn_plushie")

            SpawnPlushie(ply)
        end
    })

    -- лэнд как у фредди
    pills.editPillTable("pill_sfreddy2", "land", function(ply, ent)
        if ply:WaterLevel() < 2 then
            if ply._wereJumpingPill or not ply._wereJumpingPill and ply:GetVelocity().z < -270 then
                if not ply._jumpPosPill or ply._jumpPosPill and ply:GetPos():Distance(ply._jumpPosPill) > 150 then
                    ent:PillAnim("land", true)
                end
            end
        end

        ply:SetLocalVelocity(Vector(0, 0, 0))

        MODULE:Timer("sfreddy_land_timer" .. ply:EntIndex(), 0.4, 1, function()
            if not IsValid(ply) then return end
        end)
    end)

end)

MODULE:Hook("PillApply", "sfr_sfreddy_apply", function(ply, ent)
    if ent.formTable.name ~= "pill_sfreddy2" then return end

    timer.Simple(0.1, function()
        if not IsValid(ply) or not IsValid(ent) then return end

        ent.formTable.moveSpeed.walk   = BASE_WALK
        ent.formTable.moveSpeed.run    = BASE_RUN
        ent.formTable.moveSpeed.ducked = BASE_DUCK
        ent:SetSpeed(BASE_WALK, BASE_RUN, BASE_DUCK, BASE_JUMP)
        ply:SetSlowWalkSpeed(BASE_WALK)

        if ent.formTable.anims and ent.formTable.anims.default then
            ent.formTable.anims.default.walk = "swalk_step"
            ent.formTable.anims.default.run  = "run_step"
            ent.formTable.anims.default.land = "land_sf" -- лэнд новый
        end
    end)

    net.Start("fh_net_killer_change_tokens")
    net.WriteString("Плюши")
    net.WriteInt(0, 9)
    net.Send(ply)
end)

MODULE:Hook("KeyPress", "sfr_plushie_pickup", function(ply, key)
    if key ~= IN_USE then return end
    if not IsValid(ply) or ply:IsAnimatronic() then return end

    local eyePos  = ply:EyePos()
    local viewDir = ply:GetAimVector()

    for _, ent in ipairs(ents.FindByClass("sfreddy_plushie")) do
        if not IsValid(ent) then continue end
        local toEnt = ent:GetPos() - eyePos
        if toEnt:LengthSqr() > 200^2 then continue end
        if viewDir:Dot(toEnt:GetNormalized()) < 0.9848 then continue end

        local owner = ent.sfr_owner
        ent:Remove()

        net.Start("sfr_play_sound")
        net.WriteString("fnaf2/gfreddy/plushie_taken.wav")
        net.Send(ply)

        if IsValid(owner) then
            net.Start("sfr_play_sound")
            net.WriteString("fnaf2/gfreddy/plushie_taken_alert.wav")
            net.Send(owner)
        end

        break
    end
end)

MODULE:Hook("EntityRemoved", "sfr_recalc_on_plushie_remove", function(ent)
    if ent:GetClass() ~= "sfreddy_plushie" then return end
    local owner = ent.sfr_owner
    if not IsValid(owner) then return end
    timer.Simple(0, function()
        if IsValid(owner) then UpdateStats(owner) end
    end)
end)

MODULE:Hook("PillRestore", "sfr_cleanup_on_restore", function(ply, ent)
    if not ent.formTable or ent.formTable.name ~= "pill_sfreddy2" then return end
    KillPlushies(ply)
    net.Start("fh_net_killer_change_tokens")
    net.WriteString("Плюши")
    net.WriteInt(0, 9)
    net.Send(ply)
end)

MODULE:Hook("PlayerDeath", "sfr_cleanup_on_death", function(ply)
    local puppet = pills.getMappedEnt(ply)
    if not IsValid(puppet) then return end
    if puppet.formTable and puppet.formTable.name == "pill_sfreddy2" then
        KillPlushies(ply)
    end
end)

MODULE:Command("sfr_goto", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_sfreddy_debug") then
        ply:ChatPrint("[SFreddy] Нет доступа.")
        return
    end

    local puppet = pills.getMappedEnt(ply)
    if not IsValid(puppet) or puppet.formTable.name ~= "pill_sfreddy2" then
        ply:ChatPrint("[SFreddy] Команда только для Shadow Freddy.")
        return
    end

    local plushies = {}
    for _, ent in ipairs(ents.FindByClass("sfreddy_plushie")) do
        if IsValid(ent) and ent.sfr_owner == ply then
            table.insert(plushies, ent)
        end
    end

    if #plushies == 0 then
        ply:ChatPrint("[SFreddy] Нет активных плюш.")
        return
    end

    local target = nil
    local idx = tonumber(args[1])
    if idx then
        target = plushies[math.Clamp(idx, 1, #plushies)]
    else
        local minDist = math.huge
        for _, ent in ipairs(plushies) do
            local d = ply:GetPos():DistToSqr(ent:GetPos())
            if d < minDist then
                minDist = d
                target = ent
            end
        end
    end

    if not IsValid(target) then
        ply:ChatPrint("[SFreddy] Плюша не найдена.")
        return
    end

    ply:SetPos(target:GetPos() + Vector(0, 0, 10))
    ply:ChatPrint("[SFreddy] Телепортирован к плюше.")
end)

--]]
