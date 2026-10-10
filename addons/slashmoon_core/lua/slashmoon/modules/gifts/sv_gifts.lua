-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("gifts")

-- ========================================================
-- Подарки с предметами инвентаря (замена подарков гейммода)
-- ========================================================

SlashMoon.Gifts = SlashMoon.Gifts or {}
util.AddNetworkString("SN_Gifts_NegativeEffect")
SlashMoon.Gifts.ForeignNegativeChance = 0.50
SlashMoon.Gifts.PositiveEffects = SlashMoon.Gifts.PositiveEffects or {
    --{ id = "flashlight", chance = 14, item = "weapon_flashlight" },
    --{ id = "multitool", chance = 10, item = "weapon_multitool" },
    --{ id = "medkit_item", chance = 12, item = "weapon_fh_medkit" },
    { id = "medkit", chance = 12 },
    { id = "animcam", chance = 6, item = "sn_animcam_tablet" },
    { id = "invisibility", chance = 6 },
    { id = "gravity_gun", chance = 4 },
    { id = "animatronics_visibility", chance = 10 },
    { id = "defibrilator", chance = 5 },
    { id = "bananas", chance = 10 },
    { id = "adrenaline", chance = 8 },
    { id = "fanta", chance = 5 },
    { id = "killer_mask", chance = 1 },
}

SlashMoon.Gifts.NegativeRewards = SlashMoon.Gifts.NegativeRewards or {
    { id = "piano", chance = 18 },
    { id = "animatronics_alert", chance = 12 },
    { id = "reduce_step", chance = 10 },
    { id = "thinkfast", chance = 10 },
    { id = "fov_buff", chance = 10 },
    { id = "sound_dsp", chance = 10 },
    { id = "vanish", chance = 5 },
    { id = "bearling_attack", chance = 8 },
}

local activeGifts = {}

function SlashMoon.Gifts.GetInterval()
    return math.Clamp(MODULE:GetOption("interval"), 15, 600)
end

function SlashMoon.Gifts.ClearGift(gift)
    for owner, activeGift in pairs(activeGifts) do
        if activeGift == gift then activeGifts[owner] = nil end
    end
end

local function HasInventoryItem(ply, itemClass)
    for _, item in ipairs(ply.SN_Backpack or {}) do
        if string.Split(item, ":")[1] == itemClass then return true end
    end
    for _, item in pairs(ply.SN_Hotbar or {}) do
        if string.Split(item, ":")[1] == itemClass then return true end
    end
    return ply:HasWeapon(itemClass)
end

function SlashMoon.Gifts.AddPositiveItem(itemClass, chance, condition)
    if not isstring(itemClass) or itemClass == "" then return false end
    if not SlashMoon.Tasks or not SlashMoon.Tasks.Items or not SlashMoon.Tasks.Items[itemClass] then return false end
    if not isnumber(chance) or chance <= 0 then return false end

    SlashMoon.Gifts.PositiveEffects[#SlashMoon.Gifts.PositiveEffects + 1] = {
        id = "item_" .. itemClass,
        chance = math.Clamp(math.floor(chance), 1, 100),
        item = itemClass,
        condition = isfunction(condition) and condition or nil,
    }
    return true
end

SlashMoon.Gifts.AddReward = SlashMoon.Gifts.AddPositiveItem

local function PickEffect(ply, effects)
    local available = {}
    for _, effect in ipairs(effects) do
        local valid = not effect.condition or effect.condition(ply)
        if effect.item then
            local item = SlashMoon.Tasks.Items and SlashMoon.Tasks.Items[effect.item]
            valid = valid and item and (not item.unique or not HasInventoryItem(ply, effect.item))
        end
        if valid then
            for _ = 1, math.Clamp(math.floor(tonumber(effect.chance) or 1), 1, 100) do
                available[#available + 1] = effect
            end
        end
    end
    return #available > 0 and available[math.random(#available)] or nil
end

function SlashMoon.Gifts.PickNegative(ply)
    return PickEffect(ply, SlashMoon.Gifts.NegativeRewards)
end

local function SpawnGiftFor(ply)
    if not IsValid(ply) or not ply:Alive() or not ply:IsSurvivor() then return end
    if IsValid(activeGifts[ply]) then return end

    local reward = PickEffect(ply, SlashMoon.Gifts.PositiveEffects)
    if not reward then return end

    local gift = ents.Create("sn_inventory_gift")
    if not IsValid(gift) then return end
    gift:SetPos(ply:GetPos() + Vector(0, 0, 12))
    gift:SetOwner(ply)
    gift.SN_Reward = reward
    gift:Spawn()
    gift:Activate()
    gift:EmitSound("items/battery_pickup.wav")
    activeGifts[ply] = gift
end

function SlashMoon.Gifts.GivePositive(ply, itemClass)
    if not IsValid(ply) or not itemClass or not SlashMoon.Tasks or not SlashMoon.Tasks.GiveItem then return false end
    return SlashMoon.Tasks.GiveItem(ply, itemClass) == true
end

local function GiveWeapon(ply, class)
    if not IsValid(ply) then return false end
    if SlashMoon.Tasks and SlashMoon.Tasks.GiveItem and SlashMoon.Tasks.Items and SlashMoon.Tasks.Items[class] then
        return SlashMoon.Tasks.GiveItem(ply, class) == true
    end
    if not ply:HasWeapon(class) then
        ply:Give(class)
        local given = ply:HasWeapon(class)
        if given then
            net.Start("SN_Inv_ItemReceived")
                net.WriteString(class)
            net.Send(ply)
        end
        return given
    end
    return false
end

function SlashMoon.Gifts.ApplyPositive(ply, effect)
    if istable(effect) then
        if effect.item then return SlashMoon.Gifts.GivePositive(ply, effect.item) end
        effect = effect.id
    end
    if effect == "medkit" then
        if ply:HasWeapon("weapon_fh_medkit") then
            local weapon = ply:GetWeapon("weapon_fh_medkit")
            if IsValid(weapon) then weapon:SetClip1(weapon:Clip1() + 25) end
            net.Start("SN_Inv_ItemReceived")
                net.WriteString("weapon_fh_medkit")
            net.Send(ply)
            return true
        end
        return GiveWeapon(ply, "weapon_fh_medkit")
    elseif effect == "invisibility" then return GiveWeapon(ply, "weapon_mask")
    elseif effect == "gravity_gun" then return GiveWeapon(ply, "weapon_physcannon")
    elseif effect == "defibrilator" then return GiveWeapon(ply, "weapon_defibrillator")
    elseif effect == "adrenaline" then return GiveWeapon(ply, "weapon_adrenaline_fix")
    elseif effect == "fanta" then return GiveWeapon(ply, "weapon_fanta")
    elseif effect == "killer_mask" then return GiveWeapon(ply, "weapon_killmask")
    elseif effect == "bananas" then
        local given = GiveWeapon(ply, "weapon_banana")
        if given then ply:GiveAmmo(4, "ammo_banana", true) end
        return given
    elseif effect == "animatronics_visibility" then
        ply:SetNWBool("AnimVisibilityFH", true)
        MODULE:Timer("SN_Gifts_AnimVisibility_" .. ply:EntIndex(), 35, 1, function()
            if IsValid(ply) then ply:SetNWBool("AnimVisibilityFH", false) end
        end)
        net.Start("fh_hl_animatronics") net.Send(ply)
        return true
    end
    return SlashMoon.Gifts.GivePositive(ply, effect)
end

function SlashMoon.Gifts.ApplyNegative(ply, effect)
    if istable(effect) then effect = effect.id end
    if not isstring(effect) then return false end
    if effect == "piano" then
        local piano = ents.Create("prop_physics")
        if not IsValid(piano) then return false end
        piano:SetModel("models/props/moethe_concert_grand_piano/moethe_concert_grand_piano.mdl")
        piano:SetModelScale(1.5, 0)
        piano:SetPos(ply:GetPos() + Vector(100, 0, 400))
        piano:Spawn()
        piano:Activate()
        local phys = piano:GetPhysicsObject()
        if IsValid(phys) then phys:SetVelocity(Vector(0, 0, -1200)) end
        timer.Simple(8, function() if IsValid(piano) then piano:Remove() end end)
        net.Start("SN_Gifts_NegativeEffect")
            net.WriteString("sn.gifts.negative.piano")
        net.Send(ply)
        return true
    end
    if effect == "animatronics_alert" then
        net.Start("fh_hl_badkid") net.WriteEntity(ply) net.Broadcast()
        for _, anim in ipairs(player.GetAll()) do
            if IsValid(anim) and anim:IsAnimatronic() and highlight and highlight.Add then highlight.Add(anim, ply) end
        end
    elseif effect == "reduce_step" then
        ply:SetStepSize(0)
        timer.Simple(15, function() if IsValid(ply) then ply:SetStepSize(18) end end)
    elseif effect == "thinkfast" then
        net.Start("fh_net_thinkfast") net.Send(ply)
    elseif effect == "fov_buff" then
        ply:SetFOV(30, 1) ply:SetCanZoom(false) ply:StopZooming()
        timer.Simple(30, function() if IsValid(ply) then ply:SetFOV(0, 1) ply:SetCanZoom(true) end end)
    elseif effect == "sound_dsp" then
        ply:SetDSP(31, false)
        timer.Simple(30, function() if IsValid(ply) then ply:SetDSP(1, false) end end)
    elseif effect == "vanish" then
        ply:KillSilent()
    elseif effect == "bearling_attack" then
        local bears = {}
        for _ = 1, 5 do
            local bear = ents.Create("bearling")
            if IsValid(bear) then bear:SetPos(ply:GetPos()) bear:Spawn() bear:Activate() bear:SetTarget(ply) bears[#bears + 1] = bear end
        end
        timer.Simple(60, function() for _, bear in ipairs(bears) do if IsValid(bear) then bear:Remove() end end end)
    else
        return false
    end
    net.Start("SN_Gifts_NegativeEffect") net.WriteString("sn.gifts.negative." .. effect) net.Send(ply)
    return true
end

function SlashMoon.Gifts.SpawnRoundGifts()
    for _, ply in ipairs(player.GetAll()) do SpawnGiftFor(ply) end
end

-- The gamemode uses this hook both from its normal RandomGifts timer and from
-- the existing admin-panel "Spawn gifts" action. Spawn our gifts here so both
-- paths use the inventory-aware implementation without editing gamemode code.
MODULE:Hook("fh_prespawngifts", "SN_Gifts_ReplaceGamemodeGifts", function()
    SlashMoon.Gifts.SpawnRoundGifts()

    -- RandomGifts is also used by the original admin-panel checkbox. Keep its
    -- scheduling intact while applying our server-configurable interval.
    if timer.Exists("RandomGifts") then
        timer.Adjust("RandomGifts", SlashMoon.Gifts.GetInterval())
    end
    return false
end)

MODULE:Hook("fh_poststartgame", "SN_Gifts_StopLegacyTimer", function()
    MODULE:RemoveTimer("SN_Gifts_Timer")
end)

MODULE:Hook("fh_prestartgame", "SN_Gifts_StopTimer", function()
    MODULE:RemoveTimer("SN_Gifts_Timer")
    for _, gift in pairs(activeGifts) do if IsValid(gift) then gift:Remove() end end
    table.Empty(activeGifts)
end)

MODULE:Hook("fh_postendgame", "SN_Gifts_EndRound", function()
    MODULE:RemoveTimer("SN_Gifts_Timer")
    for _, gift in pairs(activeGifts) do if IsValid(gift) then gift:Remove() end end
    table.Empty(activeGifts)
end)

MODULE:Hook("EntityRemoved", "SN_Gifts_ClearOwnership", function(ent)
    if ent:GetClass() ~= "sn_inventory_gift" then return end
    SlashMoon.Gifts.ClearGift(ent)
end)
