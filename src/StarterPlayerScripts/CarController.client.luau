--[[
	CarController  –  LocalScript, runs once per session.
	Reads W/A/S/D input, computes speed + yaw rate, and applies them to the
	car's BodyVelocity / BodyAngularVelocity every Heartbeat.
	Works because the server gave this client network ownership of the chassis.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local CONFIG = require(ReplicatedStorage:WaitForChild("CarConfig"))

-- Live references (reset on each respawn)
local chassis    : Part?                = nil
local carVel     : BodyVelocity?        = nil
local carAngVel  : BodyAngularVelocity? = nil
local carGyro    : BodyGyro?            = nil
local speed      = 0  -- current forward speed in studs/s (negative = reverse)

-- ──────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────────────────────

-- Polls workspace until the car for this player appears.
local function waitForCar(): Model
	local carName = player.Name .. "_Car"

	-- Connect first, then check, to avoid a race condition.
	local found: Model? = nil
	local conn = workspace.ChildAdded:Connect(function(child)
		if child.Name == carName then
			found = child :: Model
		end
	end)
	-- Check in case it already exists
	if not found then
		found = workspace:FindFirstChild(carName) :: Model?
	end
	while not found do
		task.wait(0.05)
	end
	conn:Disconnect()
	return found :: Model
end

local function attachToCar(car: Model)
	chassis   = car:WaitForChild("Chassis")   :: Part
	carVel    = chassis:WaitForChild("CarVelocity")         :: BodyVelocity
	carAngVel = chassis:WaitForChild("CarAngularVelocity")  :: BodyAngularVelocity
	carGyro   = chassis:WaitForChild("CarGyro")             :: BodyGyro
	speed     = 0
	-- Increase responsiveness now that the client owns the physics
	carVel.P    = 5e5
	carAngVel.P = 5e5
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Startup + respawn handling
-- ──────────────────────────────────────────────────────────────────────────────

local function setup()
	local car = waitForCar()
	attachToCar(car)
end

player.CharacterAdded:Connect(function()
	-- Invalidate old references immediately
	chassis   = nil
	carVel    = nil
	carAngVel = nil
	carGyro   = nil
	speed     = 0
	-- Small delay so the server has time to build and spawn the new car
	task.wait(1.5)
	setup()
end)

task.spawn(setup)

-- ──────────────────────────────────────────────────────────────────────────────
-- Physics loop
-- ──────────────────────────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function(dt: number)
	-- Guard: skip if car is not ready or has been destroyed
	if not chassis or not chassis.Parent then return end
	if not carVel or not carAngVel or not carGyro then return end

	-- ── Input ──────────────────────────────────────────────────────────────
	local throttle = 0
	local steer    = 0

	if UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then throttle =  1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S)
		or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then throttle = -1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then steer    = -1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D)
		or UserInputService:IsKeyDown(Enum.KeyCode.Right) then steer    =  1 end

	-- ── Speed update ───────────────────────────────────────────────────────
	if throttle > 0 then
		-- Accelerate forward
		speed = math.min(speed + CONFIG.Acceleration * dt, CONFIG.MaxSpeed)
	elseif throttle < 0 then
		if speed > 1 then
			-- Brake (decelerating from forward)
			speed = math.max(speed - CONFIG.BrakeForce * dt, 0)
		else
			-- Reverse
			speed = math.max(speed - CONFIG.Acceleration * 0.6 * dt, -CONFIG.ReverseSpeed)
		end
	else
		-- Coast: framerate-independent friction decay
		speed = speed * CONFIG.Friction ^ (dt * 60)
		if math.abs(speed) < 0.05 then speed = 0 end
	end

	-- ── Steering ───────────────────────────────────────────────────────────
	-- Turn radius tightens with speed (more grip at low speed, loose at high)
	local speedRatio = math.clamp(math.abs(speed) / CONFIG.MaxSpeed, 0, 1)
	local steerFactor = 0.4 + 0.6 * math.sqrt(speedRatio)
	-- Flip steering direction when reversing so controls feel natural
	local yawRate = steer * CONFIG.TurnSpeed * steerFactor
		* (speed < 0 and -1 or 1)

	-- ── Apply to physics movers ────────────────────────────────────────────
	local lookVec  = chassis.CFrame.LookVector
	local rightVec = chassis.CFrame.RightVector

	-- Lateral grip: measure how much the car is sliding sideways, then cancel
	-- most of it so the car tracks its heading instead of drifting freely.
	local assemblyVel = chassis.AssemblyLinearVelocity
	local lateralDrift = assemblyVel:Dot(rightVec)

	carVel.Velocity           = lookVec * speed - rightVec * (lateralDrift * CONFIG.Grip)
	carAngVel.AngularVelocity = Vector3.new(0, -yawRate, 0)

	-- Keep gyro pointed level at the car's current yaw so it only corrects
	-- pitch/roll without fighting the angular velocity on Y.
	local yaw = math.atan2(-lookVec.X, -lookVec.Z)
	carGyro.CFrame = CFrame.new(chassis.Position) * CFrame.Angles(0, yaw, 0)

	-- ── Publish speed for the HUD ──────────────────────────────────────────
	-- Speed in studs/s ≈ km/h at Roblox scale; floor it for a clean display
	chassis:SetAttribute("SpeedKMH", math.floor(math.abs(speed)))
end)
