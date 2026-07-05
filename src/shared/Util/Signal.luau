--!strict
-- Minimal synchronous event emitter for server-internal pub/sub between services.
-- Not networked - use Net.luau/RemoteEvents for client communication.

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({
		-- Keyed by a unique per-connection token rather than an array, so Disconnect is
		-- an O(1) table clear instead of an O(N) table.find + table.remove.
		_callbacks = {} :: { [{}]: (T...) -> () },
	}, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(callback)
	local token = {}
	self._callbacks[token] = callback

	local connection = {}
	function connection.Disconnect()
		self._callbacks[token] = nil
	end

	return connection
end

function Signal:Fire(...)
	for _, callback in self._callbacks do
		task.spawn(callback, ...)
	end
end

return Signal
