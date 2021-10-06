AddCSLuaFile()

util.AddNetworkString("TTT_BeggarConverted")
util.AddNetworkString("TTT_BeggarKilled")

-------------
-- CONVARS --
-------------

CreateConVar("ttt_beggar_reveal_traitor", "1", FCVAR_NONE, "Who the beggar is revealed to when they join the traitor team", 0, 3)
CreateConVar("ttt_beggar_reveal_innocent", "2", FCVAR_NONE, "Who the beggar is revealed to when they join the innocent team", 0, 3)
CreateConVar("ttt_beggar_respawn", "0")
CreateConVar("ttt_beggar_respawn_delay", "3")
CreateConVar("ttt_beggar_notify_mode", "0", FCVAR_NONE, "The logic to use when notifying players that the beggar is killed", 0, 4)
CreateConVar("ttt_beggar_notify_sound", "0")
CreateConVar("ttt_beggar_notify_confetti", "0")

hook.Add("TTTSyncGlobals", "Beggar_TTTSyncGlobals", function()
    SetGlobalInt("ttt_beggar_reveal_traitor", GetConVar("ttt_beggar_reveal_traitor"):GetInt())
    SetGlobalInt("ttt_beggar_reveal_innocent", GetConVar("ttt_beggar_reveal_innocent"):GetInt())
end)

-------------------
-- ROLE TRACKING --
-------------------

hook.Add("WeaponEquip", "Beggar_WeaponEquip", function(wep, ply)
    if not IsValid(wep) or not IsPlayer(ply) then return end
    if not wep.CanBuy or wep.AutoSpawnable then return end

    if not wep.BoughtBy then
        wep.BoughtBy = ply
    elseif ply:IsBeggar() and (wep.BoughtBy:IsTraitorTeam() or wep.BoughtBy:IsInnocentTeam()) then
        local role
        local beggarMode
        if wep.BoughtBy:IsTraitorTeam() then
            role = ROLE_TRAITOR
            beggarMode = GetConVar("ttt_beggar_reveal_traitor"):GetInt()
        else
            role = ROLE_INNOCENT
            beggarMode = GetConVar("ttt_beggar_reveal_innocent"):GetInt()
        end

        ply:SetRole(role)
        ply:SetNWBool("WasBeggar", true)
        ply:PrintMessage(HUD_PRINTTALK, "You have joined the " .. ROLE_STRINGS[role] .. " team")
        ply:PrintMessage(HUD_PRINTCENTER, "You have joined the " .. ROLE_STRINGS[role] .. " team")
        timer.Simple(0.5, function() SendFullStateUpdate() end) -- Slight delay to avoid flickering from beggar to the new role and back to beggar

        for _, v in ipairs(player.GetAll()) do
            if beggarMode == BEGGAR_REVEAL_ALL or (v:IsActiveTraitorTeam() and beggarMode == BEGGAR_REVEAL_TRAITORS) or (not v:IsActiveTraitorTeam() and beggarMode == BEGGAR_REVEAL_INNOCENTS) then
                v:PrintMessage(HUD_PRINTTALK, "The beggar has joined the " .. ROLE_STRINGS[role] .. " team")
                v:PrintMessage(HUD_PRINTCENTER, "The beggar has joined the " .. ROLE_STRINGS[role] .. " team")
            end
        end

        net.Start("TTT_BeggarConverted")
        net.WriteString(ply:Nick())
        net.WriteString(wep.BoughtBy:Nick())
        net.WriteString(ROLE_STRINGS_EXT[role])
        net.WriteString(ply:SteamID64())
        net.Broadcast()
    end
end)

-- Disable tracking that this player was a beggar at the start of a new round or if their role changes again (e.g. if they go beggar -> innocent -> dead -> hypnotist res to traitor)
hook.Add("TTTPrepareRound", "Beggar_PrepareRound", function()
    for _, v in pairs(player.GetAll()) do
        v:SetNWBool("WasBeggar", false)
        timer.Remove(v:Nick() .. "BeggarRespawn")
    end
end)

hook.Add("TTTPlayerRoleChanged", "Beggar_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
    if oldRole ~= ROLE_BEGGAR then
        ply:SetNWBool("WasBeggar", false)
    end
end)

-----------------
-- KILL CHECKS --
-----------------

local function BeggarKilledNotification(attacker, victim)
    JesterTeamKilledNotification(attacker, victim,
        -- getkillstring
        function()
            return attacker:Nick() .. " cruelly killed the lowly " .. ROLE_STRINGS[ROLE_BEGGAR] .. "!"
        end)
end

hook.Add("PlayerDeath", "Beggar_KillCheck_PlayerDeath", function(victim, infl, attacker)
    local valid_kill = IsPlayer(attacker) and attacker ~= victim and GetRoundState() == ROUND_ACTIVE
    if not valid_kill then return end
    if not victim:IsBeggar() then return end

    BeggarKilledNotification(attacker, victim)

    if GetConVar("ttt_beggar_respawn"):GetBool() then
        local delay = GetConVar("ttt_beggar_respawn_delay"):GetInt()
        if delay > 0 then
            victim:PrintMessage(HUD_PRINTCENTER, "You were killed but will respawn in " .. delay .. " seconds.")
        else
            victim:PrintMessage(HUD_PRINTCENTER, "You were killed but are about to respawn.")
            -- Introduce a slight delay to prevent player getting stuck as a spectator
            delay = 0.1
        end
        timer.Create(victim:Nick() .. "BeggarRespawn", delay, 1, function()
            local body = victim.server_ragdoll or victim:GetRagdollEntity()
            victim:SpawnForRound(true)
            victim:SetHealth(victim:GetMaxHealth())
            SafeRemoveEntity(body)
        end)

        net.Start("TTT_BeggarKilled")
        net.WriteString(victim:Nick())
        net.WriteString(attacker:Nick())
        net.WriteUInt(delay, 8)
        net.Broadcast()
    end
end)