--[[
    Create a copy of each `car` type that can't move for the stuck in water version.

    Run in final fixes data stage in the hope I don't have to add any dependencies on other mods, as I don't want to change their prototypes, just make a copy of them.
]]

local TableUtils = require("utility.helper-utils.table-utils")
local Common = require("common")
local PrototypeUtils = require("utility.helper-utils.prototype-utils-data-stage")
local CollisionMaskUtils = require("__core__.lualib.collision-mask-util")

local carsInWater = {} ---@type table<int, Prototype.Car>
for _, carPrototype in pairs(data.raw["car"]) do
    -- Skip any vehicles from our mod.
    if string.find(carPrototype.name, "careful_driver-", 1, true) then goto EndOfCarPrototype end

    local waterVariant = TableUtils.DeepCopy(carPrototype) ---@type Prototype.Car
    local originalName = waterVariant.name

    -- Update the simpler fields on our water variant.
    waterVariant.name = Common.GetCarInWaterName(originalName)
    waterVariant.localised_name = { "entity-name.careful_driver-vehicle_stuck_in_water", { "entity-name." .. originalName } }
    waterVariant.localised_description = { "entity-description.careful_driver-vehicle_stuck_in_water", { "entity-name." .. originalName } }
    waterVariant.consumption = "0W" -- Vehicle is incapable of moving.
    waterVariant.water_reflection.pictures.shift[2] = waterVariant.water_reflection.pictures.shift[2] - 1

    -- Stopping te collision with water doesn't seem to affect getting the player in/out of the vehicle. But does make testing with the entity easier.
    local collisionMask = CollisionMaskUtils.get_default_mask(waterVariant.type) --[[@as CollisionMask]]
    CollisionMaskUtils.remove_layer(collisionMask, "water-tile")
    CollisionMaskUtils.remove_layer(collisionMask, "consider-tile-transitions")
    waterVariant.collision_mask = collisionMask

    -- Make the icon include a water background so its obvious in the editor.
    waterVariant.icons = PrototypeUtils.AddLayerToCopyOfIcons(carPrototype, "__base__/graphics/terrain/water/hr-water-o.png", 64, "back")
    waterVariant.icon = nil -- Clear any old value. If it was present we incorporated it in to icons already.
    waterVariant.icon_size = nil -- Clear any old value, we utilised it if it was set.

    -- Use custom graphics if we have made them for this vehicle type, otherwise just use their regular graphics.
    if carPrototype.name == "car" then
        -- Overwrite the main graphics. Have to update the graphic file attribute as I trimmed the image file as it had duplication.
        waterVariant.animation.layers[1] = waterVariant.animation.layers[1].hr_version
        for _, stripe in pairs(waterVariant.animation.layers[1].stripes) do
            stripe.filename = string.gsub(stripe.filename, "__base__", "__careful_driver__")
            stripe.width_in_frames = 1
        end
        waterVariant.animation.layers[1].stripes = util.multiplystripes(2, waterVariant.animation.layers[1].stripes) -- cSpell:ignore multiplystripes #  Double up the stripe entries on our new graphics. As the entire prototype is setup as if there are 2 animation frames, but we only bothered to make 1 in our new file.

        -- Overwrite the color mask graphics. This is unhelpfully on a different sprite sheet layout so ended up doing all by hand a second time quickly as very easy for these.
        waterVariant.animation.layers[2] = waterVariant.animation.layers[2].hr_version
        for _, stripe in pairs(waterVariant.animation.layers[2].stripes) do
            stripe.filename = string.gsub(stripe.filename, "__base__", "__careful_driver__")
        end

        -- Move the shadow up a bit as the water surface is higher up. Not perfect, but looks better than default shadow position. Really I need to modify the shadow sprites to make it proper.
        waterVariant.animation.layers[3].shift[1] = waterVariant.animation.layers[3].shift[1] - 0.1
        waterVariant.animation.layers[3].shift[2] = waterVariant.animation.layers[3].shift[2] - 0.2
    elseif carPrototype.name == "tank" then
        -- Overwrite the main graphics. Have to update the graphic file attribute as I trimmed the image file as it had duplication.
        waterVariant.animation.layers[1] = waterVariant.animation.layers[1].hr_version
        for _, stripe in pairs(waterVariant.animation.layers[1].stripes) do
            stripe.filename = string.gsub(stripe.filename, "__base__", "__careful_driver__")
            stripe.width_in_frames = 1
        end
        waterVariant.animation.layers[1].stripes = util.multiplystripes(2, waterVariant.animation.layers[1].stripes) -- cSpell:ignore multiplystripes #  Double up the stripe entries on our new graphics. As the entire prototype is setup as if there are 2 animation frames, but we only bothered to make 1 in our new file.

        -- Move the shadow up a bit as the water surface is higher up. Not perfect, but looks better than default shadow position. Really I need to modify the shadow sprites to make it proper.
        waterVariant.animation.layers[3].shift[1] = waterVariant.animation.layers[3].shift[1] - 0.1
        waterVariant.animation.layers[3].shift[2] = waterVariant.animation.layers[3].shift[2] - 0.2
    end

    carsInWater[#carsInWater + 1] = waterVariant

    ::EndOfCarPrototype::
end

data:extend(carsInWater)
