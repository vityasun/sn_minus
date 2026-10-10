-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("sliding")

-- ========================================================
-- Скольжение (на основе аддона Sliding Ability by GreatZenkakuMan)
-- Настройки — в админ-панели SlashMoon (модуль "Скольжение").
-- ========================================================

require("greatzenkakuman/predicted")
local predicted = greatzenkakuman.predicted
local isSingleplayer = game.SinglePlayer()

local Angle = Angle
local CurTime = CurTime
local GetInt = GetInt
local GetPos = GetPos
local GetFloat = GetFloat
local GetBool = GetBool
local GetNWBool = GetNWBool
local GetHoldType = GetHoldType
local GetNormalized = GetNormalized
local isangle = isangle
local IsZero = IsZero
local IsValid = IsValid
local IsPlayer = IsPlayer
local isfunction = isfunction
local Lerp = Lerp
local Length = Length
local LocalPlayer = LocalPlayer
local LookupBone = LookupBone
local math_abs = math.abs
local math_max = math.max
local math_Clamp = math.Clamp
local math_TimeFraction = math.TimeFraction
local ManipulateBonePosition = ManipulateBonePosition
local ManipulateBoneAngles = ManipulateBoneAngles
local Normalize = Normalize
local net_Start = net.Start
local net_WriteEntity = net.WriteEntity
local net_WriteUInt = net.WriteUInt
local net_WriteAngle = net.WriteAngle
local net_SendOmit = net.SendOmit
local net_Broadcast = net.Broadcast
local util_TraceLine = util.TraceLine
local Vector = Vector
local WorldSpaceCenter = WorldSpaceCenter

local vecBase = Vector(0, 0, 0)
local vecBoneOffset = Vector(0, 0, 8)
local vecViewModel = Vector(0, 1, -3)

local angThighOrigin = Angle(20, 35, 85)
local angCalfOrigin = Angle(0, 45, 0)
local angThighR = Angle(20, 60, 0)
local angCalfR = Angle(20, 65, 0)
local angThighL = Angle(-20, 60, 0)
local angCalfL = Angle(-20, 65, 0)
local angFoot = Angle(0, 30, 0)
local angNotZero = Angle(1, 1, 1)
local angBase = Angle(0, 0, 0)
local angViewpunch = Angle(-1, 0, -1)

sound.Add {
    name = "SlidingAbility.ImpactSoft",
    channel = CHAN_BODY,
    level = 75,
    volume = 0.6,
    sound = {
		"sn/slide/slidesound_dirt_01.wav",
		"sn/slide/slidesound_generic_01.wav",
		"sn/slide/slidesound_dirt_02.wav",
		"sn/slide/slidesound_generic_02.wav",
		"sn/slide/slidesound_dirt_03.wav",
		"sn/slide/slidesound_generic_03.wav",
		"sn/slide/slidesound_dirt_04.wav",
    },
}
sound.Add {
    name = "SlidingAbility.ScrapeRough",
    channel = CHAN_STATIC,
    level = 70,
    volume = 0.25,
    sound = "physics/body/body_medium_scrape_rough_loop1.wav",
}

local SLIDING_ABILITY_BLACKLIST = {
    climb_swep2 = true,
    parkourmod = true,
}
local SLIDE_ANIM_TRANSITION_TIME = 0.2
local SLIDE_TILT_DEG = 25
local SLIDE_VIEWMODEL_POS = 2
local SLIDE_VIEWMODEL_ANG = 45
local SLIDE_VIEWPUNCH = 1
local SLIDE_SPEED_BOOST = 1.5
local SLIDE_DUST_ENABLED = true
local SLIDE_ORIGIN_ANIM = false
-- local IN_MOVE = bit.bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT)
local ACT_HL2MP_SIT_CAMERA  = "sit_camera"
local ACT_HL2MP_SIT_DUEL    = "sit_duel"
local ACT_HL2MP_SIT_PASSIVE = "sit_passive"
local acts = {
    revolver = ACT_HL2MP_SIT_PISTOL,
    pistol   = ACT_HL2MP_SIT_PISTOL,
    shotgun  = ACT_HL2MP_SIT_SHOTGUN,
    smg      = ACT_HL2MP_SIT_SMG1,
    ar2      = ACT_HL2MP_SIT_AR2,
    physgun  = ACT_HL2MP_SIT_PHYSGUN,
    grenade  = ACT_HL2MP_SIT_GRENADE,
    rpg      = ACT_HL2MP_SIT_RPG,
    crossbow = ACT_HL2MP_SIT_CROSSBOW,
    melee    = ACT_HL2MP_SIT_MELEE,
    melee2   = ACT_HL2MP_SIT_MELEE2,
    slam     = ACT_HL2MP_SIT_SLAM,
    fist     = ACT_HL2MP_SIT_FIST,
    normal   = ACT_HL2MP_SIT,
    camera   = ACT_HL2MP_SIT_CAMERA,
    duel     = ACT_HL2MP_SIT_DUEL,
    passive  = ACT_HL2MP_SIT_PASSIVE,
    magic    = ACT_HL2MP_SIT_DUEL,
    knife    = ACT_HL2MP_SIT_KNIFE,
}

local cf = { FCVAR_ARCHIVE, FCVAR_GAMEDLL, FCVAR_REPLICATED }
local CVarAccel = CreateConVar("sliding_ability_acceleration", 250, cf,
"The acceleration/deceleration of the sliding. Larger value makes shorter sliding.", 0)
local CVarCooldown = CreateConVar("sliding_ability_cooldown", 0.5, cf,
"Cooldown time to be able to slide again in seconds.", 0)
local CVarCooldownJump = CreateConVar("sliding_ability_cooldown_jump", 1.5, cf,
"Cooldown time to be able to slide again when you jump while sliding, in seconds.", 0)
local CVarMaxSpeed = CreateConVar("sliding_ability_max_speed", 650, cf,
"The maximum speed that you can move at while sliding.", 0)
local CVarSpeedThreshold = CreateConVar("sliding_ability_threshold", -1, cf,
"Required speed to be able to slide, set to -1 for automatic", -1)
CreateConVar("sliding_ability_viewpunch", 1, cf)
CreateConVar("sliding_ability_tilt_viewmodelPosition", 2, cf)
CreateConVar("sliding_ability_tilt_viewmodelAngle", 45, cf)
CreateConVar("sliding_ability_legsAng", 20, cf)
CreateConVar("sliding_ability_thighAng", 60, cf)
CreateConVar("sliding_ability_calfAng", 65, cf)
CreateConVar("sliding_ability_footAng", 30, cf)
CreateConVar("sliding_ability_modelHeight", 8, cf)
CreateConVar("sliding_ability_modelTilt", 25, cf)
CreateConVar("sliding_ability_animTransitionTime", 0.2, cf, "", 0)
CreateConVar("sliding_ability_DustEffect", 1, cf, "", 0)
CreateConVar("sliding_ability_OriginAnim", 0, cf, "", 0)
CreateConVar("sliding_ability_speedBoost", 1.5, cf, "", 1)

if SERVER then util.AddNetworkString("SlidingAbility_CvarValues") util.AddNetworkString("SlidingAbility_BroadcastBoneManipulation") end
local function SetLocalCvarValue(convar)
	local legsAng = GetConVar("sliding_ability_legsAng"):GetInt()
	local thighAng = GetConVar("sliding_ability_thighAng"):GetInt()
	local calfAng = GetConVar("sliding_ability_calfAng"):GetInt()
	
	angThighR = Angle(legsAng, thighAng, 0)
	angCalfR = Angle(legsAng, calfAng, 0)
	angThighL = Angle(-legsAng, thighAng, 0)
	angCalfL = Angle(-legsAng, calfAng, 0)
	angFoot = Angle(0, GetConVar("sliding_ability_footAng"):GetInt(), 0)
	vecBoneOffset = Vector(0, 0, GetConVar("sliding_ability_modelHeight"):GetInt())
	SLIDE_TILT_DEG = GetConVar("sliding_ability_modelTilt"):GetInt()
	SLIDE_ANIM_TRANSITION_TIME = GetConVar("sliding_ability_animTransitionTime"):GetFloat()
	SLIDE_DUST_ENABLED = GetConVar("sliding_ability_DustEffect"):GetBool()
	SLIDE_VIEWMODEL_POS = GetConVar("sliding_ability_tilt_viewmodelPosition"):GetFloat()
	SLIDE_VIEWMODEL_ANG = GetConVar("sliding_ability_tilt_viewmodelAngle"):GetInt()
	SLIDE_VIEWPUNCH = GetConVar("sliding_ability_viewpunch"):GetFloat()
	SLIDE_ORIGIN_ANIM = GetConVar("sliding_ability_OriginAnim"):GetBool()
	SLIDE_SPEED_BOOST = GetConVar("sliding_ability_speedBoost"):GetFloat()
	
	if SERVER then
		if convar == "sliding_ability_OriginAnim" and SLIDE_ORIGIN_ANIM then
			SLIDE_TILT_DEG = 42
			vecBoneOffset = vecBase
			GetConVar("sliding_ability_modelTilt"):SetInt(42)
			GetConVar("sliding_ability_modelHeight"):SetInt(0)
		else
			net_Start("SlidingAbility_CvarValues") net.WriteString(convar or "") net_Broadcast()
		end
	end
end

if SERVER then
	cvars.AddChangeCallback("sliding_ability_legsAng", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_thighAng", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_calfAng", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_footAng", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_modelHeight", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_modelTilt", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_animTransitionTime", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_DustEffect", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_tilt_viewmodelPosition", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_tilt_viewmodelAngle", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_viewpunch", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_OriginAnim", SetLocalCvarValue)
	cvars.AddChangeCallback("sliding_ability_speedBoost", SetLocalCvarValue)
elseif CLIENT then
	MODULE:Receive("SlidingAbility_CvarValues", function() SetLocalCvarValue(net.ReadString()) end)
end
SetLocalCvarValue()


local function AngleEqualTol(a1, a2, tol)
    tol = tol or 1e-3
    if not (isangle(a1) and isangle(a2)) then return false end
    if math_abs(a1.pitch - a2.pitch) > tol then return false end
    if math_abs(a1.yaw   - a2.yaw)   > tol then return false end
    if math_abs(a1.roll  - a2.roll)  > tol then return false end
    return true
end

local function GetSlidingActivity(ply)
    local w, a = ply:GetActiveWeapon(), ACT_HL2MP_SIT_DUEL
    if IsValid(w) then
        a = acts[w:GetHoldType()]
         or acts[string.lower(w.HoldType or "")]
         or ACT_HL2MP_SIT_DUEL
    end
    if isstring(a) then
        return ply:GetSequenceActivity(ply:LookupSequence(a))
    end
    return a
end

local BoneAngleCache = SERVER and {} or nil
local function ManipulateBoneAnglesLessTraffic(ent, bone, ang, frac, isPlayer)
    local a = (not isSingleplayer and SERVER) and ang or ang * frac
    if (isSingleplayer or CLIENT) or not (BoneAngleCache[ent] and AngleEqualTol(BoneAngleCache[ent][bone], a, 1)) then
        ent:ManipulateBoneAngles(bone, a, isSingleplayer)
        if CLIENT then return end
        BoneAngleCache[ent] = BoneAngleCache[ent] or {}
        BoneAngleCache[ent][bone] = a
        if isSingleplayer then return end
        net_Start("SlidingAbility_BroadcastBoneManipulation")
        net_WriteEntity(ent)
        net_WriteUInt(bone, 8)
        net_WriteAngle(a)
        if isPlayer then
            net_SendOmit(ent)
        else
            net_Broadcast()
        end
    end
end

local function GetCurAngle(isAngleZero,angle1)
	if isAngleZero then return angBase
	else return angle1 end
end

local function ManipulateBones(ply, ent, base, isAngleZero)
    if not IsValid(ent) then return end
	
    local t0 = predicted.Get(ply, "SlidingAbility", "SlidingStartTime", 0)
    local ping = (isSingleplayer or SERVER) and 0 or LocalPlayer():Ping() / 1000
    local timefrac = math_TimeFraction(t0 - ping, t0 - ping + SLIDE_ANIM_TRANSITION_TIME, CurTime())
    timefrac = (not isSingleplayer and SERVER) and 1 or math_Clamp(timefrac, 0, 1)
	local isply = ent:IsPlayer()
	
	if not SLIDE_ORIGIN_ANIM then
		local bthighR, bthighL = ent:LookupBone("ValveBiped.Bip01_R_Thigh"), ent:LookupBone("ValveBiped.Bip01_L_Thigh")
		local bcalfR, bcalfL = ent:LookupBone("ValveBiped.Bip01_R_Calf"), ent:LookupBone("ValveBiped.Bip01_L_Calf")
		local bfootR, bfootL = ent:LookupBone("ValveBiped.Bip01_R_Foot"), ent:LookupBone("ValveBiped.Bip01_L_Foot")
		if bthighR or bthighL or bcalfR or bcalfL or bfootR or bfootL then ManipulateBoneAnglesLessTraffic(ent, 0, base, timefrac, isply) end
		if bthighR then ManipulateBoneAnglesLessTraffic(ent, bthighR, GetCurAngle(isAngleZero,angThighR), timefrac, isply) end
		if bcalfR then ManipulateBoneAnglesLessTraffic(ent, bcalfR, GetCurAngle(isAngleZero,angCalfR), timefrac, isply) end
		if bthighL then ManipulateBoneAnglesLessTraffic(ent, bthighL, GetCurAngle(isAngleZero,angThighL), timefrac, isply) end
		if bcalfL then ManipulateBoneAnglesLessTraffic(ent, bcalfL, GetCurAngle(isAngleZero,angCalfL), timefrac, isply) end
		local footAngle = GetCurAngle(isAngleZero,angFoot)
		if bfootR then ManipulateBoneAnglesLessTraffic(ent, bfootR, footAngle, timefrac, isply) end
		if bfootL then ManipulateBoneAnglesLessTraffic(ent, bfootL, footAngle, timefrac, isply) end
	else
		local bthigh, bcalf = ent:LookupBone("ValveBiped.Bip01_R_Thigh"), ent:LookupBone("ValveBiped.Bip01_R_Calf")
		if bthigh or bcalf then ManipulateBoneAnglesLessTraffic(ent, 0, base, timefrac, isply) end
		if bthigh then ManipulateBoneAnglesLessTraffic(ent, bthigh, GetCurAngle(isAngleZero,angThighOrigin), timefrac, isply) end
		if bcalf then ManipulateBoneAnglesLessTraffic(ent, bcalf, GetCurAngle(isAngleZero,angCalfOrigin), timefrac, isply) end
	end
	
	ply:ManipulateBonePosition(0, vecBoneOffset * timefrac)
end

local function SetSlidingPose(ply, ent, body_tilt)
    ManipulateBones(ply, ent, -Angle(0, 0, body_tilt), false)
end

local function IsSliding(ply)
    if predicted.Get(ply, "SlidingAbility", "IsSliding") then return true end
    if CLIENT and LocalPlayer() == ply then return false end
    return ply:GetNWBool("SlidingAbilityIsSliding", false)
end

local kaitCvar = false

local function CheckCrouching(ply)
    -- Compatibility issue with Movement - Reworked partially fixes by disabling crouch check
    if kaitCvar then return true end

    -- GetConVar returns nil on failure so this won't run twice
    if kaitCvar == false then kaitCvar = GetConVar("kait_movement_enabled") end
    return ply:Crouching()
end

local savavCvar = GetConVar("savav_parkour_Enable")
local exosuitCvar = GetConVar("sv_sliding_enabled")

MODULE:Hook("SetupMove", "SlidingAbility_CheckSliding", function(ply, mv)
    if ply:Team() ~= 2700 then return end
    if not CheckCrouching(ply) then return end
    local w = ply:GetActiveWeapon()
    if IsValid(w) and SLIDING_ABILITY_BLACKLIST[w:GetClass()] then return end
    if savavCvar and savavCvar:GetBool() then return end
    if exosuitCvar and exosuitCvar:GetBool() and ply.HasExosuit ~= false then return end

    predicted.Process("SlidingAbility", function(pr)
        -- Actual calculation of movement
		local walkspeed = ply:GetWalkSpeed()
		
        if pr.Get("IsSliding") then
            -- Calculate movement
			local plyOnGround = ply:OnGround()
            local velocity = pr.Get("SlidingCurrentVelocity", vecBase)
            local speed = velocity:Length()
            local speedref_crouch = walkspeed * ply:GetCrouchedWalkSpeed()

            local vdir = velocity:GetNormalized()
            local forward = mv:GetMoveAngles():Forward()
            local speedref_slide = pr.Get("SlidingMaxSpeed")
            local speedref_min = math.min(speedref_crouch, speedref_slide)
            local speedref_max = math_max(speedref_crouch, speedref_slide)
			local origin = mv:GetOrigin()
            local dp = origin - pr.Get("SlidingPreviousPosition", origin)
            local dp2d = Vector(dp.x, dp.y)
            dp:Normalize()
            dp2d:Normalize()
            local dot = forward:Dot(dp2d)
            local speedref = Lerp(math_max(-dp.z, 0), speedref_min, speedref_max)
            local accel = CVarAccel:GetFloat() * engine.TickInterval()
            if speed > speedref then accel = -accel end
            local maxspeed_cvar = CVarMaxSpeed:GetInt()
            velocity = LerpVector(0.005, vdir, forward) * math_Clamp(speed + accel, -maxspeed_cvar, maxspeed_cvar)

            SetSlidingPose(ply, ply, math.deg(math.asin(dp.z)) * dot + SLIDE_TILT_DEG)
            pr.Set("SlidingCurrentVelocity", velocity)
            pr.Set("SlidingPreviousPosition", origin)

            local cooldown = CVarCooldown:GetFloat()
            if mv:KeyPressed(IN_JUMP) or not plyOnGround then
                cooldown = CVarCooldownJump:GetFloat()
                velocity.z = ply:GetJumpPower()
            end

            mv:SetVelocity(velocity)
			
			local plyPos = ply:WorldSpaceCenter()
			local traceline = util_TraceLine({start = plyPos, endpos = plyPos + vdir * 32, filter = ply})
			
			if traceline.HitWorld or IsValid(traceline.Entity) then
				mv:SetVelocity(walkspeed * vdir * 0.5)
			    if SERVER then ply:SetNWBool("SlidingAbilityIsSliding", false) end
                pr.Set("IsSliding", false)
                pr.Set("SlidingCooldown", cooldown)
                pr.Set("SlidingEndTime", CurTime())
                pr.StopSound(ply, "SlidingAbility.ScrapeRough")
                ManipulateBones(ply, ply, angBase, true)
				ply:ManipulateBonePosition(0, vecBase)
            elseif not (plyOnGround and mv:KeyDown(IN_DUCK) and math_abs(speed - speedref_crouch) > 10) then
                if SERVER then ply:SetNWBool("SlidingAbilityIsSliding", false) end
                pr.Set("IsSliding", false)
                pr.Set("SlidingCooldown", cooldown)
                pr.Set("SlidingEndTime", CurTime())
                pr.StopSound(ply, "SlidingAbility.ScrapeRough")
                ManipulateBones(ply, ply, angBase, true)
				ply:ManipulateBonePosition(0, vecBase)
            end
			
			if SLIDE_DUST_ENABLED then
				local e = EffectData()
				e:SetOrigin(mv:GetOrigin())
				e:SetScale(1.6)
				pr.Effect("WheelDust", e)
			end

            return
        end

        -- Initial check to see if we can do it
        if not (ply:OnGround() and mv:KeyDown(IN_DUCK)) then return end
        -- if not mv:KeyDown(IN_SPEED) then return end -- This disables sliding for some people for some reason
        -- if not mv:KeyDown(IN_MOVE) then return end
		local CT = CurTime()
        if CT < pr.Get("SlidingEndTime", CT) + pr.Get("SlidingCooldown", 0) then return end
		local run = ply:GetRunSpeed()
        if math_abs(walkspeed - run) < 25 then return end

        local mvvelocity = mv:GetVelocity()
        local mvlength = mvvelocity:Length()
        local crouched = walkspeed * ply:GetCrouchedWalkSpeed()
        local threshold = CVarSpeedThreshold:GetInt()
        if threshold < 0 then
            threshold = (run + crouched) / 2
        end
        if run > crouched and mvlength < threshold then return end
        if run < crouched and (mvlength < run - 1 or mvlength > threshold) then return end
        -- local runspeed = math_max(ply:GetVelocity():Length(), mvlength, run) * 1.5
		local runspeed = math_max(mvlength, run) * SLIDE_SPEED_BOOST
        local dir = mvvelocity:GetNormalized()
        if SERVER then ply:SetNWBool("SlidingAbilityIsSliding", true) end
        pr.Set("IsSliding", true)
        pr.Set("SlidingStartTime", CT)
        pr.Set("SlidingCurrentVelocity", dir * runspeed)
        pr.Set("SlidingMaxSpeed", runspeed * 5)
        pr.EmitSound(ply:GetPos(), "SlidingAbility.ImpactSoft")
        pr.EmitSound(ply, "SlidingAbility.ScrapeRough")

        if SLIDE_VIEWPUNCH != 0 then
			local viewDir = ply:GetAimVector()
			viewDir.z = 0
			dir.z = 0
			local lr = (viewDir.x * dir.y) - (viewDir.y * dir.x)
			if lr > 0.08 then
				ply:ViewPunch(angViewpunch * SLIDE_VIEWPUNCH)
			elseif lr < -0.08 then
				ply:ViewPunch(-angViewpunch * SLIDE_VIEWPUNCH)
			end
        end
    end)
end)

local function SlidingFootstep(ply)
    return IsSliding(ply) or nil
end

if DSteps then
    local fsname = "zzzzzz_dstep_main"
    local esname = "zzzzz_dsteps_maskfootstep"
    local hooks = hook.GetTable()
    local DStepsHook = hooks.PlayerFootstep[fsname]
    local EmitSoundHook = hooks.EntityEmitSound[esname]
    if DStepsHook then
        MODULE:Hook("PlayerFootstep", fsname, function(...)
            if SlidingFootstep(...) then return true end
            return DStepsHook(...)
        end)
    end
    if EmitSoundHook then
        MODULE:Hook("EntityEmitSound", esname, function(data, ...)
            local ply = data.Entity
            if not (IsValid(ply) and ply:IsPlayer()) then
                return EmitSoundHook(data, ...)
            end

            if IsSliding(ply) then
                return
            end

            return EmitSoundHook(data, ...)
        end)
    end
else
    MODULE:Hook("PlayerFootstep", "SlidingAbility_SlidingSound", SlidingFootstep)
end

local function AddonCompat()
    local hooks = hook.GetTable()
    if not hooks or not istable(hooks) then return end

    -- Alternate Running Animation (Workshop ID: 1104562150)
    local calcMainActivity = hooks.CalcMainActivity
    if calcMainActivity and istable(calcMainActivity) and calcMainActivity.BaseAnimations and isfunction(calcMainActivity.BaseAnimations) then
        local orig = calcMainActivity.BaseAnimations

        -- Чужой хук снимается (и вернется при отключении модуля) и вызывается из нашей обертки
        MODULE:SuppressHook("CalcMainActivity", "BaseAnimations")
        MODULE:Hook("CalcMainActivity", "SlidingAbility_BaseAnimationsCompat", function(ply, ...)
            if not IsValid(ply) then return end
            if IsSliding(ply) then return end
            return orig(ply, ...)
        end)
    end

    -- IK Foot (Workshop ID: 1605334558)
    local postPlayerDraw = hooks.PostPlayerDraw
    if postPlayerDraw and istable(postPlayerDraw) and postPlayerDraw.IKFoot_PostPlayerDraw and isfunction(postPlayerDraw.IKFoot_PostPlayerDraw) then
        local orig = postPlayerDraw.IKFoot_PostPlayerDraw

        MODULE:SuppressHook("PostPlayerDraw", "IKFoot_PostPlayerDraw")
        MODULE:Hook("PostPlayerDraw", "SlidingAbility_IKFootCompat", function(ply, ...)
            if not IsValid(ply) then return end
            if IsSliding(ply) then return end
            return orig(ply, ...)
        end)
    end
end
MODULE:Hook("Initialize", "SlidingAbility_Compatibility", AddonCompat)

MODULE:Hook("CalcMainActivity", "SlidingAbility_SlidingAnimation", function(ply)
    if not IsSliding(ply) then return end
    if GetSlidingActivity(ply) == -1 then return end
    return GetSlidingActivity(ply), -1
end)

local function DoSomethingWithLegs(ply, doSomething, ...)
    for _, addon in ipairs { "g_LegsVer", "EnhancedCamera", "EnhancedCameraTwo", "CLegs" } do
        local leg = nil
        if not _G[addon] then continue end
        if addon == "g_LegsVer" or addon == "CLegs" then
            leg = GetPlayerLegs()
        else
            leg = _G[addon].entity
        end
        if not IsValid(leg) then continue end
        doSomething(ply, leg, ...)
    end
end

-- Workaround!!!  Revive Mod disables the sliding animation so we disable it
local ReviveModUpdateAnimation
MODULE:Hook("InitPostEntity", "SlidingAbility_ReviveModCompatibility", function()
    local updateHooks = hook.GetTable().UpdateAnimation
    ReviveModUpdateAnimation = updateHooks and updateHooks.BleedOutAnims
    if ReviveModUpdateAnimation then MODULE:SuppressHook("UpdateAnimation", "BleedOutAnims") end
end)

MODULE:Hook("UpdateAnimation", "SlidingAbility_SlidingAimPoseParameters", function(ply, velocity, maxSeqGroundSpeed)
    if ReviveModUpdateAnimation and ply:IsBleedOut() then
        ReviveModUpdateAnimation(ply, velocity, maxSeqGroundSpeed)

        return
    end
	
    if not IsSliding(ply) then
        if ply.SlidingAbility_SlidingReset then
            ply.SlidingAbility_SlidingReset = nil
            DoSomethingWithLegs(ply, ManipulateBones, angBase, true)
			ply:ManipulateBonePosition(0, vecBase)
        end

        return
    end

    local pppitch = ply:LookupPoseParameter("aim_pitch")
    local ppyaw = ply:LookupPoseParameter("aim_yaw")
    if pppitch >= 0 and ppyaw >= 0 then
        local b = ply:GetManipulateBoneAngles(0).roll
        local p = ply:GetPoseParameter("aim_pitch") -- degrees in server, 0-1 in client
        local y = ply:GetPoseParameter("aim_yaw")
        if CLIENT then
            p = Lerp(p, ply:GetPoseParameterRange(pppitch))
            y = Lerp(y, ply:GetPoseParameterRange(ppyaw))
        end

        p = p - b

        local a = ply:GetSequenceActivity(ply:GetSequence())
        local la = ply:GetSequenceActivity(ply:GetLayerSequence(0))
        if a == ply:GetSequenceActivity(ply:LookupSequence(ACT_HL2MP_SIT_DUEL)) and la ~= ACT_HL2MP_GESTURE_RELOAD_DUEL then
            p = p - 45
            ply:SetPoseParameter("aim_yaw", ply:GetPoseParameterRange(ppyaw))
        elseif a == ply:GetSequenceActivity(ply:LookupSequence(ACT_HL2MP_SIT_CAMERA)) then
            y = y + 20
            ply:SetPoseParameter("aim_yaw", y)
        end

        ply:SetPoseParameter("aim_pitch", p)
    end

    if SERVER then return end

    if ply ~= LocalPlayer() then return end
    ply.SlidingAbility_SlidingReset = true
    DoSomethingWithLegs(ply, function(p, l, ...)
        local dp = ply:GetPos() - (l.SlidingAbility_SlidingPreviousPosition or ply:GetPos())
        local dp2d = Vector(dp.x, dp.y)
        dp:Normalize()
        dp2d:Normalize()
        local dot = ply:GetForward():Dot(dp2d)
        local angle = math.deg(math.asin(dp.z)) * dot + SLIDE_TILT_DEG
        l.SlidingAbility_SlidingPreviousPosition = ply:GetPos()
        SetSlidingPose(p, l, angle)
    end)
end)

if SERVER then
    local vecInitSpawn = Vector(1, 1, 1)
    MODULE:Hook("PlayerInitialSpawn", "SlidingAbility_PreventBreakingTPSModelOnChangelevel", function(ply, transition)
        if not transition then return end
        timer.Simple(1, function()
            for i = 0, ply:GetBoneCount() - 1 do
                ply:ManipulateBoneScale(i, vecInitSpawn)
                ply:ManipulateBoneAngles(i, angBase)
                ply:ManipulateBonePosition(i, vecBase)
            end
        end)
    end)

    return
end

MODULE:Receive("SlidingAbility_BroadcastBoneManipulation", function()
    local ply = net.ReadEntity()
    if not IsValid(ply) or LocalPlayer() == ply then return end
    local bone = net.ReadUInt(8)
    local ang = net.ReadAngle()
    ply:ManipulateBoneAngles(bone, ang, false)
end)

MODULE:Hook("CalcViewModelView", "SlidingAbility_SlidingViewModelTilt", function(w, vm, op, oa, p, a)
	if SLIDE_VIEWMODEL_POS == 0 and SLIDE_VIEWMODEL_ANG == 0 then return end
    local wTbl = w:GetTable()
    if wTbl.SuppressSlidingViewModelTilt then return end -- For the future addons which are compatible with this addon
    if wTbl.Base == "mg_base" and isfunction(wTbl.GetToggleAim) and w:GetToggleAim() then return end
    if wTbl.ArcCW and w:GetState() == ArcCW.STATE_SIGHTS then return end
	if wTbl.IsTFAWeapon and w:GetIronSights() then return end

    local ply = w:GetOwner()
    if not (IsValid(ply) and ply:IsPlayer()) then return end

    local wp, wa = p, a
    if isfunction(wTbl.CalcViewModelView) then wp, wa = w:CalcViewModelView(vm, op, oa, p, a) end
    if not (wp and wa) then wp, wa = p, a end

    local isSliding = IsSliding(ply)
    local slidingStartTime = predicted.Get(ply, "SlidingAbility", "SlidingStartTime", 0)
    local slidingEndTime = predicted.Get(ply, "SlidingAbility", "SlidingEndTime", 0)
    local t0 = isSliding and slidingStartTime or slidingEndTime
    if not IsFirstTimePredicted() then t0 = t0 - ply:Ping() / 1000 end
    local timeFraction = math_Clamp(math_TimeFraction(t0, t0 + SLIDE_ANIM_TRANSITION_TIME, CurTime()), 0, 1)
    if not isSliding then
        local maxFraction = math_Clamp((slidingEndTime - slidingStartTime) / SLIDE_ANIM_TRANSITION_TIME, 0, 1)
        timeFraction = math_Clamp(maxFraction - timeFraction, 0, 1)
    end
    if timeFraction == 0 then return end
    wp:Add(LerpVector(timeFraction, vecBase, LocalToWorld(vecViewModel * SLIDE_VIEWMODEL_POS, angBase, vecBase, wa)))
    wa:RotateAroundAxis(wa:Forward(), Lerp(timeFraction, 0, -SLIDE_VIEWMODEL_ANG))
end)
