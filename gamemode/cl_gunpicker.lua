--[[ Gun Picker — shown during freeze time so players can choose their loadout ]]
--[[ Loadout Manager — 10-slot persistent system with Ready Up logic ]]
-- Add to init.lua:   AddCSLuaFile("cl_gunpicker.lua")
-- Add to cl_init.lua: include("cl_gunpicker.lua")

SND = SND or {}
SND.GunPicker = SND.GunPicker or {}

-- ── Friendly display names ────────────────────────────────────────────────
-- If a weapon class has no entry here the raw class name is shown instead.
local DISPLAY_NAMES = {
	-- [ARC9] Black Ops Classic (Verified)
	["arc9_bo1_ultimate_ak"] = "AK-47",
	["arc9_bo1_aug"] = "AUG",
	["arc9_bo1_xl60"] = "Enfield",
	["arc9_bo1_ultimate_ar15"] = "M16 / Commando",
	["arc9_bo1_famas"] = "FAMAS",
	["arc9_bo1_fal"] = "FAL",
	["arc9_bo1_g11"] = "G11",
	["arc9_bo1_galil"] = "Galil",
	["arc9_bo1_stoner"] = "Stoner 63",
	["arc9_bo1_m14"] = "M14",
	["arc9_bo1_kiparis"] = "Kiparis",
	["arc9_bo1_mac11"] = "MAC-11",
	["arc9_bo2_mp5"] = "MP5",
	["arc9_bo1_mpl"] = "MPL",
	["arc9_bo1_pm63"] = "PM63",
	["arc9_bo1_skorpion"] = "Skorpion",
	["arc9_bo1_spectre"] = "Spectre",
	["arc9_bo1_uzi"] = "Uzi",
	["arc9_bo1_m60"] = "M60",
	["arc9_bo2_rpd"] = "RPD",
	["arc9_bo1_hk21"] = "HK21",
	["arc9_bo1_spas12"] = "SPAS-12",
	["arc9_bo1_ithaca"] = "Ithaca 37",
	["arc9_bo1_olympia"] = "Olympia",
	["arc9_bo1_hs10"] = "HS10",
	["arc9_bo1_ks23"] = "KS-23",
	["arc9_bo1_dragunov"] = "Dragunov",
	["arc9_bo1_wa2000"] = "WA2000",
	["arc9_bo1_g3"] = "G3",
	["arc9_bo1_l96"] = "L96A1",
	["arc9_bo2_m82"] = "Barrett .50cal",
	["arc9_bo1_m1911"] = "M1911",
	["arc9_bo1_python"] = "Python",
	["arc9_bo1_makarov"] = "Makarov",
	["arc9_bo1_cz75"] = "CZ75",
	["arc9_bo1_asp"] = "ASP",
	["arc9_bo2_browninghp"] = "Browning HP",
	["arc9_bo1_m67frag"] = "M67 Frag",

	-- [ARC9] Black Ops II (arc9_bo2_*)
	["arc9_bo2_an94"] = "AN-94",
	["arc9_bo2_m27"] = "M27",
	["arc9_bo2_xm8"] = "M8A1",
	["arc9_bo2_mtar"] = "MTAR",
	["arc9_bo2_scarh"] = "SCAR-H",
	["arc9_bo2_smr"] = "SMR",
	["arc9_bo2_stg44"] = "STG-44",
	["arc9_bo2_sig556"] = "SWAT-556",
	["arc9_bo2_type95"] = "Type 25",
	["arc9_bo2_b23r"] = "B23R",
	["arc9_bo2_judge"] = "Executioner",
	["arc9_bo2_fiveseven"] = "Five-SeveN",
	["arc9_bo2_kard"] = "KAP-40",
	["arc9_bo2_c96"] = "Mauser C96",
	["arc9_bo2_nma"] = "New Model Army",
	["arc9_bo2_fnp45"] = "Tac-45",
	["arc9_bo2_qbb"] = "QBB LSW",
	["arc9_bo2_mk48"] = "Mk 48",
	["arc9_bo2_mg08"] = "MG 08/15",
	["arc9_bo2_lsat"] = "LSAT",
	["arc9_bo2_hamr"] = "HAMR",
	["arc9_bo2_ksg"] = "KSG",
	["arc9_bo2_m1216"] = "M1216",
	["arc9_bo2_r870"] = "Remington 870",
	["arc9_bo2_s12"] = "Saiga 12",
	["arc9_bo2_blundergat"] = "Blundergat",
	["arc9_bo2_ballista"] = "Ballista",
	["arc9_bo2_dsr50"] = "DSR 50",
	["arc9_bo2_svu"] = "SVU-AS",
	["arc9_bo2_xpr50"] = "XPR-50",
	["arc9_bo2_stormpsr"] = "Storm PSR",
	["arc9_bo2_scorpion"] = "Skorpion EVO",
	["arc9_bo2_peacekeeper"] = "Peacekeeper",
	["arc9_bo2_pdw57"] = "PDW-57",
	["arc9_bo2_msmc"] = "MSMC",
	["arc9_bo2_mp7"] = "MP7",
	["arc9_bo2_mp40"] = "MP40",
	["arc9_bo2_thompson"] = "M1A1 Thompson",
	["arc9_bo2_chicom"] = "Chicom CQB",
	["arc9_bo2_vector"] = "Vector K10",
	["arc9_bo2_ballistic_shield"] = "Riot Shield",
	["arc9_bo2_gau19"] = "Death Machine",
	["arc9_bo2_fhj"] = "FHJ-18 AA",
	["arc9_bo2_usrpg"] = "RPG-7",
	["arc9_bo2_seal_knife"] = "Seal Knife",
	["arc9_bo2_titus"] = "Titus-6",
	["arc9_bo2_m32"] = "War Machine",
	["arc9_bo2_raygunmk2"] = "Ray Gun Mark II",

	-- [ARC9] World at War (arc9_waw_*)
	["arc9_waw_arisaka"] = "Arisaka",
	["arc9_waw_k98k"] = "Kar98k",
	["arc9_waw_mosin"] = "Mosin-Nagant",
	["arc9_waw_springfield"] = "Springfield",
	["arc9_waw_flamethrower"] = "M2 Flamethrower",
	["arc9_waw_bazooka"] = "M1 Bazooka",
	["arc9_waw_panzerschreck"] = "Panzerschreck",
	["arc9_waw_p38"] = "Walther P38",
	["arc9_waw_tt33"] = "TT-33",
	["arc9_waw_nambu"] = "Nambu",
	["arc9_waw_m1911"] = "M1911 (WaW)",
	["arc9_waw_357"] = ".357 Magnum (WaW)",
	["arc9_waw_bar"] = "M1918 BAR",
	["arc9_waw_m1919"] = "M1919 Browning",
	["arc9_waw_dp28"] = "DP-28",
	["arc9_waw_mg42"] = "MG42",
	["arc9_waw_type99lmg"] = "Type 99 LMG",
	["arc9_waw_svt40"] = "SVT-40",
	["arc9_waw_stg44"] = "STG-44",
	["arc9_waw_ptrs41"] = "PTRS-41",
	["arc9_waw_garand"] = "M1 Garand",
	["arc9_waw_fg42"] = "FG42",
	["arc9_waw_g43"] = "Gewehr 43",
	["arc9_waw_carbine"] = "M1 Carbine",
	["arc9_waw_doublebarrel"] = "Double Barrel",
	["arc9_waw_trenchgun"] = "M1897 Trench Gun",
	["arc9_waw_mp40"] = "MP40",
	["arc9_waw_ppsh41"] = "PPSh-41",
	["arc9_waw_thompson"] = "M1A1 Thompson",
	["arc9_waw_type100"] = "Type 100",
	["arc9_bo1_raygun"] = "Ray Gun",

	-- [ARC9] CoD4 Extended (arc9_cod4e_*)
	["arc9_cod4e_ak47"] = "AK-47 (CoD4)",
	["arc9_cod4e_ak74u"] = "AK-74u (CoD4)",
	["arc9_cod4e_g3"] = "G3",
	["arc9_cod4e_g36c"] = "G36C",
	["arc9_cod4e_m14"] = "M14",
	["arc9_cod4e_m4m16"] = "M4A1 / M16",
	["arc9_cod4e_mp44"] = "MP44",
	["arc9_cod4e_usp"] = "USP .45",
	["arc9_cod4e_m9"] = "M9 Beretta",
	["arc9_cod4e_m1911"] = "M1911",
	["arc9_cod4e_deagle"] = "Desert Eagle",
	["arc9_cod4e_m249"] = "M249 SAW",
	["arc9_cod4e_m60"] = "M60E4",
	["arc9_cod4e_rpd"] = "RPD",
	["arc9_cod4e_m1014"] = "M1014",
	["arc9_cod4e_w1200"] = "W1200",
	["arc9_cod4e_m82"] = "Barrett .50cal",
	["arc9_cod4e_dragunov"] = "Dragunov",
	["arc9_cod4e_m40a3"] = "M40A3",
	["arc9_cod4e_r700"] = "R700",
	["arc9_cod4e_rpg7"] = "RPG-7",
	["arc9_cod4e_at4"] = "AT4",
	["arc9_cod4e_frag"] = "Frag (CoD4)",
	["arc9_cod4e_uzi"] = "Mini-Uzi",
	["arc9_cod4e_mp5"] = "MP5",
	["arc9_cod4e_p90"] = "P90",
	["arc9_cod4e_skorpion"] = "Skorpion",

	-- [ARC9] MW2 Extended (arc9_mw2e_*)
	["arc9_mw2e_acr"] = "ACR",
	["arc9_mw2e_ak47"] = "AK-47",
	["arc9_mw2e_f2000"] = "F2000",
	["arc9_mw2e_fnfal"] = "FAL",
	["arc9_mw2e_famas"] = "FAMAS",
	["arc9_mw2e_m16a4"] = "M16A4",
	["arc9_mw2e_m4a1"] = "M4A1",
	["arc9_mw2e_scarh"] = "SCAR-H",
	["arc9_mw2e_tavor"] = "TAR-21",
	["arc9_mw2e_g17"] = "Glock 17",
	["arc9_mw2e_mk23"] = "USP .45",
	["arc9_mw2e_m93r"] = "M93 Raffica",
	["arc9_mw2e_mg4"] = "MG4",
	["arc9_mw2e_m240"] = "M240",
	["arc9_mw2e_aug"] = "AUG HBAR",
	["arc9_mw2e_m1014"] = "M1014",
	["arc9_mw3e_m1887"] = "Model 1887",
	["arc9_mw2e_akimbo_1887"] = "Akimbo 1887",
	["arc9_mw2e_ranger"] = "Ranger",
	["arc9_mw2e_spas12"] = "SPAS-12",
	["arc9_mw2e_cheytac"] = "Intervention",
	["arc9_mw2e_stinger"] = "Stinger",
	["arc9_mw2e_javelin"] = "Javelin",
	["arc9_mw2e_thumper"] = "Thumper",
	["arc9_mw2e_mp5k"] = "MP5K",
	["arc9_mw2e_pp2000"] = "PP-2000",
	["arc9_mw2e_vector"] = "Vector",

	-- [ARC9] MW3 Extended (arc9_mw3e_*)
	["arc9_mw3e_acr"] = "ACR 6.8",
	["arc9_mw3e_cm901"] = "CM901",
	["arc9_mw3e_fad"] = "FAD",
	["arc9_mw3e_g36"] = "G36C",
	["arc9_mw3e_m4a1"] = "M4A1",
	["arc9_mw3e_mk14"] = "MK14 EBR",
	["arc9_mw3e_scarl"] = "SCAR-L",
	["arc9_mw3e_qbz97"] = "Type 95",
	["arc9_mw3e_m16a4"] = "M16A4",
	["arc9_mw3e_anaconda"] = ".44 Magnum",
	["arc9_mw3e_deagle"] = "Desert Eagle",
	["arc9_mw3e_fiveseven"] = "Five-SeveN",
	["arc9_mw3e_mp412"] = "MP412 Rex",
	["arc9_mw3e_p99"] = "P99",
	["arc9_mw3e_usp"] = "USP .45",
	["arc9_mw3e_pkp"] = "PKP Pecheneg",
	["arc9_mw3e_mg36"] = "MG36",
	["arc9_mw3e_mk46"] = "MK46",
	["arc9_mw3e_m60"] = "M60",
	["arc9_mw3e_l86"] = "L86 LSW",
	["arc9_mw3e_fmg9"] = "FMG9",
	["arc9_mw3e_glock"] = "G18",
	["arc9_mw3e_mp9"] = "MP9",
	["arc9_mw3e_aa12"] = "AA-12",
	["arc9_mw3e_ksg12"] = "KSG 12",
	["arc9_mw3e_striker"] = "Striker",
	["arc9_mw3e_usas12"] = "USAS-12",
	["arc9_mw3e_rsass"] = "RSASS",
	["arc9_mw3e_msr"] = "MSR",
	["arc9_mw3e_awm"] = "L118A",
	["arc9_mw3e_dragunov"] = "Dragunov",
	["arc9_mw3e_barrett"] = "Barrett .50cal",
	["arc9_mw3e_as50"] = "AS50",
	["arc9_mw3e_m320glm"] = "M320 GLM",
	["arc9_mw3e_riotshield"] = "Riot Shield",
	["arc9_mw3e_smaw"] = "SMAW",
	["arc9_mw3e_xm25"] = "XM25",
	["arc9_mw3e_ump45"] = "UMP45",
	["arc9_mw3e_pp90m1"] = "PP90M1",
	["arc9_mw3e_pm9"] = "PM-9",
	["arc9_mw3e_p90"] = "P90",
	["arc9_mw3e_mp7"] = "MP7",
	["arc9_mw3e_mp5"] = "MP5",

	-- [ARC9] Modern Warfare Classic (arc9_mw3_*)
	["arc9_mw3_acr"] = "ACR 6.8",
	["arc9_mw3_m4a1"] = "M4A1",
	["arc9_mw3_ak47"] = "AK-47 (MW3)",
	["arc9_mw3_m16"] = "M16A4",
	["arc9_mw3_scar"] = "SCAR-L",
	["arc9_mw3_g36c"] = "G36C",
	["arc9_mw3_cm901"] = "CM901",
	["arc9_mw3_fad"] = "FAD",
	["arc9_mw3_mk14"] = "MK14",
	["arc9_mw3_type95"] = "Type 95",
	["arc9_mw3_mp5"] = "MP5",
	["arc9_mw3_ump45"] = "UMP45",
	["arc9_mw3_p90"] = "P90",
	["arc9_mw3_mp7"] = "MP7",
	["arc9_mw3_ak74u"] = "AK-74u (MW3)",
	["arc9_mw3_pp90m1"] = "PP90M1",
	["arc9_mw3_pm9"] = "PM-9",
	["arc9_mw3_m60"] = "M60 (MW3)",
	["arc9_mw3_mg36"] = "MG36",
	["arc9_mw3_pkp"] = "PKP Pecheneg",
	["arc9_mw3_mk46"] = "MK46",
	["arc9_mw3_l86"] = "L86 LSW",
	["arc9_mw3_spas12"] = "SPAS-12 (MW3)",
	["arc9_mw3_striker"] = "Striker",
	["arc9_mw3_model1887"] = "Model 1887",
	["arc9_mw3_aa12"] = "AA-12",
	["arc9_mw3_usas12"] = "USAS-12",
	["arc9_mw3_ksg"] = "KSG 12",
	["arc9_mw3_msr"] = "MSR",
	["arc9_mw3_barrett"] = "Barrett .50cal",
	["arc9_mw3_l118a"] = "L118A",
	["arc9_mw3_rsass"] = "RSASS",
	["arc9_mw3_as50"] = "AS50",
	["arc9_mw3_usp"] = "USP .45",
	["arc9_mw3_p99"] = "P99",
	["arc9_mw3_magnum"] = ".44 Magnum",
	["arc9_mw3_deserteagle"] = "Desert Eagle",
	["arc9_mw3_fiveseven"] = "Five-SeveN",
	["arc9_mw3_mp412"] = "MP412 Rex",
	["arc9_mw3_glock"] = "G18",
	["arc9_mw3_fmg9"] = "FMG9",
	["arc9_mw3_riotshield"] = "Riot Shield",
}

-- Helper to get the world model for a weapon class
local function getWeaponModel(class)
	local swep = weapons.Get(class)
	return swep and swep.WorldModel or "models/weapons/w_pist_usp.mdl"
end

-- Helper to get the ARC9 icon for a weapon class
local function getWeaponIcon(class)
	local swep = weapons.Get(class)
	-- Some ARC9 packs store icons in the SWEP table, others need an instance
	-- We check the class table first as it's most reliable for the picker
	if swep and swep.Icon then return swep.Icon end
	
	-- Fallback to standard engine icon if ARC9 icon is missing
	return swep and swep.Icon
end

function SND.GunPicker.GetFriendlyName(class)
	return DISPLAY_NAMES[class] or class
end

-- ── State ─────────────────────────────────────────────────────────────────
local pickerFrame = nil
SND.GunPicker.Slots = SND.GunPicker.Slots or {}

local loadoutNameEntry = nil
local saveNameButton = nil

-- ── Open the picker panel ─────────────────────────────────────────────────
function SND.GunPicker.Open()
	if IsValid(pickerFrame) then pickerFrame:Remove() end -- Close any existing panel

	-- Strictly only allow opening during the Pre-Game phase (Waiting for players)
	local phase = SND.Client and SND.Client.Phase or SND.PHASE_WAIT
	if phase ~= SND.PHASE_WAIT then return end

	local groups = SND.GunPicker.PrimaryGroups or {}
	local secondaries = SND.GunPicker.Secondaries or {}

	local sc = math.Clamp(GetConVar("snd_hud_scale"):GetFloat() or 1, 0.75, 1.5)

	if #groups == 0 and #secondaries == 0 then
		LocalPlayer():ChatPrint("[SND] No weapon list received yet — try again in a moment.")
		return
	end

	-- ── Frame ─────────────────────────────────────────────────────────────
	local W, H = 800 * sc, 600 * sc
	local f = vgui.Create("DFrame")
	f:SetTitle("") -- Custom title drawing
	f:SetSize(W, H)
	f:Center()
	f:MakePopup()
	f:SetBackgroundBlur(true)
	f.btnMaxim:SetVisible(false) -- Hide default minimize/maximize buttons
	f.btnMinim:SetVisible(false)
	pickerFrame = f

	f.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(15, 15, 15, 250)) -- Dark background
		surface.SetDrawColor(255, 120, 0, 255) -- Orange accent line at top
		surface.DrawRect(0, 0, w, 3 * sc)
		draw.SimpleText("LOADOUT SELECTION", "SND_BO3_Title", 20 * sc, 28 * sc, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- ── 10 Slots Sidebar ──────────────────────────────────────────────────
	local sidebar = vgui.Create("DPanel", f)
	sidebar:SetWide(180 * sc)
	sidebar:Dock(LEFT)
	sidebar:DockMargin(10 * sc, 60 * sc, 5 * sc, 10 * sc) -- Adjusted margin for title and bottom buttons
	sidebar.Paint = nil

	local scrollSidebar = vgui.Create("DScrollPanel", sidebar)
	scrollSidebar:Dock(FILL)

	local content = vgui.Create("DScrollPanel", f)
	content:Dock(FILL)
	content:DockMargin(5 * sc, 60 * sc, 10 * sc, 70 * sc) -- Bottom margin increased to clear buttons
	content.Paint = nil

	local function rebuildContent()
		content:Clear() -- Clear existing content to rebuild
		
		-- Create Loadout Name Editor
		local nameEditorPanel = vgui.Create("DPanel", content)
		nameEditorPanel:SetTall(60 * sc)
		nameEditorPanel:Dock(TOP)
		nameEditorPanel:DockMargin(0, 0, 0, 10 * sc)
		nameEditorPanel.Paint = nil

		local nameLabel = vgui.Create("DLabel", nameEditorPanel)
		nameLabel:SetText("LOADOUT NAME:")
		nameLabel:SetFont("SND_BO3_Header")
		nameLabel:SetTextColor(Color(200, 200, 200))
		nameLabel:SetPos(0, 0)
		nameLabel:SetSize(120 * sc, 20 * sc)

		loadoutNameEntry = vgui.Create("DTextEntry", nameEditorPanel)
		loadoutNameEntry:SetPos(0, 25 * sc)
		loadoutNameEntry:SetWide(200 * sc)
		loadoutNameEntry:SetTall(25 * sc)
		loadoutNameEntry:SetPlaceholderText("Enter loadout name...")
		loadoutNameEntry:SetFont("DermaDefault")

		saveNameButton = vgui.Create("DButton", nameEditorPanel)
		saveNameButton:SetText("SAVE NAME")
		saveNameButton:SetFont("SND_BO3_Header")
		saveNameButton:SetTextColor(Color(255, 255, 255))
		saveNameButton:SetPos(210 * sc, 25 * sc)
		saveNameButton:SetSize(100 * sc, 25 * sc)
		saveNameButton.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and Color(255, 120, 0, 150) or Color(255, 120, 0, 100))
		end
		saveNameButton.DoClick = function()
			local slot = LocalPlayer():GetNWInt("SND_ActiveLoadoutSlot", 1)
			net.Start("SND_SaveLoadoutName")
				net.WriteUInt(slot, 4)
				net.WriteString(loadoutNameEntry:GetText())
			net.SendToServer()
			surface.PlaySound("buttons/button14.wav")
			
			-- Ensure the cache table exists before updating
			SND.GunPicker.Slots[slot] = SND.GunPicker.Slots[slot] or {}
			SND.GunPicker.Slots[slot].loadoutName = loadoutNameEntry:GetText()
			
			rebuildContent() -- Refresh sidebar buttons to show new name
		end

		-- Clear Slot Button
		local clearSlotButton = vgui.Create("DButton", nameEditorPanel)
		clearSlotButton:SetText("CLEAR SLOT")
		clearSlotButton:SetFont("SND_BO3_Header")
		clearSlotButton:SetTextColor(Color(255, 255, 255))
		clearSlotButton:SetPos(320 * sc, 25 * sc)
		clearSlotButton:SetSize(100 * sc, 25 * sc)
		clearSlotButton.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and Color(150, 50, 50, 150) or Color(120, 40, 40, 100))
		end
		clearSlotButton.DoClick = function()
			local slot = LocalPlayer():GetNWInt("SND_ActiveLoadoutSlot", 1)
			net.Start("SND_ClearLoadoutSlot")
				net.WriteUInt(slot, 4)
			net.SendToServer()
			surface.PlaySound("buttons/button19.wav") -- Error/cancel sound
		end

		local activeSlot = LocalPlayer():GetNWInt("SND_ActiveLoadoutSlot", 1)
		local data = SND.GunPicker.Slots[activeSlot] or { primary = "", secondary = "", loadoutName = "LOADOUT " .. activeSlot }
		loadoutNameEntry:SetText(data.loadoutName)

		local function createGrid(title, pool, slotKey, headerFont, headerCol, leftMargin)
			local lbl = vgui.Create("DLabel", content)
			lbl:SetText(title:upper())
			lbl:SetFont(headerFont or "SND_BO3_Header")
			lbl:SetTall(24 * sc) -- Explicit height for scaled fonts
			if headerCol then lbl:SetTextColor(headerCol) end
			lbl:Dock(TOP)
			lbl:DockMargin((leftMargin or 0) * sc + 5 * sc, 10 * sc, 0, 5 * sc)

			local grid = vgui.Create("DIconLayout", content)
			grid:Dock(TOP)
			grid:SetSpaceX(5 * sc)
			grid:SetSpaceY(5 * sc)

			for _, class in ipairs(pool) do
				local wrapper = grid:Add("DPanel") -- Add a DPanel wrapper to the layout
				wrapper:SetSize(110 * sc, 64 * sc) -- Wider slots to accommodate 2:1 weapon icons
				wrapper.Paint = function(self, w, h)
					if data[slotKey] == class then
						draw.RoundedBox(0, 0, 0, w, h, Color(255, 120, 0, 150)) -- Draw background on the wrapper
					end
				end

				local btn = vgui.Create("DButton", wrapper)
				btn:Dock(FILL)
				btn:SetText("")
				btn:SetTooltip(SND.GunPicker.GetFriendlyName(class))

				local iconMat = getWeaponIcon(class)

				btn.Paint = function(self, w, h)
					if iconMat then
						local mat = (type(iconMat) == "string") and SND.GetIMaterial(iconMat) or iconMat
						if mat and not mat:IsError() then
							surface.SetMaterial(mat)
							-- Highlight icon on hover
							surface.SetDrawColor(255, 255, 255, self:IsHovered() and 255 or 180)
							-- Draw centered with a 2:1 aspect ratio
							surface.DrawTexturedRect(5 * sc, h/2 - 25 * sc, w - 10 * sc, 50 * sc)
						end
					else
						draw.SimpleText("?", "DermaDefault", w/2, h/2, Color(100, 100, 100), 1, 1)
					end
				end

				btn.DoClick = function()
					net.Start("SND_GunPickerChoose")
						net.WriteString(slotKey)
						net.WriteString(class)
					net.SendToServer()
					
					SND.GunPicker.Slots[activeSlot] = SND.GunPicker.Slots[activeSlot] or {}
					SND.GunPicker.Slots[activeSlot][slotKey] = class
					surface.PlaySound("buttons/button14.wav")
					rebuildContent()
				end
			end

			-- Force the grid to calculate its height based on children so the ScrollPanel knows how far to scroll
			grid:InvalidateLayout(true)
			grid:SizeToChildren(false, true)
		end

		if #groups > 0 then
			local lastGame = ""
			for _, g in ipairs(groups) do
				local gameName = g.name:match("^(.-):") or "MISCELLANEOUS"
				if gameName ~= lastGame then
					local gameHeader = vgui.Create("DPanel", content)
					gameHeader:SetTall(32 * sc)
					gameHeader:Dock(TOP)
					gameHeader:DockMargin(0, 20 * sc, 0, 5 * sc)
					local currentIcon = g.icon -- Use the icon path sent from config
					gameHeader.Paint = function(self, w, h)
						local iconPath = currentIcon and ("data/snd_mwclassic/" .. currentIcon) or nil
						local iconMat = iconPath and SND.GetIMaterial(iconPath) or nil
						local textX = 0
						
						if iconMat and not iconMat:IsError() then
							local tex = iconMat:GetTexture("$basetexture")
							local ratio = 1
							if tex then
								ratio = tex:Width() / tex:Height()
							end

							local drawW = h * ratio

							surface.SetMaterial(iconMat)
							surface.SetDrawColor(255, 255, 255, 255)
							surface.DrawTexturedRect(0, 0, drawW, h)
							textX = drawW + 15 * sc
						end
						
						draw.SimpleText(gameName:upper(), "SND_BO3_Title", textX, h/2, Color(255, 120, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					end
					lastGame = gameName
				end
				
				local subHeader = g.name:match("^.-:%s*(.*)$") or g.name
				local slotKey = g.isSecondary and "secondary" or "primary"
				createGrid(subHeader, g.weapons, slotKey, "SND_BO3_Team", Color(180, 180, 180), 15 * sc)

				-- ── Separator Line ──
				local sep = vgui.Create("DPanel", content)
				sep:SetTall(20 * sc)
				sep:Dock(TOP)
				sep:DockMargin(15 * sc, 5 * sc, 10 * sc, 10 * sc)
				sep.Paint = function(self, w, h)
					surface.SetDrawColor(255, 255, 255, 15)
					surface.DrawRect(0, h/2, w, 1)
				end
			end
		end
	end

	local playerLevel = LocalPlayer():GetNWInt("SND_Level", 1)

	for i = 1, 10 do
		local slotReq = SND.Config.SlotLevels[i] or 1
		local isSlotLocked = playerLevel < slotReq

		local btn = scrollSidebar:Add("DButton")
		btn:SetText("") -- Text will be drawn in Paint function
		btn:SetTall(40 * sc)
		btn:Dock(TOP)
		btn:DockMargin(0, 0, 0, 5 * sc)

		btn.Paint = function(self, w, h)
			local active = LocalPlayer():GetNWInt("SND_ActiveLoadoutSlot", 1) == i
			local bg = active and Color(255, 120, 0, 100) or Color(255, 255, 255, 5)
			if isSlotLocked then bg = Color(50, 50, 50, 100) end

			draw.RoundedBox(0, 0, 0, w, h, bg)
			
			local customName = SND.GunPicker.Slots[i].loadoutName or "LOADOUT " .. i
			local displayName = customName
			local statusText = isSlotLocked and ("LOCKED (LVL " .. slotReq .. ")") or ""
			
			draw.SimpleText(displayName, "SND_BO3_Team", 10 * sc, isSlotLocked and 12 * sc or h/2, isSlotLocked and Color(150, 150, 150) or Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if isSlotLocked then
				draw.SimpleText(statusText, "DermaDefault", 10 * sc, 26 * sc, Color(255, 80, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			if active then 
				surface.SetDrawColor(255, 120, 0) 
				surface.DrawRect(0, 0, 4 * sc, h) 
			end
		end

		btn.DoClick = function()
			if isSlotLocked then
				surface.PlaySound("buttons/button11.wav")
				return 
			end
			net.Start("SND_SelectLoadoutSlot")
				net.WriteUInt(i, 4)
			net.SendToServer()
			surface.PlaySound("buttons/lightbutton.wav")
			timer.Simple(0.1, rebuildContent) -- Rebuild content to update name entry and weapon grids
		end
	end

	rebuildContent() -- Initial build of the content panel

	-- ── Identity Button ───────────────────────────────────────────────────
	local identity = vgui.Create("DButton", f)
	identity:SetSize(180 * sc, 40 * sc)
	identity:SetPos(W - 400 * sc, H - 55 * sc)
	identity:SetText("PLAYER IDENTITY")
	identity:SetFont("SND_BO3_Header")
	identity:SetTextColor(Color(255, 255, 255))
	identity.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and Color(60, 60, 60) or Color(40, 40, 40))
		surface.SetDrawColor(255, 255, 255, 20)
		surface.DrawOutlinedRect(0, 0, w, h, 1 * sc)
	end
	identity.DoClick = function()
		SND.OpenPersonalizationMenu()
	end

	-- ── Ready Button ──────────────────────────────────────────────────────
	local ready = vgui.Create("DButton", f)
	ready:SetSize(200 * sc, 50 * sc)
	ready:SetPos(W - 210 * sc, H - 60 * sc)
	ready:SetFont("SND_BO3_Title")
	ready:SetTextColor(Color(255, 255, 255))
	
	local currentReady = LocalPlayer():GetNWBool("SND_IsReady", false)
	ready:SetText(currentReady and "READY!" or "READY UP")

	ready.Paint = function(self, w, h)
		local rdy = LocalPlayer():GetNWBool("SND_IsReady", false)
		local col = rdy and Color(80, 220, 100) or Color(255, 120, 0)
		if self:IsHovered() then col = Color(col.r + 30, col.g + 30, col.b + 30) end
		draw.RoundedBox(0, 0, 0, w, h, col)
	end

	ready.DoClick = function()
		local newState = not LocalPlayer():GetNWBool("SND_IsReady", false)
		net.Start("SND_PlayerReady")
			net.WriteBool(newState)
		net.SendToServer()
		ready:SetText(newState and "READY!" or "READY UP")
		surface.PlaySound(newState and "buttons/button3.wav" or "buttons/button19.wav")
		
		-- Force the menu to close if we are ready and the round is in progress (Freeze or Live)
		if newState and SND.Client.Phase ~= SND.PHASE_WAIT then
			SND.GunPicker.Close()
		end
	end
end

net.Receive("SND_GunPickerOpen", function()
	local nGroups = net.ReadUInt(8)
	local groups = {}
	for i = 1, nGroups do
		local name = net.ReadString()
		local isSec = net.ReadBool()
		local icon = net.ReadString()
		local count = net.ReadUInt(8)
		local weapons = {}
		for j = 1, count do weapons[j] = net.ReadString() end
		groups[i] = { name = name, isSecondary = isSec, weapons = weapons, icon = icon }
	end

	local nSec = net.ReadUInt(8)
	local secondaries = {}
	for i = 1, nSec do secondaries[i] = net.ReadString() end

	SND.GunPicker.PrimaryGroups = groups
	SND.GunPicker.Secondaries = secondaries
	
	SND.GunPicker.Slots = {}
	for i = 1, 10 do
		SND.GunPicker.Slots[i] = {
			primary = net.ReadString(),
			secondary = net.ReadString(),
			loadoutName = net.ReadString()
		}
	end

	SND.GunPicker.Open()
end)

function SND.GunPicker.Close()
	if IsValid(pickerFrame) then
		pickerFrame:Remove()
		pickerFrame = nil
	end
end

concommand.Add("snd_gunpicker", function()
	SND.GunPicker.Open()
end)
