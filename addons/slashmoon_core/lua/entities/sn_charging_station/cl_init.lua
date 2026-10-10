-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Charging Station Entity (Client HUD + Hint)
-- ========================================================
include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

-- === 3D2D Hint Text ===
MODULE:Hook("PostDrawTranslucentRenderables", "SN_Charging_Station_Hint", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "sn_charging_station" then return end
    if ply:GetPos():Distance(ent:GetPos()) > 120 then return end

    local pos = ent:GetPos() + Vector(0, 0, 25)
    local ang = (pos - ply:GetPos()):Angle()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, 0.1)
        local text = SlashMoon.Tasks.Lang("sn.charging.hint")
        if SlashMoon.UI.Draw and SlashMoon.UI.Draw.TextShadow then
            SlashMoon.UI.Draw.TextShadow(text, "SlashMoon.Header", 0, 0, Color(80, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(text, "DermaLarge", 0, 0, Color(80, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end)

-- === Penalty Highlight Registration ===
if SlashMoon.Penalty then
    SlashMoon.Penalty.RegisterAutoReveal("sn_charging_penalty", {
        getEntities = function()
            return ents.FindByClass("sn_charging_station")
        end,
        color     = Color(80, 200, 255),
        condition = function()
            return SlashMoon.Tasks.Game.IsSurvivor(LocalPlayer())
        end
    })
end
