--[[
	Ace.lua
	Server-side implementation of Portgas D. Ace: a ranged fire zoner using
	the Mera Mera no Mi. Most of his kit is projectiles (Combat.Projectile);
	every hit applies burn.

	Base moveset (slots 1-4):
		1  Hiken       - a big fireball that explodes on impact
		2  Higan       - rapid barrage of fire bullets
		3  Enkai       - a pillar of fire erupts at the nearest enemy
		4  Flame Combo - a close-range dash combo (panic option)

	Ult (G): GREAT FLAME COMMANDMENT for a limited time; slots become:
		1  Dai Enkai: Entei    - a colossal slow fireball
		2  Enkai: Higan        - an enlarged exploding-bullet barrage
		3  Kyokaen            - a wide cross-shaped fire blast
		4  Hotarubi: Hidaruma  - fireflies gather on a target and detonate

	Interface matches the other characters.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Combat = require(script.Parent.Parent.CombatService)

local VFX = Remotes.get("VFX")
local HUDUpdate = Remotes.get("HUDUpdate")

local FIRE = Color3.fromRGB(255, 140, 40)

local Ace = {}

local MY = Config.Movesets.Ace

local m1State = {}
local flameTokens = {}

-- ========================================================================
-- Helpers
-- ========================================================================

local function faceTarget(character, targetCharacter)
	local root = Combat.Root(character)
	local targetRoot = Combat.Root(targetCharacter)
	if root and targetRoot then
		local lookAt = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
		root.CFrame = CFrame.lookAt(root.Position, lookAt)
	end
end

local function dashToTarget(character, targetCharacter)
	local root = Combat.Root(character)
	local targetRoot = Combat.Root(targetCharacter)
	if root and targetRoot then
		root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3.5)
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z))
	end
end

local function isGreatFlame(character)
	return character:GetAttribute("GreatFlame") == true
end

-- Aim toward the nearest enemy (slight auto-aim), else straight ahead.
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
			-- Only auto-aim if the target is roughly in front.
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
	return root.Position + Vector3.new(0, 1.5, 0) + flat * 2.5
end

-- ========================================================================
-- M1 combo (fire jabs)
-- ========================================================================

function Ace.M1(player, character)
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
	VFX:FireAllClients("AceM1", { Character = character, Index = isFinisher and cfg.ComboHits or state.count })

	for _, target in Combat.FrontHitbox(character, cfg.Range, cfg.Width) do
		if isFinisher then
			Combat.DealDamage(player, target, cfg.Damage, {
				KnockbackDir = look,
				KnockbackPower = cfg.FinisherKnockback,
				RagdollTime = cfg.FinisherRagdoll,
			})
		else
			Combat.DealDamage(player, target, cfg.Damage, { StunTime = cfg.HitStun })
		end
	end
end

-- ========================================================================
-- Projectile-based moves
-- ========================================================================

-- Single big fireball (Hiken / Entei).
local function fireball(player, character, cfg, castEffect)
	Combat.SetBusy(character, cfg.WindUp + 0.3, true)
	VFX:FireAllClients(castEffect, { Character = character, WindUp = cfg.WindUp })

	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end
	local dir = aimDirection(character, 90)
	Combat.Projectile(player, character, {
		Origin = muzzleOrigin(character, dir),
		Direction = dir,
		Speed = cfg.Speed,
		Life = cfg.Life,
		Radius = cfg.Radius,
		Damage = cfg.Damage,
		ExplodeRadius = cfg.ExplodeRadius,
		Knockback = cfg.Knockback,
		KnockbackUp = cfg.Knockback * 0.35,
		RagdollTime = cfg.RagdollTime,
		Burn = cfg.Burn,
		Color = FIRE,
	})
end

-- Rapid bullet barrage (Higan / Enhanced Higan).
local function bulletBarrage(player, character, cfg, castEffect)
	Combat.SetBusy(character, cfg.WindUp + cfg.Bullets * cfg.BulletInterval + 0.2, true)
	VFX:FireAllClients(castEffect, { Character = character, Bullets = cfg.Bullets })

	task.wait(cfg.WindUp)
	for _ = 1, cfg.Bullets do
		if not Combat.IsAlive(character) or character:GetAttribute("Stunned") then
			break
		end
		local dir = aimDirection(character, 90)
		-- A little spread.
		dir = (dir + Vector3.new((math.random() - 0.5) * 0.06, (math.random() - 0.5) * 0.05, (math.random() - 0.5) * 0.06)).Unit
		Combat.Projectile(player, character, {
			Origin = muzzleOrigin(character, dir),
			Direction = dir,
			Speed = cfg.BulletSpeed,
			Life = cfg.BulletLife,
			Radius = cfg.BulletRadius,
			Damage = cfg.DamagePerBullet,
			ExplodeRadius = cfg.ExplodeRadius,
			Knockback = cfg.Knockback,
			Burn = cfg.Burn,
			Color = FIRE,
		})
		task.wait(cfg.BulletInterval)
	end
end

-- A pillar of fire that erupts at a captured position (Enkai).
local function firePillar(player, character, cfg, effectName)
	local target = Combat.NearestTarget(character, cfg.Range)
	local root = Combat.Root(character)
	if not root then
		return
	end
	local center
	if target then
		local targetRoot = Combat.Root(target)
		center = targetRoot and targetRoot.Position or (root.Position + Combat.FlatLook(character) * 12)
	else
		center = root.Position + Combat.FlatLook(character) * 12
	end

	Combat.SetBusy(character, cfg.WindUp + 0.3)
	VFX:FireAllClients(effectName, { Position = center, Radius = cfg.Radius, Delay = cfg.WindUp, Color = FIRE })

	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end
	for _, tgt in Combat.GetTargetsInBox(CFrame.new(center), Vector3.new(cfg.Radius * 2, 22, cfg.Radius * 2), character) do
		local targetRoot = Combat.Root(tgt)
		local dir = targetRoot and (targetRoot.Position - center) or Vector3.zAxis
		Combat.DealDamage(player, tgt, cfg.Damage, {
			KnockbackDir = dir,
			KnockbackPower = cfg.Knockback,
			KnockbackUp = cfg.LaunchPower,
			RagdollTime = cfg.RagdollTime,
		})
		if cfg.Burn then
			Combat.Burn(player, tgt, cfg.Burn.Dps, cfg.Burn.Time)
		end
	end
end

-- Wide forward cross blast (Kyokaen).
local function crossBlast(player, character, cfg, effectName)
	Combat.SetBusy(character, cfg.WindUp + 0.3, true)
	VFX:FireAllClients(effectName, { Character = character, WindUp = cfg.WindUp, Range = cfg.Range })

	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end
	local look = Combat.FlatLook(character)
	for _, target in Combat.FrontHitbox(character, cfg.Range, cfg.Width, 18) do
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

-- Fireflies gather on the nearest target and detonate (Hotarubi finisher).
local function hotarubi(player, character, cfg, effectName)
	local target = Combat.NearestTarget(character, cfg.Range)
	Combat.SetBusy(character, cfg.WindUp + 0.4, true)

	local root = Combat.Root(character)
	local markPos = root and (root.Position + Combat.FlatLook(character) * 14) or Vector3.zero
	if target then
		local targetRoot = Combat.Root(target)
		markPos = targetRoot and targetRoot.Position or markPos
	end
	VFX:FireAllClients(effectName, { Position = markPos, Radius = cfg.Radius, WindUp = cfg.WindUp, Color = FIRE })

	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end

	-- Detonate at the target's current position if it still exists.
	local center = markPos
	if target and Combat.IsAlive(target) then
		local targetRoot = Combat.Root(target)
		if targetRoot then
			center = targetRoot.Position
		end
	end

	VFX:FireAllClients("Explosion", { Position = center, Radius = cfg.Radius, Color = FIRE })
	for _, tgt in Combat.GetTargetsInBox(CFrame.new(center), Vector3.new(cfg.Radius * 2, cfg.Radius * 2, cfg.Radius * 2), character) do
		local targetRoot = Combat.Root(tgt)
		local dir = targetRoot and (targetRoot.Position - center) or Vector3.zAxis
		Combat.DealDamage(player, tgt, cfg.Damage, {
			KnockbackDir = dir,
			KnockbackPower = cfg.Knockback,
			KnockbackUp = cfg.LaunchPower,
			RagdollTime = cfg.RagdollTime,
		})
		if cfg.Burn then
			Combat.Burn(player, tgt, cfg.Burn.Dps, cfg.Burn.Time)
		end
	end
end

-- Close-range dash combo (Flame Combo).
local function flameCombo(player, character, cfg, effectName)
	local target = Combat.NearestTarget(character, cfg.DashRange)
	if not target then
		Combat.SetBusy(character, 0.4)
		VFX:FireAllClients(effectName, { Character = character, Whiff = true })
		task.wait(0.2)
		local look = Combat.FlatLook(character)
		for _, hit in Combat.FrontHitbox(character, cfg.Range, 6) do
			Combat.DealDamage(player, hit, cfg.DamagePerHit * 2, { KnockbackDir = look, KnockbackPower = 40, StunTime = 0.6 })
			if cfg.Burn then
				Combat.Burn(player, hit, cfg.Burn.Dps, cfg.Burn.Time)
			end
		end
		return
	end

	local totalTime = cfg.Hits * cfg.HitInterval + 0.3
	Combat.SetBusy(character, totalTime, true)
	dashToTarget(character, target)
	VFX:FireAllClients(effectName, { Character = character, Target = target, Duration = totalTime })

	for hit = 1, cfg.Hits do
		if not Combat.IsAlive(character) or not Combat.IsAlive(target) then
			return
		end
		faceTarget(character, target)
		local isLast = hit == cfg.Hits
		if isLast then
			Combat.DealDamage(player, target, cfg.DamagePerHit, {
				KnockbackDir = Combat.FlatLook(character),
				KnockbackPower = cfg.FinalKnockback,
				RagdollTime = cfg.FinalRagdoll,
			})
		else
			Combat.DealDamage(player, target, cfg.DamagePerHit, { StunTime = cfg.HitInterval * 2 })
		end
		if cfg.Burn then
			Combat.Burn(player, target, cfg.Burn.Dps, cfg.Burn.Time)
		end
		if not isLast then
			task.wait(cfg.HitInterval)
		end
	end
end

-- ========================================================================
-- Move bindings
-- ========================================================================

local function hiken(player, character)
	fireball(player, character, MY.Base[1], "HikenCast")
end
local function higan(player, character)
	bulletBarrage(player, character, MY.Base[2], "HiganCast")
end
local function enkai(player, character)
	firePillar(player, character, MY.Base[3], "FirePillar")
end
local function baseFlameCombo(player, character)
	flameCombo(player, character, MY.Base[4], "FlameCombo")
end

local function entei(player, character)
	fireball(player, character, MY.Ult[1], "EnteiCast")
end
local function enhancedHigan(player, character)
	bulletBarrage(player, character, MY.Ult[2], "HiganCast")
end
local function kyokaen(player, character)
	crossBlast(player, character, MY.Ult[3], "Kyokaen")
end
local function hotarubiMove(player, character)
	hotarubi(player, character, MY.Ult[4], "Hotarubi")
end

-- ========================================================================
-- Ult: Great Flame Commandment
-- ========================================================================

function Ace.ActivateUlt(player, character)
	if not Combat.IsActionable(character) then
		return false
	end
	if isGreatFlame(character) then
		return false
	end
	local charge = player:GetAttribute("UltCharge") or 0
	if charge < Config.Ult.MaxCharge then
		return false
	end

	player:SetAttribute("UltCharge", 0)
	character:SetAttribute("GreatFlame", true)

	local token = (flameTokens[player] or 0) + 1
	flameTokens[player] = token

	local humanoid = Combat.Humanoid(character)
	if humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.Ult.HealPercent)
	end

	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed + Config.Ult.WalkSpeedBonus)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower + Config.Ult.JumpPowerBonus)
	Combat.RefreshMovement(character)

	local highlight = Instance.new("Highlight")
	highlight.Name = "GreatFlameHighlight"
	highlight.FillColor = Color3.fromRGB(120, 40, 10)
	highlight.OutlineColor = Color3.fromRGB(255, 150, 50)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0
	highlight.Parent = character

	VFX:FireAllClients("GreatFlameStart", { Character = character, Duration = Config.Ult.Duration })
	HUDUpdate:FireClient(player, "UltState", true, Config.Ult.Duration)

	task.delay(Config.Ult.Duration, function()
		if flameTokens[player] == token then
			Ace.DeactivateUlt(player, character)
		end
	end)

	return true
end

function Ace.DeactivateUlt(player, character)
	if not character or not character.Parent or not isGreatFlame(character) then
		return
	end
	character:SetAttribute("GreatFlame", false)
	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower)
	Combat.RefreshMovement(character)

	local highlight = character:FindFirstChild("GreatFlameHighlight")
	if highlight then
		highlight:Destroy()
	end

	VFX:FireAllClients("GreatFlameEnd", { Character = character })
	if player.Parent then
		HUDUpdate:FireClient(player, "UltState", false)
	end
end

-- ========================================================================
-- Skill dispatch
-- ========================================================================

local BASE_MOVES = { hiken, higan, enkai, baseFlameCombo }
local FLAME_MOVES = { entei, enhancedHigan, kyokaen, hotarubiMove }

function Ace.UseSkill(player, character, slot)
	if not Combat.IsActionable(character) then
		return nil
	end

	local flame = isGreatFlame(character)
	local moveset = flame and FLAME_MOVES or BASE_MOVES
	local cfg = flame and MY.Ult[slot] or MY.Base[slot]
	local move = moveset[slot]
	if not move or not cfg then
		return nil
	end

	local result = move(player, character)
	if result == false then
		return nil
	end
	return cfg.Cooldown
end

function Ace.ForgetPlayer(player)
	m1State[player] = nil
	flameTokens[player] = nil
end

return Ace
