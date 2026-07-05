--[[
	MapBuilder.lua
	Generates the whole arena in code at server startup (the Rojo project
	ships no place geometry).

	Theme: ONIGASHIMA (Wano arc) on a full-moon night.

	The island is real voxel terrain rising out of a real ocean. On it:
	  - the horned skull mountain: sculpted brow, cheekbones, sunken glowing
	    eyes, nostrils, a fanged gate-mouth with wooden doors, rock crags,
	    bone piles, smoke, and a shrine on the summit plateau
	  - Kaido's mansion: a five-tier Japanese castle on a stone foundation
	    with lit windows, banners, a giant doorway and the jail cell
	  - a lantern-lit village with market stalls, a stone road, banner
	    poles, dead trees and a wooden port
	  - a giant full moon behind the skull + bloom/color grading
]]

local Lighting = game:GetService("Lighting")

-- Palette ----------------------------------------------------------------
local GROUND = Color3.fromRGB(92, 92, 100)
local SKULL = Color3.fromRGB(142, 138, 150)
local SKULL_DARK = Color3.fromRGB(112, 108, 122)
local BONE = Color3.fromRGB(226, 219, 200)
local DARK = Color3.fromRGB(16, 14, 18)
local WOOD_DARK = Color3.fromRGB(62, 46, 40)
local WOOD_WARM = Color3.fromRGB(88, 64, 48)
local ROOF_RED = Color3.fromRGB(118, 32, 36)
local ROOF_SLATE = Color3.fromRGB(45, 48, 60)
local TORII_RED = Color3.fromRGB(168, 42, 42)
local STONE = Color3.fromRGB(74, 74, 82)
local LANTERN_GLOW = Color3.fromRGB(255, 196, 110)
local WINDOW_GLOW = Color3.fromRGB(255, 214, 140)
local GOLD = Color3.fromRGB(212, 175, 55)
local MOON = Color3.fromRGB(255, 243, 214)

local MapBuilder = {}

-- ========================================================================
-- Builders
-- ========================================================================

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

local function wedge(props)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		w[key] = value
	end
	return w
end

local function pointLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = parent
	return light
end

-- Classic gabled roof: overhang slab + two wedges meeting at a ridge.
local function gableRoof(parent, center, width, depth, height, color, yawDeg)
	local base = CFrame.new(center) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
	part({
		Name = "RoofSlab",
		Size = Vector3.new(width + 4, 1.2, depth + 4),
		CFrame = base * CFrame.new(0, 0.6, 0),
		Material = Enum.Material.Slate,
		Color = color,
		Parent = parent,
	})
	for _, side in { -1, 1 } do
		wedge({
			Name = "RoofSlope",
			Size = Vector3.new(width + 2, height, depth / 2 + 1),
			CFrame = base
				* CFrame.new(0, 1.2 + height / 2, side * (depth / 2 + 1) / 2)
				* CFrame.Angles(0, side == 1 and math.rad(180) or 0, 0),
			Material = Enum.Material.Slate,
			Color = color,
			Parent = parent,
		})
	end
end

local function lantern(parent, position)
	part({
		Name = "LanternPost",
		Size = Vector3.new(0.9, 9, 0.9),
		Position = position + Vector3.new(0, 4.5, 0),
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
	part({
		Name = "LanternCap",
		Size = Vector3.new(3, 0.8, 3),
		Position = position + Vector3.new(0, 11.9, 0),
		Material = Enum.Material.Wood,
		Color = DARK,
		Parent = parent,
	})
	pointLight(lamp, LANTERN_GLOW, 28, 1.1)
end

local function deadTree(parent, position, height)
	local lean = math.random(-8, 8)
	part({
		Name = "TreeTrunk",
		Size = Vector3.new(1.6, height, 1.6),
		Position = position + Vector3.new(0, height / 2, 0),
		Rotation = Vector3.new(lean, math.random(0, 359), lean / 2),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(38, 30, 28),
		Parent = parent,
	})
	for b = 1, 3 do
		part({
			Name = "TreeBranch",
			Size = Vector3.new(0.8, height * 0.45, 0.8),
			Position = position + Vector3.new(math.random(-3, 3), height * (0.55 + b * 0.1), math.random(-3, 3)),
			Rotation = Vector3.new(math.random(25, 65), math.random(0, 359), math.random(25, 65)),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(34, 27, 25),
			Parent = parent,
		})
	end
end

-- ========================================================================
-- Terrain: the island itself and the sea around it
-- ========================================================================

local function buildTerrain()
	local terrain = workspace.Terrain

	-- The ocean. Everything below y = -4 outside the island is open water.
	terrain:FillBlock(CFrame.new(0, -22, 0), Vector3.new(1800, 36, 1800), Enum.Material.Water)

	-- The island: a basalt pedestal rising from the seabed, a sandstone
	-- shore ring at the waterline and a slate top to fight on.
	terrain:FillCylinder(CFrame.new(0, -20, 0), 44, 252, Enum.Material.Basalt)
	terrain:FillCylinder(CFrame.new(0, -8, 0), 8, 246, Enum.Material.Sandstone)
	-- Top surface ends at y = 0 so built structures sit on, not in, the ground.
	terrain:FillCylinder(CFrame.new(0, -5, 0), 10, 236, Enum.Material.Slate)

	-- Patches of dirt and cracked rock so the ground isn't uniform.
	for _, patch in {
		{ Position = Vector3.new(-90, 0, 70), Radius = 26, Material = Enum.Material.Ground },
		{ Position = Vector3.new(120, 0, 110), Radius = 22, Material = Enum.Material.Ground },
		{ Position = Vector3.new(-150, 0, -60), Radius = 30, Material = Enum.Material.Basalt },
		{ Position = Vector3.new(60, 0, 170), Radius = 18, Material = Enum.Material.Ground },
		{ Position = Vector3.new(170, 0, 30), Radius = 20, Material = Enum.Material.Basalt },
		{ Position = Vector3.new(-60, 0, -170), Radius = 26, Material = Enum.Material.Basalt },
		{ Position = Vector3.new(90, 0, -60), Radius = 16, Material = Enum.Material.Ground },
	} do
		terrain:FillBall(patch.Position, patch.Radius, patch.Material)
	end

	-- Rocky rise behind the skull so it reads as a mountain (kept far
	-- enough back that it doesn't swallow the base outbuildings).
	terrain:FillBall(Vector3.new(-60, -8, -195), 45, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(60, -8, -195), 45, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(0, -5, -205), 55, Enum.Material.Rock)
end

-- ========================================================================
-- The skull mountain
-- ========================================================================

local function buildSkull(parent)
	local model = Instance.new("Model")
	model.Name = "SkullDome"

	-- Cranium.
	part({
		Name = "Cranium",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(136, 136, 136),
		Position = Vector3.new(0, 58, -128),
		Material = Enum.Material.Rock,
		Color = SKULL,
		Parent = model,
	})

	-- Cheekbones bulging through the face.
	for _, side in { -1, 1 } do
		part({
			Name = "Cheekbone",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(30, 30, 30),
			Position = Vector3.new(36 * side, 44, -80),
			Material = Enum.Material.Rock,
			Color = SKULL_DARK,
			Parent = model,
		})
	end

	-- Brow ridges: angled slabs shading the eyes.
	for _, side in { -1, 1 } do
		part({
			Name = "BrowRidge",
			Size = Vector3.new(26, 9, 14),
			Position = Vector3.new(25 * side, 88, -70),
			Rotation = Vector3.new(-12, 0, 14 * side),
			Material = Enum.Material.Rock,
			Color = SKULL_DARK,
			Parent = model,
		})
	end

	-- Eyes: deep dark sockets with a menacing ember glow.
	for _, side in { -1, 1 } do
		local socket = part({
			Name = "EyeSocket",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(15, 17, 17),
			Position = Vector3.new(24 * side, 74, -66),
			Rotation = Vector3.new(0, 90, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = DARK,
			Parent = model,
		})
		pointLight(socket, Color3.fromRGB(255, 70, 40), 34, 1.6)
	end

	-- Nostrils.
	for _, side in { -1, 1 } do
		part({
			Name = "Nostril",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7, 9, 7),
			Position = Vector3.new(4.5 * side, 48, -60.5),
			Material = Enum.Material.SmoothPlastic,
			Color = DARK,
			Parent = model,
		})
	end

	-- Horns: five tapering, curving segments per side.
	for _, side in { -1, 1 } do
		for _, seg in {
			{ X = 40, Y = 102, Tilt = 14, Size = Vector3.new(13, 26, 13) },
			{ X = 48, Y = 116, Tilt = 32, Size = Vector3.new(11, 22, 11) },
			{ X = 58, Y = 127, Tilt = 50, Size = Vector3.new(9, 18, 9) },
			{ X = 69, Y = 134, Tilt = 68, Size = Vector3.new(6, 15, 6) },
			{ X = 79, Y = 137, Tilt = 84, Size = Vector3.new(4, 12, 4) },
		} do
			part({
				Name = "Horn",
				Size = seg.Size,
				Position = Vector3.new(seg.X * side, seg.Y, -128),
				Rotation = Vector3.new(0, 0, -seg.Tilt * side),
				Material = Enum.Material.Limestone,
				Color = BONE,
				Parent = model,
			})
		end
	end

	-- The gate-mouth: a dark maw with wooden doors left ajar.
	part({
		Name = "Maw",
		Size = Vector3.new(50, 28, 34),
		Position = Vector3.new(0, 14, -58),
		Material = Enum.Material.SmoothPlastic,
		Color = DARK,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "MouthDoor",
			Size = Vector3.new(11, 23, 1.8),
			Position = Vector3.new(12 * side, 11.5, -46),
			Rotation = Vector3.new(0, -24 * side, 0),
			Material = Enum.Material.WoodPlanks,
			Color = WOOD_DARK,
			Parent = model,
		})
	end
	part({ -- stone threshold in front of the gate
		Name = "MouthThreshold",
		Size = Vector3.new(54, 1, 14),
		Position = Vector3.new(0, 0.5, -38),
		Material = Enum.Material.Basalt,
		Color = STONE,
		Parent = model,
	})

	-- Fangs framing the maw.
	for i = 0, 6 do
		local x = -21 + i * 7
		part({
			Name = "FangUpper",
			Size = Vector3.new(5, 10, 3),
			Position = Vector3.new(x, 25, -42),
			Rotation = Vector3.new(0, 0, (i % 2 == 0) and 7 or -7),
			Material = Enum.Material.Limestone,
			Color = BONE,
			Parent = model,
		})
		if i < 6 then
			part({
				Name = "FangLower",
				Size = Vector3.new(4, 8, 3),
				Position = Vector3.new(x + 3.5, 4, -42),
				Material = Enum.Material.Limestone,
				Color = BONE,
				Parent = model,
			})
		end
	end

	-- Braziers flanking the gate, with fire and drifting embers.
	for _, side in { -1, 1 } do
		local bowl = part({
			Name = "Brazier",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 7, 7),
			Position = Vector3.new(36 * side, 2, -38),
			Rotation = Vector3.new(0, 0, 90),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 38, 36),
			Parent = model,
		})
		local fire = Instance.new("Fire")
		fire.Size = 8
		fire.Heat = 12
		fire.Parent = bowl
		pointLight(bowl, LANTERN_GLOW, 40, 1.4)

		local embers = Instance.new("ParticleEmitter")
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 150, 60))
		embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		embers.Lifetime = NumberRange.new(1.5, 2.5)
		embers.Rate = 5
		embers.Speed = NumberRange.new(3, 6)
		embers.SpreadAngle = Vector2.new(25, 25)
		embers.LightEmission = 1
		embers.Parent = bowl
	end

	-- Rock crags leaning against the skull's base.
	for _, crag in {
		{ Position = Vector3.new(-70, 14, -96), Size = Vector3.new(18, 42, 18), Tilt = Vector3.new(6, 20, -14) },
		{ Position = Vector3.new(72, 12, -100), Size = Vector3.new(16, 38, 16), Tilt = Vector3.new(-4, -35, 15) },
		{ Position = Vector3.new(-84, 10, -140), Size = Vector3.new(20, 34, 20), Tilt = Vector3.new(8, 60, -10) },
		{ Position = Vector3.new(86, 11, -146), Size = Vector3.new(17, 36, 17), Tilt = Vector3.new(-6, -70, 12) },
	} do
		part({
			Name = "Crag",
			Size = crag.Size,
			Position = crag.Position,
			Rotation = crag.Tilt,
			Material = Enum.Material.Rock,
			Color = SKULL_DARK,
			Parent = model,
		})
	end

	-- Bone piles scattered near the gate.
	for _, pile in {
		Vector3.new(-52, 0, -76),
		Vector3.new(56, 0, -80),
		Vector3.new(-40, 0, -52),
		Vector3.new(46, 0, -56),
	} do
		for b = 1, 3 do
			part({
				Name = "Bone",
				Shape = (b == 3) and Enum.PartType.Cylinder or Enum.PartType.Ball,
				Size = (b == 3) and Vector3.new(7, 1.6, 1.6) or Vector3.new(3 + b, 2.5 + b, 3 + b),
				Position = pile + Vector3.new(math.random(-4, 4), 1, math.random(-4, 4)),
				Rotation = Vector3.new(0, math.random(0, 359), (b == 3) and 12 or 0),
				Material = Enum.Material.Limestone,
				Color = BONE,
				Parent = model,
			})
		end
	end

	-- Summit plateau with a tiny shrine and smoke drifting off the top.
	local plateau = part({
		Name = "SummitPlateau",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 46, 46),
		Position = Vector3.new(0, 124, -128),
		Rotation = Vector3.new(0, 0, 90),
		Material = Enum.Material.Rock,
		Color = SKULL_DARK,
		Parent = model,
	})
	part({
		Name = "ShrineHut",
		Size = Vector3.new(10, 8, 10),
		Position = Vector3.new(-8, 130, -128),
		Material = Enum.Material.WoodPlanks,
		Color = WOOD_DARK,
		Parent = model,
	})
	gableRoof(model, Vector3.new(-8, 134, -128), 10, 10, 4, ROOF_RED, 0)
	lantern(model, Vector3.new(6, 126, -124))

	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 115, 130))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 16) })
	smoke.Transparency = NumberSequence.new(0.75, 1)
	smoke.Lifetime = NumberRange.new(6, 9)
	smoke.Rate = 2
	smoke.Speed = NumberRange.new(2, 4)
	smoke.Acceleration = Vector3.new(1.5, 1, 0)
	smoke.Parent = plateau

	-- Low clouds clinging to the skull.
	for _, cloud in {
		{ Position = Vector3.new(-78, 108, -110), Size = Vector3.new(46, 12, 26) },
		{ Position = Vector3.new(72, 96, -150), Size = Vector3.new(52, 12, 30) },
		{ Position = Vector3.new(10, 118, -80), Size = Vector3.new(40, 10, 22) },
	} do
		part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = cloud.Size,
			Position = cloud.Position,
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(200, 198, 215),
			Transparency = 0.65,
			CanCollide = false,
			Parent = model,
		})
	end

	-- Outbuildings clustered around the base.
	for _, spot in {
		{ Position = Vector3.new(-98, 0, -104), Height = 22 },
		{ Position = Vector3.new(-82, 0, -146), Height = 30 },
		{ Position = Vector3.new(96, 0, -112), Height = 26 },
		{ Position = Vector3.new(80, 0, -152), Height = 18 },
	} do
		local h = spot.Height
		part({
			Name = "Outbuilding",
			Size = Vector3.new(20, h, 20),
			Position = Vector3.new(spot.Position.X, h / 2 - 1, spot.Position.Z),
			Material = Enum.Material.WoodPlanks,
			Color = WOOD_DARK,
			Parent = model,
		})
		gableRoof(model, Vector3.new(spot.Position.X, h - 1, spot.Position.Z), 20, 20, 6, ROOF_RED, 0)
	end

	model.Parent = parent
end

-- ========================================================================
-- Kaido's mansion: a five-tier castle on a stone foundation
-- ========================================================================

local function buildMansion(parent)
	local model = Instance.new("Model")
	model.Name = "KaidoMansion"

	local baseX, baseZ = 145, -35

	-- Stone foundation, two stepped slabs.
	part({
		Name = "FoundationLower",
		Size = Vector3.new(100, 10, 78),
		Position = Vector3.new(baseX, 4, baseZ),
		Material = Enum.Material.Cobblestone,
		Color = STONE,
		Parent = model,
	})
	part({
		Name = "FoundationUpper",
		Size = Vector3.new(90, 8, 68),
		Position = Vector3.new(baseX, 13, baseZ),
		Material = Enum.Material.Cobblestone,
		Color = STONE,
		Parent = model,
	})

	-- Five shrinking wooden tiers, each with an overhanging pagoda roof
	-- and a row of warmly lit windows facing the plaza.
	local tiers = {
		{ Size = Vector3.new(78, 20, 58), Y = 27 },
		{ Size = Vector3.new(62, 16, 46), Y = 45 },
		{ Size = Vector3.new(48, 14, 36), Y = 60 },
		{ Size = Vector3.new(34, 12, 26), Y = 73 },
		{ Size = Vector3.new(22, 10, 18), Y = 84 },
	}
	for index, tier in tiers do
		part({
			Name = "Tier" .. index,
			Size = tier.Size,
			Position = Vector3.new(baseX, tier.Y, baseZ),
			Material = Enum.Material.WoodPlanks,
			Color = WOOD_DARK,
			Parent = model,
		})
		part({
			Name = "TierRoof" .. index,
			Size = Vector3.new(tier.Size.X + 12, 3, tier.Size.Z + 12),
			Position = Vector3.new(baseX, tier.Y + tier.Size.Y / 2 + 1.5, baseZ),
			Material = Enum.Material.Slate,
			Color = ROOF_RED,
			Parent = model,
		})

		local windowCount = math.max(2, math.floor(tier.Size.Z / 12))
		for w = 1, windowCount do
			local offset = (w - (windowCount + 1) / 2) * 10
			local window = part({
				Name = "Window",
				Size = Vector3.new(0.6, 4, 3),
				Position = Vector3.new(baseX - tier.Size.X / 2 - 0.1, tier.Y + 1, baseZ + offset),
				Material = Enum.Material.Neon,
				Color = WINDOW_GLOW,
				Parent = model,
			})
			if w == 1 then
				pointLight(window, WINDOW_GLOW, 16, 0.5)
			end
		end
	end

	-- Crown: gabled top roof and a golden finial.
	gableRoof(model, Vector3.new(baseX, 90.5, baseZ), 24, 20, 7, ROOF_RED, 0)
	part({
		Name = "GoldenFinial",
		Size = Vector3.new(3, 8, 3),
		Position = Vector3.new(baseX, 102, baseZ),
		Material = Enum.Material.Metal,
		Color = GOLD,
		Parent = model,
	})
	part({
		Name = "GoldenOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		Position = Vector3.new(baseX, 107, baseZ),
		Material = Enum.Material.Metal,
		Color = GOLD,
		Parent = model,
	})

	-- Kaido-sized doorway facing the plaza, flanked by braziers.
	part({
		Name = "GreatDoor",
		Size = Vector3.new(2.5, 22, 26),
		Position = Vector3.new(baseX - 50.5, 11, baseZ),
		Material = Enum.Material.SmoothPlastic,
		Color = DARK,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		local sconce = part({
			Name = "DoorSconce",
			Size = Vector3.new(2, 2.6, 2),
			Position = Vector3.new(baseX - 52, 14, baseZ + 17 * side),
			Material = Enum.Material.Neon,
			Color = LANTERN_GLOW,
			Parent = model,
		})
		pointLight(sconce, LANTERN_GLOW, 26, 1)
	end

	-- The jail cell (Eustass Kid's old room): recessed, barred, low
	-- on the plaza-facing wall.
	part({
		Name = "JailCell",
		Size = Vector3.new(2, 12, 16),
		Position = Vector3.new(baseX - 50.5, 6, baseZ + 26),
		Material = Enum.Material.SmoothPlastic,
		Color = DARK,
		Parent = model,
	})
	for i = 0, 4 do
		part({
			Name = "CellBar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(12, 1, 1),
			Position = Vector3.new(baseX - 51.8, 6, baseZ + 19.5 + i * 3.25),
			Rotation = Vector3.new(0, 0, 90),
			Material = Enum.Material.DiamondPlate,
			Color = Color3.fromRGB(105, 105, 110),
			Parent = model,
		})
	end

	-- Beast Pirates banner poles at the front corners.
	for _, side in { -1, 1 } do
		part({
			Name = "BannerPole",
			Size = Vector3.new(1, 34, 1),
			Position = Vector3.new(baseX - 46, 17, baseZ + 44 * side),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(50, 48, 48),
			Parent = model,
		})
		part({
			Name = "Banner",
			Size = Vector3.new(0.4, 12, 7),
			Position = Vector3.new(baseX - 46, 27, baseZ + (44 * side) + 4),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(24, 22, 26),
			Parent = model,
		})
	end

	model.Parent = parent
end

-- ========================================================================
-- Village, road, torii, port and scenery
-- ========================================================================

local function buildHouse(parent, x, z, yawDeg, width, height)
	local depth = width * 0.8
	part({
		Name = "HouseBody",
		Size = Vector3.new(width, height, depth),
		Position = Vector3.new(x, height / 2 - 1, z),
		Rotation = Vector3.new(0, yawDeg, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(72 + math.random(-12, 12), 54 + math.random(-10, 10), 44),
		Parent = parent,
	})
	gableRoof(
		parent,
		Vector3.new(x, height - 1, z),
		width,
		depth,
		math.max(4, height * 0.35),
		(math.random() < 0.4) and ROOF_SLATE or ROOF_RED,
		yawDeg
	)

	local facing = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	local door = facing * CFrame.new(0, height * 0.3, depth / 2 + 0.1)
	part({
		Name = "HouseDoor",
		Size = Vector3.new(3, height * 0.6, 0.5),
		CFrame = door,
		Material = Enum.Material.Wood,
		Color = DARK,
		Parent = parent,
	})
	part({ -- noren cloth band above the door
		Name = "Noren",
		Size = Vector3.new(5, 1.6, 0.3),
		CFrame = facing * CFrame.new(0, height * 0.62, depth / 2 + 0.2),
		Material = Enum.Material.Fabric,
		Color = (math.random() < 0.5) and Color3.fromRGB(40, 48, 96) or Color3.fromRGB(140, 40, 40),
		Parent = parent,
	})
	for _, side in { -1, 1 } do
		local window = part({
			Name = "HouseWindow",
			Size = Vector3.new(2.6, 2.6, 0.4),
			CFrame = facing * CFrame.new(side * width * 0.28, height * 0.55, depth / 2 + 0.1),
			Material = Enum.Material.Neon,
			Color = WINDOW_GLOW,
			Parent = parent,
		})
		if side == 1 and math.random() < 0.6 then
			pointLight(window, WINDOW_GLOW, 14, 0.5)
		end
	end
end

local function buildStall(parent, x, z, yawDeg)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	part({
		Name = "StallCounter",
		Size = Vector3.new(8, 3, 3.5),
		CFrame = base * CFrame.new(0, 1.5, 0),
		Material = Enum.Material.WoodPlanks,
		Color = WOOD_WARM,
		Parent = parent,
	})
	part({
		Name = "StallAwning",
		Size = Vector3.new(9.5, 0.5, 6),
		CFrame = base * CFrame.new(0, 6.4, -0.6) * CFrame.Angles(math.rad(-12), 0, 0),
		Material = Enum.Material.Fabric,
		Color = (math.random() < 0.5) and Color3.fromRGB(150, 46, 46) or Color3.fromRGB(46, 56, 110),
		Parent = parent,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "StallPost",
			Size = Vector3.new(0.7, 6.5, 0.7),
			CFrame = base * CFrame.new(side * 4.2, 3.25, -1.6),
			Material = Enum.Material.Wood,
			Color = WOOD_DARK,
			Parent = parent,
		})
	end
	for b = 1, 2 do
		part({
			Name = "SakeBarrel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.4, 2.8, 2.8),
			CFrame = base * CFrame.new(5.8, 1.7, b * 2 - 3) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Wood,
			Color = WOOD_WARM,
			Parent = parent,
		})
	end
end

local function buildVillage(parent)
	local model = Instance.new("Model")
	model.Name = "Village"

	-- Houses along two arcs in the front half of the island, leaving the
	-- entrance road (x ~ 0) clear.
	for i = 1, 11 do
		local angle = 8 + i * 15
		if angle < 80 or angle > 100 then
			local radius = (i % 2 == 0) and 140 or 180
			local rad = math.rad(angle)
			local x, z = math.cos(rad) * radius, math.sin(rad) * radius
			buildHouse(model, x, z, -angle + 90, math.random(16, 24), math.random(12, 20))
			if i % 2 == 1 then
				lantern(model, Vector3.new(x * 0.82, 0, z * 0.82))
			end
		end
	end

	-- Market stalls flanking the road.
	buildStall(model, 18, 96, -90)
	buildStall(model, -17, 118, 90)
	buildStall(model, 21, 144, -90)

	-- Stone road from the torii gate to the plaza.
	for z = 64, 180, 9 do
		part({
			Name = "RoadSlab",
			Size = Vector3.new(10, 1, 8),
			Position = Vector3.new(math.random(-10, 10) / 10, 0.5, z),
			Rotation = Vector3.new(0, math.random(-6, 6), 0),
			Material = Enum.Material.Basalt,
			Color = STONE,
			Parent = model,
		})
	end

	-- Skull-topped banner poles lining the road.
	for _, pole in {
		Vector3.new(-10, 0, 70),
		Vector3.new(10, 0, 104),
		Vector3.new(-10, 0, 138),
		Vector3.new(10, 0, 166),
	} do
		part({
			Name = "SpikePole",
			Size = Vector3.new(0.9, 14, 0.9),
			Position = pole + Vector3.new(0, 7, 0),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(40, 34, 32),
			Parent = model,
		})
		part({
			Name = "PoleSkull",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6),
			Position = pole + Vector3.new(0, 15, 0),
			Material = Enum.Material.Limestone,
			Color = BONE,
			Parent = model,
		})
	end

	-- Torii gate marking the entrance road.
	for _, side in { -1, 1 } do
		part({
			Name = "ToriiPillar",
			Size = Vector3.new(5, 32, 5),
			Position = Vector3.new(17 * side, 16, 186),
			Material = Enum.Material.Wood,
			Color = TORII_RED,
			Parent = model,
		})
	end
	part({
		Name = "ToriiBeam",
		Size = Vector3.new(46, 4, 6),
		Position = Vector3.new(0, 30, 186),
		Material = Enum.Material.Wood,
		Color = TORII_RED,
		Parent = model,
	})
	part({
		Name = "ToriiTop",
		Size = Vector3.new(56, 5, 8),
		Position = Vector3.new(0, 36, 186),
		Material = Enum.Material.Wood,
		Color = DARK,
		Parent = model,
	})

	-- Wooden port stretching into the sea past the torii (scenery).
	for i = 0, 9 do
		part({
			Name = "DockPlank",
			Size = Vector3.new(12, 1, 6),
			Position = Vector3.new(0, 1, 226 + i * 6.5),
			Material = Enum.Material.WoodPlanks,
			Color = WOOD_WARM,
			Parent = model,
		})
		if i % 3 == 0 then
			for _, side in { -1, 1 } do
				part({
					Name = "DockPost",
					Size = Vector3.new(1.4, 14, 1.4),
					Position = Vector3.new(6.5 * side, -4, 226 + i * 6.5),
					Material = Enum.Material.Wood,
					Color = WOOD_DARK,
					Parent = model,
				})
			end
		end
	end
	lantern(model, Vector3.new(5, 1.5, 284))
	-- A moored rowboat.
	part({
		Name = "BoatHull",
		Size = Vector3.new(6, 3, 14),
		Position = Vector3.new(14, -3, 274),
		Rotation = Vector3.new(0, 8, 0),
		Material = Enum.Material.WoodPlanks,
		Color = WOOD_DARK,
		Parent = model,
	})
	for _, offset in { -3.5, 2 } do
		part({
			Name = "BoatBench",
			Size = Vector3.new(5, 0.6, 1.6),
			Position = Vector3.new(14, -1.4, 274 + offset),
			Rotation = Vector3.new(0, 8, 0),
			Material = Enum.Material.Wood,
			Color = WOOD_WARM,
			Parent = model,
		})
	end

	-- Dead trees.
	for _, spot in {
		Vector3.new(-120, 0, 55),
		Vector3.new(-165, 0, 125),
		Vector3.new(115, 0, 155),
		Vector3.new(165, 0, 95),
		Vector3.new(-95, 0, -60),
		Vector3.new(-150, 0, -95),
		Vector3.new(100, 0, -165),
		Vector3.new(60, 0, 190),
	} do
		deadTree(model, spot, math.random(11, 17))
	end

	-- Scattered boulders for cover (kept clear of road, plaza & buildings).
	local placed = 0
	while placed < 14 do
		local angle = math.rad(math.random(0, 359))
		local radius = math.random(92, 200)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local nearMansion = math.abs(x - 145) < 70 and math.abs(z + 35) < 60
		local nearSkull = z < -55 and math.abs(x) < 100
		local nearRoad = math.abs(x) < 14 and z > 50
		if not (nearMansion or nearSkull or nearRoad) then
			local size = math.random(5, 13)
			part({
				Name = "Boulder",
				Size = Vector3.new(size, size * 0.8, size),
				Position = Vector3.new(x, size * 0.3, z),
				Rotation = Vector3.new(math.random(-15, 15), math.random(0, 359), math.random(-15, 15)),
				Material = Enum.Material.Rock,
				Color = GROUND,
				Parent = model,
			})
			placed += 1
		end
	end

	model.Parent = parent
end

-- ========================================================================
-- The fighting plaza
-- ========================================================================

local function buildPlaza(parent)
	local model = Instance.new("Model")
	model.Name = "Plaza"

	-- Raised so its surface clears the voxel terrain (top at y = 1.5).
	part({
		Name = "PlazaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 118, 118),
		Position = Vector3.new(0, 0, 0),
		Rotation = Vector3.new(0, 0, 90),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(82, 82, 92),
		Parent = model,
	})
	part({ -- dark center emblem
		Name = "PlazaEmblem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 26, 26),
		Position = Vector3.new(0, 1.56, 0),
		Rotation = Vector3.new(0, 0, 90),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(52, 52, 62),
		Parent = model,
	})

	-- Kerb stones ringing the plaza.
	for i = 1, 14 do
		local angle = math.rad(i * (360 / 14))
		part({
			Name = "PlazaKerb",
			Size = Vector3.new(11, 1.8, 4),
			Position = Vector3.new(math.cos(angle) * 59, 1.2, math.sin(angle) * 59),
			Rotation = Vector3.new(0, -math.deg(angle) + 90, 0),
			Material = Enum.Material.Cobblestone,
			Color = STONE,
			Parent = model,
		})
	end

	-- Lanterns ringing the arena.
	for i = 1, 8 do
		local angle = math.rad(i * 45 + 22.5)
		lantern(model, Vector3.new(math.cos(angle) * 66, 0, math.sin(angle) * 66))
	end

	model.Parent = parent
end

-- ========================================================================
-- Sky: the full moon behind the skull
-- ========================================================================

local function buildSky(parent)
	local moon = part({
		Name = "Moon",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(300, 300, 300),
		Position = Vector3.new(0, 380, -950),
		Material = Enum.Material.Neon,
		Color = MOON,
		CanCollide = false,
		Parent = parent,
	})
	part({
		Name = "MoonHalo",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(380, 380, 380),
		Position = moon.Position,
		Material = Enum.Material.Neon,
		Color = MOON,
		Transparency = 0.88,
		CanCollide = false,
		Parent = parent,
	})
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

	buildTerrain()
	buildPlaza(arena)
	buildSkull(arena)
	buildMansion(arena)
	buildVillage(arena)
	buildSky(arena)

	-- Invisible border walls (inside the island's coastline).
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

	-- Kill plane far below the seabed.
	local killPlane = part({
		Name = "KillPlane",
		Size = Vector3.new(2000, 4, 2000),
		Position = Vector3.new(0, -90, 0),
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
		spawn.Position = Vector3.new(math.cos(angle) * 45, 2.5, math.sin(angle) * 45)
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Transparency = 1
		spawn.Neutral = true
		spawn.Duration = 0 -- spawn protection is handled by the combat server
		spawn.Parent = arena
	end

	arena.Parent = workspace

	-- Full-moon Onigashima night + cinematic grading.
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.4
	Lighting.ExposureCompensation = 0.2
	Lighting.OutdoorAmbient = Color3.fromRGB(88, 96, 132)
	Lighting.Ambient = Color3.fromRGB(48, 48, 64)
	Lighting.GlobalShadows = true

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.34
		atmosphere.Haze = 2.2
		atmosphere.Color = Color3.fromRGB(150, 138, 170)
		atmosphere.Decay = Color3.fromRGB(66, 60, 96)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.55
		bloom.Threshold = 1.1
		bloom.Size = 40
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local grading = Instance.new("ColorCorrectionEffect")
		grading.Contrast = 0.06
		grading.Saturation = -0.08
		grading.TintColor = Color3.fromRGB(235, 240, 255)
		grading.Parent = Lighting
	end
end

return MapBuilder
