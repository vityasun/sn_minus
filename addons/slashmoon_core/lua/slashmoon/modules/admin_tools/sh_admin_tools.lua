-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("admin_tools")

-- ========================================================
-- Админские утилиты: физган при спавне и невидимость в noclip
-- ========================================================

local Admin = SlashMoon.Admin

if SERVER then
    local function SetInvisible(ply, invisible)
        ply:SetNW2Bool("SlashMoon.AdminInvis", invisible)
        ply:SetNoDraw(invisible)
        ply:DrawShadow(not invisible)

        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then wep:SetNoDraw(invisible) end
    end

    MODULE:Hook("PlayerSpawn", "SlashMoon.AdminTools.Physgun", function(ply)
        if not MODULE:GetOption("give_physgun") then return end
        if not Admin.HasPermission(ply, "slashmoon_physgun") then return end

        timer.Simple(0.3, function()
            if IsValid(ply) and ply:Alive() and not ply:HasWeapon("weapon_physgun") then
                ply:Give("weapon_physgun")
            end
        end)
    end)

    MODULE:Timer("SlashMoon.AdminTools.InvisCheck", 0.2, 0, function()
        local enabled = MODULE:GetOption("noclip_invis")

        for _, ply in ipairs(player.GetAll()) do
            local isInvis = ply:GetNW2Bool("SlashMoon.AdminInvis", false)
            local shouldBe = enabled and ply:GetMoveType() == MOVETYPE_NOCLIP
                and Admin.HasPermission(ply, "slashmoon_noclip_invis")

            if shouldBe then
                if not isInvis then SetInvisible(ply, true) end

                -- Смена оружия в noclip тоже должна оставаться невидимой
                local wep = ply:GetActiveWeapon()
                if IsValid(wep) and not wep:GetNoDraw() then wep:SetNoDraw(true) end
            elseif isInvis then
                SetInvisible(ply, false)
            end
        end
    end)

    -- При отключении модуля возвращаем видимость всем
    MODULE:OnDisabled(function()
        for _, ply in ipairs(player.GetAll()) do
            if ply:GetNW2Bool("SlashMoon.AdminInvis", false) then SetInvisible(ply, false) end
        end
    end)
end

if CLIENT then
    MODULE:Hook("DrawPhysgunBeam", "SlashMoon.AdminTools.HideBeam", function(ply)
        if IsValid(ply) and ply:GetNW2Bool("SlashMoon.AdminInvis", false) then
            return false
        end
    end)
end
