-- Written for: SlashMoon. By: VIKA & Ronni

SWEP.Base = "weapon_base"
SWEP.PrintName = "Сканер расследования"
SWEP.Category = "SN Tasks"
SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.Slot = 1
SWEP.SlotPos = 6
SWEP.ViewModel = "models/weapons/c_entity_listener.mdl"
SWEP.WorldModel = "models/weapons/w_entity_listener.mdl"
SWEP.UseHands = true
SWEP.Primary = { Ammo = "none", ClipSize = -1, DefaultClip = -1, Automatic = false }
SWEP.Secondary = { Ammo = "none", ClipSize = -1, DefaultClip = -1, Automatic = false }
SWEP.AllowDrop = true

function SWEP:Initialize()
    self:SetHoldType("revolver")
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.25)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.25)
end

function SWEP:Reload()
    self:SetNextPrimaryFire(CurTime() + 0.5)
    if CLIENT then
        if CurTime() < (self.NextReportRequest or 0) then return end
        self.NextReportRequest = CurTime() + 0.5
        net.Start("SN_Investigation_ReportData")
        net.SendToServer()
    end
end
