--[[
	MainMenu.lua
	The title screen shown when you enter the game: a cinematic camera slowly
	orbits high above Onigashima while the title and a PLAY button are overlaid.
	Player controls and the combat HUD are locked/hidden until PLAY is pressed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local RED = Color3.fromRGB(220, 60, 60)
local GOLD = Color3.fromRGB(240, 200, 90)

local MainMenu = {}

local orbiting = false
local controls

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

-- Try to disable/enable the default player movement controls.
local function getControls()
	if controls then
		return controls
	end
	local ok, playerModule = pcall(function()
		return require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and playerModule then
		local gotControls
		pcall(function()
			gotControls = playerModule:GetControls()
		end)
		controls = gotControls
	end
	return controls
end

local function setGuiEnabled(name, enabled)
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local target = gui and gui:FindFirstChild(name)
	if target then
		target.Enabled = enabled
	end
end

-- Cinematic aerial orbit high above the island, looking down at it.
local function startOrbit()
	local center = Vector3.new(0, 30, -50)
	local height = 480
	local radius = 220
	local angle = 0
	orbiting = true
	Camera.CameraType = Enum.CameraType.Scriptable
	-- BindToRenderStep returns nothing, so track state with a flag and stop
	-- driving the camera once the orbit ends (the bound fn can fire one more
	-- time after Unbind is requested).
	RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not orbiting then
			return
		end
		angle += dt * 0.05
		local pos = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		Camera.CFrame = CFrame.lookAt(pos, center)
	end)
end

local function stopOrbit()
	orbiting = false
	pcall(function()
		RunService:UnbindFromRenderStep("MenuCamera")
	end)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	Camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		Camera.CameraSubject = humanoid
	end
end

function MainMenu.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenuGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Take over the camera + lock the player.
	startOrbit()
	local c = getControls()
	if c then
		c:Disable()
	end
	setGuiEnabled("CombatHUD", false)
	setGuiEnabled("CharacterSelectGui", false)

	-- Edge vignette so the overlay text stays readable over the island.
	local vignetteTop = Instance.new("Frame")
	vignetteTop.Size = UDim2.new(1, 0, 0.45, 0)
	vignetteTop.BackgroundColor3 = Color3.new(0, 0, 0)
	vignetteTop.BorderSizePixel = 0
	vignetteTop.Parent = gui
	local gradTop = Instance.new("UIGradient")
	gradTop.Rotation = 90
	gradTop.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradTop.Parent = vignetteTop

	local vignetteBottom = Instance.new("Frame")
	vignetteBottom.AnchorPoint = Vector2.new(0, 1)
	vignetteBottom.Position = UDim2.new(0, 0, 1, 0)
	vignetteBottom.Size = UDim2.new(1, 0, 0.5, 0)
	vignetteBottom.BackgroundColor3 = Color3.new(0, 0, 0)
	vignetteBottom.BorderSizePixel = 0
	vignetteBottom.Parent = gui
	local gradBottom = Instance.new("UIGradient")
	gradBottom.Rotation = 90
	gradBottom.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	gradBottom.Parent = vignetteBottom

	-- Title.
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.14, 0)
	title.Size = UDim2.new(0.9, 0, 0, 90)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeColor3 = Color3.fromRGB(40, 0, 0)
	title.TextStrokeTransparency = 0.2
	title.Text = "ONE PIECE"
	title.Parent = gui
	local titleGrad = Instance.new("UIGradient")
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 60)),
	})
	titleGrad.Rotation = 90
	titleGrad.Parent = title

	local title2 = Instance.new("TextLabel")
	title2.AnchorPoint = Vector2.new(0.5, 0)
	title2.Position = UDim2.new(0.5, 0, 0.14, 84)
	title2.Size = UDim2.new(0.9, 0, 0, 70)
	title2.BackgroundTransparency = 1
	title2.Font = Enum.Font.GothamBlack
	title2.TextScaled = true
	title2.TextColor3 = RED
	title2.TextStrokeColor3 = Color3.new(0, 0, 0)
	title2.TextStrokeTransparency = 0.3
	title2.Text = "BATTLEGROUNDS"
	title2.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0.14, 162)
	subtitle.Size = UDim2.new(0.6, 0, 0, 22)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(220, 220, 230)
	subtitle.Text = "The island of Onigashima"
	subtitle.Parent = gui

	-- PLAY button.
	local play = Instance.new("TextButton")
	play.AnchorPoint = Vector2.new(0.5, 1)
	play.Position = UDim2.new(0.5, 0, 0.82, 0)
	play.Size = UDim2.new(0, 260, 0, 64)
	play.BackgroundColor3 = RED
	play.Font = Enum.Font.GothamBlack
	play.TextSize = 26
	play.TextColor3 = Color3.new(1, 1, 1)
	play.Text = "PLAY"
	play.AutoButtonColor = true
	play.Parent = gui
	corner(play, 14)
	local playStroke = Instance.new("UIStroke")
	playStroke.Color = Color3.new(1, 1, 1)
	playStroke.Thickness = 2
	playStroke.Transparency = 0.3
	playStroke.Parent = play

	-- A gentle pulse on the PLAY button.
	task.spawn(function()
		while play.Parent do
			TweenService:Create(play, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Size = UDim2.new(0, 274, 0, 68) }):Play()
			task.wait(0.8)
			TweenService:Create(play, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Size = UDim2.new(0, 260, 0, 64) }):Play()
			task.wait(0.8)
		end
	end)

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.83, 6)
	hint.Size = UDim2.new(0.5, 0, 0, 18)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextScaled = true
	hint.TextColor3 = Color3.fromRGB(200, 200, 210)
	hint.Text = "KBM:  LMB attack · 1-4 skills · Q dash · F block · G ult      Gamepad:  R2 attack · DPad skills · L1 dash · L2 block · R1 ult · X menu"
	hint.Parent = gui

	local function play_pressed()
		play.Active = false
		-- Release GUI focus so gameplay uses mouse/keyboard normally again.
		GuiService.SelectedObject = nil
		stopOrbit()
		local c2 = getControls()
		if c2 then
			c2:Enable()
		end
		setGuiEnabled("CombatHUD", true)
		setGuiEnabled("CharacterSelectGui", true)
		-- Fade the whole menu out.
		for _, obj in gui:GetDescendants() do
			if obj:IsA("TextLabel") or obj:IsA("TextButton") then
				TweenService:Create(obj, TweenInfo.new(0.35), { TextTransparency = 1, BackgroundTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif obj:IsA("Frame") then
				TweenService:Create(obj, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(0.4, function()
			gui:Destroy()
		end)
	end

	play.Activated:Connect(play_pressed)

	-- Gamepad: pre-select PLAY so console players can press A to start.
	if GuiService.GamepadEnabled then
		GuiService.SelectedObject = play
	end
end

return MainMenu
