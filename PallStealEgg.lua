--[[
    ═══════════════════════════════════════════════════════════
    PALL — STEAL AN EGG
    Author  : ENI (for Pall)
    Version : v0.1.0 — Batch 1: Aman Total
    Features:
      • FPS Booster (client-side, zero risk)
      • ESP Egg + Player (visual only)
      • Camera Tweak
      • Anti-AFK
      • Speed Indicator
    ═══════════════════════════════════════════════════════════
--]]

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualUser         = game:GetService("VirtualUser")
local Lighting            = game:GetService("Lighting")
local HttpService         = game:GetService("HttpService")

local LP = Players.LocalPlayer

--============================================================
-- LOAD WINDUI
--============================================================
local WindUI
local ok, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)
if not ok then error("[PALL-SE] Gagal load WindUI.") end
WindUI = result

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
    -- ESP
    ESPEggs = false,
    ESPPlayers = false,
    ESPColor = Color3.fromRGB(255, 200, 60),
    ESPPlayerColor = Color3.fromRGB(80, 180, 255),
    ESPRange = 5000,

    -- FPS
    FPSCounter = false,
    LowTextures = false,
    RemoveParticles = false,
    DisableShadows = false,
    DisableSkybox = false,
    DisableAtmosphere = false,
    BurikTotal = false,

    -- Camera
    CameraZoomEnabled = false,
    CameraZoomMax = 500,

    -- Misc
    AntiAFK = true,
    ShowSpeed = true,
}

--============================================================
-- UTILITY
--============================================================
local function getHRP() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end

--============================================================
-- ESP FRAMEWORK
--============================================================
local espFolder = Instance.new("Folder")
espFolder.Name = "PallSE_ESP"
espFolder.Parent = workspace

local espCache = {}

local function createBoxESP(model, color, label)
    if not model or not model.PrimaryPart then
        -- Fallback: cari part apapun
        local found = nil
        for _, p in ipairs(model:GetChildren()) do
            if p:IsA("BasePart") then found = p; break end
        end
        if not found then return nil end
    end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "PallESPBox"
    box.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not box.Adornee then return nil end
    box.Size = box.Adornee.Size + Vector3.new(0.5, 0.5, 0.5)
    box.Color3 = color
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Transparency = 0.5
    box.Parent = espFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PallESPLabel"
    billboard.Size = UDim2.new(0, 160, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = box.Adornee
    billboard.Parent = espFolder

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = label or model.Name
    text.TextColor3 = color
    text.TextStrokeTransparency = 0
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.TextScaled = true
    text.Font = Enum.Font.GothamBold
    text.Parent = billboard

    return { box = box, billboard = billboard }
end

local function removeESPFor(instance)
    if espCache[instance] then
        if espCache[instance].box then espCache[instance].box:Destroy() end
        if espCache[instance].billboard then espCache[instance].billboard:Destroy() end
        espCache[instance] = nil
    end
end

local function clearAllESP()
    for inst, _ in pairs(espCache) do
        removeESPFor(inst)
    end
    espCache = {}
end

-- Deteksi egg: model dengan nama mengandung "egg" atau tool di workspace
local function isEggLike(model)
    if not model:IsA("Model") then return false end
    local n = model.Name:lower()
    if n:find("egg", 1, true) then return true end
    -- Cek apakah punya attribute atau tag khusus
    if model:GetAttribute("Egg") or model:GetAttribute("eggId") then return true end
    -- Cek apakah punya ProximityPrompt (interactable)
    if model:FindFirstChildOfClass("ProximityPrompt") then return true end
    return false
end

local function isPlayerChar(model)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character == model then return plr end
    end
    return nil
end

-- Loop ESP
task.spawn(function()
    while task.wait(0.5) do
        -- Egg ESP
        if State.ESPEggs then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if isEggLike(obj) and not espCache[obj] then
                    local res = createBoxESP(obj, State.ESPColor, obj.Name)
                    if res then espCache[obj] = res end
                end
            end
            -- Cleanup yang udah hilang
            for inst, _ in pairs(espCache) do
                if not inst.Parent then removeESPFor(inst) end
            end
        else
            -- Kalau toggle off, bersihin egg ESP aja (kecuali player ESP aktif)
            if not State.ESPPlayers then
                clearAllESP()
            end
        end

        -- Player ESP
        if State.ESPPlayers then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and plr.Character and not espCache[plr.Character] then
                    local res = createBoxESP(plr.Character, State.ESPPlayerColor, plr.Name)
                    if res then espCache[plr.Character] = res end
                end
            end
        end
    end
end)

--============================================================
-- FPS BOOSTER HELPERS
--============================================================
local fpsCache = { materials = {}, skybox = nil, atm = nil, shadows = nil }

local function applyLowTextures()
    fpsCache.materials = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not fpsCache.materials[obj] then
            fpsCache.materials[obj] = { mat = obj.Material, ref = obj.Reflectance }
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
        end
        if obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
            obj.Transparency = 1
        end
    end
end
local function restoreLowTextures()
    for obj, data in pairs(fpsCache.materials) do
        if obj and obj.Parent then
            obj.Material = data.mat
            obj.Reflectance = data.ref
        end
    end
    fpsCache.materials = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
            obj.Transparency = 0
        end
    end
end

local function applyParticles()
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") then
            o.Enabled = false
        end
    end
end
local function restoreParticles()
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") then
            o.Enabled = true
        end
    end
end

local function applyShadows()
    fpsCache.shadows = { g = Lighting.GlobalShadows, s = Lighting.ShadowSoftness }
    Lighting.GlobalShadows = false
    Lighting.ShadowSoftness = 0
end
local function restoreShadows()
    if fpsCache.shadows then
        Lighting.GlobalShadows = fpsCache.shadows.g
        Lighting.ShadowSoftness = fpsCache.shadows.s
    end
end

local function applySkybox()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if sky then
        fpsCache.skybox = { b=sky.SkyboxBk, d=sky.SkyboxDn, f=sky.SkyboxFt, l=sky.SkyboxLf, r=sky.SkyboxRt, u=sky.SkyboxUp }
        sky.SkyboxBk=""; sky.SkyboxDn=""; sky.SkyboxFt=""
        sky.SkyboxLf=""; sky.SkyboxRt=""; sky.SkyboxUp=""
    end
end
local function restoreSkybox()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if sky and fpsCache.skybox then
        sky.SkyboxBk=fpsCache.skybox.b; sky.SkyboxDn=fpsCache.skybox.d
        sky.SkyboxFt=fpsCache.skybox.f; sky.SkyboxLf=fpsCache.skybox.l
        sky.SkyboxRt=fpsCache.skybox.r; sky.SkyboxUp=fpsCache.skybox.u
    end
end

local function applyAtmosphere()
    local atm = Lighting:FindFirstChildOfClass("Atmosphere")
    if atm then
        fpsCache.atm = { d=atm.Density, h=atm.Haze, g=atm.Glare }
        atm.Density = 0; atm.Haze = 0; atm.Glare = 0
    end
end
local function restoreAtmosphere()
    local atm = Lighting:FindFirstChildOfClass("Atmosphere")
    if atm and fpsCache.atm then
        atm.Density = fpsCache.atm.d; atm.Haze = fpsCache.atm.h; atm.Glare = fpsCache.atm.g
    end
end

--============================================================
-- WINDOW
--============================================================
local Window = WindUI:CreateWindow({
    Title = "Pall x Steal an Egg",
    Folder = "pallse",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open Pall SE",
        CornerRadius = UDim.new(1, 0), StrokeThickness = 3,
        Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.5,
        Color = ColorSequence.new(Color3.fromHex("#FFD93D"), Color3.fromHex("#FF8A3D")),
    },
    Topbar = { Height = 44, ButtonsType = "Mac" },
})

Window:Tag({ Title = "v0.1.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: ESP (Batch 1)
--============================================================
local TabESP = Window:Tab({
    Title = "ESP", Desc = "Lihat egg & player",
    Icon = "solar:eye-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s1 = TabESP:Section({ Title = "Egg ESP", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({
        Title = "ESP Eggs (Highlight)",
        Desc = "Kotak + nama di sekitar egg",
        Value = false,
        Callback = function(v) State.ESPEggs = v end,
    })

    local s2 = TabESP:Section({ Title = "Player ESP", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({
        Title = "ESP Players",
        Desc = "Highlight player lain",
        Value = false,
        Callback = function(v) State.ESPPlayers = v end,
    })
    s2:Space()
    s2:Colorpicker({
        Title = "Warna ESP Egg",
        Default = State.ESPColor,
        Callback = function(c) State.ESPColor = c end,
    })
    s2:Space()
    s2:Colorpicker({
        Title = "Warna ESP Player",
        Default = State.ESPPlayerColor,
        Callback = function(c) State.ESPPlayerColor = c end,
    })
end

--============================================================
-- TAB: FPS BOOST (Batch 1)
--============================================================
local TabFPS = Window:Tab({
    Title = "FPS Boost", Desc = "Performa",
    Icon = "solar:cpu-bolt-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    -- FPS Counter
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Name = "PallSE_FPS"
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

    local s1 = TabFPS:Section({ Title = "Info", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Show FPS Counter", Value = false,
        Callback = function(v) State.FPSCounter = v end })

    local s2 = TabFPS:Section({ Title = "Performance", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Low Textures (burik)", Value = false,
        Callback = function(v) State.LowTextures = v
            if v then applyLowTextures() else restoreLowTextures() end end })
    s2:Space()
    s2:Toggle({ Title = "Disable Particles", Value = false,
        Callback = function(v) State.RemoveParticles = v
            if v then applyParticles() else restoreParticles() end end })
    s2:Space()
    s2:Toggle({ Title = "Disable Shadows", Value = false,
        Callback = function(v) State.DisableShadows = v
            if v then applyShadows() else restoreShadows() end end })
    s2:Space()
    s2:Toggle({ Title = "Disable Skybox", Value = false,
        Callback = function(v) State.DisableSkybox = v
            if v then applySkybox() else restoreSkybox() end end })
    s2:Space()
    s2:Toggle({ Title = "Disable Atmosphere", Value = false,
        Callback = function(v) State.DisableAtmosphere = v
            if v then applyAtmosphere() else restoreAtmosphere() end end })

    local s3 = TabFPS:Section({ Title = "Master", Box = true, BoxBorder = true, Opened = true })
    s3:Toggle({
        Title = "BURIK TOTAL MODE",
        Value = false,
        Callback = function(v)
            State.BurikTotal = v
            if v then
                applyLowTextures(); applyParticles(); applyShadows()
                applySkybox(); applyAtmosphere()
                WindUI:Notify({ Title = "Burik Total", Content = "Semua efek dimatikan." })
            else
                restoreLowTextures(); restoreParticles(); restoreShadows()
                restoreSkybox(); restoreAtmosphere()
                WindUI:Notify({ Title = "Burik Total", Content = "Restore efek visual." })
            end
        end,
    })
    s3:Space()
    s3:Button({
        Title = "Reset Semua ke Normal", Justify = "Center",
        Callback = function()
            restoreLowTextures(); restoreParticles(); restoreShadows()
            restoreSkybox(); restoreAtmosphere()
            WindUI:Notify({ Title = "Reset", Content = "Efek visual normal." })
        end,
    })
end

--============================================================
-- TAB: CAMERA (Batch 1)
--============================================================
local TabCamera = Window:Tab({
    Title = "Camera", Desc = "Zoom out",
    Icon = "solar:videocamera-record-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s = TabCamera:Section({ Title = "Camera Zoom", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({
        Title = "Unlock Max Zoom",
        Desc = "Zoom out lebih jauh dari default",
        Value = false,
        Callback = function(v)
            State.CameraZoomEnabled = v
            local cam = workspace.CurrentCamera
            if v then
                cam.CameraSubject = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") or cam.CameraSubject
            end
        end,
    })
    s:Space()
    s:Slider({
        Title = "Max Zoom Distance", Step = 10,
        Value = { Min = 50, Max = 2000, Default = 500 },
        Callback = function(v) State.CameraZoomMax = v end,
    })

    -- Apply zoom each frame kalau enabled
    RunService.RenderStepped:Connect(function()
        if State.CameraZoomEnabled then
            local plr = LP
            pcall(function()
                plr.CameraMaxZoomDistance = State.CameraZoomMax
                plr.CameraMinZoomDistance = 0.5
            end)
        end
    end)
end

--============================================================
-- TAB: PLAYER (Batch 1)
--============================================================
local TabPlayer = Window:Tab({
    Title = "Player", Desc = "Misc",
    Icon = "solar:user-bold", IconColor = Grey, IconShape = "Square", Border = true,
})
do
    local s = TabPlayer:Section({ Title = "Misc", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({
        Title = "Anti-AFK", Value = true,
        Callback = function(v) State.AntiAFK = v end,
    })
    s:Space()
    s:Toggle({
        Title = "Show Speed Indicator", Value = true,
        Callback = function(v) State.ShowSpeed = v end,
    })
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

-- Speed Indicator
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0, 120, 0, 24)
speedLabel.Position = UDim2.new(0, 10, 0, 45)
speedLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
speedLabel.BackgroundTransparency = 0.4
speedLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
speedLabel.Font = Enum.Font.Code
speedLabel.TextSize = 14
speedLabel.Text = "Speed: --"
speedLabel.Parent = LP:WaitForChild("PlayerGui")

RunService.RenderStepped:Connect(function()
    speedLabel.Visible = State.ShowSpeed
    if State.ShowSpeed then
        local hum = getHum()
        if hum then
            speedLabel.Text = "Speed: " .. string.format("%.1f", hum.WalkSpeed)
        end
    end
end)

--============================================================
-- NOTIF
--============================================================
WindUI:Notify({
    Title = "Pall SE v0.1.0",
    Content = "Batch 1 loaded: ESP, FPS Boost, Camera Zoom, Anti-AFK.",
    Icon = "solar:bell-bold",
    Duration = 6,
})

print("[PALL-SE] v0.1.0 loaded. Batch 1 — safe features only.")
