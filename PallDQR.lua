--[[
    ═══════════════════════════════════════════════════════════
    PALL HUB — DUNGEON QUEST REBORN
    Author  : ENI (for Pall)
    Version : v4.0.0 — Full Merged
    Notes   : Walk-based farm, pathfinding aggro, orbit dodge,
              sequential skill (Q→E), camera lock to NPC.
    ═══════════════════════════════════════════════════════════
--]]

--============================================================
-- SERVICES
--============================================================
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService  = game:GetService("PathfindingService")

local LP = Players.LocalPlayer

--============================================================
-- LOAD WINDUI
--============================================================
local WindUI
local ok, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)
if ok then WindUI = result else error("[PALL-HUB] Gagal load WindUI.") end

--============================================================
-- WARNA
--============================================================
local Green  = Color3.fromHex("#10C550")
local Yellow = Color3.fromHex("#ECA201")
local Purple = Color3.fromHex("#7775F2")
local Blue   = Color3.fromHex("#257AF7")
local Red    = Color3.fromHex("#EF4F1D")
local Grey   = Color3.fromHex("#83889E")

--============================================================
-- STATE GLOBAL
--============================================================
local State = {
    -- Combat
    AutoAttack = false,
    AutoAggro = false,
    AttackRange = 25,
    AggroRange = 300,
    WalkSpeed = 16,

    -- Dodge
    AutoDodge = false,
    DodgeRange = 40,
    DodgeOrbitRadius = 10,
    DodgeOrbitSpeed = 2,
    DodgeWalkSpeed = 20,

    -- Skill
    AutoSkill = false,
    SkillQDelay = 0.4,
    SkillEDelay = 0.8,
    UseRemoteFallback = true,

    -- Camera
    CameraLock = false,
    CameraTargetMode = "Nearest Enemy",
    CameraDistance = 8,
    CameraHeight = 3,
    CameraSmoothness = 0.25,
    CameraFaceTarget = true,
    CameraRestoreOnDeath = true,

    -- Misc
    Noclip = false,
    InfJump = false,
    AntiAFK = true,
}

--============================================================
-- UTILITY
--============================================================
local function getChar() return LP.Character or LP.CharacterAdded:Wait() end
local function getHRP() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end

local function getPlayerChars()
    local set = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then set[plr.Character] = true end
    end
    return set
end

local function isEnemy(model)
    if not model:IsA("Model") then return false end
    if not model:FindFirstChildOfClass("Humanoid") then return false end
    if not model:FindFirstChild("HumanoidRootPart") then return false end
    if getPlayerChars()[model] then return false end
    if model == LP.Character then return false end
    return true
end

local function isBossModel(model)
    if not model then return false end
    local n = model.Name:lower()
    return n:find("boss") or n:find("lord") or n:find("king")
        or n:find("queen") or n:find("giant")
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
    return closest, dist
end

local function getNearestBoss(maxDist)
    local hrp = getHRP()
    if not hrp then return nil end
    local closest, dist = nil, maxDist or math.huge
    for _, model in ipairs(workspace:GetDescendants()) do
        if isEnemy(model) and isBossModel(model) then
            local mhrp = model:FindFirstChild("HumanoidRootPart")
            if mhrp then
                local d = (mhrp.Position - hrp.Position).Magnitude
                if d < dist then closest, dist = model, d end
            end
        end
    end
    return closest
end
--============================================================
-- PATHFINDING (hindari wall, cari lorong)
--============================================================
local function walkWithPath(targetPos, timeout)
    timeout = timeout or 8
    local hrp = getHRP()
    local hum = getHum()
    if not hrp or not hum then return end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = false,
        WaypointSpacing = 4,
    })

    local okCompute = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)

    if not okCompute or path.Status ~= Enum.PathStatus.Success then
        hum.WalkSpeed = State.WalkSpeed
        hum:MoveTo(targetPos)
        return
    end

    local waypoints = path:GetWaypoints()
    local t0 = tick()
    for _, wp in ipairs(waypoints) do
        if tick() - t0 > timeout then break end
        if wp.Action == Enum.PathWaypointAction.Jump then
            pcall(function() hum.Jump = true end)
        end
        local cur = getHRP()
        if not cur then break end
        hum.WalkSpeed = State.WalkSpeed
        hum:MoveTo(wp.Position)
        local wt0 = tick()
        while tick() - wt0 < 3 do
            if tick() - t0 > timeout then break end
            local c2 = getHRP()
            if not c2 then break end
            if (c2.Position - wp.Position).Magnitude <= 4 then break end
            task.wait(0.08)
        end
    end
end

--============================================================
-- CAMERA STATE
--============================================================
local CameraState = {
    _originalType = nil,
    _originalAutoRotate = true,
}

local function saveOriginalCameraState()
    local cam = workspace.CurrentCamera
    CameraState._originalType = cam.CameraType
    local hum = getHum()
    if hum then
        CameraState._originalAutoRotate = hum.AutoRotate
    end
end

local function restoreCamera()
    local cam = workspace.CurrentCamera
    if CameraState._originalType then
        cam.CameraType = CameraState._originalType
    else
        cam.CameraType = Enum.CameraType.Custom
    end
    local hum = getHum()
    if hum then
        hum.AutoRotate = CameraState._originalAutoRotate
    end
end

--============================================================
-- WINDOW
--============================================================
local Window = WindUI:CreateWindow({
    Title = "Pall × DUNGEON QUEST REBORN",
    Folder = "pallhubv4",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open Pall Hub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.5,
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#e7ff2f")
        ),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})

Window:Tag({
    Title = "v4.0.0",
    Icon = "github",
    Color = Color3.fromHex("#1c1c1c"),
    Border = true,
})

--============================================================
-- TAB: COMBAT
--============================================================
local CombatTab = Window:Tab({
    Title = "Combat", Desc = "Attack, aggro, pathfinding",
    Icon = "solar:sword-bold", IconColor = Green, IconShape = "Square", Border = true,
})

do
    local AtkSec = CombatTab:Section({ Title = "Auto Attack", Box = true, BoxBorder = true, Opened = true })

    AtkSec:Toggle({
        Title = "Auto Attack (Click-based)",
        Desc = "Mencet saat ada musuh, diem saat kosong",
        Value = false,
        Callback = function(v) State.AutoAttack = v end,
    })
    AtkSec:Space()
    AtkSec:Slider({
        Title = "Attack Range", Step = 1,
        Value = { Min = 5, Max = 60, Default = 25 },
        Callback = function(v) State.AttackRange = v end,
    })
    AtkSec:Space()
    AtkSec:Slider({
        Title = "WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 60, Default = 16 },
        Callback = function(v)
            State.WalkSpeed = v
            local hum = getHum(); if hum then hum.WalkSpeed = v end
        end,
    })

    local AggroSec = CombatTab:Section({ Title = "Auto Aggro", Box = true, BoxBorder = true, Opened = true })

    AggroSec:Toggle({
        Title = "Auto Aggro All",
        Desc = "Pathfinding — hindari wall, cari lorong",
        Value = false,
        Callback = function(v) State.AutoAggro = v end,
    })
    AggroSec:Space()
    AggroSec:Slider({
        Title = "Aggro Range", Step = 10,
        Value = { Min = 50, Max = 800, Default = 300 },
        Callback = function(v) State.AggroRange = v end,
    })
end

--============================================================
-- TAB: DODGE
--============================================================
local DodgeTab = Window:Tab({
    Title = "Dodge", Desc = "Orbit walk around NPC",
    Icon = "solar:shield-check-bold", IconColor = Purple, IconShape = "Square", Border = true,
})

do
    local DodgeSec = DodgeTab:Section({ Title = "Auto Dodge (Orbit)", Box = true, BoxBorder = true, Opened = true })

    DodgeSec:Toggle({
        Title = "Auto Dodge",
        Desc = "Jalan mutar mengelilingi NPC terdekat",
        Value = false,
        Callback = function(v) State.AutoDodge = v end,
    })
    DodgeSec:Space()
    DodgeSec:Slider({
        Title = "Detect Range", Step = 1,
        Value = { Min = 10, Max = 100, Default = 40 },
        Callback = function(v) State.DodgeRange = v end,
    })
    DodgeSec:Space()
    DodgeSec:Slider({
        Title = "Orbit Radius (kelebaran)", Step = 1,
        Value = { Min = 3, Max = 50, Default = 10 },
        Callback = function(v) State.DodgeOrbitRadius = v end,
    })
    DodgeSec:Space()
    DodgeSec:Slider({
        Title = "Orbit Speed", Step = 0.5,
        Value = { Min = 0.5, Max = 10, Default = 2 },
        Callback = function(v) State.DodgeOrbitSpeed = v end,
    })
    DodgeSec:Space()
    DodgeSec:Slider({
        Title = "Dodge WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 60, Default = 20 },
        Callback = function(v) State.DodgeWalkSpeed = v end,
    })
end

--============================================================
-- TAB: SKILLS
--============================================================
local SkillTab = Window:Tab({
    Title = "Skills", Desc = "Q dulu, lalu E",
    Icon = "solar:bolt-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})

do
    local SkillSec = SkillTab:Section({ Title = "Auto Skill", Box = true, BoxBorder = true, Opened = true })

    SkillSec:Toggle({
        Title = "Auto Skill",
        Desc = "Sequential: Q → delay → E → loop",
        Value = false,
        Callback = function(v) State.AutoSkill = v end,
    })
    SkillSec:Space()
    SkillSec:Slider({
        Title = "Q → E Delay", Step = 0.1,
        Value = { Min = 0.1, Max = 3, Default = 0.4 },
        Callback = function(v) State.SkillQDelay = v end,
    })
    SkillSec:Space()
    SkillSec:Slider({
        Title = "E → Q Delay (loop)", Step = 0.1,
        Value = { Min = 0.1, Max = 5, Default = 0.8 },
        Callback = function(v) State.SkillEDelay = v end,
    })
    SkillSec:Space()
    SkillSec:Toggle({
        Title = "Use Remote Fallback",
        Desc = "Kalau key-sim gagal, pakai abilityEvent",
        Value = true,
        Callback = function(v) State.UseRemoteFallback = v end,
    })
end

--============================================================
-- TAB: CAMERA
--============================================================
local CameraTab = Window:Tab({
    Title = "Camera", Desc = "Lock kamera ke NPC",
    Icon = "solar:videocamera-record-bold", IconColor = Blue, IconShape = "Square", Border = true,
})

do
    local CamSec = CameraTab:Section({ Title = "Camera Lock", Box = true, BoxBorder = true, Opened = true })

    CamSec:Toggle({
        Title = "Lock Camera to Target",
        Desc = "Kamera ngunci ke NPC, karakter otomatis menghadap",
        Value = false,
        Callback = function(v)
            State.CameraLock = v
            if v then
                saveOriginalCameraState()
            else
                restoreCamera()
            end
        end,
    })
    CamSec:Space()
    CamSec:Dropdown({
        Title = "Target Mode",
        Values = { "Nearest Enemy", "Nearest Boss" },
        Value = "Nearest Enemy",
        Callback = function(v) State.CameraTargetMode = v end,
    })
    CamSec:Space()
    CamSec:Slider({
        Title = "Camera Distance", Step = 0.5,
        Value = { Min = 3, Max = 25, Default = 8 },
        Callback = function(v) State.CameraDistance = v end,
    })
    CamSec:Space()
    CamSec:Slider({
        Title = "Camera Height", Step = 0.5,
        Value = { Min = 0, Max = 15, Default = 3 },
        Callback = function(v) State.CameraHeight = v end,
    })
    CamSec:Space()
    CamSec:Slider({
        Title = "Smoothness", Step = 0.05,
        Value = { Min = 0.05, Max = 1, Default = 0.25 },
        Callback = function(v) State.CameraSmoothness = v end,
    })
    CamSec:Space()
    CamSec:Toggle({
        Title = "Face Target (putar karakter)",
        Desc = "Kalau nyalain Auto Dodge, matiin ini biar nggak konflik",
        Value = true,
        Callback = function(v) State.CameraFaceTarget = v end,
    })
    CamSec:Space()
    CamSec:Toggle({
        Title = "Restore on Death",
        Value = true,
        Callback = function(v) State.CameraRestoreOnDeath = v end,
    })
end
--============================================================
-- TAB: PLAYER
--============================================================
local PlayerTab = Window:Tab({
    Title = "Player", Desc = "Noclip, jump, anti-afk",
    Icon = "solar:user-bold", IconColor = Grey, IconShape = "Square", Border = true,
})

do
    local PSec = PlayerTab:Section({ Title = "Misc", Box = true, BoxBorder = true, Opened = true })

    PSec:Toggle({ Title = "Noclip", Value = false, Callback = function(v) State.Noclip = v end })
    PSec:Space()
    PSec:Toggle({ Title = "Infinite Jump", Value = false, Callback = function(v) State.InfJump = v end })
    PSec:Space()
    PSec:Toggle({ Title = "Anti-AFK", Value = true, Callback = function(v) State.AntiAFK = v end })
end

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

-- AUTO ATTACK (click-based)
local function clickOnce()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

local function activateTool()
    local char = LP.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

task.spawn(function()
    while task.wait(0.1) do
        if State.AutoAttack then
            local mob, dist = getNearestEnemy(State.AttackRange)
            if mob and dist and dist <= State.AttackRange then
                clickOnce()
                activateTool()
            end
        end
    end
end)

-- AUTO AGGRO (pathfinding)
task.spawn(function()
    while task.wait(0.6) do
        if State.AutoAggro then
            local hrp = getHRP()
            if hrp then
                local targets = {}
                for _, model in ipairs(workspace:GetDescendants()) do
                    if isEnemy(model) then
                        local mhrp = model:FindFirstChild("HumanoidRootPart")
                        if mhrp then
                            local d = (mhrp.Position - hrp.Position).Magnitude
                            if d <= State.AggroRange then
                                table.insert(targets, { hrp = mhrp, dist = d })
                            end
                        end
                    end
                end
                table.sort(targets, function(a, b) return a.dist < b.dist end)

                for _, t in ipairs(targets) do
                    if not State.AutoAggro then break end
                    local cur = getHRP()
                    if not cur then break end
                    local d = (cur.Position - t.hrp.Position).Magnitude
                    if d > 6 then
                        walkWithPath(t.hrp.Position, 6)
                    end
                end
            end
        end
    end
end)

-- AUTO DODGE (walk orbit)
local orbitAngle = 0
task.spawn(function()
    while task.wait(0.08) do
        if State.AutoDodge then
            local mob = getNearestEnemy(State.DodgeRange)
            if mob then
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                local hum = getHum()
                if mhrp and hum then
                    orbitAngle = orbitAngle + State.DodgeOrbitSpeed * 0.08
                    local targetPos = mhrp.Position + Vector3.new(
                        math.cos(orbitAngle) * State.DodgeOrbitRadius,
                        0,
                        math.sin(orbitAngle) * State.DodgeOrbitRadius
                    )
                    hum.WalkSpeed = State.DodgeWalkSpeed
                    hum:MoveTo(targetPos)
                end
            else
                orbitAngle = orbitAngle + 0.5 * 0.08
            end
        end
    end
end)

-- AUTO SKILL (Q → E)
local abilityFolder = ReplicatedStorage:FindFirstChild("abilities")
local allAbilityEvents = {}
if abilityFolder then
    for _, folder in ipairs(abilityFolder:GetChildren()) do
        local ev = folder:FindFirstChild("abilityEvent")
        if ev and ev:IsA("RemoteEvent") then
            table.insert(allAbilityEvents, ev)
        end
    end
end

local function pressKey(keyCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function fireAbility(index, target)
    local ev = allAbilityEvents[index]
    if ev then
        pcall(function()
            if target then ev:FireServer(target)
            else ev:FireServer() end
        end)
    end
end

task.spawn(function()
    while task.wait(0.1) do
        if State.AutoSkill then
            local mob = getNearestEnemy(40)
            pressKey(Enum.KeyCode.Q)
            if State.UseRemoteFallback then fireAbility(1, mob) end
            task.wait(State.SkillQDelay)
            pressKey(Enum.KeyCode.E)
            if State.UseRemoteFallback then fireAbility(2, mob) end
            task.wait(State.SkillEDelay)
        end
    end
end)

-- CAMERA LOCK
RunService.RenderStepped:Connect(function()
    if not State.CameraLock then return end
    local hrp = getHRP()
    if not hrp then return end

    local target
    if State.CameraTargetMode == "Nearest Boss" then
        target = getNearestBoss(500)
    else
        target = getNearestEnemy(500)
    end
    if not target then return end
    local tHRP = target:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    local lookAt = tHRP.Position
    local dirToTarget = lookAt - hrp.Position
    local horizDir = Vector3.new(dirToTarget.X, 0, dirToTarget.Z)
    if horizDir.Magnitude < 0.1 then horizDir = Vector3.new(0, 0, -1) end
    horizDir = horizDir.Unit

    local camPos = hrp.Position
        - horizDir * State.CameraDistance
        + Vector3.new(0, State.CameraHeight, 0)

    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Scriptable

    local desiredCF = CFrame.lookAt(camPos, lookAt)
    cam.CFrame = cam.CFrame:Lerp(desiredCF, State.CameraSmoothness)

    if State.CameraFaceTarget then
        local hum = getHum()
        if hum then
            hum.AutoRotate = false
            local flatLook = Vector3.new(lookAt.X, hrp.Position.Y, lookAt.Z)
            hrp.CFrame = CFrame.new(hrp.Position, flatLook)
        end
    end
end)

-- Restore camera on death
LP.CharacterAdded:Connect(function()
    if State.CameraRestoreOnDeath then
        task.wait(0.5)
        restoreCamera()
        if State.CameraLock then
            task.wait(0.5)
            saveOriginalCameraState()
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

-- WalkSpeed on respawn
LP.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = State.WalkSpeed
end)

--============================================================
-- NOTIF
--============================================================
WindUI:Notify({
    Title = "Pall Hub v4.0.0",
    Content = "Full merged. Semua fitur siap.",
    Icon = "solar:bell-bold",
    Duration = 6,
})

print("[PALL-HUB] v4.0.0 loaded. Full merged script.")
