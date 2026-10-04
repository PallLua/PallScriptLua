-- =====================================================================
-- PALL LOADER v8.1 - FIXED UI & PLAYERGUI PATCH
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- Konfigurasi Toggle & Nilai Fitur
getgenv().PallLoader = {
    AutoCollect = false,
    AutoNextStage = false,
    KillAura = false,
    InstantKill = false,
    StageTeleport = false,
    AutoBuyUpgrade = false,
    CustomFOV = false,
    FOVValue = 120,
    FPSUnlocker = false,
    InvisibleMode = false,
    AntiAFK = true,
    HitboxExpander = false,
    HitboxSize = 5
}

-- Hapus GUI lama jika ada agar tidak menumpuk
pcall(function()
    if PlayerGui:FindFirstChild("PallLoaderFluentHub") then
        PlayerGui.PallLoaderFluentHub:Destroy()
    end
    if PlayerGui:FindFirstChild("PallLoaderFloatingButton") then
        PlayerGui.PallLoaderFloatingButton:Destroy()
    end
end)

-- =====================================================================
-- 1. PEMBUATAN UI UTAMA (PLAYERGUI TARGET - 100% MUNCUL)
-- =====================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PallLoaderFluentHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- Main Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 550, 0, 420)
MainFrame.Position = UDim2.new(0.5, -275, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICornerMain = Instance.new("UICorner")
UICornerMain.CornerRadius = UDim.new(0, 8)
UICornerMain.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(45, 45, 58)
UIStroke.Thickness = 1
UIStroke.Parent = MainFrame

-- Top Bar (Header)
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local UICornerTop = Instance.new("UICorner")
UICornerTop.CornerRadius = UDim.new(0, 8)
UICornerTop.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 350, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡  Pall Loader  <font color='#00FFAA'>v8.1 [Fixed UI]</font>"
TitleLabel.RichText = true
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
TitleLabel.TextSize = 15
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

-- Tombol Close / Hide di Pojok Kanan Atas Header
local HideButton = Instance.new("TextButton")
HideButton.Size = UDim2.new(0, 30, 0, 30)
HideButton.Position = UDim2.new(1, -38, 0.5, -15)
HideButton.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
HideButton.Text = "-"
HideButton.TextColor3 = Color3.fromRGB(200, 200, 210)
HideButton.TextSize = 18
HideButton.Font = Enum.Font.GothamBold
HideButton.Parent = TopBar

local UICornerHide = Instance.new("UICorner")
UICornerHide.CornerRadius = UDim.new(0, 6)
UICornerHide.Parent = HideButton

-- Content Container
local ContentContainer = Instance.new("ScrollingFrame")
ContentContainer.Size = UDim2.new(1, -30, 1, -65)
ContentContainer.Position = UDim2.new(0, 15, 0, 52)
ContentContainer.BackgroundTransparency = 1
ContentContainer.CanvasSize = UDim2.new(0, 0, 0, 720)
ContentContainer.ScrollBarThickness = 4
ContentContainer.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 90)
ContentContainer.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.Parent = ContentContainer

-- Fungsi Header Kategori
local function createSectionHeader(titleText)
    local Header = Instance.new("TextLabel")
    Header.Size = UDim2.new(1, 0, 0, 25)
    Header.BackgroundTransparency = 1
    Header.Text = "  " .. string.upper(titleText)
    Header.TextColor3 = Color3.fromRGB(0, 220, 150)
    Header.TextSize = 12
    Header.Font = Enum.Font.GothamBold
    Header.TextXAlignment = Enum.TextXAlignment.Left
    Header.Parent = ContentContainer
end

-- Fungsi Tombol Toggle
local function createToggle(name, featureKey)
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(1, 0, 0, 42)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    ToggleButton.Text = ""
    ToggleButton.AutoButtonColor = false
    ToggleButton.Parent = ContentContainer

    local UICornerBtn = Instance.new("UICorner")
    UICornerBtn.CornerRadius = UDim.new(0, 6)
    UICornerBtn.Parent = ToggleButton

    local UIStrokeBtn = Instance.new("UIStroke")
    UIStrokeBtn.Color = Color3.fromRGB(40, 40, 55)
    UIStrokeBtn.Thickness = 1
    UIStrokeBtn.Parent = ToggleButton

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(210, 210, 220)
    Label.TextSize = 13
    Label.Font = Enum.Font.GothamSemibold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = ToggleButton

    local SwitchBg = Instance.new("Frame")
    SwitchBg.Size = UDim2.new(0, 40, 0, 20)
    SwitchBg.Position = UDim2.new(1, -50, 0.5, -10)
    SwitchBg.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    SwitchBg.BorderSizePixel = 0
    SwitchBg.Parent = ToggleButton

    local UICornerSwitch = Instance.new("UICorner")
    UICornerSwitch.CornerRadius = UDim.new(1, 0)
    UICornerSwitch.Parent = SwitchBg

    local SwitchDot = Instance.new("Frame")
    SwitchDot.Size = UDim2.new(0, 14, 0, 14)
    SwitchDot.Position = UDim2.new(0, 3, 0.5, -7)
    SwitchDot.BackgroundColor3 = Color3.fromRGB(150, 150, 170)
    SwitchDot.BorderSizePixel = 0
    SwitchDot.Parent = SwitchBg

    local UICornerDot = Instance.new("UICorner")
    UICornerDot.CornerRadius = UDim.new(1, 0)
    UICornerDot.Parent = SwitchDot

    ToggleButton.MouseButton1Click:Connect(function()
        getgenv().PallLoader[featureKey] = not getgenv().PallLoader[featureKey]
        local state = getgenv().PallLoader[featureKey]
        
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if state then
            TweenService:Create(SwitchBg, tweenInfo, {BackgroundColor3 = Color3.fromRGB(0, 204, 136)}):Play()
            TweenService:Create(SwitchDot, tweenInfo, {Position = UDim2.new(1, -17, 0.5, -7), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        else
            TweenService:Create(SwitchBg, tweenInfo, {BackgroundColor3 = Color3.fromRGB(45, 45, 60)}):Play()
            TweenService:Create(SwitchDot, tweenInfo, {Position = UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = Color3.fromRGB(150, 150, 170)}):Play()
        end
    end)
end

-- Fungsi Slider Pengatur Ukuran Hitbox
local function createSlider(name, min, max, default, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, 0, 0, 60)
    SliderFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    SliderFrame.Parent = ContentContainer

    local UICornerS = Instance.new("UICorner")
    UICornerS.CornerRadius = UDim.new(0, 6)
    UICornerS.Parent = SliderFrame

    local UIStrokeS = Instance.new("UIStroke")
    UIStrokeS.Color = Color3.fromRGB(40, 40, 55)
    UIStrokeS.Thickness = 1
    UIStrokeS.Parent = SliderFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -30, 0, 25)
    Label.Position = UDim2.new(0, 15, 0, 5)
    Label.BackgroundTransparency = 1
    Label.Text = name .. ": " .. tostring(default)
    Label.TextColor3 = Color3.fromRGB(210, 210, 220)
    Label.TextSize = 13
    Label.Font = Enum.Font.GothamSemibold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = SliderFrame

    local SliderBar = Instance.new("Frame")
    SliderBar.Size = UDim2.new(1, -30, 0, 6)
    SliderBar.Position = UDim2.new(0, 15, 0, 40)
    SliderBar.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    SliderBar.BorderSizePixel = 0
    SliderBar.Parent = SliderFrame

    local UICornerBar = Instance.new("UICorner")
    UICornerBar.CornerRadius = UDim.new(1, 0)
    UICornerBar.Parent = SliderBar

    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(0, 204, 136)
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderBar

    local UICornerFill = Instance.new("UICorner")
    UICornerFill.CornerRadius = UDim.new(1, 0)
    UICornerFill.Parent = SliderFill

    local TriggerButton = Instance.new("TextButton")
    TriggerButton.Size = UDim2.new(1, 0, 1, 10)
    TriggerButton.Position = UDim2.new(0, 0, 0, -5)
    TriggerButton.BackgroundTransparency = 1
    TriggerButton.Text = ""
    TriggerButton.Parent = SliderBar

    local dragging = false
    TriggerButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = math.clamp((input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
            SliderFill.Size = UDim2.new(pos, 0, 1, 0)
            local val = math.floor(min + ((max - min) * pos))
            Label.Text = name .. ": " .. tostring(val)
            callback(val)
        end
    end)
end

-- Susun Menu Berdasarkan Kategori
createSectionHeader("Combat & Kill Systems")
createToggle("Safe Instant Kill (100% Works)", "InstantKill")
createToggle("Kill Aura (Radius 150 Studs)", "KillAura")

createSectionHeader("Hitbox / Hitbar Range Customizer")
createToggle("Hitbox Expander (Long-Range Hit)", "HitboxExpander")
createSlider("Atur Ukuran Hitbox", 2, 20, 5, function(val)
    getgenv().PallLoader.HitboxSize = val
end)

createSectionHeader("Dungeon Farming & Movement")
createToggle("Stage Teleport (Auto Next)", "StageTeleport")
createToggle("Auto Collect Drops", "AutoCollect")
createToggle("Auto Buy & Upgrade Gear", "AutoBuyUpgrade")

createSectionHeader("Visuals & Performance")
createToggle("Custom FOV (120)", "CustomFOV")
createToggle("FPS Unlocker (999 FPS)", "FPSUnlocker")
createToggle("Invisible Mode (Client-side)", "InvisibleMode")

createSectionHeader("Utilities & Security")
createToggle("Anti-AFK System", "AntiAFK")

-- =====================================================================
-- 2. TOMBOL FLOATING APUNG (UNTUK MEMUNCULKAN KEMBALI MENU)
-- =====================================================================
local FloatingGui = Instance.new("ScreenGui")
FloatingGui.Name = "PallLoaderFloatingButton"
FloatingGui.ResetOnSpawn = false
FloatingGui.Parent = PlayerGui

local OpenButton = Instance.new("TextButton")
OpenButton.Size = UDim2.new(0, 45, 0, 45)
OpenButton.Position = UDim2.new(0, 20, 0.5, -22)
OpenButton.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
OpenButton.Text = "⚡"
OpenButton.TextSize = 22
OpenButton.Active = true
OpenButton.Draggable = true
OpenButton.Parent = FloatingGui

local UICornerOpen = Instance.new("UICorner")
UICornerOpen.CornerRadius = UDim.new(1, 0)
UICornerOpen.Parent = OpenButton

local UIStrokeOpen = Instance.new("UIStroke")
UIStrokeOpen.Color = Color3.fromRGB(0, 204, 136)
UIStrokeOpen.Thickness = 2
UIStrokeOpen.Parent = OpenButton

-- Fungsi Sembunyikan & Munculkan Menu
local isVisible = true
local function toggleMenu()
    isVisible = not isVisible
    MainFrame.Visible = isVisible
end

HideButton.MouseButton1Click:Connect(toggleMenu)
OpenButton.MouseButton1Click:Connect(toggleMenu)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.RightShift and not gameProcessed then
        toggleMenu()
    end
end)

-- =====================================================================
-- 3. BACKEND LOGIKA FITUR & EKsekusi
-- =====================================================================
local function getEnemies()
    local enemiesList = {}
    local enemiesFolder = Workspace:FindFirstChild("Enemies") or Workspace:FindFirstChild("Monsters")
    if enemiesFolder then
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            local humanoid = enemy:FindFirstChildOfClass("Humanoid")
            local rootPart = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Torso")
            if humanoid and rootPart and humanoid.Health > 0 then
                table.insert(enemiesList, {Model = enemy, Humanoid = humanoid, RootPart = rootPart})
            end
        end
    end
    return enemiesList
end

-- Logic: Instant Kill & Kill Aura (Radius 150 Studs)
RunService.Heartbeat:Connect(function()
    if getgenv().PallLoader.InstantKill or getgenv().PallLoader.KillAura then
        pcall(function()
            for _, enemyData in ipairs(getEnemies()) do
                if enemyData.Humanoid and enemyData.Humanoid.Health > 0 then
                    if getgenv().PallLoader.InstantKill then
                        enemyData.Humanoid.Health = 0
                        pcall(function() enemyData.Humanoid:BreakJoints() end)
                    elseif getgenv().PallLoader.KillAura then
                        if enemyData.RootPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local dist = (LocalPlayer.Character.HumanoidRootPart.Position - enemyData.RootPart.Position).Magnitude
                            if dist <= 150 then
                                enemyData.Humanoid.Health = 0
                                pcall(function() enemyData.Humanoid:BreakJoints() end)
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- Logic: Hitbox Expander
RunService.RenderStepped:Connect(function()
    if getgenv().PallLoader.HitboxExpander then
        pcall(function()
            for _, enemyData in ipairs(getEnemies()) do
                if enemyData.RootPart then
                    enemyData.RootPart.Size = Vector3.new(getgenv().PallLoader.HitboxSize, getgenv().PallLoader.HitboxSize, getgenv().PallLoader.HitboxSize)
                    enemyData.RootPart.Transparency = 0.7
                    enemyData.RootPart.BrickColor = BrickColor.new("Bright green")
                    enemyData.RootPart.CanCollide = false
                end
            end
        end)
    end
end)

RunService.Stepped:Connect(function()
    if getgenv().PallLoader.StageTeleport and LocalPlayer.Character then
        pcall(function()
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if obj.Name:lower():find("door") or obj.Name:lower():find("portal") or obj.Name:lower():find("gate") then
                        local portalPart = obj:FindFirstChild("Part") or obj:FindFirstChildOfClass("BasePart")
                        if portalPart then
                            hrp.CFrame = portalPart.CFrame + Vector3.new(0, 3, 0)
                        end
                    end
                end
            end
        end)
    end
end)

RunService.Stepped:Connect(function()
    if getgenv().PallLoader.AutoCollect and LocalPlayer.Character then
        pcall(function()
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dropsFolder = Workspace:FindFirstChild("Drops") or Workspace:FindFirstChild("Loot")
                if dropsFolder then
                    for _, drop in ipairs(dropsFolder:GetChildren()) do
                        local part = drop:FindFirstChild("Part") or drop:FindFirstChildOfClass("BasePart")
                        if part then
                            part.CFrame = hrp.CFrame
                        end
                    end
                end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(2) do
        if getgenv().PallLoader.AutoBuyUpgrade then
            pcall(function()
                local shops = Workspace:FindFirstChild("Shops") or Workspace:FindFirstChild("NPCs")
                if shops then
                    for _, shop in ipairs(shops:GetChildren()) do
                        local prompt = shop:FindFirstChildOfClass("ProximityPrompt")
                        if prompt then
                            fireproximityprompt(prompt)
                        end
                    end
                end
            end)
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if getgenv().PallLoader.CustomFOV then
        Camera.FieldOfView = getgenv().PallLoader.FOVValue
    end
    if getgenv().PallLoader.FPSUnlocker then
        setfpscap(999)
    end
end)

task.spawn(function()
    while task.wait(1) do
        if getgenv().PallLoader.InvisibleMode and LocalPlayer.Character then
            pcall(function()
                for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.Transparency = 1
                    elseif part:IsA("Decal") then
                        part.Transparency = 1
                    end
                end
            end)
        end
    end
end)

local vu = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    if getgenv().PallLoader.AntiAFK then
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

print("Pall Loader v8.1 Loaded Successfully!")
