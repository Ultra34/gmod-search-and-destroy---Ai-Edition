--[[ CSS player model animation fix for bots AND human players
--[[ 
    SND Bot Animation Overhaul 
    Purpose: Standardize CSS player model animations for NextBots and Humans.
    Fixes: T-Posing, Floating Guns, Sliding movement.
]]

-- ── 1. Shared Activity Translation ───────────────────────────────────────
-- This hook maps generic movement activities to weapon-specific activities.
hook.Add("TranslateActivity", "SND_BotAnimTranslate", function(ply, act)
    if not IsValid(ply) or not ply:Alive() then return end

    local model = ply:GetModel() or ""
    local isCSS = string.find(model, "/ct_") or string.find(model, "/t_")
    if not isCSS then return end

    local wep = ply:GetActiveWeapon()
    
    -- Priority 1: Let TFA/ARC9 Weapons define their own arm/body poses
    if IsValid(wep) and wep.TranslateActivity then
        local translated = wep:TranslateActivity(act)
        if translated and translated != -1 then return translated end
    end

    -- Priority 2: Standard HL2MP fallback mapping
    local h = IsValid(wep) and wep:GetHoldType() or "normal"
    local holdMap = {
        ["pistol"]   = "PISTOL", ["revolver"] = "REVOLVER", ["smg"] = "SMG1",
        ["ar2"]      = "AR2",    ["shotgun"]  = "SHOTGUN",  ["rpg"] = "RPG",
        ["melee"]    = "MELEE",  ["knife"]    = "KNIFE",    ["fist"] = "FIST"
    }
    local suffix = holdMap[h] or "AR2"

    if act == ACT_MP_STAND_IDLE then return _G["ACT_HL2MP_IDLE_" .. suffix] or ACT_HL2MP_IDLE
    elseif act == ACT_MP_WALK   then return _G["ACT_HL2MP_WALK_" .. suffix] or ACT_HL2MP_WALK
    elseif act == ACT_MP_RUN    then return _G["ACT_HL2MP_RUN_" .. suffix] or ACT_HL2MP_RUN
    elseif act == ACT_MP_CROUCH_IDLE then return _G["ACT_HL2MP_IDLE_CROUCH_" .. suffix] or ACT_HL2MP_IDLE_CROUCH
    elseif act == ACT_MP_CROUCHWALK then return _G["ACT_HL2MP_WALK_CROUCH_" .. suffix] or ACT_HL2MP_WALK_CROUCH
    elseif act == ACT_MP_JUMP   then return ACT_HL2MP_JUMP_AR2 end

    return act
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

    -- Aim Alignment (Fixes Floating Guns)
    local pitch = math.NormalizeAngle(eye.p)
    local yaw   = math.NormalizeAngle(eye.y - body.y)

    ply:SetPoseParameter("aim_pitch", pitch)
    ply:SetPoseParameter("aim_yaw", yaw)
    
    -- Head Tracking
    ply:SetPoseParameter("head_pitch", math.Clamp(pitch, -45, 45))
    ply:SetPoseParameter("head_yaw", math.Clamp(yaw, -60, 60))
    
    -- Procedural Leaning (Torso)
    local sideSpeed = velocity:Dot(ply:GetRight())
    ply:SetPoseParameter("body_yaw", (sideSpeed / 320) * 20)
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
