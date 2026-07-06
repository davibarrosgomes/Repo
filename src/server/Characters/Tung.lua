--[[
	Tung.lua
	ADMIN-ONLY OP character: Tung Tung Tung Sahur, the Brainrot King.
	Wields a bat. 2x health and 1.5x damage are applied on spawn from
	Config.Movesets.Tung.HealthMult / DamageMult.

	Base moveset (slots 1-4): bat attacks (still balanced, just harder-hitting).
	Ult (G): "THE KING" - plays a crown cutscene ("The king has arrived") and
	makes every ult-slot attack a one-hit kill.

	Interface matches the other characters.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Combat = require(script.Parent.Parent.CombatService)

local VFX = Remotes.get("VFX")
local HUDUpdate = Remotes.get("HUDUpdate")

local Tung = {}

local MY = Config.Movesets.Tung

local m1State = {}
local kingTokens = {}

-- ========================================================================
-- Helpers
-- ========================================================================

local function faceTarget(character, targetCharacter)
	local root = Combat.Root(character)
	local targetRoot = Combat.Root(targetCharacter)
	if root and targetRoot then
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z))
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

local function isKing(character)
	return character:GetAttribute("KingMode") == true
end

local function targetsAround(character, radius)
	local root = Combat.Root(character)
	if not root then
		return {}
	end
	return Combat.GetTargetsInBox(root.CFrame, Vector3.new(radius * 2, 14, radius * 2), character)
end

-- ========================================================================
-- Procedural bat (welded on spawn)
-- ========================================================================

local function makePart(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = nil
	return p
end

function Tung.Setup(_player, character)
	local hand = character:WaitForChild("RightHand", 5) or character:FindFirstChild("Right Arm")
	if not hand or not character.Parent then
		return
	end
	local existing = character:FindFirstChild("BrainrotBat")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BrainrotBat"
	folder.Parent = character

	local grip = CFrame.new(0, 0, -0.6) * CFrame.Angles(math.rad(-95), 0, 0)
	local pieces = {
		{ part = makePart("Handle", Vector3.new(0.5, 1.8, 0.5), Color3.fromRGB(90, 62, 38)), offset = CFrame.new(0, 0, 0) },
		{ part = makePart("Barrel", Vector3.new(1.1, 4.2, 1.1), Color3.fromRGB(120, 84, 50)), offset = CFrame.new(0, 3, 0) },
	}
	for _, entry in pieces do
		local part = entry.part
		part.Parent = folder
		local weld = Instance.new("Weld")
		weld.Part0 = hand
		weld.Part1 = part
		weld.C0 = grip * entry.offset
		weld.Parent = part
	end
end

-- ========================================================================
-- M1 combo (bat swings)
-- ========================================================================

function Tung.M1(player, character)
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
	VFX:FireAllClients("TungM1", { Character = character, Index = isFinisher and cfg.ComboHits or state.count })

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

local function forwardSmash(player, character, cfg, effectName)
	Combat.SetBusy(character, cfg.WindUp + 0.35, true)
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

local function forwardBarrage(player, character, cfg, effectName)
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
				opts.KnockbackUp = cfg.Knockback * 0.4
			end
			Combat.DealDamage(player, target, cfg.DamagePerHit, opts)
		end
		if not isLast then
			task.wait(cfg.HitInterval)
		end
	end
end

local function dashCombo(player, character, cfg, effectName)
	local target = Combat.NearestTarget(character, cfg.DashRange)
	if not target then
		Combat.SetBusy(character, 0.4)
		VFX:FireAllClients(effectName, { Character = character, Whiff = true })
		task.wait(0.22)
		local look = Combat.FlatLook(character)
		for _, hit in Combat.FrontHitbox(character, cfg.Range, 6) do
			Combat.DealDamage(player, hit, cfg.DamagePerHit * 2, { KnockbackDir = look, KnockbackPower = 40, StunTime = 0.6 })
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

-- ========================================================================
-- Movesets
-- ========================================================================

local function sahurSmash(player, character)
	forwardSmash(player, character, MY.Base[1], "SahurSmash")
end
local function tungBarrage(player, character)
	forwardBarrage(player, character, MY.Base[2], "TungBarrage")
end
local function brainrotSpin(player, character)
	spinAoE(player, character, MY.Base[3], "BrainrotSpin")
end
local function batCombo(player, character)
	dashCombo(player, character, MY.Base[4], "BatCombo")
end

local function royalDecree(player, character)
	forwardSmash(player, character, MY.Ult[1], "RoyalDecree")
end
local function kingsJudgement(player, character)
	spinAoE(player, character, MY.Ult[2], "KingsJudgement")
end
local function sahurRush(player, character)
	dashCombo(player, character, MY.Ult[3], "SahurRush")
end
local function crownCrush(player, character)
	forwardSmash(player, character, MY.Ult[4], "CrownCrush")
end

-- ========================================================================
-- Ult: THE KING
-- ========================================================================

function Tung.ActivateUlt(player, character)
	if not Combat.IsActionable(character) then
		return false
	end
	if isKing(character) then
		return false
	end
	local charge = player:GetAttribute("UltCharge") or 0
	if charge < Config.Ult.MaxCharge then
		return false
	end

	player:SetAttribute("UltCharge", 0)
	character:SetAttribute("KingMode", true)

	local token = (kingTokens[player] or 0) + 1
	kingTokens[player] = token

	local humanoid = Combat.Humanoid(character)
	if humanoid then
		humanoid.Health = humanoid.MaxHealth -- full heal on the King's arrival
	end

	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed + Config.Ult.WalkSpeedBonus)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower + Config.Ult.JumpPowerBonus)
	Combat.RefreshMovement(character)

	-- Golden royal aura.
	local highlight = Instance.new("Highlight")
	highlight.Name = "KingHighlight"
	highlight.FillColor = Color3.fromRGB(120, 90, 20)
	highlight.OutlineColor = Color3.fromRGB(255, 210, 90)
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 0
	highlight.Parent = character

	-- The crown, welded to the head (replicated to everyone).
	local head = character:FindFirstChild("Head")
	if head then
		local crown = Instance.new("Folder")
		crown.Name = "KingCrown"
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Shape = Enum.PartType.Cylinder
		band.Size = Vector3.new(0.6, 2.4, 2.4)
		band.Color = Color3.fromRGB(240, 196, 70)
		band.Material = Enum.Material.Metal
		band.Massless = true
		band.CanCollide = false
		band.CanQuery = false
		band.Parent = crown
		local bandWeld = Instance.new("Weld")
		bandWeld.Part0 = head
		bandWeld.Part1 = band
		bandWeld.C0 = CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90))
		bandWeld.Parent = band
		for i = 0, 4 do
			local angle = math.rad(i * 72)
			local spike = Instance.new("Part")
			spike.Name = "Spike"
			spike.Size = Vector3.new(0.3, 1, 0.3)
			spike.Color = Color3.fromRGB(255, 214, 90)
			spike.Material = Enum.Material.Neon
			spike.Massless = true
			spike.CanCollide = false
			spike.CanQuery = false
			spike.Parent = crown
			local weld = Instance.new("Weld")
			weld.Part0 = head
			weld.Part1 = spike
			weld.C0 = CFrame.new(math.cos(angle) * 1, 2.1, math.sin(angle) * 1)
			weld.Parent = spike
		end
		crown.Parent = character
	end

	-- The cutscene + HUD state for everyone.
	VFX:FireAllClients("KingCrown", { Character = character })
	HUDUpdate:FireClient(player, "UltState", true, Config.Ult.Duration)

	task.delay(Config.Ult.Duration, function()
		if kingTokens[player] == token then
			Tung.DeactivateUlt(player, character)
		end
	end)

	return true
end

function Tung.DeactivateUlt(player, character)
	if not character or not character.Parent or not isKing(character) then
		return
	end
	character:SetAttribute("KingMode", false)
	character:SetAttribute("BaseWalkSpeed", Config.Character.BaseWalkSpeed)
	character:SetAttribute("BaseJumpPower", Config.Character.BaseJumpPower)
	Combat.RefreshMovement(character)

	local highlight = character:FindFirstChild("KingHighlight")
	if highlight then
		highlight:Destroy()
	end
	local crown = character:FindFirstChild("KingCrown")
	if crown then
		crown:Destroy()
	end

	VFX:FireAllClients("KingCrownEnd", { Character = character })
	if player.Parent then
		HUDUpdate:FireClient(player, "UltState", false)
	end
end

-- ========================================================================
-- Skill dispatch
-- ========================================================================

local BASE_MOVES = { sahurSmash, tungBarrage, brainrotSpin, batCombo }
local KING_MOVES = { royalDecree, kingsJudgement, sahurRush, crownCrush }

function Tung.UseSkill(player, character, slot)
	if not Combat.IsActionable(character) then
		return nil
	end
	local king = isKing(character)
	local moveset = king and KING_MOVES or BASE_MOVES
	local cfg = king and MY.Ult[slot] or MY.Base[slot]
	local move = moveset[slot]
	if not move or not cfg then
		return nil
	end
	if move(player, character) == false then
		return nil
	end
	return cfg.Cooldown
end

function Tung.ForgetPlayer(player)
	m1State[player] = nil
	kingTokens[player] = nil
end

return Tung
