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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Combat = require(script.Parent.Parent.CombatService)

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

-- Grip poses (relative to the limb). Tune these if a blade sits oddly on
-- your rig: the first CFrame is the position offset, the Angles is how the
-- blade is rotated. The blade is built along the katana's local +Y axis.
local RIGHT_GRIP = CFrame.new(0, 0, -0.7) * CFrame.Angles(math.rad(-95), 0, 0)
local LEFT_GRIP = CFrame.new(0, 0, -0.7) * CFrame.Angles(math.rad(-95), 0, 0)
local MOUTH_GRIP = CFrame.new(0, -0.45, -1) * CFrame.Angles(0, 0, math.rad(90))

local function makeBladePart(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Builds a katana and rigidly welds each piece to `limb` with an explicit
-- C0, so the blade is positioned deterministically (no unanchored fall
-- window like WeldConstraint has). Pieces stack along the grip's local +Y.
local function attachKatana(limb, gripC0, folder)
	local pieces = {
		{
			part = makeBladePart("Handle", Vector3.new(0.32, 1.4, 0.32), Color3.fromRGB(28, 28, 34), Enum.Material.SmoothPlastic),
			offset = CFrame.new(0, 0, 0),
		},
		{
			part = makeBladePart("Guard", Vector3.new(1.0, 0.2, 0.34), Color3.fromRGB(90, 70, 34), Enum.Material.Metal),
			offset = CFrame.new(0, 0.85, 0),
		},
		{
			part = makeBladePart("Blade", Vector3.new(0.16, 4.6, 0.52), Color3.fromRGB(222, 226, 234), Enum.Material.Metal),
			offset = CFrame.new(0, 3.2, 0),
		},
	}
	for _, entry in pieces do
		local part = entry.part
		part.Parent = folder
		local weld = Instance.new("Weld")
		weld.Part0 = limb
		weld.Part1 = part
		weld.C0 = gripC0 * entry.offset
		weld.Parent = part
	end
end

-- Called by the server (in a task.spawn) when a Zoro character spawns.
function Zoro.Setup(_player, character)
	-- Body parts can stream in slightly after the Humanoid; wait for them.
	local rightHand = character:WaitForChild("RightHand", 5) or character:FindFirstChild("Right Arm")
	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	local head = character:FindFirstChild("Head")
	if not character.Parent then
		return
	end

	-- Never stack duplicates when the character is set up more than once.
	local existing = character:FindFirstChild("Santoryu")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Santoryu"
	folder.Parent = character

	if rightHand then
		attachKatana(rightHand, RIGHT_GRIP, folder)
	end
	if leftHand then
		attachKatana(leftHand, LEFT_GRIP, folder)
	end
	if head then
		-- Wado Ichimonji held horizontally in his mouth.
		attachKatana(head, MOUTH_GRIP, folder)
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
