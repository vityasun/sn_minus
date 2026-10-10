-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("animatronics")

-- ========================================================
-- Доработки аниматроников: мины-кексы Чики, связка Плюштрап -> Спрингтрап,
-- голос крысы для живых игроков
-- ========================================================

SlashMoon.Animatronics = SlashMoon.Animatronics or {}

local function GetPillName(ply)
    local pill = IsValid(ply) and pills and pills.getMappedEnt(ply)
    return IsValid(pill) and pill.formTable and pill.formTable.name or nil
end

local function IsRat(ply)
    return IsValid(ply) and ply:GetNW2Bool("fh_isRat", false)
end

if SERVER then
    local slowTokens = {}
    local plushSpringtrap = {}
    local ratVoiceUntil = {}
    local originalHighlightByDistance

    local function ClearChicaSlow(ply)
        if not IsValid(ply) then return end
        slowTokens[ply] = nil
        ply.FH_SpeedModifier = 1.0
    end

    local function SlowChicaTarget(ply, duration)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
        if not ply:IsSurvivor() then return end

        local token = (slowTokens[ply] or 0) + 1
        slowTokens[ply] = token
        ply.FH_SpeedModifier = 0.5

        MODULE:Timer("SN_Animatronics_ChicaSlow_" .. ply:EntIndex(), duration, 1, function()
            if IsValid(ply) and slowTokens[ply] == token then
                ClearChicaSlow(ply)
            end
        end)
    end

    SlashMoon.Animatronics.SlowChicaTarget = SlowChicaTarget

    local chicaCupcakes = {}

    local function InstallChicaAbility()
        if not pills or not pills.editPillTable then return false end

        -- Исходная способность гейммода запоминается, чтобы вернуть ее при отключении модуля
        if not MODULE.OriginalChicaAttack2 and pills.getPillTable then
            local tbl = pills.getPillTable("pill_wchica2")
            MODULE.OriginalChicaAttack2 = tbl and tbl.attack2 or false
        end

        local ok = pcall(pills.editPillTable, "pill_wchica2", "attack2", {
            mode = "trigger",
            func = function(ply, pill)
                if not IsValid(ply) or not IsValid(pill) then return end
                chicaCupcakes[ply] = chicaCupcakes[ply] or 0

                local maxCupcakes = GetConVar("fh_max_cupcakes")
                maxCupcakes = maxCupcakes and maxCupcakes:GetInt() or 3
                if chicaCupcakes[ply] >= maxCupcakes then return end
                if cooldown and cooldown.Exists and cooldown.Exists(ply, "mine") then return end

                local cupcake = ents.Create("sn_chica_cupcake")
                if not IsValid(cupcake) then return end
                cupcake:SetPos(ply:GetPos() + ply:GetUp() * 10)
                cupcake:SetAngles(ply:GetAngles())
                cupcake:SetOwner(ply)
                cupcake:Spawn()
                cupcake:Activate()
                chicaCupcakes[ply] = chicaCupcakes[ply] + 1

                if cooldown and cooldown.Set then
                    cooldown.Set(ply, "mine", 15)
                    cooldown.Send(ply, "mine")
                end
            end,
        })

        return ok
    end

    MODULE:Hook("InitPostEntity", "SN_Animatronics_InstallChicaAbility", function()
        if InstallChicaAbility() then return end
        MODULE:Timer("SN_Animatronics_ChicaAbilityRetry", 1, 10, function()
            if InstallChicaAbility() then MODULE:RemoveTimer("SN_Animatronics_ChicaAbilityRetry") end
        end)
    end)

    MODULE:Hook("PlayerSpawn", "SN_Animatronics_ClearChicaSlow", ClearChicaSlow)
    MODULE:Hook("PlayerDeath", "SN_Animatronics_ClearChicaSlowDeath", ClearChicaSlow)
    MODULE:Hook("PillRestore", "SN_Animatronics_ClearChicaSlowRestore", function(ply)
        ClearChicaSlow(ply)
        chicaCupcakes[ply] = nil
    end)

    MODULE:Hook("PlayerDeath", "SN_Animatronics_ClearChicaCupcakesDeath", function(ply)
        chicaCupcakes[ply] = nil
    end)

    MODULE:Hook("EntityRemoved", "SN_Animatronics_CupcakeCount", function(ent)
        if not IsValid(ent) or ent:GetClass() ~= "sn_chica_cupcake" then return end
        local owner = ent:GetOwner()
        if IsValid(owner) then
            chicaCupcakes[owner] = math.max((chicaCupcakes[owner] or 1) - 1, 0)
        end
    end)

    -- Plushtrap already calls highlight.ByDistance from its reload ability.
    -- Forward the same revealed survivors to Springtrap, if this Plushtrap
    -- belongs to a Springtrap player.
    MODULE:Hook("PillApply", "SN_Animatronics_LinkPlushtrap", function(plush, pill)
        if not IsValid(plush) or not IsValid(pill) or not pill.formTable or pill.formTable.name ~= "pill_plushtrap" then return end

        local closestSpringtrap
        local closestDistance
        for _, candidate in ipairs(player.GetAll()) do
            if GetPillName(candidate) == "pill_springtrap" then
                local distance = candidate:GetPos():DistToSqr(plush:GetPos())
                if not closestDistance or distance < closestDistance then
                    closestSpringtrap = candidate
                    closestDistance = distance
                end
            end
        end
        plushSpringtrap[plush] = closestSpringtrap
    end)

    MODULE:Hook("FH_HighlightByDistance", "SN_Animatronics_SharePlushReveal", function(plushOwner, _, targets)
        if GetPillName(plushOwner) ~= "pill_plushtrap" then return end
        local springtrap = plushSpringtrap[plushOwner]
        if not IsValid(springtrap) then return end
        if GetPillName(springtrap) ~= "pill_springtrap" then return end
        if not istable(targets) or #targets == 0 then return end

        highlight.Add(springtrap, targets, 5, Color(255, 80, 80))
    end)

    local function ShareNextbotReveal(springtrap)
        if not IsValid(springtrap) or GetPillName(springtrap) ~= "pill_springtrap" then return end
        local companion
        for _, ent in ipairs(ents.FindByClass("plushtrap")) do
            if IsValid(ent) and ent:GetOwner() == springtrap then
                companion = ent
                break
            end
        end
        if not IsValid(companion) or not highlight or not highlight.Add then return end

        local targets = {}
        local range = GetConVar("fh_plushtrap_highlight_range")
        local maxDistance = range and range:GetFloat() or 2200
        for _, target in ipairs(player.GetAll()) do
            if IsValid(target) and target ~= springtrap and target:Alive() and target:IsSurvivor()
            and companion:GetPos():DistToSqr(target:GetPos()) <= maxDistance * maxDistance then
                targets[#targets + 1] = target
            end
        end
        if #targets > 0 then
            -- highlight.Add expects a player as its first argument. The
            -- companion itself is a nextbot, so reveal the same targets for
            -- its Springtrap owner.
            highlight.Add(springtrap, targets, 5, Color(255, 80, 80))
        end
    end

    local nextRevealCheck = 0
    MODULE:Hook("Think", "SN_Animatronics_ShareNextbotReveal", function()
        if CurTime() < nextRevealCheck then return end
        nextRevealCheck = CurTime() + 3

        for _, plushtrap in ipairs(ents.FindByClass("plushtrap")) do
            if not IsValid(plushtrap) then continue end
            local springtrap = plushtrap:GetOwner()
            if not IsValid(springtrap) or GetPillName(springtrap) ~= "pill_springtrap" then continue end
            plushSpringtrap[plushtrap] = springtrap
            ShareNextbotReveal(springtrap)
            break
        end
    end)

    local function InstallHighlightWrapper()
        if not highlight or not isfunction(highlight.ByDistance) then return false end
        if originalHighlightByDistance then return true end
        originalHighlightByDistance = highlight.ByDistance
        highlight.ByDistance = function(ply, ent)
            local result = originalHighlightByDistance(ply, ent)
            if MODULE:IsEnabled() and GetPillName(ply) == "pill_plushtrap" then
                local springtrap = plushSpringtrap[ply]
                if IsValid(springtrap) then
                    local targets = {}
                    for _, target in ipairs(player.GetAll()) do
                        if IsValid(target) and target ~= ply and target:Alive() and target:IsSurvivor()
                        and ply:GetPos():DistToSqr(target:GetPos()) <= 2200 * 2200 then
                            targets[#targets + 1] = target
                        end
                    end
                    if #targets > 0 then highlight.Add(springtrap, targets, 5, Color(255, 80, 80)) end
                end
            end
            return result
        end
        return true
    end

    MODULE:Hook("InitPostEntity", "SN_Animatronics_InstallHighlightWrapper", function()
        if InstallHighlightWrapper() then return end
        MODULE:Timer("SN_Animatronics_HighlightRetry", 1, 10, function()
            if InstallHighlightWrapper() then MODULE:RemoveTimer("SN_Animatronics_HighlightRetry") end
        end)
    end)

    MODULE:Hook("KeyPress", "SN_Animatronics_NextbotReveal", function(ply, key)
        if key ~= IN_RELOAD or not IsValid(ply) or GetPillName(ply) ~= "pill_springtrap" then return end
        ShareNextbotReveal(ply)
    end)

    -- A rat is a spectator for the game mode, but its voice must be audible
    -- to living players in the normal proximity channel.
    MODULE:Hook("KeyPress", "SN_Animatronics_RatVoiceAbility", function(ply, key)
        if key ~= IN_ATTACK or not IsRat(ply) or not ply:Alive() then return end
        if CurTime() < (ply.SN_NextRatVoice or 0) then return end

        ply.SN_NextRatVoice = CurTime() + 30
        ratVoiceUntil[ply] = CurTime() + 8
        ply:SetNW2Float("SN_RatVoiceUntil", ratVoiceUntil[ply])
        ply:SetNW2Float("SN_RatVoiceCooldown", ply.SN_NextRatVoice)
        ply:EmitSound("rat/rat_squeak_1.wav", 75, 100, 0.8)
    end)

    local function RatVoice(listener, talker)
        if not IsRat(talker) or not IsValid(listener) or not listener:Alive() then return end
        if listener:Team() == TEAM_SPECTATOR then return end
        if CurTime() >= (ratVoiceUntil[talker] or 0) then return false, true end

        local radius = GetConVar("proximity_radius")
        local maxDistance = radius and radius:GetFloat() or 3000
        local source = IsValid(listener:GetObserverTarget()) and listener:GetObserverTarget() or listener
        if source:GetPos():DistToSqr(talker:GetPos()) <= maxDistance * maxDistance then
            return true, true
        end
        return false, true
    end

    -- Хук приближенного голоса гейммода (fh_proximity_sv) блокирует наблюдателей.
    -- Снимаем его (SuppressHook вернет его при отключении модуля) и вызываем
    -- из собственного хука после проверки "крысы".
    MODULE:Hook("PlayerCanHearPlayersVoice", "SN_Animatronics_RatVoice", function(listener, talker)
        local canHear, is3D = RatVoice(listener, talker)
        if canHear ~= nil then return canHear, is3D end
        if MODULE.OriginalProximity then return MODULE.OriginalProximity(listener, talker) end
    end)

    local function InstallRatVoice()
        if not MODULE:IsEnabled() then return end
        local list = hook.GetTable().PlayerCanHearPlayersVoice or {}
        if isfunction(list.fh_proximity_sv) then
            MODULE.OriginalProximity = list.fh_proximity_sv
            MODULE:SuppressHook("PlayerCanHearPlayersVoice", "fh_proximity_sv")
        end
    end

    timer.Simple(0, InstallRatVoice)
    MODULE:OnEnabled(InstallRatVoice)

    -- Возвращаем исходную способность Чики
    MODULE:OnDisabled(function()
        if MODULE.OriginalChicaAttack2 and pills and pills.editPillTable then
            pcall(pills.editPillTable, "pill_wchica2", "attack2", MODULE.OriginalChicaAttack2)
        end
    end)

    MODULE:Hook("PlayerDisconnected", "SN_Animatronics_ClearSlowDisconnect", function(ply)
        slowTokens[ply] = nil
        plushSpringtrap[ply] = nil
        ratVoiceUntil[ply] = nil
        chicaCupcakes[ply] = nil
        if IsValid(ply) then
            ply:SetNW2Float("SN_RatVoiceUntil", 0)
            ply:SetNW2Float("SN_RatVoiceCooldown", 0)
        end
    end)
end

if CLIENT then
    -- Keep the gamemode's "you saw an animatronic" sound disabled for rats.
    MODULE:Hook("FH_OnSeeAnimatronic", "SN_Animatronics_RatSeeException", function(_, animEnt)
        if not IsValid(animEnt) then return end
        local owner = animEnt.GetPillUser and animEnt:GetPillUser()
        if IsRat(owner) then return false end
    end)

    MODULE:Hook("PlayerStartVoice", "SN_Animatronics_RatVoiceVolume", function(ply)
        if IsRat(ply) then ply:SetVoiceVolumeScale(0.65) end
    end)

    MODULE:Hook("PlayerEndVoice", "SN_Animatronics_RatVoiceVolumeReset", function(ply)
        if IsRat(ply) then ply:SetVoiceVolumeScale(1) end
    end)

    MODULE:Hook("Think", "SN_Animatronics_RatVoiceAbilityHUD", function()
        local ply = LocalPlayer()
        if not IsRat(ply) or not currentAbilities then
            if currentAbilities then currentAbilities["ГОЛОС КРЫСЫ"] = nil end
            return
        end

        local activeUntil = ply:GetNW2Float("SN_RatVoiceUntil", 0)
        local cooldownUntil = ply:GetNW2Float("SN_RatVoiceCooldown", 0)
        local duration = math.max(0, cooldownUntil - CurTime())
        local active = activeUntil > CurTime()

        currentAbilities["ГОЛОС КРЫСЫ"] = {
            text = "LMB",
            endTime = active and activeUntil or cooldownUntil,
            maxTime = active and 8 or 30,
            tokens = -1,
            hidden = false,
            color = function()
                if active then return Color(100, 220, 140) end
                if duration > 0 then return Color(150, 150, 150) end
                return Color(200, 130, 70)
            end,
        }
    end)
end
