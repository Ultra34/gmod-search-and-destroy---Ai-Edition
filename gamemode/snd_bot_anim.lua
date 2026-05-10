```lua
--[[
    SND Bot Animation Overhaul (v4 - CSS + ARC9 Integration)
    Fixes:
    - T-Pose
    - Floating
    - Downward gun aim
    - Broken ARC9 gestures
    - CSS animation blending
    - Playback rate issues
    - Body yaw snapping
]]

-- ── Helper ────────────────────────────────────────────────────────────────
local function isCSSModel(ply)
    local model = string.lower(ply:GetModel() or "")

    return string.find(model, "/ct_")
        or string.find(model, "/t_")
end

local function isSNDBot(ply)
    return IsValid(ply)
        and ply:IsPlayer()
        and (ply.SND_IsBot == true or ply:IsBot())
end

-- ── CSS Weapon Activity Tables ────────────────────────────────────────────
local cssWeaponActs = {
    pistol = {
        idle   = ACT_HL2MP_IDLE_PISTOL,
        walk   = ACT_HL2MP_WALK_PISTOL,
        run    = ACT_HL2MP_RUN_PISTOL,
        crouch = ACT_HL2MP_IDLE_CROUCH_PISTOL,
        jump   = ACT_HL2MP_JUMP_PISTOL
    },

    revolver = {
        idle   = ACT_HL2MP_IDLE_REVOLVER,
        walk   = ACT_HL2MP_WALK_REVOLVER,
        run    = ACT_HL2MP_RUN_REVOLVER,
        crouch = ACT_HL2MP_IDLE_CROUCH_REVOLVER,
        jump   = ACT_HL2MP_JUMP_REVOLVER
    },

    smg = {
        idle   = ACT_HL2MP_IDLE_SMG1,
        walk   = ACT_HL2MP_WALK_SMG1,
        run    = ACT_HL2MP_RUN_SMG1,
        crouch = ACT_HL2MP_IDLE_CROUCH_SMG1,
        jump   = ACT_HL2MP_JUMP_SMG1
    },

    ar2 = {
        idle   = ACT_HL2MP_IDLE_AR2,
        walk   = ACT_HL2MP_WALK_AR2,
        run    = ACT_HL2MP_RUN_AR2,
        crouch = ACT_HL2MP_IDLE_CROUCH_AR2,
        jump   = ACT_HL2MP_JUMP_AR2
    },

    shotgun = {
        idle   = ACT_HL2MP_IDLE_SHOTGUN,
        walk   = ACT_HL2MP_WALK_SHOTGUN,
        run    = ACT_HL2MP_RUN_SHOTGUN,
        crouch = ACT_HL2MP_IDLE_CROUCH_SHOTGUN,
        jump   = ACT_HL2MP_JUMP_SHOTGUN
    },

    melee = {
        idle   = ACT_HL2MP_IDLE_MELEE,
        walk   = ACT_HL2MP_WALK_MELEE,
        run    = ACT_HL2MP_RUN_MELEE,
        crouch = ACT_HL2MP_IDLE_CROUCH_MELEE,
        jump   = ACT_HL2MP_JUMP_MELEE
    }
}

-- ── Resolve CSS Activity ──────────────────────────────────────────────────
local function resolveCSSActivity(ply, velocity)
    local speed = velocity:Length2D()

    local wep = ply:GetActiveWeapon()

    local hold = IsValid(wep)
        and wep:GetHoldType()
        or "ar2"

    local acts = cssWeaponActs[hold]
        or cssWeaponActs["ar2"]

    if not ply:IsOnGround() then
        return acts.jump or ACT_JUMP
    end

    if ply:Crouching() then
        if speed < 15 then
            return acts.crouch
        else
            return ACT_HL2MP_WALK_CROUCH
        end
    end

    if speed < 10 then
        return acts.idle
    elseif speed < 150 then
        return acts.walk
    else
        return acts.run
    end
end

-- ── TranslateActivity ─────────────────────────────────────────────────────
hook.Add("TranslateActivity", "SND_BotAnimTranslate", function(ply, act)
    if not IsValid(ply)
    or not ply:Alive()
    or not isCSSModel(ply) then
        return
    end

    -- Prevent ARC9 movement override conflicts
    if act == ACT_MP_STAND_IDLE
    or act == ACT_MP_WALK
    or act == ACT_MP_RUN
    or act == ACT_MP_CROUCH_IDLE
    or act == ACT_MP_CROUCHWALK
    or act == ACT_MP_JUMP then
        return nil
    end

    local wep = ply:GetActiveWeapon()

    if IsValid(wep)
    and wep.ARC9
    and wep.TranslateActivity then

        local translated = wep:TranslateActivity(act)

        if translated and translated ~= -1 then
            return translated
        end
    end
end)

-- ── CalcMainActivity ──────────────────────────────────────────────────────
hook.Add("CalcMainActivity", "SND_SharedCalcActivity", function(ply, velocity)
    if not IsValid(ply)
    or not ply:Alive()
    or not isCSSModel(ply) then
        return
    end

    return resolveCSSActivity(ply, velocity), -1
end)

-- ── Pose Parameters ───────────────────────────────────────────────────────
local function updatePoseParams(ply, velocity)
    local speed = velocity:Length()

    local eye = ply:EyeAngles()
    local body = ply:GetAngles()

    if speed > 10 then
        ply:SetPoseParameter(
            "move_x",
            velocity:Dot(ply:GetForward()) / speed
        )

        ply:SetPoseParameter(
            "move_y",
            (velocity:Dot(ply:GetRight()) / speed) * -1
        )

        ply:SetPoseParameter(
            "move_yaw",
            math.NormalizeAngle(
                velocity:Angle().y - body.y
            )
        )
    else
        ply:SetPoseParameter("move_x", 0)
        ply:SetPoseParameter("move_y", 0)
        ply:SetPoseParameter("move_yaw", 0)
    end

    local pitch = math.NormalizeAngle(eye.p)
    local yaw = math.NormalizeAngle(eye.y - body.y)

    ply:SetPoseParameter("aim_pitch", pitch)
    ply:SetPoseParameter("aim_yaw", yaw)

    ply:SetPoseParameter(
        "head_pitch",
        math.Clamp(pitch, -45, 45)
    )

    ply:SetPoseParameter(
        "head_yaw",
        math.Clamp(yaw, -60, 60)
    )

    local leanTarget =
        (velocity:Dot(ply:GetRight()) / 350) * 25

    ply:SetPoseParameter(
        "body_yaw",

        Lerp(
            FrameTime() * 5,
            ply:GetPoseParameter("body_yaw") or 0,
            leanTarget
        )
    )
end

-- ── SERVER ────────────────────────────────────────────────────────────────
if SERVER then

    hook.Add("PlayerSpawn", "SND_SetBotNWBool", function(ply)
        if isSNDBot(ply) then
            ply:SetNWBool("SND_IsBot", true)

            ply:SetModelScale(1, 0)
            ply:SetLaggedMovementValue(1)
        end
    end)

    -- ARC9 HoldType Fix
    hook.Add("WeaponEquip", "SND_ARC9HoldFix", function(wep, ply)
        if not IsValid(wep)
        or not wep.ARC9 then
            return
        end

        local h = wep:GetHoldType()

        if h == "rpg"
        or h == "physgun" then
            wep:SetHoldType("ar2")
        end
    end)

    -- Main Animation Think Loop
    hook.Add("Think", "SND_ServerBotAnims", function()

        for _, bot in ipairs(player.GetAll()) do

            if not isSNDBot(bot)
            or not bot:Alive() then
                continue
            end

            local vel = bot:GetVelocity()
            local speed = vel:Length2D()

            -- Smooth body turning
            if speed > 5 then

                local ang = bot:GetAngles()

                ang.y = LerpAngle(
                    FrameTime() * 5,
                    ang,
                    Angle(0, bot:EyeAngles().y, 0)
                ).y

                bot:SetAngles(Angle(0, ang.y, 0))
            end

            -- Sequence Resolve
            local act = resolveCSSActivity(bot, vel)

            local seq = bot:SelectWeightedSequenceSeeded(act, 0)

            if seq
            and seq ~= -1
            and bot:GetSequence() ~= seq then

                bot:SetSequence(seq)
                bot:ResetSequenceInfo()
            end

            -- ARC9 Gesture Support
            local wep = bot:GetActiveWeapon()

            if IsValid(wep)
            and wep.ARC9 then

                if wep:GetNextPrimaryFire() > CurTime() then
                    bot:AddGesture(
                        ACT_HL2MP_GESTURE_RANGE_ATTACK_AR2
                    )
                end
            end

            updatePoseParams(bot, vel)
        end
    end)

    -- Damage Flinch
    hook.Add("EntityTakeDamage", "SND_BotDamageAnims", function(target)

        if not IsValid(target)
        or not isSNDBot(target)
        or not target:Alive() then
            return
        end

        if not target.SND_NextFlinch
        or CurTime() > target.SND_NextFlinch then

            target:AnimRestartGesture(
                GESTURE_SLOT_FLINCH,
                ACT_FLINCH_PHYSICS,
                true
            )

            target.SND_NextFlinch = CurTime() + 0.8
        end
    end)

    -- Weapon Refresh
    hook.Add("PlayerSpawn", "SND_BotWeaponRefresh", function(ply)

        if not isSNDBot(ply) then return end

        timer.Simple(0.25, function()

            if not IsValid(ply)
            or not ply:Alive() then
                return
            end

            local weps = ply:GetWeapons()

            if #weps >= 2 then

                ply:SelectWeapon(weps[2]:GetClass())

                timer.Simple(0.1, function()

                    if IsValid(ply) then
                        ply:SelectWeapon(
                            weps[1]:GetClass()
                        )
                    end
                end)
            end
        end)
    end)
end

-- ── CLIENT ────────────────────────────────────────────────────────────────
if CLIENT then

    hook.Add("UpdateAnimation", "SND_ClientBotAnims",
    function(ply, velocity, maxSeqGroundSpeed)

        if not IsValid(ply)
        or not ply:Alive() then
            return
        end

        if ply:IsBot()
        or ply:GetNWBool("SND_IsBot", false) then

            local speed = velocity:Length2D()

            local rate = math.Clamp(
                speed / math.max(maxSeqGroundSpeed, 1),
                0.8,
                1.4
            )

            if speed < 10 then
                rate = 1
            end

            ply:SetPlaybackRate(rate)
        end

        updatePoseParams(ply, velocity)
    end)

end
```
