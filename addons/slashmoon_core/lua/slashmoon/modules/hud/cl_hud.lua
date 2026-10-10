-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("hud")

-- ========================================================
-- Полный редизайн HUD Fazbear's Hunt
-- Модуль перехватывает сетевые сообщения и HUD-хуки гейммода и рисует
-- собственный интерфейс. При отключении всё возвращается гейммоду.
-- ========================================================

local colors = SlashMoon.UI.Colors

-- === ЗАГРУЗКА КАСОМНЫХ ТЕКСТУР ===
local matTimerBg = Material("vgui/sn/hud/timer/timer.png", "noclamp smooth")
local matTimerGlow = Material("vgui/", "noclamp smooth") 

-- Умный кэш текстур для кнопок способностей
local keyMaterialsCache = {}
local keyToFileName = {
    ["MOUSE1"] = "LMB",
    ["MOUSE2"] = "RMB",
    ["MOUSE3"] = "MMB",
    ["SPACE"]  = "SPACE",
    ["CTRL"]   = "CTRL",
    ["SHIFT"]  = "SHIFT"
    -- Буквы (R, F, E и т.д.) не нуждаются в переводе, они будут искаться как R.png
}

local function GetAbilityKeyMaterial(rawKey)
    if not rawKey or rawKey == "" then return nil end
    local upKey = string.upper(rawKey)
    local fileName = keyToFileName[upKey] or upKey
    
    -- Если уже проверяли этот файл - отдаем из кэша
    if keyMaterialsCache[fileName] ~= nil then 
        return keyMaterialsCache[fileName] 
    end
    
    -- Пытаемся найти текстуру
    local path = "vgui/sn/hud/anim/" .. fileName .. ".png"
    local mat = Material(path, "noclamp smooth")
    
    if not mat:IsError() then
        keyMaterialsCache[fileName] = mat
        return mat
    else
        keyMaterialsCache[fileName] = false -- Запоминаем, что файла нет, чтобы не лагало
        return false
    end
end

-- Хранилище состояний перехваченного интерфейса
SlashMoon.FH = SlashMoon.FH or {
    Timer = { active = false, mode = "none", endT = 0, setupEndT = 0, total = 0, setupTotal = 0, title = "", sub = "" },
    Display = { active = false, text1 = "", text2 = "", endT = 0, fadeT = 0 },
    SpecActive = false,
    Companion = nil
}
SlashMoon.FH._fhHUDLoaded = true  -- Флаг: HUD загружен (для фазового таймера модуля tasks)

-- ========================================================
-- 1. ПОДАВЛЕНИЕ СТАРОГО ИНТЕРФЕЙСА (с возможностью вернуть его)
-- ========================================================
local SUPPRESSED_HOOKS = {
    "DrawGameTimer", "DrawKillerInterface", "DrawDead",
    "fh_killable", "fh_display_text", "FH_HudPaint_RMBHINT", "FH_HudPaint_E_HINT"
}
local suppressed = {}

MODULE:Hook("Think", "SN_HUD_Suppressor", function()
    local hudHooks = hook.GetTable().HUDPaint
    if not hudHooks then return end
    for _, hookName in ipairs(SUPPRESSED_HOOKS) do
        if hudHooks[hookName] then
            suppressed[hookName] = hudHooks[hookName]
            hook.Remove("HUDPaint", hookName)
        end
    end
end)

-- Глобальные функции подсказок принадлежат гейммоду — подменяем и запоминаем оригиналы
local OVERRIDDEN_GLOBALS = { "RMBHint", "RemoveRMBHint", "INTERACT_Hint", "RemoveINTERACT_Hint" }
local originalGlobals = {}

MODULE:OnDisabled(function()
    for hookName, fn in pairs(suppressed) do hook.Add("HUDPaint", hookName, fn) end
    suppressed = {}
    for name, fn in pairs(originalGlobals) do _G[name] = fn end
    originalGlobals = {}
end)

local FormatTime = SlashMoon.FormatTime

-- ========================================================
-- 2. ОТЛОЖЕННЫЙ ПЕРЕХВАТ СЕТИ И ФУНКЦИЙ
-- ========================================================
MODULE:Hook("Initialize", "SN_Override_Gamemode_Init", function()

    MODULE:Receive("fh_start_lobby_timer", function()
        local dur = net.ReadFloat()
        local snd = net.ReadString()
        if snd and snd ~= "" then surface.PlaySound(snd) end
        SlashMoon.FH.Timer = { active = true, mode = "lobby", title = language.GetPhrase("fazhunt.generic.startup"), sub = "", endT = CurTime() + dur, setupEndT = 0, total = dur, setupTotal = 0 }
    end)

    MODULE:Receive("fh_start_game_timer", function()
        local dur = net.ReadFloat()
        local setupDur = net.ReadFloat()
        local snd = net.ReadString()
        if snd and snd ~= "" then surface.PlaySound(snd) end
        
        local title = language.GetPhrase("fazhunt.generic.round") .. " " .. net.ReadString()
        SlashMoon.FH.Timer = { active = true, mode = "setup", title = title, sub = "", endT = CurTime() + dur + setupDur, setupEndT = CurTime() + setupDur, total = dur, setupTotal = setupDur }
    end)

    MODULE:Receive("fh_timer_cutback", function()
        local dur = net.ReadFloat()
        local snd = net.ReadString()
        if snd and snd ~= "" then surface.PlaySound(snd) end
        if SlashMoon.FH.Timer then
            SlashMoon.FH.Timer.endT = CurTime() + dur
            SlashMoon.FH.Timer.mode = "game"
        end
    end)

    MODULE:Receive("fh_pause_game_timer", function()
        local stamp = net.ReadFloat()
        local snd = net.ReadString()
        if snd and snd ~= "" then surface.PlaySound(snd) end
        if SlashMoon.FH.Timer then
            SlashMoon.FH.Timer.mode = "paused"
            SlashMoon.FH.Timer.sub = FormatTime(stamp)
        end
    end)

    MODULE:Receive("ResetTimer", function()
        if SlashMoon.FH.Timer then SlashMoon.FH.Timer.active = false end
        surface.PlaySound("ambient/levels/canals/windchime2.wav")
    end)

    MODULE:Receive("fh_net_display", function()
        local t1 = net.ReadString()
        local t2 = net.ReadString()
        local frmt = net.ReadFloat() or -1
        local dur = net.ReadFloat()
        
        if string.len(t1) > 0 then t1 = language.GetPhrase(t1) end
        if string.len(t2) > 0 then t2 = language.GetPhrase(t2) end
        if frmt > 0 then t2 = string.format(t2, frmt) end
        
        SlashMoon.FH.Display = { active = true, text1 = t1, text2 = t2, endT = CurTime() + dur, fadeT = CurTime() + dur + 1 }
    end)

    MODULE:Receive("ApplyKillerCompanion", function()
        SlashMoon.FH.Companion = { anim = net.ReadString(), color = net.ReadColor(), total = net.ReadFloat(), startT = CurTime() }
    end)

    MODULE:Receive("RemoveKillerCompanion", function() SlashMoon.FH.Companion = nil end)
    MODULE:Receive("DeadHUDEnable", function() SlashMoon.FH.SpecActive = true end)
    MODULE:Receive("DeadHUDDisable", function() SlashMoon.FH.SpecActive = false end)

    for _, name in ipairs(OVERRIDDEN_GLOBALS) do
        if _G[name] and originalGlobals[name] == nil then originalGlobals[name] = _G[name] end
    end

    function _G.RMBHint(duration)
        SlashMoon.FH.Display = { active = true, text1 = "ИСПОЛЬЗУЙТЕ [ПКМ]", text2 = "Доступно альтернативное действие", endT = CurTime() + (duration or 3), fadeT = CurTime() + (duration or 3) + 1 }
    end
    function _G.RemoveRMBHint() if SlashMoon.FH.Display then SlashMoon.FH.Display.active = false end end

    function _G.INTERACT_Hint(duration)
        SlashMoon.FH.Display = { active = true, text1 = "НАЖМИТЕ [E]", text2 = "Доступно взаимодействие", endT = CurTime() + (duration or 3), fadeT = CurTime() + (duration or 3) + 1 }
    end
    function _G.RemoveINTERACT_Hint() if SlashMoon.FH.Display then SlashMoon.FH.Display.active = false end end
end)

-- ========================================================
-- 3. ОТРИСОВКА В ФИРМЕННОМ СТИЛЕ SLASHMOON
-- ========================================================
MODULE:Hook("HUDPaint", "SN_MasterHUD_Render", function()
    if not GetConVar("cl_drawhud"):GetBool() then return end
    local sw, sh = ScrW(), ScrH()

    -- ── А) ГЛАВНЫЙ ТАЙМЕР РАУНДА ──
    -- Отображается когда SlashMoon.FH.Timer.active = true
    -- НО НЕ когда фазовая система тасков активна (SlashMoon.Phase.IsActive)
    -- — в этом случае модуль tasks рисует свой таймер с инфой о фазе
    local phaseActive = SlashMoon.Phase and SlashMoon.Phase.IsActive and SlashMoon.Phase.IsActive()
    if SlashMoon.FH.Timer.active and not phaseActive then
        local pnlW, pnlH = 350, 110
        local x = sw / 2 - pnlW / 2
        local y = 15

        local timeLeft = math.max(0, SlashMoon.FH.Timer.endT - CurTime())
        local setupLeft = math.max(0, SlashMoon.FH.Timer.setupEndT - CurTime())
        
        local isSetup = (setupLeft > 0)
        local tColor = (SlashMoon.FH.Timer.mode == "lobby") and Color(50, 150, 255) or Color(255, 50, 50)
        if isSetup then tColor = Color(255, 180, 50) end 

        if not matTimerBg:IsError() then
            surface.SetDrawColor(255, 255, 255, 250)
            surface.SetMaterial(matTimerBg)
            surface.DrawTexturedRect(x, y - 4, pnlW, pnlH)
        else
            surface.SetDrawColor(colors.DarkBG)
            surface.DrawRect(x, y, pnlW, pnlH)
            surface.SetDrawColor(tColor)
            surface.DrawRect(x, y, pnlW, 2)
            surface.SetDrawColor(colors.Outline)
            surface.DrawOutlinedRect(x, y, pnlW, pnlH, 1)
        end

        local fillP = isSetup and math.Clamp(setupLeft / math.max(1, SlashMoon.FH.Timer.setupTotal), 0, 1) or math.Clamp(timeLeft / math.max(1, SlashMoon.FH.Timer.total), 0, 1)
        local fillW = pnlW * fillP
        
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(x, y + pnlH - 6, pnlW, 6)
        surface.SetDrawColor(tColor)
        surface.DrawRect(x, y + pnlH - 6, fillW, 6)

        local tText = isSetup and "ПОДГОТОВКА" or SlashMoon.FH.Timer.title
        if SlashMoon.FH.Timer.mode == "paused" then tText = tText .. " [ПАУЗА]" end

        SlashMoon.UI.Draw.TextShadow(tText, "SlashMoon.Title", sw/2, y + 25, tColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local curTimeVal = isSetup and setupLeft or timeLeft
        local timeStr = (SlashMoon.FH.Timer.mode == "paused") and SlashMoon.FH.Timer.sub or FormatTime(curTimeVal)
        SlashMoon.UI.Draw.TextShadow(timeStr, "SlashMoon.PhaseTime", sw/2, y + 60, colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        if not matTimerGlow:IsError() then
            surface.SetDrawColor(tColor.r, tColor.g, tColor.b, 50)
            surface.SetMaterial(matTimerGlow)
            surface.DrawTexturedRect(sw / 2 - 114, y + 35, 227, 46)
        end
    end

    -- ── Б) HUD ОХОТНИКА (СПОСОБНОСТИ СЛЕВА) ──
    if currentKiller and currentKiller ~= "" then
        local kColor = fh_hud_color or colors.Theme
        
        local ax = 20
        local ay = sh - 90
        
        if SlashMoon.FH.Companion then
            local compW, compH = 200, 70
            
            surface.SetDrawColor(colors.DarkBG)
            surface.DrawRect(ax, ay, compW, compH)
            surface.SetDrawColor(SlashMoon.FH.Companion.color)
            surface.DrawRect(ax, ay, 4, compH)
            surface.SetDrawColor(colors.Outline)
            surface.DrawOutlinedRect(ax, ay, compW, compH, 1)

            local cElapsed = CurTime() - SlashMoon.FH.Companion.startT
            local cLeft = math.ceil(math.max(0, SlashMoon.FH.Companion.total - cElapsed))
            
            SlashMoon.UI.Draw.TextShadow("КОМПАНЬОН", "SlashMoon.Text", ax + 15, ay + 20, SlashMoon.FH.Companion.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            SlashMoon.UI.Draw.TextShadow(cLeft .. " СЕК", "SlashMoon.Header", ax + 15, ay + 45, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            
            ax = ax + compW + 20 
        end

        if currentAbilities then
            for aName, aData in pairs(currentAbilities) do
                local timeLeft = aData.endTime and math.max(0, aData.endTime - CurTime()) or 0
                if timeLeft == 0 and aData.hidden then continue end
                
                local abW, abH = 260, 70
                local iconW = 60 
                local aClr = type(aData.color) == "function" and aData.color() or (aData.color or kColor)
                local isOnCooldown = (timeLeft > 0)

                surface.SetDrawColor(colors.DarkBG)
                surface.DrawRect(ax, ay, abW, abH)
                
                -- Левая зона иконки
                surface.SetDrawColor(10, 10, 10, 250)
                surface.DrawRect(ax, ay, iconW, abH)
                
                local rawKey = aData.text or ""
                
                -- === УМНАЯ ОТРИСОВКА ИКОНОК ===
                local customMat = GetAbilityKeyMaterial(rawKey)
                
                if customMat then
                    -- Рисуем найденную текстуру (LMB, RMB, R, F и т.д.)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(customMat)
                    surface.DrawTexturedRect(ax + 5, ay + 10, 50, 50)
                else
                    -- Запасной вариант (Текст, если картинки нет)
                    local shortKey = string.upper(rawKey)
                    if shortKey == "MOUSE1" then shortKey = "ЛКМ" end
                    if shortKey == "MOUSE2" then shortKey = "ПКМ" end
                    if shortKey == "MOUSE3" then shortKey = "СКМ" end
                    SlashMoon.UI.Draw.TextShadow(shortKey, "SlashMoon.Header", ax + iconW/2, ay + abH/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                surface.SetDrawColor(colors.Outline)
                surface.DrawRect(ax + iconW, ay, 1, abH)

                local transKey = "fazhunt.abilities." .. aName
                local aNameText = language.GetPhrase(transKey)
                if aNameText == transKey then aNameText = aName end
                
                SlashMoon.UI.Draw.TextShadow(string.upper(aNameText), "SlashMoon.Text", ax + iconW + 15, ay + abH/2, isOnCooldown and colors.TextMuted or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                if isOnCooldown then
                    local fillP = math.Clamp(timeLeft / (aData.maxTime or 1), 0, 1)
                    
                    surface.SetDrawColor(0, 0, 0, 200)
                    surface.DrawRect(ax, ay, abW, abH)
                    
                    surface.SetDrawColor(aClr.r, aClr.g, aClr.b, 100)
                    surface.DrawRect(ax, ay + abH - 6, abW * fillP, 6)

                    SlashMoon.UI.Draw.TextShadow(math.ceil(timeLeft) .. " СЕК", "SlashMoon.Title", ax + abW - 50, ay + abH/2, Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    surface.SetDrawColor(aClr)
                    surface.DrawRect(ax, ay + abH - 3, abW, 3)
                end

                surface.SetDrawColor(colors.Outline)
                surface.DrawOutlinedRect(ax, ay, abW, abH, 1)

                if aData.tokens and aData.tokens > 0 then
                    local tkW = 15
                    for i = 1, aData.tokens do
                        surface.SetDrawColor(aClr)
                        surface.DrawRect(ax + iconW + 15 + (i-1)*(tkW+5), ay - 10, tkW, 6)
                    end
                end

                ax = ax + abW + 20 
            end
        end
    end

    -- ── В) ИНТЕРФЕЙС НАБЛЮДАТЕЛЯ (Спектатор) ──
    if SlashMoon.FH.SpecActive then
        local lp = LocalPlayer()
        local target = lp:GetObserverTarget()
        
        if IsValid(target) and lp:GetObserverMode() ~= OBS_MODE_ROAMING then
            local dName = target:IsPlayer() and target:Nick() or (IsValid(target:GetOwner()) and target:GetOwner():Nick() or target:GetClass())
            local hpText = (target:Health() > 0) and (target:Health() .. " HP") or "МЕРТВ"

            local spW, spH = 300, 65
            local spX = sw/2 - spW/2
            local spY = sh - spH - 40

            surface.SetDrawColor(colors.DarkBG)
            surface.DrawRect(spX, spY, spW, spH)
            surface.SetDrawColor(Color(202, 125, 0))
            surface.DrawRect(spX, spY, 4, spH)
            surface.SetDrawColor(colors.Outline)
            surface.DrawOutlinedRect(spX, spY, spW, spH, 1)

            local safeName = utf8.sub(dName, 0, 23)
            if not safeName or safeName == "" then safeName = string.sub(dName, 1, 23) end -- Страховка

            SlashMoon.UI.Draw.TextShadow(language.SafeGetPhrase("fazhunt.spectating") .. ":", "SlashMoon.Small", spX + 15, spY + 15, Color(202, 125, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            SlashMoon.UI.Draw.TextShadow(safeName, "SlashMoon.Header", spX + 15, spY + 40, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            SlashMoon.UI.Draw.TextShadow(hpText, "SlashMoon.Header", spX + spW - 15, spY + 40, Color(255, 100, 100), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    -- ── Г) КРУПНЫЙ ТЕКСТ (Эвенты и Уведомления) ──
    if SlashMoon.FH.Display.active then
        if CurTime() > SlashMoon.FH.Display.fadeT then
            SlashMoon.FH.Display.active = false
            return
        end
        
        local alpha = 255
        if CurTime() > SlashMoon.FH.Display.endT then
            alpha = 255 * (1 - (CurTime() - SlashMoon.FH.Display.endT))
        end

        SlashMoon.UI.Draw.TextShadow(SlashMoon.FH.Display.text1, "SlashMoon.Broadcast", sw/2, sh/4, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.FH.Display.text2, "SlashMoon.BroadcastSub", sw/2, sh/4 + 50, Color(200, 200, 200, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- ── Д) ПРИЦЕЛ УБИЙСТВА (Для Аниматроника) ──
    if pills and pills.getMappedEnt then
        local ent = pills.getMappedEnt(LocalPlayer())
        if IsValid(ent) and ent:Get("killCondition") then
            if ent.formTable.killCondition(LocalPlayer(), ent) then
                local cs = 24
                surface.SetDrawColor(255, 50, 50, 255)
                surface.DrawRect(sw/2 - 2, sh/2 - cs/2, 4, cs)
                surface.DrawRect(sw/2 - cs/2, sh/2 - 2, cs, 4)
            end
        end
    end
end)
