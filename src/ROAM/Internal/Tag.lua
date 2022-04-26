--!strict
--[[	TAG CLASS OBJECT
	Author: Raildex
	
]]

local RunService = game:GetService("RunService")

local InternalFolder = script.Parent

local Types = require(InternalFolder.Types)
local Pools = require(InternalFolder.Pools)
local Signal = require(InternalFolder.Signal)

local GLOBAL_ID = RunService:IsServer() and 1 or 2

return function (name: string): Types.Tag
	assert(name, "No name given to Tag")
	
	for id, tag in pairs(Pools.Tags) do
		if name == tag.Name then
			return tag
		end
	end
	
	local tag = {
		Id = tostring(GLOBAL_ID),
		Name = name,
		Entities = {},
		TagAdded = Signal.new(nil),
		TagRemoved = Signal.new(nil),
		ClassName = "Tag",
	} :: Types.Tag
	GLOBAL_ID += 2

	Pools.Tags[tag.Id] = tag

	return tag
end