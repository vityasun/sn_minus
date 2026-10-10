-- Written for: SlashMoon. By: VIKA & Ronni

-- sfreddy_plushie server init

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- ── МОДЕЛЬ ───────────────────────────────────────────────────
-- Замени на свою модель когда вставишь.
-- По умолчанию используем ту же что и fh_plushie как заглушку.
local PLUSHIE_MODEL = "models/RobGamings/ChuizaProductions/FNAF1/Plush/FreddyPlush.mdl"

function ENT:Initialize()
	self:SetModel(PLUSHIE_MODEL)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
	self:SetCollisionBounds(Vector(-8, -8, 0), Vector(8, 8, 24))
	self:DrawShadow(false)
	self:SetAngles(Angle(0, math.random(0, 359), 0))

	-- Тёмный/тёмно-фиолетовый скин для шедоу стиля (если доступен)
	-- self:SetSkin(3) -- раскомментируй и выбери нужный скин

	-- Самоудаление через 5 минут на случай если никто не подберёт
	timer.Simple(300, function()
		if IsValid(self) then
			local owner = self.sfr_owner
			self:Remove()
		end
	end)
end
