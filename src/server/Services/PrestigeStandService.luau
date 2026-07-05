--!strict
-- Keeps the physical prestige showcase near spawn (see WorldBuilderService.
-- buildPrestigeShowcase) updated with the server's current top lifetime donors - a
-- physical "leaderboard" reinforcing the game's core status loop (design doc: "the
-- higher server you go, the richer the people are") made visible within a single
-- server, not just on a menu. Read-only: donations still route to a player's own
-- regular stand (see StandService.luau) regardless of whether they're shown here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local RankConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RankConfig)

local PlayerDataService = require(script.Parent.PlayerDataService)

local PRESTIGE_TAG = "PrestigeStand"
local UPDATE_INTERVAL_SECONDS = 45

local PrestigeStandService = {}

local function getPedestalsSortedByRank(): { Model }
	local pedestals = {}
	for _, instance in CollectionService:GetTagged(PRESTIGE_TAG) do
		if instance:IsA("Model") then
			table.insert(pedestals, instance)
		end
	end
	table.sort(pedestals, function(a, b)
		local rankA = (a:GetAttribute("Rank") :: number?) or 0
		local rankB = (b:GetAttribute("Rank") :: number?) or 0
		return rankA < rankB
	end)
	return pedestals
end

local function updatePedestal(pedestal: Model, player: Player?, amount: number?)
	local sign = pedestal:FindFirstChild("Sign", true)
	if not sign then
		return
	end

	local nameLabel = sign:FindFirstChild("NameLabel") :: TextLabel?
	local titleLabel = sign:FindFirstChild("TitleLabel") :: TextLabel?
	local amountLabel = sign:FindFirstChild("AmountLabel") :: TextLabel?
	local rankPlate = pedestal:FindFirstChild("RankPlate") :: BasePart?

	if not player or not amount or amount <= 0 then
		if nameLabel then
			nameLabel.Text = "Unclaimed"
			nameLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
		end
		if titleLabel then
			titleLabel.Text = ""
		end
		if amountLabel then
			amountLabel.Text = ""
		end
		if rankPlate then
			rankPlate.Color = Color3.fromRGB(150, 150, 150)
		end
		return
	end

	local rankName = player:GetAttribute("RankName")
	local rank = (type(rankName) == "string" and RankConfig.getRankByName(rankName)) or RankConfig.Ranks[1]
	local title = player:GetAttribute("RankTitle")

	if nameLabel then
		nameLabel.Text = player.Name
		nameLabel.TextColor3 = rank.color
	end
	if titleLabel then
		titleLabel.Text = (type(title) == "string" and title) or rank.title
	end
	if amountLabel then
		amountLabel.Text = `{amount} R$ raised`
	end
	if rankPlate then
		rankPlate.Color = rank.color
	end
end

local function refresh()
	local pedestals = getPedestalsSortedByRank()
	if #pedestals == 0 then
		return
	end

	local ranked = {}
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.get(player)
		if profile and profile.totalReceivedRobux > 0 then
			table.insert(ranked, { player = player, amount = profile.totalReceivedRobux })
		end
	end
	table.sort(ranked, function(a, b)
		return a.amount > b.amount
	end)

	for i, pedestal in pedestals do
		local entry = ranked[i]
		updatePedestal(pedestal, entry and entry.player, entry and entry.amount)
	end
end

function PrestigeStandService.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(UPDATE_INTERVAL_SECONDS)
		end
	end)
end

return PrestigeStandService
