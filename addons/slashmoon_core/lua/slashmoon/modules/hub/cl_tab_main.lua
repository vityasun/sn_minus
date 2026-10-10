-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- Хаб: главная вкладка (приветствие + новости)
-- ========================================================

local Hub = SlashMoon.Hub
local UI = SlashMoon.UI

local CHANGE_COLORS = { ["+"] = Color(100, 220, 100), ["-"] = Color(255, 100, 100) }

Hub.RegisterTab("main", "ГЛАВНАЯ", "sn_hub/bg_main.png", 1, function(pnl)
    local welcome = UI.Create("Label", pnl)
    welcome:Dock(TOP)
    welcome:DockMargin(0, UI.Scale(20), 0, 0)
    welcome:SetFont("SlashMoon.HubTitle")
    welcome:SetText("Добро пожаловать, " .. LocalPlayer():Nick() .. "!")
    welcome:SizeToContentsY()

    local news = UI.Create("Panel", pnl)
    news:Dock(RIGHT)
    news:SetWide(math.max(UI.Scale(520), ScrW() * 0.22))
    news:DockMargin(0, 0, 0, ScrH() * 0.05)
    news:SetBackground(Color(0, 0, 0, 180))
    news:SetOutline(true)
    news:DockPadding(UI.Scale(20), UI.Scale(10), UI.Scale(20), UI.Scale(20))

    local header = UI.Create("Header", news)
    header:Dock(TOP)
    header:SetText("ОБНОВЛЕНИЯ")

    local scroll = UI.Create("Scroll", news)
    scroll:Dock(FILL)
    scroll:DockMargin(0, UI.Scale(10), 0, 0)

    for i, entry in ipairs(Hub.News or {}) do
        local date = UI.Create("Label", scroll)
        date:Dock(TOP)
        date:SetColorKey("Accent")
        date:SetText(entry.date or "")
        date:SizeToContentsY()

        local title = UI.Create("Label", scroll)
        title:Dock(TOP)
        title:DockMargin(0, UI.Scale(2), 0, UI.Scale(10))
        title:SetFont("SlashMoon.Header")
        title:SetText(entry.title or "")
        title:SizeToContentsY()

        for _, change in ipairs(entry.changes or {}) do
            local line = UI.Create("Label", scroll)
            line:Dock(TOP)
            line:DockMargin(0, 0, 0, UI.Scale(8))
            line:SetFont("SlashMoon.Small")
            line:SetWrap(true)
            line:SetAutoStretchVertical(true)
            line:SetText(change)
            local col = CHANGE_COLORS[string.sub(change, 1, 1)]
            if col then line:SetColor(col) else line:SetMuted(true) end
        end

        if i < #Hub.News then
            local div = UI.Create("Divider", scroll)
            div:Dock(TOP)
            div:DockMargin(0, UI.Scale(6), 0, UI.Scale(6))
        end
    end
end)
