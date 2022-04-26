local AnotherExample = {
	Setup = nil,
}


function AnotherExample.new(ang, ...)
	local self = AnotherExample:Setup(...)
	-- Set class variables
	self.ang = ang;

	self.OnDestroy:Connect(function()
		--print("Destroying GrandParent Class")
	end)

	return self
end

function AnotherExample:TestMethod()
	return 1
end

function AnotherExample:Destroy()
	--print("GrandParent class destroy function test")
end

return AnotherExample
