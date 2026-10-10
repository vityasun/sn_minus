-- Written for: SlashMoon. By: VIKA & Ronni

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_junk/gascan001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE) -- Нативный подбор на E от движка GMod

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then 
        phys:Wake() 
        phys:SetMass(15)
    end

    if not self.SecretFuel then
        self.SecretFuel = math.random(50, 78)
    end
    self:SetNW2Bool("SN_UnknownFuel", true)
end

function ENT:SetKnownFuel(fuel)
    self.SecretFuel = fuel
    self:SetNW2Int("SN_Fuel", fuel)
    self:SetNW2Bool("SN_UnknownFuel", false)
end

-- === НАТИВНЫЙ ПОДБОР НА E ===
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end
    if not SlashMoon.Tasks.Game.IsSurvivor(activator) then return end
    if activator:GetPos():Distance(self:GetPos()) > 150 then return end

    if (self.NextUse or 0) > CurTime() then return end
    self.NextUse = CurTime() + 0.5

    -- Получаем топливо (тайное или раскрытое)
    local isUnknown = self:GetNW2Bool("SN_UnknownFuel", true)
    local fuel = isUnknown and (self.SecretFuel or math.random(50, 78)) or self:GetNW2Int("SN_Fuel", 50)

    -- Помещаем в рюкзак предметом со значением топлива
    local itemString = "weapon_gascan:" .. fuel
    local added = SlashMoon.Tasks.GiveItem(activator, itemString)
    if not added then return end

    hook.Run("SN_Item_PickedUp", activator, itemString)
    SlashMoon.Debug("[sn_gascan] " .. activator:Nick() .. " подобрал канистру (" .. fuel .. "%)")

    self:Remove()
end
