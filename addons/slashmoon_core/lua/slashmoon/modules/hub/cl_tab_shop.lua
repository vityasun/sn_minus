-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- Хаб: магазин (анимации и наборы профиля)
-- ========================================================

local Hub = SlashMoon.Hub
local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

local function IsOwned(itemID)
    if Hub.HasItem(itemID) then return true end
    local dances = SlashMoon.Dances
    if dances and dances.Animations and dances.Animations[itemID] then
        return dances.HasDance(LocalPlayer(), itemID)
    end
    return false
end

Hub.RegisterTab("shop", "МАГАЗИН", "sn_hub/bg_shop.png", 2, function(pnl)
    local selected = nil -- { id, name, price, kind, data }
    local danceSound = nil
    local loopPath = nil -- луп эмоции, включается после интро

    local function StopMusic()
        if danceSound then danceSound:Stop() danceSound = nil end
        loopPath = nil
    end
    pnl.OnRemove = StopMusic

    local function PreviewVolume()
        local vol = GetConVar("wos_dance_music_vol")
        return vol and vol:GetFloat() or 1
    end

    -- Музыка превью играет, пока вкладка открыта: интро, затем луп по кругу
    hook.Add("Think", pnl, function()
        if not pnl:IsVisible() then StopMusic() return end
        if danceSound and not danceSound:IsPlaying() then
            if loopPath then
                danceSound:Stop()
                danceSound = CreateSound(LocalPlayer(), loopPath)
                loopPath = nil
            end
            danceSound:PlayEx(PreviewVolume(), 100)
        end
    end)

    -- ══════════ Справа: предпросмотр ══════════
    local preview = UI.Create("Panel", pnl)
    preview:Dock(RIGHT)
    preview:SetWide(ScrW() * 0.3)
    preview:DockMargin(UI.Scale(20), 0, 0, 0)
    preview:SetBackground(Color(0, 0, 0, 150))
    preview:SetOutline(true)

    preview.PaintOver = function(_, w, h)
        if not selected or selected.kind ~= "bundle" then return end
        local bundle = selected.data
        local bw = w - UI.Scale(40)
        local bh = bw / 2.5
        local by = h / 2 - bh / 2 - UI.Scale(40)

        Draw.TextShadow("НАБОР ПРОФИЛЯ", "SlashMoon.Header", w / 2, UI.Scale(36), colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if Draw.Icon(Draw.Material(bundle.banner_mat), UI.Scale(20), by, bw, bh, color_white) then
            Draw.Box(UI.Scale(20), by, bw, bh, Color(0, 0, 0, 150))
            Draw.Outline(UI.Scale(20), by, bw, bh, colors.Accent, 2)
        end
        local size = UI.Scale(130)
        local ax, ay = w / 2 - size / 2, by + bh - size / 2 + UI.Scale(20)
        if Draw.Icon(Draw.Material(bundle.avatar_path), ax, ay, size, size, color_white) then
            Draw.Outline(ax, ay, size, size, colors.Accent, 2)
        end
    end

    local mdl = UI.Create("ModelPanel", preview)
    mdl:Dock(FILL)
    mdl:SetBackground(false)
    mdl:SetModel(LocalPlayer():GetModel())
    mdl.Angles = Angle(0, 0, 0)
    mdl.Zoom = 35
    if IsValid(mdl.Entity) then
        local mn, mx = mdl.Entity:GetRenderBounds()
        local size = math.max(math.abs(mn.x) + math.abs(mx.x), math.abs(mn.y) + math.abs(mx.y), math.abs(mn.z) + math.abs(mx.z))
        mdl:SetFOV(35)
        mdl:SetCamPos(Vector(size + 20, size, size * 0.4))
        mdl:SetLookAt((mn + mx) * 0.5)
    end
    function mdl:DragMousePress() self.PressX = gui.MouseX() self.Pressed = true end
    function mdl:DragMouseRelease() self.Pressed = false end
    function mdl:OnMouseWheeled(delta)
        self.Zoom = math.Clamp(self.Zoom - delta * 3, 15, 70)
        self:SetFOV(self.Zoom)
    end
    function mdl:LayoutEntity(ent)
        ent:FrameAdvance(FrameTime())
        if self.Pressed then
            local mx = gui.MouseX()
            self.Angles.y = self.Angles.y - (self.PressX - mx) * 0.5
            self.PressX = mx
        end
        ent:SetAngles(self.Angles)
    end
    local basePaint = mdl.Paint
    mdl.Paint = function(self, w, h)
        if selected and selected.kind == "bundle" then return end
        basePaint(self, w, h)
    end

    -- ══════════ Слева: категории, сетка, покупка ══════════
    local left = UI.Create("Container", pnl)
    left:Dock(FILL)

    local categories = UI.Create("Container", left)
    categories:Dock(TOP)
    categories:SetTall(UI.Scale(46))
    categories:DockMargin(0, 0, 0, UI.Scale(15))

    local buyBtn = UI.Create("Button", left)
    buyBtn:Dock(BOTTOM)
    buyBtn:SetTall(UI.Scale(56))
    buyBtn:DockMargin(0, UI.Scale(15), 0, 0)
    buyBtn:SetFont("SlashMoon.HubBtn")

    local function UpdateBuyButton()
        if not selected then
            buyBtn:SetText("ВЫБЕРИТЕ ТОВАР")
            buyBtn:SetVariant("secondary")
            buyBtn:SetEnabled(false)
        elseif IsOwned(selected.id) then
            buyBtn:SetText("УЖЕ КУПЛЕНО")
            buyBtn:SetVariant("success")
            buyBtn:SetEnabled(false)
        else
            buyBtn:SetText("КУПИТЬ ЗА " .. Hub.FormatMoney(selected.price))
            buyBtn:SetVariant("primary")
            buyBtn:SetEnabled(true)
        end
    end
    buyBtn.Think = function(self)
        self.NextUpdate = self.NextUpdate or 0
        if CurTime() > self.NextUpdate then
            self.NextUpdate = CurTime() + 0.5
            UpdateBuyButton()
        end
    end
    buyBtn.DoClick = function()
        if not selected or IsOwned(selected.id) then return end
        local item = selected
        UI.Popup("ПОДТВЕРЖДЕНИЕ", "Купить «" .. item.name .. "» за " .. Hub.FormatMoney(item.price) .. "?", "КУПИТЬ", function()
            net.Start("SN_Hub_BuyItem")
            net.WriteString(item.id)
            net.SendToServer()
        end, "ОТМЕНА")
    end

    local scroll = UI.Create("Scroll", left)
    scroll:Dock(FILL)
    local grid = UI.Create("Grid", scroll)
    grid:Dock(FILL)
    grid:SetSpaceX(UI.Scale(15))
    grid:SetSpaceY(UI.Scale(15))

    local function ItemCard(item, subtitle, background)
        local card = grid:Add("SlashMoon.Button")
        card:SetSize(UI.Scale(220), UI.Scale(260))
        card.Paint = function(self, w, h)
            local hovered = self:IsHovered()
            local isSelected = selected and selected.id == item.id
            Draw.Box(0, 0, w, h, Color(20, 20, 20, 240))
            if background and Draw.Icon(background, 0, 0, w, h, Color(255, 255, 255, 100)) then
                Draw.Box(0, 0, w, h, Color(0, 0, 0, 200))
            end
            if isSelected then
                for i = 0, 3 do Draw.Outline(i, i, w - i * 2, h - i * 2, colors.Accent) end
            else
                Draw.Outline(0, 0, w, h, Color(colors.Accent.r, colors.Accent.g, colors.Accent.b, hovered and 150 or 50))
            end
            Draw.Text(item.name, "SlashMoon.HubText", w / 2, UI.Scale(24), (hovered or isSelected) and colors.Text or colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if subtitle then
                Draw.Text(subtitle, "SlashMoon.Small", w / 2, UI.Scale(48), colors.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            if IsOwned(item.id) then
                Draw.Text("КУПЛЕНО", "SlashMoon.HubBtn", w / 2, h - UI.Scale(32), colors.Success, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                Draw.Text(Hub.FormatMoney(item.price), "SlashMoon.HubBtn", w / 2, h - UI.Scale(32), colors.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        return card
    end

    local function PlayDancePreview(animData)
        local ent = mdl.Entity
        if not IsValid(ent) then return end
        local seq = string.StartWith(animData.seq, "ACT_") and ent:SelectWeightedSequence(_G[animData.seq] or 0) or ent:LookupSequence(animData.seq)
        if seq and seq > 0 then
            ent:ResetSequence(seq)
            ent:SetCycle(0)
        end

        StopMusic()
        local sndPath = animData.sound or animData.Sound or animData.music
        if sndPath then
            danceSound = CreateSound(LocalPlayer(), sndPath)
            danceSound:PlayEx(PreviewVolume(), 100)
            if animData.repeatMusic and animData.repeatMusic ~= sndPath then
                loopPath = animData.repeatMusic
            end
        end
    end

    local loaders = {}

    loaders["АНИМАЦИИ"] = function()
        local dances = SlashMoon.Dances
        if not dances or not dances.Animations then return end
        for animID, animData in SortedPairsByMemberValue(dances.Animations, "name") do
            local price = Hub.GetPrice(animID)
            if not price or price <= 0 then continue end
            local item = { id = animID, name = animData.name, price = price, kind = "dance", data = animData }
            ItemCard(item).DoClick = function()
                if selected and selected.id == animID then
                    if danceSound then StopMusic() else PlayDancePreview(animData) end
                    return
                end
                selected = item
                PlayDancePreview(animData)
            end
        end
    end

    loaders["ПРОФИЛЬ"] = function()
        for bundleID, bundle in SortedPairsByMemberValue(Hub.ProfileBundles, "name") do
            local price = Hub.GetPrice(bundleID)
            if not price then continue end
            local item = { id = bundleID, name = bundle.name, price = price, kind = "bundle", data = bundle }
            ItemCard(item, "Баннер + аватар", Draw.Material(bundle.banner_mat)).DoClick = function()
                StopMusic()
                selected = item
            end
        end
    end

    local categoryButtons = {}
    local function LoadCategory(name)
        grid:Clear()
        scroll:GetVBar():SetScroll(0)
        StopMusic()
        selected = nil
        mdl:SetModel(LocalPlayer():GetModel())
        mdl.Angles = Angle(0, 0, 0)
        for _, btn in ipairs(categoryButtons) do btn:SetActive(btn.Category == name) end
        loaders[name]()
        UpdateBuyButton()
    end

    for _, name in ipairs({ "АНИМАЦИИ", "ПРОФИЛЬ" }) do
        local btn = UI.Create("Button", categories)
        btn:Dock(LEFT)
        btn:SetWide(UI.Scale(200))
        btn:DockMargin(0, 0, UI.Scale(10), 0)
        btn:SetVariant("ghost")
        btn:SetText(name)
        btn.Category = name
        btn.DoClick = function() LoadCategory(name) end
        categoryButtons[#categoryButtons + 1] = btn
    end

    LoadCategory("АНИМАЦИИ")
end)
