--[[
	AdminPanel.lua
	A hidden admin panel. Press  \  (backslash) to toggle it, type the code
	and submit. The code is validated on the server (AdminAuth); on success
	the server grants the Admin attribute, which unlocks the admin-only
	character in the select menu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local LocalPlayer = Players.LocalPlayer
local AdminAuth = Remotes.get("AdminAuth")

local BG = Color3.fromRGB(20, 20, 26)
local GOLD = Color3.fromRGB(230, 190, 80)

local AdminPanel = {}

local backdrop, statusLabel, codeBox

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function setOpen(open)
	backdrop.Visible = open
	if open then
		codeBox.Text = ""
		statusLabel.Text = "Enter the access code."
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
		codeBox:CaptureFocus()
	end
end

function AdminPanel.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanelGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Visible = false
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 220)
	panel.BackgroundColor3 = BG
	panel.Parent = backdrop
	corner(panel, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 16)
	title.Size = UDim2.new(1, -40, 0, 28)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = GOLD
	title.Text = "ADMIN PANEL"
	title.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(20, 50)
	statusLabel.Size = UDim2.new(1, -40, 0, 20)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	statusLabel.Text = "Enter the access code."
	statusLabel.Parent = panel

	codeBox = Instance.new("TextBox")
	codeBox.Position = UDim2.fromOffset(20, 82)
	codeBox.Size = UDim2.new(1, -40, 0, 44)
	codeBox.Font = Enum.Font.Gotham
	codeBox.TextSize = 16
	codeBox.TextColor3 = Color3.new(1, 1, 1)
	codeBox.PlaceholderText = "Access code"
	codeBox.Text = ""
	codeBox.ClearTextOnFocus = false
	codeBox.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
	codeBox.Parent = panel
	corner(codeBox, 8)

	local submit = Instance.new("TextButton")
	submit.AnchorPoint = Vector2.new(0.5, 1)
	submit.Position = UDim2.new(0.5, 0, 1, -16)
	submit.Size = UDim2.new(1, -40, 0, 42)
	submit.Font = Enum.Font.GothamBold
	submit.TextSize = 15
	submit.TextColor3 = Color3.fromRGB(20, 20, 20)
	submit.BackgroundColor3 = GOLD
	submit.Text = "AUTHENTICATE"
	submit.Parent = panel
	corner(submit, 8)

	local function trySubmit()
		if codeBox.Text ~= "" then
			statusLabel.Text = "Checking..."
			statusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
			AdminAuth:FireServer(codeBox.Text)
		end
	end
	submit.Activated:Connect(trySubmit)
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			trySubmit()
		end
	end)

	AdminAuth.OnClientEvent:Connect(function(granted)
		if granted then
			statusLabel.Text = "ACCESS GRANTED - the King is unlocked."
			statusLabel.TextColor3 = Color3.fromRGB(120, 230, 120)
			task.delay(1.2, function()
				setOpen(false)
			end)
		else
			statusLabel.Text = "ACCESS DENIED."
			statusLabel.TextColor3 = Color3.fromRGB(235, 90, 90)
			codeBox.Text = ""
		end
	end)

	backdrop.Activated:Connect(function()
		setOpen(false)
	end)

	-- Toggle with the backslash key.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Backslash then
			setOpen(not backdrop.Visible)
		end
	end)
end

return AdminPanel
