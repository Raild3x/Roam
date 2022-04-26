--!strict
--[[
   _____                                             _   
  / ____|                                           | |  
 | |     ___  _ __ ___  _ __   ___  _ __   ___ _ __ | |_ 
 | |    / _ \| '_ ` _ \| '_ \ / _ \| '_ \ / _ \ '_ \| __|
 | |___| (_) | | | | | | |_) | (_) | | | |  __/ | | | |_ 
  \_____\___/|_| |_| |_| .__/ \___/|_| |_|\___|_| |_|\__|
                       | |                               
                       |_|          
	Component Class
	Author: Raildex
	Date Created: 02/25/2022
	Last Updated: 04/4/2022
	
	
	This is the constructor class for Components and ComponentUnit objects for use with ROAM's Objects.
	A Component must first be created with a template before a Component Unit can be created. It is
	recommended that you use a module to hold you Component declarations so they can be required from 
	wherever needed.
	
	
	-------------------------------------------------------------------------------------------------------------
	Component Declaration should follow the following template:
	
	local myComponent: Types.Component = Component({
		ComponentPropertyName1 = Type("string"),
		ComponentPropertyName2 = Type("number"),
		ComponentPropertyName3 = Type("boolean"),
		...
		
	}, "MyComponentName")
	
	
	an Example of an actual Component Declaration would be

	local Currency: Types.Component = Component({
		Gold = Type("number"),
		Premium = Type("number"),
	}, "Currency")
	
	
	-------------------------------------------------------------------------------------------------------------
	Once you have the Component Template declared you can create actual ComponentUnits to be used in conjunction
	with ROAM's Objects:
	
	local myWallet: Types.ComponentUnit = Currency({
		Gold = 100,
		Premium = 10,
	})
	
	myObject:AddComponent(myWallet)
	
	local unit: Types.ComponentUnit = myObject:GetComponent("Currency") -- This is how you could get access to the unit from the object
	
	print( myWallet:Get("Gold") ) -- 100
	
	unit:Set(20, "Gold") 
	
	print( myWallet:Get("Gold") ) -- 20
	
	
	ComponentUnits have built in utility math methods for easy adjustment of number based values:
	
	myWallet:Add(5, "Premium") -- 15
	myWallet:Mul(2, "Premium") -- 30
	myWallet:Div(3, "Premium") -- 10
	
	-------------------------------------------------------------------------------------------------------------
	ComponentUnits should be intrinsically used with ROAMs Objects. A ComponentUnit can be given to two different
	Objects, although this feature isnt fleshed out and may result in some unintended behavior, use at your own risk. 
	When a ComponentUnit is no longer associated with an Object it will clean itself up and will no longer be
	accessible through the ComponentUnit Pool. If a ComponentUnit is created and not given to a ROAM Object it can
	create a memory leak. Make sure that you manually call :Destroy() on the ComponentUnit in this scenario to 
	clean it up assuming you have access to the variable. If you know the Component the Unit is associated with
	but no longer have access to the Unit itself you can call :CleanUp() on the Component and it will call :Destroy()
	on any Units with no associated Objects.
	When creating a ComponentUnit you can pass a string as a second argument to overwrite the default lookup name of
	the component in the ROAM Object, this allows for you to specify different names in different Objects for the 
	same ComponentUnit and prevent conflicts with Components that may have the same name.


]]

local RunService 		= game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROAM 	= ReplicatedStorage.ROAM
local Types = require(ROAM.Internal.Types)

local NetworkManager 	= require(ROAM.Internal.NetworkManager)
local Pools				= require(ROAM.Internal.Pools)
local Components		= Pools.Components


local TableUtil = require(ROAM.Internal.TableUtil)
local Type 		= require(ROAM.Internal.Type)
local Signal 	= require(ROAM.Internal.Signal)

local IS_SERVER: boolean = RunService:IsServer()
local IS_CLIENT: boolean = RunService:IsClient()

local GLOBAL_ID: number = IS_SERVER and 1 or 2
local UNIT_GLOBAL_ID: number = IS_SERVER and 1 or 2
local TYPE_CHECK: boolean = false


--------------------------------------------------------------------------------------------------
-- PRIVATE UTILITY FUNCTIONS --
--------------------------------------------------------------------------------------------------

local function GetMostSimilar(word: string, tbl: {[string]: any}): string
	local similarityCount: number = 0
	local similarWord: string = "[Could not find similar Key]"
	for key: string, _ in pairs(tbl) do
		local currentSimilarities = 0
		for i = 1, #word do
			if key:find(word:sub(i,i)) then
				currentSimilarities += 1
			end
		end
		if currentSimilarities > similarityCount then
			similarityCount = currentSimilarities
			similarWord = key
		end
	end
	return similarWord
end


local function TypeCheckTable(template: any, data: any): (boolean, string)
	if type(template) == "table" and template.ClassName == "Type" then
		local succes = template(data)
		if not succes then
			return false, "[ComponentType] Could not match values from origin and incoming!"
		end
	elseif type(template) == "table" then
		for key, dataType in pairs(template) do
			if not data[key] then
				return false, "[ComponentType] Could not find key: " .. tostring(key) .. " in given data!\n"
				.. "Double check spelling on key: \'"..GetMostSimilar(key, data).."\'"
			end
			if type(data[key]) ~= "table" or (data[key].Id) then
				
				-- Typecheck the value
				if not dataType(data[key]) then
					return false, "[ComponentType] Could not match values in key: ["
						.. tostring(key)
						.. "]!\n\t\t\t\t Expected type: ["
						.. type(dataType) .. "],\n\t\t\t\t Received type: [" .. type(data[key]) .. "]";
				end
			else
				-- Recursively check the table
				local success, message = TypeCheckTable(dataType, data[key])
				if not success then
					return false, message
				end
			end
		end
	else
		error("[ComponentType] Invalid origin type!")
	end
	return true, ""
end


local function TypesAreSyncable()
	
end


--------------------------------------------------------------------------------------------------
-- COMPONENTUNIT CLASS --
--------------------------------------------------------------------------------------------------

local COMPONENT_UNIT = {}
COMPONENT_UNIT.ClassName = "ComponentUnit"
COMPONENT_UNIT.__index = COMPONENT_UNIT


local function Set(self: Types.ComponentUnit, newValue: any, dataName: string?): any
	debug.profilebegin("Set")
	local Component: Types.Component = Components[self.ComponentId]
	local template = Component.Template


	if not dataName then
		if not template(newValue) then
			error("Invalid Type given for "..dataName..". Expected: "..template.name.." - Got: "..typeof(newValue))
		end
		self.Data = newValue;
	else
		if not template[dataName](newValue) then
			error("Invalid Type given for "..dataName..". Expected: "..template[dataName].name.." - Got: "..typeof(newValue))
		end
		self.Data[dataName] = newValue;
	end

	self.Changed:Fire(newValue, dataName)

	if IS_SERVER and self.SyncEnabled then
		local unitId: string? = self.UnitId
		local CTU = NetworkManager.ComponentsToUpdate
		--print("Updating Client Component-"..tostring(unitId),newValue,dataName)
		if dataName then
			if not CTU[unitId] then
				CTU[unitId] = {}
			end
			CTU[unitId][Component:GetKeyFrom(dataName)] = newValue
		else
			CTU[unitId] = newValue
		end
	end
	debug.profileend()
	return newValue
end


local function Get(self: Types.ComponentUnit, dataName: string?)
	local data = self.Data
	if dataName then
		if not data[dataName] and not Components[self.ComponentId].Template[dataName] then
			error("Invalid Key, ["..dataName.."] does not exist in Component Template. Check your spelling.")
		end
		return data[dataName]
	end
	return data
end


COMPONENT_UNIT.Set = Set
COMPONENT_UNIT.Get = Get

-------------------------
-- Math Helper Methods --

type numeric = typeof(Vector3.new()) | typeof(Vector2.new()) | number 

local function Add(self: Types.ComponentUnit, amt: numeric, dataName: string?)
	return Set(self, Get(self, dataName) + amt, dataName);
end
local function Sub(self: Types.ComponentUnit, amt: numeric, dataName: string?)
	return Set(self, Get(self, dataName) - amt, dataName);
end
local function Mul(self: Types.ComponentUnit, amt: numeric, dataName: string?)
	return Set(self, Get(self, dataName) * amt, dataName);
end
local function Div(self: Types.ComponentUnit, amt: numeric, dataName: string?)
	return Set(self, Get(self, dataName) / amt, dataName);
end
local function Mod(self: Types.ComponentUnit, amt: numeric, dataName: string?)
	return Set(self, Get(self, dataName) % amt, dataName);
end
local function Pow(self: Types.ComponentUnit, amt: numeric, dataName: string?)
	return Set(self, Get(self, dataName) ^ amt, dataName);
end

COMPONENT_UNIT.Add = Add
COMPONENT_UNIT.Sub = Sub
COMPONENT_UNIT.Mul = Mul
COMPONENT_UNIT.Div = Div
COMPONENT_UNIT.Mod = Mod
COMPONENT_UNIT.Pow = Pow

-------------------------

function COMPONENT_UNIT.IsSingleValued(self: Types.ComponentUnit): boolean
	local comp: Types.Component = self:GetComponent()
	return typeof(comp.Template) == "table" and comp.Template.ClassName == "Type"
end

-- Queues ComponentUnits data to be sent to players without having to change it
function COMPONENT_UNIT.Flush(self: Types.ComponentUnit, ...)
	assert(IS_SERVER, ":Flush() can only be called from the Server.")
	local Component: Types.Component = Components[self.ComponentId]
	local unitId: string? = self.UnitId
	local CTU = NetworkManager.ComponentsToUpdate
	
	local attributes: {} = {...}
	if #attributes == 0 then -- if nothing is passed
		if self:IsSingleValued() then -- if its just one value
			CTU[unitId] = self.Data
		else -- flush all values
			CTU[unitId] = CTU[unitId] or {}
			
			for key, value in pairs(self.Data) do
				CTU[unitId][Component:GetKeyFrom(key)] = value
			end
		end
	else
		CTU[unitId] = CTU[unitId] or {}
		
		for _, attributeName in ipairs(attributes) do
			CTU[unitId][Component:GetKeyFrom(attributeName)] = self.Data[attributeName]
		end
	end
end

-- Immediately sends the components data to relevant players
function COMPONENT_UNIT.ForceFlush(self: Types.ComponentUnit, ...: string)
	assert(IS_SERVER, ":ForceFlush() can only be called from the Server.")
	local Component: Types.Component = Components[self.ComponentId]
	local unitId: string? = self.UnitId
	local CTU = NetworkManager.ComponentsToUpdate
	
	CTU[unitId] = nil -- clear any currently cached updates
	
	local attributes: {} = {...}
	
	if #attributes == 0 then
		NetworkManager.CreateComponentUnitOnClient(self)
	else
		error("Specifying attributes for a force flush is not yet supported.")
	end
	warn("ForceFlushed ComponentUnit")
end


function COMPONENT_UNIT.Sync(self: Types.ComponentUnit)
	assert(IS_SERVER, "Cannot Call Sync from Client")
	--if self.SyncEnabled then
	--	return warn("Already Synced ComponentUnit")-- already synced
	--end
	--TODO: Check if the Component types are syncable
	self.SyncEnabled = true
	
	NetworkManager.CreateComponentUnitOnClient(self)
end

function COMPONENT_UNIT.IsSynced(self: Types.ComponentUnit)
	return self.SyncEnabled
end


function COMPONENT_UNIT.GetPlayerIdsToSyncWith(self: Types.ComponentUnit): {number}?
	local plrs: {number} = {} -- tbl of userIds
	local registered: {[number]: boolean} = {} -- keep track of gathered plrs
	for _, entityId: string in pairs(self.EntityIds) do
		local entity: Types.Entity = Pools.Objects[entityId]
		if entity:IsSynced() then
			if entity.Internal.SyncedPlayers then
				for _, plrId: number in pairs(entity.Internal.SyncedPlayers) do
					if not registered[plrId] then
						registered[plrId] = true
						table.insert(plrs, plrId)
					end
				end
			else
				return nil
			end
		end
	end
	return plrs
end

function COMPONENT_UNIT.CanSyncWithPlayer(self: Types.ComponentUnit, plr: Player): boolean
	for _, entityId: string in pairs(self.EntityIds) do
		local entity: Types.Entity = Pools.Objects[entityId]
		if entity:IsSynced() then
			if entity.Internal.SyncedPlayers then
				if table.find(entity.Internal.SyncedPlayers, plr.UserId) then
					return true
				end
			else
				return true
			end
		end
	end
	return false
end

---------

function COMPONENT_UNIT.AddEntity(self: Types.ComponentUnit, entity: Types.Entity)
	local Component: Types.Component = Pools.Components[self.ComponentId] 
	table.insert(self.EntityIds, entity:GetId())
	table.insert(Component.Entities, entity:GetId())
	Component.ComponentAdded:Fire(entity, self)
end

function COMPONENT_UNIT.RemoveEntity(self: Types.ComponentUnit, entity: Types.Entity)
	TableUtil.FastRemoveFirstValue(self.EntityIds, entity:GetId())
	if #self.EntityIds == 0 then -- if no more entities are associated with the unit clean it up (Do we need this?)
		self:Destroy()
	end
	local Component: Types.Component = Pools.Components[self.ComponentId]
	TableUtil.FastRemoveFirstValue(Component.Entities, entity:GetId())
	Component.ComponentRemoved:Fire(entity, self)
end

--------

function COMPONENT_UNIT.GetId(self: Types.ComponentUnit): string
	return self.UnitId
end

function COMPONENT_UNIT.GetComponent(self: Types.ComponentUnit): Types.Component
	return Pools.Components[self.ComponentId]
end

---------

function COMPONENT_UNIT.Destroy(self: Types.ComponentUnit)
	self.Changed:DisconnectAll()
	TableUtil.FastRemoveFirstValue(self:GetComponent().Units, self.UnitId)
	Pools.ComponentUnits[self.UnitId] = nil
end

-----------------------------------------------------------------------------------------------

local function newUnit(Component: Types.Component, data: any, typecheck: boolean?, syncData: any?): Types.ComponentUnit
	assert(Component.ClassName == "Component", 
		"Invalid call of new ComponentUnit. "..
		"If using 'new' make sure you are calling with format MyComponent:New(...)"
	)
	
	if syncData and Pools.ComponentUnits[syncData.UnitId] then
		local unit = Pools.ComponentUnits[syncData.UnitId]
		if data.ClassName == "Type" then
			unit:Set(data)
		else
			for key, newValue in pairs(data) do
				unit:Set(newValue, key)
			end
		end
		warn("Overwriting Component Info")
		return unit
	end
	
	if typecheck ~= false or TYPE_CHECK then
		local success, message = TypeCheckTable(Component.Template, data)
		if not success then
			error(message .. " (typecheck)", 2)
		end
	end
	
	local unit = setmetatable({
		ComponentId = tostring(Component.Id),
		UnitId = tostring(UNIT_GLOBAL_ID),
		EntityIds = {},
		Data = data,
		Changed = Signal.new(nil),
		SyncEnabled = false,
	}, COMPONENT_UNIT)
	
	
	
	if syncData then
		unit.UnitId = syncData.UnitId
	else
		UNIT_GLOBAL_ID += 2
	end
	
	table.insert(Pools.Components[unit.ComponentId].Units, unit.UnitId)
	Pools.ComponentUnits[unit.UnitId] = unit
	
	-- warn("New Component Created - ", unit)
	return unit :: Types.ComponentUnit
end


--------------------------------------------------------------------------------------------------
-- COMPONENT CLASS --
--------------------------------------------------------------------------------------------------

local COMPONENT = {}
COMPONENT.ClassName = "Component"
COMPONENT.__index = COMPONENT
COMPONENT.__call = newUnit
COMPONENT.NewUnit = newUnit
COMPONENT.New = newUnit
COMPONENT.new = newUnit


function COMPONENT.CleanUp(self: Types.Component)
	for _, id: string in pairs(self.Units) do
		local unit: Types.ComponentUnit = Pools.ComponentUnits[id]
		if #unit.EntityIds == 0 then -- if no more entities are associated with the unit clean it up
			unit:Destroy()
		end
	end
end

-- returns the associated actual or shortcut key and whether or not it is the shortcutKey or not
function COMPONENT.GetKeyFrom(self: Types.Component, key: string): ((number | string), boolean)
	local template: {[string | number]: Types.Type} = self.Template
	if template[key] then
		return self.PropertyShortcuts[key], true
	end
	return self.PropertyShortcuts["AssociatedKeyOf"..key], false
end

table.freeze(COMPONENT)

-----------------------------------------------------------------------------------------------------------------------------------

local function CheckForExistingComponent(template: Types.ComponentTemplate, name: string): Types.Component?
	for id: string, component in pairs(Pools.Components) do
		if component.Name == name and typeof(template) == typeof(component.Template) and typeof(template) == "table" then
			if template.ClassName ~= "Type" then
				local template: { [string | number]: Types.Type} = template
				local valid = true
				for key: string | number, Type: Types.Type in pairs(component.Template) do
					if not template[key] or template[key].name ~= Type.name then
						valid = false
						break
					end
				end
				if valid then
					return component
				end
			elseif template.name == component.Template.name then
				return component
			end
		end
	end
	
	return nil
end

local function getTemplateKeys(template: Types.ComponentTemplate): {[string]: (string)}?
	if template.ClassName == "Type" then
		return nil;
	end
	local letterCode = 65
	local keys = {}
	for key, _ in pairs(template) do
		local letter: string = string.char(letterCode)
		keys[key] = string.char(letterCode)
		keys["AssociatedKeyOf"..letter] = key
		letterCode += 1
	end
	return keys;
end

local function validateTemplate(template: Types.ComponentTemplate): boolean
	local errMsg = "Improper Component Template Construction. " ..
		"Please use the Type class to define the component type instead of a single string."
	
	if typeof(template) == "table" and not template.ClassName == "Type" then
		for key, dataType: Types.Type | string in pairs(template) do
			if typeof(dataType) == "string" then
				error(errMsg)
			end
		end
		return false
	elseif typeof(template) == "string" then
		error(errMsg)
	end
	return true
end


local function newComponent(template: Types.ComponentTemplate, name: string, syncData: any?): Types.Component
	local isSingleValue = validateTemplate(template)
	
	local existing = CheckForExistingComponent(template, name)
	if existing then return existing end -- if matching Component already exists just use it instead

	local component: Types.Component = setmetatable({
		Id = tostring(GLOBAL_ID),
		Template = template,
		Entities = {},
		Units = {},
		ComponentAdded = Signal.new(nil),
		ComponentRemoved = Signal.new(nil),
		Name = name,
		
		PropertyShortcuts = getTemplateKeys(template)

	}, COMPONENT) :: Types.Component
	
	if syncData then
		component.Id = syncData.Id
	else
		GLOBAL_ID += 2
	end
	
	table.freeze(template)
	table.freeze(component)

	Pools.Components[component.Id] = component -- register Component

	return component :: Types.Component
end

return newComponent;

--------------------------------------------------------------------------------------------------
-- COMPONENT CLASS --
--------------------------------------------------------------------------------------------------

--local function new(tbl, ...): Types.Component
--	if typeof(tbl) == "table" and tbl.ClassName == "ComponentConstructorContainer" then
--		return newComponent(...)
--	end
--	return newComponent(tbl, ...)
--end

--local ConstructorContainer = {
--	ClassName = "ComponentConstructorContainer",
--	New = new,
--	new = new,
	
--	__call = new,
--}
--ConstructorContainer.__index = ConstructorContainer
--table.freeze(ConstructorContainer)

--return setmetatable({}, ConstructorContainer) :: {
--	new: (template: Types.ComponentTemplate, name: string, syncData: any?) -> Types.Component,
--	New: (template: Types.ComponentTemplate, name: string, syncData: any?) -> Types.Component,
--}