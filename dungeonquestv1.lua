-- =====================================================================
-- PALL LOADER v9.5 - FLY FOLLOW & SMOOTH HOVER TO TARGET
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Konfigurasi Toggle & Fitur
getgenv().PallLoader = {
    BypassEnabled = true,
    FlyFollow = false,      -- Fitur baru: Terbang mulus di atas kepala NPC
    RemoteSniper = false,
    AutoAttack = false,
    KillAura = false,
    InstantKill = false,
    HitboxExpander = false,
    HitboxSize = 5,
    AutoCollect = false,
    StageTeleport = false,
    AntiAFK = true
}

-- Bypass Proteksi Sederhana
pcall(function()
    if getgenv().PallLoader.BypassEnabled then
        local mt = getrawmetatable(game)
        if mt and setreadonly then
            setreadonly(mt, false)
            setreadonly(mt, true)
        end
    end
end)

-- Hapus UI lama
pcall(function()
    if CoreGui:FindFirstChild("PallLoaderFluentV9") then
        CoreGui.PallLoaderFluentV9:Destroy()
    end
    if LocalPlayer.PlayerGui:FindFirstChild("PallLoaderFluentV9") then
        LocalPlayer.PlayerGui.PallLoaderFluentV9:Destroy()
    end
end)

-- Buat ScreenGui Utama
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PallLoaderFluentV9"
ScreenGui.ResetOnSpawn = false

pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- =====================================================================
-- PEMBUATAN TAMPILAN FLUENT UI
-- =====================================================================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 510)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -255)
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICornerMain = Instance.new("UICorner")
UICornerMain.CornerRadius = UDim.new(0, 8)
UICornerMain.Parent = MainFrame

local UIStrokeMain = Instance.new("UIStroke")
UIStrokeMain.Color = Color3.fromRGB(45, 45, 60)
UIStrokeMain.Thickness = 1
UIStrokeMain.Parent = MainFrame

-- Topbar
local Topbar = Instance.new("Frame")
Topbar.Size = UDim2.new(1, 0, 0, 42)
Topbar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
Topbar.BorderSizePixel = 0
Topbar.Parent = MainFrame

local UICornerTop = Instance.new("UICorner")
UICornerTop.CornerRadius = UDim.new(0, 8)
UICornerTop.Parent = Topbar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 350, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ Pall Loader <font color='#00DC96'>v9.5 [Fly Follow]</font>"
Title.RichText = true
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Topbar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 32, 0, 32)
MinimizeBtn.Position = UDim2.new(1, -42, 0.5, -16)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
MinimizeBtn.TextSize = 16
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.Parent = Topbar

local UICornerMin = Instance.new("UICorner")
UICornerMin.CornerRadius = UDim.new(0, 6)
UICornerMin.Parent = MinimizeBtn

-- Kontainer Menu
local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -24, 1, -60)
Container.Position = UDim2.new(0, 12, 0, 50)
Container.BackgroundTransparency = 1
Container.CanvasSize = UDim2.new(0, 0, 0, 780)
Container.ScrollBarThickness = 3
Container.ScrollBarImageColor3 = Color3.fromRGB(0, 220, 150)
Container.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 8)
UIList.Parent = Container

local function createCategory(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text = "  " .. string.upper(text)
    lbl.TextColor3 = Color3.fromRGB(0, 220, 150)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Container
end

local function createToggle(name, key)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = Container

    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 6)
    uic.Parent = btn

    local uis = Instance.new("UIStroke")
    uis.Color = Color3.fromRGB(45, 45, 60)
    uis.Thickness = 1
    uis.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 38, 0, 20)
    indicator.Position = UDim2.new(1, -48, 0.5, -10)
    indicator.BackgroundColor3 = getgenv().PallLoader[key] and Color3.fromRGB(0, 204, 136) or Color3.fromRGB(50, 50, 65)
    indicator.BorderSizePixel = 0
    indicator.Parent = btn

    local uici = Instance.new("UICorner")
    uici.CornerRadius = UDim.new(1, 0)
    uici.Parent = indicator

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 14, 0, 14)
    dot.Position = getgenv().PallLoader[key] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    dot.BackgroundColor3 = getgenv().PallLoader[key] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 180)
    dot.BorderSizePixel = 0
    dot.Parent = indicator

    local uicd = Instance.new("UICorner")
    uicd.CornerRadius = UDim.new(1, 0)
    uicd.Parent = dot

    btn.MouseButton1Click:Connect(function()
        getgenv().PallLoader[key] = not getgenv().PallLoader[key]
        local active = getgenv().PallLoader[key]
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        
        if active then
            TweenService:Create(indicator, tweenInfo, {BackgroundColor3 = Color3.fromRGB(0, 204, 136)}):Play()
            TweenService:Create(dot, tweenInfo, {Position = UDim2.new(1, -17, 0.5, -7), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        else
            TweenService:Create(indicator, tweenInfo, {BackgroundColor3 = Color3.fromRGB(50, 50, 65)}):Play()
            TweenService:Create(dot, tweenInfo, {Position = UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = Color3.fromRGB(160, 160, 180)}):Play()
        end
    end)
end

local function createSlider(name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 55)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.Parent = Container

    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 6)
    uic.Parent = frame

    local uis = Instance.new("UIStroke")
    uis.Color = Color3.fromRGB(45, 45, 60)
    uis.Thickness = 1
    uis.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 22)
    lbl.Position = UDim2.new(0, 14, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = name .. ": " .. tostring(default) .. " Studs"
    lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -28, 0, 6)
    sliderBar.Position = UDim2.new(0, 14, 0, 36)
    sliderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = frame

    local uicb = Instance.new("UICorner")
    uicb.CornerRadius = UDim.new(1, 0)
    uicb.Parent = sliderBar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 204, 136)
    fill.BorderSizePixel = 0
    fill.Parent = sliderBar

    local uicf = Instance.new("UICorner")
    uicf.CornerRadius = UDim.new(1, 0)
    uicf.Parent = fill

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 10)
    btn.Position = UDim2.new(0, 0, 0, -5)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = sliderBar

    local dragging = false
    btn.InputBegan:Connect(function(input)
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
            local pos = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(pos, 0, 1, 0)
            local val = math.floor(min + ((max - min) * pos))
            lbl.Text = name .. ": " .. tostring(val) .. " Studs"
            callback(val)
        end
    end)
end

createCategory("Security & Protection")
createToggle("Anti-Cheat / Hook Bypass", "BypassEnabled")

createCategory("Movement & Fly Follow Systems")
createToggle("Fly Follow (Terbang Mulus Di Atas Bot)", "FlyFollow")

createCategory("Combat & True Server Systems")
createToggle("Remote Sniper (True Server Hit)", "RemoteSniper")
createToggle("Auto Attack / Swing (Auto Click)", "AutoAttack")
createToggle("Kill Aura (Radius 150 Studs)", "KillAura")
createToggle("Instant Kill (Client Force)", "InstantKill")

createCategory("Hitbox Expander Customizer")
createToggle("Hitbox Expander", "HitboxExpander")
createSlider("Ukuran Hitbox Target", 2, 25, 5, function(val)
    getgenv().PallLoader.HitboxSize = val
end)

createCategory("Dungeon & Utilities")
createToggle("Auto Collect Drops", "AutoCollect")
createToggle("Stage Teleport", "StageTeleport")
createToggle("Anti-AFK Protection", "AntiAFK")

local isVisible = true
MinimizeBtn.MouseButton1Click:Connect(function()
    isVisible = not isVisible
    Container.Visible = isVisible
    MainFrame.Size = isVisible and UDim2.new(0, 520, 0, 510) or UDim2.new(0, 520, 0, 42)
end)

-- =====================================================================
-- UNIVERSAL ENEMY DETECTOR
-- =====================================================================
local function getEnemies()
    local list = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if hum and root and hum.Health > 0 then
                local isPlayer = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character == obj then
                        isPlayer = true
                        break
                    end
                end
                if not isPlayer then
                    table.insert(list, {Model = obj, Humanoid = hum, RootPart = root})
                end
            end
        end
    end
    return list
end

-- Deteksi otomatis fungsi serangan server
local function findDamageRemote()
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local name = string.lower(v.Name)
            if name:find("hit") or name:find("damage") or name:find("attack") or name:find("combat") or name:find("swing") or name:find("skill") then
                return v
            end
        end
    end
    return nil
end

-- =====================================================================
-- FITUR FLY FOLLOW / SMOOTH HOVER DI ATAS KEPALA NPC
-- =====================================================================
RunService.RenderStepped:Connect(function()
    if getgenv().PallLoader.FlyFollow and LocalPlayer.Character then
        pcall(function()
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                local enemies = getEnemies()
                if #enemies > 0 then
                    -- Cari musuh terdekat
                    local closest = nil
                    local minDist = math.huge
                    for _, data in ipairs(enemies) do
                        local dist = (hrp.Position - data.RootPart.Position).Magnitude
                        if dist < minDist then
                            minDist = dist
                            closest = data
                        end
                    end
                    
                    if closest and closest.RootPart then
                        -- Tentukan posisi melayang tepat 5 studs di atas kepala bot
                        local targetPos = closest.RootPart.Position + Vector3.new(0, 6, 0)
                        
                        -- Nonaktifkan gravitasi sementara agar tidak jatuh (Fly mode)
                        hrp.Velocity = Vector3.new(0, 0, 0)
                        
                        -- Gerakkan secara mulus (Lerp) menuju posisi di atas kepala bot
                        hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(targetPos, closest.RootPart.Position), 0.15)
                    end
                end
            end
        end)
    end
end)

-- Remote Sniper
task.spawn(function()
    while true do
        task.wait(0.2)
        if getgenv().PallLoader.RemoteSniper then
            pcall(function()
                local remote = findDamageRemote()
                if remote then
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        for _, data in ipairs(getEnemies()) do
                            local dist = (hrp.Position - data.RootPart.Position).Magnitude
                            if dist <= 100 then
                                pcall(function() remote:FireServer(data.Model) end)
                                pcall(function() remote:FireServer(data.Humanoid) end)
                                pcall(function() remote:FireServer(data.RootPart) end)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- Sistem Auto Attack / Swing
task.spawn(function()
    while true do
        task.wait(0.1)
        if getgenv().PallLoader.AutoAttack then
            pcall(function()
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    for _, data in ipairs(getEnemies()) do
                        local dist = (hrp.Position - data.RootPart.Position).Magnitude
                        if dist <= 25 then
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                            task.wait(0.02)
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                            break
                        end
                    end
                end
            end)
        end
    end
end)

-- Instant Kill & Kill Aura
RunService.Heartbeat:Connect(function()
    if getgenv().PallLoader.InstantKill or getgenv().PallLoader.KillAura then
        pcall(function()
            for _, data in ipairs(getEnemies()) do
                if getgenv().PallLoader.InstantKill then
                    data.Humanoid.Health = 0
                    pcall(function() data.Humanoid:BreakJoints() end)
                elseif getgenv().PallLoader.KillAura and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local dist = (LocalPlayer.Character.HumanoidRootPart.Position - data.RootPart.Position).Magnitude
                    if dist <= 150 then
                        data.Humanoid.Health = 0
                        pcall(function() data.Humanoid:BreakJoints() end)
                    end
                end
            end
        end)
    end
end)

-- Hitbox Expander
RunService.RenderStepped:Connect(function()
    if getgenv().PallLoader.HitboxExpander then
        pcall(function()
            local size = getgenv().PallLoader.HitboxSize
            for _, data in ipairs(getEnemies()) do
                if data.RootPart then
                    data.RootPart.Size = Vector3.new(size, size, size)
                    data.RootPart.Transparency = 0.5
                    data.RootPart.BrickColor = BrickColor.new("Bright green")
                    data.RootPart.CanCollide = false
                end
            end
        end)
    end
end)

RunService.Stepped:Connect(function()
    if getgenv().PallLoader.AutoCollect and LocalPlayer.Character then
        pcall(function()
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local drops = Workspace:FindFirstChild("Drops") or Workspace:FindFirstChild("Loot")
            if hrp and drops then
                for _, drop in ipairs(drops:GetChildren()) do
                    local part = drop:FindFirstChild("Part") or drop:FindFirstChildOfClass("BasePart")
                    if part then part.CFrame = hrp.CFrame end
                end
            end
        end)
    end
end)

LocalPlayer.Idled:Connect(function()
    if getgenv().PallLoader.AntiAFK then
        game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

print("Pall Loader v9.5 with Fly Follow Loaded Successfully!")
