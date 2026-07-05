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

local VFXClient = {}

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "CombatEffects"
effectsFolder.Parent = workspace

-- Per-character state.
local gear5Emitters = {}
local rubberHighlights = {}
local blockHighlights = {}
local ashuraAuras = {} -- [character] = true while the Ashura aura loop runs
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

-- A bright blade streak in front of the character. `angleDeg` is the roll of
-- the slash; it sweeps ~45 degrees and fades. Returns the world hit point.
local function slash(character, angleDeg, length, color, forward, life)
	local r = root(character)
	if not r then
		return nil
	end
	forward = forward or 5
	local base = r.CFrame * CFrame.new(0, 1.2, -forward)
	local blade = makePart({
		Size = Vector3.new(0.22, length, 1.1),
		CFrame = base * CFrame.Angles(0, 0, math.rad(angleDeg)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.05,
	})
	addTrail(blade, color, 0.14, length * 0.45)
	tween(blade, life or 0.16, {
		CFrame = base * CFrame.Angles(0, 0, math.rad(angleDeg + 46)),
		Size = Vector3.new(0.22, length * 1.12, 1.1),
		Transparency = 1,
	}, Enum.EasingStyle.Quint)
	Debris:AddItem(blade, (life or 0.16) + 0.05)
	return base.Position
end

-- Horizontal arc slash sweeping around the character (spins).
local function arcSlash(character, startAngle, radius, color)
	local r = root(character)
	if not r then
		return
	end
	local arc = makePart({
		Size = Vector3.new(radius * 2, 0.25, 1.4),
		CFrame = r.CFrame * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(startAngle), 0) * CFrame.new(0, 0, -radius),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	tween(arc, 0.2, { Transparency = 1, Size = Vector3.new(radius * 2.2, 0.25, 1.4) })
	Debris:AddItem(arc, 0.25)
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
	punchArm(data.Character, side, 0.06, 0.05, 1)
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

	-- Wind-up: draw the fist back with a charge aura.
	punchArm(character, "Right", cfg.WindUp * 0.7, cfg.WindUp * 0.3, -0.4)
	chargeAura(function()
		local hand = handPart(character, "Right")
		return hand and hand.Position
	end, cfg.WindUp, RUBBER)

	task.delay(cfg.WindUp - 0.05, function()
		if not root(character) then
			return
		end
		punchArm(character, "Right", 0.07, 0.14, 1.1)
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

	punchArm(character, "Right", cfg.WindUp * 0.6, cfg.WindUp * 0.4, -0.5)
	punchArm(character, "Left", cfg.WindUp * 0.6, cfg.WindUp * 0.4, -0.5)
	chargeAura(function()
		return r.Position + r.CFrame.LookVector * 2
	end, cfg.WindUp, RUBBER)

	task.delay(cfg.WindUp - 0.05, function()
		if not root(character) then
			return
		end
		pushBothArms(character, 0.08, 0.16)
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
	punchArm(data.Character, side, 0.06, 0.05, 1)
	slash(data.Character, side == "Right" and -32 or 32, 6, SLASH, 5, 0.16)
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
	slash(character, -45, 8, SLASH, 4, 0.2)
	task.delay(0.05, function()
		slash(character, 45, 8, SLASH, 4, 0.2)
	end)
	task.delay(0.1, function()
		slash(character, 90, 8, BLADE, 4, 0.2)
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
	punchArm(character, "Right", cfg.WindUp * 0.7, cfg.WindUp * 0.3, -0.7)
	chargeAura(function()
		return r.Position + Vector3.new(0, 4, 0)
	end, cfg.WindUp, SLASH)
	task.delay(cfg.WindUp - 0.05, function()
		pushBothArms(character, 0.08, 0.14)
		slash(character, 8, 12, BLADE, 5, 0.22)
		slash(character, -4, 11, SLASH, 5, 0.22)
		local hit = r.Position + r.CFrame.LookVector * 6
		impact(hit, { Color = SLASH, Scale = 1.5, Heavy = true, CrackColor = Color3.fromRGB(70, 74, 82) })
	end)
end

function Effects.UlToraGari(data)
	local character = data.Character
	local cfg = Config.Movesets.Zoro.Base[3]
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
	task.spawn(function()
		local n = 6
		for i = 1, n do
			local side = i % 2 == 0 and 38 or -38
			punchArm(character, i % 2 == 0 and "Left" or "Right", 0.05, 0.02, 0.9)
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
local panel, backdrop, topButton

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
			if entry.Locked then
				card.stroke.Enabled = false
			elseif entry.Id == selected then
				card.button.Text = "SELECTED"
				card.button.BackgroundColor3 = entry.Color
				card.stroke.Enabled = true
				card.stroke.Color = entry.Color
			else
				card.button.Text = "SELECT"
				card.button.BackgroundColor3 = BG
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
	local scroller = Instance.new("ScrollingFrame")
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

	for order, entry in Config.Roster do
		buildCard(entry, scroller, order)
	end

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

	refreshStates()
end

return CharacterSelect
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
