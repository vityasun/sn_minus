-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

include("shared.lua")

local screenWidth, screenHeight = 240, 210
local screenOffset = Vector(-3.20, -1.66, 2.90)
local screenRotation = Angle(1.2, 0, 175)
local screenBackground = Color(10, 10, 10, 235)
local screenAccent = Color(255, 200, 60)
local screenMuted = Color(130, 130, 130)

-- Шрифт экрана (фиксированный размер рендер-таргета, без масштабирования)
SlashMoon.UI.RegisterRawFont("SlashMoon.InvestigationScanner", {
    font = system.IsWindows() and "Consolas" or "Arial",
    size = 18,
    weight = 700,
    antialias = true,
})
-- Шрифт экрана (фиксированный размер рендер-таргета, без масштабирования)
SlashMoon.UI.RegisterRawFont("SlashMoon.InvestigationScannerSmall", {
    font = system.IsWindows() and "Consolas" or "Arial",
    size = 14,
    weight = 500,
    antialias = true,
})

local clue = "Нет данных"
local scannedCase = ""
local verifyEnd = 0
local verifyStart = 0
local searchTarget
local searchStart = 0

local function DrawWrapped(text, x, y, font, color, maxWidth, lineHeight)
    surface.SetFont(font)
    local line = ""
    for _, word in ipairs(string.Explode(" ", tostring(text or ""), false)) do
        local candidate = line == "" and word or line .. " " .. word
        if line ~= "" and surface.GetTextSize(candidate) > maxWidth then
            surface.SetTextColor(color)
            surface.SetTextPos(x, y)
            surface.DrawText(line)
            y = y + (lineHeight or 18)
            line = word
        else
            line = candidate
        end
    end
    if line ~= "" then
        surface.SetTextColor(color)
        surface.SetTextPos(x, y)
        surface.DrawText(line)
    end
end

local function DrawScreen(wep)
    surface.SetDrawColor(screenBackground)
    surface.DrawRect(-10, -2, screenWidth + 20, screenHeight + 100)

    surface.SetFont("SlashMoon.InvestigationScanner")
    surface.SetTextColor(screenAccent)
    surface.SetTextPos(10, 22)
    surface.DrawText("РАССЛЕДОВАНИЕ")

    DrawWrapped(clue, 10, 52, "SlashMoon.InvestigationScannerSmall", color_white, screenWidth - 20, 18)

    surface.SetFont("SlashMoon.InvestigationScannerSmall")
    surface.SetTextColor(screenMuted)
    surface.SetTextPos(10, 112)
    surface.DrawText("Удерживайте E - обыскать")
    surface.SetTextPos(10, 132)
    surface.DrawText("E - обыскать труп")
    surface.SetTextPos(10, 152)
    surface.DrawText("R - открыть отчёт")

    if verifyEnd > CurTime() then
        local ratio = math.Clamp((CurTime() - verifyStart) / math.max(verifyEnd - verifyStart, 0.01), 0, 1)
        local progress = ratio < 0.25 and 0.2 or (ratio < 0.68 and 0.6 or ratio)
        surface.SetDrawColor(40, 30, 10, 255)
        surface.DrawRect(10, 178, screenWidth - 20, 14)
        surface.SetDrawColor(screenAccent)
        surface.DrawRect(10, 178, (screenWidth - 20) * progress, 14)
        surface.SetTextColor(screenAccent)
        surface.SetTextPos(10, 196)
        surface.DrawText(math.floor(progress * 100) .. "%")
    end
end

MODULE:Hook("Think", "SN_Investigation_SearchProgress", function()
    local ply = LocalPlayer()
    local weapon = IsValid(ply) and ply:GetActiveWeapon()
    if not IsValid(weapon) or weapon:GetClass() ~= "sn_corpse_scanner" then
        searchTarget = nil
        searchStart = 0
        return
    end

    local trace = ply:GetEyeTrace()
    local corpse = trace.Entity
    local canSearch = IsValid(corpse)
        and corpse:GetNW2Bool("SN_InvestigationCorpse", false)
        and not corpse:GetNW2Bool("SN_InvestigationSearched", false)
        and ply:GetPos():DistToSqr(trace.HitPos) <= 180 * 180
        and input.IsKeyDown(KEY_E)

    if canSearch and corpse == searchTarget then return end
    if canSearch then
        searchTarget = corpse
        searchStart = CurTime()
    else
        searchTarget = nil
        searchStart = 0
    end
end)

MODULE:Hook("HUDPaint", "SN_Investigation_SearchProgressHUD", function()
    if not IsValid(searchTarget) or searchStart <= 0 then return end
    local progress = math.Clamp((CurTime() - searchStart) / 3, 0, 1)
    local width, height = SlashMoon.UI.Scale(280), SlashMoon.UI.Scale(14)
    local x, y = ScrW() / 2 - width / 2, ScrH() / 2 + SlashMoon.UI.Scale(85)
    surface.SetDrawColor(10, 10, 10, 220)
    surface.DrawRect(x, y, width, height)
    surface.SetDrawColor(SlashMoon.UI.Colors.Theme)
    surface.DrawRect(x, y, width * progress, height)
    surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
    surface.DrawOutlinedRect(x, y, width, height, 1)
    SlashMoon.UI.Draw.TextShadow("ОБЫСК... " .. math.floor(progress * 100) .. "%", "SlashMoon.Small", ScrW() / 2, y - SlashMoon.UI.Scale(14), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

MODULE:Receive("SN_Investigation_Assign", function()
    local locationKey = net.ReadString()
    net.ReadString()
    clue = SlashMoon.Tasks.Lang("sn.investigation.clue", SlashMoon.Tasks.Lang(locationKey))
    scannedCase = ""
    local weapon = LocalPlayer():GetWeapon("sn_corpse_scanner")
    if IsValid(weapon) then weapon.ScannedCase = "" end
end)

MODULE:Receive("SN_Investigation_Scan", function()
    local locationKey = net.ReadString()
    local real = net.ReadBool()
    scannedCase = net.ReadString()
    clue = SlashMoon.Tasks.Lang("sn.investigation.clue", SlashMoon.Tasks.Lang(locationKey))
    local weapon = LocalPlayer():GetWeapon("sn_corpse_scanner")
    if IsValid(weapon) then weapon.ScannedCase = real and scannedCase or "" end
    notification.AddLegacy(real and "Найден паспорт." or "Найдена личная вещь.", real and NOTIFY_HINT or NOTIFY_GENERIC, 4)
end)

MODULE:Receive("SN_Investigation_Result", function()
    verifyEnd = 0
    local success = net.ReadBool()
    notification.AddLegacy(success and "Паспорт подтверждён." or "Паспорт не совпал.", success and NOTIFY_HINT or NOTIFY_ERROR, 4)
end)

MODULE:Receive("SN_Investigation_SubmitAck", function()
    local accepted = net.ReadBool()
    local duration = net.ReadFloat()
    if accepted then
        verifyStart = CurTime()
        verifyEnd = verifyStart + duration
    else
        notification.AddLegacy("Нужен паспорт с найденного трупа.", NOTIFY_ERROR, 3)
    end
end)

function SWEP:Deploy()
    return true
end

function SWEP:DrawScreen()
    DrawScreen(self)
end

function SWEP:PostDrawViewModel(viewModel)
    if not IsValid(viewModel) then return end
    local bonePosition, boneAngle = viewModel:GetBonePosition(39)
    if not bonePosition then return end

    boneAngle:RotateAroundAxis(boneAngle:Up(), screenRotation[1])
    boneAngle:RotateAroundAxis(boneAngle:Forward(), screenRotation[2])
    boneAngle:RotateAroundAxis(boneAngle:Right(), screenRotation[3])

    local right, forward, up = boneAngle:Right(), boneAngle:Forward(), boneAngle:Up()
    right:Mul(screenOffset[1])
    forward:Mul(screenOffset[2])
    up:Mul(screenOffset[3])
    bonePosition:Add(right)
    bonePosition:Add(forward)
    bonePosition:Add(up)

    cam.Start3D2D(bonePosition, boneAngle, 0.011)
        self:DrawScreen()
    cam.End3D2D()
end

function SWEP:DrawWorldModel()
    self:DrawModel()
    local owner = self:GetOwner()
    if not IsValid(owner) or owner ~= LocalPlayer() then return end

    local position = self:GetPos() + self:GetForward() * 4 + self:GetUp() * 3
    local angle = self:GetAngles()
    angle:RotateAroundAxis(angle:Forward(), 90)
    cam.Start3D2D(position, angle, 0.02)
        self:DrawScreen()
    cam.End3D2D()
end
