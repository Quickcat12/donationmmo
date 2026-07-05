--!strict
-- Server bootstrap. Order matters: Net.bootstrap() must run first so remotes exist,
-- and every service that listens for PlayerDataService.DataLoaded must connect its
-- listener before PlayerDataService.start() runs (started last) so no early joiners
-- are missed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net.Net)

Net.bootstrap()

local Services = script.Parent.Services

local WorldBuilderService = require(Services.WorldBuilderService)
local VIPService = require(Services.VIPService)
local ServerBoostService = require(Services.ServerBoostService)
local XPService = require(Services.XPService)
local StandService = require(Services.StandService)
local PrestigeStandService = require(Services.PrestigeStandService)
local CheckpointService = require(Services.CheckpointService)
local DonationService = require(Services.DonationService)
local XPShopService = require(Services.XPShopService)
local WorldService = require(Services.WorldService)
local QuestService = require(Services.QuestService)
local ObbyService = require(Services.ObbyService)
local LeaderboardService = require(Services.LeaderboardService)
local CosmeticService = require(Services.CosmeticService)
local WorldPopulationService = require(Services.WorldPopulationService)
local PlayerDataService = require(Services.PlayerDataService)

-- Must run before StandService.start(), which scans for already-placed stands.
WorldBuilderService.build()

VIPService.start()
ServerBoostService.start()
XPService.start()
StandService.start()
PrestigeStandService.start()
CheckpointService.start()
DonationService.start()
XPShopService.start()
WorldService.start()
QuestService.start()
ObbyService.start()
LeaderboardService.start()
CosmeticService.start()
WorldPopulationService.start()

-- Must start last: fires DataLoaded for every current/joining player, and every other
-- service above needs to already be listening for that signal.
PlayerDataService.start()
