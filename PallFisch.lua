--[[
    ═══════════════════════════════════════════════════════════
    PALL — FISCH
    Author  : ENI (for Pall)
    Version : v0.1.0 — Smooth Auto Fish
    Notes   :
      • Event-driven (bukan polling) → nggak lag
      • Tap simulation (VirtualInputManager) → aman dari Byfron
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

--============================================================
-- STATE
--============================================================
local State = {
    FPSCounter = false,
    LowTextures = false,
    RemoveParticles = false,
    DisableShadows = false,
    DisableSkybox = false,
    DisableAtmosphere = false,
    BurikTotal = false,

    CameraZoomEnabled = false,
    CameraZoomMax = 800,

    AntiAFK = true,

    -- Auto Fish
    AutoFish = false,
    AutoShake = true,
    AutoReel = true,
    ShakeSpeed = 0.06,
    ReelDelay = 0.4,
    CastDelay = 1.5,
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
Window:Tag({ Title = "v0.1.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: AUTO FISH
--============================================================
local TabAuto = Window:Tab({
    Title = "Auto Fish", Desc = "Event-driven tap",
    Icon = "solar:fish-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s1 = TabAuto:Section({ Title = "Auto Fish", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Fish", Value = false,
        Callback = function(v) State.AutoFish = v end })
    s1:Space()
    s1:Toggle({ Title = "Auto Shake Minigame", Value = true,
        Callback = function(v) State.AutoShake = v end })
    s1:Space()
    s1:Toggle({ Title = "Auto Reel", Value = true,
        Callback = function(v) State.AutoReel = v end })

    local s2 = TabAuto:Section({ Title = "Timing", Box = true, BoxBorder = true, Opened = true })
    s2:Slider({ Title = "Shake Speed", Step = 0.01,
        Value = { Min = 0.03, Max = 0.2, Default = 0.06 },
        Callback = function(v) State.ShakeSpeed = v end })
    s2:Space()
    s2:Slider({ Title = "Reel Delay", Step = 0.1,
        Value = { Min = 0.1, Max = 2, Default = 0.4 },
        Callback = function(v) State.ReelDelay = v end })
    s2:Space()
    s2:Slider({ Title = "Cast Delay", Step = 0.1,
        Value = { Min = 0.5, Max = 5, Default = 1.5 },
        Callback = function(v) State.CastDelay = v end })

    local s3 = TabAuto:Section({ Title = "Status", Box = true, BoxBorder = true, Opened = true })
    local statusText = s3:Section({ Title = "Idle", TextSize = 15, TextTransparency = 0.2 })
    task.spawn(function()
        while task.wait(0.5) do
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
-- AUTO FISH — EVENT-DRIVEN ENGINE
--============================================================
-- Status flag: apa yang lagi aktif
local flags = {
    shakeActive = false,
    reelActive = false,
    catchActive = false,
    castActive = false,
}

-- Update flag saat GUI muncul/hilang
task.spawn(function()
    while task.wait(0.1) do
        if State.AutoFish then
            -- Cek shake
            local shake = findByPath(pg, {"shakeui", "safezone", "default"})
            flags.shakeActive = shake ~= nil and shake.Visible ~= false

            -- Cek reel
            local reel = findByPath(pg, {"reel", "bar", "fish"})
            flags.reelActive = reel ~= nil and reel.Visible ~= false

            -- Cek catch announcement
            local catch = findByPath(pg, {"hud", "safezone", "announcements", "catch"})
            flags.catchActive = catch ~= nil and catch.Visible ~= false

            -- Cek bobber di workspace
            local char = LP.Character
            local rod = char and char:FindFirstChildOfClass("Tool")
            if rod then
                local bobber = rod:FindFirstChild("bobber")
                flags.castActive = bobber ~= nil
            else
                flags.castActive = false
            end
        else
            flags.shakeActive = false
            flags.reelActive = false
            flags.catchActive = false
            flags.castActive = false
        end
    end
end)

-- Engine utama
task.spawn(function()
    while task.wait(0.05) do
        if not State.AutoFish then
            State.Status = "Idle"
            task.wait(0.5)
        else
            -- PRIORITY 1: Shake minigame
            if flags.shakeActive and State.AutoShake then
                State.Status = "🔴 Auto Shake"
                local shake = findByPath(pg, {"shakeui", "safezone", "default"})
                if shake then
                    tapElement(shake)
                    task.wait(State.ShakeSpeed)
                else
                    task.wait(0.1)
                end

            -- PRIORITY 2: Reel minigame
            elseif flags.reelActive and State.AutoReel then
                State.Status = "🟡 Auto Reel"
                local reel = findByPath(pg, {"reel", "bar", "fish"})
                if reel then
                    tapElement(reel)
                    task.wait(State.ReelDelay)
                else
                    task.wait(0.1)
                end

            -- PRIORITY 3: Ikan baru ketangkep → tunggu bentar, cast lagi
            elseif flags.catchActive then
                State.Status = "🟢 Catch! Siap cast ulang"
                task.wait(State.CastDelay)

            -- PRIORITY 4: Nggak ada apa-apa → tap area mancing
            else
                State.Status = "⚪ Casting / tunggu bite"
                -- Coba tap tombol fish kalau ada
                local fishBtn = findByPath(pg, {"hud", "safezone", "fishButton"})
                if not fishBtn then
                    local hud = pg:FindFirstChild("hud")
                    if hud then
                        for _, c in ipairs(hud:GetDescendants()) do
                            if (c:IsA("ImageButton") or c:IsA("TextButton")) and c.Visible
                               and c.Name:lower():find("fish") then
                                fishBtn = c; break
                            end
                        end
                    end
                end

                if fishBtn then
                    tapElement(fishBtn)
                else
                    -- Fallback: tap tengah bawah layar (area fish button biasanya)
                    local cam = workspace.CurrentCamera
                    local vp = cam.ViewportSize
                    tapAt(vp.X * 0.5, vp.Y * 0.85)
                end
                task.wait(0.3)
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
    Title = "Pall Fisch v0.1.0",
    Content = "Auto Fish siap. Event-driven, no lag.",
    Icon = "solar:bell-bold",
    Duration = 6,
})

print("[PALL-FISCH] v0.1.0 loaded. Smooth Auto Fish aktif.")
