-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Gas Can Weapon (Server + Localized + Anti-Spam)
-- ========================================================
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local STATE_IDLE     = 0
local STATE_STARTING = 1
local STATE_POURING  = 2

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self.GasState = STATE_IDLE
    self.TransTime = 0
    self.NextFuelTick = 0
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_DRAW)
    self.GasState = STATE_IDLE
    return true
end

function SWEP:Holster()
    self.GasState = STATE_IDLE
    return true
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.1)
end

function SWEP:Think()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    local state = self.GasState or STATE_IDLE

    if ply:KeyDown(IN_ATTACK) then
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity

        if IsValid(ent) and ent:GetClass() == "sn_generator" and not ent:GetNW2Bool("SN_Fueled", false) and ply:GetPos():Distance(ent:GetPos()) <= 130 then

            if state == STATE_IDLE then
                self:SendWeaponAnim(ACT_VM_HOLSTER)
                self.GasState = STATE_STARTING
                self.TransTime = CurTime() + 0.4
                return true
            elseif state == STATE_STARTING then
                if CurTime() >= self.TransTime then
                    self:SendWeaponAnim(ACT_VM_FIDGET)
                    self.GasState = STATE_POURING
                    return true
                end
            elseif state == STATE_POURING then
                if CurTime() >= (self.NextFuelTick or 0) then
                    self.NextFuelTick = CurTime() + 0.1
                    self:DoFuelTick(ply, ent)
                end
            end
        else
            if state ~= STATE_IDLE then
                self:SendWeaponAnim(ACT_VM_IDLE)
                self.GasState = STATE_IDLE
                return true
            end
        end
    else
        if state ~= STATE_IDLE then
            self:SendWeaponAnim(ACT_VM_IDLE)
            self.GasState = STATE_IDLE
            return true
        end
    end
end

function SWEP:DoFuelTick(ply, ent)
    local currentFuel = self:GetNW2Int("SN_Fuel", 0)
    if currentFuel <= 0 then
        SlashMoon.Tasks.SendLocalizedChat(ply, "sn.inv.gascan_empty")
        ply:StripWeapon("weapon_gascan")
        return
    end

    local genFuel = ent:GetNW2Int("SN_Fuel", 0)
    local pour = math.min(1, currentFuel, 100 - genFuel)

    if pour > 0 then
        local newFuel = currentFuel - pour
        self:SetNW2Int("SN_Fuel", newFuel)
        ent:SetNW2Int("SN_Fuel", genFuel + pour)

        -- Используем дельта-синхронизацию вместо полной
        for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
            if ply.SN_Hotbar and string.StartWith(ply.SN_Hotbar[i] or "", "weapon_gascan") then
                local oldValue = ply.SN_Hotbar[i]
                ply.SN_Hotbar[i] = "weapon_gascan:" .. newFuel

                -- Дельта-апдейт вместо полной синхронизации (оптимизация!)
                if SlashMoon.Tasks.SyncInventoryDelta then
                    SlashMoon.Tasks.SyncInventoryDelta(ply, {
                        { type = "hotbar", slot = i, value = "weapon_gascan:" .. newFuel }
                    })
                else
                    SlashMoon.Tasks.SyncInventory(ply)
                end
                break
            end
        end

        if genFuel + pour >= 100 then
            ent:SetNW2Bool("SN_Fueled", true)
            ent:EmitSound("ambient/machines/generator1_start.wav", 80, 100)
            self:SendWeaponAnim(ACT_VM_IDLE)
            self.GasState = STATE_IDLE
        end
    end

    if currentFuel - pour <= 0 then
        SlashMoon.Tasks.SendLocalizedChat(ply, "sn.inv.gascan_empty")
        ply:StripWeapon("weapon_gascan")
    end
end
