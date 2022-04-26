--!strict
--[[
    Query
    
    Raildex
    3/20/2022
    
    
    local playerTag = Tag("Player") -- create a tag named 'Player'
    
    -- Create the templates for 2 components
	local Money = Component({
		Gold = Type('number'),
		Khrystals = Type('number')
	}, "Currency")

	local Stat = Component({
		Level = Type('number'),
		Exp = Type('number')
	}, "Stats")


	-----------------------------------------------------------------

	-- Create a query consisting of the Stats and Money Components and the Player tag
	local playerDataQuery = Query({
		playerTag, 
		Stat,
		Money,
	})

	-----------------------------------
	-- create our entity and add components and tags to it
	local testEntity = Object("ExampleObjectClass").new() :: Types.Entity -- make some generic object

	testEntity:AddTag( playerTag ) -- add the 'Player' tag to our entity

	-- Add the components to the entity and set their actual values
	testEntity:AddComponent(Stat({
		Level = 3,
		Exp = 127,
	}))
	testEntity:AddComponent(Money({
		Gold = 1000,
		Khrystals = 0,
	}))


	-----------------------------------------------------------------------------------

	-- QUERY EXAMPLE USAGE --

	-- The Get Method allows us to read the current table. IT DOES NOT UPDATE ON ITS OWN AND SHOULD BE USED AS A QUICK READ
	local entities = playerDataQuery:Get() -- returns a table of all objects that contain all the components 'Stats' and 'Money' and the tag 'Player'


	-- Query Statement Usage - Declare a Query Statement for later use
	local AwardPlayers = playerDataQuery:Create(function(entity, amountToAward: number)
	
		local currency = entity:GetComponent("Currency")
		local stats = entity:GetComponent("Stats")
		
		currency:Add(amountToAward * stats:Get("Level"), "Gold")--award these entities with Khrystal based on their level
		
	end, "Award")
	

	AwardPlayers(100) -- Run our created query statement
	
    playerDataQuery:GetStatement("Award")(100)
    
--]]


local RunService = game:GetService("RunService")

local InternalFolder = script.Parent

local TableUtil = require(InternalFolder.TableUtil)
local Maid = require(InternalFolder.Maid)
local Types = require(InternalFolder.Types)
local Pools = require(InternalFolder.Pools)


local IS_SERVER: boolean = RunService:IsServer()
local IS_CLIENT: boolean = RunService:IsClient()

local GLOBAL_ID: number = IS_SERVER and 1 or 2


local Query = {}

local CLASS_META_TABLE = { 
	__index = Query
}


function Query:GetStatement(statementName: string)
	return self.Statements[statementName];
end

function Query:MakeStatement(func: (entity: Types.Entity, ...any) -> (), funcName: string?)
	assert(func, "Query Missing Statement Function")
	
	local internalFunction = function(...)
		for i = 1, #self.Entities do
			func(Pools.Objects[self.Entities[i]], ...)
		end
	end
	
	if funcName then
		if self.Statements[funcName] then
			warn("Query Statement with name "..funcName.." already exists - OVERWRITING")
		end
		self.Statements[funcName] = internalFunction
	end
	
	return internalFunction
end

Query.Create = Query.MakeStatement


function Query:ForEach(func: (entity: Types.Entity, lastResult: any?) -> any?): ({[string]: any}, any)
	debug.profilebegin("QUERY:ForEach()")
	local results = {}
	local lastResult: any = nil
	for i = 1, #self.Entities do
		local e: Types.Entity = Pools.Objects[self.Entities[i]]
		local result: any = func(e, lastResult)
		results[e:GetId()] = result
		lastResult = result
	end
	debug.profileend()
	return results, lastResult
end


function Query:GetSize(): number
	return #self.Entities
end

function Query:Get(): {Types.Entity} -- Use this method sparingly, you should use :Create instead in most cases
	local entities: {Types.Entity} = {}
	for i = 1, #self.Entities do
		table.insert(entities, Pools.Objects[self.Entities[i]])
	end
	return entities
end

function Query:Destroy()
	Pools.Querys[self.Id] = nil
	self.Template = nil
	self.Entities = nil
	self.Statements = nil
	self.Maid:Destroy()
end

function Query:CheckIfEntityIsValid(entityId: string): boolean
	local currentIndex: number? = table.find(self.Entities, entityId)
	if currentIndex then
		return true -- Entity is already in Query Table
	end
	local entity = Pools.Objects[entityId]
	
	if self.Template.Entities then -- if were working with a single object for query
		if table.find(self.Template.Entities, entityId) then
			table.insert(self.Entities, entityId)
			return true
		end
	else
		local valid = true
		for index, QueryObject in pairs(self.Template) do
			if not table.find(QueryObject.Entities, entityId) then
				valid = false
				break
			end
		end
		if valid then
			table.insert(self.Entities, entityId)
			return true
		end
	end
	return false
end

function Query:RemoveOnEmpty()
	self.AutoCleanup = true
end

function Query:Has(entity: Types.Entity): boolean
	return table.find(self.Entities, entity:GetId()) ~= nil
end


----------------------------------------------------------------------------------------------------
-- Internal Use Only (This is likely where the warnings are coming from in the linter bc roblox interfaces are dumb)

function Query:__RemoveEntity(entityId: number)
	TableUtil.FastRemoveFirstValue(self.Entities, entityId)
	if #self.Entities == 0 then
		if self.AutoCleanup then
			self:Destroy()
		else
			warn("Query Entity Table is empty, consider Destroying")
		end
	end
end

function Query:__SetupEntityListeners()
	if self.Template.ClassName then -- if were working with a single resource
		local className = self.Template.ClassName
		if className == "Tag" or className == "Component" then
			self.Entities = self.Template.Entities
		elseif self.Template.Is and self.Template:Is("Object") then
			self.Entities = self.Template.Entities -- reference the objects entity list
		else
			error("Invalid Type used for Query Template")
		end
		
	else
		-- Get the initial list
		local entityList = nil
		for index, QueryObject in ipairs(self.Template) do
			if not entityList then
				entityList = TableUtil.CopyShallow(QueryObject.Entities)
			else
				for i = #entityList, 1, -1 do
					local id = entityList[i]
					if not table.find(QueryObject, id) then
						TableUtil.FastRemove(entityList,id)
					end
				end
			end
			-------------------------------------------------- Event Listeners for post setup
			if QueryObject.ClassName == "Tag" then
				self.Maid:GiveTask(QueryObject.TagAdded:Connect(function(entity)
					self:CheckIfEntityIsValid(entity:GetId())
				end))
				self.Maid:GiveTask(QueryObject.TagRemoved:Connect(function(entity)
					self:__RemoveEntity(entity:GetId())
				end))
				
			elseif QueryObject.ClassName == "Component" then
				self.Maid:GiveTask(QueryObject.ComponentAdded:Connect(function(entity)
					self:CheckIfEntityIsValid(entity:GetId())
				end))
				self.Maid:GiveTask(QueryObject.ComponentRemoved:Connect(function(entity)
					self:__RemoveEntity(entity:GetId())
				end))
				
			elseif QueryObject.EntityAdded then
				self.Maid:GiveTask(QueryObject.EntityAdded:Connect(function(entity)
					self:CheckIfEntityIsValid(entity:GetId())
				end))
				self.Maid:GiveTask(QueryObject.EntityRemoved:Connect(function(entity)
					self:__RemoveEntity(entity:GetId())
				end))
			elseif typeof(QueryObject) == "function" then
				
			else
				warn("Unsupported Query Object Detected:",QueryObject)
			end
		end
		self.Entities = entityList
	end
end

return function (toquery: (Types.Queryable | { Types.Queryable })): Types.Query
	--local list = {...}
	--if #list > 0 and toquery.ClassName ~= nil then
	--	table.insert(list, toquery)
	--	toquery = list
	--end
	local query = setmetatable({
		Id = tostring(GLOBAL_ID),
		Template = toquery,
		Entities = {},
		Statements = {},
		AutoCleanup = false,
		Maid = Maid.new(),
		ClassName = "Query",
	}, CLASS_META_TABLE) :: Types.Query
	GLOBAL_ID += 2

	Pools.Querys[query.Id] = query
	
	query:__SetupEntityListeners()

	return query
end