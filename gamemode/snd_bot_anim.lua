--[[ CSS player model animation fix for bots AND human players
--[[ 
    SND Bot Animation Overhaul (Merged Professional Edition)
    Purpose: Standardize CSS player model animations for NextBots and Humans.
    Fixes: T-Posing, Floating Guns, Sliding movement.
]]

-- ── 1. Shared Activity Translation ───────────────────────────────────────
-- This hook maps generic movement activities to weapon-specific activities.
hook.Add("TranslateActivity", "SND_BotAnimTranslate", function(ply, act)
    if not IsValid(ply) or not ply:Alive() or act == nil then return end

    local model = ply:GetModel() or ""
    local isCSS = string.find(model, "models/player/ct_", 1, true) ~= nil or string.find(model, "models/player/t_", 1, true) ~= nil
    if not isCSS then return end

    local wep = ply:GetActiveWeapon()
    
    if IsValid(wep) and wep.TranslateActivity then
        local translated = wep:TranslateActivity(act)
        if translated and translated != -1 then return translated end
    end

    -- Priority 2: CSS Native Activity Mapping
    -- This maps standard multiplayer activities to the specific sequences CSS models possess.
    local t = {
        [ACT_MP_STAND_IDLE]   = ACT_IDLE,
        [ACT_MP_WALK]         = ACT_WALK,
        [ACT_MP_RUN]          = ACT_RUN,
        [ACT_MP_CROUCHWALK]   = ACT_WALK,
        [ACT_MP_CROUCH_IDLE]  = ACT_IDLE,
        [ACT_MP_JUMP]         = ACT_JUMP,
        [ACT_MP_JUMP_START]   = ACT_JUMP,
        [ACT_MP_JUMP_FLOAT]   = ACT_GLIDE,
        [ACT_MP_JUMP_LAND]    = ACT_LAND,
        -- HL2MP hold-type activities -> base equivalents
        [ACT_HL2MP_IDLE]             = ACT_IDLE,
        [ACT_HL2MP_RUN]              = ACT_RUN,
        [ACT_HL2MP_WALK]             = ACT_WALK,
        [ACT_HL2MP_IDLE_PISTOL]      = ACT_IDLE,
        [ACT_HL2MP_RUN_PISTOL]       = ACT_RUN,
        [ACT_HL2MP_WALK_PISTOL]      = ACT_WALK,
        [ACT_HL2MP_IDLE_SMG1]        = ACT_IDLE,
        [ACT_HL2MP_RUN_SMG1]         = ACT_RUN,
        [ACT_HL2MP_WALK_SMG1]        = ACT_WALK,
        [ACT_HL2MP_IDLE_AR2]         = ACT_IDLE,
        [ACT_HL2MP_RUN_AR2]          = ACT_RUN,
        [ACT_HL2MP_WALK_AR2]         = ACT_WALK,
        [ACT_HL2MP_IDLE_SHOTGUN]     = ACT_IDLE,
        [ACT_HL2MP_RUN_SHOTGUN]      = ACT_RUN,
        [ACT_HL2MP_WALK_SHOTGUN]     = ACT_WALK,
    }

    return t[act] or act
end)

-- ── 2. Shared Main Activity Logic ────────────────────────────────────────
-- This hook tells the engine which generic state the player is in.
hook.Add("CalcMainActivity", "SND_SharedCalcActivity", function(ply, velocity)
    if not IsValid(ply) or not ply:Alive() then return end

    local speed = velocity:Length2D()
    local onGround = ply:IsOnGround()

    if not onGround then
        return ACT_MP_JUMP, -1
    end

    if ply:Crouching() or ply:GetNWBool("SND_BotCrouching", false) then
        return (speed < 10) and ACT_MP_CROUCH_IDLE or ACT_MP_CROUCHWALK, -1
    end

    if speed < 10 then
        return ACT_MP_STAND_IDLE, -1
    elseif speed < 150 then
        return ACT_MP_WALK, -1
    else
        return ACT_MP_RUN, -1
    end
end)

-- ── 3. Authoritative Pose Parameters (Server & Client) ───────────────────
-- This ensures guns aren't floating by aligning the arms with the eyes.
local function updatePoseParams(ply, velocity)
    local speed = velocity:Length()
    local eye   = ply:EyeAngles()
    local body  = ply:GetAngles()

    -- 8-Way Movement
    if speed > 10 then
        ply:SetPoseParameter("move_x", (velocity:Dot(ply:GetForward()) / speed))
        ply:SetPoseParameter("move_y", (velocity:Dot(ply:GetRight()) / speed) * -1)
        
        -- Foot alignment: Direction of movement relative to where we look
        local moveYaw = math.NormalizeAngle(velocity:Angle().y - eye.y)
        ply:SetPoseParameter("move_yaw", moveYaw)
    end

    -- Aim Alignment (Fixes Floating Guns & Hand Positioning)
    local pitch = math.NormalizeAngle(eye.p)
    local yaw   = math.NormalizeAngle(eye.y - body.y)

    ply:SetPoseParameter("aim_pitch", pitch)
    ply:SetPoseParameter("aim_yaw", yaw)
    
    -- Body pitch (Upper body tilt)
    ply:SetPoseParameter("body_pitch", math.Clamp(pitch, -60, 60))
    
    -- Head Tracking
    ply:SetPoseParameter("head_pitch", math.Clamp(pitch, -45, 45))
    ply:SetPoseParameter("head_yaw", math.Clamp(yaw, -60, 60))
    
    -- Procedural Leaning / Stability
    local sideSpeed = velocity:Dot(ply:GetRight())
    ply:SetPoseParameter("body_yaw", Lerp(FrameTime() * 5, ply:GetPoseParameter("body_yaw") or 0, (sideSpeed / 350) * 25))
end

if SERVER then
    hook.Add("Think", "SND_ServerBotAnims", function()
        for _, bot in ipairs(player.GetAll()) do
            if not bot.SND_IsBot or not bot:Alive() then continue end

            local vel = bot:GetVelocity()
            if vel:Length2D() > 5 then
                -- Force the physics body to rotate with movement
                bot:SetAngles(Angle(0, bot:EyeAngles().y, 0))
            end

            updatePoseParams(bot, vel)
        end
    end)
end

-- ── 4. Client Animation Updates ──────────────────────────────────────────
if CLIENT then
    hook.Add("UpdateAnimation", "SND_ClientBotAnims", function(ply, velocity, maxSeqGroundSpeed)
        if not IsValid(ply) or not ply:Alive() then return end

        local isBot = ply:IsBot() or ply:GetNWBool("SND_IsBot", false)
        
        -- Manually drive frame advance for bots (Prevents T-Pose/Sliding)
        if isBot then
            ply:FrameAdvance(FrameTime())
            local speed = velocity:Length2D()
            local rate  = (speed > 10) and math.Clamp(speed / maxSeqGroundSpeed, 0.2, 2) or 1
            ply:SetPlaybackRate(rate)
        end

        updatePoseParams(ply, velocity)
    end)
end

-- ── 5. Gesture Support (Flinching/Firing) ────────────────────────────────
if SERVER then
    hook.Add("EntityTakeDamage", "SND_BotDamageAnims", function(target, dmg)
        if not IsValid(target) or not target.SND_IsBot or not target:Alive() then return end
        
        if not target.SND_NextFlinch or CurTime() > target.SND_NextFlinch then
            target:AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_PHYSICS, true)
            target.SND_NextFlinch = CurTime() + 0.8
        end
    end)
end

-- ── 6. Weapon Refresh Fix ────────────────────────────────────────────────
if SERVER then
    hook.Add("PlayerSpawn", "SND_BotWeaponRefresh", function(ply)
        if not ply.SND_IsBot then return end
        timer.Simple(0.25, function()
            if not IsValid(ply) or not ply:Alive() then return end
            local weps = ply:GetWeapons()
            if #weps >= 2 then
                ply:SelectWeapon(weps[2]:GetClass())
                timer.Simple(0.1, function() if IsValid(ply) then ply:SelectWeapon(weps[1]:GetClass()) end end)
            end
        end)
    end)
end

print("[SND] Bot Animation System Rewrite Loaded")
