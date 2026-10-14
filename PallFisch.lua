--[[
    PALL — FISCH v6.3.0
    Fix: Auto Tap Reel Bar (client-side) + ReelFinish remote
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RUN = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VU = game:GetService("VirtualUser")
local VIM = game:GetService("VirtualInputManager")

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

--============================================================
-- GLOBAL FLAGS
--============================================================
_G.AutoFish = false
_G.AutoSell = false
_G.AntiAFK = true
_G.SpeedBoost = false
_G.Fly = false
_G.FlySpeed = 50
_G.ESP = false
_G.ESPRange = 300

--============================================================
-- TAP HELPER
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

--============================================================
-- REMOTE RESOLVER
--============================================================
local function getNet()
    local pkg = RS:FindFirstChild("packages")
    if not pkg then return nil end
    return pkg:FindFirstChild("Net")
end

local function getEvt(name)
    local ev = RS:FindFirstChild("events")
    if not ev then return nil end
    return ev:FindFirstChild(name)
end

local function netRemote(name)
    local net = getNet()
    if not net then return nil end
    return net:FindFirstChild(name)
end

local function tryCall(remote, ...)
    if not remote then return false end
    local args = {...}
    local ok = pcall(function()
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer(table.unpack(args))
        elseif remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args))
        end
    end)
    return ok
end

--============================================================
-- REEL BAR DETECTION
--============================================================
local function findReelBar()
    local reel = PG:FindFirstChild("reel")
    if not reel then return nil end
    if not reel.Visible then return nil end
    local bar = reel:FindFirstChild("bar")
    return bar
end

local function findHandle()
    local reel = PG:FindFirstChild("reel")
    if not reel then return nil end
    return reel:FindFirstChild("Handle", true)
end

--============================================================
-- INSTANT FISH (fixed)
--============================================================
local function castOnly()
    local cast = netRemote("RF/FishingRod/Cast")
    if cast then
        return tryCall(cast, 1)
    end
    local legacy = getEvt("rod_cast")
    if legacy then
        return tryCall(legacy, 1)
    end
    return false
end

local function reelStart()
    local rs = netRemote("RF/Reel/Start")
    if rs then return tryCall(rs, 1) end
    return false
end

local function reelFinish()
    local rf = netRemote("RE/Reel/Finish")
    if rf then return tryCall(rf, 100, true) end
    local legacy = getEvt("reelfinished")
    if legacy then return tryCall(legacy, 100, true) end
    return false
end

--============================================================
-- CHAR REF
--============================================================
local char, hrp, hum
local function refreshChar()
    char = LP.Character or LP.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart", 5)
    hum = char:WaitForChild("Humanoid", 5)
end
refreshChar()
LP.CharacterAdded:Connect(function()
    task.wait(0.8)
    refreshChar()
end)

--============================================================
-- STATUS
--============================================================
local statusStr = "Idle"
local curFPS = 0
local fishCount = 0
local fishPhase = "idle"

--============================================================
-- AUTO FISH LOOP (v2 — fix minigame)
--============================================================
task.spawn(function()
    local lastCast = 0
    while true do
        task.wait(0.1)

        if not _G.AutoFish then
            statusStr = "Idle (toggle OFF)"
            fishPhase = "idle"
            continue
        end

        -- 1. Cek apakah minigame bar muncul
        local bar = findReelBar()
        if bar then
            -- Sedang di minigame — tap bar terus buat isi progress
            fishPhase = "minigame"
            statusStr = "🎯 Isi bar (tap)"
            local pos = bar.AbsolutePosition
            local size = bar.AbsoluteSize
            local cx = pos.X + size.X / 2
            local cy = pos.Y + size.Y / 2

            -- Tap + drag handle dikit biar progress jalan
            holdAt(cx, cy, 0.1)
            task.wait(0.05)

            -- Kalau handle udah di atas 70%, finish
            local handle = findHandle()
            if handle and bar then
                local hcx = handle.AbsolutePosition.X + handle.AbsoluteSize.X / 2
                local bx = bar.AbsolutePosition.X
                local bw = bar.AbsoluteSize.X
                local prog = (hcx - bx) / bw
                if prog >= 0.7 then
                    reelFinish()
                    fishCount = fishCount + 1
                    statusStr = "✓ Catch #" .. fishCount
                    task.wait(0.5)
                end
            end
        else
            -- Nggak ada bar — cast
            local now = tick()
            if now - lastCast >= 2 then
                fishPhase = "casting"
                statusStr = "🎣 Cast..."
                castOnly()
                lastCast = now
                task.wait(0.5)
                -- Mulai minigame (server)
                reelStart()
            end
        end
    end
end)

--============================================================
-- AUTO SELL
--============================================================
task.spawn(function()
    while true do
        task.wait(3)
        if _G.AutoSell then
            local s = getEvt("SellAll")
            if s then
                pcall(function() s:InvokeServer() end)
                print("[FISH] SellAll fired")
            end
        end
    end
end)

--============================================================
-- ANTI-AFK
--============================================================
task.spawn(function()
    while task.wait(60) do
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
    while task.wait(0.5) do
        if not hum then continue end
        if _G.SpeedBoost then
            hum.WalkSpeed = 32
        elseif hum.WalkSpeed == 32 then
            hum.WalkSpeed = 16
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
        if hum then hum.PlatformStand = false end
        return
    end
    if hum then hum.PlatformStand = true end

    flyConn = RUN.RenderStepped:Connect(function()
        if not _G.Fly then
            if hum then hum.PlatformStand = false end
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
        if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then
            move = move + Vector3.new(0, 1, 0)
        end
        if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
            move = move - Vector3.new(0, 1, 0)
        end
        if move.Magnitude > 0.01 then move = move.Unit * spd end
        pcall(function()
            hrp.Velocity = move
            hrp.AssemblyLinearVelocity = move
        end)
    end)
end

--============================================================
-- ESP
--============================================================
local espBills = {}
local function clearESP()
    for _, b in ipairs(espBills) do pcall(function() b:Destroy() end) end
    espBills = {}
end

local function mkBill(adornee, text, color)
    if not adornee then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(140, 28)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
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
end

task.spawn(function()
    while task.wait(2) do
        if not _G.ESP then clearESP() continue end
        clearESP()
        if not hrp then continue end
        local roots = {}
        for _, name in ipairs({ "active", "world", "Fishing", "fish", "Fish" }) do
            local f = WS:FindFirstChild(name)
            if f then table.insert(roots, f) end
        end
        for _, root in ipairs(roots) do
            for _, obj in ipairs(root:GetChildren()) do
                if not hrp then break end
                local pos
                if obj:IsA("BasePart") then pos = obj.Position
                elseif obj:IsA("Model") then
                    local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                    if p then pos = p.Position end
                end
                if not pos then continue end
                if (pos - hrp.Position).Magnitude > _G.ESPRange then continue end
                if obj.Name:lower():find("fish") then
                    local adornee = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")) or obj
                    mkBill(adornee, "🐟 " .. obj.Name, Color3.fromRGB(100, 200, 255))
                end
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

local frames, lastTime = 0, tick()
RUN.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastTime >= 1 then
        curFPS = frames
        fpsLabel.Text = "FPS: " .. curFPS
        frames = 0
        lastTime = tick()
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
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#3DC9FF"), Color3.fromHex("#10C550")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})
Window:Tag({ Title = "v6.3.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

-- TAB: AUTO FISH
local TabFish = Window:Tab({
    Title = "Auto Fish", Desc = "Cast + Minigame + Finish",
    Icon = "solar:fish-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s = TabFish:Section({ Title = "Control", Box = true, BoxBorder = true, Opened = true })

    s:Toggle({
        Title = "Auto Fish",
        Value = false,
        Callback = function(v)
            _G.AutoFish = v
            print("[PALL-FISCH] AutoFish = " .. tostring(v))
        end,
    })

    s:Space()

    s:Button({
        Title = "▶ Test Fire Sekali",
        Justify = "Center",
        Callback = function()
            print("[PALL-FISCH] Test cast + reelStart + reelFinish")
            castOnly()
            task.wait(0.3)
            reelStart()
            task.wait(0.3)
            reelFinish()
            print("[PALL-FISCH] Test done")
        end,
    })

    local info = TabFish:Section({ Title = "Status", Box = true, BoxBorder = true, Opened = true })
    local statusTxt = info:Section({ Title = "Idle", TextSize = 14, TextTransparency = 0.2 })
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                statusTxt:SetTitle(statusStr .. "\nPhase: " .. fishPhase .. " | Catches: " .. fishCount .. " | FPS: " .. curFPS)
            end)
        end
    end)
end

-- TAB: AUTO SELL
local TabSell = Window:Tab({
    Title = "Auto Sell", Desc = "SellAll",
    Icon = "solar:cart-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s = TabSell:Section({ Title = "Control", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({
        Title = "Auto Sell All", Value = false,
        Callback = function(v) _G.AutoSell = v end,
    })
end

-- TAB: PLAYER
local TabPlayer = Window:Tab({
    Title = "Player", Desc = "Movement",
    Icon = "solar:user-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s = TabPlayer:Section({ Title = "Movement", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Speed Boost (32)", Value = false,
        Callback = function(v) _G.SpeedBoost = v end })
    s:Space()
    s:Toggle({ Title = "Fly", Value = false,
        Callback = function(v) _G.Fly = v; updateFly() end })
    s:Space()
    s:Slider({ Title = "Fly Speed", Step = 5,
        Value = { Min = 10, Max = 300, Default = 50 },
        Callback = function(v) _G.FlySpeed = v end })
    s:Space()
    s:Toggle({ Title = "Anti-AFK", Value = true,
        Callback = function(v) _G.AntiAFK = v end })
end

-- TAB: VISUAL
local TabVisual = Window:Tab({
    Title = "Visual", Desc = "ESP",
    Icon = "solar:eye-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local s = TabVisual:Section({ Title = "ESP", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "ESP Fish", Value = false,
        Callback = function(v) _G.ESP = v end })
    s:Space()
    s:Slider({ Title = "ESP Range", Step = 50,
        Value = { Min = 50, Max = 1000, Default = 300 },
        Callback = function(v) _G.ESPRange = v end })
end

WindUI:Notify({
    Title = "Pall Fisch v6.3.0",
    Content = "Fix: auto tap minigame bar.",
    Icon = "solar:bell-bold",
    Duration = 8,
})

print("[PALL-FISCH] v6.3.0 loaded. Auto tap bar aktif.")
