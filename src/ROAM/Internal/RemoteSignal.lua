local MultiRemoteSignal = {}

function MultiRemoteSignal.RegisterRemoteEvent(class: Types.EntityClass, name: string)
	assert(not self._Cached, "Cannot register after being cached")
	
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = self.Comms.Remotes.Events
	
	local self = setmetatable({
		Name = name,
		Event = event,
		
		Signals = {},
		
	}, MultiRemoteSignal)
end

function MultiRemoteSignal:Connect(id, func)
	
end

return MultiRemoteSignal


--[[

make remote for class


function Class.Client.MethodName(entity, player, ...)

end




self:FireRemote("")
function fire(...)


function Class.RegisterRemoteEvent(str)
	
	
	local tbl = {
		Name = str,
		Event = event
	}
	
	function tbl.Fire(event)
end

function Class:GetRemoteEvent(str)

end

class:RegisterRemoteEvent("EventName")

]]