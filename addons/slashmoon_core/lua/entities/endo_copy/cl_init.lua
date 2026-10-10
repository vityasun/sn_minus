-- Written for: SlashMoon. By: VIKA & Ronni

include("shared.lua")

function ENT:Initialize()
    self:SetPlaybackRate(1)
end

function ENT:Draw()
    self:DrawModel()
end

-- Think не нужен: AutomaticFrameAdvance = false (см. shared.lua) —
-- копия статична, анимация не прогрессирует. Убрали бы вызов FrameAdvance,
-- который и порождал спам SequenceDuration на кривой модели.
function ENT:Think()
    self:NextThink(CurTime() + 0.5)
    return true
end
