-- Written for: SlashMoon. By: VIKA & Ronni

-- Реворк Shadow Freddy: клиентская часть (ЭКСПЕРИМЕНТАЛЬНО, отключено в исходной сборке)
--[[
sound.Add({
    name    = "sfreddy.foot",
    channel = CHAN_STATIC,
    level   = 90,
    volume  = 1.0,
    sound   = {
        ")SHADOWSTEP1.wav",
        ")SHADOWSTEP2.wav",
        ")SHADOWSTEP3.wav",
        ")SHADOWSTEP4.wav"
    }
})
sound.Add({
    name    = "sfreddy.run",
    channel = CHAN_STATIC,
    level   = 90,
    volume  = 1.0,
    sound   = { ")SHADOWSTEP1.wav" }
})

local PLUSHIE_MODEL = "models/RobGamings/ChuizaProductions/FNAF1/Plush/FreddyPlush.mdl"

local ENT_CL = {}
ENT_CL.Type      = "anim"
ENT_CL.Base      = "base_anim"
ENT_CL.PrintName = "Shadow Freddy Plushie"
ENT_CL.Spawnable = false

function ENT_CL:Initialize()
    self:SetModel(PLUSHIE_MODEL)
end

function ENT_CL:Draw()
    self:DrawModel()
end

scripted_ents.Register(ENT_CL, "sfreddy_plushie")

-- ── При надевании формы ───────────────────────────────────────────────────────
-- "submerge" нет в killerAbilities, значит assignAbilitiesByKiller его не создаёт.
-- Сервер шлёт таймер и токены под ключом "submerge" → cl_hud вызывает
-- setDuration("submerge") и setTokens("submerge"), но записи нет → ничего не работает.
-- Решение: создаём запись "Плюши" вручную (видимое название в худе),
-- и патчим setDuration/setTokens чтобы "submerge" перенаправлялось на "Плюши".
MODULE:Hook("PillApply", "sfr_cl_patch_submerge", function(ply, ent)
    if ply ~= LocalPlayer() then return end
    if ent.formTable.name ~= "pill_sfreddy2" then return end

    -- timer.Simple(0): выполнится после hud_ApplyKiller → table.Empty(currentAbilities)
    timer.Simple(0, function()
        if not currentAbilities then return end
        currentAbilities["submerge"] = nil  -- на всякий случай
        currentAbilities["Плюши"] = {
            text      = "MOUSE2",
            timeleft  = 0,
            tokens    = 0,
            maxtokens = 5,
            hidden    = false,
        }
    end)
end)

-- ── Сброс при снятии формы ───────────────────────────────────────────────────
MODULE:Hook("PillRestore", "sfr_cl_restore_submerge", function(ply)
    if ply ~= LocalPlayer() then return end
    if not currentAbilities then return end
    currentAbilities["Плюши"] = nil
    currentAbilities["submerge"] = nil
end)

-- ── Звуки ────────────────────────────────────────────────────────────────────
MODULE:Receive("sfr_play_sound", function()
    surface.PlaySound(net.ReadString())
end)

-- ── Хало вокруг плюш для выживших ───────────────────────────────────────────
MODULE:Hook("PreDrawHalos", "sfr_plushie_halo", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:IsAnimatronic() then return end

    local viewDir = ply:GetAimVector()
    local eyePos  = ply:EyePos()
    local targets = {}

    for _, ent in ipairs(ents.FindByClass("sfreddy_plushie")) do
        if not IsValid(ent) then continue end
        local toEnt = ent:GetPos() - eyePos
        if toEnt:LengthSqr() > 200^2 then continue end
        if viewDir:Dot(toEnt:GetNormalized()) >= 0.9848 then
            table.insert(targets, ent)
        end
    end

    if #targets > 0 then
        halo.Add(targets, Color(100, 100, 255), 2, 2, 1, true, false)
    end
end)
--]]
