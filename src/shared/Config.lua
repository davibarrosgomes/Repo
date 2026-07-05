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
