-- Written for: SlashMoon. By: VIKA & Ronni

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    if self:GetModel() == "" then
        self:SetModel("models/Humans/Group01/male_07.mdl")
    end
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:SetUseType(SIMPLE_USE)
    self:SetNW2Bool("SN_InvestigationCorpse", true)
    self:SetNW2Bool("SN_InvestigationSearched", false)

    timer.Simple(0, function()
        if not IsValid(self) then return end
        local physicsCount = self:GetPhysicsObjectCount()
        for index = 0, physicsCount - 1 do
            local phys = self:GetPhysicsObjectNum(index)
            if IsValid(phys) then
                phys:EnableMotion(true)
                phys:Wake()
            end
        end

        timer.Simple(1.5, function()
            if not IsValid(self) then return end
            for index = 0, self:GetPhysicsObjectCount() - 1 do
                local phys = self:GetPhysicsObjectNum(index)
                if IsValid(phys) then
                    phys:EnableMotion(false)
                    phys:Sleep()
                end
            end
            self:SetMoveType(MOVETYPE_NONE)
        end)
    end)
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    if not ply:HasWeapon("sn_corpse_scanner") then return end
    if self:GetNW2Bool("SN_InvestigationSearched", false) then return end

    self:SetNW2Bool("SN_InvestigationSearched", true)
    local caseID = self:GetNW2String("SN_InvestigationCase", "")
    if self:GetNW2Bool("SN_InvestigationReal", false) and caseID ~= "" then
        SlashMoon.Tasks.GiveItem(ply, "sn_investigation_passport:" .. caseID)
    else
        local items = SlashMoon.Tasks.Investigation and SlashMoon.Tasks.Investigation.PersonalItems or { "sn_investigation_personal_item" }
        SlashMoon.Tasks.GiveItem(ply, items[math.random(#items)])
    end
    ply:EmitSound("items/ammo_pickup.wav")
end
