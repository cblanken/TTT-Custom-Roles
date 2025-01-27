local hook = hook
local net = net

------------------
-- TRANSLATIONS --
------------------

hook.Add("Initialize", "Swapper_Translations_Initialize", function()
    -- Event
    LANG.AddToLanguage("english", "ev_swap", "{victim} swapped with {attacker}")

    -- Popup
    LANG.AddToLanguage("english", "info_popup_swapper", [[You are {role}! {traitors} think you are {ajester} and you
deal no damage however, if anyone kills you, they become
the {swapper} and you take their role and can join the fight.]])
end)

-------------
-- SCORING --
-------------

-- Register the scoring events for the swapper
hook.Add("Initialize", "Swapper_Scoring_Initialize", function()
    local swap_icon = Material("icon16/arrow_refresh_small.png")
    local Event = CLSCORE.DeclareEventDisplay
    local PT = LANG.GetParamTranslation
    Event(EVENT_SWAPPER, {
        text = function(e)
            return PT("ev_swap", {victim = e.vic, attacker = e.att})
        end,
        icon = function(e)
            return swap_icon, "Swapped"
        end})
end)

net.Receive("TTT_SwapperSwapped", function(len)
    local victim = net.ReadString()
    local attacker = net.ReadString()
    local vicsid = net.ReadString()
    CLSCORE:AddEvent({
        id = EVENT_SWAPPER,
        vic = victim,
        att = attacker,
        sid64 = vicsid,
        bonus = 2
    })
end)

--------------
-- TUTORIAL --
--------------

hook.Add("TTTTutorialRoleText", "Swapper_TTTTutorialRoleText", function(role, titleLabel)
    if role == ROLE_SWAPPER then
        local roleColor = GetRoleTeamColor(ROLE_TEAM_JESTER)
        local html = "The " .. ROLE_STRINGS[ROLE_SWAPPER] .. " is a <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>jester</span> role whose goal is to be killed by another player and steal their role."

        html = html .. "<span style='display: block; margin-top: 10px;'>After <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>swapping</span>, they take over the goal of their new role.</span>"

        if GetGlobalInt("ttt_swapper_killer_health", 100) > 0 then
            html = html .. "<span style='display: block; margin-top: 10px;'>Be careful, the player who <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>kills the " .. ROLE_STRINGS[ROLE_SWAPPER] .."</span> then <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>becomes the " .. ROLE_STRINGS[ROLE_SWAPPER] .."</span>. Make sure to not kill them back!</span>"
        end

        return html
    end
end)