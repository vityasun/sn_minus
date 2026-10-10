-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- sn_animcam_tablet: shared.lua
-- Shared SWEP definition for the animatronic surveillance tablet.
-- Uses assets from ca_camera system (models/vondaram/c_tablet.mdl, w_tablet.mdl, tablet/ekran texture).

local math = math
local game = game

SWEP.Category       = "SN Tasks"
SWEP.PrintName      = "Animatronic Tablet"

SWEP.ViewModel      = "models/vondaram/c_tablet.mdl"
SWEP.WorldModel     = "models/vondaram/w_tablet.mdl"

SWEP.UseHands       = true
SWEP.ViewModelFOV   = 90
SWEP.Spawnable      = false  -- выдаётся только через команду / автогив

SWEP.Slot           = 5
SWEP.SlotPos        = 7
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair  = false

SWEP.Weight             = 5
SWEP.AutoSwitchTo       = false
SWEP.AutoSwitchFrom     = false

-- Уникальный маркер вместо жесткой привязки к названию папки
SWEP.IsAnimatronicTablet = true

SWEP.Primary = {
    ClipSize    = -1,
    DefaultClip = -1,
    Automatic   = false,
    Ammo        = "none"
}

SWEP.Secondary = {
    ClipSize    = -1,
    DefaultClip = -1,
    Automatic   = false,
    Ammo        = "none"
}

util.PrecacheModel(SWEP.ViewModel)
util.PrecacheModel(SWEP.WorldModel)

-- Константы зума
local DEFAULT_FOV   = 1
local MAX_FOV       = DEFAULT_FOV
local MIN_FOV       = 0.7
local FOV_STEP      = 1

local ANG_ZERO = Angle(0, 0, 0)

-- ============================================================
-- Глобальная функция индексации
-- ============================================================
function SlashMoon.Tasks.SolveAnimIndex(id, list)
    local n = #list
    if n == 0 then return 1 end
    if id > n then return 1 end
    if id < 1 then return n end
    return id
end

if CLIENT then
    SWEP.ZoomStatus = false
    SWEP.CurFOV     = DEFAULT_FOV
    SWEP.GoalFOV    = DEFAULT_FOV
end

-- ============================================================
-- Вспомогательная функция: собрать список живых аниматроников
-- ============================================================
function SlashMoon.Tasks.GetAnimatronics()
    local list = {}
    for _, ply in player.Iterator() do
        if IsValid(ply) and SlashMoon.Tasks.Game.IsAnimatronic(ply) and ply:Alive() then
            table.insert(list, ply)
        end
    end
    table.sort(list, function(a, b) return a:UserID() < b:UserID() end)
    return list
end

-- ============================================================
-- SetupDataTables
-- ============================================================
function SWEP:SetupDataTables()
    self:NetworkVar("Int",   0, "CurAnim")
    self:NetworkVar("Float", 0, "IdleTimer")
    self:NetworkVar("Bool",  0, "IsIdle")
    self:NetworkVar("Float", 1, "HolsterTimer")
    self:NetworkVar("Bool",  1, "IsHolstering")
    self:NetworkVar("Entity",1, "HolsterEntity")
    self:NetworkVar("Bool",  3, "IsFullView")
    self:NetworkVar("Float", 5, "ReloadTimer")
    self:NetworkVar("Float", 6, "Battery")
    self:NetworkVar("Bool",  6, "ScreenOn")

    if SERVER then
        self:SetCurAnim(1)
        self:SetIsHolstering(false)
        self:SetHolsterTimer(math.huge)
        self:SetIsFullView(false)
        self:SetHolsterEntity(NULL)
        self:SetBattery(1.0)
        self:SetScreenOn(false) -- Экран выключен при спавне
    end

    self:NetworkVarNotify("CurAnim",   self.OnAnimSwitch)
    self:NetworkVarNotify("ScreenOn",  self.OnScreenToggle)
end

function SWEP:Initialize()
    self:SetHoldType("pistol")
    self.m_bInitialized = true
end

function SWEP:OnAnimSwitch(name, old, new)
    local ow = self:GetOwner()
    if not IsValid(ow) then return end
    hook.Call("SN_TabletCamSwitched", nil, self, old, new)
end

function SWEP:OnScreenToggle(name, old, new)
    local ow = self:GetOwner()
    if not IsValid(ow) then return end
    hook.Call("SN_TabletScreenToggled", nil, self, new)
end

-- ============================================================
-- Deploy / Holster
-- ============================================================
function SWEP:deployInternal()
    self:SetHoldType("pistol")
    self:SendWeaponAnim(ACT_VM_DEPLOY)
    if IsFirstTimePredicted() then
        self:EmitSound("ca_tablet/equip.wav", 75, 100, 0.25)
    end
    self:SetIsIdle(false)

    local vm = self:GetOwner():GetViewModel()
    self:SetNextPrimaryFire(CurTime()   + vm:SequenceDuration() * 0.5)
    self:SetNextSecondaryFire(CurTime() + vm:SequenceDuration() * 0.5)
    self:SetIdleTimer(CurTime()         + vm:SequenceDuration() * 0.75)

    self:SetHolsterTimer(math.huge)
    self:SetIsFullView(false)
    self:SetHolsterEntity(NULL)

    if SERVER then
        self:SetIsHolstering(false)
    else
        if IsFirstTimePredicted() then
            self.CurFOV     = DEFAULT_FOV
            self.GoalFOV    = DEFAULT_FOV
            self.ZoomStatus = false
        end
    end

    if SERVER or (CLIENT and (IsFirstTimePredicted() or game.SinglePlayer())) then
        hook.Call("SN_TabletDeployed", nil, self)
    end
end

function SWEP:Deploy()
    self:deployInternal()
    return true
end

function SWEP:Holster(wep)
    if (not IsValid(wep) and not self:GetIsHolstering()) or
       (IsValid(wep) and wep:GetClass() == self:GetClass()) then
        return true
    end

    if self:GetHolsterTimer() <= CurTime() then
        self:SetHolsterTimer(math.huge)
        self:SetHolsterEntity(NULL)
        return true
    end

    if not IsValid(wep) then return end

    if self:GetIsHolstering() then
        self:SetHolsterEntity(wep)
        return
    end

    if self:GetIsFullView() then
        self:SendWeaponAnim(ACT_VM_HOLSTER_EMPTY)
    else
        self:SendWeaponAnim(ACT_VM_HOLSTER)
    end

    if IsFirstTimePredicted() then
        self:EmitSound("ca_tablet/holster.wav", 75, 100, 0.8)
    end

    self:SetHoldType("normal")
    self:SetHolsterEntity(wep)
    self:SetIsHolstering(true)
    self:SetHolsterTimer(CurTime() + self:GetOwner():GetViewModel():SequenceDuration())

    return false
end

-- ============================================================
-- Think
-- ============================================================
function SWEP:Think()
    if not self.m_bInitialized then self:Initialize() end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if not self:GetIsIdle() and self:GetIdleTimer() <= CurTime()
       and not self:GetIsHolstering() and not self:GetIsFullView() then
        self:SendWeaponAnim(ACT_VM_IDLE)
        self:SetIsIdle(true)
    end

    if SERVER and self:GetScreenOn() then
        -- Читаем drain_rate из MapConfig (приоритет) или ConVar (фоллбэк)
        local drainRate = 0
        if SlashMoon.Tasks and SlashMoon.Tasks.MapConfig and SlashMoon.Tasks.MapConfig.animcam then
            drainRate = tonumber(SlashMoon.Tasks.MapConfig.animcam.drain_rate) or 0
        end
        if drainRate <= 0 then
            local cv = GetConVar("sn_animcam_drain_rate")
            drainRate = cv and cv:GetFloat() or 0.00333
        end

        if drainRate > 0 then
            local now = CurTime()
            local lastDrain = self.SN_LastBatteryDrain or now
            if now - lastDrain < 0.2 then return end
            self.SN_LastBatteryDrain = now
            local newBattery = math.max(0, self:GetBattery() - drainRate * (now - lastDrain))
            self:SetBattery(newBattery)

            if newBattery <= 0 then
                self:SetScreenOn(false)
            end
        else
            self.SN_LastBatteryDrain = CurTime()
        end
    elseif SERVER then
        self.SN_LastBatteryDrain = CurTime()
    end

    if CLIENT then
        self:ZoomCalcInternal()
    end
end

-- ============================================================
-- Атаки: Переключение камер (Только когда экран горит)
-- ============================================================
function SWEP:attackInternal()
    if self:GetIsFullView() then
        self:SendWeaponAnim(ACT_VM_PRIMARYATTACK_2)
        if IsFirstTimePredicted() then self:EmitSound("ca_tablet/toggle.ogg", 75, 100, 0.2) end
    else
        self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
        if IsFirstTimePredicted() then self:EmitSound("ca_tablet/toggle.ogg", 75, 100, 0.125) end
    end

    self:SetIsIdle(false)
    local vm = self:GetOwner():GetViewModel()
    self:SetIdleTimer(CurTime() + vm:SequenceDuration())
    self:SetNextPrimaryFire(CurTime()   + vm:SequenceDuration() * 0.1)
    self:SetNextSecondaryFire(CurTime() + vm:SequenceDuration() * 0.1)
end

function SWEP:PrimaryAttack()
    if self:GetIsHolstering() then return end
    if not self:GetScreenOn() then return end

    if SERVER then
        local list = SlashMoon.Tasks.GetAnimatronics()
        local next = SlashMoon.Tasks.SolveAnimIndex(self:GetCurAnim() + 1, list)
        self:SetCurAnim(next)
    end

    self:attackInternal()
end

function SWEP:SecondaryAttack()
    if self:GetIsHolstering() then return end
    if not self:GetScreenOn() then return end

    if SERVER then
        local list = SlashMoon.Tasks.GetAnimatronics()
        local next = SlashMoon.Tasks.SolveAnimIndex(self:GetCurAnim() - 1, list)
        self:SetCurAnim(next)
    end

    self:attackInternal()
end

-- ============================================================
-- RELOAD (Синхронная)
-- Shift+R -> Включение/Выключение экрана
-- R       -> Приближение планшета (Full View)
-- ============================================================
function SWEP:Reload()
    if self:GetIsHolstering() then return end
    if self:GetReloadTimer() >= CurTime() then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- IN_SPEED автоматически отслеживает зажатый Shift
    if owner:KeyDown(IN_SPEED) then
        if SERVER then
            local screenOn = self:GetScreenOn()
            if not screenOn and self:GetBattery() <= 0 then return end

            self:SetScreenOn(not screenOn)
            self:EmitSound("ca_tablet/toggle.ogg", 75, 100, 0.15)
        end
        self:SetReloadTimer(CurTime() + 0.4) -- Защита от спама кнопкой
    else
        self:SetIsFullView(not self:GetIsFullView())

        if self:GetIsFullView() then
            self:SendWeaponAnim(ACT_LOOKBACK_LEFT)
            self:SetHoldType("camera")
        else
            self:SendWeaponAnim(ACT_LOOKBACK_RIGHT)
            self:SetHoldType("pistol")
        end

        self:SetIsIdle(false)

        local vm = owner:GetViewModel()
        if IsValid(vm) then
            self:SetIdleTimer(CurTime()         + vm:SequenceDuration())
            self:SetNextPrimaryFire(CurTime()   + vm:SequenceDuration() * 0.4)
            self:SetNextSecondaryFire(CurTime() + vm:SequenceDuration() * 0.4)
            self:SetReloadTimer(CurTime()       + vm:SequenceDuration() * 0.4)
        end
    end
end

-- Хук авто-холстера оружия
MODULE:Hook("StartCommand", "SN_TabletHolsterWorkout", function(ply, cmd)
    local curWep = ply:GetActiveWeapon()
    if not IsValid(curWep) or not curWep.IsAnimatronicTablet or (CLIENT and curWep:GetOwner() ~= ply) or not curWep.m_bInitialized then return end

    if curWep:GetIsHolstering() and curWep:GetHolsterTimer() <= CurTime() then
        local nextWep = curWep:GetHolsterEntity()
        if IsValid(nextWep) and ply:HasWeapon(nextWep:GetClass()) then
            cmd:SelectWeapon(nextWep)
        else
            curWep:deployInternal()
        end
    end
end)

-- ============================================================
-- CLIENT BLOCK
-- ============================================================
if CLIENT then

    function SWEP:ZoomCalcInternal()
        local wheelDelta = (self:GetIsFullView() and self.ZoomStatus and not self:GetIsHolstering()) and -1 or 1
        local newFOV     = math.Clamp(self.GoalFOV + FOV_STEP * wheelDelta, MIN_FOV, MAX_FOV)
        self.CurFOV      = Lerp(FrameTime() * 7.5, self.CurFOV, newFOV)
        self.GoalFOV     = newFOV
        return self.CurFOV
    end

    function SWEP:CalcView(ply, pos, ang, fov)
        local offAng = self.StoredVMAngles or ANG_ZERO
        ang = ang + offAng
        fov = fov * self:ZoomCalcInternal()
        return pos, ang, fov
    end

    function SWEP:ViewModelDrawn(vm)
        local headAtt = vm:LookupAttachment("anim_view")
        if headAtt <= 0 then self.StoredVMAngles = ANG_ZERO return end
        local headAng = vm:GetAttachment(headAtt).Ang
        headAng:RotateAroundAxis(headAng:Up(), 90)
        headAng = vm:WorldToLocalAngles(headAng)
        self.StoredVMAngles = headAng
    end

    MODULE:Hook("PlayerBindPress", "SN_TabletCamBinds", function(ply, bind, pressed)
        if bind ~= "+zoom" then return end
        local curWep = ply:GetActiveWeapon()
        if not IsValid(curWep) or not curWep.IsAnimatronicTablet then return end
        curWep.ZoomStatus = pressed
        return true
    end)

end

-- ============================================================
-- SERVER BLOCK
-- ============================================================
if SERVER then

    CreateConVar(
        "sn_animcam_drain_rate", "0.00333",
        { FCVAR_ARCHIVE, FCVAR_NOTIFY },
        "Battery drain rate per second (fallback when MapConfig not set)"
    )

    MODULE:Hook("PlayerCanPickupWeapon", "SN_TabletDoublePickup", function(ply, weapon)
        if IsValid(weapon) and weapon.IsAnimatronicTablet and ply:HasWeapon(weapon:GetClass()) then
            return false
        end
    end)

    function SWEP:CanBePickedUpByNPCs() return false end
end

-- ============================================================
-- HUD
-- ============================================================
if CLIENT then
    function SWEP:DrawHUD()
        local x = ScrW() - 20
        local y = ScrH() - 20

        local spacing = 25
        local font = "Trebuchet24"
        local textColor = Color(255, 0, 0, 255)
        local outlineColor = Color(0, 0, 0, 255)

        draw.SimpleTextOutlined(SlashMoon.Tasks.Lang("sn.animcam.toggle"), font, x, y, textColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, outlineColor)
        draw.SimpleTextOutlined(SlashMoon.Tasks.Lang("sn.animcam.switch"), font, x, y - spacing, textColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, outlineColor)
        draw.SimpleTextOutlined(SlashMoon.Tasks.Lang("sn.animcam.zoom"), font, x, y - spacing * 2, textColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, outlineColor)
    end
end
