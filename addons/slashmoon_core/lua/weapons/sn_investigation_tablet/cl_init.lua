-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

include("shared.lua")

local width, height = 260, 190
local offset = Vector(-1.7, -0.25, 2.5)
local rotation = Angle(0, 0, 180)
local pendingReport
local reportPanel
local escWasDown = false

-- Шрифт экрана (фиксированный размер рендер-таргета, без масштабирования)
SlashMoon.UI.RegisterRawFont("SlashMoon.InvestigationReport", { font = "Roboto", size = 17, weight = 700, antialias = true })
-- Шрифт экрана (фиксированный размер рендер-таргета, без масштабирования)
SlashMoon.UI.RegisterRawFont("SlashMoon.InvestigationReportSmall", { font = "Roboto", size = 13, weight = 500, antialias = true })

MODULE:Receive("SN_Investigation_ReportData", function()
    local clue = net.ReadString()
    local hasPassport = net.ReadBool()
    local count = net.ReadUInt(2)
    local options = {}
    for index = 1, count do options[index] = net.ReadString() end

    pendingReport = { clue = clue, hasPassport = hasPassport, options = options }
end)

MODULE:Hook("Think", "SN_Investigation_ApplyReportData", function()
    if not pendingReport then return end
    local tablet = LocalPlayer():GetWeapon("sn_investigation_tablet")
    if IsValid(tablet) then
        tablet.ReportClue = pendingReport.clue
        tablet.HasPassport = pendingReport.hasPassport
        tablet.ReportOptions = pendingReport.options
        tablet.SelectedOption = 1
        pendingReport = nil
    end
end)

local function CloseReportPanel(requestClose)
    if not IsValid(reportPanel) then return end
    reportPanel:Remove()
    reportPanel = nil
    gui.EnableScreenClicker(false)
    if requestClose then
        net.Start("SN_Investigation_CloseReport")
        net.SendToServer()
    end
end

local function OpenReportPanel(wep)
    if not IsValid(wep) or not wep:GetFullView() or not wep.ReportOptions then return end
    if IsValid(reportPanel) then return end

    reportPanel = vgui.Create("SlashMoon.Panel")
    reportPanel:SetSize(ScrW(), ScrH())
    reportPanel:MakePopup()
    reportPanel:SetKeyboardInputEnabled(false)
    -- ESC закрывает отчет, а не открывает меню паузы
    SlashMoon.UI.PushEscape(reportPanel, function() CloseReportPanel(true) end)
    gui.EnableScreenClicker(true)
    reportPanel.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 135)
        surface.DrawRect(0, 0, w, h)
    end
    reportPanel.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then CloseReportPanel(true) end
    end

    local form = vgui.Create("SlashMoon.Panel", reportPanel)
    form:SetSize(SlashMoon.UI.Scale(620), SlashMoon.UI.Scale(460))
    form:Center()
    form.PassportAttached = false
    form.OnMousePressed = function() end
    form.Paint = function(self, w, h)
        surface.SetDrawColor(SlashMoon.UI.Colors.DarkBG)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(SlashMoon.UI.Colors.Theme)
        surface.DrawRect(0, 0, w, 3)
        surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.investigation.report_title"), "SlashMoon.Header", SlashMoon.UI.Scale(20), SlashMoon.UI.Scale(25), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.investigation.clue", SlashMoon.Tasks.Lang(wep.ReportClue or "sn.investigation.location.field")), "SlashMoon.Small", SlashMoon.UI.Scale(20), SlashMoon.UI.Scale(47), Color(255, 210, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.investigation.choose_location"), "SlashMoon.Text", SlashMoon.UI.Scale(20), SlashMoon.UI.Scale(65), SlashMoon.UI.Colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.investigation.report_controls"), "SlashMoon.Small", SlashMoon.UI.Scale(20), h - SlashMoon.UI.Scale(20), SlashMoon.UI.Colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local passport = vgui.Create("SlashMoon.Panel", form)
    passport:SetSize(SlashMoon.UI.Scale(220), SlashMoon.UI.Scale(72))
    passport:SetPos(SlashMoon.UI.Scale(20), SlashMoon.UI.Scale(95))
    passport:SetMouseInputEnabled(wep.HasPassport == true)
    passport:SetCursor(wep.HasPassport and "hand" or "arrow")
    passport.Paint = function(self, w, h)
        local color = wep.HasPassport and Color(80, 170, 105) or Color(100, 100, 100)
        surface.SetDrawColor(20, 25, 22, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(color)
        surface.DrawRect(0, 0, 4, h)
        surface.SetDrawColor(color.r, color.g, color.b, 130)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.investigation.passport"), "SlashMoon.Text", SlashMoon.UI.Scale(14), SlashMoon.UI.Scale(25), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SlashMoon.UI.Draw.TextShadow(wep.HasPassport and SlashMoon.Tasks.Lang("sn.investigation.drag_passport") or SlashMoon.Tasks.Lang("sn.investigation.passport_missing"), "SlashMoon.Small", SlashMoon.UI.Scale(14), SlashMoon.UI.Scale(50), SlashMoon.UI.Colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    passport.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT or not wep.HasPassport then return end
        self.Dragging = true
        self:MouseCapture(true)
    end
    passport.OnMouseReleased = function(self, code)
        if code ~= MOUSE_LEFT then return end
        self.Dragging = false
        self:MouseCapture(false)
        local dropX, dropY = form.PassportSlot:LocalToScreen(0, 0)
        local mouseX, mouseY = gui.MousePos()
        if mouseX >= dropX and mouseX <= dropX + form.PassportSlot:GetWide() and mouseY >= dropY and mouseY <= dropY + form.PassportSlot:GetTall() then
            form.PassportAttached = true
            self:SetPos(form.PassportSlot:GetPos())
            self:SetMouseInputEnabled(false)
        else
            self:SetPos(SlashMoon.UI.Scale(20), SlashMoon.UI.Scale(95))
        end
    end
    passport.Think = function(self)
        if not self.Dragging then return end
        local x, y = form:ScreenToLocal(gui.MousePos())
        self:SetPos(x - self:GetWide() / 2, y - self:GetTall() / 2)
    end

    local passportSlot = vgui.Create("SlashMoon.Panel", form)
    passportSlot:SetSize(SlashMoon.UI.Scale(220), SlashMoon.UI.Scale(72))
    passportSlot:SetPos(SlashMoon.UI.Scale(370), SlashMoon.UI.Scale(95))
    passportSlot.Paint = function(self, w, h)
        surface.SetDrawColor(15, 15, 15, 255)
        surface.DrawRect(0, 0, w, h)
        local color = form.PassportAttached and Color(80, 220, 120) or SlashMoon.UI.Colors.Outline
        surface.SetDrawColor(color)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        SlashMoon.UI.Draw.TextShadow(form.PassportAttached and SlashMoon.Tasks.Lang("sn.investigation.passport_attached") or SlashMoon.Tasks.Lang("sn.investigation.passport_drop"), "SlashMoon.Small", w / 2, h / 2, form.PassportAttached and color_white or SlashMoon.UI.Colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    form.PassportSlot = passportSlot

    local selected = 1
    for index, option in ipairs(wep.ReportOptions) do
        local button = vgui.Create("SlashMoon.Button", form)
        button:SetSize(SlashMoon.UI.Scale(570), SlashMoon.UI.Scale(42))
        button:SetPos(SlashMoon.UI.Scale(25), SlashMoon.UI.Scale(190 + (index - 1) * 50))
        button:SetText("")
        button.Paint = function(self, w, h)
            local active = selected == index
            surface.SetDrawColor(active and SlashMoon.UI.Colors.Theme or Color(25, 30, 36, 255))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang(option), "SlashMoon.Text", SlashMoon.UI.Scale(14), h / 2, active and color_white or SlashMoon.UI.Colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        button.DoClick = function() selected = index end
    end

    local submit = vgui.Create("SlashMoon.Button", form)
    submit:SetSize(SlashMoon.UI.Scale(220), SlashMoon.UI.Scale(38))
    submit:SetPos(SlashMoon.UI.Scale(375), SlashMoon.UI.Scale(370))
    submit:SetBtnText(SlashMoon.Tasks.Lang("sn.investigation.submit_report"))
    submit.DoClick = function()
        if not form.PassportAttached then return end
        net.Start("SN_Investigation_ReportSubmit")
            net.WriteUInt(selected, 2)
        net.SendToServer()
        CloseReportPanel(false)
    end
end

local function DrawScreen(wep)
    local colors = SlashMoon.UI.Colors
    surface.SetDrawColor(8, 12, 16, 245)
    surface.DrawRect(0, 0, width, height)
    surface.SetDrawColor(colors.Theme)
    surface.DrawRect(0, 0, width, 3)

    draw.SimpleText(SlashMoon.Tasks.Lang("sn.investigation.report_title"), "SlashMoon.InvestigationReport", 12, 18, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(SlashMoon.Tasks.Lang("sn.investigation.passport_attached"), "SlashMoon.InvestigationReportSmall", 12, 42, Color(100, 220, 140), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(SlashMoon.Tasks.Lang("sn.investigation.choose_location"), "SlashMoon.InvestigationReportSmall", 12, 61, colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    for index, option in ipairs(wep.ReportOptions or {}) do
        local y = 76 + (index - 1) * 27
        local selected = index == (wep.SelectedOption or 1)
        surface.SetDrawColor(selected and colors.Theme or Color(25, 30, 36, 255))
        surface.DrawRect(10, y, width - 20, 22)
        draw.SimpleText((selected and "> " or "  ") .. SlashMoon.Tasks.Lang(option), "SlashMoon.InvestigationReportSmall", 16, y + 11, selected and color_white or colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    draw.SimpleText(SlashMoon.Tasks.Lang("sn.investigation.report_controls"), "SlashMoon.InvestigationReportSmall", 12, 176, colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function SWEP:PostDrawViewModel(viewModel)
    if not IsValid(viewModel) then return end
    local position, angle = viewModel:GetBonePosition(0)
    if not position then return end
    angle:RotateAroundAxis(angle:Right(), rotation.r)
    angle:RotateAroundAxis(angle:Up(), rotation.p)

    local right, forward, up = angle:Right(), angle:Forward(), angle:Up()
    right:Mul(offset.x)
    forward:Mul(offset.y)
    up:Mul(offset.z)
    position:Add(right)
    position:Add(forward)
    position:Add(up)

    cam.Start3D2D(position, angle, 0.012)
        DrawScreen(self)
    cam.End3D2D()
end

MODULE:Hook("Think", "SN_Investigation_ReportTabletUI", function()
    local ply = LocalPlayer()
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "sn_investigation_tablet" or not wep:GetFullView() then
        CloseReportPanel(false)
        return
    end

    local escDown = input.IsKeyDown(KEY_ESCAPE)
    if escDown and not escWasDown then
        CloseReportPanel(true)
        escWasDown = escDown
        return
    end
    escWasDown = escDown
    OpenReportPanel(wep)
end)

function SWEP:DrawWorldModel()
    self:DrawModel()
end
