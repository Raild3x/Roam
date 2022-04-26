--!strict
--[CLIENT]
--[[
	Authors: Raildex
	Date-Created: 4/21/2022
	Last-Updated: 4/21/2022
]]

--------------
-- Services --
--------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROAM = require(ReplicatedStorage.ROAM)
local ROAM: ROAM.ROAM = ROAM

local Position: ROAM.Component = ROAM.Component( ROAM.Type("Vector3"), "Position")
local Rotation: ROAM.Component = ROAM.Component( ROAM.Type("number"), "number")

local Model_Template = Instance.new("Part")
Model_Template.Anchored = true
Model_Template.Size = Vector3.new(1,1,1)
Model_Template.Color = Color3.fromRGB(0, 156, 65)
Model_Template.Transparency = 0.5

----------------------
-- TYPE Declaration --
----------------------

export type CLASS = {
	new: (...any) -> OBJECT,
	
} & ROAM.EntityClass 

export type OBJECT  = {
	Model: BasePart
} & CLASS & ROAM.Entity 

-----------------------
-- Class Declaration --
-----------------------
local Mob = { Client = {} } :: CLASS
Mob.ClassName = "Mob"


-----------------
-- CONSTRUCTOR --
-----------------

function Mob.new(...): OBJECT
	local self: OBJECT = Mob:Setup(...) :: OBJECT
	
	self.Model = Model_Template:Clone()
	self.Model.Parent = workspace
	
	self:AddComponent(Position:NewUnit(Vector3.new(0,0,0)))
	self:AddComponent(Rotation:NewUnit(0))
	
	--self:GetComponent("Position").Changed:Connect(function(value)
	--	self.Model.Position = value
	--end)
	
	return self
end


------------------------
-- Private Methods --
------------------------


return ROAM.Object(Mob, script) :: CLASS
