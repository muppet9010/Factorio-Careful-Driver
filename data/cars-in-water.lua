--[[
    Create a copy of each `car` type that is non drivable for the stuck in water version.

    Run in final fixes data stage in the hope I don't have to dependency on any other mods, as I don't want to change their prototypes, just make a copy of them.

    -- TODO: Decide how I want to do the graphics. Could juts use the remnants model, or could make a custom version of the main model and just remove the lower parts of the graphics manually. But then need to do this for every custom car type as well...
]]

local TableUtils = require("utility.helper-utils.table-utils")
local Common = require("common")

local carsInWater = {} ---@type table<int, Prototype.Car>
for _, carPrototype in pairs(data.raw["car"]) do
    local waterVariant = TableUtils.DeepCopy(carPrototype) ---@type Prototype.Car
    local originalName = waterVariant.name

    -- Update the simpler fields on our water variant.
    waterVariant.name = Common.GetCarInWaterName(originalName)
    waterVariant.allow_passengers = false
    waterVariant.localised_name = { "entity-name.careful_driver-vehicle_stuck_in_water", { "entity-name." .. originalName } }
    waterVariant.localised_description = { "entity-description.careful_driver-vehicle_stuck_in_water", { "entity-name." .. originalName } }
    waterVariant.collision_mask = {} -- Have no collision mask so that as it skids to a halt in the water it doesn't damage anything.
    waterVariant.consumption = "0W" -- Vehicle is incapable of moving.

    -- Make the icon include a water background so its obvious in the editor.
    -- TODO: check this works with something that uses `icons`, as vanilla vehicles use `icon`. Then push it to PrototypeUtils.CreatePlacementTestEntityPrototype() and maybe functionise it ?
    local iconSize = waterVariant.icon_size
    if iconSize == nil then
        iconSize = 0
        local thisIconSize
        for _, iconDetails in pairs(waterVariant.icons--[[@as IconData[] ]] ) do
            thisIconSize = iconDetails.icon_size * (waterVariant.icons[1].scale or 1) --[[@as uint16]]
            if thisIconSize > iconSize then
                iconSize = thisIconSize
            end
        end
    end
    ---@type IconData[]
    local newIcons = {
        {
            icon = "__base__/graphics/terrain/water/hr-water-o.png",
            icon_size = 64,
            scale = (iconSize / 64) * 0.5
        }
    }
    if waterVariant.icons ~= nil then
        for _, iconDetails in pairs(waterVariant.icons--[[@as IconData[] ]] ) do
            newIcons[#newIcons + 1] = iconDetails
        end
    else
        newIcons[2] = {
            icon = waterVariant.icon,
            icon_size = iconSize
        }
    end
    waterVariant.icons = newIcons

    carsInWater[#carsInWater + 1] = waterVariant
end

data:extend(carsInWater)
