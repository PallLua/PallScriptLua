-- =====================================================================
-- BANANA HUB v7 - FIXED UI LOADER
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Konfigurasi Toggle Fitur
getgenv().BananaHub = {
    AutoCollect = false,
    AutoNextStage = false,
    KillAura = false,
    InstantKill = false, -- True Damage Mode
    StageTeleport = false,
    AutoBuyUpgrade = false,
    CustomFOV = false,
    FOVValue = 120,
    FPSUnlocker = false,
    InvisibleMode = false,
    AntiAFK = true
}

-- Hapus GUI lama jika ada
pcall(function()
    if CoreGui:FindFirstChild("BananaFluentHub") then
        CoreGui.BananaFluentHub:Destroy()
    end
    if LocalPlayer.PlayerGui:FindFirstChild("BananaFluentHub") then
        LocalPlayer.PlayerGui.BananaFluentHub:Destroy()
    end
end)

-- =====================================================================
-- 1. PEMBUATAN UI UTAMA (DI COREGUI / PLAYERGUI)
-- =====================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BananaFluentHub"
ScreenGui.ResetOnSpawn = false

-- Amankan pemasangan GUI ke CoreGui atau PlayerGui
pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Main Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 550, 0, 380)
MainFrame.Position = UDim2.new(0.5, -275, 0.5, -190)
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
TitleLabel.Size = UDim2.new(0, 300, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🍌  Banana Hub  <font color='#00FFAA'>v7 [Fixed]</font>"
TitleLabel.RichText = true
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
TitleLabel.TextSize = 15
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local SubTitleLabel = Instance.new("TextLabel")
SubTitleLabel.Size = UDim2.new(0, 200, 1, 0)
SubTitleLabel.Position = UDim2.new(1, -215, 0, 0)
SubTitleLabel.BackgroundTransparency = 1
SubTitleLabel.Text = "[Right Shift] to Hide"
SubTitleLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
SubTitleLabel.TextSize = 12
SubTitleLabel.Font = Enum.Font.Gotham
SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Right
SubTitleLabel.Parent = TopBar

-- Content Container
local ContentContainer = Instance.new("ScrollingFrame")
ContentContainer.Size = UDim2.new(1, -30, 1, -65)
ContentContainer.Position = UDim2.new(0, 15, 0, 52)
ContentContainer.BackgroundTransparency = 1
ContentContainer.CanvasSize = UDim2.new(0, 0, 0, 520)
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
        getgenv().BananaHub[featureKey] = not getgenv().BananaHub[featureKey]
        local state = getgenv().BananaHub[featureKey]
        
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

-- Susun Menu
createSectionHeader("Combat & Kill Systems")
createToggle("Safe True-Damage Instant Kill", "InstantKill")
createToggle("Kill Aura (35 Studs)", "KillAura")

createSectionHeader("Dungeon Farming & Movement")
createToggle("Stage Teleport (Auto Next)", "StageTeleport")
createToggle("Auto Collect Drops", "AutoCollect")
createToggle("Auto Buy & Upgrade Gear", "AutoBuyUpgrade")

createSectionHeader("Visuals & Performance")
createToggle("Custom FOV (120)", "CustomFOV")
createToggle("FPS Unlocker (999 FPS)", "FPSUnlocker")
createToggle("Invisible Mode (Client-side)", "InvisibleMode")

createSectionHeader("Utilities")
createToggle("Anti-AFK System", "AntiAFK")

-- Shortcut Toggle Menu (Right Shift)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.RightShift and not gameProcessed then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- =====================================================================
-- 2. BACKEND LOGIKA FITUR
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

RunService.Heartbeat:Connect(function()
    if getgenv().BananaHub.InstantKill or getgenv().BananaHub.KillAura then
        pcall(function()
            for _, enemyData in ipairs(getEnemies()) do
                if enemyData.Humanoid and enemyData.Humanoid.Health > 0 then
                    if getgenv().BananaHub.InstantKill then
                        enemyData.Humanoid.Health = 0
                    elseif getgenv().BananaHub.KillAura then
                        if enemyData.RootPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local dist = (LocalPlayer.Character.HumanoidRootPart.Position - enemyData.RootPart.Position).Magnitude
                            if dist <= 35 then
                                enemyData.Humanoid:TakeDamage(5000)
                            end
                        end
                    end
                end
            end
        end)
    end
end)

RunService.Stepped:Connect(function()
    if getgenv().BananaHub.StageTeleport and LocalPlayer.Character then
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
    if getgenv().BananaHub.AutoCollect and LocalPlayer.Character then
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
        if getgenv().BananaHub.AutoBuyUpgrade then
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
    if getgenv().BananaHub.CustomFOV then
        Camera.FieldOfView = getgenv().BananaHub.FOVValue
    end
    if getgenv().BananaHub.FPSUnlocker then
        setfpscap(999)
    end
end)

task.spawn(function()
    while task.wait(1) do
        if getgenv().BananaHub.InvisibleMode and LocalPlayer.Character then
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
    if getgenv().BananaHub.AntiAFK then
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

print("Banana Hub v7 Fixed UI Loaded Successfully!")
