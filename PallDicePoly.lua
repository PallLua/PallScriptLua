--[[
    ═══════════════════════════════════════════════════════════
    PALL — DICE POLY v1.4.0 (Blind Auto Buy)
    Author  : ENI (for Pall)
    ═══════════════════════════════════════════════════════════
--]]

print("[PALL-DICE] Memulai eksekusi script...")

local Players = game:GetService("Players")
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
local Blue   = Color3.fromHex("#257AF7")

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
    RollHoldTime = 1.0,
    AntiAFK = true,
    SmartPredict = false,
    PredictTarget = "EVEN",
    
    -- Fitur Ekonomi
    AutoBuyLand = false,
    AutoBail = false,
    
    -- State internal buat ngunci biar gak tabrakan
    isHolding = false,
    isActionBusy = false 
}

local CodesList = {
    "1000PLAYER", "AMSSRBLHGSHARKAM", "200CCU",
    "RPRXDICEOPOLY", "5CHEST", "WHENYAH", "250LIKESRESTOCKUGC"
}

--============================================================
-- UTILITY
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

local function forceReleaseSafe(el)
    if not el then return end
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(el.MouseButton1Up)) do c:Fire() end
            for _, c in ipairs(getconnections(el.MouseButton1Click)) do c:Fire() end
        end
        local cx = el.AbsolutePosition.X + (el.AbsoluteSize.X / 2)
        local cy = el.AbsolutePosition.Y + (el.AbsoluteSize.Y / 2)
        VirtualInputManager:SendMouseButtonEvent(cx + 50, cy + 50, 0, false, game, 0)
    end)
    State.isHolding = false
end

local function holdElement(el, duration)
    if not el or not el.Visible then return false end
    State.isHolding = true
    
    local pos = el.AbsolutePosition
    local size = el.AbsoluteSize
    local cx = pos.X + (size.X / 2)
    local cy = pos.Y + (size.Y / 2)
    
    pcall(function() VirtualInputManager:SendMouseMoveEvent(cx, cy, game) end)
    task.wait(0.05)
    
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        if getconnections then
            for _, c in ipairs(getconnections(el.MouseButton1Down)) do c:Fire() end
        end
    end)
    
    task.wait(duration)
    forceReleaseSafe(el)
    return true
end

--============================================================
-- PENCARI TOMBOL (BLIND MODE)
--============================================================
-- Cari tombol Beli (Ngecek teks di tombol & di dalam tombol)
local function findBuyButton()
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, obj in ipairs(gui:GetDescendants()) do
                if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                    local text = ""
                    pcall(function() text = obj.Text end)
                    local ut = text:upper()
                    
                    if ut:find("BUY") or ut:find("BELI") or ut:find("PURCHASE") then
                        return obj
                    end
                    
                    -- Cek teks di dalam tombol (TextLabel)
                    for _, child in ipairs(obj:GetChildren()) do
                        if child:IsA("TextLabel") and child.Visible then
                            local ctext = child.Text
                            local cut = ctext:upper()
                            if cut:find("BUY") or cut:find("BELI") or cut:find("PURCHASE") then
                                return obj
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function findBailButton()
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, obj in ipairs(gui:GetDescendants()) do
                if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                    local text = ""
                    pcall(function() text = obj.Text end)
                    local ut = text:upper()
                    
                    if ut:find("BAIL") or ut:find("PAY") or ut:find("BAYAR") or ut:find("BEBAS") then
                        return obj
                    end
                    
                    for _, child in ipairs(obj:GetChildren()) do
                        if child:IsA("TextLabel") and child.Visible then
                            local ctext = child.Text
                            local cut = ctext:upper()
                            if cut:find("BAIL") or cut:find("PAY") or cut:find("BAYAR") then
                                return obj
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

--============================================================
-- AUTO REDEEM & FINDERS (SAMA SEPERTI SEBELUMNYA)
--============================================================
local function redeemViaGUI()
    local successCount = 0
    local guiFound = false
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("TextBox") then
                    guiFound = true
                    for _, code in ipairs(CodesList) do
                        obj.Text = code
                        task.wait(0.1)
                        local parent = obj.Parent
                        local btn = parent:FindFirstChild("Redeem", true) or parent:FindFirstChild("Claim", true) or parent:FindFirstChild("Submit", true)
                        if btn then
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
        WindUI:Notify({ Title = "Redeem", Content = "Buka menu Codes di game dulu!" })
    else
        WindUI:Notify({ Title = "Redeem", Content = "Mencoba " .. successCount .. " kode." })
    end
end

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
Window:Tag({ Title = "v1.4.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: MAIN
--============================================================
local TabMain = Window:Tab({
    Title = "Main", Desc = "Auto Roll & Play",
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
        Title = "Waktu Tahan (detik)", Step = 0.1,
        Value = { Min = 0.2, Max = 3, Default = 1.0 },
        Callback = function(v) State.RollHoldTime = v end,
    })
    s2:Space()
    s2:Button({
        Title = "⚠️ Force Release (Darurat)",
        Justify = "Center",
        Color = Red,
        Callback = function()
            local btn = findRollButton()
            if btn then
                forceReleaseSafe(btn)
                WindUI:Notify({ Title = "Force Release", Content = "Tombol dipaksa lepas." })
            end
        end,
    })
    
    s2:Space()
    s2:Section({ Title = "Smart Predict", TextSize = 13, TextTransparency = 0.3 })
    s2:Toggle({
        Title = "Aktifkan Smart Predict",
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
end

--============================================================
-- TAB: AUTO ECONOMY (BUY & BAIL)
--============================================================
local TabEco = Window:Tab({
    Title = "Economy", Desc = "Auto Buy & Bail",
    Icon = "solar:wallet-money-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s1 = TabEco:Section({ Title = "Auto Buy Land", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({
        Title = "Auto Buy Tanah (Blind Mode)",
        Desc = "Langsung beli tanpa cek harga",
        Value = false,
        Callback = function(v) State.AutoBuyLand = v end,
    })
    
    local s2 = TabEco:Section({ Title = "Auto Bail (Penjara)", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({
        Title = "Auto Bayar Bail",
        Value = false,
        Callback = function(v) State.AutoBail = v end,
    })
end

--============================================================
-- TAB: CODES
--============================================================
local TabCodes = Window:Tab({
    Title = "Codes", Desc = "Auto Redeem",
    Icon = "solar:ticket-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s = TabCodes:Section({ Title = "Redeem Codes", Box = true, BoxBorder = true, Opened = true })
    s:Button({
        Title = "Redeem via GUI",
        Justify = "Center",
        Callback = function() redeemViaGUI() end,
    })
end

--============================================================
-- AUTO LOOPS (EKSEKUSI)
--============================================================

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

task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(1)
        if not State.AutoPlay then continue end
        local btn = findPlayButton()
        if btn then tapElement(btn) end
    end
end)

-- 3. Auto Bail
task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(1)
        if not State.AutoBail or State.isActionBusy then continue end
        
        local bailBtn = findBailButton()
        if bailBtn then
            State.isActionBusy = true
            print("[DICE] Masuk Penjara! Mencoba bayar Bail...")
            tapElement(bailBtn)
            task.wait(2)
            State.isActionBusy = false
        end
    end
end)

-- 4. Auto Buy Land (BLIND MODE)
task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(0.5)
        if not State.AutoBuyLand or State.isActionBusy or State.isHolding then continue end
        
        local buyBtn = findBuyButton()
        if buyBtn then
            State.isActionBusy = true
            print("[DICE] Auto Buy: Tombol beli terdeteksi! Langsung eksekusi.")
            tapElement(buyBtn)
            task.wait(1.5) -- Jeda animasi
            State.isActionBusy = false
        end
    end
end)

-- 5. Auto Roll Utama
task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(0.5)
        if not State.AutoRoll or State.isHolding or State.isActionBusy then continue end
        
        local rollBtn = findRollButton()
        if rollBtn then
            State.isActionBusy = true
            
            if State.SmartPredict then
                local predictBtn = findPredictButton(State.PredictTarget)
                if predictBtn then
                    print("[DICE] Predict: " .. State.PredictTarget)
                    tapElement(predictBtn)
                    task.wait(1.5) 
                end
            end
            
            print("[DICE] Nahan ROLL...")
            holdElement(rollBtn, State.RollHoldTime)
            
            task.wait(3.5)
            forceReleaseSafe(rollBtn)
            
            print("[DICE] Selesai satu putaran.")
            State.isActionBusy = false
            task.wait(1)
        end
    end
end)

WindUI:Notify({
    Title = "Pall Dice v1.4.0",
    Content = "Auto Buy Blind Mode Active!",
    Icon = "solar:bell-bold",
    Duration = 6,
})

print("[PALL-DICE] v1.4.0 loaded.")
