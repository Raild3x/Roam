--!strict
--[[
	Network Manager
	Author: Raildex
	Date Created: 03/15/2022
	Last Updated: 04/4/2022
	
	This module is really shoddily put together, dont mess with anything in here.


]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

------------------------------------------------------------
local ROAM = require(ReplicatedStorage.ROAM)

local UPDATE_RATE: number = ROAM.GetUpdateRate()

local Package = script.Parent -- Internal Folder

--local NetworkObject = require(ReplicatedStorage.ROAM.Internal.NetworkObject)

local ClassManager  = require(Package.ClassManager)
local Promise		= require(Package.Promise)
local Pools 		= require(Package.Pools)
local Tag 			= require(Package.Tag)
local Types 		= require(Package.Types)


type UpdateData = {
	Objects: {},
	Components: {},
	Update: boolean,
}


local NetworkManager = {}
NetworkManager.LostComponentUnitDataStorage = {} :: {[string]: any}
NetworkManager.Entities = {}
NetworkManager.ComponentsToUpdate = {}


local function Encode(data): string
	return data
	--return HttpService:JSONEncode(data):gsub('":{"', string.char(1)):gsub('":', string.char(3)):gsub('},"', string.char(2))
end

local function Decode(json: string): any
	return json
	--return HttpService:JSONDecode(json:gsub(string.char(3), '":'):gsub(string.char(1),'":{"'):gsub(string.char(2),'},"'))
end


-------------------------------------------------------------------------------------------------------------


function NetworkManager.OnServerCreation(entityId: string, commsFolder: Folder, ...:any)
	assert(IS_CLIENT, "Cannot be used on Server")
	
	ROAM.OnStart():await()
	
	local Object = require(Package.Object)
	
	local newObject: Types.Entity = nil
	
	if commsFolder then		
		local ClassName = commsFolder.Name:sub(1, commsFolder.Name:find("_")-1)
		local class: Types.EntityClass = Object(ClassName)
		Package.Object.FlagNextId:Fire(entityId)
		newObject = class.new(...)
	else
		error("This no longer works")
		--newObject = ROAM.Object(ReplicatedStorage.ROAM.Internal.NetworkObject).new(entityId, className, types)
		--for _, tagName: string in pairs(tags) do
		--	newObject:AddTag(tagName)
		--end
	end
	
	
	--warn("New NetworkObject Created", entityId, className, types, tags)
	return newObject
end


function NetworkManager.CreateObjectOnClient(obj: Types.Entity)
	assert(IS_SERVER, "Cannot be used on Client")
	
	if obj.Internal.SyncedPlayers then
		for _, plr in pairs(obj.Internal.SyncedPlayers) do
			script.NewObject:FireClient(plr, obj:GetId(), obj.Comms, table.unpack(obj.Internal.SyncEnabled))
		end
	else
		script.NewObject:FireAllClients(obj:GetId(), obj.Comms, table.unpack(obj.Internal.SyncEnabled))
	end
	
	obj.OnDestroy:Connect(function()
		script.DestroyObject:FireAllClients(obj:GetId())
	end)
end


function NetworkManager.CreateComponentUnitOnClient(unit: Types.ComponentUnit)
	local plrs = {}
	for _, entityId: string in pairs(unit.EntityIds) do
		local entity: Types.Entity = Pools.Objects[entityId]
		if entity:IsSynced() then
			
			if entity.Internal.SyncedPlayers then
				for _, id in pairs(entity.Internal.SyncedPlayers) do
					plrs[id] = true
				end
			else
				plrs = nil
				break
			end
		end
	end
	
	local data = {
		Id = unit.ComponentId,
		UnitId = unit.UnitId,
		Data = unit.Data,
	}
	
	if plrs then
		for userId, _ in pairs(plrs) do
			script.NewComponentUnit:FireClient(game.Players:GetPlayerByUserId(userId), data)
		end
	else
		script.NewComponentUnit:FireAllClients(data)
	end
end


function NetworkManager.AddComponentToClient(entity: Types.Entity, unit: Types.ComponentUnit)
	assert(RunService:IsServer())
	assert(entity:IsSynced())
	
	if entity.Internal.SyncedPlayers then
		for _, plrId: number in pairs(entity.Internal.SyncedPlayers) do
			script.AddComponent:FireClient(game.Players:GetPlayerByUserId(plrId), entity:GetId(), unit.UnitId)
		end
	else
		script.AddComponent:FireAllClients(entity:GetId(), unit.UnitId)
	end
end



local function InitServer()
	script.PlayerReady.OnServerEvent:Connect(function(plr: Player)
		print("Received player ready", plr)

		for id, obj: Types.Entity in pairs(Pools.Objects) do
			if obj:IsSynced() then
				if obj.Internal.SyncedPlayers == nil or table.find(obj.Internal.SyncedPlayers, plr.UserId) then
					script.NewObject:FireClient(plr, obj:GetId(), obj.Comms, table.unpack(obj.Internal.SyncEnabled))
				end
			end
		end

		for id, unit: Types.ComponentUnit in pairs(Pools.ComponentUnits) do
			if unit:IsSynced() then
				if unit:CanSyncWithPlayer(plr) then
					local data = {
						Id = unit.ComponentId,
						UnitId = unit.UnitId,
						Data = unit.Data,
						EntityIds = unit.EntityIds,
					}
					script.NewComponentUnit:FireClient(plr, data)
				end
			end
		end

		script.PlayerReady:FireClient(plr)
	end)
	
	-----

	local global: UpdateData = {
		Objects = {},
		Components = {},
		Update = false,
	}
	local plrData: {UpdateData} = {}

	-- NETWORK SYNC LOOP
	task.defer(function()
		while true do
			debug.profilebegin("Server Network Sync")
			-- Update Components
			for id: string, keysToUpdate in pairs(NetworkManager.ComponentsToUpdate) do

				local plrIdsToUpdate = Pools.ComponentUnits[id]:GetPlayerIdsToSyncWith()
				if plrIdsToUpdate then
					for _, plrId in pairs(plrIdsToUpdate) do
						plrData[plrId].Components = keysToUpdate
						plrData[plrId].Update = true
					end

				else
					global.Components[id] = keysToUpdate
					global.Update = true
				end
			end

			table.clear(NetworkManager.ComponentsToUpdate)


			-- FIRE EVENTS --
			if global.Update then
				script.Update:FireAllClients(Encode(global))

				table.clear(global.Objects)
				table.clear(global.Components)
				global.Update = false
			end


			-- Fire for each player
			for _, plr in pairs(game:GetService("Players"):GetPlayers()) do
				local plrData: UpdateData = plrData[plr.UserId]
				if not plrData.Update then
					continue
				end
				script.Update:FireClient(plr, Encode(plrData))

				table.clear(plrData.Objects)
				table.clear(plrData.Components)
				plrData.Update = false
			end

			debug.profileend()
			task.wait(UPDATE_RATE)
		end
	end)


	game:GetService("Players").PlayerAdded:Connect(function(plr: Player)
		plrData[plr.UserId] = {
			Objects = {},
			Components = {},
			Update = false,
		}
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(plr: Player)
		plrData[plr.UserId] = nil
	end)
end



local function InitClient()

	function NetworkManager.AddTag(entityId: string, tagName: string)
		ROAM.OnStart():await()

		local object = ClassManager.GetObjectFromId(entityId)
		object:AddTag(tagName)
	end


	function NetworkManager.RemoveTag(entityId: string, tagName: string)
		ROAM.OnStart():await()

		local object = ClassManager.GetObjectFromId(entityId)
		object:RemoveTag(tagName)
	end


	function NetworkManager.AddComponent(entityId: string, unitId: string)
		ROAM.OnStart():await()

		local entity: Types.Entity = ClassManager.WaitForObjectFromId(entityId)
		assert(entity, "Timed Out: Could not find entity: "..entityId)
		local unit: Types.ComponentUnit = ClassManager.GetComponentUnitFromId(unitId)
		assert(unit, "Could not find ComponentUnit on Client")
		--warn("Added Component CLIENT", entity)

		local id: string = unit:GetId()
		local lostData = NetworkManager.LostComponentUnitDataStorage[id]
		if lostData then
			warn("Found Lost Data on ComponentUnit Creation: Updating CU-"..id)
			if unit:IsSingleValued() then
				unit:Set(lostData)
			else
				local component: Types.Component = unit:GetComponent()
				for codedKey: string, value: any in pairs(lostData) do
					--print("Old:",unit:Get(component:GetKeyFrom(codedKey)),"New:",value)
					local key = component:GetKeyFrom(codedKey)
					unit:Set(value, key)
				end
			end
			NetworkManager.LostComponentUnitDataStorage[id] = nil -- clear out the lost data
		end

		entity:AddComponent(unit)
	end


	function NetworkManager.NewComponentUnit(unitData)
		ClassManager.GetComponentFromIdSafe(unitData.Id):andThen(function(component: Types.Component)
			local unit = component:New(unitData.Data, nil, unitData)
			for _, id: string in pairs(unitData.EntityIds) do
				NetworkManager.AddComponent(id, unit.UnitId)
			end
		end)
	end


	function NetworkManager.DestroyObject(entityId: number)
		ROAM.OnStart():await()
		
		local entity: Types.Entity = ClassManager.GetObjectFromId(entityId)
		entity:Destroy()
	end

	script.NewObject.OnClientEvent:Connect(NetworkManager.OnServerCreation)

	script.AddTag.OnClientEvent:Connect(NetworkManager.AddTag)

	script.RemoveTag.OnClientEvent:Connect(NetworkManager.RemoveTag)

	script.NewComponentUnit.OnClientEvent:Connect(NetworkManager.NewComponentUnit)

	script.AddComponent.OnClientEvent:Connect(NetworkManager.AddComponent)

	script.DestroyObject.OnClientEvent:Connect(NetworkManager.DestroyObject)
	
	-- CLIENT LISTENERS
	script.Update.OnClientEvent:Connect(function(updatesJSON: string)
		debug.profilebegin("Updating Synced Client Data")
		local updates: UpdateData = Decode(updatesJSON)
		-------------------------------------------------------------
		local lostDataObjectIds = ""

		for id: string, keysToUpdate in pairs(updates.Objects) do
			--TODO: Finish Object Updates
		end

		-------------------------------------------------------------
		local lostDataComponentUnitIds = {}
		local lcuds = NetworkManager.LostComponentUnitDataStorage

		for id: string, keysToUpdate in pairs(updates.Components) do
			local unit: Types.ComponentUnit = Pools.ComponentUnits[id]
			if not unit then
				--warn("Erroring Data: ",keysToUpdate,"\tCU: ", Pools.ComponentUnits)
				table.insert(lostDataComponentUnitIds, id)
				if typeof(keysToUpdate) == "table" then
					lcuds[id] = lcuds[id] or {}
					for key, value in pairs(keysToUpdate) do
						lcuds[id][key] = value
					end
				else
					lcuds[id] = keysToUpdate
				end
				continue
			end


			if typeof(keysToUpdate) == "table" then
				for key, value in pairs(keysToUpdate) do
					print("Updating:",value, unit:GetComponent():GetKeyFrom(key))
					unit:Set(value, unit:GetComponent():GetKeyFrom(key))
				end
			else
				unit:Set(keysToUpdate)
				--error("Unsupported Update Type: Single Values are not yet setup for syncing")
			end
			--warn("Updated ComponentUnit-"..id)
		end


		if #lostDataObjectIds > 0 then
			warn("Failed to find Objects for IDs:\n"..lostDataObjectIds.."\n\t\t\t\t[Temporarily storing data to LostAndFound]")
		end
		if #lostDataComponentUnitIds > 0 then
			warn("Failed to find ComponentUnits for IDs:",lostDataComponentUnitIds,"\n\t\t\t\t[Temporarily storing data to LostAndFound]")
		end



		debug.profileend()
	end)
end



function NetworkManager.Init(): Types.Promise
	
	return Promise.new(function(resolve)
		if RunService:IsServer() then
			warn("SERVER - ROAM Network Manager is Ready")
			InitServer()
			resolve()
			
		else
			InitClient()
			
			script.PlayerReady.OnClientEvent:Connect(function()
				warn("CLIENT - ROAM Network Manager is Ready - "..game:GetService("Players").LocalPlayer.Name)
				resolve()
			end)
			
			script.PlayerReady:FireServer()
		end
	end)
end


return NetworkManager
