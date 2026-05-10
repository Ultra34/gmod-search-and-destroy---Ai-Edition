--[[
    SND Bot Animation Overhaul (Fixed)
    Fixes: T-Posing, Floating Guns, Sliding movement.
]]

-- ── Helper ────────────────────────────────────────────────────────────────
local function isCSSModel(ply)
    local model = ply:GetModel() or ""
    return string.find(model, "/ct_") or string.find(model, "/t_")
end

-- FIX: Unified bot detection. Prefers the explicit flag, falls back to IsBot().
local function isSNDBot(ply)
    return ply.SND_IsBot == true or ply:IsBot()
end

-- ── 1. Shared Activity Translation ───────────────────────────────────────
hook.Add("TranslateActivity", "SND_BotAnimTranslate", function(ply, act)
    if not IsValid(ply) or not ply:Alive() or act == nil then return end
    if not isCSSModel(ply) then return end

    local wep = ply:GetActiveWeapon()

    if IsValid(wep) and wep.TranslateActivity then
        local translated = wep:TranslateActivity(act)
        if translated and translated ~= -1 then return translated end
    end

    local h = IsValid(wep) and wep:GetHoldType() or "normal"
    local holdMap = {
        ["pistol"]   = "PISTOL",   ["revolver"] = "REVOLVER", ["smg"] = "SMG1",
        ["ar2"]      = "AR2",      ["shotgun"]  = "SHOTGUN",  ["rpg"] = "RPG",
        ["melee"]    = "MELEE",    ["knife"]    = "KNIFE",    ["fist"] = "FIST",
    }
    local suffix = holdMap[h] or "AR2"

    if     act == ACT_MP_STAND_IDLE  then return _G["ACT_HL2MP_IDLE_"          .. suffix] or ACT_HL2MP_IDLE
    elseif act == ACT_MP_WALK        then return _G["ACT_HL2MP_WALK_"          .. suffix] or ACT_HL2MP_WALK
    elseif act == ACT_MP_RUN         then return _G["ACT_HL2MP_RUN_"           .. suffix] or ACT_HL2MP_RUN
    elseif act == ACT_MP_CROUCH_IDLE then return _G["ACT_HL2MP_IDLE_CROUCH_"   .. suffix] or ACT_HL2MP_IDLE_CROUCH
    elseif act == ACT_MP_CROUCHWALK  then return _G["ACT_HL2MP_WALK_CROUCH_"   .. suffix] or ACT_HL2MP_WALK_CROUCH
    elseif act == ACT_MP_JUMP        then return ACT_HL2MP_JUMP_AR2
    end

    return act
end)

-- ── 2. Shared Main Activity Logic ────────────────────────────────────────
hook.Add("CalcMainActivity", "SND_SharedCalcActivity", function(ply, velocity)
    if not IsValid(ply) or not ply:Alive() then return end
    if not isCSSModel(ply) then return end

    local speed = velocity:Length2D()

    if not ply:IsOnGround() then
        return ACT_MP_JUMP, -1
    end

    -- FIX: Removed the unreliable NWBool crouching fallback.
    -- ply:Crouching() is authoritative on both server and client.
    if ply:Crouching() then
        return (speed < 10) and ACT_MP_CROUCH_IDLE or ACT_MP_CROUCHWALK, -1
    end

    if     speed < 10  then return ACT_MP_STAND_IDLE, -1
    elseif speed < 150 then return ACT_MP_WALK, -1
    else                    return ACT_MP_RUN, -1
    end
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
        -- FIX: Explicitly zero out movement params when standing still.
        -- Without this, bots can retain stale move_x/move_y and appear to slide.
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

    local sideSpeed  = velocity:Dot(ply:GetRight())
    local leanTarget = (sideSpeed / 350) * 25
    ply:SetPoseParameter("body_yaw",
        Lerp(FrameTime() * 5, ply:GetPoseParameter("body_yaw") or 0, leanTarget))
end

-- ── 4. Server Logic ───────────────────────────────────────────────────────
if SERVER then
    -- FIX: Set the NWBool on spawn so the CLIENT can actually detect SND bots.
    hook.Add("PlayerSpawn", "SND_SetBotNWBool", function(ply)
        if isSNDBot(ply) then
            ply:SetNWBool("SND_IsBot", true)
        end
    end)

    hook.Add("Think", "SND_ServerBotAnims", function()
        for _, bot in ipairs(player.GetAll()) do
            -- FIX: Use unified isSNDBot() so bots aren't silently skipped.
            if not isSNDBot(bot) or not bot:Alive() then continue end

            local vel = bot:GetVelocity()
            if vel:Length2D() > 5 then
                bot:SetAngles(Angle(0, bot:EyeAngles().y, 0))
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
        -- FIX: Use unified isSNDBot() here too.
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

        local isBot = ply:IsBot() or ply:GetNWBool("SND_IsBot", false)

        if isBot then
            -- FIX: REMOVED ply:FrameAdvance() — the engine calls this automatically.
            -- Calling it manually inside UpdateAnimation caused double-advancing,
            -- which skipped frames and produced T-poses or frozen animations.
            local speed = velocity:Length2D()
            local rate  = (speed > 10)
                and math.Clamp(speed / math.max(maxSeqGroundSpeed, 1), 0.2, 2)
                or 1
            ply:SetPlaybackRate(rate)
        end

        updatePoseParams(ply, velocity)
    end)
end