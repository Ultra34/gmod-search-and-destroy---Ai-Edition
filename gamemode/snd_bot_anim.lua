--[[
    SND Bot Animation Overhaul (v3 - T-Pose & Float Fix)
    Root fix: CalcMainActivity now returns ACT_HL2MP_* directly.
    No more silent failure from the ACT_MP_* → ACT_HL2MP_* translation chain.
]]

-- ── Helper ────────────────────────────────────────────────────────────────
local function isCSSModel(ply)
    local model = ply:GetModel() or ""
    return string.find(model, "/ct_") or string.find(model, "/t_")
end

local function isSNDBot(ply)
    return IsValid(ply) and ply:IsPlayer() and (ply.SND_IsBot == true or ply:IsBot())
end

-- ── Core: Unified CSS Activity Resolver ───────────────────────────────────
-- FIX: This is the heart of the rewrite. Instead of returning ACT_MP_* and
-- relying on TranslateActivity to remap them (which can silently fail and
-- cause T-poses), we resolve the FINAL ACT_HL2MP_* activity in one place.
-- Both CalcMainActivity (hooks) and the server Think loop use this.
local function resolveCSSActivity(ply, velocity)
    local speed = velocity:Length2D()
    local wep   = ply:GetActiveWeapon()

    -- Map hold type → animation suffix
    local holdMap = {
        pistol   = "PISTOL",   revolver = "REVOLVER", smg      = "SMG1",
        ar2      = "AR2",      shotgun  = "SHOTGUN",  rpg      = "RPG",
        melee    = "MELEE",    knife    = "KNIFE",    fist     = "FIST",
        crossbow = "CROSSBOW", physgun  = "PHYSGUN",  grenade  = "GRENADE",
    }
    local h      = IsValid(wep) and wep:GetHoldType() or "normal"
    local suffix = holdMap[h] or "AR2"

    -- FIX: Guard against nil ACT constants with explicit fallbacks at every step.
    -- A nil constant silently returns nil which the engine treats as "no sequence".
    if not ply:IsOnGround() then
        return _G["ACT_HL2MP_JUMP_" .. suffix] or ACT_HL2MP_JUMP_AR2 or ACT_JUMP
    end

    if ply:Crouching() then
        if speed < 10 then
            return _G["ACT_HL2MP_IDLE_CROUCH_" .. suffix]
                or ACT_HL2MP_IDLE_CROUCH
                or ACT_CROUCHIDLE
        else
            return _G["ACT_HL2MP_WALK_CROUCH_" .. suffix]
                or ACT_HL2MP_WALK_CROUCH
                or ACT_WALK
        end
    end

    if speed < 10 then
        return _G["ACT_HL2MP_IDLE_" .. suffix] or ACT_HL2MP_IDLE or ACT_IDLE
    elseif speed < 150 then
        return _G["ACT_HL2MP_WALK_" .. suffix] or ACT_HL2MP_WALK or ACT_WALK
    else
        return _G["ACT_HL2MP_RUN_"  .. suffix] or ACT_HL2MP_RUN  or ACT_RUN
    end
end

-- ── 1. TranslateActivity — weapon overrides only ──────────────────────────
-- FIX: This hook is now ONLY for TFA/ARC9 weapons that supply their own
-- activity. All standard movement translation was moved into resolveCSSActivity.
-- This prevents any ordering issue between the two hooks from breaking things.
hook.Add("TranslateActivity", "SND_BotAnimTranslate", function(ply, act)
    if not IsValid(ply) or not ply:Alive() or not isCSSModel(ply) then return end

    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep.TranslateActivity then
        local translated = wep:TranslateActivity(act)
        if translated and translated ~= -1 then return translated end
    end
end)

-- ── 2. CalcMainActivity — returns final HL2MP activity directly ───────────
hook.Add("CalcMainActivity", "SND_SharedCalcActivity", function(ply, velocity)
    if not IsValid(ply) or not ply:Alive() or not isCSSModel(ply) then return end
    -- Return the resolved activity with -1 for sequence (let engine look it up).
    return resolveCSSActivity(ply, velocity), -1
end)

-- ── 3. Pose Parameters ───────────────────────────────────────────────────
local function updatePoseParams(ply, velocity)
    local speed = velocity:Length()
    local eye   = ply:EyeAngles()
    local body  = ply:GetAngles()

    if speed > 10 then
        ply:SetPoseParameter("move_x",   velocity:Dot(ply:GetForward()) / speed)
        ply:SetPoseParameter("move_y",  (velocity:Dot(ply:GetRight())   / speed) * -1)
        ply:SetPoseParameter("move_yaw", math.NormalizeAngle(velocity:Angle().y - body.y))
    else
        ply:SetPoseParameter("move_x",   0)
        ply:SetPoseParameter("move_y",   0)
        ply:SetPoseParameter("move_yaw", 0)
    end

    local pitch = math.NormalizeAngle(eye.p)
    local yaw   = math.NormalizeAngle(eye.y - body.y)

    ply:SetPoseParameter("aim_pitch",  pitch)
    ply:SetPoseParameter("aim_yaw",    yaw)
    ply:SetPoseParameter("head_pitch", math.Clamp(pitch, -45, 45))
    ply:SetPoseParameter("head_yaw",   math.Clamp(yaw,   -60, 60))

    local leanTarget = (velocity:Dot(ply:GetRight()) / 350) * 25
    ply:SetPoseParameter("body_yaw",
        Lerp(FrameTime() * 5, ply:GetPoseParameter("body_yaw") or 0, leanTarget))
end

-- ── 4. Server Logic ───────────────────────────────────────────────────────
if SERVER then
    hook.Add("PlayerSpawn", "SND_SetBotNWBool", function(ply)
        if isSNDBot(ply) then ply:SetNWBool("SND_IsBot", true) end
    end)

    hook.Add("Think", "SND_ServerBotAnims", function()
        for _, bot in ipairs(player.GetAll()) do
            if not isSNDBot(bot) or not bot:Alive() then continue end

            local vel   = bot:GetVelocity()
            local speed = vel:Length2D()

            -- Align body to eye yaw while moving
            if speed > 5 then
                bot:SetAngles(Angle(0, bot:EyeAngles().y, 0))
            end

            -- FIX: Explicitly set the sequence server-side.
            -- The engine's CalcMainActivity/TranslateActivity hooks may not fire
            -- reliably for all bot types. Driving it manually here guarantees
            -- bots always have a valid sequence and never fall back to T-pose.
            local act = resolveCSSActivity(bot, vel)
            local seq = bot:SelectWeightedSequenceSeeded(act, 0)
            if seq and seq ~= -1 and bot:GetSequence() ~= seq then
                bot:SetSequence(seq)
                bot:ResetSequenceInfo()
            end

            updatePoseParams(bot, vel)
        end
    end)

    hook.Add("EntityTakeDamage", "SND_BotDamageAnims", function(target, dmg)
        if not IsValid(target) or not isSNDBot(target) or not target:Alive() then return end
        if not target.SND_NextFlinch or CurTime() > target.SND_NextFlinch then
            target:AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_PHYSICS, true)
            target.SND_NextFlinch = CurTime() + 0.8
        end
    end)

    hook.Add("PlayerSpawn", "SND_BotWeaponRefresh", function(ply)
        if not isSNDBot(ply) then return end
        timer.Simple(0.25, function()
            if not IsValid(ply) or not ply:Alive() then return end
            local weps = ply:GetWeapons()
            if #weps >= 2 then
                ply:SelectWeapon(weps[2]:GetClass())
                timer.Simple(0.1, function()
                    if IsValid(ply) then ply:SelectWeapon(weps[1]:GetClass()) end
                end)
            end
        end)
    end)
end

-- ── 5. Client Logic ───────────────────────────────────────────────────────
if CLIENT then
    hook.Add("UpdateAnimation", "SND_ClientBotAnims", function(ply, velocity, maxSeqGroundSpeed)
        if not IsValid(ply) or not ply:Alive() then return end

        if ply:IsBot() or ply:GetNWBool("SND_IsBot", false) then
            local speed = velocity:Length2D()
            ply:SetPlaybackRate(
                speed > 10
                and math.Clamp(speed / math.max(maxSeqGroundSpeed, 1), 0.2, 2)
                or 1
            )
        end

        updatePoseParams(ply, velocity)
    end)
end