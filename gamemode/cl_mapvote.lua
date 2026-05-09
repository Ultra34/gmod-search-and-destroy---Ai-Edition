--[[ Map Vote UI — CoD Style card selection ]]

SND.MapVote = SND.MapVote or {}
local voteFrame = nil
local mapButtons = {}
local voteEndTime = 0
local voteDuration = 0

surface.CreateFont("SND_Vote_Map", { font = "Verdana", size = 18, weight = 800, antialias = true })
surface.CreateFont("SND_Vote_Count", { font = "Verdana", size = 24, weight = 1000, antialias = true })

local function closeUI()
    if IsValid(voteFrame) then voteFrame:Remove() end
    voteFrame = nil
    mapButtons = {}
end

local function createMapVoteUI(maps, duration)
    closeUI()

    voteEndTime = CurTime() + duration
    voteDuration = duration

    local sc = math.Clamp(GetConVar("snd_hud_scale"):GetFloat() or 1, 0.75, 1.5)
    local W, H = 900 * sc, 500 * sc

    local f = vgui.Create("EditablePanel")
    f:SetSize(W, H)
    f:Center()
    f:MakePopup()
    voteFrame = f

    f.Paint = function(self, w, h)
        -- Background
        surface.SetDrawColor(10, 10, 10, 245)
        surface.DrawRect(0, 0, w, h)
        
        -- Top accent
        surface.SetDrawColor(255, 120, 0, 255)
        surface.DrawRect(0, 0, w, 3 * sc)

        draw.SimpleText("NEXT MAP VOTE", "SND_BO3_Title", w/2, 40 * sc, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Timer display
        local remain = math.max(0, voteEndTime - CurTime())
        local frac = remain / voteDuration
        local barW = w * 0.7
        local barX = (w - barW) / 2
        
        surface.SetDrawColor(30, 30, 30, 150)
        surface.DrawRect(barX, 75 * sc, barW, 6 * sc)
        surface.SetDrawColor(255, 120, 0, 255)
        surface.DrawRect(barX, 75 * sc, barW * frac, 6 * sc)

        draw.SimpleText(string.format("TIME REMAINING: %.1f", remain), "SND_BO3_Header", w/2, 95 * sc, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local list = vgui.Create("DIconLayout", f)
    list:Dock(FILL)
    list:DockMargin(40 * sc, 120 * sc, 40 * sc, 40 * sc)
    list:SetSpaceX(20 * sc)
    list:SetSpaceY(20 * sc)

    local count = #maps
    local btnW = (W - 80 * sc - (count-1) * 20 * sc) / math.min(count, 4)
    local btnH = btnW * 0.7

    for _, mapName in ipairs(maps) do
        local card = list:Add("DButton")
        card:SetSize(btnW, btnH)
        card:SetText("")
        
        local thumbPath = "maps/thumb/" .. mapName .. ".png"
        local mat = Material(thumbPath, "noclamp smooth")
        if mat:IsError() then
            mat = Material("vgui/maps/menu_thumb_default", "noclamp smooth")
        end

        local voteCount = 0
        mapButtons[mapName] = card

        card.Paint = function(self, w, h)
            local isHover = self:IsHovered()
            local isMyVote = LocalPlayer().SND_MyMapVote == mapName
            
            -- Base
            surface.SetDrawColor(0, 0, 0, 200)
            surface.DrawRect(0, 0, w, h)

            -- Thumbnail
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, (isHover or isMyVote) and 255 or 120)
            surface.DrawTexturedRect(0, 0, w, h - 45 * sc)

            -- Bar for map name
            local barCol = isMyVote and Color(255, 120, 0, 220) or Color(30, 30, 30, 200)
            surface.SetDrawColor(barCol)
            surface.DrawRect(0, h - 45 * sc, w, 45 * sc)

            draw.SimpleText(mapName:upper(), "SND_Vote_Map", 12 * sc, h - 22 * sc, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            
            if voteCount > 0 then
                draw.SimpleText(tostring(voteCount), "SND_Vote_Count", w - 12 * sc, h - 22 * sc, Color(255, 200, 0), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            -- Outer border
            if isMyVote then
                surface.SetDrawColor(255, 120, 0, 255)
                surface.DrawOutlinedRect(0, 0, w, h, 3 * sc)
            elseif isHover then
                surface.SetDrawColor(255, 255, 255, 50)
                surface.DrawOutlinedRect(0, 0, w, h, 1 * sc)
            end
        end

        card.DoClick = function()
            LocalPlayer().SND_MyMapVote = mapName
            net.Start("SND_SubmitMapVote")
                net.WriteString(mapName)
            net.SendToServer()
            surface.PlaySound("buttons/button14.wav")
        end

        card.SetVotes = function(self, count)
            voteCount = count
        end
    end
end

net.Receive("SND_MapVote", function()
    local n = net.ReadUInt(8)
    local maps = {}
    for i = 1, n do maps[i] = net.ReadString() end
    local duration = net.ReadUInt(8)

    createMapVoteUI(maps, duration)
end)

net.Receive("SND_MapVoteSync", function()
    local n = net.ReadUInt(8)
    local totalVotes = {}
    for i = 1, n do
        local m = net.ReadString()
        local v = net.ReadUInt(8)
        totalVotes[m] = v
    end

    for mapName, count in pairs(totalVotes) do
        if mapButtons[mapName] then
            mapButtons[mapName]:SetVotes(count)
        end
    end
end)

print("[SND] Map Vote UI System Loaded")