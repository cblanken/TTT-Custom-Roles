AddCSLuaFile()

local table = table

-- Initialize role features
ROLE_SELECTION_PREDICATE[ROLE_MADSCIENTIST] = function()
    -- Mad Scientist can only spawn when zombies are on their team
    return (INDEPENDENT_ROLES[ROLE_MADSCIENTIST] and INDEPENDENT_ROLES[ROLE_ZOMBIE]) or
            (MONSTER_ROLES[ROLE_MADSCIENTIST] and MONSTER_ROLES[ROLE_ZOMBIE])
end

hook.Add("TTTUpdateRoleState", "MadScientist_Team_TTTUpdateRoleState", function()
    local madscientist_is_monster = GetGlobalBool("ttt_madscientist_is_monster", false)
    MONSTER_ROLES[ROLE_MADSCIENTIST] = madscientist_is_monster
    INDEPENDENT_ROLES[ROLE_MADSCIENTIST] = not madscientist_is_monster
end)

------------------
-- ROLE CONVARS --
------------------

ROLE_CONVARS[ROLE_MADSCIENTIST] = {}
table.insert(ROLE_CONVARS[ROLE_MADSCIENTIST], {
    cvar = "ttt_madscientist_device_time",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
table.insert(ROLE_CONVARS[ROLE_MADSCIENTIST], {
    cvar = "ttt_madscientist_respawn_enable",
    type = ROLE_CONVAR_TYPE_BOOL
})
table.insert(ROLE_CONVARS[ROLE_MADSCIENTIST], {
    cvar = "ttt_madscientist_is_monster",
    type = ROLE_CONVAR_TYPE_BOOL
})