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
local Ace = require(script.Characters.Ace)
local Tung = require(script.Characters.Tung)
local Kaido = require(script.Characters.Kaido)

local MarketplaceService = game:GetService("MarketplaceService")

local UseSkill = Remotes.get("UseSkill")
local M1 = Remotes.get("M1")
local ActivateUlt = Remotes.get("ActivateUlt")
local Dash = Remotes.get("Dash")
local Block = Remotes.get("Block")
local SelectCharacter = Remotes.get("SelectCharacter")
local AdminAuth = Remotes.get("AdminAuth")
local VFX = Remotes.get("VFX")
local HUDUpdate = Remotes.get("HUDUpdate")

-- The admin code lives ONLY on the server (ServerScriptService is never
-- replicated to clients), so it never ships in client-readable code.
local ADMIN_CODE = "GomesFamily"

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
	Ace = Ace,
	Tung = Tung,
	Kaido = Kaido,
}
local DEFAULT_CHARACTER = "Luffy"

-- Which roster ids are free-to-all, admin-only, or early-access (gated by a
-- Game Pass purchase). Early-access ids also record their Game Pass id.
local unlockedIds = {}
local adminIds = {}
local earlyAccessIds = {}
local earlyAccessPass = {}
for _, entry in Config.Roster do
	if Characters[entry.Id] then
		if entry.Admin then
			adminIds[entry.Id] = true
		elseif entry.EarlyAccess then
			earlyAccessIds[entry.Id] = true
			earlyAccessPass[entry.Id] = entry.GamePassId or 0
		elseif not entry.Locked then
			unlockedIds[entry.Id] = true
		end
	end
end

-- Ownership cache: [player][id] = bool.
local owns = setmetatable({}, { __mode = "k" })

-- Does the player have access to an early-access character?
local function ownsEarlyAccess(player, id)
	-- The game owner and admins always have access (for testing / staff).
	if player.UserId == game.CreatorId or player:GetAttribute("Admin") == true then
		player:SetAttribute("Owns_" .. id, true)
		return true
	end
	local cache = owns[player]
	if cache and cache[id] ~= nil then
		return cache[id]
	end
	if not cache then
		cache = {}
		owns[player] = cache
	end
	local passId = earlyAccessPass[id] or 0
	local result = false
	if passId ~= 0 then
		local ok, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		result = ok and hasPass or false
	end
	cache[id] = result
	player:SetAttribute("Owns_" .. id, result)
	return result
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

-- Actually assign a character and respawn the player into it.
local function doSelect(player, id)
	if player:GetAttribute("SelectedCharacter") == id then
		return
	end
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
	player:LoadCharacter()
end

SelectCharacter.OnServerEvent:Connect(function(player, id)
	if type(id) ~= "string" or not Characters[id] then
		return
	end

	if unlockedIds[id] then
		doSelect(player, id)
	elseif adminIds[id] then
		if player:GetAttribute("Admin") == true then
			doSelect(player, id)
		end
	elseif earlyAccessIds[id] then
		if ownsEarlyAccess(player, id) then
			doSelect(player, id)
		else
			-- Not owned yet: send them to the Game Pass purchase prompt.
			local passId = earlyAccessPass[id] or 0
			if passId ~= 0 then
				pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, passId)
				end)
			end
		end
	end
end)

-- When an early-access Game Pass is purchased, grant + auto-select it.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, purchasedPassId, wasPurchased)
	if not wasPurchased then
		return
	end
	for id, passId in earlyAccessPass do
		if passId == purchasedPassId then
			local cache = owns[player]
			if not cache then
				cache = {}
				owns[player] = cache
			end
			cache[id] = true
			player:SetAttribute("Owns_" .. id, true)
			doSelect(player, id)
		end
	end
end)

-- ========================================================================
-- Admin authentication
-- The code is validated here on the server; the client only ever sends a
-- guess. A short per-player cooldown discourages brute-forcing.
-- ========================================================================
local adminTry = {}
AdminAuth.OnServerEvent:Connect(function(player, code)
	local now = os.clock()
	if now < (adminTry[player] or 0) then
		return
	end
	adminTry[player] = now + 1

	if type(code) == "string" and code == ADMIN_CODE then
		player:SetAttribute("Admin", true)
		AdminAuth:FireClient(player, true)
	else
		AdminAuth:FireClient(player, false)
	end
end)

-- ========================================================================
-- Player / character lifecycle
-- ========================================================================

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")

	-- Per-character stat multipliers (OP characters can have more health /
	-- harder hits). DamageMult is read by Combat.DealDamage.
	local moveset = Config.Movesets[player:GetAttribute("SelectedCharacter") or DEFAULT_CHARACTER]
	local healthMult = (moveset and moveset.HealthMult) or 1
	local maxHealth = Config.Character.MaxHealth * healthMult
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.BreakJointsOnDeath = false

	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower)
	character:SetAttribute("BlockHealth", Config.Block.MaxHealth)
	character:SetAttribute("DamageMult", (moveset and moveset.DamageMult) or 1)
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

	-- Pre-check early-access ownership so the menu can show OWNED (async so
	-- it never blocks the join).
	task.spawn(function()
		for id in earlyAccessIds do
			ownsEarlyAccess(player, id)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
	casting[player] = nil
	dashReady[player] = nil
	adminTry[player] = nil
	for _, module in Characters do
		if module.ForgetPlayer then
			module.ForgetPlayer(player)
		end
	end
	if player.Character then
		Combat.ForgetCharacter(player.Character)
	end
end)
