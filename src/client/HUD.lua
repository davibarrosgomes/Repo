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
local ACCENT_BASE = Color3.fromRGB(220, 60, 60)   -- straw hat red
local ACCENT_GEAR5 = Color3.fromRGB(255, 255, 255)
local ULT_COLOR = Color3.fromRGB(255, 200, 60)

local HUD = {}

local slots = {}       -- [slot] = { frame, nameLabel, cooldownOverlay, cooldownLabel }
local ultFill, ultLabel, ultBar
local gear5Active = false

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function slotName(slot)
	local cfg = gear5Active and Config.Gear5[slot] or Config.Base[slot]
	return cfg and cfg.Name or "?"
end

local function refreshSlotNames()
	for slot, ui in slots do
		ui.nameLabel.Text = slotName(slot)
		ui.keyLabel.TextColor3 = gear5Active and ACCENT_GEAR5 or ACCENT_BASE
		ui.stroke.Color = gear5Active and ACCENT_GEAR5 or ACCENT_BASE
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
		stroke.Color = ACCENT_BASE
		stroke.Thickness = 1.5
		stroke.Transparency = 0.3
		stroke.Parent = frame

		local keyLabel = Instance.new("TextLabel")
		keyLabel.BackgroundTransparency = 1
		keyLabel.Position = UDim2.new(0, 6, 0, 4)
		keyLabel.Size = UDim2.new(0, 24, 0, 24)
		keyLabel.Font = Enum.Font.GothamBlack
		keyLabel.TextSize = 20
		keyLabel.TextColor3 = ACCENT_BASE
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

	refreshSlotNames()

	-- Ult charge is an attribute on the player, kept up to date by the server.
	local function onCharge()
		HUD.SetUltCharge(LocalPlayer:GetAttribute("UltCharge") or 0)
	end
	LocalPlayer:GetAttributeChangedSignal("UltCharge"):Connect(onCharge)
	onCharge()
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

function HUD.ClearCooldowns()
	for _, ui in slots do
		ui.cooldownToken += 1
		ui.cooldownLabel.Text = ""
		ui.overlay.Size = UDim2.new(1, 0, 0, 0)
	end
end

function HUD.SetUltCharge(charge)
	local ratio = math.clamp(charge / Config.Ult.MaxCharge, 0, 1)
	TweenService:Create(ultFill, TweenInfo.new(0.2), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
	if gear5Active then
		ultLabel.Text = "GEAR 5"
	elseif ratio >= 1 then
		ultLabel.Text = "GEAR 5 READY - PRESS G"
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
		ultLabel.Text = "GEAR 5"
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
