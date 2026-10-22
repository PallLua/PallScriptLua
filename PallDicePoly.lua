--[[
    ═══════════════════════════════════════════════════════════
    PALL — DICE POLY v0.5.1 (Clean & Lean)
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
local Grey = Color3.fromHex("#83889E")
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
    RollHoldTime = 0.3,
    AntiAFK = true,
}

local CodesList = {
    "1000PLAYER", "AMSSRBLHGSHARKAM", "200CCU",
    "RPRXDICEOPOLY", "5CHEST", "WHENYAH", "250LIKESRESTOCKUGC"
}

--============================================================
-- UTILITY
--============================================================
local function tapAt(x, y)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function holdAt(x, y, duration)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(duration)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function holdElement(el, duration)
    if not el or not el.Visible then return false end
    local pos = el.AbsolutePosition
    local size = el.AbsoluteSize
    holdAt(pos.X + (size.X / 2), pos.Y + (size.Y / 2), duration)
    return true
end

--============================================================
-- REDEEM CODE SYSTEM
--============================================================
local function getAllRedeemRemotes()
    local remotes = {}
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            local n = v.Name:lower()
            if n:find("code") or n:find("redeem") or n:find("promo") or n:find("claim") then
                table.insert(remotes, v)
            end
        end
    end
    return remotes
end

local function redeemCode(codeStr)
    local remotes = getAllRedeemRemotes()
    local success = false
    
    for _, remote in ipairs(remotes) do
        local ok = pcall(function()
            if remote:IsA("RemoteFunction") then
                remote:InvokeServer(codeStr)
            else
                remote:FireServer(codeStr)
            end
        end)
        if ok then success = true end
    end
    return success
end

--============================================================
-- GUI FINDERS
--============================================================
local function findRollButton()
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, obj in ipairs(gui:GetDescendants()) do
                if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                    local n = obj.Name:lower()
                    if n:find("roll") then
                        return obj
                    end
                end
            end
        end
    end
    return nil
end

local function findPlayButton()
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, obj in ipairs(gui:GetDescendants()) do
                if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                    local txt = ""
                    pcall(function() txt = obj.Text:upper() end)
                    if txt == "PLAY" then
                        return obj
                    end
                end
            end
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
Window:Tag({ Title = "v0.5.1", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

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
    
    local s2 = TabMain:Section({ Title = "In-Game", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({
        Title = "Auto Roll (Hold & Release)",
        Desc = "Nahan tombol ROLL otomatis",
        Value = false,
        Callback = function(v) State.AutoRoll = v end,
    })
    s2:Space()
    s2:Slider({
        Title = "Hold Duration", Step = 0.05,
        Value = { Min = 0.1, Max = 2, Default = 0.3 },
        Callback = function(v) State.RollHoldTime = v end,
    })
    s2:Space()
    s2:Toggle({
        Title = "Anti-AFK", 
        Value = true, 
        Callback = function(v) State.AntiAFK = v end 
    })
end

--============================================================
-- TAB: CODES
--============================================================
local TabCodes = Window:Tab({
    Title = "Codes", Desc = "Auto Redeem",
    Icon = "solar:ticket-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s = TabCodes:Section({ Title = "Redeem Codes", Box = true, BoxBorder = true, Opened = true })
    s:Button({
        Title = "Redeem Semua Kode",
        Justify = "Center",
        Callback = function()
            WindUI:Notify({ Title = "Codes", Content = "Memproses kode..." })
            task.spawn(function()
                for i, code in ipairs(CodesList) do
                    local success = redeemCode(code)
                    if success then
                        print("[DICE] Mencoba redeem: " .. code)
                    else
                        print("[DICE] Gagal redeem: " .. code)
                    end
                    task.wait(1.5)
                end
                WindUI:Notify({ Title = "Codes", Content = "Selesai! Cek chat game." })
            end)
        end,
    })
    
    s:Space()
    s:Button({
        Title = "Scan Remote Redeem (Debug)",
        Justify = "Center",
        Color = Red,
        Callback = function()
            print("════════ REMOTE SCAN ════════")
            local remotes = getAllRedeemRemotes()
            if #remotes > 0 then
                for _, r in ipairs(remotes) do
                    print("[" .. r.ClassName .. "] " .. r.Name)
                end
            else
                print("Nggak ada remote yang namanya mengandung 'code', 'redeem', atau 'claim'.")
                print("Coba cek manual semua remote di bawah ini:")
                for _, v in ipairs(ReplicatedStorage:GetChildren()) do
                    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                        print("-> " .. v.Name)
                    end
                end
            end
            print("═════════════════════════════")
            WindUI:Notify({ Title = "Scanner", Content = "Cek console Delta!" })
        end,
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
        if btn then
            tapAt(btn.AbsolutePosition.X + btn.AbsoluteSize.X/2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y/2)
        end
    end
end)

task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        task.wait(1)
        if not State.AutoRoll then continue end
        local rollBtn = findRollButton()
        if rollBtn then
            print("[DICE] Nemu tombol roll, hold...")
            holdElement(rollBtn, State.RollHoldTime)
            task.wait(2)
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
    Title = "Pall Dice v0.5.1",
    Content = "Bersih & Ringan. Auto Roll siap!",
    Icon = "solar:bell-bold",
    Duration = 6,
})

print("[PALL-DICE] v0.5.1 loaded.")
