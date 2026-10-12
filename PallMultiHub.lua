--[[
    ═══════════════════════════════════════════════════════════
    PALL MULTI-HUB — Router
    Author  : ENI (for Pall)
    Version : v1.0.0
    Fungsi  : Deteksi game via PlaceId, lalu load modul yang sesuai.
    Cara pakai:
      - Execute file ini di game apa pun
      - Otomatis load script game yang sesuai
      - Kalau game belum di-support, muncul notif + PlaceId-nya
    ═══════════════════════════════════════════════════════════
--]]

--============================================================
-- KONFIGURASI GAME
-- Ganti/tambah entry kalau mau support game baru.
-- PlaceId bisa dilihat dengan print(game.PlaceId) di game tsb.
--============================================================
local GAMES = {
    -- Dungeon Quest Reborn (ganti PlaceId kalau salah)
    [77649408247578] = {
        Name = "Dungeon Quest Reborn",
        URL  = "https://raw.githubusercontent.com/PallLua/PallScriptLua/refs/heads/main/PallDQR.lua",
        Folder = "pallhubv610",
    },

-- Steal an Egg
[107778070777162] = {
    Name = "Steal an Egg",
    URL  = "https://raw.githubusercontent.com/PallLua/PallScriptLua/refs/heads/main/PallStealEgg.lua",
    Folder = "pallse",
},

--============================================================
-- DETEKSI GAME
--============================================================
local currentPlace = game.PlaceId
local currentGameId = game.GameId
local config = GAMES[currentPlace]

-- Kalau PlaceId nggak match, coba cek GameId (buat game yang punya banyak place)
if not config then
    for _, entry in pairs(GAMES) do
        if entry.GameId and entry.GameId == currentGameId then
            config = entry
            break
        end
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
        warn("[PALL-MH] Gagal fetch module dari URL.")
        warn("[PALL-MH] URL: " .. config.URL)
        -- Notif kalau ada WindUI yang udah loaded
        pcall(function()
            if _G.PallHubNotify then
                _G.PallHubNotify("Load Error", "Gagal fetch " .. config.Name)
            end
        end)
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
    print("[PALL-MH] GameId  : " .. currentGameId)
    print("[PALL-MH] Tambahkan PlaceId di atas ke tabel GAMES untuk support.")
    print("═══════════════════════════════════════════")

    -- Coba tampilin notif sederhana via ScreenGui
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
        body.Text = "Game belum di-support.\nPlaceId: " .. currentPlace .. "\nTambah ke tabel GAMES untuk support."
        body.TextColor3 = Color3.fromRGB(200, 200, 210)
        body.TextSize = 12
        body.Font = Enum.Font.Gotham
        body.TextWrapped = true
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.Parent = frame

        -- Auto close 10 detik
        task.delay(10, function()
            if gui and gui.Parent then gui:Destroy() end
        end)
    end)
end
