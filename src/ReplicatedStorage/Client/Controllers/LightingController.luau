--!strict
-- Compositor único do pós artístico/exposição/névoa. Filtros equipáveis usam outra camada.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Profile = require("@game/ReplicatedStorage/Shared/Game/LightingProfile")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Settings = require("./SettingsController")

local player = Players.LocalPlayer
local grade: ColorCorrectionEffect? = nil
local filter: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil
local depth: DepthOfFieldEffect? = nil
local indoor = 0
local power = 0
local danger = 0
local fog = Profile.World.fogEnd
local baseFog = Profile.World.fogEnd
local insideTarget = false
local rayClock = 1
local elapsed = 0
local treatment = 1
local forest = 0
local controller = { Name = "LightingController" }

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

function controller.setDanger(value: number)
	danger = math.clamp(value, 0, 1)
end

function controller.setFilter(item: StoreCatalog.Item)
	local fx = filter
	if not fx then
		return
	end
	local neutral = item.id == StoreCatalog.defaultFor("filter")
	fx.TintColor = if neutral or not item.tint then Color3.new(1, 1, 1) else rgb(item.tint)
	fx.Contrast = if neutral then 0 else item.contrast or 0
	fx.Saturation = if neutral then 0 else item.saturation or 0
	fx.Brightness = if neutral then 0 else item.brightness or 0
end

local function underRoof(position: Vector3): boolean
	local world = workspace:FindFirstChild(Tags.WorldFolder)
	if not world then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position, Vector3.new(0, 18, 0), params)
	return hit ~= nil and hit.Instance.CanCollide
end

function controller.debugState(): { [string]: any }
	return {
		indoor = indoor,
		power = power,
		danger = danger,
		fog = Lighting.FogEnd,
		baseFog = baseFog,
		exposure = Lighting.ExposureCompensation,
		shadows = Lighting.GlobalShadows,
		style = Lighting.LightingStyle.Name,
		bloom = bloom and bloom.Intensity,
		depth = depth and depth.FarIntensity,
		contrast = grade and grade.Contrast,
		quality = Settings.visualBudget().name,
		shaders = Settings.shadersEnabled(),
		forest = forest,
	}
end

function controller.Init()
	Lighting.ClockTime = Profile.World.clock
	local scene = Instance.new("ColorCorrectionEffect")
	scene.Name = "S9SceneGrade"
	scene.Parent = Lighting
	grade = scene
	local cosmetic = Instance.new("ColorCorrectionEffect")
	cosmetic.Name = "RetroGrade"
	cosmetic.Parent = Lighting
	filter = cosmetic
	local glow = Instance.new("BloomEffect")
	glow.Name = "RetroBloom"
	glow.Intensity = Profile.Bloom.intensity
	glow.Size = Profile.Bloom.size
	glow.Threshold = Profile.Bloom.threshold
	glow.Parent = Lighting
	bloom = glow
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "S9CinemaDepth"
	dof.FocusDistance = 55
	dof.InFocusRadius = 45
	dof.NearIntensity = 0
	dof.FarIntensity = 0
	dof.Enabled = false
	dof.Parent = Lighting
	depth = dof
end

function controller.Start()
	local function syncBase()
		local value = Lighting:GetAttribute("BaseFogEnd")
		if type(value) == "number" then
			baseFog = value
		end
	end
	syncBase()
	fog = baseFog
	power = if Lighting:GetAttribute("S9PowerOn") == true then 1 else 0
	Lighting:GetAttributeChangedSignal("BaseFogEnd"):Connect(syncBase)
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		rayClock += dt
		if elapsed < 1 / 20 then
			return
		end
		local delta = elapsed
		elapsed = 0
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if rayClock >= 0.35 then
			rayClock = 0
			insideTarget = underRoof(camera.CFrame.Position)
		end
		indoor = Profile.approach(indoor, if insideTarget then 1 else 0, delta)
		power = Profile.approach(power, if Lighting:GetAttribute("S9PowerOn") == true then 1 else 0, delta)
		local world = workspace:FindFirstChild(Tags.WorldFolder)
		forest = Profile.approach(forest, if world and world:GetAttribute("ForestActive") == true then 1 else 0, delta)
		-- A mesma composição governa luz funcional e profundidade, inclusive com Shaders OFF.
		Lighting.Ambient = rgb(Profile.ambient(indoor, power, forest))
		Lighting.OutdoorAmbient = rgb(Profile.World.outdoor):Lerp(rgb(Profile.Forest.outdoor), forest)
		Lighting.FogColor =
			rgb(Profile.World.fog):Lerp(rgb(Profile.World.fogPower), power):Lerp(rgb(Profile.Forest.fog), forest)
		Lighting.FogStart = Profile.World.fogStart + (Profile.Forest.fogStart - Profile.World.fogStart) * forest
		local values = Profile.grade(indoor, power)
		local budget = Settings.visualBudget()
		treatment = Profile.approach(treatment, if Settings.shadersEnabled() then 1 else 0, delta)
		if grade then
			grade.TintColor = Color3.new(1, 1, 1):Lerp(rgb(values.tint), treatment)
			grade.Contrast = values.contrast * treatment
			grade.Saturation = values.saturation * treatment
			grade.Brightness = values.brightness * treatment
		end
		if bloom then
			bloom.Intensity = Profile.approach(bloom.Intensity, budget.bloom, delta)
			bloom.Enabled = bloom.Intensity > 0.001
		end
		if filter then
			filter.Enabled = Settings.shadersEnabled()
		end
		Lighting.ExposureCompensation = Profile.exposure(indoor, power) + forest * Profile.Forest.exposure
		fog =
			Profile.approach(fog, Profile.fogEnd(baseFog * (1 + (Profile.Forest.fogScale - 1) * forest), danger), delta)
		Lighting.FogEnd = fog
		local cinema = budget.depth and player:GetAttribute("CinematicActive") == true and Settings.motionEnabled()
		if depth then
			depth.Enabled = cinema
			depth.FarIntensity = if cinema then 0.07 else 0
		end
	end)
	if RunService:IsStudio() then
		-- Sonda na VM real: comparação de câmeras sem editar scripts sincronizados no Studio.
		local gui = Instance.new("ScreenGui")
		gui.Name = "LightingQA"
		gui.ResetOnSpawn = false
		gui.Enabled = false
		gui.Parent = player:WaitForChild("PlayerGui")
		local bridge = Instance.new("BindableFunction")
		bridge.Name = "Probe"
		local eye: Vector3? = nil
		local look = Vector3.zero
		local prior: { [ScreenGui]: boolean } = {}
		local priorCamera: { camera: Camera, kind: Enum.CameraType, cf: CFrame, focus: CFrame, fov: number }? = nil
		bridge.OnInvoke = function(command: string, position: Vector3?, target: Vector3?): any
			if command == "camera" and position and target then
				local camera = workspace.CurrentCamera
				if not eye and camera then
					priorCamera = {
						camera = camera,
						kind = camera.CameraType,
						cf = camera.CFrame,
						focus = camera.Focus,
						fov = camera.FieldOfView,
					}
				end
				eye, look = position, target
				player:SetAttribute("ModeMenuOpen", false)
				local cinema = player.PlayerGui:FindFirstChild("AnimationDebugBridge", true)
				if cinema and cinema:IsA("BindableFunction") then
					cinema:Invoke("skip")
				end
			elseif command == "release" then
				eye = nil
				local saved = priorCamera
				if saved and saved.camera.Parent then
					saved.camera.CameraType = saved.kind
					saved.camera.CFrame = saved.cf
					saved.camera.Focus = saved.focus
					saved.camera.FieldOfView = saved.fov
				end
				priorCamera = nil
				for ui, enabled in prior do
					if ui.Parent then
						ui.Enabled = enabled
					end
				end
				prior = {}
			end
			local state = controller.debugState()
			state.audio = require("./AudioController").debugState()
			state.fixtures = require("./WorldFxController").debugState()
			return state
		end
		bridge.Parent = gui
		RunService:BindToRenderStep("S9LightingQA", Enum.RenderPriority.Last.Value + 5, function()
			local camera = workspace.CurrentCamera
			if not eye or not camera then
				return
			end
			player:SetAttribute("ModeMenuOpen", false)
			for _, ui in player.PlayerGui:GetChildren() do
				if ui:IsA("ScreenGui") and ui ~= gui then
					if prior[ui] == nil then
						prior[ui] = ui.Enabled
					end
					ui.Enabled = false
				end
			end
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(eye, look)
			camera.Focus = CFrame.new(look)
			camera.FieldOfView = 65
		end)
	end
end
return controller
