include("bot_util.lua")
include("bot_nav.lua")
include("bot_combat.lua")
include("bot_think.lua")

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
		nextShot = 0,
		strafeDir = 1,
		strafeFlip = 0,
		shootGate = 0,
		nextJump = 0
	}
end

function SND.Bots.EnsureCount()
	local want = SND.Settings.GetInt("bot_count", 0)
	local have = 0
	for _, p in ipairs(player.GetAll()) do if p.SND_IsBot then have = have + 1 end end
	
	if have < want then
		local bot = player.CreateNextBot("[BOT] SND_" .. math.random(1000, 9999))
		if IsValid(bot) then
			bot.SND_IsBot = true
			bot:SetNWBool("SND_IsBot", true)
			bot.SND_AI = newAI()
			
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

print("[SND] Modular Bot System Loaded.")