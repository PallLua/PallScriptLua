-- ============================================================
-- DQR FINAL | PART 1 of 4 — Core, State, Helpers
-- paste ini PERTAMA
-- ============================================================
local Players   = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")
local WS        = game:GetService("Workspace")
local RUN       = game:GetService("RunService")
local UIS       = game:GetService("UserInputService")
local TW        = game:GetService("TweenService")
local TS        = game:GetService("TweenService")

local LP  = Players.LocalPlayer
local PG  = LP:WaitForChild("PlayerGui")

-- bersihkan instance lama
local old = PG:FindFirstChild("DQR_FINAL")
if old then old:Destroy() end
if _G.DQR_CONN then
    for _,c in ipairs(_G.DQR_CONN) do pcall(function() c:Disconnect() end) end
end
_G.DQR_CONN = {}

-- ============================================================
-- GLOBAL STATE
-- ============================================================
_G.DQR = {
    autoSwing  = false,
    autoDodge  = false,
    autoSkill  = false,
    noClip     = false,
    hitbox     = false,
    autoSell   = false,
    autoUpgrade= false,
    autoDungeon= false,
    hitboxScale= 4,
    swingDelay = 0.12,
    dodgeRange = 10,
    skillDelay = 0.4,
}
local S = _G.DQR

-- ============================================================
-- CHAR REF
-- ============================================================
local char, hrp, hum
local function refreshChar()
    char = LP.Character or LP.CharacterAdded:Wait()
    hrp  = char:WaitForChild("HumanoidRootPart", 5)
    hum  = char:WaitForChild("Humanoid", 5)
    _G.DQR.char = char
    _G.DQR.hrp  = hrp
    _G.DQR.hum  = hum
end
refreshChar()
LP.CharacterAdded:Connect(function()
    task.wait(0.8)
    refreshChar()
end)

-- ============================================================
-- DUNGEON HELPERS
-- ============================================================
local function getDungeon()
    local d = WS:FindFirstChild("dungeon")
    if d then return d end
    for _, v in ipairs(WS:GetChildren()) do
        if v:IsA("Folder") and v:FindFirstChild("dungeonStarted") then
            return v
        end
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
-- ENEMY HELPERS — multi-room path dari scan PDF
-- rooms: room1~room6 + bossRoom
-- ============================================================
local ROOM_NAMES = {"room1","room2","room3","room4","room5","room6","bossRoom"}

local function getEnemies()
    local list = {}
    local d = getDungeon()
    if not d then return list end

    for _, rname in ipairs(ROOM_NAMES) do
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
    local h = _G.DQR.hrp
    if not h then return nil end
    local best, bestDist = nil, math.huge
    for _, m in ipairs(getEnemies()) do
        local root = m:FindFirstChild("HumanoidRootPart")
        if root then
            local d = (root.Position - h.Position).Magnitude
            if d < bestDist then bestDist = d best = m end
        end
    end
    return best
end

-- ============================================================
-- SKILL REMOTES — dari Backpack langsung (terkonfirmasi scan)
-- pattern: Players.LP.Backpack.[toolName].abilityEvent / spellEvent
-- ============================================================
local skillCD = {}

local function getSkillRemotes()
    local remotes = {}
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return remotes end
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") then
            local ab = tool:FindFirstChild("abilityEvent")
                    or tool:FindFirstChild("spellEvent")
            if ab and ab:IsA("RemoteEvent") then
                table.insert(remotes, ab)
            end
        end
    end
    -- juga cek tool equipped di char
    local c = _G.DQR.char
    if c then
        for _, tool in ipairs(c:GetChildren()) do
            if tool:IsA("Tool") then
                local ab = tool:FindFirstChild("abilityEvent")
                        or tool:FindFirstChild("spellEvent")
                if ab and ab:IsA("RemoteEvent") then
                    table.insert(remotes, ab)
                end
            end
        end
    end
    return remotes
end

local function fireSkills()
    local now = tick()
    for _, remote in ipairs(getSkillRemotes()) do
        local last = skillCD[remote] or 0
        if now - last >= S.skillDelay then
            skillCD[remote] = now
            pcall(function() remote:FireServer() end)
        end
    end
end

-- ============================================================
-- TOOL HELPERS
-- ============================================================
local function equippedTool()
    local c = _G.DQR.char
    if not c then return nil end
    return c:FindFirstChildOfClass("Tool")
end

local function equipFirst()
    local c = _G.DQR.char
    local h = _G.DQR.hum
    if not c or not h then return end
    if equippedTool() then return end
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return end
    local t = bp:FindFirstChildOfClass("Tool")
    if t then pcall(function() h:EquipTool(t) end) end
end

-- ============================================================
-- REMOTES — auto sell, upgrade, dungeon
-- ============================================================
local remotes = RS:FindFirstChild("remotes")

local function fireRemote(name, ...)
    if not remotes then return end
    local r = remotes:FindFirstChild(name)
    if r then pcall(function() r:FireServer(...) end) end
end

-- ============================================================
-- NOCLIP
-- ============================================================
local noclipActive = false
local noclipConn

local function setNoclip(state)
    noclipActive = state
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if not state then
        local c = _G.DQR.char
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    pcall(function() p.CanCollide = true end)
                end
            end
        end
        return
    end
    noclipConn = RUN.Heartbeat:Connect(function()
        if not noclipActive then return end
        local c = _G.DQR.char
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function() p.CanCollide = false end)
            end
        end
    end)
    if noclipConn then table.insert(_G.DQR_CONN, noclipConn) end
end

-- ============================================================
-- HITBOX EXPAND — visible SelectionBox
-- ============================================================
local origHandleSize = {}
local selBoxes = {}

local function applyHitbox()
    local c = _G.DQR.char
    if not c then return end
    for _, obj in ipairs(c:GetChildren()) do
        if obj:IsA("Tool") then
            local handle = obj:FindFirstChild("Handle")
            if handle then
                if not origHandleSize[obj] then
                    origHandleSize[obj] = handle.Size
                end
                local newSize = origHandleSize[obj] * S.hitboxScale
                pcall(function()
                    handle.Size     = newSize
                    handle.CanQuery = true
                    handle.CanTouch = true
                end)
                -- SelectionBox visible
                if not selBoxes[obj] then
                    local sel = Instance.new("SelectionBox")
                    sel.Adornee             = handle
                    sel.Color3              = Color3.fromRGB(255, 100, 50)
                    sel.LineThickness       = 0.05
                    sel.SurfaceColor3       = Color3.fromRGB(255, 100, 50)
                    sel.SurfaceTransparency = 0.55
                    sel.Parent              = WS
                    selBoxes[obj]           = sel
                end
            end
        end
    end
end

local function restoreHitbox()
    for obj, origSize in pairs(origHandleSize) do
        if obj and obj.Parent then
            local handle = obj:FindFirstChild("Handle")
            if handle then pcall(function() handle.Size = origSize end) end
        end
        if selBoxes[obj] then selBoxes[obj]:Destroy() selBoxes[obj] = nil end
    end
    origHandleSize = {}
end

LP.CharacterAdded:Connect(function()
    origHandleSize = {}
    selBoxes = {}
end)

-- ============================================================
-- TWEEN WALK TO — speed 16, pakai MoveTo
-- ============================================================
local ARRIVE_DIST = 4.5

local function walkToward(targetPos)
    local h = _G.DQR.hrp
    local hm = _G.DQR.hum
    if not h or not hm then return true end
    local dist = (targetPos - h.Position).Magnitude
    if dist <= ARRIVE_DIST then return true end
    pcall(function()
        hm.WalkSpeed = 16
        hm:MoveTo(targetPos)
    end)
    return false
end

-- expose ke global
_G.DQR.getDungeon    = getDungeon
_G.DQR.isActive      = isActive
_G.DQR.isBossPhase   = isBossPhase
_G.DQR.getCurrentWave= getCurrentWave
_G.DQR.getEnemies    = getEnemies
_G.DQR.nearestEnemy  = nearestEnemy
_G.DQR.fireSkills    = fireSkills
_G.DQR.equippedTool  = equippedTool
_G.DQR.equipFirst    = equipFirst
_G.DQR.fireRemote    = fireRemote
_G.DQR.setNoclip     = setNoclip
_G.DQR.applyHitbox   = applyHitbox
_G.DQR.restoreHitbox = restoreHitbox
_G.DQR.walkToward    = walkToward
_G.DQR.refreshChar   = refreshChar
-- ============================================================
-- DQR FINAL | PART 2 of 4 — Feature Loops
-- paste SETELAH part1
-- ============================================================
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local RUN     = game:GetService("RunService")
local TW      = game:GetService("TweenService")

local LP = Players.LocalPlayer
local S  = _G.DQR

-- ============================================================
-- AUTO SWING — tween walk speed 16, lalu swing
-- ============================================================
local lastSwing = 0

local function doAutoSwing()
    if not S.autoSwing then return end
    local c   = S.char
    local h   = S.hrp
    local hm  = S.hum
    if not c or not h or not hm then return end
    if hm.Health <= 0 then return end

    local target = S.nearestEnemy()
    if not target then return end

    local root = target:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local dist = (root.Position - h.Position).Magnitude

    if dist > 5 then
        -- noclip aktif biar bisa lewat terrain
        if S.noClip then
            S.setNoclip(true)
        end
        S.walkToward(root.Position)
    else
        S.equipFirst()
        local tool = S.equippedTool()
        local now  = tick()
        if tool and now - lastSwing >= S.swingDelay then
            lastSwing = now
            pcall(function() tool:Activate() end)
            -- fire weaponUsed remote (terkonfirmasi scan)
            local remotes = RS:FindFirstChild("remotes")
            if remotes then
                local wu = remotes:FindFirstChild("weaponUsed")
                if wu then pcall(function() wu:FireServer() end) end
            end
        end
    end
end

-- ============================================================
-- AUTO DODGE — tween mundur, cover boss fight juga
-- ============================================================
local lastDodge    = 0
local DODGE_CD     = 0.5
local BOSS_DODGE_R = 15  -- range lebih jauh saat boss

local function doAutoDodge()
    if not S.autoDodge then return end
    local h  = S.hrp
    local hm = S.hum
    if not h or not hm then return end
    if hm.Health <= 0 then return end

    local now = tick()
    if now - lastDodge < DODGE_CD then return end

    local range = S.isBossPhase() and BOSS_DODGE_R or S.dodgeRange

    for _, m in ipairs(S.getEnemies()) do
        local root = m:FindFirstChild("HumanoidRootPart")
        if root then
            local dist = (root.Position - h.Position).Magnitude
            if dist < range then
                -- tween mundur
                local away = (h.Position - root.Position)
                if away.Magnitude < 0.01 then away = Vector3.new(1,0,0) else away = away.Unit end
                local targetPos = h.Position + away * 14
                local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local tween = TW:Create(h, tweenInfo, {CFrame = CFrame.new(targetPos, targetPos + away)})
                pcall(function() tween:Play() end)
                lastDodge = now
                return
            end
        end
    end
end

-- ============================================================
-- AUTO SKILL — Q + E via VIM + remote dari Backpack
-- ============================================================
local lastQ = 0
local lastE = 0
local VIM   = game:GetService("VirtualInputManager")

local function doAutoSkill()
    if not S.autoSkill then return end
    local c  = S.char
    local hm = S.hum
    if not c or not hm then return end
    if hm.Health <= 0 then return end

    local now = tick()

    if now - lastQ >= S.skillDelay then
        lastQ = now
        pcall(function()
            VIM:SendKeyEvent(true,  Enum.KeyCode.Q, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        end)
        task.wait(0.05)
        S.fireSkills()
    end

    if now - lastE >= S.skillDelay + 0.1 then
        lastE = now
        pcall(function()
            VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end
end

-- ============================================================
-- AUTO SELL
-- ============================================================
local lastSell = 0

local function doAutoSell()
    if not S.autoSell then return end
    local now = tick()
    if now - lastSell < 3 then return end
    lastSell = now
    S.fireRemote("openSellShop")
    task.wait(0.3)
    S.fireRemote("sellItemEvent")
end

-- ============================================================
-- AUTO UPGRADE
-- ============================================================
local lastUpgrade = 0

local function doAutoUpgrade()
    if not S.autoUpgrade then return end
    local now = tick()
    if now - lastUpgrade < 4 then return end
    lastUpgrade = now
    S.fireRemote("upgradeItem")
end

-- ============================================================
-- AUTO DUNGEON — start + replay semua map
-- ============================================================
local lastDungeon = 0

local function doAutoDungeon()
    if not S.autoDungeon then return end
    local now = tick()
    if now - lastDungeon < 2 then return end
    lastDungeon = now

    if not S.isActive() then
        S.fireRemote("startDungeon")
        task.wait(0.5)
        S.fireRemote("replayDungeon")
    end
end

-- ============================================================
-- HITBOX LOOP
-- ============================================================
local lastHitbox = 0

local function doHitbox()
    if not S.hitbox then return end
    local now = tick()
    if now - lastHitbox < 0.15 then return end
    lastHitbox = now
    S.applyHitbox()
end

-- ============================================================
-- MAIN HEARTBEAT LOOP
-- ============================================================
local mainConn = RUN.Heartbeat:Connect(function()
    doAutoSwing()
    doAutoDodge()
    doHitbox()

    if not S.hitbox and next(rawget(_G.DQR, "origHandleSize") or {}) then
        S.restoreHitbox()
    end
end)
table.insert(_G.DQR_CONN, mainConn)

-- skill di loop terpisah agar tidak throttle heartbeat
task.spawn(function()
    while true do
        task.wait(0.1)
        doAutoSkill()
        doAutoSell()
        doAutoUpgrade()
        doAutoDungeon()
    end
end)

print("[DQR] Part 2 loaded — feature loops running")
-- ============================================================
-- DQR FINAL | PART 3 of 4 — UI macOS Style + Slider
-- paste SETELAH part1 & part2
-- ============================================================
local Players = game:GetService("Players")
local TW      = game:GetService("TweenService")
local UIS     = game:GetService("UserInputService")

local LP  = Players.LocalPlayer
local PG  = LP:WaitForChild("PlayerGui")
local S   = _G.DQR

-- ============================================================
-- PALETTE
-- ============================================================
local C = {
    bg      = Color3.fromRGB(20, 20, 24),
    surface = Color3.fromRGB(30, 29, 38),
    card    = Color3.fromRGB(38, 37, 48),
    accent  = Color3.fromRGB(110, 80, 230),
    accentL = Color3.fromRGB(140, 110, 255),
    on      = Color3.fromRGB(80, 210, 120),
    off     = Color3.fromRGB(65, 62, 82),
    text    = Color3.fromRGB(235, 232, 250),
    dim     = Color3.fromRGB(140, 135, 165),
    red     = Color3.fromRGB(220, 60, 60),
    yellow  = Color3.fromRGB(230, 185, 50),
    green   = Color3.fromRGB(60, 200, 90),
    slider  = Color3.fromRGB(90, 65, 200),
}

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = p
    return c
end

local function stroke(p, col, thick)
    local s = Instance.new("UIStroke")
    s.Color     = col or C.accent
    s.Thickness = thick or 1.2
    s.Parent    = p
    return s
end

-- ============================================================
-- ROOT GUI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "DQR_FINAL"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = PG

-- ============================================================
-- WINDOW
-- ============================================================
local WIN_W, WIN_H = 340, 520

local win = Instance.new("Frame")
win.Name             = "Window"
win.Size             = UDim2.fromOffset(WIN_W, WIN_H)
win.Position         = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
win.BackgroundColor3 = C.bg
win.BorderSizePixel  = 0
win.ClipsDescendants = true
win.Parent           = gui
corner(win, 14)
stroke(win, C.accent, 1.2)

-- drop shadow
local shadow = Instance.new("ImageLabel")
shadow.Size               = UDim2.fromOffset(WIN_W + 30, WIN_H + 30)
shadow.Position           = UDim2.new(0, -15, 0, -15)
shadow.BackgroundTransparency = 1
shadow.Image              = "rbxassetid://6014261993"
shadow.ImageColor3        = Color3.new(0,0,0)
shadow.ImageTransparency  = 0.5
shadow.ScaleType          = Enum.ScaleType.Slice
shadow.SliceCenter        = Rect.new(49,49,450,450)
shadow.ZIndex             = 0
shadow.Parent             = win

-- ============================================================
-- TITLEBAR
-- ============================================================
local tbar = Instance.new("Frame")
tbar.Size             = UDim2.new(1, 0, 0, 42)
tbar.BackgroundColor3 = C.surface
tbar.BorderSizePixel  = 0
tbar.ZIndex           = 3
tbar.Parent           = win
corner(tbar, 14)
-- fix bottom corners
local tbfix = Instance.new("Frame")
tbfix.Size             = UDim2.new(1,0,0.5,0)
tbfix.Position         = UDim2.new(0,0,0.5,0)
tbfix.BackgroundColor3 = C.surface
tbfix.BorderSizePixel  = 0
tbfix.ZIndex           = 3
tbfix.Parent           = tbar

-- traffic light dots
local function mkDot(x, col)
    local b = Instance.new("Frame")
    b.Size             = UDim2.fromOffset(13,13)
    b.Position         = UDim2.new(0, x, 0.5, -6)
    b.BackgroundColor3 = col
    b.BorderSizePixel  = 0
    b.ZIndex           = 5
    b.Parent           = tbar
    corner(b, 7)
    return b
end
local dotRed  = mkDot(14, C.red)
local dotYel  = mkDot(32, C.yellow)
local dotGrn  = mkDot(50, C.green)

local titleLbl = Instance.new("TextLabel")
titleLbl.Text               = "DQR  ·  CHEAT MENU"
titleLbl.Font               = Enum.Font.GothamBold
titleLbl.TextSize           = 13
titleLbl.TextColor3         = C.text
titleLbl.BackgroundTransparency = 1
titleLbl.Size               = UDim2.new(1,-80,1,0)
titleLbl.Position           = UDim2.fromOffset(76, 0)
titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
titleLbl.ZIndex             = 4
titleLbl.Parent             = tbar

-- status
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

-- ============================================================
-- TAB BAR
-- ============================================================
local tabBar = Instance.new("Frame")
tabBar.Size             = UDim2.new(1,-16,0,30)
tabBar.Position         = UDim2.new(0,8,0,60)
tabBar.BackgroundColor3 = C.surface
tabBar.BorderSizePixel  = 0
tabBar.ZIndex           = 3
tabBar.Parent           = win
corner(tabBar, 8)
Instance.new("UIListLayout", tabBar).FillDirection = Enum.FillDirection.Horizontal
Instance.new("UIListLayout", tabBar).VerticalAlignment = Enum.VerticalAlignment.Center
Instance.new("UIListLayout", tabBar).HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIListLayout", tabBar).Padding = UDim.new(0, 2)

-- scroll container
local scroll = Instance.new("ScrollingFrame")
scroll.Size                  = UDim2.new(1,-16,1,-100)
scroll.Position              = UDim2.new(0,8,0,96)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel       = 0
scroll.ScrollBarThickness    = 2
scroll.ScrollBarImageColor3  = C.accent
scroll.CanvasSize            = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
scroll.ZIndex                = 2
scroll.Parent                = win
local listL = Instance.new("UIListLayout", scroll)
listL.Padding = UDim.new(0, 5)

-- pages
local pages = {}
local tabBtns = {}
local currentPage = nil

local function showPage(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, b in pairs(tabBtns) do
        TW:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = n==name and C.accent or C.card,
            TextColor3       = n==name and C.text  or C.dim,
        }):Play()
    end
    currentPage = name
end

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
    sf.Parent                = scroll
    local ul = Instance.new("UIListLayout", sf)
    ul.Padding = UDim.new(0, 5)
    pages[name] = sf
    return sf
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
    b.Size             = UDim2.new(0, 98, 1, -4)
    b.ZIndex           = 4
    b.Parent           = tabBar
    corner(b, 6)
    tabBtns[name] = b
    b.Activated:Connect(function() showPage(name) end)
    return b
end

local pageFarm     = mkPage("Farm")
local pageCombat   = mkPage("Combat")
local pageSettings = mkPage("Settings")
mkTab("Farm",     "⚔ Farm")
mkTab("Combat",   "🛡 Combat")
mkTab("Settings", "⚙ Settings")

-- ============================================================
-- TOGGLE BUILDER
-- ============================================================
local function mkToggle(parent, label, desc, key)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,-2,0,54)
    row.BackgroundColor3 = C.card
    row.BorderSizePixel  = 0
    row.ZIndex           = 2
    row.Parent           = parent
    corner(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Text                  = label
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextSize              = 13
    lbl.TextColor3            = C.text
    lbl.BackgroundTransparency = 1
    lbl.Size                  = UDim2.new(1,-60,0,22)
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
    sub.Size                  = UDim2.new(1,-60,0,16)
    sub.Position              = UDim2.fromOffset(12,28)
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
    corner(pill, 13)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.fromOffset(20,20)
    knob.Position         = UDim2.new(0,3,0.5,-10)
    knob.BackgroundColor3 = C.dim
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 4
    knob.Parent           = pill
    corner(knob, 10)

    local function setVisual(on)
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
        setVisual(S[key])
        -- noclip special
        if key == "noClip" then S.setNoclip(S.noClip) end
        if key == "hitbox" and not S.hitbox then S.restoreHitbox() end
    end)
    setVisual(S[key])
end

-- ============================================================
-- SLIDER BUILDER
-- ============================================================
local function mkSlider(parent, label, key, minVal, maxVal, step)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,-2,0,64)
    row.BackgroundColor3 = C.card
    row.BorderSizePixel  = 0
    row.ZIndex           = 2
    row.Parent           = parent
    corner(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Text                  = label
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextSize              = 12
    lbl.TextColor3            = C.text
    lbl.BackgroundTransparency = 1
    lbl.Size                  = UDim2.new(0.65,0,0,22)
    lbl.Position              = UDim2.fromOffset(12,6)
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.ZIndex                = 3
    lbl.Parent                = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Font               = Enum.Font.GothamBold
    valLbl.TextSize           = 12
    valLbl.TextColor3         = C.accentL
    valLbl.BackgroundTransparency = 1
    valLbl.Size               = UDim2.new(0.3,0,0,22)
    valLbl.Position           = UDim2.new(0.68,0,0,6)
    valLbl.TextXAlignment     = Enum.TextXAlignment.Right
    valLbl.ZIndex             = 3
    valLbl.Parent             = row

    -- track
    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1,-24,0,8)
    track.Position         = UDim2.new(0,12,0,36)
    track.BackgroundColor3 = C.off
    track.BorderSizePixel  = 0
    track.ZIndex           = 3
    track.Parent           = row
    corner(track, 4)

    -- fill
    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(0,0,1,0)
    fill.BackgroundColor3 = C.slider
    fill.BorderSizePixel  = 0
    fill.ZIndex           = 4
    fill.Parent           = track
    corner(fill, 4)

    -- knob
    local kn = Instance.new("Frame")
    kn.Size             = UDim2.fromOffset(20,20)
    kn.AnchorPoint      = Vector2.new(0.5, 0.5)
    kn.Position         = UDim2.new(0,0,0.5,0)
    kn.BackgroundColor3 = Color3.new(1,1,1)
    kn.BorderSizePixel  = 0
    kn.ZIndex           = 5
    kn.Parent           = track
    corner(kn, 10)
    stroke(kn, C.slider, 1.5)

    local curVal = S[key] or minVal

    local function updateSlider(val)
        val = math.clamp(math.floor(val / step + 0.5) * step, minVal, maxVal)
        curVal      = val
        S[key]      = val
        valLbl.Text = tostring(val)
        local pct   = (val - minVal) / (maxVal - minVal)
        TW:Create(fill, TweenInfo.new(0.1), {Size = UDim2.new(pct,0,1,0)}):Play()
        TW:Create(kn,   TweenInfo.new(0.1), {Position = UDim2.new(pct,0,0.5,0)}):Play()
    end
    updateSlider(curVal)

    local dragging = false

    local function calcFromInput(input)
        local trackAbs = track.AbsoluteSize.X
        local trackPos = track.AbsolutePosition.X
        local rel = math.clamp((input.Position.X - trackPos) / trackAbs, 0, 1)
        updateSlider(minVal + rel * (maxVal - minVal))
    end

    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            calcFromInput(inp)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseMovement then
            calcFromInput(inp)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ============================================================
-- POPULATE TABS
-- ============================================================

-- FARM TAB
mkToggle(pageFarm, "Auto Swing",   "Jalan speed 16 → swing tool",     "autoSwing")
mkToggle(pageFarm, "No Clip",      "Tembus terrain ke NPC",            "noClip")
mkToggle(pageFarm, "Auto Sell",    "Sell item otomatis",               "autoSell")
mkToggle(pageFarm, "Auto Upgrade", "Upgrade item otomatis",            "autoUpgrade")
mkToggle(pageFarm, "Auto Dungeon", "Start/replay dungeon semua map",   "autoDungeon")

-- COMBAT TAB
mkToggle(pageCombat, "Auto Dodge", "Tween mundur + cover boss fight",  "autoDodge")
mkToggle(pageCombat, "Auto Skill", "Q+E spam + remote Backpack",       "autoSkill")
mkToggle(pageCombat, "Hitbox",     "Expand handle + visible box",      "hitbox")

-- SETTINGS TAB
mkSlider(pageSettings, "Hitbox Scale",  "hitboxScale", 1, 12, 0.5)
mkSlider(pageSettings, "Swing Delay",   "swingDelay",  0.02, 1, 0.02)
mkSlider(pageSettings, "Dodge Range",   "dodgeRange",  4, 25, 1)
mkSlider(pageSettings, "Skill Delay",   "skillDelay",  0.1, 3, 0.1)

-- ============================================================
-- DRAG WINDOW
-- ============================================================
local dragging, dragStart, winStart = false, nil, nil
tbar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true dragStart = inp.Position winStart = win.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if not dragging then return end
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseMovement then
        local d = inp.Position - dragStart
        win.Position = UDim2.new(winStart.X.Scale, winStart.X.Offset+d.X, winStart.Y.Scale, winStart.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- ============================================================
-- OPEN / CLOSE ANIMATION
-- ============================================================
local isOpen = true

local function closeWin()
    if not isOpen then return end
    isOpen = false
    TW:Create(win, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Size                = UDim2.fromOffset(WIN_W, 0),
        BackgroundTransparency = 1,
    }):Play()
    task.delay(0.28, function() win.Visible = false end)
end

local function openWin()
    if isOpen then return end
    isOpen = true
    win.Visible              = true
    win.Size                 = UDim2.fromOffset(WIN_W, 0)
    win.BackgroundTransparency = 1
    TW:Create(win, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size                = UDim2.fromOffset(WIN_W, WIN_H),
        BackgroundTransparency = 0,
    }):Play()
end

dotRed.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then closeWin() end
end)
dotYel.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then closeWin() end
end)
dotGrn.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then
        if win.Size.X.Offset >= WIN_W then
            TW:Create(win, TweenInfo.new(0.25), {Size=UDim2.fromOffset(WIN_W+80,WIN_H+60)}):Play()
        else
            TW:Create(win, TweenInfo.new(0.25), {Size=UDim2.fromOffset(WIN_W,WIN_H)}):Play()
        end
    end
end)

-- ============================================================
-- FLOATING TOGGLE BUTTON — muncul saat window ditutup
-- ============================================================
local fab = Instance.new("TextButton")
fab.Size             = UDim2.fromOffset(52,38)
fab.Position         = UDim2.new(0,10,0.45,-19)
fab.BackgroundColor3 = C.accent
fab.Text             = "DQR"
fab.TextColor3       = C.text
fab.TextSize         = 12
fab.Font             = Enum.Font.GothamBold
fab.BorderSizePixel  = 0
fab.AutoButtonColor  = false
fab.ZIndex           = 10
fab.Parent           = gui
corner(fab, 8)
stroke(fab, C.accentL, 1.2)
fab.Activated:Connect(openWin)

-- ============================================================
-- STATUS BAR UPDATE
-- ============================================================
task.spawn(function()
    while gui.Parent do
        task.wait(0.5)
        if S.isActive() then
            local enemies = S.getEnemies()
            local target  = S.nearestEnemy()
            local tName   = target and target.Name or "—"
            local boss    = S.isBossPhase() and " 👹BOSS" or ""
            statLbl.Text       = string.format("Wave %d · %d NPC · %s%s", S.getCurrentWave(), #enemies, tName, boss)
            statLbl.TextColor3 = C.text
        else
            statLbl.Text       = "Idle · Lobby"
            statLbl.TextColor3 = C.dim
        end
    end
end)

showPage("Farm")
print("[DQR] Part 3 loaded — UI ready")
-- ============================================================
-- DQR FINAL | PART 4 of 4 — Physical Toggle Button
-- paste TERAKHIR setelah semua part
-- ============================================================
-- Tombol fisik DQR di layar bisa di-tap untuk show/hide window
-- Bisa digeser ke mana saja
-- ============================================================

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local TW      = game:GetService("TweenService")
local LP      = Players.LocalPlayer
local PG      = LP:WaitForChild("PlayerGui")

-- cari gui yang sudah dibuat part3
local gui = PG:WaitForChild("DQR_FINAL", 5)
if not gui then
    print("[DQR] Part4: GUI tidak ditemukan, tunggu part3 dulu")
    return
end

local win = gui:WaitForChild("Window", 5)
if not win then return end

-- ============================================================
-- FAB sudah dibuat di part3, tapi kita buat versi yang
-- bisa di-drag sendiri (terpisah dari window)
-- ============================================================
local fab = gui:FindFirstChild("__fab2")
if fab then fab:Destroy() end

local dragBtn = Instance.new("TextButton")
dragBtn.Name             = "__fab2"
dragBtn.Size             = UDim2.fromOffset(56, 40)
dragBtn.Position         = UDim2.new(0, 10, 0.5, -20)
dragBtn.BackgroundColor3 = Color3.fromRGB(110, 80, 230)
dragBtn.Text             = "☰ DQR"
dragBtn.TextColor3       = Color3.new(1,1,1)
dragBtn.TextSize         = 11
dragBtn.Font             = Enum.Font.GothamBold
dragBtn.BorderSizePixel  = 0
dragBtn.AutoButtonColor  = false
dragBtn.ZIndex           = 20
dragBtn.Parent           = gui

local dc = Instance.new("UICorner")
dc.CornerRadius = UDim.new(0, 9)
dc.Parent       = dragBtn

local ds = Instance.new("UIStroke")
ds.Color     = Color3.fromRGB(140,110,255)
ds.Thickness = 1.2
ds.Parent    = dragBtn

-- drag logic untuk tombol ini
local btnDragging = false
local btnDragStart, btnStartPos

dragBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        btnDragging  = true
        btnDragStart = inp.Position
        btnStartPos  = dragBtn.Position
    end
end)

UIS.InputChanged:Connect(function(inp)
    if not btnDragging then return end
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseMovement then
        local d = inp.Position - btnDragStart
        dragBtn.Position = UDim2.new(
            btnStartPos.X.Scale, btnStartPos.X.Offset + d.X,
            btnStartPos.Y.Scale, btnStartPos.Y.Offset + d.Y
        )
    end
end)

local btnDownAt = 0
dragBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        btnDownAt = tick()
    end
end)

UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        btnDragging = false
        -- jika tap singkat (bukan drag), toggle window
        local held = tick() - btnDownAt
        if held < 0.25 then
            if win.Visible and win.Size.Y.Offset > 10 then
                -- tutup
                TW:Create(win, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                    Size = UDim2.fromOffset(win.Size.X.Offset, 0),
                    BackgroundTransparency = 1,
                }):Play()
                task.delay(0.28, function()
                    win.Visible = false
                end)
                TW:Create(dragBtn, TweenInfo.new(0.15), {
                    BackgroundColor3 = Color3.fromRGB(80, 55, 170)
                }):Play()
            else
                -- buka
                win.Visible = true
                win.Size    = UDim2.fromOffset(win.Size.X.Offset, 0)
                win.BackgroundTransparency = 1
                TW:Create(win, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Size = UDim2.fromOffset(340, 520),
                    BackgroundTransparency = 0,
                }):Play()
                TW:Create(dragBtn, TweenInfo.new(0.15), {
                    BackgroundColor3 = Color3.fromRGB(110, 80, 230)
                }):Play()
            end
        end
    end
end)

-- pulse animation di tombol saat ada fitur aktif
task.spawn(function()
    local S = _G.DQR
    while dragBtn.Parent do
        task.wait(1)
        local anyOn = S.autoSwing or S.autoDodge or S.autoSkill or S.hitbox
        if anyOn then
            TW:Create(ds, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                Thickness = 2.5
            }):Play()
        else
            ds.Thickness = 1.2
        end
    end
end)

print("[DQR] Part 4 loaded — toggle button aktif")
print("======================================")
print("[DQR] SEMUA PART LOADED — SIAP DIPAKAI")
print("  TAP tombol ☰ DQR untuk show/hide")
print("  Drag tombol ke posisi yang nyaman")
print("  Tab Farm / Combat / Settings")
print("======================================")
