-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- Хаб: галерея аниматроников
-- ========================================================

local Hub = SlashMoon.Hub
local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

local function Description(char)
    local key = "fazhunt.animatronics.description." .. char.id
    local text = language.GetPhrase(key)
    return text ~= key and text or (char.desc or "Описание появится позже.")
end

Hub.RegisterTab("gallery", "ГАЛЕРЕЯ", "sn_hub/bg_chars.png", 3, function(pnl)
    -- Справа: модель + описание
    local right = UI.Create("Container", pnl)
    right:Dock(RIGHT)
    right:SetWide(ScrW() * 0.42)
    right:DockMargin(UI.Scale(20), 0, 0, 0)

    local descPnl = UI.Create("Panel", right)
    descPnl:Dock(BOTTOM)
    descPnl:SetTall(UI.Scale(200))
    descPnl:DockMargin(0, UI.Scale(15), 0, 0)
    descPnl:SetBackground(Color(0, 0, 0, 180))
    descPnl:SetOutline(true)
    descPnl:SetAccentBar(true)
    descPnl:DockPadding(UI.Scale(20), UI.Scale(12), UI.Scale(20), UI.Scale(12))

    local descTitle = UI.Create("Label", descPnl)
    descTitle:Dock(TOP)
    descTitle:SetFont("SlashMoon.Header")
    descTitle:SetColorKey("Accent")
    descTitle:SetText("ВЫБЕРИТЕ АНИМАТРОНИКА")
    descTitle:SizeToContentsY()

    local descText = UI.Create("Label", descPnl)
    descText:Dock(FILL)
    descText:DockMargin(0, UI.Scale(6), 0, 0)
    descText:SetMuted(true)
    descText:SetWrap(true)
    descText:SetContentAlignment(7)
    descText:SetText("")

    local mdl = UI.Create("ModelPanel", right)
    mdl:Dock(FILL)
    mdl:SetBackground(Color(0, 0, 0, 150))
    mdl:SetAmbientLight(Color(20, 20, 20))
    mdl:SetDirectionalLight(BOX_RIGHT, Color(220, 230, 200))
    mdl:SetDirectionalLight(BOX_FRONT, Color(60, 60, 60))
    mdl:SetDirectionalLight(BOX_TOP, Color(100, 100, 100))
    mdl:SetDirectionalLight(BOX_LEFT, colors.Accent)
    mdl:SetDirectionalLight(BOX_BOTTOM, Color(0, 0, 0))

    function mdl:DragMousePress() self.PressX = gui.MouseX() self.Pressed = true end
    function mdl:DragMouseRelease() self.Pressed = false end
    function mdl:LayoutEntity(ent)
        if self.Pressed then
            local mx = gui.MouseX()
            ent:SetAngles(Angle(0, ent:GetAngles().y - (self.PressX - mx) * 0.5, 0))
            self.PressX = mx
        end
        ent:FrameAdvance(FrameTime())
    end

    local selected
    local function Select(char)
        selected = char.id
        descTitle:SetText(string.upper(char.name))
        descText:SetText(Description(char))
        mdl:SetModel(char.model)

        local ent = mdl:GetEntity()
        if not IsValid(ent) then return end
        local seq = ent:LookupSequence("idle")
        if seq <= 0 then seq = ent:LookupSequence("idle_all_01") end
        if seq <= 0 then seq = ent:LookupSequence("idle_subtle") end
        if seq > 0 then ent:SetSequence(seq) end

        local camPos, lookAt = Vector(-125, 125, 70), Vector(0, 0, 60)
        mdl:SetFOV(35)
        mdl:SetCamPos(camPos)
        mdl:SetLookAt(lookAt)
        ent:SetAngles(Angle(0, (camPos - lookAt):Angle().y, 0))
    end

    -- Слева: карточки
    local scroll = UI.Create("Scroll", pnl)
    scroll:Dock(FILL)
    local grid = UI.Create("Grid", scroll)
    grid:Dock(FILL)
    grid:SetSpaceX(UI.Scale(15))
    grid:SetSpaceY(UI.Scale(15))

    for _, char in ipairs(Hub.Characters or {}) do
        local icon = char.icon and Draw.Material(char.icon)
        local card = grid:Add("SlashMoon.Button")
        card:SetSize(UI.Scale(200), UI.Scale(256))
        card.Paint = function(self, w, h)
            local hovered = self:IsHovered()
            local isSelected = selected == char.id
            Draw.Box(0, 0, w, h, Color(20, 20, 20, 240))
            if not Draw.Icon(icon, 0, 0, w, w, Color(255, 255, 255, hovered and 255 or 200)) then
                Draw.Box(0, 0, w, w, colors.Surface)
                Draw.Text("NO AVATAR", "SlashMoon.Small", w / 2, w / 2, colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            if isSelected then
                for i = 0, 3 do Draw.Outline(i, i, w - i * 2, h - i * 2, colors.Accent) end
            else
                Draw.Outline(0, 0, w, h, Color(colors.Accent.r, colors.Accent.g, colors.Accent.b, hovered and 150 or 50))
            end
            Draw.Text(char.name, "SlashMoon.Text", w / 2, w + (h - w) / 2, (hovered or isSelected) and colors.Text or colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        card.DoClick = function() Select(char) end
    end

    if Hub.Characters and Hub.Characters[1] then Select(Hub.Characters[1]) end
end)
