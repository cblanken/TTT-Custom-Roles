AddCSLuaFile()

local hook = hook
local IsValid = IsValid
local net = net
local pairs = pairs
local table = table

local GetAllPlayers = player.GetAll

-------------
-- CONVARS --
-------------

local tracker_footstep_time = CreateConVar("ttt_tracker_footstep_time", "15", FCVAR_NONE, "The amount of time players' footsteps should show to the tracker before fading. Set to 0 to disable", 0, 60)
local tracker_footstep_color = CreateConVar("ttt_tracker_footstep_color", "1")

hook.Add("TTTSyncGlobals", "Tracker_TTTSyncGlobals", function()
    SetGlobalInt("ttt_tracker_footstep_time", tracker_footstep_time:GetInt())
    SetGlobalBool("ttt_tracker_footstep_color", tracker_footstep_color:GetBool())
end)

-------------------
-- ROLE FEATURES --
-------------------

hook.Add("PlayerFootstep", "Tracker_PlayerFootstep", function(ply, pos, foot, sound, volume, rf)
    if not IsValid(ply) or ply:IsSpec() or not ply:Alive() then return true end
    if ply:WaterLevel() ~= 0 then return end
    -- Trackers don't see their own footsteps
    if ply:IsTracker() then return end

    local footstep_time = tracker_footstep_time:GetInt()
    if footstep_time <= 0 then return end

    net.Start("TTT_PlayerFootstep")
    net.WriteEntity(ply)
    net.WriteVector(pos)
    net.WriteAngle(ply:GetAimVector():Angle())
    net.WriteBit(foot)
    local col = Vector(1, 1, 1)
    if tracker_footstep_color:GetBool() then
        col = ply:GetNWVector("PlayerColor", Vector(1, 1, 1))
    end
    net.WriteTable(Color(col.x * 255, col.y * 255, col.z * 255))
    net.WriteUInt(footstep_time, 8)
    local tab = {}
    for k, p in pairs(GetAllPlayers()) do
        if p:IsActiveTracker() then
            table.insert(tab, p)
        end
    end
    net.Send(tab)
end)