--!strict
-- Hooks the physical "Lobby Teleporter" portal (see WorldBuilderService.buildTeleporter)
-- up to the world-select panel. Purely a client-side convenience - opening a menu isn't
-- security-sensitive, so no remote round trip is needed here (the actual travel request
-- is still re-validated server-side in WorldService.luau).

local CollectionService = game:GetService("CollectionService")

local WorldSelectController = require(script.Parent.WorldSelectController)

local TELEPORTER_PROMPT_TAG = "WorldTeleporterPrompt"

local TeleporterController = {}

local function hookPrompt(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	instance.Triggered:Connect(function()
		WorldSelectController.open()
	end)
end

function TeleporterController.start()
	for _, instance in CollectionService:GetTagged(TELEPORTER_PROMPT_TAG) do
		hookPrompt(instance)
	end
	CollectionService:GetInstanceAddedSignal(TELEPORTER_PROMPT_TAG):Connect(hookPrompt)
end

return TeleporterController
