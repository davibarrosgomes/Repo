--[[
	Luffy.lua
	Server-side implementation of Luffy's complete kit.

	Base moveset (slots 1-4):
		1  Gomu Gomu no Pistol   - long range stretching punch
		2  Gomu Gomu no Bazooka  - double-arm strike, huge knockback
		3  Gomu Gomu no Gatling  - rapid multi-hit punch barrage
		4  Rubber Combo          - dash-in 5-hit combo

	Ult (G): transforms into GEAR 5 for a limited time and the slots become:
		1  Gomu Gomu no Bajrang Gun  - island-sized fist
		2  Gomu Gomu no Dawn Gatling - barrage that looks like many arms at once
		3  Toon Force              - rubberizes the enemy, combos them, and
		                             leaves them paralyzed after the last punch
		4  Drums of Liberation     - beats his chest, head grows huge, and he
		                             DEVOURS the enemy: one hit kill

	Every function here trusts nothing from the client except "which slot
	was pressed" - all validation, timing, hitboxes and damage are server side.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Combat = require(script.Parent.Parent.CombatService)

local VFX = Remotes.get("VFX")
local HUDUpdate = Remotes.get("HUDUpdate")

local Luffy = {}

-- M1 chain state per player: { count, lastSwing, lockedUntil }
local m1State = {}
-- Gear 5 activation token per player so an old ult can't revert a new one.
local gear5Tokens = {}

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

-- Snaps the attacker right in front of the target (battlegrounds style dash).
local function dashToTarget(character, targetCharacter)
	local root = Combat.Root(character)
	local targetRoot = Combat.Root(targetCharacter)
	if root and targetRoot then
		root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3.5)
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z))
	end
end

local function isGear5(character)
	return character:GetAttribute("Gear5") == true
end

-- ========================================================================
-- M1 combo
-- ========================================================================

function Luffy.M1(player, character)
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
	VFX:FireAllClients("M1Swing", { Character = character, Index = isFinisher and cfg.ComboHits or state.count })

	local targets = Combat.FrontHitbox(character, cfg.Range, cfg.Width)
	for _, target in targets do
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
-- Base moveset
-- ========================================================================

-- Slot 1: Gomu Gomu no Pistol - devastating stretching punch.
local function pistol(player, character)
	local cfg = Config.Base[1]
	Combat.SetBusy(character, cfg.WindUp + 0.3)
	VFX:FireAllClients("Pistol", { Character = character, Range = cfg.Range })

	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end

	local look = Combat.FlatLook(character)
	local targets = Combat.FrontHitbox(character, cfg.Range, cfg.Width)
	for _, target in targets do
		Combat.DealDamage(player, target, cfg.Damage, {
			KnockbackDir = look,
			KnockbackPower = cfg.Knockback,
			RagdollTime = cfg.RagdollTime,
		})
	end
end

-- Slot 2: Gomu Gomu no Bazooka - double-arm strike.
local function bazooka(player, character)
	local cfg = Config.Base[2]
	Combat.SetBusy(character, cfg.WindUp + 0.3, true)
	VFX:FireAllClients("Bazooka", { Character = character })

	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end

	local look = Combat.FlatLook(character)
	local targets = Combat.FrontHitbox(character, cfg.Range, cfg.Width)
	for _, target in targets do
		Combat.DealDamage(player, target, cfg.Damage, {
			KnockbackDir = look,
			KnockbackPower = cfg.Knockback,
			KnockbackUp = cfg.Knockback * 0.45,
			RagdollTime = cfg.RagdollTime,
		})
	end
end

-- Shared implementation for Gatling and Dawn Gatling.
local function gatlingBarrage(player, character, cfg, effectName)
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
		local targets = Combat.FrontHitbox(character, cfg.Range, cfg.Width)
		for _, target in targets do
			if isLast then
				Combat.DealDamage(player, target, cfg.DamagePerHit, {
					KnockbackDir = look,
					KnockbackPower = cfg.FinalKnockback,
					RagdollTime = cfg.FinalRagdoll,
				})
			else
				-- Victims are stitched in place by the barrage.
				Combat.DealDamage(player, target, cfg.DamagePerHit, { StunTime = interval * 2, SilentVFX = hit % 2 == 0 })
			end
		end
		if not isLast then
			task.wait(interval)
		end
	end
end

-- Slot 3: Gomu Gomu no Gatling.
local function gatling(player, character)
	gatlingBarrage(player, character, Config.Base[3], "Gatling")
end

-- Shared implementation for Rubber Combo and Toon Force.
-- `onFinalHit(target)` decides what the last punch does.
local function dashCombo(player, character, cfg, effectName, onFinalHit)
	local target = Combat.NearestTarget(character, cfg.DashRange)

	if not target then
		-- Nobody in dash range: do a single short-range swipe instead.
		Combat.SetBusy(character, 0.4)
		VFX:FireAllClients(effectName, { Character = character, Whiff = true })
		task.wait(0.25)
		local look = Combat.FlatLook(character)
		for _, hit in Combat.FrontHitbox(character, cfg.Range, 6) do
			Combat.DealDamage(player, hit, cfg.DamagePerHit * 2, {
				KnockbackDir = look,
				KnockbackPower = 40,
				StunTime = 0.6,
			})
		end
		return
	end

	local totalTime = cfg.Hits * cfg.HitInterval + 0.3
	Combat.SetBusy(character, totalTime, true)
	dashToTarget(character, target)
	VFX:FireAllClients(effectName, { Character = character, Target = target, Duration = totalTime })

	if effectName == "ToonForce" then
		-- The opponent is turned into rubber for the whole combo.
		Combat.Rubberize(target, cfg.Hits * cfg.HitInterval + cfg.ParalyzeTime)
	end

	for hit = 1, cfg.Hits do
		if not Combat.IsAlive(character) or not Combat.IsAlive(target) then
			return
		end
		faceTarget(character, target)
		local isLast = hit == cfg.Hits
		if isLast then
			onFinalHit(target)
		else
			Combat.DealDamage(player, target, cfg.DamagePerHit, { StunTime = cfg.HitInterval * 2 })
		end
		if not isLast then
			task.wait(cfg.HitInterval)
		end
	end
end

-- Slot 4: Rubber Combo - relentless dash-in combo.
local function rubberCombo(player, character)
	local cfg = Config.Base[4]
	dashCombo(player, character, cfg, "RubberCombo", function(target)
		Combat.DealDamage(player, target, cfg.DamagePerHit, {
			KnockbackDir = Combat.FlatLook(character),
			KnockbackPower = cfg.FinalKnockback,
			RagdollTime = cfg.FinalRagdoll,
		})
	end)
end

-- ========================================================================
-- Gear 5 moveset
-- ========================================================================

-- Slot 1 (Gear 5): Gomu Gomu no Bajrang Gun - island-sized fist.
local function bajrangGun(player, character)
	local cfg = Config.Gear5[1]
	Combat.SetBusy(character, cfg.WindUp + 0.6, true)
	VFX:FireAllClients("BajrangGun", { Character = character, WindUp = cfg.WindUp, Range = cfg.Range })

	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end

	local look = Combat.FlatLook(character)
	local targets = Combat.FrontHitbox(character, cfg.Range, cfg.Width, cfg.Height)
	for _, target in targets do
		Combat.DealDamage(player, target, cfg.Damage, {
			KnockbackDir = look,
			KnockbackPower = cfg.Knockback,
			KnockbackUp = cfg.Knockback * 0.4,
			RagdollTime = cfg.RagdollTime,
		})
	end
end

-- Slot 2 (Gear 5): Gomu Gomu no Dawn Gatling - looks like dozens of arms.
local function dawnGatling(player, character)
	gatlingBarrage(player, character, Config.Gear5[2], "DawnGatling")
end

-- Slot 3 (Gear 5): Toon Force combo - rubberize, punish, paralyze.
local function toonForce(player, character)
	local cfg = Config.Gear5[3]
	dashCombo(player, character, cfg, "ToonForce", function(target)
		-- Final punch: big damage and the rubber paralysis keeps running
		-- (it was applied for combo time + ParalyzeTime when the combo began).
		Combat.DealDamage(player, target, cfg.DamagePerHit * 3, {
			KnockbackDir = Combat.FlatLook(character),
			KnockbackPower = 25,
		})
	end)
end

-- Slot 4 (Gear 5): Drums of Liberation - chest beat, giant head, DEVOUR.
local function devour(player, character)
	local cfg = Config.Gear5[4]

	if cfg.OneUsePerUlt and character:GetAttribute("DevourUsed") then
		return false -- refuse: refund the cooldown
	end
	character:SetAttribute("DevourUsed", true)

	-- Long, loud, rooted channel: everyone nearby hears the drums and can run.
	Combat.SetBusy(character, cfg.WindUp + 1, true)
	VFX:FireAllClients("DrumsChannel", { Character = character, Duration = cfg.WindUp })

	task.wait(cfg.WindUp)
	if not Combat.IsAlive(character) then
		return
	end

	local targets = Combat.FrontHitbox(character, cfg.Range, cfg.Width)
	local victim = targets[1]
	if victim then
		faceTarget(character, victim)
		Combat.Stun(victim, 1.5)
		VFX:FireAllClients("Devour", { Character = character, Target = victim })
		task.wait(0.6) -- the head grows and chomps
		if Combat.IsAlive(character) and Combat.IsAlive(victim) then
			Combat.DealDamage(player, victim, cfg.Damage, { SilentVFX = true })
		end
	else
		VFX:FireAllClients("DevourWhiff", { Character = character })
	end
end

-- ========================================================================
-- Ult: Gear 5 transformation
-- ========================================================================

function Luffy.ActivateUlt(player, character)
	if not Combat.IsActionable(character) then
		return false
	end
	if isGear5(character) then
		return false
	end
	local charge = player:GetAttribute("UltCharge") or 0
	if charge < Config.Ult.MaxCharge then
		return false
	end

	player:SetAttribute("UltCharge", 0)
	character:SetAttribute("Gear5", true)
	character:SetAttribute("DevourUsed", false)

	local token = (gear5Tokens[player] or 0) + 1
	gear5Tokens[player] = token

	local humanoid = Combat.Humanoid(character)
	if humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.Ult.HealPercent)
	end

	-- Gear 5 movement buff (BaseWalkSpeed is what stuns restore to).
	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed + Config.Ult.WalkSpeedBonus)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower + Config.Ult.JumpPowerBonus)
	Combat.RefreshMovement(character)

	-- The white "Sun God Nika" look, replicated to everyone automatically.
	local highlight = Instance.new("Highlight")
	highlight.Name = "Gear5Highlight"
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.OutlineColor = Color3.fromRGB(255, 220, 240)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0
	highlight.Parent = character

	VFX:FireAllClients("Gear5Start", { Character = character, Duration = Config.Ult.Duration })
	HUDUpdate:FireClient(player, "UltState", true, Config.Ult.Duration)

	task.delay(Config.Ult.Duration, function()
		if gear5Tokens[player] == token then
			Luffy.DeactivateUlt(player, character)
		end
	end)

	return true
end

function Luffy.DeactivateUlt(player, character)
	if not character or not character.Parent or not isGear5(character) then
		return
	end
	character:SetAttribute("Gear5", false)
	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower)
	Combat.RefreshMovement(character)

	local highlight = character:FindFirstChild("Gear5Highlight")
	if highlight then
		highlight:Destroy()
	end

	VFX:FireAllClients("Gear5End", { Character = character })
	if player.Parent then
		HUDUpdate:FireClient(player, "UltState", false)
	end
end

-- ========================================================================
-- Skill dispatch
-- ========================================================================

local BASE_MOVES = { pistol, bazooka, gatling, rubberCombo }
local GEAR5_MOVES = { bajrangGun, dawnGatling, toonForce, devour }

-- Executes a skill. Returns the cooldown to apply, or nil if it didn't cast.
function Luffy.UseSkill(player, character, slot)
	if not Combat.IsActionable(character) then
		return nil
	end

	local gear5 = isGear5(character)
	local moveset = gear5 and GEAR5_MOVES or BASE_MOVES
	local cfgTable = gear5 and Config.Gear5 or Config.Base
	local move = moveset[slot]
	local cfg = cfgTable[slot]
	if not move or not cfg then
		return nil
	end

	local result = move(player, character)
	if result == false then
		return nil -- move refused to cast (e.g. Devour already used)
	end
	return cfg.Cooldown
end

function Luffy.ForgetPlayer(player)
	m1State[player] = nil
	gear5Tokens[player] = nil
end

return Luffy
