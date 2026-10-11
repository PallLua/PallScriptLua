--[[
    ═══════════════════════════════════════════════════════════
    PALL HUB — DUNGEON QUEST REBORN
    Author  : ENI (for Pall)
    Version : v5.5.0 — v5.4.2 base + Gear/Progression/Lobby/Config
    ═══════════════════════════════════════════════════════════
--]]
print("[PALL-DEBUG] Script mulai load...")
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
if ok then WindUI = result else error("[PALL-HUB] Gagal load WindUI.") end

local Green  = Color3.fromHex("#10C550")
local Yellow = Color3.fromHex("#ECA201")
local Purple = Color3.fromHex("#7775F2")
local Blue   = Color3.fromHex("#257AF7")
local Grey   = Color3.fromHex("#83889E")
local Red    = Color3.fromHex("#EF4F1D")

--============================================================
-- STATE
--============================================================
local State = {
    -- Combat
    AutoAttack = false, AutoAggro = false,
    AttackRange = 25, AggroRange = 300, WalkSpeed = 16,

    -- Dodge
    AutoDodge = false, DodgeRange = 40,
    DodgeOrbitRadius = 10, DodgeOrbitSpeed = 2,
    DodgeWalkSpeed = 16, MaxDodgeWalkSpeed = 16,

    DodgeBossSkill = true,
    DangerRadius = 25, AvoidStrength = 2.5, EscapeMode = true,
    DangerKeywords = "hitbox,damage,aoe,attack,skill,zone,hazard,projectile,bullet,orb,explosion,wave,strike,beam,fire,ice,frost,snow,trap,circle,area,indicator,marker,shockwave,elemental,cast,spell,impact,radius,warning,telegraph,laser,line,cone,pulse,sigil",
    ShowDebugNames = false,

    -- Skill
    AutoSkill = false, SkillQDelay = 0.4, SkillEDelay = 0.8, UseRemoteFallback = true,

    -- Camera
    CameraLock = false, CameraTargetMode = "Nearest Enemy",
    CameraDistance = 8, CameraHeight = 3, CameraSmoothness = 0.25,
    CameraMinHeight = 2, CameraFollowChar = true, CameraCollision = true,
    CameraRestoreOnDeath = true,

    -- Face
    FaceMode = "Both", FacePriority = "Camera Target",
    FaceRotationSpeed = 0.35, FaceOnlyWhenMoving = false,

    -- GEAR
    AutoUpgrade = false, UpgradeDelay = 1.5, UpgradeFilter = "All",
    AutoSell = false, SellRarity = "All", SellCategory = "All",
    KeepEquipped = true, ConfirmDialog = true, SellDelay = 0.3,
    AutoEquipBest = false,

    -- PROGRESSION
    AutoStart = false, AutoReplay = false,
    AutoLobbyReturn = false, ReplayDelay = 3,

    -- LOBBY
    AutoCreateLobby = false, AutoStartLobby = false,
    AutoBestDungeon = false, AutoBestDifficulty = false,
    Hardcore = false, PrivateLobby = false, AutoReady = false,
    StartOnlyOwner = false, DeleteLobbyOnJoin = false,

    -- Misc
    Noclip = false, InfJump = false, AntiAFK = true,

    -- Runtime
    _dodgeTarget = nil, _dangerAvoid = Vector3.zero,
    _dangerCount = 0, _dangerEscape = false,
}

--============================================================
-- REMOTES (dari scan Pall)
--============================================================
local R = {
    StartDungeon     = "startDungeon",
    ReplayDungeon    = "replayDungeon",
    JoinDungeon      = "joinDungeon",
    HostAutoReplay   = "hostSetAutoReplay",
    StartBossRaid    = "startBossRaid",
    ShowStartButton  = "showStartButton",
    ChangeStartValue = "changeStartValue",
    ReloadInvy       = "reloadInvy",
    EquipItem        = "equipItem",
    UnequipItem      = "unequipItem",
    EquipSet         = "equipSet",
    SellItem         = "sellItemEvent",
    OpenSellShop     = "openSellShop",
    UpgradeItem      = "upgradeItem",
    UpgradeKey       = "upgradeKey",
    AbilityUsed      = "abilityUsed",
    AbilityCast      = "abilityCast",
    LeaveGame        = "leaveGame",
    LeaveBossLobby   = "leaveBossLobby",
}

local remoteCache = {}
local function resolveRemote(name)
    if remoteCache[name] then return remoteCache[name] end
    local remotesFolder = ReplicatedStorage:FindFirstChild("remotes")
    if remotesFolder then
        local ev = remotesFolder:FindFirstChild(name)
        if ev then remoteCache[name] = ev; return ev end
    end
    local ev = ReplicatedStorage:FindFirstChild(name)
    if ev then remoteCache[name] = ev end
    return ev
end

local function fire(name, ...)
    local ev = resolveRemote(name)
    if ev and ev:IsA("RemoteEvent") then
        local args = {...}
        pcall(function() ev:FireServer(table.unpack(args)) end)
    end
end

local function invoke(name, ...)
    local ev = resolveRemote(name)
    if ev and ev:IsA("RemoteFunction") then
        local args = {...}
        local ok2, res = pcall(function() return ev:InvokeServer(table.unpack(args)) end)
        if ok2 then return res end
    end
    return nil
end
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
-- DANGER SCANNER
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
    local mat = part.Material
    local transp = part.Transparency
    local size = part.Size
    for _, kw in ipairs(dangerKeywordList) do
        if name:find(kw, 1, true) then return true end
    end
    if size.X > 400 or size.Y > 300 or size.Z > 400 then return false end
    local isNeon = (mat == Enum.Material.Neon)
    local isForceField = (mat == Enum.Material.ForceField)
    local isGlowing = isNeon or isForceField
    local isTransparent = (transp >= 0.15 and transp <= 0.95)
    local isSemiTransparent = (transp >= 0.3 and transp <= 0.85)
    local flatCylinder = false
    local thinBeam = false
    if size.Y <= 1.5 and math.max(size.X, size.Z) >= 4 then flatCylinder = true end
    local maxXZ = math.max(size.X, size.Z)
    local minXZ = math.min(size.X, size.Z)
    if maxXZ >= 10 and minXZ <= 2.5 then thinBeam = true end
    if flatCylinder and (isGlowing or isTransparent) then return true end
    if thinBeam and (isGlowing or isTransparent) then return true end
    if isGlowing and isSemiTransparent and size.Y < 80 then return true end
    if isInsideBoss(part) and (isGlowing or isTransparent) then return true end
    if part.Parent == workspace and isNeon and isTransparent then return true end
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
-- WINDOW
--============================================================
local Window = WindUI:CreateWindow({
    Title = "Pall x DUNGEON QUEST REBORN",
    Folder = "pallhubv550",
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

Window:Tag({ Title = "v5.5.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })
--============================================================
-- TAB: SKILLS
--============================================================
local TabSkills = Window:Tab({
    Title = "Skills", Desc = "Auto Skill Q lalu E",
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
        Value = { Min = 16, Max = 40, Default = 16 },
        Callback = function(v)
            State.DodgeWalkSpeed = v
            State.MaxDodgeWalkSpeed = v
        end })

    local bossAvoidSection = TabDodge:Section({ Title = "Boss Skill Avoidance", Box = true, BoxBorder = true, Opened = true })
    bossAvoidSection:Toggle({ Title = "Dodge Boss Skill", Value = true, Callback = function(v) State.DodgeBossSkill = v end })
    bossAvoidSection:Space()
    bossAvoidSection:Slider({ Title = "Danger Radius", Step = 1,
        Value = { Min = 10, Max = 80, Default = 25 },
        Callback = function(v) State.DangerRadius = v end })
    bossAvoidSection:Space()
    bossAvoidSection:Slider({ Title = "Avoid Strength", Step = 0.1,
        Value = { Min = 0.5, Max = 6, Default = 2.5 },
        Callback = function(v) State.AvoidStrength = v end })
    bossAvoidSection:Space()
    bossAvoidSection:Toggle({ Title = "Escape Mode", Value = true,
        Callback = function(v) State.EscapeMode = v end })
    bossAvoidSection:Space()
    bossAvoidSection:Input({
        Title = "Custom Keywords",
        Value = State.DangerKeywords,
        Callback = function(v)
            State.DangerKeywords = v
            refreshKeywords()
        end,
    })
    bossAvoidSection:Space()
    bossAvoidSection:Toggle({
        Title = "Debug: Log Indicator Names",
        Value = false,
        Callback = function(v)
            State.ShowDebugNames = v
            if v then loggedParts = {} end
        end,
    })
end
--============================================================
-- TAB: GEAR
--============================================================
local TabGear = Window:Tab({
    Title = "Gear", Desc = "Upgrade, Sell, Equip",
    Icon = "solar:bag-4-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local upgradeSec = TabGear:Section({ Title = "Auto Upgrade", Box = true, BoxBorder = true, Opened = true })
    upgradeSec:Toggle({
        Title = "Auto Upgrade",
        Desc = "Upgrade gear / key otomatis",
        Value = false,
        Callback = function(v) State.AutoUpgrade = v end,
    })
    upgradeSec:Space()
    upgradeSec:Slider({
        Title = "Upgrade Delay", Step = 0.5,
        Value = { Min = 0.5, Max = 10, Default = 1.5 },
        Callback = function(v) State.UpgradeDelay = v end,
    })
    upgradeSec:Space()
    upgradeSec:Dropdown({
        Title = "Upgrade Target",
        Values = { "All", "Item", "Key" },
        Value = "All",
        Callback = function(v) State.UpgradeFilter = v end,
    })
    upgradeSec:Space()
    upgradeSec:Button({
        Title = "Upgrade Now",
        Justify = "Center",
        Callback = function()
            fire(R.UpgradeItem)
            WindUI:Notify({ Title = "Upgrade", Content = "Mengirim permintaan upgrade..." })
        end,
    })
    upgradeSec:Space()
    upgradeSec:Button({
        Title = "Upgrade Key Now",
        Justify = "Center",
        Callback = function()
            fire(R.UpgradeKey)
            WindUI:Notify({ Title = "Upgrade Key", Content = "Mengirim permintaan upgrade key..." })
        end,
    })

    local sellSec = TabGear:Section({ Title = "Auto Sell", Box = true, BoxBorder = true, Opened = true })
    sellSec:Toggle({
        Title = "Auto Sell",
        Desc = "Jual gear otomatis sesuai filter",
        Value = false,
        Callback = function(v) State.AutoSell = v end,
    })
    sellSec:Space()
    sellSec:Dropdown({
        Title = "Sell Rarity",
        Values = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },
        Value = "All",
        Callback = function(v) State.SellRarity = v end,
    })
    sellSec:Space()
    sellSec:Dropdown({
        Title = "Sell Category",
        Values = { "All", "Spell", "Weapon", "Armor", "Accessory", "Material" },
        Value = "All",
        Callback = function(v) State.SellCategory = v end,
    })
    sellSec:Space()
    sellSec:Slider({
        Title = "Sell Delay", Step = 0.1,
        Value = { Min = 0.1, Max = 3, Default = 0.3 },
        Callback = function(v) State.SellDelay = v end,
    })
    sellSec:Space()
    sellSec:Toggle({
        Title = "Keep Equipped",
        Desc = "Jangan jual gear yang sedang dipakai",
        Value = true,
        Callback = function(v) State.KeepEquipped = v end,
    })
    sellSec:Space()
    sellSec:Toggle({
        Title = "Confirm Dialog",
        Value = true,
        Callback = function(v) State.ConfirmDialog = v end,
    })
    sellSec:Space()
    sellSec:Button({
        Title = "Sell Now",
        Justify = "Center",
        Callback = function()
            fire(R.SellItem, "all")
            WindUI:Notify({ Title = "Sell", Content = "Mengirim permintaan jual..." })
        end,
    })
    sellSec:Space()
    sellSec:Button({
        Title = "Open Sell Shop",
        Justify = "Center",
        Callback = function()
            fire(R.OpenSellShop)
        end,
    })

    local equipSec = TabGear:Section({ Title = "Auto Equip", Box = true, BoxBorder = true, Opened = true })
    equipSec:Toggle({
        Title = "Auto Equip Best",
        Desc = "Equip gear terbaik otomatis",
        Value = false,
        Callback = function(v) State.AutoEquipBest = v end,
    })
    equipSec:Space()
    equipSec:Button({
        Title = "Refresh Inventory",
        Justify = "Center",
        Callback = function()
            fire(R.ReloadInvy)
            WindUI:Notify({ Title = "Inventory", Content = "Refreshing..." })
        end,
    })
end
--============================================================
-- TAB: PROGRESSION
--============================================================
local TabProgression = Window:Tab({
    Title = "Progression", Desc = "Auto start, replay",
    Icon = "solar:chart-2-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local flowSec = TabProgression:Section({ Title = "Dungeon Flow", Box = true, BoxBorder = true, Opened = true })
    flowSec:Toggle({ Title = "Auto Start", Value = false, Callback = function(v) State.AutoStart = v end })
    flowSec:Space()
    flowSec:Toggle({ Title = "Auto Replay", Value = false, Callback = function(v) State.AutoReplay = v end })
    flowSec:Space()
    flowSec:Toggle({ Title = "Auto Return to Lobby", Value = false, Callback = function(v) State.AutoLobbyReturn = v end })
    flowSec:Space()
    flowSec:Slider({ Title = "Replay Delay", Step = 0.5,
        Value = { Min = 0.5, Max = 15, Default = 3 },
        Callback = function(v) State.ReplayDelay = v end })
    flowSec:Space()
    flowSec:Button({
        Title = "Start Dungeon Now",
        Justify = "Center",
        Callback = function() fire(R.StartDungeon) end,
    })
    flowSec:Space()
    flowSec:Button({
        Title = "Replay Dungeon Now",
        Justify = "Center",
        Callback = function() fire(R.ReplayDungeon) end,
    })
    flowSec:Space()
    flowSec:Button({
        Title = "Set Auto Replay Host",
        Justify = "Center",
        Callback = function() fire(R.HostAutoReplay, true) end,
    })
end
--============================================================
-- TAB: LOBBY
--============================================================
local TabLobby = Window:Tab({
    Title = "Lobby", Desc = "Auto create, start, ready",
    Icon = "solar:users-group-rounded-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local lobbySec = TabLobby:Section({ Title = "Lobby Automation", Box = true, BoxBorder = true, Opened = true })
    lobbySec:Toggle({ Title = "Auto Create Lobby", Value = false, Callback = function(v) State.AutoCreateLobby = v end })
    lobbySec:Space()
    lobbySec:Toggle({ Title = "Auto Start Lobby", Value = false, Callback = function(v) State.AutoStartLobby = v end })
    lobbySec:Space()
    lobbySec:Toggle({ Title = "Auto Best Dungeon", Value = false, Callback = function(v) State.AutoBestDungeon = v end })
    lobbySec:Space()
    lobbySec:Toggle({ Title = "Auto Best Difficulty", Value = false, Callback = function(v) State.AutoBestDifficulty = v end })
    lobbySec:Space()
    lobbySec:Toggle({ Title = "Hardcore", Value = false, Callback = function(v) State.Hardcore = v end })
    lobbySec:Space()
    lobbySec:Toggle({ Title = "Private", Value = false, Callback = function(v) State.PrivateLobby = v end })
    lobbySec:Space()
    lobbySec:Toggle({ Title = "Auto Ready", Value = false, Callback = function(v) State.AutoReady = v end })
    lobbySec:Space()
    lobbySec:Toggle({ Title = "Start Only If Owner", Value = false, Callback = function(v) State.StartOnlyOwner = v end })
    lobbySec:Space()
    lobbySec:Toggle({ Title = "Delete Lobby On Join", Value = false, Callback = function(v) State.DeleteLobbyOnJoin = v end })
    lobbySec:Space()
    lobbySec:Button({
        Title = "Leave Lobby Now",
        Justify = "Center",
        Callback = function() fire(R.LeaveGame) end,
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
-- TAB: CONFIG
--============================================================
local TabConfig = Window:Tab({
    Title = "Config", Desc = "Preset, Export, Import",
    Icon = "solar:folder-with-files-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local presets = {
        Physical = {
            FarmDistance = 10, DodgeOrbitRadius = 8, DodgeOrbitSpeed = 3,
            AttackRange = 20, SkillQDelay = 0.3, SkillEDelay = 0.6,
        },
        DesertTemple = {
            DodgeOrbitRadius = 12, DodgeOrbitSpeed = 2.5,
            AttackRange = 25, DangerRadius = 30,
        },
        WinterOutpost = {
            DodgeOrbitRadius = 10, DodgeOrbitSpeed = 2,
            DangerRadius = 30, AvoidStrength = 3,
        },
        PirateIsland = {
            DodgeOrbitRadius = 14, DodgeOrbitSpeed = 2,
            AttackRange = 30, DangerRadius = 25,
        },
        KingsCastle = {
            DodgeOrbitRadius = 10, DodgeOrbitSpeed = 3,
            AttackRange = 22, DangerRadius = 28, AvoidStrength = 3,
        },
        TheUnderworld = {
            DodgeOrbitRadius = 15, DodgeOrbitSpeed = 2,
            AttackRange = 30, DangerRadius = 35, AvoidStrength = 3,
        },
        BossRaid = {
            DodgeOrbitRadius = 12, DodgeOrbitSpeed = 2.5,
            DangerRadius = 32, AvoidStrength = 3, EscapeMode = true,
        },
    }

    local presetSec = TabConfig:Section({ Title = "Presets", Box = true, BoxBorder = true, Opened = true })
    for name, data in pairs(presets) do
        presetSec:Button({
            Title = "Load: " .. name,
            Justify = "Center",
            Callback = function()
                for k, v in pairs(data) do
                    if State[k] ~= nil then State[k] = v end
                end
                local hum = getHum(); if hum then hum.WalkSpeed = State.WalkSpeed end
                WindUI:Notify({
                    Title = "Preset Loaded",
                    Content = name .. " berhasil dimuat.",
                    Icon = "check",
                })
            end,
        })
        presetSec:Space()
    end

    local exportSec = TabConfig:Section({ Title = "Export / Import", Box = true, BoxBorder = true, Opened = true })
    exportSec:Button({
        Title = "Export Config (Copy)",
        Justify = "Center",
        Callback = function()
            local clean = {}
            for k, v in pairs(State) do
                if type(v) ~= "table" and type(v) ~= "function" then
                    clean[k] = v
                end
            end
            local json = HttpService:JSONEncode(clean)
            if setclipboard then setclipboard(json) end
            WindUI:Notify({ Title = "Export", Content = "Config copied to clipboard." })
        end,
    })
    exportSec:Space()
    exportSec:Button({
        Title = "Import Config (Paste)",
        Justify = "Center",
        Callback = function()
            local raw = getclipboard and getclipboard() or ""
            local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok2 and type(data) == "table" then
                for k, v in pairs(data) do
                    if State[k] ~= nil then State[k] = v end
                end
                WindUI:Notify({ Title = "Import", Content = "Config berhasil dimuat." })
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

-- Auto Attack
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

-- Auto Aggro
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
-- AUTO DODGE (v5.4.2 style)
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
-- AUTO UPGRADE
--============================================================
task.spawn(function()
    while task.wait(State.UpgradeDelay) do
        if State.AutoUpgrade then
            if State.UpgradeFilter == "All" or State.UpgradeFilter == "Item" then
                fire(R.UpgradeItem)
            end
            if State.UpgradeFilter == "All" or State.UpgradeFilter == "Key" then
                fire(R.UpgradeKey)
            end
        end
    end
end)

--============================================================
-- AUTO EQUIP BEST
--============================================================
task.spawn(function()
    while task.wait(3) do
        if State.AutoEquipBest then
            local bp = LP:FindFirstChild("Backpack")
            if bp then
                local bestTool, bestScore = nil, 0
                for _, item in ipairs(bp:GetChildren()) do
                    if item:IsA("Tool") then
                        local score = 1
                        local n = item.Name:lower()
                        if n:find("legendary") or n:find("mythic") then score = score + 10
                        elseif n:find("epic") then score = score + 7
                        elseif n:find("rare") then score = score + 5
                        elseif n:find("uncommon") then score = score + 3 end
                        if n:find("sword") or n:find("blade") then score = score + 3 end
                        if n:find("staff") or n:find("wand") then score = score + 2 end
                        if score > bestScore then bestScore, bestTool = score, item end
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
-- AUTO SELL
--============================================================
task.spawn(function()
    while task.wait(2) do
        if State.AutoSell then
            local bp = LP:FindFirstChild("Backpack")
            if bp then
                local equipped = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
                for _, item in ipairs(bp:GetChildren()) do
                    if item:IsA("Tool") then
                        local skip = false
                        if State.KeepEquipped and equipped and item.Name == equipped.Name then
                            skip = true
                        end
                        if not skip then
                            local n = item.Name:lower()
                            local rarityOK = (State.SellRarity == "All") or n:find(State.SellRarity:lower(), 1, true)
                            local catOK = (State.SellCategory == "All") or n:find(State.SellCategory:lower(), 1, true)
                            if rarityOK and catOK then
                                fire(R.SellItem, item.Name)
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
-- AUTO PROGRESSION
--============================================================
task.spawn(function()
    while task.wait(2) do
        if State.AutoStart then
            fire(R.StartDungeon)
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
    Title = "Pall Hub v5.5.0",
    Content = "Gear, Progression, Lobby, Config siap dipakai.",
    Icon = "solar:bell-bold", Duration = 6,
})

print("[PALL-HUB] v5.5.0 loaded. Base v5.4.2 + Gear/Progression/Lobby/Config.")
print("[PALL-DEBUG] Script selesai load sampe akhir.")
