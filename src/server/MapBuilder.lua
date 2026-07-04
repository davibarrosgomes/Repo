--[[
	MapBuilder.lua
	Generates the whole arena in code at server startup (the Rojo project
	ships no place geometry).

	Theme: ONIGASHIMA (Wano arc) at night —
	  - the giant horned skull rock formation with glowing eyes, a fanged
	    mouth entrance and small buildings clustered around its base
	  - Kaido's mansion: a huge multi-tiered fortress with a jail cell
	  - a Beast Pirates village with lantern-lit streets and a torii gate
	  - full-moon night lighting with purple haze
]]

local Lighting = game:GetService("Lighting")

local GROUND = Color3.fromRGB(92, 92, 100)
local SKULL = Color3.fromRGB(142, 138, 150)
local BONE = Color3.fromRGB(226, 219, 200)
local DARK = Color3.fromRGB(18, 16, 20)
local WOOD_DARK = Color3.fromRGB(62, 46, 40)
local ROOF_RED = Color3.fromRGB(118, 32, 36)
local TORII_RED = Color3.fromRGB(168, 42, 42)
local LANTERN_GLOW = Color3.fromRGB(255, 196, 110)

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

-- ========================================================================
-- The skull mountain
-- ========================================================================

local function buildSkull(parent)
	local center = Vector3.new(0, 55, -120)

	-- Cranium: one huge rock sphere, slightly buried.
	part({
		Name = "SkullCranium",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(130, 130, 130),
		Position = center,
		Material = Enum.Material.Rock,
		Color = SKULL,
		Parent = parent,
	})

	-- Horns: three tapering segments each, curving outward.
	for _, side in { -1, 1 } do
		local segments = {
			{ Size = Vector3.new(12, 24, 12), Position = Vector3.new(44, 105, -120), Tilt = 22 },
			{ Size = Vector3.new(9, 20, 9), Position = Vector3.new(55, 117, -120), Tilt = 48 },
			{ Size = Vector3.new(5, 16, 5), Position = Vector3.new(66, 124, -120), Tilt = 72 },
		}
		for _, seg in segments do
			part({
				Name = "SkullHorn",
				Size = seg.Size,
				Position = Vector3.new(seg.Position.X * side, seg.Position.Y, seg.Position.Z),
				Rotation = Vector3.new(0, 0, -seg.Tilt * side),
				Material = Enum.Material.Limestone,
				Color = BONE,
				Parent = parent,
			})
		end
	end

	-- Eye sockets: sunken black spheres with a menacing glow.
	for _, side in { -1, 1 } do
		local eye = part({
			Name = "SkullEye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(18, 18, 18),
			Position = Vector3.new(24 * side, 74, -64),
			Material = Enum.Material.SmoothPlastic,
			Color = DARK,
			Parent = parent,
		})
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 70, 40)
		glow.Range = 34
		glow.Brightness = 1.6
		glow.Parent = eye
	end

	-- Mouth: dark entrance at the base of the skull...
	part({
		Name = "SkullMouth",
		Size = Vector3.new(46, 26, 32),
		Position = Vector3.new(0, 13, -62),
		Material = Enum.Material.SmoothPlastic,
		Color = DARK,
		Parent = parent,
	})
	-- ...framed by two rows of fangs.
	for i = 0, 5 do
		local x = -17.5 + i * 7
		part({ -- upper fangs
			Name = "SkullFang",
			Size = Vector3.new(4.5, 9, 3),
			Position = Vector3.new(x, 23, -45),
			Rotation = Vector3.new(0, 0, (i % 2 == 0) and 6 or -6),
			Material = Enum.Material.Limestone,
			Color = BONE,
			Parent = parent,
		})
		part({ -- lower fangs
			Name = "SkullFang",
			Size = Vector3.new(4.5, 7, 3),
			Position = Vector3.new(x + 3.5, 3.5, -45),
			Material = Enum.Material.Limestone,
			Color = BONE,
			Parent = parent,
		})
	end

	-- Braziers flanking the mouth with real fire.
	for _, side in { -1, 1 } do
		local bowl = part({
			Name = "Brazier",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 7, 7),
			Position = Vector3.new(34 * side, 2, -42),
			Rotation = Vector3.new(0, 0, 90),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 38, 36),
			Parent = parent,
		})
		local fire = Instance.new("Fire")
		fire.Size = 8
		fire.Heat = 12
		fire.Parent = bowl
		local light = Instance.new("PointLight")
		light.Color = LANTERN_GLOW
		light.Range = 40
		light.Brightness = 1.4
		light.Parent = bowl
	end

	-- Small buildings clustered around the skull's base.
	for _, spot in {
		{ Position = Vector3.new(-92, 0, -104), Height = 22 },
		{ Position = Vector3.new(-78, 0, -140), Height = 30 },
		{ Position = Vector3.new(90, 0, -110), Height = 26 },
		{ Position = Vector3.new(76, 0, -146), Height = 18 },
	} do
		local h = spot.Height
		part({
			Name = "SkullOutbuilding",
			Size = Vector3.new(20, h, 20),
			Position = Vector3.new(spot.Position.X, h / 2, spot.Position.Z),
			Material = Enum.Material.WoodPlanks,
			Color = WOOD_DARK,
			Parent = parent,
		})
		part({
			Name = "SkullOutbuildingRoof",
			Size = Vector3.new(25, 2.5, 25),
			Position = Vector3.new(spot.Position.X, h + 1.25, spot.Position.Z),
			Material = Enum.Material.Slate,
			Color = ROOF_RED,
			Parent = parent,
		})
	end
end

-- ========================================================================
-- Kaido's mansion
-- ========================================================================

local function buildMansion(parent)
	local baseX, baseZ = 142, -40

	-- Four shrinking tiers, each capped with an overhanging pagoda roof.
	local tiers = {
		{ Size = Vector3.new(82, 26, 62), Y = 13 },
		{ Size = Vector3.new(64, 20, 48), Y = 40 },
		{ Size = Vector3.new(46, 16, 36), Y = 61 },
		{ Size = Vector3.new(30, 12, 24), Y = 78 },
	}
	for _, tier in tiers do
		part({
			Name = "MansionTier",
			Size = tier.Size,
			Position = Vector3.new(baseX, tier.Y, baseZ),
			Material = Enum.Material.WoodPlanks,
			Color = WOOD_DARK,
			Parent = parent,
		})
		part({
			Name = "MansionRoof",
			Size = Vector3.new(tier.Size.X + 12, 3.5, tier.Size.Z + 12),
			Position = Vector3.new(baseX, tier.Y + tier.Size.Y / 2 + 1.75, baseZ),
			Material = Enum.Material.Slate,
			Color = ROOF_RED,
			Parent = parent,
		})
	end
	part({ -- golden topper
		Name = "MansionTopper",
		Size = Vector3.new(6, 10, 6),
		Position = Vector3.new(baseX, 91, baseZ),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(212, 175, 55),
		Parent = parent,
	})

	-- Giant doorway (Kaido-sized) facing the plaza.
	part({
		Name = "MansionDoor",
		Size = Vector3.new(2.5, 20, 24),
		Position = Vector3.new(baseX - 41, 10, baseZ),
		Material = Enum.Material.SmoothPlastic,
		Color = DARK,
		Parent = parent,
	})

	-- The jail cell (where Eustass Kid was held): a recessed dark cell
	-- with metal bars, low on the plaza-facing wall.
	part({
		Name = "MansionCell",
		Size = Vector3.new(2, 12, 16),
		Position = Vector3.new(baseX - 41, 6, baseZ + 22),
		Material = Enum.Material.SmoothPlastic,
		Color = DARK,
		Parent = parent,
	})
	for i = 0, 4 do
		part({
			Name = "CellBar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(12, 1, 1),
			Position = Vector3.new(baseX - 42.2, 6, baseZ + 15.5 + i * 3.25),
			Rotation = Vector3.new(0, 0, 90),
			Material = Enum.Material.DiamondPlate,
			Color = Color3.fromRGB(105, 105, 110),
			Parent = parent,
		})
	end
end

-- ========================================================================
-- Village, torii and scenery
-- ========================================================================

local function buildLantern(parent, position)
	part({
		Name = "LanternPost",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 1, 1),
		Position = position + Vector3.new(0, 4.5, 0),
		Rotation = Vector3.new(0, 0, 90),
		Material = Enum.Material.Wood,
		Color = WOOD_DARK,
		Parent = parent,
	})
	local lamp = part({
		Name = "Lantern",
		Size = Vector3.new(2.4, 3.2, 2.4),
		Position = position + Vector3.new(0, 10, 0),
		Material = Enum.Material.Neon,
		Color = LANTERN_GLOW,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = LANTERN_GLOW
	light.Range = 28
	light.Brightness = 1.1
	light.Parent = lamp
end

local function buildVillage(parent)
	-- Wano-style houses in the front half of the island.
	for i = 1, 10 do
		local angle = math.rad(12 + i * 15.5)
		local radius = (i % 2 == 0) and 148 or 182
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local width = math.random(16, 24)
		local height = math.random(12, 20)
		local yaw = math.deg(-angle) + 90

		part({
			Name = "House",
			Size = Vector3.new(width, height, width * 0.8),
			Position = Vector3.new(x, height / 2, z),
			Rotation = Vector3.new(0, yaw, 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(72 + math.random(-12, 12), 54 + math.random(-10, 10), 44),
			Parent = parent,
		})
		part({
			Name = "HouseRoof",
			Size = Vector3.new(width + 5, 2.5, width * 0.8 + 5),
			Position = Vector3.new(x, height + 1.25, z),
			Rotation = Vector3.new(0, yaw, 0),
			Material = Enum.Material.Slate,
			Color = (i % 3 == 0) and Color3.fromRGB(45, 48, 60) or ROOF_RED,
			Parent = parent,
		})
		if i % 2 == 1 then
			buildLantern(parent, Vector3.new(x * 0.82, 0, z * 0.82))
		end
	end

	-- Torii gate marking the entrance road, facing the skull.
	for _, side in { -1, 1 } do
		part({
			Name = "ToriiPillar",
			Size = Vector3.new(5, 32, 5),
			Position = Vector3.new(17 * side, 16, 172),
			Material = Enum.Material.Wood,
			Color = TORII_RED,
			Parent = parent,
		})
	end
	part({
		Name = "ToriiBeam",
		Size = Vector3.new(46, 4, 6),
		Position = Vector3.new(0, 30, 172),
		Material = Enum.Material.Wood,
		Color = TORII_RED,
		Parent = parent,
	})
	part({
		Name = "ToriiTop",
		Size = Vector3.new(56, 5, 8),
		Position = Vector3.new(0, 36, 172),
		Material = Enum.Material.Wood,
		Color = DARK,
		Parent = parent,
	})

	-- Lanterns ringing the central fighting plaza.
	for i = 1, 8 do
		local angle = math.rad(i * 45 + 22.5)
		buildLantern(parent, Vector3.new(math.cos(angle) * 62, 0, math.sin(angle) * 62))
	end

	-- Scattered boulders for cover.
	for _ = 1, 16 do
		local angle = math.rad(math.random(0, 359))
		local radius = math.random(92, 200)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local nearMansion = math.abs(x - 142) < 65 and math.abs(z + 40) < 55
		local nearSkull = z < -55 and math.abs(x) < 95
		if not nearMansion and not nearSkull then
			local size = math.random(5, 13)
			part({
				Name = "Boulder",
				Size = Vector3.new(size, size * 0.8, size),
				Position = Vector3.new(x, size * 0.3, z),
				Rotation = Vector3.new(math.random(-15, 15), math.random(0, 359), math.random(-15, 15)),
				Material = Enum.Material.Rock,
				Color = GROUND,
				Parent = parent,
			})
		end
	end
end

-- ========================================================================
-- Assembly
-- ========================================================================

function MapBuilder.Build()
	if workspace:FindFirstChild("Arena") then
		return
	end

	local arena = Instance.new("Folder")
	arena.Name = "Arena"

	-- Island ground.
	part({
		Name = "Floor",
		Size = Vector3.new(440, 8, 440),
		Position = Vector3.new(0, -4, 0),
		Material = Enum.Material.Slate,
		Color = GROUND,
		Parent = arena,
	})

	buildSkull(arena)
	buildMansion(arena)
	buildVillage(arena)

	-- Invisible border walls.
	for _, wall in {
		{ Size = Vector3.new(440, 160, 4), Position = Vector3.new(0, 80, -220) },
		{ Size = Vector3.new(440, 160, 4), Position = Vector3.new(0, 80, 220) },
		{ Size = Vector3.new(4, 160, 440), Position = Vector3.new(-220, 80, 0) },
		{ Size = Vector3.new(4, 160, 440), Position = Vector3.new(220, 80, 0) },
	} do
		part({
			Name = "BorderWall",
			Size = wall.Size,
			Position = wall.Position,
			Transparency = 1,
			Parent = arena,
		})
	end

	-- Kill plane for anything that somehow leaves the map.
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

	-- Spawns around the central plaza.
	for i = 1, 8 do
		local angle = math.rad(i * 45)
		local spawn = Instance.new("SpawnLocation")
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = Vector3.new(math.cos(angle) * 45, 0.5, math.sin(angle) * 45)
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Transparency = 1
		spawn.Neutral = true
		spawn.Duration = 0 -- spawn protection is handled by the combat server
		spawn.Parent = arena
	end

	arena.Parent = workspace

	-- Full-moon Onigashima night.
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.4
	Lighting.ExposureCompensation = 0.2
	Lighting.OutdoorAmbient = Color3.fromRGB(88, 96, 132)
	Lighting.Ambient = Color3.fromRGB(48, 48, 64)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.34
		atmosphere.Haze = 2.2
		atmosphere.Color = Color3.fromRGB(150, 138, 170)
		atmosphere.Decay = Color3.fromRGB(66, 60, 96)
		atmosphere.Parent = Lighting
	end
end

return MapBuilder
