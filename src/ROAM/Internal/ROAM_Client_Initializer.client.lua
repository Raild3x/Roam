-- This will setup Network stuff the first time these classes are accessed on the client
-- This is implemented in the offchance that for some reason you havent

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ROAM = require(ReplicatedStorage.ROAM)

ROAM.Start():catch(error)