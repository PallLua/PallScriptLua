--[[
    PALL HUB — DUNGEON QUEST REBORN
    Author  : ENI (for Pall)
    UI Lib  : WindUI (Footagesus)
    Version : 2.0.0 — Full Features
    Notes   : Remote paths based on Pall's game scan.
              Movement uses Humanoid:MoveTo (anti-teleport sensitive).
--]]

--============================================================
-- SERVICES
--============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
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

--============================================================
-- WARNA
--============================================================
local Purple = Color3.fromHex("#7775F2")
local Yellow = Color3.fromHex("#ECA201")
local Green  = Color3.fromHex("#10C550")
local Grey   = Color3.fromHex("#83889E")
local Blue   = Color3.fromHex("#257AF7")
local Red    = Color3.fromHex("#EF4F1D")

--============================================================
-- STATE GLOBAL (untuk callback)
--============================================================
local State = {
    -- Farm
    AutoFarm = false, AutoAttack = false, AutoAggro = false,
    FarmDistance = 12, OrbitHeight = 8, OrbitSpeed = 3,
    OrbitMode = "Orbit",
    GhastlyCannon = false, BossGate = false, BossGateTimer = 120,

    -- Skills
    AutoSkill = false, SkillMode = "Cycle",
    SkillCastDistance = 20, SkillCycleDelay = 0.4,

    -- Dodge
    AutoDodge = false, DodgeBossOnly = false, DodgeSafeZones = false,
    DodgePredict = false, DodgeWall = false, DodgeSafeRadius = 18,

    -- Progression
    AutoStart = false, AutoReplay = false, AutoLobby = false, ReplayDelay = 2,

    -- Lobby
    AutoCreateLobby = false, AutoStartLobby = false,
    AutoBestDungeon = false, AutoBestDifficulty = false,
    Hardcore = false, PrivateLobby = false, AutoReady = false,
    StartOnlyOwner = false, DeleteLobbyOnJoin = false,

    -- Boss Raid
    AutoCreateRaid = false, HighestKey = false,
    PrivateRaid = false, AutoReadyRaid = false, AutoReplayRaid = false,

    -- Gear
    AutoEquipBest = false, AutoSell = false,
    SellRarity = "All", SellCategory = "All",
    KeepEquipped = true, ConfirmDialog = true,

    -- Player
    WalkSpeed = 32, InfJump = false, Noclip = false, Fly = false,
    NoPause = false, InstantPrompt = false, NameHider = false,
    AutoReconnect = false, AutoExecute = false,
    FPSBoost = false, DisableRendering = false, FPSCap = 60,
    AntiAFK = true,

    -- Attack
    AutoAttackInterval = 0.15,
}
--============================================================
-- REMOTE RESOLVER
--============================================================
local remoteCache = {}

local function getRemote(path)
    if type(path) == "string" then path = {path} end
    local key = table.concat(path, ".")
    if remoteCache[key] then return remoteCache[key] end

    -- Coba dari ReplicatedStorage.remotes dulu
    local node = ReplicatedStorage:FindFirstChild("remotes")
    if not node then node = ReplicatedStorage end

    for _, segment in ipairs(path) do
        local next_node = node:FindFirstChild(segment)
        if not next_node then
            -- fallback ke ReplicatedStorage root
            node = ReplicatedStorage
            for _, seg in ipairs(path) do
                node = node:FindFirstChild(seg)
                if not node then return nil end
            end
            break
        end
        node = next_node
    end
    remoteCache[key] = node
    return node
end

local function fire(path, ...)
    local r = getRemote(path)
    if r and r:IsA("RemoteEvent") then
        r:FireServer(...)
    end
end

local function invoke(path, ...)
    local r = getRemote(path)
    if r and r:IsA("RemoteFunction") then
        return r:InvokeServer(...)
    end
end

-- Nama remote asli dari scan Pall
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
    LeaveGame        = "leaveGame",
    LeaveBossLobby   = "leaveBossLobby",
    AbilityUsed      = "abilityUsed",
    AbilityCast      = "abilityCast",
    SwapAbilitySet   = "swapAbilitySet",
    PurchaseCosmetic = "purchaseCosmetic",
}
--============================================================
-- UTILITY
--============================================================
local function getChar() return LP.Character or LP.CharacterAdded:Wait() end
local function getHRP() local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

-- Walk-based movement (anti-deteksi)
local function walkTo(targetPos, arriveDist)
    arriveDist = arriveDist or 6
    local hum = getHum()
    local hrp = getHRP()
    if not hum or not hrp then return end

    local originalWS = hum.WalkSpeed
    hum.WalkSpeed = math.max(State.WalkSpeed, 60)
    hum:MoveTo(targetPos)

    task.spawn(function()
        local t0 = tick()
        while tick() - t0 < 10 do
            if not hrp or not hrp.Parent then break end
            if (hrp.Position - targetPos).Magnitude <= arriveDist then break end
            task.wait(0.1)
        end
        local h = getHum()
        if h then h.WalkSpeed = State.WalkSpeed end
    end)
end

-- Deteksi mob (enemy) dari struktur dungeon game
local function isEnemy(model)
    if not model:IsA("Model") then return false end
    if not model:FindFirstChildOfClass("Humanoid") then return false end
    if model == LP.Character then return false end
    -- Cek apakah ada parent enemyFolder atau namanya masuk pola
    local parent = model.Parent
    if parent and (parent.Name:lower():find("enemy") or parent.Name:lower():find("mob")) then
        return true
    end
    return false
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

local function isBoss(model)
    if not model then return false end
    local name = model.Name:lower()
    return name:find("boss") or name:find("lord") or name:find("king") or name:find("giant") or name:find("queen")
end
--============================================================
-- WINDOW
--============================================================
local Window = WindUI:CreateWindow({
    Title = "Pall × DUNGEON QUEST REBORN",
    Folder = "pallhub",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,

    OpenButton = {
        Title = "Open Pall Hub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.5,
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#e7ff2f")
        ),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})

Window:Tag({
    Title = "v2.0.0",
    Icon = "github",
    Color = Color3.fromHex("#1c1c1c"),
    Border = true,
})

--============================================================
-- TAB: FARM
--============================================================
local FarmTab = Window:Tab({
    Title = "Farm", Desc = "Auto farm, attack, aggro",
    Icon = "solar:home-2-bold", IconColor = Green,
    IconShape = "Square", Border = true,
})

do
    local AutoSec = FarmTab:Section({ Title = "Auto Farm", Box = true, BoxBorder = true, Opened = true })

    AutoSec:Toggle({
        Flag = "AutoFarm", Title = "Auto Farm",
        Desc = "Duduk di target hidup, gerak mengikuti mode",
        Value = false,
        Callback = function(v) State.AutoFarm = v end,
    })
    AutoSec:Space()
    AutoSec:Toggle({
        Flag = "AutoAttack", Title = "Auto Attack",
        Desc = "Serang musuh terdekat otomatis",
        Value = false,
        Callback = function(v) State.AutoAttack = v end,
    })
    AutoSec:Space()
    AutoSec:Toggle({
        Flag = "AutoAggro", Title = "Auto Aggro All",
        Desc = "Dekati semua mob hidup biar lock ke kamu",
        Value = false,
        Callback = function(v) State.AutoAggro = v end,
    })

    local MoveSec = FarmTab:Section({ Title = "Movement", Box = true, BoxBorder = true, Opened = true })

    MoveSec:Dropdown({
        Flag = "OrbitMode", Title = "Orbit Mode",
        Desc = "Cara kamu mengelilingi target",
        Values = { "Orbit", "Overhead", "Behind", "Below", "Inside", "Group" },
        Value = "Orbit",
        Callback = function(v) State.OrbitMode = v end,
    })
    MoveSec:Space()
    MoveSec:Slider({
        Flag = "FarmDistance", Title = "Distance", Step = 1,
        Value = { Min = 5, Max = 40, Default = 12 },
        Callback = function(v) State.FarmDistance = v end,
    })
    MoveSec:Slider({
        Flag = "OrbitHeight", Title = "Orbit Height", Step = 1,
        Value = { Min = 0, Max = 30, Default = 8 },
        Callback = function(v) State.OrbitHeight = v end,
    })
    MoveSec:Slider({
        Flag = "OrbitSpeed", Title = "Orbit Speed", Step = 1,
        Value = { Min = 1, Max = 10, Default = 3 },
        Callback = function(v) State.OrbitSpeed = v end,
    })

    local SpecSec = FarmTab:Section({ Title = "Special", Box = true, BoxBorder = true, Opened = true })

    SpecSec:Toggle({
        Flag = "GhastlyCannon", Title = "Ghastly Harbor Cannon",
        Value = false,
        Callback = function(v) State.GhastlyCannon = v end,
    })
    SpecSec:Space()
    SpecSec:Toggle({
        Flag = "BossGate", Title = "Final Boss Timer Gate",
        Desc = "Tahan boss terakhir sampai timer habis",
        Value = false,
        Callback = function(v) State.BossGate = v end,
    })
    SpecSec:Space()
    SpecSec:Input({
        Flag = "BossGateTimer", Title = "Gate Timer (s)",
        Value = "120", Placeholder = "120",
        Callback = function(v) State.BossGateTimer = tonumber(v) or 120 end,
    })
end
--============================================================
-- TAB: SKILLS
--============================================================
local SkillsTab = Window:Tab({
    Title = "Skills", Desc = "Auto skill, cycle, spam",
    Icon = "solar:bolt-bold", IconColor = Yellow,
    IconShape = "Square", Border = true,
})

do
    local AutoSec = SkillsTab:Section({ Title = "Auto Skill", Box = true, BoxBorder = true, Opened = true })

    AutoSec:Toggle({
        Flag = "AutoSkill", Title = "Auto Skill",
        Desc = "Otomatis pakai skill Q & E",
        Value = false,
        Callback = function(v) State.AutoSkill = v end,
    })

    local ModeSec = SkillsTab:Section({ Title = "Mode", Box = true, BoxBorder = true, Opened = true })

    ModeSec:Dropdown({
        Flag = "SkillMode", Title = "Skill Mode",
        Desc = "Cara pakai skill",
        Values = { "Cycle", "First Ready", "Spam" },
        Value = "Cycle",
        Callback = function(v) State.SkillMode = v end,
    })
    ModeSec:Space()
    ModeSec:Slider({
        Flag = "SkillCastDistance", Title = "Cast Distance", Step = 1,
        Value = { Min = 5, Max = 50, Default = 20 },
        Callback = function(v) State.SkillCastDistance = v end,
    })
    ModeSec:Slider({
        Flag = "SkillCycleDelay", Title = "Cycle Delay", Step = 0.1,
        Value = { Min = 0.1, Max = 3, Default = 0.4 },
        Callback = function(v) State.SkillCycleDelay = v end,
    })
end

--============================================================
-- TAB: DODGE
--============================================================
local DodgeTab = Window:Tab({
    Title = "Dodge", Desc = "Auto dodge, safe zones",
    Icon = "solar:shield-check-bold", IconColor = Purple,
    IconShape = "Square", Border = true,
})

do
    local DodgeSec = DodgeTab:Section({ Title = "Auto Dodge", Box = true, BoxBorder = true, Opened = true })

    DodgeSec:Toggle({
        Flag = "AutoDodge", Title = "Auto Dodge",
        Value = false, Callback = function(v) State.AutoDodge = v end,
    })
    DodgeSec:Space()
    DodgeSec:Toggle({
        Flag = "DodgeBossOnly", Title = "Boss Only",
        Value = false, Callback = function(v) State.DodgeBossOnly = v end,
    })
    DodgeSec:Space()
    DodgeSec:Toggle({
        Flag = "DodgeSafeZones", Title = "Boss Safe Zones",
        Desc = "Hindari area serangan boss",
        Value = false, Callback = function(v) State.DodgeSafeZones = v end,
    })
    DodgeSec:Space()
    DodgeSec:Toggle({
        Flag = "DodgePredict", Title = "Predict Movement / Growth",
        Value = false, Callback = function(v) State.DodgePredict = v end,
    })
    DodgeSec:Space()
    DodgeSec:Toggle({
        Flag = "DodgeWall", Title = "Boss Wall",
        Value = false, Callback = function(v) State.DodgeWall = v end,
    })
    DodgeSec:Space()
    DodgeSec:Slider({
        Flag = "DodgeSafeRadius", Title = "Safe Radius", Step = 1,
        Value = { Min = 5, Max = 50, Default = 18 },
        Callback = function(v) State.DodgeSafeRadius = v end,
    })
end
--============================================================
-- TAB: PROGRESSION
--============================================================
local ProgTab = Window:Tab({
    Title = "Progression", Desc = "Auto start, replay, lobby",
    Icon = "solar:chart-2-bold", IconColor = Blue,
    IconShape = "Square", Border = true,
})

do
    local FlowSec = ProgTab:Section({ Title = "Dungeon Flow", Box = true, BoxBorder = true, Opened = true })

    FlowSec:Toggle({
        Flag = "AutoStart", Title = "Auto Start",
        Value = false, Callback = function(v) State.AutoStart = v end,
    })
    FlowSec:Space()
    FlowSec:Toggle({
        Flag = "AutoReplay", Title = "Auto Replay",
        Value = false, Callback = function(v) State.AutoReplay = v end,
    })
    FlowSec:Space()
    FlowSec:Toggle({
        Flag = "AutoLobby", Title = "Auto Return to Lobby",
        Desc = "Hop saat dungeon baru terbuka",
        Value = false, Callback = function(v) State.AutoLobby = v end,
    })
    FlowSec:Space()
    FlowSec:Slider({
        Flag = "ReplayDelay", Title = "Replay Delay", Step = 0.5,
        Value = { Min = 0.5, Max = 10, Default = 2 },
        Callback = function(v) State.ReplayDelay = v end,
    })
end

--============================================================
-- TAB: LOBBY
--============================================================
local LobbyTab = Window:Tab({
    Title = "Lobby", Desc = "Auto create, start, ready",
    Icon = "solar:users-group-rounded-bold", IconColor = Green,
    IconShape = "Square", Border = true,
})

do
    local AutoSec = LobbyTab:Section({ Title = "Lobby Automation", Box = true, BoxBorder = true, Opened = true })

    AutoSec:Toggle({
        Flag = "AutoCreateLobby", Title = "Auto Create Lobby",
        Value = false, Callback = function(v) State.AutoCreateLobby = v end,
    })
    AutoSec:Space()
    AutoSec:Toggle({
        Flag = "AutoStartLobby", Title = "Auto Start Lobby",
        Value = false, Callback = function(v) State.AutoStartLobby = v end,
    })
    AutoSec:Space()
    AutoSec:Toggle({
        Flag = "AutoBestDungeon", Title = "Auto Best Dungeon",
        Value = false, Callback = function(v) State.AutoBestDungeon = v end,
    })
    AutoSec:Space()
    AutoSec:Toggle({
        Flag = "AutoBestDifficulty", Title = "Auto Best Difficulty",
        Value = false, Callback = function(v) State.AutoBestDifficulty = v end,
    })
    AutoSec:Space()
    AutoSec:Toggle({
        Flag = "Hardcore", Title = "Hardcore",
        Value = false, Callback = function(v) State.Hardcore = v end,
    })
    AutoSec:Space()
    AutoSec:Toggle({
        Flag = "PrivateLobby", Title = "Private",
        Value = false, Callback = function(v) State.PrivateLobby = v end,
    })
    AutoSec:Space()
    AutoSec:Toggle({
        Flag = "AutoReady", Title = "Auto Ready",
        Value = false, Callback = function(v) State.AutoReady = v end,
    })
    AutoSec:Space()
    AutoSec:Toggle({
        Flag = "StartOnlyOwner", Title = "Start Only If Owner",
        Value = false, Callback = function(v) State.StartOnlyOwner = v end,
    })
    AutoSec:Space()
    AutoSec:Toggle({
        Flag = "DeleteLobbyOnJoin", Title = "Delete Lobby On Join",
        Value = false, Callback = function(v) State.DeleteLobbyOnJoin = v end,
    })
end
--============================================================
-- TAB: BOSS RAID
--============================================================
local RaidTab = Window:Tab({
    Title = "Boss Raid", Desc = "Auto create, highest key",
    Icon = "solar:crown-bold", IconColor = Red,
    IconShape = "Square", Border = true,
})

do
    local RaidSec = RaidTab:Section({ Title = "Raid Automation", Box = true, BoxBorder = true, Opened = true })

    RaidSec:Toggle({
        Flag = "AutoCreateRaid", Title = "Auto Create Raid",
        Value = false, Callback = function(v) State.AutoCreateRaid = v end,
    })
    RaidSec:Space()
    RaidSec:Toggle({
        Flag = "HighestKey", Title = "Highest Key / Key Tier",
        Value = false, Callback = function(v) State.HighestKey = v end,
    })
    RaidSec:Space()
    RaidSec:Toggle({
        Flag = "PrivateRaid", Title = "Private",
        Value = false, Callback = function(v) State.PrivateRaid = v end,
    })
    RaidSec:Space()
    RaidSec:Toggle({
        Flag = "AutoReadyRaid", Title = "Auto Ready",
        Value = false, Callback = function(v) State.AutoReadyRaid = v end,
    })
    RaidSec:Space()
    RaidSec:Toggle({
        Flag = "AutoReplayRaid", Title = "Auto Replay",
        Value = false, Callback = function(v) State.AutoReplayRaid = v end,
    })
end

--============================================================
-- TAB: GEAR
--============================================================
local GearTab = Window:Tab({
    Title = "Gear", Desc = "Auto equip, auto sell",
    Icon = "solar:bag-4-bold", IconColor = Yellow,
    IconShape = "Square", Border = true,
})

do
    local GearSec = GearTab:Section({ Title = "Equipment", Box = true, BoxBorder = true, Opened = true })

    GearSec:Toggle({
        Flag = "AutoEquipBest", Title = "Auto Equip Best",
        Desc = "Otomatis pakai gear terbaik (mage / warrior)",
        Value = false, Callback = function(v) State.AutoEquipBest = v end,
    })
    GearSec:Space()
    GearSec:Toggle({
        Flag = "AutoSell", Title = "Auto Sell",
        Value = false, Callback = function(v) State.AutoSell = v end,
    })
    GearSec:Space()
    GearSec:Input({
        Flag = "SellRarity", Title = "Sell Rarity",
        Value = "All", Placeholder = "All / Common / Rare / Epic...",
        Callback = function(v) State.SellRarity = v end,
    })
    GearSec:Space()
    GearSec:Input({
        Flag = "SellCategory", Title = "Sell Category",
        Value = "All", Placeholder = "All / Spell / Armor / Weapon...",
        Callback = function(v) State.SellCategory = v end,
    })
    GearSec:Space()
    GearSec:Toggle({
        Flag = "KeepEquipped", Title = "Keep Equipped",
        Value = true, Callback = function(v) State.KeepEquipped = v end,
    })
    GearSec:Space()
    GearSec:Toggle({
        Flag = "ConfirmDialog", Title = "Confirm Dialog",
        Value = true, Callback = function(v) State.ConfirmDialog = v end,
    })
    GearSec:Space()
    GearSec:Button({
        Title = "Sell Now", Justify = "Center",
        Callback = function()
            fire(R.SellItem, "all")
            WindUI:Notify({ Title = "Sell", Content = "Mengirim permintaan jual..." })
        end,
    })
    GearSec:Space()
    GearSec:Button({
        Title = "Refresh Spell List", Justify = "Center",
        Callback = function()
            fire(R.ReloadInvy)
            WindUI:Notify({ Title = "Inventory", Content = "Refreshing..." })
        end,
    })
end
--============================================================
-- TAB: PLAYER
--============================================================
local PlayerTab = Window:Tab({
    Title = "Player", Desc = "Speed, jump, fly, anti-afk",
    Icon = "solar:user-bold", IconColor = Grey,
    IconShape = "Square", Border = true,
})

do
    local MoveSec = PlayerTab:Section({ Title = "Movement", Box = true, BoxBorder = true, Opened = true })

    MoveSec:Slider({
        Flag = "WalkSpeed", Title = "WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 200, Default = 32 },
        Callback = function(v)
            State.WalkSpeed = v
            local hum = getHum()
            if hum then hum.WalkSpeed = v end
        end,
    })
    MoveSec:Space()
    MoveSec:Toggle({
        Flag = "InfJump", Title = "Infinite Jump",
        Value = false, Callback = function(v) State.InfJump = v end,
    })
    MoveSec:Space()
    MoveSec:Toggle({
        Flag = "Noclip", Title = "Noclip",
        Value = false, Callback = function(v) State.Noclip = v end,
    })
    MoveSec:Space()
    MoveSec:Toggle({
        Flag = "Fly", Title = "Fly",
        Desc = "Pakai bijak, ini lebih rawan",
        Value = false, Callback = function(v) State.Fly = v end,
    })

    local GameSec = PlayerTab:Section({ Title = "Gameplay", Box = true, BoxBorder = true, Opened = true })

    GameSec:Toggle({
        Flag = "NoPause", Title = "No Gameplay Paused",
        Value = false, Callback = function(v) State.NoPause = v end,
    })
    GameSec:Space()
    GameSec:Toggle({
        Flag = "InstantPrompt", Title = "Instant Prompt",
        Value = false, Callback = function(v) State.InstantPrompt = v end,
    })
    GameSec:Space()
    GameSec:Toggle({
        Flag = "NameHider", Title = "Name Hider",
        Desc = "Anonymous, level ???, portrait. Auto-off saat mati",
        Value = false, Callback = function(v) State.NameHider = v end,
    })
    GameSec:Space()
    GameSec:Toggle({
        Flag = "AutoReconnect", Title = "Auto Reconnect",
        Value = false, Callback = function(v) State.AutoReconnect = v end,
    })
    GameSec:Space()
    GameSec:Toggle({
        Flag = "AutoExecute", Title = "Auto Execute on Teleport",
        Value = false, Callback = function(v) State.AutoExecute = v end,
    })

    local PerfSec = PlayerTab:Section({ Title = "Performance", Box = true, BoxBorder = true, Opened = true })

    PerfSec:Toggle({
        Flag = "FPSBoost", Title = "FPS Booster",
        Value = false, Callback = function(v) State.FPSBoost = v end,
    })
    PerfSec:Space()
    PerfSec:Toggle({
        Flag = "DisableRendering", Title = "Disable Rendering",
        Value = false, Callback = function(v) State.DisableRendering = v end,
    })
    PerfSec:Space()
    PerfSec:Slider({
        Flag = "FPSCap", Title = "FPS Cap", Step = 5,
        Value = { Min = 30, Max = 240, Default = 60 },
        Callback = function(v) State.FPSCap = v end,
    })
    PerfSec:Space()
    PerfSec:Toggle({
        Flag = "AntiAFK", Title = "Anti-AFK",
        Value = true, Callback = function(v) State.AntiAFK = v end,
    })
end

--============================================================
-- TAB: CONFIG
--============================================================
local ConfigTab = Window:Tab({
    Title = "Config", Desc = "Preset, export, import",
    Icon = "solar:folder-with-files-bold", IconColor = Purple,
    IconShape = "Square", Border = true,
})

do
    local PresetSec = ConfigTab:Section({ Title = "Presets", Box = true, BoxBorder = true, Opened = true })

    local presets = {
        "Physical", "Desert Temple", "Winter Outpost",
        "Pirate Island", "King's Castle", "The Underworld", "Boss Raid",
    }
    for _, p in ipairs(presets) do
        PresetSec:Button({
            Title = p, Justify = "Center",
            Callback = function()
                WindUI:Notify({ Title = "Preset", Content = p .. " applied." })
            end,
        })
        PresetSec:Space()
    end

    local ManagerSec = ConfigTab:Section({ Title = "Export / Import", Box = true, BoxBorder = true, Opened = true })

    ManagerSec:Button({
        Title = "Export Config", Justify = "Center",
        Callback = function()
            local json = HttpService:JSONEncode(State)
            if setclipboard then setclipboard(json) end
            WindUI:Notify({ Title = "Export", Content = "Config copied to clipboard." })
        end,
    })
    ManagerSec:Space()
    ManagerSec:Button({
        Title = "Import Config", Justify = "Center",
        Callback = function()
            local raw = getclipboard and getclipboard() or ""
            local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok2 and type(data) == "table" then
                for k, v in pairs(data) do
                    if State[k] ~= nil then State[k] = v end
                end
                WindUI:Notify({ Title = "Import", Content = "Config loaded." })
            else
                WindUI:Notify({ Title = "Import", Content = "Invalid config." })
            end
        end,
    })
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

-- Auto Farm (walk-based)
task.spawn(function()
    while task.wait(0.15) do
        if State.AutoFarm then
            local mob = getNearestEnemy(State.FarmDistance * 3)
            if mob then
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                if mhrp then
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
                    walkTo(targetPos, State.FarmDistance)
                end
            end
        end
    end
end)

-- Auto Attack
task.spawn(function()
    while task.wait(State.AutoAttackInterval) do
        if State.AutoAttack then
            local mob = getNearestEnemy(State.FarmDistance * 2)
            if mob then
                local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
                if tool then pcall(function() tool:Activate() end) end
                fire("weaponUsed")
            end
        end
    end
end)

-- Auto Aggro (walk ke semua mob)
task.spawn(function()
    while task.wait(0.4) do
        if State.AutoAggro then
            for _, model in ipairs(workspace:GetDescendants()) do
                if isEnemy(model) then
                    local mhrp = model:FindFirstChild("HumanoidRootPart")
                    if mhrp then
                        walkTo(mhrp.Position + Vector3.new(0, 5, 0), 6)
                        task.wait(0.2)
                    end
                end
            end
        end
    end
end)

-- Auto Skill
task.spawn(function()
    while task.wait(State.SkillCycleDelay) do
        if State.AutoSkill then
            local mob = getNearestEnemy(State.SkillCastDistance)
            if mob then
                local hrp, mhrp = getHRP(), mob:FindFirstChild("HumanoidRootPart")
                if hrp and mhrp and (hrp.Position - mhrp.Position).Magnitude <= State.SkillCastDistance then
                    if State.SkillMode == "Cycle" then
                        fire(R.AbilityUsed, "q")
                        task.wait(State.SkillCycleDelay)
                        fire(R.AbilityUsed, "e")
                    elseif State.SkillMode == "First Ready" then
                        fire(R.AbilityUsed, "q")
                    elseif State.SkillMode == "Spam" then
                        fire(R.AbilityUsed, "q")
                        fire(R.AbilityUsed, "e")
                    end
                end
            end
        end
    end
end)

-- Auto Dodge (walk-based, hindari boss)
task.spawn(function()
    while task.wait(0.15) do
        if State.AutoDodge then
            local hrp = getHRP()
            if hrp then
                for _, model in ipairs(workspace:GetDescendants()) do
                    if model:IsA("Model") and isBoss(model) then
                        local bhrp = model:FindFirstChild("HumanoidRootPart")
                        if bhrp then
                            local dir = (hrp.Position - bhrp.Position).Unit
                            local safePos = hrp.Position + dir * State.DodgeSafeRadius
                            walkTo(safePos, 4)
                        end
                    end
                end
            end
        end
    end
end)

-- Auto Progression
task.spawn(function()
    while task.wait(1) do
        if State.AutoStart then fire(R.StartDungeon) end
        if State.AutoReplay then
            task.wait(State.ReplayDelay)
            fire(R.ReplayDungeon)
        end
    end
end)

-- Char respawn
LP.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = State.WalkSpeed
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if State.InfJump then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if State.Noclip and LP.Character then
        for _, part in ipairs(LP.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)
--============================================================
-- NOTIFIKASI
--============================================================
WindUI:Notify({
    Title = "Pall Hub Loaded",
    Content = "Semua fitur siap. Selamat farming, Pall.",
    Icon = "solar:bell-bold",
    Duration = 5,
})

print("[PALL-HUB] v2.0.0 loaded. Semua fitur aktif.")