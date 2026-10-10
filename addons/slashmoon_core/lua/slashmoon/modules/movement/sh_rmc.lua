-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("movement")

SlashMoon.Movement = SlashMoon.Movement or {}

-- =============================================================================
-- ОБЩИЕ КОНФИГИ И CONVARS
-- Теперь они инициализируются и на клиенте, и на сервере для корректной работы UI.
-- =============================================================================
SlashMoon.Movement.AnimDefs = {
    { id="pill_wfreddy2",    name="Withered Freddy",          walk=100,  run=385,  duck=80,  jump=250 },
    { id="pill_wbonnie2",    name="Withered Bonnie",          walk=90,   run=385,  duck=80,  jump=250 },
    { id="pill_wchica2",     name="Withered Chica",           walk=80,   run=385,  duck=80,  jump=250 },
    { id="pill_wfoxy2",      name="Withered Foxy",            walk=150,  run=390,  duck=70,  jump=400 },
    { id="pill_endo02",      name="Endo 02",                  walk=120,  run=375,  duck=160, jump=250 },
    { id="pill_sfreddy2",    name="Shadow Freddy",            walk=100,  run=285,  duck=65,  jump=250 },
    { id="pill_mangle",      name="Mangle",                   walk=66,   run=380,  duck=80,  jump=250 },
    { id="pill_toychica",    name="Toy Chica",                walk=220,  run=400,  duck=70,  jump=255 },
    { id="pill_wgfreddy2",   name="Withered Golden Freddy",   walk=110,  run=450,  duck=70,  jump=250 },
    { id="pill_springtrap",  name="Springtrap",               walk=110,  run=400,  duck=70,  jump=250 },
    { id="pill_clown",       name="Clown",                    walk=130,  run=370,  duck=0,   jump=250 },
    { id="bear5_main",       name="Bear 5",                   walk=150,  run=400,  duck=75,  jump=240 },
    { id="fox4",             name="Fox 4",                    walk=475,  run=450,  duck=150, jump=300 },
}

SlashMoon.Movement.SurvCvars = {
    { "fh_surv_walk", "200", "Survivor walk speed" }, { "fh_surv_run", "350", "Survivor run speed" },
    { "fh_surv_duck", "100", "Survivor duck speed" }, { "fh_surv_jump", "200", "Survivor jump power" },
    { "fh_stam_enabled", "1", "Enable stamina" }, { "fh_stam_drain_per_jump", "0.4", "Stamina drain per bhop" },
    { "fh_stam_regen_delay", "1.0", "Delay before regen starts" }, { "fh_stam_regen_rate", "0.18", "Regen per sec" },
    { "fh_stam_effect_threshold", "0.25", "Stamina % where effects begin" }, { "fh_stam_max_slow", "0.50", "Max speed reduction" },
    { "fh_stam_bhop_min_speed", "420", "Min speed to count as bhop" }, { "fh_stam_drain_speed", "0.04", "Secs per 1 drain unit" },
    { "fh_fx_camera_sway", "1", "Camera sway" }, { "fh_fx_sway_strength", "1.2", "Sway strength" }, { "fh_fx_sway_speed", "1.7", "Sway speed" },
    { "fh_fx_camera_bob", "1", "Camera bob" }, { "fh_fx_bob_speed_walk", "4.0", "Bob speed walk" }, { "fh_fx_bob_speed_run", "6.0", "Bob speed run" },
    { "fh_fx_bob_intensity", "0.20", "Bob intensity walk" }, { "fh_fx_bob_intensity_run", "0.35", "Bob intensity run" },
    { "fh_fx_tilt", "1", "Camera tilt" }, { "fh_fx_tilt_intensity", "3.0", "Tilt intensity" }, { "fh_fx_tilt_smoothness", "4.0", "Tilt smoothness" },
    { "fh_fx_darkness", "0", "Darkness on fatigue" }, { "fh_fx_max_darkness", "0.15", "Max darkness" },
    { "fh_fx_frozen_frames", "0", "Frozen frame ghosting" }, { "fh_fx_frozen_alpha", "0.18", "Ghost opacity" }, { "fh_fx_frozen_decay", "0.35", "Ghost decay" },
    { "fh_fx_blur", "1", "Motion blur" }, { "fh_fx_blur_intensity", "0.4", "Motion blur intensity" },
    { "fh_fx_mouse_drift", "1", "Mouse drift" }, { "fh_fx_drift_radius", "16", "Drift radius" },
    { "fh_fx_color_desat", "1", "Color desat" }, { "fh_fx_desat_amount", "0.3", "Desat amount" },
    { "fh_fx_gasp_sound", "1", "Play gasp" }, { "fh_fx_gasp_threshold", "0.25", "Stamina level for gasp" },
    { "fh_fl_brightness", "0.5", "Flashlight brightness" }, { "fh_fl_fov", "55", "Flashlight FOV" },
    { "fh_fl_distance", "800", "Flashlight distance" }, { "fh_fl_render_dist", "1500", "Flashlight render distance" },
    { "fh_fl_smooth_speed", "14", "Smoothness speed" }, { "fh_fl_rot_speed", "10", "Rotation speed" },
    { "fh_fl_sway", "0.5", "Sway amount" }, { "fh_fl_bob_speed", "1.0", "Bob speed" }, { "fh_fl_sfr_radius", "1600", "Shadow Freddy radius" },
    { "fh_adr_fov", "12", "Adrenaline FOV boost" }, { "fh_adr_saturation", "1.6", "Adrenaline sat" },
    { "fh_adr_fade_speed", "2.0", "Adrenaline fade" }, { "fh_adr_dsp", "30", "Adrenaline DSP" },
    { "fh_dfb_duration", "2.5", "Defib duration" }, { "fh_dfb_dsp", "15", "Defib DSP" },
    { "fh_dfb_brightness", "-0.45", "Defib flash bright" }, { "fh_dfb_contrast", "1.8", "Defib contrast" },
    { "fh_dfb_bloom", "3.0", "Defib bloom" }, { "fh_dfb_flash", "0.32", "Defib flash duration" },
    { "fh_hp_start_fade", "60", "HP effects start" }, { "fh_hp_critical", "30", "HP critical" },
    { "fh_hp_min_sat", "0.4", "HP min sat" }, { "fh_hp_max_dark", "0.021", "HP max dark" },
    { "fh_hp_blur", "0.06", "HP blur intensity" }, { "fh_hp_drift_pitch", "1.0", "HP drift pitch" },
}

for _, def in ipairs(SlashMoon.Movement.AnimDefs) do
    local stats = { { "walk", def.walk }, { "run", def.run }, { "duck", def.duck }, { "jump", def.jump } }
    for _, s in ipairs(stats) do
        local name = "fh_mov_" .. def.id:gsub("[%.]", "_") .. "_" .. s[1]
        CreateConVar(name, tostring(s[2]), { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, def.name .. " – " .. s[1])
    end
end
for _, cv in ipairs(SlashMoon.Movement.SurvCvars) do
    CreateConVar(cv[1], cv[2], { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, cv[3])
end

local FH_CONFIG = {
    SurvivorTeam = 2700,
    AnimatronicTeam = 2701,

    TiltIntensity = 3.0,
    TiltSmoothness = 4.0,
    BobSpeedWalk = 4.0,
    BobSpeedRun = 6.0,
    BobIntensityBase = 0.20,
    BobIntensityRun = 0.35,
    FishEyeForce = 16.0,

    MinSpeedToFatigue = 220,
    StaminaBuildUpSpeed = 0.01,
    StaminaDrainSpeed = 0.1,
    StaminaMaxDarkness = 0.15,

    BhopMinSpeed = 420,
    StaminaDrainPerJump = 0.03,
    StaminaRegenRate = 0.18,
    StaminaLowThreshold = 0.067,
    StaminaMinSpeedMult = 0.84,
    StaminaSwayStrength = 1.2,
    StaminaSwaySpeed = 1.7,
    StaminaCircleRadius = 16,

    AdrenalineFOV = 12,
    AdrenalineSaturation = 1.6,
    AdrenalineFadeSpeed = 2.0,
    AdrenalineDSP = 30,

    RespawnDuration = 2.5,
    ShockFlashDuration = 0.32,
    RespawnDSP = 15,
    RespawnBloom = 3.0,
    RespawnContrast = 1.8,
    RespawnBrightness = -0.45,

    SndZap1 = "ambient/energy/zap1.wav",
    SndZap2 = "ambient/energy/zap2.wav",
    SndZap3 = "ambient/energy/zap3.wav",
    SndSpark1 = "ambient/energy/spark1.wav",
    SndSpark3 = "ambient/energy/spark3.wav",
    SndGasp = "player/survivor/voice/choke_01.wav",

    ShockVolume = 100,
    GaspVolume = 80,

    HP_StartFade = 60,
    HP_Critical = 30,
    HP_MinSaturation = 0.4,
    HP_MaxDarkness = 0.021,
    HP_ContrastBoost = 0.019,
    HP_DriftPitch = 1.0,
    HP_DriftRoll = 0.02,
    HP_BlurIntensity = 0.06,

    FlashlightBrightness = 0.5,
    FlashlightFOV = 55,
    FlashlightDistance = 800,
    FlashlightRenderDistance = 1500,
    FlashlightNearZ = 4,
    FlashlightEnableShadows = true,
    FlashlightColor = Color(255, 245, 230),
    FlashlightToggleDelay = 0.3,

    FlashlightSmoothSpeed = 14.0,
    FlashlightRotationSpeed = 10.0,
    FlashlightSwayAmount = 0.5,
    FlashlightBobSpeed = 1.0,
}

-- =============================================================================
-- СЕРВЕР
-- =============================================================================

if SERVER then
    if ConVarExists("df_flashlight") then
        RunConsoleCommand("df_flashlight", "0")
    end

    util.AddNetworkString("FH_FlashlightSync")
    util.AddNetworkString("FH_DefibEffects")
    util.AddNetworkString("FH_StaminaSpeed")

    local flashlightCooldowns = {}

    MODULE:Hook("PlayerSwitchFlashlight", "FH_FlashlightSwitch", function(ply, state)
        if not IsValid(ply) or not ply:Alive() then return false end
        if ply:GetMoveType() == MOVETYPE_NOCLIP then return false end
        if ply:Team() ~= FH_CONFIG.SurvivorTeam then return false end

        local lastToggle = flashlightCooldowns[ply:SteamID()] or 0
        if CurTime() - lastToggle < FH_CONFIG.FlashlightToggleDelay then return false end
        flashlightCooldowns[ply:SteamID()] = CurTime()

        local currentMode = ply:GetNW2Bool("FH_FlashlightOn", false)
        ply:SetNW2Bool("FH_FlashlightOn", not currentMode)
        ply:EmitSound("items/flashlight1.wav", 75, 100, 0.5)
        return false
    end)

    MODULE:Hook("PlayerSpawn", "FH_FlashlightSpawn", function(ply) ply:SetNW2Bool("FH_FlashlightOn", false) end)
    MODULE:Hook("PlayerDeath", "FH_FlashlightDeath", function(victim) victim:SetNW2Bool("FH_FlashlightOn", false) end)
    MODULE:Hook("PlayerNoClip", "FH_FlashlightNoclip", function(ply, state)
        if state then timer.Simple(0.1, function() if IsValid(ply) and ply:GetMoveType() == MOVETYPE_NOCLIP then ply:SetNW2Bool("FH_FlashlightOn", false) end end) end
    end)

    MODULE:Hook("PlayerDisconnected", "FH_FlashlightCleanup", function(ply)
        flashlightCooldowns[ply:SteamID()] = nil
        if ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end
    end)

    MODULE:Receive("FH_StaminaSpeed", function(len, ply)
        if not IsValid(ply) then return end
        if ply:Team() ~= FH_CONFIG.SurvivorTeam or ply:GetMoveType() == MOVETYPE_NOCLIP then return end
        local speedMult = math.Clamp(net.ReadFloat(), 0.4, 1.0)
        ply:SetNW2Float("FH_SpeedMult", speedMult)
        local baseWalk = GetConVar("fh_surv_walk"):GetInt()
        local baseRun  = GetConVar("fh_surv_run"):GetInt()
        local extMult = ply.FH_SpeedModifier or 1.0
        ply:SetWalkSpeed(baseWalk * speedMult * extMult)
        ply:SetRunSpeed(baseRun * speedMult * extMult)
    end)

    MODULE:Command("fh_trigger_defib", function(ply) if IsValid(ply) then net.Start("FH_DefibEffects"); net.Send(ply) end end)
    return
end

-- =============================================================================
-- КЛИЕНТ
-- =============================================================================

local function cvF(name, default)
    local c = GetConVar(name)
    return c and c:GetFloat() or (default or 0)
end
local function cvB(name, default)
    local c = GetConVar(name)
    if c then return c:GetBool() end
    return default ~= nil and default or false
end

local staminaEffect, adrenLerp, healthEffect = 0, 0, 0
local lastRespawnTime = -10
local lastGroundSpeed = 0
local dspActive, respawnDspActive, wasInNoclip = false, false, false
local lastFlashlightToggle, wasThirdPerson = 0, false
local stamina, staminaDrainAccum, lastStaminaDrain = 1.0, 0, 0   
local wasOnGround, lastSpeedNetSend, staminaSwayOffset = true, 0, 0
local frozenFrames, lastFreezeCapture, lastGaspTime = {}, 0, -999
local staminaMouseDriftTime, driftOffsetYaw, driftOffsetPitch = 0, 0, 0
local sfreddyInterference, sfreddyFlickerTime, sfreddyFlickerState = 0, 0, false

local function IsThirdPerson(ply)
    if not IsValid(ply) then return false end
    local viewEnt = GetViewEntity and GetViewEntity() or nil
    return IsValid(viewEnt) and viewEnt ~= ply
end

local function IsLocalSurvivor()
    local ply = LocalPlayer()
    return IsValid(ply) and ply:GetMoveType() ~= MOVETYPE_NOCLIP and ply:Team() == FH_CONFIG.SurvivorTeam
end

local function IsMasked(ply) return IsValid(ply) and ply:GetNW2Bool("KillerMaskEquiped", false) end
local function IsAdrenalineActive(ply)
    if not IsValid(ply) then return false end
    for _, child in ipairs(ply:GetChildren()) do if IsValid(child) and child:GetClass() == "env_spritetrail" then return true end end
    return false
end

local function LerpAngle(from, to, delta) return from + math.AngleDifference(to, from) * delta end

local function GetFatigue()
    local threshold = cvF("fh_stam_effect_threshold", 0.25)
    if stamina > threshold then return 0 end
    if threshold <= 0 then return 1 end
    return math.Clamp((threshold - stamina + 0.01) / (threshold + 0.01), 0, 1)
end

function SlashMoon.Movement.GetStamina() return stamina end
function SlashMoon.Movement.GetFatigue() return GetFatigue() end

local MAX_FROZEN_FRAMES = 3
local frozenRTs, frozenSlot = {}, 1

MODULE:Hook("InitPostEntity", "FH_InitRT", function()
    for i = 1, MAX_FROZEN_FRAMES do
        local rt = GetRenderTargetEx("fh_frozen_frame_" .. i, ScrW(), ScrH(), RT_SIZE_FULL_FRAME_BUFFER, MATERIAL_RT_DEPTH_NONE, 6, 0, IMAGE_FORMAT_RGB888)
        frozenRTs[i] = { rt = rt, mat = CreateMaterial("fh_frozen_frame_mat_" .. i, "UnlitGeneric", { ["$basetexture"] = rt:GetName(), ["$translucent"] = "1" }) }
    end
end)

local function CaptureFrozenFrame(fatigue)
    if not frozenRTs[frozenSlot] then return end
    local slot = frozenRTs[frozenSlot]
    render.CopyRenderTargetToTexture(slot.rt)
    frozenFrames[frozenSlot] = { slot = frozenSlot, alpha = 0, targetAlpha = cvF("fh_fx_frozen_alpha", 0.18) * fatigue, fadingIn = true }
    frozenSlot = (frozenSlot % MAX_FROZEN_FRAMES) + 1
end

local sfreddyCachedDist = nil
local function UpdateShadowFreddyCache()
    local ply = LocalPlayer()
    if not IsValid(ply) or not IsLocalSurvivor() then sfreddyCachedDist = nil; return end
    local closestDistSqr = nil
    local maxDistSqr = 1600 * 1600
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        local mdl = ent:GetModel()
        if mdl ~= "models/speps/pill/oldgoldenfreddy.mdl" and mdl ~= "models/speps/pill/oldgoldenfreddyhead.mdl" then continue end
        local mappedPill = pills and pills.getMappedEnt and pills.getMappedEnt(ent)
        if not mappedPill or not mappedPill.formTable or mappedPill.formTable.name ~= "pill_sfreddy2" then continue end
        local distSqr = ply:GetPos():DistToSqr(ent:GetPos())
        if distSqr <= maxDistSqr and (not closestDistSqr or distSqr < closestDistSqr) then closestDistSqr = distSqr end
    end
    sfreddyCachedDist = closestDistSqr and math.sqrt(closestDistSqr) or nil
end
MODULE:Timer("FH_ShadowFreddyScan", 0.3, 0, UpdateShadowFreddyCache)

MODULE:Hook("Think", "FH_DSP_Cleanup_Monitor", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not ply:Alive() or not IsLocalSurvivor() or IsMasked(ply) then
        if dspActive or respawnDspActive then ply:SetDSP(0, false); dspActive = false; respawnDspActive = false; lastRespawnTime = -10 end
    end
end)

MODULE:Hook("Think", "FH_ShadowFreddyInterference", function()
    if not IsLocalSurvivor() then sfreddyInterference = 0; return end
    local targetInterference = sfreddyCachedDist and (1 - sfreddyCachedDist / 1600) or 0
    sfreddyInterference = Lerp(FrameTime() * 2, sfreddyInterference, targetInterference)
    if sfreddyInterference > 0.3 then
        sfreddyFlickerTime = sfreddyFlickerTime + FrameTime() * (5 + sfreddyInterference * 10)
        sfreddyFlickerState = math.sin(sfreddyFlickerTime) > 0.5 or math.random() < sfreddyInterference * 0.3
    end
end)

local lastLandTime, isBhopping = 0, false

MODULE:Hook("Think", "FH_BhopStamina", function()
    if not IsLocalSurvivor() then stamina = 1.0; wasOnGround = true; staminaDrainAccum = 0; lastStaminaDrain = 0; isBhopping = false; return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or IsThirdPerson(ply) then return end

    local ft = FrameTime()
    local curTime = CurTime()
    local onGround = ply:OnGround()

    if onGround and not wasOnGround then lastLandTime = curTime end

    if onGround then
        if curTime - lastLandTime > 0.2 then isBhopping = false end
    else
        if wasOnGround and ply:GetVelocity().z > 50 and (curTime - lastLandTime) <= 0.25 then
            isBhopping = true
            lastStaminaDrain = curTime
        end
    end

    if cvB("fh_stam_enabled", true) then
        if isBhopping and not onGround then
            local drainInterval = math.max(cvF("fh_stam_drain_speed", 0.05), 0.005)
            staminaDrainAccum = staminaDrainAccum + ft
            while staminaDrainAccum >= drainInterval do
                stamina = math.Clamp(stamina - 0.01, 0, 1)
                staminaDrainAccum = staminaDrainAccum - drainInterval
                lastStaminaDrain = curTime
            end
        else
            staminaDrainAccum = 0
        end

        if curTime - lastStaminaDrain >= cvF("fh_stam_regen_delay", 1.0) then
            stamina = math.Clamp(stamina + cvF("fh_stam_regen_rate", FH_CONFIG.StaminaRegenRate) * ft, 0, 1)
        end
    else
        stamina = 1.0; staminaDrainAccum = 0; isBhopping = false
    end
    wasOnGround = onGround

    if cvB("fh_fx_gasp_sound", true) and stamina < cvF("fh_fx_gasp_threshold", 0.25) and (curTime - lastGaspTime) > 4 then
        lastGaspTime = curTime
        ply:EmitSound(FH_CONFIG.SndGasp, FH_CONFIG.GaspVolume, math.random(95, 105))
    end

    local speedMult = 1.0
    local fatigueLvl = GetFatigue()
    if fatigueLvl > 0 then
        local maxSlow = cvF("fh_stam_max_slow", 0.50)
        speedMult = math.Clamp(1.0 - (fatigueLvl * maxSlow), 1.0 - maxSlow, 1.0)
    end
    if (curTime - lastSpeedNetSend) >= 0.1 then
        lastSpeedNetSend = curTime
        net.Start("FH_StaminaSpeed"); net.WriteFloat(speedMult); net.SendToServer()
    end

    if cvB("fh_fx_frozen_frames", false) and fatigueLvl > 0 then
        if (curTime - lastFreezeCapture) > Lerp(fatigueLvl, 2.0, 0.3) then
            lastFreezeCapture = curTime
            ply._FH_FatigueCaptureLevel = fatigueLvl
            ply._FH_CaptureNextFrame = true
        end
    end
end)

MODULE:Hook("Think", "FH_UpdateScreenEffectsState", function()
    if not IsLocalSurvivor() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local ft = FrameTime(); local curTime = CurTime()
    healthEffect = math.Clamp((FH_CONFIG.HP_StartFade - ply:Health()) / FH_CONFIG.HP_StartFade, 0, 1)
    adrenLerp    = math.Approach(adrenLerp, IsAdrenalineActive(ply) and 1 or 0, ft * FH_CONFIG.AdrenalineFadeSpeed)
    local respawnProgress = math.EaseInOut(math.Clamp((lastRespawnTime + FH_CONFIG.RespawnDuration - curTime) / FH_CONFIG.RespawnDuration, 0, 1), 0.1, 0.9)

    if ply:IsPlayingTaunt() then return end

    local targetDSP = (respawnProgress > 0.01) and FH_CONFIG.RespawnDSP or (adrenLerp > 0.1 and FH_CONFIG.AdrenalineDSP or 0)
    if ply:Alive() then
        if targetDSP ~= (ply.FH_CurrentDSP or 0) then
            ply:SetDSP(targetDSP, false)
            ply.FH_CurrentDSP = targetDSP
            dspActive = (targetDSP == FH_CONFIG.AdrenalineDSP); respawnDspActive = (targetDSP == FH_CONFIG.RespawnDSP)
        end
    else
        if (ply.FH_CurrentDSP or 0) ~= 0 then ply:SetDSP(0, false); ply.FH_CurrentDSP = 0; dspActive = false; respawnDspActive = false end
    end

    if ply:OnGround() then lastGroundSpeed = ply:GetVelocity():Length() end
    staminaEffect = math.Approach(staminaEffect, (adrenLerp > 0 or respawnProgress > 0) and 0 or GetFatigue(), ft * 3)
end)

local nw2Cache, nw2CacheTime = {}, 0
MODULE:Hook("Think", "FH_DynamicFlashlightRender", function()
    local ft, curTime, localPly = FrameTime(), CurTime(), LocalPlayer()
    if (curTime - nw2CacheTime) >= 0.1 then
        nw2CacheTime = curTime
        for _, ply in ipairs(player.GetAll()) do if IsValid(ply) and ply ~= localPly then nw2Cache[ply] = ply:GetNW2Bool("FH_FlashlightOn", false) end end
    end
    
    local renderDistSqr = FH_CONFIG.FlashlightRenderDistance * FH_CONFIG.FlashlightRenderDistance

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or ply:Team() ~= FH_CONFIG.SurvivorTeam or (ply ~= localPly and (IsMasked(ply) or ply.invisible or ply:GetMaterial() == "models/null")) then
            if ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end
            continue
        end

        local isOn = (ply == localPly) and ply:GetNW2Bool("FH_FlashlightOn", false) or (nw2Cache[ply] or false)

        if not isOn then
            if ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end
            continue
        end

        if ply ~= localPly then
            if not IsValid(localPly) or localPly:GetPos():DistToSqr(ply:GetPos()) > renderDistSqr then
                if ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end
                continue
            end
            local shootPos, aimVec, eyePos, filter = ply:GetShootPos(), ply:GetAimVector(), localPly:EyePos(), {localPly, ply}
            local visible = not util.TraceLine({ start=eyePos, endpos=shootPos, filter=filter, mask=MASK_SOLID_BRUSHONLY }).Hit
            if not visible then
                local beamHit = util.TraceLine({ start=shootPos, endpos=shootPos + aimVec * FH_CONFIG.FlashlightDistance, filter={ply}, mask=MASK_SOLID_BRUSHONLY }).HitPos
                visible = not util.TraceLine({ start=eyePos, endpos=beamHit, filter=filter, mask=MASK_SOLID_BRUSHONLY }).Hit
            end
            if not visible then
                if ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end
                continue
            end
        end

        if not ply.FH_Flashlight then
            ply.FH_Flashlight = ProjectedTexture()
            ply.FH_Flashlight:SetTexture("effects/flashlight001")
            ply.FH_Flashlight:SetFOV(FH_CONFIG.FlashlightFOV)
            ply.FH_Flashlight:SetNearZ(20)
            ply.FH_Flashlight:SetFarZ(FH_CONFIG.FlashlightDistance)
            ply.FH_Flashlight:SetBrightness(FH_CONFIG.FlashlightBrightness)
            ply.FH_Flashlight:SetEnableShadows(ply == localPly)
            ply.FH_Flashlight:SetColor(FH_CONFIG.FlashlightColor)
        end

        local targetPos, targetAng
        if ply == localPly then
            local eyePos, aimVec = ply:EyePos(), ply:GetAimVector()
            targetPos = util.TraceHull({ start = eyePos, endpos = eyePos + aimVec * 41, filter = ply, mins = Vector(-2, -2, -2), maxs = Vector(2, 2, 2) }).HitPos - aimVec * 2
            targetAng = ply:EyeAngles()
            if ply:OnGround() and not IsThirdPerson(ply) then
                local speed = ply:GetVelocity():Length()
                if speed > 10 then
                    ply.FH_BobTime = (ply.FH_BobTime or 0) + ft * FH_CONFIG.FlashlightBobSpeed * (speed / 250)
                    targetAng.pitch = targetAng.pitch + math.sin(ply.FH_BobTime) * FH_CONFIG.FlashlightSwayAmount * (speed / 250)
                    targetAng.yaw   = targetAng.yaw   + math.cos(ply.FH_BobTime * 0.5) * FH_CONFIG.FlashlightSwayAmount * (speed / 250)
                end
            end
            if not ply.FH_FlashlightSmooth then ply.FH_FlashlightSmooth = { pos = targetPos, ang = Angle(targetAng) } end
            local sm = ply.FH_FlashlightSmooth
            sm.pos = LerpVector(math.Clamp(FH_CONFIG.FlashlightSmoothSpeed * ft, 0, 1), sm.pos, targetPos)
            sm.ang.pitch = LerpAngle(sm.ang.pitch, targetAng.pitch, math.Clamp(FH_CONFIG.FlashlightRotationSpeed * ft, 0, 1))
            sm.ang.yaw   = LerpAngle(sm.ang.yaw,   targetAng.yaw,   math.Clamp(FH_CONFIG.FlashlightRotationSpeed * ft, 0, 1))
            sm.ang.roll  = LerpAngle(sm.ang.roll,  targetAng.roll,  math.Clamp(FH_CONFIG.FlashlightRotationSpeed * ft, 0, 1))
            ply.FH_Flashlight:SetPos(sm.pos); ply.FH_Flashlight:SetAngles(sm.ang)
        else
            ply.FH_Flashlight:SetPos(ply:GetShootPos() + ply:GetAimVector() * 10); ply.FH_Flashlight:SetAngles(ply:EyeAngles())
        end

        if ply == localPly and sfreddyInterference > 0.1 then
            ply.FH_Flashlight:SetBrightness(FH_CONFIG.FlashlightBrightness * (1 - sfreddyInterference * 0.7) * (sfreddyFlickerState and 1 or 0.3))
            if sfreddyInterference > 0.5 then
                ply.FH_Flashlight:SetColor(Color(255 - sfreddyInterference * 100, 245 - sfreddyInterference * 100, 230 - sfreddyInterference * 50))
            else ply.FH_Flashlight:SetColor(FH_CONFIG.FlashlightColor) end
        else
            ply.FH_Flashlight:SetBrightness(FH_CONFIG.FlashlightBrightness); ply.FH_Flashlight:SetColor(FH_CONFIG.FlashlightColor)
        end
        ply.FH_Flashlight:Update()
    end
end)

MODULE:Hook("OnReloaded", "FH_FlashlightCleanup", function() for _, ply in ipairs(player.GetAll()) do if ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end end end)

local function PlayDefibSequence()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local step = FH_CONFIG.RespawnDuration / 10
    ply:EmitSound(FH_CONFIG.SndZap1, FH_CONFIG.ShockVolume, 100)
    timer.Simple(step * 1,   function() if IsValid(ply) and IsLocalSurvivor() then ply:EmitSound(FH_CONFIG.SndSpark1, FH_CONFIG.ShockVolume, 110) end end)
    timer.Simple(step * 2.1, function() if IsValid(ply) and IsLocalSurvivor() then ply:EmitSound(FH_CONFIG.SndZap2,   FH_CONFIG.ShockVolume, 100) end end)
    timer.Simple(step * 3.3, function() if IsValid(ply) and IsLocalSurvivor() then ply:EmitSound(FH_CONFIG.SndZap3,   FH_CONFIG.ShockVolume, 100) end end)
    timer.Simple(step * 4,   function() if IsValid(ply) and IsLocalSurvivor() then ply:EmitSound(FH_CONFIG.SndSpark3, FH_CONFIG.ShockVolume, 100); ply:EmitSound(FH_CONFIG.SndGasp, FH_CONFIG.GaspVolume, 100) end end)
end

MODULE:Receive("FH_DefibEffects", function() if IsLocalSurvivor() then lastRespawnTime = CurTime(); PlayDefibSequence() end end)

MODULE:Hook("CreateMove", "FH_StaminaMouseDrift", function(cmd)
    if not IsLocalSurvivor() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or IsThirdPerson(ply) then return end

    local fatigue, ft = GetFatigue(), FrameTime()
    if fatigue <= 0 then
        driftOffsetYaw, driftOffsetPitch = Lerp(ft * 5, driftOffsetYaw, 0), Lerp(ft * 5, driftOffsetPitch, 0)
    else
        staminaMouseDriftTime = staminaMouseDriftTime + ft * FH_CONFIG.StaminaSwaySpeed
        local targetYaw   = math.sin(staminaMouseDriftTime * 0.009) * fatigue * FH_CONFIG.StaminaSwayStrength * 0.006
        local targetPitch = math.cos(staminaMouseDriftTime * 0.005) * fatigue * FH_CONFIG.StaminaSwayStrength * 0.0025
        local r, dist = FH_CONFIG.StaminaCircleRadius, math.sqrt(targetYaw * targetYaw + targetPitch * targetPitch)
        if dist > r then targetYaw, targetPitch = targetYaw * r / dist, targetPitch * r / dist end
        driftOffsetYaw, driftOffsetPitch = targetYaw, targetPitch
    end

    local ang = cmd:GetViewAngles()
    ang.yaw, ang.pitch = ang.yaw + driftOffsetYaw, math.Clamp(ang.pitch + driftOffsetPitch, -89, 89)
    cmd:SetViewAngles(ang)

    local inNoclip = (ply:GetMoveType() == MOVETYPE_NOCLIP)
    if inNoclip and not wasInNoclip then
        wasInNoclip = true
        if ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end
    elseif not inNoclip and wasInNoclip then
        wasInNoclip = false
        staminaEffect, adrenLerp, healthEffect, stamina, staminaSwayOffset, staminaMouseDriftTime = 0, 0, 0, 1.0, 0, 0
    end
end)

MODULE:Hook("TranslateFOV", "FH_RealisticCameraFOV", function(ply, fov)
    if not IsLocalSurvivor() or IsThirdPerson(ply) then return end
    local curTime = CurTime()
    local respawnProgress = math.EaseInOut(math.Clamp((lastRespawnTime + FH_CONFIG.RespawnDuration - curTime) / FH_CONFIG.RespawnDuration, 0, 1), 0.1, 0.9)
    return fov + (lastGroundSpeed / 150) + (adrenLerp * FH_CONFIG.AdrenalineFOV) - (respawnProgress * 15)
end)

MODULE:Hook("RenderScreenspaceEffects", "FH_VisualEffects", function()
    if not IsLocalSurvivor() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or IsMasked(ply) or ply:IsPlayingTaunt() then return end
    if not ply:Alive() then
        if dspActive or respawnDspActive then ply:SetDSP(0, false); dspActive = false; respawnDspActive = false end
        return
    end

    local curTime = CurTime()
    local respawnProgress = math.EaseInOut(math.Clamp((lastRespawnTime + FH_CONFIG.RespawnDuration - curTime) / FH_CONFIG.RespawnDuration, 0, 1), 0.1, 0.9)
    local shockProgress   = math.Clamp((lastRespawnTime + FH_CONFIG.ShockFlashDuration - curTime) / FH_CONFIG.ShockFlashDuration, 0, 1)
    local fatigue = GetFatigue()

    if fatigue > 0 and cvB("fh_fx_darkness", false) then
        local d = fatigue * cvF("fh_fx_max_darkness", FH_CONFIG.StaminaMaxDarkness)
        DrawColorModify({ ["$pp_colour_brightness"] = -d, ["$pp_colour_contrast"] = 1 + d * 0.4, ["$pp_colour_colour"] = math.Clamp(1 - fatigue * 0.3, 0.1, 1), ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0 })
    end

    local finalSaturation = Lerp(respawnProgress, Lerp(healthEffect, Lerp(adrenLerp, 1 - (staminaEffect * (cvB("fh_fx_color_desat", true) and cvF("fh_fx_desat_amount", 0.3) or 0)), cvF("fh_adr_saturation", FH_CONFIG.AdrenalineSaturation)), cvF("fh_hp_min_sat", FH_CONFIG.HP_MinSaturation)), 0.1)
    local finalBrightness = Lerp(respawnProgress, Lerp(adrenLerp, 0, 0.01), cvF("fh_dfb_brightness", FH_CONFIG.RespawnBrightness)) + (shockProgress * 0.45) - (healthEffect * cvF("fh_hp_max_dark", FH_CONFIG.HP_MaxDarkness))
    local finalContrast = Lerp(respawnProgress, 1.05, cvF("fh_dfb_contrast", FH_CONFIG.RespawnContrast)) + (healthEffect * FH_CONFIG.HP_ContrastBoost)
    DrawColorModify({ ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0, ["$pp_colour_brightness"] = finalBrightness - 0.02, ["$pp_colour_contrast"] = finalContrast + 0.07, ["$pp_colour_colour"] = finalSaturation * 0.9, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0 })

    local totalBlur = (respawnProgress * 0.9) + (healthEffect * cvF("fh_hp_blur", FH_CONFIG.HP_BlurIntensity)) + (cvB("fh_fx_blur", true) and (fatigue * cvF("fh_fx_blur_intensity", 0.4)) or 0)
    if totalBlur > 0.01 then DrawMotionBlur(0.1, math.Clamp(totalBlur, 0, 0.95), 0.05) end
    if respawnProgress > 0.1 or healthEffect > 0.5 then DrawBloom(0.1, (respawnProgress * cvF("fh_dfb_bloom", FH_CONFIG.RespawnBloom)) + (healthEffect * 0.3), 3, 3, 1, 0, 1, 1, 1) end

    if next(frozenFrames) and cvB("fh_fx_frozen_frames", false) then
        local ft_, decaySpeed, scrW, scrH = FrameTime(), cvF("fh_fx_frozen_decay", 0.35), ScrW(), ScrH()
        for i, frame in pairs(frozenFrames) do
            if frame.fadingIn then
                frame.alpha = math.min(frame.alpha + math.max(fatigue, 0.05) * 3.0 * ft_, frame.targetAlpha)
                if frame.alpha >= frame.targetAlpha then frame.fadingIn = false end
            else
                frame.alpha = math.max(frame.alpha - decaySpeed * ft_, 0)
                if frame.alpha <= 0 then frozenFrames[i] = nil; continue end
            end
            if frozenRTs[frame.slot] then
                surface.SetDrawColor(255, 255, 255, math.Clamp(frame.alpha * 255, 0, 200))
                surface.SetMaterial(frozenRTs[frame.slot].mat); surface.DrawTexturedRect(0, 0, scrW, scrH)
            end
        end
    end
end)

local function ResetEffects(ply)
    staminaEffect, adrenLerp, healthEffect, stamina, wasOnGround, staminaSwayOffset, staminaMouseDriftTime, driftOffsetYaw, driftOffsetPitch, lastGaspTime, lastRespawnTime = 0, 0, 0, 1.0, true, 0, 0, 0, 0, -999, -10
    table.Empty(frozenFrames)
    if IsValid(ply) and (dspActive or respawnDspActive) then ply:SetDSP(0, false) end
    dspActive, respawnDspActive = false, false
end

MODULE:Hook("PlayerDeath", "FH_ClearEffectsOnDeath", function() local ply = LocalPlayer(); if IsValid(ply) then ResetEffects(ply); if ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end end end)
MODULE:Hook("OnPlayerChangedTeam", "FH_FlashlightTeamCheck", function(ply, oldTeam, newTeam) if ply == LocalPlayer() and (newTeam == FH_CONFIG.AnimatronicTeam or newTeam == TEAM_SPECTATOR) then if ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end; ResetEffects(ply); ply:SetDSP(0, false) end end)
MODULE:Hook("player_spawn", "FH_FlashlightSpawnClient", function(data) local ply = Player(data.userid); if IsValid(ply) and ply:Team() == FH_CONFIG.SurvivorTeam and ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end end)
MODULE:Hook("PostCleanupMap", "FH_FlashlightMapCleanup", function() for _, ply in ipairs(player.GetAll()) do if ply.FH_Flashlight then ply.FH_Flashlight:Remove(); ply.FH_Flashlight = nil end end end)
MODULE:Hook("PlayerBindPress", "FH_FlashlightClientDelay", function(ply, bind, pressed) if pressed and IsValid(ply) and ply == LocalPlayer() and ply:Team() == FH_CONFIG.SurvivorTeam and string.find(bind, "impulse 100") then if CurTime() - lastFlashlightToggle < FH_CONFIG.FlashlightToggleDelay then return true end; lastFlashlightToggle = CurTime(); return false end end)
MODULE:Command("fh_test_revive", function() if IsLocalSurvivor() then lastRespawnTime = CurTime(); PlayDefibSequence() end end)
