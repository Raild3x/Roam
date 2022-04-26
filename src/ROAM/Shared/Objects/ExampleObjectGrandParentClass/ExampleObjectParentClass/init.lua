local Example = {
	Setup = nil,
}


function Example.new(x, y, ...)
	local self = Example:Setup(...)
	-- Set class variables
	self.X = x;
	self.Y = y;
	
	--self.OnDestroy:Connect(function()
	--	print("Destroying Parent Class")
	--end)
	
	return self
end

function Example:TestMethod()
	return 2
end

function Example:Destroy()
	--print("Parent class destroy function test")
end



function Example:Test1(): number
	return self.A + self.X
end

return Example
