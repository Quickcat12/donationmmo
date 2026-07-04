--!strict
-- Prefixes incoming chat messages with the sender's rank tag, e.g. "[DIAMOND] Name: ...",
-- colored per RankConfig. Reads the RankName/RankColor/ShowChatTag Player Attributes that
-- CosmeticService (server) publishes - those replicate for free, so no remote is needed
-- just to render chat.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTagController = {}

local function buildPrefix(player: Player): string?
	local showTag = player:GetAttribute("ShowChatTag")
	if showTag == false then
		return nil
	end

	local rankName = player:GetAttribute("RankName")
	local rankColor = player:GetAttribute("RankColor")
	if type(rankName) ~= "string" or typeof(rankColor) ~= "Color3" then
		return nil
	end

	return `<font color="#{rankColor:ToHex()}">[{string.upper(rankName)}]</font> `
end

local function onIncomingMessage(message: TextChatMessage): TextChatMessageProperties
	local properties = Instance.new("TextChatMessageProperties")

	local source = message.TextSource
	local player = source and Players:GetPlayerByUserId(source.UserId)
	if player then
		local prefix = buildPrefix(player)
		if prefix then
			properties.PrefixText = prefix .. message.PrefixText
		end
	end

	return properties
end

local function hookChannel(channel: Instance)
	if channel:IsA("TextChannel") then
		channel.OnIncomingMessage = onIncomingMessage
	end
end

function ChatTagController.start()
	for _, channel in TextChatService.TextChannels:GetChildren() do
		hookChannel(channel)
	end
	TextChatService.TextChannels.ChildAdded:Connect(hookChannel)
end

return ChatTagController
