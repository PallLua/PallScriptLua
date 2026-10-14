--[[
    PALL — FISCH v7.0.0
    Logic  : NIGHT fisch_fixed.txt (state machine + expand bar)
    UI     : WindUI
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RUN = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

--============================================================
-- LOAD WINDUI
--============================================================
local WindUI
if _G.PallWindUI then
    WindUI = _G.PallWindUI
else
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end)
    if not ok then error("[PALL-FISCH] Gagal load WindUI.") end
    WindUI = result
    _G.PallWindUI = WindUI
end

local Green = Color3.fromHex("#10C550")
local Yellow = Color3.fromHex("#ECA201")
local Blue = Color3.fromHex("#257AF7")
local Grey = Color3.fromHex("#83889E")
local Purple = Color3.fromHex("#7775F2")

--============================================================
-- CLEAN OLD RUN
--============================================================
if _G.FISCH_RUNNING then
    _G.FISCH_RUNNING = false
    task.wait(0.5)
end
_G.FISCH_RUNNING = true

--============================================================
-- GLOBAL FLAGS
--============================================================
_G.AutoFish      = false
_G.AutoReel      = false
_G.ExpandBar     = true
_G.AutoSell      = false
_G.AutoQuest     = false
_G.AutoCollect   = false
_G.AntiAFK       = false
_G.SpeedBoost    = false
_G.AutoEquipBest = false
_G.ESP           = false
_G.FishRadar     = false
_G.Fly           = false
_G.FlySpeed      = 50
_G.ESPRange      = 300

--============================================================
-- CHAR REF
--============================================================
local char, hrp, hum
local function refreshChar()
    char = LP.Character or LP.CharacterAdded:Wait()
    hrp  = char:WaitForChild("HumanoidRootPart", 5)
    hum  = char:WaitForChild("Humanoid", 5)
end
refreshChar()
LP.CharacterAdded:Connect(function()
    task.wait(0.8)
    refreshChar()
end)

--============================================================
-- REMOTE CACHE
--============================================================
local remoteCache = {}

local function buildRemoteCache()
    remoteCache = {}
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            local key = v.Name:lower()
            if not remoteCache[key] then
                remoteCache[key] = v
            end
            remoteCache[v.Name] = v
        end
    end
end

buildRemoteCache()

task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(30)
        buildRemoteCache()
    end
end)

local function getRemote(name)
    return remoteCache[name:lower()] or remoteCache[name]
end

local function fireRE(name, ...)
    local r = getRemote(name)
    if r and r:IsA("RemoteEvent") then
        local args = {...}
        pcall(function() r:FireServer(table.unpack(args)) end)
        return true
    end
    return false
end

--============================================================
-- ROD HELPERS
--============================================================
local rodTier = {
    ["legendary"]=10, ["mythic"]=9, ["ancient"]=8,
    ["divine"]=7, ["rare"]=6, ["uncommon"]=5, ["common"]=1,
}

local function getRodScore(tool)
    local name = tool.Name:lower()
    for tier, score in pairs(rodTier) do
        if name:find(tier) then return score end
    end
    return 2
end

local function isRodTool(tool)
    if not tool:IsA("Tool") then return false end
    local n = tool.Name:lower()
    return n:find("rod") or n:find("fishing") or n:find("pole")
end

local function findBestRod()
    local best, bestScore = nil, -1
    for _, src in ipairs({ LP:FindFirstChild("Backpack"), char }) do
        if src then
            for _, t in ipairs(src:GetChildren()) do
                if isRodTool(t) then
                    local s = getRodScore(t)
                    if s > bestScore then
                        bestScore = s
                        best = t
                    end
                end
            end
        end
    end
    return best
end

local function equippedRod()
    if not char then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if isRodTool(t) then return t end
    end
    return nil
end

local function equipRod(rod)
    if not rod or not hum or not char then return end
    if char:FindFirstChild(rod.Name) then return end
    pcall(function() hum:EquipTool(rod) end)
    task.wait(0.5)
end

--============================================================
-- REEL BAR DETECTION
--============================================================
local reelBarRef = nil
local reelBarScan = 0
local REEL_BAR_CD = 2

local REEL_BAR_NAMES = {
    "ReelBar","reelBar","Reel","reel",
    "FishBar","fishBar","CatchBar","catchBar",
    "ProgressBar","progressBar","MinigameBar",
    "WhiteBar","SliderBar","Bar","FishingBar",
    "ClickBar","HoldBar","ReelFrame","FishFrame","Handle",
}

local function scanForReelBar()
    for _, name in ipairs(REEL_BAR_NAMES) do
        local found = PG:FindFirstChild(name, true)
        if found and (found:IsA("Frame") or found:IsA("ImageLabel")) and found.Visible then
            reelBarRef = found
            return found
        end
    end
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, obj in ipairs(gui:GetDescendants()) do
                if (obj:IsA("Frame") or obj:IsA("ImageLabel")) and obj.Visible then
                    local bc = obj.BackgroundColor3
                    if bc.R > 0.8 and bc.G > 0.8 and bc.B > 0.8 then
                        reelBarRef = obj
                        return obj
                    end
                end
            end
        end
    end
    return nil
end

local function getReelBar()
    local now = tick()
    if reelBarRef and reelBarRef.Parent then
        return reelBarRef.Visible and reelBarRef or nil
    end
    if now - reelBarScan >= REEL_BAR_CD then
        reelBarScan = now
        reelBarRef = nil
        return scanForReelBar()
    end
    return nil
end

--============================================================
-- EXPAND REEL BAR
--============================================================
local expandedBars = {}

local function expandReelBar()
    if not _G.ExpandBar then return end
    if not reelBarRef or not reelBarRef.Parent then return end
    local barParent = reelBarRef.Parent
    if not barParent then return end

    for _, obj in ipairs(barParent:GetDescendants()) do
        if (obj:IsA("Frame") or obj:IsA("ImageLabel")) and not expandedBars[obj] then
            expandedBars[obj] = { size = obj.Size, pos = obj.Position }
            pcall(function()
                local origW = obj.Size.X.Scale
                local origH = obj.Size.Y.Scale
                local origOX = obj.Size.X.Offset
                local origOY = obj.Size.Y.Offset
                obj.Size = UDim2.new(
                    origW,
                    origOX > 0 and origOX * 3 or origOX,
                    origH,
                    origOY
                )
            end)
        end
    end
end

local function restoreReelBar()
    for obj, orig in pairs(expandedBars) do
        if obj and obj.Parent then
            pcall(function()
                obj.Size = orig.size
                obj.Position = orig.pos
            end)
        end
    end
    expandedBars = {}
end

task.spawn(function()
    local prev = false
    while _G.FISCH_RUNNING do
        task.wait(0.3)
        if _G.ExpandBar ~= prev then
            prev = _G.ExpandBar
            if not _G.ExpandBar then restoreReelBar() end
        end
    end
end)

--============================================================
-- REMOTE LISTS
--============================================================
local CAST_REMOTES  = {"castLine","CastLine","cast","Cast","castRod","startFishing"}
local REEL_REMOTES  = {"reelIn","ReelIn","clickReel","ClickReel","reel","Reel","reelFish","pullRod"}
local SELL_REMOTES  = {"sellFish","SellFish","sellAll","SellAll","sell","Sell","sellInventory"}
local QUEST_REMOTES = {"claimQuest","ClaimQuest","acceptQuest","AcceptQuest","completeQuest","questClaim"}

local function fireList(list, ...)
    for _, name in ipairs(list) do
        fireRE(name, ...)
    end
end

--============================================================
-- AUTO EQUIP BEST ROD
--============================================================
task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(5)
        if not _G.AutoEquipBest then continue end
        if not hum or not char then continue end
        local best = findBestRod()
        if best and not char:FindFirstChild(best.Name) then
            equipRod(best)
        end
    end
end)

--============================================================
-- AUTO FISH STATE MACHINE
--============================================================
local fishState = "idle"
local lastCast = 0
local CAST_CD = 2.5
local BITE_TIMEOUT = 20

task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(0.15)
        if not _G.AutoFish then
            fishState = "idle"
            continue
        end
        if not char or not hrp or not hum then continue end
        if hum.Health <= 0 then continue end

        local now = tick()

        if fishState == "idle" then
            if now - lastCast < CAST_CD then continue end

            local rod = equippedRod()
            if not rod then
                rod = findBestRod()
                if rod then
                    equipRod(rod)
                    task.wait(0.3)
                    rod = equippedRod()
                end
            end

            if not rod then
                task.wait(3)
                continue
            end

            pcall(function() rod:Activate() end)
            task.wait(0.1)
            fireList(CAST_REMOTES)

            fishState = "waiting"
            lastCast = now

        elseif fishState == "waiting" then
            local bar = getReelBar()
            if bar then
                fishState = "reeling"
                if _G.ExpandBar then
                    task.delay(0.1, expandReelBar)
                end
            end
            if now - lastCast >= BITE_TIMEOUT then
                fishState = "idle"
                lastCast = now - CAST_CD
            end

        elseif fishState == "reeling" then
            local bar = getReelBar()
            if bar then
                fireList(REEL_REMOTES)
                local rod = equippedRod()
                if rod then pcall(function() rod:Activate() end) end
                task.wait(0.06)
            else
                restoreReelBar()
                fishState = "idle"
                lastCast = tick()
            end
        end
    end
end)

--============================================================
-- AUTO REEL STANDALONE
--============================================================
task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(0.08)
        if not _G.AutoReel then continue end
        if _G.AutoFish then continue end
        local bar = getReelBar()
        if bar then
            fireList(REEL_REMOTES)
            local rod = equippedRod()
            if rod then pcall(function() rod:Activate() end) end
        end
    end
end)

--============================================================
-- AUTO SELL
--============================================================
local lastSell = 0
task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(1)
        if not _G.AutoSell then continue end
        if tick() - lastSell < 6 then continue end
        lastSell = tick()
        fireList(SELL_REMOTES)
        for key, r in pairs(remoteCache) do
            if type(key) == "string" and key:find("sell") and r:IsA("RemoteFunction") then
                pcall(function() r:InvokeServer() end)
            end
        end
    end
end)

--============================================================
-- AUTO QUEST
--============================================================
local lastQuest = 0
task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(1)
        if not _G.AutoQuest then continue end
        if tick() - lastQuest < 10 then continue end
        lastQuest = tick()
        fireList(QUEST_REMOTES)
    end
end)

--============================================================
-- AUTO COLLECT
--============================================================
task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(0.5)
        if not _G.AutoCollect then continue end
        if not hrp then continue end
        local RANGE = 18
        local folders = {
            WS:FindFirstChild("Items"),
            WS:FindFirstChild("Drops"),
            WS:FindFirstChild("Pickups"),
            WS:FindFirstChild("Loot"),
        }
        for _, folder in ipairs(folders) do
            if not folder then continue end
            for _, obj in ipairs(folder:GetChildren()) do
                local pos
                if obj:IsA("BasePart") then
                    pos = obj.Position
                elseif obj:IsA("Model") then
                    local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                    if p then pos = p.Position end
                end
                if pos and (pos - hrp.Position).Magnitude <= RANGE then
                    pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) end)
                    fireRE("collect")
                    fireRE("pickup")
                    fireRE("Collect")
                end
            end
        end
    end
end)

--============================================================
-- ANTI AFK
--============================================================
local lastAFK = 0
task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(10)
        if not _G.AntiAFK then continue end
        if tick() - lastAFK < 180 then continue end
        lastAFK = tick()
        if not hum or not hrp then continue end
        local d = Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
        pcall(function() hum:MoveTo(hrp.Position + d) end)
        task.wait(0.5)
        pcall(function() hum:MoveTo(hrp.Position - d) end)
    end
end)

--============================================================
-- SPEED BOOST
--============================================================
task.spawn(function()
    local prev = false
    while _G.FISCH_RUNNING do
        task.wait(0.3)
        if not hum then continue end
        if _G.SpeedBoost and not prev then
            pcall(function() hum.WalkSpeed = 32 end)
            prev = true
        elseif not _G.SpeedBoost and prev then
            pcall(function() hum.WalkSpeed = 16 end)
            prev = false
        end
    end
end)

--============================================================
-- FLY
--============================================================
local flyConn
local function updateFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if not _G.Fly then
        if hum then pcall(function() hum.PlatformStand = false end) end
        return
    end
    if hum then pcall(function() hum.PlatformStand = true end) end
    flyConn = RUN.RenderStepped:Connect(function()
        if not _G.Fly then
            if hum then pcall(function() hum.PlatformStand = false end) end
            if flyConn then flyConn:Disconnect(); flyConn = nil end
            return
        end
        if not hrp then return end
        local cam = WS.CurrentCamera
        local cf = cam.CFrame
        local move = Vector3.new(0, 0, 0)
        local spd = _G.FlySpeed or 50
        if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then
            move = move + Vector3.new(0, 1, 0)
        end
        if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
            move = move - Vector3.new(0, 1, 0)
        end
        if move.Magnitude > 0.01 then move = move.Unit * spd end
        pcall(function()
            hrp.Velocity = move
            hrp.AssemblyLinearVelocity = move
        end)
    end)
end

task.spawn(function()
    local prev = false
    while _G.FISCH_RUNNING do
        task.wait(0.2)
        if _G.Fly ~= prev then
            prev = _G.Fly
            updateFly()
        end
    end
end)

--============================================================
-- ESP
--============================================================
local espBills = {}
local espCache = {}

local RARE_KW = {"legendary","mythic","ancient","divine","prismatic","event","rare","epic","ultra"}
local function isRare(name)
    local low = name:lower()
    for _, k in ipairs(RARE_KW) do
        if low:find(k) then return true end
    end
    return false
end

local function mkBill(adornee, text, color)
    if not adornee or espCache[adornee] then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(150, 32)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = adornee
    bb.Parent = WS
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.3
    lbl.BackgroundColor3 = Color3.new(0, 0, 0)
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    table.insert(espBills, bb)
    espCache[adornee] = true
end

local function clearESP()
    for _, b in ipairs(espBills) do
        pcall(function() b:Destroy() end)
    end
    espBills = {}
    espCache = {}
end

task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(3)
        if not _G.ESP then
            clearESP()
            continue
        end
        if not hrp then continue end
        clearESP()

        local range = _G.ESPRange or 300
        local hrpPos = hrp.Position

        local scanTargets = { WS }
        for _, c in ipairs(WS:GetChildren()) do
            if c:IsA("Folder") or c:IsA("Model") then
                table.insert(scanTargets, c)
            end
        end

        for _, container in ipairs(scanTargets) do
            for _, obj in ipairs(container:GetChildren()) do
                if not hrp then break end
                local name = obj.Name
                local nameLow = name:lower()
                local pos, adornee
                if obj:IsA("BasePart") then
                    pos = obj.Position
                    adornee = obj
                elseif obj:IsA("Model") then
                    local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                    if p then
                        pos = p.Position
                        adornee = p
                    end
                end
                if not pos or not adornee then continue end
                if (pos - hrpPos).Magnitude > range then continue end

                if nameLow:find("spot") or nameLow:find("bobber") or nameLow:find("buoy") then
                    mkBill(adornee, "🎣 " .. name, Color3.fromRGB(0, 255, 150))
                elseif nameLow:find("fish") and not nameLow:find("rod") and not nameLow:find("script") then
                    if isRare(name) then
                        mkBill(adornee, "⭐ " .. name, Color3.fromRGB(255, 200, 0))
                    else
                        mkBill(adornee, "🐟 " .. name, Color3.fromRGB(100, 200, 255))
                    end
                elseif nameLow:find("treasure") or nameLow:find("chest") then
                    mkBill(adornee, "💰 " .. name, Color3.fromRGB(255, 220, 50))
                end
            end
        end
    end
end)

--============================================================
-- FISH RADAR
--============================================================
local notified = {}
task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(4)
        if not _G.FishRadar then
            notified = {}
            continue
        end
        if not hrp then continue end
        for _, obj in ipairs(WS:GetDescendants()) do
            if not isRare(obj.Name) then continue end
            if not obj.Name:lower():find("fish") then continue end
            local pos
            if obj:IsA("BasePart") then
                pos = obj.Position
            elseif obj:IsA("Model") then
                local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                if p then pos = p.Position end
            end
            if pos and (pos - hrp.Position).Magnitude < 200 then
                if not notified[obj] then
                    notified[obj] = true
                    pcall(function()
                        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                            Text = "[RADAR] 🌟 RARE: " .. obj.Name,
                            Color = Color3.fromRGB(255, 200, 0),
                            FontSize = Enum.FontSize.Size18,
                        })
                    end)
                end
            else
                notified[obj] = nil
            end
        end
    end
end)

--============================================================
-- FPS COUNTER
--============================================================
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0, 100, 0, 24)
fpsLabel.Position = UDim2.new(0, 10, 0, 10)
fpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fpsLabel.BackgroundTransparency = 0.5
fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
fpsLabel.Font = Enum.Font.Code
fpsLabel.TextSize = 14
fpsLabel.Text = "FPS: --"
fpsLabel.Parent = PG

local frames, lastTime, curFPS = 0, tick(), 0
RUN.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastTime >= 1 then
        curFPS = frames
        fpsLabel.Text = "FPS: " .. curFPS
        frames = 0
        lastTime = tick()
    end
end)

--============================================================
-- WINDOW
--============================================================
local Window = WindUI:CreateWindow({
    Title = "Pall x Fisch",
    Folder = "pallfisch",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open Pall Fisch",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#3DC9FF"), Color3.fromHex("#10C550")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})
Window:Tag({ Title = "v7.0.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: AUTO FISH
--============================================================
local TabFish = Window:Tab({
    Title = "Auto Fish", Desc = "State machine + Expand Bar",
    Icon = "solar:fish-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s = TabFish:Section({ Title = "Control", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Auto Fish", Value = false,
        Callback = function(v) _G.AutoFish = v end })
    s:Space()
    s:Toggle({ Title = "Auto Reel (standalone)", Value = false,
        Callback = function(v) _G.AutoReel = v end })
    s:Space()
    s:Toggle({ Title = "Expand Reel Bar", Value = true,
        Callback = function(v) _G.ExpandBar = v end })

    local info = TabFish:Section({ Title = "Status", Box = true, BoxBorder = true, Opened = true })
    local statusTxt = info:Section({ Title = "Idle", TextSize = 14, TextTransparency = 0.2 })
    task.spawn(function()
        while _G.FISCH_RUNNING do
            task.wait(0.5)
            pcall(function()
                local rod = equippedRod()
                statusTxt:SetTitle(
                    "State: " .. fishState ..
                    "\nRod: " .. (rod and rod.Name or "none") ..
                    " | FPS: " .. curFPS
                )
            end)
        end
    end)
end

--============================================================
-- TAB: AUTO SELL
--============================================================
local TabSell = Window:Tab({
    Title = "Auto Sell", Desc = "Sell remotes",
    Icon = "solar:cart-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s = TabSell:Section({ Title = "Control", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Auto Sell", Value = false,
        Callback = function(v) _G.AutoSell = v end })
end

--============================================================
-- TAB: PLAYER
--============================================================
local TabPlayer = Window:Tab({
    Title = "Player", Desc = "Movement",
    Icon = "solar:user-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s = TabPlayer:Section({ Title = "Movement", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Auto Equip Best Rod", Value = false,
        Callback = function(v) _G.AutoEquipBest = v end })
    s:Space()
    s:Toggle({ Title = "Speed Boost (32)", Value = false,
        Callback = function(v) _G.SpeedBoost = v end })
    s:Space()
    s:Toggle({ Title = "Fly", Value = false,
        Callback = function(v) _G.Fly = v end })
    s:Space()
    s:Slider({ Title = "Fly Speed", Step = 5,
        Value = { Min = 10, Max = 300, Default = 50 },
        Callback = function(v) _G.FlySpeed = v end })
    s:Space()
    s:Toggle({ Title = "Anti-AFK", Value = false,
        Callback = function(v) _G.AntiAFK = v end })
end

--============================================================
-- TAB: EXTRA
--============================================================
local TabExtra = Window:Tab({
    Title = "Extra", Desc = "Quest, Collect, Visual",
    Icon = "solar:star-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local s1 = TabExtra:Section({ Title = "Auto Actions", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Quest", Value = false,
        Callback = function(v) _G.AutoQuest = v end })
    s1:Space()
    s1:Toggle({ Title = "Auto Collect", Value = false,
        Callback = function(v) _G.AutoCollect = v end })

    local s2 = TabExtra:Section({ Title = "Visual", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "ESP Fish", Value = false,
        Callback = function(v) _G.ESP = v end })
    s2:Space()
    s2:Slider({ Title = "ESP Range", Step = 50,
        Value = { Min = 50, Max = 1000, Default = 300 },
        Callback = function(v) _G.ESPRange = v end })
    s2:Space()
    s2:Toggle({ Title = "Fish Radar", Value = false,
        Callback = function(v) _G.FishRadar = v end })
end

--============================================================
-- NOTIF
--============================================================
WindUI:Notify({
    Title = "Pall Fisch v7.0.0",
    Content = "State machine + Expand Bar. Equip rod dulu!",
    Icon = "solar:bell-bold",
    Duration = 8,
})

print("════════════════════════════════════════════")
print("[PALL-FISCH] v7.0.0 loaded. Logic: NIGHT state machine.")
print("════════════════════════════════════════════")
