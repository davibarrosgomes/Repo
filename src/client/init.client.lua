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
