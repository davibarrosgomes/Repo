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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

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
