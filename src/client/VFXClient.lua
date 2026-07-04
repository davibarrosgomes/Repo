--[[
	VFXClient.lua
	Renders every combat visual effect on the client. All effects are
	procedural (parts + tweens + particles) so the game is fully playable
	with zero uploaded assets; sound/animation ids from Config are used
	when provided.
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

local RUBBER_COLOR = Color3.fromRGB(245, 205, 170) -- rubber-arm skin tone
local GEAR5_WHITE = Color3.fromRGB(255, 255, 255)
local TOON_PINK = Color3.fromRGB(255, 130, 200)

local VFXClient = {}

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "CombatEffects"
effectsFolder.Parent = workspace

-- Per-character state for looping effects.
local gear5Emitters = {}
local rubberHighlights = {}

-- ========================================================================
-- Helpers
-- ========================================================================

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		part[key] = value
	end
	part.Parent = effectsFolder
	return part
end

local function tween(instance, time, props, style)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
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

-- Quick camera shake for the local player, scaled down with distance.
local function shake(origin, intensity, duration)
	local myRoot = root(LocalPlayer.Character)
	if not myRoot then
		return
	end
	local dist = (myRoot.Position - origin).Magnitude
	local falloff = math.clamp(1 - dist / 120, 0, 1)
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
			local offset = Vector3.new(
				(math.random() - 0.5) * 2,
				(math.random() - 0.5) * 2,
				0
			) * intensity * decay
			Camera.CFrame *= CFrame.new(offset)
		end
	end)
end

local function shockwave(position, maxSize, color, time)
	local ring = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 1, 1),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	tween(ring, time, { Size = Vector3.new(0.4, maxSize, maxSize), Transparency = 1 })
	Debris:AddItem(ring, time + 0.1)
end

local function burst(position, color, count, speed)
	local holder = makePart({
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
		Transparency = 1,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(speed or 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Enabled = false
	emitter.Parent = holder
	emitter:Emit(count or 25)
	Debris:AddItem(holder, 1.5)
end

-- A stretching rubber arm from `fromCFrame` reaching `range` studs forward.
local function stretchArm(fromCFrame, range, thickness, color, outTime, holdTime)
	local arm = makePart({
		Size = Vector3.new(thickness, thickness, 1),
		CFrame = fromCFrame * CFrame.new(0, 0, -0.5),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
	local fist = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(thickness * 1.8, thickness * 1.8, thickness * 1.8),
		CFrame = fromCFrame * CFrame.new(0, 0, -1),
		Color = color,
	})
	tween(arm, outTime, {
		Size = Vector3.new(thickness, thickness, range),
		CFrame = fromCFrame * CFrame.new(0, 0, -range / 2),
	}, Enum.EasingStyle.Back)
	tween(fist, outTime, { CFrame = fromCFrame * CFrame.new(0, 0, -range) }, Enum.EasingStyle.Back)

	task.delay(outTime + (holdTime or 0.05), function()
		tween(arm, 0.15, { Size = Vector3.new(thickness, thickness, 1), CFrame = fromCFrame * CFrame.new(0, 0, -0.5), Transparency = 1 })
		tween(fist, 0.15, { CFrame = fromCFrame * CFrame.new(0, 0, -1), Transparency = 1 })
	end)
	Debris:AddItem(arm, outTime + 0.5)
	Debris:AddItem(fist, outTime + 0.5)
end

-- Flurry of fists inside a cone in front of the character.
local function fistFlurry(character, duration, range, color, size, perSecond)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local r = root(character)
			if not r then
				break
			end
			local origin = r.CFrame
			local fist = makePart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = 0.1,
				CFrame = origin * CFrame.new(
					(math.random() - 0.5) * 8,
					(math.random() - 0.5) * 5,
					-math.random(3, math.max(4, math.floor(range)))
				),
			})
			tween(fist, 0.12, { Transparency = 1, Size = Vector3.new(size * 0.4, size * 0.4, size * 0.4) })
			Debris:AddItem(fist, 0.15)
			playSound(Config.Sounds.Punch, fist, 0.4, 0.9 + math.random() * 0.3)
			elapsed += task.wait(1 / perSecond)
		end
	end)
end

-- ========================================================================
-- Effect implementations
-- ========================================================================

local Effects = {}

function Effects.HitImpact(data)
	burst(data.Position, Color3.fromRGB(255, 240, 150), data.Heavy and 30 or 12, data.Heavy and 30 or 15)
	playSound(data.Heavy and Config.Sounds.HeavyImpact or Config.Sounds.Punch, workspace, data.Heavy and 1 or 0.6)
	if data.Heavy then
		shake(data.Position, 0.6, 0.25)
	end
end

function Effects.M1Swing(data)
	local r = root(data.Character)
	if not r then
		return
	end
	stretchArm(r.CFrame * CFrame.new(data.Index % 2 == 0 and -1 or 1, 0.5, 0), Config.M1.Range, 0.9, RUBBER_COLOR, 0.08)
end

function Effects.Pistol(data)
	local r = root(data.Character)
	if not r then
		return
	end
	playSound(Config.Sounds.Stretch, r, 1)
	local cfg = Config.Base[1]
	-- Arm pulls back during windup, then fires.
	task.delay(cfg.WindUp - 0.1, function()
		local rNow = root(data.Character)
		if rNow then
			stretchArm(rNow.CFrame * CFrame.new(1, 0.5, 0), data.Range, 1.4, RUBBER_COLOR, 0.12, 0.1)
			shake(rNow.Position, 0.4, 0.2)
		end
	end)
end

function Effects.Bazooka(data)
	local r = root(data.Character)
	if not r then
		return
	end
	local cfg = Config.Base[2]
	task.delay(cfg.WindUp - 0.1, function()
		local rNow = root(data.Character)
		if not rNow then
			return
		end
		stretchArm(rNow.CFrame * CFrame.new(-1.2, 0.5, 0), cfg.Range, 1.3, RUBBER_COLOR, 0.1, 0.15)
		stretchArm(rNow.CFrame * CFrame.new(1.2, 0.5, 0), cfg.Range, 1.3, RUBBER_COLOR, 0.1, 0.15)
		shockwave(rNow.Position + rNow.CFrame.LookVector * cfg.Range * 0.7, 24, Color3.fromRGB(255, 255, 255), 0.4)
		shake(rNow.Position, 0.8, 0.3)
	end)
end

function Effects.Gatling(data)
	fistFlurry(data.Character, (data.Duration or 1.6) + 0.3, data.Range or 15, RUBBER_COLOR, 1.6, 18)
end

function Effects.DawnGatling(data)
	fistFlurry(data.Character, (data.Duration or 1.6) + 0.3, data.Range or 22, GEAR5_WHITE, 2.4, 30)
	local r = root(data.Character)
	if r then
		shake(r.Position, 0.5, data.Duration or 1.6)
	end
end

function Effects.RubberCombo(data)
	local r = root(data.Character)
	if not r then
		return
	end
	if data.Whiff then
		stretchArm(r.CFrame * CFrame.new(1, 0.5, 0), Config.Base[4].Range, 1, RUBBER_COLOR, 0.1)
		return
	end
	shockwave(r.Position, 10, RUBBER_COLOR, 0.3) -- dash pop
	fistFlurry(data.Character, data.Duration or 1.3, 6, RUBBER_COLOR, 1.2, 12)
end

function Effects.ToonForce(data)
	local r = root(data.Character)
	if not r then
		return
	end
	if data.Whiff then
		stretchArm(r.CFrame * CFrame.new(1, 0.5, 0), Config.Gear5[3].Range, 1.2, GEAR5_WHITE, 0.1)
		return
	end
	shockwave(r.Position, 14, TOON_PINK, 0.35)
	fistFlurry(data.Character, data.Duration or 1.6, 7, GEAR5_WHITE, 1.6, 16)
end

function Effects.BajrangGun(data)
	local r = root(data.Character)
	if not r then
		return
	end
	playSound(Config.Sounds.DrumsOfLiberation, r, 1)

	local windUp = data.WindUp or 1.2
	local range = data.Range or 70
	local fistSize = 32

	-- The giant fist charges up behind Luffy...
	local origin = r.CFrame
	local fist = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		CFrame = origin * CFrame.new(0, 14, 22),
		Color = GEAR5_WHITE,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	tween(fist, windUp, { Size = Vector3.new(fistSize, fistSize, fistSize) }, Enum.EasingStyle.Sine)

	-- ...then rockets forward.
	task.delay(windUp, function()
		local rNow = root(data.Character)
		local launch = rNow and rNow.CFrame or origin
		fist.CFrame = launch * CFrame.new(0, 8, 10)
		tween(fist, 0.35, { CFrame = launch * CFrame.new(0, 6, -range) }, Enum.EasingStyle.Quart)
		shake(launch.Position, 2, 0.6)
		task.delay(0.35, function()
			shockwave(fist.Position, 90, GEAR5_WHITE, 0.7)
			burst(fist.Position, GEAR5_WHITE, 60, 60)
			playSound(Config.Sounds.HeavyImpact, fist, 2)
			tween(fist, 0.4, { Transparency = 1, Size = Vector3.new(fistSize * 1.3, fistSize * 1.3, fistSize * 1.3) })
		end)
	end)
	Debris:AddItem(fist, windUp + 1.5)
end

function Effects.DrumsChannel(data)
	local r = root(data.Character)
	if not r then
		return
	end
	playSound(Config.Sounds.DrumsOfLiberation, r, 2)
	-- Dom dom dom... expanding rings on every chest beat.
	task.spawn(function()
		local beats = math.floor((data.Duration or 2.2) / 0.55)
		for _ = 1, beats do
			local rNow = root(data.Character)
			if not rNow then
				break
			end
			shockwave(rNow.Position, 16, GEAR5_WHITE, 0.5)
			shake(rNow.Position, 0.35, 0.15)
			task.wait(0.55)
		end
	end)
end

function Effects.Devour(data)
	local r = root(data.Character)
	local targetRoot = root(data.Target)
	if not r or not targetRoot then
		return
	end

	-- Luffy's head grows disproportionately large and chomps down.
	local mouthPos = targetRoot.Position
	local head = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(r.Position + Vector3.new(0, 2, 0)),
		Color = RUBBER_COLOR,
		Transparency = 0.05,
	})
	tween(head, 0.35, {
		Size = Vector3.new(22, 22, 22),
		CFrame = CFrame.new(mouthPos),
	}, Enum.EasingStyle.Back)

	task.delay(0.45, function()
		-- CHOMP.
		playSound(Config.Sounds.Gulp, head, 2)
		burst(mouthPos, GEAR5_WHITE, 50, 40)
		shockwave(mouthPos, 40, GEAR5_WHITE, 0.5)
		shake(mouthPos, 1.5, 0.4)
		tween(head, 0.25, { Size = Vector3.new(1, 1, 1), Transparency = 1 })
	end)
	Debris:AddItem(head, 1.2)
end

function Effects.DevourWhiff(data)
	local r = root(data.Character)
	if r then
		shockwave(r.Position + r.CFrame.LookVector * 5, 12, RUBBER_COLOR, 0.3)
	end
end

function Effects.Gear5Start(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	playSound(Config.Sounds.Gear5Activate, r, 2)
	shockwave(r.Position, 60, GEAR5_WHITE, 0.8)
	burst(r.Position, GEAR5_WHITE, 60, 50)
	shake(r.Position, 1.2, 0.5)

	-- Persistent white steam-clouds while Gear 5 lasts.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(GEAR5_WHITE)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.4, 1)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = r
	gear5Emitters[character] = emitter
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
		shockwave(r.Position, 20, GEAR5_WHITE, 0.5)
	end
end

function Effects.RubberizeStart(data)
	local character = data.Character
	if rubberHighlights[character] then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = TOON_PINK
	highlight.OutlineColor = TOON_PINK
	highlight.FillTransparency = 0.5
	highlight.Parent = character
	rubberHighlights[character] = highlight

	-- Wobble the tint so the victim looks like jelly.
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

-- ========================================================================
-- Wiring
-- ========================================================================

function VFXClient.Init()
	Remotes.get("VFX").OnClientEvent:Connect(function(effectName, data)
		local effect = Effects[effectName]
		if effect and type(data) == "table" then
			task.spawn(effect, data)
		end
	end)
end

return VFXClient
