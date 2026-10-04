-- =====================================================================
-- PALL LOADER v5.0 (Auto Swing with Interval / Auto-Clicker Mode)
-- + Byfron & Hyperion Hook Bypass Core
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
-- ADVANCED BYFRON & HYPERION HOOK BYPASS CORE
-- =====================================================================
pcall(function()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local oldNamecall = mt.__namecall
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = string.lower(getnamecallmethod())
        if method == "kick" or method == "identifier" or method == "sendnotification" or method == "teleport" then
            if self == LocalPlayer then
                return nil
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end)

-- Konfigurasi Toggle v5.0
getgenv().PallLoader = {
    BypassEnabled = true,
    AntiKick = true,
    NoClip = false,         
    FlyFollow = false,      
    HitboxExpander = false,  
    HitboxSize = 45,        
    SafeDistance = 14,      
    MeleeAutoSwing = true, 
    SwingInterval = 1,      
    KillAura = false,
    AntiRangedHit = true,   
    NPCFreeze = true,       
    GodMode = true,         
    AntiAFK = true
}

local OriginalHitboxSizes = {}
local CurrentTargetNPC = nil
local TargetSwitchTimer = 0

print("[Pall Loader v5.0] Memuat Sistem Auto Swing + Byfron & Hyperion Bypass...")

-- Hapus UI lama
pcall(function()
    for _, v in ipairs(PlayerGui:GetChildren()) do
        if v.Name:find("PallLoaderFluent") then v:Destroy() end
    end
    for _, v in ipairs(CoreGui:GetChildren()) do
        if v.Name:find("PallLoaderFluent") then v:Destroy() end
    end
end)

-- ScreenGui Utama
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PallLoaderFluentV192"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = PlayerGui end

-- MainFrame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 420, 0, 480)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -240)
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
Topbar.Size = UDim2.new(1, 0, 0, 36)
Topbar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
Topbar.BorderSizePixel = 0
Topbar.Parent = MainFrame

local UICornerTop = Instance.new("UICorner")
UICornerTop.CornerRadius = UDim.new(0, 8)
UICornerTop.Parent = Topbar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 350, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ Pall Loader <font color='#00DC96'>v5.0 (Byfron & Hyperion Safe)</font>"
Title.RichText = true
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.TextSize = 11
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Topbar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
MinimizeBtn.Position = UDim2.new(1, -34, 0.5, -13)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
MinimizeBtn.TextSize = 14
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.Parent = Topbar

local UICornerMin = Instance.new("UICorner")
UICornerMin.CornerRadius = UDim.new(0, 5)
UICornerMin.Parent = MinimizeBtn

-- Kontainer Menu
local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -20, 1, -48)
Container.Position = UDim2.new(0, 10, 0, 42)
Container.BackgroundTransparency = 1
Container.CanvasSize = UDim2.new(0, 0, 0, 1300)
Container.ScrollBarThickness = 3
Container.ScrollBarImageColor3 = Color3.fromRGB(0, 220, 150)
Container.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 6)
UIList.Parent = Container

local function createCategory(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = "  " .. string.upper(text)
    lbl.TextColor3 = Color3.fromRGB(0, 220, 150)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Container
end

local function createToggle(name, key, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = Container

    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 5)
    uic.Parent = btn

    local uis = Instance.new("UIStroke")
    uis.Color = Color3.fromRGB(45, 45, 60)
    uis.Thickness = 1
    uis.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -55, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 34, 0, 18)
    indicator.Position = UDim2.new(1, -42, 0.5, -9)
    indicator.BackgroundColor3 = getgenv().PallLoader[key] and Color3.fromRGB(0, 204, 136) or Color3.fromRGB(50, 50, 65)
    indicator.BorderSizePixel = 0
    indicator.Parent = btn

    local uici = Instance.new("UICorner")
    uici.CornerRadius = UDim.new(1, 0)
    uici.Parent = indicator

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 12, 0, 12)
    dot.Position = getgenv().PallLoader[key] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
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
            TweenService:Create(dot, tweenInfo, {Position = UDim2.new(1, -15, 0.5, -6), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        else
            TweenService:Create(indicator, tweenInfo, {BackgroundColor3 = Color3.fromRGB(50, 50, 65)}):Play()
            TweenService:Create(dot, tweenInfo, {Position = UDim2.new(0, 3, 0.5, -6), BackgroundColor3 = Color3.fromRGB(160, 160, 180)}):Play()
        end

        if callback then pcall(function() callback(active) end) end
    end)
end

local function createSlider(name, min, max, default, unit, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 48)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.Parent = Container

    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 5)
    uic.Parent = frame

    local uis = Instance.new("UIStroke")
    uis.Color = Color3.fromRGB(45, 45, 60)
    uis.Thickness = 1
    uis.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = name .. ": " .. tostring(default) .. " " .. unit
    lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -20, 0, 5)
    sliderBar.Position = UDim2.new(0, 10, 0, 32)
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
    btn.Size = UDim2.new(1, 0, 1, 8)
    btn.Position = UDim2.new(0, 0, 0, -4)
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
            lbl.Text = name .. ": " .. tostring(val) .. " " .. unit
            callback(val)
        end
    end)
end

createCategory("Security & Byfron/Hyperion Safe")
createToggle("Byfron & Hyperion Hook Bypass", "BypassEnabled")
createToggle("Anti-Kick Protection", "AntiKick")
createToggle("GodMode (Anti Damage / Kebal)", "GodMode")

createCategory("Movement & Smart Fly Follow")
createToggle("No Clip (Tembus Tembok)", "NoClip")
createToggle("Fly Follow NPC", "FlyFollow", function(active)
    if not active then
        CurrentTargetNPC = nil
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hum then hum.PlatformStand = false end
                if hrp then
                    if hrp:FindFirstChild("PallFlyVelocity") then hrp.PallFlyVelocity:Destroy() end
                    if hrp:FindFirstChild("PallFlyGyro") then hrp.PallFlyGyro:Destroy() end
                end
            end
        end)
    end
end)
createSlider("Jarak Aman Berhenti dari NPC", 5, 30, 14, "Studs", function(val)
    getgenv().PallLoader.SafeDistance = val
end)

createCategory("Unified Hitbox Expander & Long Range")
createToggle("Hitbox & Long Range Expander", "HitboxExpander", function(active)
    if not active then
        pcall(function()
            for root, origSize in pairs(OriginalHitboxSizes) do
                if root and root.Parent then
                    root.Size = origSize
                    root.Transparency = 1
                    root.CanCollide = true
                    root.Massless = false
                end
            end
            OriginalHitboxSizes = {}
        end)
    end
end)
createSlider("Ukuran Hitbox & Jangkauan Hit", 10, 80, 45, "Studs", function(val)
    getgenv().PallLoader.HitboxSize = val
end)

createCategory("Combat, NPC Freeze & Tap Auto Swing")
createToggle("Auto Swing (Tap / Clicker Mode)", "MeleeAutoSwing")
createSlider("Jeda Swing (Per Detik / Tap)", 1, 10, 1, "Detik", function(val)
    getgenv().PallLoader.SwingInterval = val
end)
createToggle("NPC Freeze / Diam Total (Tidak Bisa Serang)", "NPCFreeze")
createToggle("Anti-Ranged Hit (Stun/Pushback NPC Jauh)", "AntiRangedHit")
createToggle("Kill Aura (Radius 150 Studs)", "KillAura")

createCategory("Utilities")
createToggle("Anti-AFK Protection", "AntiAFK")

local isVisible = true
MinimizeBtn.MouseButton1Click:Connect(function()
    isVisible = not isVisible
    Container.Visible = isVisible
    MainFrame.Size = isVisible and UDim2.new(0, 420, 0, 480) or UDim2.new(0, 420, 0, 36)
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
                    if not isPlayer then
                        table.insert(list, {Model = obj, Humanoid = hum, RootPart = root})
                    end
                end
            end
        end
    end)
    return list
end

local function getAllTargets()
    local list = {}
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if hum and root and hum.Health > 0 then
                    table.insert(list, {Model = p.Character, Humanoid = hum, RootPart = root})
                end
            end
        end
        for _, npcData in ipairs(getNPCsOnly()) do
            table.insert(list, npcData)
        end
    end)
    return list
end

-- NoClip Loop
RunService.Stepped:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        if getgenv().PallLoader.NoClip then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end)

-- GodMode & NPC Freeze Loop
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

        local bv = hrp:FindFirstChild("PallFlyVelocity")
        local bg = hrp:FindFirstChild("PallFlyGyro")

        if getgenv().PallLoader.FlyFollow then
            hum.PlatformStand = true 
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
                bg.P = 4000
                bg.Parent = hrp
            end

            local npcs = getNPCsOnly()
            if #npcs > 0 then
                local targetValid = false
                if CurrentTargetNPC and CurrentTargetNPC.Model and CurrentTargetNPC.Humanoid and CurrentTargetNPC.Humanoid.Health > 0 then
                    targetValid = true
                end

                TargetSwitchTimer = TargetSwitchTimer + 1
                if not targetValid or TargetSwitchTimer > 240 then
                    TargetSwitchTimer = 0
                    local closest = nil
                    local minDist = math.huge
                    for _, data in ipairs(npcs) do
                        local dist = (hrp.Position - data.RootPart.Position).Magnitude
                        if dist < minDist then minDist = dist closest = data end
                    end
                    CurrentTargetNPC = closest
                end

                if CurrentTargetNPC and CurrentTargetNPC.RootPart then
                    local safeDist = getgenv().PallLoader.SafeDistance
                    local targetPos = CurrentTargetNPC.RootPart.Position + Vector3.new(0, 6, 0)
                    local direction = (targetPos - hrp.Position)
                    local currentDist = direction.Magnitude

                    if currentDist < safeDist then
                        bv.Velocity = -direction.Unit * 14
                    elseif currentDist > (safeDist + 4) then
                        bv.Velocity = direction.Unit * 24
                    else
                        bv.Velocity = Vector3.new(0, 0, 0)
                    end
                    bg.CFrame = CFrame.new(hrp.Position, CurrentTargetNPC.RootPart.Position)
                end
            else
                CurrentTargetNPC = nil
                bv.Velocity = Vector3.new(0, 0, 0)
            end
        else
            if hum.PlatformStand then hum.PlatformStand = false end
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
        end

        if getgenv().PallLoader.NPCFreeze then
            for _, data in ipairs(getNPCsOnly()) do
                pcall(function()
                    local npcHum = data.Humanoid
                    local npcHrp = data.RootPart
                    if npcHum and npcHrp then
                        npcHum.WalkSpeed = 0
                        npcHum.JumpPower = 0
                        npcHum:MoveTo(npcHrp.Position)
                        
                        if npcHrp:FindFirstChild("BodyVelocity") then
                            npcHrp.BodyVelocity:Destroy()
                        end
                        npcHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        npcHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                end)
            end
        end
    end)
end)

-- Unified Hitbox Expander
RunService.RenderStepped:Connect(function()
    if getgenv().PallLoader.HitboxExpander then
        pcall(function()
            local size = getgenv().PallLoader.HitboxSize
            for _, data in ipairs(getNPCsOnly()) do
                local root = data.RootPart
                if root then
                    if not OriginalHitboxSizes[root] then
                        OriginalHitboxSizes[root] = root.Size
                    end
                    root.Size = Vector3.new(size, size, size)
                    root.Transparency = 0.35
                    root.Color = Color3.fromRGB(0, 255, 150)
                    root.Material = Enum.Material.Neon
                    root.CanCollide = false 
                    root.Massless = true
                end
            end
        end)
    end
end)

-- =====================================================================
-- AUTO SWING DENGAN INTERVAL WAKTU TAP PER DETIK (AUTO CLICKER STYLE)
-- =====================================================================
task.spawn(function()
    while true do
        local interval = getgenv().PallLoader.SwingInterval or 1
        task.wait(interval)
        
        if getgenv().PallLoader.MeleeAutoSwing or getgenv().PallLoader.KillAura then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local combatRange = getgenv().PallLoader.HitboxSize + 30
                    
                    local weaponPart = nil
                    for _, child in ipairs(char:GetDescendants()) do
                        if child:IsA("BasePart") and (child.Name:lower():find("weapon") or child.Name:lower():find("sword") or child.Name:lower():find("blade") or child.Name:lower():find("staff") or child.Name:lower():find("handle")) then
                            weaponPart = child
                            break
                        end
                    end
                    
                    for _, data in ipairs(getAllTargets()) do
                        local dist = (hrp.Position - data.RootPart.Position).Magnitude
                        
                        if dist <= combatRange then
                            if getgenv().PallLoader.MeleeAutoSwing then
                                if weaponPart and data.RootPart then
                                    pcall(function()
                                        firetouchinterest(weaponPart, data.RootPart, 0)
                                        firetouchinterest(weaponPart, data.RootPart, 1)
                                    end)
                                end
                                
                                for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
                                    if remote:IsA("RemoteEvent") then
                                        local rName = remote.Name:lower()
                                        if (rName:find("swing") or rName:find("hit") or rName:find("attack") or rName:find("damage") or rName:find("combat") or rName:find("slash"))
                                           and not rName:find("room") 
                                           and not rName:find("create") 
                                           and not rName:find("party") 
                                           and not rName:find("match") 
                                           and not rName:find("lobby") 
                                           and not rName:find("teleport") then
                                            pcall(function()
                                                remote:FireServer(data.Model)
                                                remote:FireServer(data.RootPart)
                                            end)
                                        end
                                    end
                                end
                            end
                        end
                        
                        if getgenv().PallLoader.KillAura and drange <= 120 then
                            data.Humanoid.Health = 0
                        end
                    end
                end
            end)
        end
    end
end)

print("[Pall Loader v5.0] Berhasil dimuat dengan Bypass Byfron & Hyperion!")
