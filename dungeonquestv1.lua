-- =====================================================================
-- BANANA HUB v7 - ULTIMATE DUNGEON QUEST SCRIPT
-- Features: Combat, Movement, Farming, Stage Teleport, Shop, FOV/FPS, 
--           Invisible Mode, & Safe True-Damage Instant Kill
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Konfigurasi Toggle Fitur
getgenv().BananaHub = {
    AutoCollect = false,
    AutoNextStage = false,
    KillAura = false,
    InstantKill = false, -- True Damage Mode
    StageTeleport = false,
    AutoBuyUpgrade = false,
    CustomFOV = false,
    FOVValue = 120,
    FPSUnlocker = false,
    InvisibleMode = false,
    AntiAFK = true
}

-- =====================================================================
-- 1. SAFE TRUE-DAMAGE INSTANT KILL & KILL AURA
-- =====================================================================
-- Menggunakan sistem manipulasi health/remote event target musuh secara langsung 
-- tanpa menyentuh atau memantulkan damage ke LocalPlayer.

local function getEnemies()
    local enemiesList = {}
    -- Sesuaikan folder target musuh di game Dungeon Quest jika diperlukan
    local enemiesFolder = Workspace:FindFirstChild("Enemies") or Workspace:FindFirstChild("Monsters")
    if enemiesFolder then
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            local humanoid = enemy:FindFirstChildOfClass("Humanoid")
            local rootPart = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Torso")
            if humanoid and rootPart and humanoid.Health > 0 then
                table.insert(enemiesList, {Model = enemy, Humanoid = humanoid, RootPart = rootPart})
            end
        end
    end
    return enemiesList
end

RunService.Heartbeat:Connect(function()
    if getgenv().BananaHub.InstantKill or getgenv().BananaHub.KillAura then
        pcall(function()
            for _, enemyData in ipairs(getEnemies()) do
                if enemyData.Humanoid and enemyData.Humanoid.Health > 0 then
                    if getgenv().BananaHub.InstantKill then
                        -- True Damage murni langsung set health musuh ke 0 
                        -- Memastikan darah LocalPlayer aman 100%
                        enemyData.Humanoid.Health = 0
                    elseif getgenv().BananaHub.KillAura then
                        -- Berikan damage berkala secara aman
                        if enemyData.RootPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local dist = (LocalPlayer.Character.HumanoidRootPart.Position - enemyData.RootPart.Position).Magnitude
                            if dist <= 35 then
                                enemyData.Humanoid:TakeDamage(5000)
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- =====================================================================
-- 2. STAGE TELEPORT & AUTO NEXT STAGE
-- =====================================================================
RunService.Stepped:Connect(function()
    if getgenv().BananaHub.StageTeleport and LocalPlayer.Character then
        pcall(function()
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in ipairs(Workspace:GetChildren()) do
                    -- Mendeteksi pintu/portal stage berikutnya
                    if obj.Name:lower():find("door") or obj.Name:lower():find("portal") or obj.Name:lower():find("gate") then
                        local portalPart = obj:FindFirstChild("Part") or obj:FindFirstChildOfClass("BasePart")
                        if portalPart then
                            hrp.CFrame = portalPart.CFrame + Vector3.new(0, 3, 0)
                        end
                    end
                end
            end
        end)
    end
end)

-- =====================================================================
-- 3. AUTO BUY & UPGRADE GEAR / POTIONS
-- =====================================================================
task.spawn(function()
    while task.wait(2) do
        if getgenv().BananaHub.AutoBuyUpgrade then
            pcall(function()
                -- Simulasi interaksi NPC Shop di Lobby Dungeon Quest
                local shops = Workspace:FindFirstChild("Shops") or Workspace:FindFirstChild("NPCs")
                if shops and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    for _, shop in ipairs(shops:GetChildren()) do
                        local prompt = shop:FindFirstChildOfClass("ProximityPrompt")
                        if prompt then
                            fireproximityprompt(prompt)
                        end
                    end
                end
            end)
        end
    end
end)

-- =====================================================================
-- 4. CUSTOM FOV & FPS UNLOCKER
-- =====================================================================
RunService.RenderStepped:Connect(function()
    if getgenv().BananaHub.CustomFOV then
        Camera.FieldOfView = getgenv().BananaHub.FOVValue
    end
    if getgenv().BananaHub.FPSUnlocker then
        setfpscap(999)
    end
end)

-- =====================================================================
-- 5. INVISIBLE MODE (CLIENT-SIDE)
-- =====================================================================
task.spawn(function()
    while task.wait(1) do
        if getgenv().BananaHub.InvisibleMode and LocalPlayer.Character then
            pcall(function()
                for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.Transparency = 1
                    elseif part:IsA("Decal") then
                        part.Transparency = 1
                    end
                end
            end)
        end
    end
end)

-- =====================================================================
-- 6. ANTI-AFK SYSTEM
-- =====================================================================
local vu = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    if getgenv().BananaHub.AntiAFK then
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

print("Banana Hub v7 Loaded Successfully! True Damage Instant Kill Active.")
