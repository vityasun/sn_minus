-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Механика Инвентаря и Подбора (Shared + Localized)
-- ========================================================
SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Config = SlashMoon.Tasks.Config or {}

SlashMoon.Tasks.Config.MaxHotbar = 3
SlashMoon.Tasks.Config.AlwaysAllowed = {
    ["sn_empty_hands"] = true,
    ["weapon_empty_hands"] = true,
    ["weapon_physgun"] = true,
    ["gmod_tool"] = true,
    ["gmod_camera"] = true,
    ["weapon_killer_axe"] = true
    ,["sn_corpse_scanner"] = true
    ,["sn_investigation_tablet"] = true
}

function SlashMoon.Tasks.IsMaterial(class)
    return string.StartWith(class, "mat_")
end

-- ── Внедрение в GMod: Перехват ply:Give() ─────────────────────────────
local plyMeta = FindMetaTable("Player")
if not plyMeta.SN_OldGive then
    plyMeta.SN_OldGive = plyMeta.Give
end

function plyMeta:Give(class, bNoAmmo)
    self.SN_AllowPickup = true
    local wep = self:SN_OldGive(class, bNoAmmo)
    self.SN_AllowPickup = false
    return wep
end

-- ── Блокировка подбора ногами ─────────────────────────────────────────
MODULE:Hook("PlayerCanPickupWeapon", "SN_Inv_BlockAutoPickup", function(ply, wep)
    if not IsValid(ply) or not IsValid(wep) then return false end

    if ply:GetNW2Bool("KillerMaskEquiped", false) then
        local class = wep:GetClass()
        if class == "weapon_killer_axe" or class == "weapon_killmask" then return true end
        return false
    end

    if SlashMoon.Tasks.Config.AlwaysAllowed[wep:GetClass()] then return true end
    if not ply.SN_AllowPickup then return false end
    return true
end)

-- ── E-подбор предметов (сервер) ──────────────────────────────────────
if SERVER then
    MODULE:Hook("PlayerButtonDown", "SN_Inv_EPickup", function(ply, key)
        if key ~= KEY_E then return end
        if not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end
        if ply:GetNW2Bool("KillerMaskEquiped", false) then return end

        -- Анти-спам
        if not SlashMoon.Security.CheckRateLimit(ply, "inv_epickup", 0.3) then return end

        local tr = ply:GetEyeTrace()
        local ent = tr.Entity

        if not IsValid(ent) or ply:GetPos():Distance(tr.HitPos) > 120 then return end

        if ent:GetClass() == "sn_item_drop" then
            local class = ent:GetNW2String("ItemClass", "")
            if class ~= "" then
                local added = SlashMoon.Tasks.GiveItem(ply, class, ent.SN_WeaponState)
                if not added then return end
                ent:Remove()
                hook.Run("SN_Item_PickedUp", ply, class)
                ply:EmitSound("items/ammo_pickup.wav")
            end
        elseif ent:IsWeapon() and not SlashMoon.Tasks.Config.AlwaysAllowed[ent:GetClass()] then
            local class = ent:GetClass()
            local added = SlashMoon.Tasks.GiveItem(ply, class)
            if not added then return end
            ent:Remove()
            hook.Run("SN_Item_PickedUp", ply, class)
            ply:EmitSound("items/ammo_pickup.wav")
            local data = SlashMoon.Tasks.GetItemData(class)
            if SERVER then
                SlashMoon.Tasks.SendLocalizedChat(ply, "sn.inv.picked_up", data.nameKey or data.name)
            end
        end
    end)
end

-- ── Обыск трупов и подсказки (клиент) ────────────────────────────────
if CLIENT then
    local searchStart = 0
    local searchEnt = NULL

    MODULE:Hook("Think", "SN_Inv_SearchThink", function()
        local ply = LocalPlayer()
        if not SlashMoon.Tasks.Game.CanLootCorpse(ply) then return end

        local tr = ply:GetEyeTrace()
        local ent = tr.Entity

        local corpse = IsValid(ent) and (ent:GetClass() == "prop_ragdoll" or ent:GetClass() == "prop_physics")
        if corpse and ent:GetNW2Bool("SN_Lootable") and ply:GetPos():Distance(tr.HitPos) <= 120 then
            if input.IsKeyDown(KEY_E) then
                if searchStart == 0 then
                    searchStart = CurTime()
                    searchEnt = ent
                    surface.PlaySound("npc/combine_soldier/gear5.wav")
                end

                if CurTime() - searchStart >= 1.5 then
                    net.Start("SN_Inv_RequestLoot")
                    net.WriteEntity(ent)
                    net.SendToServer()
                    searchStart = 0
                    searchEnt = NULL
                end
            else
                searchStart = 0; searchEnt = NULL
            end
        else
            searchStart = 0; searchEnt = NULL
        end
    end)

    MODULE:Hook("HUDPaint", "SN_Inv_HUD", function()
        local ply = LocalPlayer()
        if not SlashMoon.Tasks.Game.CanLootCorpse(ply) then return end

        -- Прогресс обыска
        if searchStart > 0 and IsValid(searchEnt) then
            local progress = math.Clamp((CurTime() - searchStart) / 1.5, 0, 1)
            local w, h = SlashMoon.UI.Scale(200), SlashMoon.UI.Scale(10)
            local x, y = ScrW() / 2 - w / 2, ScrH() / 2 + SlashMoon.UI.Scale(80)

            surface.SetDrawColor(0, 0, 0, 150)
            surface.DrawRect(x, y, w, h)
            surface.SetDrawColor(SlashMoon.UI.Colors.Theme)
            surface.DrawRect(x, y, w * progress, h)
            surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
            surface.DrawOutlinedRect(x, y, w, h, 1)

            SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.inv.search"), "SlashMoon.Small", ScrW() / 2, y - SlashMoon.UI.Scale(15), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Подсказки подбора
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity

        if IsValid(ent) and ply:GetPos():Distance(tr.HitPos) <= 120 then
            local targetClass = nil

            if ent:GetClass() == "sn_item_drop" then
                targetClass = ent:GetNW2String("ItemClass", "")
            elseif ent:IsWeapon() and not SlashMoon.Tasks.Config.AlwaysAllowed[ent:GetClass()] then
                targetClass = ent:GetClass()
            end

            if targetClass and targetClass ~= "" then
                local data = SlashMoon.Tasks.GetItemData(targetClass)
                local hintText = SlashMoon.Tasks.Lang("sn.inv.pickup_hint", data.name)
                SlashMoon.UI.Draw.TextShadow(hintText, "SlashMoon.Header", ScrW() / 2, ScrH() / 2 + 40, SlashMoon.UI.Colors.Theme, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            elseif (ent:GetClass() == "prop_ragdoll" or ent:GetClass() == "prop_physics") and ent:GetNW2Bool("SN_Lootable") then
                local deadName = ent:GetNW2String("SN_CorpseName", SlashMoon.Tasks.Lang("sn.inv.corpse_unknown"))
                local lootHint = SlashMoon.Tasks.Lang("sn.inv.loot_hint", deadName)
                SlashMoon.UI.Draw.TextShadow(lootHint, "SlashMoon.Header", ScrW() / 2, ScrH() / 2 + 40, Color(255, 200, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end)
end
