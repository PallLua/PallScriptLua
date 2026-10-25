--[[
	PALL — UNIVERSAL COMBAT (ESP + Aimbot + Silent Aim)
	Version : v1.3.0 (Shared-Visibility + Anti-Force-Close)
--]]

-- Detach instance lama kalau re-execute.
if _G.PallCombat and _G.PallCombat.Cleanup then
	pcall(_G.PallCombat.Cleanup)
end

-- Services.
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local workspaceService = game:GetService("Workspace")

local localPlayer = playersService.LocalPlayer

-- Load WindUI.
local WindUI = _G.PallWindUI
if not WindUI then
	local ok, result = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
	end)
	if not ok then
		return warn("[PALL-UNIV] Gagal load WindUI.")
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
	AimbotShowFOV = true,

	SilentAimEnabled = false,
	SilentAimFOV = 200,
	SilentAimShowFOV = true,
	SilentAimFilter = "shoot,fire,attack,hit,damage,click",

	VisiblePlayers = {},
	CurrentTarget = nil,
	CurrentSilentTarget = nil,
}

-- Drawing containers.
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.Color = WHITE
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Visible = false

local SilentFOVCircle = Drawing.new("Circle")
SilentFOVCircle.Thickness = 1
SilentFOVCircle.Color = YELLOW
SilentFOVCircle.Filled = false
SilentFOVCircle.Transparency = 1
SilentFOVCircle.Visible = false

-- Per-category drawing storage. NEVER reassign this table.
local drawBuckets = {
	Boxes = {},
	Names = {},
	Healths = {},
	Distances = {},
	Tracers = {},
}

---Remove a single player's drawing entries across every bucket.
---@param plr Player
local function removePlayerDrawings(plr)
	for _, bucket in pairs(drawBuckets) do
		local obj = bucket[plr]
		if obj then
			pcall(function()
				obj:Remove()
			end)
			bucket[plr] = nil
		end
	end
end

---Clear every drawing, destroying the objects but keeping the bucket tables alive.
local function clearAllDrawings()
	for _, bucket in pairs(drawBuckets) do
		for key, obj in pairs(bucket) do
			pcall(function()
				obj:Remove()
			end)
			bucket[key] = nil
		end
	end
end

---Lazy-create a drawing object for a player in the given bucket.
---@param bucket table
---@param plr Player
---@param drawType string
---@param configure function
local function ensureDrawing(bucket, plr, drawType, configure)
	if bucket[plr] then
		return bucket[plr]
	end
	local ok, obj = pcall(Drawing.new, drawType)
	if not ok or not obj then
		return nil
	end
	configure(obj)
	bucket[plr] = obj
	return obj
end

---Whether plr should be excluded by the team check.
---@param plr Player
local function isAlly(plr)
	if not State.ESPTeamCheck then
		return false
	end
	if plr.Team and localPlayer.Team and plr.Team == localPlayer.Team then
		return true
	end
	return false
end

---Build the per-frame visibility list used by ESP, Aimbot, and Silent Aim.
local function computeVisiblePlayers()
	local result = {}
	local camera = workspaceService.CurrentCamera
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (camera and hrp) then
		return result
	end

	local viewport = camera.ViewportSize
	local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
	local myPos = hrp.Position
	local maxDist = State.ESPMaxDistance

	for _, plr in ipairs(playersService:GetPlayers()) do
		if plr ~= localPlayer and not isAlly(plr) then
			local targetChar = plr.Character
			if targetChar then
				local root = targetChar:FindFirstChild("HumanoidRootPart")
				local hum = targetChar:FindFirstChild("Humanoid")
				if root and hum and hum.Health > 0 then
					local distance = (myPos - root.Position).Magnitude
					if distance <= maxDist then
						local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
						-- Z > 0 ensures the target is in front of the camera, not mirrored behind.
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

---Pick the entry with the smallest center distance within fovRadius.
---@param list table
---@param fovRadius number
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

---Render ESP from the visible list (already filtered).
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

	-- Track which players currently have a rendered entry this frame.
	local rendered = {}
	for _, entry in ipairs(State.VisiblePlayers) do
		rendered[entry.player] = true
		local plr = entry.player
		local screenPos = entry.screenPos
		local distance = entry.distance
		local hum = entry.humanoid

		local sizeY = math.clamp(1000 / screenPos.Z, 20, 100)
		local sizeX = sizeY / 2

		-- Box.
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

		-- Name.
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

		-- Health.
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

		-- Distance.
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

		-- Tracer.
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

	-- Hide anything rendered last frame but no longer visible this frame.
	for _, bucket in pairs(drawBuckets) do
		for plr, obj in pairs(bucket) do
			if not rendered[plr] then
				pcall(function()
					obj.Visible = false
				end)
			end
		end
	end
end

-- Reusable filter check for silent aim remotes.
local function shouldSilentAim(remoteName)
	local lowered = remoteName:lower()
	for kw in State.SilentAimFilter:gmatch("[^,]+") do
		local trimmed = kw:match("^%s*(.-)%s*$")
		if trimmed ~= "" and lowered:find(trimmed, 1, true) then
			return true
		end
	end
	return false
end

-- Silently rewrite positional args to target CFrame / position / character.
local function rewriteArgsToTarget(args, targetCharacter, targetPart)
	for i, v in pairs(args) do
		local valueType = typeof(v)
		if valueType == "CFrame" and targetPart then
			args[i] = targetPart.CFrame
		elseif valueType == "Vector3" and targetPart then
			args[i] = targetPart.Position
		elseif valueType == "Instance" and v:IsA("Model") and v:FindFirstChild("Humanoid") then
			args[i] = targetCharacter
		end
	end
end

-- Install silent aim namecall hook.
local rawMeta = getrawmetatable(game)
local oldNamecall = rawMeta.__namecall
setreadonly(rawMeta, false)

rawMeta.__namecall = newcclosure(function(self, ...)
	local method = getnamecallmethod()
	if State.SilentAimEnabled and (method == "FireServer" or method == "InvokeServer") then
		local ok, isCombat = pcall(shouldSilentAim, self.Name)
		if ok and isCombat then
			local target = pickClosestInFov(State.VisiblePlayers, State.SilentAimFOV)
			if target then
				local part = target.character:FindFirstChild(State.AimbotTargetPart) or target.root
				local args = { ... }
				rewriteArgsToTarget(args, target.character, part)
				return oldNamecall(self, table.unpack(args))
			end
		end
	end
	return oldNamecall(self, ...)
end)

setreadonly(rawMeta, true)

-- Render loop: single source of truth per frame.
local renderConn = runService.RenderStepped:Connect(function()
	local camera = workspaceService.CurrentCamera
	if not camera then
		return
	end

	-- Refresh visible list once per frame.
	State.VisiblePlayers = computeVisiblePlayers()

	-- ESP render.
	renderESP()

	-- FOV circles.
	local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

	if State.AimbotShowFOV and State.AimbotEnabled then
		FOVCircle.Position = center
		FOVCircle.Radius = State.AimbotFOV
		FOVCircle.Visible = true
	else
		FOVCircle.Visible = false
	end

	if State.SilentAimShowFOV and State.SilentAimEnabled then
		SilentFOVCircle.Position = center
		SilentFOVCircle.Radius = State.SilentAimFOV
		SilentFOVCircle.Visible = true
	else
		SilentFOVCircle.Visible = false
	end

	-- Aimbot: pick from visible list, must be inside aimbot FOV.
	if State.AimbotEnabled then
		local target = pickClosestInFov(State.VisiblePlayers, State.AimbotFOV)
		State.CurrentTarget = target
		if target then
			local part = target.character:FindFirstChild(State.AimbotTargetPart) or target.root
			if part then
				camera.CFrame = camera.CFrame:Lerp(
					CFrame.new(camera.CFrame.Position, part.Position),
					State.AimbotSmooth
				)
			end
		end
	else
		State.CurrentTarget = nil
	end
end)

-- Cleanup listeners for player/character removal.
local playerRemovingConn = playersService.PlayerRemoving:Connect(function(plr)
	removePlayerDrawings(plr)
end)

local charRemovingConns = {}
local function bindCharacterCleanup(plr)
	local conn
	conn = plr.CharacterRemoving:Connect(function()
		removePlayerDrawings(plr)
	end)
	charRemovingConns[plr] = conn
end
for _, plr in ipairs(playersService:GetPlayers()) do
	bindCharacterCleanup(plr)
end
local playerAddedConn = playersService.PlayerAdded:Connect(bindCharacterCleanup)

-- Cleanup registry so re-execution can tear down previous run.
_G.PallCombat = {
	Cleanup = function()
		pcall(function()
			renderConn:Disconnect()
		end)
		pcall(function()
			playerRemovingConn:Disconnect()
		end)
		pcall(function()
			playerAddedConn:Disconnect()
		end)
		for _, conn in pairs(charRemovingConns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		clearAllDrawings()
		pcall(function()
			FOVCircle:Remove()
		end)
		pcall(function()
			SilentFOVCircle:Remove()
		end)
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
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
		Scale = 0.5,
		Color = ColorSequence.new(Color3.fromHex("#FF4F4F"), Color3.fromHex("#FF9F1C")),
	},
	Topbar = { Height = 44, ButtonsType = "Mac" },
})
Window:Tag({ Title = "v1.3.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

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
	s1:Dropdown({ Title = "Target Part", Values = { "Head", "HumanoidRootPart", "Torso" }, Value = "Head", Callback = function(v) State.AimbotTargetPart = v end })

	local s2 = tabAim:Section({ Title = "Silent Aim", Box = true, BoxBorder = true, Opened = true })
	s2:Toggle({ Title = "Aktifkan Silent Aim", Value = false, Callback = function(v) State.SilentAimEnabled = v end })
	s2:Space()
	s2:Slider({ Title = "Silent FOV (Radius)", Step = 10, Value = { Min = 50, Max = 800, Default = 200 }, Callback = function(v) State.SilentAimFOV = v end })
	s2:Space()
	s2:Toggle({ Title = "Tampilkan FOV Silent Aim", Value = true, Callback = function(v) State.SilentAimShowFOV = v end })
	s2:Space()
	s2:Input({ Title = "Remote Filter (koma)", Value = "shoot,fire,attack,hit,damage,click", Callback = function(v) State.SilentAimFilter = v end })
end

WindUI:Notify({ Title = "Pall Combat v1.3.0", Content = "Shared-Visibility + Anti Force-Close", Icon = "solar:bell-bold", Duration = 6 })
print("[PALL-UNIV] v1.3.0 loaded.")
