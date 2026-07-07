--[[
	init.client.lua
	Client entry point: input handling + HUD/VFX bootstrapping.

	Keyboard/Mouse:
		Left Mouse  - M1 combo         Q  - dash
		1 / 2 / 3 / 4 - skills          F (hold) - block
		G  - activate ult               K  - admin panel

	Gamepad (console):
		R2 - M1 combo                   L1 - dash
		DPad Up/Right/Down/Left - skills 1/2/3/4
		L2 (hold) - block               R1 - activate ult
		X  - character menu             A  - jump (default)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

-- Never let Roblox auto-select on-screen GUI when a controller is connected:
-- that switches the client into gamepad mode and disables mouse-click attacks.
-- We select GUI explicitly only inside menus (PLAY button, character cards).
GuiService.AutoSelectGuiEnabled = false

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local HUD = require(script.HUD)
local VFXClient = require(script.VFXClient)
local CharacterSelect = require(script.CharacterSelect)
local AdminPanel = require(script.AdminPanel)
local MainMenu = require(script.MainMenu)

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
	-- Gamepad: the D-pad maps to the four skills.
	[Enum.KeyCode.DPadUp] = 1,
	[Enum.KeyCode.DPadRight] = 2,
	[Enum.KeyCode.DPadDown] = 3,
	[Enum.KeyCode.DPadLeft] = 4,
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

	-- M1: left mouse or right trigger (R2).
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		if canAct() then
			M1:FireServer()
		end
		return
	end

	-- Ult: G or right bumper (R1).
	if input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonR1 then
		ActivateUlt:FireServer()
		return
	end

	-- Dash: Q or left bumper (L1).
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1 then
		if canAct() then
			Dash:FireServer()
		end
		return
	end

	-- Block: hold F or left trigger (L2).
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonL2 then
		Block:FireServer(true)
		return
	end

	-- Character menu: X on the gamepad (keyboard uses the topbar button).
	if input.KeyCode == Enum.KeyCode.ButtonX then
		CharacterSelect.Toggle()
		return
	end

	local slot = SKILL_KEYS[input.KeyCode]
	if slot and canAct() then
		UseSkill:FireServer(slot)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonL2 then
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
