-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: вкладки (SlashMoon.Tabs)
--
--   local tabs = SlashMoon.UI.Create("Tabs", frame)
--   tabs:Dock(FILL)
--   tabs:SetVertical(true)                      -- боковое меню вместо верхней полосы
--   tabs:AddTab("Главная", function(content)    -- ленивое построение при первом открытии
--       SlashMoon.UI.Create("Label", content):SetText("Привет")
--   end, "icon16/house.png")
--   tabs:AddTab("Готовая панель", somePanel)
--   tabs.OnTabChanged = function(self, name, content) end
-- ========================================================

local UI = SlashMoon.UI

local PANEL = {}

function PANEL:Init()
    self.Tabs = {}
    self.Vertical = false

    self.Nav = vgui.Create("SlashMoon.Panel", self)
    self.Nav:SetBackground("Header")
    self.Nav:Dock(TOP)
    self.Nav:SetTall(UI.Scale(48))
    self.Nav:DockPadding(UI.Scale(6), UI.Scale(6), UI.Scale(6), UI.Scale(6))

    self.Content = vgui.Create("SlashMoon.Container", self)
    self.Content:Dock(FILL)
    self.Content:DockMargin(0, UI.Scale(10), 0, 0)
end

--- Вертикальное боковое меню (true) или горизонтальная полоса (false).
function PANEL:SetVertical(vertical, width)
    self.Vertical = vertical == true
    if self.Vertical then
        self.Nav:Dock(LEFT)
        self.Nav:SetWide(width or UI.Scale(240))
        self.Content:DockMargin(UI.Scale(10), 0, 0, 0)
    else
        self.Nav:Dock(TOP)
        self.Nav:SetTall(UI.Scale(48))
        self.Content:DockMargin(0, UI.Scale(10), 0, 0)
    end
    for _, tab in ipairs(self.Tabs) do self:LayoutButton(tab.Button) end
end

function PANEL:LayoutButton(btn)
    if self.Vertical then
        btn:Dock(TOP)
        btn:SetTall(UI.Scale(44))
        btn:DockMargin(0, 0, 0, UI.Scale(4))
        btn:SetTextAlign(TEXT_ALIGN_LEFT)
    else
        btn:Dock(LEFT)
        btn:SizeToContentsX(UI.Scale(36))
        btn:DockMargin(0, 0, UI.Scale(4), 0)
        btn:SetTextAlign(TEXT_ALIGN_CENTER)
    end
end

--- Добавляет вкладку.
-- @param name string название
-- @param content Panel|function готовая панель или функция-построитель fn(container)
-- @param icon string|IMaterial|nil иконка
-- @return Panel контейнер содержимого вкладки
function PANEL:AddTab(name, content, icon)
    local tab = { Name = name }

    local btn = vgui.Create("SlashMoon.Button", self.Nav)
    btn:SetVariant("ghost")
    btn:SetText(name)
    if icon then btn:SetIcon(icon) end
    btn.DoClick = function() self:SetActiveTab(name) end
    tab.Button = btn
    self:LayoutButton(btn)

    if ispanel(content) then
        content:SetParent(self.Content)
        tab.Panel = content
    else
        tab.Panel = vgui.Create("SlashMoon.Container", self.Content)
        tab.Builder = content
    end
    tab.Panel:Dock(FILL)
    tab.Panel:SetVisible(false)

    self.Tabs[#self.Tabs + 1] = tab
    if #self.Tabs == 1 then self:SetActiveTab(name) end
    return tab.Panel
end

--- Совместимость с DPropertySheet:AddSheet.
function PANEL:AddSheet(name, panel, icon)
    local content = self:AddTab(name, panel, icon)
    return { Name = name, Panel = content, Tab = self.Tabs[#self.Tabs].Button }
end

--- Переключает вкладку по имени или индексу.
function PANEL:SetActiveTab(key)
    local target
    for i, tab in ipairs(self.Tabs) do
        if tab.Name == key or i == key then target = tab end
    end
    if not target then return end

    for _, tab in ipairs(self.Tabs) do
        local active = tab == target
        tab.Button:SetActive(active)
        tab.Panel:SetVisible(active)
    end

    if target.Builder then
        local builder = target.Builder
        target.Builder = nil
        SlashMoon.SafeCall(builder, target.Panel)
    end

    self.Active = target
    if self.OnTabChanged then self:OnTabChanged(target.Name, target.Panel) end
end

function PANEL:GetActiveTab()
    return self.Active and self.Active.Name, self.Active and self.Active.Panel
end

function PANEL:Paint() end

vgui.Register("SlashMoon.Tabs", PANEL, "Panel")
