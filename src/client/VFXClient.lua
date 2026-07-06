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
local BLADE = Color3.fromRGB(220, 224, 232)
local SLASH = Color3.fromRGB(205, 255, 232)   -- cool blade streak
local ASHURA_RED = Color3.fromRGB(190, 34, 46)
local ASHURA_DARK = Color3.fromRGB(24, 8, 12)
local AIR = Color3.fromRGB(200, 228, 255)      -- Sanji air-pressure kicks
local FIRE_ORANGE = Color3.fromRGB(255, 138, 36)
local FIRE_YELLOW = Color3.fromRGB(255, 208, 96)
local FIRE_DEEP = Color3.fromRGB(210, 60, 20)

local VFXClient = {}

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "CombatEffects"
effectsFolder.Parent = workspace

-- Per-character state.
local gear5Emitters = {}
local rubberHighlights = {}
local blockHighlights = {}
local ashuraAuras = {} -- [character] = true while the Ashura aura loop runs
local diableFires = {} -- [character] = { instances } for the Diable Jambe leg fire
local igniteFires = {} -- [character] = Fire instance for burn DoT
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
-- Keyframe animation engine
-- Poses the whole R15 rig (torso, head, both arms, both legs) through a
-- timeline of keyframes layered over the idle animation, so moves read as
-- real, exaggerated, goofy animation instead of a single static pose.
-- A "pose" maps joint names to CFrame offsets applied over the rest C0.
-- Joints: Root, Waist, Neck, RightShoulder, LeftShoulder, RightElbow,
--         LeftElbow, RightHip, LeftHip, RightKnee, LeftKnee.
-- ========================================================================

local jointCache = setmetatable({}, { __mode = "k" })

local function getJoint(character, name)
	if not character then
		return nil
	end
	local cache = jointCache[character]
	if cache and cache[name] and cache[name].Parent then
		return cache[name]
	end
	if not cache then
		cache = {}
		jointCache[character] = cache
	end
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			cache[name] = d
			return d
		end
	end
	return nil
end

-- Terse pose authoring: ra() = rotation in degrees, po() = position + rotation.
local function ra(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end
local function po(px, py, pz, rx, ry, rz)
	return CFrame.new(px or 0, py or 0, pz or 0) * ra(rx, ry, rz)
end

-- Tween a whole pose (jointName -> offset) over `time`.
local function poseCharacter(character, pose, time, style, dir)
	for name, offset in pose do
		local joint = getJoint(character, name)
		if joint then
			tween(joint, time, { C0 = restPose(joint) * offset }, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
		end
	end
end

local function settlePose(character, touched, time)
	for name in touched do
		local joint = getJoint(character, name)
		if joint then
			tween(joint, time or 0.22, { C0 = restPose(joint) }, Enum.EasingStyle.Quad)
		end
	end
end

-- Play an ordered list of keyframes:
--   { { t = seconds, pose = {...}, style = , dir = }, ... }
-- Runs in its own thread and eases back to rest at the end (unless holdLast).
local function playSequence(character, frames, holdLast)
	if not character then
		return
	end
	task.spawn(function()
		local touched = {}
		for _, frame in frames do
			if not character.Parent then
				return
			end
			for name in frame.pose do
				touched[name] = true
			end
			poseCharacter(character, frame.pose, frame.t, frame.style, frame.dir)
			task.wait(frame.t)
		end
		if not holdLast then
			settlePose(character, touched, 0.24)
		end
	end)
end

local BACK = Enum.EasingStyle.Back
local SINE = Enum.EasingStyle.Sine
local QUINT = Enum.EasingStyle.Quint

-- ========================================================================
-- Character animation library (signature, goofy full-body sequences)
-- ========================================================================

local Anims = {}

-- ---- Luffy: loose rubbery windmill arms + big rubber wind-ups -----------
function Anims.luffyM1(character, index)
	local right = index % 2 == 1
	playSequence(character, {
		{ t = 0.05, pose = {
			Waist = po(0, 0, 0, 6, right and -30 or 30, 0),
			[right and "RightShoulder" or "LeftShoulder"] = ra(-140, 0, right and -20 or 20),
			[right and "RightElbow" or "LeftElbow"] = ra(-30),
			Neck = ra(6, right and -12 or 12, 0),
		}, style = BACK },
		{ t = 0.1, pose = {
			Waist = po(0, 0, 0, 10, right and 26 or -26, 0),
			[right and "RightShoulder" or "LeftShoulder"] = ra(-108, 0, right and 8 or -8),
			[right and "RightElbow" or "LeftElbow"] = ra(0),
		}, style = QUINT },
	})
end

function Anims.luffyWindup(character, windup)
	playSequence(character, {
		-- Pull the arm way back, lean back, cheeks puff (goofy anticipation).
		{ t = windup * 0.6, pose = {
			Waist = po(0, -0.2, -0.4, -20, 40, 0),
			RightShoulder = ra(60, 0, -40),
			RightElbow = ra(-70),
			Neck = ra(-10, 20, 0),
			RightHip = ra(-14),
			LeftHip = ra(10),
		}, style = SINE },
		-- FIRE: whip the whole body forward.
		{ t = 0.08, pose = {
			Waist = po(0, 0, 0.2, 22, -20, 0),
			RightShoulder = ra(-100, 0, 6),
			RightElbow = ra(0),
			Neck = ra(12, -10, 0),
		}, style = BACK },
		{ t = 0.16, pose = {
			Waist = po(0, 0, 0, 10, -6, 0),
			RightShoulder = ra(-88),
		}, style = QUINT },
	})
end

function Anims.luffyBazooka(character, windup)
	playSequence(character, {
		{ t = windup * 0.6, pose = {
			Waist = po(0, -0.3, -0.5, -24, 0, 0),
			RightShoulder = ra(70, 0, -30),
			LeftShoulder = ra(70, 0, 30),
			RightElbow = ra(-80),
			LeftElbow = ra(-80),
			Neck = ra(-14, 0, 0),
			RightHip = ra(-20),
			LeftHip = ra(-20),
		}, style = SINE },
		{ t = 0.1, pose = {
			Waist = po(0, 0.2, 0.4, 26, 0, 0),
			RightShoulder = ra(-96, 0, 4),
			LeftShoulder = ra(-96, 0, -4),
			RightElbow = ra(0),
			LeftElbow = ra(0),
			Neck = ra(14, 0, 0),
		}, style = BACK },
		{ t = 0.18, pose = { Waist = po(0, 0, 0, 12, 0, 0) }, style = QUINT },
	})
end

-- ---- Zoro: bladed stances, shoulder-led slashes, three-sword spin -------
function Anims.zoroM1(character, index)
	local right = index % 2 == 1
	playSequence(character, {
		{ t = 0.05, pose = {
			Waist = po(0, 0, 0, 4, right and 34 or -34, 0),
			RightShoulder = ra(right and -70 or -30, 0, -18),
			LeftShoulder = ra(right and -30 or -70, 0, 18),
			Neck = ra(4, right and 14 or -14, 0),
			RightHip = ra(0, 0, -6),
		}, style = BACK },
		{ t = 0.11, pose = {
			Waist = po(0, 0, 0, 8, right and -30 or 30, 0),
			RightShoulder = ra(-96, 0, -20),
			LeftShoulder = ra(-96, 0, 20),
			Neck = ra(8, right and -12 or 12, 0),
		}, style = QUINT },
	})
end

function Anims.zoroSlash(character, windup)
	playSequence(character, {
		-- Draw the blades back into a wide stance.
		{ t = (windup or 0.3) * 0.6, pose = {
			Waist = po(0, 0, 0, -6, 50, 0),
			RightShoulder = ra(30, 0, -60),
			LeftShoulder = ra(-40, 0, 60),
			Neck = ra(0, 30, 0),
			RightHip = ra(0, 20, 0),
		}, style = SINE },
		-- Cross-slash through.
		{ t = 0.09, pose = {
			Waist = po(0, 0, 0, 10, -50, 0),
			RightShoulder = ra(-70, 0, 40),
			LeftShoulder = ra(-70, 0, -40),
			Neck = ra(6, -20, 0),
		}, style = BACK },
		{ t = 0.16, pose = { Waist = po(0, 0, 0, 6, -10, 0) }, style = QUINT },
	})
end

function Anims.zoroSpin(character, dur)
	-- Rapid full torso spin with arms flared out (Ul-Tora / Tatsumaki).
	local frames = {}
	local turns = math.max(2, math.floor((dur or 0.8) / 0.12))
	for i = 1, turns do
		table.insert(frames, {
			t = 0.12,
			pose = {
				Waist = ra(0, (i % 2 == 0) and 120 or -120, 0),
				RightShoulder = ra(-90, 0, 60),
				LeftShoulder = ra(-90, 0, -60),
				Neck = ra(8, 0, 0),
			},
			style = Enum.EasingStyle.Linear,
		})
	end
	playSequence(character, frames)
end

-- ---- Sanji: acrobatic one-legged spins + high kicks ---------------------
function Anims.sanjiM1(character, index)
	local right = index % 2 == 1
	playSequence(character, {
		{ t = 0.05, pose = {
			Waist = po(0, 0, 0, 8, right and -18 or 18, 0),
			[right and "RightHip" or "LeftHip"] = ra(-70, 0, right and -20 or 20),
			[right and "RightKnee" or "LeftKnee"] = ra(70),
			Neck = ra(6, 0, 0),
			RightShoulder = ra(0, 0, -30),
			LeftShoulder = ra(0, 0, 30),
		}, style = BACK },
		{ t = 0.1, pose = {
			[right and "RightHip" or "LeftHip"] = ra(-20, 0, 0),
			[right and "RightKnee" or "LeftKnee"] = ra(0),
			Waist = po(0, 0, 0, 4, 0, 0),
		}, style = QUINT },
	})
end

function Anims.sanjiHighKick(character, windup)
	playSequence(character, {
		-- Coil down onto one leg.
		{ t = (windup or 0.25) * 0.7, pose = {
			Waist = po(0, -0.3, 0, 14, 0, 0),
			RightHip = ra(30),
			RightKnee = ra(60),
			LeftHip = ra(-10),
			Neck = ra(-8, 0, 0),
			RightShoulder = ra(0, 0, -40),
			LeftShoulder = ra(0, 0, 40),
		}, style = SINE },
		-- Explode into a vertical axe kick.
		{ t = 0.09, pose = {
			Waist = po(0, 0.2, 0, -18, 0, 0),
			RightHip = ra(-130),
			RightKnee = ra(0),
			Neck = ra(10, 0, 0),
		}, style = BACK },
		{ t = 0.18, pose = { RightHip = ra(-40), Waist = po(0, 0, 0, -4, 0, 0) }, style = QUINT },
	})
end

function Anims.sanjiSpinKick(character, dur)
	local frames = {}
	local turns = math.max(2, math.floor((dur or 0.8) / 0.13))
	for i = 1, turns do
		table.insert(frames, {
			t = 0.13,
			pose = {
				Waist = ra(0, (i % 2 == 0) and 140 or -140, 0),
				RightHip = ra(-100, 0, -30),
				RightKnee = ra(10),
				LeftHip = ra(20),
				RightShoulder = ra(0, 0, -70),
				LeftShoulder = ra(0, 0, 70),
			},
			style = Enum.EasingStyle.Linear,
		})
	end
	playSequence(character, frames)
end

-- ---- Ace: caster gestures, finger-guns, arms-crossed flair --------------
function Anims.aceM1(character, index)
	local right = index % 2 == 1
	playSequence(character, {
		{ t = 0.05, pose = {
			[right and "RightShoulder" or "LeftShoulder"] = ra(-60, 0, right and -10 or 10),
			[right and "RightElbow" or "LeftElbow"] = ra(-50),
			Waist = po(0, 0, 0, 4, right and -14 or 14, 0),
		}, style = BACK },
		{ t = 0.1, pose = {
			[right and "RightShoulder" or "LeftShoulder"] = ra(-100),
			[right and "RightElbow" or "LeftElbow"] = ra(0),
			Waist = po(0, 0, 0, 8, 0, 0),
		}, style = QUINT },
	})
end

function Anims.aceCast(character, windup)
	playSequence(character, {
		-- Wind the fist back low, gathering flame.
		{ t = (windup or 0.4) * 0.6, pose = {
			Waist = po(0, -0.1, -0.3, -8, 30, 0),
			RightShoulder = ra(40, 0, -50),
			RightElbow = ra(-90),
			Neck = ra(-6, 24, 0),
			RightHip = ra(-8),
		}, style = SINE },
		-- Thrust the palm forward.
		{ t = 0.08, pose = {
			Waist = po(0, 0, 0.2, 16, -14, 0),
			RightShoulder = ra(-96, 0, 2),
			RightElbow = ra(0),
			Neck = ra(10, -8, 0),
		}, style = BACK },
		{ t = 0.18, pose = { Waist = po(0, 0, 0, 8, 0, 0), RightShoulder = ra(-86) }, style = QUINT },
	})
end

function Anims.aceFingerGun(character, count)
	-- Rapid alternating finger-gun jabs for the bullet barrage.
	local frames = {}
	for i = 1, math.max(3, count or 6) do
		local right = i % 2 == 1
		table.insert(frames, {
			t = 0.08,
			pose = {
				[right and "RightShoulder" or "LeftShoulder"] = ra(-92, 0, right and 4 or -4),
				[right and "RightElbow" or "LeftElbow"] = ra(-6),
				Waist = po(0, 0, 0, 4, right and -8 or 8, 0),
			},
			style = BACK,
		})
	end
	playSequence(character, frames)
end

-- ---- Tung: over-the-top goofy bat swings + royal king struts ------------
function Anims.tungM1(character, index)
	local right = index % 2 == 1
	playSequence(character, {
		-- Cartoonishly wind the bat way overhead.
		{ t = 0.06, pose = {
			Waist = po(0, 0.2, 0, -12, right and -40 or 40, 0),
			RightShoulder = ra(-170, 0, right and -30 or 30),
			LeftShoulder = ra(-150, 0, right and -30 or 30),
			Neck = ra(-10, 0, 0),
			RightHip = ra(-8),
		}, style = BACK },
		-- SMASH down with the whole body.
		{ t = 0.09, pose = {
			Waist = po(0, -0.3, 0.3, 30, right and 30 or -30, 0),
			RightShoulder = ra(-40),
			LeftShoulder = ra(-30),
			Neck = ra(16, 0, 0),
			RightKnee = ra(30),
			LeftKnee = ra(30),
		}, style = BACK },
		{ t = 0.16, pose = { Waist = po(0, 0, 0, 8, 0, 0) }, style = QUINT },
	})
end

function Anims.tungSmash(character, windup, big)
	local raise = big and 200 or 175
	playSequence(character, {
		-- Huge overhead bat raise, lean way back, tiny goofy hop.
		{ t = (windup or 0.4) * 0.65, pose = {
			Waist = po(0, 0.3, -0.4, -28, 0, 0),
			RightShoulder = ra(-raise, 0, -24),
			LeftShoulder = ra(-raise, 0, 24),
			Neck = ra(-18, 0, 0),
			RightHip = ra(-12),
			LeftHip = ra(-12),
			RightKnee = ra(20),
			LeftKnee = ra(20),
		}, style = BACK },
		-- Earth-shattering slam.
		{ t = 0.1, pose = {
			Waist = po(0, -0.5, 0.5, 40, 0, 0),
			RightShoulder = ra(-30),
			LeftShoulder = ra(-30),
			Neck = ra(24, 0, 0),
			RightKnee = ra(50),
			LeftKnee = ra(50),
		}, style = BACK },
		{ t = 0.2, pose = { Waist = po(0, 0, 0, 10, 0, 0), RightKnee = ra(10), LeftKnee = ra(10) }, style = QUINT },
	})
end

-- The King's royal strut on ult activation: chest out, chin up, arms wide.
function Anims.tungKingPose(character)
	playSequence(character, {
		{ t = 0.25, pose = {
			Waist = po(0, 0.3, 0, -16, 0, 0),
			Neck = ra(-20, 0, 0),
			RightShoulder = ra(0, 0, -80),
			LeftShoulder = ra(0, 0, 80),
			RightElbow = ra(-30),
			LeftElbow = ra(-30),
		}, style = BACK },
		{ t = 0.4, pose = {
			Waist = po(0, 0.2, 0, -10, 8, 0),
			Neck = ra(-14, 6, 0),
			RightShoulder = ra(0, 0, -55),
			LeftShoulder = ra(0, 0, 55),
		}, style = SINE },
		{ t = 0.5, pose = {
			Waist = po(0, 0.25, 0, -12, -8, 0),
			Neck = ra(-16, -6, 0),
		}, style = SINE },
	}, true)
end

-- A generic triumphant "ult power-up" flex used by the anime transformations.
function Anims.ultFlex(character)
	playSequence(character, {
		{ t = 0.12, pose = {
			Waist = po(0, -0.4, 0, 20, 0, 0),
			RightShoulder = ra(30, 0, -70),
			LeftShoulder = ra(30, 0, 70),
			RightElbow = ra(-90),
			LeftElbow = ra(-90),
			Neck = ra(20, 0, 0),
			RightHip = ra(20),
			LeftHip = ra(20),
			RightKnee = ra(40),
			LeftKnee = ra(40),
		}, style = BACK },
		{ t = 0.5, pose = {
			Waist = po(0, 0.2, 0, -18, 0, 0),
			RightShoulder = ra(-20, 0, -60),
			LeftShoulder = ra(-20, 0, 60),
			RightElbow = ra(-40),
			LeftElbow = ra(-40),
			Neck = ra(-16, 0, 0),
			RightKnee = ra(0),
			LeftKnee = ra(0),
		}, style = BACK },
	})
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
-- Sword primitives (Zoro)
-- ========================================================================

-- The core of a REAL slash: a thin part with a Trail is swept along a
-- circular arc, so the Trail paints a curved crescent (not a straight line).
-- The part rotates about `rotAxis`; the trail's two attachments sit along
-- `radialAxis` at inner/outer radius, so the ribbon spans the blade length.
local function arcSweep(character, o)
	local r = root(character)
	if not r then
		return nil
	end
	local pivot = r.CFrame * (o.pivot or CFrame.new(0, 1.4, -1.5))
	local inner = o.inner or 0.6
	local outer = o.outer or 6
	local fromA = math.rad(o.from or 70)
	local toA = math.rad(o.to or -70)
	local dur = o.duration or 0.16
	local color = o.color or Color3.new(1, 1, 1)
	local rotAxis = (o.rotAxis or Vector3.new(0, 0, 1))
	local radialAxis = (o.radialAxis or Vector3.new(0, 1, 0))

	local mover = makePart({
		Size = Vector3.new(0.15, 0.15, 0.15),
		Transparency = 1,
		CFrame = pivot * CFrame.fromAxisAngle(rotAxis, fromA),
	})
	local a0 = attachment(mover, radialAxis * inner)
	local a1 = attachment(mover, radialAxis * outer)
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	trail.Lifetime = math.max(0.12, dur * 1.1)
	trail.LightEmission = 1
	trail.FaceCamera = false
	trail.MaxLength = 0
	trail.Parent = mover

	task.spawn(function()
		local t = 0
		while t < dur and mover.Parent do
			local dt = RunService.RenderStepped:Wait()
			t += dt
			local frac = math.min(1, t / dur)
			-- ease-out so the blade whips fast then slows (anime timing)
			local eased = 1 - (1 - frac) * (1 - frac)
			local ang = fromA + (toA - fromA) * eased
			mover.CFrame = pivot * CFrame.fromAxisAngle(rotAxis, ang)
		end
		trail.Enabled = false
	end)
	Debris:AddItem(mover, dur + trail.Lifetime + 0.1)
	return (pivot * CFrame.new(radialAxis * outer)).Position
end

-- A forward slash arc. `angleDeg` orients the cut (0 = horizontal-ish, 90 =
-- vertical); it sweeps a curved crescent in the plane facing forward.
local function slash(character, angleDeg, length, color, forward, life)
	local r = root(character)
	if not r then
		return nil
	end
	forward = forward or 5
	angleDeg = angleDeg or 0
	arcSweep(character, {
		pivot = CFrame.new(0, 1.4, -forward * 0.45),
		from = angleDeg + 60,
		to = angleDeg - 70,
		inner = 0.7,
		outer = length,
		rotAxis = Vector3.new(0, 0, 1),
		radialAxis = Vector3.new(0, 1, 0),
		color = color,
		duration = life or 0.16,
	})
	return (r.CFrame * CFrame.new(0, 1.4, -forward)).Position
end

-- A horizontal curved sweep around the character (spins / round kicks).
local function arcSlash(character, startAngle, radius, color)
	arcSweep(character, {
		pivot = CFrame.new(0, 1, 0),
		from = startAngle - 55,
		to = startAngle + 55,
		inner = 1,
		outer = radius,
		rotAxis = Vector3.new(0, 1, 0),
		radialAxis = Vector3.new(0, 0, -1),
		color = color,
		duration = 0.2,
	})
end

-- Attach a temporary edge-trail to a real welded weapon part (sword blade,
-- bat barrel) so the physical weapon streaks as it swings.
local function weaponEdgeTrail(character, folderName, partName, color, dur)
	local folder = character:FindFirstChild(folderName)
	if not folder then
		return
	end
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") and part.Name == partName then
			local a0 = attachment(part, Vector3.new(0, part.Size.Y / 2, 0))
			local a1 = attachment(part, Vector3.new(0, -part.Size.Y / 2, 0))
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(color)
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			})
			trail.Lifetime = 0.22
			trail.LightEmission = 0.9
			trail.Parent = part
			task.delay(dur or 0.3, function()
				trail.Enabled = false
				Debris:AddItem(trail, 0.4)
				Debris:AddItem(a0, 0.4)
				Debris:AddItem(a1, 0.4)
			end)
		end
	end
end

-- Attach a temporary trail to a real limb (a foot, for kicks) so the kick
-- follows the actual leg like Luffy's arm follows his hand.
local function limbTrail(character, partNames, color, dur)
	local part = getPart(character, partNames)
	if not part then
		return
	end
	local a0 = attachment(part, Vector3.new(0, part.Size.Y / 2, 0))
	local a1 = attachment(part, Vector3.new(0, -part.Size.Y / 2, 0))
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.2
	trail.LightEmission = 0.7
	trail.Parent = part
	task.delay(dur or 0.3, function()
		trail.Enabled = false
		Debris:AddItem(trail, 0.35)
		Debris:AddItem(a0, 0.35)
		Debris:AddItem(a1, 0.35)
	end)
end

-- Convenience wrappers so each fighter's swing shows the real weapon/limb.
local function swordSwing(character, angleDeg, length, color, forward, life)
	slash(character, angleDeg, length, color, forward, life)
	weaponEdgeTrail(character, "Santoryu", "Blade", color, (life or 0.16) + 0.12)
end

local function batSwing(character, angleDeg, length, color, forward, life)
	slash(character, angleDeg, length, color, forward, life)
	weaponEdgeTrail(character, "BrainrotBat", "Barrel", color, (life or 0.16) + 0.14)
end

local function kickSwing(character, side, angleDeg, length, color, forward, life)
	slash(character, angleDeg, length, color, forward, life)
	limbTrail(character, { side .. "Foot", side .. "LowerLeg", side .. " Leg" }, color, (life or 0.16) + 0.14)
end

-- A swirling tornado column of blade shards + rising particles.
local function tornado(character, duration, radius, height, color)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local r = root(character)
			if not r then
				break
			end
			for _ = 1, 2 do
				local a = math.rad(math.random(0, 359))
				local h = math.random() * height
				local rad = radius * (0.35 + (h / height) * 0.75)
				local shard = makePart({
					Size = Vector3.new(0.35, 3, 0.35),
					CFrame = r.CFrame * CFrame.new(math.cos(a) * rad, h, math.sin(a) * rad) * CFrame.Angles(0, a, math.rad(24)),
					Color = color,
					Transparency = 0.15,
				})
				tween(shard, 0.28, { Transparency = 1 })
				Debris:AddItem(shard, 0.32)
			end
			elapsed += task.wait(0.02)
		end
	end)
	local r = root(character)
	if r then
		dust(r.Position, color, 12)
		shake(r.Position, 0.5, duration)
	end
end

-- Nine phantom blades fanned out in front (Ashura signature).
local function nineBladeFan(character, length, color, life)
	local r = root(character)
	if not r then
		return
	end
	for i = -4, 4 do
		local blade = makePart({
			Size = Vector3.new(0.28, length, 0.9),
			CFrame = r.CFrame * CFrame.new(i * 1.6, 1.5, -5) * CFrame.Angles(0, 0, math.rad(i * 9)),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
		})
		addTrail(blade, color, 0.18, length * 0.4)
		tween(blade, life or 0.3, {
			CFrame = r.CFrame * CFrame.new(i * 2.2, 1.5, -(5 + length)) * CFrame.Angles(0, 0, math.rad(i * 9)),
			Transparency = 1,
		}, Enum.EasingStyle.Quint)
		Debris:AddItem(blade, (life or 0.3) + 0.1)
	end
end

-- ========================================================================
-- Kick + fire primitives (Sanji)
-- ========================================================================

local legMotorCache = setmetatable({}, { __mode = "k" })

local function getHip(character, side)
	if not character then
		return nil
	end
	local cache = legMotorCache[character]
	if cache and cache[side] and cache[side].Parent then
		return cache[side]
	end
	if not cache then
		cache = {}
		legMotorCache[character] = cache
	end
	for _, name in { side .. "Hip", side .. " Hip" } do
		for _, d in character:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == name then
				cache[side] = d
				return d
			end
		end
	end
	return nil
end

-- Swing a leg forward/up (kick), layered over the idle like punchArm.
local function kickLeg(character, side, outTime, hold, power)
	local motor = getHip(character, side)
	if not motor then
		return
	end
	power = power or 1
	local base = restPose(motor)
	local posed = base * CFrame.Angles(math.rad(72 * power), 0, 0)
	tween(motor, outTime or 0.07, { C0 = posed }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay((outTime or 0.07) + (hold or 0.05), function()
		if motor.Parent then
			tween(motor, 0.2, { C0 = base }, Enum.EasingStyle.Quad)
		end
	end)
end

-- Fiery impact (orange variant of impact + short-lived flames).
local function flameImpact(position, scale, heavy)
	impact(position, {
		Color = FIRE_YELLOW,
		Scale = scale,
		Heavy = heavy,
		DustColor = Color3.fromRGB(60, 40, 30),
		CrackColor = Color3.fromRGB(60, 30, 20),
	})
	sparks(position, FIRE_ORANGE, math.floor(16 * (scale or 1)), 26 * (scale or 1), 1.4 * (scale or 1))
	local holder = makePart({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Transparency = 1 })
	local fire = Instance.new("Fire")
	fire.Size = 10 * (scale or 1)
	fire.Heat = 12
	fire.Color = FIRE_ORANGE
	fire.SecondaryColor = FIRE_DEEP
	fire.Parent = holder
	task.delay(0.15, function()
		fire.Enabled = false
	end)
	Debris:AddItem(holder, 1)
end

-- Trailing flame streak (fire-colored slash used for Diable kicks).
local function flameArc(character, angleDeg, length, forward)
	slash(character, angleDeg, length, FIRE_YELLOW, forward, 0.16)
	local r = root(character)
	if r then
		sparks(r.Position + r.CFrame.LookVector * (forward or 5) + Vector3.new(0, 1, 0), FIRE_ORANGE, 6, 16, 1)
	end
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
	Anims.luffyM1(data.Character, data.Index)
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

	-- Wind-up: draw the whole body back with a charge aura, then whip forward.
	Anims.luffyWindup(character, cfg.WindUp)
	chargeAura(function()
		local hand = handPart(character, "Right")
		return hand and hand.Position
	end, cfg.WindUp, RUBBER)

	task.delay(cfg.WindUp - 0.05, function()
		if not root(character) then
			return
		end
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

	Anims.luffyBazooka(character, cfg.WindUp)
	chargeAura(function()
		return r.Position + r.CFrame.LookVector * 2
	end, cfg.WindUp, RUBBER)

	task.delay(cfg.WindUp - 0.05, function()
		if not root(character) then
			return
		end
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
	Anims.ultFlex(character)

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
-- Zoro effect handlers
-- ========================================================================

function Effects.ZoroM1(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	Anims.zoroM1(data.Character, data.Index)
	swordSwing(data.Character, side == "Right" and -32 or 32, 6, SLASH, 5, 0.16)
	if isLocal(data.Character) then
		local r = root(data.Character)
		fovPunch(r and r.Position or Vector3.zero, 2, 0.14)
	end
end

function Effects.OniGiri(data)
	local character = data.Character
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		slash(character, -40, 7, SLASH, 5, 0.18)
		return
	end
	afterImage(character, SLASH, 0.4)
	-- Three-sword cross: two diagonals + a horizontal, staggered.
	swordSwing(character, -45, 8, SLASH, 4, 0.2)
	task.delay(0.05, function()
		swordSwing(character, 45, 8, SLASH, 4, 0.2)
	end)
	task.delay(0.1, function()
		swordSwing(character, 90, 8, BLADE, 4, 0.2)
	end)
	local r = root(character)
	if r then
		impact(r.Position + r.CFrame.LookVector * 5, { Color = SLASH, Scale = 1.1 })
	end
end

function Effects.ToraGari(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Base[2]
	local r = root(character)
	if not r then
		return
	end
	-- Raise the blades overhead, then a heavy vertical cleave.
	Anims.zoroSlash(character, cfg.WindUp)
	chargeAura(function()
		return r.Position + Vector3.new(0, 4, 0)
	end, cfg.WindUp, SLASH)
	task.delay(cfg.WindUp - 0.05, function()
		swordSwing(character, 8, 12, BLADE, 5, 0.22)
		swordSwing(character, -4, 11, SLASH, 5, 0.22)
		local hit = r.Position + r.CFrame.LookVector * 6
		impact(hit, { Color = SLASH, Scale = 1.5, Heavy = true, CrackColor = Color3.fromRGB(70, 74, 82) })
	end)
end

function Effects.UlToraGari(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Base[3]
	Anims.zoroSpin(character, cfg.WindUp + cfg.Hits * cfg.HitInterval)
	speedLines(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, SLASH)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 300, 60 do
				arcSlash(character, a + hit * 40, cfg.Radius, hit == cfg.Hits and BLADE or SLASH)
			end
			local r = root(character)
			if r then
				shake(r.Position, 0.3, 0.15)
			end
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.SwordCombo(data)
	local character = data.Character
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		slash(character, 30, 7, SLASH, 5, 0.16)
		return
	end
	afterImage(character, SLASH, 0.4)
	speedLines(character, data.Duration or 0.9, SLASH)
	weaponEdgeTrail(character, "Santoryu", "Blade", SLASH, (data.Duration or 0.9) + 0.2)
	task.spawn(function()
		local n = 6
		for i = 1, n do
			local side = i % 2 == 0 and 38 or -38
			Anims.zoroM1(character, i)
			slash(character, side, 6, i == n and BLADE or SLASH, 4.5, 0.14)
			task.wait(0.08)
		end
	end)
end

function Effects.Ichibugin(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Ult[1]
	local r = root(character)
	if not r then
		return
	end
	chargeAura(function()
		return r.Position + r.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
	end, cfg.WindUp, ASHURA_RED)
	pushBothArms(character, cfg.WindUp * 0.6, cfg.WindUp * 0.4)
	task.delay(cfg.WindUp - 0.05, function()
		nineBladeFan(character, cfg.Range * 0.5, ASHURA_RED, 0.35)
		slash(character, -20, cfg.Range * 0.45, BLADE, 6, 0.28)
		slash(character, 20, cfg.Range * 0.45, ASHURA_RED, 6, 0.28)
		local hit = r.Position + r.CFrame.LookVector * (cfg.Range * 0.55)
		impact(hit, { Color = ASHURA_RED, Scale = 2.4, Heavy = true, CrackColor = Color3.fromRGB(60, 20, 24) })
		shockwave(hit, 60, ASHURA_RED, 0.6, 1.6)
		screenFlash(ASHURA_RED, 0.3, 0.25)
		fovPunch(r.Position, 8, 0.4)
	end)
end

function Effects.Makyusen(data)
	local character = data.Character
	speedLines(character, data.Duration or 1.4, ASHURA_RED)
	task.spawn(function()
		local elapsed = 0
		local side = "Right"
		while elapsed < (data.Duration or 1.4) do
			punchArm(character, side, 0.05, 0.02, 0.9)
			slash(character, side == "Right" and -36 or 36, 7, math.random() < 0.5 and ASHURA_RED or BLADE, 5, 0.12)
			side = side == "Right" and "Left" or "Right"
			elapsed += task.wait(0.07)
		end
	end)
end

function Effects.Tatsumaki(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Ult[3]
	tornado(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, cfg.Radius, 22, SLASH)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 270, 90 do
				arcSlash(character, a + hit * 55, cfg.Radius, SLASH)
			end
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.KokujoOTatsumaki(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Ult[4]
	local r = root(character)
	if r then
		groundDisc(r.Position, cfg.Radius * 2, ASHURA_DARK, 0.6)
		screenFlash(ASHURA_DARK, 0.3, 0.3)
	end
	tornado(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, cfg.Radius, 40, ASHURA_DARK)
	tornado(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, cfg.Radius * 0.7, 40, ASHURA_RED)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 315, 45 do
				arcSlash(character, a + hit * 30, cfg.Radius, hit == cfg.Hits and BLADE or ASHURA_RED)
			end
			local rr = root(character)
			if rr then
				shake(rr.Position, 0.6, 0.18)
			end
			task.wait(cfg.HitInterval)
		end
		local rr = root(character)
		if rr then
			impact(rr.Position, { Color = ASHURA_RED, Scale = 2.6, Heavy = true })
		end
	end)
end

function Effects.AshuraStart(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	Anims.ultFlex(character)
	shockwave(r.Position, 55, ASHURA_RED, 0.8, 1.6)
	groundDisc(r.Position, 50, ASHURA_DARK, 0.7)
	sparks(r.Position, ASHURA_RED, 50, 45, 2)
	shake(r.Position, 1.2, 0.5)
	fovPunch(r.Position, 10, 0.5)
	if isLocal(character) then
		screenFlash(ASHURA_RED, 0.5, 0.5)
	end

	-- Dark aura + phantom blades orbiting while Ashura lasts.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(ASHURA_DARK)
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.35, 1)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Rate = 26
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = r
	gear5Emitters[character] = emitter

	ashuraAuras[character] = true
	task.spawn(function()
		local angle = 0
		while ashuraAuras[character] do
			local rNow = root(character)
			if not rNow then
				break
			end
			angle += 0.35
			for i = 0, 5 do
				local a = angle + i * (math.pi * 2 / 6)
				local blade = makePart({
					Size = Vector3.new(0.3, 4, 0.3),
					CFrame = rNow.CFrame * CFrame.new(math.cos(a) * 5, math.sin(a * 1.5) * 2, math.sin(a) * 5) * CFrame.Angles(math.rad(90), 0, 0),
					Color = i % 2 == 0 and ASHURA_RED or BLADE,
					Transparency = 0.35,
				})
				Debris:AddItem(blade, 0.12)
			end
			task.wait(0.06)
		end
	end)
end

function Effects.AshuraEnd(data)
	ashuraAuras[data.Character] = nil
	local emitter = gear5Emitters[data.Character]
	if emitter then
		emitter.Enabled = false
		Debris:AddItem(emitter, 1.5)
		gear5Emitters[data.Character] = nil
	end
	local r = root(data.Character)
	if r then
		shockwave(r.Position, 22, ASHURA_RED, 0.5, 1)
	end
end

-- ========================================================================
-- Sanji effect handlers
-- ========================================================================

function Effects.SanjiM1(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	Anims.sanjiM1(data.Character, data.Index)
	kickSwing(data.Character, side, side == "Right" and -20 or 20, 5.5, AIR, 5, 0.15)
	if isLocal(data.Character) then
		local r = root(data.Character)
		fovPunch(r and r.Position or Vector3.zero, 2, 0.13)
	end
end

function Effects.Collier(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Base[1]
	task.delay(cfg.WindUp - 0.05, function()
		kickLeg(character, "Right", 0.06, 0.12, 1.1)
		kickSwing(character, "Right", 90, 8, AIR, 5, 0.18) -- horizontal side kick
		local r = root(character)
		if r then
			impact(r.Position + r.CFrame.LookVector * 6, { Color = AIR, Scale = 1 })
		end
	end)
end

function Effects.Concasse(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Base[2]
	local r = root(character)
	if not r then
		return
	end
	Anims.sanjiHighKick(character, cfg.WindUp)
	afterImage(character, AIR, 0.3)
	task.delay(cfg.WindUp - 0.05, function()
		kickSwing(character, "Right", 4, 11, AIR, 5, 0.22) -- vertical axe kick
		local hit = r.Position + r.CFrame.LookVector * 6
		impact(hit, { Color = AIR, Scale = 1.4, Heavy = true, CrackColor = Color3.fromRGB(70, 74, 82) })
	end)
end

function Effects.PartyTable(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Base[3]
	Anims.sanjiSpinKick(character, cfg.WindUp + cfg.Hits * cfg.HitInterval)
	speedLines(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, AIR)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 270, 90 do
				arcSlash(character, a + hit * 45, cfg.Radius, AIR)
			end
			kickLeg(character, hit % 2 == 0 and "Left" or "Right", 0.05, 0.03, 0.9)
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.KickCombo(data)
	local character = data.Character
	if data.Whiff then
		kickLeg(character, "Right", 0.08, 0.05, 1)
		slash(character, 22, 6, AIR, 5, 0.15)
		return
	end
	afterImage(character, AIR, 0.4)
	speedLines(character, data.Duration or 0.9, AIR)
	limbTrail(character, { "RightFoot", "RightLowerLeg", "Right Leg" }, AIR, (data.Duration or 0.9) + 0.2)
	limbTrail(character, { "LeftFoot", "LeftLowerLeg", "Left Leg" }, AIR, (data.Duration or 0.9) + 0.2)
	task.spawn(function()
		local n = 6
		for i = 1, n do
			kickLeg(character, i % 2 == 0 and "Left" or "Right", 0.05, 0.02, 0.95)
			slash(character, i % 2 == 0 and 26 or -26, 6, AIR, 4.5, 0.13)
			task.wait(0.08)
		end
	end)
end

function Effects.PremierHachis(data)
	local character = data.Character
	speedLines(character, data.Duration or 1.4, FIRE_ORANGE)
	task.spawn(function()
		local elapsed = 0
		local side = "Right"
		while elapsed < (data.Duration or 1.4) do
			kickLeg(character, side, 0.05, 0.02, 0.95)
			flameArc(character, side == "Right" and -28 or 28, 7, 5)
			side = side == "Right" and "Left" or "Right"
			elapsed += task.wait(0.08)
		end
	end)
end

function Effects.FlambageShot(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Ult[2]
	tornado(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, cfg.Radius, 20, FIRE_ORANGE)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 270, 90 do
				arcSlash(character, a + hit * 55, cfg.Radius, FIRE_YELLOW)
			end
			kickLeg(character, hit % 2 == 0 and "Left" or "Right", 0.05, 0.03, 1)
			local r = root(character)
			if r then
				sparks(r.Position + Vector3.new(0, 1, 0), FIRE_ORANGE, 8, 20, 1.4)
			end
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.MoutonShot(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Ult[3]
	local r = root(character)
	if not r then
		return
	end
	kickLeg(character, "Right", cfg.WindUp * 0.7, cfg.WindUp * 0.3, -0.6)
	chargeAura(function()
		local foot = getPart(character, { "RightFoot", "RightLowerLeg", "Right Leg" })
		return foot and foot.Position
	end, cfg.WindUp, FIRE_ORANGE)
	task.delay(cfg.WindUp - 0.05, function()
		kickLeg(character, "Right", 0.07, 0.16, 1.2)
		flameArc(character, -16, cfg.Range * 0.5, 6)
		flameArc(character, 12, cfg.Range * 0.45, 6)
		local hit = r.Position + r.CFrame.LookVector * (cfg.Range * 0.5)
		flameImpact(hit, 2.2, true)
		shockwave(hit, 50, FIRE_ORANGE, 0.6, 1.4)
		screenFlash(FIRE_ORANGE, 0.28, 0.25)
		fovPunch(r.Position, 8, 0.4)
	end)
end

function Effects.GrillShot(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Ult[4]
	local r = root(character)
	if r then
		groundDisc(r.Position, cfg.Range, FIRE_DEEP, 0.6)
		screenFlash(FIRE_ORANGE, 0.3, 0.3)
	end
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			kickLeg(character, hit % 2 == 0 and "Left" or "Right", 0.05, 0.03, 1.1)
			flameArc(character, hit % 2 == 0 and 22 or -22, 10, 6)
			local rr = root(character)
			if rr then
				sparks(rr.Position + rr.CFrame.LookVector * 6 + Vector3.new(0, 1, 0), FIRE_ORANGE, 10, 24, 1.5)
				shake(rr.Position, 0.4, 0.15)
			end
			task.wait(cfg.HitInterval)
		end
		local rr = root(character)
		if rr then
			flameImpact(rr.Position + rr.CFrame.LookVector * 8, 2.6, true)
		end
	end)
end

function Effects.DiableStart(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	Anims.ultFlex(character)
	shockwave(r.Position, 50, FIRE_ORANGE, 0.8, 1.5)
	groundDisc(r.Position, 46, FIRE_DEEP, 0.7)
	sparks(r.Position, FIRE_ORANGE, 55, 45, 2)
	shake(r.Position, 1.2, 0.5)
	fovPunch(r.Position, 9, 0.5)
	if isLocal(character) then
		screenFlash(FIRE_ORANGE, 0.5, 0.5)
	end

	-- Persistent fire on both legs while Diable Jambe lasts.
	local instances = {}
	for _, legName in { "RightLowerLeg", "LeftLowerLeg", "Right Leg", "Left Leg", "RightFoot", "LeftFoot" } do
		local leg = character:FindFirstChild(legName)
		if leg then
			local fire = Instance.new("Fire")
			fire.Size = 5
			fire.Heat = 8
			fire.Color = FIRE_ORANGE
			fire.SecondaryColor = FIRE_DEEP
			fire.Parent = leg
			table.insert(instances, fire)
		end
	end
	diableFires[character] = instances
end

function Effects.DiableEnd(data)
	local instances = diableFires[data.Character]
	if instances then
		for _, fire in instances do
			if fire.Parent then
				fire.Enabled = false
				Debris:AddItem(fire, 1)
			end
		end
		diableFires[data.Character] = nil
	end
	local r = root(data.Character)
	if r then
		shockwave(r.Position, 20, FIRE_ORANGE, 0.5, 1)
	end
end

function Effects.IgniteStart(data)
	local character = data.Character
	if igniteFires[character] then
		return
	end
	local part = getPart(character, { "UpperTorso", "Torso", "HumanoidRootPart" })
	if not part then
		return
	end
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 6
	fire.Color = FIRE_ORANGE
	fire.SecondaryColor = FIRE_DEEP
	fire.Parent = part
	igniteFires[character] = fire
end

function Effects.IgniteEnd(data)
	local fire = igniteFires[data.Character]
	if fire then
		fire.Enabled = false
		Debris:AddItem(fire, 1)
		igniteFires[data.Character] = nil
	end
end

-- ========================================================================
-- Ace effect handlers (fire projectiles + zoning)
-- ========================================================================

local greatFlameFx = {}

-- Muzzle flash at the caster's hand.
local function muzzle(character, color)
	local hand = handPart(character, "Right")
	if hand then
		local flash = makePart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(hand.Position),
			Color = color,
			Transparency = 0.1,
		})
		tween(flash, 0.2, { Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1 })
		Debris:AddItem(flash, 0.25)
		sparks(hand.Position, color, 10, 22, 1.2)
	end
end

-- A fireball / bullet flying with the same kinematics the server simulates.
function Effects.FireProjectile(data)
	local color = data.Color or FIRE_ORANGE
	local radius = data.Radius or 3
	local ball = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		CFrame = CFrame.new(data.Origin),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.05,
	})
	addTrail(ball, color, 0.25, radius)
	local fire = Instance.new("Fire")
	fire.Size = radius * 2.5
	fire.Heat = 10
	fire.Color = color
	fire.SecondaryColor = FIRE_DEEP
	fire.Parent = ball

	task.spawn(function()
		local pos = data.Origin
		local dir = data.Direction
		local speed = data.Speed or 100
		local life = data.Life or 1
		local elapsed = 0
		while elapsed < life and ball.Parent do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			pos = pos + dir * (speed * dt)
			ball.CFrame = CFrame.new(pos)
		end
		fire.Enabled = false
		tween(ball, 0.12, { Transparency = 1, Size = Vector3.new(0.5, 0.5, 0.5) })
	end)
	Debris:AddItem(ball, (data.Life or 1) + 0.3)
end

function Effects.Explosion(data)
	local radius = data.Radius or 8
	local scale = math.clamp(radius / 6, 1, 5)
	flameImpact(data.Position, scale, true)
	shockwave(data.Position, radius * 3, data.Color or FIRE_ORANGE, 0.55, 1.3)
	if scale >= 2 then
		screenFlash(FIRE_ORANGE, 0.24, 0.22)
		fovPunch(data.Position, 6, 0.3)
	end
end

function Effects.FirePillar(data)
	local pos = data.Position
	local radius = data.Radius or 8
	-- Telegraph ring while it charges.
	local ring = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		CFrame = CFrame.new(pos.X, pos.Y - 2.5, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = data.Color or FIRE_ORANGE,
		Transparency = 0.4,
	})
	Debris:AddItem(ring, (data.Delay or 0.4) + 0.2)
	task.delay(data.Delay or 0.4, function()
		local column = makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(26, radius * 1.5, radius * 1.5),
			CFrame = CFrame.new(pos + Vector3.new(0, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = data.Color or FIRE_ORANGE,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		tween(column, 0.5, { Transparency = 1, Size = Vector3.new(28, radius * 2, radius * 2) }, Enum.EasingStyle.Quint)
		Debris:AddItem(column, 0.6)
		flameImpact(pos, radius / 6, true)
		sparks(pos, FIRE_ORANGE, 30, 40, 2)
	end)
end

function Effects.AceM1(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	Anims.aceM1(data.Character, data.Index)
	slash(data.Character, side == "Right" and -24 or 24, 5, FIRE_YELLOW, 5, 0.15)
	muzzle(data.Character, FIRE_ORANGE)
end

function Effects.HikenCast(data)
	local character = data.Character
	local cfg = Config.Movesets.Ace.Base[1]
	Anims.aceCast(character, cfg.WindUp or 0.4)
	chargeAura(function()
		local hand = handPart(character, "Right")
		return hand and hand.Position
	end, cfg.WindUp or 0.4, FIRE_ORANGE)
	task.delay((cfg.WindUp or 0.4) - 0.05, function()
		muzzle(character, FIRE_ORANGE)
	end)
end

function Effects.EnteiCast(data)
	local character = data.Character
	local cfg = Config.Movesets.Ace.Ult[1]
	local r = root(character)
	Anims.aceCast(character, cfg.WindUp or 1)
	chargeAura(function()
		local rr = root(character)
		return rr and rr.Position + rr.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
	end, cfg.WindUp or 1, FIRE_ORANGE)
	if r then
		shake(r.Position, 0.4, cfg.WindUp or 1)
	end
	task.delay((cfg.WindUp or 1) - 0.05, function()
		pushBothArms(character, 0.1, 0.2)
		muzzle(character, FIRE_YELLOW)
		local rr = root(character)
		if rr then
			screenFlash(FIRE_ORANGE, 0.25, 0.2)
		end
	end)
end

function Effects.HiganCast(data)
	Anims.aceFingerGun(data.Character, data.Bullets or 6)
	muzzle(data.Character, FIRE_ORANGE)
end

function Effects.FlameCombo(data)
	local character = data.Character
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		flameArc(character, 24, 6, 5)
		return
	end
	afterImage(character, FIRE_ORANGE, 0.4)
	speedLines(character, data.Duration or 0.9, FIRE_ORANGE)
	task.spawn(function()
		for i = 1, 5 do
			punchArm(character, i % 2 == 0 and "Left" or "Right", 0.05, 0.02, 0.95)
			flameArc(character, i % 2 == 0 and 26 or -26, 6, 4.5)
			task.wait(0.09)
		end
	end)
end

function Effects.Kyokaen(data)
	local character = data.Character
	local cfg = Config.Movesets.Ace.Ult[3]
	local r = root(character)
	if not r then
		return
	end
	pushBothArms(character, (cfg.WindUp or 0.5) * 0.6, (cfg.WindUp or 0.5) * 0.4)
	task.delay((cfg.WindUp or 0.5) - 0.05, function()
		-- A big fiery cross.
		slash(character, 45, cfg.Range * 0.5, FIRE_YELLOW, 6, 0.3)
		slash(character, -45, cfg.Range * 0.5, FIRE_ORANGE, 6, 0.3)
		local hit = r.Position + r.CFrame.LookVector * (cfg.Range * 0.5)
		flameImpact(hit, 2.2, true)
		shockwave(hit, 50, FIRE_ORANGE, 0.6, 1.4)
		screenFlash(FIRE_ORANGE, 0.28, 0.25)
		fovPunch(r.Position, 8, 0.4)
	end)
end

function Effects.Hotarubi(data)
	local pos = data.Position
	-- Fireflies gather toward the mark, then it detonates (server fires the
	-- Explosion at the end).
	chargeAura(function()
		return pos
	end, data.WindUp or 1.2, FIRE_YELLOW)
	local marker = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(pos),
		Color = FIRE_ORANGE,
		Transparency = 0.4,
	})
	tween(marker, data.WindUp or 1.2, { Size = Vector3.new(6, 6, 6), Transparency = 0.1 })
	Debris:AddItem(marker, (data.WindUp or 1.2) + 0.1)
end

function Effects.GreatFlameStart(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	Anims.ultFlex(character)
	shockwave(r.Position, 55, FIRE_ORANGE, 0.8, 1.6)
	groundDisc(r.Position, 50, FIRE_DEEP, 0.7)
	sparks(r.Position, FIRE_ORANGE, 60, 50, 2.4)
	shake(r.Position, 1.3, 0.55)
	fovPunch(r.Position, 11, 0.55)
	if isLocal(character) then
		screenFlash(FIRE_ORANGE, 0.55, 0.5)
	end

	local instances = {}
	for _, partName in { "UpperTorso", "Torso", "HumanoidRootPart", "RightLowerArm", "LeftLowerArm" } do
		local part = character:FindFirstChild(partName)
		if part then
			local fire = Instance.new("Fire")
			fire.Size = partName:find("Torso") and 8 or 4
			fire.Heat = 10
			fire.Color = FIRE_ORANGE
			fire.SecondaryColor = FIRE_DEEP
			fire.Parent = part
			table.insert(instances, fire)
		end
	end
	greatFlameFx[character] = instances
end

function Effects.GreatFlameEnd(data)
	local instances = greatFlameFx[data.Character]
	if instances then
		for _, fire in instances do
			if fire.Parent then
				fire.Enabled = false
				Debris:AddItem(fire, 1)
			end
		end
		greatFlameFx[data.Character] = nil
	end
	local r = root(data.Character)
	if r then
		shockwave(r.Position, 22, FIRE_ORANGE, 0.5, 1)
	end
end

-- ========================================================================
-- Tung Tung Tung Sahur effect handlers (bat + royal one-hit-kill ult)
-- ========================================================================

local WOOD = Color3.fromRGB(150, 108, 62)
local ROYAL_GOLD = Color3.fromRGB(255, 210, 90)

function Effects.TungM1(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	Anims.tungM1(data.Character, data.Index)
	batSwing(data.Character, side == "Right" and -30 or 30, 6, WOOD, 5, 0.16)
end

local function batSmash(character, color, big)
	local r = root(character)
	if not r then
		return
	end
	pushBothArms(character, 0.08, 0.14)
	batSwing(character, 6, big and 13 or 10, color, 5, 0.22)
	local hit = r.Position + r.CFrame.LookVector * 6
	impact(hit, { Color = color, Scale = big and 1.8 or 1.3, Heavy = true, CrackColor = Color3.fromRGB(60, 45, 30) })
end

function Effects.SahurSmash(data)
	local cfg = Config.Movesets.Tung.Base[1]
	Anims.tungSmash(data.Character, cfg.WindUp, false)
	task.delay(cfg.WindUp - 0.05, function()
		batSmash(data.Character, WOOD, false)
	end)
end

function Effects.TungBarrage(data)
	local character = data.Character
	speedLines(character, data.Duration or 1.2, WOOD)
	task.spawn(function()
		local elapsed = 0
		local side = "Right"
		while elapsed < (data.Duration or 1.2) do
			punchArm(character, side, 0.05, 0.02, 0.95)
			slash(character, side == "Right" and -26 or 26, 7, WOOD, 5, 0.12)
			side = side == "Right" and "Left" or "Right"
			elapsed += task.wait(0.1)
		end
	end)
end

function Effects.BrainrotSpin(data)
	local character = data.Character
	local cfg = Config.Movesets.Tung.Base[3]
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 270, 90 do
				arcSlash(character, a + hit * 50, cfg.Radius, WOOD)
			end
			local r = root(character)
			if r then
				shake(r.Position, 0.3, 0.15)
			end
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.BatCombo(data)
	local character = data.Character
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		slash(character, 28, 6, WOOD, 5, 0.15)
		return
	end
	afterImage(character, WOOD, 0.4)
	weaponEdgeTrail(character, "BrainrotBat", "Barrel", WOOD, 0.7)
	task.spawn(function()
		for i = 1, 5 do
			Anims.tungM1(character, i)
			slash(character, i % 2 == 0 and 26 or -26, 6, WOOD, 4.5, 0.13)
			task.wait(0.09)
		end
	end)
end

-- Royal ult moves: gilded, extra dramatic.
local function royalHit(character, offset, scale)
	local r = root(character)
	if not r then
		return
	end
	local hit = r.Position + r.CFrame.LookVector * (offset or 6)
	flameArc(character, -14, 12, 6) -- gold streak reuse (fire arc tinted below)
	impact(hit, { Color = ROYAL_GOLD, Scale = scale or 2, Heavy = true, CrackColor = Color3.fromRGB(90, 70, 20) })
	shockwave(hit, 40, ROYAL_GOLD, 0.5, 1.2)
	screenFlash(ROYAL_GOLD, 0.2, 0.2)
end

function Effects.RoyalDecree(data)
	local cfg = Config.Movesets.Tung.Ult[1]
	Anims.tungSmash(data.Character, cfg.WindUp, true)
	task.delay(cfg.WindUp - 0.05, function()
		batSmash(data.Character, ROYAL_GOLD, true)
		royalHit(data.Character, 8, 2.2)
	end)
end

function Effects.KingsJudgement(data)
	local character = data.Character
	local cfg = Config.Movesets.Tung.Ult[2]
	Anims.zoroSpin(character, cfg.WindUp + 0.2)
	task.delay(cfg.WindUp, function()
		for a = 0, 315, 45 do
			arcSlash(character, a, cfg.Radius, ROYAL_GOLD)
		end
		local r = root(character)
		if r then
			groundDisc(r.Position, cfg.Radius * 2, ROYAL_GOLD, 0.6)
			impact(r.Position, { Color = ROYAL_GOLD, Scale = 2.6, Heavy = true })
			screenFlash(ROYAL_GOLD, 0.25, 0.25)
			shake(r.Position, 1, 0.4)
		end
	end)
end

function Effects.SahurRush(data)
	local character = data.Character
	if data.Whiff then
		slash(character, 28, 7, ROYAL_GOLD, 5, 0.16)
		return
	end
	afterImage(character, ROYAL_GOLD, 0.5)
	Anims.tungM1(character, 1)
	task.spawn(function()
		for i = 1, 3 do
			Anims.tungM1(character, i)
			slash(character, i % 2 == 0 and 30 or -30, 8, ROYAL_GOLD, 5, 0.14)
			task.wait(0.1)
		end
		royalHit(character, 5, 1.8)
	end)
end

function Effects.CrownCrush(data)
	local cfg = Config.Movesets.Tung.Ult[4]
	task.delay(cfg.WindUp - 0.05, function()
		batSmash(data.Character, ROYAL_GOLD, true)
		royalHit(data.Character, 8, 2.6)
		local r = root(data.Character)
		if r then
			fovPunch(r.Position, 10, 0.4)
		end
	end)
end

-- The King's arrival cutscene: crown drops onto the head + banner for all.
function Effects.KingCrown(data)
	local character = data.Character
	local r = root(character)
	-- Hold the royal strut through the whole cutscene.
	Anims.tungKingPose(character)
	local head = character:FindFirstChild("Head")
	local landPos = head and head.Position or (r and r.Position + Vector3.new(0, 2, 0))
	if landPos then
		-- A big golden crown falls from the sky with a light beam.
		local crown = makePart({
			Size = Vector3.new(5, 3, 5),
			CFrame = CFrame.new(landPos + Vector3.new(0, 60, 0)),
			Color = ROYAL_GOLD,
			Material = Enum.Material.Neon,
			Transparency = 0.05,
		})
		addTrail(crown, ROYAL_GOLD, 0.5, 3)
		local beam = makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(120, 8, 8),
			CFrame = CFrame.new(landPos + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = ROYAL_GOLD,
			Transparency = 0.6,
		})
		Debris:AddItem(beam, 1.2)
		tween(crown, 0.7, { CFrame = CFrame.new(landPos + Vector3.new(0, 2.6, 0)) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.7, function()
			shockwave(landPos, 40, ROYAL_GOLD, 0.6, 1.4)
			sparks(landPos, ROYAL_GOLD, 60, 45, 2.4)
			if r then
				shake(r.Position, 1.4, 0.5)
			end
			tween(crown, 0.25, { Transparency = 1 })
		end)
		Debris:AddItem(crown, 1.2)
	end

	-- Full-screen "THE KING HAS ARRIVED" banner for everyone.
	local gui = Instance.new("ScreenGui")
	gui.Name = "KingCutscene"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.Parent = gui

	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.5)
	banner.Size = UDim2.fromScale(0.9, 0.2)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBlack
	banner.TextScaled = true
	banner.TextColor3 = ROYAL_GOLD
	banner.TextStrokeColor3 = Color3.fromRGB(60, 40, 0)
	banner.TextStrokeTransparency = 0
	banner.TextTransparency = 1
	banner.Text = "THE KING HAS ARRIVED"
	banner.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.fromScale(0.5, 0.62)
	subtitle.Size = UDim2.fromScale(0.6, 0.05)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(240, 230, 200)
	subtitle.TextTransparency = 1
	subtitle.Text = data.Character and data.Character.Name or "Tung Tung Tung Sahur"
	subtitle.Parent = gui

	tween(dim, 0.3, { BackgroundTransparency = 0.55 })
	tween(banner, 0.4, { TextTransparency = 0 })
	tween(subtitle, 0.6, { TextTransparency = 0 })
	screenFlash(ROYAL_GOLD, 0.5, 0.6)

	task.delay(2.2, function()
		tween(banner, 0.5, { TextTransparency = 1 })
		tween(subtitle, 0.5, { TextTransparency = 1 })
		tween(dim, 0.5, { BackgroundTransparency = 1 })
		task.delay(0.6, function()
			gui:Destroy()
		end)
	end)
end

function Effects.KingCrownEnd(data)
	local r = root(data.Character)
	if r then
		shockwave(r.Position, 20, ROYAL_GOLD, 0.5, 1)
	end
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
