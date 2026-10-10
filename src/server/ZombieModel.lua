-- Baut einen blockigen R6-Zombie aus Parts (ohne Assets).
local Config = require(game:GetService("ReplicatedStorage").Shared.ZombieConfig)

local ZombieModel = {}

local function makePart(model, name, size, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function weld(root, part, c0)
	local w = Instance.new("Weld")
	w.Part0 = root
	w.Part1 = part
	w.C0 = c0
	w.Parent = part
end

function ZombieModel.new()
	local model = Instance.new("Model")
	model.Name = "Zombie"

	local root = makePart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Config.ShirtColor)
	root.Transparency = 1
	root.CanCollide = true

	local torso = makePart(model, "Torso", Vector3.new(2, 2, 1), Config.ShirtColor)
	local head = makePart(model, "Head", Vector3.new(2, 1, 1), Config.SkinColor)
	local rightArm = makePart(model, "Right Arm", Vector3.new(1, 2, 1), Config.SkinColor)
	local leftArm = makePart(model, "Left Arm", Vector3.new(1, 2, 1), Config.SkinColor)
	local rightLeg = makePart(model, "Right Leg", Vector3.new(1, 2, 1), Config.PantsColor)
	local leftLeg = makePart(model, "Left Leg", Vector3.new(1, 2, 1), Config.PantsColor)

	for _, p in { torso, head, rightArm, leftArm, rightLeg, leftLeg } do
		p.CanCollide = false
	end

	weld(root, torso, CFrame.new())
	weld(root, head, CFrame.new(0, 1.5, 0))
	-- Arme nach vorne gestreckt (Zombie-Pose), Schulter als Drehpunkt
	local armPose = CFrame.Angles(math.pi / 2, 0, 0) * CFrame.new(0, -1, 0)
	weld(root, rightArm, CFrame.new(1.5, 1, 0) * armPose)
	weld(root, leftArm, CFrame.new(-1.5, 1, 0) * armPose)
	weld(root, rightLeg, CFrame.new(0.5, -2, 0))
	weld(root, leftLeg, CFrame.new(-0.5, -2, 0))

	-- Gesicht
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.MaxHealth = Config.Health
	humanoid.Health = Config.Health
	humanoid.WalkSpeed = Config.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

return ZombieModel
