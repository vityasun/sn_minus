-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- sn_animcam_tablet: autorun/server/sn_animcam_init.lua
-- Серверные команды и автологика выдачи планшета.
-- Интеграция с SlashMoon.Tasks.MapConfig для per-map настройки.

if not SERVER then return end

-- ============================================================
-- ConVar: автовыдача планшета выжившим при спавне
-- 0 = только вручную через команды
-- 1 = выдавать автоматически при спавне
-- MapConfig.animcam.autogive имеет приоритет над ConVar
-- ============================================================
local AUTOGIVE = CreateConVar(
    "sn_animcam_autogive", 0,
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "Auto-give animatronic tablet to survivors on spawn (0 = off, 1 = on). MapConfig overrides this."
)

local WEAPON_CLASS = "sn_animcam_tablet"

-- ============================================================
-- Вспомогательная: проверяем, можно ли выдать планшет
-- ============================================================
local function canGiveTablet(ply)
    if not IsValid(ply) then return false end
    if not ply:IsPlayer()  then return false end
    if not ply:Alive()     then return false end
    return SlashMoon.Tasks.Game.IsSurvivor(ply)
end

-- ============================================================
-- Вспомогательная: нужно ли автовыдавать (MapConfig приоритет)
-- ============================================================
local function shouldAutoGive()
    -- Приоритет: MapConfig -> ConVar
    if SlashMoon.Tasks and SlashMoon.Tasks.MapConfig and SlashMoon.Tasks.MapConfig.animcam then
        local mc = SlashMoon.Tasks.MapConfig.animcam
        if mc.autogive ~= nil then return mc.autogive end
    end
    return AUTOGIVE:GetBool()
end

-- ============================================================
-- Автовыдача при спавне
-- ============================================================
MODULE:Hook("PlayerSpawn", "SN_AnimcamAutoGive", function(ply)
    if not shouldAutoGive() then return end

    -- Небольшая задержка: даём FH успеть назначить роль
    timer.Simple(0.5, function()
        if not IsValid(ply) then return end
        if not canGiveTablet(ply) then return end
        if ply:HasWeapon(WEAPON_CLASS) then return end

        ply:Give(WEAPON_CLASS)
    end)
end)

-- ============================================================
-- Изъятие планшета, если игрок перестал быть выжившим
-- (например, стал аниматроником)
-- Поддерживаем оба хука: FH_RoleChanged (FH gamemode) и
-- SN_RoleChanged (если используется standalone режим)
-- ============================================================
local function onRoleChanged(ply)
    if not IsValid(ply) then return end
    if not SlashMoon.Tasks.Game.IsSurvivor(ply) then
        if ply:HasWeapon(WEAPON_CLASS) then
            ply:StripWeapon(WEAPON_CLASS)
        end
    end
end

MODULE:Hook("FH_RoleChanged", "SN_AnimcamRoleCheck", onRoleChanged)
MODULE:Hook("SN_RoleChanged", "SN_AnimcamRoleCheckSN", onRoleChanged)

-- ============================================================
-- Команды
-- ============================================================

-- Выдать планшет конкретному игроку (только суперадмин)
MODULE:Command("sn_animcam_give", function(caller, _, args)
    local isConsole = not IsValid(caller)
    if not isConsole and not SlashMoon.Admin.HasPermission(caller, "slashmoon_tasks_manage") then
        caller:PrintMessage(HUD_PRINTCONSOLE, "[sn_animcam] No permission.")
        return
    end

    if not args[1] then
        local msg = "[sn_animcam] Usage: sn_animcam_give <player name>\n"
        if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
        return
    end

    local target = nil
    for _, ply in player.Iterator() do
        if string.find(string.lower(ply:Nick()), string.lower(args[1]), 1, true) then
            target = ply
            break
        end
    end

    if not IsValid(target) then
        local msg = "[sn_animcam] Player not found: " .. args[1]
        if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
        return
    end

    if not canGiveTablet(target) then
        local msg = "[sn_animcam] Cannot give tablet to " .. target:Nick() .. " (not a survivor or not alive)"
        if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
        return
    end

    if target:HasWeapon(WEAPON_CLASS) then
        local msg = "[sn_animcam] " .. target:Nick() .. " already has the tablet."
        if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
        return
    end

    target:Give(WEAPON_CLASS)
    local msg = "[sn_animcam] Tablet given to " .. target:Nick()
    if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
end, nil, "Give animatronic tablet to a player")

-- Изъять планшет у конкретного игрока
MODULE:Command("sn_animcam_strip", function(caller, _, args)
    local isConsole = not IsValid(caller)
    if not isConsole and not SlashMoon.Admin.HasPermission(caller, "slashmoon_tasks_manage") then
        caller:PrintMessage(HUD_PRINTCONSOLE, "[sn_animcam] No permission.")
        return
    end

    if not args[1] then
        local msg = "[sn_animcam] Usage: sn_animcam_strip <player name>\n"
        if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
        return
    end

    local target = nil
    for _, ply in player.Iterator() do
        if string.find(string.lower(ply:Nick()), string.lower(args[1]), 1, true) then
            target = ply
            break
        end
    end

    if not IsValid(target) then
        local msg = "[sn_animcam] Player not found: " .. args[1]
        if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
        return
    end

    target:StripWeapon(WEAPON_CLASS)
    local msg = "[sn_animcam] Tablet stripped from " .. target:Nick()
    if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
end, nil, "Strip animatronic tablet from a player")

-- Выдать планшет всем текущим выжившим
MODULE:Command("sn_animcam_give_all", function(caller)
    local isConsole = not IsValid(caller)
    if not isConsole and not SlashMoon.Admin.HasPermission(caller, "slashmoon_tasks_manage") then
        caller:PrintMessage(HUD_PRINTCONSOLE, "[sn_animcam] No permission.")
        return
    end

    local count = 0
    for _, ply in player.Iterator() do
        if canGiveTablet(ply) and not ply:HasWeapon(WEAPON_CLASS) then
            ply:Give(WEAPON_CLASS)
            count = count + 1
        end
    end

    local msg = "[sn_animcam] Tablet given to " .. count .. " survivor(s)."
    if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
end, nil, "Give animatronic tablet to all survivors")

-- Изъять планшет у всех
MODULE:Command("sn_animcam_strip_all", function(caller)
    local isConsole = not IsValid(caller)
    if not isConsole and not SlashMoon.Admin.HasPermission(caller, "slashmoon_tasks_manage") then
        caller:PrintMessage(HUD_PRINTCONSOLE, "[sn_animcam] No permission.")
        return
    end

    local count = 0
    for _, ply in player.Iterator() do
        if ply:HasWeapon(WEAPON_CLASS) then
            ply:StripWeapon(WEAPON_CLASS)
            count = count + 1
        end
    end

    local msg = "[sn_animcam] Tablet stripped from " .. count .. " player(s)."
    if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
end, nil, "Strip animatronic tablet from all players")

-- ============================================================
-- Зарядка планшета
-- ============================================================

-- Зарядить конкретного игрока до 100%
MODULE:Command("sn_animcam_charge", function(caller, _, args)
    local isConsole = not IsValid(caller)
    if not isConsole and not SlashMoon.Admin.HasPermission(caller, "slashmoon_tasks_manage") then
        caller:PrintMessage(HUD_PRINTCONSOLE, "[sn_animcam] No permission.")
        return
    end

    if not args[1] then
        local msg = "[sn_animcam] Usage: sn_animcam_charge <player name>\n"
        if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
        return
    end

    local target = nil
    for _, ply in player.Iterator() do
        if string.find(string.lower(ply:Nick()), string.lower(args[1]), 1, true) then
            target = ply
            break
        end
    end

    if not IsValid(target) then
        local msg = "[sn_animcam] Player not found: " .. args[1]
        if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
        return
    end

    local wep = target:GetWeapon(WEAPON_CLASS)
    if not IsValid(wep) then
        local msg = "[sn_animcam] " .. target:Nick() .. " doesn't have the tablet."
        if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
        return
    end

    wep:SetBattery(1.0)
    local msg = "[sn_animcam] Tablet charged to 100% for " .. target:Nick()
    if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
end, nil, "Charge animatronic tablet to 100% for a player")

-- Зарядить всех сразу
MODULE:Command("sn_animcam_charge_all", function(caller)
    local isConsole = not IsValid(caller)
    if not isConsole and not SlashMoon.Admin.HasPermission(caller, "slashmoon_tasks_manage") then
        caller:PrintMessage(HUD_PRINTCONSOLE, "[sn_animcam] No permission.")
        return
    end

    local count = 0
    for _, ply in player.Iterator() do
        local wep = ply:GetWeapon(WEAPON_CLASS)
        if IsValid(wep) then
            wep:SetBattery(1.0)
            count = count + 1
        end
    end

    local msg = "[sn_animcam] Charged tablets for " .. count .. " player(s)."
    if isConsole then SlashMoon.Log(msg) else caller:PrintMessage(HUD_PRINTCONSOLE, msg) end
end, nil, "Charge animatronic tablet to 100% for all players")
