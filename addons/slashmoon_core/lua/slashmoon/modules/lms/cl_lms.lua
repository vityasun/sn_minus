-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("lms")

-- ========================================================
-- LMS (Last Man Standing): клиентская часть
-- ========================================================

CreateClientConVar("fh_lms_volume", "0.8", true, false, "Change volume lms sound", 0, 1)

local colors = SlashMoon.UI.Colors

local _lmsChannel  = nil      
local _lmsPlayerEnt = nil     
local _lmsActive   = false    
local _lmsName     = ""       
local _lmsRequest  = 0

local _lmsAlpha    = 0
local _lmsVisible  = false    

local function StopChannel()
    if IsValid(_lmsChannel) then _lmsChannel:Stop() end
    _lmsChannel = nil
end

local function DeactivateLMS()
    _lmsRequest = _lmsRequest + 1
    StopChannel()
    _lmsActive    = false
    _lmsVisible   = false
    _lmsPlayerEnt = nil
    _lmsName      = ""
end

MODULE:Hook("Think", "SN_LMS_VolumeTracker", function()
    if _lmsActive and IsValid(_lmsChannel) then
        local targetVol = GetConVar("fh_lms_volume"):GetFloat()
        if targetVol <= 0.01 then
            _lmsChannel:SetVolume(0)
        else
            _lmsChannel:SetVolume(targetVol)
        end
    end
end)

MODULE:Receive("fhi_lms_start", function()
    local url    = net.ReadString()
    local plyEnt = net.ReadEntity()

    StopChannel()
    _lmsRequest = _lmsRequest + 1
    local request = _lmsRequest

    _lmsPlayerEnt = plyEnt
    _lmsName      = IsValid(plyEnt) and plyEnt:Nick() or "???"
    _lmsActive    = true
    _lmsVisible   = true

    -- Трек может быть URL или локальным звуком (относительно sound/)
    local isURL = SlashMoon.HTTP.IsValidURL(url)
    local play = isURL and sound.PlayURL or sound.PlayFile
    local path = isURL and url or ("sound/" .. url)

    play(path, "noblock", function(channel, errid, errname)
        if request ~= _lmsRequest then
            if IsValid(channel) then channel:Stop() end
            return
        end
        if not IsValid(channel) then
            SlashMoon.Debug("[LMS] Не удалось загрузить трек ", url, ": ", errid, " (", errname, ")")
            return
        end
        
        if not _lmsActive then channel:Stop() return end

        _lmsChannel = channel
        channel:SetVolume(GetConVar("fh_lms_volume"):GetFloat())
        channel:EnableLooping(true)
        channel:Play()
    end)
end)

MODULE:Receive("fhi_lms_stop", function()
    if not _lmsActive then return end
    _lmsRequest = _lmsRequest + 1
    local request = _lmsRequest
    _lmsVisible = false
    timer.Simple(1, function()
        if request ~= _lmsRequest then return end
        DeactivateLMS()
    end)
end)

-- === ОТРИСОВКА ===
MODULE:Hook("HUDPaint", "fhi_lms_draw", function()
    if not _lmsActive and _lmsAlpha <= 0 then return end
    if not GetConVar("cl_drawhud"):GetBool() then return end

    local targetAlpha = _lmsVisible and 255 or 0
    _lmsAlpha = Lerp(FrameTime() * 5, _lmsAlpha, targetAlpha)

    if _lmsAlpha < 1 then return end

    local sw, sh = ScrW(), ScrH()
    local pnlW, pnlH = 340, 60
    local x = sw / 2 - pnlW / 2
    local y = 130 

    local offset = (1 - (_lmsAlpha / 255)) * 30

    surface.SetDrawColor(15, 15, 15, _lmsAlpha * 0.9)
    surface.DrawRect(x, y - offset, pnlW, pnlH)

    surface.SetDrawColor(colors.Theme.r, colors.Theme.g, colors.Theme.b, _lmsAlpha)
    surface.DrawRect(x, y - offset, 4, pnlH)

    surface.SetDrawColor(colors.Outline.r, colors.Outline.g, colors.Outline.b, _lmsAlpha)
    surface.DrawOutlinedRect(x, y - offset, pnlW, pnlH, 1)

    local txtColor = Color(255, 255, 255, _lmsAlpha)
    local subColor = Color(colors.Theme.r, colors.Theme.g, colors.Theme.b, _lmsAlpha)

    SlashMoon.UI.Draw.TextShadow("ПОСЛЕДНИЙ ВЫЖИВШИЙ", "SlashMoon.Small", sw/2, y + 15 - offset, subColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    SlashMoon.UI.Draw.TextShadow(_lmsName, "SlashMoon.Header", sw/2, y + 38 - offset, txtColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

MODULE:Hook("fh_postendgame", "fhi_lms_cl_cleanup", DeactivateLMS)
MODULE:OnDisabled(DeactivateLMS)
