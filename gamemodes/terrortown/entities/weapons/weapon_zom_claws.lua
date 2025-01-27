AddCSLuaFile()

local IsValid = IsValid
local math = math
local util = util

if CLIENT then
    SWEP.PrintName = "Claws"
    SWEP.EquipMenuData = {
        type = "Weapon",
        desc = "Left click to attack. Right click to leap. Press reload to spit."
    };

    SWEP.Slot = 8 -- add 1 to get the slot number key
    SWEP.ViewModelFOV = 54
    SWEP.ViewModelFlip = false
end

SWEP.InLoadoutFor = { ROLE_ZOMBIE }

SWEP.Base = "weapon_tttbase"
SWEP.Category = WEAPON_CATEGORY_ROLE

SWEP.HoldType = "fist"

SWEP.ViewModel = Model("models/weapons/c_arms_cstrike.mdl")
SWEP.WorldModel = ""

SWEP.HitDistance = 250

SWEP.Primary.Damage = 65
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.7

SWEP.Secondary.ClipSize = 5
SWEP.Secondary.DefaultClip = 5
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 2

SWEP.Tertiary = {}
SWEP.Tertiary.Damage = 25
SWEP.Tertiary.NumShots = SWEP.Primary.NumShots
SWEP.Tertiary.Recoil = 5
SWEP.Tertiary.Cone = 0.02
SWEP.Tertiary.Delay = 3

SWEP.Kind = WEAPON_ROLE

SWEP.AllowDrop = false
SWEP.IsSilent = false

SWEP.NextReload = CurTime()

-- Pull out faster than standard guns
SWEP.DeploySpeed = 2
local sound_single = Sound("Weapon_Crowbar.Single")

if SERVER then
    CreateConVar("ttt_zombie_leap_enable", "1")
    CreateConVar("ttt_zombie_spit_enable", "1")

    CreateConVar("ttt_zombie_prime_convert_chance", "1", FCVAR_NONE, "The chance that a prime zombie (e.g. player who spawned as a zombie originally) will convert other players who are killed by their claws to be zombies as well. Set to 0 to disable", 0, 1)
    CreateConVar("ttt_zombie_thrall_convert_chance", "1", FCVAR_NONE, "The chance that a zombie thrall (e.g. non-prime zombie) will convert other players who are killed by their claws to be zombies as well. Set to 0 to disable", 0, 1)

    CreateConVar("ttt_zombie_prime_attack_damage", "65", FCVAR_NONE, "The amount of a damage a prime zombie (e.g. player who spawned as a zombie originally) does with their claws. Server or round must be restarted for changes to take effect", 1, 100)
    CreateConVar("ttt_zombie_thrall_attack_damage", "45", FCVAR_NONE, "The amount of a damage a zombie thrall (e.g. non-prime zombie) does with their claws. Server or round must be restarted for changes to take effect", 1, 100)
    CreateConVar("ttt_zombie_prime_attack_delay", "0.7", FCVAR_NONE, "The amount of time between claw attacks for a prime zombie (e.g. player who spawned as a zombie originally). Server or round must be restarted for changes to take effect", 0.1, 3)
    CreateConVar("ttt_zombie_thrall_attack_delay", "1.4", FCVAR_NONE, "The amount of time between claw attacks for a zombie thrall (e.g. non-prime zombie). Server or round must be restarted for changes to take effect", 0.1, 3)
end

function SWEP:Initialize()
    if SERVER then
        SetGlobalInt("ttt_zombie_prime_attack_damage", GetConVar("ttt_zombie_prime_attack_damage"):GetInt())
        SetGlobalInt("ttt_zombie_thrall_attack_damage", GetConVar("ttt_zombie_thrall_attack_damage"):GetInt())
        SetGlobalFloat("ttt_zombie_prime_attack_delay", GetConVar("ttt_zombie_prime_attack_delay"):GetFloat())
        SetGlobalFloat("ttt_zombie_thrall_attack_delay", GetConVar("ttt_zombie_thrall_attack_delay"):GetFloat())
        SetGlobalBool("ttt_zombie_leap_enable", GetConVar("ttt_zombie_leap_enable"):GetBool())
        SetGlobalBool("ttt_zombie_spit_enable", GetConVar("ttt_zombie_spit_enable"):GetBool())
    end

    if CLIENT then
        self:AddHUDHelp("zom_claws_help_pri", "zom_claws_help_sec", true)
    end
    return self.BaseClass.Initialize(self)
end

--[[
Claw Attack
]]

function SWEP:PlayPunchAnimation()
    local anim = "fists_right"
    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence(vm:LookupSequence(anim))
    self:GetOwner():ViewPunch(Angle( 4, 4, 0 ))
    self:GetOwner():SetAnimation(PLAYER_ATTACK1)
end

function SWEP:ShouldConvert()
    local chance = self:GetOwner():IsZombiePrime() and GetConVar("ttt_zombie_prime_convert_chance"):GetFloat() or GetConVar("ttt_zombie_thrall_convert_chance"):GetFloat()
    -- Use "less-than" so a chance of 0 really means never
    return math.random() < chance
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:PlayPunchAnimation()

    if owner.LagCompensation then -- for some reason not always true
        owner:LagCompensation(true)
    end

    local spos = owner:GetShootPos()
    local sdest = spos + (owner:GetAimVector() * 70)
    local kmins = Vector(1,1,1) * -10
    local kmaxs = Vector(1,1,1) * 10

    local tr_main = util.TraceHull({start=spos, endpos=sdest, filter=owner, mask=MASK_SHOT_HULL, mins=kmins, maxs=kmaxs})
    local hitEnt = tr_main.Entity

    self:EmitSound(sound_single)

    if IsValid(hitEnt) or tr_main.HitWorld then
        self:PlayPunchAnimation()
        self:SendWeaponAnim(ACT_VM_HITCENTER)

        if not (CLIENT and (not IsFirstTimePredicted())) then
            local edata = EffectData()
            edata:SetStart(spos)
            edata:SetOrigin(tr_main.HitPos)
            edata:SetNormal(tr_main.Normal)
            edata:SetSurfaceProp(tr_main.SurfaceProps)
            edata:SetHitBox(tr_main.HitBox)
            edata:SetEntity(hitEnt)

            if hitEnt:IsPlayer() or hitEnt:GetClass() == "prop_ragdoll" then
                util.Effect("BloodImpact", edata)
                owner:LagCompensation(false)
                owner:FireBullets({ Num = 1, Src = spos, Dir = owner:GetAimVector(), Spread = Vector(0, 0, 0), Tracer = 0, Force = 1, Damage = 0 })
            else
                util.Effect("Impact", edata)
            end
        end
    else
        self:SendWeaponAnim(ACT_VM_MISSCENTER)
    end

    if not CLIENT then
        owner:SetAnimation(PLAYER_ATTACK1)

        if IsPlayer(hitEnt) and not hitEnt:IsZombieAlly() and not hitEnt:ShouldActLikeJester() then
            if hitEnt:Health() <= self.Primary.Damage and self:ShouldConvert() then
                owner:AddCredits(1)
                LANG.Msg(owner, "credit_all", { role = ROLE_STRINGS[ROLE_ZOMBIE], num = 1 })
                hitEnt:RespawnAsZombie()
            end

            local dmg = DamageInfo()
            dmg:SetDamage(self.Primary.Damage)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(self)
            dmg:SetDamageForce(owner:GetAimVector() * 5)
            dmg:SetDamagePosition(owner:GetPos())
            dmg:SetDamageType(DMG_SLASH)

            hitEnt:DispatchTraceAttack(dmg, spos + (owner:GetAimVector() * 3), sdest)
        end
    end

    if owner.LagCompensation then
        owner:LagCompensation(false)
    end
end

--[[
Jump Attack
]]

function SWEP:SecondaryAttack()
    if SERVER then
        if not GetConVar("ttt_zombie_leap_enable"):GetBool() then return end
        local owner = self:GetOwner()
        if (not self:CanSecondaryAttack()) or owner:IsOnGround() == false then return end

        local jumpsounds = { "npc/fast_zombie/leap1.wav", "npc/zombie/zo_attack2.wav", "npc/fast_zombie/fz_alert_close1.wav", "npc/zombie/zombie_alert1.wav" }
        self.SecondaryDelay = CurTime()+10
        owner:SetVelocity(owner:GetForward() * 200 + Vector(0,0,400))
        owner:EmitSound(jumpsounds[math.random(#jumpsounds)], 100, 100)
        self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
    end
end

--[[
Spit Attack
]]

function SWEP:Reload()
    if CLIENT then return end
    if not GetConVar("ttt_zombie_spit_enable"):GetBool() then return end
    if self.NextReload > CurTime() then return end
    self.NextReload = CurTime() + self.Tertiary.Delay
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    self:CSShootBullet(self.Tertiary.Damage, self.Tertiary.Recoil, self.Tertiary.NumShots, self.Tertiary.Cone)
end

function SWEP:CSShootBullet(dmg, recoil, numbul, cone)
    numbul = numbul or 1
    cone = cone or 0.01

    local owner = self:GetOwner()
    local bullet = {}
    bullet.Attacker      = owner
    bullet.Num           = 1
    bullet.Src           = owner:GetShootPos()    -- Source
    bullet.Dir           = owner:GetAimVector()   -- Dir of bullet
    bullet.Spread        = Vector(cone, 0, 0)     -- Aim Cone
    bullet.Tracer        = 1
    bullet.TracerName    = "acidtracer"
    bullet.Force         = 55
    bullet.Damage        = dmg

    owner:FireBullets(bullet)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)     -- View model animation
    owner:MuzzleFlash()                           -- Crappy muzzle light
    owner:SetAnimation(PLAYER_ATTACK1)            -- 3rd Person Animation

    if owner:IsNPC() then return end

    -- Custom Recoil, sometimes up and sometimes down
    local recoilDirection = 1
    if math.random(2) == 1 then
        recoilDirection = -1
    end

    owner:ViewPunch(Angle(recoilDirection * recoil, 0, 0))
end

function SWEP:OnDrop()
    self:Remove()
end

function SWEP:Deploy()
    if self:GetOwner():IsZombiePrime() then
        self.Primary.Damage = GetGlobalInt("ttt_zombie_prime_attack_damage", 65)
        self.Primary.Delay = GetGlobalFloat("ttt_zombie_prime_attack_delay", 0.7)
    else
        self.Primary.Damage = GetGlobalInt("ttt_zombie_thrall_attack_damage", 45)
        self.Primary.Delay = GetGlobalFloat("ttt_zombie_thrall_attack_delay", 1.4)
    end

    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence(vm:LookupSequence("fists_draw"))
end

function SWEP:Holster(weapon)
    return true
end