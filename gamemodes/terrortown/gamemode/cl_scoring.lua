-- Game report

include("cl_awards.lua")

local table = table
local string = string
local vgui = vgui
local pairs = pairs

CLSCORE = {}
CLSCORE.Events = {}
CLSCORE.Scores = {}
CLSCORE.InnocentIDs = {}
CLSCORE.TraitorIDs = {}
CLSCORE.DetectiveIDs = {}
CLSCORE.JesterIDs = {}
CLSCORE.SwapperIDs = {}
CLSCORE.GlitchIDs = {}
CLSCORE.PhantomIDs = {}
CLSCORE.HypnotistIDs = {}
CLSCORE.RevengerIDs = {}
CLSCORE.DrunkIDs = {}
CLSCORE.ClownIDs = {}
CLSCORE.DeputyIDs = {}
CLSCORE.ImpersonatorIDs = {}
CLSCORE.BeggarIDs = {}
CLSCORE.OldManIDs = {}
CLSCORE.Players = {}
CLSCORE.StartTime = 0
CLSCORE.Panel = nil

CLSCORE.EventDisplay = {}

include("scoring_shd.lua")

local skull_icon = Material("HUD/killicons/default")

surface.CreateFont("WinHuge", {
    font = "Trebuchet24",
    size = 72,
    weight = 1000,
    shadow = true,
    extended = true
})

surface.CreateFont("WinSmall", {
    font = "Trebuchet24",
    size = 32,
    weight = 1000,
    shadow = true,
    extended = true
})

surface.CreateFont("ScoreNicks", {
    font = "Trebuchet24",
    size = 32,
    weight = 100
})

-- so much text here I'm using shorter names than usual
local T = LANG.GetTranslation
local PT = LANG.GetParamTranslation
local spawnedPlayers = {}
local disconnected = {}
local customEvents = {}

function AddEvent(e)
    e["t"] = math.Round(CurTime(), 2)
    table.insert(customEvents, e)
end

local function GetPlayerFromSteam64(id)
    -- The first bot's ID is 90071996842377216 whhich translates to "STEAM_0:0:0", an 11-character string
    -- A player's Steam ID cannot be that short, so if it is this must be a bot
    local isBot = string.len(util.SteamIDFrom64(id)) == 11
    -- Bots cannot be retrieved by SteamID on the client so search by name instead
    if isBot then
        for _, p in pairs(player.GetAll()) do
            if p:Nick() == CLSCORE.Players[id] then
                return p
            end
        end
    else
        return player.GetBySteamID64(id)
    end
end

local function FitNicknameLabel(nicklbl, maxwidth, getstring, args)
    local nickw, _ = nicklbl:GetSize()
    while nickw > maxwidth do
        local nickname = nicklbl:GetText()
        nickname, args = getstring(nickname, args)
        nicklbl:SetText(nickname)
        nicklbl:SizeToContents()
        nickw, _ = nicklbl:GetSize()
    end
end

net.Receive("TTT_Hypnotised", function(len)
    local name = net.ReadString()
    AddEvent({
        id = EVENT_HYPNOTISED,
        vic = name
    })
end)

net.Receive("TTT_Defibrillated", function(len)
    local name = net.ReadString()
    AddEvent({
        id = EVENT_DEFIBRILLATED,
        vic = name
    })
end)

net.Receive("TTT_PlayerDisconnected", function(len)
    local name = net.ReadString()
    table.insert(disconnected, name)
    AddEvent({
        id = EVENT_DISCONNECTED,
        vic = name
    })
end)

net.Receive("TTT_ResetScoreboard", function(len)
    spawnedPlayers = {}
    disconnected = {}
    customEvents = {}
end)

net.Receive("TTT_SpawnedPlayers", function(len)
    local name = net.ReadString()
    local role = net.ReadUInt(8)
    table.insert(spawnedPlayers, name)
    AddEvent({
        id = EVENT_SPAWN,
        ply = name,
        rol = role
    })
end)

net.Receive("TTT_LogInfo", function(len)
    AddEvent({
        id = EVENT_LOG,
        txt = net.ReadString()
    })
end)

net.Receive("TTT_RoleChanged", function(len)
    local s64 = net.ReadString()
    local role = net.ReadUInt(8)
    local ply = GetPlayerFromSteam64(s64)
    local name = "UNKNOWN"
    if IsValid(ply) then
        name = ply:Nick()
    end

    AddEvent({
        id = EVENT_ROLECHANGE,
        ply = name,
        rol = role
    })
end)

local old_man_wins = false
net.Receive("TTT_UpdateOldManWins", function()
    old_man_wins = net.ReadBool()
end)

function CLSCORE:GetDisplay(key, event)
    local displayfns = self.EventDisplay[event.id]
    if not displayfns then return end
    local keyfn = displayfns[key]
    if not keyfn then return end

    return keyfn(event)
end

function CLSCORE:TextForEvent(e)
    return self:GetDisplay("text", e)
end

function CLSCORE:IconForEvent(e)
    return self:GetDisplay("icon", e)
end

function CLSCORE:TimeForEvent(e)
    local t = e.t - self.StartTime
    if t >= 0 then
        return util.SimpleTime(t, "%02i:%02i")
    else
        return "     "
    end
end

-- Tell CLSCORE how to display an event. See cl_scoring_events for examples.
-- Pass an empty table to keep an event from showing up.
function CLSCORE.DeclareEventDisplay(event_id, event_fns)
    -- basic input vetting, can't check returned value types because the
    -- functions may be impure
    if not tonumber(event_id) then
        error("Event ??? display: invalid event id", 2)
    end
    if not istable(event_fns) then
        error(string.format("Event %d display: no display functions found.", event_id), 2)
    end
    if not event_fns.text then
        error(string.format("Event %d display: no text display function found.", event_id), 2)
    end
    if not event_fns.icon then
        error(string.format("Event %d display: no icon and tooltip display function found.", event_id), 2)
    end

    CLSCORE.EventDisplay[event_id] = event_fns
end

function CLSCORE:FillDList(dlst)
    local allEvents = self.Events
    table.Merge(allEvents, customEvents)
    table.SortByMember(allEvents, "t", true)

    for _, e in pairs(allEvents) do
        local etxt = self:TextForEvent(e)
        local eicon, ttip = self:IconForEvent(e)
        local etime = self:TimeForEvent(e)

        if etxt then
            if eicon then
                local mat = eicon
                eicon = vgui.Create("DImage")
                eicon:SetMaterial(mat)
                eicon:SetTooltip(ttip)
                eicon:SetKeepAspect(true)
                eicon:SizeToContents()
            end

            dlst:AddLine(etime, eicon, "  " .. etxt)
        end
    end
end

local function ValidAward(a)
    return a and a.nick and a.text and a.title and a.priority
end

local wintitle = {
    [WIN_INNOCENT] = { txt = "hilite_win_innocent", c = COLOR_INNOCENT },
    [WIN_TRAITOR] = { txt = "hilite_win_traitors", c = COLOR_TRAITOR },
    [WIN_JESTER] = { txt = "hilite_win_jester", c = COLOR_JESTER },
    [WIN_CLOWN] = { txt = "hilite_win_clown", c = COLOR_JESTER }
}

function CLSCORE:BuildEventLogPanel(dpanel)
    local margin = 10

    local w, h = dpanel:GetSize()

    local dlist = vgui.Create("DListView", dpanel)
    dlist:SetPos(0, 0)
    dlist:SetSize(w, h - margin * 2)
    dlist:SetSortable(true)
    dlist:SetMultiSelect(false)

    local timecol = dlist:AddColumn(T("col_time"))
    local iconcol = dlist:AddColumn("")
    local eventcol = dlist:AddColumn(T("col_event"))

    iconcol:SetFixedWidth(16)
    timecol:SetFixedWidth(40)

    -- If sortable is off, no background is drawn for the headers which looks
    -- terrible. So enable it, but disable the actual use of sorting.
    iconcol.Header:SetDisabled(true)
    timecol.Header:SetDisabled(true)
    eventcol.Header:SetDisabled(true)

    self:FillDList(dlist)
end

function CLSCORE:BuildScorePanel(dpanel)
    local w, h = dpanel:GetSize()

    local dlist = vgui.Create("DListView", dpanel)
    dlist:SetPos(0, 0)
    dlist:SetSize(w, h)
    dlist:SetSortable(true)
    dlist:SetMultiSelect(false)

    local colnames = { "", "col_player", "col_role", "col_kills1", "col_kills2", "col_kills3", "col_points", "col_team", "col_total" }
    for _, name in pairs(colnames) do
        if name == "" then
            -- skull icon column
            local c = dlist:AddColumn("")
            c:SetFixedWidth(18)
        else
            dlist:AddColumn(T(name))
        end
    end

    -- the type of win condition triggered is relevant for team bonus
    local wintype = WIN_NONE
    for i = #self.Events, 1, -1 do
        local e = self.Events[i]
        if e.id == EVENT_FINISH then
            wintype = e.win
            break
        end
    end

    local scores = self.Scores
    local nicks = self.Players
    local bonus = ScoreTeamBonus(scores, wintype)

    for id, s in pairs(scores) do
        if id ~= -1 then
            local was_traitor = s.was_traitor or s.was_hypnotist or s.was_impersonator
            local was_innocent = s.was_innocent or s.was_detective or s.was_phantom or s.was_glitch or s.was_revenger or s.was_deputy
            local role = ROLE_STRINGS[ROLE_INNOCENT]
            if s.was_traitor then
                role = ROLE_STRINGS[ROLE_TRAITOR]
            elseif s.was_detective then
                role = ROLE_STRINGS[ROLE_DETECTIVE]
            elseif s.was_jester then
                role = ROLE_STRINGS[ROLE_JESTER]
            elseif s.was_swapper then
                role = ROLE_STRINGS[ROLE_SWAPPER]
            elseif s.was_glitch then
                role = ROLE_STRINGS[ROLE_GLITCH]
            elseif s.was_phantom then
                role = ROLE_STRINGS[ROLE_PHANTOM]
            elseif s.was_hypnotist then
                role = ROLE_STRINGS[ROLE_HYPNOTIST]
            elseif s.was_revenger then
                role = ROLE_STRINGS[ROLE_REVENGER]
            elseif s.was_drunk then
                role = ROLE_STRINGS[ROLE_DRUNK]
            elseif s.was_clown then
                role = ROLE_STRINGS[ROLE_CLOWN]
            elseif s.was_deputy then
                role = ROLE_STRINGS[ROLE_DEPUTY]
            elseif s.was_impersonator then
                role = ROLE_STRINGS[ROLE_IMPERSONATOR]
            elseif s.was_beggar then
                role = ROLE_STRINGS[ROLE_BEGGAR]
            elseif s.was_old_man then
                role = ROLE_STRINGS[ROLE_OLDMAN]
            end

            local surv = ""
            if s.deaths > 0 then
                surv = vgui.Create("ColoredBox", dlist)
                surv:SetColor(Color(150, 50, 50))
                surv:SetBorder(false)
                surv:SetSize(18, 18)

                local skull = vgui.Create("DImage", surv)
                skull:SetMaterial(skull_icon)
                skull:SetTooltip("Dead")
                skull:SetKeepAspect(true)
                skull:SetSize(18, 18)
            end

            local points_own = KillsToPoints(s, was_traitor, was_innocent)
            local points_team = bonus.innos
            if was_traitor then
                points_team = bonus.traitors
            elseif s.was_jester or s.was_swapper then
                points_team = bonus.jesters
            elseif s.was_killer then
                points_team = bonus.killers
            end
            local points_total = points_own + points_team

            local l = dlist:AddLine(surv, nicks[id], role, s.innos, s.traitors, s.jesters, points_own, points_team, points_total)

            -- center align
            for _, col in pairs(l.Columns) do
                col:SetContentAlignment(5)
            end

            -- when sorting on the column showing survival, we would get an error
            -- because images can't be sorted, so instead hack in a dummy value
            local surv_col = l.Columns[1]
            if surv_col then
                surv_col.Value = type(surv_col.Value) == "Panel" and "1" or "0"
            end
        end
    end

    dlist:SortByColumn(6)
end

function CLSCORE:AddAward(y, pw, award, dpanel)
    local nick = award.nick
    local text = award.text
    local title = string.upper(award.title)

    local titlelbl = vgui.Create("DLabel", dpanel)
    titlelbl:SetText(title)
    titlelbl:SetFont("TabLarge")
    titlelbl:SizeToContents()
    local tiw, tih = titlelbl:GetSize()

    local nicklbl = vgui.Create("DLabel", dpanel)
    nicklbl:SetText(nick)
    nicklbl:SetFont("DermaDefaultBold")
    nicklbl:SizeToContents()
    local nw, nh = nicklbl:GetSize()

    local txtlbl = vgui.Create("DLabel", dpanel)
    txtlbl:SetText(text)
    txtlbl:SetFont("DermaDefault")
    txtlbl:SizeToContents()
    local tw, _ = txtlbl:GetSize()

    titlelbl:SetPos((pw - tiw) / 2, y)
    y = y + tih + 2

    local fw = nw + tw + 5
    local fx = ((pw - fw) / 2)
    nicklbl:SetPos(fx, y)
    txtlbl:SetPos(fx + nw + 5, y)

    y = y + nh

    return y
end

local old_man_won_last_round = false
function CLSCORE:BuildSummaryPanel(dpanel)
    local w, h = dpanel:GetSize()

    local title = wintitle[WIN_INNOCENT]
    for i = #self.Events, 1, -1 do
        local e = self.Events[i]
        if e.id == EVENT_FINISH then
            local wintype = e.win
            if wintype == WIN_TIMELIMIT then wintype = WIN_INNOCENT end
            title = wintitle[wintype]
            break
        end
    end

    local bg = vgui.Create("ColoredBox", dpanel)
    bg:SetColor(Color(97, 100, 102, 255))
    bg:SetSize(w, h)
    bg:SetPos(0, 0)

    local winlbl = vgui.Create("DLabel", dpanel)
    winlbl:SetFont("WinHuge")
    winlbl:SetText(T(title.txt))
    winlbl:SetTextColor(COLOR_WHITE)
    winlbl:SizeToContents()
    local xwin = (w - winlbl:GetWide())/2
    local ywin = 15
    winlbl:SetPos(xwin, ywin)

    old_man_won_last_round = old_man_wins
    local exwinlbl = vgui.Create("DLabel", dpanel)
    if old_man_won_last_round then
        exwinlbl:SetFont("WinSmall")
        exwinlbl:SetText(T("hilite_win_old_man"))
        exwinlbl:SetTextColor(COLOR_WHITE)
        exwinlbl:SizeToContents()
        local xexwin = (w - exwinlbl:GetWide()) / 2
        local yexwin = 61
        exwinlbl:SetPos(xexwin, yexwin)
    else
        exwinlbl:SetText("")
    end

    bg.PaintOver = function()
        draw.RoundedBox(8, 8, ywin - 5, w - 14, winlbl:GetTall() + 10, title.c)
        if old_man_won_last_round then draw.RoundedBoxEx(8, 158, 65, 380, 28, COLOR_INDEPENDENT, true, true, false, false) end
        draw.RoundedBox(0, 8, ywin + winlbl:GetTall() + 6, 341, 329, Color(164, 164, 164, 255))
        draw.RoundedBox(0, 357, ywin + winlbl:GetTall() + 6, 341, 329, Color(164, 164, 164, 255))
        draw.RoundedBox(0, 8, ywin + winlbl:GetTall() + 344, 690, 32, Color(164, 164, 164, 255))
        for i = ywin + winlbl:GetTall() + 39, ywin + winlbl:GetTall() + 304, 33 do
            draw.RoundedBox(0, 8, i, 341, 1, Color(97, 100, 102, 255))
            draw.RoundedBox(0, 357, i, 341, 1, Color(97, 100, 102, 255))
        end
    end

    if old_man_wins then winlbl:SetPos(xwin, ywin - 15) end

    local scores = self.Scores
    local nicks = self.Players
    local countI = 0
    local countT = 0

    for id, s in pairs(scores) do
        if id ~= -1 then
            local foundPlayer = false
            for _, v in pairs(spawnedPlayers) do
                if v == nicks[id] then
                    foundPlayer = true
                    break
                end
            end

            if foundPlayer then
                local ply = GetPlayerFromSteam64(id)

                -- Backup in case people disconnect and we cant check their role at the end of the round
                local startingRole = ROLE_STRINGS_SHORT[ROLE_INNOCENT]
                if s.was_traitor then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_TRAITOR]
                elseif s.was_detective then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_DETECTIVE]
                elseif s.was_jester then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_JESTER]
                elseif s.was_swapper then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_SWAPPER]
                elseif s.was_glitch then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_GLITCH]
                elseif s.was_phantom then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_PHANTOM]
                elseif s.was_hypnotist then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_HYPNOTIST]
                elseif s.was_revenger then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_REVENGER]
                elseif s.was_drunk then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_DRUNK]
                elseif s.was_clown then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_CLOWN]
                elseif s.was_deputy then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_DEPUTY]
                elseif s.was_impersonator then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_IMPERSONATOR]
                elseif s.was_beggar then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_BEGGAR]
                elseif s.was_old_man then
                    startingRole = ROLE_STRINGS_SHORT[ROLE_OLDMAN]
                end

                local hasDisconnected = false

                local finalRole = ROLE_STRINGS_SHORT[ROLE_INNOCENT]

                local swappedWith = ""
                local jesterKiller = ""

                local alive = false
                if IsValid(ply) then
                    alive = ply:Alive()
                    finalRole = ROLE_STRINGS_SHORT[ply:GetRole()]
                    if ply:IsInnocent() then
                        if ply:GetNWBool("WasDrunk", false) then
                            finalRole = ROLE_STRINGS_SHORT[ROLE_DRUNK] .. "_i"
                        elseif ply:GetNWBool("WasBeggar", false) then
                            finalRole = ROLE_STRINGS_SHORT[ROLE_BEGGAR] .. "_i"
                        end
                    elseif ply:IsTraitor() then
                        local wasHypnotised = ply:GetNWString("WasHypnotised", "")
                        if ply:GetNWBool("WasDrunk", false) then
                            finalRole = ROLE_STRINGS_SHORT[ROLE_DRUNK] .. "_t"
                        elseif ply:GetNWBool("WasBeggar", false) then
                            finalRole = ROLE_STRINGS_SHORT[ROLE_BEGGAR] .. "_t"
                        elseif wasHypnotised ~= "" then
                            finalRole = wasHypnotised .. "_t"
                        end
                    elseif ply:IsJester() then
                        jesterKiller = ply:GetNWString("JesterKiller", "")
                    elseif ply:IsSwapper() then
                        swappedWith = ply:GetNWString("SwappedWith", "")
                    end
                else
                    hasDisconnected = true
                end

                local roleFileName = ROLE_STRINGS_SHORT[ROLE_INNOCENT]
                if hasDisconnected then
                    roleFileName = startingRole
                else
                    roleFileName = finalRole
                end

                local roleIcon = vgui.Create("DImage", dpanel)
                roleIcon:SetSize(32, 32)
                roleIcon:SetImage("vgui/ttt/score_" .. roleFileName .. ".png")

                local nicklbl = vgui.Create("DLabel", dpanel)
                nicklbl:SetFont("ScoreNicks")
                nicklbl:SetText(nicks[id])
                nicklbl:SetTextColor(COLOR_WHITE)
                nicklbl:SizeToContents()

                -- Auto resize the nickname label
                FitNicknameLabel(nicklbl, 275, function(nickname)
                    return string.sub(nickname, 0, string.len(nickname) - 4) .. "..."
                end)

                if (string.sub(roleFileName, -2) == "_i"
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_INNOCENT]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_DETECTIVE]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_GLITCH]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_PHANTOM]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_REVENGER]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_DEPUTY]) then
                    roleIcon:SetPos(8, 95 + 33 * countI)
                    nicklbl:SetPos(46, 93 + 33 * countI)

                    if hasDisconnected then
                        local disconIcon = vgui.Create("DImage", dpanel)
                        disconIcon:SetSize(32, 32)
                        disconIcon:SetPos(317, 95 + 33 * countI)
                        disconIcon:SetImage("vgui/ttt/score_disconicon.png")
                    elseif not alive then
                        local skullIcon = vgui.Create("DImage", dpanel)
                        skullIcon:SetSize(32, 32)
                        skullIcon:SetPos(317, 95 + 33 * countI)
                        skullIcon:SetImage("vgui/ttt/score_skullicon.png")
                    end

                    countI = countI + 1
                elseif (string.sub(roleFileName, -2) == "_t"
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_TRAITOR]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_HYPNOTIST]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_IMPERSONATOR]) then
                    roleIcon:SetPos(357, 95 + 33 * countT)
                    nicklbl:SetPos(395, 93 + 33 * countT)

                    if hasDisconnected then
                        local disconIcon = vgui.Create("DImage", dpanel)
                        disconIcon:SetSize(32, 32)
                        disconIcon:SetPos(666, 95 + 33 * countT)
                        disconIcon:SetImage("vgui/ttt/score_disconicon.png")
                    elseif not alive then
                        local skullIcon = vgui.Create("DImage", dpanel)
                        skullIcon:SetSize(32, 32)
                        skullIcon:SetPos(666, 95 + 33 * countT)
                        skullIcon:SetImage("vgui/ttt/score_skullicon.png")
                    end

                    countT = countT + 1
                elseif (roleFileName == ROLE_STRINGS_SHORT[ROLE_JESTER]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_SWAPPER]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_DRUNK]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_CLOWN]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_BEGGAR]
                        or roleFileName == ROLE_STRINGS_SHORT[ROLE_OLDMAN]) then
                    roleIcon:SetPos(8, 432)
                    nicklbl:SetPos(46, 430)

                    if roleFileName == ROLE_STRINGS_SHORT[ROLE_JESTER] and jesterKiller ~= "" then
                        nicklbl:SetText(nicks[id] .. " (Killed by " .. jesterKiller .. ")")
                        nicklbl:SizeToContents()
                    elseif roleFileName == ROLE_STRINGS_SHORT[ROLE_SWAPPER] and swappedWith ~= "" then
                        nicklbl:SetText(nicks[id] .. " (Swapped with " .. swappedWith .. ")")
                        nicklbl:SizeToContents()
                    end

                    if hasDisconnected then
                        local disconIcon = vgui.Create("DImage", dpanel)
                        disconIcon:SetSize(32, 32)
                        disconIcon:SetPos(666, 432)
                        disconIcon:SetImage("vgui/ttt/score_disconicon.png")
                    elseif not alive then
                        local skullIcon = vgui.Create("DImage", dpanel)
                        skullIcon:SetSize(32, 32)
                        skullIcon:SetPos(666, 432)
                        skullIcon:SetImage("vgui/ttt/score_skullicon.png")
                    end
                end
            end
        end
    end
end

function CLSCORE:BuildHilitePanel(dpanel)
    local w, h = dpanel:GetSize()

    local endtime = self.StartTime
    local title = wintitle[WIN_INNOCENT]
    for i=#self.Events, 1, -1 do
        local e = self.Events[i]
        if e.id == EVENT_FINISH then
           endtime = e.t
           -- when win is due to timeout, innocents win
           local wintype = e.win
           if wintype == WIN_TIMELIMIT then wintype = WIN_INNOCENT end
           title = wintitle[wintype]
           break
        end
    end

    local roundtime = endtime - self.StartTime

    local numply = table.Count(self.Players)
    local numtr = table.Count(self.TraitorIDs) + table.Count(self.HypnotistIDs) + table.Count(self.ImpersonatorIDs)

    local bg = vgui.Create("ColoredBox", dpanel)
    bg:SetColor(Color(50, 50, 50, 255))
    bg:SetSize(w,h)
    bg:SetPos(0,0)

    local winlbl = vgui.Create("DLabel", dpanel)
    winlbl:SetFont("WinHuge")
    winlbl:SetText(T(title.txt))
    winlbl:SetTextColor(COLOR_WHITE)
    winlbl:SizeToContents()
    local xwin = (w - winlbl:GetWide())/2
    local ywin = 15
    winlbl:SetPos(xwin, ywin)

    bg.PaintOver = function()
        draw.RoundedBox(8, xwin - 15, ywin - 5, winlbl:GetWide() + 30, winlbl:GetTall() + 10, title.c)
    end

    local ysubwin = ywin + winlbl:GetTall()
    local partlbl = vgui.Create("DLabel", dpanel)

    local plytxt = PT(numtr == 1 and "hilite_players2" or "hilite_players1",
                      {numplayers = numply, numtraitors = numtr})

    partlbl:SetText(plytxt)
    partlbl:SizeToContents()
    partlbl:SetPos(xwin, ysubwin + 8)

    local timelbl = vgui.Create("DLabel", dpanel)
    timelbl:SetText(PT("hilite_duration", {time= util.SimpleTime(roundtime, "%02i:%02i")}))
    timelbl:SizeToContents()
    timelbl:SetPos(xwin + winlbl:GetWide() - timelbl:GetWide(), ysubwin + 8)

    -- Awards
    local wa = math.Round(w * 0.9)
    local ha = h - ysubwin - 40
    local xa = (w - wa) / 2
    local ya = h - ha

    local awardp = vgui.Create("DPanel", dpanel)
    awardp:SetSize(wa, ha)
    awardp:SetPos(xa, ya)
    awardp:SetPaintBackground(false)

    -- Before we pick awards, seed the rng in a way that is the same on all
    -- clients. We can do this using the round start time. To make it a bit more
    -- random, involve the round's duration too.
    math.randomseed(self.StartTime + endtime)

    -- Attempt to generate every award, then sort the succeeded ones based on
    -- priority/interestingness
    local award_choices = {}
    for _, afn in pairs(AWARDS) do
        local a = afn(self.Events, self.Scores, self.Players, self.InnocentIDs, self.TraitorIDs, self.DetectiveIDs, self.JesterIDs, self.SwapperIDs, self.GlitchIDs, self.PhantomIDs, self.HypnotistIDs, self.RevengerIDs, self.DrunkIDs, self.ClownIDs, self.DeputyIDs, self.ImpersonatorIDs, self.BeggarIDs, self.OldManIDs)
        if ValidAward(a) then
            table.insert(award_choices, a)
        end
    end

    local max_awards = 5

    -- sort descending by priority
    table.SortByMember(award_choices, "priority")

    -- put the N most interesting awards in the menu
    for i=1,max_awards do
        local a = award_choices[i]
        if a then
            self:AddAward((i - 1) * 42, wa, a, awardp)
        end
    end
end

function CLSCORE:ShowPanel()
    local dpanel = vgui.Create("DFrame")
    local w, h = 750, 580
    local margin = 15
    dpanel:SetSize(w, h)
    dpanel:Center()
    dpanel:SetTitle("Round Report")
    dpanel:SetVisible(true)
    dpanel:ShowCloseButton(true)
    dpanel:SetMouseInputEnabled(true)
    dpanel:SetKeyboardInputEnabled(true)
    dpanel.OnKeyCodePressed = util.BasicKeyHandler

    function dpanel:Think()
        self:MoveToFront()
    end

    -- keep it around so we can reopen easily
    dpanel:SetDeleteOnClose(false)
    self.Panel = dpanel

    local dbut = vgui.Create("DButton", dpanel)
    local bw, bh = 100, 25
    dbut:SetSize(bw, bh)
    dbut:SetPos(w - bw - margin, h - bh - margin/2)
    dbut:SetText(T("close"))
    dbut.DoClick = function() dpanel:Close() end

    local dsave = vgui.Create("DButton", dpanel)
    dsave:SetSize(bw, bh)
    dsave:SetPos(margin, h - bh - margin/2)
    dsave:SetText(T("report_save"))
    dsave:SetTooltip(T("report_save_tip"))
    dsave:SetConsoleCommand("ttt_save_events")

    local dtabsheet = vgui.Create("DPropertySheet", dpanel)
    dtabsheet:SetPos(margin, margin + 15)
    dtabsheet:SetSize(w - margin*2, h - margin*3 - bh)
    local padding = dtabsheet:GetPadding()

    -- Summary tab
    local dtabsummary = vgui.Create("DPanel", dtabsheet)
    dtabsummary:SetPaintBackground(false)
    dtabsummary:StretchToParent(padding, padding, padding, padding)
    self:BuildSummaryPanel(dtabsummary)

    dtabsheet:AddSheet(T("report_tab_summary"), dtabsummary, "icon16/book_open.png", false, false, T("report_tab_summary_tip"))

    -- Highlight tab
    local dtabhilite = vgui.Create("DPanel", dtabsheet)
    dtabhilite:SetPaintBackground(false)
    dtabhilite:StretchToParent(padding, padding, padding, padding)
    self:BuildHilitePanel(dtabhilite)

    dtabsheet:AddSheet(T("report_tab_hilite"), dtabhilite, "icon16/star.png", false, false, T("report_tab_hilite_tip"))

    -- Event log tab
    local dtabevents = vgui.Create("DPanel", dtabsheet)
    dtabevents:StretchToParent(padding, padding, padding, padding)
    self:BuildEventLogPanel(dtabevents)

    dtabsheet:AddSheet(T("report_tab_events"), dtabevents, "icon16/application_view_detail.png", false, false, T("report_tab_events_tip"))

    -- Score tab
    local dtabscores = vgui.Create("DPanel", dtabsheet)
    dtabscores:SetPaintBackground(false)
    dtabscores:StretchToParent(padding, padding, padding, padding)
    self:BuildScorePanel(dtabscores)

    dtabsheet:AddSheet(T("report_tab_scores"), dtabscores, "icon16/user.png", false, false, T("report_tab_scores_tip"))

    dpanel:MakePopup()

    -- makepopup grabs keyboard, whereas we only need mouse
    dpanel:SetKeyboardInputEnabled(false)
end

function CLSCORE:ClearPanel()

    if IsValid(self.Panel) then
        -- move the mouse off any tooltips and then remove the panel next tick

        -- we need this hack as opposed to just calling Remove because gmod does
        -- not offer a means of killing the tooltip, and doesn't clean it up
        -- properly on Remove
        input.SetCursorPos(ScrW() / 2, ScrH() / 2)
        local pnl = self.Panel
        timer.Simple(0, function() if IsValid(pnl) then pnl:Remove() end end)
    end
end

function CLSCORE:SaveLog()
    if self.Events and #self.Events <= 0 then
        chat.AddText(COLOR_WHITE, T("report_save_error"))
        return
    end

    local logdir = "ttt/logs"
    if not file.IsDir(logdir, "DATA") then
        file.CreateDir(logdir)
    end

    local logname = logdir .. "/ttt_events_" .. os.time() .. ".txt"
    local log = "Trouble in Terrorist Town - Round Events Log\n" .. string.rep("-", 50) .. "\n"

    log = log .. string.format("%s | %-25s | %s\n", " TIME", "TYPE", "WHAT HAPPENED") .. string.rep("-", 50) .. "\n"

    for _, e in pairs(self.Events) do
        local etxt = self:TextForEvent(e)
        local etime = self:TimeForEvent(e)
        local _, etype = self:IconForEvent(e)
        if etxt then
            log = log .. string.format("%s | %-25s | %s\n", etime, etype, etxt)
        end
    end

    file.Write(logname, log)

    chat.AddText(COLOR_WHITE, T("report_save_result"), COLOR_GREEN, " /garrysmod/data/" .. logname)
end

function CLSCORE:Reset()
    self.Events = {}
    self.InnocentIDs = {}
    self.TraitorIDs = {}
    self.DetectiveIDs = {}
    self.JesterIDs = {}
    self.SwapperIDs = {}
    self.GlitchIDs = {}
    self.PhantomIDs = {}
    self.HypnotistIDs = {}
    self.RevengerIDs = {}
    self.DrunkIDs = {}
    self.ClownIDs = {}
    self.DeputyIDs = {}
    self.ImpersonatorIDs = {}
    self.BeggarIDs = {}
    self.OldManIDs = {}
    self.Scores = {}
    self.Players = {}
    self.RoundStarted = 0

    self:ClearPanel()
end

function CLSCORE:Init(events)
    -- Get start time, traitors, detectives, scores, and nicks
    local starttime = 0
    local innocents, traitors, detectives, jesters, swappers, glitches, phantoms, hypnotists, revengers, drunks, clowns, deputies, impersonators, beggars, oldmen
    local scores, nicks = {}, {}

    local game, selected, spawn = false, false, false
    for i = 1, #events do
        local e = events[i]
        if e.id == EVENT_GAME then
            if e.state == ROUND_ACTIVE then
                starttime = e.t

                if selected and spawn then
                    break
                end

                game = true
            end
        elseif e.id == EVENT_SELECTED then
            innocents = e.innocent_ids
            traitors = e.traitor_ids
            detectives = e.detective_ids
            jesters = e.jester_ids
            swappers = e.swapper_ids
            glitches = e.glitch_ids
            phantoms = e.phantom_ids
            hypnotists = e.hypnotist_ids
            revengers = e.revenger_ids
            drunks = e.drunk_ids
            clowns = e.clown_ids
            deputies = e.deputy_ids
            impersonators = e.impersonator_ids
            beggars = e.beggar_ids
            oldmen = e.old_man_ids

            if game and spawn then
                break
            end

            selected = true
        elseif e.id == EVENT_SPAWN then
            scores[e.sid64] = ScoreInit()
            nicks[e.sid64] = e.ni

            if game and selected then
                break
            end

            spawn = true
        end
    end

    if traitors == nil then traitors = {} end
    if detectives == nil then detectives = {} end

    scores = ScoreEventLog(events, scores, innocents, traitors, detectives, jesters, swappers, glitches, phantoms, hypnotists, revengers, drunks, clowns, deputies, impersonators, beggars, oldmen)

    self.Players = nicks
    self.Scores = scores
    self.InnocentIDs = innocents
    self.TraitorIDs = traitors
    self.DetectiveIDs = detectives
    self.JesterIDs = jesters
    self.SwapperIDs = swappers
    self.GlitchIDs = glitches
    self.PhantomIDs = phantoms
    self.HypnotistIDs = hypnotists
    self.RevengerIDs = revengers
    self.DrunkIDs = drunks
    self.ClownIDs = clowns
    self.DeputyIDs = deputies
    self.ImpersonatorIDs = impersonators
    self.BeggarIDs = beggars
    self.OldManIDs = oldmen
    self.StartTime = starttime
    self.Events = events
end

function CLSCORE:ReportEvents(events)
    self:Reset()

    self:Init(events)
    self:ShowPanel()
end

function CLSCORE:Toggle()
    if IsValid(self.Panel) then
        self.Panel:ToggleVisible()
    end
end

local function SortEvents(a, b)
    return a.t < b.t
end

local buff = ""
net.Receive("TTT_ReportStream_Part", function()
    buff = buff .. net.ReadData(CLSCORE.MaxStreamLength)
end)

net.Receive("TTT_ReportStream", function()
    local events = util.Decompress(buff .. net.ReadData(net.ReadUInt(16)))
    buff = ""

    if events == "" then
        ErrorNoHalt("Round report decompression failed!\n")
    end

    events = util.JSONToTable(events)
    if events == nil then
        ErrorNoHalt("Round report decoding failed!\n")
    end

    table.sort(events, SortEvents)
    CLSCORE:ReportEvents(events)
end)

concommand.Add("ttt_save_events", function()
    CLSCORE:SaveLog()
end)