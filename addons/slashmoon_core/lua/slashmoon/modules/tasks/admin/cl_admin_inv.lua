-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Admin Inventory Panel (Client — VGUI)
-- Админка: выдача предметов, конструктор предметов
-- + описание, редкость, стакируемость для кастомных
-- ========================================================
if not CLIENT then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}

-- === ЛОКАЛЬНЫЕ ПЕРЕМЕННЫЕ ===
local adminPanel    = nil   -- Корневая панель
local adminRoot     = nil   -- Затемнение фона
local cachedItems   = {}    -- Кеш предметов с сервера
local cachedPlayers = {}    -- Кеш игроков
local cachedCustom  = {}    -- Кеш кастомных предметов
local cachedRecipes = {}
local RefreshRecipeList = function() end
local RefreshPlayerList, RefreshItemList -- назначаются при построении панели
local BuildAdminPanel

-- === ШРИФТЫ ===
SlashMoon.UI.CreateFont("AdminTitle", 24, 800)
SlashMoon.UI.CreateFont("AdminText", 16, 500)
SlashMoon.UI.CreateFont("AdminSmall", 13, 500)

-- ========================================================
-- ОТПРАВКА ЗАПРОСА НА ОТКРЫТИЕ
-- ========================================================
function SlashMoon.Tasks.OpenAdminPanel()
    if adminRoot and IsValid(adminRoot) then
        adminRoot:Remove()
        adminRoot = nil
        return
    end

    if not SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_tasks_admin") then return end

    net.Start("SN_AdminInv_RequestOpen")
    net.SendToServer()
end

-- ========================================================
-- ПРИЁМ ДАННЫХ С СЕРВЕРА: СПИСОК ПРЕДМЕТОВ
-- ========================================================
MODULE:Receive("SN_AdminInv_Open", function()
    cachedItems = {}
    local count = net.ReadUInt(16)

    for i = 1, count do
        table.insert(cachedItems, {
            class       = net.ReadString(),
            nameKey     = net.ReadString(),
            name        = net.ReadString(),
            type        = net.ReadString(),
            icon        = net.ReadString(),
            unique      = net.ReadBool(),
            custom      = net.ReadBool(),
            description = net.ReadString(),
            descriptionKey = net.ReadString(),
            rarity      = net.ReadString(),
            stackable   = net.ReadBool(),
        })
    end

    -- Показываем панель после получения данных
    BuildAdminPanel()
end)

-- ========================================================
-- ПРИЁМ: СПИСОК ИГРОКОВ
-- ========================================================
MODULE:Receive("SN_AdminInv_PlayerList", function()
    cachedPlayers = {}
    local count = net.ReadUInt(8)

    for i = 1, count do
        table.insert(cachedPlayers, {
            steamID = net.ReadString(),
            name    = net.ReadString(),
            team    = net.ReadUInt(16),
            alive   = net.ReadBool(),
        })
    end

    -- Обновляем список игроков если панель открыта
    if adminPanel and IsValid(adminPanel) then
        RefreshPlayerList()
    end
end)

-- ========================================================
-- ПРИЁМ: КАСТОМНЫЕ ПРЕДМЕТЫ
-- ========================================================
MODULE:Receive("SN_AdminInv_CustomItems", function()
    cachedCustom = {}
    local count = net.ReadUInt(8)

    for i = 1, count do
        table.insert(cachedCustom, {
            class       = net.ReadString(),
            name        = net.ReadString(),
            type        = net.ReadString(),
            icon        = net.ReadString(),
            description = net.ReadString(),
            rarity      = net.ReadString(),
            stackable   = net.ReadBool(),
        })
    end
end)

MODULE:Receive("SN_AdminInv_RecipeList", function()
    cachedRecipes = {}
    for i = 1, net.ReadUInt(8) do
        local recipe = {
            id = net.ReadString(),
            name = net.ReadString(),
            result = net.ReadString(),
            craftTime = net.ReadFloat(),
            ingredients = {},
        }
        for j = 1, net.ReadUInt(5) do recipe.ingredients[j] = net.ReadString() end
        cachedRecipes[#cachedRecipes + 1] = recipe
    end
    RefreshRecipeList()
end)

-- ========================================================
-- ПРИЁМ: РЕЗУЛЬТАТ ОПЕРАЦИИ
-- ========================================================
MODULE:Receive("SN_AdminInv_Result", function()
    local success = net.ReadBool()
    local key = net.ReadString()
    local args = {}
    for i = 1, net.ReadUInt(4) do args[i] = net.ReadString() end
    local message = SlashMoon.Tasks.Lang(key, unpack(args))

    chat.AddText(
        success and Color(80, 220, 100) or Color(255, 100, 80),
        "[SN Admin] ",
        color_white,
        message
    )
end)

-- ========================================================
-- ПОСТРОЕНИЕ АДМИН-ПАНЕЛИ
-- ========================================================
BuildAdminPanel = function()
    -- Закрыть предыдущую
    if adminRoot and IsValid(adminRoot) then adminRoot:Remove() end

    local colors = SlashMoon.UI.Colors
    local sw, sh = ScrW(), ScrH()

    -- === КОРНЕВАЯ ПАНЕЛЬ (затемнение) ===
    adminRoot = vgui.Create("SlashMoon.Panel")
    adminRoot:SetSize(sw, sh)
    adminRoot:MakePopup()
    adminRoot:SetKeyboardInputEnabled(false)
    -- ESC закрывает панель, а не открывает меню паузы
    SlashMoon.UI.PushEscape(adminRoot, function(panel) panel:Remove() end)
    adminRoot.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(0, 0, w, h)
    end

    -- ESC закрытие
    adminRoot.openTime = CurTime()
    adminRoot.Think = function(self)
        if CurTime() - self.openTime < 0.2 then return end
        if input.IsKeyDown(KEY_ESCAPE) then
            if not self.closeKeyPressed then
                self.closeKeyPressed = true
                self:Remove()
                adminRoot = nil
                adminPanel = nil
            end
        else
            self.closeKeyPressed = false
        end
    end

    -- === ФРЕЙМ ===
    adminPanel = vgui.Create("SlashMoon.Frame", adminRoot)
    adminPanel:SetSize(SlashMoon.UI.Scale(1100), SlashMoon.UI.Scale(700))
    adminPanel:Center()
    adminPanel:SetHeader(SlashMoon.Tasks.Lang("sn.admin.title"))
    adminPanel.OnRemove = function()
        if IsValid(adminRoot) then adminRoot:Remove() end
        adminRoot = nil
    end

    -- === ТАБЫ ===
    local tabPanel = vgui.Create("SlashMoon.Panel", adminPanel)
    tabPanel:Dock(TOP)
    tabPanel:SetTall(SlashMoon.UI.Scale(40))
    tabPanel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(15), 0)

    local activeTab = "give"

    local giveTabBtn = vgui.Create("SlashMoon.Button", tabPanel)
    giveTabBtn:Dock(LEFT)
    giveTabBtn:SetWide(SlashMoon.UI.Scale(220))
    giveTabBtn:DockMargin(0, 0, SlashMoon.UI.Scale(8), 0)
    giveTabBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.admin.tab_give"))

    local constructorTabBtn = vgui.Create("SlashMoon.Button", tabPanel)
    constructorTabBtn:Dock(LEFT)
    constructorTabBtn:SetWide(SlashMoon.UI.Scale(220))
    constructorTabBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.admin.tab_constructor"))

    local recipeTabBtn = vgui.Create("SlashMoon.Button", tabPanel)
    recipeTabBtn:Dock(LEFT)
    recipeTabBtn:SetWide(SlashMoon.UI.Scale(220))
    recipeTabBtn:DockMargin(SlashMoon.UI.Scale(8), 0, 0, 0)
    recipeTabBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.admin.tab_recipes"))

    -- === КОНТЕНТ ОБЛАСТЬ ===
    local contentArea = vgui.Create("SlashMoon.Panel", adminPanel)
    contentArea:Dock(FILL)
    contentArea:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(15))

    local givePanel = nil
    local constructorPanel = nil
    local recipePanel = nil

    -- ════════════════════════════════════════════════════════════
    -- ФУНКЦИИ ПОСТРОЕНИЯ ТАБОВ
    -- ════════════════════════════════════════════════════════════

    local function SwitchTab(tab)
        activeTab = tab

        if givePanel and IsValid(givePanel) then givePanel:SetVisible(tab == "give") end
        if constructorPanel and IsValid(constructorPanel) then constructorPanel:SetVisible(tab == "constructor") end
        if recipePanel and IsValid(recipePanel) then recipePanel:SetVisible(tab == "recipes") end
    end

    giveTabBtn.DoClick = function() SwitchTab("give") end
    constructorTabBtn.DoClick = function() SwitchTab("constructor") end
    recipeTabBtn.DoClick = function() SwitchTab("recipes") end

    -- ════════════════════════════════════════════════════════════
    -- ТАБ: ВЫДАЧА ПРЕДМЕТОВ
    -- ════════════════════════════════════════════════════════════

    givePanel = vgui.Create("SlashMoon.Panel", contentArea)
    givePanel:Dock(FILL)

    -- --- Левая колонка: Игроки ---
    local leftCol = vgui.Create("SlashMoon.Panel", givePanel)
    leftCol:Dock(LEFT)
    leftCol:SetWide(SlashMoon.UI.Scale(280))
    leftCol:DockMargin(0, 0, SlashMoon.UI.Scale(10), 0)
    leftCol.Paint = function(self, w, h)
        surface.SetDrawColor(20, 20, 20, 200)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local playerLabel = vgui.Create("SlashMoon.Label", leftCol)
    playerLabel:Dock(TOP)
    playerLabel:SetTall(SlashMoon.UI.Scale(30))
    playerLabel:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(8), 0, 0)
    playerLabel:SetFont("SlashMoon.Text")
    playerLabel:SetTextColor(colors.TextMuted)
    playerLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.players"))

    local playerScroll = vgui.Create("SlashMoon.Scroll", leftCol)
    playerScroll:Dock(FILL)
    playerScroll:DockMargin(SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(5))

    local selectedPlayer = nil

    RefreshPlayerList = function()
        playerScroll:Clear()

        if #cachedPlayers == 0 then
            local empty = vgui.Create("SlashMoon.Label", playerScroll)
            empty:Dock(TOP)
            empty:SetTall(SlashMoon.UI.Scale(30))
            empty:DockMargin(10, 10, 10, 0)
            empty:SetFont("SlashMoon.Small")
            empty:SetTextColor(colors.TextMuted)
            empty:SetText(SlashMoon.Tasks.Lang("sn.admin.no_players"))
            return
        end

        for _, pData in ipairs(cachedPlayers) do
            local row = vgui.Create("SlashMoon.Button", playerScroll)
            row:Dock(TOP)
            row:SetTall(SlashMoon.UI.Scale(36))
            row:DockMargin(0, 0, 0, SlashMoon.UI.Scale(2))
            row:SetText("")

            local steamID = pData.steamID
            local pName   = pData.name

            row.Paint = function(self, w, h)
                local isSelected = (selectedPlayer == steamID)
                local isHovered  = self:IsHovered()

                local bgCol = isSelected and Color(40, 30, 60, 240)
                            or isHovered and Color(30, 25, 45, 230)
                            or Color(20, 20, 20, 220)
                surface.SetDrawColor(bgCol)
                surface.DrawRect(0, 0, w, h)

                if isSelected then
                    surface.SetDrawColor(colors.Theme)
                    surface.DrawRect(0, 0, 3, h)
                end

                surface.SetDrawColor(colors.Outline)
                surface.DrawOutlinedRect(0, 0, w, h, 1)

                -- Цвет статуса
                local statusCol = pData.alive and Color(80, 220, 100) or Color(255, 100, 80)
                surface.SetDrawColor(statusCol)
                surface.DrawRect(w - 8, h / 2 - 4, 6, 8)

                SlashMoon.UI.Draw.TextShadow(pName, "SlashMoon.Small",
                    10, h / 2,
                    color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            row.DoClick = function()
                selectedPlayer = steamID
                surface.PlaySound("UI/buttonclick.wav")
            end
        end
    end

    -- --- Центральная колонка: Предметы ---
    local centerCol = vgui.Create("SlashMoon.Panel", givePanel)
    centerCol:Dock(LEFT)
    centerCol:SetWide(SlashMoon.UI.Scale(420))
    centerCol:DockMargin(0, 0, SlashMoon.UI.Scale(10), 0)
    centerCol.Paint = function(self, w, h)
        surface.SetDrawColor(20, 20, 20, 200)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- Заголовок + фильтр
    local itemHeader = vgui.Create("SlashMoon.Panel", centerCol)
    itemHeader:Dock(TOP)
    itemHeader:SetTall(SlashMoon.UI.Scale(36))
    itemHeader:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(8), SlashMoon.UI.Scale(10), 0)
    itemHeader.Paint = function() end

    local itemLabel = vgui.Create("SlashMoon.Label", itemHeader)
    itemLabel:Dock(LEFT)
    itemLabel:SetWide(SlashMoon.UI.Scale(100))
    itemLabel:SetFont("SlashMoon.Text")
    itemLabel:SetTextColor(colors.TextMuted)
    itemLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.items"))

    -- Фильтр по типу
    local typeFilter = "all"
    local filterBtns = {}

    local filterPanel = vgui.Create("SlashMoon.Panel", centerCol)
    filterPanel:Dock(TOP)
    filterPanel:SetTall(SlashMoon.UI.Scale(28))
    filterPanel:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(4), SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(4))
    filterPanel.Paint = function() end

    local filterTypes = {
        { id = "all",        label = "Все" },
        { id = "material",   label = "Мат." },
        { id = "tool",       label = "Инстр." },
        { id = "weapon",     label = "Оруж." },
        { id = "consumable", label = "Расх." },
        { id = "electronic", label = "Электр." },
        { id = "quest",      label = "Квест" },
        { id = "chemical",   label = "Хим." },
        { id = "rare",       label = "Редк." },
    }

    for i, ft in ipairs(filterTypes) do
        local btn = vgui.Create("SlashMoon.Button", filterPanel)
        btn:Dock(LEFT)
        btn:SetWide(SlashMoon.UI.Scale(44))
        btn:DockMargin(i > 1 and SlashMoon.UI.Scale(3) or 0, 0, 0, 0)
        btn:SetText("")
        btn.FilterID = ft.id

        btn.Paint = function(self, w, h)
            local isActive = (typeFilter == self.FilterID)
            local isHovered = self:IsHovered()

            local bgCol = isActive and Color(colors.Accent.r, colors.Accent.g, colors.Accent.b, 180)
                        or isHovered and Color(40, 30, 60, 200)
                        or Color(25, 25, 25, 200)
            surface.SetDrawColor(bgCol)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(colors.Outline)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            SlashMoon.UI.Draw.TextShadow(ft.label, "SlashMoon.Small",
                w / 2, h / 2,
                isActive and color_white or colors.TextMuted,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function()
            typeFilter = ft.id
            RefreshItemList()
        end

        table.insert(filterBtns, btn)
    end

    local itemScroll = vgui.Create("SlashMoon.Scroll", centerCol)
    itemScroll:Dock(FILL)
    itemScroll:DockMargin(SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(5))

    local selectedItem = nil

    RefreshItemList = function()
        itemScroll:Clear()

        for _, itemData in ipairs(cachedItems) do
            -- Фильтр
            if typeFilter ~= "all" and itemData.type ~= typeFilter then continue end

            local row = vgui.Create("SlashMoon.Button", itemScroll)
            row:Dock(TOP)
            row:SetTall(SlashMoon.UI.Scale(44))
            row:DockMargin(0, 0, 0, SlashMoon.UI.Scale(2))
            row:SetText("")
            row.ItemClass = itemData.class

            local typeColor = SlashMoon.Tasks.GetTypeColor(itemData.type)

            row.Paint = function(self, w, h)
                local isSelected = (selectedItem == self.ItemClass)
                local isHovered  = self:IsHovered()

                local bgCol = isSelected and Color(40, 30, 60, 240)
                            or isHovered and Color(30, 25, 45, 230)
                            or Color(20, 20, 20, 220)
                surface.SetDrawColor(bgCol)
                surface.DrawRect(0, 0, w, h)

                -- Цвет типа
                surface.SetDrawColor(typeColor)
                surface.DrawRect(0, 0, 4, h)

                -- Редкость: рамка для оружия
                if itemData.type == "weapon" and itemData.rarity and itemData.rarity ~= "common" then
                    local rarityCol = SlashMoon.Tasks.GetRarityColor(itemData.rarity)
                    surface.SetDrawColor(rarityCol)
                    surface.DrawRect(w - 4, 0, 4, h)
                end

                if isSelected then
                    surface.SetDrawColor(colors.Theme)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                else
                    surface.SetDrawColor(colors.Outline)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end

                -- Иконка
                local mat = SlashMoon.Tasks.GetItemMaterial(self.ItemClass)
                if mat and not mat:IsError() then
                    local iconSize = h - 14
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(255, 255, 255, 220)
                    surface.DrawTexturedRect(10, (h - iconSize) / 2, iconSize, iconSize)
                end

                -- Название
                local displayName = itemData.custom and itemData.name or SlashMoon.Tasks.Lang(itemData.nameKey or itemData.name)
                if itemData.unique then displayName = displayName .. " ★" end
                if itemData.custom then displayName = displayName .. " ⚙" end

                SlashMoon.UI.Draw.TextShadow(displayName, "SlashMoon.Small",
                    h, h / 2 - SlashMoon.UI.Scale(5),
                    color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                -- Класс
                SlashMoon.UI.Draw.TextShadow(self.ItemClass, "SlashMoon.Small",
                    h, h / 2 + SlashMoon.UI.Scale(5),
                    colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            row.DoClick = function()
                selectedItem = row.ItemClass
                surface.PlaySound("UI/buttonclick.wav")
            end
        end
    end

    RefreshItemList()

    -- --- Правая колонка: Действие ---
    local rightCol = vgui.Create("SlashMoon.Panel", givePanel)
    rightCol:Dock(FILL)
    rightCol.Paint = function(self, w, h)
        surface.SetDrawColor(20, 20, 20, 200)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local actionLabel = vgui.Create("SlashMoon.Label", rightCol)
    actionLabel:Dock(TOP)
    actionLabel:SetTall(SlashMoon.UI.Scale(30))
    actionLabel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(10), 0, 0)
    actionLabel:SetFont("SlashMoon.Text")
    actionLabel:SetTextColor(colors.TextMuted)
    actionLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.action"))

    -- Выбранный предмет (информация)
    local infoPanel = vgui.Create("SlashMoon.Panel", rightCol)
    infoPanel:Dock(TOP)
    infoPanel:SetTall(SlashMoon.UI.Scale(120))
    infoPanel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(15), 0)
    infoPanel.Paint = function(self, w, h)
        surface.SetDrawColor(15, 15, 15, 240)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        if not selectedItem then
            SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.admin.select_item"), "SlashMoon.Small",
                w / 2, h / 2,
                colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local itemData = nil
        for _, it in ipairs(cachedItems) do
            if it.class == selectedItem then itemData = it break end
        end
        if not itemData then return end

        local typeColor = SlashMoon.Tasks.GetTypeColor(itemData.type)
        surface.SetDrawColor(typeColor)
        surface.DrawRect(0, 0, 4, h)

        -- Иконка
        local mat = SlashMoon.Tasks.GetItemMaterial(selectedItem)
        if mat and not mat:IsError() then
            local iconSize = 40
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, 240)
            surface.DrawTexturedRect(12, 10, iconSize, iconSize)
        end

        local nameX = 60
        local displayName = itemData.custom and itemData.name or SlashMoon.Tasks.Lang(itemData.nameKey or itemData.name)
        SlashMoon.UI.Draw.TextShadow(displayName, "SlashMoon.Text",
            nameX, 20,
            color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        SlashMoon.UI.Draw.TextShadow(selectedItem, "SlashMoon.Small",
            nameX, 40,
            colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local typeLabel = itemData.type:upper()
        SlashMoon.UI.Draw.TextShadow(typeLabel, "SlashMoon.Small",
            nameX, 58,
            typeColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Редкость (для оружия)
        if itemData.type == "weapon" and itemData.rarity then
            local rarityCol = SlashMoon.Tasks.GetRarityColor(itemData.rarity)
            local rarityName = SlashMoon.Tasks.GetRarityName(itemData.rarity)
            SlashMoon.UI.Draw.TextShadow("[" .. rarityName .. "]", "SlashMoon.Small",
                nameX + 80, 58,
                rarityCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- Описание
        if itemData.description and itemData.description ~= "" then
            local description = itemData.custom and itemData.description or SlashMoon.Tasks.Lang(itemData.descriptionKey or itemData.description)
            SlashMoon.UI.Draw.TextShadow(description, "SlashMoon.Small",
                nameX, 80,
                colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    -- Количество
    local amountPanel = vgui.Create("SlashMoon.Panel", rightCol)
    amountPanel:Dock(TOP)
    amountPanel:SetTall(SlashMoon.UI.Scale(40))
    amountPanel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(15), 0)
    amountPanel.Paint = function() end

    local amountLabel = vgui.Create("SlashMoon.Label", amountPanel)
    amountLabel:Dock(LEFT)
    amountLabel:SetWide(SlashMoon.UI.Scale(100))
    amountLabel:DockMargin(0, 0, SlashMoon.UI.Scale(10), 0)
    amountLabel:SetFont("SlashMoon.Text")
    amountLabel:SetTextColor(colors.TextMuted)
    amountLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.amount"))

    local amountSlider = vgui.Create("SlashMoon.Slider", amountPanel)
    amountSlider:Dock(FILL)
    amountSlider:SetMin(1)
    amountSlider:SetMax(64)
    amountSlider:SetDecimals(0)
    amountSlider:SetValue(1)

    -- Кнопка выдачи
    local giveBtn = vgui.Create("SlashMoon.Button", rightCol)
    giveBtn:Dock(BOTTOM)
    giveBtn:SetTall(SlashMoon.UI.Scale(50))
    giveBtn:DockMargin(SlashMoon.UI.Scale(15), 0, SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(15))
    giveBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.admin.give_btn"))

    giveBtn.DoClick = function()
        if not selectedPlayer then
            chat.AddText(Color(255, 100, 80), "[SN Admin] ", color_white, SlashMoon.Tasks.Lang("sn.admin.select_player"))
            return
        end
        if not selectedItem then
            chat.AddText(Color(255, 100, 80), "[SN Admin] ", color_white, SlashMoon.Tasks.Lang("sn.admin.select_item"))
            return
        end

        local amount = math.Clamp(math.Round(amountSlider:GetValue()), 1, 64)

        net.Start("SN_AdminInv_GiveItem")
            net.WriteString(selectedPlayer)
            net.WriteString(selectedItem)
            net.WriteUInt(amount, 8)
        net.SendToServer()

        surface.PlaySound("buttons/button14.wav")
    end

    -- ════════════════════════════════════════════════════════════
    -- ТАБ: КОНСТРУКТОР ПРЕДМЕТОВ
    -- Теперь с Описание, Редкость, Стакируемость
    -- ════════════════════════════════════════════════════════════

    constructorPanel = vgui.Create("SlashMoon.Panel", contentArea)
    constructorPanel:Dock(FILL)
    constructorPanel:SetVisible(false)

    -- Форма создания предмета
    local formPanel = vgui.Create("SlashMoon.Panel", constructorPanel)
    formPanel:Dock(TOP)
    formPanel:SetTall(SlashMoon.UI.Scale(520))
    formPanel.Paint = function(self, w, h)
        surface.SetDrawColor(20, 20, 20, 200)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local formTitle = vgui.Create("SlashMoon.Label", formPanel)
    formTitle:Dock(TOP)
    formTitle:SetTall(SlashMoon.UI.Scale(30))
    formTitle:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(10), 0, 0)
    formTitle:SetFont("SlashMoon.Text")
    formTitle:SetTextColor(colors.TextMuted)
    formTitle:SetText(SlashMoon.Tasks.Lang("sn.admin.constructor_title"))

    -- Поля ввода
    local fieldY = SlashMoon.UI.Scale(50)
    local fieldH = SlashMoon.UI.Scale(36)
    local fieldGap = SlashMoon.UI.Scale(50)
    local fieldMargin = SlashMoon.UI.Scale(15)

    -- Класс
    local classLabel = vgui.Create("SlashMoon.Label", formPanel)
    classLabel:SetPos(fieldMargin, fieldY)
    classLabel:SetSize(SlashMoon.UI.Scale(200), fieldH)
    classLabel:SetFont("SlashMoon.Small")
    classLabel:SetTextColor(colors.TextMuted)
    classLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.field_class"))

    local classEntry = vgui.Create("SlashMoon.TextEntry", formPanel)
    classEntry:SetPos(SlashMoon.UI.Scale(220), fieldY)
    classEntry:SetSize(SlashMoon.UI.Scale(400), fieldH)
    classEntry:SetPlaceholderText("custom_my_item (префикс custom_ добавится авто.)")

    -- Название
    fieldY = fieldY + fieldGap
    local nameLabel = vgui.Create("SlashMoon.Label", formPanel)
    nameLabel:SetPos(fieldMargin, fieldY)
    nameLabel:SetSize(SlashMoon.UI.Scale(200), fieldH)
    nameLabel:SetFont("SlashMoon.Small")
    nameLabel:SetTextColor(colors.TextMuted)
    nameLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.field_name"))

    local nameEntry = vgui.Create("SlashMoon.TextEntry", formPanel)
    nameEntry:SetPos(SlashMoon.UI.Scale(220), fieldY)
    nameEntry:SetSize(SlashMoon.UI.Scale(400), fieldH)
    nameEntry:SetPlaceholderText("Мой Кастомный Предмет")

    -- Тип
    fieldY = fieldY + fieldGap
    local typeLabel = vgui.Create("SlashMoon.Label", formPanel)
    typeLabel:SetPos(fieldMargin, fieldY)
    typeLabel:SetSize(SlashMoon.UI.Scale(200), fieldH)
    typeLabel:SetFont("SlashMoon.Small")
    typeLabel:SetTextColor(colors.TextMuted)
    typeLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.field_type"))

    local typeCombo = vgui.Create("SlashMoon.ComboBox", formPanel)
    typeCombo:SetPos(SlashMoon.UI.Scale(220), fieldY)
    typeCombo:SetSize(SlashMoon.UI.Scale(400), fieldH)
    typeCombo:AddChoice("material", "material", true)
    typeCombo:AddChoice("tool", "tool")
    typeCombo:AddChoice("weapon", "weapon")
    typeCombo:AddChoice("consumable", "consumable")
    typeCombo:AddChoice("electronic", "electronic")
    typeCombo:AddChoice("quest", "quest")
    typeCombo:AddChoice("chemical", "chemical")
    typeCombo:AddChoice("rare", "rare")

    -- Редкость
    fieldY = fieldY + fieldGap
    local rarityLabel = vgui.Create("SlashMoon.Label", formPanel)
    rarityLabel:SetPos(fieldMargin, fieldY)
    rarityLabel:SetSize(SlashMoon.UI.Scale(200), fieldH)
    rarityLabel:SetFont("SlashMoon.Small")
    rarityLabel:SetTextColor(colors.TextMuted)
    rarityLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.field_rarity"))

    local rarityCombo = vgui.Create("SlashMoon.ComboBox", formPanel)
    rarityCombo:SetPos(SlashMoon.UI.Scale(220), fieldY)
    rarityCombo:SetSize(SlashMoon.UI.Scale(400), fieldH)
    rarityCombo:AddChoice("common", "common", true)
    rarityCombo:AddChoice("uncommon", "uncommon")
    rarityCombo:AddChoice("rare", "rare")
    rarityCombo:AddChoice("epic", "epic")
    rarityCombo:AddChoice("legendary", "legendary")

    -- Иконка (путь)
    fieldY = fieldY + fieldGap
    local iconLabel = vgui.Create("SlashMoon.Label", formPanel)
    iconLabel:SetPos(fieldMargin, fieldY)
    iconLabel:SetSize(SlashMoon.UI.Scale(200), fieldH)
    iconLabel:SetFont("SlashMoon.Small")
    iconLabel:SetTextColor(colors.TextMuted)
    iconLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.field_icon"))

    local iconEntry = vgui.Create("SlashMoon.TextEntry", formPanel)
    iconEntry:SetPos(SlashMoon.UI.Scale(220), fieldY)
    iconEntry:SetSize(SlashMoon.UI.Scale(400), fieldH)
    iconEntry:SetPlaceholderText("materials/sn_task/items/my_item.png (опционально)")

    -- Описание
    fieldY = fieldY + fieldGap
    local descLabel = vgui.Create("SlashMoon.Label", formPanel)
    descLabel:SetPos(fieldMargin, fieldY)
    descLabel:SetSize(SlashMoon.UI.Scale(200), fieldH)
    descLabel:SetFont("SlashMoon.Small")
    descLabel:SetTextColor(colors.TextMuted)
    descLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.field_description"))

    local descEntry = vgui.Create("SlashMoon.TextEntry", formPanel)
    descEntry:SetPos(SlashMoon.UI.Scale(220), fieldY)
    descEntry:SetSize(SlashMoon.UI.Scale(400), fieldH)
    descEntry:SetPlaceholderText("Описание предмета... (опционально)")

    -- Стакируемость (чекбокс)
    fieldY = fieldY + fieldGap
    local stackLabel = vgui.Create("SlashMoon.Label", formPanel)
    stackLabel:SetPos(fieldMargin, fieldY)
    stackLabel:SetSize(SlashMoon.UI.Scale(200), fieldH)
    stackLabel:SetFont("SlashMoon.Small")
    stackLabel:SetTextColor(colors.TextMuted)
    stackLabel:SetText(SlashMoon.Tasks.Lang("sn.admin.field_stackable"))

    local stackCheckbox = vgui.Create("SlashMoon.Checkbox", formPanel)
    stackCheckbox:SetPos(SlashMoon.UI.Scale(220), fieldY + SlashMoon.UI.Scale(4))
    stackCheckbox:SetSize(SlashMoon.UI.Scale(28), SlashMoon.UI.Scale(28))

    -- Кнопки
    fieldY = fieldY + fieldGap + SlashMoon.UI.Scale(10)

    local createBtn = vgui.Create("SlashMoon.Button", formPanel)
    createBtn:SetPos(SlashMoon.UI.Scale(220), fieldY)
    createBtn:SetSize(SlashMoon.UI.Scale(190), SlashMoon.UI.Scale(44))
    createBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.admin.create_btn"))

    createBtn.DoClick = function()
        local class = classEntry:GetText()
        local name  = nameEntry:GetText()
        local _, itemType = typeCombo:GetSelected()
        local icon  = iconEntry:GetText()
        local description = descEntry:GetText()
        local _, rarity = rarityCombo:GetSelected()
        local stackable = stackCheckbox:GetChecked()

        if class == "" then
            chat.AddText(Color(255, 100, 80), "[SN Admin] ", color_white, SlashMoon.Tasks.Lang("sn.admin.invalid_class"))
            return
        end
        if name == "" then
            chat.AddText(Color(255, 100, 80), "[SN Admin] ", color_white, SlashMoon.Tasks.Lang("sn.admin.invalid_name"))
            return
        end

        net.Start("SN_AdminInv_CreateItem")
            net.WriteString(class)
            net.WriteString(name)
            net.WriteString(itemType or "material")
            net.WriteString(icon)
            net.WriteString(description)
            net.WriteString(rarity or "common")
            net.WriteBool(stackable)
        net.SendToServer()

        surface.PlaySound("buttons/button14.wav")

        -- Очистка полей
        classEntry:SetText("")
        nameEntry:SetText("")
        iconEntry:SetText("")
        descEntry:SetText("")
        stackCheckbox:SetChecked(false)
    end

    -- --- Список кастомных предметов ---
    local customScroll = vgui.Create("SlashMoon.Scroll", constructorPanel)
    customScroll:Dock(FILL)
    customScroll:DockMargin(0, SlashMoon.UI.Scale(10), 0, 0)

    -- Заполняем кастомные предметы
    for _, customItem in ipairs(cachedCustom) do
        local row = vgui.Create("SlashMoon.Panel", customScroll)
        row:Dock(TOP)
        row:SetTall(SlashMoon.UI.Scale(44))
        row:DockMargin(0, 0, 0, SlashMoon.UI.Scale(2))

        local typeColor = SlashMoon.Tasks.GetTypeColor(customItem.type)
        local rarityColor = SlashMoon.Tasks.GetRarityColor(customItem.rarity or "common")

        row.Paint = function(self, w, h)
            surface.SetDrawColor(20, 20, 20, 220)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(typeColor)
            surface.DrawRect(0, 0, 4, h)

            -- Редкость полоска справа
            if customItem.type == "weapon" and customItem.rarity and customItem.rarity ~= "common" then
                surface.SetDrawColor(rarityColor)
                surface.DrawRect(w - 4, 0, 4, h)
            end

            surface.SetDrawColor(colors.Outline)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            SlashMoon.UI.Draw.TextShadow(customItem.name, "SlashMoon.Small",
                12, h / 2 - SlashMoon.UI.Scale(5),
                color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            local subText = customItem.class
            if customItem.rarity and customItem.rarity ~= "common" then
                subText = subText .. " [" .. (customItem.rarity or "") .. "]"
            end
            SlashMoon.UI.Draw.TextShadow(subText, "SlashMoon.Small",
                12, h / 2 + SlashMoon.UI.Scale(5),
                colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local deleteBtn = vgui.Create("SlashMoon.Button", row)
        deleteBtn:Dock(RIGHT)
        deleteBtn:SetWide(SlashMoon.UI.Scale(80))
        deleteBtn:DockMargin(SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(5))
        deleteBtn:SetBtnText("✖")

        deleteBtn.DoClick = function()
            net.Start("SN_AdminInv_RemoveItem")
                net.WriteString(customItem.class)
            net.SendToServer()
            surface.PlaySound("buttons/button10.wav")
        end
    end

    -- ════════════════════════════════════════════════════════════
    -- ТАБ: РЕЦЕПТЫ ДОСТАВКИ
    -- ════════════════════════════════════════════════════════════
    recipePanel = vgui.Create("SlashMoon.Panel", contentArea)
    recipePanel:Dock(FILL)
    recipePanel:SetVisible(false)

    local recipeForm = vgui.Create("SlashMoon.Panel", recipePanel)
    recipeForm:Dock(TOP)
    recipeForm:SetTall(SlashMoon.UI.Scale(300))
    recipeForm.Paint = function(self, w, h)
        surface.SetDrawColor(20, 20, 20, 220)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local function AddRecipeField(label, placeholder, y)
        local lbl = vgui.Create("SlashMoon.Label", recipeForm)
        lbl:SetPos(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(y))
        lbl:SetSize(SlashMoon.UI.Scale(190), SlashMoon.UI.Scale(34))
        lbl:SetFont("SlashMoon.Small")
        lbl:SetTextColor(colors.TextMuted)
        lbl:SetText(label)

        local entry = vgui.Create("SlashMoon.TextEntry", recipeForm)
        entry:SetPos(SlashMoon.UI.Scale(210), SlashMoon.UI.Scale(y))
        entry:SetSize(SlashMoon.UI.Scale(600), SlashMoon.UI.Scale(34))
        entry:SetPlaceholderText(placeholder)
        return entry
    end

    local recipeID = AddRecipeField(SlashMoon.Tasks.Lang("sn.admin.recipe_id"), "receiver_repair", 15)
    local recipeName = AddRecipeField(SlashMoon.Tasks.Lang("sn.admin.recipe_name"), "Receiver repair", 57)
    local recipeResult = AddRecipeField(SlashMoon.Tasks.Lang("sn.admin.recipe_result"), "item_delivery_receiver", 99)
    local recipeIngredients = AddRecipeField(SlashMoon.Tasks.Lang("sn.admin.recipe_ingredients"), "mat_wire, mat_scrap, mat_chip", 141)
    local recipeTime = AddRecipeField(SlashMoon.Tasks.Lang("sn.admin.recipe_time"), "6", 183)

    local createRecipe = vgui.Create("SlashMoon.Button", recipeForm)
    createRecipe:SetPos(SlashMoon.UI.Scale(210), SlashMoon.UI.Scale(232))
    createRecipe:SetSize(SlashMoon.UI.Scale(250), SlashMoon.UI.Scale(45))
    createRecipe:SetBtnText(SlashMoon.Tasks.Lang("sn.admin.recipe_create"))
    createRecipe.DoClick = function()
        local ingredients = {}
        for _, ingredient in ipairs(string.Explode(",", recipeIngredients:GetText())) do
            ingredient = string.Trim(ingredient)
            if ingredient ~= "" then ingredients[#ingredients + 1] = ingredient end
        end
        if #ingredients == 0 then
            chat.AddText(Color(255, 100, 80), "[SN Admin] ", color_white, SlashMoon.Tasks.Lang("sn.admin.recipe_invalid"))
            return
        end

        net.Start("SN_AdminInv_CreateRecipe")
            net.WriteString(recipeID:GetText())
            net.WriteString(recipeName:GetText())
            net.WriteString(recipeResult:GetText())
            net.WriteUInt(math.Clamp(tonumber(recipeTime:GetText()) or 5, 1, 60), 8)
            net.WriteUInt(math.min(#ingredients, 16), 5)
            for i = 1, math.min(#ingredients, 16) do net.WriteString(ingredients[i]) end
        net.SendToServer()
    end

    local recipeScroll = vgui.Create("SlashMoon.Scroll", recipePanel)
    recipeScroll:Dock(FILL)
    recipeScroll:DockMargin(0, SlashMoon.UI.Scale(10), 0, 0)

    RefreshRecipeList = function()
        if not IsValid(recipeScroll) then return end
        recipeScroll:Clear()
        for _, recipe in ipairs(cachedRecipes) do
            local recipeData = recipe
            local row = vgui.Create("SlashMoon.Panel", recipeScroll)
            row:Dock(TOP)
            row:SetTall(SlashMoon.UI.Scale(48))
            row:DockMargin(0, 0, 0, SlashMoon.UI.Scale(3))
            row.Paint = function(self, w, h)
                surface.SetDrawColor(20, 20, 20, 220)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(colors.Theme)
                surface.DrawRect(0, 0, 4, h)
                surface.SetDrawColor(colors.Outline)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(recipeData.name, "SlashMoon.Small", 14, 15, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(recipeData.id .. " -> " .. recipeData.result .. " | " .. table.concat(recipeData.ingredients, ", "), "AdminSmall", 14, 34, colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            local remove = vgui.Create("SlashMoon.Button", row)
            remove:Dock(RIGHT)
            remove:SetWide(SlashMoon.UI.Scale(80))
            remove:DockMargin(5, 5, 5, 5)
            remove:SetBtnText("X")
            remove.DoClick = function()
                net.Start("SN_AdminInv_RemoveRecipe")
                    net.WriteString(recipeData.id)
                net.SendToServer()
            end
        end
    end
    RefreshRecipeList()

    -- Начальное состояние
    SwitchTab("give")
end

-- ========================================================
-- КОНСОЛЬНАЯ КОМАНДА
-- ========================================================
MODULE:Command("sn_admin_inv", function()
    SlashMoon.Tasks.OpenAdminPanel()
end, nil, "Открыть админ-панель инвентаря (Admin)")

-- ========================================================
-- БИНД: F6 = Админка
-- ========================================================
MODULE:Hook("PlayerButtonDown", "SN_AdminInv_Bind", function(ply, key)
    if key ~= KEY_F6 then return end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_admin") then return end
    SlashMoon.Tasks.OpenAdminPanel()
end)
