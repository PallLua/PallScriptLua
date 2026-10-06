-- // Dungeon Quest Cheat Script
-- // Platform: Roblox, DungeonQuest
-- // Built for: dj

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Root = Char:WaitForChild("HumanoidRootPart")
local Humanoid = Char:WaitForChild("Humanoid")
local Backpack = LP:WaitForChild("Backpack")

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("remotes")
local abilities = ReplicatedStorage:WaitForChild("abilities")

local function getRemote(name)
    return remotes:FindFirstChild(name)
end

-- ============================================================
-- STATE
-- ============================================================
local State = {
    AutoSwing = false,
    AutoSkill = false,
    AutoDodge = false,
    AutoSell = false,
    AutoUpgrade = false,
    AutoDungeon = false,
    NoClip = false,
    HitboxEnabled = false,
    HitboxSize = 15,
    Farming = false,
}

local HitboxPart = nil
local DodgeCooldown = false
local SwingCooldown = false

-- ============================================================
-- UI SETUP
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DQCheat"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LP.PlayerGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 340, 0, 620)
MainFrame.Position = UDim2.new(0, 20, 0.5, -310)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 14)
Corner.Parent = MainFrame

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(130, 80, 255)
Stroke.Thickness = 1.5
Stroke.Transparency = 0.3
Stroke.Parent = MainFrame

-- Gradient top bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 14)
TopCorner.Parent = TopBar

local TopGradient = Instance.new("UIGradient")
TopGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 50, 220)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 80, 255)),
})
TopGradient.Rotation = 90
TopGradient.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚔  DUNGEON QUEST"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1, -16, 0, 16)
SubTitle.Position = UDim2.new(0, 16, 0, 30)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "AUTO FARM  •  HITBOX  •  UTILS"
SubTitle.TextColor3 = Color3.fromRGB(180, 150, 255)
SubTitle.TextSize = 9
SubTitle.Font = Enum.Font.GothamMedium
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Parent = MainFrame

-- Minimize button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -38, 0, 9)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 120)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.TextSize = 12
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TopBar
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 8)
MinCorner.Parent = MinBtn

local minimized = false
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -52)
ContentFrame.Position = UDim2.new(0, 0, 0, 52)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    ContentFrame.Visible = not minimized
    MainFrame.Size = minimized and UDim2.new(0, 340, 0, 52) or UDim2.new(0, 340, 0, 620)
    MinBtn.Text = minimized and "+" or "—"
end)

-- Scroll
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, 0, 1, -10)
Scroll.Position = UDim2.new(0, 0, 0, 5)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Color3.fromRGB(130, 80, 255)
Scroll.BorderSizePixel = 0
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = ContentFrame

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

local Padding = Instance.new("UIPadding")
Padding.PaddingLeft = UDim.new(0, 12)
Padding.PaddingRight = UDim.new(0, 12)
Padding.PaddingTop = UDim.new(0, 8)
Padding.Parent = Scroll

-- ============================================================
-- HELPER: CREATE TOGGLE BUTTON
-- ============================================================
local function createSection(text)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 22)
    Label.BackgroundTransparency = 1
    Label.Text = "  " .. text
    Label.TextColor3 = Color3.fromRGB(130, 80, 255)
    Label.TextSize = 10
    Label.Font = Enum.Font.GothamBold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Scroll
    return Label
end

local function createToggle(labelText, stateKey, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 42)
    Btn.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    Btn.BorderSizePixel = 0
    Btn.Text = ""
    Btn.AutoButtonColor = false
    Btn.Parent = Scroll

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 10)
    BtnCorner.Parent = Btn

    local BtnStroke = Instance.new("UIStroke")
    BtnStroke.Color = Color3.fromRGB(45, 45, 65)
    BtnStroke.Thickness = 1
    BtnStroke.Parent = Btn

    local BtnLabel = Instance.new("TextLabel")
    BtnLabel.Size = UDim2.new(1, -60, 1, 0)
    BtnLabel.Position = UDim2.new(0, 14, 0, 0)
    BtnLabel.BackgroundTransparency = 1
    BtnLabel.Text = labelText
    BtnLabel.TextColor3 = Color3.fromRGB(210, 210, 230)
    BtnLabel.TextSize = 12
    BtnLabel.Font = Enum.Font.GothamMedium
    BtnLabel.TextXAlignment = Enum.TextXAlignment.Left
    BtnLabel.Parent = Btn

    -- Toggle pill
    local Pill = Instance.new("Frame")
    Pill.Size = UDim2.new(0, 44, 0, 22)
    Pill.Position = UDim2.new(1, -54, 0.5, -11)
    Pill.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    Pill.BorderSizePixel = 0
    Pill.Parent = Btn
    local PillCorner = Instance.new("UICorner")
    PillCorner.CornerRadius = UDim.new(1, 0)
    PillCorner.Parent = Pill

    local Dot = Instance.new("Frame")
    Dot.Size = UDim2.new(0, 16, 0, 16)
    Dot.Position = UDim2.new(0, 3, 0.5, -8)
    Dot.BackgroundColor3 = Color3.fromRGB(120, 120, 150)
    Dot.BorderSizePixel = 0
    Dot.Parent = Pill
    local DotCorner = Instance.new("UICorner")
    DotCorner.CornerRadius = UDim.new(1, 0)
    DotCorner.Parent = Dot

    local function updateVisual(on)
        TweenService:Create(Pill, TweenInfo.new(0.2), {
            BackgroundColor3 = on and Color3.fromRGB(100, 50, 220) or Color3.fromRGB(40, 40, 60)
        }):Play()
        TweenService:Create(Dot, TweenInfo.new(0.2), {
            Position = on and UDim2.new(0, 25, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 150)
        }):Play()
        BtnLabel.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(210, 210, 230)
        BtnStroke.Color = on and Color3.fromRGB(100, 50, 220) or Color3.fromRGB(45, 45, 65)
    end

    Btn.MouseButton1Click:Connect(function()
        if stateKey then
            State[stateKey] = not State[stateKey]
            updateVisual(State[stateKey])
            if callback then callback(State[stateKey]) end
        else
            if callback then callback() end
        end
    end)

    return Btn, updateVisual
end

local function createSlider(labelText, minVal, maxVal, defaultVal, onChange)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 60)
    Container.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    Container.BorderSizePixel = 0
    Container.Parent = Scroll
    local ContCorner = Instance.new("UICorner")
    ContCorner.CornerRadius = UDim.new(0, 10)
    ContCorner.Parent = Container
    local ContStroke = Instance.new("UIStroke")
    ContStroke.Color = Color3.fromRGB(45, 45, 65)
    ContStroke.Thickness = 1
    ContStroke.Parent = Container

    local SliderLabel = Instance.new("TextLabel")
    SliderLabel.Size = UDim2.new(1, -20, 0, 20)
    SliderLabel.Position = UDim2.new(0, 14, 0, 8)
    SliderLabel.BackgroundTransparency = 1
    SliderLabel.Text = labelText .. ": " .. tostring(defaultVal)
    SliderLabel.TextColor3 = Color3.fromRGB(210, 210, 230)
    SliderLabel.TextSize = 11
    SliderLabel.Font = Enum.Font.GothamMedium
    SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    SliderLabel.Parent = Container

    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, -28, 0, 6)
    Track.Position = UDim2.new(0, 14, 0, 36)
    Track.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    Track.BorderSizePixel = 0
    Track.Parent = Container
    local TrackCorner = Instance.new("UICorner")
    TrackCorner.CornerRadius = UDim.new(1, 0)
    TrackCorner.Parent = Track

    local Fill = Instance.new("Frame")
    local pct = (defaultVal - minVal) / (maxVal - minVal)
    Fill.Size = UDim2.new(pct, 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(130, 80, 255)
    Fill.BorderSizePixel = 0
    Fill.Parent = Track
    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(1, 0)
    FillCorner.Parent = Fill

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 18, 0, 18)
    Knob.Position = UDim2.new(pct, -9, 0.5, -9)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.ZIndex = 3
    Knob.Parent = Track
    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob
    local KnobShadow = Instance.new("UIStroke")
    KnobShadow.Color = Color3.fromRGB(130, 80, 255)
    KnobShadow.Thickness = 2
    KnobShadow.Parent = Knob

    local dragging = false
    local currentVal = defaultVal

    local function updateSlider(inputX)
        local trackAbsPos = Track.AbsolutePosition.X
        local trackAbsSize = Track.AbsoluteSize.X
        local relX = math.clamp((inputX - trackAbsPos) / trackAbsSize, 0, 1)
        local val = math.floor(minVal + relX * (maxVal - minVal))
        currentVal = val
        Fill.Size = UDim2.new(relX, 0, 1, 0)
        Knob.Position = UDim2.new(relX, -9, 0.5, -9)
        SliderLabel.Text = labelText .. ": " .. tostring(val)
        if onChange then onChange(val) end
    end

    Knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    Track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
            updateSlider(input.Position.X)
        end
    end)

    return Container
end

local function createButton(labelText, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 38)
    Btn.BackgroundColor3 = Color3.fromRGB(100, 50, 220)
    Btn.BorderSizePixel = 0
    Btn.Text = labelText
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.TextSize = 12
    Btn.Font = Enum.Font.GothamBold
    Btn.AutoButtonColor = false
    Btn.Parent = Scroll
    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 10)
    BtnCorner.Parent = Btn
    local BtnGrad = Instance.new("UIGradient")
    BtnGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 60, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 40, 180)),
    })
    BtnGrad.Rotation = 90
    BtnGrad.Parent = Btn

    Btn.MouseButton1Click:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(70, 30, 150)}):Play()
        task.delay(0.15, function()
            TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(100, 50, 220)}):Play()
        end)
        if callback then callback() end
    end)

    return Btn
end

-- ============================================================
-- STATUS BAR
-- ============================================================
local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1, -24, 0, 28)
StatusBar.Position = UDim2.new(0, 12, 1, -36)
StatusBar.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
StatusBar.BorderSizePixel = 0
StatusBar.Parent = MainFrame
local SBCorner = Instance.new("UICorner")
SBCorner.CornerRadius = UDim.new(0, 8)
SBCorner.Parent = StatusBar

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -10, 1, 0)
StatusLabel.Position = UDim2.new(0, 10, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "● IDLE"
StatusLabel.TextColor3 = Color3.fromRGB(130, 130, 160)
StatusLabel.TextSize = 10
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusBar

local function setStatus(text, color)
    StatusLabel.Text = "● " .. text
    StatusLabel.TextColor3 = color or Color3.fromRGB(130, 255, 130)
end

-- ============================================================
-- BUILD UI ELEMENTS
-- ============================================================
createSection("⚔  AUTO FARM")
createToggle("Auto Swing", "AutoSwing", nil)
createToggle("Auto Skill (Q + E)", "AutoSkill", nil)
createToggle("Auto Dodge (Boss)", "AutoDodge", nil)
createToggle("Auto Farm (Tween to NPC)", "Farming", function(on)
    setStatus(on and "FARMING" or "IDLE", on and Color3.fromRGB(130, 255, 130) or Color3.fromRGB(130, 130, 160))
end)

createSection("🔧  UTILS")
createToggle("No Clip", "NoClip", function(on)
    setStatus(on and "NOCLIP ON" or "IDLE", on and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(130, 130, 160))
end)
createToggle("Auto Sell", "AutoSell", nil)
createToggle("Auto Upgrade (All Items)", "AutoUpgrade", nil)
createToggle("Auto Start / Replay Dungeon", "AutoDungeon", nil)

createSection("🟣  HITBOX EXPANDER")
createToggle("Hitbox Expander (Visible)", "HitboxEnabled", function(on)
    if on then
        if HitboxPart then HitboxPart:Destroy() end
        HitboxPart = Instance.new("Part")
        HitboxPart.Name = "CheatHitbox"
        HitboxPart.Size = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
        HitboxPart.Transparency = 0.6
        HitboxPart.BrickColor = BrickColor.new("Bright violet")
        HitboxPart.Material = Enum.Material.Neon
        HitboxPart.CanCollide = false
        HitboxPart.Anchored = false
        HitboxPart.CastShadow = false
        local Weld = Instance.new("WeldConstraint")
        Weld.Part0 = Root
        Weld.Part1 = HitboxPart
        Weld.Parent = HitboxPart
        HitboxPart.Parent = Char
        HitboxPart.CFrame = Root.CFrame
    else
        if HitboxPart then
            HitboxPart:Destroy()
            HitboxPart = nil
        end
    end
end)

createSlider("Hitbox Size", 5, 60, 15, function(val)
    State.HitboxSize = val
    if HitboxPart then
        HitboxPart.Size = Vector3.new(val, val, val)
    end
end)

-- spacer
local Spacer = Instance.new("Frame")
Spacer.Size = UDim2.new(1, 0, 0, 4)
Spacer.BackgroundTransparency = 1
Spacer.Parent = Scroll

createSection("🗺  DUNGEON")
createButton("▶  Start Dungeon Now", function()
    local startRemote = getRemote("startDungeon")
    if startRemote then startRemote:FireServer() end
    local replayRemote = getRemote("replayDungeon")
    if replayRemote then replayRemote:FireServer() end
    setStatus("DUNGEON STARTED", Color3.fromRGB(130, 255, 130))
end)

createButton("🔁  Replay Dungeon", function()
    local r = getRemote("replayDungeon")
    if r then r:FireServer() end
end)

createButton("💰  Sell All Items", function()
    local r = getRemote("sellItemEvent")
    if not r then return end
    for _, tool in ipairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            r:FireServer(tool)
            task.wait(0.1)
        end
    end
    setStatus("SOLD ALL", Color3.fromRGB(255, 200, 80))
end)

createButton("⬆  Upgrade All Items", function()
    local upgradeRemote = getRemote("upgradeItem")
    if not upgradeRemote then return end
    for _, tool in ipairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            upgradeRemote:FireServer(tool)
            task.wait(0.15)
        end
    end
    setStatus("UPGRADED ALL", Color3.fromRGB(130, 255, 255))
end)

-- ============================================================
-- NOCLIP
-- ============================================================
RunService.Stepped:Connect(function()
    if State.NoClip then
        for _, part in ipairs(Char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- ============================================================
-- FIND NEAREST NPC
-- ============================================================
local function getNearestNPC()
    local closest = nil
    local closestDist = math.huge
    local dungeonFolder = Workspace:FindFirstChild("dungeon")
    local searchRoot = dungeonFolder or Workspace

    for _, obj in ipairs(searchRoot:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildWhichIsA("Humanoid") then
            local npcRoot = obj:FindFirstChild("HumanoidRootPart")
            local npcHum = obj:FindFirstChildWhichIsA("Humanoid")
            if npcRoot and npcHum and npcHum.Health > 0 then
                local dist = (Root.Position - npcRoot.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = obj
                end
            end
        end
    end
    return closest
end

-- ============================================================
-- AUTO SWING
-- ============================================================
local function doSwing()
    if SwingCooldown then return end
    SwingCooldown = true
    local tool = Char:FindFirstChildWhichIsA("Tool")
    if tool then
        local swingRemote = tool:FindFirstChild("swing")
        if swingRemote then
            swingRemote:FireServer()
        end
        local weaponUsed = getRemote("weaponUsed")
        if weaponUsed then
            weaponUsed:FireServer()
        end
    end
    task.delay(0.35, function() SwingCooldown = false end)
end

-- ============================================================
-- AUTO SKILL
-- ============================================================
local function doSkills()
    local tool = Char:FindFirstChildWhichIsA("Tool")
    if not tool then return end
    local abilityEvent = tool:FindFirstChild("abilityEvent")
    local spellEvent = tool:FindFirstChild("spellEvent")
    if abilityEvent then abilityEvent:FireServer() end
    if spellEvent then spellEvent:FireServer() end
end

-- ============================================================
-- AUTO DODGE (tween sideways)
-- ============================================================
local function doDodge()
    if DodgeCooldown then return end
    DodgeCooldown = true
    local dodge = Root.CFrame * CFrame.new(math.random(-1, 1) * 8, 0, 0)
    TweenService:Create(Root, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = dodge}):Play()
    task.delay(1.2, function() DodgeCooldown = false end)
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local farmTween = nil
local lastSell = 0
local lastUpgrade = 0
local lastDungeon = 0
local lastSkill = 0
local lastDodge = 0

RunService.Heartbeat:Connect(function()
    -- respawn safety
    if not Char.Parent then
        Char = LP.Character
        if not Char then return end
        Root = Char:FindFirstChild("HumanoidRootPart")
        Humanoid = Char:FindFirstChild("Humanoid")
        if not Root or not Humanoid then return end
    end

    local now = tick()
    local npc = getNearestNPC()
    local npcRoot = npc and npc:FindFirstChild("HumanoidRootPart")

    -- Auto Farm: tween to NPC at walkspeed 16
    if State.Farming and npcRoot then
        local dist = (Root.Position - npcRoot.Position).Magnitude
        if dist > 6 then
            local targetCF = CFrame.new(npcRoot.Position + (Root.Position - npcRoot.Position).Unit * 5, npcRoot.Position)
            local tweenTime = dist / 16
            tweenTime = math.clamp(tweenTime, 0.1, 3)
            if farmTween then farmTween:Cancel() end
            farmTween = TweenService:Create(Root, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {CFrame = targetCF})
            farmTween:Play()
        end
    end

    -- Auto Swing
    if State.AutoSwing and npc and (Root.Position - (npcRoot and npcRoot.Position or Root.Position)).Magnitude < 18 then
        doSwing()
    end

    -- Auto Skill every 2s
    if State.AutoSkill and now - lastSkill > 2 then
        lastSkill = now
        doSkills()
    end

    -- Auto Dodge every 1.5s when near boss
    if State.AutoDodge and npc and now - lastDodge > 1.5 then
        lastDodge = now
        doDodge()
    end

    -- Auto Sell every 8s
    if State.AutoSell and now - lastSell > 8 then
        lastSell = now
        local r = getRemote("sellItemEvent")
        if r then
            for _, tool in ipairs(Backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    r:FireServer(tool)
                end
            end
        end
    end   
-- Auto Upgrade every 10s
    if State.AutoUpgrade and now - lastUpgrade > 10 then
        lastUpgrade = now
        local upgradeRemote = getRemote("upgradeItem")
        if upgradeRemote then
            for _, tool in ipairs(Backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    upgradeRemote:FireServer(tool)
                end
            end
        end
    end

    -- Auto Dungeon: replay every 15s if dungeonStarted = false
    if State.AutoDungeon and now - lastDungeon > 15 then
        lastDungeon = now
        local ds = Workspace:FindFirstChild("dungeonStarted")
        if ds and ds.Value == false then
            local r = getRemote("replayDungeon") or getRemote("startDungeon")
            if r then r:FireServer() end
        end
    end

    -- Hitbox follow root
    if HitboxPart and State.HitboxEnabled then
        -- weld handles it, nothing needed
    end
end)

-- ============================================================
-- RESPAWN HANDLER
-- ============================================================
LP.CharacterAdded:Connect(function(newChar)
    Char = newChar
    Root = newChar:WaitForChild("HumanoidRootPart")
    Humanoid = newChar:WaitForChild("Humanoid")
    Backpack = LP:WaitForChild("Backpack")
    HitboxPart = nil
    State.HitboxEnabled = false
end)

setStatus("LOADED — READY", Color3.fromRGB(130, 255, 130))
ENDOFSCRIPT
echo "done"
