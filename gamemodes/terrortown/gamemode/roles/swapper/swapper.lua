AddCSLuaFile()

util.AddNetworkString("TTT_SwapperSwapped")

-------------
-- CONVARS --
-------------

CreateConVar("ttt_swapper_notify_mode", "0", FCVAR_NONE, "The logic to use when notifying players that the swapper is killed", 0, 4)
CreateConVar("ttt_swapper_notify_sound", "0")
CreateConVar("ttt_swapper_notify_confetti", "0")
local swapper_killer_health = CreateConVar("ttt_swapper_killer_health", "100")
local swapper_respawn_health = CreateConVar("ttt_swapper_respawn_health", "100")
local swapper_weapon_mode = CreateConVar("ttt_swapper_weapon_mode", "1", FCVAR_NONE, "How to handle weapons when the swapper is killed", 0, 2)

hook.Add("TTTSyncGlobals", "Swapper_TTTSyncGlobals", function()
    SetGlobalInt("ttt_swapper_killer_health", swapper_killer_health:GetInt())
end)

-----------------
-- KILL CHECKS --
-----------------

local function SwapperKilledNotification(attacker, victim)
    JesterTeamKilledNotification(attacker, victim,
        -- getkillstring
        function(ply)
            local target = "someone"
            if ply:IsTraitorTeam() or attacker:IsDetectiveLike() then
                target = ROLE_STRINGS_EXT[attacker:GetRole()] .. " (" .. attacker:Nick() .. ")"
            end
            return "The " .. ROLE_STRINGS[ROLE_SWAPPER] .. " (" .. victim:Nick() .. ") has swapped with " .. target .. "!"
        end)
end

-- Pre-generate all of this information because we need the owner's weapon info even after they've been destroyed due to (temporary) death
local function GetPlayerWeaponInfo(ply)
    local ply_weapons = {}
    for _, w in ipairs(ply:GetWeapons()) do
        local primary_ammo = nil
        local primary_ammo_type = nil
        if w.Primary and w.Primary.Ammo ~= "none" then
            primary_ammo_type = w.Primary.Ammo
            primary_ammo = ply:GetAmmoCount(primary_ammo_type)
        end

        local secondary_ammo = nil
        local secondary_ammo_type = nil
        if w.Secondary and w.Secondary.Ammo ~= "none" and w.Secondary.Ammo ~= primary_ammo_type then
            secondary_ammo_type = w.Secondary.Ammo
            secondary_ammo = ply:GetAmmoCount(secondary_ammo_type)
        end

        table.insert(ply_weapons, {
            class = WEPS.GetClass(w),
            category = w.Category,
            primary_ammo = primary_ammo,
            primary_ammo_type = primary_ammo_type,
            secondary_ammo = secondary_ammo,
            secondary_ammo_type = secondary_ammo_type
        })
    end
    return ply_weapons
end

local function GivePlayerWeaponAndAmmo(ply, weap_info)
    ply:Give(weap_info.class)
    if weap_info.primary_ammo then
        ply:SetAmmo(weap_info.primary_ammo, weap_info.primary_ammo_type)
    end
    if weap_info.secondary_ammo then
        ply:SetAmmo(weap_info.secondary_ammo, weap_info.secondary_ammo_type)
    end
end

local function StripPlayerWeaponAndAmmo(ply, weap_info)
    ply:StripWeapon(weap_info.class)
    if weap_info.primary_ammo then
        ply:SetAmmo(0, weap_info.primary_ammo_type)
    end
    if weap_info.secondary_ammo then
        ply:SetAmmo(0, weap_info.secondary_ammo_type)
    end
end

hook.Add("PlayerDeath", "Swapper_KillCheck_PlayerDeath", function(victim, infl, attacker)
    local valid_kill = IsPlayer(attacker) and attacker ~= victim and GetRoundState() == ROUND_ACTIVE
    if not valid_kill then return end
    if not victim:IsSwapper() then return end

    SwapperKilledNotification(attacker, victim)
    attacker:SetNWString("SwappedWith", victim:Nick())

    -- Only bother saving the attacker weapons if we're going to do something with them
    local weapon_mode = swapper_weapon_mode:GetInt()
    local attacker_weapons = nil
    if weapon_mode > SWAPPER_WEAPON_NONE then
        attacker_weapons = GetPlayerWeaponInfo(attacker)
    end
    local victim_weapons = GetPlayerWeaponInfo(victim)

    timer.Simple(0.01, function()
        local body = victim.server_ragdoll or victim:GetRagdollEntity()
        victim:SetRole(attacker:GetRole())
        victim:SpawnForRound(true)
        victim:SetHealth(swapper_respawn_health:GetInt())
        if IsValid(body) then
            victim:SetPos(FindRespawnLocation(body:GetPos()) or body:GetPos())
            victim:SetEyeAngles(Angle(0, body:GetAngles().y, 0))
            body:Remove()
        end

        attacker:SetRole(ROLE_SWAPPER)
        attacker:MoveRoleState(victim)
        SendFullStateUpdate()

        local health = swapper_killer_health:GetInt()
        if health == 0 then
            attacker:Kill()
        else
            attacker:SetHealth(health)
        end

        timer.Simple(0.2, function()
            if weapon_mode == SWAPPER_WEAPON_ALL then
                -- Strip everything but the sure-thing weapons
                for _, w in ipairs(attacker_weapons) do
                    if w.class ~= "weapon_ttt_unarmed" and w.class ~= "weapon_zm_carry" then
                        StripPlayerWeaponAndAmmo(attacker, w)
                    end
                end

                -- Give the opposite player's weapons back
                for _, w in ipairs(attacker_weapons) do
                    GivePlayerWeaponAndAmmo(victim, w)
                end
                for _, w in ipairs(victim_weapons) do
                    GivePlayerWeaponAndAmmo(attacker, w)
                end
            else
                if weapon_mode == SWAPPER_WEAPON_ROLE then
                    -- Remove all role weapons from the attacker and give them to the victim
                    for _, w in ipairs(attacker_weapons) do
                        if w.category == WEAPON_CATEGORY_ROLE then
                            StripPlayerWeaponAndAmmo(attacker, w)
                            -- Give the attacker a regular crowbar to compensate for the killer crowbar that was removed
                            if w.class == "weapon_kil_crowbar" then
                                attacker:Give("weapon_zm_improvised")
                            end
                            GivePlayerWeaponAndAmmo(victim, w)
                        end
                    end
                end

                -- Give the victim all their weapons back
                for _, w in ipairs(victim_weapons) do
                    GivePlayerWeaponAndAmmo(victim, w)
                end
            end

            -- Have each player select their crowbar to hide role weapons
            attacker:SelectWeapon("weapon_zm_improvised")
            victim:SelectWeapon("weapon_zm_improvised")
        end)
    end)

    net.Start("TTT_SwapperSwapped")
    net.WriteString(victim:Nick())
    net.WriteString(attacker:Nick())
    net.WriteString(victim:SteamID64())
    net.Broadcast()
end)

hook.Add("TTTPrepareRound", "Swapper_PrepareRound", function()
    for _, v in pairs(player.GetAll()) do
        v:SetNWString("SwappedWith", "")
    end
end)