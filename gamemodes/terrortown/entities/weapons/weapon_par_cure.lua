AddCSLuaFile()

local IsValid = IsValid
local math = math
local pairs = pairs
local player = player
local surface = surface
local string = string
local timer = timer
local util = util

if CLIENT then
    local GetPTranslation = LANG.GetParamTranslation
    SWEP.PrintName = "Parasite Cure"
    SWEP.Slot = 6

    SWEP.DrawCrosshair = false
    SWEP.ViewModelFOV = 54

    SWEP.EquipMenuData = {
        type =  "item_weapon",
        desc = function()
            return GetPTranslation("cure_desc", {
                parasites = string.lower(ROLE_STRINGS_PLURAL[ROLE_PARASITE])
            })
        end
    };

    SWEP.Icon = "vgui/ttt/icon_cure"
end

SWEP.Base = "weapon_tttbase"

SWEP.ViewModel = "models/weapons/c_medkit.mdl"
SWEP.WorldModel = "models/weapons/w_medkit.mdl"

SWEP.Primary.ClipSize        = -1
SWEP.Primary.DefaultClip     = -1
SWEP.Primary.Automatic       = true
SWEP.Primary.Delay           = 1
SWEP.Primary.Ammo            = "none"

SWEP.Secondary.ClipSize       = -1
SWEP.Secondary.DefaultClip    = -1
SWEP.Secondary.Automatic      = true
SWEP.Secondary.Ammo           = "none"
SWEP.Secondary.Delay          = 2

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = { ROLE_DOCTOR, ROLE_QUACK }
for role = 0, ROLE_MAX do
    if DETECTIVE_ROLES[role] then
        table.insert(SWEP.CanBuy, role)
        if not istable(DefaultEquipment[role]) then
            DefaultEquipment[role] = {}
        end
        if not table.HasValue(DefaultEquipment[role], "weapon_par_cure") then
            table.insert(DefaultEquipment[role], "weapon_par_cure")
        end
    end
end
SWEP.CanBuyDefault = table.Copy(SWEP.CanBuy)
SWEP.NoSights = true
SWEP.HoldType = "slam"

SWEP.UseHands = true
SWEP.ViewModelFlip = false
SWEP.BlockShopRandomization = true

PARASITE_CURE_KILL_NONE = 0
PARASITE_CURE_KILL_OWNER = 1
PARASITE_CURE_KILL_TARGET = 2

local DEFIB_IDLE = 0
local DEFIB_BUSY = 1
local DEFIB_ERROR = 2

local beep = Sound("buttons/button17.wav")
local hum = Sound("items/nvg_on.wav")
local cured = Sound("items/smallmedkit1.wav")

if SERVER then
    CreateConVar("ttt_parasite_cure_time", "3", FCVAR_NONE, "The amount of time (in seconds) the parasite cure takes to use", 0, 30)
end

if CLIENT then
    function SWEP:Initialize()
        self:AddHUDHelp("cure_help_pri", "cure_help_sec", true)
        return self.BaseClass.Initialize(self)
    end
end

function SWEP:SetupDataTables()
    self:NetworkVar("Int", 0, "State")
    self:NetworkVar("Int", 1, "ChargeTime")
    self:NetworkVar("Float", 0, "Begin")
    self:NetworkVar("String", 0, "Message")

    if SERVER then
        self:SetChargeTime(GetConVar("ttt_parasite_cure_time"):GetInt())
    end
end

if SERVER then
    local CureMode = CreateConVar("ttt_parasite_cure_mode", "2", FCVAR_NONE, "How to handle using a parasite cure on someone who is not infected. 0 - Kill nobody (But use up the cure), 1 - Kill the person who uses the cure, 2 - Kill the person the cure is used on", 0, 2)

    function SWEP:Reset()
        self:SetState(DEFIB_IDLE)
        self:SetBegin(-1)
        self:SetMessage('')
        self.Target = nil
    end

    function SWEP:Error(msg)
        self:SetState(DEFIB_ERROR)
        self:SetBegin(CurTime())
        self:SetMessage(msg)

        self:GetOwner():EmitSound(beep, 60, 50, 1)
        self.Target = nil

        timer.Simple(3 * 0.75, function()
            if IsValid(self) then self:Reset() end
        end)
    end

    function SWEP:DoCure(ply)
        local owner = self:GetOwner()
        if IsPlayer(ply) then
            ply:EmitSound(cured)

            if ply:GetNWBool("ParasiteInfected", false) then
                for _, v in pairs(player.GetAll()) do
                    if v:GetNWString("ParasiteInfectingTarget", "") == ply:SteamID64() then
                        ply:SetNWBool("ParasiteInfected", false)
                        v:SetNWBool("ParasiteInfecting", false)
                        v:SetNWString("ParasiteInfectingTarget", nil)
                        v:SetNWInt("ParasiteInfectionProgress", 0)
                        timer.Remove(v:Nick() .. "ParasiteInfectionProgress")
                        timer.Remove(v:Nick() .. "ParasiteInfectingSpectate")
                        v:PrintMessage(HUD_PRINTCENTER, "Your host has been cured.")
                    end
                end
            else
                local cureMode = CureMode:GetInt()
                if cureMode == PARASITE_CURE_KILL_OWNER and IsValid(owner) then
                    owner:Kill()
                elseif cureMode == PARASITE_CURE_KILL_TARGET then
                    ply:Kill()
                end
            end

            self:Remove()
        else
            if ply == owner then
                self:SetNextSecondaryFire(CurTime() + 1)
            else
                self:SetNextPrimaryFire(CurTime() + 1)
            end
        end
    end

    function SWEP:Begin(ply)
        if not IsPlayer(ply) then
            self:Error("INVALID TARGET")
            return
        end

        self:SetState(DEFIB_BUSY)
        self:SetBegin(CurTime())
        if ply == self:GetOwner() then
            self:SetMessage("CURING YOURSELF")
        else
            self:SetMessage("CURING " .. string.upper(ply:Nick()))
        end

        self:GetOwner():EmitSound(hum, 75, math.random(98, 102), 1)

        self.Target = ply
    end

    function SWEP:Think()
        if self:GetState() == DEFIB_BUSY then
            local owner = self:GetOwner()
            if self:GetBegin() + self:GetChargeTime() <= CurTime() then
                self:DoCure(self.Target)
                self:Reset()
            elseif owner == self.Target then
                if not owner:KeyDown(IN_ATTACK2) then
                    self:Error("CURE ABORTED")
                end
            elseif not owner:KeyDown(IN_ATTACK) or owner:GetEyeTrace(MASK_SHOT_HULL).Entity ~= self.Target then
                self:Error("CURE ABORTED")
            end
        end
    end

    function SWEP:PrimaryAttack()
        if self:GetState() ~= DEFIB_IDLE then return end
        if GetRoundState() ~= ROUND_ACTIVE then return end

        local owner = self:GetOwner()
        local tr = util.TraceLine({
            start = owner:GetShootPos(),
            endpos = owner:GetShootPos() + owner:GetAimVector() * 64,
            filter = owner
        })

        local ent = tr.Entity
        if IsPlayer(ent) then
            self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
            self:Begin(ent)
        end
    end

    function SWEP:SecondaryAttack()
        if self:GetState() ~= DEFIB_IDLE then return end
        if GetRoundState() ~= ROUND_ACTIVE then return end

        local owner = self:GetOwner()
        if IsPlayer(owner) then
            self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)
            self:Begin(owner)
        end
    end

    function SWEP:Equip(newowner)
        if newowner:IsTraitorTeam() then
            newowner:PrintMessage(HUD_PRINTTALK, ROLE_STRINGS[ROLE_TRAITOR] .. ", the parasite cure you are holding is real.")
        end
    end

    function SWEP:Holster()
        self:Reset()
        return true
    end
end

if CLIENT then
    function SWEP:DrawHUD()
        local state = self:GetState()
        self.BaseClass.DrawHUD(self)

        if state == DEFIB_IDLE then return end

        local charge = self:GetChargeTime()
        local time = self:GetBegin() + charge

        local x = ScrW() / 2.0
        local y = ScrH() / 2.0

        y = y + (y / 3)

        local w, h = 255, 20

        if state == DEFIB_BUSY then
            if time < 0 then return end

            local cc = math.min(1, 1 - ((time - CurTime()) / charge))

            surface.SetDrawColor(0, 255, 0, 155)

            surface.DrawOutlinedRect(x - w / 2, y - h, w, h)

            surface.DrawRect(x - w / 2, y - h, w * cc, h)

            surface.SetFont("TabLarge")
            surface.SetTextColor(255, 255, 255, 180)
            surface.SetTextPos((x - w / 2) + 3, y - h - 15)
            surface.DrawText(self:GetMessage())
        elseif state == DEFIB_ERROR then
            surface.SetDrawColor(200 + math.sin(CurTime() * 32) * 50, 0, 0, 155)

            surface.DrawOutlinedRect(x - w / 2, y - h, w, h)

            surface.DrawRect(x - w / 2, y - h, w, h)

            surface.SetFont("TabLarge")
            surface.SetTextColor(255, 255, 255, 180)
            surface.SetTextPos((x - w / 2) + 3, y - h - 15)
            surface.DrawText(self:GetMessage())
        end
    end

    function SWEP:PrimaryAttack() return false end
end

function SWEP:DryFire() return false end