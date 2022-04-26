--!strict
--[SERVER]
--[[
	Authors: Raildex
	Date-Created: 4/13/2022
	Last-Updated: 4/13/2022
]]

--------------
-- Services --
--------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ROAM = ReplicatedStorage.ROAM
local ROAM_SERVER = ServerStorage.ROAM
local Object = require(ROAM.Internal.Object)
local Types = require(ROAM.Internal.Types)
local ROAM = require(ROAM)

--local SharedModule = ROAM.Shared.Objects.TestObject
--local SharedClass = require(SharedModule)

local SuperModule = ROAM_SERVER.Objects.TestObjectParent
local SuperClass = require(SuperModule)


----------------------
-- TYPE Declaration --
----------------------

type ImplementedClasses = SuperClass.CLASS
type ImplementedObjects = SuperClass.OBJECT

export type CLASS = {
	new: (a: number, b: number, c: number,
		...any) -> OBJECT,
	
	Destroy: (self: OBJECT) -> nil,
	PrivateServerMethod: (self: OBJECT) -> nil,

} & ImplementedClasses & Types.EntityClass


export type OBJECT = {
	A: number,
	B: number,
	C: number,

} & CLASS & ImplementedObjects & Types.Entity 


-----------------------
-- Class Declaration --
-----------------------

local Class: CLASS = {
	ClassName = "TestObject"
} :: CLASS
--Class.SharedModule = SharedModule
Class.Super = SuperModule
Class.Client = {
	
	TestEvent = ROAM.CreateRemoteEvent(),

	MethodName = function(self: OBJECT, player: Player, ...)
		print(self, player, ...)
		warn("TEST:", ...)
		return "Hello"
	end
}


-----------------
-- CONSTRUCTOR --
-----------------

--@Override
function Class.new(a: number, b: number, c: number, ...: any): OBJECT	
	local self = Class:Setup(...) :: OBJECT

	self.A = a
	self.B = b
	self.C = c
	

	return self
end

function Class.Destroy(self: OBJECT)
	return
end

------------------------
-- Overridden Methods --
------------------------


------------------------
-- Private Methods --
------------------------

function Class.PrivateServerMethod(self: OBJECT)
	print("Private method called")
	return nil
end



return Object(Class) :: CLASS
