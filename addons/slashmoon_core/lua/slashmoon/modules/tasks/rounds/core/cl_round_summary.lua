-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Round Summary (centered, ESC-close, SN_InterceptEscape)
-- Лейаут: по центру экрана, отступ сверху 20%, по краям 20%
-- ========================================================
if not CLIENT then return end

local colors = SlashMoon.UI.Colors
local summaryPanel = nil
local roundStats   = {}

local AUTO_CLOSE   = 15   -- секунд до авто-закрытия

MODULE:Receive("SN_Stats_RoundEnd", function()
    roundStats = net.ReadTable()
end)

local function FormatTime(s)
    return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end

-- ── Колонки таблицы ───────────────────────────────────────────────────
local COLS = {
    { key = "status",           label = "sn.stats.status",     color = nil,                    w = 0.09 },
    { key = "kills",            label = "sn.stats.kills",       color = Color(255, 80,  80),    w = 0.07 },
    { key = "deaths",           label = "sn.stats.deaths",      color = Color(180, 100, 180),   w = 0.07 },
    { key = "generatorsFueled", label = "sn.stats.generators",  color = Color(255, 200, 50),    w = 0.08 },
    { key = "itemsPickedUp",    label = "sn.stats.items",       color = Color(100, 200, 255),   w = 0.08 },
    { key = "damageDealt",      label = "sn.stats.dmg_dealt",   color = Color(255, 120, 100),   w = 0.09 },
    { key = "damageTaken",      label = "sn.stats.dmg_taken",   color = Color(255, 150, 50),    w = 0.09 },
    { key = "distanceTraveled", label = "sn.stats.distance",    color = Color(140, 230, 140),   w = 0.08 },
    { key = "timeSurvived",     label = "sn.stats.time",        color = Color(255, 220, 100),   w = 0.09 },
}

-- ── Вычисление x-координат колонок по ширине ──────────────────────────
local function GetNameFrac()
    local f = 1
    for _, c in ipairs(COLS) do f = f - c.w end
    return f
end

local function GetColX(idx, totalW)
    local usedFrac = 0
    for i = 1, idx - 1 do usedFrac = usedFrac + COLS[i].w end
    local nameFrac = GetNameFrac()
    local startFrac = nameFrac + usedFrac
    return totalW * (startFrac + COLS[idx].w * 0.5)
end

local function GetColValue(data, key)
    if key == "status" then return nil end
    if key == "timeSurvived" then return FormatTime(data.timeSurvived or 0) end
    if key == "distanceTraveled" then return (data.distanceTraveled or 0) .. "м" end
    return tostring(data[key] or 0)
end

-- ── Закрытие панели ──────────────────────────────────────────────────
local function CloseSummary()
    if not IsValid(summaryPanel) then return end
    -- Снимаем перехват ESC
    MODULE:Unhook("SlashMoon.UI.InterceptEscape", "SN_RoundSummary_CatchESC")
    summaryPanel:Remove()
    summaryPanel = nil
end

-- ── Главная функция открытия ───────────────────────────────────────────
local function ShowRoundSummary(survivorsWon, reason)
    -- Закрыть предыдущее окно
    CloseSummary()

    local sw, sh = ScrW(), ScrH()
    local winnerColor   = survivorsWon and Color(60, 230, 100) or Color(230, 60, 60)
    local winnerKey     = survivorsWon and "sn.round.survivors_won" or "sn.round.anim_won"
    local reasonDefault = survivorsWon and "sn.round.survivors_escaped" or "sn.round.anim_destroyed"
    local closeAt       = CurTime() + AUTO_CLOSE

    surface.PlaySound(survivorsWon
        and "music/hl2_song20_submix0.mp3"
        or  "music/hl2_song16.mp3")

    -- ── Корневая панель (полный экран, затемнение) ────────────────────
    summaryPanel = vgui.Create("SlashMoon.Panel")
    summaryPanel:SetSize(sw, sh)
    summaryPanel:SetPos(0, 0)
    summaryPanel:MakePopup()
    summaryPanel:SetKeyboardInputEnabled(false)

    summaryPanel.Paint = function(self, w, h)
        -- Тёмный затемнение всего экрана
        surface.SetDrawColor(5, 5, 10, 230)
        surface.DrawRect(0, 0, w, h)
    end

    -- ── Перехват ESC (SN_InterceptEscape) ─────────────────────────────
    -- Возвращаем true → блокируем открытие кастомного ESC-меню гамemode'а
    MODULE:Hook("SlashMoon.UI.InterceptEscape", "SN_RoundSummary_CatchESC", function()
        if IsValid(summaryPanel) then
            CloseSummary()
            return true  -- Блокируем меню паузы
        end
    end)

    -- ── Автозакрытие + ESC через Think ────────────────────────────────
    summaryPanel.Think = function(self)
        -- Автозакрытие по таймеру
        if CurTime() >= closeAt then
            CloseSummary()
            return
        end

        -- ESC через input.IsKeyDown (фоллбэк, если SN_InterceptEscape
        -- не вызывается гамemode'ом)
        if input.IsKeyDown(KEY_ESCAPE) then
            if not self._escPressed then
                self._escPressed = true
                CloseSummary()
            end
        else
            self._escPressed = false
        end
    end

    -- ══════════════════════════════════════════════════════════════════
    -- ЛЕЙАУТ: по центру, отступ сверху 20%, по краям 20%
    -- ══════════════════════════════════════════════════════════════════
    local marginX  = sw * 0.20   -- 20% слева и справа
    local marginY  = sh * 0.20   -- 20% сверху
    local panelW   = sw - marginX * 2
    local panelX   = marginX
    local panelY   = marginY

    -- ── Основная панель (скруглённый контейнер) ───────────────────────
    local mainPnl = vgui.Create("SlashMoon.Panel", summaryPanel)
    mainPnl:SetPos(panelX, panelY)
    mainPnl:SetSize(panelW, sh - marginY - SlashMoon.UI.Scale(40))

    local ROW_H  = SlashMoon.UI.Scale(52)
    local HDR_H  = SlashMoon.UI.Scale(100)
    local COLHDR = SlashMoon.UI.Scale(32)
    local FOOTER = SlashMoon.UI.Scale(48)

    -- Рассчитываем высоту таблицы
    local rowCount  = #roundStats
    local tableH    = rowCount * (ROW_H + SlashMoon.UI.Scale(2))
    local contentH  = HDR_H + COLHDR + tableH + FOOTER
    local actualH   = math.min(contentH, mainPnl:GetTall())

    mainPnl:SetTall(actualH)

    mainPnl.Paint = function(self, w, h)
        -- Фон панели
        surface.SetDrawColor(12, 12, 18, 245)
        surface.DrawRect(0, 0, w, h)

        -- Верхняя цветная полоска победителя
        surface.SetDrawColor(winnerColor.r, winnerColor.g, winnerColor.b, 220)
        surface.DrawRect(0, 0, w, SlashMoon.UI.Scale(3))

        -- Тонкая обводка
        surface.SetDrawColor(winnerColor.r, winnerColor.g, winnerColor.b, 40)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local PAD = SlashMoon.UI.Scale(20)
    local tableW = panelW - PAD * 2

    -- ── Заголовок раунда ─────────────────────────────────────────────
    local hdrPnl = vgui.Create("SlashMoon.Panel", mainPnl)
    hdrPnl:SetPos(0, 0)
    hdrPnl:SetSize(panelW, HDR_H)
    hdrPnl.Paint = function(self, w, h)
        -- Затемнение под заголовком
        surface.SetDrawColor(18, 18, 28, 200)
        surface.DrawRect(0, 0, w, h)

        -- Текст победителя
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang(winnerKey),
            "SlashMoon.Broadcast", w / 2, SlashMoon.UI.Scale(35),
            winnerColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Причина
        SlashMoon.UI.Draw.TextShadow(reason and SlashMoon.Tasks.Lang(reason) or SlashMoon.Tasks.Lang(reasonDefault),
            "SlashMoon.Title", w / 2, SlashMoon.UI.Scale(72),
            colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Разделитель
        surface.SetDrawColor(40, 40, 55, 180)
        surface.DrawRect(PAD, h - 1, tableW, 1)
    end

    -- ── Строка заголовков колонок ─────────────────────────────────────
    local colHdrY = HDR_H
    local colHdr = vgui.Create("SlashMoon.Panel", mainPnl)
    colHdr:SetPos(PAD, colHdrY)
    colHdr:SetSize(tableW, COLHDR)
    colHdr.Paint = function(self, w, h)
        surface.SetDrawColor(15, 15, 22, 220)
        surface.DrawRect(0, 0, w, h)

        -- Имя игрока (первая колонка)
        local nameX = GetNameFrac() * w * 0.5
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.stats.player") or "Игрок",
            "SlashMoon.Small", nameX, h / 2,
            colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        for i, col in ipairs(COLS) do
            local x = GetColX(i, w)
            SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang(col.label),
                "SlashMoon.Small", x, h / 2,
                colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Нижняя линия
        surface.SetDrawColor(30, 30, 45, 200)
        surface.DrawRect(0, h - 1, w, 1)
    end

    -- ── Строки игроков (со скроллом, если много) ─────────────────────
    local scrollY = colHdrY + COLHDR
    local scrollH = actualH - scrollY - FOOTER

    local scroll = vgui.Create("SlashMoon.Scroll", mainPnl)
    scroll:SetPos(0, scrollY)
    scroll:SetSize(panelW, scrollH)

    -- Стилизация скроллбара
    local sbar = scroll:GetVBar()
    sbar:SetWide(SlashMoon.UI.Scale(4))
    sbar:SetHideButtons(true)
    sbar.Paint = function() end
    sbar.btnGrip.Paint = function(btn, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, h)
    end

    local rowY = 0
    for _, data in ipairs(roundStats) do
        local ply         = player.GetBySteamID(data.steamID)
        local isEscaped   = data.escaped
        local isAnim      = data.wasAnimatronic
        local isMe        = IsValid(ply) and ply == LocalPlayer()

        local statusCol = isAnim    and Color(230, 60,  60)
                        or isEscaped and Color(60,  230, 100)
                        or              Color(120, 120, 120)
        local statusTxt = isAnim    and SlashMoon.Tasks.Lang("sn.round.animatronic")
                        or isEscaped and SlashMoon.Tasks.Lang("sn.round.escaped")
                        or              SlashMoon.Tasks.Lang("sn.round.dead")

        local row = vgui.Create("SlashMoon.Panel", scroll)
        row:SetPos(PAD, rowY)
        row:SetSize(tableW, ROW_H)

        row.Paint = function(self, w, h)
            -- Фон (подсветка себя)
            local bg = isMe and Color(30, 30, 55, 230) or Color(14, 14, 20, 210)
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)

            -- Левая цветная черта статуса
            surface.SetDrawColor(statusCol)
            surface.DrawRect(0, 0, SlashMoon.UI.Scale(3), h)

            -- Имя игрока
            local nameX = SlashMoon.UI.Scale(55)
            local nameCol = isMe and color_white or Color(200, 200, 200)
            SlashMoon.UI.Draw.TextShadow(data.nick,
                isMe and "SlashMoon.Header" or "SlashMoon.Text",
                nameX, h / 2, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Статус (бейдж)
            local statusX = GetColX(1, w)
            local badgeW = SlashMoon.UI.Scale(80)
            surface.SetDrawColor(statusCol.r, statusCol.g, statusCol.b, 25)
            surface.DrawRect(statusX - badgeW / 2, h / 2 - SlashMoon.UI.Scale(10), badgeW, SlashMoon.UI.Scale(20))
            SlashMoon.UI.Draw.TextShadow(statusTxt, "SlashMoon.Small",
                statusX, h / 2, statusCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Остальные колонки
            for i = 2, #COLS do
                local col = COLS[i]
                local val = GetColValue(data, col.key)
                local cx  = GetColX(i, w)
                SlashMoon.UI.Draw.TextShadow(val, "SlashMoon.Text",
                    cx, h / 2,
                    col.color or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            -- Разделительная линия
            surface.SetDrawColor(25, 25, 38, 180)
            surface.DrawRect(0, h - 1, w, 1)
        end

        -- Аватар
        if IsValid(ply) then
            local av = vgui.Create("SlashMoon.Avatar", row)
            av:SetSize(SlashMoon.UI.Scale(36), SlashMoon.UI.Scale(36))
            av:SetPos(SlashMoon.UI.Scale(10), (ROW_H - SlashMoon.UI.Scale(36)) / 2)
            av:SetPlayer(ply, 64)
        end

        rowY = rowY + ROW_H + SlashMoon.UI.Scale(2)
    end

    -- ── Футер: таймер автозакрытия + ESC подсказка ────────────────────
    local footer = vgui.Create("SlashMoon.Panel", mainPnl)
    footer:Dock(BOTTOM)
    footer:SetTall(FOOTER)
    footer.Paint = function(self, w, h)
        local left = math.max(0, math.ceil(closeAt - CurTime()))

        -- Фон футера
        surface.SetDrawColor(12, 12, 18, 240)
        surface.DrawRect(0, 0, w, h)

        -- Полоса прогресса (сверху футера)
        local frac = math.Clamp((closeAt - CurTime()) / AUTO_CLOSE, 0, 1)
        surface.SetDrawColor(25, 25, 35, 200)
        surface.DrawRect(0, 0, w, SlashMoon.UI.Scale(2))
        surface.SetDrawColor(winnerColor.r, winnerColor.g, winnerColor.b, 160)
        surface.DrawRect(0, 0, w * frac, SlashMoon.UI.Scale(2))

        -- Таймер автозакрытия
        SlashMoon.UI.Draw.TextShadow(
            SlashMoon.Tasks.Lang("sn.stats.autoclose", left),
            "SlashMoon.Small", w / 2 - SlashMoon.UI.Scale(40), h / 2 + SlashMoon.UI.Scale(6),
            colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Подсказка ESC
        SlashMoon.UI.Draw.TextShadow("[ESC] " .. (SlashMoon.Tasks.Lang("sn.stats.close") or "Закрыть"),
            "SlashMoon.Small", w / 2 + SlashMoon.UI.Scale(80), h / 2 + SlashMoon.UI.Scale(6),
            Color(180, 180, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Если статистика пуста — показываем заглушку
    if #roundStats == 0 then
        local emptyLbl = vgui.Create("SlashMoon.Panel", mainPnl)
        emptyLbl:SetPos(0, scrollY)
        emptyLbl:SetSize(panelW, scrollH)
        emptyLbl.Paint = function(self, w, h)
            SlashMoon.UI.Draw.TextShadow(
                SlashMoon.Tasks.Lang("sn.stats.no_data") or "Нет данных за раунд",
                "SlashMoon.Header", w / 2, h / 2,
                colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

-- ── Сетевые обработчики ───────────────────────────────────────────────
MODULE:Receive("fhi_escape_result", function()
    local escaped    = net.ReadTable()
    local notEscaped = net.ReadTable()
    if SlashMoon.Rounds and SlashMoon.Rounds.HandleEscapeResult then
        SlashMoon.Rounds.HandleEscapeResult(escaped, notEscaped)
    end
    MODULE:Timer("SN_RoundSummary_Open", 1, 1, function()
        ShowRoundSummary(#escaped > 0)
    end)
end)

MODULE:Receive("SN_Round_Ended", function()
    local survivorsWon = net.ReadBool()
    local reason       = net.ReadString()
    roundStats = net.ReadTable() or roundStats
    MODULE:Unhook("HUDPaint", "DrawDead")
    MODULE:Unhook("HUDPaint", "hud_fh_request")
    MODULE:Timer("SN_RoundSummary_Open", 1, 1, function()
        ShowRoundSummary(survivorsWon, reason ~= "" and reason or nil)
    end)
end)

SlashMoon.Debug("[UI] Round Summary (centered, ESC-close) загружен")
