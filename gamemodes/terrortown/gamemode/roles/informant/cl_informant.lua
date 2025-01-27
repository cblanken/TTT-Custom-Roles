local hook = hook
local string = string

local StringUpper = string.upper

------------------
-- TRANSLATIONS --
------------------

hook.Add("Initialize", "Informant_Translations_Initialize", function()
    -- Weapons
    LANG.AddToLanguage("english", "infscanner_help_pri", "Look at a player to start scanning.")
    LANG.AddToLanguage("english", "infscanner_help_sec", "Keep light of sight or you will lose your target.")
    LANG.AddToLanguage("english", "infscanner_team", "TEAM")
    LANG.AddToLanguage("english", "infscanner_role", "ROLE")
    LANG.AddToLanguage("english", "infscanner_track", "TRACK")

    -- Popup
    LANG.AddToLanguage("english", "info_popup_informant", [[You are {role}! {comrades}

Hold out your scanner while looking at a player to learn more about them.

Press {menukey} to receive your special equipment!]])
end)

---------------
-- TARGET ID --
---------------

local function GetTeamRole(ply)
    local glitchMode = GetGlobalInt("ttt_glitch_mode", GLITCH_SHOW_AS_TRAITOR)

    if ply:IsGlitch() then
        if glitchMode == GLITCH_SHOW_AS_TRAITOR or glitchMode == GLITCH_HIDE_SPECIAL_TRAITOR_ROLES then
            return ROLE_TRAITOR
        elseif glitchMode == GLITCH_SHOW_AS_SPECIAL_TRAITOR then
            return ply:GetNWInt("GlitchBluff", ROLE_TRAITOR)
        end
    elseif ply:IsTraitorTeam() then
        if glitchMode == GLITCH_SHOW_AS_TRAITOR or glitchMode == GLITCH_HIDE_SPECIAL_TRAITOR_ROLES then
            return ROLE_TRAITOR
        elseif glitchMode == GLITCH_SHOW_AS_SPECIAL_TRAITOR then
            return ply:GetRole()
        end
    elseif ply:IsDetectiveTeam() then return ROLE_DETECTIVE
    elseif ply:IsInnocentTeam() then return ROLE_INNOCENT
    elseif ply:IsIndependentTeam() then return ROLE_DRUNK
    elseif ply:IsJesterTeam() then return ROLE_JESTER
    elseif ply:IsMonsterTeam() then return ply:GetRole() end
end

hook.Add("TTTTargetIDPlayerRoleIcon", "Informant_TTTTargetIDPlayerRoleIcon", function(ply, cli, role, noz, colorRole, hideBeggar, showJester, hideBodysnatcher)
    if GetRoundState() < ROUND_ACTIVE then return end

    local override, _, _ = cli:IsTargetIDOverridden(ply, showJester)
    if override then return end

    local state = ply:GetNWInt("TTTInformantScanStage", INFORMANT_UNSCANNED)
    if state <= INFORMANT_UNSCANNED then return end

    if cli:IsInformant() or (cli:IsTraitorTeam() and GetGlobalBool("ttt_informant_share_scans", true)) then
        local newRole = role
        local newNoZ = noZ
        local newColorRole = colorRole

        if state >= INFORMANT_SCANNED_TEAM then
            newColorRole = GetTeamRole(ply)
            newRole = ROLE_NONE
        end

        if state >= INFORMANT_SCANNED_ROLE then
            newColorRole = ply:GetRole()
            newRole = ply:GetRole()
        end

        if state == INFORMANT_SCANNED_TRACKED then
            newNoZ = true
        end

        return newRole, newNoZ, newColorRole
    end
end)

hook.Add("TTTTargetIDPlayerRing", "Informant_TTTTargetIDPlayerRing", function(ent, cli, ringVisible)
    if GetRoundState() < ROUND_ACTIVE then return end
    if not IsPlayer(ent) then return end

    local _, override, _ = cli:IsTargetIDOverridden(ent)
    if override then return end

    local state = ent:GetNWInt("TTTInformantScanStage", INFORMANT_UNSCANNED)
    if state <= INFORMANT_UNSCANNED then return end

    if cli:IsInformant() or (cli:IsTraitorTeam() and GetGlobalBool("ttt_informant_share_scans", true)) then
        local newRingVisible = ringVisible
        local newColor = false

        if state == INFORMANT_SCANNED_TEAM then
            newColor = ROLE_COLORS_RADAR[GetTeamRole(ent)]
            newRingVisible = true
        elseif state >= INFORMANT_SCANNED_ROLE then
            newColor = ROLE_COLORS_RADAR[ent:GetRole()]
            newRingVisible = true
        end

        return newRingVisible, newColor
    end
end)

hook.Add("TTTTargetIDPlayerText", "Informant_TTTTargetIDPlayerText", function(ent, cli, text, col, secondaryText)
    if GetRoundState() < ROUND_ACTIVE then return end
    if not IsPlayer(ent) then return end

    local _, _, override = cli:IsTargetIDOverridden(ent)
    if override then return end

    local state = ent:GetNWInt("TTTInformantScanStage", INFORMANT_UNSCANNED)
    if state <= INFORMANT_UNSCANNED then return end

    if cli:IsInformant() or (cli:IsTraitorTeam() and GetGlobalBool("ttt_informant_share_scans", true)) then
        local newText = text
        local newColor = col

        if state == INFORMANT_SCANNED_TEAM then
            local T = LANG.GetTranslation
            local PT = LANG.GetParamTranslation
            local role = GetTeamRole(ent)
            newColor = ROLE_COLORS_RADAR[role]

            local labelName = "target_unknown_team"
            local labelParam

            if TRAITOR_ROLES[role] then
                local glitchMode = GetGlobalInt("ttt_glitch_mode", GLITCH_SHOW_AS_TRAITOR)
                if glitchMode == GLITCH_SHOW_AS_TRAITOR or glitchMode == GLITCH_HIDE_SPECIAL_TRAITOR_ROLES then
                    labelParam = T("traitor")
                elseif glitchMode == GLITCH_SHOW_AS_SPECIAL_TRAITOR then
                    labelName = "target_unconfirmed_role"
                    labelParam = ROLE_STRINGS[role]
                end
            elseif DETECTIVE_ROLES[role] then labelParam = ROLE_STRINGS[ROLE_DETECTIVE]
            elseif INNOCENT_ROLES[role] then labelParam = T("innocent")
            elseif INDEPENDENT_ROLES[role] then labelParam = T("independent")
            elseif JESTER_ROLES[role] then labelParam = T("jester")
            elseif MONSTER_ROLES[role] then labelParam = T("monster") end

            if not (TRAITOR_ROLES[role] and not GetGlobalBool("ttt_glitch_round", false)) then
                newText = PT(labelName, { targettype = StringUpper(labelParam) })
            end
        elseif state >= INFORMANT_SCANNED_ROLE then
            newColor = ROLE_COLORS_RADAR[ent:GetRole()]
            newText = StringUpper(ROLE_STRINGS[ent:GetRole()])
        end

        return newText, newColor, false
    end
end)

----------------
-- SCOREBOARD --
----------------

hook.Add("TTTScoreboardPlayerRole", "Informant_TTTScoreboardPlayerRole", function(ply, cli, c, roleStr)
    if GetRoundState() < ROUND_ACTIVE then return end

    local _, override = cli:IsScoreboardInfoOverridden(ply)
    if override then return end

    local state = ply:GetNWInt("TTTInformantScanStage", INFORMANT_UNSCANNED)
    if state <= INFORMANT_UNSCANNED then return end

    if IsPlayer(ply) and cli:IsInformant() or (cli:IsTraitorTeam() and GetGlobalBool("ttt_informant_share_scans", true)) then
        local newColor = c
        local newRoleStr = roleStr

        if state == INFORMANT_SCANNED_TEAM then
            newColor = ROLE_COLORS_SCOREBOARD[GetTeamRole(ply)]
            newRoleStr = "nil"
        elseif state >= INFORMANT_SCANNED_ROLE then
            newColor = ROLE_COLORS_SCOREBOARD[ply:GetRole()]
            newRoleStr = ROLE_STRINGS_SHORT[ply:GetRole()]
        end

        return newColor, newRoleStr
    end
end)

-----------------
-- SCANNER HUD --
-----------------

local function DrawStructure(ply, x, y, w, h, m, color)
    local r, g, b, a = color:Unpack()
    surface.SetDrawColor(r, g, b, a)
    surface.DrawCircle(x, ScrH() / 2, math.Round(ScrW() / 6), r, g, b, 77)

    surface.DrawOutlinedRect(x - m - (3 * w) / 2, y - h, w, h)
    surface.DrawOutlinedRect(x - w / 2, y - h, w, h)
    surface.DrawOutlinedRect(x + m + w / 2, y - h, w, h)

    surface.SetFont("TabLarge")
    surface.SetTextColor(255, 255, 255, 180)
    surface.SetTextPos((x - m - (3 * w) / 2) + 3, y - h - 15)
    surface.DrawText(ply:GetNWString("TTTInformantScannerMessage", ""))

    local T = LANG.GetTranslation
    surface.SetTextPos((x - m - (3 * w) / 2) +  (w / 3), y - h + 3)
    surface.DrawText(T("infscanner_team"))

    surface.SetTextPos((x - m - (3 * w) / 2) + w + (w / 2) - 3, y - h + 3)
    surface.DrawText(T("infscanner_role"))

    surface.SetTextPos((x - m - (3 * w) / 2) + (2 * w) + (w / 2), y - h + 3)
    surface.DrawText(T("infscanner_track"))
end

hook.Add("HUDPaint", "Informant_HUDPaint", function()
    local ply = LocalPlayer()

    if not IsValid(ply) or ply:IsSpec() or GetRoundState() ~= ROUND_ACTIVE then return end

    if ply:IsInformant() and (not GetGlobalBool("ttt_informant_requires_scanner", false) or (ply.GetActiveWeapon and IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() == "weapon_inf_scanner")) then

        local state = ply:GetNWInt("TTTInformantScannerState", INFORMANT_SCANNER_IDLE)

        if state == INFORMANT_SCANNER_IDLE then
            surface.DrawCircle(ScrW() / 2, ScrH() / 2, math.Round(ScrW() / 6), 0, 255, 0, 155)
            return
        end

        local scan = GetGlobalInt("ttt_informant_scanner_time", 8)
        local time = ply:GetNWFloat("TTTInformantScannerStartTime", -1) + scan

        local x = ScrW() / 2.0
        local y = ScrH() / 2.0

        y = y + (y / 3)

        local w, h = 100, 20
        local m = 10

        if state == INFORMANT_SCANNER_LOCKED or state == INFORMANT_SCANNER_SEARCHING then
            if time < 0 then return end

            local color = Color(255, 255, 0, 155)
            if state == INFORMANT_SCANNER_LOCKED then
                color = Color(0, 255, 0, 155)
            end

            DrawStructure(ply, x, y, w, h, m, color)

            local target = player.GetBySteamID64(ply:GetNWString("TTTInformantScannerTarget", ""))
            local targetState = target:GetNWInt("TTTInformantScanStage", INFORMANT_UNSCANNED)

            local cc = math.min(1, 1 - ((time - CurTime()) / scan))
            if targetState == INFORMANT_UNSCANNED then
                surface.DrawRect(x - m - (3 * w) / 2, y - h, w * cc, h)
            elseif targetState == INFORMANT_SCANNED_TEAM then
                surface.DrawRect(x - m - (3 * w) / 2, y - h, w, h)
                surface.DrawRect(x - w / 2, y - h, w * cc, h)
            elseif targetState == INFORMANT_SCANNED_ROLE then
                surface.DrawRect(x - m - (3 * w) / 2, y - h, w, h)
                surface.DrawRect(x - w / 2, y - h, w, h)
                surface.DrawRect(x + m + w / 2, y - h, w * cc, h)
            end
        elseif state == INFORMANT_SCANNER_LOST then
            local color = Color(200 + math.sin(CurTime() * 32) * 50, 0, 0, 155)
            DrawStructure(ply, x, y, w, h, m, color)

            surface.DrawRect(x - m - (3 * w) / 2, y - h, w, h)
            surface.DrawRect(x - w / 2, y - h, w, h)
            surface.DrawRect(x + m + w / 2, y - h, w, h)
        end
    end
end)

--------------
-- TUTORIAL --
--------------

hook.Add("TTTTutorialRoleText", "Informant_TTTTutorialRoleText", function(role, titleLabel)
    if role == ROLE_INFORMANT then
        local roleColor = ROLE_COLORS[ROLE_TRAITOR]
        local jesterColor = ROLE_COLORS[ROLE_JESTER]
        local glitchColor = ROLE_COLORS[ROLE_GLITCH]
        local html = "The " .. ROLE_STRINGS[ROLE_INFORMANT] .. " is a member of the <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>traitor team</span> whose goal is to learn more about their enemies using their <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>scanner</span>."

        local scanJesters = GetGlobalBool("ttt_informant_can_scan_jesters", false)
        local scanGlitches = GetGlobalBool("ttt_informant_can_scan_glitches", false)
        if not (scanJesters and scanGlitches) then
            html = html .. "<span style='display: block; margin-top: 10px;'>You cannot scan "
            if not scanJesters then
                html = html .. "<span style='color: rgb(" .. jesterColor.r .. ", " .. jesterColor.g .. ", " .. jesterColor.b .. ")'>jesters</span>"
            end
            if not scanJesters and not scanGlitches then
                html = html .. " or "
            end
            if not scanGlitches then
                html = html .. "<span style='color: rgb(" .. glitchColor.r .. ", " .. glitchColor.g .. ", " .. glitchColor.b .. ")'>glitches</span>"
            end
            html = html .. ".</span>"
        end

        if GetGlobalBool("ttt_informant_share_scans", false) then
            html = html .. "<span style='display: block; margin-top: 10px;'>Information you discover is automatically shared with fellow <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>traitors</span>.</span>"
        end

        return html
    end
end)