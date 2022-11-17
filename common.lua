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

return Common
