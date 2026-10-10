-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("ping")

-- ========================================================
-- Метки для союзников (ALT + ЛКМ)
-- Author: VIKA
-- ========================================================

local function IsAnimatronic(t)
    return t == 2701 or (TEAM_PILLS and t == TEAM_PILLS)
end

local function IsSurvivor(t)
    return TEAM_SURVIVOR and t == TEAM_SURVIVOR
end

local function IsSpectator(t)
    return (TEAM_SPECTATOR and t == TEAM_SPECTATOR)
        or (TEAM_UNASSIGNED and t == TEAM_UNASSIGNED)
end

-- В режиме лобби метки не нужны
local function IsLobby()
    return SlashMoon.Modules.IsEnabled("lobby")
end

if SERVER then
    util.AddNetworkString("SN_Ping_Send")
    util.AddNetworkString("SN_Ping_Broadcast")
    util.AddNetworkString("SN_Ping_Error")

    MODULE:Receive("SN_Ping_Send", function(len, ply)
        if IsLobby() then return end
        if not IsValid(ply) or not ply:Alive() then return end
        if not SlashMoon.Security.CheckRateLimit(ply, "ping_transport", 0.2) then return end
        local teamID = ply:Team()
        if IsSpectator(teamID) then return end

        local pos = net.ReadVector()
        if not pos or pos.x ~= pos.x or pos.y ~= pos.y or pos.z ~= pos.z then return end
        if ply:GetShootPos():Distance(pos) > MODULE:GetOption("max_dist") + 100 then return end

        ply.SN_LastPing = ply.SN_LastPing or 0
        local ct = CurTime()

        if ct < ply.SN_LastPing then
            net.Start("SN_Ping_Error")
            net.WriteUInt(math.ceil(ply.SN_LastPing - ct), 16)
            net.Send(ply)
            return
        end

        ply.SN_LastPing = ct + MODULE:GetOption("cooldown")

        local recipients = {}
        for _, v in ipairs(player.GetAll()) do
            local vTeam = v:Team()
            if IsSpectator(vTeam) then continue end
            -- Шлем только тиммейтам (выжившим — только тем, кто рядом: 3500^2)
            if vTeam == teamID then
                if not IsSurvivor(teamID) or v:GetPos():DistToSqr(pos) <= 12250000 then
                    table.insert(recipients, v)
                end
            end
        end

        if #recipients > 0 then
            net.Start("SN_Ping_Broadcast")
            net.WriteVector(pos)
            net.WriteUInt(teamID, 16)
            net.Send(recipients)
        end
    end)
end

if CLIENT then
    local activePings = {}
    local matPing = Material("vgui/sn/hud/ping.png", "noclamp smooth")
    local wasPinging = false
    local colors = SlashMoon.UI.Colors
    local Draw = SlashMoon.UI.Draw

    -- Ввод
    MODULE:Hook("Think", "SN_Ping_Input", function()
        local ply = LocalPlayer()
        if IsLobby() or not IsValid(ply) or IsSpectator(ply:Team()) or not ply:Alive() then
            wasPinging = false
            return
        end

        if input.IsKeyDown(KEY_LALT) and input.IsMouseDown(MOUSE_LEFT) then
            if wasPinging then return end
            wasPinging = true

            local tr = ply:GetEyeTrace()
            if not tr.Hit then return end

            if tr.StartPos:Distance(tr.HitPos) <= MODULE:GetOption("max_dist") then
                net.Start("SN_Ping_Send")
                net.WriteVector(tr.HitPos)
                net.SendToServer()
            else
                chat.AddText(colors.Accent, "[МЕТКА] ", color_white, "Слишком далеко!")
            end
        else
            wasPinging = false
        end
    end)

    MODULE:Receive("SN_Ping_Broadcast", function()
        local pos = net.ReadVector()
        local teamID = net.ReadUInt(16)
        local duration = MODULE:GetOption("duration")

        table.insert(activePings, {
            pos = pos,
            team = teamID,
            duration = duration,
            expire = CurTime() + duration,
        })

        SlashMoon.PlaySound(IsAnimatronic(teamID) and "sn/ping/anim.wav" or "sn/ping/surv.wav", "buttons/blip1.wav")
    end)

    MODULE:Receive("SN_Ping_Error", function()
        local timeLeft = net.ReadUInt(16)
        chat.AddText(colors.Accent, "[МЕТКА] ", color_white, "Способность перезаряжается! Осталось: ",
            colors.Danger, string.FormattedTime(timeLeft, "%02i:%02i"))
    end)

    MODULE:Hook("HUDPaint", "SN_Ping_Render", function()
        local ply = LocalPlayer()
        local myTeam = ply:Team()
        if IsSpectator(myTeam) then return end

        local ct = CurTime()
        local myPos = ply:GetPos()
        local maxVis = MODULE:GetOption("max_vis")

        for i = #activePings, 1, -1 do
            local p = activePings[i]

            if ct > p.expire then
                table.remove(activePings, i)
                continue
            end

            if myTeam ~= p.team then continue end

            local dist = myPos:Distance(p.pos)
            if IsSurvivor(myTeam) and dist > maxVis then continue end

            local scr = p.pos:ToScreen()
            if not scr.visible then continue end

            local timeAlive = ct - (p.expire - p.duration)
            local size = 82 * (1 + math.sin(timeAlive * 8) * 0.1)
            local alpha = p.expire - ct < 1 and 255 * (p.expire - ct) or 255
            local drawColor = IsAnimatronic(myTeam) and Color(255, 50, 50, alpha) or Color(50, 200, 100, alpha)

            if not matPing:IsError() then
                surface.SetDrawColor(255, 255, 255, alpha)
                surface.SetMaterial(matPing)
                surface.DrawTexturedRect(scr.x - size / 2, scr.y - size, size, size)
            else
                Draw.Circle(scr.x, scr.y - size / 2, size / 4, drawColor)
                Draw.TextShadow("!", "SlashMoon.Title", scr.x, scr.y - size / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            local distMeters = math.floor(dist * 0.01905)
            Draw.TextShadow(distMeters .. " м", "SlashMoon.Text", scr.x, scr.y + 10, Color(200, 200, 200, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)

    MODULE:OnDisabled(function() activePings = {} end)
end
