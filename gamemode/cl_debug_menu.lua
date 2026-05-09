--[[ Debug Menu UI — SuperAdmin-only panel for map editing and weapon category toggles ]]

SND.DebugMenu = SND.DebugMenu or {}

local debugFrame = nil

local function closeUI()
    if IsValid(debugFrame) then debugFrame:Remove() end
    debugFrame = nil
end

function SND.OpenDebugMenu()
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:IsSuperAdmin() then return end

    closeUI()

    local sc = math.Clamp(GetConVar("snd_hud_scale"):GetFloat() or 1, 0.75, 1.5)

    local f = vgui.Create("DFrame")
    f:SetTitle("")
    f:SetSize(600 * sc, 700 * sc)
    f:Center()
    f:MakePopup()
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)
    debugFrame = f

    f.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(15, 15, 15, 245))
        surface.SetDrawColor(180, 50, 255, 255) -- Purple accent
        surface.DrawRect(0, 0, w, 3 * sc)
        draw.SimpleText("DEBUG MENU", "SND_BO3_Title", 15 * sc, 20 * sc, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local sheet = vgui.Create("DPropertySheet", f)
    sheet:Dock(FILL)
    sheet:DockMargin(5 * sc, 30 * sc, 5 * sc, 5 * sc)

    -- ── Weapon Pools Tab ──────────────────────────────────────────────────
    local weaponPnl = vgui.Create("DScrollPanel", sheet)
    weaponPnl:Dock(FILL)

    local checkboxes = {} -- Store references to checkboxes for Select All/None

    local function createWeaponCategoryCheckbox(group)
        local cv = GetConVar("snd_cat_" .. group.cid)
        local cb = vgui.Create("DCheckBoxLabel", weaponPnl)
        cb:SetText(group.name)
        cb:SetFont("SND_BO3_Team")
        cb:SetTall(30 * sc)
        cb:Dock(TOP)
        cb:DockMargin(20 * sc, 2 * sc, 10 * sc, 2 * sc)
        cb:SetValue(cv and cv:GetBool() or true)
        cb.OnChange = function(_, val)
            net.Start("SND_SetCvar")
                net.WriteString("snd_cat_" .. group.cid)
                net.WriteString(val and "1" or "0")
            net.SendToServer()

            if SND.Client.Phase == SND.PHASE_WAIT then
                chat.AddText(Color(255, 120, 0), "[SND] ", Color(255, 255, 255), "Weapon list updated. Refresh gun picker to see changes.")
            end
        end
        table.insert(checkboxes, cb)
    end

    local lastGameIcon = ""
    for _, group in ipairs(SND.Config.WeaponGroups or {}) do
        if not group.cid then continue end

        local gameName = group.name:match("^(.-):") or "MISCELLANEOUS"
        local iconPath = group.icon and ("data/snd_mwclassic/" .. group.icon) or nil

        if iconPath and iconPath ~= lastGameIcon then
            local header = vgui.Create("DPanel", weaponPnl)
            header:SetTall(36 * sc)
            header:Dock(TOP)
            header:DockMargin(5 * sc, 15 * sc, 5 * sc, 5 * sc)
            header.Paint = function(self, w, h)
                local iconMat = SND.GetIMaterial(iconPath)
                local textX = 0
                if iconMat and not iconMat:IsError() then
                    local tex = iconMat:GetTexture("$basetexture")
                    local ratio = 1
                    if tex then ratio = tex:Width() / tex:Height() end
                    local drawW = h * ratio
                    surface.SetMaterial(iconMat)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.DrawTexturedRect(0, 0, drawW, h)
                    textX = drawW + 5 * sc
                end
                draw.SimpleText(gameName:upper(), "SND_BO3_Title", textX, h/2, Color(255, 120, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            lastGameIcon = iconPath
        end

        createWeaponCategoryCheckbox(group)
    end

    local btnPanel = vgui.Create("DPanel", weaponPnl)
    btnPanel:SetTall(30 * sc)
    btnPanel:Dock(BOTTOM) -- Keep utilities at the bottom
    btnPanel:DockMargin(10 * sc, 20 * sc, 10 * sc, 10 * sc)
    btnPanel.Paint = nil

    local selectAllBtn = vgui.Create("DButton", btnPanel)
    selectAllBtn:SetText("Select All")
    selectAllBtn:SetSize(100 * sc, 25 * sc)
    selectAllBtn:SetPos(0, 0)
    selectAllBtn.DoClick = function()
        for _, cb in ipairs(checkboxes) do cb:SetValue(true) end
        chat.AddText(Color(255, 120, 0), "[SND] ", Color(255, 255, 255), "All weapon categories enabled. Refresh gun picker to see changes.")
    end

    local deselectAllBtn = vgui.Create("DButton", btnPanel)
    deselectAllBtn:SetText("Deselect All")
    deselectAllBtn:SetSize(100 * sc, 25 * sc)
    deselectAllBtn:SetPos(110 * sc, 0)
    deselectAllBtn.DoClick = function()
        for _, cb in ipairs(checkboxes) do cb:SetValue(false) end
        chat.AddText(Color(255, 120, 0), "[SND] ", Color(255, 255, 255), "All weapon categories disabled. Refresh gun picker to see changes.")
    end
    weaponPnl:AddItem(btnPanel)

    sheet:AddSheet("Weapon Pools", weaponPnl, "icon16/gun.png")

    -- ── Map Spawns Tab ────────────────────────────────────────────────────
    local spawnPnl = vgui.Create("DPanelList")
    spawnPnl:EnableVerticalScrollbar(true)
    spawnPnl:SetSpacing(5 * sc)
    spawnPnl:SetPadding(10 * sc)

    local function addButton(parent, text, command, args)
        local btn = vgui.Create("DButton", parent)
        btn:SetText(text)
        btn:SetTall(30 * sc)
        btn.DoClick = function()
            RunConsoleCommand(command, unpack(args or {}))
            surface.PlaySound("buttons/button14.wav")
        end
        parent:AddItem(btn)
    end

    local lblAddSpawns = vgui.Create("DLabel", spawnPnl)
    lblAddSpawns:SetText("Add Spawns (at your position):")
    lblAddSpawns:SetFont("SND_BO3_Team")
    lblAddSpawns:SetTall(25 * sc)
    spawnPnl:AddItem(lblAddSpawns)

    addButton(spawnPnl, "Add Attacker Spawn (F7)", "snd_spawn_add_attack")
    addButton(spawnPnl, "Add Defender Spawn (F8)", "snd_spawn_add_defend")

    local lblManageSpawns = vgui.Create("DLabel", spawnPnl)
    lblManageSpawns:SetText("Manage Spawns:")
    lblManageSpawns:SetFont("SND_BO3_Team")
    lblManageSpawns:SetTall(25 * sc)
    spawnPnl:AddItem(lblManageSpawns)

    addButton(spawnPnl, "Clear All Spawns", "snd_spawn_clear")
    addButton(spawnPnl, "Remove Nearest Spawn", "snd_spawn_remove_nearest")

    local gotoSpawnPanel = vgui.Create("DPanel", spawnPnl)
    gotoSpawnPanel:SetTall(60 * sc)
    gotoSpawnPanel.Paint = nil
    local teamEntry = vgui.Create("DTextEntry", gotoSpawnPanel)
    teamEntry:SetPos(0, 0)
    teamEntry:SetSize(100 * sc, 25 * sc)
    teamEntry:SetText("attack")
    local indexSlider = vgui.Create("DNumSlider", gotoSpawnPanel)
    indexSlider:SetPos(110 * sc, 0)
    indexSlider:SetSize(150 * sc, 25 * sc)
    indexSlider:SetText("Index")
    indexSlider:SetMinMax(1, 50)
    indexSlider:SetDecimals(0)
    indexSlider:SetValue(1)
    local gotoBtn = vgui.Create("DButton", gotoSpawnPanel)
    gotoBtn:SetPos(270 * sc, 0)
    gotoBtn:SetSize(100 * sc, 25 * sc)
    gotoBtn:SetText("Go To Spawn")
    gotoBtn.DoClick = function()
        RunConsoleCommand("snd_spawn_goto", teamEntry:GetText(), indexSlider:GetValue())
        surface.PlaySound("buttons/button14.wav")
    end
    spawnPnl:AddItem(gotoSpawnPanel)

    sheet:AddSheet("Map Spawns", spawnPnl, "icon16/group_add.png")

    -- ── Bomb Sites Tab ────────────────────────────────────────────────────
    local sitePnl = vgui.Create("DPanelList")
    sitePnl:EnableVerticalScrollbar(true)
    sitePnl:SetSpacing(5 * sc)
    sitePnl:SetPadding(10 * sc)

    local lblSetSites = vgui.Create("DLabel", sitePnl)
    lblSetSites:SetText("Set Sites (at your position):")
    lblSetSites:SetFont("SND_BO3_Team")
    lblSetSites:SetTall(25 * sc)
    sitePnl:AddItem(lblSetSites)

    addButton(sitePnl, "Set Site A (F5)", "snd_site_add", {"A"})
    addButton(sitePnl, "Set Site B (F6)", "snd_site_add", {"B"})

    local lblManageSites = vgui.Create("DLabel", sitePnl)
    lblManageSites:SetText("Manage Sites:")
    lblManageSites:SetFont("SND_BO3_Team")
    lblManageSites:SetTall(25 * sc)
    sitePnl:AddItem(lblManageSites)

    addButton(sitePnl, "Clear All Sites", "snd_site_clear")

    local gotoSitePanel = vgui.Create("DPanel", sitePnl)
    gotoSitePanel:SetTall(30 * sc)
    gotoSitePanel.Paint = nil
    local siteIDEntry = vgui.Create("DTextEntry", gotoSitePanel)
    siteIDEntry:SetPos(0, 0)
    siteIDEntry:SetSize(50 * sc, 25 * sc)
    siteIDEntry:SetText("A")
    local gotoSiteBtn = vgui.Create("DButton", gotoSitePanel)
    gotoSiteBtn:SetPos(60 * sc, 0)
    gotoSiteBtn:SetSize(100 * sc, 25 * sc)
    gotoSiteBtn:SetText("Go To Site")
    gotoSiteBtn.DoClick = function()
        RunConsoleCommand("snd_site_goto", siteIDEntry:GetText())
        surface.PlaySound("buttons/button14.wav")
    end
    sitePnl:AddItem(gotoSitePanel)

    sheet:AddSheet("Bomb Sites", sitePnl, "icon16/bomb.png")

    -- ── General Debug Tab ─────────────────────────────────────────────────
    local generalPnl = vgui.Create("DPanelList")
    generalPnl:EnableVerticalScrollbar(true)
    generalPnl:SetSpacing(5 * sc)
    generalPnl:SetPadding(10 * sc)

    local debugModeCV = GetConVar("snd_debug_mode")
    local debugModeCB = vgui.Create("DCheckBoxLabel")
    debugModeCB:SetText("Enable Debug Mode (F4)")
    debugModeCB:SetFont("SND_BO3_Team")
    debugModeCB:SetTall(30 * sc)
    debugModeCB:SetValue(debugModeCV and debugModeCV:GetBool() or false)
    debugModeCB.OnChange = function(_, val)
        RunConsoleCommand("snd_debug_toggle") -- This concommand handles sv_cheats and phase changes
        surface.PlaySound("buttons/button14.wav")
    end
    generalPnl:AddItem(debugModeCB)

    local noclipBtn = vgui.Create("DButton", generalPnl)
    noclipBtn:SetText("Toggle Noclip")
    noclipBtn:SetTall(30 * sc)
    noclipBtn.DoClick = function()
        RunConsoleCommand("snd_noclip")
        surface.PlaySound("buttons/button14.wav")
    end
    generalPnl:AddItem(noclipBtn)

    local lblBotDebug = vgui.Create("DLabel", generalPnl)
    lblBotDebug:SetText("Bot Debug:")
    lblBotDebug:SetFont("SND_BO3_Team")
    lblBotDebug:SetTall(25 * sc)
    generalPnl:AddItem(lblBotDebug)

    local botDebugPathsCV = GetConVar("snd_bot_debug_paths")
    local botDebugPathsCB = vgui.Create("DCheckBoxLabel")
    botDebugPathsCB:SetText("Visualize Bot Paths")
    botDebugPathsCB:SetFont("SND_BO3_Team")
    botDebugPathsCB:SetTall(30 * sc)
    botDebugPathsCB:SetValue(botDebugPathsCV and botDebugPathsCV:GetBool() or false)
    botDebugPathsCB.OnChange = function(_, val)
        net.Start("SND_SetCvar")
            net.WriteString("snd_bot_debug_paths")
            net.WriteString(val and "1" or "0")
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end
    generalPnl:AddItem(botDebugPathsCB)

    sheet:AddSheet("General Debug", generalPnl, "icon16/bug.png")

    -- ── Map File Tab ──────────────────────────────────────────────────────
    local filePnl = vgui.Create("DPanelList")
    filePnl:EnableVerticalScrollbar(true)
    filePnl:SetSpacing(10 * sc)
    filePnl:SetPadding(10 * sc)

    local lblFile = vgui.Create("DLabel", filePnl)
    lblFile:SetText("MANAGE CONFIGURATION FILE")
    lblFile:SetFont("SND_BO3_Title")
    lblFile:SetTextColor(Color(255, 120, 0))
    lblFile:SetTall(30 * sc)
    filePnl:AddItem(lblFile)

    local lblDesc = vgui.Create("DLabel", filePnl)
    lblDesc:SetText("Spawn and site changes are now kept in memory until manually saved.\nUse the buttons below to commit your changes to JSON or discard them.")
    lblDesc:SetFont("SND_BO3_Team")
    lblDesc:SetAutoStretchVertical(true)
    lblDesc:SetTextColor(Color(200, 200, 200))
    filePnl:AddItem(lblDesc)

    local saveBtn = vgui.Create("DButton", filePnl)
    saveBtn:SetText("SAVE TO DISK (Overwrites JSON)")
    saveBtn:SetTall(40 * sc)
    saveBtn.DoClick = function()
        RunConsoleCommand("snd_map_save")
        surface.PlaySound("buttons/button14.wav")
    end
    filePnl:AddItem(saveBtn)

    local reloadBtn = vgui.Create("DButton", filePnl)
    reloadBtn:SetText("RELOAD FROM DISK (Discards unsaved)")
    reloadBtn:SetTall(40 * sc)
    reloadBtn.DoClick = function()
        Derma_Query("Discard all unsaved changes and reload from the JSON file?", "Reload Map Data", "Yes, Reload", function()
            RunConsoleCommand("snd_map_reload")
        end, "Cancel")
        surface.PlaySound("buttons/button14.wav")
    end
    filePnl:AddItem(reloadBtn)

    sheet:AddSheet("Map File", filePnl, "icon16/disk.png")
end

concommand.Add("snd_open_debug_menu", function()
    SND.OpenDebugMenu()
end)

print("[SND] Debug Menu UI Loaded")