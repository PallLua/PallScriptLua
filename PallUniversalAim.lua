--[[
	PALL — UNIVERSAL COMBAT
	Version : v1.4.0 (MM2-Compat Silent Aim + Crash Fixes)
--]]

-- Detach previous run.
if _G.PallCombat and _G.PallCombat.Cleanup then
	pcall(_G.PallCombat.Cleanup)
end

-- Services.
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local workspaceService = game:GetService("Workspace")

local localPlayer = playersService.LocalPlayer

-- Load WindUI.
local WindUI = _G.PallWindUI
if not WindUI then
	local ok, result = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
	end)
	if not ok then
		return warn("[PALL-UNIV] Gagal load WindUI:", tostring(result))
	end
	WindUI = _G.PallWindUI or result
end

-- Constants.
local GREEN = Color3.fromHex("#10C550")
local RED = Color3.fromHex("#EF4F1D")
local WHITE = Color3.fromRGB(255, 255, 255)
local YELLOW = Color3.fromRGB(255, 200, 60)

-- State.
local State = {
	ESPEnabled = false,
	ESPBox = true,
	ESPName = true,
	ESPHealth = true,
	ESPDistance = true,
	ESPTracer = false,
	ESPTeamCheck = true,
	ESPMaxDistance = 1000,

	AimbotEnabled = false,
	AimbotFOV = 150,
	AimbotSmooth = 0.15,
	AimbotTargetPart = "Head",
	AimbotPrediction = 0,
	AimbotShowFOV = true,

	SilentAimEnabled = false,
	SilentAimFOV = 200,
	SilentAimShowFOV = true,
	SilentAimMode = "Mouse Hijack",

	VisiblePlayers = {},
}

-- FOV circles.
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.Color = WHITE
fovCircle.Filled = false
fovCircle.Transparency = 1
fovCircle.Visible = false

local silentFovCircle = Drawing.new("Circle")
silentFovCircle.Thickness = 1
silentFovCircle.Color = YELLOW
silentFovCircle.Filled = false
silentFovCircle.Transparency = 1
silentFovCircle.Visible = false

-- Draw buckets, never reassigned.
local drawBuckets = { Boxes = {}, Names = {}, Healths = {}, Distances = {}, Tracers = {} }

local function removePlayerDrawings(plr)
	for _, bucket in pairs(drawBuckets) do
		local obj = bucket[plr]
		if obj then
			pcall(function() obj:Remove() end)
			bucket[plr] = nil
		end
	end
end

local function clearAllDrawings()
	for _, bucket in pairs(drawBuckets) do
		for key, obj in pairs(bucket) do
			pcall(function() obj:Remove() end)
			bucket[key] = nil
		end
	end
end

local function ensureDrawing(bucket, plr, drawType, configure)
	if bucket[plr] then return bucket[plr] end
	local ok, obj = pcall(Drawing.new, drawType)
	if not ok or not obj then return nil end
	configure(obj)
	bucket[plr] = obj
	return obj
end

local function isAlly(plr)
	if not State.ESPTeamCheck then return false end
	if plr.Team and localPlayer.Team and plr.Team == localPlayer.Team then return true end
	return false
end

local function computeVisiblePlayers()
	local result = {}
	local camera = workspaceService.CurrentCamera
	if not camera then return result end
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return result end

	local viewport = camera.ViewportSize
	local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
	local myPos = hrp.Position

	for _, plr in ipairs(playersService:GetPlayers()) do
		if plr ~= localPlayer and not isAlly(plr) then
			local targetChar = plr.Character
			if targetChar then
				local root = targetChar:FindFirstChild("HumanoidRootPart")
				local hum = targetChar:FindFirstChild("Humanoid")
				if root and hum and hum.Health > 0 then
					local distance = (myPos - root.Position).Magnitude
					if distance <= State.ESPMaxDistance then
						local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
						if onScreen and screenPos.Z > 0 then
							local screenVec = Vector2.new(screenPos.X, screenPos.Y)
							table.insert(result, {
								player = plr,
								character = targetChar,
								root = root,
								humanoid = hum,
								distance = distance,
								screenPos = screenPos,
								screenVec = screenVec,
								centerDist = (screenVec - center).Magnitude,
							})
						end
					end
				end
			end
		end
	end
	return result
end

local function pickClosestInFov(list, fovRadius)
	local closest, best = nil, fovRadius
	for _, entry in ipairs(list) do
		if entry.centerDist < best then
			best = entry.centerDist
			closest = entry
		end
	end
	return closest
end

local function predictPosition(part, predictionTime)
	if predictionTime <= 0 then return part.Position end
	local ok, velocity = pcall(function() return part.AssemblyLinearVelocity end)
	if not ok or not velocity then return part.Position end
	return part.Position + velocity * predictionTime
end

local function renderESP()
	if not State.ESPEnabled then
		clearAllDrawings()
		return
	end
	local camera = workspaceService.CurrentCamera
	if not camera then
		clearAllDrawings()
		return
	end
	local rendered = {}
	for _, entry in ipairs(State.VisiblePlayers) do
		rendered[entry.player] = true
		local plr = entry.player
		local screenPos = entry.screenPos
		local distance = entry.distance
		local hum = entry.humanoid
		local sizeY = math.clamp(1000 / screenPos.Z, 20, 100)
		local sizeX = sizeY / 2

		if State.ESPBox then
			local box = ensureDrawing(drawBuckets.Boxes, plr, "Square", function(o)
				o.Thickness = 1
				o.Color = RED
				o.Filled = false
			end)
			if box then
				box.Size = Vector2.new(sizeX, sizeY)
				box.Position = Vector2.new(screenPos.X - sizeX / 2, screenPos.Y - sizeY / 2)
				box.Visible = true
			end
		end

		if State.ESPName then
			local name = ensureDrawing(drawBuckets.Names, plr, "Text", function(o)
				o.Size = 16
				o.Center = true
				o.Outline = true
				o.Color = WHITE
			end)
			if name then
				name.Text = plr.Name
				name.Position = Vector2.new(screenPos.X, screenPos.Y - sizeY / 2 - 15)
				name.Visible = true
			end
		end

		if State.ESPHealth then
			local hp = ensureDrawing(drawBuckets.Healths, plr, "Text", function(o)
				o.Size = 14
				o.Center = true
				o.Outline = true
				o.Color = GREEN
			end)
			if hp then
				hp.Text = math.floor(hum.Health) .. " HP"
				hp.Position = Vector2.new(screenPos.X, screenPos.Y + sizeY / 2 + 5)
				hp.Visible = true
			end
		end

		if State.ESPDistance then
			local dist = ensureDrawing(drawBuckets.Distances, plr, "Text", function(o)
				o.Size = 12
				o.Center = true
				o.Outline = true
				o.Color = Color3.new(0.8, 0.8, 0.8)
			end)
			if dist then
				dist.Text = "[" .. math.floor(distance) .. "m]"
				dist.Position = Vector2.new(screenPos.X, screenPos.Y + sizeY / 2 + 20)
				dist.Visible = true
			end
		end

		if State.ESPTracer then
			local tracer = ensureDrawing(drawBuckets.Tracers, plr, "Line", function(o)
				o.Thickness = 1
				o.Color = RED
			end)
			if tracer then
				tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
				tracer.To = Vector2.new(screenPos.X, screenPos.Y)
				tracer.Visible = true
			end
		end
	end
	for _, bucket in pairs(drawBuckets) do
		for plr, obj in pairs(bucket) do
			if not rendered[plr] then
				pcall(function() obj.Visible = false end)
			end
		end
	end
end

-- Camera aim: safe lerp with optional prediction.
local function applyCameraAim(target)
	local camera = workspaceService.CurrentCamera
	if not camera then return end
	local part = target.character:FindFirstChild(State.AimbotTargetPart) or target.root
	if not part then return end
	local targetPos = predictPosition(part, State.AimbotPrediction)
	local delta = targetPos - camera.CFrame.Position
	if delta.Magnitude < 0.05 then return end
	pcall(function()
		local goal = CFrame.lookAt(camera.CFrame.Position, targetPos)
		camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(State.AimbotSmooth, 0.01, 1))
	end)
end

-- Silent Aim - Mouse Hijack (primary, MM2-compatible).
local mouse = localPlayer:GetMouse()
local mouseHookInstalled = false

local function installMouseSilentAim()
	if mouseHookInstalled then return end
	local ok, err = pcall(function()
		hookmetamethod(mouse, "__index", function(self, key)
			if State.SilentAimEnabled and State.SilentAimMode == "Mouse Hijack" then
				local target = pickClosestInFov(State.VisiblePlayers, State.SilentAimFOV)
				if target then
					local part = target.character:FindFirstChild(State.AimbotTargetPart) or target.root
					if part then
						if key == "Hit" then
							return CFrame.new(part.Position)
						elseif key == "Target" then
							return part
						end
					end
				end
			end
			return getrawmetatable(mouse).__index(self, key)
		end)
	end)
	if ok then
		mouseHookInstalled = true
	else
		warn("[PALL-UNIV] Mouse hijack gagal:", tostring(err))
	end
end

-- Silent Aim - Character Aim (fallback, aggressive).
local function applyCharacterAim()
	if not (State.SilentAimEnabled and State.SilentAimMode == "Character Aim") then
		return
	end
	local target = pickClosestInFov(State.VisiblePlayers, State.SilentAimFOV)
	if not target then return end
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local part = target.character:FindFirstChild(State.AimbotTargetPart) or target.root
	if not part then return end
	local oldCF = hrp.CFrame
	local lookTarget = Vector3.new(part.Position.X, oldCF.Position.Y, part.Position.Z)
	if (lookTarget - oldCF.Position).Magnitude < 0.1 then return end
	pcall(function()
		hrp.CFrame = CFrame.lookAt(oldCF.Position, lookTarget)
	end)
end

-- Render loop (pcall-guarded).
local renderConn = runService.RenderStepped:Connect(function()
	local ok, err = pcall(function()
		local camera = workspaceService.CurrentCamera
		if not camera then return end

		State.VisiblePlayers = computeVisiblePlayers()
		renderESP()

		local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

		if State.AimbotShowFOV and State.AimbotEnabled then
			fovCircle.Position = center
			fovCircle.Radius = State.AimbotFOV
			fovCircle.Visible = true
		else
			fovCircle.Visible = false
		end

		if State.SilentAimShowFOV and State.SilentAimEnabled then
			silentFovCircle.Position = center
			silentFovCircle.Radius = State.SilentAimFOV
			silentFovCircle.Visible = true
		else
			silentFovCircle.Visible = false
		end

		if State.AimbotEnabled then
			local target = pickClosestInFov(State.VisiblePlayers, State.AimbotFOV)
			if target then
				applyCameraAim(target)
			end
		end

		applyCharacterAim()
	end)
	if not ok then
		warn("[PALL-UNIV] render:", tostring(err))
	end
end)

-- Cleanup.
local function bindPlayerCleanup(plr)
	plr.CharacterRemoving:Connect(function() removePlayerDrawings(plr) end)
end
for _, plr in ipairs(playersService:GetPlayers()) do
	bindPlayerCleanup(plr)
end
local playerAddedConn = playersService.PlayerAdded:Connect(bindPlayerCleanup)
local playerRemovingConn = playersService.PlayerRemoving:Connect(function(plr) removePlayerDrawings(plr) end)

_G.PallCombat = {
	Cleanup = function()
		pcall(function() renderConn:Disconnect() end)
		pcall(function() playerAddedConn:Disconnect() end)
		pcall(function() playerRemovingConn:Disconnect() end)
		clearAllDrawings()
		pcall(function() fovCircle:Remove() end)
		pcall(function() silentFovCircle:Remove() end)
	end,
}

-- UI.
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
Window:Tag({ Title = "v1.4.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

local tabESP = Window:Tab({ Title = "ESP", Desc = "Visual Player", Icon = "solar:eye-bold", IconColor = GREEN, IconShape = "Square", Border = true })
do
	local s = tabESP:Section({ Title = "ESP Settings", Box = true, BoxBorder = true, Opened = true })
	s:Toggle({ Title = "Aktifkan ESP", Value = false, Callback = function(v) State.ESPEnabled = v end })
	s:Space()
	s:Slider({ Title = "Jarak Maksimal ESP (m)", Step = 100, Value = { Min = 100, Max = 2000, Default = 1000 }, Callback = function(v) State.ESPMaxDistance = v end })
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

local tabAim = Window:Tab({ Title = "Aimbot", Desc = "Auto Target", Icon = "solar:crosshair-bold", IconColor = RED, IconShape = "Square", Border = true })
do
	local s1 = tabAim:Section({ Title = "Aimbot Settings", Box = true, BoxBorder = true, Opened = true })
	s1:Toggle({ Title = "Aktifkan Aimbot", Value = false, Callback = function(v) State.AimbotEnabled = v end })
	s1:Space()
	s1:Slider({ Title = "FOV (Radius)", Step = 10, Value = { Min = 50, Max = 500, Default = 150 }, Callback = function(v) State.AimbotFOV = v end })
	s1:Space()
	s1:Toggle({ Title = "Tampilkan FOV Aimbot", Value = true, Callback = function(v) State.AimbotShowFOV = v end })
	s1:Space()
	s1:Slider({ Title = "Smoothness", Step = 0.05, Value = { Min = 0.05, Max = 1, Default = 0.15 }, Callback = function(v) State.AimbotSmooth = v end })
	s1:Space()
	s1:Slider({ Title = "Prediction (Lead Shot)", Step = 0.01, Value = { Min = 0, Max = 0.5, Default = 0 }, Callback = function(v) State.AimbotPrediction = v end })
	s1:Space()
	s1:Dropdown({ Title = "Target Part", Values = { "Head", "HumanoidRootPart", "Torso" }, Value = "Head", Callback = function(v) State.AimbotTargetPart = v end })

	local s2 = tabAim:Section({ Title = "Silent Aim", Box = true, BoxBorder = true, Opened = true })
	s2:Toggle({ Title = "Aktifkan Silent Aim", Value = false, Callback = function(v) State.SilentAimEnabled = v end })
	s2:Space()
	s2:Dropdown({ Title = "Mode", Values = { "Mouse Hijack", "Character Aim" }, Value = "Mouse Hijack", Callback = function(v) State.SilentAimMode = v end })
	s2:Space()
	s2:Slider({ Title = "Silent FOV (Radius)", Step = 10, Value = { Min = 50, Max = 800, Default = 200 }, Callback = function(v) State.SilentAimFOV = v end })
	s2:Space()
	s2:Toggle({ Title = "Tampilkan FOV Silent Aim", Value = true, Callback = function(v) State.SilentAimShowFOV = v end })
end

WindUI:Notify({ Title = "Pall Combat v1.4.0", Content = "MM2-Compat + Crash Fixes", Icon = "solar:bell-bold", Duration = 6 })
print("[PALL-UNIV] v1.4.0 loaded.")
