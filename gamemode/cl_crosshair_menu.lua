--[[ Crosshair Customization Menu — accessible via chat command !crosshair ]]

SND.Crosshair = SND.Crosshair or {}

local profilesPath = "snd_mwclassic/crosshair_profiles.json"
local profiles = {}

local function loadProfiles()
    if file.Exists(profilesPath, "DATA") then
        profiles = util.JSONToTable(file.Read(profilesPath, "DATA")) or {}
    end
end

local function saveProfiles()
    file.CreateDir("snd_mwclassic")
    file.Write(profilesPath, util.TableToJSON(profiles))
end

function SND.Crosshair.OpenMenu()
    local f = vgui.Create("DFrame")
    f:SetTitle("Crosshair Customization")
    f:SetSize(450, 700)
    f:Center()
    f:MakePopup()

    -- ── Crosshair Preview ────────────────────────────────────────────────
    local preview = vgui.Create("DPanel", f)
    preview:Dock(TOP)
    preview:SetTall(150)
    preview:DockMargin(10, 5, 10, 10)
    preview.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 255))
        surface.SetDrawColor(60, 60, 60, 255)
        surface.DrawOutlinedRect(0, 0, w, h)

        if not GetConVar("snd_crosshair_enabled"):GetBool() then 
            draw.SimpleText("Crosshair Disabled", "Trebuchet18", w/2, h/2, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return 
        end

        local cx, cy = w / 2, h / 2
        local gap = GetConVar("snd_crosshair_gap"):GetFloat()
        local len = GetConVar("snd_crosshair_length"):GetFloat()
        local thick = GetConVar("snd_crosshair_thickness"):GetFloat()
        local dot = GetConVar("snd_crosshair_dot"):GetBool()
        local r = GetConVar("snd_crosshair_r"):GetInt()
        local g = GetConVar("snd_crosshair_g"):GetInt()
        local b = GetConVar("snd_crosshair_b"):GetInt()

        surface.SetDrawColor(r, g, b, 255)
        -- Left
        surface.DrawRect(cx - gap - len, cy - thick * 0.5, len, thick)
        -- Right
        surface.DrawRect(cx + gap, cy - thick * 0.5, len, thick)
        -- Top
        surface.DrawRect(cx - thick * 0.5, cy - gap - len, thick, len)
        -- Bottom
        surface.DrawRect(cx - thick * 0.5, cy + gap, thick, len)

        if dot then
            surface.DrawRect(cx - thick * 0.5, cy - thick * 0.5, thick, thick)
        end
    end

    -- ── Profiles Section ─────────────────────────────────────────────────
    local profPanel = vgui.Create("DPanel", f)
    profPanel:Dock(TOP)
    profPanel:SetTall(100)
    profPanel:DockMargin(10, 0, 10, 10)
    profPanel.Paint = function(self, w, h)
        draw.SimpleText("Crosshair Profiles", "Trebuchet18", 0, 0, Color(255, 210, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local combo = vgui.Create("DComboBox", profPanel)
    combo:SetPos(0, 20)
    combo:SetSize(200, 25)
    combo:SetValue("Select Profile...")
    for name, _ in pairs(profiles) do combo:AddChoice(name) end

    local loadBtn = vgui.Create("DButton", profPanel)
    loadBtn:SetPos(210, 20)
    loadBtn:SetSize(100, 25)
    loadBtn:SetText("Load Profile")
    loadBtn.DoClick = function()
        local val = combo:GetValue()
        local p = profiles[val]
        if p then
            RunConsoleCommand("snd_crosshair_gap", p.gap)
            RunConsoleCommand("snd_crosshair_length", p.length)
            RunConsoleCommand("snd_crosshair_thickness", p.thick)
            RunConsoleCommand("snd_crosshair_dot", p.dot)
            RunConsoleCommand("snd_crosshair_r", p.r)
            RunConsoleCommand("snd_crosshair_g", p.g)
            RunConsoleCommand("snd_crosshair_b", p.b)
            f:Close()
            SND.Crosshair.OpenMenu() -- Refresh UI components
        end
    end

    local deleteBtn = vgui.Create("DButton", profPanel)
    deleteBtn:SetPos(320, 20)
    deleteBtn:SetSize(100, 25)
    deleteBtn:SetText("Delete")
    deleteBtn.DoClick = function()
        local val = combo:GetValue()
        if profiles[val] then
            profiles[val] = nil
            saveProfiles()
            combo:Clear()
            combo:SetValue("Select Profile...")
            for name, _ in pairs(profiles) do combo:AddChoice(name) end
        end
    end

    local nameEntry = vgui.Create("DTextEntry", profPanel)
    nameEntry:SetPos(0, 55)
    nameEntry:SetSize(200, 25)
    nameEntry:SetPlaceholderText("New Profile Name...")

    local saveBtn = vgui.Create("DButton", profPanel)
    saveBtn:SetPos(210, 55)
    saveBtn:SetSize(210, 25)
    saveBtn:SetText("Save Current Settings")
    saveBtn.DoClick = function()
        local name = nameEntry:GetValue()
        if name == "" then return end
        profiles[name] = {
            gap = GetConVar("snd_crosshair_gap"):GetFloat(),
            length = GetConVar("snd_crosshair_length"):GetFloat(),
            thick = GetConVar("snd_crosshair_thickness"):GetFloat(),
            dot = GetConVar("snd_crosshair_dot"):GetInt(),
            r = GetConVar("snd_crosshair_r"):GetInt(),
            g = GetConVar("snd_crosshair_g"):GetInt(),
            b = GetConVar("snd_crosshair_b"):GetInt(),
        }
        saveProfiles()
        combo:Clear()
        combo:SetValue(name)
        for n, _ in pairs(profiles) do combo:AddChoice(n) end
    end

    local scroll = vgui.Create("DScrollPanel", f)
    scroll:Dock(FILL)

    local function addSlider(lbl, cvar, min, max, dec)
        local s = scroll:Add("DNumSlider")
        s:Dock(TOP)
        s:DockMargin(10, 5, 10, 5)
        s:SetText(lbl)
        s:SetMin(min)
        s:SetMax(max)
        s:SetDecimals(dec or 0)
        s:SetConVar(cvar)
    end

    local function addCheckbox(lbl, cvar)
        local c = scroll:Add("DCheckBoxLabel")
        c:Dock(TOP)
        c:DockMargin(10, 5, 10, 5)
        c:SetText(lbl)
        c:SetConVar(cvar)
    end

    addCheckbox("Enable Crosshair", "snd_crosshair_enabled")
    addCheckbox("Center Dot", "snd_crosshair_dot")

    addSlider("Length", "snd_crosshair_length", 0, 50, 0)
    addSlider("Thickness", "snd_crosshair_thickness", 1, 10, 0)
    addSlider("Gap", "snd_crosshair_gap", -10, 20, 0)

    local label = scroll:Add("DLabel")
    label:Dock(TOP)
    label:DockMargin(10, 20, 10, 5)
    label:SetText("Crosshair Color")
    label:SetFont("Trebuchet18")
    label:SetTextColor(Color(255, 255, 255))

    local color = vgui.Create("DColorMixer", scroll)
    color:Dock(TOP)
    color:DockMargin(10, 5, 10, 5)
    color:SetPalette(true)
    color:SetAlphaBar(false)
    color:SetWangs(true)
    
    -- Initial color
    color:SetColor(Color(
        GetConVar("snd_crosshair_r"):GetInt(),
        GetConVar("snd_crosshair_g"):GetInt(),
        GetConVar("snd_crosshair_b"):GetInt()
    ))

    color.ValueChanged = function(_, col)
        RunConsoleCommand("snd_crosshair_r", col.r)
        RunConsoleCommand("snd_crosshair_g", col.g)
        RunConsoleCommand("snd_crosshair_b", col.b)
    end
end

-- ── Chat Command ─────────────────────────────────────────────────────────
hook.Add("OnPlayerChat", "SND_CrosshairChatCommand", function(ply, text)
    if ply ~= LocalPlayer() then return end
    
    if string.lower(text) == "!crosshair" then
        SND.Crosshair.OpenMenu()
        return true -- Suppress text from appearing in chat for the sender
    end
end)

-- Load profiles automatically when the player joins/rejoins
loadProfiles()

print("[SND] Crosshair Menu System Loaded")