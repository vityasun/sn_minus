-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Подсветка объектов (Penalty / 1 Survivor)
-- ========================================================
if not CLIENT then return end

local survivorCount = 0
local nextScan = 0
local cachedTargets = {}

local function RefreshHighlightCache()
    survivorCount = 0
    for _, p in ipairs(player.GetAll()) do
        if SlashMoon.Tasks.Game.IsSurvivor(p) then survivorCount = survivorCount + 1 end
    end
    cachedTargets = {}
    for _, gen in ipairs(ents.FindByClass("sn_generator")) do
        if IsValid(gen) and not gen:GetNW2Bool("SN_Fueled", false) then cachedTargets[#cachedTargets + 1] = gen end
    end
    for _, gas in ipairs(ents.FindByClass("sn_gascan")) do
        if IsValid(gas) then cachedTargets[#cachedTargets + 1] = gas end
    end
    nextScan = CurTime() + 0.25
end

local function ShouldHighlight()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or not SlashMoon.Tasks.Game.IsSurvivor(ply) then return false end

    -- 1. Подсвечиваем в Штрафной фазе
    local phase = SlashMoon.Tasks.GetPhase and SlashMoon.Tasks.GetPhase() or "none"
    if phase == "penalty" then
        if CurTime() >= nextScan then RefreshHighlightCache() end
        return true
    end

    -- 2. Подсвечиваем, если остался ровно 1 выживший
    if CurTime() >= nextScan then RefreshHighlightCache() end
    return survivorCount == 1
end

-- Подсветка через Halos / Outlines
MODULE:Hook("PreDrawHalos", "SN_Tasks_HighlightObjects", function()
    if not ShouldHighlight() then return end

    local validTargets = {}
    for _, ent in ipairs(cachedTargets) do
        if IsValid(ent) then validTargets[#validTargets + 1] = ent end
    end
    if #validTargets > 0 then
        halo.Add(validTargets, Color(255, 200, 50), 3, 3, 2, true, true)
    end
end)

-- Анимированный текстовый оверлей при эвакуации
local escapeOverlayEnd = 0

MODULE:Receive("SN_Escape_SuccessOverlay", function()
    escapeOverlayEnd = CurTime() + 4
end)

MODULE:Hook("HUDPaint", "SN_Escape_DrawOverlay", function()
    if CurTime() < escapeOverlayEnd then
        local alpha = math.Clamp((escapeOverlayEnd - CurTime()) * 255, 0, 255)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.escape.success"), "SlashMoon.Broadcast", ScrW()/2, ScrH()/2, Color(50, 255, 100, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.escape.you_escaped"), "SlashMoon.Header", ScrW()/2, ScrH()/2 + 50, Color(200, 200, 200, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)
