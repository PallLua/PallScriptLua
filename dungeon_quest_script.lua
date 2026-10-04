-- [[ Dungeon Quest Reborn - Ultimate Pall Hub + Auto Walk + 12s Skill Cooldown + Directional Hit ]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- 1. Strong Bypass / Anti-Kick & Hook Protection
pcall(function()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local oldNamecall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if (method == "Kick" or method == "kick") and self == LocalPlayer then
            return
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end)

-- Bersihkan UI lama jika ada
if PlayerGui:FindFirstChild("PallHubDungeon") then
    PlayerGui.PallHubDungeon:Destroy()
end
if PlayerGui:FindFirstChild("PallOpenBtn") then
    PlayerGui.PallOpenBtn:Destroy()
end

-- 2. Main Screen GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PallHubDungeon"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 420, 0, 360)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Top Bar (Header)
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 8)
TopCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 320, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Dungeon Quest | Auto Walk + 12s Skill & Directional Hit"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 10
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

-- Tombol Close (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -32, 0, 2)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 11
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Tombol Open (Floating Button)
local OpenGui = Instance.new("ScreenGui")
OpenGui.Name = "PallOpenBtn"
OpenGui.ResetOnSpawn = false
OpenGui.Parent = PlayerGui

local OpenBtn = Instance.new("TextButton")
OpenBtn.Size = UDim2.new(0, 45, 0, 45)
OpenBtn.Position = UDim2.new(0, 10, 0.4, 0)
OpenBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
OpenBtn.Text = "PallMenu"
OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenBtn.TextSize = 9
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.Visible = false
OpenBtn.Active = true
OpenBtn.Draggable = true
OpenBtn.Parent = OpenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(0, 22)
OpenCorner.Parent = OpenBtn

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    OpenBtn.Visible = true
end)

OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    OpenBtn.Visible = false
end)

-- Sidebar Menu
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 110, 1, -32)
Sidebar.Position = UDim2.new(0, 0, 0, 32)
Sidebar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0, 4)
SideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SideLayout.VerticalAlignment = Enum.VerticalAlignment.Top
SideLayout.Parent = Sidebar

local SideSpacer = Instance.new("Frame")
SideSpacer.Size = UDim2.new(1, 0, 0, 8)
SideSpacer.BackgroundTransparency = 1
SideSpacer.Parent = Sidebar

-- Container Konten
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -110, 1, -32)
Container.Position = UDim2.new(0, 110, 0, 32)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

local Pages = {}
local TabButtons = {}

local function createTab(name)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0, 95, 0, 30)
    tabBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    tabBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabBtn.Text = name
    tabBtn.TextSize = 11
    tabBtn.Font = Enum.Font.GothamMedium
    tabBtn.Parent = Sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = tabBtn

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -10, 1, -10)
    page.Position = UDim2.new(0, 5, 0, 5)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = Container

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 6)
    pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    pageLayout.Parent = page

    tabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        for _, b in pairs(TabButtons) do 
            b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            b.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        page.Visible = true
        tabBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
        tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)

    table.insert(Pages, page)
    table.insert(TabButtons, tabBtn)
    return page
end

local MainTab = createTab("Combat / Aura")
local MiscTab = createTab("Movement")

Pages[1].Visible = true
TabButtons[1].BackgroundColor3 = Color3.fromRGB(255, 170, 0)
TabButtons[1].TextColor3 = Color3.fromRGB(255, 255, 255)

-- Fungsi Toggle & Dropdown
local function createToggle(parentTab, name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 275, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Text = name .. ": OFF"
    btn.TextSize = 11
    btn.Font = Enum.Font.Gotham
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    local enabled = false
    btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            btn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Text = name .. ": ON"
        else
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            btn.TextColor3 = Color3.fromRGB(220, 220, 220)
            btn.Text = name .. ": OFF"
        end
        callback(enabled)
    end)
    btn.Parent = parentTab
    return btn
end

local function createDropdown(parentTab, name, options, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 275, 0, 35)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 130, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 10
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local currentIndex = 1
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 130, 0, 25)
    btn.Position = UDim2.new(1, -135, 0, 5)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.Text = options[currentIndex]
    btn.TextColor3 = Color3.fromRGB(255, 170, 0)
    btn.TextSize = 9
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        currentIndex = currentIndex + 1
        if currentIndex > #options then currentIndex = 1 end
        btn.Text = options[currentIndex]
        callback(options[currentIndex])
    end)
    
    frame.Parent = parentTab
end

-- 3. Konfigurasi State Variabel
local godModeEnabled = false
local autoSwingEnabled = false
local killAuraEnabled = false
local autoWalkNpcEnabled = false
local skillQEnabled = false
local skillEEnabled = false
local noclipEnabled = false
local speedEnabled = false
local hitDirection = "All Directions (Bebas)"
local customSpeedValue = 25

-- Pasang Kontrol UI
createToggle(MainTab, "God Mode", function(state) godModeEnabled = state end)
createToggle(MainTab, "Auto Swing", function(state) autoSwingEnabled = state end)
createToggle(MainTab, "Kill Aura (Instant Kill, Range 150)", function(state) killAuraEnabled = state end)
createToggle(MainTab, "Auto Walk to NPC", function(state) autoWalkNpcEnabled = state end)
createToggle(MainTab, "Auto Spam Skill Q (CD 12s)", function(state) skillQEnabled = state end)
createToggle(MainTab, "Auto Spam Skill E (CD 12s)", function(state) skillEEnabled = state end)
createDropdown(MainTab, "Hit Direction Filter", {"All Directions (Bebas)", "Up (Ke Atas Saja)", "Down (Ke Bawah Saja)", "Right (Kanan Saja)", "Left (Kiri Saja)"}, function(val) hitDirection = val end)

createToggle(MiscTab, "No Clip", function(state) noclipEnabled = state end)
createToggle(MiscTab, "Speed Hack", function(state) speedEnabled = state end)

-- 4. Logika Fitur Di Balik Layar

-- God Mode
RunService.Stepped:Connect(function()
    if godModeEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        local humanoid = LocalPlayer.Character.Humanoid
        if humanoid.Health < humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end
    end
end)

-- No Clip
RunService.Stepped:Connect(function()
    if noclipEnabled and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

-- Speed Hack
RunService.Heartbeat:Connect(function()
    if speedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        if LocalPlayer.Character.Humanoid.MoveDirection.Magnitude > 0 then
            LocalPlayer.Character:TranslateBy(LocalPlayer.Character.Humanoid.MoveDirection * (customSpeedValue / 50))
        end
    end
end)

-- Auto Swing
task.spawn(function()
    while true do
        task.wait(0.1)
        if autoSwingEnabled then
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
        end
    end
end)

-- Auto Walk ke NPC
task.spawn(function()
    while true do
        task.wait(0.5)
        if autoWalkNpcEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function()
                local myRoot = LocalPlayer.Character.HumanoidRootPart
                local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
                local targetNpc = nil
                local shortestDistance = math.huge

                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                        local isPlayer = false
                        for _, p in pairs(Players:GetPlayers()) do
                            if p.Character == obj then isPlayer = true break end
                        end
                        if not isPlayer and obj.Humanoid.Health > 0 then
                            local dist = (myRoot.Position - obj.HumanoidRootPart.Position).Magnitude
                            if dist < shortestDistance then
                                shortestDistance = dist
                                targetNpc = obj.HumanoidRootPart
                            end
                        end
                    end
                end

                if targetNpc and humanoid and shortestDistance > 10 then
                    humanoid:MoveTo(targetNpc.Position)
                end
            end)
        end
    end
end)

-- Kill Aura Utama (Instant Kill, Range 150, Presisi Filter Atas/Bawah/Kanan/Kiri)
task.spawn(function()
    while true do
        task.wait(0.05)
        if killAuraEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function()
                local myRoot = LocalPlayer.Character.HumanoidRootPart
                local fixedRange = 150
                
                for _, mob in pairs(workspace:GetDescendants()) do
                    if mob:IsA("Model") and mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") and mob ~= LocalPlayer.Character then
                        
                        local isPlayer = false
                        for _, p in pairs(Players:GetPlayers()) do
                            if p.Character == mob then isPlayer = true break end
                        end
                        
                        if not isPlayer and mob.Humanoid.Health > 0 then
                            local mobRoot = mob.HumanoidRootPart
                            local distance = (myRoot.Position - mobRoot.Position).Magnitude
                            
                            if distance <= fixedRange then
                                local rel = myRoot.CFrame:PointToObjectSpace(mobRoot.Position)
                                local passDir = false
                                
                                if hitDirection == "All Directions (Bebas)" then
                                    passDir = true
                                elseif hitDirection == "Up (Ke Atas Saja)" then
                                    if rel.Y > 1.0 then passDir = true end
                                elseif hitDirection == "Down (Ke Bawah Saja)" then
                                    if rel.Y < -1.0 then passDir = true end
                                elseif hitDirection == "Right (Kanan Saja)" then
                                    if rel.X > 1.0 then passDir = true end
                                elseif hitDirection == "Left (Kiri Saja)" then
                                    if rel.X < -1.0 then passDir = true end
                                end
                                
                                if passDir then
                                    mob.Humanoid.Health = 0
                                    
                                    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                                    if tool then
                                        for _, remote in pairs(tool:GetDescendants()) do
                                            if remote:IsA("RemoteEvent") then
                                                pcall(function()
                                                    remote:FireServer(mob)
                                                end)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- Auto Spam Skill Q (Cooldown Tepat 12 Detik)
task.spawn(function()
    while true do
        if skillQEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function()
                local myRoot = LocalPlayer.Character.HumanoidRootPart
                local closestMob = nil
                local shortestDist = 150
                
                for _, mob in pairs(workspace:GetDescendants()) do
                    if mob:IsA("Model") and mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") and mob ~= LocalPlayer.Character then
                        local isPlayer = false
                        for _, p in pairs(Players:GetPlayers()) do
                            if p.Character == mob then isPlayer = true break end
                        end
                        if not isPlayer and mob.Humanoid.Health > 0 then
                            local dist = (myRoot.Position - mob.HumanoidRootPart.Position).Magnitude
                            if dist < shortestDist then
                                shortestDist = dist
                                closestMob = mob.HumanoidRootPart
                            end
                        end
                    end
                end
                
                if closestMob then
                    local camera = workspace.CurrentCamera
                    camera.CFrame = CFrame.new(camera.CFrame.Position, closestMob.Position)
                    
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                    task.wait(0.03)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                end
            end)
        end
        task.wait(12)
    end
end)

-- Auto Spam Skill E (Cooldown Tepat 12 Detik)
task.spawn(function()
    while true do
        if skillEEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function()
                local myRoot = LocalPlayer.Character.HumanoidRootPart
                local closestMob = nil
                local shortestDist = 150
                
                for _, mob in pairs(workspace:GetDescendants()) do
                    if mob:IsA("Model") and mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") and mob ~= LocalPlayer.Character then
                        local isPlayer = false
                        for _, p in pairs(Players:GetPlayers()) do
                            if p.Character == mob then isPlayer = true break end
                        end
                        if not isPlayer and mob.Humanoid.Health > 0 then
                            local dist = (myRoot.Position - mob.HumanoidRootPart.Position).Magnitude
                            if dist < shortestDist then
                                shortestDist = dist
                                closestMob = mob.HumanoidRootPart
                            end
                        end
                    end
                end
                
                if closestMob then
                    local camera = workspace.CurrentCamera
                    camera.CFrame = CFrame.new(camera.CFrame.Position, closestMob.Position)
                    
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.03)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end
            end)
        end
        task.wait(12)
    end
end)

print("Pall Hub Loaded Successfully!")
