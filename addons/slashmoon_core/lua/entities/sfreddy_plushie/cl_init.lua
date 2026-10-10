-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("sfreddy")

-- sfreddy_plushie client init

include("shared.lua")

local PLUSHIE_MODEL = "models/RobGamings/ChuizaProductions/FNAF1/Plush/FreddyPlush.mdl"

function ENT:Initialize()
	self:SetModel(PLUSHIE_MODEL)

	-- Хало-хук (подсвечиваем когда смотрим и близко)
	MODULE:Hook("PreDrawHalos", "sfr_plushie_ent_halo_" .. self:EntIndex(), function()
		if not IsValid(self) then
			MODULE:Unhook("PreDrawHalos", "sfr_plushie_ent_halo_" .. self:EntIndex())
			return
		end

		local ply     = LocalPlayer()
		if not IsValid(ply) or ply:IsAnimatronic() then return end

		local eyePos  = ply:EyePos()
		local viewDir = ply:GetAimVector()
		local toEnt   = self:GetPos() - eyePos

		if toEnt:LengthSqr() > 200^2 then return end

		local dot = viewDir:Dot(toEnt:GetNormalized())
		if dot < 0.9848 then return end

		halo.Add({self}, Color(100, 100, 255), 2, 2, 1, true, false)
	end)
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:OnRemove()
	MODULE:Unhook("PreDrawHalos", "sfr_plushie_ent_halo_" .. self:EntIndex())
end
