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

    local f = vgui.Create("DFrame")
    f:SetTitle("")
    f:SetSize(600, 700)
    f:Center()
    f:MakePopup()
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)
    debugFrame = f

    f.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(15, 15, 15, 245))
        surface.SetDrawColor(180, 50, 255, 255) -- Purple accent
        surface.DrawRect(0, 0, w, 3)
        draw.SimpleText("DEBUG MENU", "SND_BO3_Title", 15, 20, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local sheet = vgui.Create("DPropertySheet", f)
    sheet:Dock(FILL)
    sheet:DockMargin(5, 30, 5, 5)

    -- ── Weapon Pools Tab ──────────────────────────────────────────────────
    local weaponPnl = vgui.Create("DPanelList")
    weaponPnl:EnableVerticalScrollbar(true)
    weaponPnl:SetSpacing(5)
    weaponPnl:SetPadding(10)

    local checkboxes = {} -- Store references to checkboxes for Select All/None

    local function createWeaponCategoryCheckbox(group)
        local cv = GetConVar("snd_cat_" .. group.cid)
        local cb = vgui.Create("DCheckBoxLabel")
        cb:SetText(group.name)
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
        weaponPnl:AddItem(cb)
        table.insert(checkboxes, cb)
    end

    local lastGameIcon = ""
    for _, group in ipairs(SND.Config.WeaponGroups or {}) do
        if not group.cid then continue end

        local gameName = group.name:match("^(.-):") or "MISCELLANEOUS"
        local iconPath = group.icon and ("game_icons/" .. group.icon) or nil

        if iconPath and iconPath ~= lastGameIcon then
            local header = vgui.Create("DPanel", weaponPnl)
            header:SetTall(24)
            header:Dock(TOP)
            header:DockMargin(0, 10, 0, 5)
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
                    textX = drawW + 5
                end
                draw.SimpleText(gameName:upper(), "SND_BO3_Header", textX, h/2, Color(255, 120, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            weaponPnl:AddItem(header)
            lastGameIcon = iconPath
        end

        createWeaponCategoryCheckbox(group)
    end

    local btnPanel = vgui.Create("DPanel", weaponPnl)
    btnPanel:SetTall(30)
    btnPanel:Dock(TOP)
    btnPanel:DockMargin(0, 10, 0, 0)
    btnPanel.Paint = nil

    local selectAllBtn = vgui.Create("DButton", btnPanel)
    selectAllBtn:SetText("Select All")
    selectAllBtn:SetSize(100, 25)
    selectAllBtn:SetPos(0, 0)
    selectAllBtn.DoClick = function()
        for _, cb in ipairs(checkboxes) do cb:SetValue(true) end
        chat.AddText(Color(255, 120, 0), "[SND] ", Color(255, 255, 255), "All weapon categories enabled. Refresh gun picker to see changes.")
    end

    local deselectAllBtn = vgui.Create("DButton", btnPanel)
    deselectAllBtn:SetText("Deselect All")
    deselectAllBtn:SetSize(100, 25)
    deselectAllBtn:SetPos(110, 0)
    deselectAllBtn.DoClick = function()
        for _, cb in ipairs(checkboxes) do cb:SetValue(false) end
        chat.AddText(Color(255, 120, 0), "[SND] ", Color(255, 255, 255), "All weapon categories disabled. Refresh gun picker to see changes.")
    end
    weaponPnl:AddItem(btnPanel)

    sheet:AddSheet("Weapon Pools", weaponPnl, "icon16/gun.png")

    -- ── Map Spawns Tab ────────────────────────────────────────────────────
    local spawnPnl = vgui.Create("DPanelList")
    spawnPnl:EnableVerticalScrollbar(true)
    spawnPnl:SetSpacing(5)
    spawnPnl:SetPadding(10)

    local function addButton(parent, text, command, args)
        local btn = vgui.Create("DButton", parent)
        btn:SetText(text)
        btn:SetTall(30)
        btn.DoClick = function()
            RunConsoleCommand(command, unpack(args or {}))
            surface.PlaySound("buttons/button14.wav")
        end
        parent:AddItem(btn)
    end

    spawnPnl:AddItem(vgui.Create("DLabel", spawnPnl)):SetText("Add Spawns (at your position):")
    addButton(spawnPnl, "Add Attacker Spawn (F7)", "snd_spawn_add_attack")
    addButton(spawnPnl, "Add Defender Spawn (F8)", "snd_spawn_add_defend")

    spawnPnl:AddItem(vgui.Create("DLabel", spawnPnl)):SetText("Manage Spawns:")
    addButton(spawnPnl, "Clear All Spawns", "snd_spawn_clear")
    addButton(spawnPnl, "Remove Nearest Spawn", "snd_spawn_remove_nearest")

    local gotoSpawnPanel = vgui.Create("DPanel", spawnPnl)
    gotoSpawnPanel:SetTall(60)
    gotoSpawnPanel.Paint = nil
    local teamEntry = vgui.Create("DTextEntry", gotoSpawnPanel)
    teamEntry:SetPos(0, 0)
    teamEntry:SetSize(100, 25)
    teamEntry:SetText("attack")
    local indexSlider = vgui.Create("DNumSlider", gotoSpawnPanel)
    indexSlider:SetPos(110, 0)
    indexSlider:SetSize(150, 25)
    indexSlider:SetText("Index")
    indexSlider:SetMinMax(1, 50)
    indexSlider:SetDecimals(0)
    indexSlider:SetValue(1)
    local gotoBtn = vgui.Create("DButton", gotoSpawnPanel)
    gotoBtn:SetPos(270, 0)
    gotoBtn:SetSize(100, 25)
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
    sitePnl:SetSpacing(5)
    sitePnl:SetPadding(10)

    sitePnl:AddItem(vgui.Create("DLabel", sitePnl)):SetText("Set Sites (at your position):")
    addButton(sitePnl, "Set Site A (F5)", "snd_site_add", {"A"})
    addButton(sitePnl, "Set Site B (F6)", "snd_site_add", {"B"})

    sitePnl:AddItem(vgui.Create("DLabel", sitePnl)):SetText("Manage Sites:")
    addButton(sitePnl, "Clear All Sites", "snd_site_clear")

    local gotoSitePanel = vgui.Create("DPanel", sitePnl)
    gotoSitePanel:SetTall(30)
    gotoSitePanel.Paint = nil
    local siteIDEntry = vgui.Create("DTextEntry", gotoSitePanel)
    siteIDEntry:SetPos(0, 0)
    siteIDEntry:SetSize(50, 25)
    siteIDEntry:SetText("A")
    local gotoSiteBtn = vgui.Create("DButton", gotoSitePanel)
    gotoSiteBtn:SetPos(60, 0)
    gotoSiteBtn:SetSize(100, 25)
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
    generalPnl:SetSpacing(5)
    generalPnl:SetPadding(10)

    local debugModeCV = GetConVar("snd_debug_mode")
    local debugModeCB = vgui.Create("DCheckBoxLabel")
    debugModeCB:SetText("Enable Debug Mode (F4)")
    debugModeCB:SetValue(debugModeCV and debugModeCV:GetBool() or false)
    debugModeCB.OnChange = function(_, val)
        RunConsoleCommand("snd_debug_toggle") -- This concommand handles sv_cheats and phase changes
        surface.PlaySound("buttons/button14.wav")
    end
    generalPnl:AddItem(debugModeCB)

    local noclipBtn = vgui.Create("DButton", generalPnl)
    noclipBtn:SetText("Toggle Noclip")
    noclipBtn:SetTall(30)
    noclipBtn.DoClick = function()
        RunConsoleCommand("snd_noclip")
        surface.PlaySound("buttons/button14.wav")
    end
    generalPnl:AddItem(noclipBtn)

    generalPnl:AddItem(vgui.Create("DLabel", generalPnl)):SetText("Bot Debug:")
    local botDebugPathsCV = GetConVar("snd_bot_debug_paths")
    local botDebugPathsCB = vgui.Create("DCheckBoxLabel")
    botDebugPathsCB:SetText("Visualize Bot Paths")
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
end

concommand.Add("snd_open_debug_menu", function()
    SND.OpenDebugMenu()
end)

print("[SND] Debug Menu UI Loaded")