-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Client Task List HUD (Localized + Improved)
-- ========================================================
if not CLIENT then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.ClientTaskList = SlashMoon.Tasks.ClientTaskList or {}

-- Прием обновленного списка заданий от сервера
local sortedTasks = {}
local sortedTasksDirty = true
local taskMenu = nil
local f3WasDown = false

MODULE:Receive("SN_Tasks_SyncList", function()
    local incoming = net.ReadTable() or {}
    SlashMoon.Tasks.ClientTaskList = {}
    for id, data in pairs(incoming) do
        SlashMoon.Tasks.ClientTaskList[id] = {
            displayKey = data.displayKey,
            displayArgs = data.displayArgs,
            displayName = data.displayName,
            done = data.done,
            failed = data.failed,
            descriptionKey = data.descriptionKey,
            descriptionArgs = data.descriptionArgs,
        }
    end
    sortedTasksDirty = true
    if IsValid(taskMenu) then taskMenu:Remove() end
end)

local function RebuildSortedTasks()
    sortedTasks = {}
    for id, data in pairs(SlashMoon.Tasks.ClientTaskList or {}) do
        sortedTasks[#sortedTasks + 1] = {
            id = id,
            name = data.displayKey and SlashMoon.Tasks.Lang(data.displayKey, unpack(data.displayArgs or {})) or data.displayName or id,
            done = data.done,
            failed = data.failed,
            description = data.descriptionKey and SlashMoon.Tasks.Lang(data.descriptionKey, unpack(data.descriptionArgs or {})) or "",
        }
    end
    table.sort(sortedTasks, function(a, b) return a.id < b.id end)
    sortedTasksDirty = false
end

MODULE:Hook("SN_Tasks_LanguageChanged", "SN_Tasks_RebuildLocalizedList", function()
    sortedTasksDirty = true
end)

local function CloseTaskMenu()
    if IsValid(taskMenu) then taskMenu:Remove() end
    taskMenu = nil
    gui.EnableScreenClicker(false)
end

local function OpenTaskMenu()
    if sortedTasksDirty then RebuildSortedTasks() end
    CloseTaskMenu()

    local scale = SlashMoon.UI.Scale
    local rowH, headH, pad = scale(36), scale(36), scale(8)
    local listW, detailW = scale(300), scale(420)
    local menuH = headH + pad * 2 + #sortedTasks * rowH

    taskMenu = vgui.Create("SlashMoon.Panel")
    taskMenu:SetSize(listW + detailW + scale(12), math.max(menuH, scale(250)))
    taskMenu:SetPos(scale(20), scale(120))
    taskMenu:SetMouseInputEnabled(true)
    taskMenu:SetKeyboardInputEnabled(false)
    taskMenu:MakePopup()
    gui.EnableScreenClicker(true)
    taskMenu.Paint = function() end
    taskMenu.OnRemove = function() gui.EnableScreenClicker(false) end

    local list = vgui.Create("SlashMoon.Panel", taskMenu)
    list:Dock(LEFT)
    list:SetWide(listW)
    list.Paint = function(self, w, h)
        surface.SetDrawColor(SlashMoon.UI.Colors.DarkBG)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(SlashMoon.UI.Colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.task.list_title"), "SlashMoon.TaskTitle", w / 2, headH / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local details = vgui.Create("SlashMoon.Panel", taskMenu)
    details:Dock(FILL)
    details:DockMargin(scale(12), 0, 0, 0)
    details.Title = SlashMoon.Tasks.Lang("sn.task.select_hint")
    details.Paint = function(self, w, h)
        surface.SetDrawColor(SlashMoon.UI.Colors.DarkBG)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(SlashMoon.UI.Colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(self.Title, "SlashMoon.Header", scale(18), scale(22), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local description = vgui.Create("SlashMoon.Label", details)
    description:Dock(FILL)
    description:DockMargin(scale(18), scale(50), scale(18), scale(18))
    description:SetFont("SlashMoon.Text")
    description:SetTextColor(SlashMoon.UI.Colors.TextMuted)
    description:SetWrap(true)
    description:SetContentAlignment(7)
    description:SetText("")

    for i, task in ipairs(sortedTasks) do
        local btn = vgui.Create("SlashMoon.Button", list)
        btn:SetPos(pad, headH + pad + (i - 1) * rowH)
        btn:SetSize(listW - pad * 2, rowH - scale(4))
        btn:SetText("")
        btn.Paint = function(self, w, h)
            local status = task.done and Color(50, 220, 100) or (task.failed and Color(255, 70, 70) or SlashMoon.UI.Colors.Theme)
            surface.SetDrawColor(self:IsHovered() and Color(35, 35, 35, 245) or Color(15, 15, 15, 220))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(status)
            surface.DrawRect(0, 0, 3, h)
            draw.SimpleText(task.name, "SlashMoon.TaskItem", scale(14), h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            details.Title = task.name
            description:SetText(task.description ~= "" and task.description or SlashMoon.Tasks.Lang("sn.task.no_description"))
        end
    end
end

local function ToggleTaskMenu()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or SlashMoon.Tasks.Game.IsAnimatronic(ply) or SlashMoon.Tasks.Game.IsSpectator(ply) then return end

    if IsValid(taskMenu) then
        CloseTaskMenu()
        if SlashMoon.Tasks.SetPinnedRecipeEditing then SlashMoon.Tasks.SetPinnedRecipeEditing(false) end
        return
    end

    OpenTaskMenu()
    if SlashMoon.Tasks.SetPinnedRecipeEditing then
        SlashMoon.Tasks.SetPinnedRecipeEditing(SlashMoon.Tasks.PinnedRecipe ~= nil)
    end
    if IsValid(taskMenu) then taskMenu:MoveToFront() end
end

MODULE:Hook("Think", "SN_Tasks_TaskListInteraction", function()
    local isDown = input.IsKeyDown(KEY_F3)
    if isDown and not f3WasDown then ToggleTaskMenu() end
    f3WasDown = isDown
end)

MODULE:Hook("Think", "SN_Tasks_TaskListCloseInvalid", function()
    if not IsValid(taskMenu) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or SlashMoon.Tasks.Game.IsAnimatronic(ply) or SlashMoon.Tasks.Game.IsSpectator(ply) then
        CloseTaskMenu()
        if SlashMoon.Tasks.SetPinnedRecipeEditing then
            SlashMoon.Tasks.SetPinnedRecipeEditing(false)
        end
    end
end)

MODULE:Hook("ShutDown", "SN_Tasks_CloseTaskMenu", CloseTaskMenu)

-- Запрос данных при заходе на сервер
MODULE:Hook("InitPostEntity", "SN_Tasks_RequestInitialList", function()
    timer.Simple(2, function()
        net.Start("SN_Tasks_RequestSyncList")
        net.SendToServer()
    end)
end)

-- Отрисовка списка заданий слева сверху
MODULE:Hook("HUDPaint", "SN_Tasks_DrawHUDList", function()
    if not GetConVar("cl_drawhud"):GetBool() then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if SlashMoon.Tasks.Game.IsAnimatronic(ply) or SlashMoon.Tasks.Game.IsSpectator(ply) then return end

    -- Используем клиентскую фазу (экспортирована из cl_phase.lua)
    -- Раньше было SlashMoon.Phase.State.phase — это серверная переменная, на клиенте всегда "none"!
    local phase = SlashMoon.Tasks.GetPhase and SlashMoon.Tasks.GetPhase() or "none"
    if phase == "escape" or phase == "none" then return end

    local tasks = SlashMoon.Tasks.ClientTaskList
    if not tasks or table.IsEmpty(tasks) then return end

    -- Сортировка заданий
    if sortedTasksDirty then RebuildSortedTasks() end
    local sorted = sortedTasks

    local pnlW = SlashMoon.UI.Scale(260)
    local rowH = SlashMoon.UI.Scale(28)
    local headH = SlashMoon.UI.Scale(32)
    local pad = SlashMoon.UI.Scale(8)
    local x = SlashMoon.UI.Scale(20)
    local y = SlashMoon.UI.Scale(120)

    local pnlH = headH + pad + (#sorted * rowH) + pad

    -- 1. Матовый фон и обводка в стиле SlashMoon
    surface.SetDrawColor(SlashMoon.UI.Colors.DarkBG)
    surface.DrawRect(x, y, pnlW, pnlH)

    surface.SetDrawColor(SlashMoon.UI.Colors.Theme)
    surface.DrawRect(x, y, pnlW, 2)

    surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
    surface.DrawOutlinedRect(x, y, pnlW, pnlH, 1)

    -- 2. Заголовок (локализованный)
    local listTitle = SlashMoon.Tasks.Lang("sn.task.list_title")
    SlashMoon.UI.Draw.TextShadow(listTitle, "SlashMoon.TaskTitle", x + pnlW / 2, y + headH / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
    surface.DrawRect(x + pad, y + headH, pnlW - (pad * 2), 1)

    -- 3. Список задач
    local curY = y + headH + pad

    -- Подсчёт прогресса
    local totalTasks = #sorted
    local doneTasks = 0
    for _, task in ipairs(sorted) do
        if task.done then doneTasks = doneTasks + 1 end
    end

    for i, task in ipairs(sorted) do
        local ry = curY + ((i - 1) * rowH)

        local statusCol = SlashMoon.UI.Colors.TextMuted
        local statusIcon = "O"

        if task.done then
            statusCol = Color(50, 220, 100)
            statusIcon = "✓"
        elseif task.failed then
            statusCol = Color(255, 50, 50)
            statusIcon = "✕"
        end

        surface.SetDrawColor(15, 15, 15, 180)
        surface.DrawRect(x + pad, ry, pnlW - (pad * 2), rowH - 4)

        -- Индикатор статуса слева
        surface.SetDrawColor(statusCol)
        surface.DrawRect(x + pad, ry, 3, rowH - 4)

        -- Иконка и Название
        SlashMoon.UI.Draw.TextShadow(statusIcon, "SlashMoon.TaskItem", x + pad + SlashMoon.UI.Scale(10), ry + (rowH - 4) / 2, statusCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local nameCol = task.done and Color(150, 150, 150) or color_white
        SlashMoon.UI.Draw.TextShadow(task.name, "SlashMoon.TaskItem", x + pad + SlashMoon.UI.Scale(28), ry + (rowH - 4) / 2, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- 4. Мини-прогресс-бар внизу плашки
    if totalTasks > 0 then
        local barY = y + pnlH - SlashMoon.UI.Scale(4)
        local fillPct = doneTasks / totalTasks

        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(x, barY, pnlW, SlashMoon.UI.Scale(4))
        surface.SetDrawColor(50, 220, 100)
        surface.DrawRect(x, barY, pnlW * fillPct, SlashMoon.UI.Scale(4))
    end
end)
