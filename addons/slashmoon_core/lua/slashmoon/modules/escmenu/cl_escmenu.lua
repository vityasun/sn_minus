-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("escmenu")

-- ========================================================
-- Кастомное меню паузы (ESC)
-- ========================================================

SlashMoon.EscMenu = SlashMoon.EscMenu or {}
local EscMenu = SlashMoon.EscMenu
local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

EscMenu.Bypass = false

local bgMaterial = Material("sn_escmenu/background.png", "noclamp smooth")

local BuildMenu

function EscMenu.Open()
    if IsValid(EscMenu.Panel) then return end

    local ok = SlashMoon.SafeCall(BuildMenu)
    if not ok and IsValid(EscMenu.Panel) then
        EscMenu.Panel:Remove()
        EscMenu.Panel = nil
    end
    return ok
end

function BuildMenu()

    local panelWidth = UI.Scale(560)

    local pnl = UI.Create("Frame")
    pnl:SetSize(ScrW(), ScrH())
    pnl:SetPos(0, 0)
    pnl:SetShowHeader(false)
    pnl:SetDraggable(false)
    pnl:SetBlur(false)
    pnl:SetAnimated(false)
    pnl:SetCloseOnEscape(false) -- ESC обрабатывается хуком OnPauseMenuShow ниже
    pnl:DockPadding(0, 0, 0, 0)
    -- Клавиатура остается у движка: консоль и ESC работают нативно
    pnl:SetKeyboardInputEnabled(false)
    pnl:SetAlpha(0)
    pnl:AlphaTo(255, 0.15, 0)
    EscMenu.Panel = pnl

    pnl.Paint = function(_, w, h)
        if not Draw.Icon(bgMaterial, 0, 0, panelWidth, h, color_white) then
            Draw.Blur(0, 0, panelWidth, h, 3, 255)
            Draw.Box(0, 0, panelWidth, h, Color(15, 15, 15, 230))
        else
            Draw.Box(0, 0, panelWidth, h, Color(15, 15, 15, 200))
        end
        Draw.Box(panelWidth - 2, 0, 2, h, colors.Accent)
        Draw.TextShadow("МЕНЮ ПАУЗЫ", "SlashMoon.Title", UI.Scale(60), h / 2 - UI.Scale(320), colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local buttons = UI.Create("Container", pnl)
    buttons:SetSize(panelWidth - UI.Scale(120), UI.Scale(620))
    buttons:SetPos(UI.Scale(60), ScrH() / 2 - UI.Scale(260))

    local function AddButton(text, onClick, variant)
        local btn = UI.Create("Button", buttons)
        btn:Dock(TOP)
        btn:SetTall(UI.Scale(56))
        btn:DockMargin(0, 0, 0, UI.Scale(14))
        btn:SetText(text)
        if variant then btn:SetVariant(variant) end
        btn.DoClick = onClick
        return btn
    end

    AddButton("ПРОДОЛЖИТЬ", EscMenu.Close)

    AddButton("НАСТРОЙКИ", function()
        EscMenu.Close()
        EscMenu.OpenSettings()
    end)

    if SlashMoon.Modules.IsEnabled("hub") and SlashMoon.Hub and SlashMoon.Hub.Open then
        AddButton("ОТКРЫТЬ ХАБ", function()
            EscMenu.Close()
            SlashMoon.Hub.Open()
        end)
    end

    if SlashMoon.Modules.IsEnabled("dances") and SlashMoon.Dances and SlashMoon.Dances.OpenConfig then
        AddButton("ЭКИПИРОВКА АНИМАЦИЙ", function()
            EscMenu.Close()
            SlashMoon.Dances.OpenConfig()
        end)
    end

    AddButton("СТАНДАРТНОЕ МЕНЮ", function()
        EscMenu.Bypass = true
        EscMenu.Close()
        timer.Simple(0.15, function() gui.ActivateGameUI() end)
    end, "ghost")

    if SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_menu") then
        AddButton("ПАНЕЛЬ SLASHMOON", function()
            EscMenu.Close()
            RunConsoleCommand("slashmoon_menu")
        end, "ghost")
    end

    AddButton("ОТКЛЮЧИТЬСЯ", function()
        UI.Popup("ОТКЛЮЧЕНИЕ", "Вы уверены, что хотите отключиться от сервера?", "ДА, ВЫЙТИ",
            function() RunConsoleCommand("disconnect") end, "ОТМЕНА")
    end, "danger")
end

function EscMenu.Close()
    local pnl = EscMenu.Panel
    if not IsValid(pnl) or pnl.IsClosing then return end
    pnl.IsClosing = true
    pnl:AlphaTo(0, 0.15, 0, function()
        if IsValid(pnl) then pnl:Remove() end
        if EscMenu.Panel == pnl then EscMenu.Panel = nil end
    end)
end

MODULE:Hook("OnPauseMenuShow", "SN_EscMenu_Toggle", function()
    if EscMenu.Bypass then return end

    -- Сначала закрываются открытые окна библиотеки (хаб, инвентарь и т.д.)
    if UI.HandleEscape() then return false end

    if IsValid(EscMenu.Panel) then
        EscMenu.Close()
        return false
    end
    -- Меню не открылось (ошибка уже в консоли) — пускаем стандартное меню паузы
    if not EscMenu.Open() then return end
    return false
end)

-- Стандартное меню закрыли — снова перехватываем ESC
local wasVisible = false
MODULE:Hook("Think", "SN_EscMenu_ResetBypass", function()
    local isVisible = gui.IsGameUIVisible()
    if not isVisible and wasVisible then EscMenu.Bypass = false end
    wasVisible = isVisible
end)

MODULE:OnDisabled(function()
    if IsValid(EscMenu.Panel) then EscMenu.Panel:Remove() end
    if IsValid(EscMenu.SettingsFrame) then EscMenu.SettingsFrame:Remove() end
end)
