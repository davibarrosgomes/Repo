--[[
	CombatService.lua
	Server-authoritative combat primitives shared by every character:
	hitboxes, damage, ult charge, stun / ragdoll / paralysis, knockback.

	Status is stored as attributes on the character model so both server
	logic and client input code can read it:
		Stunned     (bool)   - cannot act or move
		Ragdolled   (bool)   - knocked down (PlatformStand)
		Rubberized  (bool)   - Toon Force paralysis
		Busy        (bool)   - mid-attack, cannot start another action
		Gear5       (bool)   - ult transformation active
		Blocking    (bool)   - guarding (front hits absorbed by BlockHealth)
		BlockHealth (number) - remaining guard durability
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local VFX = Remotes.get("VFX")

local Combat = {}

-- Monotonic tokens so overlapping statuses don't cancel each other early.
local stunTokens = {}
local ragdollTokens = {}
local busyTokens = {}
-- [character] = os.clock() time until which re-guarding is forbidden
local blockLock = {}

-- ========================================================================
-- Small helpers
-- ========================================================================

function Combat.Root(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Combat.Humanoid(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end

function Combat.IsAlive(character)
	local humanoid = Combat.Humanoid(character)
	return humanoid ~= nil and humanoid.Health > 0
end

-- Can this character start a new action (attack, skill, ult)?
function Combat.IsActionable(character)
	if not Combat.IsAlive(character) then
		return false
	end
	return not (
		character:GetAttribute("Stunned")
		or character:GetAttribute("Ragdolled")
		or character:GetAttribute("Rubberized")
		or character:GetAttribute("Busy")
	)
end

-- Flat, horizontal look direction of the character.
function Combat.FlatLook(character)
	local root = Combat.Root(character)
	if not root then
		return Vector3.zAxis
	end
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 0.001 then
		return Vector3.zAxis
	end
	return look.Unit
end

local function baseWalkSpeed(character)
	return character:GetAttribute("BaseWalkSpeed") or Config.Character.BaseWalkSpeed
end

local function baseJumpPower(character)
	return character:GetAttribute("BaseJumpPower") or Config.Character.BaseJumpPower
end

-- Re-apply movement stats from attributes (used when a status expires).
function Combat.RefreshMovement(character)
	local humanoid = Combat.Humanoid(character)
	if not humanoid then
		return
	end
	if character:GetAttribute("Stunned") or character:GetAttribute("Rubberized") then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	elseif character:GetAttribute("Blocking") then
		humanoid.WalkSpeed = Config.Block.WalkSpeed
		humanoid.JumpPower = 0
	else
		humanoid.WalkSpeed = baseWalkSpeed(character)
		humanoid.JumpPower = baseJumpPower(character)
	end
end

-- ========================================================================
-- Hitboxes
-- ========================================================================

-- Returns a list of enemy character models whose parts overlap a box.
function Combat.GetTargetsInBox(cframe, size, excludeCharacter)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { excludeCharacter }

	local found = {}
	for _, part in workspace:GetPartBoundsInBox(cframe, size, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not found[model] then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				found[model] = true
			end
		end
	end

	local targets = {}
	for model in found do
		table.insert(targets, model)
	end
	return targets
end

-- Convenience: box placed `range/2` studs in front of the character.
function Combat.FrontHitbox(character, range, width, height)
	local root = Combat.Root(character)
	if not root then
		return {}
	end
	height = height or 8
	local cframe = root.CFrame * CFrame.new(0, 0, -range / 2)
	return Combat.GetTargetsInBox(cframe, Vector3.new(width, height, range), character), cframe
end

-- Nearest living enemy inside `range`, or nil.
function Combat.NearestTarget(character, range)
	local root = Combat.Root(character)
	if not root then
		return nil
	end
	local best, bestDist = nil, range
	for _, model in Combat.GetTargetsInBox(root.CFrame, Vector3.new(range * 2, range * 2, range * 2), character) do
		local targetRoot = Combat.Root(model)
		if targetRoot then
			local dist = (targetRoot.Position - root.Position).Magnitude
			if dist <= bestDist then
				best, bestDist = model, dist
			end
		end
	end
	return best
end

-- ========================================================================
-- Status effects
-- ========================================================================

function Combat.Stun(character, duration)
	if not Combat.IsAlive(character) then
		return
	end
	local token = (stunTokens[character] or 0) + 1
	stunTokens[character] = token

	character:SetAttribute("Stunned", true)
	Combat.RefreshMovement(character)

	task.delay(duration, function()
		if stunTokens[character] == token and character.Parent then
			character:SetAttribute("Stunned", false)
			Combat.RefreshMovement(character)
		end
	end)
end

function Combat.Ragdoll(character, duration)
	local humanoid = Combat.Humanoid(character)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local token = (ragdollTokens[character] or 0) + 1
	ragdollTokens[character] = token

	character:SetAttribute("Ragdolled", true)
	humanoid.PlatformStand = true
	Combat.Stun(character, duration) -- ragdoll implies stun

	task.delay(duration, function()
		if ragdollTokens[character] == token and character.Parent then
			character:SetAttribute("Ragdolled", false)
			local h = Combat.Humanoid(character)
			if h then
				h.PlatformStand = false
			end
		end
	end)
end

-- Toon Force paralysis: the victim is turned to rubber and cannot move.
function Combat.Rubberize(character, duration)
	if not Combat.IsAlive(character) then
		return
	end
	character:SetAttribute("Rubberized", true)
	Combat.RefreshMovement(character)
	VFX:FireAllClients("RubberizeStart", { Character = character, Duration = duration })

	task.delay(duration, function()
		if character.Parent then
			character:SetAttribute("Rubberized", false)
			Combat.RefreshMovement(character)
			VFX:FireAllClients("RubberizeEnd", { Character = character })
		end
	end)
end

-- Marks the attacker as mid-move. `freeze` optionally roots them in place
-- during the windup of heavy moves.
function Combat.SetBusy(character, duration, freeze)
	local humanoid = Combat.Humanoid(character)
	if not humanoid then
		return
	end
	local token = (busyTokens[character] or 0) + 1
	busyTokens[character] = token

	character:SetAttribute("Busy", true)
	if freeze then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	task.delay(duration, function()
		if busyTokens[character] == token and character.Parent then
			character:SetAttribute("Busy", false)
			Combat.RefreshMovement(character)
		end
	end)
end

-- ========================================================================
-- Blocking
-- ========================================================================

function Combat.SetBlocking(character, enabled)
	local wasBlocking = character:GetAttribute("Blocking") == true
	if enabled then
		if wasBlocking or not Combat.IsAlive(character) then
			return
		end
		if not Combat.IsActionable(character) then
			return
		end
		if os.clock() < (blockLock[character] or 0) then
			return -- guard is still broken
		end
		if (character:GetAttribute("BlockHealth") or 0) <= 0 then
			return
		end
		character:SetAttribute("Blocking", true)
		VFX:FireAllClients("BlockStart", { Character = character })
	else
		if not wasBlocking then
			return
		end
		character:SetAttribute("Blocking", false)
		VFX:FireAllClients("BlockEnd", { Character = character })
	end
	Combat.RefreshMovement(character)
end

local function tryBlock(attackerPlayer, victimCharacter, amount)
	if victimCharacter:GetAttribute("Blocking") ~= true then
		return false
	end

	-- Guards only cover the front 180 degrees.
	local attackerCharacter = attackerPlayer and attackerPlayer.Character
	local attackerRoot = attackerCharacter and Combat.Root(attackerCharacter)
	local victimRoot = Combat.Root(victimCharacter)
	if attackerRoot and victimRoot then
		local toAttacker = attackerRoot.Position - victimRoot.Position
		if toAttacker.Magnitude > 0.001 and victimRoot.CFrame.LookVector:Dot(toAttacker.Unit) <= 0 then
			return false -- hit from behind
		end
	end

	local blockHealth = (victimCharacter:GetAttribute("BlockHealth") or 0) - amount
	if blockHealth > 0 then
		-- Fully absorbed: no damage, no stun, no knockback.
		victimCharacter:SetAttribute("BlockHealth", blockHealth)
		if victimRoot then
			VFX:FireAllClients("BlockHit", { Position = victimRoot.Position })
		end
		return true
	end

	-- GUARD BREAK: the guard shatters, the hit lands, and re-guarding is
	-- locked out while the victim eats the punish.
	victimCharacter:SetAttribute("BlockHealth", 0)
	blockLock[victimCharacter] = os.clock() + Config.Block.BreakLockout
	Combat.SetBlocking(victimCharacter, false)
	Combat.Ragdoll(victimCharacter, Config.Block.BreakRagdoll)
	if victimRoot then
		VFX:FireAllClients("GuardBreak", { Position = victimRoot.Position })
	end
	return false
end

-- ========================================================================
-- Knockback
-- ========================================================================

function Combat.Knockback(character, direction, power, upwardPower)
	local root = Combat.Root(character)
	if not root then
		return
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.001 then
		direction = Vector3.zAxis
	end
	root.AssemblyLinearVelocity = direction.Unit * power + Vector3.new(0, upwardPower or power * 0.35, 0)
end

-- ========================================================================
-- Damage + ult charge
-- ========================================================================

local function addUltCharge(player, amount)
	if not player then
		return
	end
	local current = player:GetAttribute("UltCharge") or 0
	player:SetAttribute("UltCharge", math.clamp(current + amount, 0, Config.Ult.MaxCharge))
end

--[[
	Applies damage from attackerPlayer's character to victimCharacter.
	opts (all optional):
		KnockbackDir / KnockbackPower / KnockbackUp
		StunTime
		RagdollTime
		SilentVFX (skip the generic hit flash)
		Unblockable (grabs like Devour go straight through guards)
]]
function Combat.DealDamage(attackerPlayer, victimCharacter, amount, opts)
	opts = opts or {}
	local humanoid = Combat.Humanoid(victimCharacter)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if victimCharacter:FindFirstChildOfClass("ForceField") then
		return false
	end

	if not opts.Unblockable and tryBlock(attackerPlayer, victimCharacter, amount) then
		return false
	end

	if attackerPlayer then
		victimCharacter:SetAttribute("LastAttackerId", attackerPlayer.UserId)
	end

	humanoid:TakeDamage(amount)

	-- Ult charge: attacker charges from damage dealt, victim from damage taken.
	local effective = math.min(amount, humanoid.MaxHealth) -- one-shots don't insta-fill bars
	addUltCharge(attackerPlayer, effective * Config.Ult.ChargePerDamageDealt)
	local victimPlayer = Players:GetPlayerFromCharacter(victimCharacter)
	if victimPlayer then
		addUltCharge(victimPlayer, effective * Config.Ult.ChargePerDamageTaken)
	end

	if opts.StunTime then
		Combat.Stun(victimCharacter, opts.StunTime)
	end
	if opts.RagdollTime then
		Combat.Ragdoll(victimCharacter, opts.RagdollTime)
	end
	if opts.KnockbackDir and opts.KnockbackPower then
		Combat.Knockback(victimCharacter, opts.KnockbackDir, opts.KnockbackPower, opts.KnockbackUp)
	end

	if not opts.SilentVFX then
		local root = Combat.Root(victimCharacter)
		if root then
			VFX:FireAllClients("HitImpact", { Position = root.Position, Heavy = amount >= 15 })
		end
	end

	return true
end

-- ========================================================================
-- Cleanup
-- ========================================================================

function Combat.ForgetCharacter(character)
	stunTokens[character] = nil
	ragdollTokens[character] = nil
	busyTokens[character] = nil
	blockLock[character] = nil
end

return Combat
