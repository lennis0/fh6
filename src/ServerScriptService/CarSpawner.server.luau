--[[
	CarSpawner  –  runs on the server.
	Builds a car model from Parts for each player when their character spawns,
	gives them network ownership so the client can drive it smoothly,
	then destroys the car when the character is removed.
]]

local Players = game:GetService("Players")

local SPAWN_OFFSET = Vector3.new(0, 5, -14) -- offset from player HRP when car appears

-- ──────────────────────────────────────────────────────────────────────────────
-- Car builder
-- ──────────────────────────────────────────────────────────────────────────────

local function weld(parent: BasePart, child: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = child
	w.Parent = parent
end

local function buildCar(position: Vector3): Model
	local car = Instance.new("Model")
	car.Name = "PlayerCar" -- renamed to owner name after build

	-- Chassis: the one collidable physics part --------------------------------
	local chassis = Instance.new("Part")
	chassis.Name        = "Chassis"
	chassis.Size        = Vector3.new(7, 1.2, 14)
	chassis.CFrame      = CFrame.new(position)
	chassis.BrickColor  = BrickColor.new("Bright red")
	chassis.Material    = Enum.Material.SmoothPlastic
	-- Low friction so the car doesn't grip sideways (we control velocity directly)
	chassis.CustomPhysicalProperties = PhysicalProperties.new(
		2,    -- density  (heavier = more stable, less bouncy)
		0.5,  -- friction (grip with ground, helps prevent spinning out)
		0.0,  -- elasticity
		0,    -- frictionWeight
		0     -- elasticityWeight
	)
	chassis.Parent = car
	car.PrimaryPart = chassis

	-- Car body (visual hull, no collision) ------------------------------------
	local body = Instance.new("Part")
	body.Name        = "Body"
	body.Size        = Vector3.new(6.5, 1.6, 9)
	body.CFrame      = CFrame.new(position + Vector3.new(0, 1.4, 0.5))
	body.BrickColor  = BrickColor.new("Bright red")
	body.Material    = Enum.Material.SmoothPlastic
	body.CanCollide  = false
	body.Parent = car
	weld(chassis, body)

	-- Roof --------------------------------------------------------------------
	local roof = Instance.new("Part")
	roof.Name        = "Roof"
	roof.Size        = Vector3.new(6, 0.4, 5)
	roof.CFrame      = CFrame.new(position + Vector3.new(0, 3.2, -0.2))
	roof.BrickColor  = BrickColor.new("Bright red")
	roof.Material    = Enum.Material.SmoothPlastic
	roof.CanCollide  = false
	roof.Parent = car
	weld(chassis, roof)

	-- Windshield --------------------------------------------------------------
	local windshield = Instance.new("Part")
	windshield.Name         = "Windshield"
	windshield.Size         = Vector3.new(5.5, 2, 0.3)
	windshield.CFrame       = CFrame.new(position + Vector3.new(0, 2.4, 2.8))
		* CFrame.Angles(math.rad(-15), 0, 0)
	windshield.BrickColor   = BrickColor.new("Light blue")
	windshield.Material     = Enum.Material.Glass
	windshield.Transparency = 0.5
	windshield.CanCollide   = false
	windshield.Parent = car
	weld(chassis, windshield)

	-- VehicleSeat (invisible – just for player attachment) --------------------
	local seat = Instance.new("VehicleSeat")
	seat.Name            = "Seat"
	seat.Size            = Vector3.new(2, 0.5, 2)
	seat.CFrame          = CFrame.new(position + Vector3.new(-1, 1.5, 1.5))
	seat.Transparency    = 1
	seat.MaxSpeed        = 0  -- we control speed in the client script
	seat.TurnSpeed       = 0  -- we control turning in the client script
	seat.HeadsUpDisplay  = false
	seat.CanCollide      = false
	seat.Parent = car
	weld(chassis, seat)

	-- Wheels (visual cylinders, no collision – chassis handles ground) --------
	local wheelDefs = {
		{ name = "WheelFL", offset = Vector3.new(-3.7, -0.6,  5) },
		{ name = "WheelFR", offset = Vector3.new( 3.7, -0.6,  5) },
		{ name = "WheelRL", offset = Vector3.new(-3.7, -0.6, -5) },
		{ name = "WheelRR", offset = Vector3.new( 3.7, -0.6, -5) },
	}
	for _, def in wheelDefs do
		local wheel = Instance.new("Part")
		wheel.Name       = def.name
		wheel.Shape      = Enum.PartType.Cylinder
		wheel.Size       = Vector3.new(1.2, 2.4, 2.4)
		-- Rotate 90° so the cylinder rolls in the forward direction
		wheel.CFrame     = CFrame.new(position + def.offset)
			* CFrame.Angles(0, 0, math.rad(90))
		wheel.BrickColor = BrickColor.new("Really black")
		wheel.Material   = Enum.Material.SmoothPlastic
		wheel.CanCollide = false
		wheel.Parent = car
		weld(chassis, wheel)
	end

	-- Physics movers (created on the server, driven by the client) -----------

	-- Forward / backward velocity
	local bv = Instance.new("BodyVelocity")
	bv.Name     = "CarVelocity"
	bv.Velocity  = Vector3.zero
	bv.MaxForce  = Vector3.new(1e6, 0, 1e6) -- no Y force; gravity still applies
	bv.P         = 1e5
	bv.Parent = chassis

	-- Turning (Y-axis rotation only)
	local bav = Instance.new("BodyAngularVelocity")
	bav.Name            = "CarAngularVelocity"
	bav.AngularVelocity = Vector3.zero
	bav.MaxTorque       = Vector3.new(0, 1e6, 0) -- Y only; gyro handles X/Z
	bav.P               = 1e5
	bav.Parent = chassis

	-- Gyro: keeps the car upright (corrects pitch/roll, ignores yaw)
	local bg = Instance.new("BodyGyro")
	bg.Name      = "CarGyro"
	bg.MaxTorque = Vector3.new(4e5, 0, 4e5) -- X and Z only; leaves Y free
	bg.D         = 800
	bg.P         = 4000
	bg.CFrame    = CFrame.new(position)
	bg.Parent = chassis

	return car
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Per-player spawning
-- ──────────────────────────────────────────────────────────────────────────────

local function spawnCarForPlayer(player: Player, character: Model)
	local hrp      = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not hrp or not humanoid then return end

	task.wait(0.5) -- let the character settle on the ground

	-- Build and place the car in the world
	local spawnPos = hrp.Position + SPAWN_OFFSET
	local car      = buildCar(spawnPos)
	car.Name       = player.Name .. "_Car"
	car.Parent     = workspace

	-- Let the client drive physics directly (required for smooth BodyVelocity)
	car.Chassis:SetNetworkOwner(player)

	-- Seat the player
	seat = car:FindFirstChild("Seat") :: VehicleSeat
	if seat then
		seat:Sit(humanoid)
	end

	-- Clean up when this character is removed (death / leaving)
	player.CharacterRemoving:Connect(function(removedChar)
		if removedChar == character and car and car.Parent then
			car:Destroy()
		end
	end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Connections
-- ──────────────────────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		spawnCarForPlayer(player, character)
	end)
end)

-- Catch players already in the server when this script first runs (Studio test)
for _, player in Players:GetPlayers() do
	if player.Character then
		task.spawn(spawnCarForPlayer, player, player.Character)
	end
end
