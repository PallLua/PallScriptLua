--[[
    PALL — FISCH v8.0.0
    Auto: Rod Equip, Cast, Bobber, Shake, Reel
    Strategy: tap simulation tiap minigame, bukan remote
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RUN = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local VU = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

--============================================================
-- LOAD WINDUI
--============================================================
local WindUI
if _G.PallWindUI then
    WindUI = _G.PallWindUI
else
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end)
    if not ok then error("[PALL-FISCH] Gagal load WindUI.") end
    WindUI = result
    _G.PallWindUI = WindUI
end

local Green = Color3.fromHex("#10C550")
local Yellow = Color3.fromHex("#ECA201")
local Blue = Color3.fromHex("#257AF7")
local Grey = Color3.fromHex("#83889E")
local Purple = Color3.fromHex("#7775F2")
local Red = Color3.fromHex("#EF4F1D")

--============================================================
-- CLEAN OLD
--============================================================
if _G.FISCH_RUNNING then
    _G.FISCH_RUNNING = false
    task.wait(0.5)
end
_G.FISCH_RUNNING = true

--============================================================
-- FLAGS
--============================================================
_G.AutoFish       = false
_G.AutoEquipBest  = true
_G.AutoBobber     = true
_G.AutoShake      = true
_G.AutoReel       = true
_G.BobberThreshold = 0.7
_G.ShakeDelay     = 0.04
_G.ReelHoldTime   = 0.15
_G.AntiAFK        = true
_G.SpeedBoost     = false
_G.Fly            = false
_G.FlySpeed       = 50
_G.ESP            = false
_G.ESPRange       = 300
_G.AutoSell       = false

--============================================================
-- CHAR REF
--============================================================
local char, hrp, hum
local function refreshChar()
    char = LP.Character or LP.CharacterAdded:Wait()
    hrp  = char:WaitForChild("HumanoidRootPart", 5)
    hum  = char:WaitForChild("Humanoid", 5)
end
refreshChar()
LP.CharacterAdded:Connect(function() task.wait(0.8) refreshChar() end)

--============================================================
-- TAP HELPERS
--============================================================
local function tapAt(x, y)
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.02)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function holdAt(x, y, duration)
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(duration)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function tapElement(el)
    if not el then return false end
    local pos, size = el.AbsolutePosition, el.AbsoluteSize
    tapAt(pos.X + size.X / 2, pos.Y + size.Y / 2)
    return true
end

--============================================================
-- ROD HELPERS
--============================================================
local rodTier = {
    ["legendary"]=10, ["mythic"]=9, ["ancient"]=8,
    ["divine"]=7, ["rare"]=6, ["uncommon"]=5, ["common"]=1,
}

local function getRodScore(tool)
    local name = tool.Name:lower()
    for tier, score in pairs(rodTier) do
        if name:find(tier) then return score end
    end
    return 2
end

local function isRodTool(tool)
    if not tool:IsA("Tool") then return false end
    local n = tool.Name:lower()
    return n:find("rod") or n:find("fishing") or n:find("pole") or n:find("batang")
end

local function findBestRod()
    local best, bestScore = nil, -1
    for _, src in ipairs({ LP:FindFirstChild("Backpack"), char }) do
        if src then
            for _, t in ipairs(src:GetChildren()) do
                if isRodTool(t) then
                    local s = getRodScore(t)
                    if s > bestScore then
                        bestScore = s
                        best = t
                    end
                end
            end
        end
    end
    return best
end

local function equippedRod()
    if not char then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if isRodTool(t) then return t end
    end
    return nil
end

local function equipRod(rod)
    if not rod or not hum or not char then return end
    if char:FindFirstChild(rod.Name) then return end
    pcall(function() hum:EquipTool(rod) end)
    task.wait(0.5)
end
--============================================================
-- GUI DETECTION — untuk 3 minigame
--============================================================

-- 1. BOBber bar vertikal (dari "Mehh..." ke "Perfect")
local function findBobberBar()
    -- Cari di reel/parent gui
    local reel = PG:FindFirstChild("reel")
    if reel then
        local bar = reel:FindFirstChild("bar", true)
        if bar then return bar end
    end

    -- Cari nama-nama spesifik
    local names = {"BobberBar", "bobberBar", "CastBar", "castBar",
                   "TimingBar", "timingBar", "PerfectBar", "perfectBar"}
    for _, name in ipairs(names) do
        local found = PG:FindFirstChild(name, true)
        if found and found.Visible then return found end
    end

    -- Fallback: cari Frame vertikal tinggi (>100px, <30px lebar)
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Visible then
            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("Frame") and obj.Visible then
                    local sz = obj.AbsoluteSize
                    if sz.Y > 80 and sz.X < 40 and sz.X > 5 then
                        return obj
                    end
                end
            end
        end
    end
    return nil
end

-- Cari handle/indicator di dalam bar (yang gerak)
local function findBobberIndicator(bar)
    if not bar then return nil end
    for _, obj in ipairs(bar:GetDescendants()) do
        if (obj:IsA("ImageLabel") or obj:IsA("Frame")) and obj.Visible then
            local n = obj.Name:lower()
            if n:find("handle") or n:find("indicator") or n:find("marker")
               or n:find("knob") or n:find("moving") or n:find("slider")
               or n:find("pointer") or n:find("cursor") then
                return obj
            end
        end
    end
    -- Fallback: cari child pertama yang bukan background
    for _, obj in ipairs(bar:GetChildren()) do
        if (obj:IsA("ImageLabel") or obj:IsA("Frame")) and obj.Visible then
            return obj
        end
    end
    return nil
end

-- 2. SHAKE button (circle Guncang)
local function findShakeButton()
    -- Path eksplisit
    local shakeui = PG:FindFirstChild("shakeui")
    if shakeui and shakeui.Visible then
        for _, c in ipairs(shakeui:GetDescendants()) do
            if c:IsA("GuiButton") and c.Visible then return c end
        end
    end

    -- Cari button dengan text "Guncang" / "Shake"
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Visible then
            for _, c in ipairs(gui:GetDescendants()) do
                if c:IsA("GuiButton") and c.Visible then
                    local txt = ""
                    pcall(function() txt = (c.Text or ""):lower() end)
                    if txt:find("guncang") or txt:find("shake") then return c end
                    if c.Name:lower():find("guncang") or c.Name:lower():find("shake") then return c end
                end
            end
        end
    end
    return nil
end

-- 3. REEL slider (horizontal kiri-kanan)
local function findReelSlider()
    -- Path reel.bar.modal
    local reel = PG:FindFirstChild("reel")
    if reel and reel.Visible then
        -- Cari Handle di dalam reel
        for _, c in ipairs(reel:GetDescendants()) do
            if c.Name == "Handle" and c.Visible then return c end
        end
        -- Fallback: bar horizontal
        for _, c in ipairs(reel:GetDescendants()) do
            if c:IsA("Frame") and c.Visible then
                local sz = c.AbsoluteSize
                if sz.X > 200 and sz.Y < 60 then return c end
            end
        end
    end
    return nil
end

--============================================================
-- BOBber bar progress (0 = bawah/Mehh, 1 = atas/Perfect)
--============================================================
local function getBobberProgress(bar, indicator)
    if not bar or not indicator then return 0.5 end
    local barPos, barSize = bar.AbsolutePosition, bar.AbsoluteSize
    local indPos = indicator.AbsolutePosition

    -- Deteksi orientasi (vertikal atau horizontal)
    if barSize.Y > barSize.X then
        -- Vertikal — 1 = atas
        local rel = 1 - ((indPos.Y - barPos.Y) / barSize.Y)
        return math.clamp(rel, 0, 1)
    else
        -- Horizontal — asumsi 1 = kanan
        local rel = (indPos.X - barPos.X) / barSize.X
        return math.clamp(rel, 0, 1)
    end
end

--============================================================
-- AUTO EQUIP BEST ROD
--============================================================
task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(3)
        if not _G.AutoEquipBest then continue end
        if not hum or not char then continue end
        local best = findBestRod()
        if best and not char:FindFirstChild(best.Name) then
            equipRod(best)
            print("[FISCH] Equipped: " .. best.Name)
        end
    end
end)

--============================================================
-- CAST — tap rod button (kanan bawah)
--============================================================
local function tapRodButton()
    local vp = WS.CurrentCamera.ViewportSize
    tapAt(vp.X * 0.88, vp.Y * 0.72)
end

--============================================================
-- AUTO FISH STATE MACHINE
--============================================================
local fishState = "idle"
local lastCast = 0
local CAST_CD = 3
local BITE_TIMEOUT = 25
local lastAction = 0

task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(0.05)
        if not _G.AutoFish then
            fishState = "idle"
            task.wait(0.3)
            continue
        end
        if not char or not hum then continue end

        local now = tick()

        -- 1. CEK SHAKE BUTTON (prioritas tertinggi)
        local shakeBtn = findShakeButton()
        if shakeBtn and _G.AutoShake then
            fishState = "shake"
            tapElement(shakeBtn)
            task.wait(_G.ShakeDelay)
            continue
        end

        -- 2. CEK BOBber bar (timing cast)
        local bobberBar = findBobberBar()
        if bobberBar and _G.AutoBobber then
            local indicator = findBobberIndicator(bobberBar)
            if indicator then
                local prog = getBobberProgress(bobberBar, indicator)
                fishState = string.format("bobber (%.0f%%)", prog * 100)

                -- Tap ketika udah di atas threshold
                if prog >= _G.BobberThreshold then
                    -- Tap di area bar buat konfirm
                    tapElement(bobberBar)
                    task.wait(0.1)
                else
                    task.wait(0.02)
                end
                continue
            end
        end

        -- 3. CEK REEL slider (balance kiri-kanan)
        local reelSlider = findReelSlider()
        if reelSlider and _G.AutoReel then
            fishState = "reel"
            -- Hold + drag biar balance
            local pos = reelSlider.AbsolutePosition
            local size = reelSlider.AbsoluteSize
            holdAt(pos.X + size.X / 2, pos.Y + size.Y / 2, _G.ReelHoldTime)
            task.wait(0.05)
            continue
        end

        -- 4. CAST kalau nggak ada minigame aktif
        if now - lastCast >= CAST_CD then
            fishState = "cast"
            -- Pastikan rod equipped
            local rod = equippedRod()
            if not rod then
                rod = findBestRod()
                if rod then
                    equipRod(rod)
                    task.wait(0.3)
                end
            end

            -- Activate rod + tap button
            local r = equippedRod()
            if r then
                pcall(function() r:Activate() end)
            end
            task.wait(0.05)
            tapRodButton()

            lastCast = now
        else
            fishState = "waiting"
            task.wait(0.1)
        end
    end
end)
--============================================================
-- ANTI-AFK
--============================================================
task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(60)
        if _G.AntiAFK then
            pcall(function()
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
            end)
        end
    end
end)

--============================================================
-- SPEED BOOST
--============================================================
task.spawn(function()
    local prev = false
    while _G.FISCH_RUNNING do
        task.wait(0.3)
        if not hum then continue end
        if _G.SpeedBoost and not prev then
            hum.WalkSpeed = 32; prev = true
        elseif not _G.SpeedBoost and prev then
            hum.WalkSpeed = 16; prev = false
        end
    end
end)

--============================================================
-- FLY
--============================================================
local flyConn
local function updateFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if not _G.Fly then
        if hum then pcall(function() hum.PlatformStand = false end) end
        return
    end
    if hum then pcall(function() hum.PlatformStand = true end) end
    flyConn = RUN.RenderStepped:Connect(function()
        if not _G.Fly then
            if hum then pcall(function() hum.PlatformStand = false end) end
            if flyConn then flyConn:Disconnect(); flyConn = nil end
            return
        end
        if not hrp then return end
        local cf = WS.CurrentCamera.CFrame
        local move = Vector3.new(0, 0, 0)
        local spd = _G.FlySpeed
        if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.Q) then move = move - Vector3.new(0, 1, 0) end
        if move.Magnitude > 0.01 then move = move.Unit * spd end
        pcall(function()
            hrp.Velocity = move
            hrp.AssemblyLinearVelocity = move
        end)
    end)
end

task.spawn(function()
    local prev = false
    while _G.FISCH_RUNNING do
        task.wait(0.2)
        if _G.Fly ~= prev then
            prev = _G.Fly
            updateFly()
        end
    end
end)

--============================================================
-- ESP
--============================================================
local espBills = {}
local espCache = {}

local RARE_KW = {"legendary","mythic","ancient","divine","prismatic","rare","epic"}
local function isRare(name)
    local low = name:lower()
    for _, k in ipairs(RARE_KW) do
        if low:find(k) then return true end
    end
    return false
end

local function mkBill(adornee, text, color)
    if not adornee or espCache[adornee] then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(150, 32)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = adornee
    bb.Parent = WS
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.3
    lbl.BackgroundColor3 = Color3.new(0, 0, 0)
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    table.insert(espBills, bb)
    espCache[adornee] = true
end

local function clearESP()
    for _, b in ipairs(espBills) do
        pcall(function() b:Destroy() end)
    end
    espBills = {}; espCache = {}
end

task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(3)
        if not _G.ESP then clearESP() continue end
        if not hrp then continue end
        clearESP()
        local range = _G.ESPRange
        local hrpPos = hrp.Position
        for _, obj in ipairs(WS:GetChildren()) do
            if not hrp then break end
            local pos, adornee
            if obj:IsA("BasePart") then
                pos, adornee = obj.Position, obj
            elseif obj:IsA("Model") then
                local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                if p then pos, adornee = p.Position, p end
            end
            if pos and adornee and (pos - hrpPos).Magnitude <= range then
                if obj.Name:lower():find("fish") then
                    local prefix = isRare(obj.Name) and "⭐ " or "🐟 "
                    local col = isRare(obj.Name) and Color3.fromRGB(255,200,0) or Color3.fromRGB(100,200,255)
                    mkBill(adornee, prefix .. obj.Name, col)
                end
            end
        end
    end
end)

--============================================================
-- AUTO SELL
--============================================================
task.spawn(function()
    while _G.FISCH_RUNNING do
        task.wait(3)
        if _G.AutoSell then
            local ev = RS:FindFirstChild("events")
            if ev then
                local sell = ev:FindFirstChild("SellAll")
                if sell then pcall(function() sell:InvokeServer() end) end
            end
        end
    end
end)

--============================================================
-- FPS COUNTER
--============================================================
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0, 100, 0, 24)
fpsLabel.Position = UDim2.new(0, 10, 0, 10)
fpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fpsLabel.BackgroundTransparency = 0.5
fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
fpsLabel.Font = Enum.Font.Code
fpsLabel.TextSize = 14
fpsLabel.Text = "FPS: --"
fpsLabel.Parent = PG

local frames, lastTime, curFPS = 0, tick(), 0
RUN.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastTime >= 1 then
        curFPS = frames
        fpsLabel.Text = "FPS: " .. curFPS
        frames = 0; lastTime = tick()
    end
end)

--============================================================
-- WINDOW
--============================================================
local Window = WindUI:CreateWindow({
    Title = "Pall x Fisch",
    Folder = "pallfisch",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open Pall Fisch",
        CornerRadius = UDim.new(1, 0), StrokeThickness = 3,
        Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#3DC9FF"), Color3.fromHex("#10C550")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})
Window:Tag({ Title = "v8.0.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: AUTO FISH
--============================================================
local TabFish = Window:Tab({
    Title = "Auto Fish", Desc = "Cast + Bobber + Shake + Reel",
    Icon = "solar:fish-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s = TabFish:Section({ Title = "Master", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({
        Title = "Auto Fish (ALL)",
        Desc = "Cast + Equip + Bobber + Shake + Reel",
        Value = false,
        Callback = function(v)
            _G.AutoFish = v
            print("[FISCH] AutoFish = " .. tostring(v))
        end,
    })
    s:Space()
    s:Toggle({
        Title = "Auto Equip Best Rod",
        Value = true,
        Callback = function(v) _G.AutoEquipBest = v end,
    })

    local s2 = TabFish:Section({ Title = "Minigame 1 — Bobber (Cast Timing)", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({
        Title = "Auto Bobber (Perfect Timing)",
        Value = true,
        Callback = function(v) _G.AutoBobber = v end,
    })
    s2:Space()
    s2:Slider({
        Title = "Perfect Threshold", Step = 0.05,
        Value = { Min = 0.5, Max = 1, Default = 0.7 },
        Callback = function(v) _G.BobberThreshold = v end,
    })

    local s3 = TabFish:Section({ Title = "Minigame 2 — Guncang", Box = true, BoxBorder = true, Opened = true })
    s3:Toggle({
        Title = "Auto Shake (Tap Guncang)",
        Value = true,
        Callback = function(v) _G.AutoShake = v end,
    })
    s3:Space()
    s3:Slider({
        Title = "Tap Delay", Step = 0.01,
        Value = { Min = 0.02, Max = 0.2, Default = 0.04 },
        Callback = function(v) _G.ShakeDelay = v end,
    })

    local s4 = TabFish:Section({ Title = "Minigame 3 — Reel Balance", Box = true, BoxBorder = true, Opened = true })
    s4:Toggle({
        Title = "Auto Reel (Hold Slider)",
        Value = true,
        Callback = function(v) _G.AutoReel = v end,
    })
    s4:Space()
    s4:Slider({
        Title = "Hold Time", Step = 0.05,
        Value = { Min = 0.05, Max = 1, Default = 0.15 },
        Callback = function(v) _G.ReelHoldTime = v end,
    })

    local status = TabFish:Section({ Title = "Status", Box = true, BoxBorder = true, Opened = true })
    local statusTxt = status:Section({ Title = "Idle", TextSize = 14, TextTransparency = 0.2 })
    task.spawn(function()
        while _G.FISCH_RUNNING do
            task.wait(0.3)
            pcall(function()
                local rod = equippedRod()
                statusTxt:SetTitle(
                    "State: " .. fishState ..
                    "\nRod: " .. (rod and rod.Name or "none") ..
                    " | FPS: " .. curFPS
                )
            end)
        end
    end)
end

--============================================================
-- TAB: PLAYER
--============================================================
local TabPlayer = Window:Tab({
    Title = "Player", Desc = "Movement",
    Icon = "solar:user-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s = TabPlayer:Section({ Title = "Movement", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Speed Boost (32)", Value = false,
        Callback = function(v) _G.SpeedBoost = v end })
    s:Space()
    s:Toggle({ Title = "Fly (WASD)", Value = false,
        Callback = function(v) _G.Fly = v end })
    s:Space()
    s:Slider({ Title = "Fly Speed", Step = 5,
        Value = { Min = 10, Max = 300, Default = 50 },
        Callback = function(v) _G.FlySpeed = v end })
    s:Space()
    s:Toggle({ Title = "Anti-AFK", Value = true,
        Callback = function(v) _G.AntiAFK = v end })
end

--============================================================
-- TAB: VISUAL & EXTRA
--============================================================
local TabExtra = Window:Tab({
    Title = "Extra", Desc = "ESP, Sell",
    Icon = "solar:star-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local s = TabExtra:Section({ Title = "Visual", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "ESP Fish", Value = false,
        Callback = function(v) _G.ESP = v end })
    s:Space()
    s:Slider({ Title = "ESP Range", Step = 50,
        Value = { Min = 50, Max = 1000, Default = 300 },
        Callback = function(v) _G.ESPRange = v end })

    local s2 = TabExtra:Section({ Title = "Auto Sell", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Auto Sell All", Value = false,
        Callback = function(v) _G.AutoSell = v end })
end

--============================================================
-- NOTIF
--============================================================
WindUI:Notify({
    Title = "Pall Fisch v8.0.0",
    Content = "Auto Bobber + Shake + Reel. Equip rod dulu!",
    Icon = "solar:bell-bold",
    Duration = 8,
})

print("════════════════════════════════════════════")
print("[PALL-FISCH] v8.0.0 loaded.")
print("  3 minigame: Bobber timing + Shake tap + Reel hold")
print("════════════════════════════════════════════")
