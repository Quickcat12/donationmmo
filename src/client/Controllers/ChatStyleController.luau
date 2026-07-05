--!strict
-- Restyles Roblox's default chat (window + bubbles) to match this game's dark/gold
-- theme, since default-styled chat looks out of place next to a custom HUD. Purely
-- client-local - every client renders chat visuals independently, so no server
-- involvement or replication is needed for this.
--
-- Each config object is touched inside its own pcall: these are plain Instance
-- properties on TextChatService's config objects, and if a property name ever shifts
-- in a future Roblox chat update, this should degrade to "chat looks default" rather
-- than throw and abort every controller that requires after this one in Main.client.luau.

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Util.Theme)

local ChatStyleController = {}

local function getOrCreate(className: string): Instance
	local existing = TextChatService:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Parent = TextChatService
	return instance
end

function ChatStyleController.start()
	pcall(function()
		local windowConfig = getOrCreate("ChatWindowConfiguration") :: any
		windowConfig.BackgroundColor3 = Theme.Background
		windowConfig.BackgroundTransparency = 0.25
		windowConfig.TextColor3 = Theme.TextPrimary
		windowConfig.Font = Enum.Font.Gotham
	end)

	pcall(function()
		local bubbleConfig = getOrCreate("BubbleChatConfiguration") :: any
		bubbleConfig.BackgroundColor3 = Theme.Panel
		bubbleConfig.TextColor3 = Theme.TextPrimary
		bubbleConfig.CornerRadius = UDim.new(0, 12)
		bubbleConfig.TailVisible = true
		bubbleConfig.Font = Enum.Font.Gotham
		bubbleConfig.VerticalStudsOffset = 3
	end)
end

return ChatStyleController
