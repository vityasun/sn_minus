-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("postprocess")

-- ========================================================
-- Постобработка карт: хранение и синхронизация
-- ========================================================

util.AddNetworkString("SN_PostProcess_Sync")
util.AddNetworkString("SN_PostProcess_Save")

local DIR_NAME = "sn_postprocess"
local FILE_NAME = DIR_NAME .. "/" .. game.GetMap() .. ".json"

SlashMoon.PostProcess = SlashMoon.PostProcess or {}
local PostProcess = SlashMoon.PostProcess

local function LoadMapSettings()
    PostProcess.Current = file.Read(FILE_NAME, "DATA")
end
LoadMapSettings()

local function Send(target)
    net.Start("SN_PostProcess_Sync")
    net.WriteString(PostProcess.Current or "")
    if target then net.Send(target) else net.Broadcast() end
end

MODULE:Hook("PlayerInitialSpawn", "SN_PostProcess_Send", function(ply)
    if PostProcess.Current then Send(ply) end
end)

-- Сохранение от администратора
MODULE:Receive("SN_PostProcess_Save", function(len, ply)
    if len > 64 * 1024 * 8 then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "postprocess_save", 2) then return end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_postprocess") then
        SlashMoon.Warn(ply:Nick(), " (", ply:SteamID(), ") пытался изменить постобработку без прав")
        return
    end

    local newData = net.ReadString()
    if not istable(SlashMoon.JSON.Decode(newData)) then return end

    if not file.IsDir(DIR_NAME, "DATA") then file.CreateDir(DIR_NAME) end
    file.Write(FILE_NAME, newData)
    PostProcess.Current = newData
    Send()

    ply:ChatPrint("[SlashMoon] Настройки графики сохранены для карты: " .. game.GetMap())
end)

-- При включении модуля на лету — сразу рассылаем настройки
MODULE:OnEnabled(function()
    if PostProcess.Current then Send() end
end)
