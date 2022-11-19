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
    if carPrototype.name == "car" then
        -- Overwrite the main graphics.
        waterVariant.animation.layers[1] = waterVariant.animation.layers[1].hr_version
        for _, stripe in pairs(waterVariant.animation.layers[1].stripes) do
            stripe.filename = string.gsub(stripe.filename, "__base__", "__careful_driver__")
            stripe.width_in_frames = 1
        end
        waterVariant.animation.layers[1].width = 201
        waterVariant.animation.layers[1].stripes = util.multiplystripes(2, waterVariant.animation.layers[1].stripes) -- cSpell:ignore multiplystripes #  Double up the stripe entries on our new graphics. As the entire prototype is setup as if there are 2 animation frames, but we only bothered to make 1 in our new file.

        -- Overwrite the color mask graphics.
        waterVariant.animation.layers[2] = waterVariant.animation.layers[2].hr_version
        for _, stripe in pairs(waterVariant.animation.layers[2].stripes) do
            stripe.filename = string.gsub(stripe.filename, "__base__", "__careful_driver__")
        end

        -- Undo the now un-needed doubled up elements.
        --[[for _, layer in pairs(waterVariant.animation.layers) do
            layer.frame_count = 1
        end
        waterVariant.light_animation.repeat_count = 1
        waterVariant.light_animation.hr_version.repeat_count = 1]]

    elseif carPrototype.name == "tank" then
        -- DO IN FUTURE
    end

    carsInWater[#carsInWater + 1] = waterVariant
end

data:extend(carsInWater)
