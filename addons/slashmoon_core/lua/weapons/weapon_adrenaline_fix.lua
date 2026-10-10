-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

AddCSLuaFile()

SWEP.PrintName = "#weapon_adrenaline"
SWEP.Author = "Valve"

if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/adrenaline" )
end

SWEP.ViewModel = "models/items/v_l4d2adren.mdl"
SWEP.WorldModel = "models/items/w_l4d2adren.mdl"
SWEP.UseHands = true
SWEP.ViewModelFOV = 56
SWEP.HoldType = "slam"

SWEP.DrawWeaponInfoBox	= false
SWEP.BounceWeaponIcon	= false 
SWEP.Spawnable = true

SWEP.Slot = 2
SWEP.SlotPos = 1
SWEP.DrawCrosshair = false
SWEP.DrawAmmo = false
SWEP.Weight = 30
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = true

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = false
SWEP.Primary.Sound = Sound("weapons/adren/adrenuse.wav")
SWEP.Primary.Delay = 0.2

SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    if self:Clip1() <= 0 then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    owner:SetAnimation(PLAYER_ATTACK1)
    self:EmitSound(self.Primary.Sound)

    self:SetNextPrimaryFire(CurTime() + 1)
    self:SetClip1(self:Clip1() - 1)

    if SERVER then
        local heal = math.random(4,7)
        local armor = 15
		
		timer.Simple(0.59, function()
			
			if IsValid(owner) and IsValid(self) then
		
				for i = 1, heal do
					timer.Simple(0 + i/1.5, function()
						if IsValid(owner) and owner:Health() < 100 then
							owner:SetHealth(owner:Health() + 1)
						end
					end) 
				end
				
				for i = 1, armor do
					timer.Simple(0 + i/15, function()
						if IsValid(owner) and owner:Armor() < 100 then
							owner:SetArmor(owner:Armor() + 1)
						end
					end) 
				end
				
				owner.FH_SpeedModifier = 1.8
				
				local trail = owner._adrenTrail or util.SpriteTrail(owner, owner:LookupAttachment( "chest" ), Color(0, 169, 255, 200), true, 32, 0, 1, 1 / ( ( 32 + 0 ) * 0.5 ), "trails/physbeam")
				
				owner._adrenTrail = trail
			end
		end)
		
		local timerName = "adren_trail_remove" .. owner:EntIndex()
		
		if timer.Exists(timerName) then
			MODULE:RemoveTimer(timerName)
		end
		
		timer.Simple(8, function()
			if IsValid(owner) then
				owner.FH_SpeedModifier = 1
			end
		end)
		
		MODULE:Timer(timerName, 8, 1, function()
			if IsValid(owner) then
				local trail = owner._adrenTrail
				
				if IsValid(trail) then
					trail:Remove()
					owner._adrenTrail = nil
				end
			end
		end)

        timer.Simple(1, function()
            if IsValid(owner) and IsValid(self) then
                owner:StripWeapon(self:GetClass())
            end
        end)
    end
end

if SERVER then
	local function trailremover(ply)
		local trail = ply._adrenTrail
		
		if IsValid(trail) then
			trail:Remove()
			ply._adrenTrail = nil
		end
	end

	MODULE:Hook("PlayerDeath", "adren_notrail_death", trailremover)
	MODULE:Hook("PlayerDisconnect", "adren_notrail_death", trailremover)
end

-- спиздил с дефибриллятора
function SWEP:SecondaryAttack()
    
	self.Owner:LagCompensation( true )
	
	local tr = util.TraceLine( {
	start = self.Owner:GetShootPos(),
	endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 65,
	filter = self.Owner,
	mask = MASK_SHOT_HULL,
	} )
	
	if !IsValid( tr.Entity ) then
		tr = util.TraceHull( {
		start = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 10,
		endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 65,
		filter = self.Owner,
		mins = Vector( -20, -20, -12 ),
		maxs = Vector( 20, 20, 12 ),
		mask = MASK_SHOT_HULL,
		} )
	end
	
	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence( vm:LookupSequence( "melee" ) )
	--self.Owner:SetAnimation( PLAYER_ATTACK1 )
	
	if SERVER then
		local force = self.Owner:GetAimVector() * 500
		local dmginfo = DamageInfo()
		dmginfo:SetAttacker(self.Owner)
		dmginfo:SetInflictor(self)
		dmginfo:SetDamagePosition(tr.HitPos)
		dmginfo:SetDamageType(DMG_SLASH) 
		dmginfo:SetDamage(5)
			
		if tr.Hit and (tr.Entity:IsPlayer() || tr.Entity:IsNPC() || tr.Entity:GetClass() == "prop_ragdoll") then
			self.Owner:EmitSound( "player/survivor/hit/rifle_swing_hit_infected" .. math.random(7, 12) .. ".wav")
			dmginfo:SetDamageForce(force)
			SuppressHostEvents( NULL )
			tr.Entity:TakeDamageInfo( dmginfo )
			SuppressHostEvents( self.Owner )
			tr.Entity:SetVelocity(Vector(force.x,force.y,10))
		elseif tr.Hit then
			self.Owner:EmitSound( "player/survivor/hit/rifle_swing_hit_world.wav")
			if IsValid(tr.Entity) then
				dmginfo:SetDamageForce(force/100)
				SuppressHostEvents( NULL )
				tr.Entity:TakeDamageInfo( dmginfo )
				SuppressHostEvents( self.Owner )
			end
		else
			self.Owner:EmitSound( "weapons/bat/bat_swing_miss" .. math.random(1, 2) .. ".wav")
		end
	else -- CLIENT
		self.Owner:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE, true )
	end
	
	self:SetNextSecondaryFire( CurTime() + self.Primary.Delay + 0.7 )
	
	self.Idle = 0
	self.IdleTimer = CurTime() + self.Owner:GetViewModel():SequenceDuration()
	
	self.Owner:LagCompensation( false )
end

function SWEP:Reload()
    return
end
