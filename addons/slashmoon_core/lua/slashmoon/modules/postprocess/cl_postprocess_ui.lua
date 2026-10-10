-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("postprocess")

-- ========================================================
-- Постобработка карт: меню администратора (SlashMoon.UI)
-- ========================================================

local PostProcess = SlashMoon.PostProcess
local UI = SlashMoon.UI

local DEFAULTS = {
    colorMod = { enable = true, brightness = 0, contrast = 1, colour = 1, mulr = 0, mulg = 0, mulb = 0 },
    bloom = { enable = true, darken = 0.65, multiply = 2, sizex = 9, sizey = 9, passes = 1, color = 1, r = 1, g = 1, b = 1 },
}

local SECTIONS = {
    {
        title = "Цветокоррекция", category = "colorMod", toggle = "Включить цветокоррекцию",
        sliders = {
            { "Яркость", -1, 1, "brightness" },
            { "Контраст", 0, 5, "contrast" },
            { "Насыщенность", 0, 5, "colour" },
            { "Множитель красного", 0, 5, "mulr" },
            { "Множитель зеленого", 0, 5, "mulg" },
            { "Множитель синего", 0, 5, "mulb" },
        },
    },
    {
        title = "Bloom (свечение)", category = "bloom", toggle = "Включить Bloom",
        sliders = {
            { "Затемнение", 0, 1, "darken" },
            { "Умножение", 0, 5, "multiply" },
            { "Размер X", 0, 50, "sizex" },
            { "Размер Y", 0, 50, "sizey" },
            { "Проходы", 0, 10, "passes", 0 },
        },
    },
}

local function OpenMenu()
    if not SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_postprocess") then return end
    if IsValid(PostProcess.Frame) then PostProcess.Frame:Remove() end

    local currentData = table.Copy(PostProcess.Original or DEFAULTS)
    for category, values in pairs(DEFAULTS) do
        currentData[category] = currentData[category] or table.Copy(values)
    end

    local frame = UI.Create("Frame")
    frame:SetSize(UI.Scale(620), math.min(ScrH() * 0.9, UI.Scale(1100)))
    frame:Center()
    frame:SetHeader("ПОСТОБРАБОТКА", game.GetMap())
    frame:SetBlur(false)
    PostProcess.Frame = frame

    -- Закрытие без сохранения возвращает исходную картинку
    frame.OnClose = function()
        PostProcess.UpdatePreview(PostProcess.Original)
    end

    local save = UI.Create("Button", frame)
    save:Dock(BOTTOM)
    save:DockMargin(0, UI.Scale(10), 0, 0)
    save:SetVariant("primary")
    save:SetText("СОХРАНИТЬ ДЛЯ КАРТЫ")
    save.DoClick = function()
        net.Start("SN_PostProcess_Save")
        net.WriteString(SlashMoon.JSON.Encode(currentData) or "{}")
        net.SendToServer()
        frame.OnClose = nil
        frame:Close()
    end

    local scroll = UI.Create("Scroll", frame)
    scroll:Dock(FILL)

    for _, section in ipairs(SECTIONS) do
        local header = UI.Create("Header", scroll)
        header:Dock(TOP)
        header:SetText(section.title)

        local values = currentData[section.category]

        local toggle = UI.Create("Checkbox", scroll)
        toggle:Dock(TOP)
        toggle:DockMargin(UI.Scale(14), 0, 0, UI.Scale(6))
        toggle:SetLabel(section.toggle)
        toggle:SetChecked(values.enable ~= false, true)
        toggle.OnChange = function(_, val)
            values.enable = val
            PostProcess.UpdatePreview(currentData)
        end

        for _, def in ipairs(section.sliders) do
            local slider = UI.Create("Slider", scroll)
            slider:Dock(TOP)
            slider:DockMargin(UI.Scale(14), 0, UI.Scale(8), 0)
            slider:SetText(def[1])
            slider:SetMinMax(def[2], def[3])
            slider:SetDecimals(def[5] or 2)
            slider:SetValue(values[def[4]] or 0)
            slider.OnValueChanged = function(_, val)
                values[def[4]] = val
                PostProcess.UpdatePreview(currentData)
            end
        end
    end
end

MODULE:Command("sn_admin_pp", OpenMenu, nil, "SlashMoon: настройка постобработки текущей карты")

MODULE:OnDisabled(function()
    if IsValid(PostProcess.Frame) then PostProcess.Frame:Remove() end
end)
