-- ============================================================
-- DQR PROJECT v1.0 — UI FRAMEWORK (Part 1/7)
-- ============================================================
local P = game:GetService("Players")
local LP = P.LocalPlayer
local UIS = game:GetService("UserInputService")
local T = game:GetService("TweenService")
local WS = game:GetService("Workspace")
local CG local okCG = pcall(function() CG = game:GetService("CoreGui") end)
local PG = LP:WaitForChild("PlayerGui")

if okCG and CG and CG:FindFirstChild("DQR") then CG.DQR:Destroy() end
if PG:FindFirstChild("DQR") then PG.DQR:Destroy() end

local Theme = {
    bgWindow   = Color3.fromRGB(30,30,32),
    bgSidebar  = Color3.fromRGB(24,24,26),
    bgTitle    = Color3.fromRGB(38,38,40),
    bgCard     = Color3.fromRGB(44,44,46),
    bgTrack    = Color3.fromRGB(28,28,30),
    textPri    = Color3.fromRGB(245,245,247),
    textSec    = Color3.fromRGB(150,150,155),
    textHead   = Color3.fromRGB(120,120,125),
    accent     = Color3.fromRGB(10,132,255),
    accentHov  = Color3.fromRGB(16,137,230),
    green      = Color3.fromRGB(48,209,88),
    red        = Color3.fromRGB(255,69,58),
    yellow     = Color3.fromRGB(255,214,10),
    toggleOff  = Color3.fromRGB(72,72,74),
    knob       = Color3.fromRGB(255,255,255),
    font       = Enum.Font.Gotham,
    fontBold   = Enum.Font.GothamBold,
    R          = UDim.new(0,10),
    Rs         = UDim.new(0,8),
    Rp         = UDim.new(1,0),
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
-- ==================== TITLE BAR ====================
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

-- ==================== SIDEBAR ====================
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
verLbl.Text = "v1.0"
verLbl.Font = Theme.font
verLbl.TextSize = 10
verLbl.TextColor3 = Theme.textSec
verLbl.BackgroundTransparency = 1
verLbl.Size = UDim2.new(1,-12,0,20)
verLbl.Position = UDim2.new(0,6,1,-26)
verLbl.TextXAlignment = Enum.TextXAlignment.Left
verLbl.Parent = sidebar

-- ==================== CONTENT ====================
local content = Instance.new("Frame")
content.Size = UDim2.new(1,-96,1,-32)
content.Position = UDim2.fromOffset(96,32)
content.BackgroundTransparency = 1
content.Parent = win
-- ==================== TAB SYSTEM ====================
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
-- ==================== COMPONENTS ====================
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
    track.Parent = card
    corner(track, Theme.Rp)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18,18)
    knob.Position = default and UDim2.fromOffset(20,2) or UDim2.fromOffset(2,2)
    knob.BackgroundColor3 = Theme.knob
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, Theme.Rp)

    local state = default or false
    track.Activated:Connect(function()
        state = not state
        T:Create(track, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            BackgroundColor3 = state and Theme.green or Theme.toggleOff
        }):Play()
        T:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = state and UDim2.fromOffset(20,2) or UDim2.fromOffset(2,2)
        }):Play()
        if callback then callback(state) end
    end)
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
        if callback then callback(stepped) end
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

-- ==================== DRAG WINDOW ====================
local dragging, dragStart, startPos
tb.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        startPos = win.Position
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
-- ==================== REGISTER TABS ====================
local farm = addTab("Farm", "📁", 1)
local combat = addTab("Combat", "⚔", 2)
local visual = addTab("Visual", "👁", 3)
local settings = addTab("Settings", "⚙", 4)

-- FARM (dummy)
Comp.section(farm, "Automation")
Comp.toggle(farm, "Auto Dungeon", "autoDungeon", false, function(v) end)
Comp.toggle(farm, "Walk Flow", "walkFlow", false, function(v) end)
Comp.toggle(farm, "Auto Swing", "autoSwing", false, function(v) end)
Comp.toggle(farm, "Auto Collect", "autoCollect", false, function(v) end)

Comp.section(farm, "Timing")
Comp.slider(farm, "swing_delay", "swingDelay", 0.02, 1, 0.02, 0.08, function(v) end)
Comp.slider(farm, "walk_delay", "walkDelay", 0.1, 1, 0.05, 0.2, function(v) end)
Comp.slider(farm, "collect_range", "collectRange", 50, 500, 10, 250, function(v) end)

Comp.section(farm, "Utility")
Comp.toggle(farm, "No Clip", "noClip", false, function(v) end)
Comp.toggle(farm, "Freeze NPC", "freezeNPC", false, function(v) end)

-- COMBAT (dummy)
Comp.section(combat, "Skills")
Comp.toggle(combat, "Auto Skill Q/E", "autoSkill", false, function(v) end)
Comp.slider(combat, "skill_q_delay", "skillQDelay", 0.2, 10, 0.1, 1.5, function(v) end)
Comp.slider(combat, "skill_e_delay", "skillEDelay", 0.2, 10, 0.1, 1.5, function(v) end)

Comp.section(combat, "Healing")
Comp.toggle(combat, "Auto Heal", "autoHeal", false, function(v) end)
Comp.slider(combat, "heal_amount", "healAmount", 50, 1000, 50, 500, function(v) end)
Comp.slider(combat, "heal_interval", "healInterval", 2, 30, 1, 5, function(v) end)

Comp.section(combat, "Dodge")
Comp.toggle(combat, "Auto Dodge", "autoDodge", false, function(v) end)
Comp.slider(combat, "dodge_range", "dodgeRange", 5, 40, 1, 10, function(v) end)
Comp.slider(combat, "dodge_speed", "dodgeSpeed", 4, 20, 1, 12, function(v) end)

-- VISUAL (dummy)
Comp.section(visual, "ESP")
Comp.toggle(visual, "ESP Overlay", "espOverlay", false, function(v) end)
Comp.slider(visual, "esp_range", "espRange", 50, 2000, 50, 800, function(v) end)

Comp.section(visual, "Hitbox")
Comp.toggle(visual, "Hitbox Visual", "hitboxVisual", false, function(v) end)
Comp.toggle(visual, "Hitbox Expand", "hitbox", false, function(v) end)
Comp.slider(visual, "hitbox_size", "hitboxSize", 1, 10, 0.5, 2.5, function(v) end)

-- SETTINGS
Comp.section(settings, "Info")
local infoLbl = Instance.new("TextLabel")
infoLbl.Text = "UI Framework v1.0\nBelum ada fitur aktif.\nFitur tinggal didaftarkan via Comp.toggle / Comp.slider."
infoLbl.Font = Theme.font
infoLbl.TextSize = 11
infoLbl.TextColor3 = Theme.textSec
infoLbl.TextXAlignment = Enum.TextXAlignment.Left
infoLbl.TextWrapped = true
infoLbl.BackgroundTransparency = 1
infoLbl.Size = UDim2.new(1,-8,0,70)
infoLbl.Position = UDim2.fromOffset(6,0)
infoLbl.LayoutOrder = nextOrder(settings)
infoLbl.Parent = settings

switchTab("Farm")
-- ==================== TOGGLE + SMOOTH ANIMATION ====================
local isOpen = true
local isAnimating = false

local baseSize = win.Size
local basePos = win.Position

local OPEN_SCALE = 0.85
local CLOSE_SCALE = 0.85
local DUR_OPEN = 0.4
local DUR_CLOSE = 0.25

-- hitung ukuran/posisi kecil (center-anchored)
local function scaledState(scale)
    local w = baseSize.X.Offset * scale
    local h = baseSize.Y.Offset * scale
    local xOff = basePos.X.Offset + (baseSize.X.Offset - w) / 2
    local yOff = basePos.Y.Offset + (baseSize.Y.Offset - h) / 2
    return UDim2.fromOffset(w, h), UDim2.new(basePos.X.Scale, xOff, basePos.Y.Scale, yOff)
end

-- ============ OPEN ============
local function openWindow()
    if isAnimating or isOpen then return end
    isAnimating = true
    isOpen = true

    local sSize, sPos = scaledState(OPEN_SCALE)
    win.Visible = true
    win.Size = sSize
    win.Position = sPos
    win.BackgroundTransparency = 1

    task.wait()

    local t = T:Create(win, TweenInfo.new(DUR_OPEN, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = baseSize,
        Position = basePos,
        BackgroundTransparency = 0,
    })
    t:Play()
    t.Completed:Connect(function() isAnimating = false end)
end

-- ============ CLOSE ============
local function closeWindow()
    if isAnimating or not isOpen then return end
    isAnimating = true
    isOpen = false

    local sSize, sPos = scaledState(CLOSE_SCALE)

    local t = T:Create(win, TweenInfo.new(DUR_CLOSE, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Size = sSize,
        Position = sPos,
        BackgroundTransparency = 1,
    })
    t:Play()
    t.Completed:Connect(function()
        win.Visible = false
        win.Size = baseSize
        win.Position = basePos
        win.BackgroundTransparency = 0
        isAnimating = false
    end)
end

-- ============ TOGGLE BUTTON ============
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleBtn"
toggleBtn.Text = "DQ"
toggleBtn.Font = Theme.fontBold
toggleBtn.TextSize = 14
toggleBtn.TextColor3 = Theme.textPri
toggleBtn.BackgroundColor3 = Theme.accent
toggleBtn.BorderSizePixel = 0
toggleBtn.Size = UDim2.fromOffset(52, 52)
toggleBtn.Position = UDim2.new(0, 20, 0, 80)
toggleBtn.AutoButtonColor = false
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.ZIndex = 10
toggleBtn.Parent = gui
corner(toggleBtn, Theme.Rp)
stroke(toggleBtn, Color3.fromRGB(0, 0, 0), 1, 0.6)

local function toggleUI()
    if isOpen then
        closeWindow()
        toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    else
        openWindow()
        toggleBtn.BackgroundColor3 = Theme.accent
    end
end

-- Multi-event fallback (reliable di semua executor)
toggleBtn.MouseButton1Click:Connect(toggleUI)
toggleBtn.Activated:Connect(toggleUI)

-- ============ RED / YELLOW = CLOSE ============
redBtn.MouseButton1Click:Connect(function() if isOpen then toggleUI() end end)
redBtn.Activated:Connect(function() if isOpen then toggleUI() end end)
ylwBtn.MouseButton1Click:Connect(function() if isOpen then toggleUI() end end)
ylwBtn.Activated:Connect(function() if isOpen then toggleUI() end end)

-- ============ GREEN = RESIZE ============
local isBig = false
grnBtn.MouseButton1Click:Connect(function()
    if isAnimating then return end
    isBig = not isBig
    isAnimating = true

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

    baseSize = targetSize
    basePos = targetPos

    local t = T:Create(win, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = targetSize,
        Position = targetPos,
    })
    t:Play()
    t.Completed:Connect(function() isAnimating = false end)
end)

print("[DQR] Toggle + animation ready")
