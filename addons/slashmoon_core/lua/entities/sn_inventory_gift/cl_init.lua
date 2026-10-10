-- Written for: SlashMoon. By: VIKA & Ronni

include("shared.lua")

function ENT:Draw()
    local position = self:GetPos() + Vector(0, 0, math.sin(CurTime() * 2.5) * 5)
    local angles = self:GetAngles()
    angles.y = angles.y + CurTime() * 90

    local oldOrigin = self:GetRenderOrigin()
    local oldAngles = self:GetRenderAngles()
    self:SetRenderOrigin(position)
    self:SetRenderAngles(angles)
    self:DrawModel()
    self:SetRenderOrigin(oldOrigin)
    self:SetRenderAngles(oldAngles)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local viewAngles = LocalPlayer():EyeAngles()
    viewAngles:RotateAroundAxis(viewAngles:Forward(), 90)
    viewAngles:RotateAroundAxis(viewAngles:Right(), 90)
    cam.Start3D2D(position + Vector(0, 0, 58), Angle(0, viewAngles.y, 90), 0.08)
        draw.SimpleText(language.GetPhrase("sn.gift.for") .. owner:Nick(), "SlashMoon.Title", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
