--[[
    PALL — UNIVERSAL COMBAT (ESP + Aimbot + Silent Aim)
    Version : v1.2.1-Stable (Safe Args Rewrite + Anti-Stuck ESP)
--]]

print("[PALL-UNIV] Memuat Universal Combat v1.2.1-Stable...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer

-- LOAD WINDUI
local WindUI
if _G.PallWindUI then
    WindUI = _G.PallWindUI
else
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end)
    if not ok then error("[PALL-UNIV] Gagal load WindUI.") end
    WindUI = _G.PallWindUI or result
end

local Green = Color3.fromHex("#10C550")
local Red   = Color3.fromHex("#EF4F1D")
local White = Color3.fromRGB(255, 255, 255)
local Yellow= Color3.fromRGB(255, 200, 60)

-- STATE
if _G.PALL_UNIV_RUNNING then
    _G.PALL_UNIV_RUNNING = false
    task.wait(0.5)
end
_G.PALL_UNIV_RUNNING = true

local State = {
    ESPEnabled = false,
    ESPBox = true,
    ESPName = true,
    ESPHealth = true,
    ESPDistance = true,
    ESPTracer = false,
    ESPTeamCheck = true,
    ESPMaxDistance = 1000,

    AimbotEnabled = false,
    AimbotFOV = 150,
    AimbotSmooth = 0.15,
    AimbotTargetPart = "Head",
    AimbotType = "Camera",
    AimbotShowFOV = true,

    SilentAimEnabled = false,
    SilentAimFOV = 300,
    SilentAimShowFOV = true,
    SilentAimFilter = "shoot,fire,attack,hit,damage,click,sword,slash,swing,throw,knife,gun,weapon,tool,combat",

    CurrentTarget = nil,
    CachedSilentTarget = nil,
    CachedSilentAimPart = nil
}

-- DRAWING SYSTEM
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.Color = White
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Visible = false

local SilentFOVCircle = Drawing.new("Circle")
SilentFOVCircle.Thickness = 1
SilentFOVCircle.Color = Yellow
SilentFOVCircle.Filled = false
SilentFOVCircle.Transparency = 1
SilentFOVCircle.Visible = false

local Drawings = { Boxes = {}, Names = {}, Healths = {}, Distances = {}, Tracers = {} }

local function clearAllDrawings()
    for _, category in pairs(Drawings) do
        for key, obj in pairs(category) do
            pcall(function() obj:Remove() end)
            category[key] = nil
        end
    end
end

local function removePlayerDrawings(plr)
    for _, category in pairs(Drawings) do
        if category[plr] then
            pcall(function() category[plr]:Remove() end)
            category[plr] = nil
        end
    end
end

local function isAlly(plr)
    if not State.ESPTeamCheck then return false end
    if plr.Team and LP.Team and plr.Team == LP.Team then return true end
    return false
end

local function updateESP()
    if not State.ESPEnabled then
        clearAllDrawings()
        return
    end

    local cam = Workspace.CurrentCamera
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    
    if not hrp or not cam then 
        clearAllDrawings()
        return 
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if not plr.Parent or not plr.Character then
            removePlayerDrawings(plr)
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character and not isAlly(plr) then
            local char = plr.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            
            if root and hum and hum.Health > 0 then
                local distance = (hrp.Position - root.Position).Magnitude
                
                if distance <= State.ESPMaxDistance then
                    local screenPos, onScreen = cam:WorldToViewportPoint(root.Position)
                    
                    if onScreen and screenPos.Z > 0 then
                        local sizeY = math.clamp(1000 / screenPos.Z, 20, 100)
                        local sizeX = sizeY / 2

                        if State.ESPBox then
                            if not Drawings.Boxes[plr] then
                                Drawings.Boxes[plr] = Drawing.new("Square")
                                Drawings.Boxes[plr].Thickness = 1
                                Drawings.Boxes[plr].Color = Red
                                Drawings.Boxes[plr].Filled = false
                            end
                            local box = Drawings.Boxes[plr]
                            box.Size = Vector2.new(sizeX, sizeY)
                            box.Position = Vector2.new(screenPos.X - sizeX/2, screenPos.Y - sizeY/2)
                            box.Visible = true
                        end

                        if State.ESPName then
                            if not Drawings.Names[plr] then
                                Drawings.Names[plr] = Drawing.new("Text")
                                Drawings.Names[plr].Size = 16
                                Drawings.Names[plr].Center = true
                                Drawings.Names[plr].Outline = true
                                Drawings.Names[plr].Color = Color3.new(1,1,1)
                            end
                            local name = Drawings.Names[plr]
                            name.Text = plr.Name
                            name.Position = Vector2.new(screenPos.X, screenPos.Y - sizeY/2 - 15)
                            name.Visible = true
                        end

                        if State.ESPHealth then
                            if not Drawings.Healths[plr] then
                                Drawings.Healths[plr] = Drawing.new("Text")
                                Drawings.Healths[plr].Size = 14
                                Drawings.Healths[plr].Center = true
                                Drawings.Healths[plr].Outline = true
                                Drawings.Healths[plr].Color = Green
                            end
                            local hp = Drawings.Healths[plr]
                            hp.Text = math.floor(hum.Health) .. " HP"
                            hp.Position = Vector2.new(screenPos.X, screenPos.Y + sizeY/2 + 5)
                            hp.Visible = true
                        end

                        if State.ESPDistance then
                            if not Drawings.Distances[plr] then
                                Drawings.Distances[plr] = Drawing.new("Text")
                                Drawings.Distances[plr].Size = 12
                                Drawings.Distances[plr].Center = true
                                Drawings.Distances[plr].Outline = true
                                Drawings.Distances[plr].Color = Color3.new(0.8,0.8,0.8)
                            end
                            local dist = Drawings.Distances[plr]
                            dist.Text = "[" .. math.floor(distance) .. "m]"
                            dist.Position = Vector2.new(screenPos.X, screenPos.Y + sizeY/2 + 20)
                            dist.Visible = true
                        end

                        if State.ESPTracer then
                            if not Drawings.Tracers[plr] then
                                Drawings.Tracers[plr] = Drawing.new("Line")
                                Drawings.Tracers[plr].Thickness = 1
                                Drawings.Tracers[plr].Color = Red
                            end
                            local tracer = Drawings.Tracers[plr]
                            tracer.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                            tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                            tracer.Visible = true
                        end
                    else
                        for _, category in pairs(Drawings) do
                            if category[plr] then category[plr].Visible = false end
                        end
                    end
                else
                    for _, category in pairs(Drawings) do
                        if category[plr] then category[plr].Visible = false end
                    end
                end
            else
                removePlayerDrawings(plr)
            end
        end
    end
end

-- TARGETING LOGIC
local function getClosestTarget(fovRadius)
    local closest = nil
    local shortestDist = fovRadius
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character and not isAlly(plr) then
            local char = plr.Character
            local part = char:FindFirstChild(State.AimbotTargetPart) or char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            
            if part and hum and hum.Health > 0 then
                local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen and screenPos.Z > 0 then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

local function refreshSilentTarget()
    if not State.SilentAimEnabled then
        State.CachedSilentTarget = nil
        State.CachedSilentAimPart = nil
        return
    end
    local target = getClosestTarget(State.SilentAimFOV)
    State.CachedSilentTarget = target
    if target and target.Character then
        local part = target.Character:FindFirstChild(State.AimbotTargetPart) or target.Character:FindFirstChild("HumanoidRootPart")
        State.CachedSilentAimPart = part
    else
        State.CachedSilentAimPart = nil
    end
end

-- RENDER LOOP
RunService.RenderStepped:Connect(function()
    pcall(function()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        
        local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

        if State.AimbotShowFOV and State.AimbotEnabled then
            FOVCircle.Position = center
            FOVCircle.Radius = State.AimbotFOV
            FOVCircle.Visible = true
        else
            FOVCircle.Visible = false
        end

        if State.SilentAimShowFOV and State.SilentAimEnabled then
            SilentFOVCircle.Position = center
            SilentFOVCircle.Radius = State.SilentAimFOV
            SilentFOVCircle.Visible = true
        else
            SilentFOVCircle.Visible = false
        end

        updateESP()
        refreshSilentTarget()

        if State.AimbotEnabled then
            local target = getClosestTarget(State.AimbotFOV)
            State.CurrentTarget = target

            if target and target.Character then
                local part = target.Character:FindFirstChild(State.AimbotTargetPart) or target.Character:FindFirstChild("HumanoidRootPart")
                if part then
                    if State.AimbotType == "Camera" then
                        cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, part.Position), State.AimbotSmooth)
                    end
                end
            end
        end
    end)
end)

-- CLEANUP
Players.PlayerRemoving:Connect(function(plr) removePlayerDrawings(plr) end)
LP.CharacterRemoving:Connect(function() clearAllDrawings() end)
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LP then
        plr.CharacterRemoving:Connect(function() removePlayerDrawings(plr) end)
    end
end

-- SILENT AIM (ARGS REWRITE ONLY - NO MOUSE HOOK)
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if State.SilentAimEnabled and (method == "FireServer" or method == "InvokeServer") then
        local remoteName = typeof(self) == "Instance" and self.Name:lower() or ""
        local isCombatRemote = false
        
        -- Cek apakah nama remote cocok dengan filter
        for kw in string.gmatch(State.SilentAimFilter, "[^,]+") do
            local trimmed = kw:match("^%s*(.-)%s*$")
            if trimmed ~= "" and remoteName:find(trimmed, 1, true) then
                isCombatRemote = true
                break
            end
        end

        if isCombatRemote then
            local target = State.CachedSilentTarget or getClosestTarget(State.SilentAimFOV)
            if target and target.Character then
                local targetPart = target.Character:FindFirstChild(State.AimbotTargetPart) or target.Character:FindFirstChild("HumanoidRootPart")
                
                if targetPart then
                    local changed = false
                    for i, v in pairs(args) do
                        if typeof(v) == "CFrame" then
                            -- Paksa koordinat serangan ke posisi musuh
                            args[i] = targetPart.CFrame
                            changed = true
                        elseif typeof(v) == "Vector3" then
                            -- Paksa vector posisi ke musuh
                            args[i] = targetPart.Position
                            changed = true
                        elseif typeof(v) == "Instance" then
                            -- Kalau game kirim model/karakter sendiri, ganti ke musuh
                            if v:IsA("Model") and v:FindFirstChild("Humanoid") then
                                args[i] = target.Character
                                changed = true
                            elseif v:IsA("Player") and v ~= LP then
                                args[i] = target
                                changed = true
                            elseif v:IsA("BasePart") then
                                -- Kalau kirim part (misal Hitbox), cari part yang sama di badan musuh
                                local samePart = target.Character:FindFirstChild(v.Name)
                                if samePart then
                                    args[i] = samePart
                                    changed = true
                                end
                            end
                        end
                    end
                    
                    if changed then
                        return oldNamecall(self, table.unpack(args))
                    end
                end
            end
        end
    end
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

-- WINDOW UI
local Window = WindUI:CreateWindow({
    Title = "Pall x Universal Combat",
    Folder = "palluniv",
    Icon = "solar:target-bold",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open Pall Combat",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#FF4F4F"), Color3.fromHex("#FF9F1C")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})
Window:Tag({ Title = "v1.2.1-Stable", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

local TabESP = Window:Tab({ Title = "ESP", Desc = "Visual Player", Icon = "solar:eye-bold", IconColor = Green, IconShape = "Square", Border = true })
do
    local s = TabESP:Section({ Title = "ESP Settings", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Aktifkan ESP", Value = false, Callback = function(v) State.ESPEnabled = v end })
    s:Space()
    s:Slider({ Title = "Jarak Maksimal ESP (m)", Step = 100, Value = { Min = 100, Max = 2000, Default = 1000 }, Callback = function(v) State.ESPMaxDistance = v end })
    s:Space()
    s:Toggle({ Title = "Box", Value = true, Callback = function(v) State.ESPBox = v end })
    s:Space()
    s:Toggle({ Title = "Name", Value = true, Callback = function(v) State.ESPName = v end })
    s:Space()
    s:Toggle({ Title = "Health", Value = true, Callback = function(v) State.ESPHealth = v end })
    s:Space()
    s:Toggle({ Title = "Distance", Value = true, Callback = function(v) State.ESPDistance = v end })
    s:Space()
    s:Toggle({ Title = "Tracer", Value = false, Callback = function(v) State.ESPTracer = v end })
    s:Space()
    s:Toggle({ Title = "Team Check (Aman)", Value = true, Callback = function(v) State.ESPTeamCheck = v end })
end

local TabAim = Window:Tab({ Title = "Aimbot", Desc = "Auto Target", Icon = "solar:crosshair-bold", IconColor = Red, IconShape = "Square", Border = true })
do
    local s1 = TabAim:Section({ Title = "Aimbot Settings", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Aktifkan Aimbot", Value = false, Callback = function(v) State.AimbotEnabled = v end })
    s1:Space()
    s1:Slider({ Title = "FOV (Radius)", Step = 10, Value = { Min = 50, Max = 500, Default = 150 }, Callback = function(v) State.AimbotFOV = v end })
    s1:Space()
    s1:Toggle({ Title = "Tampilkan Lingkaran FOV", Value = true, Callback = function(v) State.AimbotShowFOV = v end })
    s1:Space()
    s1:Slider({ Title = "Smoothness", Step = 0.05, Value = { Min = 0.05, Max = 1, Default = 0.15 }, Callback = function(v) State.AimbotSmooth = v end })
    s1:Space()
    s1:Dropdown({ Title = "Target Part", Values = { "Head", "HumanoidRootPart", "Torso" }, Value = "Head", Callback = function(v) State.AimbotTargetPart = v end })
    
    local s2 = TabAim:Section({ Title = "Silent Aim (Tap Anywhere)", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Aktifkan Silent Aim", Value = false, Callback = function(v) State.SilentAimEnabled = v end })
    s2:Space()
    s2:Slider({ Title = "Silent FOV", Step = 10, Value = { Min = 50, Max = 1000, Default = 300 }, Callback = function(v) State.SilentAimFOV = v end })
    s2:Space()
    s2:Toggle({ Title = "Tampilkan Lingkaran FOV Silent", Value = true, Callback = function(v) State.SilentAimShowFOV = v end })
    s2:Space()
    s2:Input({ Title = "Remote Filter (koma)", Value = State.SilentAimFilter, Callback = function(v) State.SilentAimFilter = v end })
end

WindUI:Notify({ Title = "Pall Combat v1.2.1-Stable", Content = "Safe Silent Aim Active!", Icon = "solar:bell-bold", Duration = 6 })
print("[PALL-UNIV] v1.2.1-Stable loaded.")
