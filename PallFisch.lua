--[[
    ═══════════════════════════════════════════════════════════
    PALL — FISCH
    Author  : ENI (for Pall)
    Version : v0.2.0 — Auto Fish (Cast + Guncang + Perfect Bar)
    Notes   :
      • Event-driven (nggak lag)
      • Tap simulation (VirtualInputManager) — aman dari Byfron
      • Nggak fire remote apa pun
    ═══════════════════════════════════════════════════════════
--]]

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting            = game:GetService("Lighting")

local LP = Players.LocalPlayer

--============================================================
-- LOAD WINDUI
--============================================================
local WindUI
if _G.PallWindUI then
    WindUI = _G.PallWindUI
    print("[PALL-FISCH] Pakai WindUI dari MultiHub.")
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

--============================================================
-- STATE
--============================================================
local State = {
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
    CameraZoomMax = 800,

    -- Player
    AntiAFK = true,

    -- Auto Fish
    AutoFish = false,
    AutoShake = true,
    AutoReel = true,
    ShakeSpeed = 0.06,
    ReelDelay = 0.1,
    CastDelay = 1.5,
    BiteWait = 5,
    PerfectThreshold = 0.7,
    Status = "Idle",
}

--============================================================
-- UTILITY
--============================================================
local function tapAt(x, y)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.015)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function tapElement(el)
    if not el then return false end
    local pos = el.AbsolutePosition
    local size = el.AbsoluteSize
    tapAt(pos.X + size.X / 2, pos.Y + size.Y / 2)
    return true
end

local function findByPath(root, path)
    local node = root
    for _, seg in ipairs(path) do
        if not node then return nil end
        node = node:FindFirstChild(seg)
    end
    return node
end

local pg = LP:WaitForChild("PlayerGui")

--============================================================
-- FPS BOOST
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
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") then o.CastShadow = false end
    end
end
local function restoreShadows()
    if fpsCache.shadows then
        Lighting.GlobalShadows = fpsCache.shadows.g
        Lighting.ShadowSoftness = fpsCache.shadows.s
    end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") then o.CastShadow = true end
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
Window:Tag({ Title = "v0.2.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: AUTO FISH
--============================================================
local TabAuto = Window:Tab({
    Title = "Auto Fish", Desc = "Cast + Guncang + Perfect",
    Icon = "solar:fish-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s1 = TabAuto:Section({ Title = "Control", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Fish", Value = false,
        Callback = function(v) State.AutoFish = v end })
    s1:Space()
    s1:Toggle({ Title = "Auto Guncang (Shake)", Value = true,
        Callback = function(v) State.AutoShake = v end })
    s1:Space()
    s1:Toggle({ Title = "Auto Perfect Bar", Value = true,
        Callback = function(v) State.AutoReel = v end })

    local s2 = TabAuto:Section({ Title = "Timing", Box = true, BoxBorder = true, Opened = true })
    s2:Slider({ Title = "Shake Speed", Step = 0.01,
        Value = { Min = 0.03, Max = 0.2, Default = 0.06 },
        Callback = function(v) State.ShakeSpeed = v end })
    s2:Space()
    s2:Slider({ Title = "Cast Delay", Step = 0.1,
        Value = { Min = 0.5, Max = 5, Default = 1.5 },
        Callback = function(v) State.CastDelay = v end })
    s2:Space()
    s2:Slider({ Title = "Bite Wait (detik)", Step = 0.5,
        Value = { Min = 2, Max = 15, Default = 5 },
        Callback = function(v) State.BiteWait = v end })
    s2:Space()
    s2:Slider({ Title = "Perfect Threshold", Step = 0.05,
        Value = { Min = 0.5, Max = 1, Default = 0.7 },
        Callback = function(v) State.PerfectThreshold = v end })

    local s3 = TabAuto:Section({ Title = "Status", Box = true, BoxBorder = true, Opened = true })
    local statusText = s3:Section({ Title = "Idle", TextSize = 15, TextTransparency = 0.2 })
    task.spawn(function()
        while task.wait(0.3) do
            pcall(function() statusText:SetTitle(State.Status) end)
        end
    end)
end

--============================================================
-- TAB: FPS BOOST
--============================================================
local TabFPS = Window:Tab({
    Title = "FPS Boost", Desc = "Performa",
    Icon = "solar:cpu-bolt-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Name = "PallFisch_FPS"
    fpsLabel.Size = UDim2.new(0, 120, 0, 30)
    fpsLabel.Position = UDim2.new(0, 10, 0, 10)
    fpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fpsLabel.BackgroundTransparency = 0.4
    fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    fpsLabel.Font = Enum.Font.Code
    fpsLabel.TextSize = 16
    fpsLabel.Text = "FPS: --"
    fpsLabel.Visible = false
    fpsLabel.Parent = pg

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
    s2:Toggle({ Title = "Low Textures", Value = false,
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
        Title = "BURIK TOTAL MODE", Value = false,
        Callback = function(v)
            State.BurikTotal = v
            if v then
                applyLowTextures(); applyParticles(); applyShadows()
                applySkybox(); applyAtmosphere()
                WindUI:Notify({ Title = "Burik Total", Content = "Efek visual mati." })
            else
                restoreLowTextures(); restoreParticles(); restoreShadows()
                restoreSkybox(); restoreAtmosphere()
                WindUI:Notify({ Title = "Burik Total", Content = "Restore." })
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
-- TAB: CAMERA
--============================================================
local TabCamera = Window:Tab({
    Title = "Camera", Desc = "Zoom out",
    Icon = "solar:videocamera-record-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s = TabCamera:Section({ Title = "Camera", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Unlock Max Zoom", Value = false,
        Callback = function(v) State.CameraZoomEnabled = v end })
    s:Space()
    s:Slider({ Title = "Max Zoom", Step = 50,
        Value = { Min = 50, Max = 3000, Default = 800 },
        Callback = function(v) State.CameraZoomMax = v end })

    RunService.RenderStepped:Connect(function()
        if State.CameraZoomEnabled then
            pcall(function()
                LP.CameraMaxZoomDistance = State.CameraZoomMax
                LP.CameraMinZoomDistance = 0.5
            end)
        end
    end)
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
    s:Toggle({ Title = "Anti-AFK", Value = true,
        Callback = function(v) State.AntiAFK = v end })
end
--============================================================
-- AUTO FISH ENGINE
--============================================================
local flags = {
    guncangActive = false,
    barActive = false,
    castActive = false,
}

-- Cari Guncang button
local function findGuncangButton()
    for _, path in ipairs({
        {"shakeui", "safezone", "default"},
        {"shakeui", "safezone"},
    }) do
        local node = findByPath(pg, path)
        if node then
            if node:IsA("GuiButton") and node.Visible then return node end
            for _, c in ipairs(node:GetDescendants()) do
                if c:IsA("GuiButton") and c.Visible then return c end
            end
        end
    end
    for _, gui in ipairs(pg:GetChildren()) do
        for _, c in ipairs(gui:GetDescendants()) do
            if c:IsA("GuiButton") and c.Visible then
                local txt = (c.Text or ""):lower()
                if txt:find("guncang") or txt:find("shake") then return c end
            end
        end
    end
    return nil
end

-- Cari reel container
local function findReelContainer()
    local reel = pg:FindFirstChild("reel")
    if reel and reel.Visible then return reel end
    return nil
end

-- Cari Handle (yang gerak naik-turun)
local function findHandle()
    local reel = findReelContainer()
    if not reel then return nil end
    for _, c in ipairs(reel:GetDescendants()) do
        if c.Name == "Handle" and c:IsA("ImageLabel") and c.Visible then
            return c
        end
    end
    return nil
end

-- Cari bar track
local function findBarTrack()
    local reel = findReelContainer()
    if not reel then return nil end
    for _, c in ipairs(reel:GetDescendants()) do
        if c.Name == "bar" and c:IsA("Frame") and c.Visible and c.AbsoluteSize.X > 20 then
            return c
        end
    end
    return nil
end

-- Hitung progress Handle (0 = kiri, 1 = kanan)
local function getHandleProgress(handle, bar)
    if not handle or not bar then return 0.5 end
    local handleCenterX = handle.AbsolutePosition.X + handle.AbsoluteSize.X / 2
    local barStartX = bar.AbsolutePosition.X
    local barWidth = bar.AbsoluteSize.X
    if barWidth <= 0 then return 0.5 end
    return math.clamp((handleCenterX - barStartX) / barWidth, 0, 1)
end

-- Update flags
task.spawn(function()
    while task.wait(0.05) do
        if State.AutoFish then
            flags.guncangActive = findGuncangButton() ~= nil
            flags.barActive = findHandle() ~= nil

            local char = LP.Character
            local rod = char and char:FindFirstChildOfClass("Tool")
            flags.castActive = rod and rod:FindFirstChild("bobber") ~= nil
        else
            flags.guncangActive = false
            flags.barActive = false
            flags.castActive = false
        end
    end
end)

-- Tap rod icon (kanan bawah, dari screenshot)
local function tapRodIcon()
    local cam = workspace.CurrentCamera
    local vp = cam.ViewportSize
    tapAt(vp.X * 0.88, vp.Y * 0.72)
end

-- Tap di tengah layar (game izinin tap mana saja)
local function tapAnywhere()
    local cam = workspace.CurrentCamera
    local vp = cam.ViewportSize
    tapAt(vp.X * 0.5, vp.Y * 0.5)
end

-- Engine utama
task.spawn(function()
    while task.wait(0.05) do
        if not State.AutoFish then
            State.Status = "Idle"
            task.wait(0.5)
        else
            -- 1. GUNCANG
            if flags.guncangActive and State.AutoShake then
                State.Status = "🔴 Guncang — spam tap"
                local gb = findGuncangButton()
                if gb then
                    tapElement(gb)
                    task.wait(State.ShakeSpeed)
                else
                    task.wait(0.05)
                end

            -- 2. PERFECT BAR
            elseif flags.barActive and State.AutoReel then
                local handle = findHandle()
                local bar = findBarTrack()

                if handle and bar then
                    local prog = getHandleProgress(handle, bar)
                    State.Status = string.format("🎯 Bar: %.0f%%", prog * 100)

                    if prog >= State.PerfectThreshold then
                        tapAnywhere()
                        task.wait(0.1)
                    else
                        task.wait(0.03)
                    end
                else
                    tapAnywhere()
                    task.wait(0.1)
                end

            -- 3. NUNGGU BITE
            elseif flags.castActive then
                State.Status = string.format("🟢 Nunggu bite (%ds)", State.BiteWait)
                task.wait(State.BiteWait)

            -- 4. CAST ROD
            else
                State.Status = "⚪ Casting..."
                tapRodIcon()
                task.wait(State.CastDelay)
            end
        end
    end
end)

--============================================================
-- ANTI-AFK
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

--============================================================
-- NOTIF
--============================================================
WindUI:Notify({
    Title = "Pall Fisch v0.2.0",
    Content = "Auto Fish: Cast + Guncang + Perfect Bar.",
    Icon = "solar:bell-bold",
    Duration = 6,
})

print("[PALL-FISCH] v0.2.0 loaded. Cast + Guncang + Perfect Bar.")
