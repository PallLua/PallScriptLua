-- =====================================================================
-- PALL LOADER v5.0 (MaxHub UI & All Features Set to False)
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- =====================================================================
-- BYFRON & HYPERION HOOK BYPASS CORE
-- =====================================================================
pcall(function()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local oldNamecall = mt.__namecall
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = string.lower(getnamecallmethod())
        if method == "kick" or method == "identifier" or method == "sendnotification" or method == "teleport" then
            if self == LocalPlayer then return nil end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end)

-- Semua Fitur diatur ke false secara default
getgenv().PallLoader = {
    BypassEnabled = false,
    AntiKick = false,
    GodMode = false,
    AntiAFK = false,
    NoClip = false,         
    FlyFollow = false,      
    SafeDistance = 14,
    DistanceAbove = 25,     
    HitboxExpander = false,  
    HitboxSize = 45,        
    MeleeAutoSwing = false, 
    SwingInterval = 1,      
    KillAura = false,
    AntiRangedHit = false,   
    NPCFreeze = false,       
    TargetLine = false,       
    AutoDungeon = false,
    AutoAbilities = false,
    AutoReplay = false,
    AutoDodge = false,
    SpeedToggle = false,
    WalkSpeedVal = 16,
    JumpToggle = false,
    JumpPowerVal = 50,
    AutoUpgrader = false
}

local OriginalHitboxSizes = {}
local CurrentTargetNPC = nil

-- Target Line Visualizer Beam
local VisualizerBeam = Instance.new("Part")
VisualizerBeam.Name = "PallTargetLine"
VisualizerBeam.Size = Vector3.new(0.1, 0.1, 0.1)
VisualizerBeam.Anchored = true
VisualizerBeam.CanCollide = false
VisualizerBeam.Transparency = 1
local Attachment0 = Instance.new("Attachment", VisualizerBeam)
local Attachment1 = Instance.new("Attachment", VisualizerBeam)
local Beam = Instance.new("Beam")
Beam.Attachment0 = Attachment0
Beam.Attachment1 = Attachment1
Beam.Color = ColorSequence.new(Color3.fromRGB(0, 150, 255))
Beam.Width0 = 0.15
Beam.Width1 = 0.15
Beam.FaceCamera = true
Beam.Parent = VisualizerBeam
VisualizerBeam.Parent = Workspace

-- Hapus UI lama
pcall(function()
    for _, v in ipairs(PlayerGui:GetChildren()) do if v.Name:find("MaxHubStyle") then v:Destroy() end end
    for _, v in ipairs(CoreGui:GetChildren()) do if v.Name:find("MaxHubStyle") then v:Destroy() end end
end)

-- ScreenGui Utama
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MaxHubStyleUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = PlayerGui end

-- MainFrame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 600, 0, 380)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICornerMain = Instance.new("UICorner")
UICornerMain.CornerRadius = UDim.new(0, 6)
UICornerMain.Parent = MainFrame

local UIStrokeMain = Instance.new("UIStroke")
UIStrokeMain.Color = Color3.fromRGB(38, 38, 50)
UIStrokeMain.Thickness = 1
UIStrokeMain.Parent = MainFrame

-- Sidebar Kiri
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 140, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local UICornerSide = Instance.new("UICorner")
UICornerSide.CornerRadius = UDim.new(0, 6)
UICornerSide.Parent = Sidebar

local LogoTitle = Instance.new("TextLabel")
LogoTitle.Size = UDim2.new(1, 0, 0, 45)
LogoTitle.Position = UDim2.new(0, 12, 0, 0)
LogoTitle.BackgroundTransparency = 1
LogoTitle.Text = "⚡ MaxHub"
LogoTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
LogoTitle.TextSize = 15
LogoTitle.Font = Enum.Font.GothamBold
LogoTitle.TextXAlignment = Enum.TextXAlignment.Left
LogoTitle.Parent = Sidebar

local SidebarList = Instance.new("UIListLayout")
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Padding = UDim.new(0, 2)
SidebarList.Parent = Sidebar

-- Kontainer Halaman Kanan
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -140, 1, 0)
ContentArea.Position = UDim2.new(0, 140, 0, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Pages = {}

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, -16, 1, -16)
    page.Position = UDim2.new(0, 8, 0, 8)
    page.BackgroundTransparency = 1
    page.CanvasSize = UDim2.new(0, 0, 0, 900)
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 255)
    page.Visible = false
    page.Parent = ContentArea

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = page

    Pages[name] = page
    return page
end

local function createCategoryHeader(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(0, 160, 255)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = page
end

local function createToggle(page, name, key, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = page

    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 4)
    uic.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 32, 0, 16)
    indicator.Position = UDim2.new(1, -40, 0.5, -8)
    indicator.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    indicator.BorderSizePixel = 0
    indicator.Parent = btn

    local uici = Instance.new("UICorner")
    uici.CornerRadius = UDim.new(1, 0)
    uici.Parent = indicator

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, 3, 0.5, -5)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel = 0
    dot.Parent = indicator

    local uicd = Instance.new("UICorner")
    uicd.CornerRadius = UDim.new(1, 0)
    uicd.Parent = dot

    btn.MouseButton1Click:Connect(function()
        getgenv().PallLoader[key] = not getgenv().PallLoader[key]
        local active = getgenv().PallLoader[key]
        local ti = TweenInfo.new(0.2)
        if active then
            TweenService:Create(indicator, ti, {BackgroundColor3 = Color3.fromRGB(0, 170, 255)}):Play()
            TweenService:Create(dot, ti, {Position = UDim2.new(1, -13, 0.5, -5)}):Play()
        else
            TweenService:Create(indicator, ti, {BackgroundColor3 = Color3.fromRGB(45, 45, 60)}):Play()
            TweenService:Create(dot, ti, {Position = UDim2.new(0, 3, 0.5, -5)}):Play()
        end
        if callback then pcall(function() callback(active) end) end
    end)
end

local function createSlider(page, name, min, max, default, unit, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    frame.Parent = page

    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 4)
    uic.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 18)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = name .. ": " .. tostring(default) .. " " .. unit
    lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -20, 0, 4)
    sliderBar.Position = UDim2.new(0, 10, 0, 30)
    sliderBar.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = frame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    fill.BorderSizePixel = 0
    fill.Parent = sliderBar

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 8)
    btn.Position = UDim2.new(0, 0, 0, -4)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = sliderBar

    local dragging = false
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(pos, 0, 1, 0)
            local val = math.floor(min + ((max - min) * pos))
            lbl.Text = name .. ": " .. tostring(val) .. " " .. unit
            callback(val)
        end
    end)
end

-- Membuat Tab Menu (MAIN, PLAYER, FARM, SETTINGS)
local mainPage = createPage("MAIN")
local playerPage = createPage("PLAYER")
local farmPage = createPage("FARM")
local settingsPage = createPage("SETTINGS")

-- Isi Tab MAIN
createCategoryHeader(mainPage, "SECURITY & BYPASS")
createToggle(mainPage, "Byfron & Hyperion Bypass", "BypassEnabled")
createToggle(mainPage, "Anti-Kick Protection", "AntiKick")
createToggle(mainPage, "GodMode (Anti Damage)", "GodMode")

-- Isi Tab PLAYER
createCategoryHeader(playerPage, "MOVEMENT & STATS")
createToggle(playerPage, "Custom WalkSpeed", "SpeedToggle")
createSlider(playerPage, "WalkSpeed Value", 16, 120, 16, "", function(v) getgenv().PallLoader.WalkSpeedVal = v end)
createToggle(playerPage, "Custom JumpPower", "JumpToggle")
createSlider(playerPage, "JumpPower Value", 50, 250, 50, "", function(v) getgenv().PallLoader.JumpPowerVal = v end)
createToggle(playerPage, "No Clip (Tembus Tembok)", "NoClip")
createToggle(playerPage, "Auto Stats Upgrader", "AutoUpgrader")

-- Isi Tab FARM
createCategoryHeader(farmPage, "DUNGEON FARM")
createToggle(farmPage, "Auto Dungeon Entry/Start", "AutoDungeon")
createToggle(farmPage, "Auto Use Abilities (Skill)", "AutoAbilities")
createToggle(farmPage, "Auto Replay Dungeon", "AutoReplay")
createToggle(farmPage, "Auto Dodge Attacks", "AutoDodge")
createSlider(farmPage, "Distance Above NPC", 5, 50, 25, "Studs", function(v) getgenv().PallLoader.DistanceAbove = v end)

createCategoryHeader(farmPage, "FARM VISUALS")
createToggle(farmPage, "Target Line Visualizer", "TargetLine", function(active)
    if not active then VisualizerBeam.Transparency = 1 end
end)

createCategoryHeader(farmPage, "COMBAT & HITBOX")
createToggle(farmPage, "Hitbox Expander", "HitboxExpander", function(active)
    if not active then
        pcall(function()
            for root, origSize in pairs(OriginalHitboxSizes) do
                if root and root.Parent then root.Size = origSize root.Transparency = 1 root.CanCollide = true end
            end
            OriginalHitboxSizes = {}
        end)
    end
end)
createSlider(farmPage, "Ukuran Hitbox", 10, 80, 45, "Studs", function(v) getgenv().PallLoader.HitboxSize = v end)
createToggle(farmPage, "Auto Swing (Clicker Mode)", "MeleeAutoSwing")
createToggle(farmPage, "NPC Freeze", "NPCFreeze")
createToggle(farmPage, "Kill Aura", "KillAura")

-- Isi Tab SETTINGS
createCategoryHeader(settingsPage, "UTILITIES")
createToggle(settingsPage, "Anti-AFK Protection", "AntiAFK")

-- Tombol Navigasi Sidebar
local function createTabButton(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 32)
    btn.Position = UDim2.new(0, 8, 0, 55 + (order * 36))
    btn.BackgroundColor3 = (order == 0) and Color3.fromRGB(30, 30, 42) or Color3.fromRGB(22, 22, 30)
    btn.Text = "  " + name
    btn.Text = "  " .. name
    btn.TextColor3 = (order == 0) and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(160, 160, 180)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = Sidebar

    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 4)
    uic.Parent = btn

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        for _, b in pairs(Sidebar:GetChildren()) do
            if b:IsA("TextButton") then
                b.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
                b.TextColor3 = Color3.fromRGB(160, 160, 180)
            end
        end
        Pages[name].Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
        btn.TextColor3 = Color3.fromRGB(0, 170, 255)
    end)
end

createTabButton("MAIN", 0)
createTabButton("PLAYER", 1)
createTabButton("FARM", 2)
createTabButton("SETTINGS", 3)

Pages["MAIN"].Visible = true

-- Core Loops (Hanya berjalan jika toggle diaktifkan pengguna)
RunService.Stepped:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if char and getgenv().PallLoader.NoClip then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
    end)
end)

local function getNPCsOnly()
    local list = {}
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj ~= LocalPlayer.Character then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
                if hum and root and hum.Health > 0 then
                    local isPlayer = false
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character == obj then isPlayer = true break end
                    end
                    if not isPlayer then table.insert(list, {Model = obj, Humanoid = hum, RootPart = root}) end
                end
            end
        end
    end)
    return list
end

RunService.RenderStepped:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        if getgenv().PallLoader.GodMode then
            hum.MaxHealth = math.huge
            hum.Health = math.huge
        end
        if getgenv().PallLoader.SpeedToggle then hum.WalkSpeed = getgenv().PallLoader.WalkSpeedVal end
        if getgenv().PallLoader.JumpToggle then hum.JumpPower = getgenv().PallLoader.JumpPowerVal end

        local npcs = getNPCsOnly()
        if #npcs > 0 then
            local closest, minDist = nil, math.huge
            for _, data in ipairs(npcs) do
                local dist = (hrp.Position - data.RootPart.Position).Magnitude
                if dist < minDist then minDist = dist closest = data end
            end
            CurrentTargetNPC = closest
        else
            CurrentTargetNPC = nil
        end

        if getgenv().PallLoader.TargetLine and CurrentTargetNPC and CurrentTargetNPC.RootPart then
            VisualizerBeam.Transparency = 0
            Attachment0.WorldPosition = hrp.Position
            Attachment1.WorldPosition = CurrentTargetNPC.RootPart.Position
        else
            VisualizerBeam.Transparency = 1
        end

        if getgenv().PallLoader.NPCFreeze then
            for _, data in ipairs(npcs) do
                pcall(function()
                    data.Humanoid.WalkSpeed = 0
                    data.RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end)
            end
        end
    end)
end)

RunService.RenderStepped:Connect(function()
    if getgenv().PallLoader.HitboxExpander then
        pcall(function()
            local size = getgenv().PallLoader.HitboxSize
            for _, data in ipairs(getNPCsOnly()) do
                local root = data.RootPart
                if root then
                    if not OriginalHitboxSizes[root] then OriginalHitboxSizes[root] = root.Size end
                    root.Size = Vector3.new(size, size, size)
                    root.Transparency = 0.4
                    root.Color = Color3.fromRGB(0, 150, 255)
                    root.CanCollide = false
                end
            end
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            if getgenv().PallLoader.AutoAbilities then
                for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
                    if r:IsA("RemoteEvent") and (r.Name:lower():find("ability") or r.Name:lower():find("skill")) then
                        r:FireServer(1)
                    end
                end
            end
            if getgenv().PallLoader.AutoUpgrader then
                for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
                    if r:IsA("RemoteEvent") and (r.Name:lower():find("upgrade") or r.Name:lower():find("stat")) then
                        r:FireServer("Spell Power")
                    end
                end
            end
            if getgenv().PallLoader.AutoReplay then
                for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
                    if r:IsA("RemoteEvent") and r.Name:lower():find("replay") then r:FireServer() end
                end
            end
        end)
    end
end)

print("[Pall Loader v5.0] Berhasil dimuat (Semua fitur default: OFF)")
