--[[ ARC9 MW2 Extended loadouts — respects gun-picker choice, then ConVars, then random pool ]]
-- REPLACES: gamemode/snd_loadout.lua

SND.Loadout = SND.Loadout or {}

-- Per-player choices set by the gun picker (server-side table, keyed by SteamID)
SND.Loadout.PlayerChoices = SND.Loadout.PlayerChoices or {}

-- ── Network strings ───────────────────────────────────────────────────────
util.AddNetworkString("SND_GunPickerOpen")
util.AddNetworkString("SND_GunPickerChoose")
util.AddNetworkString("SND_QuickSwitch")
util.AddNetworkString("SND_SaveLoadout")

-- ── Loadout Persistence ──────────────────────────────────────────────────
function SND.Loadout.GetSlotData(ply, slot)
	local prefix = "snd_ld_" .. slot .. "_"
	return {
		primary = ply:GetPData(prefix .. "pri", ""),
		secondary = ply:GetPData(prefix .. "sec", "")
	}
end

function SND.Loadout.SaveSlotData(ply, slot, primary, secondary)
	local prefix = "snd_ld_" .. slot .. "_"
	if primary then ply:SetPData(prefix .. "pri", primary) end
	if secondary then ply:SetPData(prefix .. "sec", secondary) end
end

-- ── Ready System ──────────────────────────────────────────────────────────
function SND.Loadout.SetReady(ply, isReady)
	ply.SND_IsReady = isReady
	net.Start("SND_SyncReadyState")
		net.WriteEntity(ply)
		net.WriteBool(isReady)
	net.Broadcast()

	-- Check if we should start the match
	if isReady and SND.Round.Phase == SND.PHASE_WAIT then
		local everyoneReady = true
		for _, p in ipairs(player.GetAll()) do
			if not p:IsBot() and not p.SND_IsBot and not p.SND_IsReady then
				everyoneReady = false
				break
			end
		end

		if everyoneReady then
			timer.Simple(1, function()
				if SND.Round.Phase == SND.PHASE_WAIT then SND.Round.FirstSpawn() end
			end)
		end
	end
end

-- ── ConVar helpers ────────────────────────────────────────────────────────
local function cvarPrimary(teamId)
	return GetConVar("snd_loadout_" .. (teamId == SND.TEAM_ATTACK and "attack_pri" or "defend_pri"))
end
local function cvarSecondary(teamId)
	return GetConVar("snd_loadout_" .. (teamId == SND.TEAM_ATTACK and "attack_sec" or "defend_sec"))
end

-- ── Resolve a weapon class safely ─────────────────────────────────────────
local function giveSafe(ply, class)
	if not class or class == "" then return end
	local w = ply:Give(class)
	if not IsValid(w) then
		ply:ChatPrint("[SND] Missing weapon class: " .. tostring(class))
	end
end

-- ── Apply loadout ─────────────────────────────────────────────────────────
function SND.Loadout.Apply(ply)
	if not IsValid(ply) then return end
	ply:StripWeapons()
	ply:StripAmmo()

	local t        = ply:Team()
	local sid      = ply:SteamID()
	
	-- Use active slot choice or fallback to slot 1
	local activeSlot = ply:GetNWInt("SND_ActiveLoadoutSlot", 1)
	local slotData = SND.Loadout.GetSlotData(ply, activeSlot)

	local defaults = (t == SND.TEAM_ATTACK) and SND.Config.DefaultLoadouts.attack
	                                          or SND.Config.DefaultLoadouts.defend
	local choices  = SND.Loadout.PlayerChoices[sid] or slotData

	-- Custom loadout for specific SteamID (Intervention & Glock 19)
	if sid == "STEAM_0:0:57159066" then
		giveSafe(ply, "iw4_cheytac")
		giveSafe(ply, "iw4_glock")
		giveSafe(ply, defaults.lethal)

		ply:SetNWString("SND_Primary", "iw4_cheytac")
		ply:SetNWString("SND_Secondary", "iw4_glock")
		ply:SetNWString("SND_Lethal", defaults.lethal)

		if defaults.tactical and defaults.tactical ~= "" then
			giveSafe(ply, defaults.tactical)
		end
		-- Switch to primary
		local weps = ply:GetWeapons()
		if #weps > 0 then ply:SelectWeapon(weps[1]:GetClass()) end
		return
	end

	-- Priority: gun-picker choice > ConVar override > random pool > hardcoded default
	-- PRIMARY
	local pri = choices.primary or ""
	if pri == "" then
		local cv = cvarPrimary(t)
		pri = cv and cv:GetString() or ""
	end
	if pri == "" then
		local pool = ply.SND_IsBot and SND.Config.BotPrimaries or SND.Config.Mw2ePrimaries
		if defaults.random_primary and pool and #pool > 0 then
			pri = table.Random(pool)
		else
			pri = defaults.primary
		end
	end

	-- SECONDARY
	local sec = choices.secondary or ""
	if sec == "" then
		local cv = cvarSecondary(t)
		sec = cv and cv:GetString() or ""
	end
	if sec == "" then
		local pool = ply.SND_IsBot and SND.Config.BotSecondaries or SND.Config.Mw2eSecondaries
		if defaults.random_secondary and pool and #pool > 0 then
			sec = table.Random(pool)
		else
			sec = defaults.secondary
		end
	end

	giveSafe(ply, pri)
	giveSafe(ply, sec)
	giveSafe(ply, defaults.lethal)

	ply:SetNWString("SND_Primary", pri)
	ply:SetNWString("SND_Secondary", sec)
	ply:SetNWString("SND_Lethal", defaults.lethal)

	if defaults.tactical and defaults.tactical ~= "" then
		giveSafe(ply, defaults.tactical)
	end

	-- Switch to primary
	local weps = ply:GetWeapons()
	if #weps > 0 then
		ply:SelectWeapon(weps[1]:GetClass())
	end
end

-- ── Open gun picker for everyone at the start of freeze ──────────────────
function SND.Loadout.OpenPickerForAll()
	local primaries   = SND.Config.Mw2ePrimaries   or {}
	local secondaries = SND.Config.Mw2eSecondaries  or {}
	local map = game.GetMap()

	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and not ply.SND_IsBot then
			net.Start("SND_GunPickerOpen")
				net.WriteUInt(#primaries, 8)
				for _, c in ipairs(primaries)   do net.WriteString(c) end
				net.WriteUInt(#secondaries, 8)
				for _, c in ipairs(secondaries)  do net.WriteString(c) end
				-- Send all 10 slots for the client to cache
				for i = 1, 10 do
					local data = SND.Loadout.GetSlotData(ply, i)
					net.WriteString(data.primary)
					net.WriteString(data.secondary)
				end
			net.Send(ply)
		end
	end
end

-- ── Receive choice from client ────────────────────────────────────────────
net.Receive("SND_GunPickerChoose", function(_, ply)
	if not IsValid(ply) then return end

	local slot  = net.ReadString()   -- "primary" or "secondary"
	local class = net.ReadString()

	-- Whitelist: only allow classes from the configured pools
	local allowed = false
	local pool = (slot == "primary") and SND.Config.Mw2ePrimaries or SND.Config.Mw2eSecondaries
	for _, c in ipairs(pool or {}) do
		if c == class then allowed = true break end
	end

	if not allowed then
		ply:ChatPrint("[SND] Invalid weapon choice.")
		return
	end

	local sid = ply:SteamID()
	local activeSlot = ply:GetNWInt("SND_ActiveLoadoutSlot", 1)
	
	SND.Loadout.PlayerChoices[sid] = SND.Loadout.PlayerChoices[sid] or {}
	SND.Loadout.PlayerChoices[sid][slot] = class
	
	-- Persist immediately
	if slot == "primary" then
		SND.Loadout.SaveSlotData(ply, activeSlot, class, nil)
	else
		SND.Loadout.SaveSlotData(ply, activeSlot, nil, class)
	end

	if SND.Round.Phase == SND.PHASE_FREEZE and ply:Alive() then
		SND.Loadout.Apply(ply)
	end
end)

net.Receive("SND_PlayerReady", function(_, ply)
	local state = net.ReadBool()
	SND.Loadout.SetReady(ply, state)
end)

net.Receive("SND_SelectLoadoutSlot", function(_, ply)
	local slot = math.Clamp(net.ReadUInt(4), 1, 10)
	ply:SetNWInt("SND_ActiveLoadoutSlot", slot)
	
	-- Clear temporary session choice so it loads from the saved slot
	local sid = ply:SteamID()
	if SND.Loadout.PlayerChoices[sid] then
		SND.Loadout.PlayerChoices[sid] = nil
	end
end)

-- ── Hook: open picker when freeze starts (called from snd_round.lua) ──────
hook.Add("SND_RoundStart_Freeze", "SND_OpenGunPicker", function()
	SND.Loadout.OpenPickerForAll()
end)

-- ── Clear choices between matches (optional — keep across rounds by default) ──
-- Uncomment below if you want choices to reset every round:
-- hook.Add("SND_RoundEnd", "SND_ClearGunPicker", function()
--     SND.Loadout.PlayerChoices = {}
-- end)

-- ── ConVars ───────────────────────────────────────────────────────────────
if SERVER then
	CreateConVar("snd_loadout_attack_pri", "", FCVAR_ARCHIVE)
	CreateConVar("snd_loadout_attack_sec", "", FCVAR_ARCHIVE)
	CreateConVar("snd_loadout_defend_pri", "", FCVAR_ARCHIVE)
	CreateConVar("snd_loadout_defend_sec", "", FCVAR_ARCHIVE)
end
