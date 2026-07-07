--[[
	CharacterSelect.lua
	A topbar button (sitting beside the core chat button) that opens a
	character-select menu built from Config.Roster. Selecting an unlocked
	character tells the server, which reassigns the moveset and respawns.
	Locked characters show as "COMING SOON".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local LocalPlayer = Players.LocalPlayer
local SelectCharacter = Remotes.get("SelectCharacter")

local BG = Color3.fromRGB(25, 25, 30)
local PANEL = Color3.fromRGB(32, 32, 40)
local ACCENT = Color3.fromRGB(220, 60, 60)
local LOCKED = Color3.fromRGB(90, 90, 100)

local CharacterSelect = {}

local cards = {} -- [id] = { select button, stroke, statusLabel }
local panel, backdrop, topButton, scroller

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function pad(instance, px)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = instance
end

-- ========================================================================
-- Selection state
-- ========================================================================

local function currentId()
	return LocalPlayer:GetAttribute("SelectedCharacter") or "Luffy"
end

local function refreshStates()
	local selected = currentId()
	for _, entry in Config.Roster do
		local card = cards[entry.Id]
		if card then
			local ownsEA = entry.EarlyAccess and LocalPlayer:GetAttribute("Owns_" .. entry.Id) == true
			if entry.Locked then
				card.stroke.Enabled = false
			elseif entry.EarlyAccess and not ownsEA then
				-- Not purchased yet: show the early-access buy state.
				card.button.Text = "EARLY ACCESS"
				card.button.BackgroundColor3 = Color3.fromRGB(230, 175, 60)
				card.button.TextColor3 = Color3.fromRGB(30, 25, 10)
				card.stroke.Enabled = false
			elseif entry.Id == selected then
				card.button.Text = "SELECTED"
				card.button.BackgroundColor3 = entry.Color
				card.button.TextColor3 = Color3.new(1, 1, 1)
				card.stroke.Enabled = true
				card.stroke.Color = entry.Color
			else
				card.button.Text = "SELECT"
				card.button.BackgroundColor3 = BG
				card.button.TextColor3 = Color3.new(1, 1, 1)
				card.stroke.Enabled = false
			end
		end
	end
	-- Tint the topbar button to the current character's color.
	local entry
	for _, e in Config.Roster do
		if e.Id == selected then
			entry = e
			break
		end
	end
	if topButton and entry then
		topButton.Text = entry.Name:sub(1, 1)
		topButton.BackgroundColor3 = entry.Color
	end
end

-- ========================================================================
-- Open / close
-- ========================================================================

local function setOpen(open)
	backdrop.Visible = open
	if open then
		refreshStates()
		panel.Size = UDim2.fromOffset(0, 0)
		panel.BackgroundTransparency = 1
		TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(720, 460),
			BackgroundTransparency = 0,
		}):Play()
		-- Gamepad: focus a card so console players can navigate with the stick.
		if GuiService.GamepadEnabled then
			local first = next(cards) and cards[next(cards)]
			GuiService.SelectedObject = first and first.button or nil
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(backdrop) then
		GuiService.SelectedObject = nil
	end
end

-- Open/close the menu (used by the topbar button and the gamepad X button).
function CharacterSelect.Toggle()
	if backdrop then
		setOpen(not backdrop.Visible)
	end
end

-- ========================================================================
-- Card construction
-- ========================================================================

local function buildCard(entry, parent, order)
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.fromOffset(196, 356)
	card.BackgroundColor3 = PANEL
	card.Parent = parent
	corner(card, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = entry.Color
	stroke.Thickness = 2.5
	stroke.Enabled = false
	stroke.Parent = card

	-- Color header with an initial as a stand-in portrait.
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 96)
	header.BackgroundColor3 = entry.Locked and LOCKED or entry.Color
	header.BorderSizePixel = 0
	header.Parent = card
	corner(header, 10)

	local initial = Instance.new("TextLabel")
	initial.BackgroundTransparency = 1
	initial.Size = UDim2.new(1, 0, 1, 0)
	initial.Font = Enum.Font.GothamBlack
	initial.TextSize = 54
	initial.TextColor3 = Color3.new(1, 1, 1)
	initial.TextTransparency = 0.15
	initial.Text = entry.Locked and "?" or entry.Name:sub(1, 1)
	initial.Parent = header

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 10, 0, 104)
	name.Size = UDim2.new(1, -20, 0, 20)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = entry.Locked and "???" or entry.Name
	name.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 10, 0, 124)
	title.Size = UDim2.new(1, -20, 0, 16)
	title.Font = Enum.Font.Gotham
	title.TextSize = 11
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = entry.Color
	title.Text = entry.Locked and "Locked" or entry.Title
	title.Parent = card

	-- Move list.
	local moves = Instance.new("TextLabel")
	moves.BackgroundTransparency = 1
	moves.Position = UDim2.new(0, 10, 0, 146)
	moves.Size = UDim2.new(1, -20, 0, 150)
	moves.Font = Enum.Font.Gotham
	moves.TextSize = 11
	moves.TextXAlignment = Enum.TextXAlignment.Left
	moves.TextYAlignment = Enum.TextYAlignment.Top
	moves.TextColor3 = Color3.fromRGB(200, 200, 210)
	moves.RichText = true
	moves.TextWrapped = true
	if entry.Locked then
		moves.Text = "Moveset hidden until\nthis fighter is released."
		moves.TextColor3 = Color3.fromRGB(150, 150, 160)
	else
		local lines = {}
		for i, move in entry.Moves do
			table.insert(lines, ("<b>%d</b>  %s"):format(i, move))
		end
		table.insert(lines, ("<b>ULT</b>  %s"):format(entry.Ult or "—"))
		moves.Text = table.concat(lines, "\n")
	end
	moves.Parent = card

	-- Select / locked button.
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -10)
	button.Size = UDim2.new(1, -20, 0, 34)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = not entry.Locked
	button.Parent = card
	corner(button, 7)

	if entry.Locked then
		button.Text = "COMING SOON"
		button.BackgroundColor3 = LOCKED
		button.Active = false
	else
		button.Text = "SELECT"
		button.BackgroundColor3 = BG
		button.Activated:Connect(function()
			SelectCharacter:FireServer(entry.Id)
			setOpen(false)
		end)
	end

	cards[entry.Id] = { button = button, stroke = stroke }
end

-- ========================================================================
-- Build
-- ========================================================================

function CharacterSelect.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CharacterSelectGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Topbar button, sitting just right of the core chat button.
	local BUTTON_SIZE = 32
	topButton = Instance.new("TextButton")
	topButton.Name = "CharacterButton"
	topButton.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	topButton.Font = Enum.Font.GothamBlack
	topButton.TextSize = 18
	topButton.TextColor3 = Color3.new(1, 1, 1)
	topButton.Text = "L"
	topButton.BackgroundColor3 = ACCENT
	topButton.AutoButtonColor = true
	topButton.Selectable = false -- never steal gamepad focus during combat
	topButton.Parent = gui
	corner(topButton, 16)

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Color3.new(1, 1, 1)
	topStroke.Thickness = 1.5
	topStroke.Transparency = 0.4
	topStroke.Parent = topButton

	local tip = Instance.new("TextLabel")
	tip.BackgroundTransparency = 1
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Position = UDim2.new(0.5, 0, 1, 2)
	tip.Size = UDim2.fromOffset(80, 12)
	tip.Font = Enum.Font.GothamMedium
	tip.TextSize = 9
	tip.TextColor3 = Color3.fromRGB(220, 220, 230)
	tip.TextStrokeTransparency = 0.5
	tip.Text = "CHARACTER"
	tip.Parent = topButton

	-- Place the button just right of the core topbar buttons (menu + chat).
	-- GuiService.TopbarInset reports the region NOT covered by Roblox's own
	-- topbar, so TopbarInset.Min.X is exactly where our safe area begins.
	local function positionButton()
		local inset = GuiService.TopbarInset
		if inset and inset.Width > 0 and inset.Min.X > 0 then
			local y = inset.Min.Y + (inset.Height - BUTTON_SIZE) / 2
			topButton.Position = UDim2.fromOffset(inset.Min.X + 8, math.max(2, y))
		else
			-- Fallback for clients without a reported inset.
			topButton.Position = UDim2.fromOffset(176, 4)
		end
	end
	positionButton()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(positionButton)

	-- Modal backdrop.
	backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Visible = false
	backdrop.Parent = gui

	-- Panel.
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(720, 460)
	panel.BackgroundColor3 = BG
	panel.Parent = backdrop
	corner(panel, 14)
	pad(panel, 16)

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Size = UDim2.new(1, 0, 0, 30)
	heading.Font = Enum.Font.GothamBlack
	heading.TextSize = 22
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = Color3.new(1, 1, 1)
	heading.Text = "SELECT CHARACTER"
	heading.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, 0, 0, 0)
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "X"
	closeButton.BackgroundColor3 = ACCENT
	closeButton.Parent = panel
	corner(closeButton, 7)

	-- Scrolling row of cards.
	scroller = Instance.new("ScrollingFrame")
	scroller.Position = UDim2.new(0, 0, 0, 42)
	scroller.Size = UDim2.new(1, 0, 1, -42)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.ScrollBarThickness = 6
	scroller.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = scroller

	CharacterSelect.RebuildCards()

	-- Wiring.
	topButton.Activated:Connect(function()
		setOpen(not backdrop.Visible)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	backdrop.Activated:Connect(function()
		setOpen(false)
	end)
	LocalPlayer:GetAttributeChangedSignal("SelectedCharacter"):Connect(refreshStates)
	-- Reveal the admin character the moment access is granted.
	LocalPlayer:GetAttributeChangedSignal("Admin"):Connect(CharacterSelect.RebuildCards)
	-- Update early-access cards when ownership is confirmed / purchased.
	for _, entry in Config.Roster do
		if entry.EarlyAccess then
			LocalPlayer:GetAttributeChangedSignal("Owns_" .. entry.Id):Connect(refreshStates)
		end
	end

	refreshStates()
end

-- Builds the card row, skipping admin-only characters unless the local
-- player has been granted admin access.
function CharacterSelect.RebuildCards()
	if not scroller then
		return
	end
	for _, child in scroller:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(cards)

	local isAdmin = LocalPlayer:GetAttribute("Admin") == true
	local order = 0
	for _, entry in Config.Roster do
		if not entry.Admin or isAdmin then
			order += 1
			buildCard(entry, scroller, order)
		end
	end
	refreshStates()
end

return CharacterSelect
