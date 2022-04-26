local PlayerObject = {
	Setup = nil;
}


function PlayerObject.new(id, ...)
	local self = PlayerObject:Setup(...);
	-- Set class variables
	self.UserId = id;

	--self.OnDestroy:Connect(function()
	--	print("Destroying GrandParent Class")
	--end)

	return self;
end

function PlayerObject:GetUserId()
	return self.UserId;
end

function PlayerObject:Destroy()
	print("Cleaning up Player object with id " .. self.UserId)
end

return PlayerObject
