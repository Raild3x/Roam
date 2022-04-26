--!strict
--[[ ROAM - CLASS MANAGER
	[*Rail's *Object *Addons *Manager]

	Author: Raildex
	Date Created: 02/17/2022
	Last Updated: 02/24/2022
	
	
	
	Usage:
		
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROAM = ReplicatedStorage.ROAM
local Package = script.Parent


local SharedInterfacesFolder = ROAM.Shared.Interfaces
local SharedComponentsFolder = ROAM.Shared.Components
local SharedObjectsFolder = ROAM.Shared.Objects

local TableUtil = require(Package.TableUtil)
local Promise	= require(Package.Promise)
local Signal 	= require(Package.Signal)
local Pools		= require(Package.Pools)
local Type 		= require(Package.Type)
local Tag 		= require(Package.Tag)

local Types 	= require(Package.Types)

local ClassManager = {}


------------------------------------------------------------------------------------------------------------------
	--// Accessors //--
------------------------------------------------------------------------------------------------------------------



------------------------------------------------------------------------------------------------------------------
	--// Getters //--
------------------------------------------------------------------------------------------------------------------

function ClassManager.WaitForObjectFromId(id: string, _timeOut: number?): Types.Entity?
	local entity: Types.Entity
	local startTime: number = os.clock()
	local warned: boolean = false
	while not entity and (_timeOut == nil or (os.clock() > startTime + _timeOut)) do
		entity = Pools.Objects[id]
		if _timeOut == nil and os.clock() > startTime + 5 and not warned then
			warn("Infinite yield possible on 'ClassManager.WaitForObjectFromId("..id..")'")
			warned = true
		end
		task.wait()
	end
	return entity
end

function ClassManager.GetObjectFromId(id: string): Types.Entity
	return Pools.Objects[id]
end
ClassManager.GetEntityFromId = ClassManager.GetObjectFromId

function ClassManager.GetTagFromId(id: string): Types.Tag
	return Pools.Tags[id]
end

function ClassManager.GetObjectsWithTags(...: string): {Types.Entity}
	local smallestTagIndex: number
	local listSize: number = math.huge
	
	-- Find the tag with the smallest entity list and work from there
	local tags: {Types.Tag} = {}
	local tagNames: {string} = {...}
	for i: number, tagName: string in pairs(tagNames) do
		local tag: Types.Tag = Tag(tagName)
		tags[i] = tag
		if #tag.Entities < listSize then
			listSize = #tag.Entities
			smallestTagIndex = i
		end
	end
	
	local PotentialEntityList: {string} = TableUtil.Copy(tags[smallestTagIndex].Entities)
	table.remove(tags, smallestTagIndex)
	
	local EntityList: {any} = {}
	
	for idx, entityId: string in pairs(PotentialEntityList) do
		local entity = ClassManager.GetObjectFromId(entityId)
		local valid = true
		for i = 1, #tags do
			if not entity:HasTag(tags[i]) then
				valid = false
				break
			end
		end
		if valid then
			table.insert(EntityList, entity)
		end
	end
	
	return EntityList
end


function ClassManager.GetObjectsOfType(_type: string): {any}
	local Objects: {[string | number]: Types.Entity} = Pools.Objects
	local list: {any} = {}
	for i = 1, #Objects do
		local obj: Types.Entity = Objects[i]
		if obj:Is(_type) then
			table.insert(list, obj)
		end
	end
	return list
end


local ComponentsInTransit = {}

function ClassManager.GetComponentFromIdSafe(id: string): Types.Promise
	if RunService:IsServer() then
		error("Calling Safe ComponentAccessor is unneeded on server")
	end
	
	if Pools.Components[id] then
		return Promise.resolve(Pools.Components[id])
	end
	
	local prom: Types.Promise = Promise.new(function(resolve, reject)
		if not Pools.Components[id] and not ComponentsInTransit[id] then
			warn("Fetching Component Template From Server [YIELD WARNING]")
			ComponentsInTransit[id] = Signal.new(nil)
			local data = script.GetComponentData:InvokeServer(id)
			
			if data.Template.ClassName == "Type" then
				data.Template = Type(data.Template.name)
			else
				for key, info in pairs(data.Template) do
					data.Template[key] = Type(info.name)
				end
			end
			

			local Component = require(ROAM.Internal.Component)
			local syncedComponent = Component(data.Template, data.Name, data)
			Pools.Components[id] = syncedComponent
			ComponentsInTransit[id]:Fire()
			ComponentsInTransit[id]:Destroy()
		elseif ComponentsInTransit[id] then
			warn("[YIELD] Waiting for Component Template to be retrieved.")
			ComponentsInTransit[id]:Wait()
		else
			reject("Something went wrong")
		end
		resolve(Pools.Components[id])
	end)
	
	return prom
end

function ClassManager.GetComponentFromId(id: string): Types.Component
	return Pools.Components[id]
end

function ClassManager.GetComponentUnitFromId(id: string): Types.ComponentUnit
	return Pools.ComponentUnits[id]
end

--function ClassManager.GetComponentFromName(_name: string): Types.Component
--	local comp: Types.Component
--end

------------------------------------------------------------------------------------------------------------------
	--// Debug Helpers //--
------------------------------------------------------------------------------------------------------------------

ClassManager.Debug = {} -- debug functions

-- Call this to show a list of all tags and the number of entities they are tagged to
function ClassManager.Debug.ListAllTags()
	print("Listing All Existing Tags:")
	for id, tag: Types.Tag in pairs(Pools.Tags) do
		print("\t[TAG]",tag.Name, ":", #tag.Entities)
	end
end

------------------------------------------------------------------------------------------------------------------
	--// Core //--
------------------------------------------------------------------------------------------------------------------

if RunService:IsServer() then

	script.GetComponentData.OnServerInvoke = function(plr: Player, componentId: string)
		local component = ClassManager.GetComponentFromId(componentId)
		local data = {
			Id = component.Id,
			Template = component.Template,
			Entities = component.Entities,
			Name = component.Name
		}
		return data
	end

end

export type ClassManager = typeof(ClassManager)

return ClassManager

