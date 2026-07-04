--[[
	MapBuilder.lua
	Generates the whole arena in code at server startup (the Rojo project
	ships no place geometry): a Marineford-style stone plaza with a central
	execution platform, a ring of pillars, an outer ring of buildings,
	border walls, spawn points, a kill plane and lighting.
]]

local Lighting = game:GetService("Lighting")

local STONE = Color3.fromRGB(163, 162, 150)
local DARK_STONE = Color3.fromRGB(120, 118, 110)
local WOOD = Color3.fromRGB(124, 92, 60)

local MapBuilder = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	return p
end

function MapBuilder.Build()
	if workspace:FindFirstChild("Arena") then
		return
	end

	local arena = Instance.new("Folder")
	arena.Name = "Arena"

	-- Plaza floor -----------------------------------------------------------
	part({
		Name = "Floor",
		Size = Vector3.new(440, 8, 440),
		Position = Vector3.new(0, -4, 0),
		Material = Enum.Material.Slate,
		Color = STONE,
		Parent = arena,
	})

	-- Central execution platform (Marineford vibes) --------------------------
	part({ -- stepped base
		Size = Vector3.new(46, 4, 46),
		Position = Vector3.new(0, 2, 0),
		Material = Enum.Material.Slate,
		Color = DARK_STONE,
		Parent = arena,
	})
	part({
		Size = Vector3.new(34, 4, 34),
		Position = Vector3.new(0, 6, 0),
		Material = Enum.Material.Slate,
		Color = STONE,
		Parent = arena,
	})
	for _, xOffset in { -10, 10 } do -- twin towers
		part({
			Size = Vector3.new(6, 42, 6),
			Position = Vector3.new(xOffset, 29, 0),
			Material = Enum.Material.WoodPlanks,
			Color = WOOD,
			Parent = arena,
		})
	end
	part({ -- top platform between the towers
		Size = Vector3.new(26, 2, 10),
		Position = Vector3.new(0, 51, 0),
		Material = Enum.Material.WoodPlanks,
		Color = WOOD,
		Parent = arena,
	})

	-- Ring of pillars ---------------------------------------------------------
	for i = 1, 12 do
		local angle = math.rad(i * 30)
		local height = math.random(18, 34)
		part({
			Size = Vector3.new(9, height, 9),
			Position = Vector3.new(math.cos(angle) * 130, height / 2, math.sin(angle) * 130),
			Material = Enum.Material.Slate,
			Color = DARK_STONE,
			Rotation = Vector3.new(0, math.deg(-angle), 0),
			Parent = arena,
		})
	end

	-- Outer ring of buildings ---------------------------------------------
	for i = 1, 16 do
		local angle = math.rad(i * 22.5 + 11)
		local height = math.random(24, 52)
		local width = math.random(18, 30)
		part({
			Size = Vector3.new(width, height, width),
			Position = Vector3.new(math.cos(angle) * 190, height / 2, math.sin(angle) * 190),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(
				150 + math.random(-25, 25),
				140 + math.random(-25, 25),
				125 + math.random(-20, 20)
			),
			Rotation = Vector3.new(0, math.deg(-angle), 0),
			Parent = arena,
		})
	end

	-- Invisible border walls ------------------------------------------------
	for _, wall in {
		{ Size = Vector3.new(440, 120, 4), Position = Vector3.new(0, 60, -220) },
		{ Size = Vector3.new(440, 120, 4), Position = Vector3.new(0, 60, 220) },
		{ Size = Vector3.new(4, 120, 440), Position = Vector3.new(-220, 60, 0) },
		{ Size = Vector3.new(4, 120, 440), Position = Vector3.new(220, 60, 0) },
	} do
		part({
			Name = "BorderWall",
			Size = wall.Size,
			Position = wall.Position,
			Transparency = 1,
			Parent = arena,
		})
	end

	-- Kill plane for anything that somehow leaves the map --------------------
	local killPlane = part({
		Name = "KillPlane",
		Size = Vector3.new(2000, 4, 2000),
		Position = Vector3.new(0, -80, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = arena,
	})
	killPlane.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)

	-- Spawns ------------------------------------------------------------------
	for i = 1, 8 do
		local angle = math.rad(i * 45)
		local spawn = Instance.new("SpawnLocation")
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = Vector3.new(math.cos(angle) * 70, 0.5, math.sin(angle) * 70)
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Transparency = 1
		spawn.Neutral = true
		spawn.Duration = 0 -- spawn protection is handled by the combat server
		spawn.Parent = arena
	end

	arena.Parent = workspace

	-- Lighting ---------------------------------------------------------------
	Lighting.ClockTime = 14.3
	Lighting.Brightness = 2.5
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Haze = 1.5
		atmosphere.Parent = Lighting
	end
end

return MapBuilder
