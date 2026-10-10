-- Written for: SlashMoon. By: VIKA & Ronni

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/Items/item_item_crate.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

local function TakeItem(ply, baseClass)
    for i, entry in ipairs(ply.SN_Backpack or {}) do
        local parsed = SlashMoon.Tasks.ParseItemEntry(entry)
        if parsed.baseClass ~= baseClass then continue end
        if parsed.count > 1 then
            ply.SN_Backpack[i] = SlashMoon.Tasks.MakeItemEntry(baseClass, parsed.count - 1)
        else
            table.remove(ply.SN_Backpack, i)
        end
        return true
    end
    return false
end

function ENT:Use(activator)
    if self:GetNW2Bool("SN_Delivered", false) then return end
    if not IsValid(activator) or not activator:IsPlayer() or not SlashMoon.Tasks.Game.IsSurvivor(activator) then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 120 * 120 then return end
    if not SlashMoon.Security.CheckRateLimit(activator, "delivery_use", 0.5) then return end

    local itemClass = self:GetNW2String("SN_DeliveryItem", "")
    if itemClass == "" or not TakeItem(activator, itemClass) then
        SlashMoon.Tasks.SendLocalizedChat(activator, "sn.task.delivery.missing", SlashMoon.Tasks.GetItemName(itemClass))
        return
    end

    local delivered = self:GetNW2Int("SN_DeliveredCount", 0) + 1
    local required = math.max(1, self:GetNW2Int("SN_DeliveryRequired", 1))
    self:SetNW2Int("SN_DeliveredCount", delivered)
    if delivered >= required then
        self:SetNW2Bool("SN_Delivered", true)
        self:SetColor(Color(80, 220, 100))
    end
    activator:EmitSound("buttons/button14.wav")
    SlashMoon.Tasks.SyncInventory(activator)
    if delivered >= required then
        SlashMoon.Tasks.SendLocalizedChat(activator, "sn.task.delivery.complete")
    else
        SlashMoon.Tasks.SendLocalizedChat(activator, "sn.task.delivery.progress", delivered, required)
    end
end
