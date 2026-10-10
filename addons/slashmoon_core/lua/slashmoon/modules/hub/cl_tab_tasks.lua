-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("hub")

-- ========================================================
-- Хаб: задания и награды
-- ========================================================

local Hub = SlashMoon.Hub
local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

Hub.TasksStats = Hub.TasksStats or {}
Hub.TasksCompleted = Hub.TasksCompleted or {}

local function RewardText(reward)
    local parts = {}
    if reward.balance then parts[#parts + 1] = Hub.FormatMoney(reward.balance) end
    if reward.item then parts[#parts + 1] = "предмет" end
    return table.concat(parts, " + ")
end

MODULE:Receive("SN_Hub_SyncTasks", function()
    Hub.TasksStats = net.ReadTable()
    Hub.TasksCompleted = net.ReadTable()
    hook.Run("SlashMoon.Hub.TasksUpdated")
end)

MODULE:Receive("SN_Hub_TaskResult", function()
    if net.ReadBool() then
        surface.PlaySound("ambient/levels/labs/coinslot1.wav")
        UI.Toast("Награда получена!", "success", 3)
    else
        surface.PlaySound("buttons/button10.wav")
        UI.Toast("Не удалось получить награду", "error", 3)
    end
end)

Hub.RegisterTab("tasks", "ЗАДАНИЯ", "sn_hub/bg_shop.png", 4, function(pnl)
    local scroll = UI.Create("Scroll", pnl)
    scroll:Dock(FILL)
    scroll:DockMargin(ScrW() * 0.08, 0, ScrW() * 0.08, 0)

    local loading = UI.Create("Label", scroll)
    loading:Dock(TOP)
    loading:DockMargin(0, UI.Scale(50), 0, 0)
    loading:SetFont("SlashMoon.Header")
    loading:SetColorKey("Accent")
    loading:SetContentAlignment(5)
    loading:SetText("СИНХРОНИЗАЦИЯ ПРОГРЕССА...")

    local function Render()
        if not IsValid(scroll) then return end
        scroll:Clear()

        for _, task in ipairs(Hub.Tasks or {}) do
            local state = Hub.TasksCompleted[task.id] or {}
            local isDone = (task.type == "onetime" and state.all_time) or (task.type == "daily" and state.today)
            local progress = task.stat and (Hub.TasksStats[task.stat] or 0) or 0
            local canClaim = not isDone and progress >= (task.req or 0)

            local card = UI.Create("Panel", scroll)
            card:Dock(TOP)
            card:DockMargin(0, 0, 0, UI.Scale(15))
            card:SetTall(UI.Scale(120))
            card:SetBackground(Color(20, 20, 20, 240))
            card:SetOutline(true)
            card:SetAccentBar(isDone and "Success" or "Accent")
            card:DockPadding(0, UI.Scale(28), UI.Scale(24), UI.Scale(28))

            card.PaintOver = function(_, w, h)
                local x = UI.Scale(24)
                Draw.TextShadow(task.title .. (task.type == "daily" and " (ежедневное)" or ""), "SlashMoon.Header", x, UI.Scale(26), colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                Draw.Text(task.desc, "SlashMoon.Text", x, UI.Scale(56), colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                Draw.Text("Награда: " .. RewardText(task.reward or {}), "SlashMoon.HubSubBtn", x, h - UI.Scale(26), Color(255, 215, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                if (task.req or 0) > 0 then
                    local barW, barH = UI.Scale(260), UI.Scale(22)
                    local barX, barY = w - barW - UI.Scale(240), h / 2 - barH / 2
                    local fraction = isDone and 1 or math.Clamp(progress / task.req, 0, 1)
                    Draw.ProgressBar(barX, barY, barW, barH, fraction, isDone and colors.Success or colors.Accent, UI.Scale(4))
                    Draw.Text((isDone and task.req or progress) .. " / " .. task.req, "SlashMoon.Small", barX + barW / 2, barY + barH / 2, colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            local btn = UI.Create("Button", card)
            btn:Dock(RIGHT)
            btn:SetWide(UI.Scale(190))
            if isDone then
                btn:SetText("ВЫПОЛНЕНО")
                btn:SetVariant("success")
                btn:SetEnabled(false)
            elseif canClaim then
                btn:SetText("ЗАБРАТЬ")
                btn:SetVariant("primary")
            else
                btn:SetText("В ПРОЦЕССЕ")
                btn:SetEnabled(false)
            end
            btn.DoClick = function()
                if not canClaim then return end
                btn:SetEnabled(false)
                net.Start("SN_Hub_ClaimTask")
                net.WriteString(task.id)
                net.SendToServer()
            end
        end
    end

    hook.Add("SlashMoon.Hub.TasksUpdated", scroll, Render)

    net.Start("SN_Hub_RequestTasks")
    net.SendToServer()
end)
