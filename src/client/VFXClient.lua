--[[
	VFXClient.lua
	High-end procedural combat visuals + procedural character animation.

	Everything is generated at runtime (no uploaded assets required):
	  - real arm-thrust posing by layering Motor6D C0 offsets over the idle
	    animation, so Luffy actually winds up and throws his punches
	  - rubber arms that launch from the hand with trails and Haki coating
	  - impact frames: flash, shockwave rings, sparks, dust, ground cracks
	  - "hitstop" camera punch + FOV kick + screen flash on heavy blows
	  - speed lines, charge auras, afterimages, Conqueror's lightning

	Driven entirely by the server's VFX RemoteEvent; every effect name the
	server fires has a handler in the Effects table below.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local DEFAULT_FOV = 70

-- Palette ----------------------------------------------------------------
local RUBBER = Color3.fromRGB(245, 205, 170)
local HAKI = Color3.fromRGB(22, 20, 28)         -- Armament Haki black
local HAKI_EDGE = Color3.fromRGB(150, 70, 255)  -- Conqueror lightning
local GEAR5 = Color3.fromRGB(255, 255, 255)
local GEAR5_RIM = Color3.fromRGB(255, 220, 240)
local TOON = Color3.fromRGB(255, 130, 200)
local GOLD = Color3.fromRGB(255, 225, 150)
local IMPACT_YELLOW = Color3.fromRGB(255, 240, 150)

local VFXClient = {}

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "CombatEffects"
effectsFolder.Parent = workspace

-- Per-character state.
local gear5Emitters = {}
local rubberHighlights = {}
local blockHighlights = {}
local baseC0 = setmetatable({}, { __mode = "k" }) -- memoized rest pose per Motor6D
local motorCache = setmetatable({}, { __mode = "k" }) -- [character][side] = Motor6D

-- Screen flash overlay (created lazily).
local flashFrame

-- ========================================================================
-- Core helpers
-- ========================================================================

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in props do
		part[key] = value
	end
	part.Parent = effectsFolder
	return part
end

local function tween(instance, time, props, style, dir)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function attachment(part, offset)
	local a = Instance.new("Attachment")
	a.Position = offset or Vector3.zero
	a.Parent = part
	return a
end

local function playSound(soundId, parent, volume, pitch)
	if not soundId or soundId == 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. soundId
	sound.Volume = volume or 1
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = parent or workspace
	sound:Play()
	Debris:AddItem(sound, 6)
end

local function root(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getPart(character, names)
	if not character then
		return nil
	end
	for _, name in names do
		local p = character:FindFirstChild(name)
		if p then
			return p
		end
	end
	return nil
end

-- The character's hand (R15), falling back to arm (R6) then root.
local function handPart(character, side)
	return getPart(character, { side .. "Hand", side .. " Arm", "HumanoidRootPart" })
end

local function isLocal(character)
	return character and character == LocalPlayer.Character
end

local function distanceFromLocal(position)
	local r = root(LocalPlayer.Character)
	return r and (r.Position - position).Magnitude or math.huge
end

-- ========================================================================
-- Camera juice
-- ========================================================================

local function shake(origin, intensity, duration)
	local falloff = math.clamp(1 - distanceFromLocal(origin) / 130, 0, 1)
	intensity *= falloff
	if intensity <= 0.01 then
		return
	end
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			local decay = 1 - elapsed / duration
			Camera.CFrame *= CFrame.new(
				(math.random() - 0.5) * 2 * intensity * decay,
				(math.random() - 0.5) * 2 * intensity * decay,
				0
			) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.02 * intensity * decay)
		end
	end)
end

-- Quick punch-in then ease-out of the FOV; scaled by distance.
local function fovPunch(origin, amount, duration)
	local falloff = math.clamp(1 - distanceFromLocal(origin) / 110, 0, 1)
	amount *= falloff
	if amount <= 0.1 then
		return
	end
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			local p = elapsed / duration
			-- fast dip in the first 20%, smooth return after.
			local curve = p < 0.2 and (p / 0.2) or (1 - (p - 0.2) / 0.8)
			Camera.FieldOfView = DEFAULT_FOV - amount * curve
		end
		Camera.FieldOfView = DEFAULT_FOV
	end)
end

-- Simulated hitstop: a single-frame white/color pop on the screen edges.
local function screenFlash(color, maxAlpha, duration)
	if not flashFrame then
		local gui = Instance.new("ScreenGui")
		gui.Name = "CombatFlash"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 50
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		flashFrame = Instance.new("Frame")
		flashFrame.Size = UDim2.fromScale(1, 1)
		flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		flashFrame.BackgroundTransparency = 1
		flashFrame.BorderSizePixel = 0
		flashFrame.Parent = gui
	end
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - maxAlpha
	tween(flashFrame, duration, { BackgroundTransparency = 1 })
end

-- ========================================================================
-- Effect primitives
-- ========================================================================

local function addTrail(part, color, lifetime, width)
	local a0 = attachment(part, Vector3.new(0, (width or 1), 0))
	local a1 = attachment(part, Vector3.new(0, -(width or 1), 0))
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = lifetime or 0.25
	trail.LightEmission = 0.6
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = part
	return trail
end

local function shockwave(position, maxSize, color, time, thickness)
	local ring = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness or 0.5, 2, 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	tween(ring, time, { Size = Vector3.new(thickness or 0.5, maxSize, maxSize), Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(ring, time + 0.1)
end

-- Flat expanding energy disc on the ground (for slams / activations).
local function groundDisc(position, maxRadius, color, time)
	local disc = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2, 2),
		CFrame = CFrame.new(position.X, position.Y - 2.5, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})
	tween(disc, time, { Size = Vector3.new(0.6, maxRadius, maxRadius), Transparency = 1 })
	Debris:AddItem(disc, time + 0.1)
end

local function sparks(position, color, count, speed, size)
	local holder = makePart({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size or 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(0.25, 0.55)
	emitter.Speed = NumberRange.new(speed or 25)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Enabled = false
	emitter.Parent = holder
	emitter:Emit(count or 24)
	Debris:AddItem(holder, 1)
end

local function dust(position, color, count)
	local holder = makePart({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(140, 130, 120))
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(1, 9),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Enabled = false
	emitter.Parent = holder
	emitter:Emit(count or 14)
	Debris:AddItem(holder, 1.5)
end

-- Cracked shards radiating out on the ground.
local function groundCrack(position, radius, color)
	for i = 1, 8 do
		local angle = math.rad(i * 45 + math.random(-12, 12))
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local length = radius * (0.6 + math.random() * 0.5)
		local shard = makePart({
			Size = Vector3.new(1, 0.4, length),
			CFrame = CFrame.lookAt(position - Vector3.new(0, 2.4, 0) + dir * length / 2, position + dir),
			Color = color or Color3.fromRGB(60, 55, 50),
			Material = Enum.Material.Slate,
			Transparency = 0.1,
		})
		tween(shard, 0.7, { Transparency = 1 }, Enum.EasingStyle.Linear)
		Debris:AddItem(shard, 0.8)
	end
end

-- Flying debris chunks kicked up by a big impact.
local function debris(position, color, count)
	for _ = 1, count or 6 do
		local chunk = makePart({
			Anchored = false,
			CanCollide = false,
			Material = Enum.Material.Slate,
			Color = color or Color3.fromRGB(70, 65, 60),
			Size = Vector3.new(1, 1, 1) * (0.6 + math.random()),
			CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
		})
		chunk.AssemblyLinearVelocity = Vector3.new(
			(math.random() - 0.5) * 40,
			25 + math.random() * 25,
			(math.random() - 0.5) * 40
		)
		tween(chunk, 1, { Transparency = 1 })
		Debris:AddItem(chunk, 1.1)
	end
end

-- Converging speed-lines around a character (barrage feel).
local function speedLines(character, duration, color)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local r = root(character)
			if not r then
				break
			end
			local angle = math.rad(math.random(0, 359))
			local far = r.Position + Vector3.new(math.cos(angle) * 14, math.random(-4, 6), math.sin(angle) * 14)
			local near = r.Position + Vector3.new(math.cos(angle) * 5, 0, math.sin(angle) * 5)
			local line = makePart({
				Size = Vector3.new(0.15, 0.15, (far - near).Magnitude),
				CFrame = CFrame.lookAt((far + near) / 2, far),
				Color = color,
				Transparency = 0.2,
			})
			tween(line, 0.12, { Transparency = 1 })
			Debris:AddItem(line, 0.15)
			elapsed += RunService.RenderStepped:Wait()
		end
	end)
end

-- Charge-in aura: particles flowing INTO a point during a windup.
local function chargeAura(getPos, duration, color)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local pos = getPos()
			if not pos then
				break
			end
			local angle = math.rad(math.random(0, 359))
			local start = pos + Vector3.new(math.cos(angle) * 10, math.random(-5, 5), math.sin(angle) * 10)
			local mote = makePart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.1, 1.1, 1.1),
				CFrame = CFrame.new(start),
				Color = color,
				Transparency = 0.1,
			})
			tween(mote, 0.3, { CFrame = CFrame.new(pos), Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(mote, 0.35)
			elapsed += task.wait(0.04)
		end
	end)
end

-- Full impact package.
local function impact(position, opts)
	opts = opts or {}
	local color = opts.Color or IMPACT_YELLOW
	local scale = opts.Scale or 1

	-- White-hot flash sphere.
	local flash = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2) * scale,
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = 0.05,
	})
	tween(flash, 0.18, { Size = Vector3.new(7, 7, 7) * scale, Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(flash, 0.25)

	shockwave(position, 14 * scale, color, 0.35, 0.5)
	sparks(position, color, math.floor(18 * scale), 22 * scale, 1 * scale)

	if opts.Heavy then
		shockwave(position, 26 * scale, GEAR5, 0.5, 0.8)
		dust(position, opts.DustColor, 18)
		groundCrack(position, 10 * scale, opts.CrackColor)
		debris(position, opts.CrackColor, 6)
		shake(position, 0.9 * scale, 0.3)
		fovPunch(position, 6 * scale, 0.22)
		if distanceFromLocal(position) < 40 then
			screenFlash(color, 0.25, 0.18)
		end
	else
		shake(position, 0.35, 0.18)
	end
end

-- ========================================================================
-- Procedural character animation (Motor6D posing)
-- ========================================================================

local function getMotor(character, side)
	if not character then
		return nil
	end
	local cache = motorCache[character]
	if cache and cache[side] and cache[side].Parent then
		return cache[side]
	end
	if not cache then
		cache = {}
		motorCache[character] = cache
	end
	-- R15 uses "RightShoulder"; R6 uses "Right Shoulder".
	for _, name in { side .. "Shoulder", side .. " Shoulder" } do
		for _, d in character:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == name then
				cache[side] = d
				return d
			end
		end
	end
	return nil
end

local function restPose(motor)
	if not baseC0[motor] then
		baseC0[motor] = motor.C0
	end
	return baseC0[motor]
end

-- Thrust an arm forward (punch), then let it ease back to the idle.
-- `power` 0..1 scales how far the arm extends.
local function punchArm(character, side, outTime, hold, power)
	local motor = getMotor(character, side)
	if not motor then
		return
	end
	power = power or 1
	local base = restPose(motor)
	-- Raise + rotate the upper arm so it points forward.
	local posed = base * CFrame.Angles(math.rad(-95 * power), 0, math.rad((side == "Right" and -8 or 8) * power))
	tween(motor, outTime or 0.08, { C0 = posed }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay((outTime or 0.08) + (hold or 0.06), function()
		if motor.Parent then
			tween(motor, 0.22, { C0 = base }, Enum.EasingStyle.Quad)
		end
	end)
end

-- Both arms forward (Bazooka / Bajrang).
local function pushBothArms(character, outTime, hold)
	punchArm(character, "Right", outTime, hold, 1)
	punchArm(character, "Left", outTime, hold, 1)
end

-- A faint afterimage clone of the torso+arms (dash / burst).
local function afterImage(character, color, life)
	local r = root(character)
	if not r then
		return
	end
	local ghost = makePart({
		Size = Vector3.new(2.5, 5, 1.5),
		CFrame = r.CFrame,
		Color = color or GEAR5,
		Material = Enum.Material.ForceField,
		Transparency = 0.4,
	})
	tween(ghost, life or 0.35, { Transparency = 1 })
	Debris:AddItem(ghost, (life or 0.35) + 0.05)
end

-- ========================================================================
-- The signature rubber arm
-- ========================================================================

-- A stretching rubber arm from the character's hand reaching `range` studs
-- along its look vector. Returns nothing; self-cleans.
local function rubberArm(character, side, range, thickness, color, haki, outTime, hold)
	local hand = handPart(character, side)
	local r = root(character)
	if not hand or not r then
		return
	end
	local origin = CFrame.new(hand.Position) * (r.CFrame - r.CFrame.Position)
	local armColor = haki and HAKI or color

	local arm = makePart({
		Size = Vector3.new(thickness, thickness, 2),
		CFrame = origin * CFrame.new(0, 0, -1),
		Color = armColor,
		Material = haki and Enum.Material.Glass or Enum.Material.SmoothPlastic,
		Reflectance = haki and 0.35 or 0,
		Transparency = 0,
	})
	local fist = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(thickness * 1.9, thickness * 1.9, thickness * 1.9),
		CFrame = origin * CFrame.new(0, 0, -2),
		Color = armColor,
		Material = haki and Enum.Material.Glass or Enum.Material.SmoothPlastic,
		Reflectance = haki and 0.35 or 0,
	})
	addTrail(fist, haki and HAKI_EDGE or color, 0.2, thickness)

	if haki then
		-- Conqueror lightning crackling along the arm.
		local bolt = makePart({
			Size = Vector3.new(thickness * 1.3, thickness * 1.3, 2),
			CFrame = arm.CFrame,
			Color = HAKI_EDGE,
			Transparency = 0.4,
		})
		tween(bolt, outTime + 0.15, {
			Size = Vector3.new(thickness * 1.3, thickness * 1.3, range),
			CFrame = origin * CFrame.new(0, 0, -range / 2),
			Transparency = 1,
		}, Enum.EasingStyle.Back)
		Debris:AddItem(bolt, outTime + 0.3)
	end

	tween(arm, outTime, {
		Size = Vector3.new(thickness, thickness, range),
		CFrame = origin * CFrame.new(0, 0, -range / 2),
	}, Enum.EasingStyle.Back)
	tween(fist, outTime, { CFrame = origin * CFrame.new(0, 0, -range) }, Enum.EasingStyle.Back)

	task.delay(outTime + (hold or 0.05), function()
		tween(arm, 0.14, {
			Size = Vector3.new(thickness, thickness, 2),
			CFrame = origin * CFrame.new(0, 0, -1),
			Transparency = 1,
		})
		tween(fist, 0.14, { CFrame = origin * CFrame.new(0, 0, -2), Transparency = 1 })
	end)
	Debris:AddItem(arm, outTime + 0.5)
	Debris:AddItem(fist, outTime + 0.5)
	return origin
end

-- A barrage of rubber fists inside a cone in front of the character.
local function fistFlurry(character, duration, range, color, haki, size, perSecond)
	task.spawn(function()
		local elapsed = 0
		local side = "Right"
		while elapsed < duration do
			local r = root(character)
			if not r then
				break
			end
			punchArm(character, side, 0.05, 0.02, 0.8)
			side = side == "Right" and "Left" or "Right"

			local origin = r.CFrame
			local dist = math.random(4, math.max(5, math.floor(range)))
			local fist = makePart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				Color = haki and HAKI or color,
				Material = haki and Enum.Material.Glass or Enum.Material.Neon,
				Reflectance = haki and 0.3 or 0,
				Transparency = 0.05,
				CFrame = origin * CFrame.new((math.random() - 0.5) * 7, (math.random() - 0.5) * 5, -1),
			})
			addTrail(fist, haki and HAKI_EDGE or color, 0.12, size * 0.5)
			tween(fist, 0.1, {
				CFrame = origin * CFrame.new((math.random() - 0.5) * 6, (math.random() - 0.5) * 4, -dist),
				Transparency = 1,
			}, Enum.EasingStyle.Quint)
			Debris:AddItem(fist, 0.16)
			playSound(Config.Sounds.Punch, fist, 0.35, 0.9 + math.random() * 0.4)
			elapsed += task.wait(1 / perSecond)
		end
	end)
end

-- ========================================================================
-- Effect handlers
-- ========================================================================

local Effects = {}

function Effects.HitImpact(data)
	impact(data.Position, {
		Color = data.Heavy and GEAR5 or IMPACT_YELLOW,
		Scale = data.Heavy and 1.4 or 0.8,
		Heavy = data.Heavy,
	})
	playSound(data.Heavy and Config.Sounds.HeavyImpact or Config.Sounds.Punch, workspace, data.Heavy and 1 or 0.6)
end

function Effects.M1Swing(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	punchArm(data.Character, side, 0.06, 0.05, 1)
	rubberArm(data.Character, side, Config.M1.Range, 0.9, RUBBER, data.Index >= Config.M1.ComboHits, 0.07)
	if isLocal(data.Character) then
		fovPunch(root(data.Character) and root(data.Character).Position or Vector3.zero, 2, 0.15)
	end
end

function Effects.Pistol(data)
	local character = data.Character
	local cfg = Config.Base[1]
	local r = root(character)
	if not r then
		return
	end
	playSound(Config.Sounds.Stretch, r, 1)

	-- Wind-up: draw the fist back with a charge aura.
	punchArm(character, "Right", cfg.WindUp * 0.7, cfg.WindUp * 0.3, -0.4)
	chargeAura(function()
		local hand = handPart(character, "Right")
		return hand and hand.Position
	end, cfg.WindUp, RUBBER)

	task.delay(cfg.WindUp - 0.05, function()
		if not root(character) then
			return
		end
		punchArm(character, "Right", 0.07, 0.14, 1.1)
		local origin = rubberArm(character, "Right", data.Range, 1.5, RUBBER, false, 0.1, 0.14)
		if origin then
			impact(origin.Position + origin.LookVector * data.Range, { Color = RUBBER, Scale = 1.1, Heavy = true, CrackColor = Color3.fromRGB(90, 70, 55) })
		end
		shake(r.Position, 0.5, 0.2)
	end)
end

function Effects.Bazooka(data)
	local character = data.Character
	local cfg = Config.Base[2]
	local r = root(character)
	if not r then
		return
	end

	punchArm(character, "Right", cfg.WindUp * 0.6, cfg.WindUp * 0.4, -0.5)
	punchArm(character, "Left", cfg.WindUp * 0.6, cfg.WindUp * 0.4, -0.5)
	chargeAura(function()
		return r.Position + r.CFrame.LookVector * 2
	end, cfg.WindUp, RUBBER)

	task.delay(cfg.WindUp - 0.05, function()
		if not root(character) then
			return
		end
		pushBothArms(character, 0.08, 0.16)
		rubberArm(character, "Right", cfg.Range, 1.7, RUBBER, false, 0.09, 0.16)
		rubberArm(character, "Left", cfg.Range, 1.7, RUBBER, false, 0.09, 0.16)
		local hitPos = r.Position + r.CFrame.LookVector * cfg.Range
		impact(hitPos, { Color = GEAR5, Scale = 1.6, Heavy = true, CrackColor = Color3.fromRGB(90, 70, 55) })
		groundDisc(r.Position, 34, RUBBER, 0.45)
	end)
end

function Effects.Gatling(data)
	fistFlurry(data.Character, (data.Duration or 1.6) + 0.3, data.Range or 15, RUBBER, false, 1.8, 20)
	speedLines(data.Character, (data.Duration or 1.6) + 0.3, RUBBER)
	local r = root(data.Character)
	if r then
		shake(r.Position, 0.4, data.Duration or 1.6)
	end
end

function Effects.DawnGatling(data)
	fistFlurry(data.Character, (data.Duration or 1.6) + 0.3, data.Range or 22, GEAR5, false, 2.6, 34)
	speedLines(data.Character, (data.Duration or 1.6) + 0.3, GEAR5)
	local r = root(data.Character)
	if r then
		-- The many-arms illusion: extra wide rubber arms firing outward.
		task.spawn(function()
			local elapsed = 0
			while elapsed < (data.Duration or 1.6) do
				rubberArm(data.Character, math.random() < 0.5 and "Right" or "Left", data.Range or 22, 1.4, GEAR5, false, 0.12, 0.02)
				elapsed += task.wait(0.09)
			end
		end)
		shake(r.Position, 0.6, data.Duration or 1.6)
		fovPunch(r.Position, 3, 0.4)
	end
end

function Effects.RubberCombo(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		rubberArm(character, "Right", Config.Base[4].Range, 1, RUBBER, false, 0.1)
		return
	end
	afterImage(character, RUBBER, 0.4)
	groundDisc(r.Position, 12, RUBBER, 0.3)
	fistFlurry(character, data.Duration or 1.3, 6, RUBBER, false, 1.5, 16)
	speedLines(character, data.Duration or 1.3, RUBBER)
end

function Effects.ToonForce(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		rubberArm(character, "Right", Config.Gear5[3].Range, 1.3, GEAR5, false, 0.1)
		return
	end
	afterImage(character, TOON, 0.5)
	groundDisc(r.Position, 16, TOON, 0.35)
	-- Cartoon-bright barrage with pink pops.
	fistFlurry(character, data.Duration or 1.6, 7, GEAR5, false, 1.8, 20)
	speedLines(character, data.Duration or 1.6, TOON)
	task.spawn(function()
		local elapsed = 0
		while elapsed < (data.Duration or 1.6) do
			local rr = root(character)
			if rr then
				sparks(rr.Position + rr.CFrame.LookVector * math.random(3, 8) + Vector3.new(0, math.random(-2, 3), 0), TOON, 6, 14, 1.4)
			end
			elapsed += task.wait(0.12)
		end
	end)
end

function Effects.BajrangGun(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	playSound(Config.Sounds.DrumsOfLiberation, r, 1)
	local windUp = data.WindUp or 1.2
	local range = data.Range or 70
	local fistSize = 34

	-- Wind-up: raise both arms overhead, giant fist inflates behind Luffy
	-- as clouds/energy pour in.
	punchArm(character, "Right", windUp * 0.5, windUp * 0.5, -0.7)
	punchArm(character, "Left", windUp * 0.5, windUp * 0.5, -0.7)

	local fist = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		CFrame = r.CFrame * CFrame.new(0, 16, 24),
		Color = GEAR5,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.05,
	})
	addTrail(fist, GEAR5_RIM, 0.4, fistSize * 0.4)
	local knuckles = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		CFrame = fist.CFrame,
		Color = GEAR5_RIM,
		Transparency = 0.6,
	})
	tween(fist, windUp, { Size = Vector3.new(fistSize, fistSize, fistSize) }, Enum.EasingStyle.Sine)
	tween(knuckles, windUp, { Size = Vector3.new(fistSize * 1.15, fistSize * 1.15, fistSize * 1.15), Transparency = 0.85 }, Enum.EasingStyle.Sine)
	chargeAura(function()
		return fist.Position
	end, windUp, GEAR5)
	shake(r.Position, 0.3, windUp)

	task.delay(windUp, function()
		local rNow = root(character)
		local launch = rNow and rNow.CFrame or r.CFrame
		pushBothArms(character, 0.1, 0.4)
		fist.CFrame = launch * CFrame.new(0, 8, 8)
		knuckles.CFrame = fist.CFrame
		tween(fist, 0.3, { CFrame = launch * CFrame.new(0, 6, -range) }, Enum.EasingStyle.Quart)
		tween(knuckles, 0.3, { CFrame = launch * CFrame.new(0, 6, -range) }, Enum.EasingStyle.Quart)
		shake(launch.Position, 2.2, 0.6)
		fovPunch(launch.Position, 10, 0.5)

		task.delay(0.3, function()
			local hitPos = fist.Position
			impact(hitPos, { Color = GEAR5, Scale = 3, Heavy = true, CrackColor = Color3.fromRGB(90, 70, 55) })
			shockwave(hitPos, 120, GEAR5, 0.8, 2)
			shockwave(hitPos, 80, GEAR5_RIM, 0.6, 1.4)
			sparks(hitPos, GEAR5, 80, 60, 3)
			debris(hitPos, Color3.fromRGB(80, 72, 66), 16)
			screenFlash(GEAR5, 0.4, 0.3)
			tween(fist, 0.4, { Transparency = 1, Size = Vector3.new(fistSize * 1.4, fistSize * 1.4, fistSize * 1.4) })
			tween(knuckles, 0.4, { Transparency = 1 })
		end)
	end)
	Debris:AddItem(fist, windUp + 1.6)
	Debris:AddItem(knuckles, windUp + 1.6)
end

function Effects.DrumsChannel(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	playSound(Config.Sounds.DrumsOfLiberation, r, 2)
	task.spawn(function()
		local beats = math.floor((data.Duration or 2.2) / 0.55)
		for _ = 1, beats do
			local rNow = root(character)
			if not rNow then
				break
			end
			-- Beat the chest: alternate arm slaps + a heartbeat ring.
			punchArm(character, "Right", 0.08, 0.05, 0.5)
			punchArm(character, "Left", 0.08, 0.05, 0.5)
			shockwave(rNow.Position, 20, GEAR5, 0.5, 1)
			groundDisc(rNow.Position, 18, GEAR5_RIM, 0.4)
			shake(rNow.Position, 0.45, 0.2)
			fovPunch(rNow.Position, 2, 0.2)
			task.wait(0.55)
		end
	end)
end

function Effects.Devour(data)
	local character = data.Character
	local targetRoot = root(data.Target)
	local r = root(character)
	if not r or not targetRoot then
		return
	end
	local mouthPos = targetRoot.Position

	local head = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(r.Position + Vector3.new(0, 2, 0)),
		Color = RUBBER,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.05,
	})
	local jaw = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		CFrame = head.CFrame,
		Color = Color3.fromRGB(120, 40, 40),
		Transparency = 0.2,
	})
	tween(head, 0.35, { Size = Vector3.new(24, 24, 24), CFrame = CFrame.new(mouthPos) }, Enum.EasingStyle.Back)
	tween(jaw, 0.35, { Size = Vector3.new(20, 10, 20), CFrame = CFrame.new(mouthPos + Vector3.new(0, -6, 0)) }, Enum.EasingStyle.Back)

	task.delay(0.45, function()
		playSound(Config.Sounds.Gulp, head, 2)
		impact(mouthPos, { Color = GEAR5, Scale = 2.4, Heavy = true })
		shockwave(mouthPos, 46, RUBBER, 0.5, 1.5)
		screenFlash(RUBBER, 0.3, 0.25)
		tween(head, 0.25, { Size = Vector3.new(1, 1, 1), Transparency = 1 })
		tween(jaw, 0.25, { Transparency = 1 })
	end)
	Debris:AddItem(head, 1.2)
	Debris:AddItem(jaw, 1.2)
end

function Effects.DevourWhiff(data)
	local r = root(data.Character)
	if r then
		shockwave(r.Position + r.CFrame.LookVector * 5, 12, RUBBER, 0.3, 0.6)
	end
end

function Effects.Dash(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	afterImage(character, GEAR5, 0.3)
	local direction = data.Direction or r.CFrame.LookVector
	local streak = makePart({
		Size = Vector3.new(1.5, 1.5, 9),
		CFrame = CFrame.lookAt(r.Position - direction * 4, r.Position - direction * 12),
		Color = Color3.new(1, 1, 1),
		Transparency = 0.35,
	})
	tween(streak, 0.25, { Size = Vector3.new(0.2, 0.2, 16), Transparency = 1 })
	Debris:AddItem(streak, 0.3)
	dust(r.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(150, 140, 130), 8)
end

function Effects.Gear5Start(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	playSound(Config.Sounds.Gear5Activate, r, 2)

	-- Giant liberation shockwaves + pillar of light.
	shockwave(r.Position, 70, GEAR5, 0.9, 2)
	shockwave(r.Position, 45, GEAR5_RIM, 0.7, 1.4)
	groundDisc(r.Position, 60, GEAR5, 0.7)
	sparks(r.Position, GEAR5, 70, 55, 2.5)
	shake(r.Position, 1.4, 0.6)
	fovPunch(r.Position, 12, 0.6)
	if isLocal(character) then
		screenFlash(GEAR5, 0.6, 0.5)
	end

	local pillar = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 1, 1),
		CFrame = CFrame.new(r.Position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GEAR5,
		Transparency = 0.2,
	})
	tween(pillar, 0.5, { Size = Vector3.new(200, 12, 12), Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(pillar, 0.6)

	-- Persistent white steam-clouds + rim glow while Gear 5 lasts.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(GEAR5)
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.45, 1)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Rate = 30
	emitter.Speed = NumberRange.new(3, 7)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = r
	gear5Emitters[character] = emitter

	local highlight = character:FindFirstChild("Gear5Highlight")
	if highlight and highlight:IsA("Highlight") then
		-- server already added one; add a subtle pulse.
		task.spawn(function()
			while highlight.Parent and character:GetAttribute("Gear5") do
				tween(highlight, 0.6, { FillTransparency = 0.2 })
				task.wait(0.6)
				tween(highlight, 0.6, { FillTransparency = 0.45 })
				task.wait(0.6)
			end
		end)
	end
end

function Effects.Gear5End(data)
	local emitter = gear5Emitters[data.Character]
	if emitter then
		emitter.Enabled = false
		Debris:AddItem(emitter, 1.5)
		gear5Emitters[data.Character] = nil
	end
	local r = root(data.Character)
	if r then
		shockwave(r.Position, 24, GEAR5, 0.5, 1)
		dust(r.Position, GEAR5, 12)
	end
end

function Effects.RubberizeStart(data)
	local character = data.Character
	if rubberHighlights[character] then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = TOON
	highlight.OutlineColor = TOON
	highlight.FillTransparency = 0.5
	highlight.Parent = character
	rubberHighlights[character] = highlight
	task.spawn(function()
		while rubberHighlights[character] == highlight and highlight.Parent do
			tween(highlight, 0.25, { FillTransparency = 0.2 })
			task.wait(0.25)
			tween(highlight, 0.25, { FillTransparency = 0.6 })
			task.wait(0.25)
		end
	end)
end

function Effects.RubberizeEnd(data)
	local highlight = rubberHighlights[data.Character]
	if highlight then
		highlight:Destroy()
		rubberHighlights[data.Character] = nil
	end
end

function Effects.BlockStart(data)
	local character = data.Character
	if blockHighlights[character] then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(180, 210, 255)
	highlight.OutlineColor = Color3.fromRGB(200, 225, 255)
	highlight.FillTransparency = 0.75
	highlight.Parent = character
	blockHighlights[character] = highlight
end

function Effects.BlockEnd(data)
	local highlight = blockHighlights[data.Character]
	if highlight then
		highlight:Destroy()
		blockHighlights[data.Character] = nil
	end
end

function Effects.BlockHit(data)
	sparks(data.Position, Color3.fromRGB(180, 210, 255), 12, 18, 1)
	shockwave(data.Position, 8, Color3.fromRGB(180, 210, 255), 0.25, 0.5)
	playSound(Config.Sounds.Punch, workspace, 0.5, 1.4)
end

function Effects.GuardBreak(data)
	impact(data.Position, { Color = Color3.fromRGB(255, 90, 90), Scale = 1.3, Heavy = true })
	playSound(Config.Sounds.HeavyImpact, workspace, 1.2)
end

-- ========================================================================
-- Wiring
-- ========================================================================

function VFXClient.Init()
	Camera.FieldOfView = DEFAULT_FOV
	Remotes.get("VFX").OnClientEvent:Connect(function(effectName, data)
		local effect = Effects[effectName]
		if effect and type(data) == "table" then
			task.spawn(effect, data)
		end
	end)
end

return VFXClient
