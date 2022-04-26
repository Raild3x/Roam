--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService 		= game:GetService("RunService")
local Players 			= game:GetService("Players")

local Package = script.Parent.Parent -- Internal Folder

local NetworkManager = require(Package.NetworkManager)

local Types 	= require(Package.Types)
local Pools 	= require(Package.Pools)
local Tag 		= require(Package.Tag)
local Maid 		= require(Package.Maid)
local Signal 	= require(Package.Signal)
local Promise 	= require(Package.Promise)
local TableUtil = require(Package.TableUtil)

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local GLOBAL_ID = IS_SERVER and 1 or 2

local __NEXT_ID: string? = nil

local _IsBaseClass = true

------------------------------------------------------------------------------------------------------------------
--// Utility Functions //--
------------------------------------------------------------------------------------------------------------------

script.Parent.FlagNextId.Event:Connect(function(id: string)
	__NEXT_ID = id
end)


local function getTag(_tag: string | Types.Tag): Types.Tag
	local tag: Types.Tag
	if typeof(_tag) == "string" then
		tag = Tag(_tag)
	else
		tag = _tag
	end
	return tag
end


------------------------------------------------------------------------------------------------------------------
--// Functions To Apply //--
------------------------------------------------------------------------------------------------------------------

local function Destroy(self: Types.Entity)
	if self.__DESTROYED then
		return warn("Object already destroyed") -- if this is bugging you then you can safely remove this warn
	end
	self.__DESTROYED = true

	TableUtil.FastRemoveFirstValue(self.Entities,self:GetId())
	self.EntityRemoved:Fire(self)
	if self._Destroy then
		self:_Destroy()
	end
	self.Internal.Maid:Destroy()
	--warn("Destroying Object "..self:GetId())
end

---------------------------------------------------------------

local function Serialize(self: Types.Entity): Types.SerialData -- TODO: Go over this
	-- Get Tags at time of Serialization
	local tagList: {Types.Tag} = self:GetTags()
	local tagNames: {string} = {}
	for _, tag: Types.Tag in pairs(tagList) do
		table.insert(tagNames, tag.Name)
	end
	
	local class: Types.EntityClass = getmetatable(self)
	-- Get Components at time of Serialization

	-- Construct SerialData
	local serialData: Types.SerialData = {
		Tags = tagNames,
		Components = {},
		UserSerialData = class._Serialize(self),
		ClassName = self.ClassName
	}

	return serialData
end

---------------------------------------------------------------
--[[
	Handles which players to sync the Entity with.
	@param _playersToSync:		Can be a player or table of players. If set to nil then it will assume all players.
	@param _playersToIgnore:	Can be a player or table of players. Any player in this table will not be synced with
								even if they are in the _playersToSync table.
]]--
local function SetSyncedPlayers(self: Types.Entity, _playersToSync: (Player | {Player})?, _playersToIgnore: (Player | {Player})?)
	assert(IS_SERVER, ":SetSyncPlayers() can only be called from the Server.")

	-- Get the players to sync with
	local plrIds: {number}? = {}
	if typeof(_playersToSync) ~= "table" and _playersToSync then -- if is single user
		plrIds = {_playersToSync.UserId}
	elseif typeof(_playersToSync) == "table" then
		plrIds = {}
		for _, plr in pairs(_playersToSync) do
			table.insert(plrIds :: {number}, plr.UserId)
		end
	else
		plrIds = nil
	end 

	self.Internal.SyncedPlayers = plrIds;
	
	-- get players to ignore
	local plrIds: {number}? = {}
	if typeof(_playersToIgnore) ~= "table" and _playersToIgnore then -- if is single user
		plrIds = {_playersToIgnore.UserId}
	elseif typeof(_playersToIgnore) == "table" then
		plrIds = {}
		for _, plr in pairs(_playersToIgnore) do
			table.insert(plrIds :: {number}, plr.UserId)
		end
	else
		plrIds = nil
	end 

	self.Internal.IgnoredPlayers = plrIds;
end



local function GetSyncedPlayers(self: Types.Entity): {Player}
	if self.Internal.SyncedPlayers then
		local plrs: {Player} = {}
		for _, userId: number in ipairs(self.Internal.SyncedPlayers) do
			if not self.Internal.IgnoredPlayers or not table.find(self.Internal.IgnoredPlayers, userId) then
				table.insert(plrs, Players:GetPlayerByUserId(userId))
			end
		end
		return plrs
	else
		local plrs: {Player} = {}
		for _, plr: Player in ipairs(Players:GetPlayers()) do
			if not self.Internal.IgnoredPlayers or not table.find(self.Internal.IgnoredPlayers, plr.UserId) then
				table.insert(plrs, plr)
			end
		end
		return plrs
	end
end

--[[
	Marks this entity as visible to clients and exposes its components and remote methods.
	@param ...:	a tuple of any network safe types that will be used as the arguments for the client-side constructor. 
]]--
local function Sync(self: Types.Entity, ...:any)
	assert(RunService:IsServer(), ":Sync() can only be called from the Server.")
	assert(getmetatable(self).Client, "No client table found, cannot sync")

	if self.Internal.SyncEnabled then
		error("Already Synced")
		return
	end

	self.Internal.SyncEnabled = {...};

	-- Sync all attached Component Units
	for _, unit: Types.ComponentUnit in pairs(self.Internal.Components) do
		unit:Sync()
	end

	-- Check for an associated Shared Module
	if not self.Comms then
		warn("No Shared given for class, Client Object will only contain components.")
	end

	NetworkManager.CreateObjectOnClient(self, ...)
end

--[[
	Tells the server to queue the current values of its components to syncable clients.
	@param ...:	A tuple of strings that are the names of the components you want to specifically flush. 
				If none are specified than all are assumed.
]]--
local function FlushComponents(self: Types.Entity, ...: string)
	assert(IS_SERVER, ":FlushComponents() can only be called from the Server.")
	assert(self:IsSynced(), "Cannot Flush an object that isnt synced.")

	local componentKeys: {string} = {...}
	if #componentKeys == 0 then
		for _, component in pairs(self.Internal.Components) do
			component:Flush()
		end
	else
		for _, componentName in pairs(componentKeys) do
			self.Internal.Components[componentName]:Flush()
		end
	end
end

--[[
	Tells the server to immediately send the current values of its components to syncable clients.
	@param ...:	A tuple of strings that are the names of the components you want to specifically flush. 
				If none are specified than all are assumed.
]]--
local function ForceFlushComponents(self: Types.Entity, ...: string)
	assert(RunService:IsServer(), ":FlushComponents() can only be called from the Server.")
	assert(self:IsSynced(), "Cannot Flush an object that isnt synced.")

	local componentKeys: {string} = {...}
	if #componentKeys == 0 then
		for _, component in pairs(self.Internal.Components) do
			component:ForceFlush()
		end
	else
		for _, componentName in pairs(componentKeys) do
			self.Internal.Components[componentName]:ForceFlush()
		end
	end
	warn("ForceFlushed ComponentUnits")
end


-------------------------------------------------------------------------------------------

local function Is(self: Types.EntityClass, Name: string): boolean
	return (Name == "Object") 
		or (Name == self.ClassName) 
		or (table.find(self.Types, Name) ~= nil) 
		or (self.Super and self.Super:Is(Name))
end


local function IsSynced(self: Types.Entity)
	if IS_CLIENT then
		return tonumber(self.Internal.Id) % 2 == 1
	end
	return self.Internal.SyncEnabled;
end

-------------------------------------------------------------------------------------------

local function GetTypes(self: Types.Entity): {string}
	local types = self.Types or getmetatable(self).Types
	local typeList = TableUtil.Copy(types)
	table.insert(typeList, self.ClassName)
	if self.Super then
		local parentTypes = self.Super:GetTypes()
		for i = 1, #parentTypes do
			if not table.find(typeList, parentTypes[i]) then
				table.insert(typeList, parentTypes[i])
			end
		end
	end
	return typeList
end

local function GetId(self: Types.Entity): string
	return self.Internal.Id;
end

-------------------------------------------------------------------------------------------

local function AddEvent(self: Types.Entity, eventName: string): nil
	assert(self.Internal.Events[eventName] == nil, "Event with Name "..eventName.." already exists.");
	local event: Types.Signal = Signal.new(nil);
	self.Internal.Events[eventName] = event;
	return nil;
end

local function GetEvent(self: Types.Entity, eventName: string): Types.Signal
	return self.Internal.Events[eventName];
end

-------------------------------------------------------------------------------------------

local function HasTag(self: Types.Entity, _tag: string | Types.Tag): boolean
	local tag: Types.Tag = getTag(_tag)
	if table.find(self.Internal.Tags, tag.Id) then
		return true
	else
		return false
	end
end

local function AddTag(self: Types.Entity, _tag: string | Types.Tag)
	local tag: Types.Tag = getTag(_tag)

	if table.find(self.Internal.Tags, tag.Id) then
		return warn(self.ClassName.." Object is already tagged with Tag: '"..tag.Name.."'\t[Tag was not added]")
	end

	table.insert(tag.Entities, self:GetId())
	table.insert(self.Internal.Tags, tag.Id)
	tag.TagAdded:Fire(self)

	if self:IsSynced() then

	end
end

local function RemoveTag(self: Types.Entity, _tag: string | Types.Tag)
	local tag: Types.Tag = getTag(_tag)
	local idx: number? = table.find(self.Internal.Tags, tag.Id)
	if not idx then
		warn("Class already does not have Tag "..tag.Name)
		return
	end
	table.remove(self.Internal.Tags,idx)
	local idx2: number? = table.find(tag.Entities,self:GetId())
	table.remove(tag.Entities, idx2)
	tag.TagRemoved:Fire(self)
end

local function GetTags(self: Types.Entity): {Types.Tag}
	local list: {Types.Tag} = {}
	for _, id in pairs(self.Internal.Tags) do
		table.insert(list, Pools.Tags[id])
	end
	return list
end

local function GetTagNames(self: Types.Entity): {string}
	local list: {string} = {}
	for _, id in pairs(self.Internal.Tags) do
		table.insert(list, Pools.Tags[id].Name)
	end
	return list
end

-------------------------------------------------------------------------------------------

local function GetComponent(self: Types.Entity, componentName: string): Types.ComponentUnit
	local compTbl = self.Internal.Components
	local unit = compTbl[componentName]
	if not unit then
		error("Object has no compenent with name: "..componentName)
	end
	return compTbl[componentName]
end

local function AddComponent(self: Types.Entity, unit: Types.ComponentUnit, componentName: string?): Types.ComponentUnit
	local compTbl = self.Internal.Components
	local componentName: string = componentName or Pools.Components[unit.ComponentId].Name
	assert(componentName, "No Component name given or inferred.")
	assert(compTbl[componentName] == nil, "Object already has a component with name: "..componentName)
	compTbl[componentName] = unit

	unit:AddEntity(self)

	if self:IsSynced() and IS_SERVER then
		unit:Sync()
		NetworkManager.AddComponentToClient(self, unit)
	end

	return unit;
end

local function RemoveComponent(self: Types.Entity, componentName: string): Types.ComponentUnit
	local compTbl = self.Internal.Components
	local unit: Types.ComponentUnit = compTbl[componentName]
	if not unit then
		error("Object has no compenent with name: "..componentName)
	end

	local Component: Types.Component = Pools.Components[unit.ComponentId]
	local idx: number? = table.find(Component.Entities, self:GetId())
	assert(idx, "Could not find Entity in Component Table")
	compTbl[componentName] = nil

	unit:RemoveEntity(self)

	return unit;
end

local function WaitForComponent(self: Types.Entity, componentName: string, _timeOut: number?): Types.Promise
	local startTime: number = os.clock()
	return Promise.new(function(resolve, reject, onCancel)
		local loop = true
		onCancel(function()
			loop = false
		end)
		
		while loop do
			task.wait()
			if self.Internal.Components[componentName] then
				return resolve(self:GetComponent(componentName))
			end
			if _timeOut and os.clock() >= startTime + _timeOut then
				return reject()
			end
		end
	end)
end



------------------------------------------------------------------------------------------------------------------
--// Main Function //--
------------------------------------------------------------------------------------------------------------------

return function(class: any)

	-- This function is the key to everything! --
	function class.Setup(self: Types.EntityClass, ...): Types.Entity

		local IsBaseClass = _IsBaseClass
		_IsBaseClass = false

		local object = {}


		if self.Super then
			local super: Types.EntityClass = self.Super :: Types.EntityClass
			object = super.new(...)
			setmetatable(object, self)
		else
			object = {} :: Types.Entity

			setmetatable(object, self)

			local id = __NEXT_ID or tostring(GLOBAL_ID)
			__NEXT_ID = nil
			GLOBAL_ID += 2

			local internalContainer: Types.ObjectInternals = {
				Id = id,
				Maid = Maid.new(),
				Events = {},
				Tags = {},
				Components = {},
				SyncEnabled = false,
				NetworkOwner = nil,
				SyncedPlayers = nil,
				IgnoredPlayers = nil,
			}

			object.Internal = internalContainer
			Pools.Objects[id] = object

			object:AddEvent("OnDestroy")
			object.OnDestroy = object:GetEvent("OnDestroy")


			internalContainer.Maid:GiveTask(function()

				-- Activate any user specified code before fully clearing
				object.OnDestroy:Fire()

				-- Clear all events (We dont give the maid the signals as tasks so that we have control over deconstruction order)
				for _, signal: Types.Signal in pairs(internalContainer.Events) do
					signal:Destroy()
				end

				-- Clear all associated tags
				for _, tag: Types.Tag in pairs(object:GetTags()) do
					object:RemoveTag(tag)
				end

				-- Clear all components
				for unitName: string, _ in pairs(internalContainer.Components) do
					object:RemoveComponent(unitName)
				end


				-- Remove from the global Pool and entity pool
				Pools.Objects[id] = nil

			end)
		end

		table.insert(self.Entities, object:GetId())
		object.OnDestroy:Connect(function()
			TableUtil.FastRemoveFirstValue(self.Entities, object:GetId())
		end)
		self.EntityAdded:Fire(object)

		_IsBaseClass = IsBaseClass

		return object :: Types.Entity
	end

	-----------------------------------------------------------------------------------

	class.Destroy = Destroy

	-----------------------------------------------------------------------------------

	class.Serialize = Serialize

	function class.Deserialize(serialData: Types.SerialData) --TODO: Go over this
		local newObject = class.new()

		assert(newObject.ClassName == serialData.ClassName, "Invalid class match.")

		class._Deserialize(serialData.UserSerialData)

		for _, tagName in pairs(serialData.Tags) do
			newObject:AddTag(Tag(tagName))
		end

		return newObject
	end

	------------------------------------------------------------------------------------

	class.SetSyncedPlayers = SetSyncedPlayers
	
	class.GetSyncedPlayers = GetSyncedPlayers
	
	class.Sync = Sync
	
	class.FlushComponents = FlushComponents
	
	class.ForceFlushComponents = ForceFlushComponents

	----
	class.Is = Is

	class.IsA = Is -- create an alias to prevent linting issues
	
	class.IsSynced = IsSynced
	----
	
	class.GetTypes = GetTypes
	
	class.GetId = GetId

	----
	
	class.AddEvent = AddEvent

	class.GetEvent = GetEvent

	----

	class.HasTag = HasTag
	
	class.AddTag = AddTag
	
	class.RemoveTag = RemoveTag

	class.GetTags = GetTags
	
	class.GetTagNames = GetTagNames

	----
	
	class.GetComponent = GetComponent
	
	class.AddComponent = AddComponent
	
	class.RemoveComponent = RemoveComponent
	
	class.WaitForComponent = WaitForComponent

end
