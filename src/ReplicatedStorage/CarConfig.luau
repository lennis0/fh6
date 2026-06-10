-- Shared car and camera tuning values.
-- Change these numbers to adjust the feel of the car.
return {
	-- Movement
	MaxSpeed     = 100,  -- studs/s forward  (~80 km/h feel in Roblox)
	Acceleration = 45,   -- studs/s²
	BrakeForce   = 120,  -- studs/s² deceleration while braking
	ReverseSpeed = 30,   -- max reverse studs/s
	TurnSpeed    = 2.0,  -- rad/s maximum yaw rate
	Friction     = 0.85, -- fraction of speed kept per 60Hz frame while coasting
	Grip         = 0.88, -- lateral grip strength (0 = full drift, 1 = no sideways slip)

	-- Camera
	CameraDistance = 22, -- studs behind the car
	CameraHeight   = 9,  -- studs above the car
}
