--[[
	=====================================================================
	ONE PIECE BATTLEGROUNDS  -  SERVER  (paste-ready, single Script)
	=====================================================================
	HOW TO INSTALL (2 scripts total, no folders, no ModuleScripts):

	  1. In ServerScriptService, insert a  >> Script <<  and paste THIS
	     whole file into it. (Name it anything, e.g. "Game".)

	  2. In StarterPlayer > StarterPlayerScripts, insert a
	     >> LocalScript <<  and paste the CLIENT file into it.

	  3. Delete the default Baseplate + SpawnLocation from Workspace
	     (the game builds its own island). Press Play.

	This one Script contains the config, remotes, combat engine, the
	Onigashima map builder, Luffy's full moveset, and all game wiring.
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
-- Playable roster (drives the character-select menu).
-- Only entries with Locked = false have a server-side moveset module.
-- To add a character: build src/server/Characters/<Id>.lua, register it in
-- init.server.lua's Characters table, and flip Locked to false here.
-- ========================================================================
Config.Roster = {
	{
		Id = "Luffy",
		Name = "Monkey D. Luffy",
		Title = "Gomu Gomu no Mi",
		Color = Color3.fromRGB(220, 60, 60),
		Locked = false,
		Moves = {
			"Gomu Gomu no Pistol",
			"Gomu Gomu no Bazooka",
			"Gomu Gomu no Gatling",
			"Rubber Combo",
		},
		Ult = "Gear 5",
	},
	{
		Id = "Zoro",
		Name = "Roronoa Zoro",
		Title = "Santoryu",
		Color = Color3.fromRGB(60, 150, 90),
		Locked = false,
		Moves = { "Oni Giri", "Tora Gari", "Ul-Tora Gari", "Sword Combo" },
		Ult = "Ashura",
	},
	{
		Id = "Sanji",
		Name = "Vinsmoke Sanji",
		Title = "Black Leg",
		Color = Color3.fromRGB(230, 200, 70),
		Locked = true,
		Moves = { "Collier", "Concasse", "Party Table Kick", "Kick Combo" },
		Ult = "Diable Jambe",
	},
	{
		Id = "Ace",
		Name = "Portgas D. Ace",
		Title = "Mera Mera no Mi",
		Color = Color3.fromRGB(235, 120, 40),
		Locked = true,
		Moves = { "Hiken", "Higan", "Enkai", "Flame Combo" },
		Ult = "Great Flame Commandment",
	},
	{
		Id = "Law",
		Name = "Trafalgar Law",
		Title = "Ope Ope no Mi",
		Color = Color3.fromRGB(210, 210, 220),
		Locked = true,
		Moves = { "Shambles", "Injection Shot", "Counter Shock", "Room Combo" },
		Ult = "Gamma Knife",
	},
}

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
-- Zoro - base moveset (fast rushdown, Three-Sword Style)
-- ========================================================================
local ZoroBase = {
	[1] = {
		Id = "OniGiri",
		Name = "Oni Giri",
		DamagePerHit = 6,
		Hits = 3,
		HitInterval = 0.11,
		Cooldown = 6,
		DashRange = 30,
		Range = 9,
		FinalKnockback = 62,
		FinalRagdoll = 1.2,
	},
	[2] = {
		Id = "ToraGari",
		Name = "Tora Gari",
		Damage = 20,
		Cooldown = 9,
		WindUp = 0.32,
		Range = 12,
		Width = 8,
		Knockback = 70,
		RagdollTime = 1.9,
	},
	[3] = {
		Id = "UlToraGari",
		Name = "Ul-Tora Gari",
		DamagePerHit = 7,
		Hits = 3,
		HitInterval = 0.16,
		Cooldown = 11,
		WindUp = 0.25,
		Radius = 13,
		Knockback = 55,
		RagdollTime = 1.3,
	},
	[4] = {
		Id = "SwordCombo",
		Name = "Sword Combo",
		DamagePerHit = 4,
		Hits = 5,
		HitInterval = 0.13,
		Cooldown = 5,
		DashRange = 24,
		Range = 8,
		FinalKnockback = 66,
		FinalRagdoll = 1.4,
	},
}

-- ========================================================================
-- Zoro - Ashura moveset (Nine-Sword Style, while the ult is active)
-- ========================================================================
local ZoroAshura = {
	[1] = {
		Id = "Ichibugin",
		Name = "Ashura: Ichibugin",
		Damage = 46,
		Cooldown = 16,
		WindUp = 0.7,
		Range = 42,
		Width = 18,
		Knockback = 120,
		RagdollTime = 2.6,
	},
	[2] = {
		Id = "Makyusen",
		Name = "Makyusen",
		DamagePerHit = 4,
		Hits = 12,
		Duration = 1.4,
		Cooldown = 11,
		WindUp = 0.22,
		Range = 20,
		Width = 12,
		FinalKnockback = 72,
		FinalRagdoll = 1.8,
	},
	[3] = {
		Id = "Tatsumaki",
		Name = "Tatsumaki",
		DamagePerHit = 5,
		Hits = 5,
		HitInterval = 0.12,
		Cooldown = 12,
		WindUp = 0.35,
		Radius = 16,
		Knockback = 40,
		LaunchPower = 85, -- upward launch
		RagdollTime = 2,
	},
	[4] = {
		Id = "KokujoOTatsumaki",
		Name = "Kokujo: O Tatsumaki",
		DamagePerHit = 8,
		Hits = 8,
		HitInterval = 0.16,
		Cooldown = 30,
		WindUp = 1.1,
		Radius = 24,
		Knockback = 60,
		LaunchPower = 110,
		RagdollTime = 3,
	},
}

-- ========================================================================
-- Per-character moveset registry (consumed by character modules + HUD).
-- Base = slots 1-4 normally; Ult = slots 1-4 while the ult is active.
-- Luffy reuses the top-level tables above; new characters add an entry.
-- ========================================================================
Config.Movesets = {
	Luffy = { UltName = "Gear 5", Base = Config.Base, Ult = Config.Gear5 },
	Zoro = { UltName = "Ashura", Base = ZoroBase, Ult = ZoroAshura },
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
	Dash             client -> server : ()
	Block            client -> server : (enabled: boolean)
	SelectCharacter  client -> server : (characterId: string)
	VFX          server -> client : (effectName: string, data: table)
	HUDUpdate    server -> client : (kind: string, ...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "UseSkill", "M1", "ActivateUlt", "Dash", "Block", "SelectCharacter", "VFX", "HUDUpdate" }

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
	-- Time out instead of yielding forever, so a stale/mismatched Remotes
	-- module surfaces as a clear error instead of a silent hang (which would
	-- stall the map build on the server and the UI on the client).
	local remote = folder:WaitForChild(name, 10)
	if not remote then
		error(
			("Remotes.get: RemoteEvent %q was not found. Make sure the Remotes "
				.. "module is updated to the latest version on BOTH server and client."):format(name),
			2
		)
	end
	return remote
end

return Remotes
end)()

-- ====================================================================
-- MODULE: Combat   (src/server/CombatService.lua)
-- ====================================================================
local Combat = (function()
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
end)()

-- ====================================================================
-- MODULE: MapBuilder   (src/server/MapBuilder.lua)
-- ====================================================================
local MapBuilder = (function()
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
end)()

-- ====================================================================
-- MODULE: Luffy   (src/server/Characters/Luffy.lua)
-- ====================================================================
local Luffy = (function()
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
			-- A grab: guards do not save you from being eaten.
			Combat.DealDamage(player, victim, cfg.Damage, { SilentVFX = true, Unblockable = true })
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
end)()

-- ====================================================================
-- MODULE: Zoro   (src/server/Characters/Zoro.lua)
-- ====================================================================
local Zoro = (function()
--[[
	Zoro.lua
	Server-side implementation of Roronoa Zoro's kit: a fast melee rushdown
	fighter using Santoryu (Three-Sword Style). Procedural katanas are welded
	to both hands and his mouth in Setup().

	Base moveset (slots 1-4):
		1  Oni Giri      - dash-in three-sword cross-slash
		2  Tora Gari     - heavy overhead downward cleave (knockdown)
		3  Ul-Tora Gari  - spinning slashes that hit everyone around him
		4  Sword Combo   - fast rushing multi-slash string

	Ult (G): ASHURA (Nine-Sword Style) for a limited time; slots become:
		1  Ashura: Ichibugin   - massive phantom nine-blade forward slash
		2  Makyusen            - barrage of afterimage slashes
		3  Tatsumaki           - spinning twister that launches enemies up
		4  Kokujo: O Tatsumaki - huge black-blade tornado finisher

	Interface matches Luffy: UseSkill, M1, ActivateUlt, DeactivateUlt,
	ForgetPlayer, Setup. All validation/timing/hitboxes are server side.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")



local VFX = Remotes.get("VFX")
local HUDUpdate = Remotes.get("HUDUpdate")

local Zoro = {}

local MY = Config.Movesets.Zoro

-- M1 chain state per player: { count, lastSwing, lockedUntil }
local m1State = {}
-- Ashura activation token per player so an old ult can't revert a new one.
local ashuraTokens = {}

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

local function isAshura(character)
	return character:GetAttribute("Ashura") == true
end

-- Everyone in a radius around the character (used for spin AoE moves).
local function targetsAround(character, radius)
	local root = Combat.Root(character)
	if not root then
		return {}
	end
	return Combat.GetTargetsInBox(root.CFrame, Vector3.new(radius * 2, 12, radius * 2), character)
end

-- ========================================================================
-- Procedural swords
-- ========================================================================

local function makeBladePart(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Builds a katana whose hilt sits at `grip` (relative to `limb`) and welds
-- every piece to the limb so it follows the body.
local function attachKatana(limb, grip)
	local pieces = {
		makeBladePart("Handle", Vector3.new(0.3, 1.6, 0.3), Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic),
		makeBladePart("Guard", Vector3.new(1.1, 0.2, 0.3), Color3.fromRGB(70, 55, 30), Enum.Material.Metal),
		makeBladePart("Blade", Vector3.new(0.16, 5, 0.55), Color3.fromRGB(220, 224, 232), Enum.Material.Metal),
	}
	local offsets = {
		CFrame.new(0, 0, 0),          -- handle at grip
		CFrame.new(0, 1, 0),          -- guard above handle
		CFrame.new(0, 3.6, 0),        -- blade above guard
	}
	for i, piece in pieces do
		piece.CFrame = limb.CFrame * grip * offsets[i]
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = piece
		weld.Parent = piece
		piece.Parent = limb.Parent
	end
end

-- Called by the server (in a task.spawn) when a Zoro character spawns.
function Zoro.Setup(_player, character)
	-- Body parts can stream in a frame after the Humanoid; wait briefly.
	local rightHand = character:WaitForChild("RightHand", 5)
		or character:FindFirstChild("Right Arm")
	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	local head = character:FindFirstChild("Head")
	if not character.Parent then
		return
	end

	if rightHand then
		attachKatana(rightHand, CFrame.new(0, 0, -0.4) * CFrame.Angles(math.rad(-8), 0, 0))
	end
	if leftHand then
		attachKatana(leftHand, CFrame.new(0, 0, -0.4) * CFrame.Angles(math.rad(-8), 0, 0))
	end
	if head then
		-- Wado Ichimonji held horizontally in his mouth.
		attachKatana(head, CFrame.new(0, -0.5, -1) * CFrame.Angles(0, 0, math.rad(90)))
	end
end

-- ========================================================================
-- M1 combo (sword slashes)
-- ========================================================================

function Zoro.M1(player, character)
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
	VFX:FireAllClients("ZoroM1", { Character = character, Index = isFinisher and cfg.ComboHits or state.count })

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
-- Shared move shapes
-- ========================================================================

-- A dash-in combo that snaps to the nearest target and slashes repeatedly.
local function dashSlashCombo(player, character, cfg, effectName)
	local target = Combat.NearestTarget(character, cfg.DashRange)

	if not target then
		Combat.SetBusy(character, 0.4)
		VFX:FireAllClients(effectName, { Character = character, Whiff = true })
		task.wait(0.22)
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
		if not isLast then
			task.wait(cfg.HitInterval)
		end
	end
end

-- A spinning multi-hit that strikes everyone in a radius; optional upward launch.
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

-- A single heavy forward strike after a windup.
local function forwardStrike(player, character, cfg, effectName, freeze)
	Combat.SetBusy(character, cfg.WindUp + 0.35, freeze)
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
	end
end

-- A forward multi-hit barrage of slashes.
local function slashBarrage(player, character, cfg, effectName)
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
		end
		if not isLast then
			task.wait(interval)
		end
	end
end

-- ========================================================================
-- Base moveset
-- ========================================================================

local function oniGiri(player, character)
	dashSlashCombo(player, character, MY.Base[1], "OniGiri")
end

local function toraGari(player, character)
	forwardStrike(player, character, MY.Base[2], "ToraGari", true)
end

local function ulToraGari(player, character)
	spinAoE(player, character, MY.Base[3], "UlToraGari")
end

local function swordCombo(player, character)
	dashSlashCombo(player, character, MY.Base[4], "SwordCombo")
end

-- ========================================================================
-- Ashura moveset
-- ========================================================================

local function ichibugin(player, character)
	forwardStrike(player, character, MY.Ult[1], "Ichibugin", true)
end

local function makyusen(player, character)
	slashBarrage(player, character, MY.Ult[2], "Makyusen")
end

local function tatsumaki(player, character)
	spinAoE(player, character, MY.Ult[3], "Tatsumaki")
end

local function kokujoOTatsumaki(player, character)
	spinAoE(player, character, MY.Ult[4], "KokujoOTatsumaki")
end

-- ========================================================================
-- Ult: Ashura
-- ========================================================================

function Zoro.ActivateUlt(player, character)
	if not Combat.IsActionable(character) then
		return false
	end
	if isAshura(character) then
		return false
	end
	local charge = player:GetAttribute("UltCharge") or 0
	if charge < Config.Ult.MaxCharge then
		return false
	end

	player:SetAttribute("UltCharge", 0)
	character:SetAttribute("Ashura", true)

	local token = (ashuraTokens[player] or 0) + 1
	ashuraTokens[player] = token

	local humanoid = Combat.Humanoid(character)
	if humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.Ult.HealPercent)
	end

	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed + Config.Ult.WalkSpeedBonus)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower + Config.Ult.JumpPowerBonus)
	Combat.RefreshMovement(character)

	-- Demonic dark-red Ashura aura, replicated to everyone.
	local highlight = Instance.new("Highlight")
	highlight.Name = "AshuraHighlight"
	highlight.FillColor = Color3.fromRGB(30, 10, 14)
	highlight.OutlineColor = Color3.fromRGB(180, 30, 40)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 0
	highlight.Parent = character

	VFX:FireAllClients("AshuraStart", { Character = character, Duration = Config.Ult.Duration })
	HUDUpdate:FireClient(player, "UltState", true, Config.Ult.Duration)

	task.delay(Config.Ult.Duration, function()
		if ashuraTokens[player] == token then
			Zoro.DeactivateUlt(player, character)
		end
	end)

	return true
end

function Zoro.DeactivateUlt(player, character)
	if not character or not character.Parent or not isAshura(character) then
		return
	end
	character:SetAttribute("Ashura", false)
	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower)
	Combat.RefreshMovement(character)

	local highlight = character:FindFirstChild("AshuraHighlight")
	if highlight then
		highlight:Destroy()
	end

	VFX:FireAllClients("AshuraEnd", { Character = character })
	if player.Parent then
		HUDUpdate:FireClient(player, "UltState", false)
	end
end

-- ========================================================================
-- Skill dispatch
-- ========================================================================

local BASE_MOVES = { oniGiri, toraGari, ulToraGari, swordCombo }
local ASHURA_MOVES = { ichibugin, makyusen, tatsumaki, kokujoOTatsumaki }

function Zoro.UseSkill(player, character, slot)
	if not Combat.IsActionable(character) then
		return nil
	end

	local ashura = isAshura(character)
	local moveset = ashura and ASHURA_MOVES or BASE_MOVES
	local cfg = ashura and MY.Ult[slot] or MY.Base[slot]
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

function Zoro.ForgetPlayer(player)
	m1State[player] = nil
	ashuraTokens[player] = nil
end

return Zoro
end)()

-- ====================================================================
-- MAIN: init.server   (src/server/init.server.lua)
-- ====================================================================
--[[
	init.server.lua
	Main server entry point: player/character setup, remote handling,
	server-side cooldown enforcement, KO leaderboard.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")



local UseSkill = Remotes.get("UseSkill")
local M1 = Remotes.get("M1")
local ActivateUlt = Remotes.get("ActivateUlt")
local Dash = Remotes.get("Dash")
local Block = Remotes.get("Block")
local SelectCharacter = Remotes.get("SelectCharacter")
local VFX = Remotes.get("VFX")
local HUDUpdate = Remotes.get("HUDUpdate")

MapBuilder.Build()

-- ========================================================================
-- Character registry
-- Every playable (unlocked) character has a module here with a uniform
-- interface: UseSkill, M1, ActivateUlt, DeactivateUlt, ForgetPlayer.
-- Add a new character with one line once its module + roster entry exist.
-- ========================================================================
local Characters = {
	Luffy = Luffy,
	Zoro = Zoro,
}
local DEFAULT_CHARACTER = "Luffy"

-- Which roster ids are actually selectable (unlocked + have a module).
local unlockedIds = {}
for _, entry in Config.Roster do
	if not entry.Locked and Characters[entry.Id] then
		unlockedIds[entry.Id] = true
	end
end

local function moduleFor(player)
	local id = player:GetAttribute("SelectedCharacter") or DEFAULT_CHARACTER
	return Characters[id] or Luffy
end

-- [player] = { [slot] = os.clock() time when the slot is ready again }
local cooldowns = {}
-- [player] = true while one of their skills is still executing
local casting = {}
-- [player] = os.clock() time when the dash is ready again
local dashReady = {}

-- ========================================================================
-- Skill handling
-- ========================================================================

UseSkill.OnServerEvent:Connect(function(player, slot)
	if type(slot) ~= "number" or slot < 1 or slot > 4 or slot % 1 ~= 0 then
		return
	end
	local character = player.Character
	if not character or casting[player] then
		return
	end

	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end
	if os.clock() < (playerCooldowns[slot] or 0) then
		return
	end

	Combat.SetBlocking(character, false) -- attacking drops your guard

	casting[player] = true
	local ok, cooldown = pcall(moduleFor(player).UseSkill, player, character, slot)
	casting[player] = nil

	if not ok then
		warn(("Skill %d errored for %s: %s"):format(slot, player.Name, tostring(cooldown)))
		return
	end
	if cooldown then
		playerCooldowns[slot] = os.clock() + cooldown
		HUDUpdate:FireClient(player, "Cooldown", slot, cooldown)
	end
end)

M1.OnServerEvent:Connect(function(player)
	local character = player.Character
	if character and not casting[player] then
		Combat.SetBlocking(character, false)
		moduleFor(player).M1(player, character)
	end
end)

-- ========================================================================
-- Dash & block
-- ========================================================================

Dash.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character or not Combat.IsActionable(character) then
		return
	end
	if os.clock() < (dashReady[player] or 0) then
		return
	end
	local root = Combat.Root(character)
	local humanoid = Combat.Humanoid(character)
	if not root or not humanoid then
		return
	end

	Combat.SetBlocking(character, false)
	dashReady[player] = os.clock() + Config.Dash.Cooldown

	-- Dash along the movement input, or forward when standing still.
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = Combat.FlatLook(character)
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = direction * Config.Dash.Speed + Vector3.new(0, Config.Dash.UpBoost, 0)
	velocity.Parent = root
	task.delay(Config.Dash.Duration, function()
		velocity:Destroy()
		attachment:Destroy()
	end)

	VFX:FireAllClients("Dash", { Character = character, Direction = direction })
	HUDUpdate:FireClient(player, "DashCooldown", Config.Dash.Cooldown)
end)

Block.OnServerEvent:Connect(function(player, enabled)
	local character = player.Character
	if character and type(enabled) == "boolean" and not casting[player] then
		Combat.SetBlocking(character, enabled)
	end
end)

-- Guard durability regenerates while not blocking.
task.spawn(function()
	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and Combat.IsAlive(character) and not character:GetAttribute("Blocking") then
				local blockHealth = character:GetAttribute("BlockHealth") or 0
				if blockHealth < Config.Block.MaxHealth then
					character:SetAttribute(
						"BlockHealth",
						math.min(Config.Block.MaxHealth, blockHealth + Config.Block.RegenPerSecond * 0.25)
					)
				end
			end
		end
	end
end)

ActivateUlt.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then
		return
	end
	if moduleFor(player).ActivateUlt(player, character) then
		-- Fresh moveset, fresh slots.
		cooldowns[player] = {}
	end
end)

-- ========================================================================
-- Character selection
-- ========================================================================

SelectCharacter.OnServerEvent:Connect(function(player, id)
	if type(id) ~= "string" or not unlockedIds[id] then
		return
	end
	if player:GetAttribute("SelectedCharacter") == id then
		return
	end

	-- Drop any active ult on the current character before switching.
	if player.Character then
		local current = moduleFor(player)
		if current.DeactivateUlt then
			current.DeactivateUlt(player, player.Character)
		end
	end

	player:SetAttribute("SelectedCharacter", id)
	player:SetAttribute("UltCharge", 0)
	cooldowns[player] = {}
	dashReady[player] = nil

	-- Respawn so any character-specific setup applies cleanly.
	player:LoadCharacter()
end)

-- ========================================================================
-- Player / character lifecycle
-- ========================================================================

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.MaxHealth = Config.Character.MaxHealth
	humanoid.Health = Config.Character.MaxHealth
	humanoid.BreakJointsOnDeath = false

	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower)
	character:SetAttribute("BlockHealth", Config.Block.MaxHealth)
	Combat.RefreshMovement(character)

	-- Character-specific spawn setup (e.g. Zoro's welded swords).
	local module = moduleFor(player)
	if module.Setup then
		task.spawn(module.Setup, player, character)
	end

	-- Brief spawn protection.
	if Config.Character.SpawnProtectionTime > 0 then
		local forceField = Instance.new("ForceField")
		forceField.Parent = character
		task.delay(Config.Character.SpawnProtectionTime, function()
			forceField:Destroy()
		end)
	end

	humanoid.Died:Connect(function()
		-- KO credit.
		local attackerId = character:GetAttribute("LastAttackerId")
		if attackerId then
			local attacker = Players:GetPlayerByUserId(attackerId)
			if attacker and attacker ~= player then
				local stats = attacker:FindFirstChild("leaderstats")
				local kos = stats and stats:FindFirstChild("KOs")
				if kos then
					kos.Value += 1
				end
			end
		end
		moduleFor(player).DeactivateUlt(player, character)
		Combat.ForgetCharacter(character)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("UltCharge", 0)
	player:SetAttribute("SelectedCharacter", DEFAULT_CHARACTER)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local kos = Instance.new("IntValue")
	kos.Name = "KOs"
	kos.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
	casting[player] = nil
	dashReady[player] = nil
	for _, module in Characters do
		if module.ForgetPlayer then
			module.ForgetPlayer(player)
		end
	end
	if player.Character then
		Combat.ForgetCharacter(player.Character)
	end
end)
