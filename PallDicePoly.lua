--[[
    ═══════════════════════════════════════════════════════════
    PALL — DICE POLY v2.0.0 (Final Integration)
    Author  : ENI (for Pall)
    Credit  : NIGHT (InputBegan/Ended Logic)
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
    -- Main
    AutoPlay = false,
    AutoRoll = false,
    RollHoldTime = 1.0,
    AntiAFK = true,
    SmartPredict = false,
    PredictTarget = "EVEN",
    
    -- Ekonomi
    AutoBuy = false,
    AutoBuyAll = false,
    AutoSell = false,
    AutoBankLoan = false,
    BuyHoldTime = 0.25, -- Waktu tahan tombol beli (bisa diatur)
    
    -- State Internal
    isHolding = false,
    isActionBusy = false 
}

local SKIP_KEYWORDS = {"cancel", "skip", "no", "auction", "back", "spectate", "robux", "sell", "bank loan", "bankrupt"}
local BUY_KEYWORDS = {"buy", "purchase", "beli"}

--============================================================
-- INPUT LOGIC (JALAN NINJA DARI NIGHT)
--============================================================
local function holdClick(btn, duration)
    if not btn or not btn.Visible then return false end
    duration = duration or 0.25

    local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
    local x, y = pos.X, pos.Y

    -- 1. Virtual Input (Fisik)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
    end)

    -- 2. InputBegan (Sistem Game)
    pcall(function()
        local inputDown = Instance.new("InputObject")
        inputDown.UserInputType = Enum.UserInputType.MouseButton1
        inputDown.UserInputState = Enum.UserInputState.Begin
        btn:FireInputBegan(inputDown)
    end)

    -- 3. GetConnections (Paksa)
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(btn.MouseButton1Down)) do c:Fire() end
        end
    end)

    task.wait(duration)

    -- 4. Lepas Fisik
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)

    -- 5. InputEnded (Sistem Game)
    pcall(function()
        local inputUp = Instance.new("InputObject")
        inputUp.UserInputType = Enum.UserInputType.MouseButton1
        inputUp.UserInputState = Enum.UserInputState.End
        btn:FireInputEnded(inputUp)
    end)

    -- 6. Lepas Connections
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(btn.MouseButton1Up)) do c:Fire() end
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
        end
    end)

    print("[DICE] Hold & Release: '" .. btn.Text .. "' (" .. duration .. "s)")
    return true
end

-- Fungsi Klik Biasa (Buat Play/Even/Odd)
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
        if getconnections then
            for _, c in ipairs(getconnections(el.MouseButton1Click)) do c:Fire() end
        end
    end)
    return true
end

--============================================================
-- FINDERS & DETEKSI
--============================================================
local function isBuyButton(btn)
    local t = btn.Text:lower()
    for _, skip in ipairs(SKIP_KEYWORDS) do
        if t:find(skip, 1, true) then return false end
    end
    for _, kw in ipairs(BUY_KEYWORDS) do
        if t:find(kw, 1, true) then return true end
    end
    return false
end

local function findBuyButton(root)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextButton") and obj.Visible and obj.Active then
            if isBuyButton(obj) then return obj end
        end
    end
    return nil
end

local function isNearlyBankrupt()
    local gameUI = PG:FindFirstChild("GameUI")
    if not gameUI then return false end
    for _, obj in ipairs(gameUI:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local t = obj.Text:lower()
            if t:find("nearly bankrupt") or t:find("bankrupt") then return true end
        end
    end
    return false
end

local function findButtonByText(root, targetText)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextButton") and obj.Visible then
            if obj.Text:lower():find(targetText:lower()) then return obj end
        end
    end
    return nil
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
    local gameUI = PG:FindFirstChild("GameUI")
    local root = gameUI or PG
    return findButtonByText(root, "play")
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
        Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#FFD93D"), Color3.fromHex("#FF8A3D")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})
Window:Tag({ Title = "v2.0.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB 1: MAIN (ROLL & PREDICT)
--============================================================
local TabMain = Window:Tab({ Title = "Main", Desc = "Auto Roll & Play", Icon = "solar:home-2-bold", IconColor = Green, IconShape = "Square", Border = true })
do
    local s1 = TabMain:Section({ Title = "Lobby", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Play (Masuk Game)", Value = false, Callback = function(v) State.AutoPlay = v end })
    
    local s2 = TabMain:Section({ Title = "In-Game & Predict", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Auto Roll (Hold & Release)", Value = false, Callback = function(v) State.AutoRoll = v end })
    s2:Space()
    s2:Slider({ Title = "Waktu Tahan Roll (detik)", Step = 0.1, Value = { Min = 0.2, Max = 3, Default = 1.0 }, Callback = function(v) State.RollHoldTime = v end })
    s2:Space()
    s2:Section({ Title = "Smart Predict", TextSize = 13, TextTransparency = 0.3 })
    s2:Toggle({ Title = "Aktifkan Smart Predict", Value = false, Callback = function(v) State.SmartPredict = v end })
    s2:Space()
    s2:Dropdown({ Title = "Target Dadu", Values = { "EVEN", "ODD" }, Value = "EVEN", Callback = function(v) State.PredictTarget = v end })
end

--============================================================
-- TAB 2: EKONOMI (FITUR AUTO BUY & SELL)
--============================================================
local TabEco = Window:Tab({ Title = "Economy", Desc = "Auto Buy & Bankrupt", Icon = "solar:wallet-money-bold", IconColor = Yellow, IconShape = "Square", Border = true })
do
    local s1 = TabEco:Section({ Title = "Auto Buy Land", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Buy Tanah", Value = false, Callback = function(v) State.AutoBuy = v end })
    s1:Space()
    s1:Toggle({ Title = "Auto Buy All (DevPanel)", Value = false, Callback = function(v) State.AutoBuyAll = v end })
    s1:Space()
    s1:Slider({ Title = "Waktu Tahan Beli (detik)", Step = 0.05, Value = { Min = 0.1, Max = 1.0, Default = 0.25 }, Callback = function(v) State.BuyHoldTime = v end })
    
    local s2 = TabEco:Section({ Title = "Bankrupt Protection", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Auto Bank Loan", Desc = "Pinjam uang saat mau bangkrut", Value = false, Callback = function(v) State.AutoBankLoan = v end })
    s2:Space()
    s2:Toggle({ Title = "Auto Sell", Desc = "Jual aset saat mau bangkrut", Value = false, Callback = function(v) State.AutoSell = v end })
end

--============================================================
-- AUTO LOOPS
--============================================================

-- 1. Anti AFK
task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(60)
        if State.AntiAFK then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end) end
    end
end)

-- 2. Auto Play
task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(1)
        if not State.AutoPlay then continue end
        local btn = findPlayButton()
        if btn then tapElement(btn) end
    end
end)

-- 3. Auto Bank Loan & Auto Sell
task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(0.5)
        if not State.AutoSell and not State.AutoBankLoan then continue end
        
        local gameUI = PG:FindFirstChild("GameUI")
        if not gameUI then continue end
        if not isNearlyBankrupt() then continue end
        
        if State.AutoBankLoan then
            local loanBtn = findButtonByText(gameUI, "bank loan")
            if loanBtn then
                print("[DICE] Nearly Bankrupt! Ambil Bank Loan.")
                tapElement(loanBtn)
                task.wait(1)
                continue
            end
        end
        
        if State.AutoSell then
            local autoSellBtn = findButtonByText(gameUI, "auto sell")
            if autoSellBtn then
                print("[DICE] Nearly Bankrupt! Auto Sell.")
                tapElement(autoSellBtn)
                task.wait(1)
                continue
            end
        end
    end
end)

-- 4. Auto Sell Confirm
task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(0.5)
        if not State.AutoSell then continue end
        
        local gameUI = PG:FindFirstChild("GameUI")
        if not gameUI then continue end
        
        local sellConfirm = gameUI:FindFirstChild("SellConfirm")
        if sellConfirm and sellConfirm.Visible then
            for _, btn in ipairs(sellConfirm:GetDescendants()) do
                if btn:IsA("TextButton") and btn.Visible then
                    local t = btn.Text:lower()
                    if t:find("cancel") then continue end
                    if t:find("sell") or t:find("confirm") or t:find("ok") or t:find("yes") then
                        tapElement(btn)
                        task.wait(0.5)
                        break
                    end
                end
            end
        end
    end
end)

-- 5. Auto Buy Land (PAKAI HOLD CLICK NIGHT)
task.spawn(function()
    local lastBuy = 0
    while _G.PALL_DICE_RUNNING do
        task.wait(0.25)
        if not State.AutoBuy and not State.AutoBuyAll then continue end
        if State.isActionBusy or State.isHolding then continue end
        
        local gameUI = PG:FindFirstChild("GameUI")
        if not gameUI then continue end

        local now = tick()
        if now - lastBuy < 0.8 then continue end

        -- Prioritas 1: Buy All
        if State.AutoBuyAll then
            local devPanel = gameUI:FindFirstChild("DevPanel")
            if devPanel and devPanel.Visible then
                local buyAllBtn = findButtonByText(devPanel, "buy all")
                if buyAllBtn then
                    lastBuy = now
                    State.isActionBusy = true
                    holdClick(buyAllBtn, State.BuyHoldTime)
                    task.wait(0.5)
                    State.isActionBusy = false
                    continue
                end
            end
        end

        -- Prioritas 2: Buy Biasa
        if State.AutoBuy then
            local buyBtn = findBuyButton(gameUI)
            if buyBtn then
                lastBuy = now
                State.isActionBusy = true
                holdClick(buyBtn, State.BuyHoldTime)
                task.wait(0.5)
                State.isActionBusy = false
            end
        end
    end
end)

-- 6. Auto Roll Utama
task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(0.5)
        if not State.AutoRoll or State.isHolding or State.isActionBusy then continue end
        
        local rollBtn = findRollButton()
        if rollBtn then
            State.isActionBusy = true
            
            if State.SmartPredict then
                local predictBtn = findPredictButton(State.PredictTarget)
                if predictBtn then tapElement(predictBtn); task.wait(1.5) end
            end
            
            print("[DICE] Nahan ROLL...")
            holdClick(rollBtn, State.RollHoldTime)
            task.wait(3.5)
            
            State.isActionBusy = false
            task.wait(1)
        end
    end
end)

WindUI:Notify({ Title = "Pall Dice v2.0.0", Content = "InputBegan Logic Merged! Auto Buy Mantap.", Icon = "solar:bell-bold", Duration = 6 })
print("[PALL-DICE] v2.0.0 loaded. Auto Buy Hold & Release active.")
