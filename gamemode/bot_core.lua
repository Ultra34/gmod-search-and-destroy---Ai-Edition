include("bot_util.lua")
include("bot_nav.lua")
include("bot_combat.lua")
include("bot_think.lua")

-- AI State Constants
local BS_IDLE   = 0
local BS_PATROL = 1
local BS_ENGAGE = 2
local BS_CHASE  = 3
local BS_PLANT  = 4
local BS_DEFUSE = 5
local BS_RELOAD = 6

SND.Bots.CustomNamePool = {
	"radracerdk",
	"Dezener",
	"BOIDBERG",
	"Long Long Maaaaan",
	"TTV_LoopedVibes",
	"Soap",
	"Price",
	"Ghost",
	"Gaz",
	"Roach",
	"Sandman",
	"Grinch",
	"Frost",
	"Yuri",
	"Makarov",
	"Shepherd",
	"Kamarov",
	"Nikolai",
	"Alex",
	"Farah"
}

local currentBotNames = table.Copy(SND.Bots.CustomNamePool)

hook.Add("SND_RoundStart_Freeze", "SND_ResetBotNames", function()
	currentBotNames = table.Copy(SND.Bots.CustomNamePool)
end)

local PERSONALITIES = {
	{ name="Rusher",    aggressionBias= 0.9, roamSpeedMult=1.30, holdRange=0 },
	{ name="Stalker",   aggressionBias= 0.0, roamSpeedMult=0.85, holdRange=700 },
	{ name="Camper",    aggressionBias=-0.4, roamSpeedMult=0.65, holdRange=950 },
	{ name="Tactician", aggressionBias= 0.3, roamSpeedMult=1.00, holdRange=400 },
}

local function newAI()
	return {
		state = 0,
		personality = table.Random(PERSONALITIES),
		stuckPos = Vector(0,0,0),
		nextScan = 0,
		isScanning = false,
		scanOffset = 0,
		nextPathUpdate = 0,
		lastPathGoal = Vector(0,0,0),
		stuckCheck = 0,
		stuckStartTime = 0,
		recoilPitch = 0,
		recoilYaw = 0,
		recoilLastAt = CurTime(),
		nextShot = 0,
		strafeDir = 1,
		strafeFlip = 0,
		shootGate = 0,
		nextJump = 0
	}
end

function SND.Bots.OnPlayerSpawn(ply)
	if not ply.SND_IsBot then return end
	SND.Teams.ApplyFactionModel(ply)
	ply:SetNWBool("SND_IsBot", true)
	ply.SND_AI = newAI()

	-- Force holdtype update to prevent T-posing on initial spawn for CSS rigs
	timer.Simple(0.1, function()
		if IsValid(ply) and ply:Alive() then
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) then
				ply:SetupHands()
				wep:SetHoldType(wep:GetHoldType())
			end
		end
	end)
end

function SND.Bots.EnsureCount()
	local want = SND.Settings.GetInt("bot_count", 0)
	local have = 0
	for _, p in ipairs(player.GetAll()) do if p.SND_IsBot then have = have + 1 end end
	
	for i = have + 1, want do
		local rawName = "SNDBot" .. i
		if #currentBotNames > 0 then
			local idx = math.random(#currentBotNames)
			rawName = currentBotNames[idx]
			table.remove(currentBotNames, idx)
		end

		local npcMode = SND.Settings.GetInt("bot_npc_mode", 0) == 1
		local finalName = npcMode and rawName or ("[BOT] " .. rawName)

		local bot = player.CreateNextBot(string.sub(finalName, 1, 25))
		if IsValid(bot) then
			bot.SND_IsBot = true
			bot.SND_AI = newAI()
			
			-- Forced Identity: Titles, Unified Background & Emblem
			local botTitles = {"Lone Wolf", "Shadow", "Elite", "Hunter", "Stalker", "Marksman", "Vanguard"}
			bot:SetNWString("SND_CardTitle", table.Random(botTitles))
			bot:SetNWString("SND_CardMat", SND.Config.DefaultBotBanner or "")
			bot:SetNWBool("SND_ShowTitle", true)
			bot:SetNWBool("SND_UseTitleMat", false)
			bot:SetNWString("SND_TitleMat", "")

			local botEmb = SND.Config.DefaultBotEmblem or "data/snd_mwclassic/emblems/bot_emblem.png"
			if not file.Exists(botEmb:gsub("^data/", ""), "DATA") then
				botEmb = "vgui/icon_skull" -- engine fallback
			end
			bot:SetNWString("SND_EmblemMat", botEmb)

			local a = #team.GetPlayers(SND.TEAM_ATTACK)
			local d = #team.GetPlayers(SND.TEAM_DEFEND)
			bot:SetTeam((a <= d) and SND.TEAM_ATTACK or SND.TEAM_DEFEND)
			
			bot:Spawn()
		end
	end
end

hook.Add("StartCommand", "SND_BotThinkModular", function(bot, cmd)
	if not bot.SND_IsBot or not bot:Alive() then return end
	if SND.Round.Phase == SND.PHASE_FREEZE then
		cmd:ClearButtons()
		cmd:ClearMovement()
		return
	end
	
	if not bot.SND_AI then bot.SND_AI = newAI() end
	SND.Bots.Think(bot, cmd)
end)

hook.Add("Think", "SND_BotManager", function()
	if CurTime() % 2 < 0.1 then SND.Bots.EnsureCount() end
end)

-- ── Acoustic Awareness: Reacting to footsteps and gunshots ───────────────
hook.Add("EntityEmitSound", "SND_BotHearing", function(t)
	local src = t.Entity
	if not IsValid(src) or not src:IsPlayer() or not src:Alive() then return end

	local soundPos = t.Pos or src:GetPos()
	local isGunshot = string.find(t.SoundName:lower(), "fire") or string.find(t.SoundName:lower(), "shoot")
	local isFootstep = string.find(t.SoundName:lower(), "step")

	-- Define hearing ranges
	local range = 0
	if isGunshot then range = 2500 end
	if isFootstep then range = 500 end
	if range == 0 then return end

	for _, bot in ipairs(player.GetAll()) do
		if not bot.SND_IsBot or not bot:Alive() or bot:Team() == src:Team() then continue end
		
		local ai = bot.SND_AI
		if not ai or ai.state == 2 then continue end -- 2 = BS_ENGAGE

		local dist = bot:GetPos():Distance(soundPos)
		local skill = SND.Bots.GetSkill()
		
		-- High skill bots hear better and from further away
		local modifiedRange = range * (0.5 + (SND.Bots.SkillT(skill)))

		if dist < modifiedRange then
			if not SND.Bots.CanSee(bot, src) then
				ai.lastKnownPos = soundPos
				ai.lastKnownTime = CurTime()
				-- Mark for investigation in bot_think
				ai.investigating = true
			end
		end
	end
end)

-- ── Suppression: Reacting to bullets whizzing past ──────────────────────
hook.Add("EntityFireBullets", "SND_BotSuppression", function(ent, data)
	if not IsValid(ent) or not ent:IsPlayer() then return end

	local src = data.Src
	local dir = data.Dir
	local dist = data.Distance or 4096

	for _, bot in ipairs(player.GetAll()) do
		if not bot.SND_IsBot or not bot:Alive() or bot:Team() == ent:Team() then continue end

		local ai = bot.SND_AI
		if not ai then continue end

		local botPos = bot:WorldSpaceCenter()
		local lineVec = botPos - src
		local dot = lineVec:Dot(dir)

		-- If bullet is flying towards or past the bot
		if dot > 0 and dot < dist then
			local closestPoint = src + dir * dot
			local distToBullet = closestPoint:Distance(botPos)

			if distToBullet < 80 then -- Bullet whizzed within 80 units
				ai.suppressedEnd = CurTime() + math.Rand(0.8, 2.0)
			end
		end
	end
end)

-- ── Server-Side Bot Rotation & Flinching ───────────────────────────────────
hook.Add("Think", "SND_ServerBotAnims", function()
	for _, bot in ipairs(player.GetAll()) do
		if not bot.SND_IsBot or not bot:Alive() then continue end

		local velocity = bot:GetVelocity()
		local speed = velocity:Length2D()
		local eyeYaw = bot:EyeAngles().y
		local bodyYaw = bot:GetAngles().y
		local diff = math.NormalizeAngle(eyeYaw - bodyYaw)

		-- Smoothed Snap-Threshold Rotation:
		-- Mimics human player turn-in-place behavior and prevents bone snapping.
		if speed > 10 then
			local moveAng = velocity:Angle()
			bot:SetAngles(Angle(0, moveAng.y, 0))
		elseif math.abs(diff) > 35 then 
			-- Gradually rotate the body hull if stationary to minimize torso twist
			local targetAng = Angle(0, eyeYaw - (diff > 0 and 30 or -30), 0)
			bot:SetAngles(LerpAngle(FrameTime() * 20, bot:GetAngles(), targetAng))
		end
	end
end)

hook.Add("EntityTakeDamage", "SND_BotDamageAnims", function(target, dmg)
	if not IsValid(target) or not target.SND_IsBot or not target:Alive() or not dmg then return end
	if not target.SND_NextFlinch or CurTime() > target.SND_NextFlinch then
		target:AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_PHYSICS, true)
		
		-- Use weight to scale the flinch jerk based on damage (capped at 1.0)
		local intensity = math.Clamp(dmg:GetDamage() / 50, 0.2, 1.0)
		target:SetLayerWeight(GESTURE_SLOT_FLINCH, intensity)

		target.SND_NextFlinch = CurTime() + 0.8
	end
end)

print("[SND] Modular Bot System Loaded.")