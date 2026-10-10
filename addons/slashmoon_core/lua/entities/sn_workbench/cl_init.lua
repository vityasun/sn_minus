-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Workbench Entity (Client — UI + Rendering)
-- Верстак: интерфейс крафта, 3D2D подсказки, прогресс
-- Дизайн: двухпанельный (рецепты | детали), toast-ы
-- ========================================================
include("shared.lua")

-- Защита от race condition: SlashMoon.Tasks может быть ещё не определён,
-- т.к. авторун оборачивает инициализацию в timer.Simple(0)
SlashMoon.Tasks = SlashMoon.Tasks or {}

-- === ШРИФТЫ ===
SlashMoon.UI.CreateFont("WorkbenchTitle", 28, 800)
SlashMoon.UI.CreateFont("WorkbenchText", 18, 500)
SlashMoon.UI.CreateFont("WorkbenchSmall", 14, 500)

-- === ЛОКАЛЬНЫЕ ПЕРЕМЕННЫЕ ===
local colors = SlashMoon.UI.Colors
local wbRoot       = nil   -- Корневая панель UI (затемнение)
local wbMenu       = nil   -- SN_Frame
local CraftProgress = 0    -- Текущий прогресс крафта (0-1)
local IsCrafting    = false
local CurrentWorkbench = NULL
local ActiveCraftWorkbench = NULL

-- ========================================================
-- ОТРИСОВКА МОДЕЛИ
-- ========================================================
function ENT:Draw()
    self:DrawModel()
end

-- ========================================================
-- 3D2D ПОДСКАЗКА НАД ВЕРСТАКОМ
-- ========================================================
MODULE:Hook("PostDrawTranslucentRenderables", "SN_Workbench_3D2D_Hint", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "sn_workbench" then return end
    if ply:GetPos():Distance(ent:GetPos()) > 120 then return end

    local pos = ent:GetPos() + Vector(0, 0, 25)
    local ang = (pos - ply:GetPos()):Angle()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, 0.1)
        local hint = SlashMoon.Tasks.Lang("sn.workbench.3d_hint")
        SlashMoon.UI.Draw.TextShadow(hint, "SlashMoon.Header", 0, 0, Color(50, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end)

-- ========================================================
-- HUD ПОДСКАЗКА (ЦЕЛИМСЯ В ВЕРСТАК)
-- ========================================================
MODULE:Hook("HUDPaint", "SN_Workbench_HUD", function()
    local ply = LocalPlayer()
    if not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "sn_workbench" then return end
    if ply:GetPos():Distance(ent:GetPos()) > 80 then return end

    local sw, sh = ScrW(), ScrH()
    local isCrafting = ent:GetNW2Bool("SN_Crafting", false)
    local crafter   = ent:GetNW2Entity("SN_Crafter")

    if isCrafting and crafter ~= ply then
        local busyText = SlashMoon.Tasks.Lang("sn.workbench.busy")
        SlashMoon.UI.Draw.TextShadow(busyText, "SlashMoon.Header", sw / 2, sh / 2 + SlashMoon.UI.Scale(40), Color(255, 80, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        local openHint = SlashMoon.Tasks.Lang("sn.workbench.open_hint")
        SlashMoon.UI.Draw.TextShadow(openHint, "SlashMoon.Header", sw / 2, sh / 2 + SlashMoon.UI.Scale(40), Color(50, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- ========================================================
-- TOAST УВЕДОМЛЕНИЯ
-- ========================================================
SlashMoon.Tasks._wbToasts = SlashMoon.Tasks._wbToasts or {}

local function ShowWorkbenchToast(message, success)
    local toast = {
        message = message,
        success = success,
        startT  = CurTime(),
        duration = 2.5,
    }
    table.insert(SlashMoon.Tasks._wbToasts, toast)
end

MODULE:Hook("HUDPaint", "SN_Workbench_Toasts", function()
    local y = ScrH() / 2 + SlashMoon.UI.Scale(150)
    local now = CurTime()

    for i = #SlashMoon.Tasks._wbToasts, 1, -1 do
        local t = SlashMoon.Tasks._wbToasts[i]
        if now - t.startT > t.duration then
            table.remove(SlashMoon.Tasks._wbToasts, i)
        end
    end

    for _, t in ipairs(SlashMoon.Tasks._wbToasts) do
        local elapsed = now - t.startT
        local alpha = 255
        if elapsed < 0.2 then
            alpha = math.Clamp(elapsed / 0.2 * 255, 0, 255)
        elseif elapsed > t.duration - 0.5 then
            alpha = math.Clamp((t.duration - elapsed) / 0.5 * 255, 0, 255)
        end

        local col = t.success and Color(80, 220, 100, alpha) or Color(255, 100, 80, alpha)
        local w, h = SlashMoon.UI.Scale(420), SlashMoon.UI.Scale(36)
        local x = ScrW() / 2 - w / 2

        surface.SetDrawColor(15, 15, 15, alpha * 0.9)
        surface.DrawRect(x, y, w, h)
        surface.SetDrawColor(col)
        surface.DrawRect(x, y, 4, h)
        surface.SetDrawColor(col.r, col.g, col.b, alpha * 0.4)
        surface.DrawOutlinedRect(x, y, w, h, 1)

        SlashMoon.UI.Draw.TextShadow(t.message, "SlashMoon.Text", x + w / 2, y + h / 2,
            Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        y = y + h + SlashMoon.UI.Scale(4)
    end
end)

-- ========================================================
-- ИНТЕРФЕЙС КРАФТА
-- ========================================================

local function CloseWorkbenchUI()
    if IsValid(wbRoot) then wbRoot:Remove() end
    wbRoot       = nil
    wbMenu       = nil
    CurrentWorkbench = NULL
end

-- Обработчик сетевого сообщения: открытие верстака
MODULE:Receive("SN_Workbench_Open", function()
    local workbench = net.ReadEntity()
    if not IsValid(workbench) then return end

    -- Чтение рецептов
    local recipeCount = net.ReadUInt(8)
    local recipes = {}
    for i = 1, recipeCount do
        local r = {}
        r.id          = net.ReadString()
        r.nameKey     = net.ReadString()
        r.result      = net.ReadString()
        r.craftTime   = net.ReadFloat()
        r.canCraft    = net.ReadBool()

        local ingCount = net.ReadUInt(8)
        r.ingredients = {}
        for j = 1, ingCount do
            table.insert(r.ingredients, net.ReadString())
        end

        table.insert(recipes, r)
    end

    -- Чтение рюкзака
    local bpCount = net.ReadUInt(8)
    local backpack = {}
    for i = 1, bpCount do
        table.insert(backpack, net.ReadString())
    end

    -- Закрыть предыдущее окно
    CloseWorkbenchUI()
    CurrentWorkbench = workbench

    -- === КОРНЕВАЯ ПАНЕЛЬ (затемнение) ===
    wbRoot = vgui.Create("SlashMoon.Panel")
    wbRoot:SetSize(ScrW(), ScrH())
    wbRoot:MakePopup()
    wbRoot:SetKeyboardInputEnabled(false)
    -- ESC закрывает верстак, а не открывает меню паузы
    SlashMoon.UI.PushEscape(wbRoot, CloseWorkbenchUI)
    wbRoot.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 120)
        surface.DrawRect(0, 0, w, h)
    end

    wbRoot.openTime = CurTime()
    wbRoot.Think = function(self)
        if CurTime() - self.openTime < 0.2 then return end
        local inventoryKey = SlashMoon.Tasks.GetInventoryKey and SlashMoon.Tasks.GetInventoryKey() or KEY_I
        if input.IsKeyDown(KEY_ESCAPE) or input.IsKeyDown(inventoryKey) then
            if not self.closeKeyPressed then
                self.closeKeyPressed = true
                CloseWorkbenchUI()
            end
        else
            self.closeKeyPressed = false
        end
    end

    -- === ФРЕЙМ ===
    wbMenu = vgui.Create("SlashMoon.Frame", wbRoot)
    wbMenu:SetSize(SlashMoon.UI.Scale(900), SlashMoon.UI.Scale(640))
    wbMenu:Center()
    wbMenu:SetHeader(SlashMoon.Tasks.Lang("sn.workbench.title"))
    wbMenu.SelectedRecipe = nil
    wbMenu.OnRemove = function()
        if IsValid(wbRoot) then wbRoot:Remove() end
        CurrentWorkbench = NULL
    end

    -- === ЛЕВАЯ ПАНЕЛЬ: список рецептов ===
    local leftPanel = vgui.Create("SlashMoon.Panel", wbMenu)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(SlashMoon.UI.Scale(420))
    leftPanel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(15), 0, SlashMoon.UI.Scale(15))
    leftPanel.Paint = function(self, w, h)
        surface.SetDrawColor(20, 20, 20, 200)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.workbench.recipes"),
            "SlashMoon.Header", SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(20),
            colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local recipeScroll = vgui.Create("SlashMoon.Scroll", leftPanel)
    recipeScroll:Dock(FILL)
    recipeScroll:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(40), SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(10))

    -- === ПРАВАЯ ПАНЕЛЬ: детали выбранного рецепта ===
    local rightPanel = vgui.Create("SlashMoon.Panel", wbMenu)
    rightPanel:Dock(FILL)
    rightPanel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(15))
    rightPanel.Paint = function(self, w, h)
        surface.SetDrawColor(15, 15, 15, 240)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local detailTitle = vgui.Create("SlashMoon.Label", rightPanel)
    detailTitle:Dock(TOP)
    detailTitle:SetTall(SlashMoon.UI.Scale(40))
    detailTitle:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(15), 0)
    detailTitle:SetFont("SlashMoon.Header")
    detailTitle:SetTextColor(color_white)
    detailTitle:SetText("")

    local detailScroll = vgui.Create("SlashMoon.Scroll", rightPanel)
    detailScroll:Dock(FILL)
    detailScroll:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(70))

    -- Кнопка крафта (внизу правой панели)
    local craftBtn = vgui.Create("SlashMoon.Button", rightPanel)
    craftBtn:Dock(BOTTOM)
    craftBtn:SetTall(SlashMoon.UI.Scale(50))
    craftBtn:DockMargin(SlashMoon.UI.Scale(15), 0, SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(15))
    craftBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.workbench.craft_btn"))
    craftBtn:SetEnabled(false)

    local pinBtn = vgui.Create("SlashMoon.Button", rightPanel)
    pinBtn:Dock(BOTTOM)
    pinBtn:SetTall(SlashMoon.UI.Scale(36))
    pinBtn:DockMargin(SlashMoon.UI.Scale(15), 0, SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(6))
    pinBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.workbench.pin_recipe"))
    pinBtn:SetEnabled(false)
    pinBtn.Think = function(self)
        local selectedID = wbMenu.SelectedRecipe
        local isPinned = SlashMoon.Tasks.PinnedRecipe and SlashMoon.Tasks.PinnedRecipe.id == selectedID
        local targetText = isPinned
            and SlashMoon.Tasks.Lang("sn.workbench.unpin_recipe")
            or SlashMoon.Tasks.Lang("sn.workbench.pin_recipe")
        if self.BtnText ~= targetText then self:SetBtnText(targetText) end
    end

    -- Подсчёт предметов в рюкзаке для have/need
    local function CountBackpackItems()
        local counts = {}
        for _, item in ipairs(backpack) do
            local parsed = SlashMoon.Tasks.ParseItemEntry(item)
            counts[parsed.baseClass] = (counts[parsed.baseClass] or 0) + parsed.count
        end
        return counts
    end

    -- === Показать детали рецепта ===
    local function ShowRecipeDetail(recipeID)
        local recipe = nil
        for _, r in ipairs(recipes) do
            if r.id == recipeID then recipe = r break end
        end
        if not recipe then return end

        detailScroll:Clear()

        -- Локализованное имя рецепта
        local recipeName = SlashMoon.Tasks.Lang(recipe.nameKey)
        detailTitle:SetText(recipeName)

        pinBtn:SetEnabled(true)
        pinBtn:SetBtnText(SlashMoon.Tasks.PinnedRecipe and SlashMoon.Tasks.PinnedRecipe.id == recipe.id
            and SlashMoon.Tasks.Lang("sn.workbench.unpin_recipe")
            or SlashMoon.Tasks.Lang("sn.workbench.pin_recipe"))
        pinBtn.DoClick = function()
            local isPinned = SlashMoon.Tasks.PinnedRecipe and SlashMoon.Tasks.PinnedRecipe.id == recipe.id
            net.Start("SN_Workbench_PinRecipe")
                net.WriteString(isPinned and "" or recipe.id)
            net.SendToServer()
            surface.PlaySound("buttons/button14.wav")
        end

        -- Ингредиенты
        local ingHeader = vgui.Create("SlashMoon.Label", detailScroll)
        ingHeader:Dock(TOP)
        ingHeader:SetTall(SlashMoon.UI.Scale(28))
        ingHeader:DockMargin(0, 0, 0, SlashMoon.UI.Scale(6))
        ingHeader:SetFont("SlashMoon.Text")
        ingHeader:SetTextColor(colors.TextMuted)
        ingHeader:SetText(SlashMoon.Tasks.Lang("sn.workbench.requires"))

        local have = CountBackpackItems()

        -- Подсчёт необходимых ингредиентов
        local needed = {}
        for _, ing in ipairs(recipe.ingredients) do
            needed[ing] = (needed[ing] or 0) + 1
        end

        for neededClass, neededCount in pairs(needed) do
            local itemData = SlashMoon.Tasks.GetItemData(neededClass)
            local haveCount = have[neededClass] or 0
            local enough = haveCount >= neededCount

            local row = vgui.Create("SlashMoon.Panel", detailScroll)
            row:Dock(TOP)
            row:SetTall(SlashMoon.UI.Scale(48))
            row:DockMargin(0, 0, 0, SlashMoon.UI.Scale(4))
            row.Paint = function(self, w, h)
                surface.SetDrawColor(20, 20, 20, 220)
                surface.DrawRect(0, 0, w, h)

                local typeColor = SlashMoon.Tasks.GetTypeColor(itemData.type)
                surface.SetDrawColor(typeColor)
                surface.DrawRect(0, 0, 4, h)

                if self:IsHovered() then
                    surface.SetDrawColor(typeColor.r, typeColor.g, typeColor.b, 40)
                    surface.DrawRect(0, 0, w, h)
                end

                surface.SetDrawColor(colors.Outline)
                surface.DrawOutlinedRect(0, 0, w, h, 1)

                -- Иконка
                local mat = SlashMoon.Tasks.GetItemMaterial(neededClass)
                if mat and not mat:IsError() then
                    local iconSize = h - 12
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(255, 255, 255, 220)
                    surface.DrawTexturedRect(12, (h - iconSize) / 2, iconSize, iconSize)
                end

                -- Название
                SlashMoon.UI.Draw.TextShadow(itemData.name, "SlashMoon.Text",
                    h + 6, h / 2,
                    color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                -- Счётчик have/need
                local counterTxt = haveCount .. " / " .. neededCount
                SlashMoon.UI.Draw.TextShadow(counterTxt, "SlashMoon.Header",
                    w - 12, h / 2,
                    enough and Color(80, 220, 100) or Color(255, 100, 80),
                    TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        -- Результат
        local resHeader = vgui.Create("SlashMoon.Label", detailScroll)
        resHeader:Dock(TOP)
        resHeader:SetTall(SlashMoon.UI.Scale(28))
        resHeader:DockMargin(0, SlashMoon.UI.Scale(10), 0, SlashMoon.UI.Scale(6))
        resHeader:SetFont("SlashMoon.Text")
        resHeader:SetTextColor(colors.TextMuted)
        resHeader:SetText(SlashMoon.Tasks.Lang("sn.workbench.result"))

        local resultData = SlashMoon.Tasks.GetItemData(recipe.result)
        local resultRow = vgui.Create("SlashMoon.Panel", detailScroll)
        resultRow:Dock(TOP)
        resultRow:SetTall(SlashMoon.UI.Scale(56))
        resultRow:DockMargin(0, 0, 0, 0)
        resultRow.Paint = function(self, w, h)
            surface.SetDrawColor(30, 25, 50, 230)
            surface.DrawRect(0, 0, w, h)

            local typeColor = SlashMoon.Tasks.GetTypeColor(resultData.type)
            surface.SetDrawColor(typeColor)
            surface.DrawRect(0, 0, 4, h)
            surface.SetDrawColor(typeColor.r, typeColor.g, typeColor.b, 60)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            -- Иконка
            local mat = SlashMoon.Tasks.GetItemMaterial(recipe.result)
            if mat and not mat:IsError() then
                local iconSize = h - 12
                surface.SetMaterial(mat)
                surface.SetDrawColor(255, 255, 255, 240)
                surface.DrawTexturedRect(12, (h - iconSize) / 2, iconSize, iconSize)
            end

            -- Название + время
            local timeInfo = "  (" .. SlashMoon.Tasks.Lang("sn.workbench.craft_time", recipe.craftTime) .. ")"
            SlashMoon.UI.Draw.TextShadow(resultData.name .. timeInfo, "SlashMoon.Header",
                h + 6, h / 2,
                color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- Обновляем состояние кнопки крафта
        craftBtn:SetEnabled(recipe.canCraft)
        craftBtn.DoClick = function()
            if not IsValid(CurrentWorkbench) then return end
            ActiveCraftWorkbench = CurrentWorkbench
            surface.PlaySound("buttons/button14.wav")
            net.Start("SN_Workbench_Craft")
                net.WriteEntity(CurrentWorkbench)
                net.WriteString(recipe.id)
            net.SendToServer()
            CloseWorkbenchUI()
        end
    end

    -- === Построение списка рецептов ===
    local function BuildRecipeList()
        recipeScroll:Clear()

        if #recipes == 0 then
            local emptyLbl = vgui.Create("SlashMoon.Label", recipeScroll)
            emptyLbl:Dock(TOP)
            emptyLbl:SetTall(SlashMoon.UI.Scale(40))
            emptyLbl:DockMargin(10, 10, 10, 10)
            emptyLbl:SetFont("SlashMoon.Text")
            emptyLbl:SetTextColor(colors.TextMuted)
            emptyLbl:SetText(SlashMoon.Tasks.Lang("sn.workbench.no_recipes"))
            return
        end

        for _, recipe in ipairs(recipes) do
            local recipeName = SlashMoon.Tasks.Lang(recipe.nameKey)
            local canCraft = recipe.canCraft

            local row = vgui.Create("SlashMoon.Button", recipeScroll)
            row:Dock(TOP)
            row:SetTall(SlashMoon.UI.Scale(56))
            row:DockMargin(0, 0, 0, SlashMoon.UI.Scale(4))
            row:SetText("")
            row.RecipeID   = recipe.id
            row.RecipeName = recipeName

            row.Paint = function(self, w, h)
                local isSelected = (wbMenu.SelectedRecipe == self.RecipeID)
                local isHovered = self:IsHovered()

                local bgCol = isSelected and Color(40, 30, 60, 240)
                            or isHovered and Color(30, 25, 45, 230)
                            or Color(20, 20, 20, 220)
                surface.SetDrawColor(bgCol)
                surface.DrawRect(0, 0, w, h)

                local resultData = SlashMoon.Tasks.GetItemData(recipe.result)
                local typeColor = SlashMoon.Tasks.GetTypeColor(resultData.type)
                surface.SetDrawColor(typeColor)
                surface.DrawRect(0, 0, 4, h)

                if isSelected then
                    surface.SetDrawColor(colors.Theme)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                else
                    surface.SetDrawColor(colors.Outline)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end

                -- Иконка результата
                local mat = SlashMoon.Tasks.GetItemMaterial(recipe.result)
                if mat and not mat:IsError() then
                    local iconSize = h - 14
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(255, 255, 255, 230)
                    surface.DrawTexturedRect(12, (h - iconSize) / 2, iconSize, iconSize)
                end

                -- Название
                SlashMoon.UI.Draw.TextShadow(self.RecipeName, "SlashMoon.Text",
                    h + 6, h / 2 - SlashMoon.UI.Scale(8),
                    color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                -- Кол-во ингредиентов
                local ingCount = #recipe.ingredients
                local ingTxt = SlashMoon.Tasks.Lang("sn.workbench.ingredients_count", ingCount)
                local ingColor = canCraft and Color(80, 220, 100) or Color(255, 150, 80)
                SlashMoon.UI.Draw.TextShadow(ingTxt, "SlashMoon.Small",
                    h + 6, h / 2 + SlashMoon.UI.Scale(8),
                    ingColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                -- Галочка готовности
                if canCraft then
                    SlashMoon.UI.Draw.TextShadow("●", "SlashMoon.Header",
                        w - 18, h / 2,
                        Color(80, 220, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            row.DoClick = function(self)
                surface.PlaySound("UI/buttonclick.wav")
                wbMenu.SelectedRecipe = self.RecipeID
                ShowRecipeDetail(self.RecipeID)
                BuildRecipeList()  -- обновить подсветку выделения
            end

            -- Дабл-клик = сразу крафт
            row.LastClick = 0
            row.OnMousePressed = function(self, code)
                if code == MOUSE_LEFT then
                    if RealTime() - (self.LastClick or 0) < 0.35 then
                        -- Дабл-клик
                        wbMenu.SelectedRecipe = self.RecipeID
                        ShowRecipeDetail(self.RecipeID)
                        if craftBtn:IsEnabled() then
                            craftBtn:DoClick()
                        end
                        self.LastClick = 0
                        return
                    end
                    self.LastClick = RealTime()
                    wbMenu.SelectedRecipe = self.RecipeID
                    ShowRecipeDetail(self.RecipeID)
                    BuildRecipeList()
                end
            end
        end
    end

    BuildRecipeList()

    -- Авто-выбор первого рецепта
    if #recipes > 0 then
        wbMenu.SelectedRecipe = recipes[1].id
        ShowRecipeDetail(recipes[1].id)
        BuildRecipeList()
    end
end)

-- ========================================================
-- ОБРАБОТЧИК ПРОГРЕССА КРАФТА
-- ========================================================
MODULE:Receive("SN_Workbench_Progress", function()
    CraftProgress = net.ReadFloat()
    IsCrafting = true
end)

-- ========================================================
-- ОБРАБОТЧИК РЕЗУЛЬТАТА КРАФТА
-- ========================================================
MODULE:Receive("SN_Workbench_Result", function()
    local success = net.ReadBool()
    local data    = net.ReadString()

    IsCrafting    = false
    CraftProgress = 0
    ActiveCraftWorkbench = NULL

    if success then
        surface.PlaySound("buttons/button14.wav")
        local resultData = SlashMoon.Tasks.GetItemData(data)
        ShowWorkbenchToast(SlashMoon.Tasks.Lang("sn.workbench.craft_success", resultData.name), true)
    else
        surface.PlaySound("buttons/button10.wav")
        if data == "busy" then
            ShowWorkbenchToast(SlashMoon.Tasks.Lang("sn.workbench.busy"), false)
        elseif data == "missing_ingredients" then
            ShowWorkbenchToast(SlashMoon.Tasks.Lang("sn.workbench.missing_ingredients"), false)
        else
            ShowWorkbenchToast(SlashMoon.Tasks.Lang("sn.workbench.craft_failed"), false)
        end
    end
end)

-- ========================================================
-- PROGRESS BAR (ОТРИСОВКА ВО ВРЕМЯ КРАФТА)
-- ========================================================
MODULE:Hook("HUDPaint", "SN_Workbench_ProgressHUD", function()
    if not IsCrafting or CraftProgress <= 0 then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local sw, sh = ScrW(), ScrH()

    local barW = SlashMoon.UI.Scale(400)
    local barH = SlashMoon.UI.Scale(20)
    local barX = sw / 2 - barW / 2
    local barY = sh - SlashMoon.UI.Scale(100)

    -- Фон
    surface.SetDrawColor(15, 15, 15, 240)
    surface.DrawRect(barX - SlashMoon.UI.Scale(2), barY - SlashMoon.UI.Scale(2), barW + SlashMoon.UI.Scale(4), barH + SlashMoon.UI.Scale(4))

    -- Заполнение
    local fillW = barW * math.Clamp(CraftProgress, 0, 1)
    surface.SetDrawColor(colors.Theme)
    surface.DrawRect(barX, barY, fillW, barH)

    -- Обводка
    surface.SetDrawColor(colors.Outline)
    surface.DrawOutlinedRect(barX - SlashMoon.UI.Scale(2), barY - SlashMoon.UI.Scale(2), barW + SlashMoon.UI.Scale(4), barH + SlashMoon.UI.Scale(4), 1)

    -- Текст прогресса
    local percent = math.floor(CraftProgress * 100)
    local progressText = SlashMoon.Tasks.Lang("sn.workbench.crafting_progress", percent)
    SlashMoon.UI.Draw.TextShadow(progressText, "SlashMoon.WorkbenchText", sw / 2, barY - SlashMoon.UI.Scale(20), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Подсказка отмены
    local cancelText = SlashMoon.Tasks.Lang("sn.workbench.cancel_hint")
    SlashMoon.UI.Draw.TextShadow(cancelText, "SlashMoon.WorkbenchSmall", sw / 2, barY + barH + SlashMoon.UI.Scale(12), Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- ========================================================
-- ОТМЕНА КРАФТА ПО КНОПКЕ C
-- ========================================================
MODULE:Hook("PlayerButtonDown", "SN_Workbench_CancelKey", function(ply, key)
    if key ~= KEY_C then return end
    if not IsCrafting then return end
    if not IsValid(ActiveCraftWorkbench) then return end

    net.Start("SN_Workbench_Cancel")
        net.WriteEntity(ActiveCraftWorkbench)
    net.SendToServer()
end)

-- ========================================================
-- PENALTY HIGHLIGHT (АВТОВЫДЕЛЕНИЕ)
-- ========================================================
if SlashMoon.Penalty then
    SlashMoon.Penalty.RegisterAutoReveal("sn_workbench_penalty", {
        getEntities = function()
            return ents.FindByClass("sn_workbench")
        end,
        color     = Color(50, 200, 255),
        condition = function()
            return SlashMoon.Tasks.Game.IsSurvivor(LocalPlayer())
        end
    })
end
