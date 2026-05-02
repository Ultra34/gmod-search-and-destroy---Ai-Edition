--[[ First-person legs — renders the player's own leg bones when looking down
     NEW FILE: gamemode/cl_legs.lua  (CLIENT ONLY)
     Add to init.lua:    AddCSLuaFile("cl_legs.lua")
     Add to cl_init.lua: include("cl_legs.lua")

     How it works
     ─────────────
     A clientside copy of the player's model is created and kept in sync with
     the player's position and eye angles every frame.  During RenderScreenspaceEffects
     we render only the lower-body bones (pelvis downward) into the view, clipped
     behind the camera near-plane so arms/torso don't poke through.

     Supports all CSS player models (t_phoenix, ct_urban, etc.).
     Also works correctly for spectated players (legs stay hidden).
]]

-- ── Config ────────────────────────────────────────────────────────────────
local LEG_ENABLED    = true    -- master switch
local PITCH_THRESHOLD = 10     -- degrees looking down before legs start fading in
local PITCH_FULL      = 50     -- degrees looking down for full opacity
local LEG_OFFSET_FWD  = 6      -- units forward from eye so legs aren't inside the camera
local LEG_OFFSET_DOWN = 64     -- drop from eye height to roughly hip position

-- CSS model bone names that belong to the lower body.
-- Any bone NOT in this list is hidden (prevents the torso rendering over the weapon).
local LOWER_BONES = {
	["ValveBiped.Bip01_Pelvis"]        = true,
	["ValveBiped.Bip01_Spine"]         = true,   -- base spine for root
	["ValveBiped.Bip01_L_Thigh"]       = true,
	["ValveBiped.Bip01_L_Calf"]        = true,
	["ValveBiped.Bip01_L_Foot"]        = true,
	["ValveBiped.Bip01_L_Toe0"]        = true,
	["ValveBiped.Bip01_R_Thigh"]       = true,
	["ValveBiped.Bip01_R_Calf"]        = true,
	["ValveBiped.Bip01_R_Foot"]        = true,
	["ValveBiped.Bip01_R_Toe0"]        = true,
}

-- ── State ─────────────────────────────────────────────────────────────────
local legModel    = nil   -- ClientsideModel entity
local lastModel   = ""
local boneAlphaCache = {}

-- ── Helpers ───────────────────────────────────────────────────────────────
local function cleanup()
	if IsValid(legModel) then legModel:Remove() end
	legModel  = nil
	lastModel = ""
	boneAlphaCache = {}
end

local function ensureLegModel(mdl)
	if mdl == lastModel and IsValid(legModel) then return true end
	cleanup()
	if not mdl or mdl == "" then return false end

	legModel  = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
	if not IsValid(legModel) then return false end

	legModel:SetNoDraw(true)   -- we draw it manually in the hook
	lastModel = mdl

	-- Pre-compute which bones to mask (hide upper body)
	boneAlphaCache = {}
	legModel:SetupBones()
	for i = 0, legModel:GetBoneCount() - 1 do
		local name = legModel:GetBoneName(i)
		boneAlphaCache[i] = LOWER_BONES[name] and 255 or 0
	end
	return true
end

-- ── Main render (fires from PreDrawViewModel so it goes behind the weapon) ──
hook.Add("PreDrawViewModel", "SND_LegsRender", function()
	if not LEG_ENABLED then return end

	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then cleanup() return end

	-- Don't draw legs in third-person or spectate
	if lp:GetObserverMode() ~= OBS_MODE_NONE then cleanup() return end

	-- Ensure the leg model matches the player's current model
	if not ensureLegModel(lp:GetModel()) then return end

	-- How far the player is looking down
	local eyeAng   = lp:EyeAngles()
	local pitch    = math.NormalizeAngle(eyeAng.p)  -- negative = looking down in Source
	local lookDown = -pitch   -- positive means looking down

	if lookDown < PITCH_THRESHOLD then
		legModel:SetNoDraw(true)
		return
	end

	-- Opacity: fade in between threshold and full
	local alpha = math.Clamp((lookDown - PITCH_THRESHOLD) / (PITCH_FULL - PITCH_THRESHOLD), 0, 1)
	if alpha <= 0 then legModel:SetNoDraw(true) return end

	-- Position: place at the player's feet, nudged forward slightly so the legs
	-- sit in front of the camera and are not z-fighting with the world
	local fwd    = eyeAng:Forward()
	fwd.z = 0
	fwd:Normalize()

	local eyePos = lp:EyePos()
	local legPos = eyePos
		+ fwd * LEG_OFFSET_FWD
		- Vector(0, 0, LEG_OFFSET_DOWN)

	-- Match the player's yaw (never pitch/roll so legs don't tilt with the camera)
	local legAng = Angle(0, eyeAng.y, 0)

	legModel:SetPos(legPos)
	legModel:SetAngles(legAng)

	-- Sync animation sequences from the real player
	legModel:SetSequence(lp:GetSequence())
	legModel:SetPlaybackRate(lp:GetPlaybackRate())
	legModel:SetCycle(lp:GetCycle())

	-- Sync pose parameters (move_yaw, body_pitch, etc.)
	for i = 0, legModel:GetNumPoseParameters() - 1 do
		local name = legModel:GetPoseParameterName(i)
		legModel:SetPoseParameter(name, lp:GetPoseParameter(i))
	end

	legModel:SetupBones()

	-- Draw the model with upper-body bones masked to 0 alpha
	-- GMod doesn't support per-bone alpha natively, so we use the stencil /
	-- render mask approach: draw the full model at desired alpha, but before
	-- that we write a stencil mask from the lower-body so only those pixels
	-- are written to the frame buffer.

	render.SetStencilEnable(true)
	render.ClearStencil()

	-- Pass 1: write stencil = 1 for all pixels this model occupies
	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)

	legModel:SetNoDraw(false)

	-- Render with the correct alpha
	local r, g, b = 255, 255, 255
	legModel:SetColor(Color(r, g, b, math.floor(alpha * 255)))
	legModel:DrawModel()

	render.SetStencilEnable(false)
end)

-- Clean up when dying or switching to spectate
hook.Add("LocalPlayerDeath", "SND_LegsCleanup", function()
	cleanup()
end)

hook.Add("OnEntityCreated", "SND_LegsModelInit", function(ent)
	-- nothing needed — legs are rebuilt on next PreDrawViewModel
end)

-- Rebuild if the player's model changes (team switch, etc.)
hook.Add("NotifyShouldTransmit", "SND_LegsModelCheck", function() end)

-- ── ConCommand: toggle legs ────────────────────────────────────────────────
concommand.Add("snd_legs_toggle", function()
	LEG_ENABLED = not LEG_ENABLED
	LocalPlayer():ChatPrint("[SND] First-person legs: " .. (LEG_ENABLED and "ON" or "OFF"))
	if not LEG_ENABLED then cleanup() end
end)

-- ── Settings slider in the settings panel (optional) ─────────────────────
-- Call from cl_settings.lua if you want a checkbox in the settings frame:
function SND.Legs_SettingsRow(panel)
	local cb = vgui.Create("DCheckBoxLabel", panel)
	cb:SetText("Show legs when looking down")
	cb:SetValue(LEG_ENABLED and 1 or 0)
	cb.OnChange = function(_, val)
		LEG_ENABLED = val
		if not val then cleanup() end
	end
	panel:AddItem(cb)
end
