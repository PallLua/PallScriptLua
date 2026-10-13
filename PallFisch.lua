--[[
    ═══════════════════════════════════════════════════════════
    PALL — FISCH v1.0.0
    Logic  : Diadaptasi dari script komunitas Fisch yang proven
    UI     : WindUI (milik kita)
    Features:
      • Auto Fish (Cast + Shake + Reel + Perfect)
      • Auto Sell (Hand, All, Below C$)
      • Auto Appraise
      • FPS Boost, Camera, Movement, World
    ═══════════════════════════════════════════════════════════
--]]

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting            = game:GetService("Lighting")
local HttpService         = game:GetService("HttpService")

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
local Red    = Color3.fromHex("#EF4F1D")

--============================================================
-- STATE
--============================================================
local State = {
    -- Auto Fish
    AutoFish = false,
    AutoCast = true,
    AutoShake = true,
    AutoReel = true,
    InstantReel = false,
    PerfectCatch = true,
    CastDelay = 1.5,
    BiteWait = 5,
    PerfectThreshold = 0.65,
    ShakeSpeed = 0.06,

    -- Auto Sell
    AutoSell = false,
    SellMode = "Held",       -- Held / All / Below
    SellBelowAmount = 100,
    SellDelay = 2,

    -- Auto Appraise
    AutoAppraise = false,
    AppraiseDelay = 3,

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

local function findByPath(root, path)
    local node = root
    for _, seg in ipairs(path) do
        if not node then return nil end
        node = node:FindFirstChild(seg)
    end
    return node
end

local function getHum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getHRP() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

--============================================================
-- FPS BOOST (client-side)
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

-- World
local worldCache = { ambient=Color3.new(0,0,0), outdoor=Color3.new(0,0,0), fogEnd=0, fogStart=0 }
local function applyFullBright()
    worldCache.ambient = Lighting.Ambient
    worldCache.outdoor = Lighting.OutdoorAmbient
    Lighting.Ambient = Color3.fromRGB(180, 180, 180)
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
    Lighting.Brightness = 3
end
local function restoreFullBright()
    Lighting.Ambient = worldCache.ambient
    Lighting.OutdoorAmbient = worldCache.outdoor
    Lighting.Brightness = 1
end
local function applyNoFog()
    worldCache.fogEnd = Lighting.FogEnd
    worldCache.fogStart = Lighting.FogStart
    Lighting.FogEnd = 100000
    Lighting.FogStart = 100000
end
local function restoreNoFog()
    Lighting.FogEnd = worldCache.fogEnd
    Lighting.FogStart = worldCache.fogStart
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
Window:Tag({ Title = "v1.0.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

--============================================================
-- TAB: AUTO FISH
--============================================================
local TabAuto = Window:Tab({
    Title = "Auto Fish", Desc = "Cast, Guncang, Reel",
    Icon = "solar:fish-bold", IconColor = Green, IconShape = "Square", Border = true,
})
do
    local s1 = TabAuto:Section({ Title = "Control", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Fish", Value = false,
        Callback = function(v) State.AutoFish = v end })
    s1:Space()
    s1:Toggle({ Title = "Auto Cast", Value = true,
        Callback = function(v) State.AutoCast = v end })
    s1:Space()
    s1:Toggle({ Title = "Auto Guncang (Shake)", Value = true,
        Callback = function(v) State.AutoShake = v end })
    s1:Space()
    s1:Toggle({ Title = "Auto Reel / Bar", Value = true,
        Callback = function(v) State.AutoReel = v end })
    s1:Space()
    s1:Toggle({ Title = "Perfect Catch", Value = true,
        Callback = function(v) State.PerfectCatch = v end })

    local s2 = TabAuto:Section({ Title = "Timing", Box = true, BoxBorder = true, Opened = true })
    s2:Slider({ Title = "Shake Speed", Step = 0.01,
        Value = { Min = 0.03, Max = 0.2, Default = 0.06 },
        Callback = function(v) State.ShakeSpeed = v end })
    s2:Space()
    s2:Slider({ Title = "Cast Delay", Step = 0.1,
        Value = { Min = 0.5, Max = 5, Default = 1.5 },
        Callback = function(v) State.CastDelay = v end })
    s2:Space()
    s2:Slider({ Title = "Bite Wait", Step = 0.5,
        Value = { Min = 2, Max = 15, Default = 5 },
        Callback = function(v) State.BiteWait = v end })
    s2:Space()
    s2:Slider({ Title = "Perfect Threshold", Step = 0.05,
        Value = { Min = 0.5, Max = 1, Default = 0.65 },
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
-- TAB: AUTO SELL
--============================================================
local TabSell = Window:Tab({
    Title = "Auto Sell", Desc = "Jual ikan otomatis",
    Icon = "solar:cart-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s1 = TabSell:Section({ Title = "Auto Sell", Box = true, BoxBorder = true, Opened = true })
    s1:Toggle({ Title = "Auto Sell", Value = false,
        Callback = function(v) State.AutoSell = v end })
    s1:Space()
    s1:Dropdown({
        Title = "Mode",
        Values = { "Held", "All", "Below" },
        Value = "Held",
        Callback = function(v) State.SellMode = v end,
    })
    s1:Space()
    s1:Slider({ Title = "Sell Below C$", Step = 10,
        Value = { Min = 10, Max = 5000, Default = 100 },
        Callback = function(v) State.SellBelowAmount = v end })
    s1:Space()
    s1:Slider({ Title = "Sell Delay", Step = 0.5,
        Value = { Min = 1, Max = 10, Default = 2 },
        Callback = function(v) State.SellDelay = v end })
end

--============================================================
-- TAB: AUTO APPRAISE
--============================================================
local TabAppraise = Window:Tab({
    Title = "Appraise", Desc = "Appraise otomatis",
    Icon = "solar:star-bold", IconColor = Yellow, IconShape = "Square", Border = true,
})
do
    local s = TabAppraise:Section({ Title = "Auto Appraise", Box = true, BoxBorder = true, Opened = true })
    s:Toggle({ Title = "Auto Appraise", Value = false,
        Callback = function(v) State.AutoAppraise = v end })
    s:Space()
    s:Slider({ Title = "Appraise Delay", Step = 0.5,
        Value = { Min = 1, Max = 10, Default = 3 },
        Callback = function(v) State.AppraiseDelay = v end })
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
            else
                restoreLowTextures(); restoreParticles(); restoreShadows()
                restoreSkybox(); restoreAtmosphere()
            end
        end,
    })
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
    s1:Slider({
        Title = "WalkSpeed", Step = 1,
        Value = { Min = 16, Max = 150, Default = 16 },
        Callback = function(v)
            State.WalkSpeed = v
            local hum = getHum()
            if hum then hum.WalkSpeed = v end
        end,
    })

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
-- AUTO FISH ENGINE (diadaptasi dari script komunitas)
--============================================================
local flags = { guncangActive = false, barActive = false, castActive = false }

local function findGuncang()
    for _, gui in ipairs(pg:GetChildren()) do
        for _, c in ipairs(gui:GetDescendants()) do
            if c:IsA("GuiButton") and c.Visible then
                local txt = ""
                pcall(function() txt = (c.Text or ""):lower() end)
                if txt:find("guncang") or txt:find("shake") then return c end
                if c.Name:lower():find("guncang") or c.Name:lower():find("shake") then return c end
            end
        end
    end
    local node = pg:FindFirstChild("shakeui")
    if node then
        for _, c in ipairs(node:GetDescendants()) do
            if c:IsA("GuiButton") and c.Visible then return c end
        end
    end
    return nil
end

local function findReelBar()
    local reel = pg:FindFirstChild("reel")
    if reel and reel.Visible then return reel end
    return nil
end

local function findReelHandle(reel)
    if not reel then return nil end
    for _, c in ipairs(reel:GetDescendants()) do
        if c.Name == "Handle" and c.Visible then return c end
    end
    return nil
end

local function findReelBarTrack(reel)
    if not reel then return nil end
    for _, c in ipairs(reel:GetDescendants()) do
        if c.Name == "bar" and c:IsA("Frame") and c.Visible and c.AbsoluteSize.X > 20 then
            return c
        end
    end
    return nil
end

local function getHandleProgress(handle, bar)
    if not handle or not bar then return 0.5 end
    local hcx = handle.AbsolutePosition.X + handle.AbsoluteSize.X / 2
    local bx = bar.AbsolutePosition.X
    local bw = bar.AbsoluteSize.X
    if bw <= 0 then return 0.5 end
    return math.clamp((hcx - bx) / bw, 0, 1)
end

local function tapRod()
    local vp = workspace.CurrentCamera.ViewportSize
    tapAt(vp.X * 0.88, vp.Y * 0.72)
end

local function tapCenter()
    local vp = workspace.CurrentCamera.ViewportSize
    tapAt(vp.X * 0.5, vp.Y * 0.5)
end

-- Update flags
task.spawn(function()
    while task.wait(0.05) do
        if State.AutoFish then
            flags.guncangActive = findGuncang() ~= nil
            flags.barActive = findReelBar() ~= nil
            local char = LP.Character
            local rod = char and char:FindFirstChildOfClass("Tool")
            flags.castActive = rod and rod:FindFirstChild("bobber") ~= nil
        end
    end
end)

-- Engine
task.spawn(function()
    while task.wait(0.05) do
        if not State.AutoFish then
            State.Status = "Idle"
            task.wait(0.5)
        else
            if flags.guncangActive and State.AutoShake then
                State.Status = "🔴 Guncang"
                local gb = findGuncang()
                if gb then tapElement(gb) end
                task.wait(State.ShakeSpeed)

            elseif flags.barActive and State.AutoReel then
                local reel = findReelBar()
                local handle = findReelHandle(reel)
                local bar = findReelBarTrack(reel)
                if handle and bar then
                    local prog = getHandleProgress(handle, bar)
                    State.Status = string.format("🎯 Bar: %.0f%%", prog * 100)
                    if prog >= State.PerfectThreshold then
                        tapCenter()
                        task.wait(0.1)
                    else
                        task.wait(0.03)
                    end
                else
                    tapCenter()
                    task.wait(0.1)
                end

            elseif flags.castActive then
                State.Status = string.format("🟢 Nunggu bite (%ds)", State.BiteWait)
                task.wait(State.BiteWait)

            elseif State.AutoCast then
                State.Status = "⚪ Casting..."
                tapRod()
                task.wait(State.CastDelay)
            else
                State.Status = "Idle (Auto Cast off)"
                task.wait(1)
            end
        end
    end
end)

--============================================================
-- AUTO SELL ENGINE (tap-based, dari script komunitas)
--============================================================
task.spawn(function()
    while task.wait(State.SellDelay) do
        if State.AutoSell then
            -- Buka inventory (tekan B atau tap icon)
            local backpackBtn = nil
            for _, gui in ipairs(pg:GetChildren()) do
                for _, c in ipairs(gui:GetDescendants()) do
                    if c:IsA("GuiButton") and c.Visible then
                        local n = c.Name:lower()
                        if n:find("backpack") or n:find("inventory") or n:find("bag") then
                            backpackBtn = c; break
                        end
                    end
                end
                if backpackBtn then break end
            end
            if backpackBtn then
                tapElement(backpackBtn)
                task.wait(0.5)
            end

            -- Cari tombol sell di inventory
            local sellBtn = nil
            for _, gui in ipairs(pg:GetChildren()) do
                for _, c in ipairs(gui:GetDescendants()) do
                    if c:IsA("GuiButton") and c.Visible then
                        local n = c.Name:lower()
                        local t = ""
                        pcall(function() t = (c.Text or ""):lower() end)
                        if n:find("sell") or t:find("sell") or t:find("jual") then
                            sellBtn = c; break
                        end
                    end
                end
                if sellBtn then break end
            end
            if sellBtn then
                tapElement(sellBtn)
                task.wait(0.5)
                -- Konfirmasi kalau ada
                local confirmBtn = nil
                for _, gui in ipairs(pg:GetChildren()) do
                    for _, c in ipairs(gui:GetDescendants()) do
                        if c:IsA("GuiButton") and c.Visible then
                            local t = ""
                            pcall(function() t = (c.Text or ""):lower() end)
                            if t:find("yes") or t:find("confirm") or t:find("ok") then
                                confirmBtn = c; break
                            end
                        end
                    end
                    if confirmBtn then break end
                end
                if confirmBtn then tapElement(confirmBtn) end
            end
        end
    end
end)

--============================================================
-- AUTO APPRAISE ENGINE (tap-based)
--============================================================
task.spawn(function()
    while task.wait(State.AppraiseDelay) do
        if State.AutoAppraise then
            -- Cari tombol appraise di inventory
            local appraiseBtn = nil
            for _, gui in ipairs(pg:GetChildren()) do
                for _, c in ipairs(gui:GetDescendants()) do
                    if c:IsA("GuiButton") and c.Visible then
                        local n = c.Name:lower()
                        local t = ""
                        pcall(function() t = (c.Text or ""):lower() end)
                        if n:find("appraise") or t:find("appraise") or t:find("nilai") then
                            appraiseBtn = c; break
                        end
                    end
                end
                if appraiseBtn then break end
            end
            if appraiseBtn then
                tapElement(appraiseBtn)
                task.wait(0.5)
                -- Konfirmasi kalau ada
                local confirmBtn = nil
                for _, gui in ipairs(pg:GetChildren()) do
                    for _, c in ipairs(gui:GetDescendants()) do
                        if c:IsA("GuiButton") and c.Visible then
                            local t = ""
                            pcall(function() t = (c.Text or ""):lower() end)
                            if t:find("yes") or t:find("confirm") then
                                confirmBtn = c; break
                            end
                        end
                    end
                    if confirmBtn then break end
                end
                if confirmBtn then tapElement(confirmBtn) end
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
    Title = "Pall Fisch v1.0.0",
    Content = "Logic komunitas + UI kita. Auto Fish, Auto Sell, Auto Appraise.",
    Icon = "solar:bell-bold",
    Duration = 8,
})

print("[PALL-FISCH] v1.0.0 loaded. Community logic + our UI.")
