--[[
	CameraController  –  LocalScript, runs once per session.
	Spring-follow camera that stays behind the car.
	Hold right mouse button to freely orbit; release to auto-follow.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local CONFIG = require(ReplicatedStorage:WaitForChild("CarConfig"))

-- Camera state
local camAngleX = 0               -- horizontal orbit angle (radians)
local camAngleY = math.rad(18)    -- vertical angle (radians, looking slightly down)
local camPos    = Vector3.zero    -- smoothed world position of the camera
local camVel    = Vector3.zero    -- spring velocity

local MIN_PITCH       = math.rad(-5)
local MAX_PITCH       = math.rad(70)
local MOUSE_SENS      = 0.004
local SPRING_STIFF    = 12   -- higher = snappier
local SPRING_DAMP     = 6    -- higher = less bouncy

local isRMB = false

-- ──────────────────────────────────────────────────────────────────────────────
-- Mouse orbit input
-- ──────────────────────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRMB = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRMB = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────────────────────

local function getChassis(): BasePart?
	local car = workspace:FindFirstChild(player.Name .. "_Car")
	return car and car:FindFirstChild("Chassis") :: BasePart? or nil
end

-- Wrap an angle to the range [-π, π]
local function wrapAngle(a: number): number
	return ((a + math.pi) % (2 * math.pi)) - math.pi
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Reset on respawn
-- ──────────────────────────────────────────────────────────────────────────────

player.CharacterAdded:Connect(function()
	camAngleX = 0
	camAngleY = math.rad(18)
	camPos    = Vector3.zero
	camVel    = Vector3.zero
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- Render loop
-- ──────────────────────────────────────────────────────────────────────────────

RunService.RenderStepped:Connect(function(dt: number)
	local chassis = getChassis()

	if not chassis then
		-- Fall back to Roblox default camera when not in a car
		camera.CameraType = Enum.CameraType.Custom
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable

	-- ── Mouse orbit / auto-follow ──────────────────────────────────────────
	if isRMB then
		local delta = UserInputService:GetMouseDelta()
		camAngleX = camAngleX - delta.X * MOUSE_SENS
		camAngleY = math.clamp(camAngleY + delta.Y * MOUSE_SENS, MIN_PITCH, MAX_PITCH)
	else
		-- Slowly rotate camera to face the car's direction
		local lookVec  = chassis.CFrame.LookVector
		local carYaw   = math.atan2(-lookVec.X, -lookVec.Z)
		local diff     = wrapAngle(carYaw - camAngleX)
		camAngleX = camAngleX + diff * math.min(dt * 2.5, 1)
	end

	-- ── Desired camera position ────────────────────────────────────────────
	local carPos        = chassis.Position
	local horizDist     = CONFIG.CameraDistance * math.cos(camAngleY)
	local vertOffset    = CONFIG.CameraHeight + CONFIG.CameraDistance * math.sin(camAngleY)
	local desired       = carPos + Vector3.new(
		math.sin(camAngleX) * horizDist,
		vertOffset,
		math.cos(camAngleX) * horizDist
	)

	-- Seed camPos on first valid frame so there's no snap from world origin
	if camPos == Vector3.zero then
		camPos = desired
	end

	-- ── Spring smoothing ───────────────────────────────────────────────────
	local force = (desired - camPos) * SPRING_STIFF
	camVel = camVel + force * dt
	camVel = camVel * (1 - SPRING_DAMP * dt)
	camPos = camPos + camVel * dt

	-- ── Point camera at the car ────────────────────────────────────────────
	local lookTarget = carPos + Vector3.new(0, 1.5, 0)
	camera.CFrame = CFrame.lookAt(camPos, lookTarget)
end)
