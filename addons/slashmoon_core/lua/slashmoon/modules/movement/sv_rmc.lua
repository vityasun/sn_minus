-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("movement")


if SERVER then
    util.AddNetworkString("FH_MovCfg_SetCvar")     -- клиент → сервер: хочу изменить конвар
end

local function cvarName(pillId, stat) return "fh_mov_" .. pillId:gsub("[%.]", "_") .. "_" .. stat end

-- ============================================================
-- ПРИМЕНЕНИЕ СКОРОСТЕЙ К АНИМАТРОНИКУ
-- ============================================================
local function ApplyAnimSpeed(ply, pillId)
    local walkCv = GetConVar(cvarName(pillId, "walk"))
    local runCv  = GetConVar(cvarName(pillId, "run"))
    local duckCv = GetConVar(cvarName(pillId, "duck"))
    local jumpCv = GetConVar(cvarName(pillId, "jump"))
    
    if not walkCv or not runCv or not duckCv or not jumpCv then return end

    local puppet = pills.getMappedEnt(ply)
    if not IsValid(puppet) then return end

    local walk = walkCv:GetInt()
    local run  = runCv:GetInt()
    local duck = duckCv:GetInt()
    local jump = jumpCv:GetInt()

    if puppet.formTable and puppet.formTable.moveSpeed then
        puppet.formTable.moveSpeed.walk   = walk
        puppet.formTable.moveSpeed.run    = run
        puppet.formTable.moveSpeed.ducked = duck
    end

    ply:SetWalkSpeed(walk)
    ply:SetRunSpeed(run)
    ply:SetSlowWalkSpeed(duck)
    ply:SetJumpPower(jump)
end

MODULE:Hook("PillApply", "FH_MovCfg_PillApply", function(ply, ent)
    local pillId = ent.formTable and ent.formTable.name
    if not pillId then return end
    timer.Simple(0.15, function()
        if IsValid(ply) then ApplyAnimSpeed(ply, pillId) end
    end)
end)

-- ============================================================
-- ПРИМЕНЕНИЕ СКОРОСТИ ВЫЖИВШИХ
-- ============================================================
local function ApplySurvivorsSpeed()
    local walk = GetConVar("fh_surv_walk") and GetConVar("fh_surv_walk"):GetInt() or 200
    local run  = GetConVar("fh_surv_run") and GetConVar("fh_surv_run"):GetInt() or 350
    local duck = GetConVar("fh_surv_duck") and GetConVar("fh_surv_duck"):GetInt() or 100
    local jump = GetConVar("fh_surv_jump") and GetConVar("fh_surv_jump"):GetInt() or 200

    for _, ply in player.Iterator() do
        if IsValid(ply) and ply:Team() == 2700 and not IsValid(pills.getMappedEnt(ply)) then
            local extMult = ply.FH_SpeedModifier or 1.0
            
            ply:SetWalkSpeed(walk * extMult)
            ply:SetRunSpeed(run * extMult)
            ply:SetSlowWalkSpeed(duck * extMult)
            ply:SetJumpPower(jump)
        end
    end
end

MODULE:Hook("PlayerSpawn", "FH_MovCfg_SurvSpawn", function(ply)
    timer.Simple(0.1, function()
        if not IsValid(ply) or ply:Team() ~= 2700 or IsValid(pills.getMappedEnt(ply)) then return end
        ApplySurvivorsSpeed()
    end)
end)

-- ============================================================
-- РЕГИСТРАЦИЯ КОЛЛБЕКОВ ПРИ ИЗМЕНЕНИИ КОНВАРОВ (Через 0.1 сек чтобы sh_rmc.txt 100% прогрузился)
-- ============================================================
timer.Simple(0.1, function()
    for _, def in ipairs(SlashMoon.Movement.AnimDefs or {}) do
        for _, stat in ipairs({ "walk", "run", "duck", "jump" }) do
            local name = cvarName(def.id, stat)
            cvars.AddChangeCallback(name, function(cv, old, new)
                for _, ply in player.Iterator() do
                    local puppet = pills.getMappedEnt(ply)
                    if IsValid(puppet) and puppet.formTable and puppet.formTable.name == def.id then
                        ApplyAnimSpeed(ply, def.id)
                    end
                end
            end, "FH_MovCfg")
        end
    end

    for _, name in ipairs({ "fh_surv_walk", "fh_surv_run", "fh_surv_duck", "fh_surv_jump" }) do
        cvars.AddChangeCallback(name, function() ApplySurvivorsSpeed() end, "FH_MovCfg_Surv")
    end
end)

-- ============================================================
-- ПРИМЕНЕНИЕ КОНВАРОВ ИЗ UI КЛИЕНТА
-- ============================================================
MODULE:Receive("FH_MovCfg_SetCvar", function(len, ply)
    if not IsValid(ply) then return end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_movement") then
        ply:ChatPrint("[MovConfig] Нет прав для изменения настроек.")
        return
    end

    local cvarNameStr = net.ReadString()
    local valueStr = tostring(net.ReadString() or "")
    local allowed = false

    for _, def in ipairs(SlashMoon.Movement.AnimDefs or {}) do
        for _, stat in ipairs({ "walk", "run", "duck", "jump" }) do
            if cvarName(def.id, stat) == cvarNameStr then allowed = true; break end
        end
        if allowed then break end
    end

    if not allowed then
        for _, cv in ipairs(SlashMoon.Movement.SurvCvars or {}) do
            if cv[1] == cvarNameStr then allowed = true; break end
        end
    end

    if not allowed then
        ply:ChatPrint("[MovConfig] Неизвестный конвар: " .. cvarNameStr)
        return
    end

    local cvarObj = GetConVar(cvarNameStr)
    if not cvarObj then return end

    -- ИСПРАВЛЕНИЕ: Вызываем напрямую SetString. 
    -- RunConsoleCommand часто блокируется или игнорируется!
    cvarObj:SetString(valueStr)
end)


function SlashMoon.Movement.RestoreAnimSpeed(ply)
    if not IsValid(ply) then return end
    local puppet = pills.getMappedEnt(ply)
    if not IsValid(puppet) then return end
    local pillId = puppet.formTable and puppet.formTable.name
    if pillId then ApplyAnimSpeed(ply, pillId) end
end
