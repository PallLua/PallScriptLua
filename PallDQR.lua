--[[
    PALL HUB — v5.2.0
    Fix   : Auto Dodge face-lock ke NPC (karakter muter sambil hadap)
            Camera anti-nunduk (lookAt leveled + Y-clamp post-raycast)
--]]

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService  = game:GetService("PathfindingService")

local LP = Players.LocalPlayer

local WindUI
local ok, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)
if ok then WindUI = result else error("[PALL-HUB] Gagal load WindUI.") end

local Green  = Color3.fromHex("#10C550")
local Yellow = Color3.fromHex("#ECA201")
local Purple = Color3.fromHex("#7775F2")
local Blue   = Color3.fromHex("#257AF7")
local Grey   = Color3.fromHex("#83889E")

--============================================================
-- STATE
--============================================================
local State = {
    AutoAttack = false, AutoAggro = false,
    AttackRange = 25, AggroRange = 300, WalkSpeed = 16,

    AutoDodge = false, DodgeRange = 40,
    DodgeOrbitRadius = 10, DodgeOrbitSpeed = 2, DodgeWalkSpeed = 20,

    AutoSkill = false, SkillQDelay = 0.4, SkillEDelay = 0.8, UseRemoteFallback = true,

    CameraLock = false, CameraTargetMode = "Nearest Enemy",
    CameraDistance = 8, CameraHeight = 3, CameraSmoothness = 0.25,
    CameraMinHeight = 1.5, CameraFollowChar = false, CameraCollision = true,
    CameraRestoreOnDeath = true,

    FaceMode = "Both", FacePriority = "Camera Target",
    FaceRotationSpeed = 0.35, FaceOnlyWhenMoving = false,

    _dodgeTarget = nil,

    Noclip = false, InfJump = false, AntiAFK = true,
}

--============================================================
-- UTILITY
--============================================================
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
    local hrp = getHRP(); if not hrp then return nil end
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
    local hrp = getHRP(); if not hrp then return nil end
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
-- PATHFINDING
--============================================================
local function walkWithPath(targetPos, timeout)
    timeout = timeout or 8
    local hrp, hum = getHRP(), getHum()
    if not hrp or not hum then return end
    local path = PathfindingService:CreatePath({
        AgentRadius = 2, AgentHeight = 5, AgentCanJump = true,
        AgentCanClimb = false, WaypointSpacing = 4,
    })
    local okCompute = pcall(function() path:ComputeAsync(hrp.Position, targetPos) end)
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
        local cur = getHRP(); if not cur then break end
        hum.WalkSpeed = State.WalkSpeed
        hum:MoveTo(wp.Position)
        local wt0 = tick()
        while tick() - wt0 < 3 do
            if tick() - t0 > timeout then break end
            local c2 = getHRP(); if not c2 then break end
            if (c2.Position - wp.Position).Magnitude <= 4 then break end
            task.wait(0.08)
        end
    end
end

--============================================================
-- CAMERA HELPERS
--============================================================
local CameraState = { _originalType = nil, _originalAutoRotate = true }

local function saveOriginalCameraState()
    CameraState._originalType = workspace.CurrentCamera.CameraType
    local hum = getHum()
    if hum then CameraState._originalAutoRotate = hum.AutoRotate end
end

local function restoreCamera()
    local cam = workspace.CurrentCamera
    cam.CameraType = CameraState._originalType or Enum.CameraType.Custom
    local hum = getHum()
    if hum then hum.AutoRotate = CameraState._originalAutoRotate end
end

local function smoothFaceY(targetPos, speed)
    local hrp = getHRP(); if not hrp then return end
    local pos = hrp.Position
    local dirXZ = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
    if dirXZ.Magnitude < 0.1 then return end
    local desiredY = math.atan2(-dirXZ.X, -dirXZ.Z)
    local _, curY, _ = hrp.CFrame:ToEulerAnglesYXZ()
    local diff = desiredY - curY
    while diff > math.pi do diff = diff - math.pi * 2 end
    while diff < -math.pi do diff = diff + math.pi * 2 end
    local newY = curY + diff * math.clamp(speed, 0.05, 1)
    hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, newY, 0)
end

local function pickFaceTarget()
    if State.FacePriority == "Dodge Target" and State._dodgeTarget and State._dodgeTarget.Parent then
        return State._dodgeTarget
    elseif State.FacePriority == "Nearest Boss" then
        return getNearestBoss(500)
    elseif State.FacePriority == "Nearest Enemy" then
        return getNearestEnemy(500)
    end
    if State.CameraTargetMode == "Nearest Boss" then
        return getNearestBoss(500)
    else
        return getNearestEnemy(500)
    end
end

-- Raycast — cuma ambil titik atas dari hit, biar kamera nggak nyemplung ke tanah
local function getSafeCameraPos(hrp, desiredPos)
    local rayOrigin = hrp.Position + Vector3.new(0, 2, 0)
    local rayDir = desiredPos - rayOrigin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LP.Character}
    params.IgnoreWater = true
    local hit = workspace:Raycast(rayOrigin, rayDir, params)
    if hit then
        local dist = math.max((hit.Position - rayOrigin).Magnitude - 0.8, 1)
        return rayOrigin + rayDir.Unit * dist
    end
    return desiredPos
end
--============================================================
-- WINDOW
--============================================================
local Window = WindUI:CreateWindow({
    Title = "Pall × DUNGEON QUEST REBORN",
    Folder = "pallhubv52",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open Pall Hub",
        CornerRadius = UDim.new(1, 0), StrokeThickness = 3,
        Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#e7ff2f")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})

Window:Tag({ Title = "v5.2.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: COMBAT
--============================================================
local CombatTab = Window:Tab({
    Title = "Combat", Desc = "Attack & Aggro",
    Icon = "solar:sword-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local AtkSec = CombatTab:Section({ Title = "Auto Attack", Box = true, BoxBorder = true, Opened = true })
    AtkSec:Toggle({ Title = "Auto Attack", Value = false, Callback = function(v) State.AutoAttack = v end })
    AtkSec:Space()
    AtkSec:Slider({ Title = "Attack Range", Step = 1,
        Value = { Min = 5, Max = 60, Default = 25 },
        Callback = function(v) State.AttackRange = v end })
    AtkSec:Space()
    AtkSec:Slider({ Title = "WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 60, Default = 16 },
        Callback = function(v)
            State.WalkSpeed = v
            local hum = getHum(); if hum then hum.WalkSpeed = v end
        end })

    local AggroSec = CombatTab:Section({ Title = "Auto Aggro", Box = true, BoxBorder = true, Opened = true })
    AggroSec:Toggle({ Title = "Auto Aggro All", Value = false, Callback = function(v) State.AutoAggro = v end })
    AggroSec:Space()
    AggroSec:Slider({ Title = "Aggro Range", Step = 10,
        Value = { Min = 50, Max = 800, Default = 300 },
        Callback = function(v) State.AggroRange = v end })
end

--============================================================
-- TAB: DODGE
--============================================================
local DodgeTab = Window:Tab({
    Title = "Dodge", Desc = "Orbit + hadap NPC",
    Icon = "solar:shield-check-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local DodgeSec = DodgeTab:Section({ Title = "Auto Dodge (Orbit + Face)", Box = true, BoxBorder = true, Opened = true })
    DodgeSec:Toggle({ Title = "Auto Dodge", Desc = "Karakter muter sambil hadap NPC",
        Value = false, Callback = function(v) State.AutoDodge = v end })
    DodgeSec:Space()
    DodgeSec:Slider({ Title = "Detect Range", Step = 1,
        Value = { Min = 10, Max = 100, Default = 40 },
        Callback = function(v) State.DodgeRange = v end })
    DodgeSec:Space()
    DodgeSec:Slider({ Title = "Orbit Radius", Step = 1,
        Value = { Min = 3, Max = 50, Default = 10 },
        Callback = function(v) State.DodgeOrbitRadius = v end })
    DodgeSec:Space()
    DodgeSec:Slider({ Title = "Orbit Speed", Step = 0.5,
        Value = { Min = 0.5, Max = 10, Default = 2 },
        Callback = function(v) State.DodgeOrbitSpeed = v end })
    DodgeSec:Space()
    DodgeSec:Slider({ Title = "Dodge WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 60, Default = 20 },
        Callback = function(v) State.DodgeWalkSpeed = v end })
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
    SkillSec:Toggle({ Title = "Auto Skill", Value = false, Callback = function(v) State.AutoSkill = v end })
    SkillSec:Space()
    SkillSec:Slider({ Title = "Q → E Delay", Step = 0.1,
        Value = { Min = 0.1, Max = 3, Default = 0.4 },
        Callback = function(v) State.SkillQDelay = v end })
    SkillSec:Space()
    SkillSec:Slider({ Title = "E → Q Delay", Step = 0.1,
        Value = { Min = 0.1, Max = 5, Default = 0.8 },
        Callback = function(v) State.SkillEDelay = v end })
    SkillSec:Space()
    SkillSec:Toggle({ Title = "Use Remote Fallback", Value = true,
        Callback = function(v) State.UseRemoteFallback = v end })
end

--============================================================
-- TAB: CAMERA
--============================================================
local CameraTab = Window:Tab({
    Title = "Camera", Desc = "Anti-nunduk + follow rotation",
    Icon = "solar:videocamera-record-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local CamSec = CameraTab:Section({ Title = "Camera Lock", Box = true, BoxBorder = true, Opened = true })
    CamSec:Toggle({ Title = "Lock Camera to Target", Value = false,
        Callback = function(v)
            State.CameraLock = v
            if v then saveOriginalCameraState() else restoreCamera() end
        end })
    CamSec:Space()
    CamSec:Dropdown({ Title = "Target Mode",
        Values = { "Nearest Enemy", "Nearest Boss" },
        Value = "Nearest Enemy",
        Callback = function(v) State.CameraTargetMode = v end })
    CamSec:Space()
    CamSec:Slider({ Title = "Camera Distance", Step = 0.5,
        Value = { Min = 3, Max = 25, Default = 8 },
        Callback = function(v) State.CameraDistance = v end })
    CamSec:Space()
    CamSec:Slider({ Title = "Camera Height", Step = 0.5,
        Value = { Min = 0, Max = 15, Default = 3 },
        Callback = function(v) State.CameraHeight = v end })
    CamSec:Space()
    CamSec:Slider({ Title = "Smoothness", Step = 0.05,
        Value = { Min = 0.05, Max = 1, Default = 0.25 },
        Callback = function(v) State.CameraSmoothness = v end })

    local FixSec = CameraTab:Section({ Title = "Anti-Nunduk / Tanah", Box = true, BoxBorder = true, Opened = true })
    FixSec:Slider({ Title = "Min Height (clamp Y)", Step = 0.5,
        Desc = "Naikin ke 3-4 kalau masih ke bawah",
        Value = { Min = 0, Max = 8, Default = 2 },
        Callback = function(v) State.CameraMinHeight = v end })
    FixSec:Space()
    FixSec:Toggle({ Title = "Anti Tembus Dinding", Value = true,
        Callback = function(v) State.CameraCollision = v end })
    FixSec:Space()
    FixSec:Toggle({ Title = "Follow Character Rotation",
        Desc = "Kamera ikut muter bareng karakter saat orbit",
        Value = true,
        Callback = function(v) State.CameraFollowChar = v end })
    FixSec:Space()
    FixSec:Toggle({ Title = "Restore on Death", Value = true,
        Callback = function(v) State.CameraRestoreOnDeath = v end })
end

--============================================================
-- TAB: FACE TARGET
--============================================================
local FaceTab = Window:Tab({
    Title = "Face Target", Desc = "Rotasi karakter",
    Icon = "solar:user-speak-rounded-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local FSec = FaceTab:Section({ Title = "Face Target Settings", Box = true, BoxBorder = true, Opened = true })
    FSec:Dropdown({ Title = "Face Mode",
        Values = { "Both", "Camera Only", "Character Only", "Off" },
        Value = "Both",
        Callback = function(v)
            State.FaceMode = v
            if v == "Off" or v == "Camera Only" then
                local hum = getHum(); if hum then hum.AutoRotate = true end
            end
        end })
    FSec:Space()
    FSec:Dropdown({ Title = "Target Priority",
        Values = { "Camera Target", "Nearest Enemy", "Nearest Boss", "Dodge Target" },
        Value = "Camera Target",
        Callback = function(v) State.FacePriority = v end })
    FSec:Space()
    FSec:Slider({ Title = "Rotasi Speed (1 = snap)", Step = 0.05,
        Value = { Min = 0.05, Max = 1, Default = 0.35 },
        Callback = function(v) State.FaceRotationSpeed = v end })
    FSec:Space()
    FSec:Toggle({ Title = "Face Only When Moving", Value = false,
        Callback = function(v) State.FaceOnlyWhenMoving = v end })
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

local function clickOnce()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

local function activateTool()
    local char = LP.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

task.spawn(function()
    while task.wait(0.1) do
        if State.AutoAttack then
            local mob, dist = getNearestEnemy(State.AttackRange)
            if mob and dist and dist <= State.AttackRange then
                clickOnce(); activateTool()
            end
        end
    end
end)

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
                    local cur = getHRP(); if not cur then break end
                    local d = (cur.Position - t.hrp.Position).Magnitude
                    if d > 6 then walkWithPath(t.hrp.Position, 6) end
                end
            end
        end
    end
end)

-- AUTO DODGE — orbit + face-lock (Face di-handle RenderStepped utama)
local orbitAngle = 0
task.spawn(function()
    while task.wait(0.05) do
        if State.AutoDodge then
            local mob = getNearestEnemy(State.DodgeRange)
            if mob then
                State._dodgeTarget = mob
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                local hum = getHum()
                if mhrp and hum then
                    orbitAngle = orbitAngle + State.DodgeOrbitSpeed * 0.05
                    local targetPos = mhrp.Position + Vector3.new(
                        math.cos(orbitAngle) * State.DodgeOrbitRadius, 0,
                        math.sin(orbitAngle) * State.DodgeOrbitRadius
                    )
                    hum.AutoRotate = false
                    hum.WalkSpeed = State.DodgeWalkSpeed
                    hum:MoveTo(targetPos)
                end
            else
                State._dodgeTarget = nil
                orbitAngle = orbitAngle + 0.5 * 0.05
            end
        end
    end
end)

-- AUTO SKILL
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
            if target then ev:FireServer(target) else ev:FireServer() end
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
--============================================================
-- CAMERA + FACE TARGET (unified)
--============================================================
RunService.RenderStepped:Connect(function()
    local hrp = getHRP(); if not hrp then return end
    local target = pickFaceTarget()
    if not target then return end
    local tHRP = target:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    local npcPos = tHRP.Position

    -- Base direction — selalu horizontal (Y dibuang)
    local baseDir
    if State.CameraFollowChar then
        local look = hrp.CFrame.LookVector
        baseDir = Vector3.new(look.X, 0, look.Z)
    else
        local diff = npcPos - hrp.Position
        baseDir = Vector3.new(diff.X, 0, diff.Z)
    end
    if baseDir.Magnitude < 0.05 then baseDir = Vector3.new(0, 0, -1) end
    baseDir = baseDir.Unit

    -- Desired camera pos
    local desiredPos = hrp.Position - baseDir * State.CameraDistance
        + Vector3.new(0, State.CameraHeight, 0)

    -- Anti-collision
    if State.CameraCollision then
        desiredPos = getSafeCameraPos(hrp, desiredPos)
    end

    -- Y clamp TERAKHIR (setelah raycast)
    local minY = hrp.Position.Y + State.CameraMinHeight
    desiredPos = Vector3.new(desiredPos.X, math.max(desiredPos.Y, minY), desiredPos.Z)

    -- Apply camera
    if State.CameraLock then
        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Scriptable
        -- LookAt LEVELED — Y sama dengan camera, biar nggak nunduk
        local lookAtLeveled = Vector3.new(npcPos.X, desiredPos.Y, npcPos.Z)
        local desiredCF = CFrame.lookAt(desiredPos, lookAtLeveled)
        cam.CFrame = cam.CFrame:Lerp(desiredCF, State.CameraSmoothness)
    end

    -- FACE TARGET
    -- Kalau Auto Dodge ON, prioritas face ke NPC yang lagi di-orbit (dodge target)
    local faceModeActive = (State.FaceMode == "Both" or State.FaceMode == "Character Only")
    if State.AutoDodge and State._dodgeTarget then
        -- Auto Dodge handle face sendiri — face lock ke NPC orbit
        local mhrp = State._dodgeTarget:FindFirstChild("HumanoidRootPart")
        if mhrp then
            local hum = getHum()
            if hum then hum.AutoRotate = false end
            local flatLook = Vector3.new(mhrp.Position.X, hrp.Position.Y, mhrp.Position.Z)
            local desiredCF = CFrame.new(hrp.Position, flatLook)
            hrp.CFrame = hrp.CFrame:Lerp(desiredCF, 0.6)
        end
    elseif faceModeActive then
        if State.FaceOnlyWhenMoving then
            local hum = getHum()
            if hum and hum.MoveDirection.Magnitude < 0.1 then return end
        end
        local hum = getHum()
        if hum then hum.AutoRotate = false end
        smoothFaceY(npcPos, State.FaceRotationSpeed)
    end
end)

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

RunService.Stepped:Connect(function()
    if State.Noclip and LP.Character then
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if State.InfJump then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

LP.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = State.WalkSpeed
end)

WindUI:Notify({
    Title = "Pall Hub v5.2.0",
    Content = "Auto Dodge face-lock + Camera anti-nunduk.",
    Icon = "solar:bell-bold", Duration = 6,
})

print("[PALL-HUB] v5.2.0 loaded.")
