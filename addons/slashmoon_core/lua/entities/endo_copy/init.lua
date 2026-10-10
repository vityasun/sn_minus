-- Written for: SlashMoon. By: VIKA & Ronni

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local ENDO_MODEL = "models/mountroid/thudner/hw withered pack/endo02.mdl"

function ENT:Initialize()
    self:SetModel(ENDO_MODEL)
    self:SetSkin(1)

    local bgIdx = self:FindBodygroupByName("Ears")
    if bgIdx >= 0 then
        self:SetBodygroup(bgIdx, 1)
    end

    self:SetMoveType(MOVETYPE_STEP)
    self:SetSolid(SOLID_BBOX)
    
    -- Используем COLLISION_GROUP_PLAYER, чтобы игроки проходили сквозь копии 
    -- и не застревали между ними. При этом копии будут стоять на полу и 
    -- получать попадания от пуль.
    self:SetCollisionGroup(COLLISION_GROUP_PLAYER) 
    
    self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 86))
    self:DrawShadow(true)

    local seqCount = self:GetSequenceCount() or 0
    local idleSeq = self:LookupSequence("idle")
    if not idleSeq or idleSeq < 0 or idleSeq >= seqCount then
        idleSeq = self:SelectWeightedSequence(ACT_IDLE)
        if not idleSeq or idleSeq < 0 or idleSeq >= seqCount then
            idleSeq = 0
        end
    end
    if idleSeq >= 0 and idleSeq < seqCount then
        self:ResetSequence(idleSeq)
    end
    self:SetPlaybackRate(1)
end

function ENT:Think()
    self:NextThink(CurTime() + 0.1)

    -- === FIX ЛИФТА И ПЛАТФОРМ ===
    local pos = self:GetPos()
    local tr = util.TraceLine({
        start = pos,
        endpos = pos - Vector(0, 0, 10),
        filter = self,
        mask = MASK_SOLID
    })

    if IsValid(tr.Entity) and (tr.Entity:GetMoveType() == MOVETYPE_PUSH or tr.Entity:IsNPC()) then
        if self:GetParent() ~= tr.Entity then
            self:SetParent(tr.Entity)
        end
    else
        if IsValid(self:GetParent()) then
            self:SetParent(nil)
        end
    end

    -- Очистка декалей
    if not self._nextDecalClean or CurTime() >= self._nextDecalClean then
        self:RemoveAllDecals()
        self._nextDecalClean = CurTime() + 1
    end

    return true
end

function ENT:Explode()
    local pos = self:GetPos() + Vector(0, 0, 43)
    self:EmitSound("physics/metal/metal_sheet_impact_hard" .. math.random(7, 8) .. ".wav", 90, 100, 1)
    timer.Simple(0.05, function()
        if IsValid(self) then
            self:EmitSound("physics/metal/metal_sheet_impact_hard" .. math.random(7, 8) .. ".wav", 80, 110, 0.8)
        end
    end)

    local fx = EffectData()
    fx:SetOrigin(pos)
    fx:SetStart(pos)
    fx:SetScale(1.5)
    util.Effect("cball_explode", fx, true, true)
end
