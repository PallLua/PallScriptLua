--[[
    ═══════════════════════════════════════════════════════════
    PALL — DICE POLY v0.8.0 (Ultimate Fix)
    Author  : ENI (for Pall)
    ═══════════════════════════════════════════════════════════
--]]

print("[PALL-DICE] Memulai eksekusi script...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

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
    if not ok then error("[PALL-DICE] Gagal load WindUI.") end
    WindUI = _G.PallWindUI or result
end

local Green = Color3.fromHex("#10C550")
local Yellow = Color3.fromHex("#ECA201")
local Red    = Color3.fromHex("#EF4F1D")

--============================================================
-- FLAGS & STATE
--============================================================
if _G.PALL_DICE_RUNNING then
    _G.PALL_DICE_RUNNING = false
    task.wait(0.5)
end
_G.PALL_DICE_RUNNING = true

local State = {
    AutoRoll = false,
    AutoPlay = false,
    RollHoldTime = 1.5,
    AntiAFK = true,
    SmartPredict = false,
    PredictTarget = "EVEN"
}

local CodesList = {
    "1000PLAYER", "AMSSRBLHGSHARKAM", "200CCU",
    "RPRXDICEOPOLY", "5CHEST", "WHENYAH", "250LIKESRESTOCKUGC"
}

--============================================================
-- UTILITY (KLIK & HOLD PAKAI GETCONNECTIONS)
--============================================================
local function tapElement(el)
    if not el or not el.Visible then return false end
    local pos = el.AbsolutePosition
    local size = el.AbsoluteSize
    local cx = pos.X + (size.X / 2)
    local cy = pos.Y + (size.Y / 2)
    
    pcall(function()
        VirtualInputManager:SendMouseMoveEvent(cx, cy, game)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
    return true
end

local function holdElement(el, duration)
    if not el or not el.Visible then return false end
    local success = false
    
    -- METODE UTAMA: GetConnections (Nembak event langsung)
    pcall(function()
        if getconnections then
            local downConns = getconnections(el.MouseButton1Down)
            local upConns = getconnections(el.MouseButton1Up)
            
            if #downConns > 0 then
                print("[DICE] Nahan tombol (Down Event)...")
                for _, c in ipairs(downConns) do c:Fire() end
                task.wait(duration)
                
                if #upConns > 0 then
                    print("[DICE] Lepas tombol (Up Event)...")
                    for _, c in ipairs(upConns) do c:Fire() end
                else
                    -- Fallback kalau up event nggak ada, pake click
                    local clickConns = getconnections(el.MouseButton1Click)
                    for _, c in ipairs(clickConns) do c:Fire() end
                end
                success = true
            end
        end
    end)

    -- METODE 2: VirtualInputManager (Fallback)
    if not success then
        local pos = el.AbsolutePosition
        local size = el.AbsoluteSize
        local cx = pos.X + (size.X / 2)
        local cy = pos.Y + (size.Y / 2)
        
        pcall(function()
            VirtualInputManager:SendMouseMoveEvent(cx, cy, game)
            task.wait(0.1)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            task.wait(duration)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
        end)
    end
    return true
end

--============================================================
-- AUTO REDEEM (GUI BASED)
--============================================================
local function redeemViaGUI()
    local successCount = 0
    local guiFound = false
    
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("TextBox") then
                    guiFound = true
                    print("[DICE] Nemu TextBox kode: " .. obj.Name)
                    
                    for _, code in ipairs(CodesList) do
                        obj.Text = code
                        task.wait(0.1)
                        
                        local parent = obj.Parent
                        local btn = parent:FindFirstChild("Redeem", true) or parent:FindFirstChild("Claim", true) or parent:FindFirstChild("Submit", true)
                        
                        if btn and (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
                            tapElement(btn)
                            successCount = successCount + 1
                        else
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                        end
                        task.wait(1.5)
                    end
                end
            end
        end
    end
    
    if not guiFound then
        WindUI:Notify({ Title = "Redeem", Content = "Buka menu Codes di game dulu, baru klik ini!" })
    else
        WindUI:Notify({ Title = "Redeem", Content = "Mencoba " .. successCount .. " kode via GUI." })
    end
end

--============================================================
-- GUI FINDERS
--============================================================
local function findRollButton()
    local gameUI = PG:FindFirstChild("GameUI")
    if not gameUI then return nil end
    local rollGauge = gameUI:FindFirstChild("RollGauge")
    if not rollGauge then return nil end
    
    local btn = rollGauge:FindFirstChild("RollButton", true)
    if btn and btn.Visible then return btn end
    return nil
end

local function findPlayButton()
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, obj in ipairs(gui:GetDescendants()) do
                if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                    local txt = ""
                    pcall(function() txt = obj.Text:upper() end)
                    if txt == "PLAY" then return obj end
                end
            end
        end
    end
    return nil
end

local function findPredictButton(targetStr)
    local gameUI = PG:FindFirstChild("GameUI")
    if not gameUI then return nil end
    local rollGauge = gameUI:FindFirstChild("RollGauge")
    if not rollGauge then return nil end
    
    -- Cari tombol ODD atau EVEN di dalam gauge
    for _, obj in ipairs(rollGauge:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
            local txt = ""
            pcall(function() txt = obj.Text:upper() end)
            if txt:find(targetStr) then return obj end
        end
    end
    return nil
end

--============================================================
-- WINDOW UI
--============================================================
print("[PALL-DICE] Membuat Window UI...")
local Window = WindUI:CreateWindow({
    Title = "Pall x Dice Poly",
    Folder = "palldice",
    Icon = "solar:dice-bold",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open Pall Dice",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#FFD93D"), Color3.fromHex("#FF8A3D")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})
Window:Tag({ Title = "v0.8.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: MAIN
--============================================================
local TabMain = Window:Tab({
    Title = "Main", Desc = "Auto Play & Roll",
    Icon = "solar:home-2-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s1 = TabMain:Section({ Title = "Lobby", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({
        Title = "Auto Play (Masuk Game)",
        Value = false,
        Callback = function(v) State.AutoPlay = v end,
    })
    
    local s2 = TabMain:Section({ Title = "In-Game & Predict", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({
        Title = "Auto Roll (Hold & Release)",
        Value = false,
        Callback = function(v) State.AutoRoll = v end,
    })
    s2:Space()
    s2:Slider({
        Title = "Hold Duration (detik)", Step = 0.1,
        Value = { Min = 0.5, Max = 3, Default = 1.5 },
        Callback = function(v) State.RollHoldTime = v end,
    })
    
    s2:Space()
    s2:Section({ Title = "Smart Predict (Anti Landmark Musuh)", TextSize = 13, TextTransparency = 0.3 })
    
    s2:Toggle({
        Title = "Aktifkan Smart Predict",
        Desc = "Otomatis ngeklik tombol ODD/EVEN sebelum roll",
        Value = false,
        Callback = function(v) State.SmartPredict = v end,
    })
    s2:Space()
    s2:Dropdown({
        Title = "Target Dadu",
        Values = { "EVEN", "ODD" },
        Value = "EVEN",
        Callback = function(v) State.PredictTarget = v end,
    })
    
    s2:Space()
    s2:Toggle({ Title = "Anti-AFK", Value = true, Callback = function(v) State.AntiAFK = v end })
end

--============================================================
-- TAB: CODES
--============================================================
local TabCodes = Window:Tab({
    Title = "Codes", Desc = "Auto Redeem",
    Icon = "solar:ticket-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s = TabCodes:Section({ Title = "Redeem Codes (GUI Mode)", Box = true, BoxBorder = true, Opened = true })
    s:Section({
        Title = "Buka menu Codes di game dulu, baru klik tombol ini.",
        TextSize = 12, TextTransparency = 0.2,
    })
    s:Space()
    s:Button({
        Title = "Redeem via GUI",
        Justify = "Center",
        Callback = function() redeemViaGUI() end,
    })
end

--============================================================
-- AUTO LOOPS
--============================================================
task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(1)
        if not State.AutoPlay then continue end
        local btn = findPlayButton()
        if btn then tapElement(btn) end
    end
end)

task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(1)
        if not State.AutoRoll then continue end
        
        -- Smart Predict Logic
        if State.SmartPredict then
            local predictBtn = findPredictButton(State.PredictTarget)
            if predictBtn then
                print("[DICE] Smart Predict: Ngeklik " .. State.PredictTarget .. "...")
                tapElement(predictBtn)
                task.wait(0.8) -- Jeda sebelum roll
            end
        end
        
        local rollBtn = findRollButton()
        if rollBtn then
            print("[DICE] Nahan tombol ROLL...")
            holdElement(rollBtn, State.RollHoldTime)
            task.wait(3) -- Jeda nunggu hasil dadu
        end
    end
end)

task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(60)
        if State.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end
end)

WindUI:Notify({
    Title = "Pall Dice v0.8.0",
    Content = "Auto Roll Fixed with GetConnections!",
    Icon = "solar:bell-bold",
    Duration = 6,
})

print("[PALL-DICE] v0.8.0 loaded.")
