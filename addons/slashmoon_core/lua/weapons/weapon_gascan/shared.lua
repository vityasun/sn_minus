-- Written for: SlashMoon. By: VIKA & Ronni

SWEP.Base = "weapon_base"
SWEP.PrintName = "Канистра"
SWEP.Author = "SN Tasks"
SWEP.Category = "SN Tasks"
SWEP.Spawnable = false

SWEP.ViewModel = "models/fh_minus/weapon/v_gascan.mdl"
SWEP.WorldModel = "models/fh_minus/weapon/w_gascan.mdl"
SWEP.HoldType = "slam"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
-- Continuous refueling is handled by SWEP:Think while IN_ATTACK is held.
-- Keeping weapon_base automatic here causes repeated dry-fire sounds.
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end
