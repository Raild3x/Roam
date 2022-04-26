--!strict
--[[
	  ____   ___    _    __  __ 
	 |  _ \ / _ \  / \  |  \/  |
	 | |_) | | | |/ _ \ | |\/| |
	 |  _ <| |_| / ___ \| |  | |
	 |_| \_\\___/_/   \_\_|  |_|
 
 	V1.0
	Author: Raildex
	Date Created: 3/12/2022
	Last Updated: 4/21/2022
	
	ROAM, or Rail's Object Accessibility Manager, is a framework designed to help
	you create and manage complex objects across your game and the network boundary.
	For more information please check out the ReadMe parented to this Module.
	
	To Use ROAM, in some control manager script that starts when the game loads,
	insert the following lines:
	
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local ROAM = require(ReplicatedStorage)
		local ROAM: ROAM.ROAM = ROAM	-- This line informs the linter of ROAM's API
		ROAM.Start():catch(warn):await()	-- This line starts ROAM
		
		-- In some other script you can use this line to wait for ROAM to be ready
		ROAM.OnStart():await()
	
	
	-------------
	--// API //--
	-------------
	ROAM.Tag(string) -> Tag
	ROAM.Query(...: EntityClass | ComponentUnit | Tag ) -> Query
	ROAM.Object({}, ModuleScript?) -> EntityClass
	ROAM.Component({[string] = Type}, string)
	
	ROAM.Util = {
		Maid
		Signal
		Promise
		TableUtil
	}
	
	ROAM.Shared = {
		Objects = {[string]: EntityClass}
		Queries = {[string]: Query}
		Interfaces = {[string]: Interface}
		Components = {[string]: Component}
	}
	
	ROAM.Objects = {[string]: EntityClass}
	ROAM.Queries = {[string]: Query}
	ROAM.Interfaces = {[string]: Interface}
	ROAM.Components = {[string]: Component}
	
	ROAM.GetUpdateRate()
	ROAM.CreateRemoteEvent()
	ROAM.Start()
	ROAM.OnStart()
	
]]

local RunService = game:GetService("RunService")

local internalFolder 	= script.Internal
local sharedFolder 		= script.Shared

local Maid 		= require(internalFolder.Maid)
local Signal 	= require(internalFolder.Signal)
local Promise 	= require(internalFolder.Promise)
local Types 	= require(internalFolder.Types)
local TableUtil = require(internalFolder.TableUtil)
local Tag 		= require(internalFolder.Tag)
local ClassManager = require(internalFolder.ClassManager)

local UPDATE_RATE: number = 1/10

local started = false
local startedComplete = false
local onStartedComplete = Instance.new("BindableEvent")


local REMOTE_EVENT_MARKER = newproxy(true)
getmetatable(REMOTE_EVENT_MARKER).__tostring = function()
	return "REMOTE_EVENT_MARKER"
end

----------------------------------------------------------------------------------------------------
--// Private Functions //--
----------------------------------------------------------------------------------------------------

local function getFolder()
	local folder
	if RunService:IsServer() then
		folder = game:GetService("ServerStorage"):WaitForChild("ROAM", 4)
	else
		folder = game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("ROAM", 4)
	end

	assert(folder, "Failed to find ROAM folder on "..(RunService:IsServer() and "Server" or "Client").."!\n"
		.. "\t\t\t\tPlease make sure you have the proper folder structure to use ROAM."
	)
	return folder
end

----------------------------------------------------------------------------------------------------
--// Type Declarations //--
----------------------------------------------------------------------------------------------------

export type Tag = Types.Tag
export type Query = Types.Query
export type Entity = Types.Entity
export type EntityClass = Types.EntityClass
export type Component = Types.Component
export type ComponentUnit = Types.ComponentUnit

export type Maid = Types.Maid
export type Promise = Types.Promise
export type Signal = Types.Signal
export type Type = Types.Type

export type ROAM = {
	--// Imported Classes //--
	Tag: (name: string) -> Tag,
	Component: (template: Types.ComponentTemplate, name: string) -> Component,
	Object: (class: {ClassName: string}, _module: ModuleScript?) -> EntityClass,
	Query: (toquery: (Types.Queryable | { Types.Queryable })) -> Query,
	Type: (name: Types.DataType) -> Type,
	--Interface:
	
	--// ROAM Folders //--
	Shared: {
		Objects: {[string]: Types.EntityClass},
		Components: {[string]: Types.Component},
		Interfaces: {[string]: Types.Interface},
		Queries: {[string]: Types.Query},
		Modules: {[string]: any},
	},
	
	Objects: {[string]: Types.EntityClass},
	Components: {[string]: Types.Component},
	Interfaces: {[string]: Types.Interface},
	Queries: {[string]: Types.QueryMetaTable},
	Modules: {[string]: any},
	
	Util: {
		Maid: Types.Maid,
		Signal: Signal.Class,
		Promise: Types.Promise,
		TableUtil: TableUtil.TableUtil,
		ClassManager: ClassManager.ClassManager,
	},
	
	--// ROAM Methods //--
	GetUpdateRate: () -> number,
	CreateRemoteEvent: () -> any,
	Start: () -> Types.Promise,
	OnStart: () -> Types.Promise,
}

type ROAM_Internal = {
	_FOLDER: Folder,
	Shared: {
		_FOLDER: Folder,
		Objects: {_FOLDER: Folder},
		Components: {_FOLDER: Folder},
		Interfaces: {_FOLDER: Folder},
		Queries: {_FOLDER: Folder},
		Modules: {_FOLDER: Folder},
	},

	Objects: {_FOLDER: Folder},
	Components: {_FOLDER: Folder},
	Interfaces: {_FOLDER: Folder},
	Queries: {_FOLDER: Folder},
	Modules: {_FOLDER: Folder},
} & ROAM

-----------------------------------------

local mt = {}
mt.__index = function(t, k)
	local m = t._FOLDER:FindFirstChild(k)
	if m and m:IsA("ModuleScript") then
		m = require(m)
	end
	t[k] = m
	return m
end

local folder = getFolder()

--// ROAM Object //--
local ROAM: ROAM_Internal = {} :: ROAM_Internal

ROAM._FOLDER = internalFolder
ROAM.Shared = {
	_FOLDER = sharedFolder,
	Objects = {
		_FOLDER = sharedFolder.Objects,	
	},
	Components = {
		_FOLDER = sharedFolder.Components,		
	},
	Queries = {
		_FOLDER = sharedFolder.Queries,		
	},
	Interfaces = {
		_FOLDER = sharedFolder.Interfaces,		
	},
	Modules = {
		_FOLDER = sharedFolder.Modules,		
	},
}

--// Set the Server/Client folder accessors //--
ROAM.Objects = {
	_FOLDER = folder.Objects,	
}
ROAM.Components = {
	_FOLDER = folder.Components,	
}
ROAM.Queries = {
	_FOLDER = folder.Queries,	
}
ROAM.Interfaces = {
	_FOLDER = folder.Interfaces,	
}
ROAM.Modules = {
	_FOLDER = folder.Modules,	
}

--// Get immediate requires //--
ROAM.Tag = Tag
ROAM.Util = {
	Maid = Maid,
	Signal = Signal,
	Promise = Promise,
	TableUtil = TableUtil,
	ClassManager = ClassManager,
}

--// Set MetaTables //--
setmetatable(ROAM, mt)

setmetatable(ROAM.Objects, mt)
setmetatable(ROAM.Queries, mt)
setmetatable(ROAM.Components, mt)
setmetatable(ROAM.Interfaces, mt)
setmetatable(ROAM.Modules, mt)

setmetatable(ROAM.Shared.Objects, mt)
setmetatable(ROAM.Shared.Queries, mt)
setmetatable(ROAM.Shared.Components, mt)
setmetatable(ROAM.Shared.Interfaces, mt)
setmetatable(ROAM.Shared.Modules, mt)


----------------------------------------------------------------------------------------------------
--// Setup Code //--
----------------------------------------------------------------------------------------------------

--// This is done so that if for some reason ROAM isnt called on the client it gets done
--// We may not need this eventually. TODO: Look Over This
game.Players.PlayerAdded:Connect(function(plr: Player)
	local initScript = internalFolder.ROAM_Client_Initializer:Clone()
	initScript.Parent = plr:WaitForChild("PlayerGui")
end)


----------------------------------------------------------------------------------------------------
--// ROAM Methods //--
----------------------------------------------------------------------------------------------------

--[[
	@return The rate at which the server sends information to the clients.
]]
function ROAM.GetUpdateRate()
	return UPDATE_RATE
end

--[[
	Creates a marker for where to make remote events. Dont worry about how this works.
	@return REMOTE_EVENT_MARKER
]]
function ROAM.CreateRemoteEvent()
	assert(RunService:IsServer())
	return REMOTE_EVENT_MARKER
end


--[[
	Starts ROAM. 
	This should be called once in some main control script at the start of your code.
	It is imperative that this is called as early as possible so it can setup all
	necessary backend connections and structures.
	@return Promise
]]
function ROAM.Start()
	
	if started then
		return Promise.reject("ROAM already started")
	end

	started = true

	return Promise.new(function(resolve)
		
		local NetworkManager = require(internalFolder.NetworkManager)
		local NmPromise: Types.Promise = NetworkManager:Init()
		
		task.spawn(function()
			for _, module in ipairs(getFolder().Objects:GetChildren()) do
				require(module)
			end
		end)
		
		NmPromise:await()
		
		
		
		if RunService:IsServer() then
			warn("ROAM-Server ready.")
		else
			warn("ROAM-Client ready.")
		end
		
		resolve()

	end):andThen(function()

		-- Start:
		startedComplete = true
		onStartedComplete:Fire()

		task.defer(function()
			onStartedComplete:Destroy()
		end)
	end)
end

--[[
	Use this to wait until ROAM has fully started and is ready for use.
	@return Promise
]]
function ROAM.OnStart()
	if startedComplete then
		return Promise.resolve()
	else
		return Promise.fromEvent(onStartedComplete.Event)
	end
end


return ROAM :: ROAM
