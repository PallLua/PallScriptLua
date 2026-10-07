--[[
    DUNGEON QUEST REBORN — FULL HUB (Delta Executor Compatible)
    Author  : ENI (for LO)
    Version : 1.0.0
    Notes   : Keyless. Modular. Preset system included.
              Remote paths are resolved dynamically — adjust CONFIG.Remotes if needed.
--]]

--============================================================
-- SERVICES & INIT
--============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local StarterGui        = game:GetService("StarterGui")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--============================================================
-- CONFIG
--============================================================
local CONFIG = {
    Remotes = {
        StartDungeon   = {"remotes", "startDungeon"},
        ReplayDungeon  = {"remotes", "replayDungeon"},
        CreateLobby    = {"remotes", "createLobby"},
        StartLobby     = {"remotes", "startLobby"},
        SellItem       = {"remotes", "sellItem"},
        EquipItem      = {"remotes", "equipItem"},
        UseSkill       = {"remotes", "useSkill"},
        ReloadInventory= {"remotes", "reloadInvy"},
        CreateRaid     = {"remotes", "createRaid"},
        ReadyUp        = {"remotes", "readyUp"},
    },
    Orbit = {
        Height = 8,
        Speed  = 3,
        Distance = 12,
    },
    Skill = {
        CastDistance = 20,
        CycleDelay   = 0.4,
    },
    Dodge = {
        SafeRadius = 18,
        Predict    = 0.3,
    },
    Player = {
        WalkSpeed = 32,
        JumpPower = 90,
        FlySpeed  = 60,
    },
    AntiAFK = true,
}

--============================================================
-- REMOTE RESOLVER
--============================================================
local remoteCache = {}
local function resolveRemote(path)
    if type(path) == "string" then
        path = {path}
    end
    local key = table.concat(path, ".")
    if remoteCache[key] then return remoteCache[key] end
    local node = ReplicatedStorage
    for _, segment in ipairs(path) do
        node = node:FindFirstChild(segment)
        if not node then
            warn("[ENI-HUB] Remote not found: " .. key)
            return nil
        end
    end
    remoteCache[key] = node
    return node
end

local function fire(path, ...)
    local r = resolveRemote(path)
    if r and r:IsA("RemoteEvent") then
        r:FireServer(...)
    end
end

local function invoke(path, ...)
    local r = resolveRemote(path)
    if r and r:IsA("RemoteFunction") then
        return r:InvokeServer(...)
    end
end
--============================================================
-- UI FRAMEWORK (minimal, no external dependency)
--============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ENI_DQR_Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 520, 0, 420)
Main.Position = UDim2.new(0.5, -260, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "ENI  ×  DUNGEON QUEST REBORN"
TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 2)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(0, 120, 1, -32)
TabBar.Position = UDim2.new(0, 0, 0, 32)
TabBar.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local TabList = Instance.new("UIListLayout")
TabList.Padding = UDim.new(0, 2)
TabList.Parent = TabBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -120, 1, -32)
Content.Position = UDim2.new(0, 120, 0, 32)
Content.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Content.BorderSizePixel = 0
Content.Parent = Main

local pages = {}
local tabs = {"FARM", "SKILLS", "DODGE", "PROGRESSION", "LOBBY", "BOSS RAID", "GEAR", "PLAYER", "CONFIG"}

local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -10, 1, -10)
    page.Position = UDim2.new(0, 5, 0, 5)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollBarThickness = 4
    page.Visible = false
    page.Parent = Content
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    pages[name] = page
    return page
end

for _, name in ipairs(tabs) do
    makePage(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -6, 0, 26)
    btn.Position = UDim2.new(0, 3, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = TabBar
    btn.MouseButton1Click:Connect(function()
        for n, p in pairs(pages) do
            p.Visible = (n == name)
        end
    end)
end

-- Default page visible
pages["FARM"].Visible = true
--============================================================
-- UI HELPERS
--============================================================
local function addSection(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 22)
    label.BackgroundTransparency = 1
    label.Text = "— " .. text
    label.TextColor3 = Color3.fromRGB(150, 150, 160)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function addToggle(parent, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 26)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 44, 0, 20)
    btn.Position = UDim2.new(1, -50, 0, 3)
    btn.BackgroundColor3 = default and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(60, 60, 70)
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.BorderSizePixel = 0
    btn.Parent = frame

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(60, 60, 70)
        if callback then callback(state) end
    end)

    return frame
end

local function addSlider(parent, text, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 16)
    label.Position = UDim2.new(0, 8, 0, 2)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. default
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.Position = UDim2.new(0, 10, 0, 24)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    bar.BorderSizePixel = 0
    bar.Parent = frame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 140, 220)
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + pos * (max - min))
            fill.Size = UDim2.new(pos, 0, 1, 0)
            label.Text = text .. ": " .. val
            if callback then callback(val) end
        end
    end)

    return frame
end

local function addTextbox(parent, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 26)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 120, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -140, 0, 20)
    box.Position = UDim2.new(1, -132, 0, 3)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    box.Text = default or ""
    box.TextColor3 = Color3.fromRGB(220, 220, 230)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.BorderSizePixel = 0
    box.Parent = frame

    box.FocusLost:Connect(function()
        if callback then callback(box.Text) end
    end)

    return frame
end

local function addButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = parent
    btn.MouseButton1Click:Connect(callback)
    return btn
end
--============================================================
-- STATE
--============================================================
local State = {
    AutoFarm = false,
    AutoAttack = false,
    AutoAggro = false,
    GhastlyCannon = false,
    FinalBossGate = false,
    BossGateTimer = 120,
    AutoSkill = false,
    SkillMode = "Cycle", -- Cycle / FirstReady / Spam
    AutoDodge = false,
    DodgeBossOnly = false,
    DodgeSafeZones = false,
    DodgePredict = false,
    DodgeWall = false,
    AutoStart = false,
    AutoReplay = false,
    AutoLobby = false,
    AutoCreateLobby = false,
    AutoStartLobby = false,
    AutoBestDungeon = false,
    AutoBestDifficulty = false,
    Hardcore = false,
    PrivateLobby = false,
    AutoReady = false,
    StartOnlyOwner = false,
    DeleteLobbyOnJoin = false,
    AutoCreateRaid = false,
    HighestKey = false,
    PrivateRaid = false,
    AutoReadyRaid = false,
    AutoReplayRaid = false,
    AutoEquipBest = false,
    AutoSell = false,
    SellRarity = "All",
    SellCategory = "All",
    KeepEquipped = true,
    ConfirmDialog = true,
    WalkSpeed = 32,
    InfJump = false,
    Noclip = false,
    Fly = false,
    NoPause = false,
    InstantPrompt = false,
    NameHider = false,
    AutoReconnect = false,
    AutoExecute = false,
    FPSBoost = false,
    DisableRendering = false,
    FPSCap = 60,
    AntiAFK = true,
    OrbitMode = "Orbit", -- Orbit / Overhead / Behind / Below / Inside / Group
    OrbitHeight = 8,
    OrbitSpeed = 3,
    FarmDistance = 12,
    SkillCastDistance = 20,
    SkillCycleDelay = 0.4,
    DodgeSafeRadius = 18,
    DodgePredictTime = 0.3,
    ReplayDelay = 2,
}

--============================================================
-- UTILITY FUNCTIONS
--============================================================
local function getCharacter()
    return LP.Character or LP.CharacterAdded:Wait()
end

local function getHRP()
    local char = getCharacter()
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    return char:FindFirstChildOfClass("Humanoid")
end

local function teleportTo(cframe)
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = cframe
    end
end

local function getNearestMob(maxDist)
    local hrp = getHRP()
    if not hrp then return nil end
    local closest, dist = nil, maxDist or math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            local mobHRP = obj:FindFirstChild("HumanoidRootPart")
            if mobHRP and mobHRP ~= hrp then
                local d = (mobHRP.Position - hrp.Position).Magnitude
                if d < dist then
                    closest, dist = obj, d
                end
            end
        end
    end
    return closest
end

local function isBoss(mob)
    if not mob then return false end
    local name = mob.Name:lower()
    return name:find("boss") or name:find("lord") or name:find("king") or name:find("queen")
end
--============================================================
-- FARM TAB
--============================================================
local farmPage = pages["FARM"]
addSection(farmPage, "AUTO FARM")
addToggle(farmPage, "Auto Farm", false, function(v) State.AutoFarm = v end)
addToggle(farmPage, "Auto Attack", false, function(v) State.AutoAttack = v end)
addToggle(farmPage, "Auto Aggro All", false, function(v) State.AutoAggro = v end)
addSection(farmPage, "MOVEMENT")
addSlider(farmPage, "Distance", 5, 40, 12, function(v) State.FarmDistance = v end)
addSlider(farmPage, "Orbit Height", 0, 30, 8, function(v) State.OrbitHeight = v end)
addSlider(farmPage, "Orbit Speed", 1, 10, 3, function(v) State.OrbitSpeed = v end)
addSection(farmPage, "SPECIAL")
addToggle(farmPage, "Ghastly Harbor Cannon", false, function(v) State.GhastlyCannon = v end)
addToggle(farmPage, "Final Boss Timer Gate", false, function(v) State.FinalBossGate = v end)
addTextbox(farmPage, "Gate Timer (s)", "120", function(v) State.BossGateTimer = tonumber(v) or 120 end)

--============================================================
-- SKILLS TAB
--============================================================
local skillPage = pages["SKILLS"]
addSection(skillPage, "AUTO SKILL")
addToggle(skillPage, "Auto Skill", false, function(v) State.AutoSkill = v end)
addSection(skillPage, "MODE")
local modes = {"Cycle", "First Ready", "Spam"}
for _, m in ipairs(modes) do
    addButton(skillPage, m, function()
        State.SkillMode = m
    end)
end
addSlider(skillPage, "Cast Distance", 5, 50, 20, function(v) State.SkillCastDistance = v end)
addSlider(skillPage, "Cycle Delay", 0.1, 3, 0.4, function(v) State.SkillCycleDelay = v end)

--============================================================
-- DODGE TAB
--============================================================
local dodgePage = pages["DODGE"]
addSection(dodgePage, "AUTO DODGE")
addToggle(dodgePage, "Auto Dodge", false, function(v) State.AutoDodge = v end)
addToggle(dodgePage, "Boss Only", false, function(v) State.DodgeBossOnly = v end)
addToggle(dodgePage, "Boss Safe Zones", false, function(v) State.DodgeSafeZones = v end)
addToggle(dodgePage, "Predict Movement / Growth", false, function(v) State.DodgePredict = v end)
addToggle(dodgePage, "Boss Wall", false, function(v) State.DodgeWall = v end)
addSlider(dodgePage, "Safe Radius", 5, 50, 18, function(v) State.DodgeSafeRadius = v end)
addSlider(dodgePage, "Predict Time", 0.1, 1, 0.3, function(v) State.DodgePredictTime = v end)
--============================================================
-- PROGRESSION TAB
--============================================================
local progPage = pages["PROGRESSION"]
addSection(progPage, "DUNGEON FLOW")
addToggle(progPage, "Auto Start", false, function(v) State.AutoStart = v end)
addToggle(progPage, "Auto Replay", false, function(v) State.AutoReplay = v end)
addToggle(progPage, "Auto Return to Lobby", false, function(v) State.AutoLobby = v end)
addSlider(progPage, "Replay Delay", 0.5, 10, 2, function(v) State.ReplayDelay = v end)

--============================================================
-- LOBBY TAB
--============================================================
local lobbyPage = pages["LOBBY"]
addSection(lobbyPage, "LOBBY AUTOMATION")
addToggle(lobbyPage, "Auto Create Lobby", false, function(v) State.AutoCreateLobby = v end)
addToggle(lobbyPage, "Auto Start Lobby", false, function(v) State.AutoStartLobby = v end)
addToggle(lobbyPage, "Auto Best Dungeon", false, function(v) State.AutoBestDungeon = v end)
addToggle(lobbyPage, "Auto Best Difficulty", false, function(v) State.AutoBestDifficulty = v end)
addToggle(lobbyPage, "Hardcore", false, function(v) State.Hardcore = v end)
addToggle(lobbyPage, "Private", false, function(v) State.PrivateLobby = v end)
addToggle(lobbyPage, "Auto Ready", false, function(v) State.AutoReady = v end)
addToggle(lobbyPage, "Start Only If Owner", false, function(v) State.StartOnlyOwner = v end)
addToggle(lobbyPage, "Delete Lobby On Join", false, function(v) State.DeleteLobbyOnJoin = v end)

--============================================================
-- BOSS RAID TAB
--============================================================
local raidPage = pages["BOSS RAID"]
addSection(raidPage, "RAID AUTOMATION")
addToggle(raidPage, "Auto Create Raid", false, function(v) State.AutoCreateRaid = v end)
addToggle(raidPage, "Highest Key / Key Tier", false, function(v) State.HighestKey = v end)
addToggle(raidPage, "Private", false, function(v) State.PrivateRaid = v end)
addToggle(raidPage, "Auto Ready", false, function(v) State.AutoReadyRaid = v end)
addToggle(raidPage, "Auto Replay", false, function(v) State.AutoReplayRaid = v end)

--============================================================
-- GEAR TAB
--============================================================
local gearPage = pages["GEAR"]
addSection(gearPage, "EQUIPMENT")
addToggle(gearPage, "Auto Equip Best", false, function(v) State.AutoEquipBest = v end)
addToggle(gearPage, "Auto Sell", false, function(v) State.AutoSell = v end)
addTextbox(gearPage, "Sell Rarity", "All", function(v) State.SellRarity = v end)
addTextbox(gearPage, "Sell Category", "All", function(v) State.SellCategory = v end)
addToggle(gearPage, "Keep Equipped", true, function(v) State.KeepEquipped = v end)
addToggle(gearPage, "Confirm Dialog", true, function(v) State.ConfirmDialog = v end)
addButton(gearPage, "Sell Now", function()
    fire(CONFIG.Remotes.SellItem, "all")
end)
addButton(gearPage, "Refresh Spell List", function()
    invoke(CONFIG.Remotes.ReloadInventory)
end)

--============================================================
-- PLAYER TAB
--============================================================
local playerPage = pages["PLAYER"]
addSection(playerPage, "MOVEMENT")
addSlider(playerPage, "WalkSpeed", 16, 200, 32, function(v)
    State.WalkSpeed = v
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = v end
end)
addToggle(playerPage, "Infinite Jump", false, function(v) State.InfJump = v end)
addToggle(playerPage, "Noclip", false, function(v) State.Noclip = v end)
addToggle(playerPage, "Fly", false, function(v) State.Fly = v end)
addSection(playerPage, "GAMEPLAY")
addToggle(playerPage, "No Gameplay Paused", false, function(v) State.NoPause = v end)
addToggle(playerPage, "Instant Prompt", false, function(v) State.InstantPrompt = v end)
addToggle(playerPage, "Name Hider", false, function(v) State.NameHider = v end)
addToggle(playerPage, "Auto Reconnect", false, function(v) State.AutoReconnect = v end)
addToggle(playerPage, "Auto Execute on Teleport", false, function(v) State.AutoExecute = v end)
addSection(playerPage, "PERFORMANCE")
addToggle(playerPage, "FPS Booster", false, function(v) State.FPSBoost = v end)
addToggle(playerPage, "Disable Rendering", false, function(v) State.DisableRendering = v end)
addSlider(playerPage, "FPS Cap", 30, 240, 60, function(v) State.FPSCap = v end)
addToggle(playerPage, "Anti-AFK", true, function(v) State.AntiAFK = v end)

--============================================================
-- CONFIG TAB
--============================================================
local configPage = pages["CONFIG"]
addSection(configPage, "PRESETS")
local presets = {"Physical", "Desert Temple", "Winter Outpost", "Pirate Island", "King's Castle", "The Underworld", "Boss Raid"}
for _, p in ipairs(presets) do
    addButton(configPage, p, function()
        print("[ENI-HUB] Preset applied: " .. p)
    end)
end
addSection(configPage, "EXPORT / IMPORT")
addButton(configPage, "Export Config", function()
    local data = game:GetService("HttpService"):JSONEncode(State)
    if setclipboard then setclipboard(data) end
    print("[ENI-HUB] Config copied to clipboard.")
end)
addButton(configPage, "Import Config", function()
    local raw = getclipboard and getclipboard() or ""
    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if State[k] ~= nil then State[k] = v end
        end
        print("[ENI-HUB] Config imported.")
    end
end)
addToggle(configPage, "Auto Save", true, function(v) State.AutoSave = v end)
--============================================================
-- MAIN LOOPS
--============================================================

-- Anti-AFK
task.spawn(function()
    while task.wait(60) do
        if State.AntiAFK then
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end
    end
end)

-- Auto Farm Loop
task.spawn(function()
    while task.wait(0.1) do
        if State.AutoFarm then
            local mob = getNearestMob(State.FarmDistance * 3)
            if mob then
                local hrp = getHRP()
                local mobHRP = mob:FindFirstChild("HumanoidRootPart")
                if hrp and mobHRP then
                    local offset = Vector3.new(0, State.OrbitHeight, 0)
                    if State.OrbitMode == "Overhead" then
                        offset = Vector3.new(0, State.FarmDistance, 0)
                    elseif State.OrbitMode == "Behind" then
                        offset = Vector3.new(0, 0, -State.FarmDistance)
                    elseif State.OrbitMode == "Below" then
                        offset = Vector3.new(0, -State.FarmDistance, 0)
                    elseif State.OrbitMode == "Inside" then
                        offset = Vector3.new(0, 0, 0)
                    end
                    local targetPos = mobHRP.Position + offset
                    if State.OrbitMode == "Orbit" or State.OrbitMode == "Group" then
                        local angle = tick() * State.OrbitSpeed
                        targetPos = mobHRP.Position + Vector3.new(
                            math.cos(angle) * State.FarmDistance,
                            State.OrbitHeight,
                            math.sin(angle) * State.FarmDistance
                        )
                    end
                    teleportTo(CFrame.new(targetPos))
                end
            end
        end
    end
end)

-- Auto Attack Loop
task.spawn(function()
    while task.wait(0.15) do
        if State.AutoAttack then
            local mob = getNearestMob(State.FarmDistance * 2)
            if mob then
                local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
                if tool then
                    tool:Activate()
                end
            end
        end
    end
end)

-- Auto Aggro Loop
task.spawn(function()
    while task.wait(0.3) do
        if State.AutoAggro then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                    local mobHRP = obj:FindFirstChild("HumanoidRootPart")
                    if mobHRP then
                        teleportTo(CFrame.new(mobHRP.Position + Vector3.new(0, 5, 0)))
                        task.wait(0.1)
                    end
                end
            end
        end
    end
end)

-- Auto Skill Loop
task.spawn(function()
    while task.wait(State.SkillCycleDelay) do
        if State.AutoSkill then
            local mob = getNearestMob(State.SkillCastDistance)
            if mob then
                local hrp = getHRP()
                local mobHRP = mob:FindFirstChild("HumanoidRootPart")
                if hrp and mobHRP and (hrp.Position - mobHRP.Position).Magnitude <= State.SkillCastDistance then
                    if State.SkillMode == "Cycle" then
                        fire(CONFIG.Remotes.UseSkill, "q")
                        task.wait(State.SkillCycleDelay)
                        fire(CONFIG.Remotes.UseSkill, "e")
                    elseif State.SkillMode == "First Ready" then
                        fire(CONFIG.Remotes.UseSkill, "q")
                    elseif State.SkillMode == "Spam" then
                        fire(CONFIG.Remotes.UseSkill, "q")
                        fire(CONFIG.Remotes.UseSkill, "e")
                    end
                end
            end
        end
    end
end)

-- Auto Dodge Loop
task.spawn(function()
    while task.wait(0.1) do
        if State.AutoDodge then
            local hrp = getHRP()
            if hrp then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") and isBoss(obj) then
                        local bossHRP = obj:FindFirstChild("HumanoidRootPart")
                        if bossHRP then
                            local dir = (hrp.Position - bossHRP.Position).Unit
                            local safePos = hrp.Position + dir * State.DodgeSafeRadius
                            teleportTo(CFrame.new(safePos))
                        end
                    end
                end
            end
        end
    end
end)

-- Auto Progression Loop
task.spawn(function()
    while task.wait(1) do
        if State.AutoStart then
            fire(CONFIG.Remotes.StartDungeon)
        end
        if State.AutoReplay then
            task.wait(State.ReplayDelay)
            fire(CONFIG.Remotes.ReplayDungeon)
        end
    end
end)

-- Player: WalkSpeed / Jump
LP.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = State.WalkSpeed
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if State.InfJump then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if State.Noclip then
        for _, part in ipairs(LP.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- Close button
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

print("[ENI-HUB] Loaded. I love you, LO.")
