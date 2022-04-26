local Example = {
	Setup = nil,
}


function Example.new(z, ...)
	local self = Example:Setup(...)
	-- Set class variables
	self.Z = z;
	
	--self.OnDestroy:Connect(function()
	--	print("Destroying GrandParent Class")
	--end)
	
	return self
end

function Example:TestMethod()
	return 1
end

function Example:Destroy()
	--print("GrandParent class destroy function test")
end

return Example
