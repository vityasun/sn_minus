-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: contextual controls hints
-- ========================================================
if not CLIENT then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}
if not GetConVar("sn_hints_enabled") then
    CreateClientConVar("sn_hints_enabled", "1", true, false, "Показывать игровые подсказки")
end
local hintsWasDown = false

local function HintsEnabled()
    local cv = GetConVar("sn_hints_enabled")
    return not cv or cv:GetBool()
end

local function ToggleHints()
    local cv = GetConVar("sn_hints_enabled")
    if not cv then return end
    RunConsoleCommand("sn_hints_enabled", cv:GetBool() and "0" or "1")
end

MODULE:Hook("Think", "SN_Tasks_HintsToggle", function()
    local down = input.IsKeyDown(KEY_F8)
    if down and not hintsWasDown then ToggleHints() end
    hintsWasDown = down
end)

MODULE:Hook("HUDPaint", "SN_Tasks_ControlHints", function()
    if not HintsEnabled() then return end
    if gui.IsGameUIVisible() then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if SlashMoon.Tasks.Game.IsAnimatronic(ply) or SlashMoon.Tasks.Game.IsSpectator(ply) then return end

    local scale = SlashMoon.UI.Scale
    local rows = {
        { "F3", "Открепить мышку" },
        { "F4", "Открыть хаб" },
        { "ДВОЙНОЙ КЛИК", "Быстрая экипировка" },
        { "H", "Колесо эмоций" },
        { "F8", "Скрыть подсказки" },
    }
    local inventoryKey = GetConVar("sn_inventory_key")
    if inventoryKey then
        rows[#rows + 1] = { input.GetKeyName(inventoryKey:GetInt()) or "I", "Открыть инвентарь" }
    end

    local width = scale(285)
    local rowHeight = scale(30)
    local gap = scale(4)
    local x = ScrW() - math.floor(ScrW() * 0.01) - width
    local y = ScrH() * 0.50 - (#rows * (rowHeight + gap)) / 2

    for _, row in ipairs(rows) do
        surface.SetDrawColor(SlashMoon.UI.Colors.DarkBG)
        surface.DrawRect(x, y, width, rowHeight)
        surface.SetDrawColor(SlashMoon.UI.Colors.Theme)
        surface.DrawRect(x, y, scale(3), rowHeight)
        surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
        surface.DrawOutlinedRect(x, y, width, rowHeight, 1)
        SlashMoon.UI.Draw.TextShadow(row[1], "SlashMoon.Small", x + scale(12), y + rowHeight / 2, SlashMoon.UI.Colors.Theme, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SlashMoon.UI.Draw.TextShadow(row[2], "SlashMoon.Small", x + scale(105), y + rowHeight / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        y = y + rowHeight + gap
    end
end)
