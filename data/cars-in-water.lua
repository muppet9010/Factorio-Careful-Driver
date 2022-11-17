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
    waterVariant.name = Common.GetCarInWaterName(waterVariant.name)
    waterVariant.allow_passengers = false
    waterVariant.localised_description = "thing stuck in water" -- TODO & name.
    --TODO: make the icon more unique so in the editor list its apparent. Just add water tile graphic behind the image or something simple.

    carsInWater[#carsInWater + 1] = waterVariant
end

data:extend(carsInWater)
