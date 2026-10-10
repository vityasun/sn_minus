-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("empty_hands")

SWEP.Name					=  "Empty Hands"
SWEP.HoldType				=  "normal"
SWEP.Category				=  "Other"

SWEP.Spawnable				=  true
SWEP.AdminSpawnable			=  true

SWEP.Primary.Automatic		=  true

SWEP.Weight = 5

if CLIENT then
    MODULE.NextTip = MODULE.NextTip or 0
end

function SWEP:Deploy()
    if CLIENT and IsFirstTimePredicted() then
        if CurTime() > MODULE.NextTip then
            MODULE.NextTip = CurTime() + 480
 
            chat.AddText(SlashMoon.UI.Colors.Theme, "[Подсказка] ", SlashMoon.UI.Colors.Text, "Нажмите R, чтобы скрыть или показать прицел.")
			chat.AddText(SlashMoon.UI.Colors.Theme, "[Подсказка] ", SlashMoon.UI.Colors.Text, "Нажмите ALT+ЛКМ, чтобы поставить", SlashMoon.UI.Colors.Hover, " метку.")
        end
    end
    
    return true -- Разрешаем достать оружие
end

function SWEP:CanPrimaryAttack()
	return true
end

function SWEP:CanSecondaryAttack()
	return true
end

function SWEP:CanReload()
	return true
end

function SWEP:Initialize()
	self:SetHoldType( self.HoldType )
	
	self.Time = 0
	self.Range = 120
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	local Pos = ply:GetShootPos()
	local Aim = ply:GetAimVector()

	local Tr = util.TraceLine{
		start = Pos,
		endpos = Pos + Aim * self.Range,
		filter = player.GetAll(),
	}

	local HitEnt = Tr.Entity
	
	if self.Drag then
		HitEnt = self.Drag.Entity
	else
		if !IsValid(HitEnt) or HitEnt:GetMoveType() ~= MOVETYPE_VPHYSICS or
			HitEnt:IsVehicle() or HitEnt:GetNWBool("NoDrag", false) or
			HitEnt.BlockDrag ~= nil or
			IsValid(HitEnt:GetParent()) then
			return
		end
		
		if HitEnt:GetVelocity():Length2D() > 100 then
			return
		end
		
		if SERVER and HitEnt:IsPlayerHolding() then
			return
		end

		local Phys = HitEnt:GetPhysicsObject()
		if not IsValid(Phys) then return end
		
		if ply:GetGroundEntity() == HitEnt then
			return
		end

		self.Drag = {
			OffPos = HitEnt:WorldToLocal(Tr.HitPos),
			Entity = HitEnt,
			Fraction = Tr.Fraction,
		}
		
		if IsValid(HitEnt.IsBeingDragged) and HitEnt.IsBeingDragged ~= ply then
			local wep = HitEnt.IsBeingDragged:GetActiveWeapon()
			
			if IsValid(wep) and wep:GetClass() == self:GetClass() then
				if wep.StopDrag then wep:StopDrag() end
			end
		end
		
		HitEnt.IsBeingDragged = ply
	end

	if CLIENT or not IsValid(HitEnt) then return end

	local Phys = HitEnt:GetPhysicsObject()
	if IsValid(Phys) then
		local Pos2 = Pos + Aim * self.Range * self.Drag.Fraction
		local OffPos = HitEnt:LocalToWorld(self.Drag.OffPos)
		local Dif = Pos2 - OffPos

		local mass = Phys:GetMass()
		local forceMult = math.max(10, 500 - mass)

		if ply:GetGroundEntity() == HitEnt then
			hook.Run("OnPlayerPhysicsDrop", ply, self.Drag.Entity, false)
			self.Drag = nil
			return
		end

		local Nom = (Dif:GetNormal() * math.min(1, Dif:Length() / 100) * forceMult - Phys:GetVelocity()) * mass
		Phys:ApplyForceOffset(Nom, OffPos)
		Phys:AddAngleVelocity(-Phys:GetAngleVelocity() / 4)
	end
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end

	if game.SinglePlayer() then
		self:SetShouldDrawCrosshair( not self:GetShouldDrawCrosshair() )
	elseif CLIENT then
		self.CrosshairPredicted = not self.CrosshairPredicted
	end

	self:SetNextSecondaryFire( CurTime() + 0.25 )

	return true
end

function SWEP:Reload()
	-- Защита от спама (чтобы прицел не мигал 100 раз в секунду)
	if not IsFirstTimePredicted() then return end
	if CurTime() < (self.NextReload or 0) then return end
	self.NextReload = CurTime() + 0.3

	if CLIENT then
		local cv = GetConVar("emptyhands_showcrosshair")
		if cv then
			cv:SetBool(not cv:GetBool())
		end
	end
end

function SWEP:SetupDataTables( )
	self:NetworkVar( "Bool", 0, "IsDeployed" )
	self:NetworkVar( "Bool", 1, "ShouldDrawCrosshair" )
end

function SWEP:StopDrag()
    local ply = self:GetOwner()
	if self.Drag and IsValid(self.Drag.Entity) then
		if !IsValid(self.Drag.Entity.IsBeingDragged) or self.Drag.Entity.IsBeingDragged == self:GetOwner() then
			self.Drag.Entity.IsBeingDragged = nil
		end
		hook.Run("OnPlayerPhysicsDrop", ply, self.Drag.Entity, false)
	end
	self.Drag = nil
end

function SWEP:Think()
    local ply = self:GetOwner()
    if self.Drag and (not ply:KeyDown(IN_ATTACK) or not IsValid(self.Drag.Entity)) then
		self:StopDrag()
    end
end

function SWEP:ShouldDrawViewModel()
	return false
end

function SWEP:DrawWorldModel()
end

MODULE:Hook("OnPlayerPhysicsDrop", "emptyhands_prop_damage", function(ply, ent)
	ent._ImpulseOwner = ply
	
	local timerName = "reset_impulse_owner" .. ent:EntIndex()
	
	if timer.Exists(timerName) then
		MODULE:RemoveTimer(timerName)
	end
	
	MODULE:Timer(timerName, 2, 1, function()
		if IsValid(ent) and ent._ImpulseOwner then
			ent._ImpulseOwner = nil
		end
	end)
end)

MODULE:Hook("EntityTakeDamage", "prevent_empty_hands_prop_damage", function(ent, dmg)
    local inflictor = dmg:GetInflictor()

    if IsValid(inflictor) then
		local dragger = inflictor.IsBeingDragged 
		if IsValid(dragger) and ent ~= dragger then
			dmg:SetAttacker(dragger)
		end
    end
end)

if CLIENT then
	local x, y = ScrW() /2, ScrH() /2
	local MainCol = Color( 255, 255, 255, 255 )
	local Col = Color( 255, 255, 255, 255 )

	function SWEP:DrawHUD()
		local ply = self:GetOwner()
		if IsValid( ply:GetVehicle() ) then return end
		local Pos = ply:GetShootPos()
		local Aim = ply:GetAimVector()

		local Tr = util.TraceLine{
			start = Pos,
			endpos = Pos +Aim *self.Range,
			filter = player.GetAll(),
		}

		local HitEnt = Tr.Entity
		if IsValid( HitEnt ) and HitEnt:GetMoveType() == MOVETYPE_VPHYSICS and
			not self.rDag and
			not HitEnt:IsVehicle() and
			not IsValid( HitEnt:GetParent() ) and
			not HitEnt:GetNWBool( "NoDrag", false ) then

			self.Time = math.min( 1, self.Time +2 *FrameTime() )
		else
			self.Time = math.max( 0, self.Time -2 *FrameTime() )
		end

		if self.Time > 0 then
			Col.a = MainCol.a *self.Time

			draw.SimpleText(
				"Drag",
				"DermaLarge",
				x,
				y,
				Col,
				TEXT_ALIGN_CENTER
			)
		end

		if self.Drag and IsValid( self.Drag.Entity ) then
			local Pos2 = Pos +Aim *100 *self.Drag.Fraction
			local OffPos = self.Drag.Entity:LocalToWorld( self.Drag.OffPos )
			local Dif = Pos2 -OffPos

			local A = OffPos:ToScreen()
			local B = Pos2:ToScreen()

			surface.DrawRect( A.x -2, A.y -2, 4, 4, MainCol )
			surface.DrawRect( B.x -2, B.y -2, 4, 4, MainCol )
			surface.DrawLine( A.x, A.y, B.x, B.y, MainCol )
		end
	end
end
