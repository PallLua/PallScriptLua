--[[
    PALL — FISCH v5.0.0 (Instant Catch)
    Logic  : myCompiler community script (verified remote)
    Remotes:
      - RE/EquipToolFromHotbar:FireServer()
      - RF/ChargeFishingRod:InvokeServer(1)
      - RF/RequestFishingMinigameStarted:InvokeServer(1, 1)
      - RE/FishingCompleted:FireServer()
      - RF/SellAllItems:InvokeServer()
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RUN = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VU = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")

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
-- NET FOLDER RESOLVER
--============================================================
local netFolder = nil

local function findNetFolder()
    if netFolder and netFolder.Parent then return netFolder end
    -- Path utama: ReplicatedStorage.Packages._Index.<sleitnick_net>.net
    local packages = RS:FindFirstChild("Packages")
    if packages then
        local index = packages:FindFirstChild("_Index")
        if index then
            for _, child in ipairs(index:GetChildren()) do
                if child.Name:lower():find("sleitnick_net") or child.Name:lower():find("net") then
                    local net = child:FindFirstChild("net")
                    if net then
                        netFolder = net
                        return net
                    end
                end
            end
        end
    end
    -- Fallback: scan ReplicatedStorage untuk folder "net"
    for _, desc in ipairs(RS:GetDescendants()) do
        if desc:IsA("Folder") and desc.Name:lower() == "net" then
            netFolder = desc
            return desc
        end
    end
    return nil
end

local function getNet(name)
    local net = findNetFolder()
    if not net then return nil end
    return net:FindFirstChild(name)
end

--============================================================
-- INSTANT CATCH CORE
--============================================================
local function instantFish()
    local net = findNetFolder()
    if not net then return false, "net folder not found" end

    local equip = net:FindFirstChild("RE/EquipToolFromHotbar")
    local charge = net:FindFirstChild("RF/ChargeFishingRod")
    local start = net:FindFirstChild("RF/RequestFishingMinigameStarted")
    local complete = net:FindFirstChild("RE/FishingCompleted")

    if not equip or not charge or not start or not complete then
        return false, "remote missing"
    end

    pcall(function() equip:FireServer() end)
    task.wait(0.01)
    pcall(function() charge:InvokeServer(1) end)
    task.wait(0.01)
    pcall(function() start:InvokeServer(1, 1) end)
    task.wait(0.01)
    pcall(function() complete:FireServer() end)

    return true, "ok"
end

local function sellAll()
    local net = findNetFolder()
    if not net then return false end
    local sell = net:FindFirstChild("RF/SellAllItems")
    if sell then
        pcall(function() sell:InvokeServer() end)
        return true
    end
    return false
end

--============================================================
-- STATE
--============================================================
local State = {
    AutoFish = false,
    AutoSell = false,
    FishDelay = 1,
    SellDelay = 1,

    AntiAFK = true,
    SpeedBoost = false,
    Fly = false,
    FlySpeed = 50,
    ESP = false,
    ESPRange = 300,

    Status = "Idle",
    FPS = 0,
}

local char, hrp, hum
local function refreshChar()
    char = LP.Character or LP.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart", 5)
    hum = char:WaitForChild("Humanoid", 5)
end
refreshChar()
LP.CharacterAdded:Connect(function() task.wait(0.8) refreshChar() end)

--============================================================
-- AUTO FISH LOOP (INSTANT)
--============================================================
task.spawn(function()
    while task.wait(State.FishDelay) do
        if not State.AutoFish then
            State.Status = "Idle"
            continue
        end
        if not char or not hum then continue end

        local ok, msg = instantFish()
        if ok then
            State.Status = "Instant catch ✓"
        else
            State.Status = "❌ " .. msg
        end
    end
end)

--============================================================
-- AUTO SELL LOOP
--============================================================
task.spawn(function()
    while task.wait(State.SellDelay) do
        if not State.AutoSell then continue end
        if sellAll() then
            State.Status = "SellAll ✓"
        end
    end
end)

--============================================================
-- ANTI-AFK
--============================================================
task.spawn(function()
    while task.wait(60) do
        if State.AntiAFK then
            pcall(function()
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
            end)
        end
    end
end)

--============================================================
-- SPEED BOOST
--============================================================
task.spawn(function()
    while task.wait(0.5) do
        if not hum then continue end
        if State.SpeedBoost then
            hum.WalkSpeed = 32
        elseif hum.WalkSpeed == 32 then
            hum.WalkSpeed = 16
        end
    end
end)

--============================================================
-- FLY
--============================================================
local flyConn
local function updateFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if not State.Fly then
        if hum then hum.PlatformStand = false end
        return
    end
    if hum then hum.PlatformStand = true end

    flyConn = RUN.RenderStepped:Connect(function()
        if not State.Fly then
            if hum then hum.PlatformStand = false end
            flyConn:Disconnect(); flyConn = nil
            return
        end
        if not hrp then return end
        local cf = WS.CurrentCamera.CFrame
        local move = Vector3.new(0, 0, 0)
        local spd = State.FlySpeed
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

--============================================================
-- ESP (optimized)
--============================================================
local espBills = {}
local function clearESP()
    for _, b in ipairs(espBills) do pcall(function() b:Destroy() end) end
    espBills = {}
end

local function mkBill(adornee, text, color)
    if not adornee then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(140, 28)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
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
    table.insert(espBills, bb)
end

task.spawn(function()
    while task.wait(2) do
        if not State.ESP then clearESP() continue end
        clearESP()
        if not hrp then continue end

        local roots = {}
        for _, name in ipairs({ "active", "world", "Fishing", "fish", "Fish" }) do
            local f = WS:FindFirstChild(name)
            if f then table.insert(roots, f) end
        end

        for _, root in ipairs(roots) do
            for _, obj in ipairs(root:GetChildren()) do
                if not hrp then break end
                local pos
                if obj:IsA("BasePart") then pos = obj.Position
                elseif obj:IsA("Model") then
                    local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                    if p then pos = p.Position end
                end
                if not pos then continue end
                if (pos - hrp.Position).Magnitude > State.ESPRange then continue end
                local n = obj.Name:lower()
                if n:find("fish") then
                    local adornee = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")) or obj
                    mkBill(adornee, "🐟 " .. obj.Name, Color3.fromRGB(100, 200, 255))
                end
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

local frames, lastTime = 0, tick()
RUN.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastTime >= 1 then
        State.FPS = frames
        fpsLabel.Text = "FPS: " .. frames
        frames = 0; lastTime = tick()
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
        CornerRadius = UDim.new(1, 0), StrokeThickness = 3,
        Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#3DC9FF"), Color3.fromHex("#10C550")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})
Window:Tag({ Title = "v5.0.0 Instant", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

-- TAB: AUTO FISH
local TabFish = Window:Tab({
    Title = "Auto Fish", Desc = "Instant Catch (Remote)",
    Icon = "solar:fish-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s = TabFish:Section({ Title = "Instant Fishing", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Auto Fish (Instant)", Value = false,
        Callback = function(v) State.AutoFish = v end })
    s:Space()
    s:Slider({ Title = "Fish Loop Delay", Step = 0.1,
        Value = { Min = 0.1, Max = 5, Default = 1 },
        Callback = function(v) State.FishDelay = v end })

    local info = TabFish:Section({ Title = "Status", Box = true, BoxBorder = true, Opened = true })
    local statusTxt = info:Section({ Title = "Idle", TextSize = 15, TextTransparency = 0.3 })
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function() statusTxt:SetTitle(State.Status .. " | FPS: " .. State.FPS) end)
        end
    end)
end

-- TAB: AUTO SELL
local TabSell = Window:Tab({
    Title = "Auto Sell", Desc = "SellAllItems",
    Icon = "solar:cart-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s = TabSell:Section({ Title = "Auto Sell", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Auto Sell All", Value = false,
        Callback = function(v) State.AutoSell = v end })
    s:Space()
    s:Slider({ Title = "Sell Delay", Step = 0.2,
        Value = { Min = 0.2, Max = 5, Default = 1 },
        Callback = function(v) State.SellDelay = v end })
end

-- TAB: PLAYER
local TabPlayer = Window:Tab({
    Title = "Player", Desc = "Movement",
    Icon = "solar:user-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s = TabPlayer:Section({ Title = "Movement", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Speed Boost (32)", Value = false,
        Callback = function(v) State.SpeedBoost = v end })
    s:Space()
    s:Toggle({ Title = "Fly (WASD + Space/Q)", Value = false,
        Callback = function(v) State.Fly = v; updateFly() end })
    s:Space()
    s:Slider({ Title = "Fly Speed", Step = 5,
        Value = { Min = 10, Max = 300, Default = 50 },
        Callback = function(v) State.FlySpeed = v end })
    s:Space()
    s:Toggle({ Title = "Anti-AFK", Value = true,
        Callback = function(v) State.AntiAFK = v end })
end

-- TAB: VISUAL
local TabVisual = Window:Tab({
    Title = "Visual", Desc = "ESP",
    Icon = "solar:eye-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local s = TabVisual:Section({ Title = "ESP", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "ESP Fish", Value = false,
        Callback = function(v) State.ESP = v end })
    s:Space()
    s:Slider({ Title = "ESP Range", Step = 50,
        Value = { Min = 50, Max = 1000, Default = 300 },
        Callback = function(v) State.ESPRange = v end })
end

WindUI:Notify({
    Title = "Pall Fisch v5.0.0",
    Content = "Instant catch via verified remote.",
    Icon = "solar:bell-bold",
    Duration = 8,
})

print("[PALL-FISCH] v5.0.0 loaded. Instant catch active.")
