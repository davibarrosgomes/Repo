--[[
	Sanji.lua
	Server-side implementation of Vinsmoke Sanji: a mobile Black Leg kick
	fighter. His ultimate, Diable Jambe, ignites his leg and adds a burn
	damage-over-time to every hit.

	Base moveset (slots 1-4):
		1  Collier Shoot   - fast side kick, quick poke
		2  Concasse        - overhead axe kick, slams down (knockdown)
		3  Party Table Kick- spinning kicks hitting everyone around
		4  Kick Combo      - dash-in rapid kick string

	Ult (G): DIABLE JAMBE for a limited time; slots become flaming kicks that
	also apply burn:
		1  Premier Hachis  - flaming kick barrage
		2  Flambage Shot   - flaming spin that launches enemies up
		3  Mouton Shot     - one huge flaming kick
		4  Bien Cuit: Grill Shot - flaming finisher cone

	Interface matches the other characters: UseSkill, M1, ActivateUlt,
	DeactivateUlt, ForgetPlayer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Combat = require(script.Parent.Parent.CombatService)

local VFX = Remotes.get("VFX")
local HUDUpdate = Remotes.get("HUDUpdate")

local Sanji = {}

local MY = Config.Movesets.Sanji

local m1State = {}
local diableTokens = {}
-- Burn DoT token per victim so overlapping burns refresh instead of stacking.
local burnTokens = setmetatable({}, { __mode = "k" })

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

local function isDiable(character)
	return character:GetAttribute("DiableJambe") == true
end

local function targetsAround(character, radius)
	local root = Combat.Root(character)
	if not root then
		return {}
	end
	return Combat.GetTargetsInBox(root.CFrame, Vector3.new(radius * 2, 12, radius * 2), character)
end

-- Applies a burn DoT: `dps` damage per second over `duration`, refreshing.
local function burn(player, victim, dps, duration)
	if not dps or not Combat.IsAlive(victim) then
		return
	end
	local token = (burnTokens[victim] or 0) + 1
	burnTokens[victim] = token
	VFX:FireAllClients("IgniteStart", { Character = victim, Duration = duration })

	task.spawn(function()
		local ticks = math.max(1, math.floor(duration / 0.5))
		for _ = 1, ticks do
			task.wait(0.5)
			if burnTokens[victim] ~= token or not Combat.IsAlive(victim) then
				break
			end
			-- Burn bypasses guard (it's already on you) and stays quiet.
			Combat.DealDamage(player, victim, dps * 0.5, { SilentVFX = true, Unblockable = true })
		end
		if burnTokens[victim] == token and victim.Parent then
			VFX:FireAllClients("IgniteEnd", { Character = victim })
		end
	end)
end

-- ========================================================================
-- M1 combo (kicks)
-- ========================================================================

function Sanji.M1(player, character)
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
	VFX:FireAllClients("SanjiM1", { Character = character, Index = isFinisher and cfg.ComboHits or state.count })

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
-- Shared move shapes (apply burn when cfg.BurnDps is present)
-- ========================================================================

local function applyBurn(player, target, cfg)
	if cfg.BurnDps then
		burn(player, target, cfg.BurnDps, cfg.BurnTime or 3)
	end
end

local function dashKickCombo(player, character, cfg, effectName)
	local target = Combat.NearestTarget(character, cfg.DashRange)

	if not target then
		Combat.SetBusy(character, 0.4)
		VFX:FireAllClients(effectName, { Character = character, Whiff = true })
		task.wait(0.2)
		local look = Combat.FlatLook(character)
		for _, hit in Combat.FrontHitbox(character, cfg.Range, 6) do
			Combat.DealDamage(player, hit, cfg.DamagePerHit * 2, { KnockbackDir = look, KnockbackPower = 40, StunTime = 0.6 })
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
		applyBurn(player, target, cfg)
		if not isLast then
			task.wait(cfg.HitInterval)
		end
	end
end

local function spinKickAoE(player, character, cfg, effectName)
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
			applyBurn(player, target, cfg)
		end
		if not isLast then
			task.wait(cfg.HitInterval)
		end
	end
end

local function forwardKick(player, character, cfg, effectName, downward)
	Combat.SetBusy(character, cfg.WindUp + 0.35, true)
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
			KnockbackUp = downward and 0 or cfg.Knockback * 0.3,
			RagdollTime = cfg.RagdollTime,
		})
		applyBurn(player, target, cfg)
	end
end

local function kickBarrage(player, character, cfg, effectName)
	Combat.SetBusy(character, cfg.WindUp + cfg.Duration + 0.2, true)
	VFX:FireAllClients(effectName, { Character = character, Duration = cfg.Duration, Range = cfg.Range })

	task.wait(cfg.WindUp)

	local interval = cfg.Duration / cfg.Hits
	for hit = 1, cfg.Hits do
		if not Combat.IsAlive(character) or character:GetAttribute("Stunned") then
			break
		end
		local isLast = hit == cfg.Hits
		local look = Combat.FlatLook(character)
		for _, target in Combat.FrontHitbox(character, cfg.Range, cfg.Width) do
			if isLast then
				Combat.DealDamage(player, target, cfg.DamagePerHit, {
					KnockbackDir = look,
					KnockbackPower = cfg.FinalKnockback,
					RagdollTime = cfg.FinalRagdoll,
				})
			else
				Combat.DealDamage(player, target, cfg.DamagePerHit, { StunTime = interval * 2, SilentVFX = hit % 2 == 0 })
			end
			applyBurn(player, target, cfg)
		end
		if not isLast then
			task.wait(interval)
		end
	end
end

-- Forward cone multi-hit (Grill Shot finisher).
local function coneBarrage(player, character, cfg, effectName)
	Combat.SetBusy(character, cfg.WindUp + cfg.Hits * cfg.HitInterval + 0.2, true)
	VFX:FireAllClients(effectName, { Character = character, WindUp = cfg.WindUp, Range = cfg.Range })

	task.wait(cfg.WindUp)

	for hit = 1, cfg.Hits do
		if not Combat.IsAlive(character) or character:GetAttribute("Stunned") then
			break
		end
		local isLast = hit == cfg.Hits
		local look = Combat.FlatLook(character)
		for _, target in Combat.FrontHitbox(character, cfg.Range, cfg.Width) do
			local opts = { StunTime = cfg.HitInterval * 2.5 }
			if isLast then
				opts.KnockbackDir = look
				opts.KnockbackPower = cfg.FinalKnockback
				opts.KnockbackUp = cfg.FinalKnockback * 0.5
				opts.RagdollTime = cfg.FinalRagdoll
			end
			Combat.DealDamage(player, target, cfg.DamagePerHit, opts)
			applyBurn(player, target, cfg)
		end
		if not isLast then
			task.wait(cfg.HitInterval)
		end
	end
end

-- ========================================================================
-- Base moveset
-- ========================================================================

local function collier(player, character)
	forwardKick(player, character, MY.Base[1], "Collier", false)
end

local function concasse(player, character)
	forwardKick(player, character, MY.Base[2], "Concasse", true)
end

local function partyTable(player, character)
	spinKickAoE(player, character, MY.Base[3], "PartyTable")
end

local function kickCombo(player, character)
	dashKickCombo(player, character, MY.Base[4], "KickCombo")
end

-- ========================================================================
-- Diable Jambe moveset
-- ========================================================================

local function premierHachis(player, character)
	kickBarrage(player, character, MY.Ult[1], "PremierHachis")
end

local function flambageShot(player, character)
	spinKickAoE(player, character, MY.Ult[2], "FlambageShot")
end

local function moutonShot(player, character)
	forwardKick(player, character, MY.Ult[3], "MoutonShot", false)
end

local function grillShot(player, character)
	coneBarrage(player, character, MY.Ult[4], "GrillShot")
end

-- ========================================================================
-- Ult: Diable Jambe
-- ========================================================================

function Sanji.ActivateUlt(player, character)
	if not Combat.IsActionable(character) then
		return false
	end
	if isDiable(character) then
		return false
	end
	local charge = player:GetAttribute("UltCharge") or 0
	if charge < Config.Ult.MaxCharge then
		return false
	end

	player:SetAttribute("UltCharge", 0)
	character:SetAttribute("DiableJambe", true)

	local token = (diableTokens[player] or 0) + 1
	diableTokens[player] = token

	local humanoid = Combat.Humanoid(character)
	if humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.Ult.HealPercent)
	end

	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed + Config.Ult.WalkSpeedBonus)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower + Config.Ult.JumpPowerBonus)
	Combat.RefreshMovement(character)

	-- Fiery orange aura, replicated to everyone.
	local highlight = Instance.new("Highlight")
	highlight.Name = "DiableHighlight"
	highlight.FillColor = Color3.fromRGB(90, 24, 8)
	highlight.OutlineColor = Color3.fromRGB(255, 130, 40)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 0
	highlight.Parent = character

	VFX:FireAllClients("DiableStart", { Character = character, Duration = Config.Ult.Duration })
	HUDUpdate:FireClient(player, "UltState", true, Config.Ult.Duration)

	task.delay(Config.Ult.Duration, function()
		if diableTokens[player] == token then
			Sanji.DeactivateUlt(player, character)
		end
	end)

	return true
end

function Sanji.DeactivateUlt(player, character)
	if not character or not character.Parent or not isDiable(character) then
		return
	end
	character:SetAttribute("DiableJambe", false)
	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower)
	Combat.RefreshMovement(character)

	local highlight = character:FindFirstChild("DiableHighlight")
	if highlight then
		highlight:Destroy()
	end

	VFX:FireAllClients("DiableEnd", { Character = character })
	if player.Parent then
		HUDUpdate:FireClient(player, "UltState", false)
	end
end

-- ========================================================================
-- Skill dispatch
-- ========================================================================

local BASE_MOVES = { collier, concasse, partyTable, kickCombo }
local DIABLE_MOVES = { premierHachis, flambageShot, moutonShot, grillShot }

function Sanji.UseSkill(player, character, slot)
	if not Combat.IsActionable(character) then
		return nil
	end

	local diable = isDiable(character)
	local moveset = diable and DIABLE_MOVES or BASE_MOVES
	local cfg = diable and MY.Ult[slot] or MY.Base[slot]
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

function Sanji.ForgetPlayer(player)
	m1State[player] = nil
	diableTokens[player] = nil
end

return Sanji
