--[[
	PALL — UNIVERSAL COMBAT
	Version : v1.2.2 (1.2.0 base + optional extras, all OFF by default)
--]]

print("[PALL-UNIV] Memuat Universal Combat v1.2.2...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer

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

local Green  = Color3.fromHex("#10C550")
local Red    = Color3.fromHex("#EF4F1D")
local White  = Color3.fromRGB(255, 255, 255)
local Yellow = Color3.fromRGB(255, 200, 60)

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
    SilentAimFOV = 200,
    SilentAimFilter = "shoot,fire,attack,hit,damage,click,sword,slash,swing,throw,knife,gun,weapon,tool",

    -- NEW (default OFF, opt-in extras)
    SilentSpoofMouse = false,   -- spoof mouse.Hit / Target
    SilentCharAim = false,      -- rotate character toward target
    SilentShowFOV = true,

    CurrentTarget = nil,
    CachedSilentTarget = nil,
    CachedSilentAimPart = nil,
    CachedSilentAimPos = nil,
}

--============================================================
-- DRAWING
--============================================================
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
                                local b = Drawing.new("Square")
                                b.Thickness = 1
                                b.Color = Red
                                b.Filled = false
                                Drawings.Boxes[plr] = b
                            end
                            local box = Drawings.Boxes[plr]
                            box.Size = Vector2.new(sizeX, sizeY)
                            box.Position = Vector2.new(screenPos.X - sizeX / 2, screenPos.Y - sizeY / 2)
                            box.Visible = true
                        end

                        if State.ESPName then
                            if not Drawings.Names[plr] then
                                local n = Drawing.new("Text")
                                n.Size = 16
                                n.Center = true
                                n.Outline = true
                                n.Color = White
                                Drawings.Names[plr] = n
                            end
                            local name = Drawings.Names[plr]
                            name.Text = plr.Name
                            name.Position = Vector2.new(screenPos.X, screenPos.Y - sizeY / 2 - 15)
                            name.Visible = true
                        end

                        if State.ESPHealth then
                            if not Drawings.Healths[plr] then
                                local h = Drawing.new("Text")
                                h.Size = 14
                                h.Center = true
                                h.Outline = true
                                h.Color = Green
                                Drawings.Healths[plr] = h
                            end
                            local hp = Drawings.Healths[plr]
                            hp.Text = math.floor(hum.Health) .. " HP"
                            hp.Position = Vector2.new(screenPos.X, screenPos.Y + sizeY / 2 + 5)
                            hp.Visible = true
                        end

                        if State.ESPDistance then
                            if not Drawings.Distances[plr] then
                                local d = Drawing.new("Text")
                                d.Size = 12
                                d.Center = true
                                d.Outline = true
                                d.Color = Color3.new(0.8, 0.8, 0.8)
                                Drawings.Distances[plr] = d
                            end
                            local dist = Drawings.Distances[plr]
                            dist.Text = "[" .. math.floor(distance) .. "m]"
                            dist.Position = Vector2.new(screenPos.X, screenPos.Y + sizeY / 2 + 20)
                            dist.Visible = true
                        end

                        if State.ESPTracer then
                            if not Drawings.Tracers[plr] then
                                local t = Drawing.new("Line")
                                t.Thickness = 1
                                t.Color = Red
                                Drawings.Tracers[plr] = t
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

--============================================================
-- TARGETING
--============================================================
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
        State.CachedSilentAimPos = nil
        return
    end
    local target = getClosestTarget(State.SilentAimFOV)
    State.CachedSilentTarget = target
    if target and target.Character then
        local part = target.Character:FindFirstChild(State.AimbotTargetPart) or target.Character:FindFirstChild("HumanoidRootPart")
        State.CachedSilentAimPart = part
        State.CachedSilentAimPos = part and part.Position or nil
    else
        State.CachedSilentAimPart = nil
        State.CachedSilentAimPos = nil
    end
end

--============================================================
-- LAZY MOUSE HOOK (only installed when user enables the toggle)
--============================================================
local mouseHookInstalled = false
local function ensureMouseHook()
    if mouseHookInstalled then return end
    local ok, err = pcall(function()
        local mouse = LP:GetMouse()
        if not mouse then return end
        local rawMeta = getrawmetatable(mouse)
        local originalIndex = rawMeta and rawMeta.__index
        if not originalIndex then return end
        hookmetamethod(mouse, "__index", newcclosure(function(self, key)
            if State.SilentAimEnabled and State.SilentSpoofMouse then
                local aimPos = State.CachedSilentAimPos
                local aimPart = State.CachedSilentAimPart
                if aimPos and aimPart then
                    if key == "Hit" then
                        return CFrame.new(aimPos)
                    elseif key == "Target" then
                        return aimPart
                    end
                end
            end
            return originalIndex(self, key)
        end))
        mouseHookInstalled = true
    end)
    if not ok then
        warn("[PALL-UNIV] mouse hook gagal:", tostring(err))
    end
end

--============================================================
-- NAMECALL ARG REWRITE (same as 1.2.0)
--============================================================
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if State.SilentAimEnabled and (method == "FireServer" or method == "InvokeServer") then
        local remoteName = (typeof(self) == "Instance") and self.Name:lower() or ""
        local isCombatRemote = false

        for kw in string.gmatch(State.SilentAimFilter, "[^,]+") do
            local trimmed = kw:match("^%s*(.-)%s*$")
            if trimmed ~= "" and remoteName:find(trimmed, 1, true) then
                isCombatRemote = true
                break
            end
        end

        if isCombatRemote then
            local target = State.CachedSilentTarget or State.CurrentTarget or getClosestTarget(State.SilentAimFOV)
            if target and target.Character then
                local targetPart = target.Character:FindFirstChild(State.AimbotTargetPart) or target.Character:FindFirstChild("HumanoidRootPart")

                for i, v in pairs(args) do
                    if typeof(v) == "CFrame" and targetPart then
                        args[i] = targetPart.CFrame
                    elseif typeof(v) == "Instance" and v:IsA("Model") and v:FindFirstChild("Humanoid") then
                        args[i] = target.Character
                    elseif typeof(v) == "Vector3" and targetPart then
                        args[i] = targetPart.Position
                    end
                end
                return oldNamecall(self, table.unpack(args))
            end
        end
    end
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

--============================================================
-- CHARACTER AIM (opt-in)
--============================================================
local function applyCharacterAim()
    if not (State.SilentAimEnabled and State.SilentCharAim) then return end
    local aimPos = State.CachedSilentAimPos
    if not aimPos then return end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local flat = Vector3.new(aimPos.X, hrp.Position.Y, aimPos.Z)
    if (flat - hrp.Position).Magnitude < 0.1 then return end
    pcall(function()
        hrp.CFrame = CFrame.lookAt(hrp.Position, flat)
    end)
end

--============================================================
-- RENDER LOOP
--============================================================
RunService.RenderStepped:Connect(function()
    local ok, err = pcall(function()
        local cam = Workspace.CurrentCamera
        if not cam then return end

        refreshSilentTarget()
        updateESP()

        local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

        if State.AimbotShowFOV and State.AimbotEnabled then
            FOVCircle.Position = center
            FOVCircle.Radius = State.AimbotFOV
            FOVCircle.Visible = true
        else
            FOVCircle.Visible = false
        end

        if State.SilentShowFOV and State.SilentAimEnabled then
            SilentFOVCircle.Position = center
            SilentFOVCircle.Radius = State.SilentAimFOV
            SilentFOVCircle.Visible = true
        else
            SilentFOVCircle.Visible = false
        end

        if State.AimbotEnabled then
            local target = getClosestTarget(State.AimbotFOV)
            State.CurrentTarget = target
            if target and target.Character then
                local part = target.Character:FindFirstChild(State.AimbotTargetPart) or target.Character:FindFirstChild("HumanoidRootPart")
                if part then
                    cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, part.Position), State.AimbotSmooth)
                end
            end
        end

        applyCharacterAim()
    end)
    if not ok then warn("[PALL-UNIV] render:", tostring(err)) end
end)

--============================================================
-- UI
--============================================================
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
Window:Tag({ Title = "v1.2.2", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

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
    s1:Toggle({ Title = "Tampilkan Lingkaran FOV Aimbot", Value = true, Callback = function(v) State.AimbotShowFOV = v end })
    s1:Space()
    s1:Slider({ Title = "Smoothness", Step = 0.05, Value = { Min = 0.05, Max = 1, Default = 0.15 }, Callback = function(v) State.AimbotSmooth = v end })
    s1:Space()
    s1:Dropdown({ Title = "Target Part", Values = { "Head", "HumanoidRootPart", "Torso" }, Value = "Head", Callback = function(v) State.AimbotTargetPart = v end })

    local s2 = TabAim:Section({ Title = "Silent Aim (Args Rewrite)", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Aktifkan Silent Aim", Value = false, Callback = function(v) State.SilentAimEnabled = v end })
    s2:Space()
    s2:Slider({ Title = "Silent FOV (Radius)", Step = 10, Value = { Min = 50, Max = 1200, Default = 200 }, Callback = function(v) State.SilentAimFOV = v end })
    s2:Space()
    s2:Toggle({ Title = "Tampilkan Lingkaran FOV Silent", Value = true, Callback = function(v) State.SilentShowFOV = v end })
    s2:Space()
    s2:Input({ Title = "Remote Filter (koma)", Value = State.SilentAimFilter, Callback = function(v) State.SilentAimFilter = v end })

    local s3 = TabAim:Section({ Title = "Silent Aim - Extra (opt-in)", Box = true, BoxBorder = true, Opened = false })
    s3:Toggle({ Title = "Spoof mouse.Hit / Target (RISKY)", Value = false, Callback = function(v)
        State.SilentSpoofMouse = v
        if v then ensureMouseHook() end
    end })
    s3:Space()
    s3:Toggle({ Title = "Character Aim (rotate char)", Value = false, Callback = function(v) State.SilentCharAim = v end })
end

WindUI:Notify({ Title = "Pall Combat v1.2.2", Content = "Base 1.2.0 restored. Extras OFF by default."
