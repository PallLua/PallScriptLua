--[[
    ═══════════════════════════════════════════════════════════
    PALL — DICE POLY v0.4.2 (UI Fix)
    Author  : ENI (for Pall)
    ═══════════════════════════════════════════════════════════
--]]

print("[PALL-DICE] Memulai eksekusi script...")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
    WindUI = result
    _G.PallWindUI = WindUI
end

local Green = Color3.fromHex("#10C550")
local Yellow = Color3.fromHex("#ECA201")
local Blue = Color3.fromHex("#257AF7")
local Grey = Color3.fromHex("#83889E")

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
    SpeedBoost = false,
    Fly = false,
    FlySpeed = 50,
    AntiAFK = true,
}

local CodesList = {
    "1000PLAYER",
    "AMSSRBLHGSHARKAM",
    "200CCU",
    "RPRXDICEOPOLY",
    "5CHEST",
    "WHENYAH",
    "250LIKESRESTOCKUGC"
}

--============================================================
-- UTILITY
--============================================================
local char, hrp, hum
-- PENTING: Jangan block script, jalanin di background
task.spawn(function()
    while _G.PALL_DICE_RUNNING do
        char = LP.Character or LP.CharacterAdded:Wait()
        hrp = char:WaitForChild("HumanoidRootPart", 5)
        hum = char:WaitForChild("Humanoid", 5)
        task.wait(2) -- Update terus kalau mati/respawn
    end
end)

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
local function getRedeemRemote()
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            local n = v.Name:lower()
            if n:find("code") or n:find("redeem") or n:find("promo") then
                return v
            end
        end
    end
    return nil
end

local function redeemCode(codeStr)
    local remote = getRedeemRemote()
    if remote then
        local ok = pcall(function()
            if remote:IsA("RemoteFunction") then
                remote:InvokeServer(codeStr)
            else
                remote:FireServer(codeStr)
            end
        end)
        return ok
    end
    return false
end

--============================================================
-- GUI FINDERS
--============================================================
local function findRollButton()
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, obj in ipairs(gui:GetDescendants()) do
                if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                    local txt = ""
                    pcall(function() txt = obj.Text:upper() end)
                    if txt == "ROLL" or txt:find("ROLL") or obj.Name:lower() == "roll" then
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
-- WINDOW UI (DIJALANKAN PALING ATAS)
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
Window:Tag({ Title = "v0.4.2", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

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
        Title = "Hold Duration", Step = 0.05,
        Value = { Min = 0.1, Max = 2, Default = 0.3 },
        Callback = function(v) State.RollHoldTime = v end,
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
    s:Section({
        Title = "Klik tombol di bawah untuk klaim semua kode dari Discord.",
        TextSize = 12, TextTransparency = 0.3,
    })
    s:Space()
    s:Button({
        Title = "Redeem Semua Kode",
        Justify = "Center",
        Callback = function()
            WindUI:Notify({ Title = "Codes", Content = "Memproses kode..." })
            task.spawn(function()
                for i, code in ipairs(CodesList) do
                    local success = redeemCode(code)
                    if success then
                        print("[DICE] Redeemed: " .. code)
                    else
                        print("[DICE] Gagal redeem: " .. code)
                    end
                    task.wait(1.5)
                end
                WindUI:Notify({ Title = "Codes", Content = "Selesai! Cek chat game." })
            end)
        end,
    })
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
    s:Toggle({ Title = "Speed Boost (32)", Value = false, Callback = function(v) State.SpeedBoost = v end })
    s:Space()
    s:Toggle({ Title = "Fly (WASD)", Value = false, Callback = function(v) State.Fly = v end })
    s:Space()
    s:Slider({ Title = "Fly Speed", Step = 5, Value = { Min = 10, Max = 300, Default = 50 }, Callback = function(v) State.FlySpeed = v end })
    s:Space()
    s:Toggle({ Title = "Anti-AFK", Value = true, Callback = function(v) State.AntiAFK = v end })
end

--============================================================
-- AUTO LOOPS (BACKGROUND)
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

task.spawn(function()
    local prev = false
    while _G.PALL_DICE_RUNNING do
        task.wait(0.5)
        if not hum then continue end
        if State.SpeedBoost and not prev then
            hum.WalkSpeed = 32; prev = true
        elseif not State.SpeedBoost and prev then
            hum.WalkSpeed = 16; prev = false
        end
    end
end)

local flyConn
task.spawn(function()
    local prev = false
    while _G.PALL_DICE_RUNNING do
        task.wait(0.2)
        if State.Fly ~= prev then
            prev = State.Fly
            if flyConn then flyConn:Disconnect(); flyConn = nil end
            
            if not State.Fly then
                if hum then pcall(function() hum.PlatformStand = false end) end
            else
                if hum then pcall(function() hum.PlatformStand = true end) end
                flyConn = RunService.RenderStepped:Connect(function()
                    if not State.Fly or not hrp then return end
                    local cf = Workspace.CurrentCamera.CFrame
                    local move = Vector3.new(0, 0, 0)
                    local spd = State.FlySpeed
                    
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then move = move - Vector3.new(0,1,0) end
                    
                    if move.Magnitude > 0.01 then move = move.Unit * spd end
                    pcall(function()
                        hrp.Velocity = move
                        hrp.AssemblyLinearVelocity = move
                    end)
                end)
            end
        end
    end
end)

--============================================================
-- NOTIF
--============================================================
WindUI:Notify({
    Title = "Pall Dice v0.4.2",
    Content = "UI berhasil dimuat! Cek tab Codes.",
    Icon = "solar:bell-bold",
    Duration = 6,
})

print("[PALL-DICE] v0.4.2 loaded perfectly.")
