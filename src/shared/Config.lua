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
