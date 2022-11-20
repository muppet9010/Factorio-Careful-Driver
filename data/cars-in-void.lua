--[[
    Create an animation for each `car` type for when it falls in to the void.

    Run in final fixes data stage in the hope I don't have to add any dependencies on other mods, as I don't want to change their prototypes, just make a copy of them.

    This is all a bit flaky and written to just work with base game assets.
]]

local TableUtils = require("utility.helper-utils.table-utils")
local Common = require("common")
local PrototypeUtils = require("utility.helper-utils.prototype-utils-data-stage")

for _, carPrototype in pairs(data.raw["car"]) do
    -- Skip any vehicles from our mod.
    if string.find(carPrototype.name, "careful_driver-", 1, true) then goto EndOfCarPrototype end

    -- CODE NOTE: this assumes only the structure of base car types (cars and tanks). Hopefully any modded car types would use a similar layout.
    local carRotationsInVoid = {} ---@type table<int, Prototype.Animation>

    -- Make the framework of our animations for the direction count.
    local directionCount = carPrototype.animation.layers[1].direction_count
    local targetFrameCount = carPrototype.animation.layers[1].frame_count -- Just assume the first layer is the one with all the variations. And the later layers are the ones with potentially less real frames.
    local maxAdvance = carPrototype.animation.layers[1].max_advance -- Not entirely sure what it does, but we need the same on all layers.
    for rotationCount = 1, directionCount do
        ---@type Prototype.Animation
        carRotationsInVoid[rotationCount] = {
            type = "animation",
            name = Common.GetCarInVoidName(carPrototype.name, rotationCount),
            layers = {}
        }
    end

    -- Loop over each rotated animation layer for the main animation and turret. We will need to extract each rotation graphic from each layer in to our animation prototypes. The turret will always be pointing forwards for this, as otherwise we have to make a separate graphic for the turret.
    for _, animationPart in pairs({ carPrototype.animation.layers, carPrototype.turret_animation.layers }) do
        if animationPart ~= nil then
            for _, rotatedAnimation in pairs(animationPart) do
                local rotatedAnimationBase = TableUtils.DeepCopy(rotatedAnimation) --[[@as RotatedAnimation ]]

                -- We either do the hr_version or regular, don't bother with both.
                if rotatedAnimationBase.hr_version ~= nil then
                    rotatedAnimationBase = rotatedAnimationBase.hr_version
                end

                -- Trim the layer info down so its just an animation.
                rotatedAnimationBase.direction_count = nil
                local animationBase = rotatedAnimationBase --[[@as Animation]]

                -- Handle the filename specification format.
                if animationBase.stripes ~= nil then
                    -- Loop over the stripes entries.

                    local rotationCount = 0
                    local stripeFilesAlreadyDone = {} ---@type table<string, true> # Some animation stripes have the same same stripe multiple times to bulk up the frame count (double use the same frame image). This is needed in the original defs as other layers have additional frames per rotation and they all need the same number.

                    for _, stripe in pairs(animationBase.stripes) do
                        -- Check this stripe filename hasn't already been processed (duplicate stripes).
                        if not stripeFilesAlreadyDone[stripe.filename] then
                            stripeFilesAlreadyDone[stripe.filename] = true

                            -- For each rotation in the stripe push the details to the Animation prototype.
                            for stripeInnerCount = 1, stripe.height_in_frames do
                                rotationCount = rotationCount + 1
                                local carRotationInVoid_layer = {} ---@type Animation
                                local carRotationInVoid = carRotationsInVoid[rotationCount]

                                -- Extract the stripe details and push them to the new layer.
                                carRotationInVoid_layer.filename = stripe.filename
                                carRotationInVoid_layer.y = (stripeInnerCount - 1) * animationBase.height --[[@as int16]]
                                -- Select the right bit of the sprite for our specific frame row.

                                -- If this stripe doesn't have the right number of frames then just duplicate them. The original structure duplicated the stripes to make up for it, but we are ignoring duplicated stripes as they just make things weird to process.
                                if stripe.width_in_frames ~= targetFrameCount then
                                    carRotationInVoid_layer.frame_count = 1
                                    carRotationInVoid_layer.repeat_count = targetFrameCount --[[@as uint8 # Just hope its ok, more than 255 animation frames would be an excessively large vehicle graphic.]]
                                    carRotationInVoid_layer.line_length = 1
                                else
                                    carRotationInVoid_layer.frame_count = targetFrameCount
                                    carRotationInVoid_layer.repeat_count = animationBase.repeat_count
                                    carRotationInVoid_layer.line_length = animationBase.line_length
                                end

                                -- For each field in the main animation details add them to the animation prototype, excluding the stripes field as we've already processed the data we need from this.
                                for fieldName, value in pairs(animationBase--[[@as table<string, any> # We treat the source as just a dictionary to be looped over.]] ) do
                                    if fieldName ~= "stripes" and fieldName ~= "frame_count" and fieldName ~= "repeat_count" and fieldName ~= "line_length" and fieldName ~= "max_advance" then
                                        ---@cast carRotationInVoid_layer table<string, any> # Just treat the carRotationInVoid object as a dictionary for this process.
                                        carRotationInVoid_layer[fieldName] = value
                                    end
                                end

                                -- Just blindly set some values to avoid errors.
                                carRotationInVoid_layer.max_advance = maxAdvance

                                -- Record this new layer to our Animation.
                                carRotationInVoid.layers[#carRotationInVoid.layers + 1] = carRotationInVoid_layer
                            end
                        end
                    end
                else
                    -- Is a straight filename.

                    -- For each rotation push the details to the Animation prototype.
                    for rotationCount = 1, targetFrameCount do
                        local carRotationInVoid_layer = {} ---@type Animation
                        local carRotationInVoid = carRotationsInVoid[rotationCount]

                        -- If this stripe doesn't have the right number of frames then just duplicate them. The original structure duplicated the stripes to make up for it, but we are ignoring duplicated stripes as they just make things weird to process.
                        if animationBase.frame_count ~= targetFrameCount then
                            carRotationInVoid_layer.frame_count = 1
                            carRotationInVoid_layer.repeat_count = targetFrameCount --[[@as uint8 # Just hope its ok, more than 255 animation frames would be an excessively large vehicle graphic.]]
                            carRotationInVoid_layer.line_length = 1
                        else
                            carRotationInVoid_layer.frame_count = targetFrameCount
                            carRotationInVoid_layer.repeat_count = animationBase.repeat_count
                            carRotationInVoid_layer.line_length = animationBase.line_length
                        end

                        -- For each field in the main animation details add them to the animation prototype.
                        for fieldName, value in pairs(animationBase--[[@as table<string, any> # We treat the source as just a dictionary to be looped over.]] ) do
                            if fieldName ~= "frame_count" and fieldName ~= "repeat_count" and fieldName ~= "line_length" and fieldName ~= "max_advance" then
                                ---@cast carRotationInVoid_layer table<string, any> # Just treat the carRotationInVoid object as a dictionary for this process.
                                carRotationInVoid_layer[fieldName] = value
                            end
                        end

                        -- Just blindly set some values to avoid errors.
                        carRotationInVoid_layer.max_advance = maxAdvance

                        -- Record this new layer to our Animation.
                        carRotationInVoid.layers[#carRotationInVoid.layers + 1] = carRotationInVoid_layer
                    end
                end
            end
        end
    end

    -- Push the animations for this car type.
    data:extend(carRotationsInVoid)

    ::EndOfCarPrototype::
end
