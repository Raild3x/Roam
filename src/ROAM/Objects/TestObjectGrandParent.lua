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

local Package = script.Parent
local Internal = ReplicatedStorage.ROAM.Internal

local ROAM = require(ReplicatedStorage.ROAM)
local Object = require(Internal.Object)
local Types = require(Internal.Types)

--local SharedModule = ROAM.Shared.Objects.TestObject
--local SharedClass = require(SharedModule)


----------------------
-- TYPE Declaration --
----------------------

export type CLASS = {
	ClassName: "TestObjectGrandParent",

	new: (...any) -> OBJECT,

	InheritedMethod: (self: OBJECT) -> nil,

} & Types.EntityClass 

export type OBJECT  = {
	ParentValue: string,
	N: number,

} & CLASS & Types.Entity 

-----------------------
-- Class Declaration --
-----------------------
local Class = { Client = {} } :: CLASS
Class.ClassName = "TestObjectGrandParent"

Class.Client.TestEvent2 = ROAM.CreateRemoteEvent()

function Class.Client.GrandParentMethod()
	--print("Grand Parent Method Fired")
end


-----------------
-- Inheritance --
-----------------





-----------------
-- CONSTRUCTOR --
-----------------


function Class.new(...): OBJECT
	local self = Class:Setup(...) :: OBJECT
	

	return self
end

------------------------
-- Overridden Methods --
------------------------


------------------------
-- Private Methods --
------------------------


function Class.InheritedMethod(self: OBJECT)
	print("Inherited method called")
end



return Object(Class) :: CLASS
