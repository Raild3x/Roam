local ExampleChildClass = {
	Setup = nil, -- Implement this to calm the warnings
}


function ExampleChildClass.new(a,b,c, ...)
	local self = ExampleChildClass:Setup(...) -- calls the parent classes to setup inheritance at the top level and then build back down to this class
	-- Set class variables
	self.A = a;
	self.B = b;
	self.C = c;
	
	--self.OnDestroy:Connect(function()
	--	print("Destroying Child Class")
	--end)
	
	return self
end

function ExampleChildClass:Destroy()
	--print("Child class destroy function test")
end

function ExampleChildClass:Test2()
	print(self.B,self.Y)
end


return ExampleChildClass
