-- ============================================================
-- DQR PROJECT v1.4 (Part 1/8)
-- ============================================================
local P = game:GetService("Players")
local LP = P.LocalPlayer
local UIS = game:GetService("UserInputService")
local T = game:GetService("TweenService")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local PathfindingService = game:GetService("PathfindingService")
local Players = P
local CG local okCG = pcall(function() CG = game:GetService("CoreGui") end)
local PG = LP:WaitForChild("PlayerGui")

if okCG and CG and CG:FindFirstChild("DQR") then CG.DQR:Destroy() end
if PG:FindFirstChild("DQR") then PG.DQR:Destroy() end

local Theme = {
    bgWindow=Color3.fromRGB(30,30,32), bgSidebar=Color3.fromRGB(24,24,26),
    bgTitle=Color3.fromRGB(38,38,40), bgCard=Color3.fromRGB(44,44,46),
    bgTrack=Color3.fromRGB(28,28,30), textPri=Color3.fromRGB(245,245,247),
    textSec=Color3.fromRGB(150,150,155), textHead=Color3.fromRGB(120,120,125),
    accent=Color3.fromRGB(10,132,255), accentHov=Color3.fromRGB(16,137,230),
    green=Color3.fromRGB(48,209,88), red=Color3.fromRGB(255,69,58),
    yellow=Color3.fromRGB(255,214,10), toggleOff=Color3.fromRGB(72,72,74),
    knob=Color3.fromRGB(255,255,255),
    font=Enum.Font.Gotham, fontBold=Enum.Font.GothamBold,
    R=UDim.new(0,10), Rs=UDim.new(0,8), Rp=UDim.new(1,0),
}

local function corner(o,r) local c=Instance.new("UICorner") c.CornerRadius=r or Theme.R c.Parent=o return c end
local function stroke(o,col,t) local s=Instance.new("UIStroke") s.Color=col or Color3.fromRGB(70,70,75) s.Thickness=t or 1 s.Transparency=0.5 s.Parent=o return s end

local gui = Instance.new("ScreenGui")
gui.Name = "DQR"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = (okCG and CG) or PG

local vpSize = WS.CurrentCamera.ViewportSize
local WIN_W = 400
local WIN_H = math.clamp(math.floor(vpSize.Y * 0.85), 420, 620)

local win = Instance.new("Frame")
win.Size = UDim2.fromOffset(WIN_W, WIN_H)
win.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
win.BackgroundColor3 = Theme.bgWindow
win.BorderSizePixel = 0
win.Active = true
win.Parent = gui
corner(win, Theme.R)
stroke(win, Color3.fromRGB(60,60,65), 1, 0.3)
local tb = Instance.new("Frame")
tb.Size = UDim2.new(1,0,0,32)
tb.BackgroundColor3 = Theme.bgTitle
tb.BorderSizePixel = 0
tb.Parent = win
corner(tb, Theme.R)
local tbFix = Instance.new("Frame")
tbFix.Size = UDim2.new(1,0,0,12)
tbFix.Position = UDim2.new(0,0,1,-12)
tbFix.BackgroundColor3 = Theme.bgTitle
tbFix.BorderSizePixel = 0
tbFix.Parent = tb

local function dot(x,col)
    local d = Instance.new("TextButton")
    d.Text = "" d.Size = UDim2.fromOffset(10,10)
    d.Position = UDim2.fromOffset(x,11)
    d.BackgroundColor3 = col d.BorderSizePixel = 0
    d.AutoButtonColor = false d.Parent = tb
    corner(d, Theme.Rp)
    return d
end
local redBtn = dot(12, Theme.red)
local ylwBtn = dot(28, Theme.yellow)
local grnBtn = dot(44, Theme.green)

local titleLbl = Instance.new("TextLabel")
titleLbl.Text = "Dungeon Quest Reborn"
titleLbl.Font = Theme.fontBold
titleLbl.TextSize = 12
titleLbl.TextColor3 = Theme.textPri
titleLbl.BackgroundTransparency = 1
titleLbl.Size = UDim2.new(1,-80,1,0)
titleLbl.Position = UDim2.fromOffset(60,0)
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = tb

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0,96,1,-32)
sidebar.Position = UDim2.fromOffset(0,32)
sidebar.BackgroundColor3 = Theme.bgSidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = win
local sbFix = Instance.new("Frame")
sbFix.Size = UDim2.new(0,8,1,0)
sbFix.Position = UDim2.new(1,-8,0,0)
sbFix.BackgroundColor3 = Theme.bgSidebar
sbFix.BorderSizePixel = 0
sbFix.Parent = sidebar
local sbPad = Instance.new("UIPadding")
sbPad.PaddingTop = UDim.new(0,10)
sbPad.PaddingLeft = UDim.new(0,6)
sbPad.PaddingRight = UDim.new(0,6)
sbPad.Parent = sidebar
local sbList = Instance.new("UIListLayout")
sbList.Padding = UDim.new(0,4)
sbList.SortOrder = Enum.SortOrder.LayoutOrder
sbList.Parent = sidebar

local verLbl = Instance.new("TextLabel")
verLbl.Text = "v1.4"
verLbl.Font = Theme.font
verLbl.TextSize = 10
verLbl.TextColor3 = Theme.textSec
verLbl.BackgroundTransparency = 1
verLbl.Size = UDim2.new(1,-12,0,20)
verLbl.Position = UDim2.new(0,6,1,-26)
verLbl.TextXAlignment = Enum.TextXAlignment.Left
verLbl.Parent = sidebar

local content = Instance.new("Frame")
content.Size = UDim2.new(1,-96,1,-32)
content.Position = UDim2.fromOffset(96,32)
content.BackgroundTransparency = 1
content.Parent = win
local tabs = {}
local pages = {}
local current = nil

local function switchTab(name)
    if current == name then return end
    current = name
    for n, page in pairs(pages) do page.Visible = (n==name) end
    for n, t in pairs(tabs) do
        local on = (n == name)
        T:Create(t.bg, TweenInfo.new(0.2), {BackgroundColor3 = on and Theme.accent or Theme.bgSidebar}):Play()
        T:Create(t.lbl, TweenInfo.new(0.2), {TextColor3 = on and Theme.textPri or Theme.textSec}):Play()
    end
end

local function addTab(name, icon, order)
    local btn = Instance.new("TextButton")
    btn.Text = ""
    btn.Size = UDim2.new(1,0,0,32)
    btn.BackgroundColor3 = Theme.bgSidebar
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.Parent = sidebar
    corner(btn, Theme.Rs)

    local lbl = Instance.new("TextLabel")
    lbl.Text = (icon and icon.."  " or "") .. name
    lbl.Font = Theme.fontBold
    lbl.TextSize = 11
    lbl.TextColor3 = Theme.textSec
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1,-8,1,0)
    lbl.Position = UDim2.fromOffset(10,0)
    lbl.Parent = btn

    btn.Activated:Connect(function() switchTab(name) end)
    tabs[name] = {bg = btn, lbl = lbl}

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.fromScale(1,1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.textSec
    page.CanvasSize = UDim2.new(0,0,0,0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0,12)
    pad.PaddingLeft = UDim.new(0,12)
    pad.PaddingRight = UDim.new(0,12)
    pad.PaddingBottom = UDim.new(0,12)
    pad.Parent = page
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0,6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = page
    pages[name] = page
    return page
end
local order = {}
local function nextOrder(parent)
    order[parent] = (order[parent] or 0) + 1
    return order[parent]
end

local Comp = {}

function Comp.section(parent, text)
    local s = Instance.new("TextLabel")
    s.Text = string.upper(text)
    s.Font = Theme.fontBold
    s.TextSize = 10
    s.TextColor3 = Theme.textHead
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.BackgroundTransparency = 1
    s.Size = UDim2.new(1,0,0,18)
    s.Position = UDim2.fromOffset(6,0)
    s.LayoutOrder = nextOrder(parent)
    s.Parent = parent
end

function Comp.toggle(parent, name, key, default, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1,-4,0,36)
    card.BackgroundColor3 = Theme.bgCard
    card.BorderSizePixel = 0
    card.LayoutOrder = nextOrder(parent)
    card.Parent = parent
    corner(card, Theme.Rs)

    local lbl = Instance.new("TextLabel")
    lbl.Text = name
    lbl.Font = Theme.font
    lbl.TextSize = 12
    lbl.TextColor3 = Theme.textPri
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1,-60,1,0)
    lbl.Position = UDim2.fromOffset(12,0)
    lbl.Parent = card

    local track = Instance.new("TextButton")
    track.Text = ""
    track.Size = UDim2.fromOffset(40,22)
    track.Position = UDim2.new(1,-52,0.5,-11)
    track.BackgroundColor3 = default and Theme.green or Theme.toggleOff
    track.BorderSizePixel = 0
    track.AutoButtonColor = false
    track.Active = true
    track.Selectable = true
    track.ZIndex = 5
    track.Parent = card
    corner(track, Theme.Rp)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18,18)
    knob.Position = default and UDim2.fromOffset(20,2) or UDim2.fromOffset(2,2)
    knob.BackgroundColor3 = Theme.knob
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    knob.Parent = track
    corner(knob, Theme.Rp)

    local state = default or false
    local lastClick = 0
    local function doToggle()
        local now = tick()
        if now - lastClick < 0.2 then return end
        lastClick = now
        state = not state
        T:Create(track, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            BackgroundColor3 = state and Theme.green or Theme.toggleOff
        }):Play()
        T:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = state and UDim2.fromOffset(20,2) or UDim2.fromOffset(2,2)
        }):Play()
        print("[Toggle]", name, "→", state and "ON" or "OFF")
        if callback then
            local ok, err = pcall(callback, state)
            if not ok then warn("[Toggle] Error:", err) end
        end
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then doToggle() end
    end)
    track.MouseButton1Click:Connect(function() task.wait(0.05) doToggle() end)
    track.Activated:Connect(function() task.wait(0.1) doToggle() end)
end

function Comp.slider(parent, name, key, min, max, step, default, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1,-4,0,48)
    card.BackgroundColor3 = Theme.bgCard
    card.BorderSizePixel = 0
    card.LayoutOrder = nextOrder(parent)
    card.Parent = parent
    corner(card, Theme.Rs)

    local lbl = Instance.new("TextLabel")
    lbl.Text = name .. "   " .. default
    lbl.Font = Theme.font
    lbl.TextSize = 11
    lbl.TextColor3 = Theme.textPri
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1,-16,0,16)
    lbl.Position = UDim2.fromOffset(12,6)
    lbl.Parent = card

    local track = Instance.new("TextButton")
    track.Text = ""
    track.Size = UDim2.new(1,-24,0,8)
    track.Position = UDim2.new(0,12,1,-18)
    track.BackgroundColor3 = Theme.bgTrack
    track.BorderSizePixel = 0
    track.AutoButtonColor = false
    track.Active = true
    track.Parent = card
    corner(track, Theme.Rp)

    local ratio0 = (default - min) / (max - min)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(ratio0,0,1,0)
    fill.BackgroundColor3 = Theme.knob
    fill.BorderSizePixel = 0
    fill.Parent = track
    corner(fill, Theme.Rp)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16,16)
    knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.Position = UDim2.new(ratio0,0,0.5,0)
    knob.BackgroundColor3 = Theme.knob
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, Theme.Rp)

    local value = default
    local dragging = false
    local function update(absX)
        local abs = track.AbsolutePosition.X
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local r = math.clamp((absX-abs)/w, 0, 1)
        local raw = min + r*(max-min)
        local stepped = math.floor(raw/step + 0.5) * step
        stepped = math.clamp(stepped, min, max)
        stepped = math.floor(stepped*1000 + 0.5)/1000
        value = stepped
        lbl.Text = name .. "   " .. stepped
        local nr = (stepped - min)/(max - min)
        fill.Size = UDim2.new(nr,0,1,0)
        knob.Position = UDim2.new(nr,0,0.5,0)
        if callback then pcall(callback, stepped) end
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(UIS:GetMouseLocation().X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(UIS:GetMouseLocation().X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local dragging, dragStart, startPos
tb.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true dragStart = i.Position startPos = win.Position
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
local char, hrp, hum
local cur = nil

local function refreshChar()
    char = LP.Character or LP.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart", 5)
    hum = char:WaitForChild("Humanoid", 5)
end
refreshChar()
LP.CharacterAdded:Connect(function() task.wait(1) refreshChar() end)

local function inDungeon()
    local v = WS:FindFirstChild("dungeonStarted")
    return v and v:IsA("BoolValue") and v.Value
end
local function getWave()
    local v = WS:FindFirstChild("currentWave")
    return v and v.Value or 0
end
local function isEnemy(m)
    if not m or not m:IsA("Model") then return false end
    if m == char then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    if not m:FindFirstChild("HumanoidRootPart") then return false end
    return true
end
local function getEnemies()
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
    local best, dist = nil, math.huge
    for _, e in ipairs(getEnemies()) do
        local hE = e:FindFirstChild("HumanoidRootPart")
        if hE then
            local d = (hE.Position - hrp.Position).Magnitude
            if d < dist then dist = d best = e end
        end
    end
    cur = best
    return best
end
local function autoEquip()
    if not char then return end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h then return end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") then return end
    end
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") then pcall(function() h:EquipTool(t) end) return end
    end
end
local function isBossPhase()
    local dungeon = WS:FindFirstChild("dungeon")
    if dungeon then
        local bossRoom = dungeon:FindFirstChild("bossRoom")
        if bossRoom then
            local fighting = bossRoom:FindFirstChild("fightingBoss")
            if fighting and fighting:IsA("BoolValue") and fighting.Value then return true end
        end
    end
    for _, e in ipairs(getEnemies()) do
        local n = string.lower(e.Name)
        if string.find(n, "boss") or string.find(n, "giant")
        or string.find(n, "king") or string.find(n, "queen") then return true end
    end
    return false
end
local Feat = {}
Feat.threads = {}

local function stopFeat(name)
    if Feat.threads[name] then
        pcall(task.cancel, Feat.threads[name])
        Feat.threads[name] = nil
    end
end
local function startFeat(name, fn)
    stopFeat(name)
    Feat.threads[name] = task.spawn(fn)
end

-- Auto Dungeon
Feat.AutoDungeon = function()
    while true do
        if not inDungeon() then
            local rm = RS:FindFirstChild("remotes")
            if rm then
                local cv = rm:FindFirstChild("changeStartValue")
                if cv then pcall(function() cv:FireServer("Desert Temple") end) end
                task.wait(0.5)
                local sd = rm:FindFirstChild("startDungeon")
                if sd then pcall(function() sd:FireServer() end) end
                task.wait(2)
                if not inDungeon() then
                    local rp = rm:FindFirstChild("replayDungeon")
                    if rp then pcall(function() rp:FireServer() end) end
                end
            end
            task.wait(5)
        else task.wait(2) end
    end
end

-- Walk Flow (Pathfinding)
Feat.WalkFlow = function()
    local path = PathfindingService:CreatePath({
        AgentRadius = 2.5, AgentHeight = 5,
        AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 4,
    })
    local waypoints = {} local currentWP = 1
    local lastTargetPos = nil local lastComputeTime = 0
    local stuckCounter = 0 local lastPos = nil

    local function computePath(targetPos)
        local ok = pcall(function() path:ComputeAsync(hrp.Position, targetPos) end)
        if not ok then return false end
        if path.Status == Enum.PathStatus.Success then
            waypoints = path:GetWaypoints()
            currentWP = 2
            return true
        end
        return false
    end

    while true do
        if hrp and hum and hum.Health > 0 then
            local target = getNearestEnemy()
            if target then
                local tHrp = target:FindFirstChild("HumanoidRootPart")
                if tHrp then
                    local targetPos = tHrp.Position
                    local dist = (targetPos - hrp.Position).Magnitude
                    local now = tick()
                    local needRecompute = (#waypoints == 0)
                        or (lastTargetPos and (targetPos - lastTargetPos).Magnitude > 8)
                        or (now - lastComputeTime > 1.5)
                    if needRecompute and dist > 5 then
                        computePath(targetPos)
                        lastTargetPos = targetPos
                        lastComputeTime = now
                    end
                    if #waypoints > 0 and currentWP <= #waypoints then
                        local wp = waypoints[currentWP]
                        if wp.Action == Enum.PathWaypointAction.Jump then
                            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                        end
                        pcall(function() hum:MoveTo(wp.Position) end)
                        if (wp.Position - hrp.Position).Magnitude < 3 then currentWP = currentWP + 1 end
                    else
                        pcall(function() hum:MoveTo(targetPos) end)
                    end
                    if lastPos then
                        if (hrp.Position - lastPos).Magnitude < 0.5 then
                            stuckCounter = stuckCounter + 1
                            if stuckCounter > 10 then
                                waypoints = {} currentWP = 1
                                lastTargetPos = nil stuckCounter = 0
                            end
                        else stuckCounter = 0 end
                    end
                    lastPos = hrp.Position
                end
            else waypoints = {} currentWP = 1 lastTargetPos = nil end
            task.wait(0.1)
        else task.wait(0.5) end
    end
end

-- Auto Swing
Feat.AutoSwing = function()
    while true do
        if char and hum and hum.Health > 0 then
            autoEquip()
            local t = getNearestEnemy()
            if t then
                local hE = t:FindFirstChild("HumanoidRootPart")
                if hE and hrp then
                    pcall(function()
                        hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(hE.Position.X, hrp.Position.Y, hE.Position.Z))
                    end)
                end
            end
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then pcall(function() tool:Activate() end) end
            end
            pcall(function()
                local cam = WS.CurrentCamera
                if not cam then return end
                local cx = cam.ViewportSize.X / 2
                local cy = cam.ViewportSize.Y / 2
                VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                task.wait(0.01)
                VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end)
            task.wait(_G.DQR_SwingDelay or 0.08)
        else task.wait(0.5) end
    end
end

-- Auto Skill Q/E
Feat.AutoSkill = function()
    local lastQ = 0 local lastE = 0
    while true do
        if char and hum and hum.Health > 0 then
            local now = tick()
            if now - lastQ >= (_G.DQR_SkillQDelay or 1.5) then
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                end)
                lastQ = now
            end
            if now - lastE >= (_G.DQR_SkillEDelay or 1.5) then
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
                lastE = now
            end
            task.wait(0.1)
        else task.wait(0.5) end
    end
end

-- Auto Heal
Feat.AutoHeal = function()
    local lastHeal = 0 local lastHP = 0 local lastDamage = 0 local lastChar = nil
    while true do
        if char ~= lastChar then lastChar = char lastHeal = tick() lastHP = 0 end
        if hum and hum.Parent and hum.Health > 0 then
            local now = hum.Health
            if now < lastHP - 5 then lastDamage = tick() end
            lastHP = now
            if tick() - lastHeal >= (_G.DQR_HealInterval or 5) and tick() - lastDamage >= 2 then
                if now < hum.MaxHealth then
                    pcall(function() hum.Health = math.min(now + (_G.DQR_HealAmount or 500), hum.MaxHealth) end)
                end
                lastHeal = tick()
            end
        end
        task.wait(0.2)
    end
end

-- Freeze NPC
Feat.FreezeNPC = function()
    local frozen = {}
    while true do
        for _, m in ipairs(getEnemies()) do
            local h = m:FindFirstChildOfClass("Humanoid")
            local hE = m:FindFirstChild("HumanoidRootPart")
            if h then
                if not frozen[h] then frozen[h] = {walk=h.WalkSpeed, jump=h.JumpPower, jheight=h.JumpHeight} end
                pcall(function() h.WalkSpeed = 0 h.JumpPower = 0 h.JumpHeight = 0 end)
                if hE then pcall(function() hE.Anchored = true end) end
            end
        end
        for h, _ in pairs(frozen) do if not h.Parent then frozen[h] = nil end end
        task.wait(0.4)
    end
end

-- No Clip
Feat.NoClip = function()
    while true do
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
            end
        end
        task.wait(0.2)
    end
end

-- Auto Dodge
Feat.AutoDodge = function()
    local lastDodge = 0
    while true do
        if hrp and hum and hum.Health > 0 and char then
            local now = tick()
            local range = isBossPhase() and 15 or (_G.DQR_DodgeRange or 10)
            local speed = _G.DQR_DodgeSpeed or 12
            local cooldown = math.max(0.3, 6 / speed)
            if now - lastDodge >= cooldown then
                for _, m in ipairs(getEnemies()) do
                    local root = m:FindFirstChild("HumanoidRootPart")
                    if root then
                        local dist = (root.Position - hrp.Position).Magnitude
                        if dist < range then
                            local away = hrp.Position - root.Position
                            if away.Magnitude < 0.01 then away = Vector3.new(1,0,0) else away = away.Unit end
                            local tp = hrp.Position + away * (speed * 1.2)
                            T:Create(hrp, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                CFrame = CFrame.new(tp)
                            }):Play()
                            lastDodge = now
                            break
                        end
                    end
                end
            end
        end
        task.wait(0.05)
    end
end

-- ESP Lines
Feat.ESPLines = function()
    local espCache = {}
    local ESP_OK = pcall(function() local d = Drawing.new("Line") d:Remove() end)
    if not ESP_OK then print("[DQR] Drawing gak support") return end
    while true do
        if char and hrp and WS.CurrentCamera then
            local enemies = getEnemies()
            local seen = {}
            for _, m in ipairs(enemies) do
                seen[m] = true
                if not espCache[m] then
                    local l = Drawing.new("Line")
                    l.Visible = false l.Color = Color3.fromRGB(255,60,60)
                    l.Thickness = 1.5 l.Transparency = 0.85
                    l.From = Vector2.new(0,0) l.To = Vector2.new(0,0)
                    espCache[m] = l
                end
            end
            for m, line in pairs(espCache) do
                if not seen[m] or not m.Parent then
                    pcall(function() line:Remove() end)
                    espCache[m] = nil
                end
            end
            local cam = WS.CurrentCamera
            local ss = cam.ViewportSize
            local bc = Vector2.new(ss.X / 2, ss.Y)
            local espRange = _G.DQR_ESPRange or 800
            for m, line in pairs(espCache) do
                local hE = m:FindFirstChild("HumanoidRootPart")
                if hE and hrp then
                    local dist = (hE.Position - hrp.Position).Magnitude
                    if dist <= espRange then
                        local sp, onScreen = cam:WorldToViewportPoint(hE.Position)
                        if onScreen then
                            line.From = bc
                            line.To = Vector2.new(sp.X, sp.Y)
                            if m == cur then
                                line.Color = Color3.fromRGB(255,220,0)
                                line.Thickness = 2.5
                            else
                                line.Color = Color3.fromRGB(255,60,60)
                                line.Thickness = 1.5
                            end
                            line.Visible = true
                        else line.Visible = false end
                    else line.Visible = false end
                else line.Visible = false end
            end
        else task.wait(0.5) end
        task.wait(0.03)
    end
end
-- 5 TABS
local auto = addTab("Auto", "🤖", 1)
local combat = addTab("Combat", "⚔", 2)
local visual = addTab("Visual", "👁", 3)
local misc = addTab("Misc", "🔧", 4)
local settings = addTab("Settings", "⚙", 5)

-- ============ TAB AUTO ============
Comp.section(auto, "Automation")
Comp.toggle(auto, "Auto Dungeon", "autoDungeon", false, function(v)
    if v then startFeat("AutoDungeon", Feat.AutoDungeon) else stopFeat("AutoDungeon") end
end)
Comp.toggle(auto, "Walk Flow (Path)", "walkFlow", false, function(v)
    if v then startFeat("WalkFlow", Feat.WalkFlow) else stopFeat("WalkFlow") end
end)
Comp.toggle(auto, "Auto Swing", "autoSwing", false, function(v)
    if v then startFeat("AutoSwing", Feat.AutoSwing) else stopFeat("AutoSwing") end
end)
Comp.toggle(auto, "Auto Collect", "autoCollect", false, function(v) end)

Comp.section(auto, "Timing")
Comp.slider(auto, "swing_delay", "swingDelay", 0.02, 1, 0.02, 0.08, function(v)
    _G.DQR_SwingDelay = v
end)

Comp.section(auto, "Utility")
Comp.toggle(auto, "No Clip", "noClip", false, function(v)
    if v then startFeat("NoClip", Feat.NoClip) else stopFeat("NoClip") end
end)
Comp.toggle(auto, "Freeze NPC", "freezeNPC", false, function(v)
    if v then startFeat("FreezeNPC", Feat.FreezeNPC) else stopFeat("FreezeNPC") end
end)

-- ============ TAB COMBAT ============
Comp.section(combat, "Auto Skill")
Comp.toggle(combat, "Auto Skill Q/E", "autoSkill", false, function(v)
    if v then startFeat("AutoSkill", Feat.AutoSkill) else stopFeat("AutoSkill") end
end)
Comp.slider(combat, "skill_q_delay", "skillQDelay", 0.2, 10, 0.1, 1.5, function(v)
    _G.DQR_SkillQDelay = v
end)
Comp.slider(combat, "skill_e_delay", "skillEDelay", 0.2, 10, 0.1, 1.5, function(v)
    _G.DQR_SkillEDelay = v
end)

Comp.section(combat, "Healing")
Comp.toggle(combat, "Auto Heal", "autoHeal", false, function(v)
    if v then startFeat("AutoHeal", Feat.AutoHeal) else stopFeat("AutoHeal") end
end)
Comp.slider(combat, "heal_amount", "healAmount", 50, 1000, 50, 500, function(v)
    _G.DQR_HealAmount = v
end)
Comp.slider(combat, "heal_interval", "healInterval", 2, 30, 1, 5, function(v)
    _G.DQR_HealInterval = v
end)

Comp.section(combat, "Dodge")
Comp.toggle(combat, "Auto Dodge", "autoDodge", false, function(v)
    if v then startFeat("AutoDodge", Feat.AutoDodge) else stopFeat("AutoDodge") end
end)
Comp.slider(combat, "dodge_range", "dodgeRange", 5, 40, 1, 10, function(v)
    _G.DQR_DodgeRange = v
end)
Comp.slider(combat, "dodge_speed", "dodgeSpeed", 4, 20, 1, 12, function(v)
    _G.DQR_DodgeSpeed = v
end)

-- ============ TAB VISUAL ============
Comp.section(visual, "ESP")
Comp.toggle(visual, "ESP Lines", "espLines", false, function(v)
    if v then startFeat("ESPLines", Feat.ESPLines) else stopFeat("ESPLines") end
end)
Comp.slider(visual, "esp_range", "espRange", 50, 2000, 50, 800, function(v)
    _G.DQR_ESPRange = v
end)

local vInfo = Instance.new("TextLabel")
vInfo.Text = "More visual features coming soon."
vInfo.Font = Theme.font
vInfo.TextSize = 11
vInfo.TextColor3 = Theme.textSec
vInfo.TextXAlignment = Enum.TextXAlignment.Left
vInfo.TextWrapped = true
vInfo.BackgroundTransparency = 1
vInfo.Size = UDim2.new(1,-8,0,40)
vInfo.Position = UDim2.fromOffset(6,0)
vInfo.LayoutOrder = nextOrder(visual)
vInfo.Parent = visual

-- ============ TAB MISC ============
Comp.section(misc, "Utility")
Comp.toggle(misc, "Anti AFK", "antiAfk", false, function(v)
    if v then
        task.spawn(function()
            while _G.DQR_AntiAFK do
                pcall(function()
                    local vu = game:GetService("VirtualUser")
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new())
                end)
                task.wait(30)
            end
        end)
        _G.DQR_AntiAFK = true
    else
        _G.DQR_AntiAFK = false
    end
end)
Comp.toggle(misc, "Auto Rejoin", "autoRejoin", false, function(v) end)

Comp.section(misc, "Hitbox")
Comp.slider(misc, "hitbox_size", "hitboxSize", 1, 10, 0.5, 2.5, function(v) end)

Comp.section(misc, "Info")
local mInfo = Instance.new("TextLabel")
mInfo.Text = "Misc features mostly experimental."
mInfo.Font = Theme.font
mInfo.TextSize = 11
mInfo.TextColor3 = Theme.textSec
mInfo.TextXAlignment = Enum.TextXAlignment.Left
mInfo.TextWrapped = true
mInfo.BackgroundTransparency = 1
mInfo.Size = UDim2.new(1,-8,0,40)
mInfo.Position = UDim2.fromOffset(6,0)
mInfo.LayoutOrder = nextOrder(misc)
mInfo.Parent = misc

-- ============ TAB SETTINGS ============
Comp.section(settings, "Status")
local statusLbl = Instance.new("TextLabel")
statusLbl.Text = "Loading..."
statusLbl.Font = Theme.font
statusLbl.TextSize = 11
statusLbl.TextColor3 = Theme.textSec
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextWrapped = true
statusLbl.BackgroundTransparency = 1
statusLbl.Size = UDim2.new(1,-8,0,60)
statusLbl.Position = UDim2.fromOffset(6,0)
statusLbl.LayoutOrder = nextOrder(settings)
statusLbl.Parent = settings

task.spawn(function()
    while true do
        if inDungeon() then
            statusLbl.Text = string.format("In Dungeon\nWave: %d\nEnemies: %d", getWave(), #getEnemies())
            statusLbl.TextColor3 = Theme.green
        else
            statusLbl.Text = "Idle · Lobby"
            statusLbl.TextColor3 = Theme.textSec
        end
        task.wait(1)
    end
end)

-- Defaults
_G.DQR_SwingDelay = 0.08
_G.DQR_SkillQDelay = 1.5
_G.DQR_SkillEDelay = 1.5
_G.DQR_HealAmount = 500
_G.DQR_HealInterval = 5
_G.DQR_DodgeRange = 10
_G.DQR_DodgeSpeed = 12
_G.DQR_ESPRange = 800

switchTab("Auto")
local isOpen = true
local isAnimating = false
local baseSize = win.Size
local basePos = win.Position
local OPEN_SCALE = 0.85
local CLOSE_SCALE = 0.85
local DUR_OPEN = 0.4
local DUR_CLOSE = 0.25

local function scaledState(scale)
    local w = baseSize.X.Offset * scale
    local h = baseSize.Y.Offset * scale
    local xOff = basePos.X.Offset + (baseSize.X.Offset - w) / 2
    local yOff = basePos.Y.Offset + (baseSize.Y.Offset - h) / 2
    return UDim2.fromOffset(w, h), UDim2.new(basePos.X.Scale, xOff, basePos.Y.Scale, yOff)
end

local function openWindow()
    if isAnimating or isOpen then return end
    isAnimating = true isOpen = true
    local sSize, sPos = scaledState(OPEN_SCALE)
    win.Visible = true
    win.Size = sSize win.Position = sPos
    win.BackgroundTransparency = 1
    task.wait()
    local t = T:Create(win, TweenInfo.new(DUR_OPEN, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = baseSize, Position = basePos, BackgroundTransparency = 0,
    })
    t:Play()
    t.Completed:Connect(function() isAnimating = false end)
end

local function closeWindow()
    if isAnimating or not isOpen then return end
    isAnimating = true isOpen = false
    local sSize, sPos = scaledState(CLOSE_SCALE)
    local t = T:Create(win, TweenInfo.new(DUR_CLOSE, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Size = sSize, Position = sPos, BackgroundTransparency = 1,
    })
    t:Play()
    t.Completed:Connect(function()
        win.Visible = false
        win.Size = baseSize win.Position = basePos
        win.BackgroundTransparency = 0
        isAnimating = false
    end)
end

local toggleBtn = Instance.new("TextButton")
toggleBtn.Text = "DQ"
toggleBtn.Font = Theme.fontBold
toggleBtn.TextSize = 14
toggleBtn.TextColor3 = Theme.textPri
toggleBtn.BackgroundColor3 = Theme.accent
toggleBtn.BorderSizePixel = 0
toggleBtn.Size = UDim2.fromOffset(52,52)
toggleBtn.Position = UDim2.new(0,20,0,80)
toggleBtn.AutoButtonColor = false
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.ZIndex = 10
toggleBtn.Parent = gui
corner(toggleBtn, Theme.Rp)
stroke(toggleBtn, Color3.fromRGB(0,0,0), 1, 0.6)

local function toggleUI()
    if isOpen then
        closeWindow()
        toggleBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
    else
        openWindow()
        toggleBtn.BackgroundColor3 = Theme.accent
    end
end
toggleBtn.MouseButton1Click:Connect(toggleUI)
toggleBtn.Activated:Connect(toggleUI)

redBtn.MouseButton1Click:Connect(function() if isOpen then toggleUI() end end)
redBtn.Activated:Connect(function() if isOpen then toggleUI() end end)
ylwBtn.MouseButton1Click:Connect(function() if isOpen then toggleUI() end end)
ylwBtn.Activated:Connect(function() if isOpen then toggleUI() end end)

local isBig = false
grnBtn.MouseButton1Click:Connect(function()
    if isAnimating then return end
    isBig = not isBig isAnimating = true
    local targetSize, targetPos
    if isBig then
        local bigH = math.min(baseSize.Y.Offset + 100, 700)
        targetSize = UDim2.fromOffset(baseSize.X.Offset, bigH)
        targetPos = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale, basePos.Y.Offset - 50)
    else
        local freshH = math.clamp(math.floor(WS.CurrentCamera.ViewportSize.Y * 0.85), 420, 620)
        targetSize = UDim2.fromOffset(WIN_W, freshH)
        targetPos = UDim2.new(0.5, -WIN_W/2, 0.5, -freshH/2)
    end
    baseSize = targetSize basePos = targetPos
    local t = T:Create(win, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = targetSize, Position = targetPos,
    })
    t:Play()
    t.Completed:Connect(function() isAnimating = false end)
end)

print("[DQR] v1.4 loaded")
print("  Tabs: Auto · Combat · Visual · Misc · Settings")
print("  Fitur: 9 aktif")
