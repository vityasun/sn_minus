-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("dances")

-- ========================================================
-- Колесо эмоций (клавиша H) на SlashMoon.RadialMenu
-- ========================================================

local UI = SlashMoon.UI
local Dances = SlashMoon.Dances
local RadialMenu = nil

local function PlayDance(animID)
    if not animID then return end
    net.Start("wOS_Dance_Play")
    net.WriteString(animID)
    net.SendToServer()
end

local function OpenRadialMenu()
    if IsValid(RadialMenu) then return end

    local slots = {}
    for i, entry in ipairs(Dances.GetCircleData()) do
        slots[i] = { name = entry.name or "Пусто", data = entry.id }
    end

    RadialMenu = UI.Create("RadialMenu")
    RadialMenu:SetSlots(slots)
    RadialMenu.OnSelect = function(_, _, slot) PlayDance(slot.data) end

    -- Кнопка настроек в левом верхнем углу
    local configBtn = UI.Create("Button", RadialMenu)
    configBtn:SetSize(UI.Scale(280), UI.Scale(56))
    configBtn:SetPos(UI.Scale(40), UI.Scale(40))
    configBtn:SetText("НАСТРОЙКИ")
    configBtn:SetIcon("icon16/cog.png")
    configBtn.DoClick = function()
        RadialMenu:Remove()
        Dances.OpenConfig()
    end
    RadialMenu.ConfigBtn = configBtn

    -- Пока курсор над кнопкой, выбор танца отключен
    RadialMenu.IsInputBlocked = function() return configBtn:IsHovered() end
end

MODULE:Hook("PlayerButtonDown", "wOS_Dance_Open", function(_, button)
    if button == KEY_H and IsFirstTimePredicted() then OpenRadialMenu() end
end)

MODULE:Hook("PlayerButtonUp", "wOS_Dance_Close", function(_, button)
    if button ~= KEY_H or not IsValid(RadialMenu) then return end

    -- Отпустили H над кнопкой настроек — открываем настройки
    if IsValid(RadialMenu.ConfigBtn) and RadialMenu.ConfigBtn:IsHovered() then
        RadialMenu:Remove()
        Dances.OpenConfig()
        return
    end

    local _, slot = RadialMenu:GetSelected()
    if slot then PlayDance(slot.data) end
    RadialMenu:Remove()
end)

MODULE:OnDisabled(function()
    if IsValid(RadialMenu) then RadialMenu:Remove() end
end)
