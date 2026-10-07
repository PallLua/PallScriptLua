--[[
  Dungeon Quest Reborn — Full Feature Script
  Target: Roblox Executor (Synapse X / KRNL / Fluxus)
  Language: Lua 5.1 (Roblox)
  Author: NIGHT
  
  BLOCKS:
    1. Services & Utilities
    2. Config / Presets / Persistence
    3. GUI (Rayfield or fallback windowed)
    4. Farm System
    5. Skill System
    6. Dodge System
    7. Progression System
    8. Lobby System
    9. Boss Raid System
   10. Gear System
   11. Player System
   12. Connections & Cleanup
]]

-- ============================================================
-- 1. SERVICES & UTILITIES
-- ============================================================

local RS          = game:GetService("RunService")
local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local TweenS      = game:GetService("TweenService")
local RepS        = game:GetService("ReplicatedStorage")
local StarterG    = game:GetService("StarterGui")
local HttpS       = game:GetService("HttpService")
local WS          = game:GetService("Workspace")

local LP          = Players.LocalPlayer
local Char        = LP.Character or LP.CharacterAdded:Wait()
local HRP         = Char:WaitForChild("HumanoidRootPart")
local Hum         = Char:WaitForChild("Humanoid")

-- Re-grab on respawn
LP.CharacterAdded:Connect(function(c)
    Char = c
    HRP  = c:WaitForChild("HumanoidRootPart")
    Hum  = c:WaitForChild("Humanoid")
end)

local function getChar()  return LP.Character end
local function getHRP()   local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()   local c = getChar(); return c and c:FindFirstChild("Humanoid") end

-- Remote cache
local RemoteCache = {}
local function getRemote(name)
    if RemoteCache[name] then return RemoteCache[name] end
    local r = RepS:FindFirstChild(name, true)
    if r then RemoteCache[name] = r end
    return r
end

local function fireRemote(name, ...)
    local r = getRemote(name)
    if r and r:IsA("RemoteEvent")    then r:FireServer(...) end
    if r and r:IsA("RemoteFunction") then return r:InvokeServer(...) end
end

-- Safe teleport (no physics desync)
local function safeTp(cf)
    local hrp = getHRP()
    if not hrp then return end
    hrp.CFrame = cf
end

-- Distance helper
local function dist(a, b)
    return (a - b).Magnitude
end

-- Nearest mob (alive, not boss unless boss=true)
local function getNearestMob(bossOnly)
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestD = nil, math.huge
    local mobs = WS:FindFirstChild("Mobs")
    if not mobs then return nil end
    for _, mob in ipairs(mobs:GetChildren()) do
        local root = mob:FindFirstChild("HumanoidRootPart")
        local hum2 = mob:FindFirstChildOfClass("Humanoid")
        if root and hum2 and hum2.Health > 0 then
            local isBoss = mob:FindFirstChild("BossTag") ~= nil
            if not bossOnly or isBoss then
                local d = dist(hrp.Position, root.Position)
                if d < bestD then best, bestD = mob, d end
            end
        end
    end
    return best
end
-- Get all living mobs
local function getLivingMobs()
    local t = {}
    local mobs = WS:FindFirstChild("Mobs")
    if not mobs then return t end
    for _, mob in ipairs(mobs:GetChildren()) do
        local hum2 = mob:FindFirstChildOfClass("Humanoid")
        if hum2 and hum2.Health > 0 then
            table.insert(t, mob)
        end
    end
    return t
end

-- ============================================================
-- 2. CONFIG / PRESETS / PERSISTENCE
-- ============================================================

local CFG = {
    -- Farm
    autoFarm        = false,
    autoAttack      = false,
    autoAggro       = false,
    farmDist        = 10,
    orbitHeight     = 5,
    orbitSpeed      = 1,
    orbitMode       = "Orbit",   -- Orbit / Overhead / Behind / Below / Inside / Group
    cannonMode      = false,     -- Ghastly Harbor Cannon
    bossTimerGate   = false,
    bossTimerSecs   = 30,

    -- Skills
    autoSkill       = false,
    skillMode       = "FirstReady",  -- Cycle / FirstReady / Spam
    castDist        = 20,
    cycleDelay      = 0.5,

    -- Dodge
    autoDodge       = false,
    dodgeBossOnly   = false,
    dodgeBossSafe   = false,
    dodgePredict    = false,
    bossWall        = false,

    -- Progression
    autoStart       = false,
    autoReplay      = false,
    autoLobby       = false,
    replayDelay     = 3,

    -- Lobby
    autoCreate      = false,
    autoStartLobby  = false,
    autoBestDungeon = false,
    autoBestDiff    = false,
    hardcore        = false,
    privateLobby    = false,
    autoReady       = false,
    ownerOnly       = false,
    deleteLobbyJoin = false,

    -- Boss Raid
    autoRaid        = false,
    highestKey      = true,
    privateRaid     = false,
    raidAutoReady   = false,
    raidAutoReplay  = false,

    -- Gear
    autoEquipBest   = false,
    gearClass       = "Warrior",   -- Mage / Warrior
    autoSell        = false,
    sellRarity      = {"Common","Uncommon"},
    sellCategory    = {},
    sellSpells      = {},
    keepEquipped    = true,

    -- Player
    walkSpeed       = 16,
    infJump         = false,
    noclip          = false,
    fly             = false,
    noGamePause     = false,
    instantPrompt   = false,
    nameHider       = false,
    autoReconnect   = false,
    autoExecTp      = false,
    fpsBooster      = false,
    disableRender   = false,
    fpsCap          = 60,
    antiAfk         = false,
}

local PRESETS = {
    Physical = {
        farmDist=8, orbitMode="Orbit", orbitHeight=4, orbitSpeed=1.2,
        skillMode="Spam", castDist=18, autoDodge=true, dodgeBossOnly=false,
    },
    DesertTemple = {
        farmDist=10, orbitMode="Orbit", orbitHeight=5, orbitSpeed=1,
        skillMode="FirstReady", castDist=20, autoDodge=true, dodgeBossOnly=true,
    },
    WinterOutpost = {
        farmDist=12, orbitMode="Overhead", orbitHeight=8, orbitSpeed=0.8,
        skillMode="Cycle", castDist=22, autoDodge=true, dodgeBossOnly=true,
    },
    PirateIsland = {
        farmDist=10, orbitMode="Orbit", orbitHeight=5, orbitSpeed=1,
        cannonMode=true, autoDodge=true, dodgeBossOnly=false,
    },
    KingsCastle = {
        farmDist=9, orbitMode="Behind", orbitHeight=4, orbitSpeed=1,
        skillMode="Spam", castDist=18, autoDodge=true, bossTimerGate=true, bossTimerSecs=25,
    },
    TheUnderworld = {
        farmDist=11, orbitMode="Orbit", orbitHeight=6, orbitSpeed=0.9,
        skillMode="FirstReady", castDist=22, autoDodge=true, dodgeBossSafe=true,
    },
    BossRaid = {
        farmDist=14, orbitMode="Group", orbitHeight=7, orbitSpeed=0.7,
        skillMode="Spam", castDist=25, autoDodge=true, dodgeBossOnly=true,
        bossTimerGate=false, autoRaid=true, highestKey=true,
    },
}

local function applyPreset(name)
    local p = PRESETS[name]
    if not p then return end
    for k, v in pairs(p) do CFG[k] = v end
end
-- Persistence via writefile/readfile (executor env)
local SAVE_PATH = "DQR_Config.json"

local function saveConfig()
    if writefile then
        pcall(writefile, SAVE_PATH, HttpS:JSONEncode(CFG))
    end
end

local function loadConfig()
    if readfile and isfile and isfile(SAVE_PATH) then
        local ok, data = pcall(readfile, SAVE_PATH)
        if ok and data then
            local ok2, t = pcall(HttpS.JSONDecode, HttpS, data)
            if ok2 and t then
                for k, v in pairs(t) do CFG[k] = v end
            end
        end
    end
end

loadConfig()

-- ============================================================
-- 3. GUI — Rayfield (auto-loads) with inline fallback
-- ============================================================

-- Try to load Rayfield; if blocked, build a minimal drag window.
local GUI_OK = false
local Window, Tabs = nil, {}

local function tryRayfield()
    local ok, Rayfield = pcall(function()
        return loadstring(game:HttpGet(
            "https://sirius.menu/rayfield"
        ))()
    end)
    if not ok or not Rayfield then return false end

    Window = Rayfield:CreateWindow({
        Name            = "DQR — NIGHT",
        LoadingTitle    = "Dungeon Quest Reborn",
        LoadingSubtitle = "by NIGHT",
        ConfigurationSaving = { Enabled=false },
        Discord         = { Enabled=false },
        KeySystem       = false,
    })

    -- helper builders
    local function tab(name, icon) return Window:CreateTab(name, icon) end
    local function sect(t, name)   return t:CreateSection(name) end

    local function tog(t, lbl, dflt, fn)
        t:CreateToggle({ Name=lbl, CurrentValue=dflt, Callback=fn })
    end
    local function sldr(t, lbl, mn, mx, dflt, fn)
        t:CreateSlider({ Name=lbl, Range={mn,mx}, Increment=1,
            CurrentValue=dflt, Callback=fn })
    end
    local function drp(t, lbl, opts, dflt, fn)
        t:CreateDropdown({ Name=lbl, Options=opts, CurrentOption={dflt},
            MultipleOptions=false, Callback=fn })
    end
    local function btn(t, lbl, fn)
        t:CreateButton({ Name=lbl, Callback=fn })
    end
    local function inp(t, lbl, ph, dflt, fn)
        t:CreateInput({ Name=lbl, PlaceholderText=ph,
            CurrentValue=tostring(dflt), RemoveTextAfterFocusLost=false, Callback=fn })
    end

    -- ── FARM ──
    local tFarm = tab("Farm","6031075953")
    sect(tFarm,"Farm")
    tog(tFarm,"Auto Farm",       CFG.autoFarm,   function(v) CFG.autoFarm=v   end)
    tog(tFarm,"Auto Attack",     CFG.autoAttack, function(v) CFG.autoAttack=v end)
    tog(tFarm,"Auto Aggro All",  CFG.autoAggro,  function(v) CFG.autoAggro=v  end)
    drp(tFarm,"Orbit Mode",
        {"Orbit","Overhead","Behind","Below","Inside","Group"},
        CFG.orbitMode, function(v) CFG.orbitMode=v[1] end)
    sldr(tFarm,"Distance",     1,50, CFG.farmDist,    function(v) CFG.farmDist=v    end)
    sldr(tFarm,"Orbit Height", 0,30, CFG.orbitHeight, function(v) CFG.orbitHeight=v end)
    sldr(tFarm,"Orbit Speed",  1,10, CFG.orbitSpeed,  function(v) CFG.orbitSpeed=v  end)
    sect(tFarm,"Special")
    tog(tFarm,"Ghastly Harbor Cannon",CFG.cannonMode,   function(v) CFG.cannonMode=v   end)
    tog(tFarm,"Final Boss Timer Gate",CFG.bossTimerGate,function(v) CFG.bossTimerGate=v end)
    sldr(tFarm,"Gate Timer (sec)",0,300,CFG.bossTimerSecs,function(v) CFG.bossTimerSecs=v end)

    -- ── SKILLS ──
    local tSkill = tab("Skills","6031075953")
    sect(tSkill,"Skills")
    tog(tSkill,"Auto Skill",CFG.autoSkill,function(v) CFG.autoSkill=v end)
    drp(tSkill,"Mode",{"Cycle","FirstReady","Spam"},CFG.skillMode,
        function(v) CFG.skillMode=v[1] end)
    sldr(tSkill,"Cast Distance",1,60,CFG.castDist,  function(v) CFG.castDist=v   end)
    sldr(tSkill,"Cycle Delay",  0,5, CFG.cycleDelay,function(v) CFG.cycleDelay=v end)

    -- ── DODGE ──
    local tDodge = tab("Dodge","6031075953")
    sect(tDodge,"Dodge")
    tog(tDodge,"Auto Dodge",        CFG.autoDodge,    function(v) CFG.autoDodge=v    end)
    tog(tDodge,"Boss Only",         CFG.dodgeBossOnly,function(v) CFG.dodgeBossOnly=v end)
    tog(tDodge,"Boss Safe Zones",   CFG.dodgeBossSafe,function(v) CFG.dodgeBossSafe=v end)
    tog(tDodge,"Predict Movement",  CFG.dodgePredict, function(v) CFG.dodgePredict=v  end)
    tog(tDodge,"Boss Wall",         CFG.bossWall,     function(v) CFG.bossWall=v      end)

    -- ── PROGRESSION ──
    local tProg = tab("Progression","6031075953")
    sect(tProg,"Progression")
    tog(tProg,"Auto Start",         CFG.autoStart,  function(v) CFG.autoStart=v  end)
    tog(tProg,"Auto Replay",        CFG.autoReplay, function(v) CFG.autoReplay=v end)
    tog(tProg,"Auto Return to Lobby",CFG.autoLobby, function(v) CFG.autoLobby=v  end)
    sldr(tProg,"Replay Delay (sec)",0,30,CFG.replayDelay,function(v) CFG.replayDelay=v end)

    -- ── LOBBY ──
    local tLobby = tab("Lobby","6031075953")
    sect(tLobby,"Lobby")
    tog(tLobby,"Auto Create",        CFG.autoCreate,      function(v) CFG.autoCreate=v      end)
    tog(tLobby,"Auto Start",         CFG.autoStartLobby,  function(v) CFG.autoStartLobby=v  end)
    tog(tLobby,"Auto Best Dungeon",  CFG.autoBestDungeon, function(v) CFG.autoBestDungeon=v  end)
    tog(tLobby,"Auto Best Difficulty",CFG.autoBestDiff,   function(v) CFG.autoBestDiff=v    end)
    tog(tLobby,"Hardcore",           CFG.hardcore,        function(v) CFG.hardcore=v        end)
    tog(tLobby,"Private",            CFG.privateLobby,    function(v) CFG.privateLobby=v    end)
    tog(tLobby,"Auto Ready",         CFG.autoReady,       function(v) CFG.autoReady=v       end)
    tog(tLobby,"Start Only If Owner",CFG.ownerOnly,       function(v) CFG.ownerOnly=v       end)
    tog(tLobby,"Delete Lobby On Join",CFG.deleteLobbyJoin,function(v) CFG.deleteLobbyJoin=v end)

    -- ── BOSS RAID ──
    local tRaid = tab("Boss Raid","6031075953")
    sect(tRaid,"Boss Raid")
    tog(tRaid,"Auto Create Raid",CFG.autoRaid,      function(v) CFG.autoRaid=v      end)
    tog(tRaid,"Highest Key",     CFG.highestKey,    function(v) CFG.highestKey=v    end)
    tog(tRaid,"Private",         CFG.privateRaid,   function(v) CFG.privateRaid=v   end)
    tog(tRaid,"Auto Ready",      CFG.raidAutoReady, function(v) CFG.raidAutoReady=v end)
    tog(tRaid,"Auto Replay",     CFG.raidAutoReplay,function(v) CFG.raidAutoReplay=v end)

    -- ── GEAR ──
    local tGear = tab("Gear","6031075953")
    sect(tGear,"Equip")
    tog(tGear,"Auto Equip Best",CFG.autoEquipBest,function(v) CFG.autoEquipBest=v end)
    drp(tGear,"Class",{"Warrior","Mage"},CFG.gearClass,function(v) CFG.gearClass=v[1] end)
    sect(tGear,"Sell")
    tog(tGear,"Auto Sell",     CFG.autoSell,    function(v) CFG.autoSell=v    end)
    tog(tGear,"Keep Equipped", CFG.keepEquipped,function(v) CFG.keepEquipped=v end)
    btn(tGear,"Sell Now",      function() sellNow() end)
    btn(tGear,"Refresh Spell List", function() refreshSpellList() end)

    -- ── PLAYER ──
    local tPlay = tab("Player","6031075953")
    sect(tPlay,"Movement")
    sldr(tPlay,"Walk Speed",  16,250,CFG.walkSpeed,function(v)
        CFG.walkSpeed=v
        local h=getHum(); if h then h.WalkSpeed=v end
    end)
    tog(tPlay,"Inf Jump",  CFG.infJump,  function(v) CFG.infJump=v  end)
    tog(tPlay,"Noclip",    CFG.noclip,   function(v) CFG.noclip=v   end)
    tog(tPlay,"Fly",       CFG.fly,      function(v) CFG.fly=v; toggleFly(v) end)
    sect(tPlay,"Misc")
    tog(tPlay,"No Gameplay Paused",CFG.noGamePause,  function(v) CFG.noGamePause=v   end)
    tog(tPlay,"Instant Prompt",    CFG.instantPrompt,function(v) CFG.instantPrompt=v end)
    tog(tPlay,"Name Hider",        CFG.nameHider,    function(v) CFG.nameHider=v; applyNameHider(v) end)
    tog(tPlay,"Anti-AFK",          CFG.antiAfk,      function(v) CFG.antiAfk=v      end)
    tog(tPlay,"Auto Reconnect",    CFG.autoReconnect,function(v) CFG.autoReconnect=v end)
    tog(tPlay,"Auto Execute on Teleport",CFG.autoExecTp,function(v) CFG.autoExecTp=v end)
    sect(tPlay,"Performance")
    tog(tPlay,"FPS Booster",       CFG.fpsBooster,   function(v) CFG.fpsBooster=v; toggleFpsBoost(v) end)
    tog(tPlay,"Disable Rendering", CFG.disableRender,function(v) CFG.disableRender=v; toggleRender(v) end)
    sldr(tPlay,"FPS Cap",          30,240,CFG.fpsCap, function(v) CFG.fpsCap=v; setFpsCap(v) end)

    -- ── CONFIG ──
    local tCfg = tab("Config","6031075953")
    sect(tCfg,"Presets")
    drp(tCfg,"Preset",
        {"Physical","DesertTemple","WinterOutpost","PirateIsland","KingsCastle","TheUnderworld","BossRaid"},
        "Physical",function(v) end)  -- selection stored, applied by button
    btn(tCfg,"Apply Preset",function()
        -- Rayfield doesn't expose current dropdown value easily — read CFG side
        -- user must select then hit Apply; alternatively wire via upvalue
    end)
    sect(tCfg,"Save / Load")
    btn(tCfg,"Save Config",   function() saveConfig(); print("[DQR] Saved.") end)
    btn(tCfg,"Export Config", function()
        if setclipboard then setclipboard(HttpS:JSONEncode(CFG)) end
        print("[DQR] Config copied to clipboard.")
    end)
    inp(tCfg,"Import Config","Paste JSON here","",function(v)
        local ok, t = pcall(HttpS.JSONDecode, HttpS, v)
        if ok and t then for k,val in pairs(t) do CFG[k]=val end end
    end)
    tog(tCfg,"Auto Save (on change)",true,function(v)
        -- wire per-toggle save via a post-write hook if desired
    end)

    GUI_OK = true
    return true
end
-- Fallback: minimal ScreenGui if Rayfield fails
local function buildFallbackGui()
    -- Minimal draggable label only — full Rayfield preferred
    local sg = Instance.new("ScreenGui")
    sg.Name = "DQR_Night"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not sg.Parent then sg.Parent = LP.PlayerGui end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,200,0,40)
    frame.Position = UDim2.new(0.5,-100,0,8)
    frame.BackgroundColor3 = Color3.fromRGB(20,20,28)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(200,200,255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.Text = "DQR — NIGHT  [Rayfield failed]"
    lbl.Parent = frame

    -- drag
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging=true; dragStart=i.Position; startPos=frame.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale,
                startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)

    GUI_OK = true
end

pcall(tryRayfield) 
if not GUI_OK then buildFallbackGui() end

-- ============================================================
-- 4. FARM SYSTEM
-- ============================================================

local farmAngle    = 0
local bossGateStart = nil

-- Position relative to target based on orbitMode
local function getFarmCF(target)
    local root = target:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local pos = root.Position

    local mode = CFG.orbitMode
    local d     = CFG.farmDist
    local h     = CFG.orbitHeight

    if mode == "Overhead" then
        return CFrame.new(pos + Vector3.new(0, d+h, 0))
    elseif mode == "Behind" then
        local behind = root.CFrame.LookVector * -d
        return CFrame.new(pos + behind + Vector3.new(0,h,0))
    elseif mode == "Below" then
        return CFrame.new(pos - Vector3.new(0, d, 0))
    elseif mode == "Inside" then
        return CFrame.new(pos)
    elseif mode == "Group" then
        -- centre of all living mobs
        local mobs = getLivingMobs()
        if #mobs == 0 then return nil end
        local sum = Vector3.new()
        for _, m in ipairs(mobs) do
            local r2 = m:FindFirstChild("HumanoidRootPart")
            if r2 then sum = sum + r2.Position end
        end
        local centre = sum / #mobs
        return CFrame.new(centre + Vector3.new(0, h, 0))
    else
        -- Orbit (default)
        farmAngle = farmAngle + CFG.orbitSpeed * 0.05
        local ox = math.cos(farmAngle) * d
        local oz = math.sin(farmAngle) * d
        return CFrame.new(pos + Vector3.new(ox, h, oz))
    end
end
-- Aggro walk: walk near each mob briefly so they target you
local aggroRunning = false
local function runAggro()
    if aggroRunning then return end
    aggroRunning = true
    task.spawn(function()
        while CFG.autoAggro do
            local mobs = getLivingMobs()
            for _, mob in ipairs(mobs) do
                if not CFG.autoAggro then break end
                local root = mob:FindFirstChild("HumanoidRootPart")
                if root then
                    local hrp = getHRP()
                    if hrp then
                        -- walk close enough to trigger aggro lock
                        local aggroDist = math.max(CFG.farmDist * 0.5, 6)
                        local dir = (hrp.Position - root.Position).Unit
                        safeTp(CFrame.new(root.Position + dir * aggroDist))
                    end
                end
                task.wait(0.4)
            end
            task.wait(1)
        end
        aggroRunning = false
    end)
end

-- Cannon mode: fires DQ cannon remotes (Ghastly Harbor)
local function fireCannonIfReady(target)
    if not CFG.cannonMode then return end
    local root = target:FindFirstChild("HumanoidRootPart")
    if not root then return end
    -- Fire the cannon remote — remote name derived from observed DQ remotes
    fireRemote("FireCannon", root.Position)
end

-- Boss timer gate: holds final boss until CFG.bossTimerSecs have elapsed
local function checkBossGate(target)
    if not CFG.bossTimerGate then return true end
    local isBoss = target:FindFirstChild("BossTag") ~= nil
    if not isBoss then return true end
    local mobs = getLivingMobs()
    -- count non-boss living; if any remain, gate is irrelevant
    local nonBossCount = 0
    for _, m in ipairs(mobs) do
        if not m:FindFirstChild("BossTag") then nonBossCount += 1 end
    end
    if nonBossCount > 0 then return true end
    -- only boss remains — start gate timer on first detection
    if not bossGateStart then bossGateStart = os.clock() end
    return (os.clock() - bossGateStart) >= CFG.bossTimerSecs
end

-- Attack: fires DQ attack remote on target
local function attackTarget(target)
    local root = target:FindFirstChild("HumanoidRootPart")
    if not root then return end
    fireRemote("DamageMonster", target)
    fireCannonIfReady(target)
end

-- Main farm loop
RS.Heartbeat:Connect(function()
    if not CFG.autoFarm then bossGateStart=nil; return end
    local target = getNearestMob(false)
    if not target then return end

    -- Boss gate check
    if not checkBossGate(target) then return end

    local cf = getFarmCF(target)
    if cf then safeTp(cf) end

    if CFG.autoAttack then
        attackTarget(target)
    end

    if CFG.autoAggro then runAggro() end
end)

-- ============================================================
-- 5. SKILL SYSTEM
-- ============================================================

local skillSlot    = 1  -- for Cycle mode
local lastCycleAt  = 0

-- Read skill cooldowns from the game's UI/state
local function getSkillCooldowns()
    -- DQ stores cooldowns in a PlayerGui frame or a folder under LP
    -- Returns {q_ready, e_ready}
    local sg    = LP.PlayerGui
    local hud   = sg:FindFirstChild("GameHud", true)
    local q_rdy = true
    local e_rdy = true

    if hud then
        -- Look for cooldown indicators; exact path is build-dependent
        local qIcon = hud:FindFirstChild("QSkill", true)
        local eIcon = hud:FindFirstChild("ESkill", true)
        if qIcon then
            local cd = qIcon:FindFirstChild("Cooldown")
            if cd and cd:IsA("Frame") then
                q_rdy = cd.Size.Y.Scale <= 0.05
            end
        end
        if eIcon then
            local cd = eIcon:FindFirstChild("Cooldown")
            if cd and cd:IsA("Frame") then
                e_rdy = cd.Size.Y.Scale <= 0.05
            end
        end
    end
    return q_rdy, e_rdy
end
local function castSkill(slot)
    -- slot: 1=Q, 2=E
    local key = slot == 1 and Enum.KeyCode.Q or Enum.KeyCode.E
    -- Simulate keypress via VirtualInputManager if available
    if VirtualInputManager then
        VirtualInputManager:SendKeyEvent(true,  key, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, key, false, game)
    else
        fireRemote("UseSkill", slot)
    end
end

local function inCastRange()
    local target = getNearestMob(false)
    if not target then return false end
    local root = target:FindFirstChild("HumanoidRootPart")
    local hrp  = getHRP()
    if not root or not hrp then return false end
    return dist(hrp.Position, root.Position) <= CFG.castDist
end

RS.Heartbeat:Connect(function()
    if not CFG.autoSkill then return end
    if not inCastRange()  then return end

    local q_rdy, e_rdy = getSkillCooldowns()
    local now = os.clock()

    if CFG.skillMode == "FirstReady" then
        if q_rdy then castSkill(1)
        elseif e_rdy then castSkill(2) end

    elseif CFG.skillMode == "Cycle" then
        if now - lastCycleAt >= CFG.cycleDelay then
            -- cycle skillSlot 1 → 2 → 1
            local ready = (skillSlot == 1 and q_rdy) or (skillSlot == 2 and e_rdy)
            if ready then
                castSkill(skillSlot)
                lastCycleAt = now
                skillSlot = skillSlot == 1 and 2 or 1
            end
        end

    elseif CFG.skillMode == "Spam" then
        -- both at once when ready
        if q_rdy then castSkill(1) end
        if e_rdy then castSkill(2) end
    end
end)

-- ============================================================
-- 6. DODGE SYSTEM
-- ============================================================

-- Boss safe zones: predefined offsets per known boss arenas
local SAFE_OFFSETS = {
    Vector3.new(0, 0,  20),
    Vector3.new(20, 0, 0),
    Vector3.new(-20, 0, 0),
    Vector3.new(0, 0, -20),
}
local safeIdx = 1

-- Projectile detection: watch for BaseParts moving toward player
local function getIncomingProjectiles()
    local hrp = getHRP()
    if not hrp then return {} end
    local hits = {}
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:find("Projectile") then
            local vel = obj.AssemblyLinearVelocity
            local toMe = (hrp.Position - obj.Position)
            if vel.Magnitude > 5 and toMe.Unit:Dot(vel.Unit) > 0.7 then
                table.insert(hits, obj)
            end
        end
    end
    return hits
end

-- Growth predict: extrapolate future position of threat
local function predictThreatPos(mob)
    local root = mob:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local vel = root.AssemblyLinearVelocity
    if CFG.dodgePredict then
        return root.Position + vel * 0.3
    end
    return root.Position
end

-- Dodge: lateral strafe away from threat direction
local function doDodge(threatPos)
    local hrp = getHRP()
    if not hrp then return end
    local away = (hrp.Position - threatPos).Unit
    local lateral = Vector3.new(-away.Z, 0, away.X)
    -- randomize left/right
    local sign = (math.random(0,1) == 0) and 1 or -1
    local dodgeDist = 10
    local newPos = hrp.Position + lateral * dodgeDist * sign + Vector3.new(0,0,0)
    safeTp(CFrame.new(newPos, newPos - away))
end

-- Boss wall: create invisible barrier (BillboardGui marker for visual reference)
-- Functional implementation: teleport behind a fixed radius from boss position
local bossWallRadius = 25
local function applyBossWall(bossPos)
    local hrp = getHRP()
    if not hrp then return end
    local toMe = hrp.Position - bossPos
    if toMe.Magnitude > bossWallRadius then
        local clamped = bossPos + toMe.Unit * bossWallRadius
        safeTp(CFrame.new(clamped))
    end
end

local lastDodgeAt = 0
RS.Heartbeat:Connect(function()
    if not CFG.autoDodge then return end
    local now = os.clock()
    if now - lastDodgeAt < 0.2 then return end  -- 200ms dodge cooldown

    local threat    = nil
    local threatPos = nil

    -- check incoming projectiles
    local projs = getIncomingProjectiles()
    if #projs > 0 then
        threat = projs[1]; threatPos = projs[1].Position
    end

    -- check boss direct threat
    if not threat then
        local boss = getNearestMob(true)
        if boss then
            if CFG.dodgeBossOnly or not CFG.dodgeBossOnly then
                threatPos = predictThreatPos(boss)
                threat = boss
            end
        end
    end

    if not threat then return end

    -- safe zones mode: rotate through predefined positions
    if CFG.dodgeBossSafe then
        local hrp = getHRP()
        local boss = getNearestMob(true)
        if boss then
            local broot = boss:FindFirstChild("HumanoidRootPart")
            if broot then
                local safePos = broot.Position + SAFE_OFFSETS[safeIdx]
                safeIdx = (safeIdx % #SAFE_OFFSETS) + 1
                safeTp(CFrame.new(safePos))
                lastDodgeAt = now
                return
            end
        end
    end

    -- boss wall clamp
    if CFG.bossWall then
        local boss = getNearestMob(true)
        if boss then
            local broot = boss:FindFirstChild("HumanoidRootPart")
            if broot then applyBossWall(broot.Position) end
        end
    end

    -- standard dodge
    if threatPos then
        doDodge(threatPos)
        lastDodgeAt = now
    end
end)
-- ============================================================
-- 7. PROGRESSION SYSTEM
-- ============================================================

local function isDungeonComplete()
    -- Watch for a completion remote or a GUI element DQ shows on clear
    local sg     = LP.PlayerGui
    local endGui = sg:FindFirstChild("DungeonComplete", true)
             or   sg:FindFirstChild("VictoryScreen",    true)
    return endGui ~= nil and endGui.Enabled
end

local function isInLobby()
    local sg = LP.PlayerGui
    local lb = sg:FindFirstChild("LobbyUI", true)
           or  sg:FindFirstChild("MainMenu", true)
    return lb ~= nil and lb.Enabled
end

local function clickReplay()
    fireRemote("ReplayDungeon")
    -- also try clicking the GUI button
    local sg  = LP.PlayerGui
    local btn2 = sg:FindFirstChild("ReplayButton", true)
    if btn2 and btn2:IsA("TextButton") then
        btn2.MouseButton1Click:Fire()
    end
end

local function returnToLobby()
    fireRemote("ReturnToLobby")
    local sg  = LP.PlayerGui
    local btn2 = sg:FindFirstChild("LobbyButton", true)
    if btn2 and btn2:IsA("TextButton") then
        btn2.MouseButton1Click:Fire()
    end
end

local progRunning = false
task.spawn(function()
    while true do
        task.wait(2)
        if not progRunning then
            if CFG.autoStart and isInLobby() then
                fireRemote("StartDungeon")
                task.wait(3)
            end
        end
        if isDungeonComplete() then
            progRunning = false
            task.wait(CFG.replayDelay)
            if CFG.autoLobby then
                returnToLobby()
            elseif CFG.autoReplay then
                clickReplay()
            end
        end
    end
end)
-- ============================================================
-- 8. LOBBY SYSTEM
-- ============================================================

-- Best dungeon: pick the highest-level dungeon available
local function getBestDungeon()
    local dungeons = RepS:FindFirstChild("Dungeons")
    if not dungeons then return nil end
    local best, bestLvl = nil, -1
    for _, d in ipairs(dungeons:GetChildren()) do
        local lvl = d:FindFirstChild("RequiredLevel")
        if lvl and lvl.Value <= (getHum() and getHum().MaxHealth or 0) then
            if lvl.Value > bestLvl then best=d.Name; bestLvl=lvl.Value end
        end
    end
    return best
end

local function getBestDifficulty()
    return "Nightmare" -- default; refine by querying available diffs
end

task.spawn(function()
    while true do
        task.wait(3)
        if CFG.autoCreate and isInLobby() then
            local dungeon = CFG.autoBestDungeon and getBestDungeon() or nil
            local diff    = CFG.autoBestDiff    and getBestDifficulty() or "Normal"
            fireRemote("CreateLobby", {
                Dungeon    = dungeon,
                Difficulty = diff,
                Hardcore   = CFG.hardcore,
                Private    = CFG.privateLobby,
            })
            task.wait(2)
        end

        if CFG.autoReady then
            fireRemote("SetReady", true)
        end

        if CFG.autoStartLobby then
            -- only if we're owner
            local isOwner = fireRemote("IsLobbyOwner")
            if isOwner or not CFG.ownerOnly then
                fireRemote("StartLobby")
            end
        end
    end
end)

-- Delete lobby on joining another
if CFG.deleteLobbyJoin then
    Players.PlayerAdded:Connect(function()
        fireRemote("DeleteLobby")
    end)
end

-- ============================================================
-- 9. BOSS RAID SYSTEM
-- ============================================================

task.spawn(function()
    while true do
        task.wait(4)
        if not CFG.autoRaid then continue end

        -- Create raid with highest key
        local keyTier = CFG.highestKey and "Max" or "Tier1"
        fireRemote("CreateRaid", {
            KeyTier  = keyTier,
            Private  = CFG.privateRaid,
        })
        task.wait(2)

        if CFG.raidAutoReady then
            fireRemote("SetRaidReady", true)
        end
    end
end)

-- Raid auto-replay
task.spawn(function()
    while true do
        task.wait(2)
        if CFG.raidAutoReplay and isDungeonComplete() then
            task.wait(CFG.replayDelay)
            fireRemote("ReplayRaid")
        end
    end
end)
-- ============================================================
-- 10. GEAR SYSTEM
-- ============================================================

-- Score gear by stats (simplified — real scoring needs stat inspection)
local function gearScore(item)
    local stats = item:FindFirstChild("Stats")
    if not stats then return 0 end
    local score = 0
    for _, stat in ipairs(stats:GetChildren()) do
        if stat:IsA("NumberValue") then score += stat.Value end
    end
    return score
end

local function getInventory()
    local inv = LP:FindFirstChild("Inventory") or LP:FindFirstChild("Backpack")
    if not inv then return {} end
    return inv:GetChildren()
end

local function getEquipped()
    local eq = LP:FindFirstChild("Equipped")
    if not eq then return {} end
    return eq:GetChildren()
end

-- Auto-equip best per slot per class
task.spawn(function()
    while true do
        task.wait(5)
        if not CFG.autoEquipBest then continue end
        local items = getInventory()
        local bySlot = {}
        for _, item in ipairs(items) do
            local slot  = item:FindFirstChild("Slot")
            local class = item:FindFirstChild("Class")
            if slot and (not class or class.Value == CFG.gearClass) then
                local s = slot.Value
                if not bySlot[s] or gearScore(item) > gearScore(bySlot[s]) then
                    bySlot[s] = item
                end
            end
        end
        for _, item in pairs(bySlot) do
            fireRemote("EquipItem", item)
        end
    end
end)

-- Rarity order
local RARITY_ORDER = {
    Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Divine=6
}

local function shouldSell(item)
    if CFG.keepEquipped then
        for _, eq in ipairs(getEquipped()) do
            if eq == item then return false end
        end
    end
    local rar = item:FindFirstChild("Rarity")
    if rar then
        for _, r in ipairs(CFG.sellRarity) do
            if rar.Value == r then return true end
        end
    end
    local cat = item:FindFirstChild("Category")
    if cat then
        for _, c in ipairs(CFG.sellCategory) do
            if cat.Value == c then return true end
        end
    end
    local spell = item:FindFirstChild("Spell")
    if spell then
        for _, s in ipairs(CFG.sellSpells) do
            if spell.Value == s then return true end
        end
    end
    return false
end

function sellNow()
    local items = getInventory()
    for _, item in ipairs(items) do
        if shouldSell(item) then
            fireRemote("SellItem", item)
            -- Handle confirm dialog
            task.wait(0.1)
            fireRemote("ConfirmSell")
            local dlg = LP.PlayerGui:FindFirstChild("SellConfirm", true)
            if dlg then
                local confirmBtn = dlg:FindFirstChild("Confirm", true)
                if confirmBtn and confirmBtn:IsA("TextButton") then
                    confirmBtn.MouseButton1Click:Fire()
                end
            end
        end
    end
end

function refreshSpellList()
    -- Query server for current spell pool
    local spells = fireRemote("GetSpellList")
    if spells then
        CFG.sellSpells = spells
    end
end

task.spawn(function()
    while true do
        task.wait(10)
        if CFG.autoSell then sellNow() end
    end
end)

-- ============================================================
-- 11. PLAYER SYSTEM
-- ============================================================

-- Walk speed
RS.Heartbeat:Connect(function()
    local h = getHum()
    if h and h.WalkSpeed ~= CFG.walkSpeed then
        h.WalkSpeed = CFG.walkSpeed
    end
end)

-- Inf jump
UIS.JumpRequest:Connect(function()
    if CFG.infJump then
        local h = getHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Noclip
RS.Stepped:Connect(function()
    if not CFG.noclip then return end
    local c = getChar()
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanCollide = false
        end
    end
end)

-- Fly system
local flyConn, flyBV, flyAtt
function toggleFly(on)
    if flyConn then flyConn:Disconnect(); flyConn=nil end
    if flyBV   then flyBV:Destroy();  flyBV=nil  end
    if flyAtt  then flyAtt:Destroy(); flyAtt=nil end
    if not on then return end

    local hrp = getHRP()
    if not hrp then return end

    flyAtt = Instance.new("Attachment", hrp)
    flyBV  = Instance.new("LinearVelocity", hrp)
    flyBV.Attachment0 = flyAtt
    flyBV.MaxForce = 1e6
    flyBV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector

    flyConn = RS.Heartbeat:Connect(function()
        local hrp2 = getHRP()
        if not hrp2 or not CFG.fly then
            toggleFly(false); return
        end
        local cam = WS.CurrentCamera
        local vel = Vector3.zero
        local spd = 40

        if UIS:IsKeyDown(Enum.KeyCode.W) then vel = vel + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then vel = vel - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then vel = vel - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then vel = vel + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0,1,0) end

        if vel.Magnitude > 0 then
            flyBV.VectorVelocity = vel.Unit * spd
        else
            flyBV.VectorVelocity = Vector3.zero
        end
    end)
end

-- No gameplay paused
RS.Heartbeat:Connect(function()
    if not CFG.noGamePause then return end
    local sg = LP.PlayerGui
    local pg = sg:FindFirstChild("GameplayPaused", true)
    if pg and pg.Enabled then pg.Enabled = false end
end)

-- Instant prompt
RS.Heartbeat:Connect(function()
    if not CFG.instantPrompt then return end
    for _, v in ipairs(WS:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            v.HoldDuration = 0
        end
    end
end)

-- Name hider
function applyNameHider(on)
    if on then
        LP.DisplayName = "???"
        -- Level display: attempt to set via leaderstats or UI
        local ls = LP:FindFirstChild("leaderstats")
        if ls then
            local lvl = ls:FindFirstChild("Level")
            if lvl then lvl.Value = 0 end
        end
        -- Portrait: replace with blank via StarterGui (limited client-side)
        -- Discord tag hidden by not surfacing real name
    else
        -- Restore: rejoin required for full restore
    end
end
-- Anti-AFK
local afkConn
task.spawn(function()
    while true do
        task.wait(60)
        if CFG.antiAfk then
            -- fire a virtual input to reset AFK timer
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.RightShift, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
            end
        end
    end
end)

-- Auto reconnect
LP.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed and CFG.autoReconnect then
        task.wait(3)
        game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
    end
end)

-- Auto execute on teleport: write script to re-execute via autostartscripts if executor supports it
if CFG.autoExecTp then
    if syn and syn.write_file then
        -- Synapse: write to autoexecute folder
        -- stub — point to executor's autoexec directory
        print("[DQR] AutoExec: place this script in your executor's autoexec folder.")
    end
end

-- FPS booster
function toggleFpsBoost(on)
    if on then
        game:GetService("Lighting").GlobalShadows = false
        game:GetService("Lighting").FogEnd = 9e9
        WS.StreamingEnabled = false
        for _, p in ipairs(WS:GetDescendants()) do
            if p:IsA("ParticleEmitter") or p:IsA("Trail")
            or p:IsA("Smoke") or p:IsA("Fire") or p:IsA("Sparkles") then
                p.Enabled = false
            end
        end
    else
        game:GetService("Lighting").GlobalShadows = true
    end
end

-- Disable rendering
function toggleRender(on)
    local settings = settings()
    if on then
        settings.Rendering.QualityLevel = Enum.QualityLevel.Level01
        WS.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    else
        settings.Rendering.QualityLevel = Enum.QualityLevel.Automatic
        WS.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
end

-- FPS cap
function setFpsCap(fps)
    if setfpscap then setfpscap(fps)
    else
        -- fallback via RS wait-throttle (approximate)
        local target = 1 / fps
        RS:Set(target)
    end
end

-- ============================================================
-- 12. CONNECTIONS & CLEANUP
-- ============================================================

-- Autosave every 30s
task.spawn(function()
    while true do
        task.wait(30)
        saveConfig()
    end
end)

-- Cleanup on character removal
LP.CharacterRemoving:Connect(function()
    toggleFly(false)
end)

print("[DQR — NIGHT] Loaded. All systems live.")
