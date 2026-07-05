--[[
	=====================================================================
	ONE PIECE BATTLEGROUNDS  -  CLIENT  (paste-ready, single LocalScript)
	=====================================================================
	Insert a  >> LocalScript <<  in StarterPlayer > StarterPlayerScripts
	and paste this whole file into it. Requires the SERVER Script to be
	installed in ServerScriptService (it creates the RemoteEvents).

	Controls:  Left click = M1 combo | 1-4 = skills | Q = dash
	           F (hold) = block | G = Gear 5 ult (when the bar is full)
	=====================================================================
]]

-- ====================================================================
-- MODULE: Config   (src/shared/Config.lua)
-- ====================================================================
local Config = (function()
--[[
	Config.lua
	Central balance / tuning data for the whole game.
	All damage numbers, cooldowns, ranges and timings live here so the
	game can be rebalanced without touching combat logic.
]]

local Config = {}

-- ========================================================================
-- General character stats
-- ========================================================================
Config.Character = {
	BaseWalkSpeed = 16,
	BaseJumpPower = 50,
	MaxHealth = 100,
	SpawnProtectionTime = 3, -- seconds of ForceField after spawning
}

-- ========================================================================
-- Dash (Q)
-- ========================================================================
Config.Dash = {
	Speed = 90,
	Duration = 0.22,
	UpBoost = 4,
	Cooldown = 3,
}

-- ========================================================================
-- Block (hold F)
-- ========================================================================
Config.Block = {
	MaxHealth = 45,        -- damage a full guard can absorb
	RegenPerSecond = 9,    -- regenerates while not blocking
	WalkSpeed = 6,         -- movement while guarding
	BreakLockout = 4,      -- seconds you cannot re-guard after a guard break
	BreakRagdoll = 2.5,    -- ragdoll punish when the guard shatters
}

-- ========================================================================
-- M1 (left click) combo
-- ========================================================================
Config.M1 = {
	Damage = 5,
	Range = 7,            -- studs in front of the attacker
	Width = 5,
	ComboHits = 4,        -- hits in a full chain
	SwingCooldown = 0.35, -- time between swings inside the chain
	ComboResetTime = 1.2, -- idle time before the chain resets
	ChainCooldown = 1.4,  -- lockout after finishing a full chain
	HitStun = 0.45,
	FinisherKnockback = 55,
	FinisherRagdoll = 1.2,
}

-- ========================================================================
-- Luffy - base moveset (slots 1-4)
-- ========================================================================
Config.Base = {
	[1] = {
		Id = "Pistol",
		Name = "Gomu Gomu no Pistol",
		Damage = 16,
		Cooldown = 6,
		WindUp = 0.35,
		Range = 32, -- how far the arm stretches
		Width = 6,
		Knockback = 70,
		RagdollTime = 1.5,
	},
	[2] = {
		Id = "Bazooka",
		Name = "Gomu Gomu no Bazooka",
		Damage = 24,
		Cooldown = 10,
		WindUp = 0.5,
		Range = 13,
		Width = 11,
		Knockback = 110,
		RagdollTime = 2.2,
	},
	[3] = {
		Id = "Gatling",
		Name = "Gomu Gomu no Gatling",
		DamagePerHit = 3,
		Hits = 10,
		Duration = 1.6,
		Cooldown = 14,
		WindUp = 0.4,
		Range = 15,
		Width = 10,
		FinalKnockback = 60,
		FinalRagdoll = 1.5,
	},
	[4] = {
		Id = "RubberCombo",
		Name = "Rubber Combo",
		DamagePerHit = 4,
		Hits = 5,
		HitInterval = 0.2,
		Cooldown = 18,
		DashRange = 26, -- how far Luffy can snap to a target
		Range = 8,      -- fallback swipe range if nobody is close
		FinalKnockback = 80,
		FinalRagdoll = 1.8,
	},
}

-- ========================================================================
-- Luffy - Gear 5 moveset (slots 1-4 while the ult is active)
-- ========================================================================
Config.Gear5 = {
	[1] = {
		Id = "BajrangGun",
		Name = "Gomu Gomu no Bajrang Gun",
		Damage = 60,
		Cooldown = 20,
		WindUp = 1.2,
		Range = 70,
		Width = 34, -- the fist is island sized
		Height = 34,
		Knockback = 160,
		RagdollTime = 3,
	},
	[2] = {
		Id = "DawnGatling",
		Name = "Gomu Gomu no Dawn Gatling",
		DamagePerHit = 4,
		Hits = 14,
		Duration = 1.6,
		Cooldown = 12,
		WindUp = 0.3,
		Range = 22,
		Width = 16,
		FinalKnockback = 80,
		FinalRagdoll = 2,
	},
	[3] = {
		Id = "ToonForce",
		Name = "Toon Force",
		DamagePerHit = 5,
		Hits = 6,
		HitInterval = 0.22,
		Cooldown = 18,
		DashRange = 24,
		Range = 9,
		ParalyzeTime = 3.5, -- rubberized paralysis after the last punch
	},
	[4] = {
		Id = "Devour",
		Name = "Drums of Liberation",
		Cooldown = 45,
		WindUp = 2.2,   -- chest beating channel (huge telegraph = fair one-shot)
		Range = 12,
		Width = 10,
		OneUsePerUlt = true,
		Damage = 10000, -- one hit kill
	},
}

-- ========================================================================
-- Ultimate (Gear 5)
-- ========================================================================
Config.Ult = {
	MaxCharge = 100,
	ChargePerDamageDealt = 0.35, -- ult charge gained per point of damage dealt
	ChargePerDamageTaken = 0.15, -- ult charge gained per point of damage taken
	Duration = 30,               -- seconds Gear 5 lasts
	HealPercent = 0.25,          -- heal on activation
	WalkSpeedBonus = 8,
	JumpPowerBonus = 25,
}

-- ========================================================================
-- Assets. Replace the zeros with your own uploaded asset ids.
-- Every consumer of this table safely skips ids that are 0.
-- ========================================================================
Config.Sounds = {
	Punch = 0,
	HeavyImpact = 0,
	Stretch = 0,
	Gear5Activate = 0,
	DrumsOfLiberation = 0, -- the Gear 5 heartbeat drums
	Gulp = 0,
}

Config.Animations = {
	M1 = { 0, 0, 0, 0 }, -- one per swing in the chain
	Pistol = 0,
	Bazooka = 0,
	Gatling = 0,
	RubberCombo = 0,
	BajrangGun = 0,
	DawnGatling = 0,
	ToonForce = 0,
	Devour = 0,
	Gear5Idle = 0,
}

return Config
end)()

-- ====================================================================
-- MODULE: Remotes   (src/shared/Remotes.lua)
-- ====================================================================
local Remotes = (function()
--[[
	Remotes.lua
	Creates (on the server) and fetches (on either side) the RemoteEvents
	used by the combat system.

	UseSkill     client -> server : (slot: number 1-4)
	M1           client -> server : ()
	ActivateUlt  client -> server : ()
	Dash         client -> server : ()
	Block        client -> server : (enabled: boolean)
	VFX          server -> client : (effectName: string, data: table)
	HUDUpdate    server -> client : (kind: string, ...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "UseSkill", "M1", "ActivateUlt", "Dash", "Block", "VFX", "HUDUpdate" }

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, name in NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

function Remotes.get(name)
	return folder:WaitForChild(name)
end

return Remotes
end)()

-- ====================================================================
-- MODULE: HUD   (src/client/HUD.lua)
-- ====================================================================
local HUD = (function()
--[[
	HUD.lua
	Builds the combat HUD entirely in code:
	  - 4 skill slots (keys 1-4) with name, keybind and cooldown sweep
	  - ult charge bar that flashes "GEAR 5 READY - PRESS G" at full charge
	  - slot names/colors swap automatically while Gear 5 is active
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")


local LocalPlayer = Players.LocalPlayer

local BG = Color3.fromRGB(25, 25, 30)
local ACCENT_BASE = Color3.fromRGB(220, 60, 60)   -- straw hat red
local ACCENT_GEAR5 = Color3.fromRGB(255, 255, 255)
local ULT_COLOR = Color3.fromRGB(255, 200, 60)

local BLOCK_COLOR = Color3.fromRGB(180, 210, 255)

local HUD = {}

local slots = {}       -- [slot] = { frame, nameLabel, cooldownOverlay, cooldownLabel }
local ultFill, ultLabel, ultBar
local blockFill
local dashChip
local gear5Active = false

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function slotName(slot)
	local cfg = gear5Active and Config.Gear5[slot] or Config.Base[slot]
	return cfg and cfg.Name or "?"
end

local function refreshSlotNames()
	for slot, ui in slots do
		ui.nameLabel.Text = slotName(slot)
		ui.keyLabel.TextColor3 = gear5Active and ACCENT_GEAR5 or ACCENT_BASE
		ui.stroke.Color = gear5Active and ACCENT_GEAR5 or ACCENT_BASE
	end
end

-- ========================================================================
-- Construction
-- ========================================================================

function HUD.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Skill bar ----------------------------------------------------------
	local bar = Instance.new("Frame")
	bar.Name = "SkillBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -18)
	bar.Size = UDim2.new(0, 4 * 92 + 3 * 10, 0, 92)
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = bar

	for slot = 1, 4 do
		local frame = Instance.new("Frame")
		frame.Name = "Slot" .. slot
		frame.LayoutOrder = slot
		frame.Size = UDim2.new(0, 92, 0, 92)
		frame.BackgroundColor3 = BG
		frame.BackgroundTransparency = 0.15
		frame.Parent = bar
		corner(frame, 10)

		local stroke = Instance.new("UIStroke")
		stroke.Color = ACCENT_BASE
		stroke.Thickness = 1.5
		stroke.Transparency = 0.3
		stroke.Parent = frame

		local keyLabel = Instance.new("TextLabel")
		keyLabel.BackgroundTransparency = 1
		keyLabel.Position = UDim2.new(0, 6, 0, 4)
		keyLabel.Size = UDim2.new(0, 24, 0, 24)
		keyLabel.Font = Enum.Font.GothamBlack
		keyLabel.TextSize = 20
		keyLabel.TextColor3 = ACCENT_BASE
		keyLabel.Text = tostring(slot)
		keyLabel.TextXAlignment = Enum.TextXAlignment.Left
		keyLabel.Parent = frame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.AnchorPoint = Vector2.new(0.5, 1)
		nameLabel.Position = UDim2.new(0.5, 0, 1, -6)
		nameLabel.Size = UDim2.new(1, -10, 0, 40)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextWrapped = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Text = ""
		nameLabel.Parent = frame

		-- Cooldown overlay sweeps from full height down to zero.
		local overlay = Instance.new("Frame")
		overlay.Name = "Cooldown"
		overlay.AnchorPoint = Vector2.new(0, 1)
		overlay.Position = UDim2.new(0, 0, 1, 0)
		overlay.Size = UDim2.new(1, 0, 0, 0)
		overlay.BackgroundColor3 = Color3.new(0, 0, 0)
		overlay.BackgroundTransparency = 0.4
		overlay.BorderSizePixel = 0
		overlay.ZIndex = 2
		overlay.Parent = frame
		corner(overlay, 10)

		local cooldownLabel = Instance.new("TextLabel")
		cooldownLabel.BackgroundTransparency = 1
		cooldownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		cooldownLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
		cooldownLabel.Size = UDim2.new(1, 0, 0, 30)
		cooldownLabel.Font = Enum.Font.GothamBlack
		cooldownLabel.TextSize = 24
		cooldownLabel.TextColor3 = Color3.new(1, 1, 1)
		cooldownLabel.Text = ""
		cooldownLabel.ZIndex = 3
		cooldownLabel.Parent = frame

		slots[slot] = {
			frame = frame,
			stroke = stroke,
			keyLabel = keyLabel,
			nameLabel = nameLabel,
			overlay = overlay,
			cooldownLabel = cooldownLabel,
			cooldownToken = 0,
		}
	end

	-- Ult bar -------------------------------------------------------------
	ultBar = Instance.new("Frame")
	ultBar.Name = "UltBar"
	ultBar.AnchorPoint = Vector2.new(0.5, 1)
	ultBar.Position = UDim2.new(0.5, 0, 1, -120)
	ultBar.Size = UDim2.new(0, 340, 0, 18)
	ultBar.BackgroundColor3 = BG
	ultBar.BackgroundTransparency = 0.15
	ultBar.Parent = gui
	corner(ultBar, 9)

	ultFill = Instance.new("Frame")
	ultFill.BackgroundColor3 = ULT_COLOR
	ultFill.BorderSizePixel = 0
	ultFill.Size = UDim2.new(0, 0, 1, 0)
	ultFill.Parent = ultBar
	corner(ultFill, 9)

	ultLabel = Instance.new("TextLabel")
	ultLabel.BackgroundTransparency = 1
	ultLabel.Size = UDim2.new(1, 0, 1, 0)
	ultLabel.Font = Enum.Font.GothamBlack
	ultLabel.TextSize = 12
	ultLabel.TextColor3 = Color3.new(1, 1, 1)
	ultLabel.TextStrokeTransparency = 0.5
	ultLabel.Text = "ULT 0%"
	ultLabel.ZIndex = 2
	ultLabel.Parent = ultBar

	-- Block bar (guard durability) ---------------------------------------
	local blockBar = Instance.new("Frame")
	blockBar.Name = "BlockBar"
	blockBar.AnchorPoint = Vector2.new(0.5, 1)
	blockBar.Position = UDim2.new(0.5, 0, 1, -144)
	blockBar.Size = UDim2.new(0, 340, 0, 8)
	blockBar.BackgroundColor3 = BG
	blockBar.BackgroundTransparency = 0.15
	blockBar.Parent = gui
	corner(blockBar, 4)

	blockFill = Instance.new("Frame")
	blockFill.BackgroundColor3 = BLOCK_COLOR
	blockFill.BorderSizePixel = 0
	blockFill.Size = UDim2.new(1, 0, 1, 0)
	blockFill.Parent = blockBar
	corner(blockFill, 4)

	-- Dash chip (Q) --------------------------------------------------------
	dashChip = Instance.new("Frame")
	dashChip.Name = "DashChip"
	dashChip.AnchorPoint = Vector2.new(1, 1)
	dashChip.Position = UDim2.new(0.5, -(2 * 92 + 2 * 10 + 8), 1, -18)
	dashChip.Size = UDim2.new(0, 44, 0, 44)
	dashChip.BackgroundColor3 = BG
	dashChip.BackgroundTransparency = 0.15
	dashChip.Parent = gui
	corner(dashChip, 8)

	local dashLabel = Instance.new("TextLabel")
	dashLabel.BackgroundTransparency = 1
	dashLabel.Size = UDim2.new(1, 0, 1, 0)
	dashLabel.Font = Enum.Font.GothamBlack
	dashLabel.TextSize = 16
	dashLabel.TextColor3 = Color3.new(1, 1, 1)
	dashLabel.Text = "Q"
	dashLabel.Parent = dashChip

	local dashOverlay = Instance.new("Frame")
	dashOverlay.Name = "Cooldown"
	dashOverlay.AnchorPoint = Vector2.new(0, 1)
	dashOverlay.Position = UDim2.new(0, 0, 1, 0)
	dashOverlay.Size = UDim2.new(1, 0, 0, 0)
	dashOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	dashOverlay.BackgroundTransparency = 0.4
	dashOverlay.BorderSizePixel = 0
	dashOverlay.ZIndex = 2
	dashOverlay.Parent = dashChip
	corner(dashOverlay, 8)

	refreshSlotNames()

	-- Guard durability lives as an attribute on the character.
	local function bindCharacter(character)
		local function onBlockHealth()
			local blockHealth = character:GetAttribute("BlockHealth") or Config.Block.MaxHealth
			local ratio = math.clamp(blockHealth / Config.Block.MaxHealth, 0, 1)
			blockFill.Size = UDim2.new(ratio, 0, 1, 0)
			blockFill.BackgroundColor3 = ratio < 0.3 and Color3.fromRGB(255, 120, 120) or BLOCK_COLOR
		end
		character:GetAttributeChangedSignal("BlockHealth"):Connect(onBlockHealth)
		onBlockHealth()
	end
	LocalPlayer.CharacterAdded:Connect(bindCharacter)
	if LocalPlayer.Character then
		bindCharacter(LocalPlayer.Character)
	end

	-- Ult charge is an attribute on the player, kept up to date by the server.
	local function onCharge()
		HUD.SetUltCharge(LocalPlayer:GetAttribute("UltCharge") or 0)
	end
	LocalPlayer:GetAttributeChangedSignal("UltCharge"):Connect(onCharge)
	onCharge()
end

-- ========================================================================
-- Updates
-- ========================================================================

function HUD.SetCooldown(slot, duration)
	local ui = slots[slot]
	if not ui then
		return
	end
	ui.cooldownToken += 1
	local token = ui.cooldownToken

	ui.overlay.Size = UDim2.new(1, 0, 1, 0)
	TweenService:Create(ui.overlay, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(1, 0, 0, 0),
	}):Play()

	task.spawn(function()
		local remaining = duration
		while remaining > 0 and ui.cooldownToken == token do
			ui.cooldownLabel.Text = remaining >= 10 and tostring(math.ceil(remaining)) or string.format("%.1f", remaining)
			task.wait(0.1)
			remaining -= 0.1
		end
		if ui.cooldownToken == token then
			ui.cooldownLabel.Text = ""
			ui.overlay.Size = UDim2.new(1, 0, 0, 0)
		end
	end)
end

function HUD.SetDashCooldown(duration)
	local overlay = dashChip and dashChip:FindFirstChild("Cooldown")
	if not overlay then
		return
	end
	overlay.Size = UDim2.new(1, 0, 1, 0)
	TweenService:Create(overlay, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(1, 0, 0, 0),
	}):Play()
end

function HUD.ClearCooldowns()
	for _, ui in slots do
		ui.cooldownToken += 1
		ui.cooldownLabel.Text = ""
		ui.overlay.Size = UDim2.new(1, 0, 0, 0)
	end
end

function HUD.SetUltCharge(charge)
	local ratio = math.clamp(charge / Config.Ult.MaxCharge, 0, 1)
	TweenService:Create(ultFill, TweenInfo.new(0.2), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
	if gear5Active then
		ultLabel.Text = "GEAR 5"
	elseif ratio >= 1 then
		ultLabel.Text = "GEAR 5 READY - PRESS G"
		ultFill.BackgroundColor3 = Color3.new(1, 1, 1)
	else
		ultLabel.Text = ("ULT %d%%"):format(math.floor(ratio * 100))
		ultFill.BackgroundColor3 = ULT_COLOR
	end
end

function HUD.SetUltState(active, duration)
	gear5Active = active
	refreshSlotNames()
	HUD.ClearCooldowns()

	if active then
		ultLabel.Text = "GEAR 5"
		ultFill.BackgroundColor3 = Color3.new(1, 1, 1)
		ultFill.Size = UDim2.new(1, 0, 1, 0)
		-- Drain the bar over the ult duration as a timer.
		TweenService:Create(ultFill, TweenInfo.new(duration or Config.Ult.Duration, Enum.EasingStyle.Linear), {
			Size = UDim2.new(0, 0, 1, 0),
		}):Play()
	else
		HUD.SetUltCharge(LocalPlayer:GetAttribute("UltCharge") or 0)
	end
end

return HUD
end)()

-- ====================================================================
-- MODULE: VFXClient   (src/client/VFXClient.lua)
-- ====================================================================
local VFXClient = (function()
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
local blockHighlights = {}

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

function Effects.Dash(data)
	local r = root(data.Character)
	if not r then
		return
	end
	-- Quick white streak trailing opposite the dash direction.
	local direction = data.Direction or r.CFrame.LookVector
	local streak = makePart({
		Size = Vector3.new(1.5, 1.5, 8),
		CFrame = CFrame.lookAlong(r.Position - direction * 4, direction),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	})
	tween(streak, 0.25, { Size = Vector3.new(0.2, 0.2, 14), Transparency = 1 })
	Debris:AddItem(streak, 0.3)
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
	burst(data.Position, Color3.fromRGB(180, 210, 255), 10, 18)
	playSound(Config.Sounds.Punch, workspace, 0.5, 1.4)
end

function Effects.GuardBreak(data)
	burst(data.Position, Color3.fromRGB(255, 90, 90), 35, 35)
	shockwave(data.Position, 16, Color3.fromRGB(255, 120, 120), 0.4)
	playSound(Config.Sounds.HeavyImpact, workspace, 1.2)
	shake(data.Position, 0.8, 0.3)
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
end)()

-- ====================================================================
-- MAIN: init.client   (src/client/init.client.lua)
-- ====================================================================
--[[
	init.client.lua
	Client entry point: input handling + HUD/VFX bootstrapping.

	Controls:
		Left Mouse  - M1 combo
		1 / 2 / 3 / 4 - skills
		Q           - dash
		F (hold)    - block
		G           - activate Gear 5 (when the ult bar is full)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")



local LocalPlayer = Players.LocalPlayer

local UseSkill = Remotes.get("UseSkill")
local M1 = Remotes.get("M1")
local ActivateUlt = Remotes.get("ActivateUlt")
local Dash = Remotes.get("Dash")
local Block = Remotes.get("Block")
local HUDUpdate = Remotes.get("HUDUpdate")

HUD.Init()
VFXClient.Init()

local SKILL_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

-- The server is authoritative; this only avoids spamming remotes while
-- visibly stunned / mid-move.
local function canAct()
	local character = LocalPlayer.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	return not (
		character:GetAttribute("Stunned")
		or character:GetAttribute("Ragdolled")
		or character:GetAttribute("Rubberized")
		or character:GetAttribute("Busy")
	)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if canAct() then
			M1:FireServer()
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.G then
		ActivateUlt:FireServer()
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		if canAct() then
			Dash:FireServer()
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.F then
		Block:FireServer(true)
		return
	end

	local slot = SKILL_KEYS[input.KeyCode]
	if slot and canAct() then
		UseSkill:FireServer(slot)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		Block:FireServer(false)
	end
end)

HUDUpdate.OnClientEvent:Connect(function(kind, ...)
	if kind == "Cooldown" then
		HUD.SetCooldown(...)
	elseif kind == "UltState" then
		HUD.SetUltState(...)
	elseif kind == "DashCooldown" then
		HUD.SetDashCooldown(...)
	end
end)
