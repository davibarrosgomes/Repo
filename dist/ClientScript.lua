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
	AdminAuth        client -> server : (code: string) ; server -> client : (granted: boolean)
	VFX          server -> client : (effectName: string, data: table)
	HUDUpdate    server -> client : (kind: string, ...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "UseSkill", "M1", "ActivateUlt", "Dash", "Block", "SelectCharacter", "AdminAuth", "VFX", "HUDUpdate" }

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
local ACCENT_ULT = Color3.fromRGB(255, 255, 255)
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

-- Resolves the selected character's moveset + roster entry (for names/colors).
local function moveset()
	local id = LocalPlayer:GetAttribute("SelectedCharacter") or "Luffy"
	return Config.Movesets[id] or Config.Movesets.Luffy
end

local function accentColor()
	local id = LocalPlayer:GetAttribute("SelectedCharacter") or "Luffy"
	for _, entry in Config.Roster do
		if entry.Id == id then
			return entry.Color
		end
	end
	return Color3.fromRGB(220, 60, 60)
end

local function slotName(slot)
	local ms = moveset()
	local cfg = gear5Active and ms.Ult[slot] or ms.Base[slot]
	return cfg and cfg.Name or "?"
end

local function refreshSlotNames()
	local accent = gear5Active and ACCENT_ULT or accentColor()
	for slot, ui in slots do
		ui.nameLabel.Text = slotName(slot)
		ui.keyLabel.TextColor3 = accent
		ui.stroke.Color = accent
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
		stroke.Color = accentColor()
		stroke.Thickness = 1.5
		stroke.Transparency = 0.3
		stroke.Parent = frame

		local keyLabel = Instance.new("TextLabel")
		keyLabel.BackgroundTransparency = 1
		keyLabel.Position = UDim2.new(0, 6, 0, 4)
		keyLabel.Size = UDim2.new(0, 24, 0, 24)
		keyLabel.Font = Enum.Font.GothamBlack
		keyLabel.TextSize = 20
		keyLabel.TextColor3 = accentColor()
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

	-- Switching character swaps the whole moveset display.
	LocalPlayer:GetAttributeChangedSignal("SelectedCharacter"):Connect(function()
		gear5Active = false
		refreshSlotNames()
		onCharge()
	end)
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
	local ultName = moveset().UltName or "ULT"
	local ratio = math.clamp(charge / Config.Ult.MaxCharge, 0, 1)
	TweenService:Create(ultFill, TweenInfo.new(0.2), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
	if gear5Active then
		ultLabel.Text = ultName:upper()
	elseif ratio >= 1 then
		ultLabel.Text = ("%s READY - PRESS G"):format(ultName:upper())
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
		ultLabel.Text = (moveset().UltName or "ULT"):upper()
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
	High-end procedural combat visuals + procedural character animation.

	Everything is generated at runtime (no uploaded assets required):
	  - real arm-thrust posing by layering Motor6D C0 offsets over the idle
	    animation, so Luffy actually winds up and throws his punches
	  - rubber arms that launch from the hand with trails and Haki coating
	  - impact frames: flash, shockwave rings, sparks, dust, ground cracks
	  - "hitstop" camera punch + FOV kick + screen flash on heavy blows
	  - speed lines, charge auras, afterimages, Conqueror's lightning

	Driven entirely by the server's VFX RemoteEvent; every effect name the
	server fires has a handler in the Effects table below.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local DEFAULT_FOV = 70

-- Palette ----------------------------------------------------------------
local RUBBER = Color3.fromRGB(245, 205, 170)
local HAKI = Color3.fromRGB(22, 20, 28)         -- Armament Haki black
local HAKI_EDGE = Color3.fromRGB(150, 70, 255)  -- Conqueror lightning
local GEAR5 = Color3.fromRGB(255, 255, 255)
local GEAR5_RIM = Color3.fromRGB(255, 220, 240)
local TOON = Color3.fromRGB(255, 130, 200)
local GOLD = Color3.fromRGB(255, 225, 150)
local IMPACT_YELLOW = Color3.fromRGB(255, 240, 150)
local BLADE = Color3.fromRGB(220, 224, 232)
local SLASH = Color3.fromRGB(205, 255, 232)   -- cool blade streak
local ASHURA_RED = Color3.fromRGB(190, 34, 46)
local ASHURA_DARK = Color3.fromRGB(24, 8, 12)
local AIR = Color3.fromRGB(200, 228, 255)      -- Sanji air-pressure kicks
local FIRE_ORANGE = Color3.fromRGB(255, 138, 36)
local FIRE_YELLOW = Color3.fromRGB(255, 208, 96)
local FIRE_DEEP = Color3.fromRGB(210, 60, 20)

local VFXClient = {}

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "CombatEffects"
effectsFolder.Parent = workspace

-- Per-character state.
local gear5Emitters = {}
local rubberHighlights = {}
local blockHighlights = {}
local ashuraAuras = {} -- [character] = true while the Ashura aura loop runs
local diableFires = {} -- [character] = { instances } for the Diable Jambe leg fire
local igniteFires = {} -- [character] = Fire instance for burn DoT
local baseC0 = setmetatable({}, { __mode = "k" }) -- memoized rest pose per Motor6D
local motorCache = setmetatable({}, { __mode = "k" }) -- [character][side] = Motor6D

-- Screen flash overlay (created lazily).
local flashFrame

-- ========================================================================
-- Core helpers
-- ========================================================================

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in props do
		part[key] = value
	end
	part.Parent = effectsFolder
	return part
end

local function tween(instance, time, props, style, dir)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function attachment(part, offset)
	local a = Instance.new("Attachment")
	a.Position = offset or Vector3.zero
	a.Parent = part
	return a
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

local function getPart(character, names)
	if not character then
		return nil
	end
	for _, name in names do
		local p = character:FindFirstChild(name)
		if p then
			return p
		end
	end
	return nil
end

-- The character's hand (R15), falling back to arm (R6) then root.
local function handPart(character, side)
	return getPart(character, { side .. "Hand", side .. " Arm", "HumanoidRootPart" })
end

local function isLocal(character)
	return character and character == LocalPlayer.Character
end

local function distanceFromLocal(position)
	local r = root(LocalPlayer.Character)
	return r and (r.Position - position).Magnitude or math.huge
end

-- ========================================================================
-- Camera juice
-- ========================================================================

local function shake(origin, intensity, duration)
	local falloff = math.clamp(1 - distanceFromLocal(origin) / 130, 0, 1)
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
			Camera.CFrame *= CFrame.new(
				(math.random() - 0.5) * 2 * intensity * decay,
				(math.random() - 0.5) * 2 * intensity * decay,
				0
			) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.02 * intensity * decay)
		end
	end)
end

-- Quick punch-in then ease-out of the FOV; scaled by distance.
local function fovPunch(origin, amount, duration)
	local falloff = math.clamp(1 - distanceFromLocal(origin) / 110, 0, 1)
	amount *= falloff
	if amount <= 0.1 then
		return
	end
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			local p = elapsed / duration
			-- fast dip in the first 20%, smooth return after.
			local curve = p < 0.2 and (p / 0.2) or (1 - (p - 0.2) / 0.8)
			Camera.FieldOfView = DEFAULT_FOV - amount * curve
		end
		Camera.FieldOfView = DEFAULT_FOV
	end)
end

-- Simulated hitstop: a single-frame white/color pop on the screen edges.
local function screenFlash(color, maxAlpha, duration)
	if not flashFrame then
		local gui = Instance.new("ScreenGui")
		gui.Name = "CombatFlash"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 50
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		flashFrame = Instance.new("Frame")
		flashFrame.Size = UDim2.fromScale(1, 1)
		flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		flashFrame.BackgroundTransparency = 1
		flashFrame.BorderSizePixel = 0
		flashFrame.Parent = gui
	end
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - maxAlpha
	tween(flashFrame, duration, { BackgroundTransparency = 1 })
end

-- ========================================================================
-- Effect primitives
-- ========================================================================

local function addTrail(part, color, lifetime, width)
	local a0 = attachment(part, Vector3.new(0, (width or 1), 0))
	local a1 = attachment(part, Vector3.new(0, -(width or 1), 0))
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = lifetime or 0.25
	trail.LightEmission = 0.6
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = part
	return trail
end

local function shockwave(position, maxSize, color, time, thickness)
	local ring = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness or 0.5, 2, 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	tween(ring, time, { Size = Vector3.new(thickness or 0.5, maxSize, maxSize), Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(ring, time + 0.1)
end

-- Flat expanding energy disc on the ground (for slams / activations).
local function groundDisc(position, maxRadius, color, time)
	local disc = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2, 2),
		CFrame = CFrame.new(position.X, position.Y - 2.5, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})
	tween(disc, time, { Size = Vector3.new(0.6, maxRadius, maxRadius), Transparency = 1 })
	Debris:AddItem(disc, time + 0.1)
end

local function sparks(position, color, count, speed, size)
	local holder = makePart({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size or 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(0.25, 0.55)
	emitter.Speed = NumberRange.new(speed or 25)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Enabled = false
	emitter.Parent = holder
	emitter:Emit(count or 24)
	Debris:AddItem(holder, 1)
end

local function dust(position, color, count)
	local holder = makePart({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(140, 130, 120))
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(1, 9),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Enabled = false
	emitter.Parent = holder
	emitter:Emit(count or 14)
	Debris:AddItem(holder, 1.5)
end

-- Cracked shards radiating out on the ground.
local function groundCrack(position, radius, color)
	for i = 1, 8 do
		local angle = math.rad(i * 45 + math.random(-12, 12))
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local length = radius * (0.6 + math.random() * 0.5)
		local shard = makePart({
			Size = Vector3.new(1, 0.4, length),
			CFrame = CFrame.lookAt(position - Vector3.new(0, 2.4, 0) + dir * length / 2, position + dir),
			Color = color or Color3.fromRGB(60, 55, 50),
			Material = Enum.Material.Slate,
			Transparency = 0.1,
		})
		tween(shard, 0.7, { Transparency = 1 }, Enum.EasingStyle.Linear)
		Debris:AddItem(shard, 0.8)
	end
end

-- Flying debris chunks kicked up by a big impact.
local function debris(position, color, count)
	for _ = 1, count or 6 do
		local chunk = makePart({
			Anchored = false,
			CanCollide = false,
			Material = Enum.Material.Slate,
			Color = color or Color3.fromRGB(70, 65, 60),
			Size = Vector3.new(1, 1, 1) * (0.6 + math.random()),
			CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
		})
		chunk.AssemblyLinearVelocity = Vector3.new(
			(math.random() - 0.5) * 40,
			25 + math.random() * 25,
			(math.random() - 0.5) * 40
		)
		tween(chunk, 1, { Transparency = 1 })
		Debris:AddItem(chunk, 1.1)
	end
end

-- Converging speed-lines around a character (barrage feel).
local function speedLines(character, duration, color)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local r = root(character)
			if not r then
				break
			end
			local angle = math.rad(math.random(0, 359))
			local far = r.Position + Vector3.new(math.cos(angle) * 14, math.random(-4, 6), math.sin(angle) * 14)
			local near = r.Position + Vector3.new(math.cos(angle) * 5, 0, math.sin(angle) * 5)
			local line = makePart({
				Size = Vector3.new(0.15, 0.15, (far - near).Magnitude),
				CFrame = CFrame.lookAt((far + near) / 2, far),
				Color = color,
				Transparency = 0.2,
			})
			tween(line, 0.12, { Transparency = 1 })
			Debris:AddItem(line, 0.15)
			elapsed += RunService.RenderStepped:Wait()
		end
	end)
end

-- Charge-in aura: particles flowing INTO a point during a windup.
local function chargeAura(getPos, duration, color)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local pos = getPos()
			if not pos then
				break
			end
			local angle = math.rad(math.random(0, 359))
			local start = pos + Vector3.new(math.cos(angle) * 10, math.random(-5, 5), math.sin(angle) * 10)
			local mote = makePart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.1, 1.1, 1.1),
				CFrame = CFrame.new(start),
				Color = color,
				Transparency = 0.1,
			})
			tween(mote, 0.3, { CFrame = CFrame.new(pos), Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(mote, 0.35)
			elapsed += task.wait(0.04)
		end
	end)
end

-- Full impact package.
local function impact(position, opts)
	opts = opts or {}
	local color = opts.Color or IMPACT_YELLOW
	local scale = opts.Scale or 1

	-- White-hot flash sphere.
	local flash = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2) * scale,
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = 0.05,
	})
	tween(flash, 0.18, { Size = Vector3.new(7, 7, 7) * scale, Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(flash, 0.25)

	shockwave(position, 14 * scale, color, 0.35, 0.5)
	sparks(position, color, math.floor(18 * scale), 22 * scale, 1 * scale)

	if opts.Heavy then
		shockwave(position, 26 * scale, GEAR5, 0.5, 0.8)
		dust(position, opts.DustColor, 18)
		groundCrack(position, 10 * scale, opts.CrackColor)
		debris(position, opts.CrackColor, 6)
		shake(position, 0.9 * scale, 0.3)
		fovPunch(position, 6 * scale, 0.22)
		if distanceFromLocal(position) < 40 then
			screenFlash(color, 0.25, 0.18)
		end
	else
		shake(position, 0.35, 0.18)
	end
end

-- ========================================================================
-- Procedural character animation (Motor6D posing)
-- ========================================================================

local function getMotor(character, side)
	if not character then
		return nil
	end
	local cache = motorCache[character]
	if cache and cache[side] and cache[side].Parent then
		return cache[side]
	end
	if not cache then
		cache = {}
		motorCache[character] = cache
	end
	-- R15 uses "RightShoulder"; R6 uses "Right Shoulder".
	for _, name in { side .. "Shoulder", side .. " Shoulder" } do
		for _, d in character:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == name then
				cache[side] = d
				return d
			end
		end
	end
	return nil
end

local function restPose(motor)
	if not baseC0[motor] then
		baseC0[motor] = motor.C0
	end
	return baseC0[motor]
end

-- Thrust an arm forward (punch), then let it ease back to the idle.
-- `power` 0..1 scales how far the arm extends.
local function punchArm(character, side, outTime, hold, power)
	local motor = getMotor(character, side)
	if not motor then
		return
	end
	power = power or 1
	local base = restPose(motor)
	-- Raise + rotate the upper arm so it points forward.
	local posed = base * CFrame.Angles(math.rad(-95 * power), 0, math.rad((side == "Right" and -8 or 8) * power))
	tween(motor, outTime or 0.08, { C0 = posed }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay((outTime or 0.08) + (hold or 0.06), function()
		if motor.Parent then
			tween(motor, 0.22, { C0 = base }, Enum.EasingStyle.Quad)
		end
	end)
end

-- Both arms forward (Bazooka / Bajrang).
local function pushBothArms(character, outTime, hold)
	punchArm(character, "Right", outTime, hold, 1)
	punchArm(character, "Left", outTime, hold, 1)
end

-- A faint afterimage clone of the torso+arms (dash / burst).
local function afterImage(character, color, life)
	local r = root(character)
	if not r then
		return
	end
	local ghost = makePart({
		Size = Vector3.new(2.5, 5, 1.5),
		CFrame = r.CFrame,
		Color = color or GEAR5,
		Material = Enum.Material.ForceField,
		Transparency = 0.4,
	})
	tween(ghost, life or 0.35, { Transparency = 1 })
	Debris:AddItem(ghost, (life or 0.35) + 0.05)
end

-- ========================================================================
-- Keyframe animation engine
-- Poses the whole R15 rig (torso, head, both arms, both legs) through a
-- timeline of keyframes layered over the idle animation, so moves read as
-- real, exaggerated, goofy animation instead of a single static pose.
-- A "pose" maps joint names to CFrame offsets applied over the rest C0.
-- Joints: Root, Waist, Neck, RightShoulder, LeftShoulder, RightElbow,
--         LeftElbow, RightHip, LeftHip, RightKnee, LeftKnee.
-- ========================================================================

local jointCache = setmetatable({}, { __mode = "k" })

local function getJoint(character, name)
	if not character then
		return nil
	end
	local cache = jointCache[character]
	if cache and cache[name] and cache[name].Parent then
		return cache[name]
	end
	if not cache then
		cache = {}
		jointCache[character] = cache
	end
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			cache[name] = d
			return d
		end
	end
	return nil
end

-- Terse pose authoring: ra() = rotation in degrees, po() = position + rotation.
local function ra(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end
local function po(px, py, pz, rx, ry, rz)
	return CFrame.new(px or 0, py or 0, pz or 0) * ra(rx, ry, rz)
end

-- Tween a whole pose (jointName -> offset) over `time`.
local function poseCharacter(character, pose, time, style, dir)
	for name, offset in pose do
		local joint = getJoint(character, name)
		if joint then
			tween(joint, time, { C0 = restPose(joint) * offset }, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
		end
	end
end

local function settlePose(character, touched, time)
	for name in touched do
		local joint = getJoint(character, name)
		if joint then
			tween(joint, time or 0.22, { C0 = restPose(joint) }, Enum.EasingStyle.Quad)
		end
	end
end

-- Play an ordered list of keyframes:
--   { { t = seconds, pose = {...}, style = , dir = }, ... }
-- Runs in its own thread and eases back to rest at the end (unless holdLast).
local function playSequence(character, frames, holdLast)
	if not character then
		return
	end
	task.spawn(function()
		local touched = {}
		for _, frame in frames do
			if not character.Parent then
				return
			end
			for name in frame.pose do
				touched[name] = true
			end
			poseCharacter(character, frame.pose, frame.t, frame.style, frame.dir)
			task.wait(frame.t)
		end
		if not holdLast then
			settlePose(character, touched, 0.24)
		end
	end)
end

local BACK = Enum.EasingStyle.Back
local SINE = Enum.EasingStyle.Sine
local QUINT = Enum.EasingStyle.Quint

-- ========================================================================
-- Character animation library (signature, goofy full-body sequences)
-- ========================================================================

local Anims = {}

-- ---- Luffy: loose rubbery windmill arms + big rubber wind-ups -----------
function Anims.luffyM1(character, index)
	local right = index % 2 == 1
	playSequence(character, {
		{ t = 0.05, pose = {
			Waist = po(0, 0, 0, 6, right and -30 or 30, 0),
			[right and "RightShoulder" or "LeftShoulder"] = ra(-140, 0, right and -20 or 20),
			[right and "RightElbow" or "LeftElbow"] = ra(-30),
			Neck = ra(6, right and -12 or 12, 0),
		}, style = BACK },
		{ t = 0.1, pose = {
			Waist = po(0, 0, 0, 10, right and 26 or -26, 0),
			[right and "RightShoulder" or "LeftShoulder"] = ra(-108, 0, right and 8 or -8),
			[right and "RightElbow" or "LeftElbow"] = ra(0),
		}, style = QUINT },
	})
end

function Anims.luffyWindup(character, windup)
	playSequence(character, {
		-- Pull the arm way back, lean back, cheeks puff (goofy anticipation).
		{ t = windup * 0.6, pose = {
			Waist = po(0, -0.2, -0.4, -20, 40, 0),
			RightShoulder = ra(60, 0, -40),
			RightElbow = ra(-70),
			Neck = ra(-10, 20, 0),
			RightHip = ra(-14),
			LeftHip = ra(10),
		}, style = SINE },
		-- FIRE: whip the whole body forward.
		{ t = 0.08, pose = {
			Waist = po(0, 0, 0.2, 22, -20, 0),
			RightShoulder = ra(-100, 0, 6),
			RightElbow = ra(0),
			Neck = ra(12, -10, 0),
		}, style = BACK },
		{ t = 0.16, pose = {
			Waist = po(0, 0, 0, 10, -6, 0),
			RightShoulder = ra(-88),
		}, style = QUINT },
	})
end

function Anims.luffyBazooka(character, windup)
	playSequence(character, {
		{ t = windup * 0.6, pose = {
			Waist = po(0, -0.3, -0.5, -24, 0, 0),
			RightShoulder = ra(70, 0, -30),
			LeftShoulder = ra(70, 0, 30),
			RightElbow = ra(-80),
			LeftElbow = ra(-80),
			Neck = ra(-14, 0, 0),
			RightHip = ra(-20),
			LeftHip = ra(-20),
		}, style = SINE },
		{ t = 0.1, pose = {
			Waist = po(0, 0.2, 0.4, 26, 0, 0),
			RightShoulder = ra(-96, 0, 4),
			LeftShoulder = ra(-96, 0, -4),
			RightElbow = ra(0),
			LeftElbow = ra(0),
			Neck = ra(14, 0, 0),
		}, style = BACK },
		{ t = 0.18, pose = { Waist = po(0, 0, 0, 12, 0, 0) }, style = QUINT },
	})
end

-- ---- Zoro: bladed stances, shoulder-led slashes, three-sword spin -------
function Anims.zoroM1(character, index)
	local right = index % 2 == 1
	playSequence(character, {
		{ t = 0.05, pose = {
			Waist = po(0, 0, 0, 4, right and 34 or -34, 0),
			RightShoulder = ra(right and -70 or -30, 0, -18),
			LeftShoulder = ra(right and -30 or -70, 0, 18),
			Neck = ra(4, right and 14 or -14, 0),
			RightHip = ra(0, 0, -6),
		}, style = BACK },
		{ t = 0.11, pose = {
			Waist = po(0, 0, 0, 8, right and -30 or 30, 0),
			RightShoulder = ra(-96, 0, -20),
			LeftShoulder = ra(-96, 0, 20),
			Neck = ra(8, right and -12 or 12, 0),
		}, style = QUINT },
	})
end

function Anims.zoroSlash(character, windup)
	playSequence(character, {
		-- Draw the blades back into a wide stance.
		{ t = (windup or 0.3) * 0.6, pose = {
			Waist = po(0, 0, 0, -6, 50, 0),
			RightShoulder = ra(30, 0, -60),
			LeftShoulder = ra(-40, 0, 60),
			Neck = ra(0, 30, 0),
			RightHip = ra(0, 20, 0),
		}, style = SINE },
		-- Cross-slash through.
		{ t = 0.09, pose = {
			Waist = po(0, 0, 0, 10, -50, 0),
			RightShoulder = ra(-70, 0, 40),
			LeftShoulder = ra(-70, 0, -40),
			Neck = ra(6, -20, 0),
		}, style = BACK },
		{ t = 0.16, pose = { Waist = po(0, 0, 0, 6, -10, 0) }, style = QUINT },
	})
end

function Anims.zoroSpin(character, dur)
	-- Rapid full torso spin with arms flared out (Ul-Tora / Tatsumaki).
	local frames = {}
	local turns = math.max(2, math.floor((dur or 0.8) / 0.12))
	for i = 1, turns do
		table.insert(frames, {
			t = 0.12,
			pose = {
				Waist = ra(0, (i % 2 == 0) and 120 or -120, 0),
				RightShoulder = ra(-90, 0, 60),
				LeftShoulder = ra(-90, 0, -60),
				Neck = ra(8, 0, 0),
			},
			style = Enum.EasingStyle.Linear,
		})
	end
	playSequence(character, frames)
end

-- ---- Sanji: acrobatic one-legged spins + high kicks ---------------------
function Anims.sanjiM1(character, index)
	local right = index % 2 == 1
	playSequence(character, {
		{ t = 0.05, pose = {
			Waist = po(0, 0, 0, 8, right and -18 or 18, 0),
			[right and "RightHip" or "LeftHip"] = ra(-70, 0, right and -20 or 20),
			[right and "RightKnee" or "LeftKnee"] = ra(70),
			Neck = ra(6, 0, 0),
			RightShoulder = ra(0, 0, -30),
			LeftShoulder = ra(0, 0, 30),
		}, style = BACK },
		{ t = 0.1, pose = {
			[right and "RightHip" or "LeftHip"] = ra(-20, 0, 0),
			[right and "RightKnee" or "LeftKnee"] = ra(0),
			Waist = po(0, 0, 0, 4, 0, 0),
		}, style = QUINT },
	})
end

function Anims.sanjiHighKick(character, windup)
	playSequence(character, {
		-- Coil down onto one leg.
		{ t = (windup or 0.25) * 0.7, pose = {
			Waist = po(0, -0.3, 0, 14, 0, 0),
			RightHip = ra(30),
			RightKnee = ra(60),
			LeftHip = ra(-10),
			Neck = ra(-8, 0, 0),
			RightShoulder = ra(0, 0, -40),
			LeftShoulder = ra(0, 0, 40),
		}, style = SINE },
		-- Explode into a vertical axe kick.
		{ t = 0.09, pose = {
			Waist = po(0, 0.2, 0, -18, 0, 0),
			RightHip = ra(-130),
			RightKnee = ra(0),
			Neck = ra(10, 0, 0),
		}, style = BACK },
		{ t = 0.18, pose = { RightHip = ra(-40), Waist = po(0, 0, 0, -4, 0, 0) }, style = QUINT },
	})
end

function Anims.sanjiSpinKick(character, dur)
	local frames = {}
	local turns = math.max(2, math.floor((dur or 0.8) / 0.13))
	for i = 1, turns do
		table.insert(frames, {
			t = 0.13,
			pose = {
				Waist = ra(0, (i % 2 == 0) and 140 or -140, 0),
				RightHip = ra(-100, 0, -30),
				RightKnee = ra(10),
				LeftHip = ra(20),
				RightShoulder = ra(0, 0, -70),
				LeftShoulder = ra(0, 0, 70),
			},
			style = Enum.EasingStyle.Linear,
		})
	end
	playSequence(character, frames)
end

-- ---- Ace: caster gestures, finger-guns, arms-crossed flair --------------
function Anims.aceM1(character, index)
	local right = index % 2 == 1
	playSequence(character, {
		{ t = 0.05, pose = {
			[right and "RightShoulder" or "LeftShoulder"] = ra(-60, 0, right and -10 or 10),
			[right and "RightElbow" or "LeftElbow"] = ra(-50),
			Waist = po(0, 0, 0, 4, right and -14 or 14, 0),
		}, style = BACK },
		{ t = 0.1, pose = {
			[right and "RightShoulder" or "LeftShoulder"] = ra(-100),
			[right and "RightElbow" or "LeftElbow"] = ra(0),
			Waist = po(0, 0, 0, 8, 0, 0),
		}, style = QUINT },
	})
end

function Anims.aceCast(character, windup)
	playSequence(character, {
		-- Wind the fist back low, gathering flame.
		{ t = (windup or 0.4) * 0.6, pose = {
			Waist = po(0, -0.1, -0.3, -8, 30, 0),
			RightShoulder = ra(40, 0, -50),
			RightElbow = ra(-90),
			Neck = ra(-6, 24, 0),
			RightHip = ra(-8),
		}, style = SINE },
		-- Thrust the palm forward.
		{ t = 0.08, pose = {
			Waist = po(0, 0, 0.2, 16, -14, 0),
			RightShoulder = ra(-96, 0, 2),
			RightElbow = ra(0),
			Neck = ra(10, -8, 0),
		}, style = BACK },
		{ t = 0.18, pose = { Waist = po(0, 0, 0, 8, 0, 0), RightShoulder = ra(-86) }, style = QUINT },
	})
end

function Anims.aceFingerGun(character, count)
	-- Rapid alternating finger-gun jabs for the bullet barrage.
	local frames = {}
	for i = 1, math.max(3, count or 6) do
		local right = i % 2 == 1
		table.insert(frames, {
			t = 0.08,
			pose = {
				[right and "RightShoulder" or "LeftShoulder"] = ra(-92, 0, right and 4 or -4),
				[right and "RightElbow" or "LeftElbow"] = ra(-6),
				Waist = po(0, 0, 0, 4, right and -8 or 8, 0),
			},
			style = BACK,
		})
	end
	playSequence(character, frames)
end

-- ---- Tung: over-the-top goofy bat swings + royal king struts ------------
function Anims.tungM1(character, index)
	local right = index % 2 == 1
	playSequence(character, {
		-- Cartoonishly wind the bat way overhead.
		{ t = 0.06, pose = {
			Waist = po(0, 0.2, 0, -12, right and -40 or 40, 0),
			RightShoulder = ra(-170, 0, right and -30 or 30),
			LeftShoulder = ra(-150, 0, right and -30 or 30),
			Neck = ra(-10, 0, 0),
			RightHip = ra(-8),
		}, style = BACK },
		-- SMASH down with the whole body.
		{ t = 0.09, pose = {
			Waist = po(0, -0.3, 0.3, 30, right and 30 or -30, 0),
			RightShoulder = ra(-40),
			LeftShoulder = ra(-30),
			Neck = ra(16, 0, 0),
			RightKnee = ra(30),
			LeftKnee = ra(30),
		}, style = BACK },
		{ t = 0.16, pose = { Waist = po(0, 0, 0, 8, 0, 0) }, style = QUINT },
	})
end

function Anims.tungSmash(character, windup, big)
	local raise = big and 200 or 175
	playSequence(character, {
		-- Huge overhead bat raise, lean way back, tiny goofy hop.
		{ t = (windup or 0.4) * 0.65, pose = {
			Waist = po(0, 0.3, -0.4, -28, 0, 0),
			RightShoulder = ra(-raise, 0, -24),
			LeftShoulder = ra(-raise, 0, 24),
			Neck = ra(-18, 0, 0),
			RightHip = ra(-12),
			LeftHip = ra(-12),
			RightKnee = ra(20),
			LeftKnee = ra(20),
		}, style = BACK },
		-- Earth-shattering slam.
		{ t = 0.1, pose = {
			Waist = po(0, -0.5, 0.5, 40, 0, 0),
			RightShoulder = ra(-30),
			LeftShoulder = ra(-30),
			Neck = ra(24, 0, 0),
			RightKnee = ra(50),
			LeftKnee = ra(50),
		}, style = BACK },
		{ t = 0.2, pose = { Waist = po(0, 0, 0, 10, 0, 0), RightKnee = ra(10), LeftKnee = ra(10) }, style = QUINT },
	})
end

-- The King's royal strut on ult activation: chest out, chin up, arms wide.
function Anims.tungKingPose(character)
	playSequence(character, {
		{ t = 0.25, pose = {
			Waist = po(0, 0.3, 0, -16, 0, 0),
			Neck = ra(-20, 0, 0),
			RightShoulder = ra(0, 0, -80),
			LeftShoulder = ra(0, 0, 80),
			RightElbow = ra(-30),
			LeftElbow = ra(-30),
		}, style = BACK },
		{ t = 0.4, pose = {
			Waist = po(0, 0.2, 0, -10, 8, 0),
			Neck = ra(-14, 6, 0),
			RightShoulder = ra(0, 0, -55),
			LeftShoulder = ra(0, 0, 55),
		}, style = SINE },
		{ t = 0.5, pose = {
			Waist = po(0, 0.25, 0, -12, -8, 0),
			Neck = ra(-16, -6, 0),
		}, style = SINE },
	}, true)
end

-- A generic triumphant "ult power-up" flex used by the anime transformations.
function Anims.ultFlex(character)
	playSequence(character, {
		{ t = 0.12, pose = {
			Waist = po(0, -0.4, 0, 20, 0, 0),
			RightShoulder = ra(30, 0, -70),
			LeftShoulder = ra(30, 0, 70),
			RightElbow = ra(-90),
			LeftElbow = ra(-90),
			Neck = ra(20, 0, 0),
			RightHip = ra(20),
			LeftHip = ra(20),
			RightKnee = ra(40),
			LeftKnee = ra(40),
		}, style = BACK },
		{ t = 0.5, pose = {
			Waist = po(0, 0.2, 0, -18, 0, 0),
			RightShoulder = ra(-20, 0, -60),
			LeftShoulder = ra(-20, 0, 60),
			RightElbow = ra(-40),
			LeftElbow = ra(-40),
			Neck = ra(-16, 0, 0),
			RightKnee = ra(0),
			LeftKnee = ra(0),
		}, style = BACK },
	})
end

-- ========================================================================
-- The signature rubber arm
-- ========================================================================

-- A stretching rubber arm from the character's hand reaching `range` studs
-- along its look vector. Returns nothing; self-cleans.
local function rubberArm(character, side, range, thickness, color, haki, outTime, hold)
	local hand = handPart(character, side)
	local r = root(character)
	if not hand or not r then
		return
	end
	local origin = CFrame.new(hand.Position) * (r.CFrame - r.CFrame.Position)
	local armColor = haki and HAKI or color

	local arm = makePart({
		Size = Vector3.new(thickness, thickness, 2),
		CFrame = origin * CFrame.new(0, 0, -1),
		Color = armColor,
		Material = haki and Enum.Material.Glass or Enum.Material.SmoothPlastic,
		Reflectance = haki and 0.35 or 0,
		Transparency = 0,
	})
	local fist = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(thickness * 1.9, thickness * 1.9, thickness * 1.9),
		CFrame = origin * CFrame.new(0, 0, -2),
		Color = armColor,
		Material = haki and Enum.Material.Glass or Enum.Material.SmoothPlastic,
		Reflectance = haki and 0.35 or 0,
	})
	addTrail(fist, haki and HAKI_EDGE or color, 0.2, thickness)

	if haki then
		-- Conqueror lightning crackling along the arm.
		local bolt = makePart({
			Size = Vector3.new(thickness * 1.3, thickness * 1.3, 2),
			CFrame = arm.CFrame,
			Color = HAKI_EDGE,
			Transparency = 0.4,
		})
		tween(bolt, outTime + 0.15, {
			Size = Vector3.new(thickness * 1.3, thickness * 1.3, range),
			CFrame = origin * CFrame.new(0, 0, -range / 2),
			Transparency = 1,
		}, Enum.EasingStyle.Back)
		Debris:AddItem(bolt, outTime + 0.3)
	end

	tween(arm, outTime, {
		Size = Vector3.new(thickness, thickness, range),
		CFrame = origin * CFrame.new(0, 0, -range / 2),
	}, Enum.EasingStyle.Back)
	tween(fist, outTime, { CFrame = origin * CFrame.new(0, 0, -range) }, Enum.EasingStyle.Back)

	task.delay(outTime + (hold or 0.05), function()
		tween(arm, 0.14, {
			Size = Vector3.new(thickness, thickness, 2),
			CFrame = origin * CFrame.new(0, 0, -1),
			Transparency = 1,
		})
		tween(fist, 0.14, { CFrame = origin * CFrame.new(0, 0, -2), Transparency = 1 })
	end)
	Debris:AddItem(arm, outTime + 0.5)
	Debris:AddItem(fist, outTime + 0.5)
	return origin
end

-- A barrage of rubber fists inside a cone in front of the character.
local function fistFlurry(character, duration, range, color, haki, size, perSecond)
	task.spawn(function()
		local elapsed = 0
		local side = "Right"
		while elapsed < duration do
			local r = root(character)
			if not r then
				break
			end
			punchArm(character, side, 0.05, 0.02, 0.8)
			side = side == "Right" and "Left" or "Right"

			local origin = r.CFrame
			local dist = math.random(4, math.max(5, math.floor(range)))
			local fist = makePart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				Color = haki and HAKI or color,
				Material = haki and Enum.Material.Glass or Enum.Material.Neon,
				Reflectance = haki and 0.3 or 0,
				Transparency = 0.05,
				CFrame = origin * CFrame.new((math.random() - 0.5) * 7, (math.random() - 0.5) * 5, -1),
			})
			addTrail(fist, haki and HAKI_EDGE or color, 0.12, size * 0.5)
			tween(fist, 0.1, {
				CFrame = origin * CFrame.new((math.random() - 0.5) * 6, (math.random() - 0.5) * 4, -dist),
				Transparency = 1,
			}, Enum.EasingStyle.Quint)
			Debris:AddItem(fist, 0.16)
			playSound(Config.Sounds.Punch, fist, 0.35, 0.9 + math.random() * 0.4)
			elapsed += task.wait(1 / perSecond)
		end
	end)
end

-- ========================================================================
-- Sword primitives (Zoro)
-- ========================================================================

-- The core of a REAL slash: a thin part with a Trail is swept along a
-- circular arc, so the Trail paints a curved crescent (not a straight line).
-- The part rotates about `rotAxis`; the trail's two attachments sit along
-- `radialAxis` at inner/outer radius, so the ribbon spans the blade length.
local function arcSweep(character, o)
	local r = root(character)
	if not r then
		return nil
	end
	local pivot = r.CFrame * (o.pivot or CFrame.new(0, 1.4, -1.5))
	local inner = o.inner or 0.6
	local outer = o.outer or 6
	local fromA = math.rad(o.from or 70)
	local toA = math.rad(o.to or -70)
	local dur = o.duration or 0.16
	local color = o.color or Color3.new(1, 1, 1)
	local rotAxis = (o.rotAxis or Vector3.new(0, 0, 1))
	local radialAxis = (o.radialAxis or Vector3.new(0, 1, 0))

	local mover = makePart({
		Size = Vector3.new(0.15, 0.15, 0.15),
		Transparency = 1,
		CFrame = pivot * CFrame.fromAxisAngle(rotAxis, fromA),
	})
	local a0 = attachment(mover, radialAxis * inner)
	local a1 = attachment(mover, radialAxis * outer)
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	trail.Lifetime = math.max(0.12, dur * 1.1)
	trail.LightEmission = 1
	trail.FaceCamera = false
	trail.MaxLength = 0
	trail.Parent = mover

	task.spawn(function()
		local t = 0
		while t < dur and mover.Parent do
			local dt = RunService.RenderStepped:Wait()
			t += dt
			local frac = math.min(1, t / dur)
			-- ease-out so the blade whips fast then slows (anime timing)
			local eased = 1 - (1 - frac) * (1 - frac)
			local ang = fromA + (toA - fromA) * eased
			mover.CFrame = pivot * CFrame.fromAxisAngle(rotAxis, ang)
		end
		trail.Enabled = false
	end)
	Debris:AddItem(mover, dur + trail.Lifetime + 0.1)
	return (pivot * CFrame.new(radialAxis * outer)).Position
end

-- A forward slash arc. `angleDeg` orients the cut (0 = horizontal-ish, 90 =
-- vertical); it sweeps a curved crescent in the plane facing forward.
local function slash(character, angleDeg, length, color, forward, life)
	local r = root(character)
	if not r then
		return nil
	end
	forward = forward or 5
	angleDeg = angleDeg or 0
	arcSweep(character, {
		pivot = CFrame.new(0, 1.4, -forward * 0.45),
		from = angleDeg + 60,
		to = angleDeg - 70,
		inner = 0.7,
		outer = length,
		rotAxis = Vector3.new(0, 0, 1),
		radialAxis = Vector3.new(0, 1, 0),
		color = color,
		duration = life or 0.16,
	})
	return (r.CFrame * CFrame.new(0, 1.4, -forward)).Position
end

-- A horizontal curved sweep around the character (spins / round kicks).
local function arcSlash(character, startAngle, radius, color)
	arcSweep(character, {
		pivot = CFrame.new(0, 1, 0),
		from = startAngle - 55,
		to = startAngle + 55,
		inner = 1,
		outer = radius,
		rotAxis = Vector3.new(0, 1, 0),
		radialAxis = Vector3.new(0, 0, -1),
		color = color,
		duration = 0.2,
	})
end

-- Attach a temporary edge-trail to a real welded weapon part (sword blade,
-- bat barrel) so the physical weapon streaks as it swings.
local function weaponEdgeTrail(character, folderName, partName, color, dur)
	local folder = character:FindFirstChild(folderName)
	if not folder then
		return
	end
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") and part.Name == partName then
			local a0 = attachment(part, Vector3.new(0, part.Size.Y / 2, 0))
			local a1 = attachment(part, Vector3.new(0, -part.Size.Y / 2, 0))
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(color)
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			})
			trail.Lifetime = 0.22
			trail.LightEmission = 0.9
			trail.Parent = part
			task.delay(dur or 0.3, function()
				trail.Enabled = false
				Debris:AddItem(trail, 0.4)
				Debris:AddItem(a0, 0.4)
				Debris:AddItem(a1, 0.4)
			end)
		end
	end
end

-- Attach a temporary trail to a real limb (a foot, for kicks) so the kick
-- follows the actual leg like Luffy's arm follows his hand.
local function limbTrail(character, partNames, color, dur)
	local part = getPart(character, partNames)
	if not part then
		return
	end
	local a0 = attachment(part, Vector3.new(0, part.Size.Y / 2, 0))
	local a1 = attachment(part, Vector3.new(0, -part.Size.Y / 2, 0))
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.2
	trail.LightEmission = 0.7
	trail.Parent = part
	task.delay(dur or 0.3, function()
		trail.Enabled = false
		Debris:AddItem(trail, 0.35)
		Debris:AddItem(a0, 0.35)
		Debris:AddItem(a1, 0.35)
	end)
end

-- Convenience wrappers so each fighter's swing shows the real weapon/limb.
local function swordSwing(character, angleDeg, length, color, forward, life)
	slash(character, angleDeg, length, color, forward, life)
	weaponEdgeTrail(character, "Santoryu", "Blade", color, (life or 0.16) + 0.12)
end

local function batSwing(character, angleDeg, length, color, forward, life)
	slash(character, angleDeg, length, color, forward, life)
	weaponEdgeTrail(character, "BrainrotBat", "Barrel", color, (life or 0.16) + 0.14)
end

local function kickSwing(character, side, angleDeg, length, color, forward, life)
	slash(character, angleDeg, length, color, forward, life)
	limbTrail(character, { side .. "Foot", side .. "LowerLeg", side .. " Leg" }, color, (life or 0.16) + 0.14)
end

-- A swirling tornado column of blade shards + rising particles.
local function tornado(character, duration, radius, height, color)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local r = root(character)
			if not r then
				break
			end
			for _ = 1, 2 do
				local a = math.rad(math.random(0, 359))
				local h = math.random() * height
				local rad = radius * (0.35 + (h / height) * 0.75)
				local shard = makePart({
					Size = Vector3.new(0.35, 3, 0.35),
					CFrame = r.CFrame * CFrame.new(math.cos(a) * rad, h, math.sin(a) * rad) * CFrame.Angles(0, a, math.rad(24)),
					Color = color,
					Transparency = 0.15,
				})
				tween(shard, 0.28, { Transparency = 1 })
				Debris:AddItem(shard, 0.32)
			end
			elapsed += task.wait(0.02)
		end
	end)
	local r = root(character)
	if r then
		dust(r.Position, color, 12)
		shake(r.Position, 0.5, duration)
	end
end

-- Nine phantom blades fanned out in front (Ashura signature).
local function nineBladeFan(character, length, color, life)
	local r = root(character)
	if not r then
		return
	end
	for i = -4, 4 do
		local blade = makePart({
			Size = Vector3.new(0.28, length, 0.9),
			CFrame = r.CFrame * CFrame.new(i * 1.6, 1.5, -5) * CFrame.Angles(0, 0, math.rad(i * 9)),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
		})
		addTrail(blade, color, 0.18, length * 0.4)
		tween(blade, life or 0.3, {
			CFrame = r.CFrame * CFrame.new(i * 2.2, 1.5, -(5 + length)) * CFrame.Angles(0, 0, math.rad(i * 9)),
			Transparency = 1,
		}, Enum.EasingStyle.Quint)
		Debris:AddItem(blade, (life or 0.3) + 0.1)
	end
end

-- ========================================================================
-- Kick + fire primitives (Sanji)
-- ========================================================================

local legMotorCache = setmetatable({}, { __mode = "k" })

local function getHip(character, side)
	if not character then
		return nil
	end
	local cache = legMotorCache[character]
	if cache and cache[side] and cache[side].Parent then
		return cache[side]
	end
	if not cache then
		cache = {}
		legMotorCache[character] = cache
	end
	for _, name in { side .. "Hip", side .. " Hip" } do
		for _, d in character:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == name then
				cache[side] = d
				return d
			end
		end
	end
	return nil
end

-- Swing a leg forward/up (kick), layered over the idle like punchArm.
local function kickLeg(character, side, outTime, hold, power)
	local motor = getHip(character, side)
	if not motor then
		return
	end
	power = power or 1
	local base = restPose(motor)
	local posed = base * CFrame.Angles(math.rad(72 * power), 0, 0)
	tween(motor, outTime or 0.07, { C0 = posed }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay((outTime or 0.07) + (hold or 0.05), function()
		if motor.Parent then
			tween(motor, 0.2, { C0 = base }, Enum.EasingStyle.Quad)
		end
	end)
end

-- Fiery impact (orange variant of impact + short-lived flames).
local function flameImpact(position, scale, heavy)
	impact(position, {
		Color = FIRE_YELLOW,
		Scale = scale,
		Heavy = heavy,
		DustColor = Color3.fromRGB(60, 40, 30),
		CrackColor = Color3.fromRGB(60, 30, 20),
	})
	sparks(position, FIRE_ORANGE, math.floor(16 * (scale or 1)), 26 * (scale or 1), 1.4 * (scale or 1))
	local holder = makePart({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Transparency = 1 })
	local fire = Instance.new("Fire")
	fire.Size = 10 * (scale or 1)
	fire.Heat = 12
	fire.Color = FIRE_ORANGE
	fire.SecondaryColor = FIRE_DEEP
	fire.Parent = holder
	task.delay(0.15, function()
		fire.Enabled = false
	end)
	Debris:AddItem(holder, 1)
end

-- Trailing flame streak (fire-colored slash used for Diable kicks).
local function flameArc(character, angleDeg, length, forward)
	slash(character, angleDeg, length, FIRE_YELLOW, forward, 0.16)
	local r = root(character)
	if r then
		sparks(r.Position + r.CFrame.LookVector * (forward or 5) + Vector3.new(0, 1, 0), FIRE_ORANGE, 6, 16, 1)
	end
end

-- ========================================================================
-- Effect handlers
-- ========================================================================

local Effects = {}

function Effects.HitImpact(data)
	impact(data.Position, {
		Color = data.Heavy and GEAR5 or IMPACT_YELLOW,
		Scale = data.Heavy and 1.4 or 0.8,
		Heavy = data.Heavy,
	})
	playSound(data.Heavy and Config.Sounds.HeavyImpact or Config.Sounds.Punch, workspace, data.Heavy and 1 or 0.6)
end

function Effects.M1Swing(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	Anims.luffyM1(data.Character, data.Index)
	rubberArm(data.Character, side, Config.M1.Range, 0.9, RUBBER, data.Index >= Config.M1.ComboHits, 0.07)
	if isLocal(data.Character) then
		fovPunch(root(data.Character) and root(data.Character).Position or Vector3.zero, 2, 0.15)
	end
end

function Effects.Pistol(data)
	local character = data.Character
	local cfg = Config.Base[1]
	local r = root(character)
	if not r then
		return
	end
	playSound(Config.Sounds.Stretch, r, 1)

	-- Wind-up: draw the whole body back with a charge aura, then whip forward.
	Anims.luffyWindup(character, cfg.WindUp)
	chargeAura(function()
		local hand = handPart(character, "Right")
		return hand and hand.Position
	end, cfg.WindUp, RUBBER)

	task.delay(cfg.WindUp - 0.05, function()
		if not root(character) then
			return
		end
		local origin = rubberArm(character, "Right", data.Range, 1.5, RUBBER, false, 0.1, 0.14)
		if origin then
			impact(origin.Position + origin.LookVector * data.Range, { Color = RUBBER, Scale = 1.1, Heavy = true, CrackColor = Color3.fromRGB(90, 70, 55) })
		end
		shake(r.Position, 0.5, 0.2)
	end)
end

function Effects.Bazooka(data)
	local character = data.Character
	local cfg = Config.Base[2]
	local r = root(character)
	if not r then
		return
	end

	Anims.luffyBazooka(character, cfg.WindUp)
	chargeAura(function()
		return r.Position + r.CFrame.LookVector * 2
	end, cfg.WindUp, RUBBER)

	task.delay(cfg.WindUp - 0.05, function()
		if not root(character) then
			return
		end
		rubberArm(character, "Right", cfg.Range, 1.7, RUBBER, false, 0.09, 0.16)
		rubberArm(character, "Left", cfg.Range, 1.7, RUBBER, false, 0.09, 0.16)
		local hitPos = r.Position + r.CFrame.LookVector * cfg.Range
		impact(hitPos, { Color = GEAR5, Scale = 1.6, Heavy = true, CrackColor = Color3.fromRGB(90, 70, 55) })
		groundDisc(r.Position, 34, RUBBER, 0.45)
	end)
end

function Effects.Gatling(data)
	fistFlurry(data.Character, (data.Duration or 1.6) + 0.3, data.Range or 15, RUBBER, false, 1.8, 20)
	speedLines(data.Character, (data.Duration or 1.6) + 0.3, RUBBER)
	local r = root(data.Character)
	if r then
		shake(r.Position, 0.4, data.Duration or 1.6)
	end
end

function Effects.DawnGatling(data)
	fistFlurry(data.Character, (data.Duration or 1.6) + 0.3, data.Range or 22, GEAR5, false, 2.6, 34)
	speedLines(data.Character, (data.Duration or 1.6) + 0.3, GEAR5)
	local r = root(data.Character)
	if r then
		-- The many-arms illusion: extra wide rubber arms firing outward.
		task.spawn(function()
			local elapsed = 0
			while elapsed < (data.Duration or 1.6) do
				rubberArm(data.Character, math.random() < 0.5 and "Right" or "Left", data.Range or 22, 1.4, GEAR5, false, 0.12, 0.02)
				elapsed += task.wait(0.09)
			end
		end)
		shake(r.Position, 0.6, data.Duration or 1.6)
		fovPunch(r.Position, 3, 0.4)
	end
end

function Effects.RubberCombo(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		rubberArm(character, "Right", Config.Base[4].Range, 1, RUBBER, false, 0.1)
		return
	end
	afterImage(character, RUBBER, 0.4)
	groundDisc(r.Position, 12, RUBBER, 0.3)
	fistFlurry(character, data.Duration or 1.3, 6, RUBBER, false, 1.5, 16)
	speedLines(character, data.Duration or 1.3, RUBBER)
end

function Effects.ToonForce(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		rubberArm(character, "Right", Config.Gear5[3].Range, 1.3, GEAR5, false, 0.1)
		return
	end
	afterImage(character, TOON, 0.5)
	groundDisc(r.Position, 16, TOON, 0.35)
	-- Cartoon-bright barrage with pink pops.
	fistFlurry(character, data.Duration or 1.6, 7, GEAR5, false, 1.8, 20)
	speedLines(character, data.Duration or 1.6, TOON)
	task.spawn(function()
		local elapsed = 0
		while elapsed < (data.Duration or 1.6) do
			local rr = root(character)
			if rr then
				sparks(rr.Position + rr.CFrame.LookVector * math.random(3, 8) + Vector3.new(0, math.random(-2, 3), 0), TOON, 6, 14, 1.4)
			end
			elapsed += task.wait(0.12)
		end
	end)
end

function Effects.BajrangGun(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	playSound(Config.Sounds.DrumsOfLiberation, r, 1)
	local windUp = data.WindUp or 1.2
	local range = data.Range or 70
	local fistSize = 34

	-- Wind-up: raise both arms overhead, giant fist inflates behind Luffy
	-- as clouds/energy pour in.
	punchArm(character, "Right", windUp * 0.5, windUp * 0.5, -0.7)
	punchArm(character, "Left", windUp * 0.5, windUp * 0.5, -0.7)

	local fist = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		CFrame = r.CFrame * CFrame.new(0, 16, 24),
		Color = GEAR5,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.05,
	})
	addTrail(fist, GEAR5_RIM, 0.4, fistSize * 0.4)
	local knuckles = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		CFrame = fist.CFrame,
		Color = GEAR5_RIM,
		Transparency = 0.6,
	})
	tween(fist, windUp, { Size = Vector3.new(fistSize, fistSize, fistSize) }, Enum.EasingStyle.Sine)
	tween(knuckles, windUp, { Size = Vector3.new(fistSize * 1.15, fistSize * 1.15, fistSize * 1.15), Transparency = 0.85 }, Enum.EasingStyle.Sine)
	chargeAura(function()
		return fist.Position
	end, windUp, GEAR5)
	shake(r.Position, 0.3, windUp)

	task.delay(windUp, function()
		local rNow = root(character)
		local launch = rNow and rNow.CFrame or r.CFrame
		pushBothArms(character, 0.1, 0.4)
		fist.CFrame = launch * CFrame.new(0, 8, 8)
		knuckles.CFrame = fist.CFrame
		tween(fist, 0.3, { CFrame = launch * CFrame.new(0, 6, -range) }, Enum.EasingStyle.Quart)
		tween(knuckles, 0.3, { CFrame = launch * CFrame.new(0, 6, -range) }, Enum.EasingStyle.Quart)
		shake(launch.Position, 2.2, 0.6)
		fovPunch(launch.Position, 10, 0.5)

		task.delay(0.3, function()
			local hitPos = fist.Position
			impact(hitPos, { Color = GEAR5, Scale = 3, Heavy = true, CrackColor = Color3.fromRGB(90, 70, 55) })
			shockwave(hitPos, 120, GEAR5, 0.8, 2)
			shockwave(hitPos, 80, GEAR5_RIM, 0.6, 1.4)
			sparks(hitPos, GEAR5, 80, 60, 3)
			debris(hitPos, Color3.fromRGB(80, 72, 66), 16)
			screenFlash(GEAR5, 0.4, 0.3)
			tween(fist, 0.4, { Transparency = 1, Size = Vector3.new(fistSize * 1.4, fistSize * 1.4, fistSize * 1.4) })
			tween(knuckles, 0.4, { Transparency = 1 })
		end)
	end)
	Debris:AddItem(fist, windUp + 1.6)
	Debris:AddItem(knuckles, windUp + 1.6)
end

function Effects.DrumsChannel(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	playSound(Config.Sounds.DrumsOfLiberation, r, 2)
	task.spawn(function()
		local beats = math.floor((data.Duration or 2.2) / 0.55)
		for _ = 1, beats do
			local rNow = root(character)
			if not rNow then
				break
			end
			-- Beat the chest: alternate arm slaps + a heartbeat ring.
			punchArm(character, "Right", 0.08, 0.05, 0.5)
			punchArm(character, "Left", 0.08, 0.05, 0.5)
			shockwave(rNow.Position, 20, GEAR5, 0.5, 1)
			groundDisc(rNow.Position, 18, GEAR5_RIM, 0.4)
			shake(rNow.Position, 0.45, 0.2)
			fovPunch(rNow.Position, 2, 0.2)
			task.wait(0.55)
		end
	end)
end

function Effects.Devour(data)
	local character = data.Character
	local targetRoot = root(data.Target)
	local r = root(character)
	if not r or not targetRoot then
		return
	end
	local mouthPos = targetRoot.Position

	local head = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(r.Position + Vector3.new(0, 2, 0)),
		Color = RUBBER,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.05,
	})
	local jaw = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		CFrame = head.CFrame,
		Color = Color3.fromRGB(120, 40, 40),
		Transparency = 0.2,
	})
	tween(head, 0.35, { Size = Vector3.new(24, 24, 24), CFrame = CFrame.new(mouthPos) }, Enum.EasingStyle.Back)
	tween(jaw, 0.35, { Size = Vector3.new(20, 10, 20), CFrame = CFrame.new(mouthPos + Vector3.new(0, -6, 0)) }, Enum.EasingStyle.Back)

	task.delay(0.45, function()
		playSound(Config.Sounds.Gulp, head, 2)
		impact(mouthPos, { Color = GEAR5, Scale = 2.4, Heavy = true })
		shockwave(mouthPos, 46, RUBBER, 0.5, 1.5)
		screenFlash(RUBBER, 0.3, 0.25)
		tween(head, 0.25, { Size = Vector3.new(1, 1, 1), Transparency = 1 })
		tween(jaw, 0.25, { Transparency = 1 })
	end)
	Debris:AddItem(head, 1.2)
	Debris:AddItem(jaw, 1.2)
end

function Effects.DevourWhiff(data)
	local r = root(data.Character)
	if r then
		shockwave(r.Position + r.CFrame.LookVector * 5, 12, RUBBER, 0.3, 0.6)
	end
end

function Effects.Dash(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	afterImage(character, GEAR5, 0.3)
	local direction = data.Direction or r.CFrame.LookVector
	local streak = makePart({
		Size = Vector3.new(1.5, 1.5, 9),
		CFrame = CFrame.lookAt(r.Position - direction * 4, r.Position - direction * 12),
		Color = Color3.new(1, 1, 1),
		Transparency = 0.35,
	})
	tween(streak, 0.25, { Size = Vector3.new(0.2, 0.2, 16), Transparency = 1 })
	Debris:AddItem(streak, 0.3)
	dust(r.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(150, 140, 130), 8)
end

function Effects.Gear5Start(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	playSound(Config.Sounds.Gear5Activate, r, 2)
	Anims.ultFlex(character)

	-- Giant liberation shockwaves + pillar of light.
	shockwave(r.Position, 70, GEAR5, 0.9, 2)
	shockwave(r.Position, 45, GEAR5_RIM, 0.7, 1.4)
	groundDisc(r.Position, 60, GEAR5, 0.7)
	sparks(r.Position, GEAR5, 70, 55, 2.5)
	shake(r.Position, 1.4, 0.6)
	fovPunch(r.Position, 12, 0.6)
	if isLocal(character) then
		screenFlash(GEAR5, 0.6, 0.5)
	end

	local pillar = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 1, 1),
		CFrame = CFrame.new(r.Position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GEAR5,
		Transparency = 0.2,
	})
	tween(pillar, 0.5, { Size = Vector3.new(200, 12, 12), Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(pillar, 0.6)

	-- Persistent white steam-clouds + rim glow while Gear 5 lasts.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(GEAR5)
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.45, 1)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Rate = 30
	emitter.Speed = NumberRange.new(3, 7)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = r
	gear5Emitters[character] = emitter

	local highlight = character:FindFirstChild("Gear5Highlight")
	if highlight and highlight:IsA("Highlight") then
		-- server already added one; add a subtle pulse.
		task.spawn(function()
			while highlight.Parent and character:GetAttribute("Gear5") do
				tween(highlight, 0.6, { FillTransparency = 0.2 })
				task.wait(0.6)
				tween(highlight, 0.6, { FillTransparency = 0.45 })
				task.wait(0.6)
			end
		end)
	end
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
		shockwave(r.Position, 24, GEAR5, 0.5, 1)
		dust(r.Position, GEAR5, 12)
	end
end

function Effects.RubberizeStart(data)
	local character = data.Character
	if rubberHighlights[character] then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = TOON
	highlight.OutlineColor = TOON
	highlight.FillTransparency = 0.5
	highlight.Parent = character
	rubberHighlights[character] = highlight
	task.spawn(function()
		while rubberHighlights[character] == highlight and highlight.Parent do
			tween(highlight, 0.25, { FillTransparency = 0.2 })
			task.wait(0.25)
			tween(highlight, 0.25, { FillTransparency = 0.6 })
			task.wait(0.25)
		end
	end)
end

function Effects.RubberizeEnd(data)
	local highlight = rubberHighlights[data.Character]
	if highlight then
		highlight:Destroy()
		rubberHighlights[data.Character] = nil
	end
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
	sparks(data.Position, Color3.fromRGB(180, 210, 255), 12, 18, 1)
	shockwave(data.Position, 8, Color3.fromRGB(180, 210, 255), 0.25, 0.5)
	playSound(Config.Sounds.Punch, workspace, 0.5, 1.4)
end

function Effects.GuardBreak(data)
	impact(data.Position, { Color = Color3.fromRGB(255, 90, 90), Scale = 1.3, Heavy = true })
	playSound(Config.Sounds.HeavyImpact, workspace, 1.2)
end

-- ========================================================================
-- Zoro effect handlers
-- ========================================================================

function Effects.ZoroM1(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	Anims.zoroM1(data.Character, data.Index)
	swordSwing(data.Character, side == "Right" and -32 or 32, 6, SLASH, 5, 0.16)
	if isLocal(data.Character) then
		local r = root(data.Character)
		fovPunch(r and r.Position or Vector3.zero, 2, 0.14)
	end
end

function Effects.OniGiri(data)
	local character = data.Character
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		slash(character, -40, 7, SLASH, 5, 0.18)
		return
	end
	afterImage(character, SLASH, 0.4)
	-- Three-sword cross: two diagonals + a horizontal, staggered.
	swordSwing(character, -45, 8, SLASH, 4, 0.2)
	task.delay(0.05, function()
		swordSwing(character, 45, 8, SLASH, 4, 0.2)
	end)
	task.delay(0.1, function()
		swordSwing(character, 90, 8, BLADE, 4, 0.2)
	end)
	local r = root(character)
	if r then
		impact(r.Position + r.CFrame.LookVector * 5, { Color = SLASH, Scale = 1.1 })
	end
end

function Effects.ToraGari(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Base[2]
	local r = root(character)
	if not r then
		return
	end
	-- Raise the blades overhead, then a heavy vertical cleave.
	Anims.zoroSlash(character, cfg.WindUp)
	chargeAura(function()
		return r.Position + Vector3.new(0, 4, 0)
	end, cfg.WindUp, SLASH)
	task.delay(cfg.WindUp - 0.05, function()
		swordSwing(character, 8, 12, BLADE, 5, 0.22)
		swordSwing(character, -4, 11, SLASH, 5, 0.22)
		local hit = r.Position + r.CFrame.LookVector * 6
		impact(hit, { Color = SLASH, Scale = 1.5, Heavy = true, CrackColor = Color3.fromRGB(70, 74, 82) })
	end)
end

function Effects.UlToraGari(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Base[3]
	Anims.zoroSpin(character, cfg.WindUp + cfg.Hits * cfg.HitInterval)
	speedLines(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, SLASH)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 300, 60 do
				arcSlash(character, a + hit * 40, cfg.Radius, hit == cfg.Hits and BLADE or SLASH)
			end
			local r = root(character)
			if r then
				shake(r.Position, 0.3, 0.15)
			end
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.SwordCombo(data)
	local character = data.Character
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		slash(character, 30, 7, SLASH, 5, 0.16)
		return
	end
	afterImage(character, SLASH, 0.4)
	speedLines(character, data.Duration or 0.9, SLASH)
	weaponEdgeTrail(character, "Santoryu", "Blade", SLASH, (data.Duration or 0.9) + 0.2)
	task.spawn(function()
		local n = 6
		for i = 1, n do
			local side = i % 2 == 0 and 38 or -38
			Anims.zoroM1(character, i)
			slash(character, side, 6, i == n and BLADE or SLASH, 4.5, 0.14)
			task.wait(0.08)
		end
	end)
end

function Effects.Ichibugin(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Ult[1]
	local r = root(character)
	if not r then
		return
	end
	chargeAura(function()
		return r.Position + r.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
	end, cfg.WindUp, ASHURA_RED)
	pushBothArms(character, cfg.WindUp * 0.6, cfg.WindUp * 0.4)
	task.delay(cfg.WindUp - 0.05, function()
		nineBladeFan(character, cfg.Range * 0.5, ASHURA_RED, 0.35)
		slash(character, -20, cfg.Range * 0.45, BLADE, 6, 0.28)
		slash(character, 20, cfg.Range * 0.45, ASHURA_RED, 6, 0.28)
		local hit = r.Position + r.CFrame.LookVector * (cfg.Range * 0.55)
		impact(hit, { Color = ASHURA_RED, Scale = 2.4, Heavy = true, CrackColor = Color3.fromRGB(60, 20, 24) })
		shockwave(hit, 60, ASHURA_RED, 0.6, 1.6)
		screenFlash(ASHURA_RED, 0.3, 0.25)
		fovPunch(r.Position, 8, 0.4)
	end)
end

function Effects.Makyusen(data)
	local character = data.Character
	speedLines(character, data.Duration or 1.4, ASHURA_RED)
	task.spawn(function()
		local elapsed = 0
		local side = "Right"
		while elapsed < (data.Duration or 1.4) do
			punchArm(character, side, 0.05, 0.02, 0.9)
			slash(character, side == "Right" and -36 or 36, 7, math.random() < 0.5 and ASHURA_RED or BLADE, 5, 0.12)
			side = side == "Right" and "Left" or "Right"
			elapsed += task.wait(0.07)
		end
	end)
end

function Effects.Tatsumaki(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Ult[3]
	tornado(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, cfg.Radius, 22, SLASH)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 270, 90 do
				arcSlash(character, a + hit * 55, cfg.Radius, SLASH)
			end
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.KokujoOTatsumaki(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Ult[4]
	local r = root(character)
	if r then
		groundDisc(r.Position, cfg.Radius * 2, ASHURA_DARK, 0.6)
		screenFlash(ASHURA_DARK, 0.3, 0.3)
	end
	tornado(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, cfg.Radius, 40, ASHURA_DARK)
	tornado(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, cfg.Radius * 0.7, 40, ASHURA_RED)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 315, 45 do
				arcSlash(character, a + hit * 30, cfg.Radius, hit == cfg.Hits and BLADE or ASHURA_RED)
			end
			local rr = root(character)
			if rr then
				shake(rr.Position, 0.6, 0.18)
			end
			task.wait(cfg.HitInterval)
		end
		local rr = root(character)
		if rr then
			impact(rr.Position, { Color = ASHURA_RED, Scale = 2.6, Heavy = true })
		end
	end)
end

function Effects.AshuraStart(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	Anims.ultFlex(character)
	shockwave(r.Position, 55, ASHURA_RED, 0.8, 1.6)
	groundDisc(r.Position, 50, ASHURA_DARK, 0.7)
	sparks(r.Position, ASHURA_RED, 50, 45, 2)
	shake(r.Position, 1.2, 0.5)
	fovPunch(r.Position, 10, 0.5)
	if isLocal(character) then
		screenFlash(ASHURA_RED, 0.5, 0.5)
	end

	-- Dark aura + phantom blades orbiting while Ashura lasts.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(ASHURA_DARK)
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.35, 1)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Rate = 26
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = r
	gear5Emitters[character] = emitter

	ashuraAuras[character] = true
	task.spawn(function()
		local angle = 0
		while ashuraAuras[character] do
			local rNow = root(character)
			if not rNow then
				break
			end
			angle += 0.35
			for i = 0, 5 do
				local a = angle + i * (math.pi * 2 / 6)
				local blade = makePart({
					Size = Vector3.new(0.3, 4, 0.3),
					CFrame = rNow.CFrame * CFrame.new(math.cos(a) * 5, math.sin(a * 1.5) * 2, math.sin(a) * 5) * CFrame.Angles(math.rad(90), 0, 0),
					Color = i % 2 == 0 and ASHURA_RED or BLADE,
					Transparency = 0.35,
				})
				Debris:AddItem(blade, 0.12)
			end
			task.wait(0.06)
		end
	end)
end

function Effects.AshuraEnd(data)
	ashuraAuras[data.Character] = nil
	local emitter = gear5Emitters[data.Character]
	if emitter then
		emitter.Enabled = false
		Debris:AddItem(emitter, 1.5)
		gear5Emitters[data.Character] = nil
	end
	local r = root(data.Character)
	if r then
		shockwave(r.Position, 22, ASHURA_RED, 0.5, 1)
	end
end

-- ========================================================================
-- Sanji effect handlers
-- ========================================================================

function Effects.SanjiM1(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	Anims.sanjiM1(data.Character, data.Index)
	kickSwing(data.Character, side, side == "Right" and -20 or 20, 5.5, AIR, 5, 0.15)
	if isLocal(data.Character) then
		local r = root(data.Character)
		fovPunch(r and r.Position or Vector3.zero, 2, 0.13)
	end
end

function Effects.Collier(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Base[1]
	task.delay(cfg.WindUp - 0.05, function()
		kickLeg(character, "Right", 0.06, 0.12, 1.1)
		kickSwing(character, "Right", 90, 8, AIR, 5, 0.18) -- horizontal side kick
		local r = root(character)
		if r then
			impact(r.Position + r.CFrame.LookVector * 6, { Color = AIR, Scale = 1 })
		end
	end)
end

function Effects.Concasse(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Base[2]
	local r = root(character)
	if not r then
		return
	end
	Anims.sanjiHighKick(character, cfg.WindUp)
	afterImage(character, AIR, 0.3)
	task.delay(cfg.WindUp - 0.05, function()
		kickSwing(character, "Right", 4, 11, AIR, 5, 0.22) -- vertical axe kick
		local hit = r.Position + r.CFrame.LookVector * 6
		impact(hit, { Color = AIR, Scale = 1.4, Heavy = true, CrackColor = Color3.fromRGB(70, 74, 82) })
	end)
end

function Effects.PartyTable(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Base[3]
	Anims.sanjiSpinKick(character, cfg.WindUp + cfg.Hits * cfg.HitInterval)
	speedLines(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, AIR)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 270, 90 do
				arcSlash(character, a + hit * 45, cfg.Radius, AIR)
			end
			kickLeg(character, hit % 2 == 0 and "Left" or "Right", 0.05, 0.03, 0.9)
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.KickCombo(data)
	local character = data.Character
	if data.Whiff then
		kickLeg(character, "Right", 0.08, 0.05, 1)
		slash(character, 22, 6, AIR, 5, 0.15)
		return
	end
	afterImage(character, AIR, 0.4)
	speedLines(character, data.Duration or 0.9, AIR)
	limbTrail(character, { "RightFoot", "RightLowerLeg", "Right Leg" }, AIR, (data.Duration or 0.9) + 0.2)
	limbTrail(character, { "LeftFoot", "LeftLowerLeg", "Left Leg" }, AIR, (data.Duration or 0.9) + 0.2)
	task.spawn(function()
		local n = 6
		for i = 1, n do
			kickLeg(character, i % 2 == 0 and "Left" or "Right", 0.05, 0.02, 0.95)
			slash(character, i % 2 == 0 and 26 or -26, 6, AIR, 4.5, 0.13)
			task.wait(0.08)
		end
	end)
end

function Effects.PremierHachis(data)
	local character = data.Character
	speedLines(character, data.Duration or 1.4, FIRE_ORANGE)
	task.spawn(function()
		local elapsed = 0
		local side = "Right"
		while elapsed < (data.Duration or 1.4) do
			kickLeg(character, side, 0.05, 0.02, 0.95)
			flameArc(character, side == "Right" and -28 or 28, 7, 5)
			side = side == "Right" and "Left" or "Right"
			elapsed += task.wait(0.08)
		end
	end)
end

function Effects.FlambageShot(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Ult[2]
	tornado(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, cfg.Radius, 20, FIRE_ORANGE)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 270, 90 do
				arcSlash(character, a + hit * 55, cfg.Radius, FIRE_YELLOW)
			end
			kickLeg(character, hit % 2 == 0 and "Left" or "Right", 0.05, 0.03, 1)
			local r = root(character)
			if r then
				sparks(r.Position + Vector3.new(0, 1, 0), FIRE_ORANGE, 8, 20, 1.4)
			end
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.MoutonShot(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Ult[3]
	local r = root(character)
	if not r then
		return
	end
	kickLeg(character, "Right", cfg.WindUp * 0.7, cfg.WindUp * 0.3, -0.6)
	chargeAura(function()
		local foot = getPart(character, { "RightFoot", "RightLowerLeg", "Right Leg" })
		return foot and foot.Position
	end, cfg.WindUp, FIRE_ORANGE)
	task.delay(cfg.WindUp - 0.05, function()
		kickLeg(character, "Right", 0.07, 0.16, 1.2)
		flameArc(character, -16, cfg.Range * 0.5, 6)
		flameArc(character, 12, cfg.Range * 0.45, 6)
		local hit = r.Position + r.CFrame.LookVector * (cfg.Range * 0.5)
		flameImpact(hit, 2.2, true)
		shockwave(hit, 50, FIRE_ORANGE, 0.6, 1.4)
		screenFlash(FIRE_ORANGE, 0.28, 0.25)
		fovPunch(r.Position, 8, 0.4)
	end)
end

function Effects.GrillShot(data)
	local character = data.Character
	local cfg = Config.Movesets.Sanji.Ult[4]
	local r = root(character)
	if r then
		groundDisc(r.Position, cfg.Range, FIRE_DEEP, 0.6)
		screenFlash(FIRE_ORANGE, 0.3, 0.3)
	end
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			kickLeg(character, hit % 2 == 0 and "Left" or "Right", 0.05, 0.03, 1.1)
			flameArc(character, hit % 2 == 0 and 22 or -22, 10, 6)
			local rr = root(character)
			if rr then
				sparks(rr.Position + rr.CFrame.LookVector * 6 + Vector3.new(0, 1, 0), FIRE_ORANGE, 10, 24, 1.5)
				shake(rr.Position, 0.4, 0.15)
			end
			task.wait(cfg.HitInterval)
		end
		local rr = root(character)
		if rr then
			flameImpact(rr.Position + rr.CFrame.LookVector * 8, 2.6, true)
		end
	end)
end

function Effects.DiableStart(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	Anims.ultFlex(character)
	shockwave(r.Position, 50, FIRE_ORANGE, 0.8, 1.5)
	groundDisc(r.Position, 46, FIRE_DEEP, 0.7)
	sparks(r.Position, FIRE_ORANGE, 55, 45, 2)
	shake(r.Position, 1.2, 0.5)
	fovPunch(r.Position, 9, 0.5)
	if isLocal(character) then
		screenFlash(FIRE_ORANGE, 0.5, 0.5)
	end

	-- Persistent fire on both legs while Diable Jambe lasts.
	local instances = {}
	for _, legName in { "RightLowerLeg", "LeftLowerLeg", "Right Leg", "Left Leg", "RightFoot", "LeftFoot" } do
		local leg = character:FindFirstChild(legName)
		if leg then
			local fire = Instance.new("Fire")
			fire.Size = 5
			fire.Heat = 8
			fire.Color = FIRE_ORANGE
			fire.SecondaryColor = FIRE_DEEP
			fire.Parent = leg
			table.insert(instances, fire)
		end
	end
	diableFires[character] = instances
end

function Effects.DiableEnd(data)
	local instances = diableFires[data.Character]
	if instances then
		for _, fire in instances do
			if fire.Parent then
				fire.Enabled = false
				Debris:AddItem(fire, 1)
			end
		end
		diableFires[data.Character] = nil
	end
	local r = root(data.Character)
	if r then
		shockwave(r.Position, 20, FIRE_ORANGE, 0.5, 1)
	end
end

function Effects.IgniteStart(data)
	local character = data.Character
	if igniteFires[character] then
		return
	end
	local part = getPart(character, { "UpperTorso", "Torso", "HumanoidRootPart" })
	if not part then
		return
	end
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 6
	fire.Color = FIRE_ORANGE
	fire.SecondaryColor = FIRE_DEEP
	fire.Parent = part
	igniteFires[character] = fire
end

function Effects.IgniteEnd(data)
	local fire = igniteFires[data.Character]
	if fire then
		fire.Enabled = false
		Debris:AddItem(fire, 1)
		igniteFires[data.Character] = nil
	end
end

-- ========================================================================
-- Ace effect handlers (fire projectiles + zoning)
-- ========================================================================

local greatFlameFx = {}

-- Muzzle flash at the caster's hand.
local function muzzle(character, color)
	local hand = handPart(character, "Right")
	if hand then
		local flash = makePart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(hand.Position),
			Color = color,
			Transparency = 0.1,
		})
		tween(flash, 0.2, { Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1 })
		Debris:AddItem(flash, 0.25)
		sparks(hand.Position, color, 10, 22, 1.2)
	end
end

-- A fireball / bullet flying with the same kinematics the server simulates.
function Effects.FireProjectile(data)
	local color = data.Color or FIRE_ORANGE
	local radius = data.Radius or 3
	local ball = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		CFrame = CFrame.new(data.Origin),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.05,
	})
	addTrail(ball, color, 0.25, radius)
	local fire = Instance.new("Fire")
	fire.Size = radius * 2.5
	fire.Heat = 10
	fire.Color = color
	fire.SecondaryColor = FIRE_DEEP
	fire.Parent = ball

	task.spawn(function()
		local pos = data.Origin
		local dir = data.Direction
		local speed = data.Speed or 100
		local life = data.Life or 1
		local elapsed = 0
		while elapsed < life and ball.Parent do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			pos = pos + dir * (speed * dt)
			ball.CFrame = CFrame.new(pos)
		end
		fire.Enabled = false
		tween(ball, 0.12, { Transparency = 1, Size = Vector3.new(0.5, 0.5, 0.5) })
	end)
	Debris:AddItem(ball, (data.Life or 1) + 0.3)
end

function Effects.Explosion(data)
	local radius = data.Radius or 8
	local scale = math.clamp(radius / 6, 1, 5)
	flameImpact(data.Position, scale, true)
	shockwave(data.Position, radius * 3, data.Color or FIRE_ORANGE, 0.55, 1.3)
	if scale >= 2 then
		screenFlash(FIRE_ORANGE, 0.24, 0.22)
		fovPunch(data.Position, 6, 0.3)
	end
end

function Effects.FirePillar(data)
	local pos = data.Position
	local radius = data.Radius or 8
	-- Telegraph ring while it charges.
	local ring = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		CFrame = CFrame.new(pos.X, pos.Y - 2.5, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = data.Color or FIRE_ORANGE,
		Transparency = 0.4,
	})
	Debris:AddItem(ring, (data.Delay or 0.4) + 0.2)
	task.delay(data.Delay or 0.4, function()
		local column = makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(26, radius * 1.5, radius * 1.5),
			CFrame = CFrame.new(pos + Vector3.new(0, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = data.Color or FIRE_ORANGE,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		tween(column, 0.5, { Transparency = 1, Size = Vector3.new(28, radius * 2, radius * 2) }, Enum.EasingStyle.Quint)
		Debris:AddItem(column, 0.6)
		flameImpact(pos, radius / 6, true)
		sparks(pos, FIRE_ORANGE, 30, 40, 2)
	end)
end

function Effects.AceM1(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	Anims.aceM1(data.Character, data.Index)
	slash(data.Character, side == "Right" and -24 or 24, 5, FIRE_YELLOW, 5, 0.15)
	muzzle(data.Character, FIRE_ORANGE)
end

function Effects.HikenCast(data)
	local character = data.Character
	local cfg = Config.Movesets.Ace.Base[1]
	Anims.aceCast(character, cfg.WindUp or 0.4)
	chargeAura(function()
		local hand = handPart(character, "Right")
		return hand and hand.Position
	end, cfg.WindUp or 0.4, FIRE_ORANGE)
	task.delay((cfg.WindUp or 0.4) - 0.05, function()
		muzzle(character, FIRE_ORANGE)
	end)
end

function Effects.EnteiCast(data)
	local character = data.Character
	local cfg = Config.Movesets.Ace.Ult[1]
	local r = root(character)
	Anims.aceCast(character, cfg.WindUp or 1)
	chargeAura(function()
		local rr = root(character)
		return rr and rr.Position + rr.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
	end, cfg.WindUp or 1, FIRE_ORANGE)
	if r then
		shake(r.Position, 0.4, cfg.WindUp or 1)
	end
	task.delay((cfg.WindUp or 1) - 0.05, function()
		pushBothArms(character, 0.1, 0.2)
		muzzle(character, FIRE_YELLOW)
		local rr = root(character)
		if rr then
			screenFlash(FIRE_ORANGE, 0.25, 0.2)
		end
	end)
end

function Effects.HiganCast(data)
	Anims.aceFingerGun(data.Character, data.Bullets or 6)
	muzzle(data.Character, FIRE_ORANGE)
end

function Effects.FlameCombo(data)
	local character = data.Character
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		flameArc(character, 24, 6, 5)
		return
	end
	afterImage(character, FIRE_ORANGE, 0.4)
	speedLines(character, data.Duration or 0.9, FIRE_ORANGE)
	task.spawn(function()
		for i = 1, 5 do
			punchArm(character, i % 2 == 0 and "Left" or "Right", 0.05, 0.02, 0.95)
			flameArc(character, i % 2 == 0 and 26 or -26, 6, 4.5)
			task.wait(0.09)
		end
	end)
end

function Effects.Kyokaen(data)
	local character = data.Character
	local cfg = Config.Movesets.Ace.Ult[3]
	local r = root(character)
	if not r then
		return
	end
	pushBothArms(character, (cfg.WindUp or 0.5) * 0.6, (cfg.WindUp or 0.5) * 0.4)
	task.delay((cfg.WindUp or 0.5) - 0.05, function()
		-- A big fiery cross.
		slash(character, 45, cfg.Range * 0.5, FIRE_YELLOW, 6, 0.3)
		slash(character, -45, cfg.Range * 0.5, FIRE_ORANGE, 6, 0.3)
		local hit = r.Position + r.CFrame.LookVector * (cfg.Range * 0.5)
		flameImpact(hit, 2.2, true)
		shockwave(hit, 50, FIRE_ORANGE, 0.6, 1.4)
		screenFlash(FIRE_ORANGE, 0.28, 0.25)
		fovPunch(r.Position, 8, 0.4)
	end)
end

function Effects.Hotarubi(data)
	local pos = data.Position
	-- Fireflies gather toward the mark, then it detonates (server fires the
	-- Explosion at the end).
	chargeAura(function()
		return pos
	end, data.WindUp or 1.2, FIRE_YELLOW)
	local marker = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(pos),
		Color = FIRE_ORANGE,
		Transparency = 0.4,
	})
	tween(marker, data.WindUp or 1.2, { Size = Vector3.new(6, 6, 6), Transparency = 0.1 })
	Debris:AddItem(marker, (data.WindUp or 1.2) + 0.1)
end

function Effects.GreatFlameStart(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	Anims.ultFlex(character)
	shockwave(r.Position, 55, FIRE_ORANGE, 0.8, 1.6)
	groundDisc(r.Position, 50, FIRE_DEEP, 0.7)
	sparks(r.Position, FIRE_ORANGE, 60, 50, 2.4)
	shake(r.Position, 1.3, 0.55)
	fovPunch(r.Position, 11, 0.55)
	if isLocal(character) then
		screenFlash(FIRE_ORANGE, 0.55, 0.5)
	end

	local instances = {}
	for _, partName in { "UpperTorso", "Torso", "HumanoidRootPart", "RightLowerArm", "LeftLowerArm" } do
		local part = character:FindFirstChild(partName)
		if part then
			local fire = Instance.new("Fire")
			fire.Size = partName:find("Torso") and 8 or 4
			fire.Heat = 10
			fire.Color = FIRE_ORANGE
			fire.SecondaryColor = FIRE_DEEP
			fire.Parent = part
			table.insert(instances, fire)
		end
	end
	greatFlameFx[character] = instances
end

function Effects.GreatFlameEnd(data)
	local instances = greatFlameFx[data.Character]
	if instances then
		for _, fire in instances do
			if fire.Parent then
				fire.Enabled = false
				Debris:AddItem(fire, 1)
			end
		end
		greatFlameFx[data.Character] = nil
	end
	local r = root(data.Character)
	if r then
		shockwave(r.Position, 22, FIRE_ORANGE, 0.5, 1)
	end
end

-- ========================================================================
-- Tung Tung Tung Sahur effect handlers (bat + royal one-hit-kill ult)
-- ========================================================================

local WOOD = Color3.fromRGB(150, 108, 62)
local ROYAL_GOLD = Color3.fromRGB(255, 210, 90)

function Effects.TungM1(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	Anims.tungM1(data.Character, data.Index)
	batSwing(data.Character, side == "Right" and -30 or 30, 6, WOOD, 5, 0.16)
end

local function batSmash(character, color, big)
	local r = root(character)
	if not r then
		return
	end
	pushBothArms(character, 0.08, 0.14)
	batSwing(character, 6, big and 13 or 10, color, 5, 0.22)
	local hit = r.Position + r.CFrame.LookVector * 6
	impact(hit, { Color = color, Scale = big and 1.8 or 1.3, Heavy = true, CrackColor = Color3.fromRGB(60, 45, 30) })
end

function Effects.SahurSmash(data)
	local cfg = Config.Movesets.Tung.Base[1]
	Anims.tungSmash(data.Character, cfg.WindUp, false)
	task.delay(cfg.WindUp - 0.05, function()
		batSmash(data.Character, WOOD, false)
	end)
end

function Effects.TungBarrage(data)
	local character = data.Character
	speedLines(character, data.Duration or 1.2, WOOD)
	task.spawn(function()
		local elapsed = 0
		local side = "Right"
		while elapsed < (data.Duration or 1.2) do
			punchArm(character, side, 0.05, 0.02, 0.95)
			slash(character, side == "Right" and -26 or 26, 7, WOOD, 5, 0.12)
			side = side == "Right" and "Left" or "Right"
			elapsed += task.wait(0.1)
		end
	end)
end

function Effects.BrainrotSpin(data)
	local character = data.Character
	local cfg = Config.Movesets.Tung.Base[3]
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 270, 90 do
				arcSlash(character, a + hit * 50, cfg.Radius, WOOD)
			end
			local r = root(character)
			if r then
				shake(r.Position, 0.3, 0.15)
			end
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.BatCombo(data)
	local character = data.Character
	if data.Whiff then
		punchArm(character, "Right", 0.08, 0.05, 1)
		slash(character, 28, 6, WOOD, 5, 0.15)
		return
	end
	afterImage(character, WOOD, 0.4)
	weaponEdgeTrail(character, "BrainrotBat", "Barrel", WOOD, 0.7)
	task.spawn(function()
		for i = 1, 5 do
			Anims.tungM1(character, i)
			slash(character, i % 2 == 0 and 26 or -26, 6, WOOD, 4.5, 0.13)
			task.wait(0.09)
		end
	end)
end

-- Royal ult moves: gilded, extra dramatic.
local function royalHit(character, offset, scale)
	local r = root(character)
	if not r then
		return
	end
	local hit = r.Position + r.CFrame.LookVector * (offset or 6)
	flameArc(character, -14, 12, 6) -- gold streak reuse (fire arc tinted below)
	impact(hit, { Color = ROYAL_GOLD, Scale = scale or 2, Heavy = true, CrackColor = Color3.fromRGB(90, 70, 20) })
	shockwave(hit, 40, ROYAL_GOLD, 0.5, 1.2)
	screenFlash(ROYAL_GOLD, 0.2, 0.2)
end

function Effects.RoyalDecree(data)
	local cfg = Config.Movesets.Tung.Ult[1]
	Anims.tungSmash(data.Character, cfg.WindUp, true)
	task.delay(cfg.WindUp - 0.05, function()
		batSmash(data.Character, ROYAL_GOLD, true)
		royalHit(data.Character, 8, 2.2)
	end)
end

function Effects.KingsJudgement(data)
	local character = data.Character
	local cfg = Config.Movesets.Tung.Ult[2]
	Anims.zoroSpin(character, cfg.WindUp + 0.2)
	task.delay(cfg.WindUp, function()
		for a = 0, 315, 45 do
			arcSlash(character, a, cfg.Radius, ROYAL_GOLD)
		end
		local r = root(character)
		if r then
			groundDisc(r.Position, cfg.Radius * 2, ROYAL_GOLD, 0.6)
			impact(r.Position, { Color = ROYAL_GOLD, Scale = 2.6, Heavy = true })
			screenFlash(ROYAL_GOLD, 0.25, 0.25)
			shake(r.Position, 1, 0.4)
		end
	end)
end

function Effects.SahurRush(data)
	local character = data.Character
	if data.Whiff then
		slash(character, 28, 7, ROYAL_GOLD, 5, 0.16)
		return
	end
	afterImage(character, ROYAL_GOLD, 0.5)
	Anims.tungM1(character, 1)
	task.spawn(function()
		for i = 1, 3 do
			Anims.tungM1(character, i)
			slash(character, i % 2 == 0 and 30 or -30, 8, ROYAL_GOLD, 5, 0.14)
			task.wait(0.1)
		end
		royalHit(character, 5, 1.8)
	end)
end

function Effects.CrownCrush(data)
	local cfg = Config.Movesets.Tung.Ult[4]
	task.delay(cfg.WindUp - 0.05, function()
		batSmash(data.Character, ROYAL_GOLD, true)
		royalHit(data.Character, 8, 2.6)
		local r = root(data.Character)
		if r then
			fovPunch(r.Position, 10, 0.4)
		end
	end)
end

-- The King's arrival cutscene: crown drops onto the head + banner for all.
function Effects.KingCrown(data)
	local character = data.Character
	local r = root(character)
	-- Hold the royal strut through the whole cutscene.
	Anims.tungKingPose(character)
	local head = character:FindFirstChild("Head")
	local landPos = head and head.Position or (r and r.Position + Vector3.new(0, 2, 0))
	if landPos then
		-- A big golden crown falls from the sky with a light beam.
		local crown = makePart({
			Size = Vector3.new(5, 3, 5),
			CFrame = CFrame.new(landPos + Vector3.new(0, 60, 0)),
			Color = ROYAL_GOLD,
			Material = Enum.Material.Neon,
			Transparency = 0.05,
		})
		addTrail(crown, ROYAL_GOLD, 0.5, 3)
		local beam = makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(120, 8, 8),
			CFrame = CFrame.new(landPos + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = ROYAL_GOLD,
			Transparency = 0.6,
		})
		Debris:AddItem(beam, 1.2)
		tween(crown, 0.7, { CFrame = CFrame.new(landPos + Vector3.new(0, 2.6, 0)) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.7, function()
			shockwave(landPos, 40, ROYAL_GOLD, 0.6, 1.4)
			sparks(landPos, ROYAL_GOLD, 60, 45, 2.4)
			if r then
				shake(r.Position, 1.4, 0.5)
			end
			tween(crown, 0.25, { Transparency = 1 })
		end)
		Debris:AddItem(crown, 1.2)
	end

	-- Full-screen "THE KING HAS ARRIVED" banner for everyone.
	local gui = Instance.new("ScreenGui")
	gui.Name = "KingCutscene"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.Parent = gui

	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.5)
	banner.Size = UDim2.fromScale(0.9, 0.2)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBlack
	banner.TextScaled = true
	banner.TextColor3 = ROYAL_GOLD
	banner.TextStrokeColor3 = Color3.fromRGB(60, 40, 0)
	banner.TextStrokeTransparency = 0
	banner.TextTransparency = 1
	banner.Text = "THE KING HAS ARRIVED"
	banner.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.fromScale(0.5, 0.62)
	subtitle.Size = UDim2.fromScale(0.6, 0.05)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(240, 230, 200)
	subtitle.TextTransparency = 1
	subtitle.Text = data.Character and data.Character.Name or "Tung Tung Tung Sahur"
	subtitle.Parent = gui

	tween(dim, 0.3, { BackgroundTransparency = 0.55 })
	tween(banner, 0.4, { TextTransparency = 0 })
	tween(subtitle, 0.6, { TextTransparency = 0 })
	screenFlash(ROYAL_GOLD, 0.5, 0.6)

	task.delay(2.2, function()
		tween(banner, 0.5, { TextTransparency = 1 })
		tween(subtitle, 0.5, { TextTransparency = 1 })
		tween(dim, 0.5, { BackgroundTransparency = 1 })
		task.delay(0.6, function()
			gui:Destroy()
		end)
	end)
end

function Effects.KingCrownEnd(data)
	local r = root(data.Character)
	if r then
		shockwave(r.Position, 20, ROYAL_GOLD, 0.5, 1)
	end
end

-- ========================================================================
-- Kaido effect handlers (kanabo + Azure Dragon)
-- ========================================================================

local AZURE = Color3.fromRGB(90, 160, 220)
local AZURE_DEEP = Color3.fromRGB(40, 90, 150)

-- A jagged lightning bolt striking down onto a world position.
local function lightningBolt(position, color, segments)
	color = color or Color3.fromRGB(180, 210, 255)
	segments = segments or 6
	local top = position + Vector3.new(math.random(-6, 6), 90, math.random(-6, 6))
	local prev = top
	for i = 1, segments do
		local frac = i / segments
		local target = position:Lerp(top, 1 - frac) + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5)) * (1 - frac)
		if i == segments then
			target = position
		end
		local seg = makePart({
			Size = Vector3.new(0.5, 0.5, (target - prev).Magnitude),
			CFrame = CFrame.lookAt((prev + target) / 2, target),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.05,
		})
		tween(seg, 0.18, { Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(seg, 0.25)
		prev = target
	end
	sparks(position, color, 26, 40, 1.6)
	shockwave(position, 26, color, 0.4, 1)
end

local function kanaboSwing(character, angleDeg, length, color, forward, life)
	slash(character, angleDeg, length, color, forward, life)
	weaponEdgeTrail(character, "Kanabo", "Barrel", color, (life or 0.2) + 0.14)
end

function Effects.KaidoM1(data)
	local side = data.Index % 2 == 0 and "Left" or "Right"
	Anims.tungM1(data.Character, data.Index)
	kanaboSwing(data.Character, side == "Right" and -30 or 30, 8, Color3.fromRGB(150, 160, 175), 5, 0.18)
end

function Effects.Ragnaraku(data)
	local character = data.Character
	local cfg = Config.Movesets.Kaido.Base[1]
	Anims.tungSmash(character, cfg.WindUp, true)
	task.delay(cfg.WindUp - 0.05, function()
		local r = root(character)
		if not r then
			return
		end
		kanaboSwing(character, 6, 13, Color3.fromRGB(150, 160, 175), 5, 0.24)
		local hit = r.Position + r.CFrame.LookVector * 7
		lightningBolt(hit, Color3.fromRGB(200, 220, 255))
		impact(hit, { Color = Color3.fromRGB(200, 220, 255), Scale = 2, Heavy = true, CrackColor = Color3.fromRGB(60, 60, 70) })
		fovPunch(r.Position, 7, 0.35)
	end)
end

function Effects.Kaifu(data)
	local character = data.Character
	Anims.aceCast(character, Config.Movesets.Kaido.Base[2].WindUp or 0.35)
	local r = root(character)
	if r then
		-- azure wind gathering at the hand
		chargeAura(function()
			local hand = handPart(character, "Right")
			return hand and hand.Position
		end, Config.Movesets.Kaido.Base[2].WindUp or 0.35, AZURE)
	end
end

function Effects.KanaboSweep(data)
	local character = data.Character
	local cfg = Config.Movesets.Kaido.Base[3]
	Anims.zoroSpin(character, cfg.WindUp + cfg.Hits * cfg.HitInterval)
	weaponEdgeTrail(character, "Kanabo", "Barrel", Color3.fromRGB(150, 160, 175), cfg.WindUp + cfg.Hits * cfg.HitInterval + 0.2)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 270, 90 do
				arcSlash(character, a + hit * 50, cfg.Radius, Color3.fromRGB(170, 180, 195))
			end
			local r = root(character)
			if r then
				shake(r.Position, 0.4, 0.15)
			end
			task.wait(cfg.HitInterval)
		end
	end)
end

local function breathCone(character, cfg, color)
	Anims.aceCast(character, cfg.WindUp or 0.4)
	task.delay((cfg.WindUp or 0.4) - 0.05, function()
		local r = root(character)
		if not r then
			return
		end
		-- Fire/heat breath fanning out in front.
		for i = -2, 2 do
			flameArc(character, i * 16, (cfg.Range or 24) * 0.5, 5)
		end
		for n = 1, 3 do
			task.delay(n * 0.06, function()
				local rr = root(character)
				if rr then
					local pos = rr.Position + rr.CFrame.LookVector * (6 + n * 5) + Vector3.new(0, 1, 0)
					sparks(pos, color, 12, 24, 1.6)
				end
			end)
		end
		shake(r.Position, 0.5, 0.3)
	end)
end

function Effects.BoloBreath(data)
	breathCone(data.Character, Config.Movesets.Kaido.Base[4], FIRE_ORANGE)
end

-- Dragon-form breath casts (projectile itself is rendered by FireProjectile).
function Effects.DragonBoroBreath(data)
	local character = data.Character
	Anims.aceCast(character, Config.Movesets.Kaido.Ult[1].WindUp or 0.6)
	local r = root(character)
	if r then
		chargeAura(function()
			local rr = root(character)
			return rr and rr.Position + rr.CFrame.LookVector * 3 + Vector3.new(0, 1.5, 0)
		end, Config.Movesets.Kaido.Ult[1].WindUp or 0.6, FIRE_ORANGE)
		shake(r.Position, 0.4, 0.5)
		task.delay((Config.Movesets.Kaido.Ult[1].WindUp or 0.6) - 0.05, function()
			screenFlash(FIRE_ORANGE, 0.22, 0.2)
		end)
	end
end

function Effects.BlastBreath(data)
	local character = data.Character
	Anims.aceCast(character, Config.Movesets.Kaido.Ult[2].WindUp or 0.5)
	local r = root(character)
	if r then
		chargeAura(function()
			local rr = root(character)
			return rr and rr.Position + rr.CFrame.LookVector * 3 + Vector3.new(0, 1.5, 0)
		end, Config.Movesets.Kaido.Ult[2].WindUp or 0.5, Color3.fromRGB(255, 120, 50))
	end
end

function Effects.DragonTwister(data)
	local character = data.Character
	local cfg = Config.Movesets.Kaido.Ult[3]
	tornado(character, cfg.WindUp + cfg.Hits * cfg.HitInterval, cfg.Radius, 34, AZURE)
	task.delay(cfg.WindUp, function()
		for hit = 1, cfg.Hits do
			for a = 0, 270, 90 do
				arcSlash(character, a + hit * 55, cfg.Radius, AZURE)
			end
			task.wait(cfg.HitInterval)
		end
	end)
end

function Effects.RaimeiHakke(data)
	local character = data.Character
	local cfg = Config.Movesets.Kaido.Ult[4]
	Anims.tungSmash(character, cfg.WindUp, true)
	task.delay(cfg.WindUp - 0.05, function()
		local r = root(character)
		if not r then
			return
		end
		local hit = r.Position + r.CFrame.LookVector * 8
		for _ = 1, 3 do
			lightningBolt(hit + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)), Color3.fromRGB(200, 220, 255))
		end
		impact(hit, { Color = Color3.fromRGB(210, 225, 255), Scale = 3, Heavy = true, CrackColor = Color3.fromRGB(60, 60, 70) })
		shockwave(hit, 70, AZURE, 0.7, 1.6)
		screenFlash(Color3.fromRGB(200, 220, 255), 0.35, 0.3)
		fovPunch(r.Position, 10, 0.5)
	end)
end

-- The Azure Dragon transformation cutscene.
function Effects.DragonStart(data)
	local character = data.Character
	local r = root(character)
	if not r then
		return
	end
	Anims.ultFlex(character)

	-- Storm gathers: dark cloud, lightning ring, azure shockwaves, roar.
	local cloud = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(10, 6, 10),
		CFrame = CFrame.new(r.Position + Vector3.new(0, 40, 0)),
		Color = Color3.fromRGB(40, 48, 66),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.2,
		CanCollide = false,
	})
	tween(cloud, 0.6, { Size = Vector3.new(80, 26, 80), Transparency = 0.35 })
	Debris:AddItem(cloud, 2.5)

	for i = 1, 6 do
		task.delay(i * 0.12, function()
			lightningBolt(r.Position + Vector3.new(math.random(-16, 16), 0, math.random(-16, 16)), Color3.fromRGB(200, 220, 255))
		end)
	end

	shockwave(r.Position, 70, AZURE, 0.9, 2)
	shockwave(r.Position, 45, AZURE_DEEP, 0.7, 1.4)
	groundDisc(r.Position, 60, AZURE_DEEP, 0.8)
	sparks(r.Position, AZURE, 70, 55, 2.5)
	shake(r.Position, 1.8, 0.8)
	fovPunch(r.Position, 14, 0.7)
	if isLocal(character) then
		screenFlash(AZURE, 0.55, 0.6)
	end

	-- Swirling mist + a flame-cloud disc beneath his feet while transformed.
	local mist = Instance.new("ParticleEmitter")
	mist.Color = ColorSequence.new(Color3.fromRGB(150, 180, 210))
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0) })
	mist.Transparency = NumberSequence.new(0.5, 1)
	mist.Lifetime = NumberRange.new(0.7, 1.3)
	mist.Rate = 24
	mist.Speed = NumberRange.new(2, 5)
	mist.SpreadAngle = Vector2.new(180, 180)
	mist.Parent = r
	greatFlameFx[character] = { mist }

	-- Roar banner.
	local gui = Instance.new("ScreenGui")
	gui.Name = "DragonCutscene"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.5)
	banner.Size = UDim2.fromScale(0.85, 0.16)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBlack
	banner.TextScaled = true
	banner.TextColor3 = AZURE
	banner.TextStrokeColor3 = Color3.fromRGB(0, 10, 30)
	banner.TextStrokeTransparency = 0
	banner.TextTransparency = 1
	banner.Text = "UO UO NO MI — AZURE DRAGON"
	banner.Parent = gui
	tween(banner, 0.4, { TextTransparency = 0 })
	task.delay(1.9, function()
		tween(banner, 0.5, { TextTransparency = 1 })
		task.delay(0.6, function()
			gui:Destroy()
		end)
	end)
end

function Effects.DragonEnd(data)
	local instances = greatFlameFx[data.Character]
	if instances then
		for _, fx in instances do
			if fx.Parent then
				fx.Enabled = false
				Debris:AddItem(fx, 1.5)
			end
		end
		greatFlameFx[data.Character] = nil
	end
	local r = root(data.Character)
	if r then
		shockwave(r.Position, 24, AZURE, 0.5, 1)
		sparks(r.Position, AZURE, 20, 30, 1.5)
	end
end

-- ========================================================================
-- Wiring
-- ========================================================================

function VFXClient.Init()
	Camera.FieldOfView = DEFAULT_FOV
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
-- MODULE: CharacterSelect   (src/client/CharacterSelect.lua)
-- ====================================================================
local CharacterSelect = (function()
--[[
	CharacterSelect.lua
	A topbar button (sitting beside the core chat button) that opens a
	character-select menu built from Config.Roster. Selecting an unlocked
	character tells the server, which reassigns the moveset and respawns.
	Locked characters show as "COMING SOON".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")


local LocalPlayer = Players.LocalPlayer
local SelectCharacter = Remotes.get("SelectCharacter")

local BG = Color3.fromRGB(25, 25, 30)
local PANEL = Color3.fromRGB(32, 32, 40)
local ACCENT = Color3.fromRGB(220, 60, 60)
local LOCKED = Color3.fromRGB(90, 90, 100)

local CharacterSelect = {}

local cards = {} -- [id] = { select button, stroke, statusLabel }
local panel, backdrop, topButton, scroller

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function pad(instance, px)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = instance
end

-- ========================================================================
-- Selection state
-- ========================================================================

local function currentId()
	return LocalPlayer:GetAttribute("SelectedCharacter") or "Luffy"
end

local function refreshStates()
	local selected = currentId()
	for _, entry in Config.Roster do
		local card = cards[entry.Id]
		if card then
			local ownsEA = entry.EarlyAccess and LocalPlayer:GetAttribute("Owns_" .. entry.Id) == true
			if entry.Locked then
				card.stroke.Enabled = false
			elseif entry.EarlyAccess and not ownsEA then
				-- Not purchased yet: show the early-access buy state.
				card.button.Text = "EARLY ACCESS"
				card.button.BackgroundColor3 = Color3.fromRGB(230, 175, 60)
				card.button.TextColor3 = Color3.fromRGB(30, 25, 10)
				card.stroke.Enabled = false
			elseif entry.Id == selected then
				card.button.Text = "SELECTED"
				card.button.BackgroundColor3 = entry.Color
				card.button.TextColor3 = Color3.new(1, 1, 1)
				card.stroke.Enabled = true
				card.stroke.Color = entry.Color
			else
				card.button.Text = "SELECT"
				card.button.BackgroundColor3 = BG
				card.button.TextColor3 = Color3.new(1, 1, 1)
				card.stroke.Enabled = false
			end
		end
	end
	-- Tint the topbar button to the current character's color.
	local entry
	for _, e in Config.Roster do
		if e.Id == selected then
			entry = e
			break
		end
	end
	if topButton and entry then
		topButton.Text = entry.Name:sub(1, 1)
		topButton.BackgroundColor3 = entry.Color
	end
end

-- ========================================================================
-- Open / close
-- ========================================================================

local function setOpen(open)
	backdrop.Visible = open
	if open then
		refreshStates()
		panel.Size = UDim2.fromOffset(0, 0)
		panel.BackgroundTransparency = 1
		TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(720, 460),
			BackgroundTransparency = 0,
		}):Play()
	end
end

-- ========================================================================
-- Card construction
-- ========================================================================

local function buildCard(entry, parent, order)
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.fromOffset(196, 356)
	card.BackgroundColor3 = PANEL
	card.Parent = parent
	corner(card, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = entry.Color
	stroke.Thickness = 2.5
	stroke.Enabled = false
	stroke.Parent = card

	-- Color header with an initial as a stand-in portrait.
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 96)
	header.BackgroundColor3 = entry.Locked and LOCKED or entry.Color
	header.BorderSizePixel = 0
	header.Parent = card
	corner(header, 10)

	local initial = Instance.new("TextLabel")
	initial.BackgroundTransparency = 1
	initial.Size = UDim2.new(1, 0, 1, 0)
	initial.Font = Enum.Font.GothamBlack
	initial.TextSize = 54
	initial.TextColor3 = Color3.new(1, 1, 1)
	initial.TextTransparency = 0.15
	initial.Text = entry.Locked and "?" or entry.Name:sub(1, 1)
	initial.Parent = header

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 10, 0, 104)
	name.Size = UDim2.new(1, -20, 0, 20)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = entry.Locked and "???" or entry.Name
	name.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 10, 0, 124)
	title.Size = UDim2.new(1, -20, 0, 16)
	title.Font = Enum.Font.Gotham
	title.TextSize = 11
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = entry.Color
	title.Text = entry.Locked and "Locked" or entry.Title
	title.Parent = card

	-- Move list.
	local moves = Instance.new("TextLabel")
	moves.BackgroundTransparency = 1
	moves.Position = UDim2.new(0, 10, 0, 146)
	moves.Size = UDim2.new(1, -20, 0, 150)
	moves.Font = Enum.Font.Gotham
	moves.TextSize = 11
	moves.TextXAlignment = Enum.TextXAlignment.Left
	moves.TextYAlignment = Enum.TextYAlignment.Top
	moves.TextColor3 = Color3.fromRGB(200, 200, 210)
	moves.RichText = true
	moves.TextWrapped = true
	if entry.Locked then
		moves.Text = "Moveset hidden until\nthis fighter is released."
		moves.TextColor3 = Color3.fromRGB(150, 150, 160)
	else
		local lines = {}
		for i, move in entry.Moves do
			table.insert(lines, ("<b>%d</b>  %s"):format(i, move))
		end
		table.insert(lines, ("<b>ULT</b>  %s"):format(entry.Ult or "—"))
		moves.Text = table.concat(lines, "\n")
	end
	moves.Parent = card

	-- Select / locked button.
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -10)
	button.Size = UDim2.new(1, -20, 0, 34)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = not entry.Locked
	button.Parent = card
	corner(button, 7)

	if entry.Locked then
		button.Text = "COMING SOON"
		button.BackgroundColor3 = LOCKED
		button.Active = false
	else
		button.Text = "SELECT"
		button.BackgroundColor3 = BG
		button.Activated:Connect(function()
			SelectCharacter:FireServer(entry.Id)
			setOpen(false)
		end)
	end

	cards[entry.Id] = { button = button, stroke = stroke }
end

-- ========================================================================
-- Build
-- ========================================================================

function CharacterSelect.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CharacterSelectGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Topbar button, sitting just right of the core chat button.
	local BUTTON_SIZE = 32
	topButton = Instance.new("TextButton")
	topButton.Name = "CharacterButton"
	topButton.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	topButton.Font = Enum.Font.GothamBlack
	topButton.TextSize = 18
	topButton.TextColor3 = Color3.new(1, 1, 1)
	topButton.Text = "L"
	topButton.BackgroundColor3 = ACCENT
	topButton.AutoButtonColor = true
	topButton.Parent = gui
	corner(topButton, 16)

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Color3.new(1, 1, 1)
	topStroke.Thickness = 1.5
	topStroke.Transparency = 0.4
	topStroke.Parent = topButton

	local tip = Instance.new("TextLabel")
	tip.BackgroundTransparency = 1
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Position = UDim2.new(0.5, 0, 1, 2)
	tip.Size = UDim2.fromOffset(80, 12)
	tip.Font = Enum.Font.GothamMedium
	tip.TextSize = 9
	tip.TextColor3 = Color3.fromRGB(220, 220, 230)
	tip.TextStrokeTransparency = 0.5
	tip.Text = "CHARACTER"
	tip.Parent = topButton

	-- Place the button just right of the core topbar buttons (menu + chat).
	-- GuiService.TopbarInset reports the region NOT covered by Roblox's own
	-- topbar, so TopbarInset.Min.X is exactly where our safe area begins.
	local function positionButton()
		local inset = GuiService.TopbarInset
		if inset and inset.Width > 0 and inset.Min.X > 0 then
			local y = inset.Min.Y + (inset.Height - BUTTON_SIZE) / 2
			topButton.Position = UDim2.fromOffset(inset.Min.X + 8, math.max(2, y))
		else
			-- Fallback for clients without a reported inset.
			topButton.Position = UDim2.fromOffset(176, 4)
		end
	end
	positionButton()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(positionButton)

	-- Modal backdrop.
	backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Visible = false
	backdrop.Parent = gui

	-- Panel.
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(720, 460)
	panel.BackgroundColor3 = BG
	panel.Parent = backdrop
	corner(panel, 14)
	pad(panel, 16)

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Size = UDim2.new(1, 0, 0, 30)
	heading.Font = Enum.Font.GothamBlack
	heading.TextSize = 22
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = Color3.new(1, 1, 1)
	heading.Text = "SELECT CHARACTER"
	heading.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, 0, 0, 0)
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "X"
	closeButton.BackgroundColor3 = ACCENT
	closeButton.Parent = panel
	corner(closeButton, 7)

	-- Scrolling row of cards.
	scroller = Instance.new("ScrollingFrame")
	scroller.Position = UDim2.new(0, 0, 0, 42)
	scroller.Size = UDim2.new(1, 0, 1, -42)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.ScrollBarThickness = 6
	scroller.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = scroller

	CharacterSelect.RebuildCards()

	-- Wiring.
	topButton.Activated:Connect(function()
		setOpen(not backdrop.Visible)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	backdrop.Activated:Connect(function()
		setOpen(false)
	end)
	LocalPlayer:GetAttributeChangedSignal("SelectedCharacter"):Connect(refreshStates)
	-- Reveal the admin character the moment access is granted.
	LocalPlayer:GetAttributeChangedSignal("Admin"):Connect(CharacterSelect.RebuildCards)
	-- Update early-access cards when ownership is confirmed / purchased.
	for _, entry in Config.Roster do
		if entry.EarlyAccess then
			LocalPlayer:GetAttributeChangedSignal("Owns_" .. entry.Id):Connect(refreshStates)
		end
	end

	refreshStates()
end

-- Builds the card row, skipping admin-only characters unless the local
-- player has been granted admin access.
function CharacterSelect.RebuildCards()
	if not scroller then
		return
	end
	for _, child in scroller:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(cards)

	local isAdmin = LocalPlayer:GetAttribute("Admin") == true
	local order = 0
	for _, entry in Config.Roster do
		if not entry.Admin or isAdmin then
			order += 1
			buildCard(entry, scroller, order)
		end
	end
	refreshStates()
end

return CharacterSelect
end)()

-- ====================================================================
-- MODULE: AdminPanel   (src/client/AdminPanel.lua)
-- ====================================================================
local AdminPanel = (function()
--[[
	AdminPanel.lua
	A hidden admin panel. Press  K  to toggle it, type the code and submit.
	The code is validated on the server (AdminAuth); on success
	the server grants the Admin attribute, which unlocks the admin-only
	character in the select menu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")


local LocalPlayer = Players.LocalPlayer
local AdminAuth = Remotes.get("AdminAuth")

local BG = Color3.fromRGB(20, 20, 26)
local GOLD = Color3.fromRGB(230, 190, 80)

local AdminPanel = {}

local backdrop, statusLabel, codeBox

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function setOpen(open)
	backdrop.Visible = open
	if open then
		codeBox.Text = ""
		statusLabel.Text = "Enter the access code."
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
		codeBox:CaptureFocus()
	end
end

function AdminPanel.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanelGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Visible = false
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 220)
	panel.BackgroundColor3 = BG
	panel.Parent = backdrop
	corner(panel, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 16)
	title.Size = UDim2.new(1, -40, 0, 28)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = GOLD
	title.Text = "ADMIN PANEL"
	title.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(20, 50)
	statusLabel.Size = UDim2.new(1, -40, 0, 20)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	statusLabel.Text = "Enter the access code."
	statusLabel.Parent = panel

	codeBox = Instance.new("TextBox")
	codeBox.Position = UDim2.fromOffset(20, 82)
	codeBox.Size = UDim2.new(1, -40, 0, 44)
	codeBox.Font = Enum.Font.Gotham
	codeBox.TextSize = 16
	codeBox.TextColor3 = Color3.new(1, 1, 1)
	codeBox.PlaceholderText = "Access code"
	codeBox.Text = ""
	codeBox.ClearTextOnFocus = false
	codeBox.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
	codeBox.Parent = panel
	corner(codeBox, 8)

	local submit = Instance.new("TextButton")
	submit.AnchorPoint = Vector2.new(0.5, 1)
	submit.Position = UDim2.new(0.5, 0, 1, -16)
	submit.Size = UDim2.new(1, -40, 0, 42)
	submit.Font = Enum.Font.GothamBold
	submit.TextSize = 15
	submit.TextColor3 = Color3.fromRGB(20, 20, 20)
	submit.BackgroundColor3 = GOLD
	submit.Text = "AUTHENTICATE"
	submit.Parent = panel
	corner(submit, 8)

	local function trySubmit()
		if codeBox.Text ~= "" then
			statusLabel.Text = "Checking..."
			statusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
			AdminAuth:FireServer(codeBox.Text)
		end
	end
	submit.Activated:Connect(trySubmit)
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			trySubmit()
		end
	end)

	AdminAuth.OnClientEvent:Connect(function(granted)
		if granted then
			statusLabel.Text = "ACCESS GRANTED - the King is unlocked."
			statusLabel.TextColor3 = Color3.fromRGB(120, 230, 120)
			task.delay(1.2, function()
				setOpen(false)
			end)
		else
			statusLabel.Text = "ACCESS DENIED."
			statusLabel.TextColor3 = Color3.fromRGB(235, 90, 90)
			codeBox.Text = ""
		end
	end)

	backdrop.Activated:Connect(function()
		setOpen(false)
	end)

	-- Toggle with the K key.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.K then
			setOpen(not backdrop.Visible)
		end
	end)
end

return AdminPanel
end)()

-- ====================================================================
-- MODULE: MainMenu   (src/client/MainMenu.lua)
-- ====================================================================
local MainMenu = (function()
--[[
	MainMenu.lua
	The title screen shown when you enter the game: a cinematic camera slowly
	orbits high above Onigashima while the title and a PLAY button are overlaid.
	Player controls and the combat HUD are locked/hidden until PLAY is pressed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local RED = Color3.fromRGB(220, 60, 60)
local GOLD = Color3.fromRGB(240, 200, 90)

local MainMenu = {}

local orbiting = false
local controls

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

-- Try to disable/enable the default player movement controls.
local function getControls()
	if controls then
		return controls
	end
	local ok, playerModule = pcall(function()
		return require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and playerModule then
		local gotControls
		pcall(function()
			gotControls = playerModule:GetControls()
		end)
		controls = gotControls
	end
	return controls
end

local function setGuiEnabled(name, enabled)
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local target = gui and gui:FindFirstChild(name)
	if target then
		target.Enabled = enabled
	end
end

-- Cinematic aerial orbit high above the island, looking down at it.
local function startOrbit()
	local center = Vector3.new(0, 30, -50)
	local height = 480
	local radius = 220
	local angle = 0
	orbiting = true
	Camera.CameraType = Enum.CameraType.Scriptable
	-- BindToRenderStep returns nothing, so track state with a flag and stop
	-- driving the camera once the orbit ends (the bound fn can fire one more
	-- time after Unbind is requested).
	RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not orbiting then
			return
		end
		angle += dt * 0.05
		local pos = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		Camera.CFrame = CFrame.lookAt(pos, center)
	end)
end

local function stopOrbit()
	orbiting = false
	pcall(function()
		RunService:UnbindFromRenderStep("MenuCamera")
	end)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	Camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		Camera.CameraSubject = humanoid
	end
end

function MainMenu.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenuGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Take over the camera + lock the player.
	startOrbit()
	local c = getControls()
	if c then
		c:Disable()
	end
	setGuiEnabled("CombatHUD", false)
	setGuiEnabled("CharacterSelectGui", false)

	-- Edge vignette so the overlay text stays readable over the island.
	local vignetteTop = Instance.new("Frame")
	vignetteTop.Size = UDim2.new(1, 0, 0.45, 0)
	vignetteTop.BackgroundColor3 = Color3.new(0, 0, 0)
	vignetteTop.BorderSizePixel = 0
	vignetteTop.Parent = gui
	local gradTop = Instance.new("UIGradient")
	gradTop.Rotation = 90
	gradTop.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradTop.Parent = vignetteTop

	local vignetteBottom = Instance.new("Frame")
	vignetteBottom.AnchorPoint = Vector2.new(0, 1)
	vignetteBottom.Position = UDim2.new(0, 0, 1, 0)
	vignetteBottom.Size = UDim2.new(1, 0, 0.5, 0)
	vignetteBottom.BackgroundColor3 = Color3.new(0, 0, 0)
	vignetteBottom.BorderSizePixel = 0
	vignetteBottom.Parent = gui
	local gradBottom = Instance.new("UIGradient")
	gradBottom.Rotation = 90
	gradBottom.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	gradBottom.Parent = vignetteBottom

	-- Title.
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.14, 0)
	title.Size = UDim2.new(0.9, 0, 0, 90)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeColor3 = Color3.fromRGB(40, 0, 0)
	title.TextStrokeTransparency = 0.2
	title.Text = "ONE PIECE"
	title.Parent = gui
	local titleGrad = Instance.new("UIGradient")
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 60)),
	})
	titleGrad.Rotation = 90
	titleGrad.Parent = title

	local title2 = Instance.new("TextLabel")
	title2.AnchorPoint = Vector2.new(0.5, 0)
	title2.Position = UDim2.new(0.5, 0, 0.14, 84)
	title2.Size = UDim2.new(0.9, 0, 0, 70)
	title2.BackgroundTransparency = 1
	title2.Font = Enum.Font.GothamBlack
	title2.TextScaled = true
	title2.TextColor3 = RED
	title2.TextStrokeColor3 = Color3.new(0, 0, 0)
	title2.TextStrokeTransparency = 0.3
	title2.Text = "BATTLEGROUNDS"
	title2.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0.14, 162)
	subtitle.Size = UDim2.new(0.6, 0, 0, 22)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(220, 220, 230)
	subtitle.Text = "The island of Onigashima"
	subtitle.Parent = gui

	-- PLAY button.
	local play = Instance.new("TextButton")
	play.AnchorPoint = Vector2.new(0.5, 1)
	play.Position = UDim2.new(0.5, 0, 0.82, 0)
	play.Size = UDim2.new(0, 260, 0, 64)
	play.BackgroundColor3 = RED
	play.Font = Enum.Font.GothamBlack
	play.TextSize = 26
	play.TextColor3 = Color3.new(1, 1, 1)
	play.Text = "PLAY"
	play.AutoButtonColor = true
	play.Parent = gui
	corner(play, 14)
	local playStroke = Instance.new("UIStroke")
	playStroke.Color = Color3.new(1, 1, 1)
	playStroke.Thickness = 2
	playStroke.Transparency = 0.3
	playStroke.Parent = play

	-- A gentle pulse on the PLAY button.
	task.spawn(function()
		while play.Parent do
			TweenService:Create(play, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Size = UDim2.new(0, 274, 0, 68) }):Play()
			task.wait(0.8)
			TweenService:Create(play, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Size = UDim2.new(0, 260, 0, 64) }):Play()
			task.wait(0.8)
		end
	end)

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.83, 6)
	hint.Size = UDim2.new(0.5, 0, 0, 18)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextScaled = true
	hint.TextColor3 = Color3.fromRGB(200, 200, 210)
	hint.Text = "Controls:  M1 attack  ·  1-4 skills  ·  Q dash  ·  F block  ·  G ult  ·  K admin"
	hint.Parent = gui

	local function play_pressed()
		play.Active = false
		stopOrbit()
		local c2 = getControls()
		if c2 then
			c2:Enable()
		end
		setGuiEnabled("CombatHUD", true)
		setGuiEnabled("CharacterSelectGui", true)
		-- Fade the whole menu out.
		for _, obj in gui:GetDescendants() do
			if obj:IsA("TextLabel") or obj:IsA("TextButton") then
				TweenService:Create(obj, TweenInfo.new(0.35), { TextTransparency = 1, BackgroundTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif obj:IsA("Frame") then
				TweenService:Create(obj, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(0.4, function()
			gui:Destroy()
		end)
	end

	play.Activated:Connect(play_pressed)
end

return MainMenu
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
CharacterSelect.Init()
AdminPanel.Init()
-- The title screen takes over the camera + hides the HUD until PLAY.
MainMenu.Init()

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
