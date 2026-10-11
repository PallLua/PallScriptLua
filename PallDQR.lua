--[[
    PALL HUB — v6.0.0
    Changes:
      - Lobby tab DIHAPUS
      - Progression: 15 dungeon + 6 difficulty + Auto Best
      - Gear: Auto Sell / Upgrade / Equip Best beneran baca stats
    Author : ENI (for Pall)
--]]

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService  = game:GetService("PathfindingService")
local HttpService         = game:GetService("HttpService")

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

--============================================================
-- STATE
--============================================================
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

    CameraLock = false, CameraTargetMode = "Nearest Enemy",
    CameraDistance = 8, CameraHeight = 3, CameraSmoothness = 0.25,
    CameraMinHeight = 2, CameraFollowChar = true, CameraCollision = true,
    CameraRestoreOnDeath = true,

    FaceMode = "Both", FacePriority = "Camera Target",
    FaceRotationSpeed = 0.35, FaceOnlyWhenMoving = false,

    -- GEAR
    AutoSell = false, SellRarity = "common", SellType = "ability",
    SellIncludeEquipped = false, SellDelay = 0.3, SellMaxPrice = 99999,
    KeepEquipped = true,
    AutoUpgrade = false, UpgradeTarget = "Item", UpgradeDelay = 2,
    AutoEquipBest = false, EquipBestType = "ability",

    -- PROGRESSION
    AutoStart = false, AutoReplay = false, ReplayDelay = 3,
    AutoBestDungeon = false, AutoBestDifficulty = false,
    SelectedDungeon = "Northern Lands", SelectedDifficulty = "Nightmare",
    HardcoreMode = false,

    Noclip = false, InfJump = false, AntiAFK = true,

    _dodgeTarget = nil, _dangerAvoid = Vector3.zero,
    _dangerCount = 0, _dangerEscape = false,
}
--============================================================
-- REMOTES
--============================================================
local R = {
    StartDungeon = "startDungeon", ReplayDungeon = "replayDungeon",
    HostAutoReplay = "hostSetAutoReplay",
    ReloadInventory = "reloadInventory", ReloadInvy = "reloadInvy",
    EquipItem = "equipItem", UnequipItem = "unequipItem", EquipSet = "equipSet",
    SellItem = "sellItemEvent", OpenSellShop = "openSellShop",
    UpgradeItem = "upgradeItem", UpgradeKey = "upgradeKey",
    MoveItemToInventory = "moveItemToInventory",
    SwapEquippedToInvy = "swapEquippedToInvy",
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
--============================================================
-- DUNGEON DATA
--============================================================
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
--============================================================
-- BOSS + UTILITY
--============================================================
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
--============================================================
-- DANGER SCANNER
--============================================================
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
--============================================================
-- CAMERA HELPERS
--============================================================
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

--============================================================
-- WINDOW
--============================================================
local Window = WindUI:CreateWindow({
    Title = "Pall x DUNGEON QUEST REBORN",
    Folder = "pallhubv600",
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
Window:Tag({ Title = "v6.0.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: SKILLS
--============================================================
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
--============================================================
-- TAB: COMBAT
--============================================================
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

--============================================================
-- TAB: DODGE
--============================================================
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
        Callback = function(v)
            State.DodgeWalkSpeed = v
            State.MaxDodgeWalkSpeed = v
        end })

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
    s2:Input({
        Title = "Custom Keywords",
        Value = State.DangerKeywords,
        Callback = function(v) State.DangerKeywords = v; refreshKeywords() end,
    })
end
--============================================================
-- TAB: GEAR (REBUILT)
--============================================================
local TabGear = Window:Tab({
    Title = "Gear", Desc = "Sell, Upgrade, Equip",
    Icon = "solar:bag-4-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    -- Fungsi baca stats tool
    local function getToolStat(tool, statName)
        local child = tool:FindFirstChild(statName)
        if child and child:IsA("ValueBase") then return child.Value end
        return nil
    end

    -- AUTO SELL
    local s1 = TabGear:Section({ Title = "Auto Sell", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({
        Title = "Auto Sell",
        Desc = "Jual tool sesuai rarity & type",
        Value = false, Callback = function(v) State.AutoSell = v end,
    })
    s1:Space()
    s1:Dropdown({
        Title = "Sell Rarity",
        Values = { "Any", "common", "uncommon", "rare", "epic", "legendary", "mythic", "ultimate" },
        Value = "common",
        Callback = function(v) State.SellRarity = v end,
    })
    s1:Space()
    s1:Dropdown({
        Title = "Sell Type",
        Values = { "Any", "ability", "weapon", "armor", "accessory" },
        Value = "ability",
        Callback = function(v) State.SellType = v end,
    })
    s1:Space()
    s1:Slider({
        Title = "Sell Delay", Step = 0.1,
        Value = { Min = 0.1, Max = 3, Default = 0.3 },
        Callback = function(v) State.SellDelay = v end,
    })
    s1:Space()
    s1:Toggle({
        Title = "Keep Equipped",
        Value = true, Callback = function(v) State.KeepEquipped = v end,
    })
    s1:Space()
    s1:Button({
        Title = "Sell Now", Justify = "Center",
        Callback = function()
            local bp = LP:FindFirstChild("Backpack")
            if not bp then return end
            local count = 0
            for _, tool in ipairs(bp:GetChildren()) do
                if tool:IsA("Tool") then
                    local rarity = getToolStat(tool, "rarity") or ""
                    local typ = getToolStat(tool, "type") or ""
                    local matchR = (State.SellRarity == "Any") or (rarity == State.SellRarity)
                    local matchT = (State.SellType == "Any") or (typ == State.SellType)
                    if matchR and matchT then
                        fire(R.SellItem, tool)
                        count = count + 1
                        task.wait(State.SellDelay)
                    end
                end
            end
            WindUI:Notify({ Title = "Sell Now", Content = "Mencoba jual " .. count .. " item." })
        end,
    })
    s1:Space()
    s1:Button({
        Title = "Open Sell Shop", Justify = "Center",
        Callback = function() fire(R.OpenSellShop) end,
    })

    -- AUTO UPGRADE
    local s2 = TabGear:Section({ Title = "Auto Upgrade", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({
        Title = "Auto Upgrade",
        Desc = "Upgrade item / key otomatis",
        Value = false, Callback = function(v) State.AutoUpgrade = v end,
    })
    s2:Space()
    s2:Dropdown({
        Title = "Upgrade Target",
        Values = { "Item", "Key", "Both" },
        Value = "Item",
        Callback = function(v) State.UpgradeTarget = v end,
    })
    s2:Space()
    s2:Slider({
        Title = "Upgrade Delay", Step = 0.5,
        Value = { Min = 1, Max = 15, Default = 2 },
        Callback = function(v) State.UpgradeDelay = v end,
    })
    s2:Space()
    s2:Button({
        Title = "Upgrade Item Now", Justify = "Center",
        Callback = function() fire(R.UpgradeItem) end,
    })
    s2:Space()
    s2:Button({
        Title = "Upgrade Key Now", Justify = "Center",
        Callback = function() fire(R.UpgradeKey) end,
    })

    -- AUTO EQUIP BEST
    local s3 = TabGear:Section({ Title = "Auto Equip Best", Box = true, BoxBorder = true, Opened = true })
    s3:Toggle({
        Title = "Auto Equip Best",
        Desc = "Equip tool dengan damage tertinggi",
        Value = false, Callback = function(v) State.AutoEquipBest = v end,
    })
    s3:Space()
    s3:Dropdown({
        Title = "Type Priority",
        Values = { "Any", "ability", "weapon" },
        Value = "Any",
        Callback = function(v) State.EquipBestType = v end,
    })
    s3:Space()
    s3:Button({
        Title = "Refresh Inventory", Justify = "Center",
        Callback = function()
            fire(R.ReloadInventory)
            fire(R.ReloadInvy)
            WindUI:Notify({ Title = "Refresh", Content = "Request sent." })
        end,
    })
end
--============================================================
-- TAB: PROGRESSION (REBUILT)
--============================================================
local TabProgression = Window:Tab({
    Title = "Progression", Desc = "Dungeon auto start",
    Icon = "solar:chart-2-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    -- Dropdown pilih dungeon
    local dungeonNames = {}
    for _, d in ipairs(DUNGEONS) do table.insert(dungeonNames, d.Name) end

    local s1 = TabProgression:Section({ Title = "Dungeon Selection", Box = true, BoxBorder = true, Opened = true })
    s1:Dropdown({
        Title = "Dungeon",
        Values = dungeonNames,
        Value = "Northern Lands",
        Callback = function(v) State.SelectedDungeon = v end,
    })
    s1:Space()
    s1:Dropdown({
        Title = "Difficulty",
        Values = DIFFICULTIES,
        Value = "Nightmare",
        Callback = function(v) State.SelectedDifficulty = v end,
    })
    s1:Space()
    s1:Toggle({
        Title = "Hardcore Mode",
        Value = false, Callback = function(v) State.HardcoreMode = v end,
    })

    local s2 = TabProgression:Section({ Title = "Auto Flow", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({
        Title = "Auto Best Dungeon",
        Desc = "Pilih dungeon tertinggi yang kamu bisa masuk",
        Value = false, Callback = function(v) State.AutoBestDungeon = v end,
    })
    s2:Space()
    s2:Toggle({
        Title = "Auto Best Difficulty",
        Value = false, Callback = function(v) State.AutoBestDifficulty = v end,
    })
    s2:Space()
    s2:Toggle({
        Title = "Auto Start",
        Value = false, Callback = function(v) State.AutoStart = v end,
    })
    s2:Space()
    s2:Toggle({
        Title = "Auto Replay",
        Value = false, Callback = function(v) State.AutoReplay = v end,
    })
    s2:Space()
    s2:Slider({
        Title = "Replay Delay", Step = 0.5,
        Value = { Min = 1, Max = 15, Default = 3 },
        Callback = function(v) State.ReplayDelay = v end,
    })
    s2:Space()
    s2:Button({
        Title = "Start Now (via GUI)", Justify = "Center",
        Callback = function()
            local pg = LP:FindFirstChild("PlayerGui")
            if pg then
                local qg = pg:FindFirstChild("queueGui")
                if qg then
                    local startBtn = qg:FindFirstChild("startButton", true)
                    if startBtn and startBtn:IsA("TextButton") then
                        pcall(function()
                            for _, conn in ipairs(getconnections(startBtn.MouseButton1Click)) do
                                conn:Fire()
                            end
                        end)
                    end
                end
            end
            fire(R.StartDungeon)
        end,
    })
    s2:Space()
    s2:Button({
        Title = "Replay Now", Justify = "Center",
        Callback = function()
            fire(R.ReplayDungeon)
            fire(R.HostAutoReplay, true)
        end,
    })
end
--============================================================
-- TAB: CAMERA
--============================================================
local TabCamera = Window:Tab({
    Title = "Camera", Desc = "Lock camera",
    Icon = "solar:videocamera-record-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s1 = TabCamera:Section({ Title = "Camera Lock", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({
        Title = "Lock Camera to Target", Value = false,
        Callback = function(v)
            State.CameraLock = v
            if v then saveCamState() else restoreCamera() end
        end,
    })
    s1:Space()
    s1:Dropdown({ Title = "Target Mode",
        Values = { "Nearest Enemy", "Nearest Boss" },
        Value = "Nearest Enemy",
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
--============================================================
-- TAB: FACE TARGET
--============================================================
local TabFace = Window:Tab({
    Title = "Face Target", Desc = "Rotasi karakter",
    Icon = "solar:user-speak-rounded-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s = TabFace:Section({ Title = "Face Target Settings", Box = true, BoxBorder = true, Opened = true })
    s:Dropdown({ Title = "Face Mode",
        Values = { "Both", "Camera Only", "Character Only", "Off" },
        Value = "Both",
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
-- TAB: CONFIG
--============================================================
local TabConfig = Window:Tab({
    Title = "Config", Desc = "Preset, Export, Import",
    Icon = "solar:folder-with-files-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local presets = {
        Physical = { DodgeOrbitRadius = 8, DodgeOrbitSpeed = 3, AttackRange = 20 },
        DesertTemple = { DodgeOrbitRadius = 12, DodgeOrbitSpeed = 2.5, DangerRadius = 30 },
        WinterOutpost = { DodgeOrbitRadius = 10, DodgeOrbitSpeed = 2, DangerRadius = 30, AvoidStrength = 3 },
        PirateIsland = { DodgeOrbitRadius = 14, DodgeOrbitSpeed = 2, AttackRange = 30 },
        KingsCastle = { DodgeOrbitRadius = 10, DodgeOrbitSpeed = 3, DangerRadius = 28, AvoidStrength = 3 },
        TheUnderworld = { DodgeOrbitRadius = 15, DodgeOrbitSpeed = 2, DangerRadius = 35 },
        NorthernLands = { DodgeOrbitRadius = 12, DodgeOrbitSpeed = 2.5, DangerRadius = 32 },
    }

    local s1 = TabConfig:Section({ Title = "Presets", Box = true, BoxBorder = true, Opened = true })
    for name, data in pairs(presets) do
        s1:Button({
            Title = "Load: " .. name, Justify = "Center",
            Callback = function()
                for k, v in pairs(data) do
                    if State[k] ~= nil then State[k] = v end
                end
                WindUI:Notify({ Title = "Preset Loaded", Content = name .. " dimuat." })
            end,
        })
        s1:Space()
    end

    local s2 = TabConfig:Section({ Title = "Export / Import", Box = true, BoxBorder = true, Opened = true })
    s2:Button({
        Title = "Export Config (Copy)", Justify = "Center",
        Callback = function()
            local clean = {}
            for k, v in pairs(State) do
                if type(v) ~= "table" and type(v) ~= "function" then clean[k] = v end
            end
            local json = HttpService:JSONEncode(clean)
            if setclipboard then setclipboard(json) end
            WindUI:Notify({ Title = "Export", Content = "Config copied." })
        end,
    })
    s2:Space()
    s2:Button({
        Title = "Import Config (Paste)", Justify = "Center",
        Callback = function()
            local raw = getclipboard and getclipboard() or ""
            local okJ, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if okJ and type(data) == "table" then
                for k, v in pairs(data) do
                    if State[k] ~= nil then State[k] = v end
                end
                WindUI:Notify({ Title = "Import", Content = "Config dimuat." })
            else
                WindUI:Notify({ Title = "Import", Content = "Config tidak valid." })
            end
        end,
    })
end
--============================================================
-- TAB: PLAYER
--============================================================
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

-- AUTO ATTACK
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

-- AUTO AGGRO
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

-- AUTO DODGE
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
-- AUTO SELL LOOP
--============================================================
local function getToolStat(tool, statName)
    local child = tool:FindFirstChild(statName)
    if child and child:IsA("ValueBase") then return child.Value end
    return nil
end

task.spawn(function()
    while task.wait(2) do
        if State.AutoSell then
            local bp = LP:FindFirstChild("Backpack")
            if bp then
                local equipped = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
                for _, tool in ipairs(bp:GetChildren()) do
                    if tool:IsA("Tool") then
                        local skip = State.KeepEquipped and equipped and tool.Name == equipped.Name
                        if not skip then
                            local rarity = getToolStat(tool, "rarity") or ""
                            local typ = getToolStat(tool, "type") or ""
                            local matchR = (State.SellRarity == "Any") or (rarity == State.SellRarity)
                            local matchT = (State.SellType == "Any") or (typ == State.SellType)
                            if matchR and matchT then
                                fire(R.SellItem, tool)
                                task.wait(State.SellDelay)
                            end
                        end
                    end
                end
            end
        end
    end
end)
--============================================================
-- AUTO UPGRADE LOOP
--============================================================
task.spawn(function()
    while task.wait(State.UpgradeDelay) do
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
--============================================================
-- AUTO EQUIP BEST LOOP
--============================================================
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
                            if score > bestScore then
                                bestScore, bestTool = score, tool
                            end
                        end
                    end
                end
                if bestTool then
                    fire(R.EquipItem, bestTool)
                end
            end
        end
    end
end)
--============================================================
-- PROGRESSION LOOPS
--============================================================
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
-- Helper: klik tombol/label GUI beneran
local function clickGuiElement(el)
    if not el then return false end
    if el:IsA("TextButton") or el:IsA("ImageButton") then
        local ok = pcall(function()
            for _, conn in ipairs(getconnections(el.MouseButton1Click)) do
                conn:Fire()
            end
        end)
        if ok then return true end
        -- Fallback: pake firesignal
        pcall(function() firesignal(el.MouseButton1Click) end)
        return true
    end
    return false
end

-- Helper: cari label di dalam folder dengan text match
local function findLabelByText(parent, text)
    for _, child in ipairs(parent:GetDescendants()) do
        if (child:IsA("TextLabel") or child:IsA("TextButton"))
            and child.Text and child.Text:lower():find(text:lower(), 1, true) then
            return child
        end
    end
    return nil
end

-- Fungsi utama: pilih dungeon + difficulty + start
local function startDungeonViaGui(dungeonName, difficulty, hardcore)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return false end
    local qg = pg:FindFirstChild("queueGui")
    if not qg then return false end

    -- Cari folder chooseDungeon yang isinya label dungeon
    local chooseDungeon = qg:FindFirstChild("chooseDungeon", true)
    if not chooseDungeon then return false end

    -- 1) Klik dungeon label
    local dungeonLabel = findLabelByText(chooseDungeon, dungeonName)
    if dungeonLabel then
        print("[PALL-HUB] Klik dungeon:", dungeonName)
        -- Kalau label bukan button, coba parentnya
        if not clickGuiElement(dungeonLabel) then
            if dungeonLabel.Parent then clickGuiElement(dungeonLabel.Parent) end
        end
        task.wait(0.5)
    else
        print("[PALL-HUB] Dungeon tidak ditemukan di GUI:", dungeonName)
        return false
    end

    -- 2) Klik difficulty
    local diffLabel = findLabelByText(qg, difficulty)
    if diffLabel then
        print("[PALL-HUB] Klik difficulty:", difficulty)
        if not clickGuiElement(diffLabel) then
            if diffLabel.Parent then clickGuiElement(diffLabel.Parent) end
        end
        task.wait(0.4)
    end

    -- 3) Hardcore mode (opsional)
    if hardcore then
        local hcLabel = findLabelByText(qg, "Hardcore")
        if hcLabel then
            clickGuiElement(hcLabel)
            task.wait(0.3)
        end
    end

    -- 4) Klik createGame / joinGame
    local createBtn = qg:FindFirstChild("createGame", true)
    local joinBtn = qg:FindFirstChild("joinGame", true)
    if createBtn and createBtn:IsA("TextButton") then
        print("[PALL-HUB] Klik createGame")
        clickGuiElement(createBtn)
    elseif joinBtn and joinBtn:IsA("TextButton") then
        print("[PALL-HUB] Klik joinGame")
        clickGuiElement(joinBtn)
    end
    task.wait(2)

    -- 5) Start (kalau owner)
    local startBtn = qg:FindFirstChild("startButton", true)
    if startBtn and startBtn:IsA("TextButton") then
        print("[PALL-HUB] Klik startButton")
        clickGuiElement(startBtn)
    end

    -- 6) Fire remote sebagai backup
    fire(R.StartDungeon)
    return true
end

_G.PallStartDungeon = startDungeonViaGui

task.spawn(function()
    while task.wait(5) do
        if State.AutoStart then
            startDungeonViaGui(State.SelectedDungeon, State.SelectedDifficulty, State.HardcoreMode)
            task.wait(15) -- cooldown biar nggak spam
        end
    end
end)
--============================================================
-- CAMERA + FACE
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
--============================================================
-- MISC LOOPS
--============================================================
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
--============================================================
-- NOTIF
--============================================================
WindUI:Notify({
    Title = "Pall Hub v6.0.0",
    Content = "Lobby dihapus. Progression & Gear rebuilt.",
    Icon = "solar:bell-bold", Duration = 6,
})

print("[PALL-HUB] v6.0.0 loaded. Lobby removed. Progression + Gear rebuilt.")
