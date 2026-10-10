-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: всплывающие окна и уведомления
--
--   SlashMoon.UI.Popup("ЗАГОЛОВОК", "Текст", "ОК", onConfirm, "ОТМЕНА", onCancel)
--   SlashMoon.UI.InputPopup("ЗАГОЛОВОК", "Текст", "Плейсхолдер", "ОК", function(text) end, "ОТМЕНА")
--   SlashMoon.UI.DoubleInputPopup("ЗАГОЛОВОК", "Текст", "Поле 1", "Поле 2", "ОК", function(a, b) end, "ОТМЕНА")
--   SlashMoon.UI.ActionMenu("ДЕЙСТВИЯ", { { text = "Кик", color = Color(255,0,0), onClick = fn }, ... })
--   SlashMoon.UI.Toast("Сохранено", "success", 3)
-- ========================================================

local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

local function ClosePopup()
    if IsValid(UI.ActivePopup) then UI.ActivePopup:Remove() end
end

-- Общий каркас модального окна: заголовок, текст, область содержимого, кнопки.
local function BuildPopup(title, message, height, confirmText, onConfirm, cancelText, onCancel, getValues)
    ClosePopup()

    local popup = vgui.Create("SlashMoon.Frame")
    popup:SetSize(UI.Scale(560), UI.Scale(height))
    popup:Center()
    popup:SetHeader(title or "")
    popup:DoModal()
    UI.ActivePopup = popup

    local lbl = vgui.Create("SlashMoon.Label", popup)
    lbl:Dock(TOP)
    lbl:DockMargin(UI.Scale(8), UI.Scale(4), UI.Scale(8), UI.Scale(8))
    lbl:SetText(message or "")
    lbl:SetWrap(true)
    lbl:SetAutoStretchVertical(true)
    lbl:SetContentAlignment(5)

    local content = vgui.Create("SlashMoon.Container", popup)
    content:Dock(FILL)
    content:DockMargin(UI.Scale(8), 0, UI.Scale(8), UI.Scale(8))

    local buttons = vgui.Create("SlashMoon.Container", popup)
    buttons:Dock(BOTTOM)
    buttons:SetTall(UI.Scale(48))
    buttons:DockMargin(UI.Scale(8), 0, UI.Scale(8), UI.Scale(4))

    if confirmText then
        local yes = vgui.Create("SlashMoon.Button", buttons)
        yes:Dock(RIGHT)
        yes:SetWide(UI.Scale(220))
        yes:SetVariant("success")
        yes:SetText(confirmText)
        yes.DoClick = function()
            local values = getValues and { getValues() } or {}
            popup:Close()
            if onConfirm then onConfirm(unpack(values)) end
        end
        popup.ConfirmButton = yes
    end

    if cancelText then
        local no = vgui.Create("SlashMoon.Button", buttons)
        no:Dock(LEFT)
        no:SetWide(UI.Scale(220))
        no:SetVariant("danger")
        no:SetText(cancelText)
        no.DoClick = function()
            popup:Close()
            if onCancel then onCancel() end
        end
        popup.CancelButton = no
    end

    return popup, content
end

--- Модальное окно с сообщением и кнопками.
function UI.Popup(title, message, confirmText, onConfirm, cancelText, onCancel)
    local popup = BuildPopup(title, message, 260, confirmText, onConfirm, cancelText, onCancel)
    return popup
end

local function MakeInput(parent, placeholder, dockFill)
    local entry = vgui.Create("SlashMoon.TextEntry", parent)
    entry:Dock(dockFill and FILL or TOP)
    entry:SetTall(UI.Scale(44))
    entry:SetPlaceholderText(placeholder or "")
    return entry
end

--- Модальное окно с одним полем ввода.
-- onConfirm(text)
function UI.InputPopup(title, message, placeholder, confirmText, onConfirm, cancelText, onCancel)
    local input
    local popup, content = BuildPopup(title, message, 300, confirmText, onConfirm, cancelText, onCancel, function()
        return input:GetValue()
    end)
    input = MakeInput(content, placeholder)
    input.OnEnter = function()
        if IsValid(popup.ConfirmButton) then popup.ConfirmButton:DoClick() end
    end
    input:RequestFocus()
    return popup, input
end

--- Модальное окно с двумя полями ввода.
-- onConfirm(text1, text2)
function UI.DoubleInputPopup(title, message, placeholder1, placeholder2, confirmText, onConfirm, cancelText, onCancel)
    local input1, input2
    local popup, content = BuildPopup(title, message, 360, confirmText, onConfirm, cancelText, onCancel, function()
        return input1:GetValue(), input2:GetValue()
    end)
    input1 = MakeInput(content, placeholder1)
    input1:DockMargin(0, 0, 0, UI.Scale(12))
    input2 = MakeInput(content, placeholder2)
    input1:RequestFocus()
    return popup, input1, input2
end

--- Невидимый полноэкранный "щит": перехватывает клики мимо всплывающего меню.
-- @param onClick function вызывается при клике мимо
-- @return Panel
function UI.Shield(onClick)
    local shield = vgui.Create("DButton")
    shield:SetSize(ScrW(), ScrH())
    shield:SetText("")
    shield:SetCursor("arrow")
    shield.Paint = function() end
    shield.DoClick = function(s)
        if onClick then onClick(s) else s:Remove() end
    end
    shield:MakePopup()
    shield:SetKeyboardInputEnabled(false)
    return shield
end

--- Всплывающее контекстное меню у курсора.
--   local menu = SlashMoon.UI.ContextMenu()
--   menu:AddOption("Текст", "icon16/user.png", function() end)
--   menu:AddSpacer("ЗАГОЛОВОК")
--   menu:AddPanel(panel, height)
--   menu:Open()
function UI.ContextMenu(width)
    if IsValid(UI.ActiveContextMenu) then UI.ActiveContextMenu:Remove() end

    local shield = UI.Shield()
    UI.ActiveContextMenu = shield

    local menu = vgui.Create("SlashMoon.Panel", shield)
    menu:SetBackground("Header")
    menu:SetOutline("Accent")
    menu:SetWide(width or UI.Scale(300))
    menu:DockPadding(1, 1, 1, 1)
    menu.Shield = shield

    function menu:AddOption(text, icon, onClick)
        local btn = vgui.Create("SlashMoon.Button", self)
        btn:Dock(TOP)
        btn:SetTall(UI.Scale(44))
        btn:SetVariant("ghost")
        btn:SetRadius(0)
        btn:SetTextAlign(TEXT_ALIGN_LEFT)
        btn:SetFont("SlashMoon.Small")
        btn:SetText(text)
        if icon then btn:SetIcon(icon) end
        btn.DoClick = function()
            if IsValid(shield) then shield:Remove() end
            if onClick then onClick() end
        end
        return btn
    end

    function menu:AddSpacer(title)
        local header = vgui.Create("SlashMoon.Header", self)
        header:Dock(TOP)
        header:SetText(title or "")
        return header
    end

    function menu:AddPanel(panel, height)
        panel:SetParent(self)
        panel:Dock(TOP)
        if height then panel:SetTall(height) end
        return panel
    end

    function menu:Open()
        self:InvalidateLayout(true)
        self:SizeToChildren(false, true)
        local h = self:GetTall() + 2
        self:SetTall(h)
        local mx, my = gui.MousePos()
        mx = math.min(mx, ScrW() - self:GetWide())
        my = math.min(my, ScrH() - h)
        self:SetPos(mx, my)
    end

    return menu
end

--- Меню действий (список кнопок по центру экрана, клик мимо — закрыть).
-- buttons: { { text = "...", color = Color|nil, onClick = function() end }, ... }
function UI.ActionMenu(title, buttons)
    if IsValid(UI.ActiveActionMenu) then UI.ActiveActionMenu:Remove() end

    local shield = UI.Shield()
    UI.ActiveActionMenu = shield

    local btnH, margin = UI.Scale(44), UI.Scale(10)
    -- Окно создается после "щита", поэтому оказывается поверх него
    local menu = vgui.Create("SlashMoon.Frame")
    menu:SetBlur(false)
    menu:SetHeader(title or "")
    menu:SetSize(UI.Scale(380), menu:GetHeaderHeight() + (btnH + margin) * #buttons + margin * 2)
    menu:Center()
    menu.OnRemove = function()
        if IsValid(shield) then shield:Remove() end
    end

    local function CloseMenu()
        if IsValid(menu) then menu:Close() end
    end
    shield.DoClick = CloseMenu
    shield.OnRemove = function()
        if IsValid(menu) then menu:Remove() end
    end

    for _, data in ipairs(buttons or {}) do
        local btn = vgui.Create("SlashMoon.Button", menu)
        btn:Dock(TOP)
        btn:SetTall(btnH)
        btn:DockMargin(0, 0, 0, margin)
        btn:SetText(data.text or "")
        if data.color then btn:SetAccentColor(data.color) end
        if data.icon then btn:SetIcon(data.icon) end
        btn.DoClick = function()
            CloseMenu()
            if data.onClick then timer.Simple(0.15, data.onClick) end
        end
    end

    return menu
end

-- ========================================================
-- Тосты (всплывающие уведомления в правом нижнем углу)
-- ========================================================
UI.Toasts = UI.Toasts or {}

local TOAST_COLORS = { info = "Info", success = "Success", error = "Danger", warning = "Warning" }

--- Показывает уведомление.
-- @param text string
-- @param kind string "info" | "success" | "error" | "warning"
-- @param duration number секунды (по умолчанию 4)
function UI.Toast(text, kind, duration)
    table.insert(UI.Toasts, 1, {
        text = tostring(text),
        color = TOAST_COLORS[kind or "info"] or "Info",
        start = SysTime(),
        duration = duration or 4,
    })
    while #UI.Toasts > 6 do table.remove(UI.Toasts) end
end

hook.Add("DrawOverlay", "SlashMoon.UI.Toasts", function()
    if #UI.Toasts == 0 then return end
    local now = SysTime()
    local y = ScrH() - UI.Scale(40)
    local pad = UI.Scale(16)

    for i = #UI.Toasts, 1, -1 do
        if now - UI.Toasts[i].start > UI.Toasts[i].duration + 0.3 then table.remove(UI.Toasts, i) end
    end

    surface.SetFont("SlashMoon.Text")
    for _, toast in ipairs(UI.Toasts) do
        local age = now - toast.start
        local alpha = math.Clamp(math.min(age / 0.2, (toast.duration + 0.3 - age) / 0.3), 0, 1)
        local tw, th = surface.GetTextSize(toast.text)
        local w, h = tw + pad * 2 + UI.Scale(6), th + pad
        local x = ScrW() - w - UI.Scale(24) + (1 - alpha) * UI.Scale(40)
        y = y - h

        local accent = colors[toast.color]
        Draw.RoundedBox(UI.Scale(6), x, y, w, h, Color(colors.Header.r, colors.Header.g, colors.Header.b, 240 * alpha))
        Draw.RoundedBox(UI.Scale(6), x, y, UI.Scale(5), h, Color(accent.r, accent.g, accent.b, 255 * alpha), true, false, true, false)
        draw.SimpleText(toast.text, "SlashMoon.Text", x + pad + UI.Scale(6), y + h / 2, Color(255, 255, 255, 255 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        y = y - UI.Scale(8)
    end
end)
