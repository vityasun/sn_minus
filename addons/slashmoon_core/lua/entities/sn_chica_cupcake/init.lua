-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("animatronics")

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("fh_remove_hud_mine")

util.PrecacheModel("models/team vr/cupcake.mdl")

local nearPlayers = {}

function ENT:Initialize()
    self:SetModel("models/team vr/cupcake.mdl")
	self:SetModelScale(0.4, 0)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	
	--self:SetColor(Color(255, 255, 255, 100))
	self:SetRenderMode( RENDERMODE_TRANSCOLOR )
	
    local phys = self:GetPhysicsObject()
	
    if phys:IsValid() then
        phys:Wake()
    end

    self:SetHealth(10)

    MODULE:Timer("CheckPlayersTimer_" .. self:EntIndex(), 0.5, 0, function()
        if !IsValid(self) then return end
        self:CheckForPlayers()
    end)
end

function ENT:OnRemove()
    MODULE:RemoveTimer("CheckPlayersTimer_" .. self:EntIndex())
	self:EmitExplosion()
	
	net.Start('fh_remove_hud_mine')
	net.Send(self:GetOwner())
	
	self:CheckForPlayers()
end

function ENT:CheckForPlayers()
	local owner = self:GetOwner()
    local pos = self:GetPos()
    local radius = 200
	local totalPlayers = {}
	
	local outworlded = getOutworldVictims()

    for _, ply in pairs(ents.FindInSphere(pos, radius)) do
        if ply:IsPlayer() and ply ~= owner and ply:Alive() and ply:IsSurvivor() and !table.HasValue(nearPlayers, ply) and !outworlded[ply] then
			local trace = util.TraceLine({
				start = pos,
				endpos = ply:GetPos(),
				filter = function(ent)
					return ent != ignorePlayer and !ent:IsPlayer() and !ent:IsNPC()
				end,
				mask = MASK_PLAYERSOLID_BRUSHONLY
			})
			
			if trace.Hit then return end
			
			net.Start("fh_play_sound")
			net.WriteString("vision_affected_cake.wav")
			net.Send(ply)
			
			table.insert(nearPlayers, ply)
			table.insert(totalPlayers, ply)
			
            ply.FH_SpeedModifier = 0.5
			ply._cupcakeAffected = true
			stats.Add(ply, "got_slowed", 1)
			
			if IsValid(owner) then
				stats.Add(owner, "slowed_using_cupcake", 1)
			
				cooldown.Set(owner, "mine", 10)
				cooldown.Send(owner, "mine")
			end
            
            timer.Simple(7, function()
                if IsValid(ply) then
					ply.FH_SpeedModifier = 1
					ply._cupcakeAffected = false
                end
            end)
			
			timer.Simple(20, function()
				table.RemoveByValue(nearPlayers, ply)
			end)
        end
    end
	if table.IsEmpty(totalPlayers) then return end
	self:EmitSparks()

	local rf = RecipientFilter()
	rf:AddAllPlayers()
	if IsValid(owner) then
		rf:RemovePlayer(owner)
	end

	for k,v in pairs(totalPlayers) do
		rf:RemovePlayer(v)
	end

	self:EmitSound(")cupcake_triggered.wav", 75, 100, 1, CHAN_AUTO, 0, 1, rf)
	
	if IsValid(owner) then
		highlight.Add(owner, totalPlayers)
	end
			
	net.Start("fh_draw_hl_overlay")
	net.WriteBool(true)
	net.Send(totalPlayers)
			
	net.Start("fh_play_sound")
	net.WriteString("vision_success_cake.wav")
	net.Send(self:GetOwner())
end

function ENT:OnTakeDamage(dmginfo)
	local attacker = dmginfo:GetAttacker()
	local owner = self:GetOwner()
	
	if !attacker:IsSurvivor() and attacker ~= owner then return 0 end

    self:TakePhysicsDamage(dmginfo)
	
    local health = self:Health()
    health = health - dmginfo:GetDamage()
    self:SetHealth(health)

    if health <= 0 then
        self:Remove()
    end
end

function ENT:PhysgunPickup(ply, ent)
    return false
end

MODULE:Hook("GravGunPickupAllowed", "fh_cakemine_pickup", function(ply, entity)
    if entity:GetClass() == "cakemine" then
        return false
    end
end)

MODULE:Hook("GravGunPunt", "fh_cakemine_punt", function(ply, entity)
    if entity:GetClass() == "cakemine" then
		entity:TakeDamage(100, ply)
    end
end)

function ENT:EmitExplosion()
    local effectdata = EffectData()
    effectdata:SetOrigin(self:GetPos())
    effectdata:SetScale(1)
    util.Effect("Explosion", effectdata)
end

function ENT:EmitSparks()
    local effectdata = EffectData()
    effectdata:SetOrigin(self:GetPos())
    effectdata:SetScale(1)
    util.Effect("cball_explode", effectdata)
end
