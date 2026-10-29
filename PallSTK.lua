--[[
    PALL — STK ULTIMATE (GOOD & EVIL MODE)
    Version : v10.2.3 (Anti-Flicker & Escape Lock Fix)
--]]

print("[PALL-STK] Memuat STK Farm v10.2.3...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer

local WindUI
if _G.PallWindUI then
    WindUI = _G.PallWindUI
else
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end)
    if not ok then error("[PALL-STK] Gagal load WindUI.") end
    WindUI = _G.PallWindUI or result
end

local Purple = Color3.fromHex("#B464FF")
local Yellow = Color3.fromHex("#FFD700")
local White = Color3.fromRGB(255, 255, 255)
local Red = Color3.fromHex("#FF3232")
local Blue = Color3.fromHex("#0096FF")
local Green = Color3.fromHex("#10C550")

if _G.PALL_STK_FARM then
    _G.PALL_STK_FARM = false
    task.wait(0.5)
end
_G.PALL_STK_FARM = true

local State = {
    ESPEnabled = true,
    PlayerESP = true,
    AutoCollect = false,
    AutoRevive = false,
    TeleportDelay = 0.15,
    TicketKeyword = "direwick",
    
    EvilAutoKill = false,
    TweenSpeed = 0.3,
    
    AutoEscape = false,
    IsCollecting = false,
    IsReviving = false,
    IsKilling = false,
    IsEscaping = false, -- Kunci khusus biar ga tabrakan
}

local ItemCache = {}
local ItemDrawings = { Boxes = {}, Texts = {} }
local PlayerDrawings = { Boxes = {}, Names = {} }
local Cooldowns = {}
local CurrentEscapeTrigger = nil

-- CACHE ITEM (DENGAN FILTER LOBBY)
local function addToCache(obj)
    if not obj then return end
    local lobby = Workspace:FindFirstChild("_Lobby")
    if lobby and obj:IsDescendantOf(lobby) then return end

    local function isInsideLootSpawns(part)
        local model = part.Parent
        local idPart = model and model.Parent
        return (model and model.Name == "Model" and idPart and idPart.Parent and idPart.Parent.Name == "LootSpawns")
    end

    if obj.Name == "Candy" and obj:IsA("BasePart") then
        if isInsideLootSpawns(obj) then
            table.insert(ItemCache, { instance = obj, part = obj, isTicket = false })
        end
    elseif State.TicketKeyword ~= "" and obj:IsA("BasePart") then
        local nameLower = obj.Name:lower()
        if nameLower:find(State.TicketKeyword:lower(), 1, true) then
            if isInsideLootSpawns(obj) then
                table.insert(ItemCache, { instance = obj, part = obj, isTicket = true })
            end
        end
    end
end

for _, obj in ipairs(Workspace:GetDescendants()) do addToCache(obj) end
Workspace.DescendantAdded:Connect(addToCache)

-- PENCARIAN PINTU KELUAR (ANTI-FLICKER)
task.spawn(function()
    while task.wait(1) do
        if State.AutoEscape then
            local foundTrigger = nil
            for _, map in ipairs(Workspace:GetChildren()) do
                if map.Name ~= "_Lobby" then
                    local exits = map:FindFirstChild("Exits")
                    if exits then
                        for _, gateway in ipairs(exits:GetChildren()) do
                            local trigger = gateway:FindFirstChild("Trigger")
                            if trigger and trigger:IsA("BasePart") then
                                foundTrigger = trigger
                                break
                            end
                        end
                    end
                end
                if foundTrigger then break end
            end
            -- Hanya update kalau ketemu (biar ga berkedip nil)
            if foundTrigger then
                CurrentEscapeTrigger = foundTrigger
            elseif not State.IsEscaping then
                CurrentEscapeTrigger = nil
            end
        else
            CurrentEscapeTrigger = nil
        end
    end
end)

-- UPDATE ESP ITEM
local function updateItemESP()
    if not State.ESPEnabled then
        for obj, _ in pairs(ItemDrawings.Boxes) do
            pcall(function() ItemDrawings.Boxes[obj]:Remove() end) ItemDrawings.Boxes[obj] = nil
            pcall(function() ItemDrawings.Texts[obj]:Remove() end) ItemDrawings.Texts[obj] = nil
        end
        return
    end

    local cam = Workspace.CurrentCamera
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not cam then return end

    local rendered = {}
    for i = #ItemCache, 1, -1 do
        local data = ItemCache[i]
        local obj = data.instance
        local part = data.part
        if not obj or not obj.Parent or not part or not part.Parent then
            if ItemDrawings.Boxes[obj] then ItemDrawings.Boxes[obj]:Remove() ItemDrawings.Boxes[obj] = nil end
            if ItemDrawings.Texts[obj] then ItemDrawings.Texts[obj]:Remove() ItemDrawings.Texts[obj] = nil end
            table.remove(ItemCache, i)
        else
            local distance = (hrp.Position - part.Position).Magnitude
            if distance <= 2000 then
                rendered[obj] = true
                if not ItemDrawings.Boxes[obj] then
                    local b = Drawing.new("Square") b.Thickness = 1 b.Filled = false ItemDrawings.Boxes[obj] = b
                end
                if not ItemDrawings.Texts[obj] then
                    local t = Drawing.new("Text") t.Size = 14 t.Center = true t.Outline = true t.Color = White ItemDrawings.Texts[obj] = t
                end
                local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen and screenPos.Z > 0 then
                    local sizeY = math.clamp(500 / screenPos.Z, 10, 40)
                    local box = ItemDrawings.Boxes[obj]
                    box.Color = data.isTicket and Yellow or Purple
                    box.Size = Vector2.new(sizeY, sizeY)
                    box.Position = Vector2.new(screenPos.X - sizeY/2, screenPos.Y - sizeY/2)
                    box.Visible = true
                    local text = ItemDrawings.Texts[obj]
                    text.Text = (data.isTicket and "Ticket" or "Candy") .. " [" .. math.floor(distance) .. "m]"
                    text.Position = Vector2.new(screenPos.X, screenPos.Y - sizeY/2 - 12)
                    text.Visible = true
                else
                    ItemDrawings.Boxes[obj].Visible = false ItemDrawings.Texts[obj].Visible = false
                end
            else
                if ItemDrawings.Boxes[obj] then ItemDrawings.Boxes[obj].Visible = false end
                if ItemDrawings.Texts[obj] then ItemDrawings.Texts[obj].Visible = false end
            end
        end
    end
    for obj, _ in pairs(ItemDrawings.Boxes) do
        if not rendered[obj] then
            pcall(function() ItemDrawings.Boxes[obj]:Remove() end) ItemDrawings.Boxes[obj] = nil
            pcall(function() ItemDrawings.Texts[obj]:Remove() end) ItemDrawings.Texts[obj] = nil
        end
    end
end

-- UPDATE ESP PLAYER
local function updatePlayerESP()
    if not State.PlayerESP then
        for plr, _ in pairs(PlayerDrawings.Boxes) do
            if PlayerDrawings.Boxes[plr] then PlayerDrawings.Boxes[plr]:Remove() PlayerDrawings.Boxes[plr] = nil end
            if PlayerDrawings.Names[plr] then PlayerDrawings.Names[plr]:Remove() PlayerDrawings.Names[plr] = nil end
        end
        return
    end

    local cam = Workspace.CurrentCamera
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not cam then return end

    local rendered = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local pHum = plr.Character:FindFirstChild("Humanoid")
            local pRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            if pHum and pRoot and pHum.Health > 0 then
                local distance = (hrp.Position - pRoot.Position).Magnitude
                if distance <= 2000 then
                    rendered[plr] = true
                    local isAlly = (plr.Team and LP.Team and plr.Team == LP.Team) or (plr.TeamColor and LP.TeamColor and plr.TeamColor == LP.TeamColor)
                    local color = isAlly and Blue or Red
                    
                    if not PlayerDrawings.Boxes[plr] then
                        local b = Drawing.new("Square") b.Thickness = 1 b.Filled = false PlayerDrawings.Boxes[plr] = b
                        local n = Drawing.new("Text") n.Size = 14 n.Center = true n.Outline = true PlayerDrawings.Names[plr] = n
                    end
                    
                    local screenPos, onScreen = cam:WorldToViewportPoint(pRoot.Position)
                    if onScreen and screenPos.Z > 0 then
                        local sizeY = math.clamp(1000 / screenPos.Z, 20, 100)
                        local box = PlayerDrawings.Boxes[plr]
                        box.Size = Vector2.new(sizeY/2, sizeY)
                        box.Position = Vector2.new(screenPos.X - sizeY/4, screenPos.Y - sizeY/2)
                        box.Color = color box.Visible = true
                        
                        local text = PlayerDrawings.Names[plr]
                        local status = isAlly and "[Teman]" or "[Musuh]"
                        text.Text = plr.Name .. " " .. status
                        text.Color = color text.Position = Vector2.new(screenPos.X, screenPos.Y - sizeY/2 - 15) text.Visible = true
                    else
                        PlayerDrawings.Boxes[plr].Visible = false PlayerDrawings.Names[plr].Visible = false
                    end
                end
            end
        end
    end
    for plr, _ in pairs(PlayerDrawings.Boxes) do
        if not rendered[plr] then
            pcall(function() PlayerDrawings.Boxes[plr]:Remove() end) PlayerDrawings.Boxes[plr] = nil
            pcall(function() PlayerDrawings.Names[plr]:Remove() end) PlayerDrawings.Names[plr] = nil
        end
    end
end

-- LOGIC AUTO REVIVE
local function doAutoRevive()
    if not State.AutoRevive or State.IsReviving then return false end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end

    local targetToRevive = nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local isAlly = (plr.Team and LP.Team and plr.Team == LP.Team) or (plr.TeamColor and LP.TeamColor and plr.TeamColor == LP.TeamColor)
            if isAlly then
                local pHum = plr.Character:FindFirstChild("Humanoid")
                local pRoot = plr.Character:FindFirstChild("HumanoidRootPart")
                if pHum and pRoot and pHum.Health > 0 then
                    local isKnocked = pHum.PlatformStand or (pRoot:FindFirstChild("PromptAttachment") ~= nil)
                    if isKnocked then targetToRevive = plr break end
                end
            end
        end
    end

    if targetToRevive then
        State.IsReviving = true
        local targetRoot = targetToRevive.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            pcall(function() hrp.CFrame = targetRoot.CFrame end)
            task.wait(0.2)
            
            local promptAttachment = targetRoot:FindFirstChild("PromptAttachment")
            local prompt = promptAttachment and promptAttachment:FindFirstChildWhichIsA("ProximityPrompt")
            
            if prompt then
                pcall(function() fireproximityprompt(prompt) end)
            else
                pcall(function()
                    firetouchinterest(hrp, targetRoot, 0)
                    task.wait(0.1)
                    firetouchinterest(hrp, targetRoot, 1)
                end)
            end
            task.wait(2)
        end
        State.IsReviving = false
        return true
    end
    return false
end

-- LOGIC AUTO COLLECT (DENGAN FILTER Y & ESCAPE LOCK)
local function doAutoCollect()
    -- JIKA LAGI ESCAPE, JANGAN COLLECT!
    if not State.AutoCollect or State.IsCollecting or State.IsReviving or State.IsEscaping or #ItemCache == 0 then return end
    
    -- Cek jarak trigger untuk berhenti farming kalau pintu udah deket
    if State.AutoEscape and CurrentEscapeTrigger then return end 

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    State.IsCollecting = true
    local availableItems = {}
    local now = tick()
    
    for _, data in ipairs(ItemCache) do
        local isCooldown = Cooldowns[data.instance] and (now - Cooldowns[data.instance] <= 2)
        if not isCooldown then
            -- Filter anti terbang (jarak vertikal > 60 diabaikan)
            local yDifference = math.abs(hrp.Position.Y - data.part.Position.Y)
            if yDifference <= 60 then
                table.insert(availableItems, data)
            end
        end
    end

    if #availableItems > 0 then
        local target = availableItems[math.random(1, #availableItems)]
        Cooldowns[target.instance] = tick()
        
        pcall(function() hrp.CFrame = CFrame.new(target.part.Position + Vector3.new(0, 3, 0)) end)
        task.wait(State.TeleportDelay)
        
        pcall(function()
            firetouchinterest(hrp, target.part, 0)
            if target.instance.Name == "Candy" and target.instance.Parent and target.instance.Parent.Parent then
                firetouchinterest(hrp, target.instance.Parent.Parent, 0)
            end
            task.wait(0.05)
            firetouchinterest(hrp, target.part, 1)
            if target.instance.Name == "Candy" and target.instance.Parent and target.instance.Parent.Parent then
                firetouchinterest(hrp, target.instance.Parent.Parent, 1)
            end
        end)
    end
    State.IsCollecting = false
end

-- LOGIC EVIL MODE
local function doEvilMode()
    if not State.EvilAutoKill or State.IsKilling or State.IsReviving or State.IsCollecting or State.IsEscaping then return end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    local closestEnemy = nil
    local shortestDist = 500
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local pHum = plr.Character:FindFirstChild("Humanoid")
            local pRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            if pHum and pRoot and pHum.Health > 0 then
                local isAlly = (plr.Team and LP.Team and plr.Team == LP.Team) or (plr.TeamColor and LP.TeamColor and plr.TeamColor == LP.TeamColor)
                if not isAlly then
                    local dist = (hrp.Position - pRoot.Position).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        closestEnemy = plr
                    end
                end
            end
        end
    end

    if closestEnemy then
        State.IsKilling = true
        local eRoot = closestEnemy.Character:FindFirstChild("HumanoidRootPart")
        if eRoot then
            local goal = { CFrame = CFrame.new(eRoot.Position + Vector3.new(0, 2, 0)) }
            local tweenInfo = TweenInfo.new(State.TweenSpeed, Enum.EasingStyle.Linear)
            local tween = TweenService:Create(hrp, tweenInfo, goal)
            tween:Play()
            tween.Completed:Wait()
            
            for i = 1, 5 do
                pcall(function()
                    firetouchinterest(hrp, eRoot, 0)
                    task.wait(0.05)
                    firetouchinterest(hrp, eRoot, 1)
                end)
                
                local tool = char:FindFirstChildWhichIsA("Tool")
                if tool then pcall(function() tool:Activate() end) end
                task.wait(0.05)
            end
        end
        State.IsKilling = false
    end
end

-- 1X TAP MATI SEMUA
local function killAllEnemies()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    WindUI:Notify({Title="Killer Mode", Content="Memburu semua musuh...", Duration=3})
    
    task.spawn(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local pHum = plr.Character:FindFirstChild("Humanoid")
                local pRoot = plr.Character:FindFirstChild("HumanoidRootPart")
                if pHum and pRoot and pHum.Health > 0 then
                    local isAlly = (plr.Team and LP.Team and plr.Team == LP.Team) or (plr.TeamColor and LP.TeamColor and plr.TeamColor == LP.TeamColor)
                    if not isAlly then
                        local goal = { CFrame = CFrame.new(pRoot.Position + Vector3.new(0, 2, 0)) }
                        local tween = TweenService:Create(hrp, TweenInfo.new(0.3, Enum.EasingStyle.Linear), goal)
                        tween:Play()
                        tween.Completed:Wait()
                        
                        for i=1, 5 do
                            pcall(function()
                                firetouchinterest(hrp, pRoot, 0)
                                task.wait(0.05)
                                firetouchinterest(hrp, pRoot, 1)
                            end)
                            local tool = char:FindFirstChildWhichIsA("Tool")
                            if tool then pcall(function() tool:Activate() end) end
                            task.wait(0.05)
                        end
                    end
                end
            end
        end
    end)
end

-- LOGIC AUTO ESCAPE (LOCKED)
local function doAutoEscape()
    if not State.AutoEscape or not CurrentEscapeTrigger or State.IsEscaping then return false end
    
    State.IsEscaping = true
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then 
        State.IsEscaping = false
        return false 
    end

    pcall(function() 
        hrp.CFrame = CFrame.new(CurrentEscapeTrigger.Position + Vector3.new(0, 3, 0)) 
    end)
    task.wait(0.2)
    
    pcall(function()
        firetouchinterest(hrp, CurrentEscapeTrigger, 0)
        task.wait(0.1)
        firetouchinterest(hrp, CurrentEscapeTrigger, 1)
    end)
    
    task.wait(0.5)
    State.IsEscaping = false
    return true
end

-- LOOP UTAMA (PRIORITAS MUTLAK)
RunService.RenderStepped:Connect(function()
    updateItemESP()
    updatePlayerESP()
end)

RunService.Heartbeat:Connect(function()
    -- 1. Prioritas Utama: Escape
    if State.AutoEscape and CurrentEscapeTrigger then
        pcall(doAutoEscape)
    -- 2. Prioritas Kedua: Revive
    elseif State.AutoRevive then
        pcall(doAutoRevive)
    end
    
    -- 3. Auto Collect HANYA jalan kalau TIDAK SEDANG ESCAPE & TIDAK SEDANG REVIVE
    if not State.IsReviving and not State.IsEscaping and not CurrentEscapeTrigger then
        pcall(doAutoCollect)
    end
    
    -- 4. Killer Mode
    if not State.IsReviving and not State.IsCollecting and not State.IsEscaping and not CurrentEscapeTrigger then
        pcall(doEvilMode)
    end
end)

-- UI
local Window = WindUI:CreateWindow({
    Title = "STK Farm v10.2.3",
    Folder = "pallstk",
    Icon = "solar:candy-bold",
    NewElements = true,
    OpenButton = {
        Title = "Open STK Menu",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#10C550"), Color3.fromHex("#FF3232")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})

local TabGood = Window:Tab({ Title = "Mode Baik", Icon = "solar:shield-check-bold", IconColor = Blue, IconShape = "Square", Border = true })
local SecFarm = TabGood:Section({ Title = "Collect Settings", Box = true, BoxBorder = true, Opened = true })
SecFarm:Toggle({ Title = "ESP Candy & Ticket", Value = true, Callback = function(v) State.ESPEnabled = v end })
SecFarm:Space()
SecFarm:Toggle({ Title = "Auto Collect (Random)", Value = false, Callback = function(v) State.AutoCollect = v end })
SecFarm:Space()
SecFarm:Slider({ Title = "Teleport Delay (detik)", Step = 0.05, Value = { Min = 0.05, Max = 0.5, Default = 0.15 }, Callback = function(v) State.TeleportDelay = v end })
SecFarm:Space()
SecFarm:Input({ Title = "Kata Kunci Tiket", Value = State.TicketKeyword, Callback = function(v) 
    State.TicketKeyword = v 
    for i = #ItemCache, 1, -1 do
        if ItemCache[i].isTicket then table.remove(ItemCache, i) end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do addToCache(obj) end
end })

local SecGoodPlayer = TabGood:Section({ Title = "Player & Revive", Box = true, BoxBorder = true, Opened = true })
SecGoodPlayer:Toggle({ Title = "Wallhack (Teman Biru, Musuh Merah)", Value = true, Callback = function(v) State.PlayerESP = v end })
SecGoodPlayer:Space()
SecGoodPlayer:Toggle({ Title = "Auto Revive Teman", Value = false, Callback = function(v) State.AutoRevive = v end })

local TabEvil = Window:Tab({ Title = "Mode Jahat", Icon = "solar:skull-bold", IconColor = Red, IconShape = "Square", Border = true })
local SecEvil = TabEvil:Section({ Title = "Killer Mode (Tween)", Box = true, BoxBorder = true, Opened = true })
SecEvil:Toggle({ Title = "Auto Kill Musuh Terdekat", Value = false, Callback = function(v) State.EvilAutoKill = v end })
SecEvil:Space()
SecEvil:Slider({ Title = "Tween Speed (detik)", Step = 0.05, Value = { Min = 0.1, Max = 1.0, Default = 0.3 }, Callback = function(v) State.TweenSpeed = v end })
SecEvil:Space()
SecEvil:Button({ Title = "1x Tap Mati Semua", Callback = function() 
    State.EvilAutoKill = false 
    killAllEnemies() 
end })

local TabEscape = Window:Tab({ Title = "Auto Escape", Icon = "solar:exit-bold", IconColor = Green, IconShape = "Square", Border = true })
local SecEscape = TabEscape:Section({ Title = "Escape Settings", Box = true, BoxBorder = true, Opened = true })
SecEscape:Toggle({ Title = "Auto Kabur (Ke Pintu Exit)", Value = false, Callback = function(v) State.AutoEscape = v end })
SecEscape:Space()
SecEscape:Note({ Title = "Info", Desc = "Bebas tabrakan. Kalau pintu keluar terbuka, Auto Collect akan mati total dan karakter fokus kabur." })

WindUI:Notify({ Title = "STK v10.2.3", Content = "Bebas Terbang Naik Turun!", Icon = "solar:bell-bold", Duration = 6 })
print("[PALL-STK] v10.2.3 loaded.")
