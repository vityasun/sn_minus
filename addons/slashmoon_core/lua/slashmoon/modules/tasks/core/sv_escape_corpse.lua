-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

if not SERVER then return end

local function SpawnEscapedCorpse(ply)
    if not IsValid(ply) then return end
    if not ply:GetNW2Bool("fhi_escaped", false) and not ply.SN_TasksEscapedLastRound then return end

    -- FH removes its own CreateEntityRagdoll result. This corpse is spawned
    -- directly and is therefore independent of the gamemode ragdoll hook.
    if IsValid(ply.SN_TasksEscapedCorpse) then return end

    local corpse = ents.Create("prop_ragdoll")
    if not IsValid(corpse) then return end
    corpse:SetModel(ply:GetModel())
    corpse:SetPos(ply:GetPos())
    corpse:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    corpse:SetSkin(ply:GetSkin())
    corpse:SetColor(ply:GetColor())
    corpse:SetMaterial(ply:GetMaterial())
    corpse:SetNW2Bool("SN_EscapedCorpse", true)
    corpse:Spawn()
    corpse:Activate()
    corpse:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    ply.SN_TasksEscapedCorpse = corpse

    timer.Simple(0, function()
        if not IsValid(corpse) then return end
        for i = 0, corpse:GetPhysicsObjectCount() - 1 do
            local phys = corpse:GetPhysicsObjectNum(i)
            if IsValid(phys) then phys:Wake() end
        end
    end)
end

MODULE:Hook("SN_Player_Escaped", "SN_Tasks_MarkEscapedPlayer", function(ply)
    if IsValid(ply) then ply.SN_TasksEscapedLastRound = true end
end)

MODULE:Hook("PlayerDeath", "SN_Tasks_PreserveEscapedCorpse", SpawnEscapedCorpse)

local function CleanupEscapedCorpses()
    for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
        if ent:GetNW2Bool("SN_EscapedCorpse", false) then ent:Remove() end
    end
end

MODULE:Hook("SN_Game_RoundEnd", "SN_Tasks_CleanupEscapedCorpses", CleanupEscapedCorpses)
MODULE:Hook("PostCleanupMap", "SN_Tasks_CleanupEscapedCorpsesMap", CleanupEscapedCorpses)

MODULE:Hook("SN_Game_RoundStart", "SN_Tasks_ClearEscapedMarkers", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply.SN_TasksEscapedLastRound = nil
            ply.SN_TasksEscapedCorpse = nil
        end
    end
end)
