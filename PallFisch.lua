--[[
    PALL — FISCH v6.1.0 (Debug + _G flags)
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RUN = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
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

--============================================================
-- GLOBAL FLAGS (dari NIGHT, proven works)
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
-- REMOTE RESOLVER
--============================================================
local function getNet()
    local pkg = RS:FindFirstChild("packages")
    return pkg and pkg:FindFirstChild("Net")
end

local function getEvt(name)
    local ev = RS:FindFirstChild("events")
    return ev and ev:FindFirstChild(name)
end

local function netRemote(name)
    local net = getNet()
    return net and net:FindFirstChild(name)
end

--============================================================
-- INSTANT CATCH
--============================================================
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

local function instantFish()
    local cast = netRemote("RF/FishingRod/Cast")
    local reelStart = netRemote("RF/Reel/Start")
    local reelFinish = netRemote("RE/Reel/Finish")

    if cast and reelStart and reelFinish then
        print("[FISH] Fire modern: cast → reelStart → reelFinish")
        tryCall(cast, 1)
        task.wait(0.05)
        tryCall(reelStart, 1)
        task.wait(0.05)
        tryCall(reelFinish, 100, true)
        return true, "modern"
    end

    local legacyCast = getEvt("rod_cast")
    local legacyReel = getEvt("reelfinished")
    if legacyCast and legacyReel then
        print("[FISH] Fire legacy: rod_cast → reelfinished")
        tryCall(legacyCast, 1)
        task.wait(0.05)
        tryCall(legacyReel, 100, true)
        return true, "legacy"
    end

    return false, "no remote"
end

local function sellAll()
    local s = getEvt("SellAll")
    if s then
        pcall(function() s:InvokeServer() end)
        return true
    end
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
LP.CharacterAdded:Connect(function() task.wait(0.8) refreshChar() end)

--============================================================
-- AUTO FISH LOOP (fixed)
--============================================================
local statusStr = "Idle"
local lastMethod = "-"
local fishCount = 0

task.spawn(function()
    while true do
        task.wait(0.5)
        if not _G.AutoFish then
            statusStr = "Idle (toggle OFF)"
            continue
        end
        statusStr = "Auto fish ON — calling remote..."
        local ok, msg = instantFish()
        if ok then
            fishCount = fishCount + 1
            statusStr = "✓ Catch #" .. fishCount .. " (" .. msg .. ")"
            lastMethod = msg
            print("[FISH] Catch success #" .. fishCount)
        else
            statusStr = "❌ " .. msg
            print("[FISH] Failed: " .. msg)
        end
    end
end)

--============================================================
-- AUTO SELL LOOP
--============================================================
task.spawn(function()
    while true do
        task.wait(2)
        if _G.AutoSell then
            if sellAll() then
                print("[FISH] SellAll called")
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
            flyConn:Disconnect(); flyConn = nil
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
Window:Tag({ Title = "v6.1.0 Debug", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

-- TAB: AUTO FISH
local TabFish = Window:Tab({
    Title = "Auto Fish", Desc = "Instant Catch",
    Icon = "solar:fish-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s = TabFish:Section({ Title = "Control", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({
        Title = "Auto Fish (Instant)",
        Value = false,
        Callback = function(v)
            _G.AutoFish = v
            print("[PALL-FISCH] AutoFish toggle = " .. tostring(v))
        end,
    })
    s:Space()
    s:Button({
        Title = "▶ Test Fire Remote Sekali",
        Justify = "Center",
        Callback = function()
            print("[PALL-FISCH] Manual test button clicked")
            local ok, msg = instantFish()
            print("[PALL-FISCH] Manual result:", ok, msg)
            WindUI:Notify({ Title = "Test", Content = ok and ("OK: " .. msg) or ("Gagal: " .. msg) })
        end,
    })

    local info = TabFish:Section({ Title = "Status", Box = true, BoxBorder = true, Opened = true })
    local statusTxt = info:Section({ Title = "Idle", TextSize = 14, TextTransparency = 0.2 })
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                statusTxt:SetTitle(statusStr .. "\nMethod: " .. lastMethod .. " | Catches: " .. fishCount .. " | FPS: " .. curFPS)
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
        Title = "Auto Sell All",
        Value = false,
        Callback = function(v)
            _G.AutoSell = v
            print("[PALL-FISCH] AutoSell = " .. tostring(v))
        end,
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
        Callback = function(v) _G.SpeedBoost = v; print("[PALL-FISCH] Speed = " .. tostring(v)) end })
    s:Space()
    s:Toggle({ Title = "Fly", Value = false,
        Callback = function(v) _G.Fly = v; updateFly(); print("[PALL-FISCH] Fly = " .. tostring(v)) end })
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
    Title = "Pall Fisch v6.1.0 Debug",
    Content = "Ada tombol 'Test Fire Remote Sekali'. Coba klik!",
    Icon = "solar:bell-bold",
    Duration = 10,
})

print("════════════════════════════════════════════")
print("[PALL-FISCH] v6.1.0 Debug loaded.")
print("[PALL-FISCH] Klik toggle Auto Fish → lihat console.")
print("[PALL-FISCH] Atau klik tombol 'Test Fire Remote Sekali'.")
print("════════════════════════════════════════════")
