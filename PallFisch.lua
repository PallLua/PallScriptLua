--[[
    ═══════════════════════════════════════════════════════════
    PALL — FISCH v3.0.0
    Logic  : NIGHT (community script — no UI)
    UI     : WindUI (Pall)
    Notes  : Logic internal identik, toggle dipindah ke UI
    ═══════════════════════════════════════════════════════════
--]]

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local WS      = game:GetService("Workspace")
local RUN     = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local TW      = game:GetService("TweenService")

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
    if not ok then error("[PALL-FISCH] Gagal load WindUI.") end
    WindUI = result
    _G.PallWindUI = WindUI
end

local Green  = Color3.fromHex("#10C550")
local Yellow = Color3.fromHex("#ECA201")
local Blue   = Color3.fromHex("#257AF7")
local Grey   = Color3.fromHex("#83889E")
local Purple = Color3.fromHex("#7775F2")
local Red    = Color3.fromHex("#EF4F1D")

--============================================================
-- GLOBAL STATE (dari NIGHT, dipindah ke _G biar logic internal tetap jalan)
--============================================================
_G.AutoFish      = false
_G.AutoReel      = false
_G.NoShake       = false
_G.InfiniteStam  = false
_G.AutoSell      = false
_G.AutoQuest     = false
_G.AutoCollect   = false
_G.AntiAFK       = false
_G.SpeedBoost    = false
_G.AutoEquipBest = false
_G.ESP           = false
_G.FishRadar     = false
_G.Fly           = false
_G.FlySpeed      = 50
_G.ESPRange      = 500

--============================================================
-- CHAR REF
--============================================================
local char, hrp, hum
local function refreshChar()
    char = LP.Character or LP.CharacterAdded:Wait()
    hrp  = char:WaitForChild("HumanoidRootPart", 5)
    hum  = char:WaitForChild("Humanoid", 5)
end
refreshChar()
LP.CharacterAdded:Connect(function() task.wait(0.8) refreshChar() end)

--============================================================
-- REMOTE HELPERS
--============================================================
local remoteCache = {}
local function findRemote(name)
    if remoteCache[name] then return remoteCache[name] end
    local nameLow = name:lower()
    for _, v in ipairs(RS:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
            if v.Name:lower() == nameLow or v.Name:lower():find(nameLow) then
                remoteCache[name] = v
                return v
            end
        end
    end
    return nil
end

local function fireRemote(name, ...)
    local r = findRemote(name)
    if not r then return end
    local args = {...}
    if r:IsA("RemoteEvent") then
        pcall(function() r:FireServer(table.unpack(args)) end)
    elseif r:IsA("RemoteFunction") then
        pcall(function() r:InvokeServer(table.unpack(args)) end)
    end
end

--============================================================
-- ROD HELPERS
--============================================================
local rodTier = {
    ["legendary"] = 10, ["mythic"] = 9, ["ancient"] = 8,
    ["divine"]    = 7,  ["rare"]   = 6, ["uncommon"]= 5,
    ["common"]    = 1,
}

local function getRodScore(tool)
    local name = tool.Name:lower()
    for tier, score in pairs(rodTier) do
        if name:find(tier) then return score end
    end
    return 2
end

local function findBestRod()
    local best, bestScore = nil, -1
    local sources = {LP:FindFirstChild("Backpack"), char}
    for _, src in ipairs(sources) do
        if src then
            for _, t in ipairs(src:GetChildren()) do
                if t:IsA("Tool") and (t.Name:lower():find("rod") or t.Name:lower():find("fishing")) then
                    local score = getRodScore(t)
                    if score > bestScore then
                        bestScore = score
                        best = t
                    end
                end
            end
        end
    end
    return best
end

local function findAnyRod()
    if not char then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and (t.Name:lower():find("rod") or t.Name:lower():find("fishing")) then
            return t
        end
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and (t.Name:lower():find("rod") or t.Name:lower():find("fishing")) then
                return t
            end
        end
    end
    return nil
end

local function equipRod(rod)
    if not rod or not hum or not char then return end
    if char:FindFirstChild(rod.Name) then return end
    pcall(function() hum:EquipTool(rod) end)
    task.wait(0.4)
end

local function equippedRod()
    if not char then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and (t.Name:lower():find("rod") or t.Name:lower():find("fishing")) then
            return t
        end
    end
    return nil
end

--============================================================
-- AUTO EQUIP BEST ROD (logic NIGHT)
--============================================================
task.spawn(function()
    while true do
        task.wait(3)
        if not _G.AutoEquipBest then continue end
        if not hum or not char then continue end
        local best = findBestRod()
        if best and not char:FindFirstChild(best.Name) then
            equipRod(best)
            print("[FISCH] Equipped best rod: " .. best.Name)
        end
    end
end)

--============================================================
-- AUTO FISH (logic NIGHT)
--============================================================
local fishState = "idle"
local lastCast  = 0
local CAST_CD   = 3
local BITE_TIMEOUT = 18

local function findReelGui()
    for _, g in ipairs(PG:GetDescendants()) do
        if g:IsA("Frame") and g.Visible then
            local n = g.Name:lower()
            if n:find("reel") or n:find("fishbar") or n:find("progress") or n:find("bite") then
                return g
            end
        end
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.08)
        if not _G.AutoFish then
            fishState = "idle"
            continue
        end
        if not char or not hrp or not hum then continue end
        if hum.Health <= 0 then continue end

        local now = tick()

        if fishState == "idle" then
            if now - lastCast >= CAST_CD then
                local rod = equippedRod()
                if not rod then
                    rod = findAnyRod()
                    if rod then equipRod(rod) end
                end
                rod = equippedRod()
                if rod then
                    pcall(function() rod:Activate() end)
                    fireRemote("cast")
                    fireRemote("Cast")
                    fireRemote("castRod")
                    fishState = "waiting"
                    lastCast  = now
                end
            end

        elseif fishState == "waiting" then
            local reelGui = findReelGui()
            if reelGui then
                fishState = "reeling"
            end
            if now - lastCast >= BITE_TIMEOUT then
                fishState = "idle"
                lastCast  = now - CAST_CD
            end

        elseif fishState == "reeling" then
            local reelGui = findReelGui()
            if reelGui then
                fireRemote("reel")
                fireRemote("Reel")
                fireRemote("reelFish")
                fireRemote("ReelFish")
                fireRemote("click")
                local rod = equippedRod()
                if rod then pcall(function() rod:Activate() end) end
                task.wait(0.04)
            else
                fishState = "idle"
                lastCast  = tick()
                print("[FISCH] Fish caught!")
            end
        end
    end
end)
-- AUTO REEL
task.spawn(function()
    while true do
        task.wait(0.05)
        if not _G.AutoReel then continue end
        local reelGui = findReelGui()
        if reelGui then
            fireRemote("reel")
            fireRemote("Reel")
            fireRemote("reelFish")
            local rod = equippedRod()
            if rod then pcall(function() rod:Activate() end) end
        end
    end
end)

-- NO SHAKE
task.spawn(function()
    while true do
        task.wait(0.1)
        if not _G.NoShake then continue end
        fireRemote("shake")
        fireRemote("Shake")
        fireRemote("shakeSuccess")
        fireRemote("passShake")
        fireRemote("shakeComplete")
    end
end)

-- INFINITE STAMINA
task.spawn(function()
    while true do
        task.wait(0.1)
        if not _G.InfiniteStam then continue end
        if char then
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("NumberValue") then
                    local n = v.Name:lower()
                    if n:find("stamina") or n:find("energy") or n:find("endur") then
                        pcall(function()
                            if v.Value < 80 then v.Value = 100 end
                        end)
                    end
                end
            end
        end
        fireRemote("stamina")
        fireRemote("refillStamina")
        fireRemote("restoreStamina")
    end
end)

-- AUTO SELL
local lastSell = 0
task.spawn(function()
    while true do
        task.wait(0.5)
        if not _G.AutoSell then continue end
        if tick() - lastSell < 5 then continue end
        lastSell = tick()

        fireRemote("sell")
        fireRemote("Sell")
        fireRemote("sellFish")
        fireRemote("SellFish")
        fireRemote("sellAll")
        fireRemote("SellAll")
        fireRemote("sellInventory")

        for _, v in ipairs(RS:GetDescendants()) do
            if v:IsA("RemoteFunction") and v.Name:lower():find("sell") then
                pcall(function() v:InvokeServer() end)
            end
        end
        print("[FISCH] Auto sell fired")
    end
end)
-- AUTO QUEST
local lastQuest = 0
task.spawn(function()
    while true do
        task.wait(1)
        if not _G.AutoQuest then continue end
        if tick() - lastQuest < 8 then continue end
        lastQuest = tick()

        fireRemote("acceptQuest")
        fireRemote("AcceptQuest")
        fireRemote("claimQuest")
        fireRemote("ClaimQuest")
        fireRemote("completeQuest")
        fireRemote("questAccept")
        fireRemote("questClaim")
        fireRemote("questComplete")
        print("[FISCH] Auto quest fired")
    end
end)

-- AUTO COLLECT
task.spawn(function()
    while true do
        task.wait(0.3)
        if not _G.AutoCollect then continue end
        if not hrp then continue end
        local COLLECT_RANGE = 20
        for _, obj in ipairs(WS:GetDescendants()) do
            if not hrp then break end
            local n = obj.Name:lower()
            if n:find("pickup") or n:find("loot") or n:find("drop")
            or n:find("reward") or n:find("coin") or n:find("gem")
            or n:find("treasure") or n:find("chest") then
                local pos
                if obj:IsA("BasePart") then
                    pos = obj.Position
                elseif obj:IsA("Model") then
                    local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                    if p then pos = p.Position end
                end
                if pos and (pos - hrp.Position).Magnitude <= COLLECT_RANGE then
                    if obj:IsA("BasePart") then
                        pcall(function()
                            hrp.CFrame = CFrame.new(pos + Vector3.new(0,2,0))
                        end)
                    end
                    fireRemote("collect")
                    fireRemote("pickup")
                    fireRemote("Collect")
                    fireRemote("Pickup")
                end
            end
        end
    end
end)

-- ANTI AFK
local lastAFK = 0
task.spawn(function()
    while true do
        task.wait(5)
        if not _G.AntiAFK then continue end
        if tick() - lastAFK < 240 then continue end
        lastAFK = tick()
        if not hrp or not hum then continue end
        local dirs = {
            Vector3.new(2,0,0), Vector3.new(-2,0,0),
            Vector3.new(0,0,2), Vector3.new(0,0,-2),
        }
        local d = dirs[math.random(1, #dirs)]
        pcall(function() hum:MoveTo(hrp.Position + d) end)
        task.wait(0.5)
        pcall(function() hum:MoveTo(hrp.Position - d) end)
        print("[FISCH] Anti-AFK triggered")
    end
end)

-- SPEED BOOST
task.spawn(function()
    while true do
        task.wait(0.2)
        if not hum then continue end
        if _G.SpeedBoost then
            pcall(function() hum.WalkSpeed = 32 end)
        else
            if hum.WalkSpeed == 32 then
                pcall(function() hum.WalkSpeed = 16 end)
            end
        end
    end
end)

-- FLY
local flyConn
local function updateFly()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if not _G.Fly then
        if hum then pcall(function() hum.PlatformStand = false end) end
        return
    end
    if hum then pcall(function() hum.PlatformStand = true end) end

    flyConn = RUN.RenderStepped:Connect(function()
        if not _G.Fly then
            if hum then pcall(function() hum.PlatformStand = false end) end
            flyConn:Disconnect() flyConn = nil
            return
        end
        if not hrp then return end
        local cam  = WS.CurrentCamera
        local cf   = cam.CFrame
        local move = Vector3.new(0,0,0)
        local spd  = _G.FlySpeed or 50
        if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then
            move = move + Vector3.new(0,1,0)
        end
        if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
            move = move - Vector3.new(0,1,0)
        end
        if move.Magnitude > 0.01 then move = move.Unit * spd end
        pcall(function()
            hrp.Velocity               = move
            hrp.AssemblyLinearVelocity = move
        end)
    end)
end

task.spawn(function()
    local prev = false
    while true do
        task.wait(0.2)
        if _G.Fly ~= prev then
            prev = _G.Fly
            updateFly()
        end
    end
end)

-- ESP
local espBills = {}
local function clearESP()
    for _, b in ipairs(espBills) do pcall(function() b:Destroy() end) end
    espBills = {}
end

local RARE_KEYWORDS = {
    "legendary","mythic","ancient","divine","prismatic",
    "event","special","rare","epic","ultra"
}
local function isRare(name)
    local low = name:lower()
    for _, k in ipairs(RARE_KEYWORDS) do
        if low:find(k) then return true end
    end
    return false
end

local function mkBill(adornee, text, color)
    if not adornee then return end
    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.fromOffset(140, 32)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.Adornee     = adornee
    bb.Parent      = WS

    local lbl = Instance.new("TextLabel", bb)
    lbl.Size                   = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 0.25
    lbl.BackgroundColor3       = Color3.new(0,0,0)
    lbl.Text                   = text
    lbl.TextColor3             = color
    lbl.TextSize               = 12
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3       = Color3.new(0,0,0)
    table.insert(espBills, bb)
end

task.spawn(function()
    while true do
        task.wait(1.5)
        if not _G.ESP then clearESP() continue end
        clearESP()
        if not hrp then continue end
        local range = _G.ESPRange or 500
        for _, obj in ipairs(WS:GetDescendants()) do
            if not hrp then break end
            local name = obj.Name
            local nameLow = name:lower()
            local pos
            if obj:IsA("BasePart") then pos = obj.Position
            elseif obj:IsA("Model") then
                local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                if p then pos = p.Position end
            end
            if not pos then continue end
            if (pos - hrp.Position).Magnitude > range then continue end

            if nameLow:find("spot") or nameLow:find("bobber")
            or nameLow:find("fishing") or nameLow:find("buoy") then
                local adornee = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")) or obj
                mkBill(adornee, "🎣 " .. name, Color3.fromRGB(0, 255, 150))
            end

            if nameLow:find("fish") and not nameLow:find("rod")
            and not nameLow:find("tool") and not nameLow:find("script") then
                local adornee = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")) or obj
                if isRare(name) then
                    mkBill(adornee, "⭐ " .. name, Color3.fromRGB(255, 200, 0))
                else
                    mkBill(adornee, "🐟 " .. name, Color3.fromRGB(100, 200, 255))
                end
            end

            if nameLow:find("treasure") or nameLow:find("chest")
            or nameLow:find("loot") then
                local adornee = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")) or obj
                mkBill(adornee, "💰 " .. name, Color3.fromRGB(255, 220, 50))
            end
        end
    end
end)

-- FISH RADAR
local notified = {}
task.spawn(function()
    while true do
        task.wait(2)
        if not _G.FishRadar then
            notified = {}
            continue
        end
        if not hrp then continue end
        for _, obj in ipairs(WS:GetDescendants()) do
            if not isRare(obj.Name) then continue end
            local nameLow = obj.Name:lower()
            if not nameLow:find("fish") then continue end
            local pos
            if obj:IsA("BasePart") then pos = obj.Position
            elseif obj:IsA("Model") then
                local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                if p then pos = p.Position end
            end
            if pos and (pos - hrp.Position).Magnitude < 250 then
                if not notified[obj] then
                    notified[obj] = true
                    pcall(function()
                        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                            Text     = "[RADAR] 🌟 RARE: " .. obj.Name,
                            Color    = Color3.fromRGB(255,200,0),
                            FontSize = Enum.FontSize.Size18,
                        })
                    end)
                    print("[FISCH RADAR] Rare fish nearby: " .. obj.Name)
                end
            else
                notified[obj] = nil
            end
        end
    end
end)
--============================================================
-- WINDOW UI
--============================================================
local Window = WindUI:CreateWindow({
    Title = "Pall x Fisch",
    Folder = "pallfisch",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open Pall Fisch",
        CornerRadius = UDim.new(1, 0), StrokeThickness = 3,
        Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#3DC9FF"), Color3.fromHex("#10C550")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})
Window:Tag({ Title = "v3.0.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: FISHING
--============================================================
local TabFish = Window:Tab({
    Title = "Fishing", Desc = "Auto cast, reel, shake",
    Icon = "solar:fish-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s = TabFish:Section({ Title = "Auto Fishing", Box = true, BoxBorder = true, Opened = true })

    s:Toggle({
        Title = "Auto Fish",
        Desc = "Cast → tunggu bite → reel",
        Value = false,
        Callback = function(v) _G.AutoFish = v end,
    })
    s:Space()
    s:Toggle({
        Title = "Auto Reel",
        Desc = "Spam reel saat bar muncul",
        Value = false,
        Callback = function(v) _G.AutoReel = v end,
    })
    s:Space()
    s:Toggle({
        Title = "No Shake",
        Desc = "Skip minigame guncang",
        Value = false,
        Callback = function(v) _G.NoShake = v end,
    })
    s:Space()
    s:Toggle({
        Title = "Infinite Stamina",
        Value = false,
        Callback = function(v) _G.InfiniteStam = v end,
    })

    local st = TabFish:Section({ Title = "Auto Equip Best Rod", Box = true, BoxBorder = true, Opened = true })
    st:Toggle({
        Title = "Auto Equip Best Rod",
        Value = false,
        Callback = function(v) _G.AutoEquipBest = v end,
    })
end

--============================================================
-- TAB: ITEMS
--============================================================
local TabItems = Window:Tab({
    Title = "Items", Desc = "Sell, Quest, Collect",
    Icon = "solar:bag-4-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s = TabItems:Section({ Title = "Auto Actions", Box = true, BoxBorder = true, Opened = true })

    s:Toggle({
        Title = "Auto Sell",
        Value = false,
        Callback = function(v) _G.AutoSell = v end,
    })
    s:Space()
    s:Toggle({
        Title = "Auto Quest",
        Value = false,
        Callback = function(v) _G.AutoQuest = v end,
    })
    s:Space()
    s:Toggle({
        Title = "Auto Collect",
        Desc = "Ambil loot sekitar",
        Value = false,
        Callback = function(v) _G.AutoCollect = v end,
    })
end

--============================================================
-- TAB: MOVEMENT
--============================================================
local TabMove = Window:Tab({
    Title = "Movement", Desc = "Speed, Fly, AFK",
    Icon = "solar:running-2-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s = TabMove:Section({ Title = "Movement", Box = true, BoxBorder = true, Opened = true })

    s:Toggle({
        Title = "Speed Boost (32)",
        Value = false,
        Callback = function(v) _G.SpeedBoost = v end,
    })
    s:Space()
    s:Toggle({
        Title = "Anti-AFK",
        Value = false,
        Callback = function(v) _G.AntiAFK = v end,
    })
    s:Space()
    s:Toggle({
        Title = "Fly (WASD + Space/E)",
        Value = false,
        Callback = function(v) _G.Fly = v end,
    })
    s:Space()
    s:Slider({
        Title = "Fly Speed", Step = 5,
        Value = { Min = 10, Max = 300, Default = 50 },
        Callback = function(v) _G.FlySpeed = v end,
    })
end

--============================================================
-- TAB: VISUAL
--============================================================
local TabVisual = Window:Tab({
    Title = "Visual", Desc = "ESP & Radar",
    Icon = "solar:eye-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local s = TabVisual:Section({ Title = "Visuals", Box = true, BoxBorder = true, Opened = true })

    s:Toggle({
        Title = "ESP (Fishing Spot, Fish, Chest)",
        Value = false,
        Callback = function(v) _G.ESP = v end,
    })
    s:Space()
    s:Slider({
        Title = "ESP Range", Step = 50,
        Value = { Min = 100, Max = 2000, Default = 500 },
        Callback = function(v) _G.ESPRange = v end,
    })
    s:Space()
    s:Toggle({
        Title = "Fish Radar (notif rare fish)",
        Value = false,
        Callback = function(v) _G.FishRadar = v end,
    })
end

--============================================================
-- TAB: INFO
--============================================================
local TabInfo = Window:Tab({
    Title = "Info", Desc = "Status & log",
    Icon = "solar:info-circle-bold", IconColor = Grey, IconShape = "Square", Border = true,
})
do
    local s = TabInfo:Section({ Title = "Status", Box = true, BoxBorder = true, Opened = true })
    local statusText = s:Section({ Title = "Loading...", TextSize = 14, TextTransparency = 0.2 })

    task.spawn(function()
        while task.wait(1) do
            local rod = equippedRod()
            local txt = string.format(
                "State: %s\nRod: %s\nFish: %s | Reel: %s | Shake: %s\nSell: %s | Quest: %s | Collect: %s\nFly: %s | ESP: %s | Radar: %s",
                fishState,
                rod and rod.Name or "none",
                tostring(_G.AutoFish), tostring(_G.AutoReel), tostring(not _G.NoShake),
                tostring(_G.AutoSell), tostring(_G.AutoQuest), tostring(_G.AutoCollect),
                tostring(_G.Fly), tostring(_G.ESP), tostring(_G.FishRadar)
            )
            pcall(function() statusText:SetTitle(txt) end)
        end
    end)
end

--============================================================
-- NOTIF
--============================================================
WindUI:Notify({
    Title = "Pall Fisch v3.0.0",
    Content = "Logic dari NIGHT + WindUI. Toggle di tab masing-masing.",
    Icon = "solar:bell-bold",
    Duration = 8,
})

print("════════════════════════════════════════════")
print("[PALL-FISCH] v3.0.0 loaded.")
print("Logic: NIGHT community script")
print("UI: WindUI")
print("════════════════════════════════════════════")
