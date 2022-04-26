--!strict
--[[
	Author: Raildex
	Date Created: 02/17/2022
	Last Updated: 04/13/2022
	
	This Module is meant to be used as an intermediary handler for creating custom Luau objects.
	It is intended to simplify the management of complex objects. It is suggested that you use the
	provided folder structure for managing objects as you can specify modules by name rather than
	reference for ease of use. You can think of it as an alternate method of Requiring an object
	based module. There should be very little change from your standard luau OOP implementations.
	
	Usage:
		[Your Object's Module]--------------------------------------------------------------------------------
		
			local RS = game:GetService("ReplicatedStorage")
			local Object = require(RS.ROAM.Internal.Object)
			
			local ExampleClass = {
				ClassName = "ExampleClass",		-- If unspecified ROAM will assume the ClassName is the Module name, however it is highly recommended you set this yourself.
				Super = RS.ExampleParentClass	-- If this class inherits another module then set the path to it here (DO NOT REQUIRE IT)
				Client = {
				
				},
			}

			function ExampleClass.new(a,b,c, ...)
				local self = ExampleClass:Setup(...); -- calls the parent classes to setup inheritance at the top level and then build back down to this class
				
				-- Set class variables
				self.A = a;
				self.B = b;
				self.C = c;
				
				return self;
			end
			
			return Object(script, ExampleClass)	-- You MUST have this line to copy over all ROAM internal methods for everything to work
		
		[Some other Script]------------------------------------------------------------------------------------
	
			local RS = game:GetService("ReplicatedStorage")
			local ROAM = require(RS.ROAM)
			ROAM.OnStart():await()
		
			local MyClass = require(YourObjectModulePath)
			local MyObject = MyClass.new(1,2,3)
			
			print( MyObject.ClassName )			Output: 'ExampleClass'
			print( MyObject.B )					Output: '2'
]]



--[[ Automatically Implemented Properties
	-- Global Class Properties --
	.ClassName: string	
	.Super: (ModuleScript | EntityClass)?
	.Types: {string}
	.Implements: {ModuleScript}
	.Client: {string: any}?		-- Only Server Size Objects may have this property, 
	.Server: {string: any}?		-- Only Client Size Objects may have this property
	
	-- Idividual Object Properties --
	.Internal: ObjectInternals		(Dont mess with this unless you're absolutely sure you know what youre doing)
	.OnDestroy: Signal
	
]]

--[[ Automatically Implemented Methods:
	:Destroy() 
	:Is(string): boolean -- Similar to the Instance class IsA, uses a different syntax to prevent conflicts
	:GetTypes(): {string} -- Mainly used for debugging
	:GetId(): number
	:AddEvent(string)
	:GetEvent(string): Signal
	:AddTag(string | Types.Tag)
	:RemoveTag(string | Types.Tag)
	:HasTag(string | Types.Tag): boolean
	:GetTags(): {Types.Tag}
	
	:Serialize(): SerialData
	.Deserialize(SerialData): Entity
	
	:AddComponent(ComponentUnit, string?)
	:GetComponent(string): ComponentUnit
	:RemoveComponent(string): ComponentUnit
	:SetComponentValue(string, any?, string?)
	
	:SetSyncedPlayers( (Player | {Player})?, (Player | {Player})? )
	:Sync( ... )
	:FlushComponents(...string?)
	:ForceFlushComponents(...string?)
	
	:Setup(...): {any} (This should only ever be used once, in the constructor, it is imperative that you use this)
]]


------------------------------------------------------------------------------------------------------------------
	--// References //--
------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ROAM: ModuleScript	= ReplicatedStorage.ROAM
local Internal	 			= script.Parent
local NL: Folder 			= Internal:FindFirstChild("NetworkLayer") :: Folder
local Shared: Folder   		= ROAM:FindFirstChild("Shared") :: Folder

local ApplySharedMethods = require(script.ApplySharedMethods)

local ROAM		= require(ROAM)
local Types 	= require(Internal.Types)
local Pools 	= require(Internal.Pools)
local Tag 		= require(Internal.Tag)
local Maid 		= require(Internal.Maid)
local Signal 	= require(Internal.Signal)
local Promise	= require(Internal.Promise)
local TableUtil = require(Internal.TableUtil)

local ReservedIndexes = {"Comms", "Client", "Server", "new"}

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

------------------------------------------------------------------------------------------------------------------
	--// Type Declarations //--
------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
	--// Global Variables //--
------------------------------------------------------------------------------------------------------------------
-- This is used to keep a list of everything already cached so we dont cache again
local CachedObjectClasses: {[string]: Types.EntityClass} = {}

------------------------------------------------------------------------------------------------------------------
	--// Private Functions //--
------------------------------------------------------------------------------------------------------------------



local function buildNetworkLayer(class: Types.EntityClass, _module: ModuleScript?)
	local CommsFolder: Folder = NL:FindFirstChild(class.ClassName.."_Comms") :: Folder or Instance.new("Folder")
	CommsFolder.Name = class.ClassName.."_Comms"

	local AssociatedModuleRef: ObjectValue = Instance.new("ObjectValue")
	AssociatedModuleRef.Name = "AssociatedModule"
	AssociatedModuleRef.Value = _module
	AssociatedModuleRef.Parent = CommsFolder
	
	if class.Super then
		local ParentNetworkLayer: ObjectValue = Instance.new("ObjectValue")
		ParentNetworkLayer.Name = "ParentNetworkLayer"
		ParentNetworkLayer.Value = buildNetworkLayer(class.Super)
		ParentNetworkLayer.Parent = CommsFolder
	end

	local RemotesFolder: Folder = CommsFolder:FindFirstChild("Remotes") :: Folder or Instance.new("Folder")
	RemotesFolder.Name = "Remotes"
	RemotesFolder.Parent = CommsFolder
	local FunctionsFolder: Folder = RemotesFolder:FindFirstChild("Functions") :: Folder or Instance.new("Folder")
	FunctionsFolder.Name = "Functions"
	FunctionsFolder.Parent = RemotesFolder
	local EventsFolder: Folder = RemotesFolder:FindFirstChild("Events") :: Folder or Instance.new("Folder")
	EventsFolder.Name = "Events"
	EventsFolder.Parent = RemotesFolder

	CommsFolder.Parent = NL
	return CommsFolder
end


local function ServerWrapMethod(method, name: string, parent: Folder)
	local RemoteFunction = Instance.new("RemoteFunction")
	local RemoteEvent = Instance.new("RemoteEvent")
	
	RemoteFunction.OnServerInvoke = function(player: Instance, entityId: string, ...)
		local entity = Pools.Objects[entityId]
		assert(entity, "Could not find corresponding server entity.")
		return method(entity, player, ...)
	end
	RemoteEvent.OnServerEvent:Connect(function(player: Instance, entityId: string, ...)
		local entity = Pools.Objects[entityId]
		assert(entity, "Could not find corresponding server entity.")
		method(entity, player, ...) -- discard return values
	end)
	
	RemoteFunction.Name = name
	RemoteFunction.Parent = parent
	RemoteEvent.Name = name.."_Event"
	RemoteEvent.Parent = parent
end

local function ServerWrapEvent(class: Types.EntityClass, name: string, parent: Folder)
	local RemoteEvent: RemoteEvent = Instance.new("RemoteEvent")
	
	local connections = {}
	
	class.EntityAdded:Connect(function(entity: Types.Entity)
		entity.Client = (rawget(entity,"Client") or setmetatable({Server = entity},{__index = class.Client}))
		
		local outbound: Types.Signal = Signal.new(nil)
		local inbound:  Types.Signal = Signal.new(nil)
		
		local middleware = {
			object = entity,
			FireServer 	= function(m, ...) return inbound:Fire(...) 		end,
			Wait 		= function(m, ...) return inbound:Wait(...) 		end,
			WaitPromise = function(m, ...) return inbound:WaitPromise(...) 	end,
			Connect 	= function(m, ...) return inbound:Connect(...) 		end,
			FireClient 	= function(m, ...) return outbound:Fire(...) 		end,
			Fire 		= function(m, ...) return outbound:Fire(...) 		end,
		}
		
		outbound:Connect(function(...)
			if not entity:IsSynced() then
				return warn("Cannot Fire RemoteEvent on Entity that isnt Synced")
			end
			local id: string = entity:GetId()
			local plrs = entity:GetSyncedPlayers()
			for _, plr in ipairs(plrs) do
				RemoteEvent:FireClient(plr, id, ...)
			end
		end)
		
		entity.Client[name] = middleware
		connections[entity:GetId()] = middleware 
		
		entity.OnDestroy:Connect(function()
			inbound:Destroy()
			outbound:Destroy()
			entity.Client[name] = nil
			connections[entity:GetId()] = nil
		end)
	end)
	
	
	RemoteEvent.OnServerEvent:Connect(function(player: Player, entityId, ...)
		local middleware = connections[tostring(entityId)]
		if middleware then
			middleware:FireServer(middleware.object, player, ...)
		end
	end)
	
	RemoteEvent.Name = name
	RemoteEvent.Parent = parent
	
	return RemoteEvent
end

local function ClientWrapEvents(class: Types.EntityClass, event: RemoteEvent)
	local connections = {}

	class.EntityAdded:Connect(function(entity: Types.Entity)
		entity.Server = rawget(entity, "Server") or setmetatable({Client = entity},{__index = class.Server})
		
		local class = class

		local outbound: Types.Signal = Signal.new(nil)
		local inbound:  Types.Signal = Signal.new(nil)

		local middleware = {
			object = entity,
			FireClient 	= function(m, ...) return inbound:Fire(...) 		end,
			Wait 		= function(m, ...) return inbound:Wait(...) 		end,
			WaitPromise = function(m, ...) return inbound:WaitPromise(...) 	end,
			Connect 	= function(m, ...) return inbound:Connect(...) 		end,
			FireServer 	= function(m, ...) return outbound:Fire(...) 		end,
			Fire 		= function(m, ...) return outbound:Fire(...) 		end,
		}

		outbound:Connect(function(...)
			if not entity:IsSynced() then
				return warn("Cannot Fire RemoteEvent on Entity that isnt Synced")
			end
			local id: string = entity:GetId()
			event:FireServer(id, ...)
		end)
		
		local serverId: string = tostring(entity:GetId()-1)
		
		entity.Server[event.Name] = middleware
		connections[serverId] = middleware 

		entity.OnDestroy:Connect(function()
			inbound:Destroy()
			outbound:Destroy()
			entity.Server[event.Name] = nil
			connections[serverId] = nil
		end)
	end)


	event.OnClientEvent:Connect(function(entityId: string, ...)
		ROAM.OnStart():await()
		local middleware = connections[tostring(entityId)]
		if middleware then
			middleware:FireClient(...)
		end
	end)
	
	return event
end



local function SetupRemotesServer(class: Types.EntityClass)
	assert(class.Client)
	
	local Remotes = class.Comms.Remotes
	
	for key, v in pairs(class.Client) do
		if type(v) == "function" then
			ServerWrapMethod(v, key, Remotes.Functions)			
		elseif v == ROAM.CreateRemoteEvent() then
			class.Client[key] = ServerWrapEvent(class, key, Remotes.Events)
		end
	end
end


local function SetupRemotesClient(class: Types.EntityClass)
	local comms = class.Comms
	repeat
		for _, RF: RemoteFunction in ipairs(comms.Remotes.Functions:GetChildren()) do
			if not RF:IsA("RemoteFunction") then
				continue
			end
			assert(class.Server)
			assert(class.Server[RF.Name] == nil, "The Index '"..RF.Name.."' was reserved by the Server.")
			local RE: RemoteEvent = comms.Remotes.Functions:FindFirstChild(RF.Name.."_Event")
			
			local methodStorage = class.Server
			
			local invoke = function(self: {Client: Types.Entity}, ...)
				local self: Types.Entity = self.Client
				assert(self:IsSynced(), "NetworkMethods cannot be called in the Constructor.")
				return RF:InvokeServer(self:GetId(), ...)
			end
			methodStorage[RF.Name] = invoke
			methodStorage["Invoke"..RF.Name] = invoke
			
			methodStorage[RF.Name.."Async"] = function(self: {Client: Types.Entity}, ...)
				local self: Types.Entity = self.Client
				local args = {...}
				assert(self:IsSynced(), "NetworkMethods cannot be called in the Constructor.")
				return Promise.new(function(resolve)
					RF:InvokeServer(self:GetId(), table.unpack(args))
				end)
			end
			
			local event = function(self: {Client: Types.Entity}, ...)
				local self: Types.Entity = self.Client
				assert(self:IsSynced(), "NetworkMethods cannot be called in the Constructor.")
				RE:FireServer(self:GetId(), ...) -- discard return values
			end
			methodStorage["Fire"..RF.Name] = event
		end
		
		if comms:FindFirstChild("ParentNetworkLayer") then
			comms = comms.ParentNetworkLayer.Value
		else
			comms = nil
			break
		end
	until comms == nil
	
	---------------------------------------------------------------------------------------------
	local comms = class.Comms -- reload to base comms
	
	repeat
		for _, RE: RemoteEvent in ipairs(comms.Remotes.Events:GetChildren()) do
			if not RE:IsA("RemoteEvent") then
				continue
			end
			assert(class.Server)
			assert(class.Server[RE.Name] == nil, "The Index '"..RE.Name.."' was reserved by the Server.")
			
			ClientWrapEvents(class, RE)
		end
		
		if comms:FindFirstChild("ParentNetworkLayer") then
			comms = comms.ParentNetworkLayer.Value
		else
			comms = nil
			break
		end
	until comms == nil
end


------------------------------------------------------------------------------------------------------

local cacheStack: number = 0

local function cacheClass(class: any, _module: ModuleScript?): Types.EntityClass
	cacheStack += 1
	local benchmark: number = os.clock()
	
	local className: string

	if class.ClassName then
		assert(type(class.ClassName) == "string", "Class must have a defined ClassName property.")
		className = class.ClassName
	elseif _module then
		assert(typeof(_module) == "Instance" and _module:IsA("ModuleScript"),
			"Passed Class lacks a ClassName and passed secondary arg is not a ModuleScript")
		className = _module.Name
	else
		error("No module or classname found")
	end
	
	if CachedObjectClasses[className] then
		assert(CachedObjectClasses[className] == class, "Two classes cannot share the same ClassName: "..className)
		warn("Already Cached")
		-- We dont warn or error here because multiple classes might share parent classes that are already cached
		return CachedObjectClasses[className]
	end
	
	warn("Caching Class: " .. className .. " | Stack: "..cacheStack)
	
	
	-- DECLARE ANY STATIC PROPERTIES OF THE CLASS HERE
	CachedObjectClasses[className] = class -- store this class for later use
	class.ClassName = className
	class.Types = class.Types or {}
	class.Extends = class.Extends or {}
	class.Entities = {}
	class.EntityAdded = Signal.new(nil)
	class.EntityRemoved = Signal.new(nil)
	
	if class.__index and class.__index ~= class then
		warn("Overwriting __index for class")
	end
	class.__index = class.__index or class -- setup __indexing if it hasnt been done already
	
	-- CLASS PRE-EXISTENCE ASSERTIONS
	assert(class.new, "Every object class must have a constructor of name .new()")
	
	
	-- cache the superclass, check if one is already set, if not then assume the parent is the superclass
	if class.Super then
		if typeof(class.Super) == "Instance" then
			assert(class.Super:IsA("ModuleScript"), className.." Super must be a ModuleScript")
			class.Super = require(class.Super)
		elseif typeof(class.Super) == "table" then
			class.Super = cacheClass(class.Super)
		else
			error("Super in an invalid type. Expected 'ModuleScript' or 'EntityClass'. Got: "..typeof(class.Super))
		end

	else
		-- if a Super isnt already specified then assume the parent of the module (DO I WANT TO KEEP THIS?)
		if _module and _module.Parent and _module.Parent:IsA("ModuleScript") then
			class.Super = require(_module.Parent)
		end
	end
	
	if class.Client then
		assert(IS_SERVER, "Client Modules cannot have Client Tables")
		assert(Internal.NetworkLayer:FindFirstChild(class.ClassName.."_Comms") == nil, "Class "..class.ClassName.." already has a comms folder.")
		assert(class.Comms == nil, "Comms is a reserved Class Index")
		
		class.__index = class
		class.Comms = buildNetworkLayer(class, _module)
		
		SetupRemotesServer(class)
	elseif RunService:IsClient() then -- TODO: Review this code, we probably shouldnt be always giving a server value.
		class.Comms = Internal.NetworkLayer:WaitForChild(class.ClassName.."_Comms",1)
		assert(class.Server == nil, "Server is a reserved Class Index")
		
		class.Server = class.Server or {}
		assert(typeof(class.Server) == "table", "Class Server Index must be a table.")
		class.EntityAdded:Connect(function(entity: Types.Entity)
			entity.Server = rawget(entity, "Server") or setmetatable({Client = entity},{__index = class.Server})
		end)
		
		
		if class.Comms then
			class.Comms.AssociatedModule.Value = _module
			SetupRemotesClient(class)
		end
		
	end
	
	
	if class.new then
		-- Overload with some custom new method
	end
	
	-- Do some really funky stuff with the destroy methods if one exists
	if class.Destroy then
		assert(typeof(class.Destroy) == "function", className.." class has 'Destroy' set to something other than a function.")
		class.__Destroy = class.Destroy
		class._Destroy = function(tbl)
			local class = class
			class.__Destroy(tbl)
			while class.Super do
				class = class.Super
				if class.__Destroy then
					class.__Destroy(tbl)
				end
			end
		end
		class.Destroy = nil
	end
	
	if class.Serialize then
		assert(typeof(class.Serialize) == "function", className.." class has 'Serialize' set to something other than a function.")
		
	end
	
	if class.Deserialize then
		assert(typeof(class.Deserialize) == "function", className.." class has 'Deserialize' set to something other than a function.")
		
	end

	
	if class.Super then
		for index, func in pairs(class.Super) do
			if typeof(func) == "function" and not class[index] and not table.find(ReservedIndexes, index) then
				class[index] = func
			end
		end
	end
	
	
	--TODO: Add Interface Support
	--[[
	for _, interface in pairs(class.Extends) do
		if typeof(interface) == "string" then
			interface = 
		elseif typeof(interface) == "Instance" then
			interface = require(interface)
		end
	end
	]]
	
	--if class.Implements then
	--	assert(typeof(class.Implements) == "table")

	--	for _, module: ModuleScript in pairs(class.Implements) do
	--		assert(typeof(module) == "Instance")
	--		assert(module:IsA("ModuleScript"))

	--		local ImplementedClass = cacheClass(module)

	--		for index, func in pairs(ImplementedClass) do
	--			if typeof(func) == "function" and not class[index] then
	--				class[index] = func
	--			end
	--		end
	--	end

	--end
	
	
	
	--TODO: Add Component Support
	
	ApplySharedMethods(class)
	
	warn("Cached  Class: "..className.." in: ",math.ceil((os.clock()-benchmark)*1000000)/1000,"ms.")
	if class.Init then
		class:Init()
	end
	
	class._Cached = true
	
	cacheStack -= 1
	return class;
end


------------------------------------------------------------------------------------------------------------------
	--// Core //--
------------------------------------------------------------------------------------------------------------------

return function(class: {} | string, _module: ModuleScript?): Types.EntityClass
	assert(class)
	
	if type(class) == "string" then
		if CachedObjectClasses[class] == nil then
			warn("Could not find cached class",class)
		end
		return CachedObjectClasses[class]
	end
	
	local class: Types.EntityClass = cacheClass(class, _module)
	
	return class
end
