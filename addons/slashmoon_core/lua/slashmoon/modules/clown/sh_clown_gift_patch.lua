-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("clown")

-- ========================================================
-- Клоун: фальшивые подарки, эффекты подарков для клоуна,
-- усиленный молот и способность "Трюк"
-- ========================================================

MODULE.FakeGiftCooldown = MODULE.FakeGiftCooldown or {}

-- Метод игрока IsClown (если гейммод его не определил)
local PLAYER = FindMetaTable("Player")
if PLAYER and not PLAYER.IsClown then
    function PLAYER:IsClown()
        local pill = self:GetPill()
        return IsValid(pill) and pill.formTable.name == "pill_clown"
    end
end

if SERVER then
    util.AddNetworkString("ClownAbilityActivated")
    util.AddNetworkString("ClownNegativeEffect")
    util.AddNetworkString("ClownRevealStart")
    util.AddNetworkString("ClownRevealStop")

    -- ══════════════════════════════════════════════════════
    --  Спавн машины
    -- ══════════════════════════════════════════════════════
    local function SpawnCarOnPlayer(ply)
        if not IsValid(ply) then return end
        local playerPos    = ply:GetPos()
        local playerHeight = ply:OBBMaxs().z - ply:OBBMins().z
        local car = ents.Create("prop_physics")
        if not IsValid(car) then return end
        car:SetModel("models/props_vehicles/truck001a.mdl")
        local carMins, carMaxs = car:GetCollisionBounds()
        local startPos = playerPos + Vector(0, 0, playerHeight + (carMaxs.z - carMins.z) / 2 + 10)
        local endPos   = startPos + Vector(0, 0, 500)
        local tr = util.TraceHull({ start = startPos, endpos = endPos, filter = {ply, car}, mins = carMins, maxs = carMaxs })
        car:SetPos(tr.Hit and tr.HitPos or endPos)
        car:Spawn()
        car:Activate()
        local phys = car:GetPhysicsObject()
        if IsValid(phys) then phys:SetVelocity(-car:GetUp() * 2000) end
        timer.Simple(10, function() if IsValid(car) then car:Remove() end end)
    end

    -- ══════════════════════════════════════════════════════
    --  Негативные эффекты для клоуна
    -- ══════════════════════════════════════════════════════
    local clownNegativeEffects = {
        [1] = function(ply)
            ply._clownHeavy = true
            net.Start("ClownNegativeEffect") net.WriteString("Тяжесть") net.Send(ply)
            return "Тяжесть"
        end,
        [2] = function(ply)
            -- Отправляем всем выжившим команду подсветить клоуна
            for _, p in player.Iterator() do
                if IsValid(p) and p:IsSurvivor() then
                    net.Start("ClownRevealStart")
                        net.WriteEntity(ply)
                    net.Send(p)
                end
            end

            MODULE:Timer("ClownReveal_" .. ply:EntIndex(), 20, 1, function()
                if not IsValid(ply) then return end
                for _, p in player.Iterator() do
                    if IsValid(p) and p:IsSurvivor() then
                        net.Start("ClownRevealStop")
                            net.WriteEntity(ply)
                        net.Send(p)
                    end
                end
            end)

            net.Start("ClownNegativeEffect") net.WriteString("Порченный просвет") net.Send(ply)
            return "Порченный просвет"
        end,
        [3] = function(ply)
            MODULE:Timer("ClownBananas_" .. ply:EntIndex(), 0.5, 14, function()
                if not IsValid(ply) then return end
                local peel = ents.Create("banana_peel")
                if not IsValid(peel) then return end
                peel:SetPos(ply:GetPos() + ply:GetForward() * 60)
                peel:Spawn()
                peel:Activate()
                timer.Simple(2, function() if IsValid(peel) then peel:Remove() end end)
            end)
            net.Start("ClownNegativeEffect") net.WriteString("Дырявые кармашки") net.Send(ply)
            return "Дырявые кармашки"
        end,
    }

    -- ══════════════════════════════════════════════════════
    --  Позитивные эффекты для клоуна
    -- ══════════════════════════════════════════════════════
    local clownPositiveEffects = {
        [1] = function(ply)
            local origWalk = ply:GetWalkSpeed()
            local origRun  = ply:GetRunSpeed()
            local origCrch = ply:GetCrouchedWalkSpeed()
            ply:SetWalkSpeed(110) ply:SetRunSpeed(480) ply:SetCrouchedWalkSpeed(origCrch * 1.4)
            local trail = util.SpriteTrail(ply, ply:LookupAttachment("chest"), Color(255, 0, 51), true, 32, 0, 1, 1/(32*0.5), "trails/physbeam")
            ply._clownSpeedTrail = trail
            timer.Simple(8, function()
                if not IsValid(ply) then return end
                ply:SetWalkSpeed(origWalk) ply:SetRunSpeed(origRun) ply:SetCrouchedWalkSpeed(origCrch)
                if IsValid(ply._clownSpeedTrail) then ply._clownSpeedTrail:Remove() ply._clownSpeedTrail = nil end
            end)
            return "+ Адреналин клоуна"
        end,
        [2] = function(ply)
            local farthest, maxDist = nil, 0
            for _, p in ipairs(team.GetPlayers(TEAM_SURVIVOR)) do
                if IsValid(p) and p:Alive() then
                    local dist = ply:GetPos():Distance(p:GetPos())
                    if dist > maxDist then maxDist = dist farthest = p end
                end
            end
            if not IsValid(farthest) then return "Нет целей" end
            highlight.Add(ply, farthest)
            ply:EmitSound("kloun/ebanat.wav")
            return "Дальний охотник"
        end,
        [3] = function(ply)
            ply._clownHammer = true
            timer.Simple(30, function() if IsValid(ply) then ply._clownHammer = nil end end)
            return "+ Масса"
        end,
    }

    local function GetNextEffect(ply, pool, usedKey)
        if not IsValid(ply) then return nil end
        local used      = ply[usedKey] or {}
        local available = {}
        for i = 1, #pool do
            if not used[i] then table.insert(available, i) end
        end
        if #available == 0 then
            used = {}
            for i = 1, #pool do table.insert(available, i) end
        end
        local idx    = table.Random(available)
        used[idx]    = true
        ply[usedKey] = used
        return pool[idx]
    end

    -- ══════════════════════════════════════════════════════
    --  Патч fh_gift
    -- ══════════════════════════════════════════════════════
    MODULE:Hook("InitPostEntity", "ClownGiftPatch", function()
        local giftEnt = scripted_ents.GetStored("fh_gift")
        if not giftEnt then return end

        -- Оригинал запоминается один раз, чтобы повторное включение модуля не оборачивало патч в патч
        MODULE.OriginalGiftTouch = MODULE.OriginalGiftTouch or giftEnt.t.Touch
        local Original_Touch = MODULE.OriginalGiftTouch

        function giftEnt.t:Touch(ent)
            if not MODULE:IsEnabled() then return Original_Touch(self, ent) end
            if self.IsUsed then return end
            if CurTime() - self.SpawnTime < 1.5 then return end
            if not ent:IsPlayer() or ent:IsBot() or not ent:Alive() then return end

            if self._isFakeGift then
                if not ent:IsSurvivor() then return end
                self.IsUsed = true
                if math.random(1, 100) <= 99 then
                    SpawnCarOnPlayer(ent)
                    self:EmitSound("ahuitebe.mp3")
                else
                    gifts.GrantEffect(ent, "killer_mask")
                    self:EmitSound("orch_hit_csharp_short.wav")
                end
                self:Remove()
                return
            end

            if ent:IsSurvivor() then
                return Original_Touch(self, ent)
            end

            if ent:IsClown() then
                self.IsUsed = true

                local isOwner    = self:GetOwner() == ent
                local isNegative = not isOwner and math.random(1, 2) == 1
                local msg

                if isNegative then
                    local fn = GetNextEffect(ent, clownNegativeEffects, "_clownUsedNeg")
                    if fn then msg = fn(ent) end
                    self:EmitSound("ahuitebe.mp3")
                else
                    local fn = GetNextEffect(ent, clownPositiveEffects, "_clownUsedPos")
                    if fn then msg = fn(ent) end
                    self:EmitSound("orch_hit_csharp_short.wav")
                end

                net.Start("fh_net_display")
                    net.WriteString(isNegative and "fazhunt.gifts.negative" or "fazhunt.gifts.positive")
                    net.WriteString(msg or "")
                    net.WriteFloat(-1)
                    net.WriteFloat(5)
                net.Send(ent)
                self:Remove()
                return
            end
        end
    end)

    -- ══════════════════════════════════════════════════════
    --  editPillTable — attack2 и land
    -- ══════════════════════════════════════════════════════
    MODULE:Hook("PostGamemodeLoaded", "ClownPillTableOverride", function()
        if engine.ActiveGamemode() ~= "fazbearshunt" then return end

        -- attack2 — Фальшивка
        pills.editPillTable("pill_clown", "attack2", {
            mode = "trigger",
            func = function(ply, ent)
                if not MODULE:IsEnabled() then return end
                if ply.tasered or not roundActive then return end

                local idx     = ply:EntIndex()
                local lastUse = MODULE.FakeGiftCooldown[idx] or 0
                local now     = CurTime()
                local cd      = 60

                if now - lastUse < cd then return end

                local aliveSurvivors = {}
                for _, p in ipairs(team.GetPlayers(TEAM_SURVIVOR)) do
                    if IsValid(p) and p:Alive() then table.insert(aliveSurvivors, p) end
                end

                if #aliveSurvivors == 0 then
                    ply:ChatPrint("Некому подставить...")
                    return
                end

                MODULE.FakeGiftCooldown[idx] = now

                local fakeOwner = table.Random(aliveSurvivors)
                local gift      = ents.Create("fh_gift")
                if not IsValid(gift) then return end

                local pos = ply:GetPos() + Vector(0, 0, 10)
                local tr  = util.TraceHull({
                    start  = pos, endpos = pos,
                    mins   = Vector(-16, -16, 0), maxs = Vector(16, 16, 32),
                    filter = {ply}
                })

                if not tr.Hit then
                    gift:SetPos(pos)
                    gift:SetOwner(fakeOwner)
                    gift:Spawn()
                    gift:Activate()
                    gift._isFakeGift = true
                else
                    gift:Remove()
                    return
                end

                ply:EmitSound("orch_hit_csharp_short.wav")

                net.Start("ClownAbilityActivated")
                    net.WriteString("Фальшивка")
                    net.WriteFloat(cd)
                net.Send(ply)
            end
        })

        pills.editPillTable("pill_clown", "land", function(ply, ent)
			ent.anim = nil
			if ply.lobbyFreeze then return end
			if ply:WaterLevel() < 1 and ply:GetVelocity().z < -100 then
				ent:PillGesture("land", 1, 2, 0.1, 0.3, 0.06)
				ent:PillLoopStop("dance")

				if ply._clownHeavy then
					ply:Freeze(true)
					MODULE:Timer("clown_heavy_land_" .. ply:EntIndex(), 0.6, 1, function()
						if not IsValid(ply) then return end
						ply:Freeze(false)
					end)
				end
			end
		end)
    end)

    -- ══════════════════════════════════════════════════════
    --  Усиленный молот — выбивание дверей
    -- ══════════════════════════════════════════════════════
    MODULE:Hook("FuncDoorBust", "ClownHammerDoorBust", function(ply, door)
        if not ply._clownHammer then return end
        local puppet = pills.getMappedEnt(ply)
        if not IsValid(puppet) or puppet.formTable.name ~= "pill_clown" then return end
        breakBustDoor(ply, door)
    end)

    -- ══════════════════════════════════════════════════════
    --  Сброс эффектов
    -- ══════════════════════════════════════════════════════
    MODULE:Hook("PostCleanupMap", "ClownEffectsReset", function()
        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end
            ply._clownHeavy  = nil
            ply._clownHammer = nil
            MODULE:RemoveTimer("ClownReveal_"  .. ply:EntIndex())
            MODULE:RemoveTimer("ClownBananas_" .. ply:EntIndex())
        end
    end)

    MODULE:Hook("PillRestore", "ClownEffectsCleanup", function(ply, ent)
        if ent.formTable.name ~= "pill_clown" then return end
        ply._clownHeavy  = nil
        ply._clownHammer = nil
        MODULE:RemoveTimer("ClownReveal_"  .. ply:EntIndex())
        MODULE:RemoveTimer("ClownBananas_" .. ply:EntIndex())
    end)
end

-- ══════════════════════════════════════════════════════
--  КЛИЕНТ
-- ══════════════════════════════════════════════════════
if CLIENT then
    MODULE:Hook("PillApply", "ClownAddFakeGiftButton", function(ply, ent)
        if ply ~= LocalPlayer() or ent.formTable.name ~= "pill_clown" then return end
        if not currentAbilities then currentAbilities = {} end
        currentAbilities["Трюк"] = {
            text    = "RMB",
            endTime = 0,
            maxTime = 0,
            tokens  = -1,
            hidden  = false,
            color   = Color(255, 105, 180)
        }
    end)

    MODULE:Hook("PillRestore", "ClownRemoveFakeGiftButton", function(ply)
        if ply ~= LocalPlayer() then return end
        if currentAbilities and currentAbilities["Трюк"] then
            currentAbilities["Трюк"] = nil
        end
    end)

    MODULE:Receive("ClownAbilityActivated", function()
        local name     = net.ReadString()
        local duration = net.ReadFloat()
        if not currentAbilities then currentAbilities = {} end
        currentAbilities["Трюк"] = {
            text    = "RMB",
            endTime = CurTime() + duration,
            maxTime = duration,
            tokens  = -1,
            hidden  = false,
            color   = Color(255, 105, 180)
        }
        timer.Simple(duration, function()
            if currentAbilities and currentAbilities["Трюк"] then
                currentAbilities["Трюк"].endTime = 0
                currentAbilities["Трюк"].maxTime = 0
            end
        end)
    end)

    MODULE:Receive("ClownNegativeEffect", function()
        net.ReadString() -- название эффекта показывается через fh_net_display
    end)
    MODULE:Receive("ClownRevealStart", function()
        local ply = net.ReadEntity()
        if IsValid(ply) then
            addAffected(ply, nil, Color(255, 0, 255))
        end
    end)

    MODULE:Receive("ClownRevealStop", function()
        local ply = net.ReadEntity()
        if IsValid(ply) then
            removeAffected(ply)
        end
    end)
end
