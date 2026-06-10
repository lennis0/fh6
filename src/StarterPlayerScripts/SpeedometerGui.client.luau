--[[
	SpeedometerGui  –  LocalScript, runs once per session.
	Builds a simple bottom-right HUD showing the car's speed in km/h.
	Reads the "SpeedKMH" attribute that CarController publishes each frame.
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ──────────────────────────────────────────────────────────────────────────────
-- Build the GUI (purely in code, no Studio objects required)
-- ──────────────────────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name          = "SpeedometerGui"
gui.ResetOnSpawn  = false          -- persists through respawns
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent        = player.PlayerGui

-- Dark pill in the bottom-right corner
local frame = Instance.new("Frame")
frame.Name                  = "Container"
frame.Size                  = UDim2.new(0, 170, 0, 85)
frame.Position              = UDim2.new(1, -190, 1, -105)
frame.BackgroundColor3      = Color3.fromRGB(8, 8, 8)
frame.BackgroundTransparency = 0.3
frame.BorderSizePixel       = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

-- Speed number
local speedLabel = Instance.new("TextLabel")
speedLabel.Name               = "Speed"
speedLabel.Size               = UDim2.new(1, 0, 0.62, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.Text               = "0"
speedLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
speedLabel.TextScaled         = true
speedLabel.Font               = Enum.Font.GothamBold
speedLabel.TextXAlignment     = Enum.TextXAlignment.Center
speedLabel.Parent = frame

-- Unit label
local unitLabel = Instance.new("TextLabel")
unitLabel.Name               = "Unit"
unitLabel.Size               = UDim2.new(1, 0, 0.32, 0)
unitLabel.Position           = UDim2.new(0, 0, 0.65, 0)
unitLabel.BackgroundTransparency = 1
unitLabel.Text               = "KM/H"
unitLabel.TextColor3         = Color3.fromRGB(150, 150, 150)
unitLabel.TextScaled         = true
unitLabel.Font               = Enum.Font.Gotham
unitLabel.TextXAlignment     = Enum.TextXAlignment.Center
unitLabel.Parent = frame

-- ──────────────────────────────────────────────────────────────────────────────
-- Update loop
-- ──────────────────────────────────────────────────────────────────────────────

local function getChassis(): Instance?
	local car = workspace:FindFirstChild(player.Name .. "_Car")
	return car and car:FindFirstChild("Chassis") or nil
end

local displayed = 0  -- smoothed display value

RunService.Heartbeat:Connect(function(dt: number)
	local chassis = getChassis()
	local target  = chassis and (chassis:GetAttribute("SpeedKMH") or 0) or 0
	-- Smooth the displayed number so it doesn't jump
	displayed = displayed + (target - displayed) * math.min(dt * 12, 1)
	speedLabel.Text = tostring(math.floor(displayed))
end)
