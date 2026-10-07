-- ============================================================
-- DQR FULL SCRIPT — satu file, paste sekali di Delta
-- ============================================================
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local WS      = game:GetService("Workspace")
local RUN     = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local TW      = game:GetService("TweenService")

local LP  = Players.LocalPlayer
local PG  = LP:WaitForChild("PlayerGui")

-- bersihkan instance lama
local old = PG:FindFirstChild("DQR_FULL")
if old then old:Destroy() end

-- ============================================================
-- STATE
-- ============================================================
local S = {
    autoSwing   = false,
    autoDodge   = false,
    autoSkill   = false,
    noClip      = false,
    hitbox      = false,
    autoSell    = false,
    autoUpgrade = false,
    autoDungeon = false,
    hitboxScale = 4,
    swingDelay  = 0.12,
    dodgeRange  = 10,
    skillDelay  = 0.4,
}

-- ============================================================
-- CHAR REF
-- ============================================================
local char, hrp, hum
local function refreshChar()
    char = LP.Character or LP.CharacterAdded:Wait()
    hrp  = char:WaitForChild("HumanoidRootPart", 5)
    hum  = char:WaitForChild("Humanoid", 5)
end
refreshChar()
LP.CharacterAdded:Connect(function() task.wait(0.8) refreshChar() end)

-- ============================================================
-- DUNGEON HELPERS
-- ============================================================
local function getDungeon()
    local d = WS:FindFirstChild("dungeon")
    if d then return d end
    for _, v in ipairs(WS:GetChildren()) do
        if v:IsA("Folder") and v:FindFirstChild("dungeonStarted") then return v end
    end
    return nil
end

local function isActive()
    local d = getDungeon()
    if not d then return false end
    local f = d:FindFirstChild("dungeonStarted")
    return f and f.Value == true
end

local function isBossPhase()
    local d = getDungeon()
    if not d then return false end
    local br = d:FindFirstChild("bossRoom")
    if not br then return false end
    local fb = br:FindFirstChild("fightingBoss")
    return fb and fb.Value == true
end

local function getCurrentWave()
    local d = getDungeon()
    if not d then return 0 end
    local w = d:FindFirstChild("currentWave")
    return w and w.Value or 0
end

-- ============================================================
-- ENEMY SCAN — multi room dari scan log
-- ============================================================
local ROOMS = {"room1","room2","room3","room4","room5","room6","bossRoom"}

local function getEnemies()
    local list = {}
    local d = getDungeon()
    if not d then return list end
    for _, rname in ipairs(ROOMS) do
        local room = d:FindFirstChild(rname)
        if room then
            local ef = room:FindFirstChild("enemyFolder")
            if ef then
                for _, m in ipairs(ef:GetChildren()) do
                    if m:IsA("Model") then
                        local h    = m:FindFirstChildOfClass("Humanoid")
                        local root = m:FindFirstChild("HumanoidRootPart")
                        if h and root and h.Health > 0
                        and not Players:GetPlayerFromCharacter(m) then
                            table.insert(list, m)
                        end
                    end
                end
            end
        end
    end
    return list
end

local function nearestEnemy()
    if not hrp then return nil end
    local best, bestDist = nil, math.huge
    for _, m in ipairs(getEnemies()) do
        local root = m:FindFirstChild("HumanoidRootPart")
        if root then
            local d = (root.Position - hrp.Position).Magnitude
            if d < bestDist then bestDist = d best = m end
        end
    end
    return best
end

-- ============================================================
-- SKILL REMOTES dari Backpack
-- ============================================================
local skillCD = {}

local function fireSkills()
    local now = tick()
    local bp  = LP:FindFirstChild("Backpack")
    local sources = {bp, char}
    for _, src in ipairs(sources) do
        if src then
            for _, tool in ipairs(src:GetChildren()) do
                if tool:IsA("Tool") then
                    local ab = tool:FindFirstChild("abilityEvent")
                            or tool:FindFirstChild("spellEvent")
                    if ab and ab:IsA("RemoteEvent") then
                        local last = skillCD[ab] or 0
                        if now - last >= S.skillDelay then
                            skillCD[ab] = now
                            pcall(function() ab:FireServer() end)
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================
-- TOOL
-- ============================================================
local function equippedTool()
    if not char then return nil end
    return char:FindFirstChildOfClass("Tool")
end

local function equipFirst()
    if not char or not hum then return end
    if equippedTool() then return end
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return end
    local t = bp:FindFirstChildOfClass("Tool")
    if t then pcall(function() hum:EquipTool(t) end) end
end

-- ============================================================
-- REMOTES
-- ============================================================
local function fireRemote(name)
    local remotes = RS:FindFirstChild("remotes")
    if not remotes then return end
    local r = remotes:FindFirstChild(name)
    if r then pcall(function() r:FireServer() end) end
end

-- ============================================================
-- NOCLIP
-- ============================================================
local noclipConn
local function setNoclip(state)
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if not state then
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end
            end
        end
        return
    end
    noclipConn = RUN.Heartbeat:Connect(function()
        if not S.noClip then return end
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
        end
    end)
end

-- ============================================================
-- HITBOX VISIBLE
-- ============================================================
local origSize = {}
local selBoxes = {}

local function applyHitbox()
    if not char then return end
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") then
            local handle = obj:FindFirstChild("Handle")
            if handle then
                if not origSize[obj] then origSize[obj] = handle.Size end
                pcall(function()
                    handle.Size     = origSize[obj] * S.hitboxScale
                    handle.CanQuery = true
                    handle.CanTouch = true
                end)
                if not selBoxes[obj] then
                    local sel = Instance.new("SelectionBox")
                    sel.Adornee             = handle
                    sel.Color3              = Color3.fromRGB(255,100,50)
                    sel.LineThickness       = 0.05
                    sel.SurfaceColor3       = Color3.fromRGB(255,100,50)
                    sel.SurfaceTransparency = 0.55
                    sel.Parent              = WS
                    selBoxes[obj]           = sel
                end
            end
        end
    end
end

local function restoreHitbox()
    for obj, os in pairs(origSize) do
        if obj and obj.Parent then
            local h = obj:FindFirstChild("Handle")
            if h then pcall(function() h.Size = os end) end
        end
        if selBoxes[obj] then selBoxes[obj]:Destroy() selBoxes[obj] = nil end
    end
    origSize = {} selBoxes = {}
end

LP.CharacterAdded:Connect(function() origSize = {} selBoxes = {} end)

-- ============================================================
-- FEATURE LOOPS
-- ============================================================
local lastSwing   = 0
local lastDodge   = 0
local lastSell    = 0
local lastUpgrade = 0
local lastDungeon = 0

-- VIM untuk skill
local ok, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
if not ok then VIM = nil end

local lastQ = 0
local lastE = 0

-- HEARTBEAT — hanya noclip + hitbox, TIDAK ada movement/swing di sini
RUN.Heartbeat:Connect(function()
    if not char or not hrp or not hum then return end
    if hum.Health <= 0 then return end

    -- HITBOX
    if S.hitbox then
        applyHitbox()
    else
        if next(origSize) then restoreHitbox() end
    end
end)

-- AUTO SWING + MOVEMENT — task.spawn sendiri agar tidak block Heartbeat
-- MoveTo dipanggil max sekali per 0.4s, bukan setiap frame
task.spawn(function()
    local moveTarget     = nil
    local lastMoveCall   = 0
    local moveTween      = nil

    while true do
        task.wait(S.swingDelay > 0 and S.swingDelay or 0.12)
        if not S.autoSwing then continue end
        if not char or not hrp or not hum then continue end
        if hum.Health <= 0 then continue end

        local target = nearestEnemy()
        if not target then continue end
        local root = target:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        local dist = (root.Position - hrp.Position).Magnitude

        if dist > 5 then
            -- Tween ke NPC di walkspeed 16 — hanya buat tween baru jika target berubah
            -- atau tween sebelumnya sudah selesai (jangan interrupt tiap frame)
            local now = tick()
            if now - lastMoveCall >= 0.4 then
                lastMoveCall = now
                if moveTween then moveTween:Cancel() end
                local dir        = (hrp.Position - root.Position).Unit
                local targetCF   = CFrame.new(root.Position + dir * 4, root.Position)
                local tweenTime  = math.clamp(dist / 16, 0.15, 5)
                moveTween = TW:Create(hrp,
                    TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
                    {CFrame = targetCF}
                )
                moveTween:Play()
            end
        else
            -- Sudah dekat — stop tween, swing
            if moveTween then moveTween:Cancel() moveTween = nil end
            equipFirst()
            local tool = equippedTool()
            if tool then
                pcall(function() tool:Activate() end)
                fireRemote("weaponUsed")
            end
        end
    end
end)

-- AUTO DODGE — task.spawn sendiri
task.spawn(function()
    while true do
        task.wait(0.45)
        if not S.autoDodge then continue end
        if not char or not hrp or not hum then continue end
        if hum.Health <= 0 then continue end

        local range = isBossPhase() and 15 or S.dodgeRange
        for _, m in ipairs(getEnemies()) do
            local root = m:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - hrp.Position).Magnitude
                if dist < range then
                    local away = (hrp.Position - root.Position)
                    if away.Magnitude < 0.01 then away = Vector3.new(1,0,0) else away = away.Unit end
                    local tp = hrp.Position + away * 14
                    TW:Create(hrp, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        CFrame = CFrame.new(tp)
                    }):Play()
                    break
                end
            end
        end
    end
end)

-- skill + sell + upgrade + dungeon di spawn terpisah
task.spawn(function()
    while true do
        task.wait(0.12)

        if S.autoSkill and char and hum and hum.Health > 0 then
            local now = tick()
            if VIM and now - lastQ >= S.skillDelay then
                lastQ = now
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                end)
                task.wait(0.05)
                fireSkills()
            end
            if VIM and now - lastE >= S.skillDelay + 0.1 then
                lastE = now
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
            end
            if not VIM then fireSkills() end
        end

        local now = tick()
        if S.autoSell and now - lastSell >= 3 then
            lastSell = now
            fireRemote("openSellShop")
            task.wait(0.3)
            fireRemote("sellItemEvent")
        end
        if S.autoUpgrade and now - lastUpgrade >= 4 then
            lastUpgrade = now
            fireRemote("upgradeItem")
        end
        if S.autoDungeon and now - lastDungeon >= 2 then
            lastDungeon = now
            if not isActive() then
                fireRemote("startDungeon")
                task.wait(0.5)
                fireRemote("replayDungeon")
            end
        end
    end
end)

-- ============================================================
-- UI
-- ============================================================
local C = {
    bg      = Color3.fromRGB(20,20,24),
    surface = Color3.fromRGB(30,29,38),
    card    = Color3.fromRGB(38,37,48),
    accent  = Color3.fromRGB(110,80,230),
    accentL = Color3.fromRGB(140,110,255),
    on      = Color3.fromRGB(80,210,120),
    off     = Color3.fromRGB(65,62,82),
    text    = Color3.fromRGB(235,232,250),
    dim     = Color3.fromRGB(140,135,165),
    red     = Color3.fromRGB(220,60,60),
    yellow  = Color3.fromRGB(230,185,50),
    green   = Color3.fromRGB(60,200,90),
    slider  = Color3.fromRGB(90,65,200),
}

local function R(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = p
end

local function SK(p, col, t)
    local s = Instance.new("UIStroke")
    s.Color = col or C.accent
    s.Thickness = t or 1.2
    s.Parent = p
end

-- GUI root
local gui = Instance.new("ScreenGui")
gui.Name           = "DQR_FULL"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = PG

-- window
local WIN_W, WIN_H = 340, 520
local win = Instance.new("Frame")
win.Name             = "Window"
win.Size             = UDim2.fromOffset(WIN_W, WIN_H)
win.Position         = UDim2.new(0.5,-WIN_W/2,0.5,-WIN_H/2)
win.BackgroundColor3 = C.bg
win.BorderSizePixel  = 0
win.ClipsDescendants = true
win.Parent           = gui
R(win, 14)
SK(win, C.accent, 1.2)

-- titlebar
local tbar = Instance.new("Frame")
tbar.Size             = UDim2.new(1,0,0,42)
tbar.BackgroundColor3 = C.surface
tbar.BorderSizePixel  = 0
tbar.ZIndex           = 3
tbar.Parent           = win
R(tbar, 14)
local tbfix = Instance.new("Frame")
tbfix.Size             = UDim2.new(1,0,0.5,0)
tbfix.Position         = UDim2.new(0,0,0.5,0)
tbfix.BackgroundColor3 = C.surface
tbfix.BorderSizePixel  = 0
tbfix.ZIndex           = 3
tbfix.Parent           = tbar

-- dots
local function mkDot(x, col)
    local f = Instance.new("Frame")
    f.Size             = UDim2.fromOffset(13,13)
    f.Position         = UDim2.new(0,x,0.5,-6)
    f.BackgroundColor3 = col
    f.BorderSizePixel  = 0
    f.ZIndex           = 5
    f.Parent           = tbar
    R(f, 7)
    return f
end
local dotR = mkDot(14, C.red)
local dotY = mkDot(32, C.yellow)
local dotG = mkDot(50, C.green)

local titleLbl = Instance.new("TextLabel")
titleLbl.Text               = "DQR  ·  CHEAT MENU"
titleLbl.Font               = Enum.Font.GothamBold
titleLbl.TextSize           = 13
titleLbl.TextColor3         = C.text
titleLbl.BackgroundTransparency = 1
titleLbl.Size               = UDim2.new(1,-80,1,0)
titleLbl.Position           = UDim2.fromOffset(76,0)
titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
titleLbl.ZIndex             = 4
titleLbl.Parent             = tbar

local statLbl = Instance.new("TextLabel")
statLbl.Size                  = UDim2.new(1,-16,0,14)
statLbl.Position              = UDim2.new(0,8,0,44)
statLbl.BackgroundTransparency = 1
statLbl.Text                  = "Idle · Lobby"
statLbl.TextColor3            = C.dim
statLbl.TextSize              = 10
statLbl.Font                  = Enum.Font.Gotham
statLbl.TextXAlignment        = Enum.TextXAlignment.Left
statLbl.ZIndex                = 3
statLbl.Parent                = win

-- tab bar
local tabBarFrame = Instance.new("Frame")
tabBarFrame.Size             = UDim2.new(1,-16,0,30)
tabBarFrame.Position         = UDim2.new(0,8,0,60)
tabBarFrame.BackgroundColor3 = C.surface
tabBarFrame.BorderSizePixel  = 0
tabBarFrame.ZIndex           = 3
tabBarFrame.Parent           = win
R(tabBarFrame, 8)

local tabUL = Instance.new("UIListLayout")
tabUL.FillDirection        = Enum.FillDirection.Horizontal
tabUL.VerticalAlignment    = Enum.VerticalAlignment.Center
tabUL.HorizontalAlignment  = Enum.HorizontalAlignment.Center
tabUL.Padding              = UDim.new(0,3)
tabUL.Parent               = tabBarFrame

-- scroll host
local host = Instance.new("Frame")
host.Size             = UDim2.new(1,-16,1,-100)
host.Position         = UDim2.new(0,8,0,96)
host.BackgroundTransparency = 1
host.BorderSizePixel  = 0
host.ZIndex           = 2
host.Parent           = win

-- pages dict
local pages   = {}
local tabBtns = {}

local function mkPage(name)
    local sf = Instance.new("ScrollingFrame")
    sf.Size                  = UDim2.new(1,0,1,0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel       = 0
    sf.ScrollBarThickness    = 2
    sf.ScrollBarImageColor3  = C.accentL
    sf.CanvasSize            = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    sf.Visible               = false
    sf.ZIndex                = 2
    sf.Parent                = host
    local ul = Instance.new("UIListLayout", sf)
    ul.Padding = UDim.new(0,5)
    pages[name] = sf
    return sf
end

local function showPage(name)
    for n, p in pairs(pages) do p.Visible = (n==name) end
    for n, b in pairs(tabBtns) do
        TW:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = n==name and C.accent or C.card,
            TextColor3       = n==name and C.text  or C.dim,
        }):Play()
    end
end

local function mkTab(name, label)
    local b = Instance.new("TextButton")
    b.Text             = label
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 11
    b.TextColor3       = C.dim
    b.BackgroundColor3 = C.card
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    b.Size             = UDim2.new(0,100,1,-4)
    b.ZIndex           = 4
    b.Parent           = tabBarFrame
    R(b, 6)
    tabBtns[name] = b
    b.Activated:Connect(function() showPage(name) end)
end

local pageFarm   = mkPage("Farm")
local pageCombat = mkPage("Combat")
local pageSet    = mkPage("Settings")
mkTab("Farm",     "⚔ Farm")
mkTab("Combat",   "🛡 Combat")
mkTab("Settings", "⚙ Settings")

-- ============================================================
-- TOGGLE ROW
-- ============================================================
local function mkToggle(parent, label, desc, key)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,-4,0,56)
    row.BackgroundColor3 = C.card
    row.BorderSizePixel  = 0
    row.ZIndex           = 2
    row.Parent           = parent
    R(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Text                  = label
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextSize              = 13
    lbl.TextColor3            = C.text
    lbl.BackgroundTransparency = 1
    lbl.Size                  = UDim2.new(1,-62,0,22)
    lbl.Position              = UDim2.fromOffset(12,8)
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.ZIndex                = 3
    lbl.Parent                = row

    local sub = Instance.new("TextLabel")
    sub.Text                  = desc
    sub.Font                  = Enum.Font.Gotham
    sub.TextSize              = 10
    sub.TextColor3            = C.dim
    sub.BackgroundTransparency = 1
    sub.Size                  = UDim2.new(1,-62,0,16)
    sub.Position              = UDim2.fromOffset(12,30)
    sub.TextXAlignment        = Enum.TextXAlignment.Left
    sub.ZIndex                = 3
    sub.Parent                = row

    local pill = Instance.new("Frame")
    pill.Size             = UDim2.fromOffset(46,26)
    pill.Position         = UDim2.new(1,-54,0.5,-13)
    pill.BackgroundColor3 = C.off
    pill.BorderSizePixel  = 0
    pill.ZIndex           = 3
    pill.Parent           = row
    R(pill, 13)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.fromOffset(20,20)
    knob.Position         = UDim2.new(0,3,0.5,-10)
    knob.BackgroundColor3 = C.dim
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 4
    knob.Parent           = pill
    R(knob, 10)

    local function setV(on)
        TW:Create(pill, TweenInfo.new(0.18, Enum.EasingStyle.Quint), {
            BackgroundColor3 = on and C.on or C.off
        }):Play()
        TW:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quint), {
            Position         = on and UDim2.new(0,23,0.5,-10) or UDim2.new(0,3,0.5,-10),
            BackgroundColor3 = on and Color3.fromRGB(240,255,245) or C.dim,
        }):Play()
    end

    local hit = Instance.new("TextButton")
    hit.Size                  = UDim2.new(1,0,1,0)
    hit.BackgroundTransparency = 1
    hit.Text                  = ""
    hit.ZIndex                = 5
    hit.Parent                = row
    hit.Activated:Connect(function()
        S[key] = not S[key]
        setV(S[key])
        if key == "noClip" then setNoclip(S.noClip) end
        if key == "hitbox" and not S.hitbox then restoreHitbox() end
    end)
    setV(S[key])
end

-- ============================================================
-- SLIDER ROW
-- ============================================================
local function mkSlider(parent, label, key, mn, mx, step)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,-4,0,68)
    row.BackgroundColor3 = C.card
    row.BorderSizePixel  = 0
    row.ZIndex           = 2
    row.Parent           = parent
    R(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Text                  = label
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextSize              = 12
    lbl.TextColor3            = C.text
    lbl.BackgroundTransparency = 1
    lbl.Size                  = UDim2.new(0.62,0,0,22)
    lbl.Position              = UDim2.fromOffset(12,6)
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.ZIndex                = 3
    lbl.Parent                = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Font               = Enum.Font.GothamBold
    valLbl.TextSize           = 12
    valLbl.TextColor3         = C.accentL
    valLbl.BackgroundTransparency = 1
    valLbl.Size               = UDim2.new(0.32,0,0,22)
    valLbl.Position           = UDim2.new(0.65,0,0,6)
    valLbl.TextXAlignment     = Enum.TextXAlignment.Right
    valLbl.ZIndex             = 3
    valLbl.Parent             = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1,-24,0,8)
    track.Position         = UDim2.new(0,12,0,38)
    track.BackgroundColor3 = C.off
    track.BorderSizePixel  = 0
    track.ZIndex           = 3
    track.Parent           = row
    R(track, 4)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(0,0,1,0)
    fill.BackgroundColor3 = C.slider
    fill.BorderSizePixel  = 0
    fill.ZIndex           = 4
    fill.Parent           = track
    R(fill, 4)

    local kn = Instance.new("Frame")
    kn.Size             = UDim2.fromOffset(22,22)
    kn.AnchorPoint      = Vector2.new(0.5,0.5)
    kn.Position         = UDim2.new(0,0,0.5,0)
    kn.BackgroundColor3 = Color3.new(1,1,1)
    kn.BorderSizePixel  = 0
    kn.ZIndex           = 5
    kn.Parent           = track
    R(kn, 11)
    SK(kn, C.slider, 1.5)

    local curVal = S[key] or mn
    local function upd(val)
        val = math.clamp(math.floor(val/step+0.5)*step, mn, mx)
        curVal = val
        S[key] = val
        valLbl.Text = tostring(val)
        local pct = (val-mn)/(mx-mn)
        fill.Size     = UDim2.new(pct,0,1,0)
        kn.Position   = UDim2.new(pct,0,0.5,0)
    end
    upd(curVal)

    local dragging = false
    local function fromInp(inp)
        local tw = track.AbsoluteSize.X
        local tp = track.AbsolutePosition.X
        if tw <= 0 then return end
        local rel = math.clamp((inp.Position.X - tp)/tw, 0, 1)
        upd(mn + rel*(mx-mn))
    end

    track.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.Touch
        or inp.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging = true fromInp(inp)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType==Enum.UserInputType.Touch
        or inp.UserInputType==Enum.UserInputType.MouseMovement then
            fromInp(inp)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.Touch
        or inp.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ============================================================
-- POPULATE TABS
-- ============================================================
mkToggle(pageFarm,   "Auto Swing",    "Jalan 16 → swing tool",          "autoSwing")
mkToggle(pageFarm,   "No Clip",       "Tembus terrain ke NPC",          "noClip")
mkToggle(pageFarm,   "Auto Sell",     "Sell item otomatis",             "autoSell")
mkToggle(pageFarm,   "Auto Upgrade",  "Upgrade item otomatis",          "autoUpgrade")
mkToggle(pageFarm,   "Auto Dungeon",  "Start/replay dungeon all map",   "autoDungeon")

mkToggle(pageCombat, "Auto Dodge",    "Tween mundur + boss fight",      "autoDodge")
mkToggle(pageCombat, "Auto Skill",    "Q+E + remote Backpack",          "autoSkill")
mkToggle(pageCombat, "Hitbox",        "Expand handle + visible box",    "hitbox")

mkSlider(pageSet, "Hitbox Scale",  "hitboxScale", 1,  12, 0.5)
mkSlider(pageSet, "Swing Delay",   "swingDelay",  0.02, 1, 0.02)
mkSlider(pageSet, "Dodge Range",   "dodgeRange",  4,  25, 1)
mkSlider(pageSet, "Skill Delay",   "skillDelay",  0.1, 3, 0.1)

-- ============================================================
-- DRAG WINDOW
-- ============================================================
local drag, dragS, winS = false, nil, nil
tbar.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.Touch
    or inp.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true dragS=inp.Position winS=win.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if not drag then return end
    if inp.UserInputType==Enum.UserInputType.Touch
    or inp.UserInputType==Enum.UserInputType.MouseMovement then
        local d=inp.Position-dragS
        win.Position=UDim2.new(winS.X.Scale,winS.X.Offset+d.X,winS.Y.Scale,winS.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.Touch
    or inp.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)

-- ============================================================
-- OPEN / CLOSE
-- ============================================================
local isOpen = true

local function closeWin()
    if not isOpen then return end
    isOpen = false
    TW:Create(win, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Size = UDim2.fromOffset(WIN_W,0),
        BackgroundTransparency = 1,
    }):Play()
    task.delay(0.28, function() win.Visible = false end)
end

local function openWin()
    if isOpen then return end
    isOpen = true
    win.Visible              = true
    win.Size                 = UDim2.fromOffset(WIN_W,0)
    win.BackgroundTransparency = 1
    TW:Create(win, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(WIN_W,WIN_H),
        BackgroundTransparency = 0,
    }):Play()
end

dotR.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then closeWin() end end)
dotY.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then closeWin() end end)
dotG.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
    if win.Size.Y.Offset >= WIN_H then
        TW:Create(win, TweenInfo.new(0.25),{Size=UDim2.fromOffset(WIN_W+80,WIN_H+60)}):Play()
    else
        TW:Create(win, TweenInfo.new(0.25),{Size=UDim2.fromOffset(WIN_W,WIN_H)}):Play()
    end
end end)

-- ============================================================
-- FLOATING TOGGLE BUTTON — bisa di-drag, tap untuk show/hide
-- ============================================================
local fab = Instance.new("TextButton")
fab.Size             = UDim2.fromOffset(56,40)
fab.Position         = UDim2.new(0,8,0.45,-20)
fab.BackgroundColor3 = C.accent
fab.Text             = "☰ DQR"
fab.TextColor3       = C.text
fab.TextSize         = 11
fab.Font             = Enum.Font.GothamBold
fab.BorderSizePixel  = 0
fab.AutoButtonColor  = false
fab.ZIndex           = 20
fab.Parent           = gui
R(fab, 9)
SK(fab, C.accentL, 1.2)

local fabDrag, fabDragS, fabStartP = false, nil, nil
local fabDownAt = 0

fab.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.Touch
    or inp.UserInputType==Enum.UserInputType.MouseButton1 then
        fabDrag=true fabDragS=inp.Position fabStartP=fab.Position fabDownAt=tick()
    end
end)
UIS.InputChanged:Connect(function(inp)
    if not fabDrag then return end
    if inp.UserInputType==Enum.UserInputType.Touch
    or inp.UserInputType==Enum.UserInputType.MouseMovement then
        local d=inp.Position-fabDragS
        fab.Position=UDim2.new(fabStartP.X.Scale,fabStartP.X.Offset+d.X,fabStartP.Y.Scale,fabStartP.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.Touch
    or inp.UserInputType==Enum.UserInputType.MouseButton1 then
        fabDrag = false
        if tick()-fabDownAt < 0.25 then
            if isOpen then closeWin() else openWin() end
        end
    end
end)

-- ============================================================
-- STATUS UPDATE
-- ============================================================
task.spawn(function()
    while gui.Parent do
        task.wait(0.5)
        if isActive() then
            local enemies = getEnemies()
            local t       = nearestEnemy()
            local boss    = isBossPhase() and " 👹" or ""
            statLbl.Text       = string.format("W%d · %dNPC · %s%s", getCurrentWave(), #enemies, t and t.Name or "—", boss)
            statLbl.TextColor3 = C.text
        else
            statLbl.Text       = "Idle · Lobby"
            statLbl.TextColor3 = C.dim
        end
    end
end)

showPage("Farm")
print("[DQR] loaded — tap ☰ DQR untuk show/hide")
