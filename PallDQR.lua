--[[
    PALL HUB — DUNGEON QUEST REBORN
    Author  : ENI (for Pall)
    Version : v6.1.0
    Notes   : + FPS Booster tab. Config = save/load/delete.
--]]

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService  = game:GetService("PathfindingService")
local HttpService         = game:GetService("HttpService")
local Lighting            = game:GetService("Lighting")
local SoundService        = game:GetService("SoundService")

local LP = Players.LocalPlayer

local WindUI
local ok, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)
if not ok then error("[PALL-HUB] Gagal load WindUI.") end
WindUI = result

local Green  = Color3.fromHex("#10C550")
local Yellow = Color3.fromHex("#ECA201")
local Purple = Color3.fromHex("#7775F2")
local Blue   = Color3.fromHex("#257AF7")
local Grey   = Color3.fromHex("#83889E")

local State = {
    AutoAttack = false, AutoAggro = false,
    AttackRange = 25, AggroRange = 300, WalkSpeed = 16,
    AutoDodge = false, DodgeRange = 40,
    DodgeOrbitRadius = 10, DodgeOrbitSpeed = 2,
    DodgeWalkSpeed = 16, MaxDodgeWalkSpeed = 16,
    DodgeBossSkill = true, DangerRadius = 25, AvoidStrength = 2.5,
    EscapeMode = true,
    DangerKeywords = "hitbox,damage,aoe,attack,skill,zone,hazard,projectile,bullet,orb,explosion,wave,strike,beam,fire,ice,frost,snow,trap,circle,area,indicator,marker,shockwave,elemental,cast,spell,impact,radius,warning,telegraph,laser,line,cone,pulse,sigil",
    ShowDebugNames = false,
    AutoSkill = false, SkillQDelay = 0.4, SkillEDelay = 0.8, UseRemoteFallback = true,
    AutoSpendSkill = false, SkillUpPriority = "Physical Power",
    SkillUpDelay = 0.4, SkillUpCheck = true,
    CameraLock = false, CameraTargetMode = "Nearest Enemy",
    CameraDistance = 8, CameraHeight = 3, CameraSmoothness = 0.25,
    CameraMinHeight = 2, CameraFollowChar = true, CameraCollision = true,
    CameraRestoreOnDeath = true,
    FaceMode = "Both", FacePriority = "Camera Target",
    FaceRotationSpeed = 0.35, FaceOnlyWhenMoving = false,
    AutoUpgrade = false, UpgradeTarget = "Item", UpgradeDelay = 2,
    AutoEquipBest = false, EquipBestType = "Any",
    AutoStart = false, AutoReplay = false, ReplayDelay = 3,
    AutoBestDungeon = false, AutoBestDifficulty = false,
    SelectedDungeon = "Northern Lands", SelectedDifficulty = "Nightmare",
    HardcoreMode = false,
    Noclip = false, InfJump = false, AntiAFK = true,
    -- FPS
    FPSCounter = false, LowTextures = false, RemoveDecals = false,
    RemoveParticles = false, RemoveBeams = false, DisableShadows = false,
    LowTerrain = false, DisableSkybox = false, DisableAtmosphere = false,
    DisableSounds = false, LowMeshFidelity = false, StopAnimations = false,
    BurikTotal = false,
    _dodgeTarget = nil, _dangerAvoid = Vector3.zero,
    _dangerCount = 0, _dangerEscape = false,
}

local R = {
    StartDungeon = "startDungeon", ReplayDungeon = "replayDungeon",
    HostAutoReplay = "hostSetAutoReplay",
    ReloadInventory = "reloadInventory", ReloadInvy = "reloadInvy",
    EquipItem = "equipItem", UnequipItem = "unequipItem", EquipSet = "equipSet",
    UpgradeItem = "upgradeItem", UpgradeKey = "upgradeKey",
    SpendSkillPoint = "spendSkillPoint",
}

local remoteCache = {}
local function resolveRemote(name)
    if remoteCache[name] then return remoteCache[name] end
    local folder = ReplicatedStorage:FindFirstChild("remotes")
    if folder then
        local ev = folder:FindFirstChild(name)
        if ev then remoteCache[name] = ev; return ev end
    end
    local ev = ReplicatedStorage:FindFirstChild(name)
    if ev then remoteCache[name] = ev end
    return ev
end

local function fire(name, ...)
    local ev = resolveRemote(name)
    if ev and (ev:IsA("RemoteEvent") or ev:IsA("RemoteFunction")) then
        local args = {...}
        pcall(function()
            if ev:IsA("RemoteEvent") then
                ev:FireServer(table.unpack(args))
            else
                ev:InvokeServer(table.unpack(args))
            end
        end)
    end
end

local DUNGEONS = {
    { Name = "Pumpkin King", Level = 1 },
    { Name = "Desert Temple", Level = 1 },
    { Name = "Winter Outpost", Level = 33 },
    { Name = "Pirate Island", Level = 65 },
    { Name = "King's Castle", Level = 75 },
    { Name = "The Underworld", Level = 85 },
    { Name = "Samurai Palace", Level = 95 },
    { Name = "The Canals", Level = 105 },
    { Name = "Ghastly Harbor", Level = 115 },
    { Name = "Steampunk Sewers", Level = 125 },
    { Name = "Orbital Outpost", Level = 145 },
    { Name = "Volcanic Chambers", Level = 155 },
    { Name = "Aquatic Temple", Level = 165 },
    { Name = "Enchanted Forest", Level = 175 },
    { Name = "Northern Lands", Level = 185 },
}

local DIFFICULTIES = { "Easy", "Medium", "Hard", "Insane", "Nightmare" }

local function getPlayerLevel()
    local ls = LP:FindFirstChild("leaderstats") or LP:FindFirstChild("Leaderstats")
    if ls then
        local lvl = ls:FindFirstChild("Level")
        if lvl then return lvl.Value end
    end
    return 1
end

local BOSS_KEYWORDS = {
    "boss","lord","king","queen","giant","titan","elemental",
    "reaper","demon","guardian","warden","champion","warlord",
    "dragon","golem","kraken","hydra","void","phantom",
}
local function isBossModel(model)
    if not model then return false end
    local n = model.Name:lower()
    for _, kw in ipairs(BOSS_KEYWORDS) do
        if n:find(kw, 1, true) then return true end
    end
    return false
end

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
    for _, m in ipairs(workspace:GetDescendants()) do
        if isEnemy(m) then
            local mhrp = m:FindFirstChild("HumanoidRootPart")
            if mhrp then
                local d = (mhrp.Position - hrp.Position).Magnitude
                if d < dist then closest, dist = m, d end
            end
        end
    end
    return closest, dist
end

local function getNearestBoss(maxDist)
    local hrp = getHRP(); if not hrp then return nil end
    local closest, dist = nil, maxDist or math.huge
    for _, m in ipairs(workspace:GetDescendants()) do
        if isEnemy(m) and isBossModel(m) then
            local mhrp = m:FindFirstChild("HumanoidRootPart")
            if mhrp then
                local d = (mhrp.Position - hrp.Position).Magnitude
                if d < dist then closest, dist = m, d end
            end
        end
    end
    return closest
end

local function walkWithPath(targetPos, timeout)
    timeout = timeout or 8
    local hrp, hum = getHRP(), getHum()
    if not hrp or not hum then return end
    local path = PathfindingService:CreatePath({
        AgentRadius = 2, AgentHeight = 5, AgentCanJump = true,
        AgentCanClimb = false, WaypointSpacing = 4,
    })
    local okC = pcall(function() path:ComputeAsync(hrp.Position, targetPos) end)
    if not okC or path.Status ~= Enum.PathStatus.Success then
        hum.WalkSpeed = State.WalkSpeed
        hum:MoveTo(targetPos)
        return
    end
    for _, wp in ipairs(path:GetWaypoints()) do
        local cur = getHRP(); if not cur then break end
        if wp.Action == Enum.PathWaypointAction.Jump then
            pcall(function() hum.Jump = true end)
        end
        hum.WalkSpeed = State.WalkSpeed
        hum:MoveTo(wp.Position)
        local t0 = tick()
        while tick() - t0 < 3 do
            local c2 = getHRP(); if not c2 then break end
            if (c2.Position - wp.Position).Magnitude <= 4 then break end
            task.wait(0.08)
        end
    end
end

local dangerKeywordList = {}
local function refreshKeywords()
    dangerKeywordList = {}
    for k in State.DangerKeywords:gmatch("[^,]+") do
        local t = k:match("^%s*(.-)%s*$"):lower()
        if #t > 0 then table.insert(dangerKeywordList, t) end
    end
end
refreshKeywords()

local function isPlayerOwned(part)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and part:IsDescendantOf(plr.Character) then return true end
    end
    return false
end

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

local function isDangerousPart(part)
    if not part:IsA("BasePart") then return false end
    if isPlayerOwned(part) then return false end
    local name = part.Name:lower()
    local mat, transp, size = part.Material, part.Transparency, part.Size
    for _, kw in ipairs(dangerKeywordList) do
        if name:find(kw, 1, true) then return true end
    end
    if size.X > 400 or size.Y > 300 or size.Z > 400 then return false end
    local isNeon = (mat == Enum.Material.Neon)
    local isFF = (mat == Enum.Material.ForceField)
    local isGlow = isNeon or isFF
    local isTrans = (transp >= 0.15 and transp <= 0.95)
    local isSemi = (transp >= 0.3 and transp <= 0.85)
    local flatCyl = (size.Y <= 1.5 and math.max(size.X, size.Z) >= 4)
    local thinBeam = (math.max(size.X, size.Z) >= 10 and math.min(size.X, size.Z) <= 2.5)
    if flatCyl and (isGlow or isTrans) then return true end
    if thinBeam and (isGlow or isTrans) then return true end
    if isGlow and isSemi and size.Y < 80 then return true end
    if isInsideBoss(part) and (isGlow or isTrans) then return true end
    if part.Parent == workspace and isNeon and isTrans then return true end
    return false
end

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
                            local maxSize = math.max(obj.Size.X, obj.Size.Y, obj.Size.Z)
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

local CameraState = { _originalType = nil, _originalAutoRotate = true }
local function saveCamState()
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
    end
    return getNearestEnemy(500)
end

local function getSafeCameraPos(hrp, desiredPos)
    local origin = hrp.Position + Vector3.new(0, 2, 0)
    local dir = desiredPos - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LP.Character}
    params.IgnoreWater = true
    local hit = workspace:Raycast(origin, dir, params)
    if hit then
        local d = math.max((hit.Position - origin).Magnitude - 0.8, 1)
        return origin + dir.Unit * d
    end
    return desiredPos
end

local Window = WindUI:CreateWindow({
    Title = "Pall x DUNGEON QUEST REBORN",
    Folder = "pallhubv610",
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
Window:Tag({ Title = "v6.1.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

-- TAB: SKILLS
local TabSkills = Window:Tab({
    Title = "Skills", Desc = "Auto Skill",
    Icon = "solar:star-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local sec = TabSkills:Section({ Title = "Auto Skill", Box = true, BoxBorder = true, Opened = true })
    sec:Toggle({ Title = "Auto Skill", Value = false, Callback = function(v) State.AutoSkill = v end })
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
-- TAB: SKILL UP
local TabSkillUp = Window:Tab({
    Title = "Skill Up", Desc = "Auto spend skill points",
    Icon = "solar:medal-star-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s1 = TabSkillUp:Section({ Title = "Auto Spend Skill Points", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Spend Skill Points", Value = false, Callback = function(v) State.AutoSpendSkill = v end })
    s1:Space()
    s1:Dropdown({ Title = "Priority Stats",
        Values = { "Physical Power", "Spell Power", "Stamina" },
        Value = "Physical Power",
        Callback = function(v) State.SkillUpPriority = v end })
    s1:Space()
    s1:Slider({ Title = "Delay per Point", Step = 0.05,
        Value = { Min = 0.1, Max = 2, Default = 0.4 },
        Callback = function(v) State.SkillUpDelay = v end })

    local s2 = TabSkillUp:Section({ Title = "Manual", Box = true, BoxBorder = true, Opened = true })
    s2:Button({ Title = "+1 Physical Power", Justify = "Center",
        Callback = function() fire("spendSkillPoint", "physicalPower", 1) end })
    s2:Space()
    s2:Button({ Title = "+1 Spell Power", Justify = "Center",
        Callback = function() fire("spendSkillPoint", "spellPower", 1) end })
    s2:Space()
    s2:Button({ Title = "+1 Stamina", Justify = "Center",
        Callback = function() fire("spendSkillPoint", "stamina", 1) end })
end

-- TAB: COMBAT
local TabCombat = Window:Tab({
    Title = "Combat", Desc = "Attack, Aggro",
    Icon = "solar:sword-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s1 = TabCombat:Section({ Title = "Auto Attack", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Attack", Value = false, Callback = function(v) State.AutoAttack = v end })
    s1:Space()
    s1:Slider({ Title = "Attack Range", Step = 1,
        Value = { Min = 5, Max = 60, Default = 25 },
        Callback = function(v) State.AttackRange = v end })
    s1:Space()
    s1:Slider({ Title = "WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 60, Default = 16 },
        Callback = function(v)
            State.WalkSpeed = v
            local hum = getHum(); if hum then hum.WalkSpeed = v end
        end })

    local s2 = TabCombat:Section({ Title = "Auto Aggro", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Auto Aggro All", Value = false, Callback = function(v) State.AutoAggro = v end })
    s2:Space()
    s2:Slider({ Title = "Aggro Range", Step = 10,
        Value = { Min = 50, Max = 800, Default = 300 },
        Callback = function(v) State.AggroRange = v end })
end
-- TAB: DODGE
local TabDodge = Window:Tab({
    Title = "Dodge", Desc = "Orbit + Boss Avoidance",
    Icon = "solar:shield-check-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local s1 = TabDodge:Section({ Title = "Auto Dodge Orbit", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Dodge", Value = false, Callback = function(v) State.AutoDodge = v end })
    s1:Space()
    s1:Slider({ Title = "Detect Range", Step = 1,
        Value = { Min = 10, Max = 100, Default = 40 },
        Callback = function(v) State.DodgeRange = v end })
    s1:Space()
    s1:Slider({ Title = "Orbit Radius", Step = 1,
        Value = { Min = 3, Max = 50, Default = 10 },
        Callback = function(v) State.DodgeOrbitRadius = v end })
    s1:Space()
    s1:Slider({ Title = "Orbit Speed", Step = 0.5,
        Value = { Min = 0.5, Max = 10, Default = 2 },
        Callback = function(v) State.DodgeOrbitSpeed = v end })
    s1:Space()
    s1:Slider({ Title = "Dodge WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 40, Default = 16 },
        Callback = function(v) State.DodgeWalkSpeed = v; State.MaxDodgeWalkSpeed = v end })

    local s2 = TabDodge:Section({ Title = "Boss Skill Avoidance", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Dodge Boss Skill", Value = true, Callback = function(v) State.DodgeBossSkill = v end })
    s2:Space()
    s2:Slider({ Title = "Danger Radius", Step = 1,
        Value = { Min = 10, Max = 80, Default = 25 },
        Callback = function(v) State.DangerRadius = v end })
    s2:Space()
    s2:Slider({ Title = "Avoid Strength", Step = 0.1,
        Value = { Min = 0.5, Max = 6, Default = 2.5 },
        Callback = function(v) State.AvoidStrength = v end })
    s2:Space()
    s2:Toggle({ Title = "Escape Mode", Value = true, Callback = function(v) State.EscapeMode = v end })
    s2:Space()
    s2:Input({ Title = "Custom Keywords", Value = State.DangerKeywords,
        Callback = function(v) State.DangerKeywords = v; refreshKeywords() end })
    s2:Space()
    s2:Toggle({ Title = "Debug: Log Indicator Names", Value = false,
        Callback = function(v) State.ShowDebugNames = v; if v then loggedParts = {} end end })
end

-- TAB: GEAR
local TabGear = Window:Tab({
    Title = "Gear", Desc = "Upgrade, Equip Best",
    Icon = "solar:bag-4-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s2 = TabGear:Section({ Title = "Auto Upgrade", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Auto Upgrade", Value = false, Callback = function(v) State.AutoUpgrade = v end })
    s2:Space()
    s2:Dropdown({ Title = "Upgrade Target",
        Values = { "Item", "Key", "Both" }, Value = "Item",
        Callback = function(v) State.UpgradeTarget = v end })
    s2:Space()
    s2:Slider({ Title = "Upgrade Delay", Step = 0.5,
        Value = { Min = 1, Max = 15, Default = 2 },
        Callback = function(v) State.UpgradeDelay = v end })
    s2:Space()
    s2:Button({ Title = "Upgrade Item Now", Justify = "Center",
        Callback = function() fire(R.UpgradeItem) end })
    s2:Space()
    s2:Button({ Title = "Upgrade Key Now", Justify = "Center",
        Callback = function() fire(R.UpgradeKey) end })

    local s3 = TabGear:Section({ Title = "Auto Equip Best", Box = true, BoxBorder = true, Opened = true })
    s3:Toggle({ Title = "Auto Equip Best", Value = false,
        Callback = function(v) State.AutoEquipBest = v end })
    s3:Space()
    s3:Dropdown({ Title = "Type Priority",
        Values = { "Any", "ability", "weapon" }, Value = "Any",
        Callback = function(v) State.EquipBestType = v end })
    s3:Space()
    s3:Button({ Title = "Refresh Inventory", Justify = "Center",
        Callback = function()
            fire(R.ReloadInventory); fire(R.ReloadInvy)
            WindUI:Notify({ Title = "Refresh", Content = "Request sent." })
        end })
end
-- TAB: PROGRESSION
local TabProgression = Window:Tab({
    Title = "Progression", Desc = "Dungeon auto start",
    Icon = "solar:chart-2-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local dungeonNames = {}
    for _, d in ipairs(DUNGEONS) do table.insert(dungeonNames, d.Name) end

    local s1 = TabProgression:Section({ Title = "Dungeon Selection", Box = true, BoxBorder = true, Opened = true })
    s1:Dropdown({ Title = "Dungeon",
        Values = dungeonNames, Value = "Northern Lands",
        Callback = function(v) State.SelectedDungeon = v end })
    s1:Space()
    s1:Dropdown({ Title = "Difficulty",
        Values = DIFFICULTIES, Value = "Nightmare",
        Callback = function(v) State.SelectedDifficulty = v end })
    s1:Space()
    s1:Toggle({ Title = "Hardcore Mode", Value = false,
        Callback = function(v) State.HardcoreMode = v end })

    local function clickElement(el)
        if not el then return false end
        local ok2 = pcall(function()
            if getconnections then
                for _, conn in ipairs(getconnections(el.MouseButton1Click)) do
                    conn:Fire()
                end
            elseif firesignal then
                firesignal(el.MouseButton1Click)
            end
        end)
        return ok2
    end

    local function findLabelByName(parent, targetText)
        if not parent then return nil end
        for _, child in ipairs(parent:GetDescendants()) do
            if (child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("ImageButton")) then
                local txt = child.Text or ""
                if txt:lower() == targetText:lower() or txt:lower():find(targetText:lower(), 1, true) then
                    return child
                end
            end
        end
        return nil
    end

    local function doStartDungeon()
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then return false, "PlayerGui tidak ada" end
        local qg = pg:FindFirstChild("queueGui")
        if not qg then return false, "queueGui tidak ada" end

        local dungeonLabel = findLabelByName(qg, State.SelectedDungeon)
        if dungeonLabel then
            clickElement(dungeonLabel)
            if dungeonLabel.Parent then clickElement(dungeonLabel.Parent) end
            task.wait(0.5)
        end

        local diffLabel = findLabelByName(qg, State.SelectedDifficulty)
        if diffLabel then
            clickElement(diffLabel)
            if diffLabel.Parent then clickElement(diffLabel.Parent) end
            task.wait(0.4)
        end

        if State.HardcoreMode then
            local hc = findLabelByName(qg, "Hardcore")
            if hc then clickElement(hc); task.wait(0.3) end
        end

        local createBtn = qg:FindFirstChild("createGame", true)
        if createBtn then clickElement(createBtn) end
        task.wait(1)
        local joinBtn = qg:FindFirstChild("joinGame", true)
        if joinBtn and createBtn == nil then clickElement(joinBtn) end
        task.wait(2)
        local startBtn = qg:FindFirstChild("startButton", true)
        if startBtn then clickElement(startBtn) end

        fire(R.StartDungeon)
        return true, "OK"
    end

    _G.PallStartDungeon = doStartDungeon

    local s2 = TabProgression:Section({ Title = "Auto Flow", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Auto Best Dungeon", Value = false,
        Callback = function(v) State.AutoBestDungeon = v end })
    s2:Space()
    s2:Toggle({ Title = "Auto Best Difficulty", Value = false,
        Callback = function(v) State.AutoBestDifficulty = v end })
    s2:Space()
    s2:Toggle({ Title = "Auto Start", Value = false, Callback = function(v) State.AutoStart = v end })
    s2:Space()
    s2:Toggle({ Title = "Auto Replay", Value = false, Callback = function(v) State.AutoReplay = v end })
    s2:Space()
    s2:Slider({ Title = "Replay Delay", Step = 0.5,
        Value = { Min = 1, Max = 15, Default = 3 },
        Callback = function(v) State.ReplayDelay = v end })
    s2:Space()
    s2:Button({ Title = "Start Now (GUI Auto)", Justify = "Center",
        Callback = function()
            local ok2, msg = doStartDungeon()
            WindUI:Notify({ Title = "Progression",
                Content = ok2 and ("Dungeon start: " .. msg) or ("Gagal: " .. msg) })
        end })
    s2:Space()
    s2:Button({ Title = "Replay Now", Justify = "Center",
        Callback = function()
            fire(R.ReplayDungeon); fire(R.HostAutoReplay, true)
        end })
    s2:Space()
    s2:Button({ Title = "Debug GUI", Justify = "Center",
        Callback = function()
            local pg = LP:FindFirstChild("PlayerGui")
            local qg = pg and pg:FindFirstChild("queueGui")
            if not qg then
                WindUI:Notify({ Title = "Debug", Content = "queueGui tidak ada" })
                return
            end
            print("\n════ queueGui STRUCTURE ════")
            for _, child in ipairs(qg:GetDescendants()) do
                if child:IsA("TextButton") or child:IsA("ImageButton") then
                    print("[BTN] " .. child.Name .. " | Text=" .. tostring(child.Text) .. " | " .. child:GetFullName())
                elseif child:IsA("TextLabel") and child.Text ~= "" then
                    print("[LBL] " .. child.Name .. " | Text=" .. child.Text)
                end
            end
            print("═══════════════════════════")
            WindUI:Notify({ Title = "Debug", Content = "Cek console Delta." })
        end })
end

-- TAB: CAMERA
local TabCamera = Window:Tab({
    Title = "Camera", Desc = "Lock camera",
    Icon = "solar:videocamera-record-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s1 = TabCamera:Section({ Title = "Camera Lock", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Lock Camera to Target", Value = false,
        Callback = function(v)
            State.CameraLock = v
            if v then saveCamState() else restoreCamera() end
        end })
    s1:Space()
    s1:Dropdown({ Title = "Target Mode",
        Values = { "Nearest Enemy", "Nearest Boss" }, Value = "Nearest Enemy",
        Callback = function(v) State.CameraTargetMode = v end })
    s1:Space()
    s1:Slider({ Title = "Camera Distance", Step = 0.5,
        Value = { Min = 3, Max = 25, Default = 8 },
        Callback = function(v) State.CameraDistance = v end })
    s1:Space()
    s1:Slider({ Title = "Camera Height", Step = 0.5,
        Value = { Min = 0, Max = 15, Default = 3 },
        Callback = function(v) State.CameraHeight = v end })
    s1:Space()
    s1:Slider({ Title = "Smoothness", Step = 0.05,
        Value = { Min = 0.05, Max = 1, Default = 0.25 },
        Callback = function(v) State.CameraSmoothness = v end })

    local s2 = TabCamera:Section({ Title = "Anti Nunduk", Box = true, BoxBorder = true, Opened = true })
    s2:Slider({ Title = "Min Height Y", Step = 0.5,
        Value = { Min = 0, Max = 8, Default = 2 },
        Callback = function(v) State.CameraMinHeight = v end })
    s2:Space()
    s2:Toggle({ Title = "Anti Tembus Dinding", Value = true,
        Callback = function(v) State.CameraCollision = v end })
    s2:Space()
    s2:Toggle({ Title = "Follow Character Rotation", Value = true,
        Callback = function(v) State.CameraFollowChar = v end })
    s2:Space()
    s2:Toggle({ Title = "Restore on Death", Value = true,
        Callback = function(v) State.CameraRestoreOnDeath = v end })
end
-- TAB: FACE TARGET
local TabFace = Window:Tab({
    Title = "Face Target", Desc = "Rotasi karakter",
    Icon = "solar:user-speak-rounded-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s = TabFace:Section({ Title = "Face Target Settings", Box = true, BoxBorder = true, Opened = true })
    s:Dropdown({ Title = "Face Mode",
        Values = { "Both", "Camera Only", "Character Only", "Off" }, Value = "Both",
        Callback = function(v) State.FaceMode = v end })
    s:Space()
    s:Dropdown({ Title = "Target Priority",
        Values = { "Camera Target", "Nearest Enemy", "Nearest Boss", "Dodge Target" },
        Value = "Camera Target",
        Callback = function(v) State.FacePriority = v end })
    s:Space()
    s:Slider({ Title = "Rotasi Speed", Step = 0.05,
        Value = { Min = 0.05, Max = 1, Default = 0.35 },
        Callback = function(v) State.FaceRotationSpeed = v end })
    s:Space()
    s:Toggle({ Title = "Face Only When Moving", Value = false,
        Callback = function(v) State.FaceOnlyWhenMoving = v end })
end
--============================================================
-- TAB: FPS BOOST
--============================================================
local TabFPS = Window:Tab({
    Title = "FPS Boost", Desc = "Performa & burik",
    Icon = "solar:cpu-bolt-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    -- FPS Counter UI
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Name = "PallFPSCounter"
    fpsLabel.Size = UDim2.new(0, 120, 0, 30)
    fpsLabel.Position = UDim2.new(0, 10, 0, 10)
    fpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fpsLabel.BackgroundTransparency = 0.4
    fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    fpsLabel.Font = Enum.Font.Code
    fpsLabel.TextSize = 16
    fpsLabel.Text = "FPS: --"
    fpsLabel.Visible = false
    fpsLabel.Parent = LP:WaitForChild("PlayerGui")

    local frames, lastTime = 0, tick()
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        if tick() - lastTime >= 1 then
            if State.FPSCounter then fpsLabel.Text = "FPS: " .. frames end
            frames = 0
            lastTime = tick()
        end
        fpsLabel.Visible = State.FPSCounter
    end)

    -- Cache original values
    local cache = { materials = {}, skybox = nil, atm = nil, shadows = nil, terrain = nil }

    -- LOW TEXTURES
    local function applyLowTextures()
        cache.materials = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not cache.materials[obj] then
                cache.materials[obj] = { mat = obj.Material, ref = obj.Reflectance }
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
            end
            if obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
                obj.Transparency = 1
            end
        end
    end
    local function restoreLowTextures()
        for obj, data in pairs(cache.materials) do
            if obj and obj.Parent then
                obj.Material = data.mat
                obj.Reflectance = data.ref
            end
        end
        cache.materials = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
                obj.Transparency = 0
            end
        end
    end

    -- HIDE DECALS
    local function applyDecals() for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Decal") then o.Transparency = 1 end
    end end
    local function restoreDecals() for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Decal") then o.Transparency = 0 end
    end end

    -- PARTICLES
    local function applyParticles() for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") then
            o.Enabled = false
        end
    end end
    local function restoreParticles() for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") then
            o.Enabled = true
        end
    end end

    -- BEAMS
    local function applyBeams() for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Beam") or o:IsA("Trail") then o.Enabled = false end
    end end
    local function restoreBeams() for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Beam") or o:IsA("Trail") then o.Enabled = true end
    end end

    -- SHADOWS
    local function applyShadows()
        cache.shadows = { g = Lighting.GlobalShadows, s = Lighting.ShadowSoftness }
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
        for _, o in ipairs(workspace:GetDescendants()) do
            if o:IsA("BasePart") then o.CastShadow = false end
        end
    end
    local function restoreShadows()
        Lighting.GlobalShadows = cache.shadows and cache.shadows.g or true
        Lighting.ShadowSoftness = cache.shadows and cache.shadows.s or 0.2
        for _, o in ipairs(workspace:GetDescendants()) do
            if o:IsA("BasePart") then o.CastShadow = true end
        end
    end

    -- TERRAIN
    local function applyTerrain()
        local T = workspace.Terrain
        cache.terrain = { w1=T.WaterWaveSize, w2=T.WaterWaveSpeed, w3=T.WaterReflectance, w4=T.WaterTransparency }
        T.WaterWaveSize = 0; T.WaterWaveSpeed = 0
        T.WaterReflectance = 0; T.WaterTransparency = 1
        T.Decoration = false
    end
    local function restoreTerrain()
        local T = workspace.Terrain
        if cache.terrain then
            T.WaterWaveSize = cache.terrain.w1; T.WaterWaveSpeed = cache.terrain.w2
            T.WaterReflectance = cache.terrain.w3; T.WaterTransparency = cache.terrain.w4
        end
        T.Decoration = true
    end

    -- SKYBOX
    local function applySkybox()
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then
            cache.skybox = { b=sky.SkyboxBk, d=sky.SkyboxDn, f=sky.SkyboxFt, l=sky.SkyboxLf, r=sky.SkyboxRt, u=sky.SkyboxUp }
            sky.SkyboxBk=""; sky.SkyboxDn=""; sky.SkyboxFt=""
            sky.SkyboxLf=""; sky.SkyboxRt=""; sky.SkyboxUp=""
        end
    end
    local function restoreSkybox()
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky and cache.skybox then
            sky.SkyboxBk=cache.skybox.b; sky.SkyboxDn=cache.skybox.d
            sky.SkyboxFt=cache.skybox.f; sky.SkyboxLf=cache.skybox.l
            sky.SkyboxRt=cache.skybox.r; sky.SkyboxUp=cache.skybox.u
        end
    end

    -- ATMOSPHERE
    local function applyAtmosphere()
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then
            cache.atm = { d=atm.Density, h=atm.Haze, g=atm.Glare }
            atm.Density = 0; atm.Haze = 0; atm.Glare = 0
        end
    end
    local function restoreAtmosphere()
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm and cache.atm then
            atm.Density = cache.atm.d; atm.Haze = cache.atm.h; atm.Glare = cache.atm.g
        end
    end

    -- SOUNDS
    local function applySounds() for _, o in ipairs(game:GetDescendants()) do
        if o:IsA("Sound") then o.Volume = 0 end
    end end
    local function restoreSounds() for _, o in ipairs(game:GetDescendants()) do
        if o:IsA("Sound") then o.Volume = 0.5 end
    end end

    -- MESH
    local function applyMesh() for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("MeshPart") then
            pcall(function() o.RenderFidelity = Enum.RenderFidelity.Performance end)
            o.CastShadow = false
        end
    end end
    local function restoreMesh() for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("MeshPart") then
            pcall(function() o.RenderFidelity = Enum.RenderFidelity.Automatic end)
            o.CastShadow = true
        end
    end end

    local s1 = TabFPS:Section({ Title = "Info", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Show FPS Counter", Value = false,
        Callback = function(v) State.FPSCounter = v end })

    local s2 = TabFPS:Section({ Title = "Performance", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Low Textures (burik)", Value = false,
        Callback = function(v) State.LowTextures = v
            if v then applyLowTextures() else restoreLowTextures() end end })
    s2:Space()
    s2:Toggle({ Title = "Hide Decals", Value = false,
        Callback = function(v) State.RemoveDecals = v
            if v then applyDecals() else restoreDecals() end end })
    s2:Space()
    s2:Toggle({ Title = "Disable Particles", Value = false,
        Callback = function(v) State.RemoveParticles = v
            if v then applyParticles() else restoreParticles() end end })
    s2:Space()
    s2:Toggle({ Title = "Disable Beams & Trails", Value = false,
        Callback = function(v) State.RemoveBeams = v
            if v then applyBeams() else restoreBeams() end end })
    s2:Space()
    s2:Toggle({ Title = "Disable Shadows", Value = false,
        Callback = function(v) State.DisableShadows = v
            if v then applyShadows() else restoreShadows() end end })
    s2:Space()
    s2:Toggle({ Title = "Low Terrain", Value = false,
        Callback = function(v) State.LowTerrain = v
            if v then applyTerrain() else restoreTerrain() end end })
    s2:Space()
    s2:Toggle({ Title = "Disable Skybox", Value = false,
        Callback = function(v) State.DisableSkybox = v
            if v then applySkybox() else restoreSkybox() end end })
    s2:Space()
    s2:Toggle({ Title = "Disable Atmosphere", Value = false,
        Callback = function(v) State.DisableAtmosphere = v
            if v then applyAtmosphere() else restoreAtmosphere() end end })
    s2:Space()
    s2:Toggle({ Title = "Mute All Sounds", Value = false,
        Callback = function(v) State.DisableSounds = v
            if v then applySounds() else restoreSounds() end end })
    s2:Space()
    s2:Toggle({ Title = "Low Mesh Fidelity", Value = false,
        Callback = function(v) State.LowMeshFidelity = v
            if v then applyMesh() else restoreMesh() end end })

    local s3 = TabFPS:Section({ Title = "Master", Box = true, BoxBorder = true, Opened = true })
    s3:Toggle({ Title = "BURIK TOTAL MODE",
        Desc = "Semua efek dimatikan sekaligus",
        Value = false,
        Callback = function(v)
            State.BurikTotal = v
            if v then
                applyLowTextures(); applyDecals(); applyParticles(); applyBeams()
                applyShadows(); applyTerrain(); applySkybox(); applyAtmosphere(); applyMesh()
                WindUI:Notify({ Title = "Burik Total", Content = "Semua efek visual dimatikan." })
            else
                restoreLowTextures(); restoreDecals(); restoreParticles(); restoreBeams()
                restoreShadows(); restoreTerrain(); restoreSkybox(); restoreAtmosphere(); restoreMesh()
                WindUI:Notify({ Title = "Burik Total", Content = "Restore efek visual." })
            end
        end })
    s3:Space()
    s3:Button({ Title = "Reset Semua ke Normal", Justify = "Center",
        Callback = function()
            restoreLowTextures(); restoreDecals(); restoreParticles(); restoreBeams()
            restoreShadows(); restoreTerrain(); restoreSkybox(); restoreAtmosphere(); restoreMesh()
            restoreSounds()
            WindUI:Notify({ Title = "Reset", Content = "Semua efek visual kembali normal." })
        end })
end
-- TAB: CONFIG
local TabConfig = Window:Tab({
    Title = "Config", Desc = "Save, Load, Delete",
    Icon = "solar:folder-with-files-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local CONFIG_FILE = "pallhub_config.json"
    local function fileExists(name) return isfile and isfile(name) end

    local function saveConfig()
        if not writefile then
            WindUI:Notify({ Title = "Config", Content = "writefile tidak tersedia." })
            return
        end
        local clean = {}
        for k, v in pairs(State) do
            if type(v) ~= "table" and type(v) ~= "function" and k:sub(1,1) ~= "_" then
                clean[k] = v
            end
        end
        local okJ, json = pcall(function() return HttpService:JSONEncode(clean) end)
        if not okJ then
            WindUI:Notify({ Title = "Config", Content = "Gagal encode JSON." })
            return
        end
        local okW = pcall(writefile, CONFIG_FILE, json)
        if okW then
            WindUI:Notify({ Title = "Config Saved", Content = "Setting tersimpan." })
        else
            WindUI:Notify({ Title = "Config", Content = "Gagal simpan." })
        end
    end

    local function loadConfig()
        if not readfile then
            WindUI:Notify({ Title = "Config", Content = "readfile tidak tersedia." })
            return
        end
        local okR, raw = pcall(readfile, CONFIG_FILE)
        if not okR or not raw or raw == "" then
            WindUI:Notify({ Title = "Config", Content = "Belum ada config." })
            return
        end
        local okJ, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not okJ or type(data) ~= "table" then
            WindUI:Notify({ Title = "Config", Content = "Config rusak." })
            return
        end
        local count = 0
        for k, v in pairs(data) do
            if State[k] ~= nil then
                State[k] = v
                count = count + 1
            end
        end
        WindUI:Notify({ Title = "Config Loaded", Content = count .. " setting dimuat." })
    end

    local function deleteConfig()
        if not delfile then
            WindUI:Notify({ Title = "Config", Content = "delfile tidak tersedia." })
            return
        end
        if not fileExists(CONFIG_FILE) then
            WindUI:Notify({ Title = "Config", Content = "Belum ada config." })
            return
        end
        local okD = pcall(delfile, CONFIG_FILE)
        if okD then
            WindUI:Notify({ Title = "Config Deleted", Content = "Setting dihapus." })
        else
            WindUI:Notify({ Title = "Config", Content = "Gagal hapus." })
        end
    end

    local s = TabConfig:Section({ Title = "Config Manager", Box = true, BoxBorder = true, Opened = true })
    s:Button({ Title = "Save Current Settings", Justify = "Center", Callback = saveConfig })
    s:Space()
    s:Button({ Title = "Load Saved Settings", Justify = "Center", Callback = loadConfig })
    s:Space()
    s:Button({ Title = "Delete Saved Settings", Justify = "Center", Callback = deleteConfig })
    s:Space()
    s:Button({ Title = "Check Config Status", Justify = "Center",
        Callback = function()
            if fileExists(CONFIG_FILE) then
                WindUI:Notify({ Title = "Config", Content = "Config TERSEDIA." })
            else
                WindUI:Notify({ Title = "Config", Content = "Config KOSONG." })
            end
        end })
end
-- TAB: PLAYER
local TabPlayer = Window:Tab({
    Title = "Player", Desc = "Misc",
    Icon = "solar:user-bold", IconColor = Grey, IconShape = "Square", Border = true,
})
do
    local s = TabPlayer:Section({ Title = "Misc", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Noclip", Value = false, Callback = function(v) State.Noclip = v end })
    s:Space()
    s:Toggle({ Title = "Infinite Jump", Value = false, Callback = function(v) State.InfJump = v end })
    s:Space()
    s:Toggle({ Title = "Anti-AFK", Value = true, Callback = function(v) State.AntiAFK = v end })
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
                for _, m in ipairs(workspace:GetDescendants()) do
                    if isEnemy(m) then
                        local mhrp = m:FindFirstChild("HumanoidRootPart")
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
                    if (cur.Position - t.hrp.Position).Magnitude > 6 then
                        walkWithPath(t.hrp.Position, 6)
                    end
                end
            end
        end
    end
end)

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
                    local targetPos = orbitPos
                    local moveSpeed = State.DodgeWalkSpeed
                    if State.DodgeBossSkill and State._dangerCount > 0 then
                        if State._dangerEscape and State.EscapeMode then
                            local escapeDir = State._dangerAvoid
                            if escapeDir.Magnitude < 0.1 then
                                escapeDir = (hrp.Position - mhrp.Position).Unit * 5
                            end
                            targetPos = hrp.Position + escapeDir.Unit * 8
                        else
                            targetPos = orbitPos + State._dangerAvoid
                        end
                    end
                    moveSpeed = math.min(moveSpeed, State.MaxDodgeWalkSpeed)
                    hum.AutoRotate = false
                    hum.WalkSpeed = moveSpeed
                    hum:MoveTo(targetPos)
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

local SKILL_MAP = {
    ["Physical Power"] = "physicalPower",
    ["Spell Power"]    = "spellPower",
    ["Stamina"]        = "stamina",
}
task.spawn(function()
    while task.wait(State.SkillUpDelay or 0.4) do
        if State.AutoSpendSkill then
            local remoteKey = SKILL_MAP[State.SkillUpPriority or "Physical Power"] or "physicalPower"
            fire("spendSkillPoint", remoteKey, 1)
        end
    end
end)

task.spawn(function()
    while task.wait(State.UpgradeDelay or 2) do
        if State.AutoUpgrade then
            if State.UpgradeTarget == "Item" or State.UpgradeTarget == "Both" then
                fire(R.UpgradeItem)
            end
            if State.UpgradeTarget == "Key" or State.UpgradeTarget == "Both" then
                fire(R.UpgradeKey)
            end
        end
    end
end)

local function getToolStat(tool, statName)
    local child = tool:FindFirstChild(statName)
    if child and child:IsA("ValueBase") then return child.Value end
    return nil
end

task.spawn(function()
    while task.wait(3) do
        if State.AutoEquipBest then
            local bp = LP:FindFirstChild("Backpack")
            if bp then
                local bestTool, bestScore = nil, -1
                for _, tool in ipairs(bp:GetChildren()) do
                    if tool:IsA("Tool") then
                        local typ = getToolStat(tool, "type") or ""
                        if State.EquipBestType == "Any" or typ == State.EquipBestType then
                            local dmg = tonumber(getToolStat(tool, "damage")) or 0
                            local rarity = tostring(getToolStat(tool, "rarity") or "common"):lower()
                            local rarityBonus = 0
                            if rarity == "mythic" or rarity == "ultimate" then rarityBonus = 500
                            elseif rarity == "legendary" then rarityBonus = 300
                            elseif rarity == "epic" then rarityBonus = 150
                            elseif rarity == "rare" then rarityBonus = 80
                            elseif rarity == "uncommon" then rarityBonus = 30 end
                            local score = dmg + rarityBonus
                            if score > bestScore then bestScore, bestTool = score, tool end
                        end
                    end
                end
                if bestTool then fire(R.EquipItem, bestTool) end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(3) do
        if State.AutoBestDungeon then
            local lvl = getPlayerLevel()
            local best = DUNGEONS[1]
            for _, d in ipairs(DUNGEONS) do
                if lvl >= d.Level then best = d end
            end
            State.SelectedDungeon = best.Name
        end
    end
end)

task.spawn(function()
    while task.wait(8) do
        if State.AutoStart then
            if _G.PallStartDungeon then
                local ok2, msg = _G.PallStartDungeon()
                print("[PALL-HUB] Auto Start:", ok2, msg)
            end
            task.wait(15)
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if State.AutoReplay then
            task.wait(State.ReplayDelay)
            fire(R.ReplayDungeon)
            fire(R.HostAutoReplay, true)
        end
    end
end)

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

    local faceActive = (State.FaceMode == "Both" or State.FaceMode == "Character Only")
    if not State.AutoDodge and faceActive then
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
            saveCamState()
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
    Title = "Pall Hub v6.1.0",
    Content = "FPS Booster tab ditambahkan.",
    Icon = "solar:bell-bold", Duration = 6,
})

print("[PALL-HUB] v6.1.0 loaded.")
