--!strict
-- The menu rail every panel opens from: one column of rounded icon buttons with short
-- labels, down the left edge of the screen. Built for touch first - phones have no
-- keyboard and single letters ("Q", "W") mean nothing to new players, while an icon plus
-- a word is self-explanatory. The left edge stays clear of Roblox's mobile thumbstick
-- (bottom-left) and jump button (bottom-right).
--
-- Opening a panel closes the others, since small screens can't fit two at once, and
-- every registered UI scales with the viewport so panels designed at 1080p still fit a
-- landscape phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

export type ButtonSpec = {
	id: string,
	icon: string, -- an emoji glyph; renders crisply at any size with no image upload
	label: string,
	order: number,
	accent: Color3?,
	panel: GuiObject?, -- toggled exclusively when the button is pressed
	onClick: (() -> ())?, -- used instead of `panel` for custom behavior
}

local Dock = {}

local BUTTON = 62
local GAP = 8
-- The layout is designed against a 720px-tall viewport; smaller screens scale down.
local DESIGN_HEIGHT = 720

local rail: Frame? = nil
local panels: { GuiObject } = {}
local scaled: { { scale: UIScale, min: number } } = {}
local badges: { [string]: TextLabel } = {}

-- The widest fixed element (streak chip + HUD bar) is ~560px; keep it on screen in
-- portrait too, where height alone would leave it at full size and clipped.
local DESIGN_WIDTH = 760

local function currentScale(): number
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(DESIGN_WIDTH, DESIGN_HEIGHT)
	return math.clamp(math.min(size.Y / DESIGN_HEIGHT, size.X / DESIGN_WIDTH), 0.45, 1.15)
end

local function refreshScale()
	local s = currentScale()
	for _, entry in scaled do
		entry.scale.Scale = math.max(s, entry.min)
	end
end

-- Adds a viewport-driven UIScale to any GuiObject (panels, the HUD bar...).
-- `minScale` keeps touch targets usable: the dock never shrinks below ~48pt buttons.
function Dock.autoScale(object: GuiObject, minScale: number?)
	local existing = object:FindFirstChild("ResponsiveScale")
	local scale: UIScale = if existing and existing:IsA("UIScale") then existing else Instance.new("UIScale")
	scale.Name = "ResponsiveScale"
	scale.Parent = object
	table.insert(scaled, { scale = scale, min = minScale or 0 })
	refreshScale()
end

local function ensureRail(): Frame
	if rail then
		return rail
	end
	local screen = UICreate("ScreenGui", {
		Name = "Dock",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui

	local frame = UICreate("Frame", {
		Name = "Rail",
		BackgroundTransparency = 1,
		Parent = screen,
	}) :: Frame
	local grid = UICreate("UIGridLayout", {
		CellSize = UDim2.fromOffset(BUTTON, BUTTON),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		Parent = frame,
	}) :: UIGridLayout
	rail = frame
	Dock.autoScale(frame, 0.78)

	-- Tall screens (desktop/tablet): one column down the left edge. Short screens
	-- (landscape phones): one row along the bottom center, in the free space between
	-- the thumbstick (bottom-left) and the jump button (bottom-right). Never stacked.
	local function layout()
		local camera = Workspace.CurrentCamera
		local height = camera and camera.ViewportSize.Y or DESIGN_HEIGHT
		local compact = height < 600
		local count = 0
		for _, child in frame:GetChildren() do
			if child:IsA("GuiButton") then
				count += 1
			end
		end
		count = math.max(count, 1)
		if compact then
			grid.FillDirection = Enum.FillDirection.Horizontal
			grid.FillDirectionMaxCells = count
			frame.Size = UDim2.fromOffset(count * BUTTON + (count - 1) * GAP, BUTTON)
			frame.AnchorPoint = Vector2.new(0.5, 1)
			frame.Position = UDim2.new(0.5, 0, 1, -8)
		else
			grid.FillDirection = Enum.FillDirection.Vertical
			grid.FillDirectionMaxCells = count
			frame.Size = UDim2.fromOffset(BUTTON, count * BUTTON + (count - 1) * GAP)
			frame.AnchorPoint = Vector2.new(0, 0.5)
			frame.Position = UDim2.new(0, 12, 0.55, 0)
		end
	end
	layout()
	frame.ChildAdded:Connect(layout)

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			refreshScale()
			layout()
		end)
	end
	return frame
end

function Dock.closeAll(except: GuiObject?)
	for _, panel in panels do
		if panel ~= except then
			panel.Visible = false
		end
	end
end

-- Registers a panel so it participates in "one open at a time" and scales on mobile.
function Dock.registerPanel(panel: GuiObject)
	if table.find(panels, panel) then
		return
	end
	table.insert(panels, panel)
	Dock.autoScale(panel)
	-- Every panel gets the same big close button: on a phone there's no Escape key and
	-- reaching back to the rail to close is awkward.
	if not panel:FindFirstChild("DockClose") then
		local close = UICreate("TextButton", {
			Name = "DockClose",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = Theme.Danger,
			Text = "X",
			Font = Theme.Font,
			TextSize = 20,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			ZIndex = 20,
			Parent = panel,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextButton
		close.Activated:Connect(function()
			panel.Visible = false
		end)
	end
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			Dock.closeAll(panel)
		end
	end)
end

function Dock.toggle(panel: GuiObject)
	panel.Visible = not panel.Visible
end

-- A small red count bubble on a button (e.g. claimable quests). nil/0 hides it.
function Dock.setBadge(id: string, count: number?)
	local badge = badges[id]
	if not badge then
		return
	end
	local n = count or 0
	badge.Visible = n > 0
	badge.Text = if n > 9 then "9+" else tostring(n)
end

function Dock.addButton(spec: ButtonSpec): TextButton
	local frame = ensureRail()
	local accent = spec.accent or Theme.Accent

	local button = UICreate("TextButton", {
		Name = spec.id,
		LayoutOrder = spec.order,
		Size = UDim2.fromOffset(BUTTON, BUTTON),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.08,
		AutoButtonColor = false,
		Text = "",
		Parent = frame,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 16) }),
		UICreate("UIStroke", { Color = accent, Transparency = 0.55, Thickness = 2 }),
		UICreate("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 210)),
		}),
		UICreate("TextLabel", {
			Name = "Icon",
			Position = UDim2.fromOffset(0, 5),
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			Text = spec.icon,
			TextSize = 28,
			Font = Theme.Font,
			TextColor3 = Theme.TextPrimary,
		}),
		UICreate("TextLabel", {
			Name = "Label",
			Position = UDim2.new(0, 2, 1, -21),
			Size = UDim2.new(1, -4, 0, 16),
			BackgroundTransparency = 1,
			Text = spec.label,
			TextScaled = true,
			Font = Theme.Font,
			TextColor3 = accent,
		}, { UICreate("UITextSizeConstraint", { MaxTextSize = 13 }) }),
	}) :: TextButton

	badges[spec.id] = UICreate("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Theme.Danger,
		Text = "",
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextLabel

	-- Press feedback that works the same for a mouse click and a finger tap.
	local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
	local function pulse(down: boolean)
		TweenService:Create(button, TweenInfo.new(0.08), {
			BackgroundColor3 = down and Theme.PanelLight or Theme.Panel,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.08), { Transparency = down and 0.1 or 0.55 }):Play()
	end
	button.MouseButton1Down:Connect(function()
		pulse(true)
	end)
	button.MouseButton1Up:Connect(function()
		pulse(false)
	end)
	button.MouseLeave:Connect(function()
		pulse(false)
	end)

	button.Activated:Connect(function()
		if spec.panel then
			Dock.toggle(spec.panel)
		elseif spec.onClick then
			spec.onClick()
		end
	end)

	if spec.panel then
		Dock.registerPanel(spec.panel)
	end
	return button
end

return Dock
