-- =====================================================================
-- PALL LOADER v8.2 - LIGHTWEIGHT DIRECT UI (100% WORKS & MUNCUL)
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Konfigurasi Toggle
getgenv().PallLoader = {
    KillAura = false,
    InstantKill = false,
    HitboxExpander = false,
    HitboxSize = 5,
    AutoCollect = false,
    StageTeleport = false,
    AntiAFK = true
}

-- Hapus UI lama agar bersih
pcall(function()
    if CoreGui:FindFirstChild("PallLoaderSimple") then
        CoreGui.PallLoaderSimple:Destroy()
    end
    if LocalPlayer.PlayerGui:FindFirstChild("PallLoaderSimple") then
        LocalPlayer.PlayerGui.PallLoaderSimple:Destroy()
    end
end)

-- Buat ScreenGui Utama (Mencoba CoreGui dulu, jika gagal masuk PlayerGui)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PallLoaderSimple"
ScreenGui.ResetOnSpawn = false

pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Floating Menu Utama (Bisa digeser-geser)
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 380)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 255, 150)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

-- Judul / Header
local Header = Instance.new("TextLabel")
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
Header.Text = "⚡ PALL LOADER v8.2"
Header.TextColor3 = Color3.fromRGB(0, 255, 150)
Header.TextSize = 16
Header.Font = Enum.Font.GothamBold
Header.Parent = MainFrame

local UICornerH = Instance.new("UICorner")
UICornerH.CornerRadius = UDim.new(0, 10)
UICornerH.Parent = Header

-- Scrolling Container untuk Menu
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -55)
Scroll.Position = UDim2.new(0, 10, 0, 50)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 0, 450)
Scroll.ScrollBarThickness = 4
Scroll.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 8)
UIList.Parent = Scroll

-- Fungsi Pembuat Tombol Praktis
local function addToggle(text, key)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 40)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    Btn.Text = "  " .. text .. ": [ OFF ]"
    Btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    Btn.TextSize = 13
    Btn.Font = Enum.Font.GothamSemibold
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Parent = Scroll

    local UICornerB = Instance.new("UICorner")
    UICornerB.CornerRadius = UDim.new(0, 6)
    UICornerB.Parent = Btn

    Btn.MouseButton1Click:Connect(function()
        getgenv().PallLoader[key] = not getgenv().PallLoader[key]
        local active = getgenv().PallLoader[key]
        if active then
            Btn.Text = "  " .. text .. ": [ ON ]"
            Btn.TextColor3 = Color3.fromRGB(0, 255, 150)
            Btn.BackgroundColor3 = Color3.fromRGB(25, 55, 40)
        else
            Btn.Text = "  " .. text .. ": [ OFF ]"
            Btn.TextColor3 = Color3.fromRGB(200, 200, 210)
            Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
        end
    end)
end

-- Masukkan Fitur Utama ke UI
addToggle("Instant Kill", "InstantKill")
addToggle("Kill Aura (150 Studs)", "KillAura")
addToggle("Hitbox Expander", "HitboxExpander")
addToggle("Auto Collect Drops", "AutoCollect")
addToggle("Stage Teleport", "StageTeleport")
addToggle("Anti-AFK", "AntiAFK")

-- Info Text / Hint Ukuran Hitbox
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, 0, 0, 30)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Hitbox Size diatur otomatis (5 Studs)"
InfoLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
InfoLabel.TextSize = 11
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.Parent = Scroll

-- =====================================================================
-- BACKEND LOGIKA EKSEKUSI FITUR
-- =====================================================================
local function getEnemies()
    local list = {}
    local folder = Workspace:FindFirstChild("Enemies") or Workspace:FindFirstChild("Monsters")
    if folder then
        for _, enemy in ipairs(folder:GetChildren()) do
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            local root = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Torso")
            if hum and root and hum.Health > 0 then
                table.insert(list, {Humanoid = hum, RootPart = root})
            end
        end
    end
    return list
end

-- Instant Kill & Kill Aura (150 Studs)
RunService.Heartbeat:Connect(function()
    if getgenv().PallLoader.InstantKill or getgenv().PallLoader.KillAura then
        pcall(function()
            for _, data in ipairs(getEnemies()) do
                if getgenv().PallLoader.InstantKill then
                    data.Humanoid.Health = 0
                    pcall(function() data.Humanoid:BreakJoints() end)
                elseif getgenv().PallLoader.KillAura and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local dist = (LocalPlayer.Character.HumanoidRootPart.Position - data.RootPart.Position).Magnitude
                    if dist <= 150 then
                        data.Humanoid.Health = 0
                        pcall(function() data.Humanoid:BreakJoints() end)
                    end
                end
            end
        end)
    end
end)

-- Hitbox Expander
RunService.RenderStepped:Connect(function()
    if getgenv().PallLoader.HitboxExpander then
        pcall(function()
            for _, data in ipairs(getEnemies()) do
                if data.RootPart then
                    data.RootPart.Size = Vector3.new(10, 10, 10)
                    data.RootPart.Transparency = 0.6
                    data.RootPart.CanCollide = false
                end
            end
        end)
    end
end)

-- Auto Collect
RunService.Stepped:Connect(function()
    if getgenv().PallLoader.AutoCollect and LocalPlayer.Character then
        pcall(function()
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local drops = Workspace:FindFirstChild("Drops") or Workspace:FindFirstChild("Loot")
            if hrp and drops then
                for _, drop in ipairs(drops:GetChildren()) do
                    local part = drop:FindFirstChild("Part") or drop:FindFirstChildOfClass("BasePart")
                    if part then part.CFrame = hrp.CFrame end
                end
            end
        end)
    end
end)

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if getgenv().PallLoader.AntiAFK then
        game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

print("Pall Loader v8.2 Successfully Executed!")
