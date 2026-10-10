-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("player_editor")

-- ========================================================
-- Редактор персонажа: сервер (применение модели, приватизация)
-- ========================================================

local Editor = SlashMoon.PlayerEditor

util.AddNetworkString("ronni_pe_apply_model")
util.AddNetworkString("ronni_pe_privatize_model")
util.AddNetworkString("ronni_pe_send_private_list")

-- Путь модели (lower) -> SteamID64, и обратный индекс (один игрок = одна модель)
local PrivateModels = {}
local PlayerPrivate = {}
local PRIVATE_FILE = "ronni_player_editor/private_models.json"

local loaded = SlashMoon.JSON.Decode(file.Read(PRIVATE_FILE, "DATA"))
if istable(loaded) then
    PrivateModels = loaded
    for mdl, sid in pairs(PrivateModels) do PlayerPrivate[sid] = mdl end
end

local function SavePrivate()
    if not file.IsDir("ronni_player_editor", "DATA") then file.CreateDir("ronni_player_editor") end
    file.Write(PRIVATE_FILE, SlashMoon.JSON.Encode(PrivateModels, true) or "{}")
end

local function SendPrivateList(target)
    net.Start("ronni_pe_send_private_list")
    net.WriteTable(PrivateModels)
    if target then net.Send(target) else net.Broadcast() end
end

MODULE:Hook("PlayerInitialSpawn", "ronni_pe_init_spawn", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then SendPrivateList(ply) end
    end)
end)

local function ApplyAppearance(ply, mdlname, skin, bodygroups, pcolor, wcolor)
    ply:SetModel(player_manager.TranslatePlayerModel(mdlname))
    ply:SetSkin(skin)
    local groups = string.Explode(" ", bodygroups or "")
    for k = 0, ply:GetNumBodyGroups() - 1 do
        ply:SetBodygroup(k, tonumber(groups[k + 1]) or 0)
    end
    if pcolor then ply:SetPlayerColor(pcolor) end
    if wcolor then ply:SetWeaponColor(wcolor) end
end

MODULE:Receive("ronni_pe_apply_model", function(_, ply)
    if not IsValid(ply) or not SlashMoon.Security.CheckRateLimit(ply, "pe_apply", 1) then return end

    local mdlname = net.ReadString()
    local skin = net.ReadInt(8)
    local bodygroups = net.ReadString()
    local pcolor = net.ReadVector()
    local wcolor = net.ReadVector()

    local mdlpath = string.lower(player_manager.TranslatePlayerModel(mdlname))
    local owner = PrivateModels[mdlpath]

    -- Нельзя взять чужую приватную модель или модель из скрытого списка
    if owner and owner ~= ply:SteamID64() then
        ply:ChatPrint("Эта модель приватизирована и недоступна для тебя.")
        return
    end
    if Editor.IsBlacklisted(mdlpath) then
        ply:ChatPrint("Эта модель заблокирована и не может быть использована.")
        return
    end

    ApplyAppearance(ply, mdlname, skin, bodygroups, pcolor, wcolor)
    timer.Simple(0.1, function()
        if IsValid(ply) and ply.SetupHands then ply:SetupHands() end
    end)
end)

-- Приватизация (mode 1) / снятие (mode 2) — только для бустеров
MODULE:Receive("ronni_pe_privatize_model", function(_, ply)
    if not IsValid(ply) or not SlashMoon.Security.CheckRateLimit(ply, "pe_privatize", 1) then return end
    if not Editor.IsBooster(ply) then
        ply:ChatPrint("У тебя нет прав для приватизации моделей.")
        return
    end

    local mdlname = net.ReadString()
    local mdlpath = string.lower(player_manager.TranslatePlayerModel(mdlname))
    local mode = net.ReadInt(4)
    local sid = ply:SteamID64()

    if mode == 1 then
        local currentOwner = PrivateModels[mdlpath]
        if currentOwner and currentOwner ~= sid then
            ply:ChatPrint("Эта модель уже приватизирована другим игроком.")
            return
        end

        local oldMdl = PlayerPrivate[sid]
        if oldMdl and oldMdl ~= mdlpath then
            PrivateModels[oldMdl] = nil
            ply:ChatPrint("Приватизация снята с предыдущей модели.")
        end

        PrivateModels[mdlpath] = sid
        PlayerPrivate[sid] = mdlpath
        SavePrivate()
        SendPrivateList()
        ply:ChatPrint("Модель приватизирована: " .. mdlname)
    elseif mode == 2 then
        if PrivateModels[mdlpath] ~= sid then
            ply:ChatPrint("Ты не являешься владельцем этой модели.")
            return
        end

        PrivateModels[mdlpath] = nil
        PlayerPrivate[sid] = nil
        SavePrivate()
        SendPrivateList()
        ply:ChatPrint("Приватизация снята: " .. mdlname)
    end
end)

-- После спавна возвращаем выбранный вид (гейммод может сбросить модель)
MODULE:Hook("PlayerSpawn", "ronni_pe_respawn", function(ply)
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        local mdlname = ply:GetInfo("cl_playermodel")
        local mdlpath = string.lower(player_manager.TranslatePlayerModel(mdlname))
        local owner = PrivateModels[mdlpath]
        if (owner and owner ~= ply:SteamID64()) or Editor.IsBlacklisted(mdlpath) then return end

        local pcol = ply:GetInfo("cl_playercolor")
        local wcol = ply:GetInfo("cl_weaponcolor")
        ApplyAppearance(ply, mdlname, ply:GetInfoNum("cl_playerskin", 0), ply:GetInfo("cl_playerbodygroups"),
            pcol and Vector(pcol) or nil, wcol and Vector(wcol) or nil)
    end)
end)
