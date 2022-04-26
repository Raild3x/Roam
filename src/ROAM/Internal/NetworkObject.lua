--!strict
-- CLIENT

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


------------------------------------------------------------
local ROAM = require(ReplicatedStorage.ROAM)
local Types = require(ReplicatedStorage.ROAM.Internal.Types)

local ClassManager = ROAM.ClassManager
local Pools = ROAM.Pools
local Tag = ROAM.Tag


local NetworkObject = {}


--------------------------------------------------------------------------------------------------------

local function getTag(_tag: string | Types.Tag): Types.Tag
	local tag: Types.Tag
	if typeof(_tag) == "string" then
		tag = Tag(_tag)
	else
		tag = _tag
	end
	return tag
end

--------------------------------------------------------------------------------------------------------

function NetworkObject:Is(Name: string): boolean
	return (Name == "Object") or (Name == self.ClassName) or (table.find(self.Types, Name) ~= nil)
end

------------------------------------------------------------------------



function NetworkObject:AddComponent(unit: Types.ComponentUnit, componentName: string?): Types.ComponentUnit
	local compTbl = self.Internal.Components
	local componentName: string = componentName or Pools.Components[unit.ComponentId].Name
	assert(componentName, "No Component name given or inferred.")
	--assert(compTbl[componentName] == nil, "Object already has a component with name: "..componentName)
	compTbl[componentName] = unit

	unit:AddEntity(self)

	return unit;
end

function NetworkObject:GetComponent(componentName: string): Types.ComponentUnit
	local compTbl = self.Internal.Components
	assert(compTbl[componentName], "Object has no compenent with name: "..componentName)

	return compTbl[componentName]
end


--------------------------------------------------------------------------------------------------------

function NetworkObject.new(entityId: number, className: string, types: {string}): Types.Entity
	local self = NetworkObject:Setup() :: Types.Entity
	
	Pools.Objects[self.Internal.Id] = nil -- clear the auto reserved space
	Pools.Objects[entityId] = self -- move it to the new location
	
	self.ClassName = className
	self.Internal.Id = entityId
	self.Types = types

	
	table.insert(types, "NetworkObject")

	return self
end


return NetworkObject
