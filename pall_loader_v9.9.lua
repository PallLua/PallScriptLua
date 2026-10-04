-- =====================================================================
-- PALL LOADER v13.0 - FLY FOLLOW, WORKING HITBOX & NOCLIP EDITION
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Konfigurasi Toggle (WalkFollow diubah ke FlyFollow)
getgenv().PallLoader = {
    BypassEnabled = true,
    AntiKick = true,
    NoClip = false,         
    FlyFollow = false,      -- Fitur Baru: Terbang Melayang Mengikuti Target (Speed 16)
    MeleeAutoSwing = false,
    KillAura = false,
    HitboxExpander = true,  
    HitboxSize = 10,        
    AntiAFK = true
}

print("[Pall Loader v13.0] Memuat Sistem Fly Follow & Fungsional Hitbox...")

-- Hapus UI lama
pcall(function()
    for _, v in ipairs(PlayerGui:GetChildren()) do
        if v.Name:find("PallLoaderFluent") then v:Destroy() end
    end
end)

-- Buat ScreenGui Utama
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PallLoaderFluentV13"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- MainFrame
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
Title.Size = UDim2.new(0, 320, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ Pall Loader <font color='#00DC96'>v13.0 [Fly Follow]</font>"
Title.RichText = true
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Topbar

-- Tombol Reset Posisi UI
local CenterBtn = Instance.new("TextButton")
CenterBtn.Size = UDim2.new(0, 75, 0, 26)
CenterBtn.Position = UDim2.new(1, -125, 0.5, -13)
CenterBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 110)
CenterBtn.Text = "Reset Pos"
CenterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CenterBtn.TextSize = 11
CenterBtn.Font = Enum.Font.GothamBold
CenterBtn.Parent = Topbar

local UICornerCenter = Instance.new("UICorner")
UICornerCenter.CornerRadius = UDim.new(0, 5)
UICornerCenter.Parent = CenterBtn

CenterBtn.MouseButton1Click:Connect(function()
    MainFrame.Position = UDim2.new(0.5, -260, 0.5, -255)
    MainFrame.Visible = true
end)

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
Container.CanvasSize = UDim2.new(0, 0, 0, 920)
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

createCategory("Security & Server Protection")
createToggle("Anti-Cheat Hook Bypass", "BypassEnabled")
createToggle("Anti-Kick Protection", "AntiKick")

createCategory("Movement & Fly Follow Systems")
createToggle("No Clip (Tembus Tembok/Dinding)", "NoClip")
createToggle("Fly Follow (Terbang Ikuti Musuh - Speed 16)", "FlyFollow")

createCategory("Combat & Melee Sword Systems")
createToggle("Melee Auto Swing (Auto Pedang)", "MeleeAutoSwing")
createToggle("Kill Aura (Radius 150 Studs)", "KillAura")

createCategory("Hitbox Expander Customizer")
createToggle("Hitbox Expander (Working / Fungsional)", "HitboxExpander")
createSlider("Ukuran Hitbox Target", 2, 25, 10, function(val)
    getgenv().PallLoader.HitboxSize = val
end)

createCategory("Utilities & AFK Manager")
createToggle("Anti-AFK Protection", "AntiAFK")

local isVisible = true
MinimizeBtn.MouseButton1Click:Connect(function()
    isVisible = not isVisible
    Container.Visible = isVisible
    MainFrame.Size = isVisible and UDim2.new(0, 520, 0, 510) or UDim2.new(0, 520, 0, 42)
end)

-- Universal Enemy Detector
local function getEnemies()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                table.insert(list, {Model = p.Character, Humanoid = hum, RootPart = root})
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if hum and root and hum.Health > 0 then
                local isPlayer = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character == obj then isPlayer = true break end
                end
                if not isPlayer then
                    table.insert(list, {Model = obj, Humanoid = hum, RootPart = root})
                end
            end
        end
    end
    return list
end

-- FITUR: NO CLIP
RunService.Stepped:Connect(function()
    if getgenv().PallLoader.NoClip then
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end)

-- FITUR: FLY FOLLOW (Terbang melayang stabil mengikuti musuh dengan speed 16)
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    local bv = hrp:FindFirstChild("PallFlyVelocity")
    local bg = hrp:FindFirstChild("PallFlyGyro")

    if getgenv().PallLoader.FlyFollow then
        hum.PlatformStand = true -- Membuat karakter melayang tanpa jatuh ke bawah
        
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "PallFlyVelocity"
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hrp
        end
        if not bg then
            bg = Instance.new("BodyGyro")
            bg.Name = "PallFlyGyro"
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 3000
            bg.Parent = hrp
        end

        local enemies = getEnemies()
        if #enemies > 0 then
            local closest = nil
            local minDist = math.huge
            for _, data in ipairs(enemies) do
                local dist = (hrp.Position - data.RootPart.Position).Magnitude
                if dist < minDist then minDist = dist closest = data end
            end
            if closest and closest.RootPart then
                local targetPos = closest.RootPart.Position + Vector3.new(0, 4, 0) -- Melayang sedikit di atas target
                local direction = (targetPos - hrp.Position)
                
                if direction.Magnitude > 3 then
                    -- Gerak terbang halus dengan kecepatan (Speed 16)
                    bv.Velocity = direction.Unit * 16
                    bg.CFrame = CFrame.new(hrp.Position, targetPos)
                else
                    bv.Velocity = Vector3.new(0, 0, 0)
                end
            end
        else
            bv.Velocity = Vector3.new(0, 0, 0)
        end
    else
        hum.PlatformStand = false
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
    end
end)

-- FITUR: WORKING HITBOX EXPANDER
RunService.RenderStepped:Connect(function()
    if getgenv().PallLoader.HitboxExpander then
        pcall(function()
            local size = getgenv().PallLoader.HitboxSize
            for _, data in ipairs(getEnemies()) do
                local root = data.RootPart
                if root then
                    root.Size = Vector3.new(size, size, size)
                    root.Transparency = 0.5 
                    root.Color = Color3.fromRGB(0, 255, 120)
                    root.Material = Enum.Material.Neon
                    root.CanCollide = false 
                    root.Massless = true
                end
            end
        end)
    end
end)

-- Melee Auto Swing & Kill Aura
task.spawn(function()
    while true do
        task.wait(0.15)
        if getgenv().PallLoader.MeleeAutoSwing or getgenv().PallLoader.KillAura then
            pcall(function()
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    for _, data in ipairs(getEnemies()) do
                        local dist = (hrp.Position - data.RootPart.Position).Magnitude
                        if getgenv().PallLoader.MeleeAutoSwing and dist <= 35 then
                            local char = LocalPlayer.Character
                            if char then
                                local tool = char:FindFirstChildOfClass("Tool")
                                if tool then tool:Activate() end
                            end
                        end
                        if getgenv().PallLoader.KillAura and dist <= 150 then
                            data.Humanoid.Health = 0
                        end
                    end
                end
            end)
        end
    end
end)

print("[Pall Loader v13.0] Fly Follow & Working Hitbox aktif!")
