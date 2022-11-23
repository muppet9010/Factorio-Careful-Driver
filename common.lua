--[[
    Common things used by multiple files. Can be utilised across data and control stages.
]]

local Common = {} ---@class Common

--- Get the entity name for the variant of a car prototype that is used when stuck in the water.
---@param entityName string
---@return string
Common.GetCarInWaterName = function(entityName)
    return "careful_driver-" .. entityName .. "-stuck_in_water"
end

--- Get the entity name for the variant of a car prototype that is used when falling in to the void and should not be tinted.
---@param entityName string
---@param rotation uint # 1-64
---@param part "body"|"turret"
---@param tintable "nonTinted"|"tinted"
---@return string
Common.GetCarInVoidName = function(entityName, rotation, part, tintable)
    return "careful_driver-" .. entityName .. "-falling_in_void-" .. part .. "-" .. tintable .. "-" .. rotation
end

return Common
