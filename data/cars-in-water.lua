--[[
    Create a copy of each `car` type that is non drivable for the stuck in water version.

    Run in final fixes data stage in the hope I don't have to add any dependencies on other mods, as I don't want to change their prototypes, just make a copy of them.
]]

local TableUtils = require("utility.helper-utils.table-utils")
local Common = require("common")
local PrototypeUtils = require("utility.helper-utils.prototype-utils-data-stage")

local carsInWater = {} ---@type table<int, Prototype.Car>
for _, carPrototype in pairs(data.raw["car"]) do
    local waterVariant = TableUtils.DeepCopy(carPrototype) ---@type Prototype.Car
    local originalName = waterVariant.name

    -- Update the simpler fields on our water variant.
    waterVariant.name = Common.GetCarInWaterName(originalName)
    waterVariant.allow_passengers = false
    waterVariant.localised_name = { "entity-name.careful_driver-vehicle_stuck_in_water", { "entity-name." .. originalName } }
    waterVariant.localised_description = { "entity-description.careful_driver-vehicle_stuck_in_water", { "entity-name." .. originalName } }
    waterVariant.consumption = "0W" -- Vehicle is incapable of moving.

    -- Make the icon include a water background so its obvious in the editor.
    waterVariant.icons = PrototypeUtils.AddLayerToCopyOfIcons(carPrototype, "__base__/graphics/terrain/water/hr-water-o.png", 64, "back")
    waterVariant.icon = nil -- Clear any old value. If it was present we incorporated it in to icons already.
    waterVariant.icon_size = nil -- Clear any old value, we utilised it if it was set.

    -- Use custom graphics if we have made them for this vehicle type, otherwise just use their regular graphics.
    -- FUTURE: not used at present as it looks odd when partially on ground still.
    --[[if carPrototype.name == "car" then
        -- Only overwrite the main graphics. Leave everything else.
        waterVariant.animation.layers[1] = waterVariant.animation.layers[1].hr_version
        for _, stripe in pairs(waterVariant.animation.layers[1].stripes) do
            stripe.filename = string.gsub(stripe.filename, "__base__", "__careful_driver__")
        end
    elseif carPrototype.name == "tank" then
        -- DO IN FUTURE
    end]]
    -- Readme note: The graphics used for when road vehicles end up in the water have to be specifically made. Where these haven't been made for modded vehicles the regular vehicle graphic will be used instead.

    carsInWater[#carsInWater + 1] = waterVariant
end

data:extend(carsInWater)
