═══════════════════════════════════════════════════════
DUNGEON QUEST AUTO FARM - FULL SCRIPT
Copy SEMUA mulai dari baris pertama sampai akhir
═══════════════════════════════════════════════════════

-- ============================================================
-- DUNGEON QUEST - AUTO FARM (WINDOW OPEN BY DEFAULT)
-- ============================================================
if game.CoreGui:FindFirstChild("DQAF") then game.CoreGui.DQAF:Destroy() end
local LP0 = game:GetService("Players").LocalPlayer
if LP0.PlayerGui:FindFirstChild("DQAF") then LP0.PlayerGui.DQAF:Destroy() end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local VIM = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local remotes = RS:WaitForChild("remotes", 10)

local Config = {
    WalkFlow       = false,
    ESPLines       = false,
    AutoTap        = false,
    AutoCollect    = false,
    AutoDungeon    = false,
    WalkDelay      = 0.3,
    TapDelay       = 0.1,
    CollectRange   = 250,
    ESPColor       = Color3.fromRGB(255, 60, 60),
    ESPThickness   = 1.5,
    ESPRange       = 500,
}

local currentTarget = nil
local TARGET_DROP_DISTANCE = 200

local char, hrp, hum
local function refreshChar()
    char = LP.Character or LP.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart", 5)
    hum = char:WaitForChild("Humanoid", 5)
end
refreshChar()
LP.CharacterAdded:Connect(function() task.wait(1) refreshChar() end)

local function isInDungeon()
    local v = WS:FindFirstChild("dungeonStarted")
    return v and v:IsA("BoolValue") and v.Value
end

local function getWave()
    local v = WS:FindFirstChild("currentWave")
    return v and v.Value or 0
end

local function isEnemy(model)
    if not model or not model:IsA("Model") then return false end
    if model == char then return false end
    local h = model:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    if not model:FindFirstChild("HumanoidRootPart") then return false end
    return true
end

local function getEnemiesList()
    local list = {}
    for _, v in ipairs(WS:GetDescendants()) do
        if isEnemy(v) then
            local hE = v:FindFirstChild("HumanoidRootPart")
            if hE then table.insert(list, v) end
        end
    end
    return list
end

local function getNearestEnemy()
    if not hrp then return nil end
    local nearest, dist = nil, math.huge
    for _, e in ipairs(getEnemiesList()) do
        local hE = e:FindFirstChild("HumanoidRootPart")
        if hE then
            local d = (hE.Position - hrp.Position).Magnitude
            if d < dist then
                dist = d
                nearest = e
            end
        end
    end
    return nearest
end

local function isValidTarget(model)
    if not model or not model.Parent then return false end
    if not isEnemy(model) then return false end
    return true
end

local function getTarget()
    if isValidTarget(currentTarget) then
        local hE = currentTarget:FindFirstChild("HumanoidRootPart")
        if hE and hrp then
            local d = (hE.Position - hrp.Position).Magnitude
            if d < TARGET_DROP_DISTANCE then
                return currentTarget
            end
        end
    end
    local newTarget = getNearestEnemy()
    currentTarget = newTarget
    return currentTarget
end

task.spawn(function()
    while true do
        if currentTarget then
            local h = currentTarget:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 or not currentTarget.Parent then
                currentTarget = nil
            end
        end
        task.wait(0.1)
    end
end)

local espCache = {}
local ESP_OK = pcall(function()
    local d = Drawing.new("Line")
    d:Remove()
end)

local function createESP(model)
    if not ESP_OK then return end
    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = Config.ESPColor
    line.Thickness = Config.ESPThickness
    line.Transparency = 1
    line.From = Vector2.new(0, 0)
    line.To = Vector2.new(0, 0)
    espCache[model] = line
end

local function removeESP(model)
    local line = espCache[model]
    if line then
        pcall(function() line:Remove() end)
        espCache[model] = nil
    end
end

task.spawn(function()
    local camera = WS.CurrentCamera
    while true do
        if Config.ESPLines and ESP_OK and hrp and camera then
            local enemies = getEnemiesList()
            for _, e in ipairs(enemies) do
                if not espCache[e] then createESP(e) end
            end
            for m, line in pairs(espCache) do
                if not m.Parent or not isEnemy(m) then removeESP(m) end
            end

            local screenSize = camera.ViewportSize
            local bottomCenter = Vector2.new(screenSize.X / 2, screenSize.Y)

            for m, line in pairs(espCache) do
                local hE = m:FindFirstChild("HumanoidRootPart")
                if hE and hrp then
                    local dist = (hE.Position - hrp.Position).Magnitude
                    if dist <= Config.ESPRange then
                        local screenPos, onScreen = camera:WorldToViewportPoint(hE.Position)
                        if onScreen then
                            line.From = bottomCenter
                            line.To = Vector2.new(screenPos.X, screenPos.Y)
                            if m == currentTarget then
                                line.Color = Color3.fromRGB(255, 220, 0)
                                line.Thickness = Config.ESPThickness + 1
                            else
                                line.Color = Config.ESPColor
                                line.Thickness = Config.ESPThickness
                            end
                            line.Visible = true
                        else
                            line.Visible = false
                        end
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        else
            for _, line in pairs(espCache) do line.Visible = false end
            task.wait(0.3)
        end
        task.wait(0.02)
    end
end)

local function tapEnemy(model)
    local camera = WS.CurrentCamera
    if not camera or not model then return false end
    local hE = model:FindFirstChild("HumanoidRootPart")
    if not hE then return false end

    local screenPos, onScreen = camera:WorldToViewportPoint(hE.Position)
    if not onScreen then return false end

    local vs = camera.ViewportSize
    if screenPos.X < 0 or screenPos.X > vs.X then return false end
    if screenPos.Y < 0 or screenPos.Y > vs.Y then return false end

    if hrp then
        pcall(function()
            hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(hE.Position.X, hrp.Position.Y, hE.Position.Z))
        end)
    end

    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                pcall(function() tool:Activate() end)
            end
        end
    end

    pcall(function()
        VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 1)
        task.wait(0.02)
        VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 1)
    end)

    pcall(function()
        VIM:SendMouseButtonEvent(vs.X/2, vs.Y/2, 0, true, game, 1)
        task.wait(0.02)
        VIM:SendMouseButtonEvent(vs.X/2, vs.Y/2, 0, false, game, 1)
    end)

    return true
end

local function autoTapLoop()
    while Config.AutoTap do
        if hrp and hum and hum.Health > 0 then
            local target = getTarget()
            if target then
                tapEnemy(target)
                local h = target:FindFirstChildOfClass("Humanoid")
                if not h or h.Health <= 0 then currentTarget = nil end
                task.wait(Config.TapDelay)
            else
                task.wait(0.15)
            end
        else
            task.wait(0.5)
        end
    end
end

local function walkFlowLoop()
    while Config.WalkFlow do
        if hrp and hum and hum.Health > 0 then
            local target = getTarget()
            if target then
                local hE = target:FindFirstChild("HumanoidRootPart")
                if hE then
                    local dist = (hE.Position - hrp.Position).Magnitude
                    if dist > 10 then
                        pcall(function()
                            hum:MoveTo(Vector3.new(hE.Position.X, hrp.Position.Y, hE.Position.Z))
                        end)
                        task.wait(Config.WalkDelay)
                    else
                        pcall(function() hum:MoveTo(hrp.Position) end)
                        task.wait(0.1)
                    end
                else
                    currentTarget = nil
                    task.wait(0.2)
                end
            else
                task.wait(0.5)
            end
        else
            task.wait(0.5)
        end
    end
end

local function collectLoop()
    while Config.AutoCollect do
        if hrp and hum and hum.Health > 0 then
            for _, v in ipairs(WS:GetDescendants()) do
                if not Config.AutoCollect then break end
                if v:IsA("BasePart") and v.Parent then
                    local n = string.lower(v.Name)
                    if string.find(n, "coin") or string.find(n, "gold")
                    or string.find(n, "drop") or string.find(n, "gem") then
                        local d = (v.Position - hrp.Position).Magnitude
                        if d < Config.CollectRange and d > 3 then
                            pcall(function() hum:MoveTo(v.Position) end)
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
        task.wait(0.3)
    end
end

local function dungeonLoop()
    task.wait(1)
    while Config.AutoDungeon do
        if not isInDungeon() then
            local changeVal = remotes:FindFirstChild("changeStartValue")
            if changeVal then pcall(function() changeVal:FireServer("Desert Temple") end) end
            task.wait(0.5)
            local startD = remotes:FindFirstChild("startDungeon")
            if startD then pcall(function() startD:FireServer() end) end
            task.wait(2)
            if not isInDungeon() then
                local replay = remotes:FindFirstChild("replayDungeon")
                if replay then pcall(function() replay:FireServer() end) end
                task.wait(2)
            end
            task.wait(5)
        else
            task.wait(2)
        end
    end
end

local Theme = {
    Accent = Color3.fromRGB(0, 120, 212),
    AccentHover = Color3.fromRGB(16, 137, 230),
    Bg = Color3.fromRGB(32, 32, 32),
    BgLayer = Color3.fromRGB(43, 43, 43),
    BgBtn = Color3.fromRGB(58, 58, 58),
    Stroke = Color3.fromRGB(80, 80, 80),
    Text = Color3.fromRGB(255, 255, 255),
    TextSub = Color3.fromRGB(180, 180, 180),
    Success = Color3.fromRGB(108, 203, 95),
    Font = Enum.Font.GothamBold,
}

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 8)
    c.Parent = o
end
local function stroke(o, c, t)
    local s = Instance.new("UIStroke")
    s.Color = c or Theme.Stroke
    s.Thickness = 1
    s.Transparency = t or 0.4
    s.Parent = o
end

local gui = Instance.new("ScreenGui")
gui.Name = "DQAF"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local win = Instance.new("Frame")
win.Name = "MainWindow"
win.Size = UDim2.fromOffset(360, 580)
win.Position = UDim2.new(0.5, -180, 0.5, -290)
win.BackgroundColor3 = Theme.Bg
win.BorderSizePixel = 0
win.Visible = true
win.Active = true
win.Parent = gui
corner(win, UDim.new(0, 12))
stroke(win)

local tb = Instance.new("Frame")
tb.Size = UDim2.new(1, 0, 0, 40)
tb.BackgroundColor3 = Theme.BgLayer
tb.BorderSizePixel = 0
tb.Parent = win
corner(tb, UDim.new(0, 12))

local tbFix = Instance.new("Frame")
tbFix.Size = UDim2.new(1, 0, 0, 12)
tbFix.Position = UDim2.new(0, 0, 1, -12)
tbFix.BackgroundColor3 = Theme.BgLayer
tbFix.BorderSizePixel = 0
tbFix.Parent = tb

local titleLbl = Instance.new("TextLabel")
titleLbl.Text = "  Dungeon Quest - Auto Farm"
titleLbl.Font = Theme.Font
titleLbl.TextSize = 14
titleLbl.TextColor3 = Theme.Text
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.BackgroundTransparency = 1
titleLbl.Size = UDim2.new(1, -50, 1, 0)
titleLbl.Position = UDim2.fromOffset(12, 0)
titleLbl.Parent = tb

local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Font = Theme.Font
closeBtn.TextSize = 14
closeBtn.TextColor3 = Theme.Text
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Size = UDim2.fromOffset(28, 24)
closeBtn.Position = UDim2.new(1, -36, 0.5, -12)
closeBtn.AutoButtonColor = false
closeBtn.Parent = tb
corner(closeBtn, UDim.new(0, 6))

local toggleBtn

local function hideWindow()
    win.Visible = false
    toggleBtn.Visible = true
end
closeBtn.Activated:Connect(hideWindow)

local dragging, dragStart, startPos
tb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = win.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        win.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -50)
content.Position = UDim2.fromOffset(10, 45)
content.BackgroundTransparency = 1
content.Parent = win

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = content

local statusLbl = Instance.new("TextLabel")
statusLbl.Text = "Status: Lobby"
statusLbl.Font = Theme.Font
statusLbl.TextSize = 12
statusLbl.TextColor3 = Theme.TextSub
statusLbl.BackgroundColor3 = Theme.BgLayer
statusLbl.BorderSizePixel = 0
statusLbl.Size = UDim2.new(1, 0, 0, 36)
statusLbl.Parent = content
corner(statusLbl, UDim.new(0, 6))

local function makeToggle(text, key, onStart)
    local btn = Instance.new("TextButton")
    btn.Text = text .. ": OFF"
    btn.Font = Theme.Font
    btn.TextSize = 13
    btn.TextColor3 = Theme.Text
    btn.BackgroundColor3 = Theme.BgBtn
    btn.BorderSizePixel = 0
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.AutoButtonColor = false
    btn.Parent = content
    corner(btn, UDim.new(0, 6))

    btn.Activated:Connect(function()
        Config[key] = not Config[key]
        if Config[key] then
            btn.Text = text .. ": ON"
            btn.BackgroundColor3 = Theme.Accent
            if onStart then task.spawn(onStart) end
        else
            btn.Text = text .. ": OFF"
            btn.BackgroundColor3 = Theme.BgBtn
        end
    end)
    return btn
end

makeToggle("Auto Dungeon", "AutoDungeon", dungeonLoop)
makeToggle("Walk Flow (jalan ke musuh)", "WalkFlow", walkFlowLoop)
makeToggle("ESP Lines (garis ke musuh)", "ESPLines", nil)
makeToggle("Auto Tap (klik musuh)", "AutoTap", autoTapLoop)
makeToggle("Auto Collect Coin", "AutoCollect", collectLoop)

local function makeSlider(label, key, min, max, step, default)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 52)
    holder.BackgroundColor3 = Theme.BgLayer
    holder.BorderSizePixel = 0
    holder.Parent = content
    corner(holder, UDim.new(0, 6))

    local lbl = Instance.new("TextLabel")
    lbl.Text = label .. ": " .. default
    lbl.Font = Theme.Font
    lbl.TextSize = 12
    lbl.TextColor3 = Theme.TextSub
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -16, 0, 20)
    lbl.Position = UDim2.fromOffset(8, 4)
    lbl.Parent = holder

    local minus = Instance.new("TextButton")
    minus.Text = "-"; minus.Font = Theme.Font; minus.TextSize = 16
    minus.TextColor3 = Theme.Text
    minus.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    minus.BorderSizePixel = 0
    minus.Size = UDim2.fromOffset(36, 22)
    minus.Position = UDim2.fromOffset(8, 26)
    minus.AutoButtonColor = false
    minus.Parent = holder
    corner(minus, UDim.new(0, 4))

    local plus = Instance.new("TextButton")
    plus.Text = "+"; plus.Font = Theme.Font; plus.TextSize = 16
    plus.TextColor3 = Theme.Text
    plus.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    plus.BorderSizePixel = 0
    plus.Size = UDim2.fromOffset(36, 22)
    plus.Position = UDim2.new(1, -44, 0, 26)
    plus.AutoButtonColor = false
    plus.Parent = holder
    corner(plus, UDim.new(0, 4))

    local val = default
    local function update()
        Config[key] = val
        lbl.Text = label .. ": " .. val
    end
    update()

    minus.Activated:Connect(function() val = math.max(min, val - step); update() end)
    plus.Activated:Connect(function() val = math.min(max, val + step); update() end)
end

makeSlider("Tap Delay (s)", "TapDelay", 0.02, 1, 0.02, 0.1)
makeSlider("Walk Delay (s)", "WalkDelay", 0.1, 1, 0.05, 0.3)
makeSlider("ESP Range", "ESPRange", 50, 2000, 50, 500)

local infoLbl = Instance.new("TextLabel")
infoLbl.Text = "ESP + Auto Tap + Walk Flow + Target Lock"
infoLbl.Font = Theme.Font
infoLbl.TextSize = 10
infoLbl.TextColor3 = Color3.fromRGB(100, 100, 100)
infoLbl.BackgroundTransparency = 1
infoLbl.Size = UDim2.new(1, 0, 0, 14)
infoLbl.Parent = content

toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleBtn"
toggleBtn.Text = "DQ Farm"
toggleBtn.Font = Theme.Font
toggleBtn.TextSize = 14
toggleBtn.TextColor3 = Theme.Text
toggleBtn.BackgroundColor3 = Theme.Accent
toggleBtn.BorderSizePixel = 0
toggleBtn.Size = UDim2.fromOffset(130, 40)
toggleBtn.Position = UDim2.new(0, 20, 0, 80)
toggleBtn.AutoButtonColor = false
toggleBtn.Visible = false
toggleBtn.Parent = gui
corner(toggleBtn, UDim.new(0, 8))
stroke(toggleBtn, Color3.new(0,0,0), 0.5)

toggleBtn.Activated:Connect(function()
    win.Visible = true
    toggleBtn.Visible = false
end)

task.spawn(function()
    while gui.Parent do
        if isInDungeon() then
            local list = getEnemiesList()
            local tName = currentTarget and currentTarget.Name or "-"
            statusLbl.Text = string.format("Wave:%d | Musuh:%d | Lock:%s",
                getWave(), #list, tName)
            statusLbl.TextColor3 = Theme.Success
        else
            statusLbl.Text = "Status: Lobby"
            statusLbl.TextColor3 = Theme.TextSub
        end
        task.wait(0.5)
    end
end)

print("[DQ] Loaded. Window kebuka otomatis.")
print("[DQ] GUI Parent:", gui.Parent and gui.Parent:GetFullName() or "NIL")
print("[DQ] Drawing support:", ESP_OK)

═══════════════════════════════════════════════════════
END OF SCRIPT
═══════════════════════════════════════════════════════
