-- Written for: SlashMoon. By: VIKA & Ronni

SWEP.Base = "weapon_base"
SWEP.PrintName = "Планшет отчёта"
SWEP.Category = "SN Tasks"
SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.Slot = 5
SWEP.SlotPos = 8
SWEP.ViewModel = "models/vondaram/c_tablet.mdl"
SWEP.WorldModel = "models/vondaram/w_tablet.mdl"
SWEP.UseHands = true
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Primary = { Ammo = "none", ClipSize = -1, DefaultClip = -1, Automatic = false }
SWEP.Secondary = { Ammo = "none", ClipSize = -1, DefaultClip = -1, Automatic = false }

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "FullView")
end

function SWEP:Initialize()
    self:SetHoldType("slam")
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.2)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:Reload()
    self:SetNextPrimaryFire(CurTime() + 0.2)
    if SERVER then
        self:SetFullView(not self:GetFullView())
    end
end
