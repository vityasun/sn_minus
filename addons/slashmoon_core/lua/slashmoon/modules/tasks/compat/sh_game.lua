-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Game = SlashMoon.Tasks.Game or {}

local Game = SlashMoon.Tasks.Game
local validModes = { fh = true, standalone = true }

function Game.GetMode()
    local mode = SlashMoon.Tasks.Config and SlashMoon.Tasks.Config.CompatibilityMode or "fh"
    return validModes[mode] and mode or "fh"
end

function Game.IsFH()
    return Game.GetMode() == "fh"
end

function Game.IsStandalone()
    return Game.GetMode() == "standalone"
end

function Game.GetTeam(role)
    local teams = SlashMoon.Tasks.Config and SlashMoon.Tasks.Config.Teams or {}
    if role == "spectator" then return teams.spectator or TEAM_SPECTATOR end
    return teams[role]
end

function Game.IsEditor(ply)
    return IsValid(ply) and ply:Team() == Game.GetTeam("editor")
end

function Game.IsSpectator(ply)
    return IsValid(ply) and ply:Team() == Game.GetTeam("spectator")
end

function Game.IsSurvivorTeam(ply)
    return IsValid(ply) and ply:Team() == Game.GetTeam("survivor")
end

function Game.IsSurvivor(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if Game.IsFH() and ply.IsSurvivor then return ply:IsSurvivor() end
    return Game.IsSurvivorTeam(ply) and not ply:GetNW2Bool("sn_escaped", ply:GetNW2Bool("fhi_escaped", false))
end

function Game.IsAnimatronic(ply)
    if not IsValid(ply) then return false end
    if Game.IsFH() and ply.IsAnimatronic then return ply:IsAnimatronic() end
    return ply:Team() == Game.GetTeam("animatronic")
end

function Game.CanLootCorpse(ply)
    if not IsValid(ply) or not ply:Alive() or not Game.IsSurvivorTeam(ply) then return false end
    if Game.IsEditor(ply) then return false end
    if ply:GetNW2Bool("sn_escaped", ply:GetNW2Bool("fhi_escaped", false)) then return false end
    if ply:GetNW2Bool("KillerMaskEquiped", false) then return false end
    return true
end

function Game.GetSurvivors()
    local result = {}
    if SERVER and Game.IsFH() and istable(survivors) then
        for ply in pairs(survivors) do
            if IsValid(ply) then table.insert(result, ply) end
        end
        return result
    end
    for _, ply in ipairs(player.GetAll()) do
        if Game.IsSurvivorTeam(ply) and not ply:GetNW2Bool("sn_escaped", ply:GetNW2Bool("fhi_escaped", false)) then
            table.insert(result, ply)
        end
    end
    return result
end

function Game.GetAnimatronics()
    local result = {}
    if SERVER and Game.IsFH() and istable(animatronics) then
        for ply in pairs(animatronics) do
            if IsValid(ply) then table.insert(result, ply) end
        end
        return result
    end
    for _, ply in ipairs(player.GetAll()) do
        if Game.IsAnimatronic(ply) then table.insert(result, ply) end
    end
    return result
end

if SERVER then
    function Game.IsRoundActive()
        if Game.IsFH() then return isGameOn == true and roundEnding ~= true end
        return SlashMoon.Rounds.GetState and SlashMoon.Rounds.GetState() == SlashMoon.Rounds.STATE_ACTIVE
    end

    function Game.IsRoundPaused()
        return Game.IsFH() and roundPaused == true or false
    end

    function Game.RemoveSurvivor(ply)
        if Game.IsFH() and istable(survivors) then survivors[ply] = nil end
    end

    function Game.SetSpectator(ply, observerMode)
        if not IsValid(ply) then return end
        ply:Spectate(observerMode or OBS_MODE_ROAMING)
        local teamID = Game.GetTeam("spectator")
        if teamID then ply:SetTeam(teamID) end
    end

    function Game.EndRound(survivorsWon, duration, reason)
        if Game.IsFH() then
            if endRound then endRound(not survivorsWon, duration or 8) end
        elseif SlashMoon.Rounds.Finish then
            SlashMoon.Rounds.Finish(survivorsWon, reason)
        end
    end

    MODULE:Hook("fh_poststartgame", "SN_Game_FH_RoundStart", function(...)
        if Game.IsFH() then hook.Run("SN_Game_RoundStart", ...) end
    end)

    MODULE:Hook("fh_postendgame", "SN_Game_FH_RoundEnd", function(...)
        if Game.IsFH() then hook.Run("SN_Game_RoundEnd", ...) end
    end)

    MODULE:Hook("fh_createragdoll", "SN_Game_FH_Ragdoll", function(ply, rag)
        if Game.IsFH() then hook.Run("SN_Game_RagdollCreated", ply, rag) end
    end)

    MODULE:Hook("CreateEntityRagdoll", "SN_Game_Standalone_Ragdoll", function(ent, rag)
        if Game.IsStandalone() and IsValid(ent) and ent:IsPlayer() then
            hook.Run("SN_Game_RagdollCreated", ent, rag)
        end
    end)
end
