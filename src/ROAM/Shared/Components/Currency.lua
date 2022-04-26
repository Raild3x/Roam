--!strict
--[[

	ROAM Currency COMPONENT

	Authors: Raildex
	Date Created: April 17, 2022
	Last Updated: April 17, 2022
	
	[Documentation]
		--TODO:
	
	[Usage]
		local Currency: Types.Component = require(ROAM.Components.Currency)
		
		local CurrencyUnit: Types.ComponentUnit = Currency({
			Gold      = 5,
			Khrystals = 2,
		})
		
--]]

----------------------------------------------------------------
-- VARIABLES --
----------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Internal 			= ReplicatedStorage.ROAM.Internal

local Component = require(Internal.Component)
local Types 	= require(Internal.Types) 
local Type 		= require(Internal.Type)

local COMPONENT_NAME: string = "Currency"

----------------------------------------------------------------
-- COMPONENT DECLARATION --
----------------------------------------------------------------

return Component({
	Gold      = Type('number'),
	Khrystals = Type('number'),
}, COMPONENT_NAME) :: Types.Component