--[[
	PALL — UNIVERSAL COMBAT
	Version : v1.5.2 (Recursion Fix + UI-First)
--]]

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
local ESP_REFRESH_FRAMES = 2
local RAYCAST_MIN_LEN = 10
local RAYCAST_MAX_LEN = 5000

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
	SilentAimFOV = 250,
	SilentAimShowFOV = true,
	SilentAimMode = "Combined (Recommended)",
	SilentAimFilter = "shoot,fire,attack,hit,damage,click,sword,slash,swing,throw,knife,tool",

	VisiblePlayers = {},
	CachedSilentTarget = nil,
	CachedSilentAimPart = nil,
	CachedSilentAimPos = nil,
	FilterArray = {},
}

local SILENT_MODES = {
	"Combined (Recommended)",
	"Raycast Only",
	"Arg Rewrite Only",
	"Mouse Hijack",
	"Character Aim",
}

local function rebuildFilter()
	local out = {}
	for kw in State.SilentAimFilter:gmatch("[^,]+") do
		local trimmed = kw:match("^%s*(.-)%s*$")
		if trimmed ~= "" then
			table.insert(out, trimmed:lower())
		end
	end
	State.FilterArray = out
end
rebuildFilter()

local function modeActive(...)
	for _, m in ipairs({ ... }) do
		if State.SilentAimMode == m then return true end
	end
	return false
end

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

-- Drawing buckets.
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

local function refreshSilentTarget()
	if not State.SilentAimEnabled then
		State.CachedSilentTarget = nil
		State.CachedSilentAimPart = nil
		State.CachedSilentAimPos = nil
		return
	end
	local target = pickClosestInFov(State.VisiblePlayers, State.SilentAimFOV)
	State.CachedSilentTarget = target
	if target then
		local part = target.character:FindFirstChild(State.AimbotTargetPart) or target.root
		State.CachedSilentAimPart = part
		if part then
			State.CachedSilentAimPos = predictPosition(part, State.AimbotPrediction)
		else
			State.CachedSilentAimPos = nil
		end
	else
		State.CachedSilentAimPart = nil
		State.CachedSilentAimPos = nil
	end
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

-- Weak-table cache for remote-name matching.
local remoteMatchCache = setmetatable({}, { __mode = "k" })

local function remoteMatches(remote)
	local cached = remoteMatchCache[remote]
	if cached ~= nil then return cached end
	local ok, name = pcall(function() return remote.Name:lower() end)
	if not ok or not name then
		remoteMatchCache[remote] = false
		return false
	end
	local filters = State.FilterArray
	local matched = false
	for i = 1, #filters do
		if name:find(filters[i], 1, true) then
			matched = true
			break
		end
	end
	remoteMatchCache[remote] = matched
	return matched
end

-- Camera aim.
local function applyCameraAim(target)
	local camera = workspaceService.CurrentCamera
	if not camera then return end
	local part = target.character:FindFirstChild(State.AimbotTargetPart) or target.root
	if not part then return end
	local aimPos = predictPosition(part, State.AimbotPrediction)
	local delta = aimPos - camera.CFrame.Position
	if delta.Magnitude < 0.05 then return end
	pcall(function()
		local goal = CFrame.lookAt(camera.CFrame.Position, aimPos)
		camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(State.AimbotSmooth, 0.01, 1))
	end)
end

local function applyCharacterAim()
	if not (State.SilentAimEnabled and modeActive("Character Aim")) then return end
	local target = State.CachedSilentTarget
	local aimPos = State.CachedSilentAimPos
	if not target or not aimPos then return end
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local flat = Vector3.new(aimPos.X, hrp.Position.Y, aimPos.Z)
	if (flat - hrp.Position).Magnitude < 0.1 then return end
	pcall(function()
		hrp.CFrame = CFrame.lookAt(hrp.Position, flat)
	end)
end

-- Render loop.
local frameCounter = 0
local renderConn = runService.RenderStepped:Connect(function()
	local ok, err = pcall(function()
		local camera = workspaceService.CurrentCamera
		if not camera then return end

		frameCounter = frameCounter + 1
		if frameCounter % ESP_REFRESH_FRAMES == 0 then
			State.VisiblePlayers = computeVisiblePlayers()
			refreshSilentTarget()
		end

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

-- ============================================================
-- UI FIRST (so UI always loads, before any risky hooks).
-- ============================================================
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
Window:Tag({ Title = "v1.5.2", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

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
	s2:Dropdown({ Title = "Mode", Values = SILENT_MODES, Value = "Combined (Recommended)", Callback = function(v) State.SilentAimMode = v end })
	s2:Space()
	s2:Slider({ Title = "Silent FOV (Radius)", Step = 10, Value = { Min = 50, Max = 800, Default = 250 }, Callback = function(v) State.SilentAimFOV = v end })
	s2:Space()
	s2:Toggle({ Title = "Tampilkan FOV Silent Aim", Value = true, Callback = function(v) State.SilentAimShowFOV = v end })
	s2:Space()
	s2:Input({ Title = "Remote Filter (koma)", Value = State.SilentAimFilter, Callback = function(v)
		State.SilentAimFilter = v
		rebuildFilter()
		remoteMatchCache = setmetatable({}, { __mode = "k" })
	end })
end

WindUI:Notify({ Title = "Pall Combat v1.5.2", Content = "UI loaded. Installing hooks...", Icon = "solar:bell-bold", Duration = 4 })

-- ============================================================
-- HOOKS (installed AFTER UI, each wrapped in pcall).
-- ============================================================
local hookStatus = { raycast = false, namecall = false, mouse = false }

-- Raycast hook. CRITICAL: call saved `oldRaycast`, never `workspace.Raycast`.
do
	local ok, err = pcall(function()
		local reentrant = false
		local oldRaycast
		oldRaycast = hookfunction(workspaceService.Raycast, newcclosure(function(self, origin, direction, params, ...)
			-- Guard: original never resolved or already inside -> fall through.
			if reentrant or not oldRaycast then
				return workspaceService.Raycast(self, origin, direction, params, ...)
			end
			if not State.SilentAimEnabled or not modeActive("Combined (Recommended)", "Raycast Only") then
				return oldRaycast(self, origin, direction, params, ...)
			end
			if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
				return oldRaycast(self, origin, direction, params, ...)
			end
			local dirLen = direction.Magnitude
			if dirLen < RAYCAST_MIN_LEN or dirLen > RAYCAST_MAX_LEN then
				return oldRaycast(self, origin, direction, params, ...)
			end
			local aimPos = State.CachedSilentAimPos
			local target = State.CachedSilentTarget
			if not aimPos or not target then
				return oldRaycast(self, origin, direction, params, ...)
			end
			local toTarget = aimPos - origin
			local distToTarget = toTarget.Magnitude
			if distToTarget < 0.1 then
				return oldRaycast(self, origin, direction, params, ...)
			end
			reentrant = true
			local success, result = pcall(function()
				local extendedLen = math.max(dirLen, distToTarget + 10)
				local newDir = toTarget.Unit * extendedLen
				local redirected = oldRaycast(self, origin, newDir, params, ...)
				if redirected and redirected.Instance and redirected.Instance:IsDescendantOf(target.character) then
					return redirected
				end
				return oldRaycast(self, origin, direction, params, ...)
			end)
			reentrant = false
			if success and result ~= nil then
				return result
			end
			return oldRaycast(self, origin, direction, params, ...)
		end))
		hookStatus.raycast = oldRaycast ~= nil
	end)
	if not ok then
		warn("[PALL-UNIV] Raycast hook gagal:", tostring(err))
	end
end

-- Namecall hook.
do
	local ok, err = pcall(function()
		local oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			if not State.SilentAimEnabled or not modeActive("Combined (Recommended)", "Arg Rewrite Only") then
				return oldNamecall(self, ...)
			end
			local method = getnamecallmethod()
			if method ~= "FireServer" and method ~= "InvokeServer" then
				return oldNamecall(self, ...)
			end
			if typeof(self) ~= "Instance" then
				return oldNamecall(self, ...)
			end
			if not remoteMatches(self) then
				return oldNamecall(self, ...)
			end
			local target = State.CachedSilentTarget
			local aimPos = State.CachedSilentAimPos
			if not target or not aimPos then
				return oldNamecall(self, ...)
			end

			local args = { ... }
			local changed = false
			for i = 1, #args do
				local v = args[i]
				local vType = typeof(v)
				if vType == "CFrame" then
					args[i] = CFrame.new(aimPos)
					changed = true
				elseif vType == "Vector3" then
					args[i] = aimPos
					changed = true
				elseif vType == "Instance" then
					if v:IsA("Player") and v ~= localPlayer then
						args[i] = target.player
						changed = true
					elseif v:IsA("Model") and v:FindFirstChild("Humanoid") then
						args[i] = target.character
						changed = true
					elseif v:IsA("BasePart") then
						local sameName = target.character:FindFirstChild(v.Name)
						if sameName and sameName:IsA("BasePart") then
							args[i] = sameName
							changed = true
						end
					end
				elseif vType == "table" then
					for k, inner in pairs(v) do
						local iType = typeof(inner)
						if iType == "Vector3" then
							v[k] = aimPos
							changed = true
						elseif iType == "CFrame" then
							v[k] = CFrame.new(aimPos)
							changed = true
						end
					end
				end
			end
			if not changed then
				return oldNamecall(self, ...)
			end
			return oldNamecall(self, table.unpack(args))
		end))
		hookStatus.namecall = oldNamecall ~= nil
	end)
	if not ok then
		warn("[PALL-UNIV] Namecall hook gagal:", tostring(err))
	end
end

-- Mouse hijack fallback.
do
	local ok, err = pcall(function()
		local mouse = localPlayer:GetMouse()
		local oldIndex = hookmetamethod(mouse, "__index", newcclosure(function(self, key)
			if State.SilentAimEnabled and modeActive("Mouse Hijack") then
				local aimPos = State.CachedSilentAimPos
				local aimPart = State.CachedSilentAimPart
				if aimPos and aimPart then
					if key == "Hit" then
						return CFrame.new(aimPos)
					elseif key == "Target" then
						return aimPart
					end
				end
			end
			return oldIndex(self, key)
		end))
		hookStatus.mouse = oldIndex ~= nil
	end)
	if not ok then
		warn("[PALL-UNIV] Mouse hijack gagal:", tostring(err))
	end
end

-- Cleanup registry.
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

WindUI:Notify({
	Title = "Hooks Installed",
	Content = string.format("Raycast:%s Namecall:%s Mouse:%s",
		tostring(hookStatus.raycast), tostring(hookStatus.namecall), tostring(hookStatus.mouse)),
	Icon = "solar:check-circle-bold",
	Duration = 6,
})
print("[PALL-UNIV] v1.5.2 loaded.", "Raycast:", hookStatus.raycast, "Namecall:", hookStatus.namecall, "Mouse:", hookStatus.mouse)
