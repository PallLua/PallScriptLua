--[[
    PALL HUB — v3.0.0 (FIXED)
    Author : ENI (for Pall)
    Notes  : Walk-based farm, proper enemy detection,
             tool equip + activate, key-sim skill.
--]]

--============================================================
-- SERVICES
--============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService       = game:GetService("HttpService")

local LP = Players.LocalPlayer

--============================================================
-- LOAD WINDUI
--============================================================
local WindUI
local ok, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)
if ok then WindUI = result else error("[PALL-HUB] Gagal load WindUI.") end

local Green  = Color3.fromHex("#10C550")
local Yellow = Color3.fromHex("#ECA201")
local Purple = Color3.fromHex("#7775F2")
local Blue   = Color3.fromHex("#257AF7")
local Red    = Color3.fromHex("#EF4F1D")
local Grey   = Color3.fromHex("#83889E")

--============================================================
-- STATE
--============================================================
local State = {
    AutoFarm = false, AutoAttack = false, AutoAggro = false,
    AutoSkill = false, AutoDodge = false,
    FarmDistance = 12, OrbitHeight = 6, OrbitSpeed = 3,
    OrbitMode = "Orbit",
    SkillCastDistance = 20, SkillCycleDelay = 0.4,
    WalkSpeed = 16, Noclip = false, InfJump = false, AntiAFK = true,
    DodgeSafeRadius = 18,
}

--============================================================
-- UTILITY
--============================================================
local function getChar() return LP.Character or LP.CharacterAdded:Wait() end
local function getHRP() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end

-- Set of player characters to exclude
local function getPlayerChars()
    local set = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then set[plr.Character] = true end
    end
    return set
end

-- Deteksi enemy: Model dengan Humanoid yang BUKAN karakter player
local function isEnemy(model)
    if not model:IsA("Model") then return false end
    if not model:FindFirstChildOfClass("Humanoid") then return false end
    if not model:FindFirstChild("HumanoidRootPart") then return false end
    if getPlayerChars()[model] then return false end
    if model == LP.Character then return false end
    return true
end

local function getNearestEnemy(maxDist)
    local hrp = getHRP()
    if not hrp then return nil end
    local closest, dist = nil, maxDist or math.huge
    for _, model in ipairs(workspace:GetDescendants()) do
        if isEnemy(model) then
            local mhrp = model:FindFirstChild("HumanoidRootPart")
            if mhrp then
                local d = (mhrp.Position - hrp.Position).Magnitude
                if d < dist then closest, dist = model, d end
            end
        end
    end
    return closest
end

-- WALK properly — no boost, no teleport, WalkSpeed user-defined
local function walkTo(pos)
    local hum = getHum()
    if not hum then return end
    hum.WalkSpeed = State.WalkSpeed
    hum:MoveTo(pos)
end
--============================================================
-- WINDOW
--============================================================
local Window = WindUI:CreateWindow({
    Title = "Pall × DUNGEON QUEST REBORN",
    Folder = "pallhubv3",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    OpenButton = {
        Title = "Open Pall Hub v3",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#e7ff2f")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})

Window:Tag({ Title = "v3.0.0 FIXED", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- FARM TAB
--============================================================
local FarmTab = Window:Tab({
    Title = "Farm", Desc = "Walk-based, no teleport",
    Icon = "solar:home-2-bold", IconColor = Green, IconShape = "Square", Border = true,
})

local AutoSec = FarmTab:Section({ Title = "Auto Farm", Box = true, BoxBorder = true, Opened = true })

AutoSec:Toggle({
    Title = "Auto Farm", Desc = "Jalan ke musuh, walk-based",
    Value = false, Callback = function(v) State.AutoFarm = v end,
})
AutoSec:Space()
AutoSec:Toggle({
    Title = "Auto Attack", Desc = "Equip tool, lalu activate",
    Value = false, Callback = function(v) State.AutoAttack = v end,
})
AutoSec:Space()
AutoSec:Toggle({
    Title = "Auto Aggro All", Desc = "Jalan ke semua mob, kecepatan 16",
    Value = false, Callback = function(v) State.AutoAggro = v end,
})

local MoveSec = FarmTab:Section({ Title = "Movement", Box = true, BoxBorder = true, Opened = true })

MoveSec:Slider({
    Title = "WalkSpeed", Step = 1,
    Value = { Min = 16, Max = 60, Default = 16 },
    Callback = function(v)
        State.WalkSpeed = v
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end,
})
MoveSec:Space()
MoveSec:Slider({
    Title = "Farm Distance", Step = 1,
    Value = { Min = 5, Max = 40, Default = 12 },
    Callback = function(v) State.FarmDistance = v end,
})
MoveSec:Space()
MoveSec:Dropdown({
    Title = "Orbit Mode",
    Values = { "Orbit", "Overhead", "Behind", "Below", "Inside", "Group" },
    Value = "Orbit",
    Callback = function(v) State.OrbitMode = v end,
})
MoveSec:Space()
MoveSec:Slider({
    Title = "Orbit Height", Step = 1,
    Value = { Min = 0, Max = 20, Default = 6 },
    Callback = function(v) State.OrbitHeight = v end,
})
MoveSec:Space()
MoveSec:Slider({
    Title = "Orbit Speed", Step = 1,
    Value = { Min = 1, Max = 10, Default = 3 },
    Callback = function(v) State.OrbitSpeed = v end,
})
--============================================================
-- SKILLS TAB
--============================================================
local SkillTab = Window:Tab({
    Title = "Skills", Desc = "Key-sim Q & E",
    Icon = "solar:bolt-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})

local SkillSec = SkillTab:Section({ Title = "Auto Skill", Box = true, BoxBorder = true, Opened = true })

SkillSec:Toggle({
    Title = "Auto Skill", Desc = "Kirim Q & E pakai VirtualInput",
    Value = false, Callback = function(v) State.AutoSkill = v end,
})
SkillSec:Space()
SkillSec:Slider({
    Title = "Cast Distance", Step = 1,
    Value = { Min = 5, Max = 50, Default = 20 },
    Callback = function(v) State.SkillCastDistance = v end,
})
SkillSec:Space()
SkillSec:Slider({
    Title = "Cycle Delay", Step = 0.1,
    Value = { Min = 0.1, Max = 3, Default = 0.4 },
    Callback = function(v) State.SkillCycleDelay = v end,
})
--============================================================
-- PLAYER TAB (basic)
--============================================================
local PlayerTab = Window:Tab({
    Title = "Player", Desc = "Speed, noclip, anti-afk",
    Icon = "solar:user-bold", IconColor = Grey, IconShape = "Square", Border = true,
})

local PSec = PlayerTab:Section({ Title = "Movement", Box = true, BoxBorder = true, Opened = true })

PSec:Toggle({
    Title = "Noclip", Value = false,
    Callback = function(v) State.Noclip = v end,
})
PSec:Space()
PSec:Toggle({
    Title = "Infinite Jump", Value = false,
    Callback = function(v) State.InfJump = v end,
})
PSec:Space()
PSec:Toggle({
    Title = "Anti-AFK", Value = true,
    Callback = function(v) State.AntiAFK = v end,
})

--============================================================
-- LOOPS
--============================================================

-- Anti-AFK
task.spawn(function()
    while task.wait(60) do
        if State.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end
end)

-- AUTO FARM — walk ke musuh terdekat, loop terus
task.spawn(function()
    while task.wait(0.2) do
        if State.AutoFarm then
            local mob = getNearestEnemy(State.FarmDistance * 4)
            if mob then
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                local hrp = getHRP()
                if mhrp and hrp then
                    local targetPos = mhrp.Position
                    if State.OrbitMode == "Orbit" or State.OrbitMode == "Group" then
                        local angle = tick() * State.OrbitSpeed
                        targetPos = mhrp.Position + Vector3.new(
                            math.cos(angle) * State.FarmDistance,
                            State.OrbitHeight,
                            math.sin(angle) * State.FarmDistance
                        )
                    elseif State.OrbitMode == "Overhead" then
                        targetPos = mhrp.Position + Vector3.new(0, State.FarmDistance, 0)
                    elseif State.OrbitMode == "Behind" then
                        targetPos = mhrp.Position + Vector3.new(0, 0, -State.FarmDistance)
                    elseif State.OrbitMode == "Below" then
                        targetPos = mhrp.Position + Vector3.new(0, -State.FarmDistance, 0)
                    elseif State.OrbitMode == "Inside" then
                        targetPos = mhrp.Position
                    end
                    walkTo(targetPos)
                end
            end
        end
    end
end)

-- AUTO ATTACK — equip tool dulu, lalu Activate
local function equipBestTool()
    local char = LP.Character
    if not char then return nil end
    -- Cek tool yang udah dipegang
    local equipped = char:FindFirstChildOfClass("Tool")
    if equipped then return equipped end
    -- Equip dari backpack
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then
                item.Parent = char
                task.wait(0.1)
                return item
            end
        end
    end
    return nil
end

task.spawn(function()
    while task.wait(0.2) do
        if State.AutoAttack then
            local mob = getNearestEnemy(State.FarmDistance * 3)
            if mob then
                local hrp = getHRP()
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                if hrp and mhrp and (hrp.Position - mhrp.Position).Magnitude <= State.FarmDistance * 2 then
                    local tool = equipBestTool()
                    if tool then
                        pcall(function() tool:Activate() end)
                    end
                end
            end
        end
    end
end)

-- AUTO AGGRO — walk ke tiap mob, SATU PER SATU (blocking), speed 16
task.spawn(function()
    while task.wait(0.5) do
        if State.AutoAggro then
            for _, model in ipairs(workspace:GetDescendants()) do
                if not State.AutoAggro then break end
                if isEnemy(model) then
                    local mhrp = model:FindFirstChild("HumanoidRootPart")
                    if mhrp then
                        local hum = getHum()
                        if hum then
                            hum.WalkSpeed = State.WalkSpeed
                            hum:MoveTo(mhrp.Position)
                            -- Tunggu sampai dekat atau timeout 4 detik
                            local t0 = tick()
                            while tick() - t0 < 4 do
                                if not State.AutoAggro then break end
                                local curHrp = getHRP()
                                if not curHrp then break end
                                if (curHrp.Position - mhrp.Position).Magnitude <= 8 then break end
                                task.wait(0.1)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- AUTO SKILL — simulate key press Q & E
local function pressKey(keyCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

task.spawn(function()
    while task.wait(State.SkillCycleDelay) do
        if State.AutoSkill then
            local mob = getNearestEnemy(State.SkillCastDistance * 2)
            if mob then
                local hrp = getHRP()
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                if hrp and mhrp and (hrp.Position - mhrp.Position).Magnitude <= State.SkillCastDistance then
                    pressKey(Enum.KeyCode.Q)
                    task.wait(State.SkillCycleDelay)
                    pressKey(Enum.KeyCode.E)
                end
            end
        end
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if State.Noclip and LP.Character then
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
end)

-- Inf Jump
UserInputService.JumpRequest:Connect(function()
    if State.InfJump then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- WalkSpeed apply on respawn
LP.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = State.WalkSpeed
end)
--============================================================
-- NOTIF
--============================================================
WindUI:Notify({
    Title = "Pall Hub v3 Loaded",
    Content = "Fixed: walk-based farm, proper attack, key-sim skill.",
    Icon = "solar:bell-bold", Duration = 6,
})

print("[PALL-HUB] v3.0.0 loaded. Walk-based, no teleport.")
