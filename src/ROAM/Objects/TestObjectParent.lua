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

local ROAM = ReplicatedStorage.ROAM
local Object = require(ROAM.Internal.Object)
local Types = require(ROAM.Internal.Types)

--local SharedModule = ROAM.Shared.Objects.TestObject
--local SharedClass = require(SharedModule)


----------------------
-- TYPE Declaration --
----------------------

export type CLASS = {
	ClassName: "TestObjectParent",

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
local Class = {} :: CLASS
Class.ClassName = "TestObjectParent"
Class.Super = script.Parent.TestObjectGrandParent


-----------------
-- Inheritance --
-----------------





-----------------
-- CONSTRUCTOR --
-----------------


function Class.new(N: number, ...): OBJECT
	local self = Class:Setup(...) :: OBJECT

	self.ParentValue = "Test"
	self.N = N
	

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
