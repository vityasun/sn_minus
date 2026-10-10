-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("defib_refuse")

-- ========================================================
-- Отказ от воскрешения дефибриллятором
-- ========================================================

MODULE.Refusing = MODULE.Refusing or {}

-- Хелпер: одинаковая логика на сервере и клиенте.
-- Рагдолл воскрешаем если владелец мёртв ИЛИ является крысой.
local function IsRevivableOwner(owner)
    if not IsValid(owner) or not owner:IsPlayer() then return false end
    if not owner:Alive() then return true end
    if owner:GetNW2Bool("fh_isRat", false) then return true end
    return false
end

if SERVER then
    util.AddNetworkString("DefibSyncRefusedPlayers")
    util.AddNetworkString("DefibRequestRefuseToggle")

    MODULE:Hook("PlayerInitialSpawn", "DefibSendRefused", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) then
                net.Start("DefibSyncRefusedPlayers")
                net.WriteTable(MODULE.Refusing)
                net.Send(ply)
            end
        end)
    end)

    MODULE:Hook("PlayerDisconnected", "DefibClearRefused", function(ply)
        if ply:SteamID() then
            MODULE.Refusing[ply:SteamID()] = nil
            net.Start("DefibSyncRefusedPlayers")
            net.WriteTable(MODULE.Refusing)
            net.Broadcast()
        end
    end)

    MODULE:Receive("DefibRequestRefuseToggle", function(_, ply)
        if not IsValid(ply) then return end
        if not SlashMoon.Security.CheckRateLimit(ply, "defib_refuse_toggle", 1) then return end
        local steamID = ply:SteamID()
        MODULE.Refusing[steamID] = not MODULE.Refusing[steamID]

        net.Start("DefibSyncRefusedPlayers")
        net.WriteTable(MODULE.Refusing)
        net.Broadcast()

        local msg = MODULE.Refusing[steamID] and
            "Вы отказались от воскрешения." or
            "Теперь вас можно воскресить."
        ply:ChatPrint(msg)
    end)

    -- Патчим дефибриллятор
    MODULE:Hook("InitPostEntity", "PatchDefibRevive", function()
        local SWEP = weapons.GetStored("weapon_defibrillator")
        if not SWEP or not SWEP.PrimaryAttack then return end

        -- Оригинал запоминается один раз (хук может вызываться повторно при включении модуля)
        MODULE.OriginalPrimaryAttack = MODULE.OriginalPrimaryAttack or SWEP.PrimaryAttack
        local Original_PrimaryAttack = MODULE.OriginalPrimaryAttack
        local pendingRevive = {}

        function SWEP:PrimaryAttack()
            if not MODULE:IsEnabled() then return Original_PrimaryAttack(self) end

            local tr = util.TraceLine({
                start = self.Owner:GetShootPos(),
                endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 60,
                filter = self.Owner,
                mask = MASK_SHOT_HULL,
            })

            if not IsValid(tr.Entity) then
                tr = util.TraceHull({
                    start = self.Owner:GetShootPos(),
                    endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 60,
                    filter = self.Owner,
                    mins = Vector(-20, -20, 0),
                    maxs = Vector(20, 20, 0),
                    mask = MASK_SHOT_HULL,
                })
            end

            if IsValid(tr.Entity) and tr.Entity:GetClass() == "prop_ragdoll" then
                local owner = tr.Entity:GetOwner()
                if IsRevivableOwner(owner) then
                    if MODULE.Refusing[owner:SteamID()] then
                        self.Owner:EmitSound("HL2Player.UseDeny")
                        return
                    end

                    pendingRevive[owner:SteamID()] = CurTime()
                end
            end

            return Original_PrimaryAttack(self)
        end

        -- Ловим РЕАЛЬНЫЙ момент воскрешения
        MODULE:Hook("PlayerSpawn", "FH_DefibReviveEffect", function(ply)
            local sid = ply:SteamID()
            if pendingRevive[sid] and (CurTime() - pendingRevive[sid]) < 15 then
                pendingRevive[sid] = nil
                timer.Simple(0.2, function()
                    if IsValid(ply) then
                        ply:ConCommand("fh_trigger_defib")
                    end
                end)
            end
        end)

        MODULE:Hook("PlayerDisconnected", "FH_DefibReviveClear", function(ply)
            pendingRevive[ply:SteamID()] = nil
        end)
    end)
end

if CLIENT then
    CreateClientConVar("fh_defib_refuse", "0", true, false)

    MODULE:Receive("DefibSyncRefusedPlayers", function()
        MODULE.Refusing = net.ReadTable() or {}
    end)

    cvars.AddChangeCallback("fh_defib_refuse", function(name, old, new)
        net.Start("DefibRequestRefuseToggle")
        net.SendToServer()
    end)

    -- === ПАТЧИМ КОНТЕКСТНОЕ МЕНЮ БЕЗ ИЗМЕНЕНИЯ cl_hud.lua ===

    local lastToggle = 0

    MODULE:Hook("OnContextMenuOpen", "DefibRefuse_PatchMenu", function()
        timer.Simple(0.01, function()
            local foundMenu = nil
            local allPanels = vgui.GetWorldPanel():GetChildren()

            for _, pnl in ipairs(allPanels) do
                if IsValid(pnl) and pnl.ClassName == "DMenu" and not pnl.DefibRefusePatched then
                    local function checkPanel(parent)
                        for _, child in ipairs(parent:GetChildren()) do
                            if IsValid(child) and child.GetText then
                                local txt = child:GetText()
                                if type(txt) == "string" and (txt:find("Редактор") or txt:find("Editor")) then
                                    return true
                                end
                            end
                            if checkPanel(child) then return true end
                        end
                        return false
                    end
                    if checkPanel(pnl) then foundMenu = pnl break end
                end
            end

            if IsValid(foundMenu) then
                foundMenu:AddSpacer()

                local cvar = GetConVar("fh_defib_refuse")
                if not cvar then return end

                local isRefusing = cvar:GetBool()
                local btnText = isRefusing and "Отказаться от воскрешения" or "Разрешить воскрешение"

                local myBtn = foundMenu:AddOption(btnText, function()
                    if RealTime() < lastToggle + 1 then return end
                    lastToggle = RealTime()

                    local target = isRefusing and "0" or "1"
                    LocalPlayer():ConCommand("fh_defib_refuse " .. target)

                    if IsValid(g_ContextMenu) then g_ContextMenu:Close() end
                end)

                myBtn:SetIcon(isRefusing and "icon16/user_delete.png" or "icon16/user_add.png")
                foundMenu.DefibRefusePatched = true

                foundMenu:InvalidateLayout(true)
                foundMenu:SizeToContents()
            end
        end)
    end)

    -- === Подсветка трупов ===
    MODULE:Hook("PreDrawHalos", "DefibHighlightCorpses_Patched", function()
        local lply = LocalPlayer()
        local wep = lply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_defibrillator" then return end

        local corpses = {}
        for _, ent in pairs(ents.FindByClass("prop_ragdoll")) do
            local owner = ent:GetOwner()
            if IsRevivableOwner(owner) and not MODULE.Refusing[owner:SteamID()] then
                if ent:GetPos():Distance(lply:GetPos()) <= 3064 then
                    table.insert(corpses, ent)
                end
            end
        end
        halo.Add(corpses, Color(255, 0, 0), 1, 1, 2, true, true)
    end)

    MODULE:Hook("HUDPaint", "DefibDrawNames_Patched", function()
        local lply = LocalPlayer()
        local wep = lply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_defibrillator" then return end

        for _, ent in pairs(ents.FindByClass("prop_ragdoll")) do
            local owner = ent:GetOwner()
            if IsRevivableOwner(owner) and not MODULE.Refusing[owner:SteamID()] then
                if ent:GetPos():Distance(lply:GetPos()) <= 377 then
                    local screenPos = ent:GetPos():ToScreen()
                    draw.SimpleText(owner:Nick(), "timerFontBelow", screenPos.x, screenPos.y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end
    end)
end
