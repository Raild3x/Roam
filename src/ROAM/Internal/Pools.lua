--!strict
local Types = require(script.Parent.Types)

local Pools = {
	Objects = {} 		:: {[string]: Types.Entity},
	Tags = {} 			:: {[string]: Types.Tag},
	Components = {} 	:: {[string]: Types.Component},
	ComponentUnits = {} :: {[string]: Types.ComponentUnit},
	Querys = {} 		:: {[string]: Types.Query}
}

return Pools
