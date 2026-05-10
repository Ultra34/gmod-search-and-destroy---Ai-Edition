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

		local bot = player.CreateNextBot("[BOT] " .. string.sub(rawName, 1, 25))
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

print("[SND] Modular Bot System Loaded.")