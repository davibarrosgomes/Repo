--[[
	init.server.lua
	Main server entry point: player/character setup, remote handling,
	server-side cooldown enforcement, KO leaderboard.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Combat = require(script.CombatService)
local MapBuilder = require(script.MapBuilder)
local Luffy = require(script.Characters.Luffy)
local Zoro = require(script.Characters.Zoro)
local Sanji = require(script.Characters.Sanji)

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
	Sanji = Sanji,
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
