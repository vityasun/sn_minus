-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("postprocess")

-- ========================================================
-- Постобработка карт: рендер с кэшированием
-- ========================================================

SlashMoon.PostProcess = SlashMoon.PostProcess or {}
local PostProcess = SlashMoon.PostProcess

local cachedSettings = nil
local cachedColorModify = nil

local function RebuildCache(data)
    cachedSettings = data
    if data and data.colorMod then
        cachedColorModify = {
            ["$pp_colour_addr"] = data.colorMod.addr or 0,
            ["$pp_colour_addg"] = data.colorMod.addg or 0,
            ["$pp_colour_addb"] = data.colorMod.addb or 0,
            ["$pp_colour_brightness"] = data.colorMod.brightness or 0,
            ["$pp_colour_contrast"] = data.colorMod.contrast or 1,
            ["$pp_colour_colour"] = data.colorMod.colour or 1,
            ["$pp_colour_mulr"] = data.colorMod.mulr or 0,
            ["$pp_colour_mulg"] = data.colorMod.mulg or 0,
            ["$pp_colour_mulb"] = data.colorMod.mulb or 0,
        }
    else
        cachedColorModify = nil
    end
end

MODULE:Receive("SN_PostProcess_Sync", function()
    local data = SlashMoon.JSON.Decode(net.ReadString())
    PostProcess.Original = data and table.Copy(data) or nil
    RebuildCache(data)
end)

--- Живой предпросмотр из меню настройки.
function PostProcess.UpdatePreview(newData)
    RebuildCache(newData)
end

local cvBloom = CreateClientConVar("sn_postprocess_bloom", "1", true, false, "Показывать Bloom-эффект карты")

MODULE:Hook("RenderScreenspaceEffects", "SN_PostProcess_Render", function()
    if not cachedSettings then return end

    if cachedColorModify and cachedSettings.colorMod.enable ~= false then
        DrawColorModify(cachedColorModify)
    end

    local b = cachedSettings.bloom
    if b and b.enable ~= false and cvBloom:GetBool() then
        DrawBloom(b.darken, b.multiply, b.sizex, b.sizey, b.passes, b.color, b.r, b.g, b.b)
    end
end)
