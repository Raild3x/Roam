--!strict
--[[

	ROAM PlayerData COMPONENT

	Authors: Raildex
	Date Created: April 17, 2022
	Last Updated: April 17, 2022
	
	[Documentation]
		--TODO:
	
	[Usage]
		local PlayerData: Types.Component = require(ROAM.Components.PlayerData)
		
		local PlayerDataUnit: Types.ComponentUnit = PlayerData({
			Position = Vector3.new(9, 7, 9),
			Level    = 9,
			Title    = "Egg",
			Pet      = Instance.new("Part"),
		})
		
--]]

----------------------------------------------------------------
-- REFERENCES --
----------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Internal 			= ReplicatedStorage.ROAM.Internal

local Component = require(Internal.Component)
local Types 	= require(Internal.Types) 
local Type 		= require(Internal.Type)

local COMPONENT_NAME: string = "PlayerData"

----------------------------------------------------------------
-- COMPONENT DECLARATION --
----------------------------------------------------------------

return Component({
	Position = Type('Vector3'),
	Level    = Type('number'),
	Title    = Type('string'),
	Pet      = Type('Instance'),
}, COMPONENT_NAME) :: Types.Component

