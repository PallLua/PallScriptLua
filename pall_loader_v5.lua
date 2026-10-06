-- NopallKing Dungeon Cheat | PART 1
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local Char, Hum, HRP

local CFG = {
    Enabled = false,
    autoFarm = false,
    autoSwing = false,
    autoSkill = false,
    autoDodge = false,
    noClip = false,
    autoSell = false,
    autoUpgrade = false,
    autoStart = false,
    tweenSpeed = 16,
    hitboxSize = 8,
    hitboxVisible = true,
    skillDelay = 1.2,
    swingDelay = 0.35,
    dodgeDist = 18,
    farmRange = 120,
}

local Remotes = ReplicatedStorage:WaitForChild("remotes", 9)
local Abilities = ReplicatedStorage:WaitForChild("abilities", 9)

local function getRemote(name)
    return Remotes and Remotes:FindFirstChild(name)
end

local function fireAbility(name)
    local folder = Abilities and Abilities:FindFirstChild(name)
    if folder then
        local ev = folder:FindFirstChild("abilityEvent") or folder:FindFirstChild("spellEvent")
        if ev then pcall(function() ev:FireServer() end) end
    end
end

local function refreshChar()
    Char = LP.Character or LP.CharacterAdded:Wait()
    Hum = Char:WaitForChild("Humanoid")
    HRP = Char:WaitForChild("HumanoidRootPart")
end
refreshChar()
LP.CharacterAdded:Connect(function()
    task.wait(0.4)
    refreshChar()
end)
-- NopallKing Dungeon Cheat | PART 2
local HitboxPart
local currentTween
local lastDodge = 0

local function destroyHitbox()
    if HitboxPart then HitboxPart:Destroy() HitboxPart = nil end
end

local function createHitbox()
    destroyHitbox()
    if not Char or not HRP then return end
    HitboxPart = Instance.new("Part")
    HitboxPart.Name = "PlayerHitbox"
    HitboxPart.Anchored = true
    HitboxPart.CanCollide = false
    HitboxPart.CanQuery = false
    HitboxPart.CastShadow = false
    HitboxPart.Material = Enum.Material.ForceField
    HitboxPart.Color = Color3.fromRGB(0, 255, 170)
    HitboxPart.Transparency = 0.55
    HitboxPart.Size = Vector3.new(CFG.hitboxSize, CFG.hitboxSize, CFG.hitboxSize)
    HitboxPart.CFrame = HRP.CFrame
    HitboxPart.Parent = Workspace
    local box = Instance.new("SelectionBox")
    box.Adornee = HitboxPart
    box.Color3 = Color3.fromRGB(0, 255, 170)
    box.LineThickness = 0.05
    box.Transparency = 0.2
    box.Parent = HitboxPart
end

RunService.Heartbeat:Connect(function()
    if HitboxPart and HRP and HitboxPart.Parent then
        HitboxPart.CFrame = HRP.CFrame
        HitboxPart.Size = Vector3.new(CFG.hitboxSize, CFG.hitboxSize, CFG.hitboxSize)
    end
end)

local function setNoClip(state)
    if not Char then return end
    for _, p in ipairs(Char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanCollide = not state
        end
    end
end

local function tweenTo(pos)
    if not HRP then return end
    if currentTween then currentTween:Cancel() end
    local dist = (HRP.Position - pos).Magnitude
    local t = math.clamp(dist / CFG.tweenSpeed, 0.15, 4)
    currentTween = TweenService:Create(HRP, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = CFrame.new(pos)})
    currentTween:Play()
end

local function getNearestEnemy()
    local best, bestDist = nil, CFG.farmRange
    local dungeon = Workspace:FindFirstChild("dungeon")
    if not dungeon then return nil end
    for _, room in ipairs(dungeon:GetChildren()) do
        local folder = room:FindFirstChild("enemyFolder")
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") then
                    local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health > 0 then
                        local d = (HRP.Position - hrp.Position).Magnitude
                        if d < bestDist then
                            bestDist = d
                            best = hrp
                        end
                    end
                end
            end
        end
    end
    local boss = dungeon:FindFirstChild("bossRoom")
    if boss then
        local folder = boss:FindFirstChild("enemyFolder")
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") then
                    local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health > 0 then
                        local d = (HRP.Position - hrp.Position).Magnitude
                        if d < bestDist then
                            bestDist = d
                            best = hrp
                        end
                    end
                end
            end
        end
    end
    return best
end

local function doDodge()
    if tick() - lastDodge < 1.1 then return end
    lastDodge = tick()
    if not HRP then return end
    local dir = Vector3.new(math.random(-1,1), 0, math.random(-1,1))
    if dir.Magnitude < 0.1 then dir = Vector3.new(1,0,0) end
    dir = dir.Unit * CFG.dodgeDist
    tweenTo(HRP.Position + dir)
end
-- NopallKing Dungeon Cheat | PART 3
local lastSwing, lastSkill = 0, 0

task.spawn(function()
    while true do
        task.wait(0.05)
        if not CFG.enabled or not HRP or not Hum or Hum.Health <= 0 then continue end

        if CFG.noClip then setNoClip(true) end

        if CFG.autoFarm then
            local target = getNearestEnemy()
            if target then
                local goal = target.Position + (HRP.Position - target.Position).Unit * 4
                tweenTo(goal)
            end
        end

        if CFG.autoSwing and tick() - lastSwing > CFG.swingDelay then
            lastSwing = tick()
            local tool = Char:FindFirstChildOfClass("Tool") or LP.Backpack:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end
            local wu = getRemote("weaponUsed")
            if wu then pcall(function() wu:FireServer() end) end
            if tool then
                local ab = tool:FindFirstChild("abilityEvent")
                if ab then pcall(function() ab:FireServer() end) end
            end
        end

        if CFG.autoSkill and tick() - lastSkill > CFG.skillDelay then
            lastSkill = tick()
            fireAbility("Gale Slice")
            fireAbility("Redemption")
            fireAbility("Lightning Beam")
            fireAbility("Pulsefire")
        end

        if CFG.autoDodge then
            local t = getNearestEnemy()
            if t and (t.Position - HRP.Position).Magnitude < 12 then
                doDodge()
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(2.5)
        if not CFG.enabled then continue end
        if CFG.autoSell then
            local sell = getRemote("sellItemEvent") or getRemote("openSellShop")
            if sell then pcall(function() sell:FireServer() end) end
        end
        if CFG.autoUpgrade then
            local up = getRemote("upgradeItem") or getRemote("upgradeKey") or getRemote("equipOrBuyWeaponEnchant")
            if up then pcall(function() up:FireServer() end) end
        end
        if CFG.autoStart then
            local start = getRemote("startDungeon") or getRemote("startBossRaid") or getRemote("joinDungeon")
            if start then pcall(function() start:FireServer() end) end
        end
    end
end)
-- NopallKing Dungeon Cheat | PART 4 (UI)
local function corner(r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    return c
end
local function stroke(col, th)
    local s = Instance.new("UIStroke")
    s.Color = col
    s.Thickness = th or 1
    s.Transparency = 0.3
    return s
end

local Screen = Instance.new("ScreenGui")
Screen.Name = "NopallCheat"
Screen.ResetOnSpawn = false
Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Screen.Parent = game:GetService("CoreGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 340, 0, 520)
Main.Position = UDim2.new(0.5, -170, 0.5, -260)
Main.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = Screen
corner(14).Parent = Main
stroke(Color3.fromRGB(0, 255, 170), 1.5).Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
Header.BorderSizePixel = 0
Header.Parent = Main
corner(14).Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "NOPALL · DUNGEON"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(0, 255, 170)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 32, 0, 32)
Close.Position = UDim2.new(1, -40, 0.5, -16)
Close.BackgroundColor3 = Color3.fromRGB(255, 60, 80)
Close.Text = "×"
Close.Font = Enum.Font.GothamBold
Close.TextSize = 20
Close.TextColor3 = Color3.new(1,1,1)
Close.Parent = Header
corner(8).Parent = Close
Close.MouseButton1Click:Connect(function() Screen:Destroy() end)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 1, -60)
Scroll.Position = UDim2.new(0, 8, 0, 52)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 170)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 780)
Scroll.Parent = Main

local List = Instance.new("UIListLayout")
List.Padding = UDim.new(0, 8)
List.SortOrder = Enum.SortOrder.LayoutOrder
List.Parent = Scroll

local function section(txt, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 22)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.Font = Enum.Font.GothamBold
    l.TextSize = 13
    l.TextColor3 = Color3.fromRGB(140, 140, 160)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
    l.Parent = Scroll
end

local function makeToggle(name, key, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 36)
    f.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.Parent = Scroll
    corner(8).Parent = f
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextColor3 = Color3.fromRGB(230, 230, 240)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 44, 0, 24)
    btn.Position = UDim2.new(1, -52, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    btn.Text = ""
    btn.Parent = f
    corner(12).Parent = btn
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
    knob.BorderSizePixel = 0
    knob.Parent = btn
    corner(9).Parent = knob
    local function update()
        if CFG[key] then
            btn.BackgroundColor3 = Color3.fromRGB(0, 200, 140)
            knob.Position = UDim2.new(1, -21, 0.5, -9)
            knob.BackgroundColor3 = Color3.new(1,1,1)
        else
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
            knob.Position = UDim2.new(0, 3, 0.5, -9)
            knob.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
        end
    end
    update()
    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        update()
        if key == "hitboxVisible" then
            if CFG.hitboxVisible then createHitbox() else destroyHitbox() end
        elseif key == "noClip" then
            setNoClip(CFG.noClip)
        elseif key == "enabled" and CFG.enabled then
            if CFG.hitboxVisible then createHitbox() end
        end
    end)
end

local function makeSlider(name, key, minV, maxV, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 58)
    f.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.Parent = Scroll
    corner(8).Parent = f
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = name .. "  ·  " .. tostring(CFG[key])
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(230, 230, 240)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 8)
    track.Position = UDim2.new(0, 12, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    track.BorderSizePixel = 0
    track.Parent = f
    corner(4).Parent = track
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((CFG[key]-minV)/(maxV-minV), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 170)
    fill.BorderSizePixel = 0
    fill.Parent = track
    corner(4).Parent = fill
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new((CFG[key]-minV)/(maxV-minV), -9, 0.5, -9)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(9).Parent = knob
    stroke(Color3.fromRGB(0, 200, 140), 1).Parent = knob
    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(minV + rel * (maxV - minV) + 0.5)
        CFG[key] = val
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -9, 0.5, -9)
        lbl.Text = name .. "  ·  " .. tostring(val)
        if key == "hitboxSize" and HitboxPart then
            HitboxPart.Size = Vector3.new(val, val, val)
        end
    end
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(inp.Position.X)
        end
    end)
    track.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end)
end

section("MAIN", 1)
makeToggle("Master Enable", "enabled", 2)
makeToggle("Auto Farm (Tween)", "autoFarm", 3)
makeToggle("Auto Swing", "autoSwing", 4)
makeToggle("Auto Skill (Q+E)", "autoSkill", 5)
makeToggle("Auto Dodge (Tween)", "autoDodge", 6)
makeToggle("No-Clip", "noClip", 7)

section("HITBOX (PLAYER ONLY · VISIBLE)", 10)
makeToggle("Show Hitbox", "hitboxVisible", 11)
makeSlider("Hitbox Size", "hitboxSize", 4, 30, 12)

section("SPEED / TIMING", 15)
makeSlider("Tween Speed", "tweenSpeed", 8, 40, 16)
makeSlider("Swing Delay", "swingDelay", 0.15, 1.5, 17)
makeSlider("Skill Delay", "skillDelay", 0.5, 3, 18)

section("AUTO SYSTEMS", 20)
makeToggle("Auto Sell", "autoSell", 21)
makeToggle("Auto Upgrade", "autoUpgrade", 22)
makeToggle("Auto Start Dungeon", "autoStart", 23)

local Foot = Instance.new("TextLabel")
Foot.Size = UDim2.new(1, 0, 0, 20)
Foot.BackgroundTransparency = 1
Foot.Text = "tween farm · visible hitbox · all maps"
Foot.Font = Enum.Font.Gotham
Foot.TextSize = 11
Foot.TextColor3 = Color3.fromRGB(90, 90, 110)
Foot.LayoutOrder = 30
Foot.Parent = Scroll

print("[PART 4] UI loaded · toggle Master Enable")
