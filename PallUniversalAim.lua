--[[
    ═══════════════════════════════════════════════════════════
    PALL — UNIVERSAL COMBAT (ESP + Aimbot + Silent Aim)
    Author  : ENI (for Pall)
    Version : v1.0.1 (Auto-Clean ESP)
    ═══════════════════════════════════════════════════════════
--]]

print("[PALL-UNIV] Memuat Universal Combat...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

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
    if not ok then error("[PALL-UNIV] Gagal load WindUI.") end
    WindUI = _G.PallWindUI or result
end

local Green = Color3.fromHex("#10C550")
local Red   = Color3.fromHex("#EF4F1D")
local Blue  = Color3.fromHex("#257AF7")

--============================================================
-- STATE
--============================================================
if _G.PALL_UNIV_RUNNING then
    _G.PALL_UNIV_RUNNING = false
    task.wait(0.5)
end
_G.PALL_UNIV_RUNNING = true

local State = {
    -- ESP
    ESPEnabled = false,
    ESPBox = true,
    ESPName = true,
    ESPHealth = true,
    ESPDistance = true,
    ESPTracer = false,
    ESPTeamCheck = true,
    
    -- Aimbot
    AimbotEnabled = false,
    AimbotFOV = 150,
    AimbotSmooth = 0.15,
    AimbotTargetPart = "Head",
    AimbotType = "Camera",
    
    -- Silent Aim
    SilentAimEnabled = false,
    SilentAimFOV = 200,
    SilentAimFilter = "shoot,fire,attack,hit,damage,click",
    
    -- Internal
    CurrentTarget = nil
}

--============================================================
-- ESP DRAWING & AUTO-CLEANUP
--============================================================
local Drawings = { Boxes = {}, Names = {}, Healths = {}, Distances = {}, Tracers = {} }

local function clearDrawings()
    for _, t in pairs(Drawings) do
        for _, d in pairs(t) do
            pcall(function() d:Remove() end)
        end
    end
    Drawings = { Boxes = {}, Names = {}, Healths = {}, Distances = {}, Tracers = {} }
end

local function isAlly(plr)
    if not State.ESPTeamCheck then return false end
    if plr.Team and LP.Team and plr.Team == LP.Team then return true end
    return false
end

-- Fungsi buat hapus ESP satu player (kalau mati/keluar)
local function removePlayerESP(plr)
    for _, t in pairs(Drawings) do
        if t[plr] then
            pcall(function() t[plr]:Remove() end)
            t[plr] = nil
        end
    end
end

local function drawESP()
    if not State.ESPEnabled then
        clearDrawings()
        return
    end

    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- ========================================================
    -- CLEANUP: Hapus ESP musuh yang udah mati atau keluar game
    -- ========================================================
    for plr, _ in pairs(Drawings.Boxes) do
        local hasLeft = not plr.Parent
        local isDead = false
        
        if not hasLeft then
            local char = plr.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if not char or not hum or hum.Health <= 0 then
                isDead = true
            end
        end
        
        if hasLeft or isDead then
            removePlayerESP(plr)
        end
    end

    -- ========================================================
    -- LOOP: Gambar ESP untuk musuh yang masih hidup
    -- ========================================================
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character and not isAlly(plr) then
            local char = plr.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            
            -- Cek kalau musuh masih hidup & valid
            if root and hum and hum.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                
                if onScreen then
                    local distance = (hrp.Position - root.Position).Magnitude
                    local sizeY = math.clamp(1000 / screenPos.Z, 20, 100)
                    local sizeX = sizeY / 2

                    -- Box
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

                    -- Name
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

                    -- Health
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

                    -- Distance
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

                    -- Tracer
                    if State.ESPTracer then
                        if not Drawings.Tracers[plr] then
                            Drawings.Tracers[plr] = Drawing.new("Line")
                            Drawings.Tracers[plr].Thickness = 1
                            Drawings.Tracers[plr].Color = Red
                        end
                        local tracer = Drawings.Tracers[plr]
                        tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        tracer.Visible = true
                    end
                else
                    -- Sembunyiin kalau di luar layar (tapi jangan dihapus dulu)
                    for _, t in pairs(Drawings) do
                        if t[plr] then t[plr].Visible = false end
                    end
                end
            end
        end
    end
end

--============================================================
-- AIMBOT & TARGET LOGIC
--============================================================
local function getClosestTarget(fovRadius)
    local closest = nil
    local shortestDist = fovRadius
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character and not isAlly(plr) then
            local char = plr.Character
            local part = char:FindFirstChild(State.AimbotTargetPart) or char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            
            if part and hum and hum.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
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

RunService.RenderStepped:Connect(function()
    drawESP()

    if State.AimbotEnabled then
        local target = getClosestTarget(State.AimbotFOV)
        State.CurrentTarget = target

        if target and target.Character then
            local part = target.Character:FindFirstChild(State.AimbotTargetPart) or target.Character:FindFirstChild("HumanoidRootPart")
            if part then
                if State.AimbotType == "Camera" then
                    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, part.Position), State.AimbotSmooth)
                end
            end
        end
    end
end)

--============================================================
-- SILENT AIM (HOOKING __namecall)
--============================================================
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if State.SilentAimEnabled and (method == "FireServer" or method == "InvokeServer") then
        local remoteName = self.Name:lower()
        local isCombatRemote = false
        
        for kw in string.gmatch(State.SilentAimFilter, "[^,]+") do
            if remoteName:find(kw:match("^%s*(.-)%s*$")) then
                isCombatRemote = true
                break
            end
        end

        if isCombatRemote then
            local target = State.CurrentTarget or getClosestTarget(State.SilentAimFOV)
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
-- WINDOW UI
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
Window:Tag({ Title = "v1.0.1", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: ESP
--============================================================
local TabESP = Window:Tab({ Title = "ESP", Desc = "Visual Player", Icon = "solar:eye-bold", IconColor = Green, IconShape = "Square", Border = true })
do
    local s = TabESP:Section({ Title = "ESP Settings", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Aktifkan ESP", Value = false, Callback = function(v) State.ESPEnabled = v end })
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

--============================================================
-- TAB: AIMBOT & SILENT
--============================================================
local TabAim = Window:Tab({ Title = "Aimbot", Desc = "Auto Target", Icon = "solar:crosshair-bold", IconColor = Red, IconShape = "Square", Border = true })
do
    local s1 = TabAim:Section({ Title = "Aimbot Settings", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Aktifkan Aimbot", Value = false, Callback = function(v) State.AimbotEnabled = v end })
    s1:Space()
    s1:Slider({ Title = "FOV (Radius)", Step = 10, Value = { Min = 50, Max = 500, Default = 150 }, Callback = function(v) State.AimbotFOV = v end })
    s1:Space()
    s1:Slider({ Title = "Smoothness", Step = 0.05, Value = { Min = 0.05, Max = 1, Default = 0.15 }, Callback = function(v) State.AimbotSmooth = v end })
    s1:Space()
    s1:Dropdown({ Title = "Target Part", Values = { "Head", "HumanoidRootPart", "Torso" }, Value = "Head", Callback = function(v) State.AimbotTargetPart = v end })
    
    local s2 = TabAim:Section({ Title = "Silent Aim (Peluru Nyari Target)", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Aktifkan Silent Aim", Value = false, Callback = function(v) State.SilentAimEnabled = v end })
    s2:Space()
    s2:Slider({ Title = "Silent FOV", Step = 10, Value = { Min = 50, Max = 800, Default = 200 }, Callback = function(v) State.SilentAimFOV = v end })
    s2:Space()
    s2:Input({ Title = "Remote Filter (koma)", Value = "shoot,fire,attack,hit,damage,click", Callback = function(v) State.SilentAimFilter = v end })
end

WindUI:Notify({ Title = "Pall Combat v1.0.1", Content = "Auto-Clean ESP Active!", Icon = "solar:bell-bold", Duration = 6 })
print("[PALL-UNIV] v1.0.1 loaded.")
