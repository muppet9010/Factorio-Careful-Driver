--[[
    Create an animation for each `car` type for when it falls in to the void.

    Run in final fixes data stage in the hope I don't have to add any dependencies on other mods, as I don't want to change their prototypes, just make a copy of them.
]]

local TableUtils = require("utility.helper-utils.table-utils")
local Common = require("common")
local PrototypeUtils = require("utility.helper-utils.prototype-utils-data-stage")

local carsInVoid = {} ---@type table<int, Prototype.Animation>
for _, carPrototype in pairs(data.raw["car"]) do
    -- CODE NOTE: this assumes only the structure of base car types. Hopefully any modded car types would use a similar layout. We also assume that there are the full 64 rotation animations supplied.

    -- TODO: we need to grab just the right entry in each stripe of each layer for this rotation. So we need to build up the new animation layers as we go through each original layer and stripe. Only iterate the HR entries in each layer. The below code doesn't do this, but is where we got to before realising the approach was wrong.
    -- TODO: also add on the turret_animations once main animations are done.

    local layerBaseData = TableUtils.DeepCopy(carPrototype.animation.layers) --[[@as RotatedAnimation[] ]]
    -- Trim the layer info down so its just an animation.
    for _, animation in pairs(layerBaseData) do
        animation.direction_count = nil
        animation.line_length = nil
        if animation.hr_version ~= nil then
            animation.hr_version.direction_count = nil
            animation.hr_version.line_length = nil
        end
    end
    ---@cast layerBaseData Animation[]

    -- Make a new prototype for each rotation.
    for rotation = 1, 64 do
        local layers = TableUtils.DeepCopy(layerBaseData) --[[@as Animation[] ]]
        for _, animation in pairs(layers) do
            animation.y = rotation * animation.height --[[@as int16]]
            if animation.hr_version ~= nil then
                animation.hr_version.y = rotation * animation.hr_version.height --[[@as int16]]
            end
        end

        ---@type Prototype.Animation
        local voidAnimation = {
            type = "animation",
            name = Common.GetCarInVoidName(carPrototype.name, rotation),
            layers = layers
        }

        carsInVoid[#carsInVoid + 1] = voidAnimation
    end
end

data:extend(carsInVoid)
