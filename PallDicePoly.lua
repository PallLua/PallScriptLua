--[[
    ═══════════════════════════════════════════════════════════
    PALL — DICE POLY v0.6.0
    Author  : ENI (for Pall)
    Fixes   : Auto Roll (Hold), Auto Redeem (GUI Mode)
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
    RollHoldTime = 1.5, -- Ditingkatkan jadi 1.5 detik biar makin mantap
    AntiAFK = true,
}

local CodesList = {
    "1000PLAYER", "AMSSRBLHGSHARKAM", "200CCU",
    "RPRXDICEOPOLY", "5CHEST", "WHENYAH", "250LIKESRESTOCKUGC"
}

--============================================================
-- UTILITY (HOLD & RELEASE PAKAI MOUSE1)
--============================================================
local function tapAt(x, y)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function holdElement(el, duration)
    if not el or not el.Visible then return false end
    local pos = el.AbsolutePosition
    local size = el.AbsoluteSize
    local cx = pos.X + (size.X / 2)
    local cy = pos.Y + (size.Y / 2)
    
    pcall(function()
        -- Pindahin kursor dulu
        VirtualInputManager:SendMouseMoveEvent(cx, cy, game)
        task.wait(0.05)
        -- Tekan tahan
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(duration)
        -- Lepas
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
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
                    print("[DICE] NemU TextBox kode: " .. obj.Name)
                    
                    for _, code in ipairs(CodesList) do
                        obj.Text = code
                        task.wait(0.1)
                        
                        -- Cari tombol redeem di dekat TextBox
                        local parent = obj.Parent
                        local btn = parent:FindFirstChild("Redeem", true) or parent:FindFirstChild("Claim", true) or parent:FindFirstChild("Submit", true)
                        
                        if btn and (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
                            local bPos = btn.AbsolutePosition
                            local bSize = btn.AbsoluteSize
                            tapAt(bPos.X + bSize.X/2, bPos.Y + bSize.Y/2)
                            successCount = successCount + 1
                        else
                            -- Kalau nggak ada tombol, coba pencet Enter
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
        print("[DICE] TextBox kode nggak ketemu. Pastikan menu redeem sedang terbuka.")
    else
        WindUI:Notify({ Title = "Redeem", Content = "Mencoba " .. successCount .. " kode via GUI." })
    end
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
Window:Tag({ Title = "v0.6.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

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
        Title = "PENTING: Buka menu 'Codes' di dalam game dulu (sampai kotak ketiknya kelihatan), baru klik tombol ini.",
        TextSize = 12, TextTransparency = 0.2,
    })
    s:Space()
    s:Button({
        Title = "Redeem via GUI",
        Justify = "Center",
        Callback = function()
            redeemViaGUI()
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
            print("[DICE] Nahan tombol ROLL selama " .. State.RollHoldTime .. " detik...")
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
    Title = "Pall Dice v0.6.0",
    Content = "Auto Roll & Redeem Fixed!",
    Icon = "solar:bell-bold",
    Duration = 6,
})

print("[PALL-DICE] v0.6.0 loaded.")
