--[[
    ═══════════════════════════════════════════════════════════
    PALL HUB — DUNGEON QUEST REBORN
    Author  : ENI (for Pall)
    Version : v5.4.1 — Indicator Shape Detection
    Notes   : Deteksi warning indicator (beam/circle/AOE) pakai
              shape + material. Escape mode lari keluar zona.
    ═══════════════════════════════════════════════════════════
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

    DodgeBossSkill = true,
    DangerRadius = 25,
    AvoidStrength = 2.5,
    EscapeMode = true,
    EscapeSpeed = 45,
    DangerKeywords = "hitbox,damage,aoe,attack,skill,zone,hazard,projectile,bullet,orb,explosion,wave,strike,beam,fire,ice,frost,snow,trap,circle,area,indicator,marker,shockwave,elemental,cast,spell,impact,radius,warning,telegraph,laser,line,aoe,cone,pulse,sigil",
    ShowDebugNames = false,

    AutoSkill = false, SkillQDelay = 0.4, SkillEDelay = 0.8, UseRemoteFallback = true,

    CameraLock = false, CameraTargetMode = "Nearest Enemy",
    CameraDistance = 8, CameraHeight = 3, CameraSmoothness = 0.25,
    CameraMinHeight = 2, CameraFollowChar = true, CameraCollision = true,
    CameraRestoreOnDeath = true,

    FaceMode = "Both", FacePriority = "Camera Target",
    FaceRotationSpeed = 0.35, FaceOnlyWhenMoving = false,

    _dodgeTarget = nil,
    _dangerAvoid = Vector3.zero,
    _dangerCount = 0,
    _dangerEscape = false,

    Noclip = false, InfJump = false, AntiAFK = true,
}

--============================================================
-- BOSS KEYWORDS
--============================================================
local BOSS_KEYWORDS = {
    "boss", "lord", "king", "queen", "giant", "titan", "elemental",
    "reaper", "demon", "guardian", "warden", "champion", "warlord",
    "dragon", "golem", "kraken", "hydra", "void", "phantom",
}

local function isBossModel(model)
    if not model then return false end
    local n = model.Name:lower()
    for _, kw in ipairs(BOSS_KEYWORDS) do
        if n:find(kw, 1, true) then return true end
    end
    return false
end

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
-- DANGER SCANNER v2 — SHAPE + MATERIAL DETECTION
--============================================================
local dangerKeywordList = {}
local function refreshKeywords()
    dangerKeywordList = {}
    for k in State.DangerKeywords:gmatch("[^,]+") do
        local trimmed = k:match("^%s*(.-)%s*$"):lower()
        if #trimmed > 0 then table.insert(dangerKeywordList, trimmed) end
    end
end
refreshKeywords()

-- Cek apakah part ini descendant dari karakter player (apapun)
local function isPlayerOwned(part)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and part:IsDescendantOf(plr.Character) then return true end
    end
    return false
end

-- Cek nama di kedalaman parent (boss cast effect sering ada di folder)
local function isInsideBoss(part)
    local parent = part.Parent
    local depth = 0
    while parent and parent ~= workspace and depth < 4 do
        if isBossModel(parent) then return true end
        parent = parent.Parent
        depth = depth + 1
    end
    return false
end

-- Deteksi part berbahaya pakai bentuk + material
local function isDangerousPart(part)
    if not part:IsA("BasePart") then return false end
    if isPlayerOwned(part) then return false end

    local name = part.Name:lower()
    local mat = part.Material
    local transp = part.Transparency
    local size = part.Size

    -- Keyword explicit dulu (paling akurat)
    for _, kw in ipairs(dangerKeywordList) do
        if name:find(kw, 1, true) then return true end
    end

    -- Filter: part dengan ukuran raksasa kemungkinan map, bukan hazard
    if size.X > 400 or size.Y > 300 or size.Z > 400 then return false end

    -- Material detection
    local isNeon = (mat == Enum.Material.Neon)
    local isForceField = (mat == Enum.Material.ForceField)
    local isGlass = (mat == Enum.Material.Glass)
    local isGlowing = (mat == Enum.Material.Neon or mat == Enum.Material.ForceField)
    local isTransparent = (transp >= 0.15 and transp <= 0.95)
    local isSemiTransparent = (transp >= 0.3 and transp <= 0.85)

    -- Shape heuristic (indikator skill di lantai)
    local flatCylinder = false
    local thinBeam = false

    -- Flat cylinder / circle (AOE zone): tebal tipis, radius agak lebar
    if size.Y <= 1.5 and math.max(size.X, size.Z) >= 4 then
        flatCylinder = true
    end

    -- Thin long beam: satu axis panjang, dua axis tipis
    local maxXZ = math.max(size.X, size.Z)
    local minXZ = math.min(size.X, size.Z)
    if maxXZ >= 10 and minXZ <= 2.5 then
        thinBeam = true
    end

    -- Konfigurasi deteksi:
    -- A) Flat cylinder + (Neon / transparan) = AOE zone indicator
    if flatCylinder and (isGlowing or isTransparent) then return true end

    -- B) Thin beam + (Neon / transparan) = laser / line indicator
    if thinBeam and (isGlowing or isTransparent) then return true end

    -- C) Neon / ForceField dengan transparansi sedang, ukuran wajar = effect
    if isGlowing and isSemiTransparent and size.Y < 80 then return true end

    -- D) Bagian dari boss model (child / descendant depth 3)
    if isInsideBoss(part) and (isGlowing or isTransparent) then return true end

    -- E) Part besar yang di Workspace langsung tapi transparan Neon = cast effect
    if part.Parent == workspace and isNeon and isTransparent then return true end

    return false
end

-- Debug: log nama part kalau user mau
local loggedParts = {}
task.spawn(function()
    while task.wait(0.3) do
        if State.ShowDebugNames then
            local hrp = getHRP()
            if hrp then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not loggedParts[obj] then
                        local d = (obj.Position - hrp.Position).Magnitude
                        if d <= State.DangerRadius + 10 and isDangerousPart(obj) then
                            loggedParts[obj] = true
                            print("[PALL-HUB][Indicator] " .. obj.Name ..
                                " | class=" .. obj.ClassName ..
                                " | mat=" .. tostring(obj.Material) ..
                                " | transp=" .. string.format("%.2f", obj.Transparency) ..
                                " | size=" .. tostring(obj.Size))
                        end
                    end
                end
            end
        end
    end
end)

-- Scanner loop
task.spawn(function()
    while task.wait(0.15) do
        if State.AutoDodge and State.DodgeBossSkill then
            local hrp = getHRP()
            if hrp then
                local avoid = Vector3.zero
                local count = 0
                local radius = State.DangerRadius
                local escapeThreat = false

                for _, obj in ipairs(workspace:GetDescendants()) do
                    if isDangerousPart(obj) then
                        local d = (obj.Position - hrp.Position).Magnitude
                        if d <= radius and d > 0.5 then
                            local strength = (radius - d) / radius
                            -- Kalau objek ukuran besar (AOE), paksa escape
                            local sz = obj.Size
                            local maxSize = math.max(sz.X, sz.Y, sz.Z)
                            if maxSize >= 8 or (obj.Material == Enum.Material.Neon and obj.Transparency < 0.7) then
                                escapeThreat = true
                            end
                            avoid = avoid + (hrp.Position - obj.Position).Unit * strength
                            count = count + 1
                        end
                    end
                end

                if count > 0 then
                    State._dangerAvoid = (avoid / count) * State.AvoidStrength
                    State._dangerCount = count
                    State._dangerEscape = escapeThreat or State.EscapeMode
                else
                    State._dangerAvoid = Vector3.zero
                    State._dangerCount = 0
                    State._dangerEscape = false
                end
            end
        else
            State._dangerAvoid = Vector3.zero
            State._dangerCount = 0
            State._dangerEscape = false
        end
    end
end)
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
    Title = "Pall x DUNGEON QUEST REBORN",
    Folder = "pallhubv541",
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

Window:Tag({ Title = "v5.4.1", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: SKILLS
--============================================================
local TabSkills = Window:Tab({
    Title = "Skills", Desc = "Auto Skill Q lalu E",
    Icon = "solar:star-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local sec = TabSkills:Section({ Title = "Auto Skill", Box = true, BoxBorder = true, Opened = true })
    sec:Toggle({ Title = "Auto Skill", Desc = "Otomatis tekan Q lalu E berulang",
        Value = false, Callback = function(v) State.AutoSkill = v end })
    sec:Space()
    sec:Slider({ Title = "Q ke E Delay", Step = 0.1,
        Value = { Min = 0.1, Max = 3, Default = 0.4 },
        Callback = function(v) State.SkillQDelay = v end })
    sec:Space()
    sec:Slider({ Title = "E ke Q Delay", Step = 0.1,
        Value = { Min = 0.1, Max = 5, Default = 0.8 },
        Callback = function(v) State.SkillEDelay = v end })
    sec:Space()
    sec:Toggle({ Title = "Use Remote Fallback", Value = true,
        Callback = function(v) State.UseRemoteFallback = v end })
end

--============================================================
-- TAB: COMBAT
--============================================================
local TabCombat = Window:Tab({
    Title = "Combat", Desc = "Attack dan Aggro",
    Icon = "solar:sword-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local atkSection = TabCombat:Section({ Title = "Auto Attack", Box = true, BoxBorder = true, Opened = true })
    atkSection:Toggle({ Title = "Auto Attack", Value = false, Callback = function(v) State.AutoAttack = v end })
    atkSection:Space()
    atkSection:Slider({ Title = "Attack Range", Step = 1,
        Value = { Min = 5, Max = 60, Default = 25 },
        Callback = function(v) State.AttackRange = v end })
    atkSection:Space()
    atkSection:Slider({ Title = "WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 60, Default = 16 },
        Callback = function(v)
            State.WalkSpeed = v
            local hum = getHum(); if hum then hum.WalkSpeed = v end
        end })

    local aggroSection = TabCombat:Section({ Title = "Auto Aggro", Box = true, BoxBorder = true, Opened = true })
    aggroSection:Toggle({ Title = "Auto Aggro All", Value = false, Callback = function(v) State.AutoAggro = v end })
    aggroSection:Space()
    aggroSection:Slider({ Title = "Aggro Range", Step = 10,
        Value = { Min = 50, Max = 800, Default = 300 },
        Callback = function(v) State.AggroRange = v end })
end

--============================================================
-- TAB: DODGE
--============================================================
local TabDodge = Window:Tab({
    Title = "Dodge", Desc = "Orbit plus Boss Skill Avoidance",
    Icon = "solar:shield-check-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local dodgeSection = TabDodge:Section({ Title = "Auto Dodge Orbit", Box = true, BoxBorder = true, Opened = true })
    dodgeSection:Toggle({ Title = "Auto Dodge", Value = false, Callback = function(v) State.AutoDodge = v end })
    dodgeSection:Space()
    dodgeSection:Slider({ Title = "Detect Range", Step = 1,
        Value = { Min = 10, Max = 100, Default = 40 },
        Callback = function(v) State.DodgeRange = v end })
    dodgeSection:Space()
    dodgeSection:Slider({ Title = "Orbit Radius", Step = 1,
        Value = { Min = 3, Max = 50, Default = 10 },
        Callback = function(v) State.DodgeOrbitRadius = v end })
    dodgeSection:Space()
    dodgeSection:Slider({ Title = "Orbit Speed", Step = 0.5,
        Value = { Min = 0.5, Max = 10, Default = 2 },
        Callback = function(v) State.DodgeOrbitSpeed = v end })
    dodgeSection:Space()
    dodgeSection:Slider({ Title = "Dodge WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 60, Default = 20 },
        Callback = function(v) State.DodgeWalkSpeed = v end })

    local bossAvoidSection = TabDodge:Section({ Title = "Boss Skill Avoidance", Box = true, BoxBorder = true, Opened = true })
    bossAvoidSection:Toggle({ Title = "Dodge Boss Skill", Desc = "Hindari hitbox / AOE / beam indicator",
        Value = true, Callback = function(v) State.DodgeBossSkill = v end })
    bossAvoidSection:Space()
    bossAvoidSection:Slider({ Title = "Danger Radius", Step = 1,
        Value = { Min = 10, Max = 80, Default = 25 },
        Callback = function(v) State.DangerRadius = v end })
    bossAvoidSection:Space()
    bossAvoidSection:Slider({ Title = "Avoid Strength", Step = 0.1,
        Value = { Min = 0.5, Max = 6, Default = 2.5 },
        Callback = function(v) State.AvoidStrength = v end })
    bossAvoidSection:Space()
    bossAvoidSection:Toggle({ Title = "Escape Mode", Desc = "Langsung lari keluar zona saat ada threat besar",
        Value = true, Callback = function(v) State.EscapeMode = v end })
    bossAvoidSection:Space()
    bossAvoidSection:Slider({ Title = "Escape Speed", Step = 1,
        Value = { Min = 30, Max = 80, Default = 45 },
        Callback = function(v) State.EscapeSpeed = v end })
    bossAvoidSection:Space()
    bossAvoidSection:Input({
        Title = "Custom Keywords",
        Desc = "Pisah pakai koma",
        Value = State.DangerKeywords,
        Callback = function(v)
            State.DangerKeywords = v
            refreshKeywords()
        end,
    })
    bossAvoidSection:Space()
    bossAvoidSection:Toggle({
        Title = "Debug: Log Indicator Names",
        Desc = "Print nama part yang ke-detect ke console. Berguna buat report.",
        Value = false,
        Callback = function(v)
            State.ShowDebugNames = v
            if v then loggedParts = {} end
        end,
    })
end

--============================================================
-- TAB: CAMERA
--============================================================
local TabCamera = Window:Tab({
    Title = "Camera", Desc = "Anti nunduk dan follow rotation",
    Icon = "solar:videocamera-record-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local camSection = TabCamera:Section({ Title = "Camera Lock", Box = true, BoxBorder = true, Opened = true })
    camSection:Toggle({ Title = "Lock Camera to Target", Value = false,
        Callback = function(v)
            State.CameraLock = v
            if v then saveOriginalCameraState() else restoreCamera() end
        end })
    camSection:Space()
    camSection:Dropdown({ Title = "Target Mode",
        Values = { "Nearest Enemy", "Nearest Boss" },
        Value = "Nearest Enemy",
        Callback = function(v) State.CameraTargetMode = v end })
    camSection:Space()
    camSection:Slider({ Title = "Camera Distance", Step = 0.5,
        Value = { Min = 3, Max = 25, Default = 8 },
        Callback = function(v) State.CameraDistance = v end })
    camSection:Space()
    camSection:Slider({ Title = "Camera Height", Step = 0.5,
        Value = { Min = 0, Max = 15, Default = 3 },
        Callback = function(v) State.CameraHeight = v end })
    camSection:Space()
    camSection:Slider({ Title = "Smoothness", Step = 0.05,
        Value = { Min = 0.05, Max = 1, Default = 0.25 },
        Callback = function(v) State.CameraSmoothness = v end })

    local fixSection = TabCamera:Section({ Title = "Anti Nunduk Tanah", Box = true, BoxBorder = true, Opened = true })
    fixSection:Slider({ Title = "Min Height clamp Y", Step = 0.5,
        Value = { Min = 0, Max = 8, Default = 2 },
        Callback = function(v) State.CameraMinHeight = v end })
    fixSection:Space()
    fixSection:Toggle({ Title = "Anti Tembus Dinding", Value = true,
        Callback = function(v) State.CameraCollision = v end })
    fixSection:Space()
    fixSection:Toggle({ Title = "Follow Character Rotation", Value = true,
        Callback = function(v) State.CameraFollowChar = v end })
    fixSection:Space()
    fixSection:Toggle({ Title = "Restore on Death", Value = true,
        Callback = function(v) State.CameraRestoreOnDeath = v end })
end

--============================================================
-- TAB: FACE TARGET
--============================================================
local TabFace = Window:Tab({
    Title = "Face Target", Desc = "Rotasi karakter",
    Icon = "solar:user-speak-rounded-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local faceSection = TabFace:Section({ Title = "Face Target Settings", Box = true, BoxBorder = true, Opened = true })
    faceSection:Dropdown({ Title = "Face Mode",
        Values = { "Both", "Camera Only", "Character Only", "Off" },
        Value = "Both",
        Callback = function(v)
            State.FaceMode = v
            if v == "Off" or v == "Camera Only" then
                local hum = getHum(); if hum then hum.AutoRotate = true end
            end
        end })
    faceSection:Space()
    faceSection:Dropdown({ Title = "Target Priority",
        Values = { "Camera Target", "Nearest Enemy", "Nearest Boss", "Dodge Target" },
        Value = "Camera Target",
        Callback = function(v) State.FacePriority = v end })
    faceSection:Space()
    faceSection:Slider({ Title = "Rotasi Speed", Step = 0.05,
        Value = { Min = 0.05, Max = 1, Default = 0.35 },
        Callback = function(v) State.FaceRotationSpeed = v end })
    faceSection:Space()
    faceSection:Toggle({ Title = "Face Only When Moving", Value = false,
        Callback = function(v) State.FaceOnlyWhenMoving = v end })
end

--============================================================
-- TAB: PLAYER
--============================================================
local TabPlayer = Window:Tab({
    Title = "Player", Desc = "Noclip jump anti-afk",
    Icon = "solar:user-bold", IconColor = Grey, IconShape = "Square", Border = true,
})
do
    local pSection = TabPlayer:Section({ Title = "Misc", Box = true, BoxBorder = true, Opened = true })
    pSection:Toggle({ Title = "Noclip", Value = false, Callback = function(v) State.Noclip = v end })
    pSection:Space()
    pSection:Toggle({ Title = "Infinite Jump", Value = false, Callback = function(v) State.InfJump = v end })
    pSection:Space()
    pSection:Toggle({ Title = "Anti-AFK", Value = true, Callback = function(v) State.AntiAFK = v end })
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
--============================================================
-- AUTO DODGE — orbit + face-lock + boss skill escape
--============================================================
local orbitAngle = 0
local faceAlign = nil
local faceAttach = nil

local function ensureAlign()
    local hrp = getHRP(); if not hrp then return end
    if faceAlign and faceAlign.Parent == hrp then return end
    if faceAlign and faceAlign.Parent then faceAlign:Destroy() end
    if faceAttach and faceAttach.Parent then faceAttach:Destroy() end

    faceAttach = Instance.new("Attachment")
    faceAttach.Name = "PallFaceAttach"
    faceAttach.Parent = hrp

    faceAlign = Instance.new("AlignOrientation")
    faceAlign.Name = "PallFaceAlign"
    faceAlign.Mode = Enum.OrientationAlignmentMode.OneAttachment
    faceAlign.Attachment0 = faceAttach
    faceAlign.MaxTorque = 1e6
    faceAlign.MaxAngularVelocity = math.huge
    faceAlign.Responsiveness = 60
    faceAlign.RigidityEnabled = false
    faceAlign.Parent = hrp
end

local function clearAlign()
    if faceAlign and faceAlign.Parent then faceAlign:Destroy() end
    if faceAttach and faceAttach.Parent then faceAttach:Destroy() end
    faceAlign, faceAttach = nil, nil
end

task.spawn(function()
    while task.wait(0.05) do
        if State.AutoDodge then
            local mob = getNearestEnemy(State.DodgeRange)
            if mob then
                State._dodgeTarget = mob
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                local hum = getHum()
                local hrp = getHRP()
                if mhrp and hum and hrp then
                    ensureAlign()
                    orbitAngle = orbitAngle + State.DodgeOrbitSpeed * 0.05

                    local orbitPos = mhrp.Position + Vector3.new(
                        math.cos(orbitAngle) * State.DodgeOrbitRadius, 0,
                        math.sin(orbitAngle) * State.DodgeOrbitRadius
                    )

                    -- Kalau ada danger, prioritize escape
                    if State.DodgeBossSkill and State._dangerCount > 0 then
                        if State._dangerEscape and State.EscapeMode then
                            -- Escape mode: lari keluar zona secepat mungkin
                            hum.WalkSpeed = State.EscapeSpeed
                            local escapeDir = State._dangerAvoid
                            if escapeDir.Magnitude < 0.1 then
                                -- Fallback: hindari dari boss
                                local bhrp = mhrp.Position
                                escapeDir = (hrp.Position - bhrp).Unit * 5
                            end
                            local escapeTarget = hrp.Position + escapeDir.Unit * 12
                            hum:MoveTo(escapeTarget)
                        else
                            -- Blend mode (avoid lembut)
                            orbitPos = orbitPos + State._dangerAvoid
                            hum.WalkSpeed = State.DodgeWalkSpeed
                            hum:MoveTo(orbitPos)
                        end
                    else
                        hum.WalkSpeed = State.DodgeWalkSpeed
                        hum:MoveTo(orbitPos)
                    end

                    hum.AutoRotate = false

                    if faceAlign then
                        local dir = mhrp.Position - hrp.Position
                        local flatDir = Vector3.new(dir.X, 0, dir.Z)
                        if flatDir.Magnitude > 0.1 then
                            faceAlign.CFrame = CFrame.lookAt(Vector3.zero, flatDir.Unit)
                        end
                    end
                end
            else
                State._dodgeTarget = nil
                clearAlign()
                orbitAngle = orbitAngle + 0.5 * 0.05
            end
        else
            clearAlign()
        end
    end
end)

--============================================================
-- AUTO SKILL
--============================================================
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
-- CAMERA + FACE TARGET
--============================================================
RunService.RenderStepped:Connect(function()
    local hrp = getHRP(); if not hrp then return end
    local target = pickFaceTarget()
    if not target then return end
    local tHRP = target:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    local npcPos = tHRP.Position

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

    local desiredPos = hrp.Position - baseDir * State.CameraDistance
        + Vector3.new(0, State.CameraHeight, 0)

    if State.CameraCollision then
        desiredPos = getSafeCameraPos(hrp, desiredPos)
    end

    local minY = hrp.Position.Y + State.CameraMinHeight
    desiredPos = Vector3.new(desiredPos.X, math.max(desiredPos.Y, minY), desiredPos.Z)

    if State.CameraLock then
        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Scriptable
        local lookAtLeveled = Vector3.new(npcPos.X, desiredPos.Y, npcPos.Z)
        local desiredCF = CFrame.lookAt(desiredPos, lookAtLeveled)
        cam.CFrame = cam.CFrame:Lerp(desiredCF, State.CameraSmoothness)
    end

    local faceModeActive = (State.FaceMode == "Both" or State.FaceMode == "Character Only")
    if not State.AutoDodge and faceModeActive then
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
    Title = "Pall Hub v5.4.1",
    Content = "Indicator shape detection + Escape mode aktif.",
    Icon = "solar:bell-bold", Duration = 6,
})

print("[PALL-HUB] v5.4.1 loaded. Indicator detection v2.")
