--[[
    ═══════════════════════════════════════════════════════════
    PALL — FISCH v1.1.0
    Logic  : Diambil dari script komunitas (Pastebin + Xeno Scripts)
    UI     : WindUI
    Remote:
      - Cast : tool.events.cast:FireServer(100, 1)
      - Reel : ReplicatedStorage.events.reelfinished:FireServer(100, true)
      - Sell : ReplicatedStorage.events.SellAll:InvokeServer()
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
local pg = LP:WaitForChild("PlayerGui")

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

--============================================================
-- STATE
--============================================================
local State = {
    -- Auto Fish
    AutoFish = false,
    AutoShake = true,
    InstantReel = true,
    CastDelay = 2,
    ShakeSearchRadius = 200,  -- radius pencarian tombol shake (px)

    -- Auto Sell
    AutoSell = false,
    SellDelay = 2,

    -- Client
    FPSCounter = false,
    LowTextures = false,
    RemoveParticles = false,
    DisableShadows = false,
    DisableSkybox = false,
    DisableAtmosphere = false,
    BurikTotal = false,
    CamZoom = false,
    CamZoomMax = 800,
    WalkSpeed = 16,
    InfJump = false,
    Noclip = false,
    AntiAFK = true,
    FullBright = false,
    NoFog = false,

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
    local pos, size = el.AbsolutePosition, el.AbsoluteSize
    tapAt(pos.X + size.X / 2, pos.Y + size.Y / 2)
    return true
end

local function getHum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getHRP() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

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
        if obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then obj.Transparency = 1 end
    end
end
local function restoreLowTextures()
    for obj, data in pairs(fpsCache.materials) do
        if obj and obj.Parent then
            obj.Material = data.mat; obj.Reflectance = data.ref
        end
    end
    fpsCache.materials = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then obj.Transparency = 0 end
    end
end

local function applyParticles()
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") then o.Enabled = false end
    end
end
local function restoreParticles()
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") then o.Enabled = true end
    end
end

local function applyShadows()
    fpsCache.shadows = { g = Lighting.GlobalShadows, s = Lighting.ShadowSoftness }
    Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0
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

local worldCache = { ambient=Color3.new(0,0,0), outdoor=Color3.new(0,0,0), fogEnd=0, fogStart=0 }
local function applyFullBright()
    worldCache.ambient = Lighting.Ambient; worldCache.outdoor = Lighting.OutdoorAmbient
    Lighting.Ambient = Color3.fromRGB(180,180,180)
    Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
    Lighting.Brightness = 3
end
local function restoreFullBright()
    Lighting.Ambient = worldCache.ambient; Lighting.OutdoorAmbient = worldCache.outdoor
    Lighting.Brightness = 1
end
local function applyNoFog()
    worldCache.fogEnd = Lighting.FogEnd; worldCache.fogStart = Lighting.FogStart
    Lighting.FogEnd = 100000; Lighting.FogStart = 100000
end
local function restoreNoFog()
    Lighting.FogEnd = worldCache.fogEnd; Lighting.FogStart = worldCache.fogStart
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
Window:Tag({ Title = "v1.1.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: AUTO FISH
--============================================================
local TabAuto = Window:Tab({
    Title = "Auto Fish", Desc = "Cast + Shake + Reel",
    Icon = "solar:fish-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s1 = TabAuto:Section({ Title = "Control", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Fish", Value = false,
        Callback = function(v) State.AutoFish = v end })
    s1:Space()
    s1:Toggle({ Title = "Auto Shake (tap)", Value = true,
        Callback = function(v) State.AutoShake = v end })
    s1:Space()
    s1:Toggle({ Title = "Instant Reel (FireServer)", Value = true,
        Callback = function(v) State.InstantReel = v end })

    local s2 = TabAuto:Section({ Title = "Timing", Box = true, BoxBorder = true, Opened = true })
    s2:Slider({ Title = "Cast Delay", Step = 0.5,
        Value = { Min = 1, Max = 10, Default = 2 },
        Callback = function(v) State.CastDelay = v end })
    s2:Space()
    s2:Slider({ Title = "Shake Search Radius (px)", Step = 50,
        Value = { Min = 100, Max = 800, Default = 200 },
        Callback = function(v) State.ShakeSearchRadius = v end })

    local s3 = TabAuto:Section({ Title = "Status", Box = true, BoxBorder = true, Opened = true })
    local statusText = s3:Section({ Title = "Idle", TextSize = 15, TextTransparency = 0.2 })
    task.spawn(function()
        while task.wait(0.3) do
            pcall(function() statusText:SetTitle(State.Status) end)
        end
    end)
end

--============================================================
-- TAB: AUTO SELL
--============================================================
local TabSell = Window:Tab({
    Title = "Auto Sell", Desc = "SellAll remote",
    Icon = "solar:cart-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s = TabSell:Section({ Title = "Auto Sell", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Auto Sell (SellAll)", Value = false,
        Callback = function(v) State.AutoSell = v end })
    s:Space()
    s:Slider({ Title = "Sell Delay", Step = 0.5,
        Value = { Min = 1, Max = 15, Default = 2 },
        Callback = function(v) State.SellDelay = v end })
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
            frames = 0; lastTime = tick()
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
    s3:Toggle({ Title = "BURIK TOTAL MODE", Value = false,
        Callback = function(v)
            State.BurikTotal = v
            if v then
                applyLowTextures(); applyParticles(); applyShadows()
                applySkybox(); applyAtmosphere()
            else
                restoreLowTextures(); restoreParticles(); restoreShadows()
                restoreSkybox(); restoreAtmosphere()
            end
        end })
end

--============================================================
-- TAB: WORLD
--============================================================
local TabWorld = Window:Tab({
    Title = "World", Desc = "Lighting & Fog",
    Icon = "solar:sun-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s = TabWorld:Section({ Title = "Lighting", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Full Bright", Value = false,
        Callback = function(v) State.FullBright = v
            if v then applyFullBright() else restoreFullBright() end end })
    s:Space()
    s:Toggle({ Title = "No Fog", Value = false,
        Callback = function(v) State.NoFog = v
            if v then applyNoFog() else restoreNoFog() end end })
end

--============================================================
-- TAB: MOVEMENT
--============================================================
local TabMove = Window:Tab({
    Title = "Movement", Desc = "Speed, Jump, Noclip",
    Icon = "solar:running-2-bold", IconColor = Blue, IconShape = "Square", Border = true,
})
do
    local s1 = TabMove:Section({ Title = "Speed", Box = true, BoxBorder = true, Opened = true })
    s1:Slider({ Title = "WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 150, Default = 16 },
        Callback = function(v)
            State.WalkSpeed = v
            local hum = getHum(); if hum then hum.WalkSpeed = v end
        end })

    local s2 = TabMove:Section({ Title = "Misc", Box = true, BoxBorder = true, Opened = true })
    s2:Toggle({ Title = "Infinite Jump", Value = false,
        Callback = function(v) State.InfJump = v end })
    s2:Space()
    s2:Toggle({ Title = "Noclip", Value = false,
        Callback = function(v) State.Noclip = v end })
    s2:Space()
    s2:Toggle({ Title = "Anti-AFK", Value = true,
        Callback = function(v) State.AntiAFK = v end })
end

--============================================================
-- TAB: CAMERA
--============================================================
local TabCamera = Window:Tab({
    Title = "Camera", Desc = "Zoom out",
    Icon = "solar:videocamera-record-bold", IconColor = Purple, IconShape = "Square", Border = true,
})
do
    local s = TabCamera:Section({ Title = "Camera", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Unlock Max Zoom", Value = false,
        Callback = function(v) State.CamZoom = v end })
    s:Space()
    s:Slider({ Title = "Max Zoom", Step = 50,
        Value = { Min = 50, Max = 3000, Default = 800 },
        Callback = function(v) State.CamZoomMax = v end })

    RunService.RenderStepped:Connect(function()
        if State.CamZoom then
            pcall(function()
                LP.CameraMaxZoomDistance = State.CamZoomMax
                LP.CameraMinZoomDistance = 0.5
            end)
        end
    end)
end

--============================================================
-- AUTO FISH ENGINE (LOGIC KOMUNITAS)
--============================================================
-- Cari rod yang punya remote events.cast
local function findRodWithCast()
    local char = LP.Character
    if not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local events = tool:FindFirstChild("events")
            if events and events:FindFirstChild("cast") then
                return tool
            end
        end
    end
    -- Cek backpack juga
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local events = tool:FindFirstChild("events")
                if events and events:FindFirstChild("cast") then
                    return tool
                end
            end
        end
    end
    return nil
end

-- Cari tombol Guncang (shake) yang muncul acak
local function findShakeButton()
    for _, gui in ipairs(pg:GetChildren()) do
        for _, c in ipairs(gui:GetDescendants()) do
            if (c:IsA("ImageButton") or c:IsA("TextButton")) and c.Visible then
                local n = c.Name:lower()
                local t = ""
                pcall(function() t = (c.Text or ""):lower() end)
                if n:find("shake") or n:find("guncang") or t:find("shake") or t:find("guncang") then
                    return c
                end
                -- Cek parent name
                if c.Parent and c.Parent.Name:lower():find("shake") then
                    return c
                end
            end
        end
    end
    return nil
end

-- Cast rod pakai remote komunitas
local function castRod()
    local rod = findRodWithCast()
    if rod then
        local events = rod:FindFirstChild("events")
        if events and events:FindFirstChild("cast") then
            pcall(function()
                events.cast:FireServer(100, 1)
            end)
            return true
        end
    end
    return false
end

-- Reel pakai remote komunitas
local function reelFish()
    local events = ReplicatedStorage:FindFirstChild("events")
    if events and events:FindFirstChild("reelfinished") then
        pcall(function()
            events.reelfinished:FireServer(100, true)
        end)
        return true
    end
    return false
end

-- Sell pakai remote komunitas
local function sellAll()
    local events = ReplicatedStorage:FindFirstChild("events")
    if events and events:FindFirstChild("SellAll") then
        pcall(function()
            events.SellAll:InvokeServer()
        end)
        return true
    end
    return false
end

-- Engine Auto Fish
task.spawn(function()
    while task.wait(0.1) do
        if State.AutoFish then
            local rod = findRodWithCast()

            if not rod then
                State.Status = "⚠️ Rod dengan events.cast tidak ditemukan"
                task.wait(1)
            else
                -- Cek apakah rod udah di-cast (bobber ada)
                local bobber = rod:FindFirstChild("bobber")
                local shakeBtn = findShakeButton()

                if shakeBtn and State.AutoShake then
                    State.Status = "🔴 Shake — tap"
                    tapElement(shakeBtn)
                    task.wait(0.05)

                elseif bobber then
                    State.Status = "🟢 Nunggu bite — Instant Reel aktif"
                    if State.InstantReel then
                        reelFish()
                    end
                    task.wait(0.5)

                else
                    State.Status = "⚪ Casting..."
                    castRod()
                    task.wait(State.CastDelay)
                end
            end
        else
            State.Status = "Idle"
            task.wait(0.5)
        end
    end
end)

-- Auto Sell Engine
task.spawn(function()
    while task.wait(State.SellDelay) do
        if State.AutoSell then
           if sellAll() then
                State.Status = "💰 SellAll triggered"
            end
        end
    end
end)

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

UserInputService.JumpRequest:Connect(function()
    if State.InfJump then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

RunService.Stepped:Connect(function()
    if State.Noclip and LP.Character then
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
end)

LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = State.WalkSpeed end
end)

--============================================================
-- NOTIF
--============================================================
WindUI:Notify({
    Title = "Pall Fisch v1.1.0",
    Content = "Logic komunitas: Cast + Instant Reel + SellAll.",
    Icon = "solar:bell-bold",
    Duration = 8,
})

print("[PALL-FISCH] v1.1.0 loaded. Community logic.")
