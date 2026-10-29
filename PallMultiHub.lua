--[[
    ═══════════════════════════════════════════════════════════
    PALL MULTI-HUB — Router
    Author  : ENI (for Pall)
    Version : v1.4.0 — Support DQR, Dice Poly, & STK
    ═══════════════════════════════════════════════════════════
--]]

--============================================================
-- DAFTAR GAME
--============================================================
local GAMES = {
    -- Dungeon Quest Reborn (LOBBY)
    [77649408247578] = {
        Name = "Dungeon Quest Reborn (Lobby)",
        URL  = "https://raw.githubusercontent.com/PallLua/PallScriptLua/refs/heads/main/PallDQR.lua",
        Folder = "pallhubv610",
    },

    -- Dungeon Quest Reborn (DUNGEON)
    [85776757589518] = {
        Name = "Dungeon Quest Reborn (Dungeon)",
        URL  = "https://raw.githubusercontent.com/PallLua/PallScriptLua/refs/heads/main/PallDQR.lua",
        Folder = "pallhubv610",
    },

    -- Dice Poly
    [112499281467636] = {
        Name = "Dice Poly",
        URL  = "https://raw.githubusercontent.com/PallLua/PallScriptLua/refs/heads/main/PallDicePoly.lua",
        Folder = "palldice",
    },

    -- Survive The Killer (STK)
    [4580204640] = {
        Name = "Survive The Killer",
        URL  = "https://raw.githubusercontent.com/PallLua/PallScriptLua/refs/heads/main/PallSTK.lua",
        Folder = "pallstk",
    },
}

--============================================================
-- DETEKSI GAME
--============================================================
local currentPlace = game.PlaceId
local currentGameId = game.GameId
local config = GAMES[currentPlace]

if not config then
    for _, entry in pairs(GAMES) do
        if entry.GameId and entry.GameId == currentGameId then
            config = entry
            break
        end
    end
end

--============================================================
-- LOAD WINDUI (shared via _G)
--============================================================
if not _G.PallWindUI then
    print("[PALL-MH] Loading WindUI...")
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end)
    if ok and result then
        _G.PallWindUI = result
        print("[PALL-MH] WindUI loaded OK.")
    else
        error("[PALL-MH] Gagal load WindUI: " .. tostring(result))
    end
end

--============================================================
-- LOAD MODULE
--============================================================
if config then
    print("═══════════════════════════════════════════")
    print("[PALL-MH] Detected: " .. config.Name)
    print("[PALL-MH] PlaceId : " .. currentPlace)
    print("[PALL-MH] Loading module...")
    print("═══════════════════════════════════════════")

    local okFetch, content = pcall(function()
        return game:HttpGet(config.URL)
    end)

    if not okFetch or not content or content == "" then
        warn("[PALL-MH] Gagal fetch module dari URL. Cek link GitHub kamu!")
    else
        local fn, err = loadstring(content)
        if not fn then
            warn("[PALL-MH] Gagal parse module: " .. tostring(err))
        else
            local okRun, errRun = pcall(fn)
            if not okRun then
                warn("[PALL-MH] Module error: " .. tostring(errRun))
            else
                print("[PALL-MH] Module " .. config.Name .. " loaded successfully.")
            end
        end
    end
else
    -- Game belum di-support
    print("═══════════════════════════════════════════")
    print("[PALL-MH] Game belum di-support.")
    print("[PALL-MH] PlaceId : " .. currentPlace)
    
    pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "PallMH_Notify"
        gui.ResetOnSpawn = false
        gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 320, 0, 110)
        frame.Position = UDim2.new(0.5, -160, 0, 80)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
        frame.BorderSizePixel = 0
        frame.Parent = gui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = frame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 28)
        title.Position = UDim2.new(0, 10, 0, 8)
        title.BackgroundTransparency = 1
        title.Text = "Pall Multi-Hub"
        title.TextColor3 = Color3.fromRGB(255, 200, 60)
        title.TextSize = 16
        title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = frame

        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -20, 0, 60)
        body.Position = UDim2.new(0, 10, 0, 40)
        body.BackgroundTransparency = 1
        body.Text = "Game belum di-support.\nPlaceId: " .. currentPlace
        body.TextColor3 = Color3.fromRGB(200, 200, 210)
        body.TextSize = 12
        body.Font = Enum.Font.Gotham
        body.TextWrapped = true
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.Parent = frame

        task.delay(10, function()
            if gui and gui.Parent then gui:Destroy() end
        end)
    end)
end
