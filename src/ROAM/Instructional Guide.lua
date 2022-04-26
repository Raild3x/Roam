--!strict
--[[
	~Object ReadMe~
	
	Author: Raildex
	Date Created: 4/21/2022
	Last Updated: 4/21/2022

		Welcome to ROAM's guide on using OOP with ROAM. Objects are often referred to as Entities
	within ROAM as they are the main inherited class. When you see something is of type Entity you
	can know that it is a ROAM based class. The basis to creating a ROAM class or converting a
	pre-existing one is done in four simple steps. 
	
	(1) Require ROAM. 
	
	(2) Create your class and make sure that it has a unique ClassName index set to a string. 
	This is very important and is what allows ROAM to differentiate your object classes easily. 
	
	(3) In your Objects constructor, instead of setting the object to a table you should set it 
	to the method `MyClass:Setup(...)` where the variadic is any arguments you want to pass to 
	classes your object inherits from.
	
	(4) At the very end of your module where you would usually `return MyClass` you should instead
	do `return ROAM.Object(MyClass, script) :: ROAM.EntityClass`. This will apply all the internal
	methods to your class and then return it afterwards. 
	
	I will show an example of a ROAM based object class. In this case our class will be `Car`. 
	Because luau's linter doesnt like metatables it is recommended you declare methods that take the 
	object itself with `MyClass.MethodName(self: MyObjectType, ...)` rather than `MyClass:MethodName(...)`. 
	This may seem annoying but it is a great help with linting and type checking as you can infer the 
	type of objects that should be expected.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ROAM = require(ReplicatedStorage.ROAM)
local ROAM: ROAM.ROAM = ROAM

--// This is the type for this module's class, declare static properties and methods here.
export type CarClass = {
	new: (maxSpeed: number, ...any) -> (CarObject),
	
	Gas: (self: CarObject, amount: number) -> (),
	Brake: (self: CarObject, amount: number) -> (),
	GetMaxSpeed: (self: CarObject) -> (number)
} & ROAM.EntityClass -- Inherit the EntityClass type

--// This is the type for the Object made from the class's constructor, declare properties here.
export type CarObject = {
	MaxSpeed: number,
	CurrentSpeed: number,
} & CarClass & ROAM.Entity -- inherit the class and the Entity type


--// Declare the Class
local Car: CarClass = {} :: CarClass
Car.ClassName = "Car"


function Car.new(maxSpeed: number, ...:any): CarObject
	local self: CarObject = Car:Setup(...) :: CarObject
	
	self.MaxSpeed = maxSpeed
	self.CurrentSpeed = 0
	
	return self
end

function Car.Gas(self: CarObject, amount: number)
	assert(amount >= 0, "Gas amount must be greater than 0")
	self.CurrentSpeed = math.min(self.MaxSpeed, self.CurrentSpeed + amount)
end

function Car.Brake(self: CarObject, amount: number)
	assert(amount >= 0, "Brake amount must be greater than 0")
	self.CurrentSpeed = math.max(0, self.CurrentSpeed - amount)
end

function Car.GetMaxSpeed(self: CarObject): number
	return self.MaxSpeed
end

return ROAM.Object(Car, script) :: CarClass

-------------------------------------------------------------------------------------------------
--[[
	Once you have setup your Object you can require it elsewhere and utilize it like normal.
	Ignore any warnings or errors that are being displayed below. They are just because this is all
	written in one script. In an actual proper setting they would not appear with this code.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ROAM = require(ReplicatedStorage.ROAM)
local ROAM: ROAM.ROAM = ROAM

local Car = require(ReplicatedStorage.ROAM.Shared.Objects.Car) -- assume this is where you have stored your module
local Car: Car.CarClass = Car

ROAM.OnStart():await()

local myCar: Car.CarObject = Car.new(60)

myCar:Gas(22)
myCar:Gas(8)

print(myCar.CurrentSpeed) -- 30

myCar:Brake(5)

print(myCar.CurrentSpeed) -- 25

myCar:Destroy() -- Clean up the object's internals and mark it for Garbage Collection

--[[
	You may have noticed above that I called :Destroy() on our car even though no :Destroy() method
	was defined on our class. This is because it is inherited by EntityClass. The one main downside
	to ROAM is that you MUST call :Destroy() on objects you create when you no longer need them so they
	can be Garbage Collected. If you dont they will persist internally forever. This is done for a
	multitude of reasons. (1) It allows for access anytime anywhere in your other modules through the
	use of Queries and ROAM. (2) It allows for automatic network communication of Objects. I can assure
	you that it is well worth it. If you already do proper object memory management or use a lower level
	language like C then this shouldn't be foreign to you. Along with the :Destroy() method there is also
	a property given to every ROAM object `.OnDestroy` which is an event you can connect to that will
	trigger when :Destroy() is called on the object.
]]

myCar.OnDestroy:Connect(function()
	print("Car "..myCar:GetId().." was destroyed")
end)

--[[
	Something you might be worried about is that you now wont be able to define your own :Destroy() methods
	in your objects, but fret not! ROAM has anticipated this, and it will call your :Destroy() method aswell
	as cleaning up the internal code. It will also call any :Destroy() method that it inheirts from other
	classes so you can organize your Object deconstructors per class.

	Other features ROAM Objects include is the ability to add whats referred to as Components to your Object.
	Components are essentially groups of properties you can add. The benefit of these over normal properties is 
	that ROAM components can be used as query search conditions and they are also network compatible. Some
	component types are not network safe such as functions, tables with metadata, and certain instances not visible
	to the client. It is recommended to only use them for simple datatypes like numbers, strings, booleans, Vector3,
	EnumItem, shallow tables, etc...
	
	To utilize a component you must first create one from a template like so. I will create two different components.
	ROAM.Component(
		template: {[string]: ROAM.Type} | ROAM.Type, 
		name: string
	): ROAM.Component
]]

local Currency: ROAM.Component = ROAM.Component({
	Gold = ROAM.Type("number"),
	Crystals = ROAM.Type("number"),
}, "Currency")

local Position: ROAM.Component = ROAM.Component( ROAM.Type("Vector3"), "Position")

--[[
	The above code create Components or whats sometimes referred to as a ComponentTemplate. The first component
	has two attributes, Gold and Crystals, both of which are numbers and then we gave it the name "Currency".
	The other consists of a single Vector3 attribute and has the name "Position". These templates would typically
	be declared in their own module script for consistency and reuse but are not required to be. Now that we have 
	the templates we can use them to create whats referred to as ComponentUnits. This is data that follows the 
	structure of the given component. These are the actual units of work that you will be using in your objects.
	ComponentUnits can be created and then given to an Object like so:
]]

local cUnit: ROAM.ComponentUnit = Currency:NewUnit({
	Gold = 100,
	Crystals = 0,
})

local pUnit: ROAM.ComponentUnit = Position:NewUnit( Vector3.new(0,5,0) )

myCar:AddComponent(cUnit)
myCar:AddComponent(pUnit)

--[[
	Proper ROAM formatting would usually suggest that you create the ComponentUnit directly in the :AddComponent
	method arguments. Although you can give a single ComponentUnit to multiple Objects it is not recommended and 
	can lead to uninteded behavior if you are iterating entities and changing the values of object's ComponentUnits.
	It can also lead to memory leaks if ComponentUnit is not given to an object as when the objects are destroyed
	they automatically clean up the associated ComponentUnit if it no longer has any objects it is associated with.
	Once given to an object CUs (ComponentUnits) can be accessed via their original template name and the object's 
	:GetComponent(string) method. Once you have the CU you can use the ComponentUnit's :Get(), :Set(), :Add(), :Sub(),
	:Mul(), :Div(), :Mod(), :Pow() to retrieve or change the values of the CU. If you try and set an attribute to a
	different datatype than was originally specified in the template it will throw an error to prevent accidents.
	Here are some examples:
]]

local money: ROAM.ComponentUnit = myCar:GetComponent("Currency")
local pos: ROAM.ComponentUnit = myCar:GetComponent("Position")

print( money:Get("Gold") ) -- 100
print( pos:Get() ) -- (0, 5, 0)

money:Mul(2, "Gold")
print( money:Get("Gold") ) -- 200

pos:Add( Vector3.new(2, 13, 0) )
print( pos:Get() ) -- (2, 18, 0)

money:Set(321, "Crystals")
print( money:Get("Crystals") ) -- 321

--[[
	If you have a number based attribute and need to do math it is recommended that you use the built in methods 
	rather than using :Get() and :Set() repeatedly as they are much more efficient when doing these operations. 
	As you may have noticed when a CU consists of only one value you do not have to specify an attribute name.
	If you ever need to remove a component from an object you can do so with :RemoveComponent(string).
	
	If you arent sure if an Object has a particular ComponentUnit yet then you can use the 
	:WaitForComponent(name: string, _timeOut: number?) -> Promise
	method. It will return a promise that resolves when the component is found or rejected if it times out.
	Occaisionally you may want to watch for changes in a ComponentUnit's values. You can detect these changes 
	with the CU's .Changed:Connect(function(value: any, attributeName: string?) event.
]]

myCar:WaitForComponent("Currency"):andThen(function(unit: ROAM.ComponentUnit)
	unit.Changed:Connect(function(newValue, attributeName)
		print(attributeName," was updated to ", newValue)
	end)
end):catch(warn)

--[[
	Along with Components you can also easily add Events and Tags to your Objects. Events are essentially just
	bindables you can easily attach to your objects and Tags are essentially strings. Under the hood they are 
	more quite a bit more, however you dont need to worry about any of that.
]]

--// TAGS
local redTeamTag: ROAM.Tag = ROAM.Tag("RedTeam")
local premiumUserTag: ROAM.Tag = ROMA.Tag("PremiumUser")

myCar:AddTag(redTeamTag)
myCar:AddTag(premiumUserTag)
myCar:AddTag("Renderable")

print( myCar:GetTagNames() ) -- {"RedTeam", "PremiumUser", "Renderable"}

print( myCar:HasTag("PremiumUser") ) -- true

myCar:RemoveTag(redTeamTag)

--// EVENTS

myCar:AddEvent("DriverChanged")

local myEvent = myCar:GetEvent("DriverChanged")

local connection = myEvent:Connect(function(newDriver: string)
	print("Car has a new driver: "..newDriver)
end)

myEvent:Fire("Raildex") -- Car has a new driver: Raildex

connection:Disconnect()

--[[
	To keep track of and access entities based on conditions ROAM introduces Queries. Queries allow you to specify
	a list of conditions that an entity must have by giving it Tags, Components, or EntityClasses. Say for instance
	you wanted to track everything that had the RedTeam tag and a Position component. You would pass the tag and the
	original Component used for defining units in an array to the Query.
]]

local myQuery: ROAM.Query = ROAM.Query({redTeamTag, Position})

--[[
	The query will then internally keep track of all entities that have both the RedTeam Tag and the Position Component.
	You can access the current list of entities at any given moment with :Get(). However, Queries are best used with
	Query Statements or their built in ForEach iterator.
]]

local moveRedTeamUp = myQuery:MakeStatement(function(entity: ROAM.Entity, amount: number)
	entity:GetComponent("Position"):Add( Vector3.new(0,amount,0) )
end)

-- This will add 5 to the position-Y of all entities that are on the redTeam and have a position Component at the time of calling.
moveRedTeamUp(5) 

-- Although not necessary, ForEach allows you to retrive the previous returned value of your function
-- It also returns a table of results for each entity.
local results, finalResult = myQuery:ForEach(function(entity: ROAM.Entity, previousResult: any?)
	local currentY = entity:GetComponent("Position"):Get().Y
	return currentY + (previousResult or 0)
end)

print("AverageHeight: ", finalResult / myQuery:GetSize())

--[[----------------------------------------------------------------------------------------------------

		Now for the real meat of ROAM, the entity syncronization system. ROAM allows you to syncronize component
	values between server and client versions of an object so you can easily read from an internal value. You
	can also setup remote events and functions for easy calling. 
	
		To get started and enable the syncronization
	feature the Object class must have its Client index set to a table. You must then create an class with
	the same ClassName on the client and have both the server module and the client module required by ROAM
	in its initial setup stage for everything to work smoothly. Placing the Object Modules in the respective
	Server Objects Folder and Client Objects Folder will automatically do the requiring step for you as it 
	will iterate through and and require each module it finds in these folders before declaring itself ready. 
	
		Secondly, you must then call :Sync() on your server side object. This will mark it for syncronization with
	clients. You can specify which clients excatly to sync with or to ignore with :SetSyncedPlayers(). If this
	method isnt used it will assume to sync with all clients. When you call :Sync() if you give it any arguments,
	these arguments will be used for the client side constructor. Here is an example:
]]

-- Class Declaration [SERVER] --
local Car: CarClass = {} :: CarClass
Car.ClassName = "Car"
Car.Client = {}

Car.Client.TestEvent = ROAM.CreateRemoteEvent()

function Car.Client.TestMethod(self: CarObject, player: Player, ...)
	print("Client sent:", ...)
	return "World"
end


function Car.new(...): CarObject
	local self: CarObject = Car:Setup(...) :: CarObject
	-- declare properties
	
	self.Client.TestEvent:Connect(function(value)
		print(value) -- Egg
	end)
	
	self:Sync("Mercedes") -- this can be called anywhere, not just constructor
	
	return self
end




-- Class Declaration [CLIENT] --
local Car: CarClass = {} :: CarClass
Car.ClassName = "Car"

function Car.new(name, ...): CarObject
	local self: CarObject = Car:Setup(...) :: CarObject
	
	self.Name = name
	
	print(self.Name) -- Mercedes
	
	local result = self.Server:TestMethod("Hello") -- calls as a normal Remotefunction
	print( result ) -- "World"
	
	self.Server:TestMethodAsync("Hello"):andThen(function(result) -- adding async returns a promise
		print(result)
	end)
	
	self.Server:FireTestMethod("Hello") -- calls as an event, discards return value
	
	self.Server.TestEvent:Fire("Egg")
	
	return self
end

--TODO: FINISH INSTRUCTIONAL GUIDE