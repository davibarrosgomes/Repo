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
		Locked = false,
		Moves = { "Collier Shoot", "Concasse", "Party Table Kick", "Kick Combo" },
		Ult = "Diable Jambe",
	},
	{
		Id = "Ace",
		Name = "Portgas D. Ace",
		Title = "Mera Mera no Mi",
		Color = Color3.fromRGB(235, 120, 40),
		Locked = false,
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
	{
		-- EARLY ACCESS: unlocked by buying a Game Pass. Set GamePassId to your
		-- real pass id (Create > Game Passes on the Roblox site). Until it is
		-- set, only the game owner + admins can play him (for testing).
		Id = "Kaido",
		Name = "Kaido of the Beasts",
		Title = "Uo Uo no Mi, Azure Dragon",
		Color = Color3.fromRGB(90, 150, 200),
		EarlyAccess = true,
		GamePassId = 0, -- <-- put your Game Pass id here
		Price = "Early Access",
		Moves = { "Ragnaraku", "Kaifu", "Kanabo Sweep", "Bolo Breath" },
		Ult = "Azure Dragon",
	},
	{
		-- Admin-only OP character. Hidden from normal players; only shown +
		-- selectable after entering the admin code (validated server-side).
		Id = "Tung",
		Name = "Tung Tung Tung Sahur",
		Title = "Brainrot King  (ADMIN)",
		Color = Color3.fromRGB(196, 150, 70),
		Admin = true,
		Moves = { "Sahur Smash", "Tung Barrage", "Brainrot Spin", "Bat Combo" },
		Ult = "The King",
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
-- Sanji - base moveset (Black Leg; mobile kick fighter)
-- ========================================================================
local SanjiBase = {
	[1] = {
		Id = "Collier",
		Name = "Collier Shoot",
		Damage = 15,
		Cooldown = 5,
		WindUp = 0.22,
		Range = 11,
		Width = 6,
		Knockback = 74,
		RagdollTime = 1.3,
	},
	[2] = {
		Id = "Concasse",
		Name = "Concasse",
		Damage = 22,
		Cooldown = 10,
		WindUp = 0.42,
		Range = 10,
		Width = 9,
		Knockback = 58, -- driven downward
		RagdollTime = 2,
	},
	[3] = {
		Id = "PartyTable",
		Name = "Party Table Kick",
		DamagePerHit = 6,
		Hits = 4,
		HitInterval = 0.14,
		Cooldown = 11,
		WindUp = 0.2,
		Radius = 12,
		Knockback = 55,
		RagdollTime = 1.3,
	},
	[4] = {
		Id = "KickCombo",
		Name = "Kick Combo",
		DamagePerHit = 4,
		Hits = 6,
		HitInterval = 0.12,
		Cooldown = 5,
		DashRange = 26,
		Range = 8,
		FinalKnockback = 68,
		FinalRagdoll = 1.4,
	},
}

-- ========================================================================
-- Sanji - Diable Jambe moveset (flaming leg; adds burn damage-over-time)
-- ========================================================================
local SanjiDiable = {
	[1] = {
		Id = "PremierHachis",
		Name = "Diable Jambe: Premier Hachis",
		DamagePerHit = 4,
		Hits = 12,
		Duration = 1.4,
		Cooldown = 11,
		WindUp = 0.2,
		Range = 18,
		Width = 11,
		FinalKnockback = 70,
		FinalRagdoll = 1.7,
		BurnDps = 3,
		BurnTime = 3,
	},
	[2] = {
		Id = "FlambageShot",
		Name = "Diable Jambe: Flambage Shot",
		DamagePerHit = 6,
		Hits = 4,
		HitInterval = 0.12,
		Cooldown = 12,
		WindUp = 0.3,
		Radius = 15,
		Knockback = 45,
		LaunchPower = 82,
		RagdollTime = 2,
		BurnDps = 4,
		BurnTime = 3,
	},
	[3] = {
		Id = "MoutonShot",
		Name = "Diable Jambe: Mouton Shot",
		Damage = 44,
		Cooldown = 15,
		WindUp = 0.6,
		Range = 30,
		Width = 12,
		Knockback = 120,
		RagdollTime = 2.5,
		BurnDps = 5,
		BurnTime = 3,
	},
	[4] = {
		Id = "GrillShot",
		Name = "Bien Cuit: Grill Shot",
		DamagePerHit = 8,
		Hits = 6,
		HitInterval = 0.13,
		Cooldown = 30,
		WindUp = 1,
		Range = 24,
		Width = 16,
		FinalKnockback = 100,
		FinalRagdoll = 3,
		BurnDps = 6,
		BurnTime = 4,
	},
}

-- ========================================================================
-- Ace - base moveset (Mera Mera no Mi; ranged fire zoner, projectiles)
-- ========================================================================
local AceBase = {
	[1] = {
		Id = "Hiken",
		Name = "Hiken",
		Cooldown = 7,
		WindUp = 0.4,
		Speed = 130,
		Life = 1,
		Radius = 4,
		Damage = 24,
		ExplodeRadius = 11,
		Knockback = 95,
		RagdollTime = 1.6,
		Burn = { Dps = 3, Time = 3 },
	},
	[2] = {
		Id = "Higan",
		Name = "Higan",
		Cooldown = 9,
		WindUp = 0.25,
		Bullets = 6,
		BulletInterval = 0.09,
		BulletSpeed = 175,
		BulletLife = 0.7,
		BulletRadius = 2,
		DamagePerBullet = 5,
		Knockback = 20,
		Burn = { Dps = 2, Time = 2 },
	},
	[3] = {
		Id = "Enkai",
		Name = "Enkai",
		Cooldown = 11,
		WindUp = 0.45,
		Range = 42, -- target search range
		Radius = 9,
		Damage = 20,
		Knockback = 40,
		LaunchPower = 72,
		RagdollTime = 1.6,
		Burn = { Dps = 4, Time = 3 },
	},
	[4] = {
		Id = "FlameCombo",
		Name = "Flame Combo",
		Cooldown = 6,
		DashRange = 24,
		Range = 8,
		Hits = 5,
		HitInterval = 0.12,
		DamagePerHit = 4,
		FinalKnockback = 60,
		FinalRagdoll = 1.4,
		Burn = { Dps = 2, Time = 2 },
	},
}

-- ========================================================================
-- Ace - Great Flame Commandment moveset (ult; enlarged fire attacks)
-- ========================================================================
local AceGreatFlame = {
	[1] = {
		Id = "Entei",
		Name = "Dai Enkai: Entei",
		Cooldown = 18,
		WindUp = 1,
		Speed = 80,
		Life = 1.6,
		Radius = 12,
		Damage = 55,
		ExplodeRadius = 26,
		Knockback = 150,
		RagdollTime = 2.6,
		Burn = { Dps = 6, Time = 4 },
	},
	[2] = {
		Id = "EnhancedHigan",
		Name = "Enkai: Higan",
		Cooldown = 12,
		WindUp = 0.3,
		Bullets = 12,
		BulletInterval = 0.07,
		BulletSpeed = 190,
		BulletLife = 0.8,
		BulletRadius = 2.6,
		DamagePerBullet = 5,
		ExplodeRadius = 5,
		Knockback = 25,
		Burn = { Dps = 3, Time = 2 },
	},
	[3] = {
		Id = "Kyokaen",
		Name = "Kyokaen",
		Cooldown = 13,
		WindUp = 0.5,
		Range = 32,
		Width = 16,
		Damage = 40,
		Knockback = 110,
		RagdollTime = 2.2,
		Burn = { Dps = 5, Time = 3 },
	},
	[4] = {
		Id = "Hotarubi",
		Name = "Hotarubi: Hidaruma",
		Cooldown = 30,
		WindUp = 1.2,
		Range = 45,
		Radius = 16,
		Damage = 60,
		Knockback = 90,
		LaunchPower = 60,
		RagdollTime = 3,
		Burn = { Dps = 8, Time = 4 },
	},
}

-- ========================================================================
-- Tung Tung Tung Sahur - ADMIN-ONLY OP character (bat brainrot king).
-- 2x health + 1.5x damage (applied via HealthMult/DamageMult below). Every
-- ult move is a one-hit kill (Damage far above any health pool).
-- ========================================================================
local ONE_HIT_KILL = 100000

local TungBase = {
	[1] = {
		Id = "SahurSmash",
		Name = "Sahur Smash",
		Damage = 22,
		Cooldown = 7,
		WindUp = 0.38,
		Range = 13,
		Width = 9,
		Knockback = 85,
		RagdollTime = 2,
	},
	[2] = {
		Id = "TungBarrage",
		Name = "Tung Barrage",
		DamagePerHit = 5,
		Hits = 8,
		Duration = 1.2,
		Cooldown = 10,
		WindUp = 0.3,
		Range = 14,
		Width = 9,
		FinalKnockback = 72,
		FinalRagdoll = 1.8,
	},
	[3] = {
		Id = "BrainrotSpin",
		Name = "Brainrot Spin",
		DamagePerHit = 8,
		Hits = 3,
		HitInterval = 0.16,
		Cooldown = 11,
		WindUp = 0.25,
		Radius = 13,
		Knockback = 60,
		RagdollTime = 1.5,
	},
	[4] = {
		Id = "BatCombo",
		Name = "Bat Combo",
		DamagePerHit = 5,
		Hits = 5,
		HitInterval = 0.12,
		Cooldown = 6,
		DashRange = 28,
		Range = 8,
		FinalKnockback = 72,
		FinalRagdoll = 1.5,
	},
}

local TungKing = {
	[1] = {
		Id = "RoyalDecree",
		Name = "Royal Decree",
		Damage = ONE_HIT_KILL,
		Cooldown = 5,
		WindUp = 0.3,
		Range = 17,
		Width = 11,
		Knockback = 130,
		RagdollTime = 3,
	},
	[2] = {
		Id = "KingsJudgement",
		Name = "King's Judgement",
		DamagePerHit = ONE_HIT_KILL,
		Hits = 1,
		HitInterval = 0.1,
		Cooldown = 9,
		WindUp = 0.4,
		Radius = 20,
		Knockback = 110,
		RagdollTime = 3,
	},
	[3] = {
		Id = "SahurRush",
		Name = "Sahur Sahur Sahur",
		DamagePerHit = ONE_HIT_KILL,
		Hits = 3,
		HitInterval = 0.1,
		Cooldown = 8,
		DashRange = 34,
		Range = 9,
		FinalKnockback = 120,
		FinalRagdoll = 3,
	},
	[4] = {
		Id = "CrownCrush",
		Name = "Crown Crush",
		Damage = ONE_HIT_KILL,
		Cooldown = 12,
		WindUp = 0.55,
		Range = 19,
		Width = 15,
		Knockback = 150,
		RagdollTime = 3,
	},
}

-- ========================================================================
-- Kaido - base moveset (kanabo bruiser; Uo Uo no Mi in human form)
-- ========================================================================
local KaidoBase = {
	[1] = {
		Id = "Ragnaraku",
		Name = "Ragnaraku",
		Damage = 30,
		Cooldown = 9,
		WindUp = 0.5,
		Range = 15,
		Width = 10,
		Knockback = 100,
		RagdollTime = 2.5,
	},
	[2] = {
		Id = "Kaifu",
		Name = "Kaifu",
		Cooldown = 8,
		WindUp = 0.35,
		Speed = 120,
		Life = 1.1,
		Radius = 3.5,
		Damage = 22,
		ExplodeRadius = 8,
		Knockback = 80,
		RagdollTime = 1.6,
	},
	[3] = {
		Id = "KanaboSweep",
		Name = "Kanabo Sweep",
		DamagePerHit = 12,
		Hits = 2,
		HitInterval = 0.2,
		Cooldown = 11,
		WindUp = 0.35,
		Radius = 15,
		Knockback = 82,
		RagdollTime = 1.8,
	},
	[4] = {
		Id = "BoloBreath",
		Name = "Bolo Breath",
		Damage = 20,
		Cooldown = 10,
		WindUp = 0.4,
		Range = 26,
		Width = 14,
		Knockback = 60,
		RagdollTime = 1.6,
		Burn = { Dps = 4, Time = 3 },
	},
}

-- ========================================================================
-- Kaido - Azure Dragon moveset (ult; transformed dragon form)
-- ========================================================================
local KaidoDragon = {
	[1] = {
		Id = "DragonBoroBreath",
		Name = "Boro Breath",
		Cooldown = 14,
		WindUp = 0.6,
		Speed = 150,
		Life = 1.6,
		Radius = 9,
		Damage = 55,
		ExplodeRadius = 22,
		Knockback = 150,
		RagdollTime = 2.6,
		Burn = { Dps = 6, Time = 4 },
	},
	[2] = {
		Id = "BlastBreath",
		Name = "Blast Breath",
		Cooldown = 12,
		WindUp = 0.5,
		Speed = 92,
		Life = 1.4,
		Radius = 10,
		Damage = 48,
		ExplodeRadius = 24,
		Knockback = 140,
		RagdollTime = 2.4,
		Burn = { Dps = 5, Time = 3 },
	},
	[3] = {
		Id = "DragonTwister",
		Name = "Dragon Twister",
		DamagePerHit = 8,
		Hits = 5,
		HitInterval = 0.14,
		Cooldown = 13,
		WindUp = 0.4,
		Radius = 20,
		Knockback = 60,
		LaunchPower = 100,
		RagdollTime = 2.5,
	},
	[4] = {
		Id = "RaimeiHakke",
		Name = "Raimei Hakke",
		Damage = 70,
		Cooldown = 18,
		WindUp = 0.8,
		Range = 20,
		Width = 16,
		Knockback = 170,
		RagdollTime = 3,
	},
}

-- ========================================================================
-- Per-character moveset registry (consumed by character modules + HUD).
-- Base = slots 1-4 normally; Ult = slots 1-4 while the ult is active.
-- HealthMult / DamageMult (optional) scale a character's stats.
-- Luffy reuses the top-level tables above; new characters add an entry.
-- ========================================================================
Config.Movesets = {
	Luffy = { UltName = "Gear 5", Base = Config.Base, Ult = Config.Gear5 },
	Zoro = { UltName = "Ashura", Base = ZoroBase, Ult = ZoroAshura },
	Sanji = { UltName = "Diable Jambe", Base = SanjiBase, Ult = SanjiDiable },
	Ace = { UltName = "Great Flame Commandment", Base = AceBase, Ult = AceGreatFlame },
	Tung = { UltName = "The King", Base = TungBase, Ult = TungKing, HealthMult = 2, DamageMult = 1.5 },
	Kaido = { UltName = "Azure Dragon", Base = KaidoBase, Ult = KaidoDragon, HealthMult = 1.5, DamageMult = 1.1 },
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
