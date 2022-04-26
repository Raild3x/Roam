--!strict
--[[
    Types.
    
    A list of types used for type checking.
    
    Author: Raildex
    Date Created: 2/22/2022
   	Last Updated: 4/7/2022
--]]

local Package = script.Parent

export type Signal = typeof(require(Package.Signal).new())

export type Maid = typeof(require(Package.Maid).new())

export type Promise = typeof(require(Package.Promise).new(function(resolve) resolve() end))

export type numeric = typeof(Vector3.new()) | typeof(Vector2.new()) | number 

------------------------------------------------------------------------------------------------

export type EntityClass = {
	ClassName: string,
	Client: {},
	Server: {},
	
	Entities: {string},
	EntityAdded: Signal,
	EntityRemoved: Signal,
	
	Super: (EntityClass)?,
	Implements: {ModuleScript}?,
	Types: {string},
	
	new: (...any) -> Entity,
	
	Init: ((self: EntityClass) -> nil)?,
	Setup: (self: EntityClass, ...any) -> Entity,
	
	Destroy: (self: any) -> nil,

	Is: (self: EntityClass, name: string) -> boolean,
	IsSynced: (self: Entity) -> boolean,
	GetId: (self: Entity) -> string,
	GetTypes: (self: Entity) -> {string},

	Serialize: (self: Entity) -> SerialData,
	Deserialize: (data: SerialData) -> nil,

	AddEvent: (self: Entity, eventName: string) -> nil,
	GetEvent: (self: Entity, eventName: string) -> Signal,

	HasTag: (self: Entity, tag: string | Tag) -> boolean,
	AddTag: (self: Entity, tag: string | Tag) -> nil,
	RemoveTag: (self: Entity, tag: string | Tag) -> nil,
	GetTags: (self: Entity) -> {Tag},
	GetTagNames: (self: Entity) -> {string},

	GetComponent: (self: Entity, componentName: string) -> ComponentUnit,
	AddComponent: (self: Entity, unit: ComponentUnit, name: string?) -> ComponentUnit,
	RemoveComponent: (self: Entity, componentName: string) -> ComponentUnit,
	WaitForComponent: (self: Entity, componentName: string, _timeOut: number?) -> Promise,
	
	SetSyncedPlayers: (self: Entity, playersToSync: (Player | {Player})?, playersToIgnore: (Player | {Player})?) -> nil,
	GetSyncedPlayers: (self: Entity) -> {Player},
	Sync: (self: Entity, ...any) -> nil,
	FlushComponents: (self: Entity, ...string) -> nil,
	ForceFlushComponents: (self: Entity, ...string) -> nil,
}


export type Entity = {
	Internal: ObjectInternals,
	OnDestroy: Signal,
	
	--[string]: any,
} & EntityClass;


export type ServerEntity = {
	Client: {},
} & Entity

export type ClientEntity = {
	Server: {},
} & Entity



export type ObjectInternals = {
	Id: string,
	Maid: Maid,
	Events: {[string]: Signal},
	Tags: {string},
	Components: {[string]: ComponentUnit},
	SyncEnabled: {}?,
	NetworkOwner: Player?,
	SyncedPlayers: {number}?,
	IgnoredPlayers: {number}?,
}

export type SerialData = {
	ClassName: string,
	Tags: {string},
	Components: {any}, -- TODO: COME BACK TO THIS
	UserSerialData: {any} | nil	
}

-------------------------------------------------------------------------

export type ComponentUnitMetaTable = {
	ClassName: "ComponentUnit",
	
	Set: (self: ComponentUnit, newValue: any, dataName: string?) -> any,
	Get: (self: ComponentUnit, dataName: string?) -> any,

	-- Utility Methods for easier math updates
	Add: (self: ComponentUnit, addAmt: numeric, dataName: string?) -> numeric,
	Sub: (self: ComponentUnit, subAmt: numeric, dataName: string?) -> numeric,
	Mul: (self: ComponentUnit, mulAmt: numeric, dataName: string?) -> numeric,
	Div: (self: ComponentUnit, divAmt: numeric, dataName: string?) -> numeric,
	Mod: (self: ComponentUnit, modAmt: numeric, dataName: string?) -> numeric,
	Pow: (self: ComponentUnit, powAmt: numeric, dataName: string?) -> numeric,

	Destroy: (self: ComponentUnit) -> nil,
	
	GetId: (self: ComponentUnit) -> string,
	GetComponent: (self: ComponentUnit) -> Component,
	IsSynced: (self: ComponentUnit) -> boolean,
	IsSingleValued: (self: ComponentUnit) -> boolean,
	
	GetPlayerIdsToSyncWith: (self: ComponentUnit) -> {number}?,
	CanSyncWithPlayer: (self: ComponentUnit, plr: Player) -> boolean,
	
	Flush: (self: ComponentUnit, ...string) -> nil,
	ForceFlush: (self: ComponentUnit, ...string) -> nil,
	-- TODO: ForceFlush: 
}


export type ComponentUnit = {
	ComponentId: string,
	UnitId: string,
	EntityIds: {string},
	Data: any, --| { [string | number]: any },
	Changed: Signal,
	SyncEnabled: boolean,
	
	--[string]: any, -- prevent linting issues with simplified syntax
	
} & ComponentUnitMetaTable


-------------------------------------------------------------------------

export type ComponentMetatable ={
	ClassName: "Component",
	NewUnit: (self: Component, data: any, typecheck: boolean?, syncData: any?) -> ComponentUnit,
	
	--__call: (value: any, typecheck: boolean?) -> ComponentUnit,
	
	GetKeyFrom: (self: Component, key: string) -> ((string), boolean),
	CleanUp: (self: Component)
}

export type Component = {
	Id: string,
	Template: ComponentTemplate,
	Entities: { string },
	Units: {[string]: string},
	ComponentAdded: Signal,
	ComponentRemoved: Signal,
	Name: string,
	
	PropertyShortcuts: {[string]: (string)},
	
	
} & ComponentMetatable

export type ComponentTemplate = Type | { [string | number]: Type}

-------------------------------------------------------------------------

export type InterfaceMetatable = {
	ClassName: "Interface",
	__index: InterfaceMetatable,
	
	SetupClass: (self: Interface, class: EntityClass) -> (),
	SetupObject: (self: Interface, class: Entity) -> ()
}

export type InterfaceData = {
	InterfaceId: number,
	ClassFields: {[string]: any},
	ObjectProperties: {[string]: any}
}

export type Interface = typeof(setmetatable({} :: InterfaceData, {} :: InterfaceMetatable))

-------------------------------------------------------------------------

export type Tag = {
	Id: string,
	Name: string,
	Entities: { string },
	TagAdded: Signal,
	TagRemoved: Signal,
	ClassName: "Tag",
}

export type Type = {
	id: string,
	name: DataType,
	ClassName: "Type",
}--[[, {
	__call: (self: Type, value: any) -> boolean,
}>]]

export type DataType = "string" | "number" | "boolean" | "table" | "vector" | "function" | "CFrame" | "Vector3" | "Vector2" | "UDim" | "UDim2" | "Instance" | "Color3" | "EnumItem" | "Enum" | "Component" | "Object" | "Query" | "Tag" | "Type" | "any"

export type Queryable = Component | EntityClass | Tag

export type QueryMetaTable = {
	ClassName: "Query",
	
	Destroy: (self: Query) -> nil,
	Get: (self: Query) -> {number}, -- returns table of entities
	
	RemoveOnEmpty: (self: Query) -> nil,

	Create: (self: Query, (Entity, ...any) -> (nil), statementName: string?) -> ((...any) -> nil),
	MakeStatement: (self: Query, (Entity, ...any) -> (nil), statementName: string?) -> ((...any) -> nil),

	GetStatement: (self: Query, statementName: string) -> ((...any) -> nil),
	
	GetSize: (self: Query) -> number,
	
	ForEach: (self: Query, func: (entity: Entity, lastResult: any?) -> (any?) ) -> ({[string]: any}, any?)
}

export type Query = {
	Id: string,
	Template: Queryable | { [string | number]: Queryable },
	Entities: { string },
	Statements: { [string]: ((...any) -> nil) },
	AutoCleanup: boolean,
	Maid: Maid,
} & QueryMetaTable


return nil