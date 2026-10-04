-- ============================================================
-- DUNGEON QUEST AUTO FARM
-- ============================================================
local P = game:GetService("Players")
local LP = P.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local T = game:GetService("TweenService")

local CG
local okCG = pcall(function() CG = game:GetService("CoreGui") end)
if okCG and CG then
    local old = CG:FindFirstChild("DQAF")
    if old then old:Destroy() end
end
local PG = LP:WaitForChild("PlayerGui")
local oldPG = PG:FindFirstChild("DQAF")
if oldPG then oldPG:Destroy() end

local cfg = {
    WalkFlow = false, ESPLines = false, AutoSwing = false,
    AutoCollect = false, AutoDungeon = false, NoClip = false,
    Hitbox = false, AutoDodge = false,
    WalkDelay = 0.3, SwingDelay = 0.1, CollectRange = 250,
    ESPRange = 500, HitboxSize = 3,
    DodgeRange = 14, DodgeDistance = 12,
}

local char, hrp, hum
local function refreshChar()
    char = LP.Character or LP.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart", 5)
    hum = char:WaitForChild("Humanoid", 5)
end
refreshChar()
LP.CharacterAdded:Connect(function() task.wait(1) refreshChar() end)

local cur = nil
local espCache = {}
local hitboxCache = {}
local dodgeLock = 0
local lastHP = math.huge
local function inD()
    local v = WS:FindFirstChild("dungeonStarted")
    return v and v:IsA("BoolValue") and v.Value
end
local function wv()
    local v = WS:FindFirstChild("currentWave")
    return v and v.Value or 0
end
local function isE(m)
    if not m or not m:IsA("Model") then return false end
    if m == char then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    if P:GetPlayerFromCharacter(m) then return false end
    if not m:FindFirstChild("HumanoidRootPart") then return false end
    return true
end
local function eList()
    local l = {}
    for _, v in ipairs(WS:GetDescendants()) do
        if isE(v) then
            local hE = v:FindFirstChild("HumanoidRootPart")
            if hE then table.insert(l, v) end
        end
    end
    return l
end
local function near()
    if not hrp then return nil end
    local n, d = nil, math.huge
    for _, e in ipairs(eList()) do
        local hE = e:FindFirstChild("HumanoidRootPart")
        if hE then
            local dd = (hE.Position - hrp.Position).Magnitude
            if dd < d then d = dd n = e end
        end
    end
    return n
end
local function getT()
    if cur and cur.Parent and isE(cur) then
        local hE = cur:FindFirstChild("HumanoidRootPart")
        if hE and hrp and (hE.Position - hrp.Position).Magnitude < 200 then
            return cur
        end
    end
    cur = near()
    return cur
end
task.spawn(function()
    while true do
        if cur then
            local h = cur:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 or not cur.Parent then cur = nil end
        end
        task.wait(0.1)
    end
end)
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
        if t:IsA("Tool") then
            pcall(function() h:EquipTool(t) end)
            return
        end
    end
end

local function noclipLoop()
    while cfg.NoClip do
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
            end
        end
        task.wait(0.2)
    end
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                pcall(function() p.CanCollide = true end)
            end
        end
    end
end

local function applyHitbox(m)
    local hE = m:FindFirstChild("HumanoidRootPart")
    if not hE then return end
    local c = hitboxCache[hE]
    if c then
        if c.applied == cfg.HitboxSize then return end
        pcall(function() hE.Size = c.size * cfg.HitboxSize end)
        c.applied = cfg.HitboxSize
        return
    end
    hitboxCache[hE] = { size = hE.Size, trans = hE.Transparency,
        collide = hE.CanCollide, massless = hE.Massless, applied = cfg.HitboxSize }
    pcall(function()
        hE.Size = hE.Size * cfg.HitboxSize
        hE.Transparency = 1
        hE.CanCollide = false
        hE.Massless = true
        hE.CanQuery = true
        hE.CanTouch = true
    end)
end

local function restoreHitbox(hE)
    local c = hitboxCache[hE]
    if not c then return end
    pcall(function()
        hE.Size = c.size
        hE.Transparency = c.trans
        hE.CanCollide = c.collide
        hE.Massless = c.massless
    end)
    hitboxCache[hE] = nil
end

local function hitboxLoop()
    while cfg.Hitbox do
        for _, m in ipairs(eList()) do applyHitbox(m) end
        for hE, _ in pairs(hitboxCache) do
            if not hE.Parent then restoreHitbox(hE) end
        end
        task.wait(0.4)
    end
    for hE, _ in pairs(hitboxCache) do restoreHitbox(hE) end
end

local ESPok = pcall(function()
    local d = Drawing.new("Line")
    d:Remove()task.spawn(function()
    local cam = WS.CurrentCamera
    while true do
        if cfg.ESPLines and ESPok and hrp and cam then
            local en = eList()
            for _, e in ipairs(en) do
                if not espCache[e] then
                    local l = Drawing.new("Line")
                    l.Visible = false
                    l.Color = Color3.fromRGB(255, 69, 58)
                    l.Thickness = 1.5
                    l.Transparency = 1
                    l.From = Vector2.new(0, 0)
                    l.To = Vector2.new(0, 0)
                    espCache[e] = l
                end
            end
            for m, l in pairs(espCache) do
                if not m.Parent or not isE(m) then
                    pcall(function() l:Remove() end)
                    espCache[m] = nil
                end
            end
            local ss = cam.ViewportSize
            local bc = Vector2.new(ss.X / 2, ss.Y)
            for m, l in pairs(espCache) do
                local hE = m:FindFirstChild("HumanoidRootPart")
                if hE and hrp and (hE.Position - hrp.Position).Magnitude <= cfg.ESPRange then
                    local sp, on = cam:WorldToViewportPoint(hE.Position)
                    if on then
                        l.From = bc
                        l.To = Vector2.new(sp.X, sp.Y)
                        if m == cur then
                            l.Color = Color3.fromRGB(48, 209, 88)
                            l.Thickness = 3
                        else
                            l.Color = Color3.fromRGB(255, 69, 58)
                            l.Thickness = 1.5
                        end
                        l.Visible = true
                    else l.Visible = false end
                else l.Visible = false end
            end
        else
            for _, l in pairs(espCache) do l.Visible = false end
            task.wait(0.3)
        end
        task.wait(0.02)
    end
end)

local function swingLoop()
    while cfg.AutoSwing do
        if char and hum and hum.Health > 0 then
            autoEquip()
            local t = getT()
            if t then
                local hE = t:FindFirstChild("HumanoidRootPart")
                if hE and hrp then
                    pcall(function()
                        hrp.CFrame = CFrame.new(hrp.Position,
                            Vector3.new(hE.Position.X, hrp.Position.Y, hE.Position.Z))
                    end)
                end
                local h = t:FindFirstChildOfClass("Humanoid")
                if not h or h.Health <= 0 then cur = nil end
            end
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then pcall(function() tool:Activate() end) end
            end
            task.wait(cfg.SwingDelay)
        else task.wait(0.5) end
    end
        end
end)
local function walkLoop()
    while cfg.WalkFlow do
        if hrp and hum and hum.Health > 0 then
            if tick() - dodgeLock < 0.35 then task.wait(0.05)
            else
                local t = getT()
                if t then
                    local hE = t:FindFirstChild("HumanoidRootPart")
                    if hE then
                        local d = (hE.Position - hrp.Position).Magnitude
                        if d > 10 then
                            pcall(function()
                                hum:MoveTo(Vector3.new(hE.Position.X, hrp.Position.Y, hE.Position.Z))
                            end)
                            task.wait(cfg.WalkDelay)
                        else
                            pcall(function() hum:MoveTo(hrp.Position) end)
                            task.wait(0.1)
                        end
                    else cur = nil task.wait(0.2) end
                else task.wait(0.5) end
            end
        else task.wait(0.5) end
    end
end

local function colLoop()
    while cfg.AutoCollect do
        if hrp and hum and hum.Health > 0 then
            for _, v in ipairs(WS:GetDescendants()) do
                if not cfg.AutoCollect then break end
                if v:IsA("BasePart") and v.Parent then
                    local n = string.lower(v.Name)
                    if string.find(n, "coin") or string.find(n, "gold")
                    or string.find(n, "drop") or string.find(n, "gem") then
                        local d = (v.Position - hrp.Position).Magnitude
                        if d < cfg.CollectRange and d > 3 then
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

local function dunLoop()
    task.wait(1)
    while cfg.AutoDungeon do
        if not inD() then
            local rm = RS:FindFirstChild("remotes")
            if rm then
                local cv = rm:FindFirstChild("changeStartValue")
                if cv then pcall(function() cv:FireServer("Desert Temple") end) end
            end
            task.wait(0.5)
            local rm2 = RS:FindFirstChild("remotes")
            if rm2 then
                local sd = rm2:FindFirstChild("startDungeon")
                if sd then pcall(function() sd:FireServer() end) end
            end
            task.wait(2)
            if not inD() then
                local rm3 = RS:FindFirstChild("remotes")
                if rm3 then
                    local rp = rm3:FindFirstChild("replayDungeon")
                    if rp then pcall(function() rp:FireServer() end) end
                end
                task.wait(2)
            end
            task.wait(5)
        else task.wait(2) end
    end
end

local function dodgeAway(fromPos, distance)
    if not hrp or not hum then return end
    local dir = hrp.Position - fromPos
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
    dir = dir.Unit
    local side = Vector3.new(-dir.Z, 0, dir.X) * (math.random(-10, 10) / 10)
    local fd = dir * 0.75 + side * 0.25
    if fd.Magnitude > 0.1 then fd = fd.Unit end
    pcall(function() hum:MoveTo(hrp.Position + fd * distance) end)
    dodgeLock = tick()
end

local function dodgeLoop()
    while cfg.AutoDodge do
        if hrp and hum and hum.Health > 0 then
            if hum.Health < lastHP - 0.5 then
                local enemies = eList()
                if #enemies > 0 then
                    local nh, nd = nil, math.huge
                    for _, e in ipairs(enemies) do
                        local hE = e:FindFirstChild("HumanoidRootPart")
                        if hE then
                            local d = (hE.Position - hrp.Position).Magnitude
                            if d < nd then nd = d nh = hE end
                        end
                    end
                    if nh then dodgeAway(nh.Position, cfg.DodgeDistance * 1.8) end
                end
            end
            lastHP = hum.Health
            if tick() - dodgeLock > 0.35 then
                local enemies = eList()
                local nHrp, nDist = nil, math.huge
                for _, e in ipairs(enemies) do
                    local hE = e:FindFirstChild("HumanoidRootPart")
                    if hE then
                        local d = (hE.Position - hrp.Position).Magnitude
                        if d < nDist then nDist = d nHrp = hE end
                    end
                end
                if nHrp and nDist < cfg.DodgeRange then
                    local toMe = hrp.Position - nHrp.Position
                    toMe = Vector3.new(toMe.X, 0, toMe.Z)
                    local facing = false
                    if toMe.Magnitude > 0.1 then
                        facing = nHrp.CFrame.LookVector:Dot(toMe.Unit) > 0.2
                    end
                    if facing or nDist < cfg.DodgeRange * 0.55 then
                        dodgeAway(nHrp.Position, cfg.DodgeDistance)
                    end
                end
            end
        end
        task.wait(0.05)
    end
end
local parentGui = PG
if okCG and CG then parentGui = CG end

local Mac = {
    Bg = Color3.fromRGB(28, 28, 30),
    BgGlass = Color3.fromRGB(38, 38, 42),
    Card = Color3.fromRGB(48, 48, 52),
    Stroke = Color3.fromRGB(70, 70, 75),
    Text = Color3.fromRGB(245, 245, 247),
    TextDim = Color3.fromRGB(150, 150, 155),
    Accent = Color3.fromRGB(10, 132, 255),
    Green = Color3.fromRGB(48, 209, 88),
    Red = Color3.fromRGB(255, 69, 58),
    Yellow = Color3.fromRGB(255, 214, 10),
    ToggleOff = Color3.fromRGB(99, 99, 102),
    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    R = UDim.new(0, 12),
    Rs = UDim.new(0, 8),
    Rp = UDim.new(1, 0),
}

local gui = Instance.new("ScreenGui")
gui.Name = "DQAF"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = parentGui

local shadow = Instance.new("ImageLabel")
shadow.Image = "rbxassetid://5028857472"
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(24, 24, 276, 276)
shadow.SliceScale = 0.5
shadow.BackgroundTransparency = 1
shadow.ImageColor3 = Color3.new(0, 0, 0)
shadow.ImageTransparency = 0.4
shadow.ZIndex = 0
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
shadow.Size = UDim2.new(0, 340, 0, 440)
shadow.Visible = false
shadow.Parent = gui

local win = Instance.new("Frame")
win.AnchorPoint = Vector2.new(0.5, 0.5)
win.Position = UDim2.new(0.5, 0, 0.5, 0)
win.Size = UDim2.new(0, 320, 0, 420)
win.BackgroundColor3 = Mac.Bg
win.BackgroundTransparency = 0.05
win.BorderSizePixel = 0
win.Visible = false
win.ZIndex = 1
win.Parent = gui
local cw = Instance.new("UICorner") cw.CornerRadius = Mac.R cw.Parent = win
local sw = Instance.new("UIStroke") sw.Color = Mac.Stroke sw.Thickness = 1 sw.Transparency = 0.4 sw.Parent = win

local tb = Instance.new("Frame")
tb.Size = UDim2.new(1, 0, 0, 36)
tb.BackgroundColor3 = Mac.BgGlass
tb.BackgroundTransparency = 0.3
tb.BorderSizePixel = 0
tb.ZIndex = 2
tb.Parent = win
local ctb = Instance.new("UICorner") ctb.CornerRadius = Mac.R ctb.Parent = tb
local tbf = Instance.new("Frame")
tbf.Size = UDim2.new(1, 0, 0, 12)
tbf.Position = UDim2.new(0, 0, 1, -12)
tbf.BackgroundColor3 = Mac.BgGlass
tbf.BackgroundTransparency = 0.3
tbf.BorderSizePixel = 0
tbf.ZIndex = 2
tbf.Parent = tb

local function dot(x, color)
    local d = Instance.new("TextButton")
    d.Text = ""
    d.Size = UDim2.fromOffset(12, 12)
    d.Position = UDim2.fromOffset(x, 12)
    d.BackgroundColor3 = color
    d.BorderSizePixel = 0
    d.AutoButtonColor = false
    d.ZIndex = 3
    d.Parent = tb
    local c = Instance.new("UICorner") c.CornerRadius = Mac.Rp c.Parent = d
    return d
end
local redBtn = dot(14, Mac.Red)
local ylwBtn = dot(32, Mac.Yellow)
local grnBtn = dot(50, Mac.Green)

local titleLbl = Instance.new("TextLabel")
titleLbl.Text = "Dungeon Quest"
titleLbl.Font = Mac.FontBold
titleLbl.TextSize = 12
titleLbl.TextColor3 = Mac.Text
titleLbl.BackgroundTransparency = 1
titleLbl.Size = UDim2.new(1, -80, 1, 0)
titleLbl.Position = UDim2.fromOffset(70, 0)
titleLbl.ZIndex = 3
titleLbl.Parent = tb

local st = Instance.new("TextLabel")
st.Text = "Idle"
st.Font = Mac.FontBold
st.TextSize = 10
st.TextColor3 = Mac.TextDim
st.TextXAlignment = Enum.TextXAlignment.Left
st.BackgroundColor3 = Mac.Card
st.BorderSizePixel = 0
st.Size = UDim2.new(1, -16, 0, 24)
st.Position = UDim2.fromOffset(8, 40)
st.ZIndex = 2
st.Parent = win
local c4 = Instance.new("UICorner") c4.CornerRadius = UDim.new(0, 6) c4.Parent = st
local sp4 = Instance.new("UIPadding") sp4.PaddingLeft = UDim.new(0, 10) sp4.Parent = st

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 32)
tabBar.Position = UDim2.fromOffset(8, 68)
tabBar.BackgroundColor3 = Mac.Card
tabBar.BackgroundTransparency = 0.4
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 2
tabBar.Parent = win
local ctb2 = Instance.new("UICorner") ctb2.CornerRadius = UDim.new(0, 6) ctb2.Parent = tabBar
local tlay = Instance.new("UIListLayout")
tlay.FillDirection = Enum.FillDirection.Horizontal
tlay.SortOrder = Enum.SortOrder.LayoutOrder
tlay.Padding = UDim.new(0, 4)
tlay.Parent = tabBar
local tpad = Instance.new("UIPadding")
tpad.PaddingLeft = UDim.new(0, 4)
tpad.PaddingRight = UDim.new(0, 4)
tpad.PaddingTop = UDim.new(0, 4)
tpad.PaddingBottom = UDim.new(0, 4)
tpad.Parent = tabBar

local pagesHolder = Instance.new("Frame")
pagesHolder.Size = UDim2.new(1, -16, 1, -114)
pagesHolder.Position = UDim2.fromOffset(8, 104)
pagesHolder.BackgroundTransparency = 1
pagesHolder.ZIndex = 2
pagesHolder.Parent = win

local pages = {}
local tabs = {}
local currentTab = nil

local function showTab(name)
    if currentTab == name then return end
    currentTab = name
    for n, page in pairs(pages) do page.Visible = (n == name) end
    for n, btn in pairs(tabs) do
        if n == name then
            T:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Mac.Accent, TextColor3 = Mac.Text }):Play()
        else
            T:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Mac.Card, TextColor3 = Mac.TextDim }):Play()
        end
    end
end

local function makeTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Text = name
    btn.Font = Mac.FontBold
    btn.TextSize = 11
    btn.TextColor3 = Mac.TextDim
    btn.BackgroundColor3 = Mac.Card
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.Size = UDim2.new(0, 0, 1, 0)
    btn.ZIndex = 3
    btn.Parent = tabBar
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = btn
    btn.Activated:Connect(function() showTab(name) end)
    tabs[name] = btn
end

local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Mac.TextDim
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.ZIndex = 2
    page.Parent = pagesHolder
    local lay = Instance.new("UIListLayout") lay.Padding = UDim.new(0, 5) lay.Parent = page
    pages[name] = page
    return page
end

makeTab("Auto", 1)
makeTab("Combat", 2)
makeTab("Misc", 3)
local pageAuto = makePage("Auto")
local pageCombat = makePage("Combat")
local pageMisc = makePage("Misc")

task.spawn(function()
    task.wait(0.1)
    for _, btn in pairs(tabs) do
        btn.Size = UDim2.new(0, btn.TextBounds.X + 20, 1, 0)
    end
end)

print("[DQAF] Core loaded. ESP:", ESPok)
local function mkT(parent, name, key, fn)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -2, 0, 40)
    row.BackgroundColor3 = Mac.Card
    row.BorderSizePixel = 0
    row.ZIndex = 2
    row.Parent = parent
    local cr = Instance.new("UICorner") cr.CornerRadius = Mac.Rs cr.Parent = row
    local lbl = Instance.new("TextLabel")
    lbl.Text = name
    lbl.Font = Mac.Font
    lbl.TextSize = 12
    lbl.TextColor3 = Mac.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.fromOffset(12, 0)
    lbl.ZIndex = 3
    lbl.Parent = row
    local track = Instance.new("TextButton")
    track.Text = ""
    track.Size = UDim2.fromOffset(42, 22)
    track.Position = UDim2.new(1, -54, 0.5, -11)
    track.BackgroundColor3 = Mac.ToggleOff
    track.BorderSizePixel = 0
    track.AutoButtonColor = false
    track.ZIndex = 3
    track.Parent = row
    local ctr = Instance.new("UICorner") ctr.CornerRadius = Mac.Rp ctr.Parent = track
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 4
    knob.Parent = track
    local ck = Instance.new("UICorner") ck.CornerRadius = Mac.Rp ck.Parent = knob
    local function setState(on, anim)
        if on then
            if anim then
                T:Create(track, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundColor3 = Mac.Green }):Play()
                T:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(22, 2) }):Play()
            else track.BackgroundColor3 = Mac.Green knob.Position = UDim2.fromOffset(22, 2) end
        else
            if anim then
                T:Create(track, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundColor3 = Mac.ToggleOff }):Play()
                T:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(2, 2) }):Play()
            else track.BackgroundColor3 = Mac.ToggleOff knob.Position = UDim2.fromOffset(2, 2) end
        end
    end
    setState(cfg[key], false)
    track.Activated:Connect(function()
        cfg[key] = not cfg[key]
        setState(cfg[key], true)
        if cfg[key] and fn then task.spawn(fn) end
    end)
end

local function mkS(parent, name, key, mn, mx, stp, dv)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -2, 0, 44)
    row.BackgroundColor3 = Mac.Card
    row.BorderSizePixel = 0
    row.ZIndex = 2
    row.Parent = parent
    local cr = Instance.new("UICorner") cr.CornerRadius = Mac.Rs cr.Parent = row
    local lbl = Instance.new("TextLabel")
    lbl.Text = name .. "  ·  " .. dv
    lbl.Font = Mac.Font
    lbl.TextSize = 11
    lbl.TextColor3 = Mac.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -20, 0, 16)
    lbl.Position = UDim2.fromOffset(12, 6)
    lbl.ZIndex = 3
    lbl.Parent = row
    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -70, 0, 4)
    barBg.Position = UDim2.fromOffset(12, 30)
    barBg.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 3
    barBg.Parent = row
    local cb = Instance.new("UICorner") cb.CornerRadius = Mac.Rp cb.Parent = barBg
    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new((dv - mn) / (mx - mn), 0, 1, 0)
    barFill.BackgroundColor3 = Mac.Accent
    barFill.BorderSizePixel = 0
    barFill.ZIndex = 4
    barFill.Parent = barBg
    local cf = Instance.new("UICorner") cf.CornerRadius = Mac.Rp cf.Parent = barFill
    local v = dv
    local function update()
        cfg[key] = v
        lbl.Text = name .. "  ·  " .. v
        local ratio = (v - mn) / (mx - mn)
        T:Create(barFill, TweenInfo.new(0.15, Enum.EasingStyle.Quart), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
    end
    local minus = Instance.new("TextButton")
    minus.Text = "−"
    minus.Font = Mac.FontBold
    minus.TextSize = 15
    minus.TextColor3 = Mac.Text
    minus.BackgroundColor3 = Color3.fromRGB(60, 60, 64)
    minus.BorderSizePixel = 0
    minus.Size = UDim2.fromOffset(22, 22)
    minus.Position = UDim2.new(1, -58, 0.5, -11)
    minus.AutoButtonColor = false
    minus.ZIndex = 4
    minus.Parent = row
    local cm = Instance.new("UICorner") cm.CornerRadius = Mac.Rp cm.Parent = minus
    local plus = Instance.new("TextButton")
    plus.Text = "+"
    plus.Font = Mac.FontBold
    plus.TextSize = 13
    plus.TextColor3 = Mac.Text
    plus.BackgroundColor3 = Color3.fromRGB(60, 60, 64)
    plus.BorderSizePixel = 0
    plus.Size = UDim2.fromOffset(22, 22)
    plus.Position = UDim2.new(1, -30, 0.5, -11)
    plus.AutoButtonColor = false
    plus.ZIndex = 4
    plus.Parent = row
    local cp = Instance.new("UICorner") cp.CornerRadius = Mac.Rp cp.Parent = plus
    minus.Activated:Connect(function() v = math.max(mn, v - stp) v = math.floor(v * 1000 + 0.5) / 1000 update() end)
    plus.Activated:Connect(function() v = math.min(mx, v + stp) v = math.floor(v * 1000 + 0.5) / 1000 update() end)
end

mkT(pageAuto, "Auto Dungeon", "AutoDungeon", dunLoop)
mkT(pageAuto, "Walk Flow", "WalkFlow", walkLoop)
mkT(pageAuto, "Auto Swing", "AutoSwing", swingLoop)
mkT(pageAuto, "Auto Collect", "AutoCollect", colLoop)
mkT(pageCombat, "ESP Lines", "ESPLines", nil)
mkT(pageCombat, "Hitbox Expand", "Hitbox", hitboxLoop)
mkT(pageCombat, "Auto Dodge", "AutoDodge", dodgeLoop)
mkT(pageCombat, "No Clip", "NoClip", noclipLoop)

local function head(parent, text)
    local s = Instance.new("TextLabel")
    s.Text = text
    s.Font = Mac.FontBold
    s.TextSize = 9
    s.TextColor3 = Mac.TextDim
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.BackgroundTransparency = 1
    s.Size = UDim2.new(1, 0, 0, 16)
    s.Position = UDim2.fromOffset(4, 0)
    s.Parent = parent
end
head(pageMisc, "TIMING")
mkS(pageMisc, "swing_delay", "SwingDelay", 0.02, 1, 0.02, 0.1)
mkS(pageMisc, "walk_delay", "WalkDelay", 0.1, 1, 0.05, 0.3)
head(pageMisc, "COMBAT")
mkS(pageMisc, "esp_range", "ESPRange", 50, 2000, 50, 500)
mkS(pageMisc, "hitbox_size", "HitboxSize", 1, 10, 0.5, 3)
head(pageMisc, "DODGE")
mkS(pageMisc, "dodge_range", "DodgeRange", 5, 40, 1, 14)
mkS(pageMisc, "dodge_dist", "DodgeDistance", 3, 30, 1, 12)

showTab("Auto")

local isOpen = false
local isAnim = false

local function openWindow()
    if isAnim or isOpen then return end
    isAnim = true
    isOpen = true
    shadow.Visible = true
    win.Visible = true
    win.Size = UDim2.new(0, 260, 0, 340)
    win.BackgroundTransparency = 1
    shadow.Size = UDim2.new(0, 280, 0, 360)
    shadow.ImageTransparency = 1
    local t1 = T:Create(win, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 320, 0, 420), BackgroundTransparency = 0.05 })
    T:Create(shadow, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 340, 0, 440), ImageTransparency = 0.4 }):Play()
    t1:Play()
    t1.Completed:Connect(function() isAnim = false end)
end

local function closeWindow()
    if isAnim or not isOpen then return end
    isAnim = true
    isOpen = false
    local t1 = T:Create(win, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 260, 0, 340), BackgroundTransparency = 1 })
    T:Create(shadow, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 280, 0, 360), ImageTransparency = 1 }):Play()
    t1:Play()
    t1.Completed:Connect(function()
        win.Visible = false
        shadow.Visible = false
        win.Size = UDim2.new(0, 320, 0, 420)
        win.BackgroundTransparency = 0.05
        shadow.Size = UDim2.new(0, 340, 0, 440)
        shadow.ImageTransparency = 0.4
        isAnim = false
    end)
end

redBtn.Activated:Connect(closeWindow)
ylwBtn.Activated:Connect(closeWindow)
grnBtn.Activated:Connect(function()
    if win.Size.X.Offset >= 320 then
        T:Create(win, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Size = UDim2.new(0, 400, 0, 500) }):Play()
    else
        T:Create(win, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Size = UDim2.new(0, 320, 0, 420) }):Play()
    end
end)

for _, btn in ipairs({ redBtn, ylwBtn, grnBtn }) do
    btn.MouseEnter:Connect(function()
        T:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = btn.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.3) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        local orig = btn == redBtn and Mac.Red or btn == ylwBtn and Mac.Yellow or Mac.Green
        T:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = orig }):Play()
    end)
end

local dragging, dragStart, startPos
tb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = win.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        shadow.Position = win.Position
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local tg = Instance.new("TextButton")
tg.Text = "DQ"
tg.Font = Mac.FontBold
tg.TextSize = 12
tg.TextColor3 = Mac.Text
tg.BackgroundColor3 = Mac.Accent
tg.BorderSizePixel = 0
tg.Size = UDim2.fromOffset(44, 34)
tg.Position = UDim2.new(0, 20, 0, 80)
tg.AutoButtonColor = false
tg.ZIndex = 5
tg.Parent = gui
local ctg = Instance.new("UICorner") ctg.CornerRadius = Mac.Rp ctg.Parent = tg
local stg = Instance.new("UIStroke") stg.Color = Color3.new(0, 0, 0) stg.Thickness = 1 stg.Transparency = 0.6 stg.Parent = tg
tg.Activated:Connect(function()
    if isOpen then closeWindow() else openWindow() end
end)

task.wait(0.1)
openWindow()

task.spawn(function()
    while gui.Parent do
        if inD() then
            local l = eList()
            local tn = cur and cur.Name or "none"
            st.Text = string.format("Wave %d  ·  %d musuh  ·  %s", wv(), #l, tn)
            st.TextColor3 = Mac.Text
        else
            st.Text = "Idle  ·  Lobby"
            st.TextColor3 = Mac.TextDim
        end
        task.wait(0.5)
    end
end)

print("[DQAF] All loaded. ESP support:", ESPok)
