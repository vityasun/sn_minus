-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("hub")

-- ========================================================
-- Хаб: главное окно (F4 / sn_hub)
-- ========================================================

local Hub = SlashMoon.Hub
local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

Hub.Tabs = Hub.Tabs or {}
Hub.Inventory = Hub.Inventory or {}

UI.CreateFont("HubTitle", 36, 700)
UI.CreateFont("HubBtn", 24, 600)
UI.CreateFont("HubSubBtn", 20, 700)
UI.CreateFont("HubPlayBtn", 32, 800)
UI.CreateFont("HubText", 18, 500)

local coinIcon = Material("sn_hub/coin.png", "noclamp smooth")

--- Регистрирует вкладку хаба.
-- @param buildFunc function(panel) строит содержимое
function Hub.RegisterTab(id, name, bgMatPath, order, buildFunc)
    for i = #Hub.Tabs, 1, -1 do
        if Hub.Tabs[i].id == id then table.remove(Hub.Tabs, i) end
    end
    table.insert(Hub.Tabs, {
        id = id, name = name, order = order, buildFunc = buildFunc,
        bgMat = bgMatPath and Material(bgMatPath, "noclamp smooth") or nil,
    })
    table.SortByMember(Hub.Tabs, "order", true)
end

local function HasItem(itemID)
    return Hub.Inventory[itemID] == true
end
Hub.HasItem = HasItem

-- ========================================================
-- ВЫБОР АВАТАРА И БАННЕРА
-- ========================================================
local function SelectorFrame(title, w, h)
    if IsValid(Hub.SelectorFrame) then Hub.SelectorFrame:Remove() end
    local frame = UI.Create("Frame")
    frame:SetSize(UI.Scale(w), UI.Scale(h))
    frame:Center()
    frame:SetHeader(title)
    frame:SetBlur(false)
    Hub.SelectorFrame = frame

    local scroll = UI.Create("Scroll", frame)
    scroll:Dock(FILL)
    local grid = UI.Create("Grid", scroll)
    grid:Dock(FILL)
    grid:SetSpaceX(UI.Scale(14))
    grid:SetSpaceY(UI.Scale(14))
    return frame, grid
end

local function SelectableCard(grid, w, h, isSelected, paintContent, onClick)
    local card = grid:Add("SlashMoon.Button")
    card:SetSize(UI.Scale(w), UI.Scale(h))
    card.Paint = function(self, cw, ch)
        local hovered = self:IsHovered()
        local r = UI.GetRadius()
        Draw.RoundedBox(r, 0, 0, cw, ch, colors.Header)
        paintContent(self, cw, ch, hovered)
        if isSelected() then
            for i = 0, 2 do Draw.RoundedOutline(r, i, i, cw - i * 2, ch - i * 2, colors.Accent) end
        else
            Draw.RoundedOutline(r, 0, 0, cw, ch, Color(colors.Accent.r, colors.Accent.g, colors.Accent.b, hovered and 150 or 50))
        end
    end
    card.DoClick = onClick
    return card
end

function Hub.OpenAvatarSelector()
    local _, grid = SelectorFrame("ВЫБОР АВАТАРА", 760, 560)
    local current = LocalPlayer():GetNW2String("SN_EquippedAvatar", "steam")

    local function AddCard(id, label)
        local card = SelectableCard(grid, 160, 190, function() return current == id end, function(_, cw, ch, hovered)
            Draw.Text(label, "SlashMoon.Small", cw / 2, ch - UI.Scale(20), (hovered or current == id) and colors.Text or colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end, function()
            net.Start("SN_Hub_SetAvatar")
            net.WriteString(id)
            net.SendToServer()
            current = id
        end)

        local avatar = UI.Create("Avatar", card)
        avatar:SetSize(UI.Scale(124), UI.Scale(124))
        avatar:SetPos(UI.Scale(18), UI.Scale(16))
        avatar:SetMouseInputEnabled(false)
        if id == "steam" then avatar:SetPlayer(LocalPlayer(), 128) else avatar:SetImage(id) end
    end

    AddCard("steam", "Steam")
    for _, data in ipairs(Hub.AvailableAvatars) do
        if not data.req_bundle or HasItem(data.req_bundle) then AddCard(data.path, "Особый") end
    end
end

function Hub.OpenBannerSelector()
    local _, grid = SelectorFrame("ВЫБОР БАННЕРА", 900, 620)
    local current = LocalPlayer():GetNW2String("SN_Banner", "none")

    for _, data in ipairs(Hub.AvailableBanners) do
        if data.req_bundle and not HasItem(data.req_bundle) then continue end
        local mat = data.mat and Draw.Material(data.mat)
        SelectableCard(grid, 410, 130, function() return current == data.id end, function(_, cw, ch, hovered)
            if mat and not mat:IsError() then
                Draw.Icon(mat, 0, 0, cw, ch, Color(255, 255, 255, hovered and 255 or 150))
                Draw.Box(0, 0, cw, ch, Color(0, 0, 0, hovered and 50 or 150))
            end
            Draw.TextShadow(data.name, "SlashMoon.Header", cw / 2, ch / 2, (hovered or current == data.id) and colors.Text or colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end, function()
            net.Start("SN_Hub_SetBanner")
            net.WriteString(data.id)
            net.SendToServer()
            current = data.id
        end)
    end
end

local function OpenPromoPopup()
    UI.InputPopup("ПРОМОКОД", "Введите промокод:", "КОД...", "АКТИВИРОВАТЬ", function(code)
        if code and string.Trim(code) ~= "" then
            net.Start("SN_Promo_Submit")
            net.WriteString(code)
            net.SendToServer()
        end
    end, "ОТМЕНА")
end

-- ========================================================
-- ГЛАВНОЕ ОКНО
-- ========================================================
local HubMenu = nil

local function BuildTopBar(frame, onTab)
    local barH = UI.Scale(64)
    local margin = UI.Scale(24)
    local ply = LocalPlayer()

    -- Профиль (слева)
    local profile = UI.Create("Button", frame)
    profile:SetSize(UI.Scale(300), barH)
    profile:SetPos(margin, margin)
    profile:SetText("")
    profile.Paint = function(self, w, h)
        local hovered = self:IsHovered()
        Draw.RoundedBox(UI.GetRadius(), 0, 0, w, h, Color(0, 0, 0, 160))
        Draw.RoundedBox(UI.GetRadius(), 0, 0, w, h, Color(colors.Accent.r, colors.Accent.g, colors.Accent.b, hovered and 90 or 20))
        Draw.Box(0, 0, UI.Scale(4), h, colors.Accent)
        Draw.RoundedOutline(UI.GetRadius(), 0, 0, w, h, colors.Border)
        Draw.Text(ply:Nick(), "SlashMoon.HubText", h + UI.Scale(6), h / 2, hovered and colors.Text or colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    profile.DoClick = function()
        local menu = UI.Menu()
        menu:AddOption("Сменить аватар", Hub.OpenAvatarSelector):SetIcon("icon16/user.png")
        menu:AddOption("Сменить баннер", Hub.OpenBannerSelector):SetIcon("icon16/picture.png")
        menu:AddOption("Ввести промокод", OpenPromoPopup):SetIcon("icon16/key.png")
        menu:Open()
    end

    local avatar = UI.Create("Avatar", profile)
    avatar:SetSize(barH - UI.Scale(16), barH - UI.Scale(16))
    avatar:SetPos(UI.Scale(12), UI.Scale(8))
    avatar:SetMouseInputEnabled(false)
    avatar.Think = function(self)
        local id = ply:GetNW2String("SN_EquippedAvatar", "steam")
        if self.LastID == id then return end
        self.LastID = id
        if id == "steam" then self:SetPlayer(ply, 64) else self:SetImage(id) end
    end

    -- Баланс (справа)
    local balance = UI.Create("Panel", frame)
    balance:SetSize(UI.Scale(220), barH)
    balance:SetPos(ScrW() - margin - UI.Scale(220), margin)
    balance.Paint = function(_, w, h)
        Draw.RoundedBox(UI.GetRadius(), 0, 0, w, h, Color(0, 0, 0, 160))
        Draw.Box(w - UI.Scale(4), 0, UI.Scale(4), h, colors.Accent)
        Draw.RoundedOutline(UI.GetRadius(), 0, 0, w, h, colors.Border)

        local text = string.Comma(ply:GetNW2Int("SN_Balance", 0))
        surface.SetFont("SlashMoon.HubSubBtn")
        local tw = surface.GetTextSize(text)
        local icon = UI.Scale(26)
        local x = (w - tw - UI.Scale(8) - icon) / 2
        Draw.Text(text, "SlashMoon.HubSubBtn", x, h / 2, colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if not Draw.Icon(coinIcon, x + tw + UI.Scale(8), h / 2 - icon / 2, icon, icon, color_white) then
            Draw.Text(Hub.Currency(), "SlashMoon.HubSubBtn", x + tw + UI.Scale(8), h / 2, colors.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Вкладки (по центру)
    local tabW, gap = UI.Scale(220), UI.Scale(16)
    local total = #Hub.Tabs * tabW + math.max(0, #Hub.Tabs - 1) * gap
    local tabs = UI.Create("Container", frame)
    tabs:SetSize(total, barH)
    tabs:SetPos((ScrW() - total) / 2, margin)

    local buttons = {}
    for i, tab in ipairs(Hub.Tabs) do
        local btn = UI.Create("Button", tabs)
        btn:Dock(LEFT)
        btn:SetWide(tabW)
        btn:DockMargin(0, 0, i < #Hub.Tabs and gap or 0, 0)
        btn:SetVariant("ghost")
        btn:SetFont("SlashMoon.HubBtn")
        btn:SetText(tab.name)
        btn.DoClick = function()
            for _, other in ipairs(buttons) do other:SetActive(other == btn) end
            onTab(tab)
        end
        buttons[i] = btn
    end
    return buttons
end

local function BuildPlayButton(frame)
    local servers = Hub.GetServers()
    local w, h = UI.Scale(360), UI.Scale(64)

    local play = UI.Create("Button", frame)
    play:SetSize(w, h)
    play:SetPos((ScrW() - w) / 2, ScrH() - h - UI.Scale(40))
    play:SetVariant("primary")
    play:SetFont("SlashMoon.HubPlayBtn")
    play:SetText(#servers > 0 and "ИГРАТЬ" or "ПРОДОЛЖИТЬ")
    play.DoClick = function()
        if #servers == 0 then
            Hub.Close()
            return
        end

        local buttons = {}
        for _, srv in ipairs(servers) do
            buttons[#buttons + 1] = { text = srv.name, onClick = function()
                UI.Popup("ПОДКЛЮЧЕНИЕ", "Подключиться к серверу «" .. srv.name .. "»?\n" .. srv.address, "ПОДКЛЮЧИТЬСЯ",
                    function() LocalPlayer():ConCommand("connect " .. srv.address) end, "ОТМЕНА")
            end }
        end
        buttons[#buttons + 1] = { text = "Остаться здесь", color = colors.TextMuted, onClick = Hub.Close }
        UI.ActionMenu("ВЫБОР СЕРВЕРА", buttons)
    end
end

function Hub.Open()
    if IsValid(HubMenu) then HubMenu:Remove() end

    local frame = UI.Create("Frame")
    frame:SetSize(ScrW(), ScrH())
    frame:SetPos(0, 0)
    frame:SetShowHeader(false)
    frame:SetDraggable(false)
    frame:SetBlur(false)
    frame:DockPadding(UI.Scale(100), UI.Scale(130), UI.Scale(100), UI.Scale(140))
    HubMenu = frame
    Hub.Frame = frame

    frame.Paint = function(self, w, h)
        local bg = self.ActiveBG
        if not Draw.Icon(bg, 0, 0, w, h, color_white) then
            Draw.Box(0, 0, w, h, colors.Header)
        end
        Draw.Box(0, 0, w, h, Color(0, 0, 0, 150))
        Draw.Box(0, 0, w, UI.Scale(4), colors.Accent)
    end

    local content = UI.Create("Container", frame)
    content:Dock(FILL)

    local pages = {}
    local function ShowTab(tab)
        frame.ActiveBG = tab.bgMat
        for id, page in pairs(pages) do page:SetVisible(id == tab.id) end
        if not pages[tab.id] then
            local page = UI.Create("Container", content)
            page:Dock(FILL)
            pages[tab.id] = page
            SlashMoon.SafeCall(tab.buildFunc, page)
        end
    end

    local buttons = BuildTopBar(frame, ShowTab)
    BuildPlayButton(frame)
    if buttons[1] then buttons[1]:DoClick() end
end

function Hub.Close()
    if IsValid(HubMenu) then HubMenu:Close() end
end

function Hub.Toggle()
    if IsValid(HubMenu) and not HubMenu.Closing then Hub.Close() else Hub.Open() end
end

-- ========================================================
-- ВОДЯНОЙ ЗНАК С UID (опция модуля)
-- ========================================================
MODULE:Hook("HUDPaint", "SN_Hub_DrawUID", function()
    if not MODULE:GetOption("watermark") then return end
    local uid = LocalPlayer():GetNW2Int("SN_UID", 0)
    if uid <= 0 then return end
    local mode = SlashMoon.Modules.IsEnabled("lobby") and "LOBBY" or "GAME"
    local text = string.format("SlashMoon %s | %s | UID %s", SlashMoon.Version, mode, uid)
    Draw.TextShadow(text, "SlashMoon.Watermark", ScrW() - 20, ScrH() - 15, Color(210, 210, 210, 210), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end)

-- ========================================================
-- СЕТЬ И БИНДЫ
-- ========================================================
MODULE:Receive("SN_Hub_Open", function()
    if IsValid(LocalPlayer()) then Hub.Open() end
end)

MODULE:Receive("SN_Hub_SyncInventory", function()
    Hub.Inventory = net.ReadTable()
    LocalPlayer().SN_Inventory = Hub.Inventory
end)

local BUY_MESSAGES = {
    [0] = { "Покупка не удалась", "error" },
    [1] = { "Покупка совершена!", "success" },
    [2] = { "Этот предмет уже есть", "warning" },
    [3] = { "Недостаточно средств", "error" },
}

MODULE:Receive("SN_Hub_BuyResult", function()
    local msg = BUY_MESSAGES[net.ReadUInt(4)] or BUY_MESSAGES[0]
    UI.Toast(msg[1], msg[2], 3)
    if msg[2] == "success" then surface.PlaySound("ambient/levels/labs/coinslot1.wav") end
end)

local PROMO_MESSAGES = {
    invalid = "Такого промокода не существует.",
    already_used = "Вы уже активировали этот промокод.",
    limit_reached = "Лимит активаций промокода исчерпан.",
    already_have_item = "У вас уже есть этот предмет.",
}

MODULE:Receive("SN_Promo_Result", function()
    local status, kind, value = net.ReadString(), net.ReadString(), net.ReadString()
    if status == "success" then
        surface.PlaySound("ambient/levels/labs/coinslot1.wav")
        local text = kind == "balance" and ("Начислено " .. Hub.FormatMoney(value) .. "!") or "Предмет добавлен в инвентарь!"
        UI.Popup("ПРОМОКОД АКТИВИРОВАН", text, "ОК")
    else
        surface.PlaySound("buttons/button10.wav")
        UI.Popup("ПРОМОКОД НЕ ПРИНЯТ", PROMO_MESSAGES[status] or "Неизвестная ошибка.", "ОК")
    end
end)

MODULE:Command("sn_hub", function()
    if IsValid(LocalPlayer()) then Hub.Toggle() end
end, nil, "SlashMoon: открыть хаб")

MODULE:Hook("PlayerBindPress", "SN_Hub_F4_Toggle", function(_, bind, pressed)
    if pressed and string.find(bind, "gm_showspare2", 1, true) then
        Hub.Toggle()
        return true
    end
end)

MODULE:OnDisabled(function()
    if IsValid(HubMenu) then HubMenu:Remove() end
    if IsValid(Hub.SelectorFrame) then Hub.SelectorFrame:Remove() end
end)
