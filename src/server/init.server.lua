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
local Luffy = require(script.Characters.Luffy)

local UseSkill = Remotes.get("UseSkill")
local M1 = Remotes.get("M1")
local ActivateUlt = Remotes.get("ActivateUlt")
local HUDUpdate = Remotes.get("HUDUpdate")

-- [player] = { [slot] = os.clock() time when the slot is ready again }
local cooldowns = {}
-- [player] = true while one of their skills is still executing
local casting = {}

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

	casting[player] = true
	local ok, cooldown = pcall(Luffy.UseSkill, player, character, slot)
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
		Luffy.M1(player, character)
	end
end)

ActivateUlt.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then
		return
	end
	if Luffy.ActivateUlt(player, character) then
		-- Fresh moveset, fresh slots.
		cooldowns[player] = {}
	end
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
	Combat.RefreshMovement(character)

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
		Luffy.DeactivateUlt(player, character)
		Combat.ForgetCharacter(character)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("UltCharge", 0)

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
	Luffy.ForgetPlayer(player)
	if player.Character then
		Combat.ForgetCharacter(player.Character)
	end
end)
