local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.ZombieConfig)
local ZombieModel = require(script.Parent.ZombieModel)

local zombies = {}

local function nearestPlayer(position)
	local best, bestDist
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 then
			local dist = (hrp.Position - position).Magnitude
			if not bestDist or dist < bestDist then
				best, bestDist = hrp, dist
			end
		end
	end
	return best, bestDist
end

local function spawnZombie()
	local zombie = ZombieModel.new()
	local angle = math.random() * math.pi * 2
	local pos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.SpawnRadius
	zombie:PivotTo(CFrame.new(pos + Vector3.new(0, 5, 0)))
	zombie.Parent = workspace
	zombie.PrimaryPart:SetNetworkOwner(nil)

	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	local lastAttack = 0
	zombies[zombie] = true

	humanoid.Died:Connect(function()
		zombies[zombie] = nil
		Debris:AddItem(zombie, 3)
	end)

	task.spawn(function()
		while zombie.Parent and humanoid.Health > 0 do
			local target, dist = nearestPlayer(zombie.PrimaryPart.Position)
			if target then
				humanoid:MoveTo(target.Position)
				if dist <= Config.AttackRange and os.clock() - lastAttack >= Config.AttackCooldown then
					lastAttack = os.clock()
					target.Parent:FindFirstChildOfClass("Humanoid"):TakeDamage(Config.AttackDamage)
				end
			end
			task.wait(0.25)
		end
	end)
end

task.spawn(function()
	while true do
		local count = 0
		for _ in zombies do
			count += 1
		end
		if count < Config.MaxZombies and #Players:GetPlayers() > 0 then
			spawnZombie()
		end
		task.wait(Config.SpawnInterval)
	end
end)
