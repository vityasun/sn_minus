-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: витрина компонентов для разработчиков
-- Консольная команда: slashmoon_ui_demo
-- ========================================================

local UI = SlashMoon.UI

local function Section(parent, title, desc)
    local header = UI.Create("Header", parent)
    header:Dock(TOP)
    header:SetText(title)
    if desc then header:SetDescription(desc) end
    header:DockMargin(0, UI.Scale(8), 0, UI.Scale(6))
    return header
end

local function Row(parent, height)
    local row = UI.Create("Container", parent)
    row:Dock(TOP)
    row:SetTall(UI.Scale(height or 44))
    row:DockMargin(0, 0, 0, UI.Scale(10))
    return row
end

function UI.OpenDemo()
    if IsValid(UI.DemoFrame) then UI.DemoFrame:Remove() end

    local w, h = UI.WindowSize(0.55, 0.75, 1100, 900)
    local frame = UI.Create("Frame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetHeader("SLASHMOON UI", "витрина компонентов v" .. SlashMoon.Version)
    UI.DemoFrame = frame

    local tabs = UI.Create("Tabs", frame)
    tabs:Dock(FILL)
    tabs:SetVertical(true)

    tabs:AddTab("Кнопки", function(content)
        local scroll = UI.Create("Scroll", content)
        scroll:Dock(FILL)

        Section(scroll, "Варианты", "SetVariant: primary / secondary / ghost / success / danger")
        local row = Row(scroll)
        for _, variant in ipairs({ "primary", "secondary", "ghost", "success", "danger" }) do
            local btn = UI.Create("Button", row)
            btn:Dock(LEFT)
            btn:DockMargin(0, 0, UI.Scale(10), 0)
            btn:SetWide(UI.Scale(150))
            btn:SetVariant(variant)
            btn:SetText(string.upper(variant))
            btn.DoClick = function() UI.Toast("Нажата кнопка " .. variant, variant == "danger" and "error" or "info") end
        end

        Section(scroll, "Состояния", "Default / Hover / Active / Disabled + иконки")
        row = Row(scroll)
        local active = UI.Create("Button", row)
        active:Dock(LEFT)
        active:SetWide(UI.Scale(200))
        active:SetText("ACTIVE")
        active:SetActive(true)
        active:DockMargin(0, 0, UI.Scale(10), 0)

        local disabled = UI.Create("Button", row)
        disabled:Dock(LEFT)
        disabled:SetWide(UI.Scale(200))
        disabled:SetText("DISABLED")
        disabled:SetEnabled(false)
        disabled:DockMargin(0, 0, UI.Scale(10), 0)

        local icon = UI.Create("Button", row)
        icon:Dock(LEFT)
        icon:SetWide(UI.Scale(200))
        icon:SetVariant("primary")
        icon:SetText("С ИКОНКОЙ")
        icon:SetIcon("icon16/star.png")
        icon:DockMargin(0, 0, UI.Scale(10), 0)

        local iconBtn = UI.Create("IconButton", row)
        iconBtn:Dock(LEFT)
        iconBtn:SetWide(UI.Scale(44))
        iconBtn:SetGlyph("+")

        Section(scroll, "Всплывающие окна")
        row = Row(scroll)
        local popups = {
            { "POPUP", function() UI.Popup("ВОПРОС", "Вы уверены?", "ДА", nil, "НЕТ") end },
            { "INPUT", function() UI.InputPopup("ВВОД", "Введите текст", "Текст...", "ОК", function(t) UI.Toast("Введено: " .. t, "success") end, "ОТМЕНА") end },
            { "ACTION MENU", function()
                UI.ActionMenu("ДЕЙСТВИЯ", {
                    { text = "Первое", onClick = function() UI.Toast("Первое") end },
                    { text = "Опасное", color = UI.Colors.Danger, onClick = function() UI.Toast("Опасное", "error") end },
                })
            end },
            { "TOAST", function() UI.Toast("Это уведомление", "success") end },
        }
        for _, data in ipairs(popups) do
            local btn = UI.Create("Button", row)
            btn:Dock(LEFT)
            btn:SetWide(UI.Scale(180))
            btn:DockMargin(0, 0, UI.Scale(10), 0)
            btn:SetText(data[1])
            btn.DoClick = data[2]
        end
    end)

    tabs:AddTab("Управление", function(content)
        local scroll = UI.Create("Scroll", content)
        scroll:Dock(FILL)

        Section(scroll, "Строки настроек", "SettingRow + Toggle / Checkbox / SliderBar / ComboBox")

        local toggleRow = UI.Create("SettingRow", scroll)
        toggleRow:Dock(TOP)
        toggleRow:SetTitle("Переключатель")
        toggleRow:SetDescription("SlashMoon.Toggle")
        local toggle = toggleRow:SetControl(UI.Create("Toggle"))
        toggle.OnChange = function(_, v) UI.Toast("Toggle: " .. tostring(v)) end

        local sliderRow = UI.Create("SettingRow", scroll)
        sliderRow:Dock(TOP)
        sliderRow:SetTitle("Ползунок")
        sliderRow:SetDescription("SlashMoon.SliderBar")
        local bar = sliderRow:SetControl(UI.Create("SliderBar"), UI.Scale(260))
        bar:SetMinMax(0, 100)
        bar:SetDecimals(0)
        bar:SetValue(40)

        local comboRow = UI.Create("SettingRow", scroll)
        comboRow:Dock(TOP)
        comboRow:SetTitle("Выпадающий список")
        comboRow:SetDescription("SlashMoon.ComboBox")
        local combo = comboRow:SetControl(UI.Create("ComboBox"), UI.Scale(260))
        combo:AddChoice("Первый", 1, true)
        combo:AddChoice("Второй", 2)
        combo:AddChoice("Третий", 3)

        local check = UI.Create("Checkbox", scroll)
        check:Dock(TOP)
        check:DockMargin(0, UI.Scale(6), 0, UI.Scale(10))
        check:SetLabel("SlashMoon.Checkbox с подписью")

        local slider = UI.Create("Slider", scroll)
        slider:Dock(TOP)
        slider:SetText("SlashMoon.Slider (DNumSlider)")
        slider:SetMinMax(0, 10)
        slider:SetDecimals(1)
        slider:SetValue(5)

        local entry = UI.Create("TextEntry", scroll)
        entry:Dock(TOP)
        entry:DockMargin(0, UI.Scale(10), 0, 0)
        entry:SetPlaceholderText("SlashMoon.TextEntry — плейсхолдер")

        local progress = UI.Create("ProgressBar", scroll)
        progress:Dock(TOP)
        progress:DockMargin(0, UI.Scale(16), 0, 0)
        progress:SetTall(UI.Scale(18))
        progress:SetText("ProgressBar")
        progress.Think = function(s) s:SetFraction((math.sin(CurTime()) + 1) / 2) end
    end)

    tabs:AddTab("Палитра", function(content)
        local scroll = UI.Create("Scroll", content)
        scroll:Dock(FILL)
        Section(scroll, "SlashMoon.UI.Colors", "Меняется через SlashMoon.UI.SetTheme({...})")

        local grid = UI.Create("Grid", scroll)
        grid:Dock(TOP)
        for key, col in SortedPairs(UI.Colors) do
            local card = grid:Add("SlashMoon.Panel")
            card:SetSize(UI.Scale(200), UI.Scale(70))
            card:SetOutline("BorderNeutral")
            card.PaintOver = function(_, cw, ch)
                UI.Draw.RoundedBox(UI.Scale(4), UI.Scale(10), UI.Scale(10), ch - UI.Scale(20), ch - UI.Scale(20), col)
                UI.Draw.Text(key, "SlashMoon.Small", ch, ch / 2, UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        grid:SetTall(UI.Scale(80) * math.ceil(table.Count(UI.Colors) / 4))

        local row = Row(scroll)
        row:DockMargin(0, UI.Scale(16), 0, 0)
        local presets = {
            { "Фиолетовая", Color(150, 50, 255) },
            { "Синяя", Color(40, 140, 255) },
            { "Красная", Color(230, 50, 70) },
            { "Зеленая", Color(40, 190, 110) },
        }
        for _, preset in ipairs(presets) do
            local btn = UI.Create("Button", row)
            btn:Dock(LEFT)
            btn:SetWide(UI.Scale(170))
            btn:DockMargin(0, 0, UI.Scale(10), 0)
            btn:SetText(preset[1])
            btn:SetAccentColor(preset[2])
            btn.DoClick = function() UI.SetTheme({ Accent = preset[2] }) end
        end
    end)
end

concommand.Add("slashmoon_ui_demo", function() UI.OpenDemo() end, nil, "SlashMoon: витрина компонентов UI-библиотеки")
