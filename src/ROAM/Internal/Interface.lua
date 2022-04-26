--!strict

-- Interface.lua
-- AbiZinho
-- Created: April 17, 2022
-- Updated: April 18, 2022

--[[
	Interface Instance for ROAM.
]]--

-- [[ Services ]] --
local ReplicatedStorage	= 	game:GetService("ReplicatedStorage")
local RunService		=	game:GetService("RunService")

--[[ Modules ]]--
local Internal		=	ReplicatedStorage.ROAM.Internal
local Types: any 	=	require(Internal.Types)

-- [[ Static Variables ]] --
local INTERFACE_ID: number	=	0
local IS_SERVER: boolean	= 	RunService:IsServer()

-- [[ Private Methods ]] --


-- [[ Interface Class ]] --
local Interface: Types.InterfaceMetatable = {} :: Types.InterfaceMetatable
Interface.ClassName	= "Interface"
Interface.__index	= Interface

--[[
	Sets all stored fields in self.ClassFields into class without overriding fields.
	@param self The interface instance
	@param class The Class object (entity metatable)
]]--
function Interface.SetupClass(self: Types.Interface, class: Types.EntityClass)
	for key: string, val: any in pairs(self.ClassFields) do
		if class[key] == nil then
			class[key] = val
		end
	end
end

--[[
	Sets all stored fields in self.ObjectProperties into object without overriding fields.
	Had problems setting type of object to Types.Entity, so instead use any.
	@param self The interface instance
	@param object The Object instance (entity)
]]--
function Interface.SetupObject(self: Types.Interface, object: any)
	for key: string, val: any in pairs(self.ObjectProperties) do
		if object[key] == nil then
			object[key] = val
		end
	end
end

--[[
	Creates interface instance given default class fields and object properties.
	@param classFields The class fields
	@param objectProperties The properties of objects
	@return The interface instance
]]--
local function createInterface(classFields: {[string]: any}, objectProperties: {[string]: any}): Types.Interface	
	for key: string, val: any in pairs(objectProperties) do
		-- Remove all values which are functions - we want properties only
		if type(val) == "function" then
			objectProperties[key] = nil
		end
	end
	
	INTERFACE_ID += 1
	local InterfaceData: Types.InterfaceData = {
		ClassFields = classFields;
		ObjectProperties = objectProperties;
		InterfaceId = INTERFACE_ID;
	}
	
	table.freeze(InterfaceData)
	table.freeze(classFields)
	table.freeze(objectProperties)
	
	return setmetatable(InterfaceData, Interface)
end

return createInterface