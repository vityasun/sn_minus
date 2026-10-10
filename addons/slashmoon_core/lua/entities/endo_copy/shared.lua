-- Written for: SlashMoon. By: VIKA & Ronni

ENT.Type                = "anim"
ENT.Base                = "base_anim"
ENT.PrintName           = "Endo Copy"
ENT.Spawnable           = false

ENT.AutomaticFrameAdvance = false

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "IsHovered")
    self:NetworkVar("Entity", 0, "OwnerPlayer")
    self:NetworkVar("Int", 0, "CopyIndex")
    self:NetworkVar("Int", 1, "CopyHP")
    self:NetworkVar("Bool", 1, "IsOriginal")
    self:NetworkVar("Vector", 0, "VisionDir")
end

-- Безопасный геттер: если VisionDir не задан (нули — до первого свитча),
-- возвращает горизонтальный forward из angles модели. Так конус на свежей
-- копии светит туда, куда повёрнут корпус, без отдельной инициализации.
function ENT:GetVisionDirSafe()
    local v = self:GetVisionDir()
    if v and v:LengthSqr() > 0.0001 then return v:GetNormalized() end
    return self:GetAngles():Forward()
end

-- Always transmit to all clients so outlines & hover work at any distance
function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end
