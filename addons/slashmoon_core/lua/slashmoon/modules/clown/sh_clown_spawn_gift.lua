-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("clown")

-- ========================================================
-- Клоун получает собственный подарок при раздаче подарков гейммодом
-- ========================================================

if SERVER then
	MODULE:Hook("InitPostEntity", "ClownGiftSpawner", function()
		-- Оригинал гейммода запоминается один раз (хук может вызываться повторно при включении модуля)
		MODULE.OriginalSpawnGifts = MODULE.OriginalSpawnGifts or _G.SpawnGifts
		local Original_SpawnGifts = MODULE.OriginalSpawnGifts
		if not Original_SpawnGifts then return end

		_G.SpawnGifts = function(...)
			Original_SpawnGifts(...)
			if not MODULE:IsEnabled() then return end

			-- Дополнительно для клоуна
			for _, ply in ipairs(player.GetAll()) do
				if ply:IsAnimatronic() and IsValid(ply:GetPill()) and ply:GetPill().formTable.name == "pill_clown" then
					if ply:Alive() and not ply:GetNWBool("HasClownGift", false) then
						timer.Simple(math.random(10, 100) / 10, function()
							if not IsValid(ply) or ply:GetNWBool("HasClownGift", false) then return end

							local gift = ents.Create("fh_gift") -- ← оригинальная сущность!
							if not IsValid(gift) then return end
							gift:SetPos(ply:GetPos() + Vector(0, 0, 10))
							gift:SetOwner(ply)
							gift:Spawn()
							gift:Activate()

							ply:SetNWBool("HasClownGift", true)

							MODULE:Hook("EntityRemoved", "ClownGiftFlag_"..ply:EntIndex(), function(ent)
								if ent == gift then
									ply:SetNWBool("HasClownGift", false)
									MODULE:Unhook("EntityRemoved", "ClownGiftFlag_"..ply:EntIndex())
								end
							end)
						end)
					end
				end
			end
		end
	end)
end
