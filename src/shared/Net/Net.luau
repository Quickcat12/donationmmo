--!strict
-- Thin wrapper around RemoteEvents living under ReplicatedStorage.Remotes.
-- Server calls Net.bootstrap() once at startup to create every event up front.
-- Both server and client call Net.get(name) to fetch a reference safely.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteNames = require(script.Parent.RemoteNames)

local REMOTES_FOLDER_NAME = "Remotes"

local Net = {}

local remoteCache: { [string]: RemoteEvent } = {}

local function getRemotesFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REMOTES_FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

-- Server-only: creates every RemoteEvent declared in RemoteNames.Events.
function Net.bootstrap()
	local folder = getRemotesFolder()
	for _, remoteName in RemoteNames.Events do
		if not folder:FindFirstChild(remoteName) then
			local event = Instance.new("RemoteEvent")
			event.Name = remoteName
			event.Parent = folder
		end
	end
end

function Net.get(remoteName: string): RemoteEvent
	local cached = remoteCache[remoteName]
	if cached then
		return cached
	end

	local folder = getRemotesFolder()
	local event = folder:FindFirstChild(remoteName) or folder:WaitForChild(remoteName, 10)
	assert(event, `Remote "{remoteName}" was never created - did the server call Net.bootstrap()?`)

	remoteCache[remoteName] = event :: RemoteEvent
	return event :: RemoteEvent
end

return Net
