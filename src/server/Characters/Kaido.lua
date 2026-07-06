--[[
	Kaido.lua
	Server-side implementation of Kaido: a heavy bruiser wielding a spiked
	kanabo. His ultimate transforms him into his Azure Dragon form (Uo Uo no
	Mi) - he grows, gains dragon features + a flame cloud, and his moveset
	becomes devastating breath-and-storm attacks.

	Base moveset (slots 1-4):
		1  Ragnaraku    - overhead kanabo smash with a lightning strike
		2  Kaifu        - a ranged wind-blade projectile
		3  Kanabo Sweep - a spinning club that hits everyone around him
		4  Bolo Breath  - a short-range fire-breath cone (applies burn)

	Ult (G): AZURE DRAGON for a limited time; slots become:
		1  Boro Breath    - a colossal fire beam
		2  Blast Breath   - a heat cannonball explosion
		3  Dragon Twister - a tornado that launches everyone up
		4  Raimei Hakke   - a colossal lightning claw smash

	Interface matches the other characters (UseSkill, M1, ActivateUlt,
	DeactivateUlt, ForgetPlayer, Setup).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Combat = require(script.Parent.Parent.CombatService)

local VFX = Remotes.get("VFX")
local HUDUpdate = Remotes.get("HUDUpdate")

local FIRE = Color3.fromRGB(255, 140, 40)
local AZURE = Color3.fromRGB(90, 160, 220)

local Kaido = {}

local MY = Config.Movesets.Kaido

local m1State = {}
local dragonTokens = {}

-- ========================================================================
-- Helpers
-- ========================================================================

local function isDragon(character)
	return character:GetAttribute("Dragon") == true
end

local function targetsAround(character, radius)
	local root = Combat.Root(character)
	if not root then
		return {}
	end
	return Combat.GetTargetsInBox(root.CFrame, Vector3.new(radius * 2, 16, radius * 2), character)
end

local function aimDirection(character, range)
	local root = Combat.Root(character)
	if not root then
		return Vector3.zAxis
	end
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local target = Combat.NearestTarget(character, range or 80)
	if target then
		local targetRoot = Combat.Root(target)
		if targetRoot then
			local to = (targetRoot.Position + Vector3.new(0, 1, 0)) - origin
			if to.Magnitude > 0.1 and Combat.FlatLook(character):Dot(Vector3.new(to.X, 0, to.Z)) > 0 then
				return to.Unit
			end
		end
	end
	return Combat.FlatLook(character)
end

local function muzzleOrigin(character, dir)
	local root = Combat.Root(character)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = flat.Magnitude > 0.001 and flat.Unit or Combat.FlatLook(character)
	return root.Position + Vector3.new(0, 1.5, 0) + flat * 3
end

-- ========================================================================
-- The kanabo (welded on spawn)
-- ========================================================================

local function makePart(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	return p
end

function Kaido.Setup(_player, character)
	local hand = character:WaitForChild("RightHand", 5) or character:FindFirstChild("Right Arm")
	if not hand or not character.Parent then
		return
	end
	local existing = character:FindFirstChild("Kanabo")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Kanabo"
	folder.Parent = character

	local grip = CFrame.new(0, 0, -0.7) * CFrame.Angles(math.rad(-95), 0, 0)
	local handle = makePart("Handle", Vector3.new(0.5, 3, 0.5), Color3.fromRGB(70, 50, 34), Enum.Material.Wood)
	local head = makePart("Barrel", Vector3.new(1.6, 3.4, 1.6), Color3.fromRGB(80, 82, 90), Enum.Material.Metal)
	local pieces = {
		{ part = handle, offset = CFrame.new(0, 0, 0) },
		{ part = head, offset = CFrame.new(0, 3.1, 0) },
	}
	for _, entry in pieces do
		local part = entry.part
		part.Parent = folder
		local weld = Instance.new("Weld")
		weld.Part0 = hand
		weld.Part1 = part
		weld.C0 = grip * entry.offset
		weld.Parent = part
	end
	-- Spikes around the head.
	for i = 0, 5 do
		local angle = math.rad(i * 60)
		local spike = makePart("Spike", Vector3.new(0.4, 0.9, 0.4), Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
		spike.Parent = folder
		local weld = Instance.new("Weld")
		weld.Part0 = hand
		weld.Part1 = spike
		weld.C0 = grip * CFrame.new(math.cos(angle) * 1, 3.1, math.sin(angle) * 1) * CFrame.Angles(math.rad(90), 0, angle)
		weld.Parent = spike
	end
end

-- ========================================================================
-- M1 combo (kanabo swings)
-- ========================================================================

function Kaido.M1(player, character)
	if not Combat.IsActionable(character) then
		return
	end
	local cfg = Config.M1
	local now = os.clock()
	local state = m1State[player]
	if not state then
		state = { count = 0, lastSwing = 0, lockedUntil = 0 }
		m1State[player] = state
	end
	if now < state.lockedUntil then
		return
	end
	if now - state.lastSwing < cfg.SwingCooldown then
		return
	end
	if now - state.lastSwing > cfg.ComboResetTime then
		state.count = 0
	end
	state.count += 1
	state.lastSwing = now
	local isFinisher = state.count >= cfg.ComboHits
	if isFinisher then
		state.count = 0
		state.lockedUntil = now + cfg.ChainCooldown
	end

	local look = Combat.FlatLook(character)
	VFX:FireAllClients("KaidoM1", { Character = character, Index = isFinisher and cfg.ComboHits or state.count })
	for _, target in Combat.FrontHitbox(character, cfg.Range + 2, cfg.Width + 1) do
		if isFinisher then
			Combat.DealDamage(player, target, cfg.Damage + 3, {
				KnockbackDir = look,
				KnockbackPower = cfg.FinisherKnockback + 20,
				RagdollTime = cfg.FinisherRagdoll,
			})
		else
			Combat.DealDamage(player, target, cfg.Damage + 3, { StunTime = cfg.HitStun })
		end
	end
end

-- ========================================================================
-- Shared move shapes
-- ========================================================================

local function forwardStrike(player, character, cfg, effectName)
	Combat.SetBusy(character, cfg.WindUp + 0.4, true)
	VFX:FireAllClients(effectName, { Character = character, WindUp = cfg.WindUp, Range = cfg.Range })
	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end
	local look = Combat.FlatLook(character)
	for _, target in Combat.FrontHitbox(character, cfg.Range, cfg.Width) do
		Combat.DealDamage(player, target, cfg.Damage, {
			KnockbackDir = look,
			KnockbackPower = cfg.Knockback,
			KnockbackUp = cfg.Knockback * 0.3,
			RagdollTime = cfg.RagdollTime,
		})
		if cfg.Burn then
			Combat.Burn(player, target, cfg.Burn.Dps, cfg.Burn.Time)
		end
	end
end

local function coneBreath(player, character, cfg, effectName)
	Combat.SetBusy(character, cfg.WindUp + 0.35, true)
	VFX:FireAllClients(effectName, { Character = character, WindUp = cfg.WindUp, Range = cfg.Range })
	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end
	local look = Combat.FlatLook(character)
	for _, target in Combat.FrontHitbox(character, cfg.Range, cfg.Width, 16) do
		Combat.DealDamage(player, target, cfg.Damage, {
			KnockbackDir = look,
			KnockbackPower = cfg.Knockback,
			RagdollTime = cfg.RagdollTime,
		})
		if cfg.Burn then
			Combat.Burn(player, target, cfg.Burn.Dps, cfg.Burn.Time)
		end
	end
end

local function spinAoE(player, character, cfg, effectName)
	Combat.SetBusy(character, cfg.WindUp + cfg.Hits * cfg.HitInterval + 0.2, true)
	VFX:FireAllClients(effectName, { Character = character, Radius = cfg.Radius, Hits = cfg.Hits })
	task.wait(cfg.WindUp)
	for hit = 1, cfg.Hits do
		if not Combat.IsAlive(character) or character:GetAttribute("Stunned") then
			break
		end
		local root = Combat.Root(character)
		local isLast = hit == cfg.Hits
		for _, target in targetsAround(character, cfg.Radius) do
			local opts = { StunTime = cfg.HitInterval * 2.5 }
			if isLast then
				opts.RagdollTime = cfg.RagdollTime
				local targetRoot = Combat.Root(target)
				local dir = root and targetRoot and (targetRoot.Position - root.Position) or Vector3.zAxis
				opts.KnockbackDir = dir
				opts.KnockbackPower = cfg.Knockback
				opts.KnockbackUp = cfg.LaunchPower or cfg.Knockback * 0.4
			end
			Combat.DealDamage(player, target, cfg.DamagePerHit, opts)
		end
		if not isLast then
			task.wait(cfg.HitInterval)
		end
	end
end

local function breathProjectile(player, character, cfg, effectName, color)
	Combat.SetBusy(character, cfg.WindUp + 0.3, true)
	VFX:FireAllClients(effectName, { Character = character, WindUp = cfg.WindUp })
	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end
	local dir = aimDirection(character, 100)
	Combat.Projectile(player, character, {
		Origin = muzzleOrigin(character, dir),
		Direction = dir,
		Speed = cfg.Speed,
		Life = cfg.Life,
		Radius = cfg.Radius,
		Damage = cfg.Damage,
		ExplodeRadius = cfg.ExplodeRadius,
		Knockback = cfg.Knockback,
		KnockbackUp = cfg.Knockback * 0.3,
		RagdollTime = cfg.RagdollTime,
		Burn = cfg.Burn,
		Color = color or FIRE,
	})
end

-- ========================================================================
-- Base moveset
-- ========================================================================

local function ragnaraku(player, character)
	forwardStrike(player, character, MY.Base[1], "Ragnaraku")
end
local function kaifu(player, character)
	breathProjectile(player, character, MY.Base[2], "Kaifu", AZURE)
end
local function kanaboSweep(player, character)
	spinAoE(player, character, MY.Base[3], "KanaboSweep")
end
local function boloBreath(player, character)
	coneBreath(player, character, MY.Base[4], "BoloBreath")
end

-- ========================================================================
-- Dragon moveset
-- ========================================================================

local function dragonBoro(player, character)
	breathProjectile(player, character, MY.Ult[1], "DragonBoroBreath", FIRE)
end
local function blastBreath(player, character)
	breathProjectile(player, character, MY.Ult[2], "BlastBreath", Color3.fromRGB(255, 100, 40))
end
local function dragonTwister(player, character)
	spinAoE(player, character, MY.Ult[3], "DragonTwister")
end
local function raimeiHakke(player, character)
	forwardStrike(player, character, MY.Ult[4], "RaimeiHakke")
end

-- ========================================================================
-- Ult: Azure Dragon transformation
-- ========================================================================

local function scaleValue(humanoid, name, target, time)
	local value = humanoid:FindFirstChild(name)
	if value and value:IsA("NumberValue") then
		local TweenService = game:GetService("TweenService")
		TweenService:Create(value, TweenInfo.new(time or 0.6), { Value = target }):Play()
	end
end

function Kaido.ActivateUlt(player, character)
	if not Combat.IsActionable(character) then
		return false
	end
	if isDragon(character) then
		return false
	end
	local charge = player:GetAttribute("UltCharge") or 0
	if charge < Config.Ult.MaxCharge then
		return false
	end

	player:SetAttribute("UltCharge", 0)
	character:SetAttribute("Dragon", true)

	local token = (dragonTokens[player] or 0) + 1
	dragonTokens[player] = token

	local humanoid = Combat.Humanoid(character)
	if humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.Ult.HealPercent)
		-- Grow into the dragon form.
		scaleValue(humanoid, "BodyHeightScale", 1.35, 0.7)
		scaleValue(humanoid, "BodyWidthScale", 1.35, 0.7)
		scaleValue(humanoid, "BodyDepthScale", 1.35, 0.7)
		scaleValue(humanoid, "HeadScale", 1.4, 0.7)
	end

	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed + Config.Ult.WalkSpeedBonus)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower + Config.Ult.JumpPowerBonus)
	Combat.RefreshMovement(character)

	local highlight = Instance.new("Highlight")
	highlight.Name = "DragonHighlight"
	highlight.FillColor = Color3.fromRGB(30, 60, 90)
	highlight.OutlineColor = AZURE
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0
	highlight.Parent = character

	-- Dragon features welded to the head (horns + whiskers).
	local head = character:FindFirstChild("Head")
	if head then
		local features = Instance.new("Folder")
		features.Name = "DragonFeatures"
		for _, side in { -1, 1 } do
			local horn = makePart("Horn", Vector3.new(0.4, 3, 0.4), Color3.fromRGB(210, 200, 170), Enum.Material.SmoothPlastic)
			horn.Parent = features
			local weld = Instance.new("Weld")
			weld.Part0 = head
			weld.Part1 = horn
			weld.C0 = CFrame.new(0.5 * side, 1, -0.2) * CFrame.Angles(math.rad(-30), 0, math.rad(20 * side))
			weld.Parent = horn

			local whisker = makePart("Whisker", Vector3.new(0.15, 4, 0.15), AZURE, Enum.Material.Neon)
			whisker.Parent = features
			local wweld = Instance.new("Weld")
			wweld.Part0 = head
			wweld.Part1 = whisker
			wweld.C0 = CFrame.new(0.6 * side, -0.2, -0.6) * CFrame.Angles(math.rad(80), 0, math.rad(30 * side))
			wweld.Parent = whisker
		end
		features.Parent = character
	end

	VFX:FireAllClients("DragonStart", { Character = character, Duration = Config.Ult.Duration })
	HUDUpdate:FireClient(player, "UltState", true, Config.Ult.Duration)

	task.delay(Config.Ult.Duration, function()
		if dragonTokens[player] == token then
			Kaido.DeactivateUlt(player, character)
		end
	end)

	return true
end

function Kaido.DeactivateUlt(player, character)
	if not character or not character.Parent or not isDragon(character) then
		return
	end
	character:SetAttribute("Dragon", false)
	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower)
	Combat.RefreshMovement(character)

	local humanoid = Combat.Humanoid(character)
	if humanoid then
		scaleValue(humanoid, "BodyHeightScale", 1, 0.5)
		scaleValue(humanoid, "BodyWidthScale", 1, 0.5)
		scaleValue(humanoid, "BodyDepthScale", 1, 0.5)
		scaleValue(humanoid, "HeadScale", 1, 0.5)
	end

	local highlight = character:FindFirstChild("DragonHighlight")
	if highlight then
		highlight:Destroy()
	end
	local features = character:FindFirstChild("DragonFeatures")
	if features then
		features:Destroy()
	end

	VFX:FireAllClients("DragonEnd", { Character = character })
	if player.Parent then
		HUDUpdate:FireClient(player, "UltState", false)
	end
end

-- ========================================================================
-- Skill dispatch
-- ========================================================================

local BASE_MOVES = { ragnaraku, kaifu, kanaboSweep, boloBreath }
local DRAGON_MOVES = { dragonBoro, blastBreath, dragonTwister, raimeiHakke }

function Kaido.UseSkill(player, character, slot)
	if not Combat.IsActionable(character) then
		return nil
	end
	local dragon = isDragon(character)
	local moveset = dragon and DRAGON_MOVES or BASE_MOVES
	local cfg = dragon and MY.Ult[slot] or MY.Base[slot]
	local move = moveset[slot]
	if not move or not cfg then
		return nil
	end
	if move(player, character) == false then
		return nil
	end
	return cfg.Cooldown
end

function Kaido.ForgetPlayer(player)
	m1State[player] = nil
	dragonTokens[player] = nil
end

return Kaido
