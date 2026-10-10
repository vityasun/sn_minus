-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("scoreboard")

-- ========================================================
-- Табло игроков (TAB)
-- ========================================================

SlashMoon.Scoreboard = SlashMoon.Scoreboard or {}
local Scoreboard = SlashMoon.Scoreboard
local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

local BOOSTER_COLOR = Color(190, 106, 222)

-- ========================================================
-- 1. КОНФИГУРАЦИЯ И ДАННЫЕ
-- ========================================================
local function GetAnimatronicID(ply)
    -- 2701 — ID команды аниматроников в Fazbear's Hunt
    if not IsValid(ply) or ply:Team() ~= 2701 then return nil end
    if not ply.GetPill then return nil end

    local pill = ply:GetPill()
    if isstring(pill) then
        return string.lower(pill)
    elseif IsValid(pill) then
        if pill.GetPillForm then
            return string.lower(tostring(pill:GetPillForm()))
        end
        return string.lower(pill:GetClass())
    end
end

Scoreboard.AnimAvatars = {
    ["pill_springtrap"] = Material("sn_hub/chars/springtrap.png", "noclamp smooth"),
    ["pill_wfreddy2"]   = Material("sn_hub/chars/freddy.png", "noclamp smooth"),
    ["pill_wbonnie2"]   = Material("sn_hub/chars/bonnie.png", "noclamp smooth"),
    ["pill_wchica2"]    = Material("sn_hub/chars/chica.png", "noclamp smooth"),
    ["pill_wfoxy2"]     = Material("sn_hub/chars/foxy.png", "noclamp smooth"),
    ["pill_endo02"]     = Material("sn_hub/chars/minus_endo.png", "noclamp smooth"),
    ["pill_plushtrap"]  = Material("sn_hub/chars/plushtrap.png", "noclamp smooth"),
    ["pill_mangle"]     = Material("sn_hub/chars/mangle.png", "noclamp smooth"),
    ["pill_sfreddy"]    = Material("sn_hub/chars/shadow.png", "noclamp smooth"),
    ["pill_gfreddy"]    = Material("sn_hub/chars/golden.png", "noclamp smooth"),
}

local boosterIcon = Material("sn_hub/sn_tab/icon_by.png", "noclamp smooth")

-- Баннеры (фоны карточки игрока)
Scoreboard.Banners = {
    ["neon_city"]    = Material("sn_hub/banners/neon_city.png", "noclamp smooth"),
    ["dark_forest"]  = Material("sn_hub/banners/dark_forest.png", "noclamp smooth"),
    ["old"]          = Material("sn_hub/banners/old.png", "noclamp smooth"),
    ["factory_moon"] = Material("sn_hub/banners/zavod.png", "noclamp smooth"),
    ["hunter"]       = Material("sn_hub/banners/hunter.png", "noclamp smooth"),
    ["comeback"]     = Material("sn_hub/banners/comeback.png", "noclamp smooth"),
    ["died"]         = Material("sn_hub/banners/died.png", "noclamp smooth"),
    ["jpn"]          = Material("sn_hub/banners/jpn.png", "noclamp smooth"),
}

function Scoreboard.GetPlayerBanner(ply)
    return Scoreboard.Banners[ply:GetNW2String("SN_Banner", "")]
end

-- Бейджи рангов из настройки "ранг=ТЕКСТ:R,G,B; ..."
local function ParseBadges(text)
    local out = {}
    for entry in string.gmatch(tostring(text or ""), "[^;]+") do
        local rank, label, r, g, b = string.match(entry, "^%s*([^=]+)=([^:]+):%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
        if rank then
            out[string.Trim(rank)] = { text = string.Trim(label), color = Color(tonumber(r), tonumber(g), tonumber(b)) }
        end
    end
    return out
end

function Scoreboard.GetBadges(ply)
    local badges = {}
    local byRank = ParseBadges(MODULE:GetOption("badges"))
    local badge = byRank[SlashMoon.Admin.GetRank(ply)]
    if badge then badges[#badges + 1] = badge end
    hook.Run("SlashMoon.Scoreboard.Badges", ply, badges)
    return badges
end

function Scoreboard.GetPlayerAvatar(ply)
    if not IsValid(ply) then return "sn_hub/sn_tab/survivor_default.png" end
    if ply:GetNW2Bool("fh_isRat", false) then return "rat/rat.png" end
    if TEAM_PILLS and ply:Team() == TEAM_PILLS then return "sn_hub/sn_tab/animatronic_default.png" end
    return "sn_hub/sn_tab/survivor_default.png"
end

local function IsBooster(ply)
    return SlashMoon.Boosters and SlashMoon.Boosters.IsBooster(ply:SteamID64() or "") or false
end

-- ========================================================
-- 2. КОНТЕКСТНОЕ МЕНЮ ИГРОКА
-- ========================================================
local function VolumeCookie(ply)
    return "sn_vol_" .. tostring(ply:SteamID64() or ply:AccountID())
end

local function CopyToClipboard(label, value)
    SetClipboardText(tostring(value))
    UI.Toast(label .. " скопирован: " .. tostring(value), "success", 3)
end

local function OpenPlayerMenu(ply)
    if not IsValid(ply) then return end

    local menu = UI.ContextMenu(UI.Scale(320))
    Scoreboard.ActiveMenu = menu.Shield

    local isMuted = ply:IsMuted()
    menu:AddOption(isMuted and "Включить микрофон" or "Замьютить", isMuted and "icon16/sound_none.png" or "icon16/sound.png", function()
        if IsValid(ply) then ply:SetMuted(not isMuted) end
    end)

    -- Громкость голоса (сохраняется в cookie клиента)
    local initialVol = tonumber(cookie.GetString(VolumeCookie(ply)) or "") or 1
    if ply ~= LocalPlayer() then ply:SetVoiceVolumeScale(initialVol) end

    local volRow = UI.Create("Container")
    volRow:DockPadding(UI.Scale(14), UI.Scale(6), UI.Scale(14), UI.Scale(6))
    local volLabel = UI.Create("Label", volRow)
    volLabel:Dock(LEFT)
    volLabel:SetFont("SlashMoon.Small")
    volLabel:SetMuted(true)
    volLabel:SetText("Громкость")
    volLabel:SizeToContents()
    local volSlider = UI.Create("SliderBar", volRow)
    volSlider:Dock(FILL)
    volSlider:DockMargin(UI.Scale(12), 0, 0, 0)
    volSlider:SetMinMax(0, 1)
    volSlider:SetDecimals(2)
    volSlider:SetValue(initialVol, true)
    volSlider.OnValueChanged = function(_, vol)
        if not IsValid(ply) then return end
        if ply ~= LocalPlayer() then ply:SetVoiceVolumeScale(vol) end
        cookie.Set(VolumeCookie(ply), tostring(vol))
    end
    menu:AddPanel(volRow, UI.Scale(44))

    local targetName = "\"" .. ply:Nick() .. "\""
    if SlashMoon.Admin.CanRunCommand("pm") then
        menu:AddOption("Написать в ЛС", "icon16/email.png", function()
            UI.InputPopup("ЛС " .. targetName, "Введите сообщение для " .. targetName .. ":", "Сообщение...", "ОТПРАВИТЬ", function(msg)
                if msg and msg ~= "" then SlashMoon.Admin.RunCommand("pm", ply, msg) end
            end, "ОТМЕНА")
        end)
    end

    if not ply:IsBot() then
        menu:AddOption("Профиль Steam", "icon16/vcard.png", function() ply:ShowProfile() end)
    end

    if SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_scoreboard_admin") then
        menu:AddSpacer("АДМИНИСТРИРОВАНИЕ")

        local uid = ply:GetNW2Int("SN_UID", 0)
        if uid > 0 then
            menu:AddOption("Скопировать UID", "icon16/tag_blue.png", function() CopyToClipboard("UID", uid) end)
        end
        if not ply:IsBot() then
            menu:AddOption("Скопировать SteamID64", "icon16/page_copy.png", function() CopyToClipboard("SteamID64", ply:SteamID64()) end)
        end

        if SlashMoon.Admin.CanRunCommand("goto") then
            menu:AddOption("Телепортироваться", "icon16/arrow_right.png", function() SlashMoon.Admin.RunCommand("goto", ply) end)
            menu:AddOption("Телепортировать к себе", "icon16/arrow_left.png", function() SlashMoon.Admin.RunCommand("bring", ply) end)
            menu:AddOption("Вернуть обратно", "icon16/arrow_undo.png", function() SlashMoon.Admin.RunCommand("return", ply) end)
            menu:AddOption("Кикнуть", "icon16/door_in.png", function()
                UI.InputPopup("КИК", "Введите причину кика:", "Причина...", "КИК", function(reason)
                    SlashMoon.Admin.RunCommand("kick", ply, reason ~= "" and reason or "Без причины")
                end, "ОТМЕНА")
            end)
            menu:AddOption("Забанить", "icon16/cancel.png", function()
                UI.DoubleInputPopup("БАН", "Введите срок наказания и причину:", "Срок (1m | 1h | 1d)...", "Причина...", "ЗАБАНИТЬ", function(duration, reason)
                    SlashMoon.Admin.RunCommand("ban", ply, duration, reason ~= "" and reason or "Без причины")
                end, "ОТМЕНА")
            end)
        end
    end

    menu:Open()
end

-- ========================================================
-- 3. КАРТОЧКА ИГРОКА
-- ========================================================
local function CreatePlayerRow(parent, ply)
    if not IsValid(ply) then return end

    local rowHeight = math.Clamp(math.floor(ScrH() * 0.06), 70, 100)
    local muteIcon = Draw.Material("icon16/sound_none.png")

    local pnl = parent:Add("SlashMoon.Button")
    pnl:Dock(TOP)
    pnl:DockMargin(0, 0, 0, 8)
    pnl:SetTall(rowHeight)

    local badges = Scoreboard.GetBadges(ply)

    pnl.Paint = function(self, w, h)
        if not IsValid(ply) then self:Remove() return end

        local hovered = self:IsHovered()
        local bannerMat = Scoreboard.GetPlayerBanner(ply)
        if bannerMat and not bannerMat:IsError() then
            Draw.Icon(bannerMat, 0, 0, w, h, Color(255, 255, 255, hovered and 255 or 200))
            Draw.Box(0, 0, w, h, Color(0, 0, 0, hovered and 120 or 180))
        else
            Draw.Box(0, 0, w, h, hovered and colors.SurfaceHover or colors.Background)
        end

        Draw.Box(0, 0, 4, h, team.GetColor(ply:Team()) or colors.Accent)
        Draw.Outline(0, 0, w, h, colors.Border)

        local startX = rowHeight + 15
        local centerY = h / 2
        local nick = ply:Nick()
        local booster = IsBooster(ply)

        surface.SetFont("SlashMoon.PlayerName")
        local nickW = surface.GetTextSize(nick)
        Draw.TextShadow(nick, "SlashMoon.PlayerName", startX, centerY, booster and BOOSTER_COLOR or colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local curX = startX + nickW + 10
        if booster then
            if not Draw.Icon(boosterIcon, curX, centerY - 10, 20, 20, color_white) then
                Draw.Text("★", "SlashMoon.PlayerName", curX, centerY - 2, BOOSTER_COLOR, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            curX = curX + 30
        end

        for _, badge in ipairs(badges) do
            curX = curX + Draw.Badge(curX, centerY - 9, badge.text, badge.color)
        end

        local ping = ply:Ping()
        local pingColor = (ping > 200 and colors.Danger) or (ping > 100 and colors.Warning) or Color(211, 211, 211)
        Draw.TextShadow(ping .. " ms", "SlashMoon.Small", w - 15, centerY, pingColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        if ply:IsMuted() then
            Draw.Icon(muteIcon, w - 75, centerY - 8, 16, 16, colors.Danger)
        end
    end

    pnl.DoClick = function()
        if IsValid(ply) then OpenPlayerMenu(ply) end
    end

    local avatar = UI.Create("Avatar", pnl)
    avatar:SetSize(rowHeight, rowHeight)
    avatar:SetPos(4, 0)
    avatar:SetBorderColor(team.GetColor(ply:Team()) or colors.Accent)
    avatar:SetMouseInputEnabled(false)
    avatar.NextUpdate = 0

    avatar.Think = function(self)
        if not IsValid(ply) then return end

        local ct = CurTime()
        if ct < self.NextUpdate then return end
        self.NextUpdate = ct + 0.5

        self:SetBorderColor(team.GetColor(ply:Team()) or colors.Accent)

        local isRat = ply:GetNW2Bool("fh_isRat", false)
        local avatarID = ply:GetNW2String("SN_EquippedAvatar", "steam")
        local animID = GetAnimatronicID(ply)

        -- Кэш, чтобы не пересоздавать аватар каждые полсекунды
        if self.lastIsRat == isRat and self.lastAvatarID == avatarID and self.lastAnimID == animID then return end
        self.lastIsRat, self.lastAvatarID, self.lastAnimID = isRat, avatarID, animID

        if isRat then
            self:SetImage("rat/rat.png")
            return
        end

        local animMat = animID and Scoreboard.AnimAvatars[animID]
        if animMat and not animMat:IsError() then
            self:SetImage(animMat)
            return
        end

        if avatarID == "steam" then
            self:SetPlayer(ply, 128)
        else
            self:SetImage(avatarID)
        end
    end
end

-- ========================================================
-- 4. ОКНО ТАБЛО
-- ========================================================
local ScoreboardPanel = nil

local function ShowScoreboard()
    if IsValid(ScoreboardPanel) then
        if ScoreboardPanel.IsClosing then
            ScoreboardPanel:Stop()
            ScoreboardPanel:AlphaTo(255, 0.05, 0)
            ScoreboardPanel.IsClosing = false
        end
        return
    end

    local sw, sh = ScrW(), ScrH()
    local boardW = math.Clamp(sw * 0.45, 600, 1000)
    local boardH = math.Clamp(sh * 0.85, math.min(900, sh), 1700)
    local headerH = math.Clamp(math.floor(sh * 0.06), 50, 70)

    ScoreboardPanel = UI.Create("Frame")
    ScoreboardPanel:SetSize(boardW, boardH)
    ScoreboardPanel:Center()
    ScoreboardPanel:SetAnimated(false)
    ScoreboardPanel:SetBlur(false)
    ScoreboardPanel:SetDraggable(false)
    ScoreboardPanel:SetCloseOnEscape(false)
    ScoreboardPanel:SetHeaderHeight(headerH)
    ScoreboardPanel:ShowCloseButton(false)
    ScoreboardPanel:SetKeyboardInputEnabled(false)
    ScoreboardPanel:SetAlpha(0)
    ScoreboardPanel:AlphaTo(255, 0.05, 0)
    ScoreboardPanel.IsClosing = false

    ScoreboardPanel.Paint = function(self, w, h)
        local r = UI.GetRadius()
        Draw.RoundedBox(r, 0, 0, w, h, Color(15, 15, 15, 250))
        Draw.RoundedBox(r, 0, 0, w, headerH, colors.Header, true, true, false, false)
        Draw.Box(0, headerH, w, 2, colors.Accent)

        Draw.TextShadow(GetHostName(), "SlashMoon.Title", 20, headerH / 2, colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        Draw.TextShadow("ИГРОКОВ: " .. player.GetCount(), "SlashMoon.Header", w - 20, headerH / 2, colors.TextMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        Draw.RoundedOutline(r, 0, 0, w, h, colors.Border)
    end

    local mainScroll = UI.Create("Scroll", ScoreboardPanel)
    mainScroll:Dock(FILL)
    mainScroll:DockMargin(8, 8, 8, 8)
    ScoreboardPanel.Scroll = mainScroll

    local animatronics, survivors, spectators = {}, {}, {}
    for _, ply in ipairs(player.GetAll()) do
        local t = ply:Team()
        if TEAM_PILLS and t == TEAM_PILLS then
            table.insert(animatronics, ply)
        elseif TEAM_SPECTATOR and t == TEAM_SPECTATOR then
            table.insert(spectators, ply)
        else
            table.insert(survivors, ply)
        end
    end

    local function CreateCategoryHeader(title, color, marginTop)
        local header = mainScroll:Add("SlashMoon.Panel")
        header:Dock(TOP)
        header:DockMargin(0, marginTop, 0, 10)
        header:SetTall(30)
        header.Paint = function(_, w, h)
            Draw.TextShadow(title, "SlashMoon.Header", 0, 0, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            Draw.Box(0, h - 2, w, 2, Color(color.r, color.g, color.b, 100))
        end
    end

    local hasPrev = false
    if #animatronics > 0 then
        CreateCategoryHeader("АНИМАТРОНИКИ (" .. #animatronics .. ")", Color(255, 50, 50), 0)
        for _, ply in ipairs(animatronics) do CreatePlayerRow(mainScroll, ply) end
        hasPrev = true
    end

    if #survivors > 0 then
        if #animatronics > 0 or #spectators > 0 then
            CreateCategoryHeader("ВЫЖИВШИЕ (" .. #survivors .. ")", Color(50, 150, 255), hasPrev and 20 or 0)
        end
        for _, ply in ipairs(survivors) do CreatePlayerRow(mainScroll, ply) end
        hasPrev = true
    end

    if #spectators > 0 then
        if hasPrev then
            CreateCategoryHeader("НАБЛЮДАТЕЛИ (" .. #spectators .. ")", Color(150, 150, 150), 20)
        end
        for _, ply in ipairs(spectators) do CreatePlayerRow(mainScroll, ply) end
    end

    if Scoreboard.LastScroll then
        timer.Simple(0, function()
            if IsValid(mainScroll) then mainScroll:GetVBar():SetScroll(Scoreboard.LastScroll) end
        end)
    end
end

local function HideScoreboard(instant)
    if IsValid(Scoreboard.ActiveMenu) then Scoreboard.ActiveMenu:Remove() end
    if not IsValid(ScoreboardPanel) or ScoreboardPanel.IsClosing then return end

    ScoreboardPanel.IsClosing = true
    if IsValid(ScoreboardPanel.Scroll) then
        Scoreboard.LastScroll = ScoreboardPanel.Scroll:GetVBar():GetScroll()
    end

    if instant then
        ScoreboardPanel:Remove()
        ScoreboardPanel = nil
        return
    end

    ScoreboardPanel:AlphaTo(0, 0.05, 0, function()
        if IsValid(ScoreboardPanel) then ScoreboardPanel:Remove() end
        ScoreboardPanel = nil
    end)
end

-- Возврат значения из хука не дает гейммоду открыть свое табло
MODULE:Hook("ScoreboardShow", "SN_Scoreboard_Open", function()
    ShowScoreboard()
    return false
end)

MODULE:Hook("ScoreboardHide", "SN_Scoreboard_Close", function()
    HideScoreboard()
end)

-- Сохраненная громкость применяется до того, как голос дойдет до клиента
MODULE:Hook("PlayerStartVoice", "SN_Scoreboard_VoiceLock", function(ply)
    if not IsValid(ply) or ply == LocalPlayer() then return end
    local vol = tonumber(cookie.GetString(VolumeCookie(ply)) or "")
    if vol then ply:SetVoiceVolumeScale(vol) end
end)

MODULE:OnDisabled(function() HideScoreboard(true) end)
