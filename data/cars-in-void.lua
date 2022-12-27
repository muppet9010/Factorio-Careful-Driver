--[[
    Create an animation for each `car` type for when it falls in to the void.

    Run in final fixes data stage in the hope I don't have to add any dependencies on other mods, as I don't want to change their prototypes, just make a copy of them.

    This is all a bit flaky and written to just work with base game assets.
]]

local TableUtils = require("utility.helper-utils.table-utils")
local Common = require("common")

--- Returns the value if non nil, otherwise the default value
---@param value any
---@param default any
---@return any
local ValueOrDefault = function(value, default)
    if value ~= nil then return value end
    return default
end

for _, carPrototype in pairs(data.raw["car"]) do
    -- Skip any vehicles from our mod.
    if string.find(carPrototype.name, "careful_driver-", 1, true) then goto EndOfCarPrototype end

    -- CODE NOTE: this assumes only the structure of base car types (cars and tanks). Hopefully any modded car types would use a similar layout.
    ---@type table<int, Prototype.Animation>, table<int, Prototype.Animation>, table<int, Prototype.Animation>, table<int, Prototype.Animation>
    local carBodyRotationsInVoid, tintableCarBodyRotationsInVoid, carTurretRotationsInVoid, tintableCarTurretRotationsInVoid = {}, {}, {}, {}

    -- Make the framework of our animations for the direction count.
    local primaryAnimationLayer
    if carPrototype.animation.layers ~= nil then
        primaryAnimationLayer = carPrototype.animation.layers[1]
    else
        primaryAnimationLayer = carPrototype.animation
    end
    local directionCount = primaryAnimationLayer.direction_count
    local targetFrameCount = ValueOrDefault(primaryAnimationLayer.frame_count, 1) -- Just assume the first layer is the one with all the variations. And the later layers are the ones with potentially less real frames.
    local maxAdvance = primaryAnimationLayer.max_advance -- Not entirely sure what it does, but we need the same on all layers.

    for animationPrototypes, nameOptions in pairs({ [carBodyRotationsInVoid] = { part = "body", tintable = "nonTinted" }, [tintableCarBodyRotationsInVoid] = { part = "body", tintable = "tinted" }, [carTurretRotationsInVoid] = { part = "turret", tintable = "nonTinted" }, [tintableCarTurretRotationsInVoid] = { part = "turret", tintable = "tinted" } }) do
        ---@cast animationPrototypes table<int, Prototype.Animation>
        ---@cast nameOptions table

        ---@type uint
        for rotationCount = 1, directionCount do
            ---@type Prototype.Animation
            animationPrototypes[rotationCount] = {
                type = "animation",
                name = Common.GetCarInVoidName(carPrototype.name, rotationCount, nameOptions.part, nameOptions.tintable),
                layers = {}
            }
        end
    end

    -- Loop over each rotated animation layer for the main animation and turret. We will need to extract each rotation graphic from each layer in to our animation prototypes. The turret will always be pointing forwards for this, as otherwise we have to make a separate graphic for the turret.
    -- If there aren't layers then we treat the single animation definition as a single layer.
    local animationParts = {} ---@type table<"body"|"turret", RotatedAnimation[]>
    if carPrototype.animation ~= nil then
        if carPrototype.animation.layers ~= nil then
            animationParts.body = carPrototype.animation.layers
        else
            animationParts.body = { carPrototype.animation }
        end
    end
    if carPrototype.turret_animation ~= nil then
        if carPrototype.turret_animation.layers ~= nil then
            animationParts.turret = carPrototype.turret_animation.layers
        else
            animationParts.turret = { carPrototype.turret_animation }
        end
    end
    for partName, animationPart in pairs(animationParts) do
        if animationPart == nil then goto EndOfThis_AnimationParts_LoopInstance end

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
                        local stripeInnerCount = 1
                        for heightCount = 1, stripe.height_in_frames do
                            for widthCount = 1, stripe.width_in_frames, ValueOrDefault(animationBase.frame_count, 1) do
                                rotationCount = rotationCount + 1
                                local carRotationInVoid_layer = {} ---@type Animation

                                -- Extract the stripe details and push them to the new layer.
                                carRotationInVoid_layer.filename = stripe.filename
                                -- Select the right bit of the sprite for our specific frame row.
                                carRotationInVoid_layer.x = (widthCount - 1) * ValueOrDefault(animationBase.width, animationBase.size) --[[@as int16]]
                                carRotationInVoid_layer.y = (heightCount - 1) * ValueOrDefault(animationBase.height, animationBase.size) --[[@as int16]]

                                -- If this stripe doesn't have the right number of frames then just duplicate the first one, don't worry about trying to handle odd multiplications. The original vanilla car and tank structure duplicated the stripes to make up for it, but we are ignoring duplicated stripes as they just make things weird to process.
                                if stripe.width_in_frames ~= targetFrameCount then
                                    carRotationInVoid_layer.frame_count = 1
                                    carRotationInVoid_layer.repeat_count = targetFrameCount --[[@as uint8 # Just hope its ok, more than 255 animation frames would be an excessively large vehicle graphic.]]
                                    carRotationInVoid_layer.line_length = 1
                                else
                                    carRotationInVoid_layer.frame_count = targetFrameCount
                                    carRotationInVoid_layer.repeat_count = ValueOrDefault(animationBase.repeat_count, 1)
                                    carRotationInVoid_layer.line_length = ValueOrDefault(animationBase.line_length, 0)
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
                                local carRotationInVoid
                                if partName == "body" then
                                    if not carRotationInVoid_layer.apply_runtime_tint then
                                        -- Standard Animation that isn't tinted at run time.
                                        carRotationInVoid = carBodyRotationsInVoid[rotationCount]
                                    else
                                        -- Animation that can be tinted to player color at run time.
                                        carRotationInVoid = tintableCarBodyRotationsInVoid[rotationCount]
                                    end
                                elseif partName == "turret" then
                                    if not carRotationInVoid_layer.apply_runtime_tint then
                                        -- Standard Animation that isn't tinted at run time.
                                        carRotationInVoid = carTurretRotationsInVoid[rotationCount]
                                    else
                                        -- Animation that can be tinted to player color at run time.
                                        carRotationInVoid = tintableCarTurretRotationsInVoid[rotationCount]
                                    end
                                end
                                carRotationInVoid.layers[#carRotationInVoid.layers + 1] = carRotationInVoid_layer
                                stripeInnerCount = stripeInnerCount + 1
                                if stripeInnerCount == directionCount then
                                    -- Some mods have empty gaps at the end of their sprite sheets.
                                    break
                                end
                            end
                            if stripeInnerCount == directionCount then
                                -- Some mods have empty gaps at the end of their sprite sheets.
                                break
                            end
                        end
                    end
                end
            else
                -- Is a straight filename.

                -- For each rotation push the details to the Animation prototype.
                for rotationCount = 1, directionCount do
                    local carRotationInVoid_layer = {} ---@type Animation

                    -- Select the right bit of the animations for our specific frame row.
                    -- This is likely a grid of animations, so need to find the right one for our rotation.
                    local rotationsPerLine = ValueOrDefault(animationBase.line_length, 0) / ValueOrDefault(animationBase.frame_count, 1)
                    if rotationsPerLine < 1 then
                        -- Needed for Avatar mod with its badly defined (but valid) graphics. They don't behave as that mod's author intended, but they do load without error.
                        rotationsPerLine = 1
                    end
                    local yLine = math.floor((rotationCount - 1) / rotationsPerLine)
                    carRotationInVoid_layer.y = yLine * ValueOrDefault(animationBase.height, animationBase.size) --[[@as int16]]
                    local xLine = (rotationCount - ((yLine * rotationsPerLine) + 1)) * ValueOrDefault(animationBase.frame_count, 1)
                    carRotationInVoid_layer.x = xLine * ValueOrDefault(animationBase.width, animationBase.size) --[[@as int16]]

                    -- If this animation doesn't have the right number of frames then just duplicate the first one, don't worry about trying to handle odd multiplications. The original vanilla car and tank structure duplicated the animations to make up for it, but we are ignoring duplicated animations as they just make things weird to process.
                    if animationBase.frame_count ~= targetFrameCount then
                        carRotationInVoid_layer.frame_count = 1
                        carRotationInVoid_layer.repeat_count = targetFrameCount --[[@as uint8 # Just hope its ok, more than 255 animation frames would be an excessively large vehicle graphic.]]
                        carRotationInVoid_layer.line_length = 1
                    else
                        carRotationInVoid_layer.frame_count = targetFrameCount
                        carRotationInVoid_layer.repeat_count = ValueOrDefault(animationBase.repeat_count, 1)
                        carRotationInVoid_layer.line_length = ValueOrDefault(animationBase.line_length, 0)
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
                    local carRotationInVoid
                    if partName == "body" then
                        if not carRotationInVoid_layer.apply_runtime_tint then
                            -- Standard Animation that isn't tinted at run time.
                            carRotationInVoid = carBodyRotationsInVoid[rotationCount]
                        else
                            -- Animation that can be tinted to player color at run time.
                            carRotationInVoid = tintableCarBodyRotationsInVoid[rotationCount]
                        end
                    elseif partName == "turret" then
                        if not carRotationInVoid_layer.apply_runtime_tint then
                            -- Standard Animation that isn't tinted at run time.
                            carRotationInVoid = carTurretRotationsInVoid[rotationCount]
                        else
                            -- Animation that can be tinted to player color at run time.
                            carRotationInVoid = tintableCarTurretRotationsInVoid[rotationCount]
                        end
                    end
                    carRotationInVoid.layers[#carRotationInVoid.layers + 1] = carRotationInVoid_layer
                end
            end
        end

        ::EndOfThis_AnimationParts_LoopInstance::
    end

    -- If any of the animations are empty for this vehicle add an empty sprite to them. As runtime can't know what exists and doesn't easily.
    for _, animationPrototypes in pairs({ carBodyRotationsInVoid, tintableCarBodyRotationsInVoid, carTurretRotationsInVoid, tintableCarTurretRotationsInVoid }) do
        for _, animationPrototype in pairs(animationPrototypes) do
            if #animationPrototype.layers == 0 then
                animationPrototype.layers[1] = {
                    filename = "__core__/graphics/empty.png",
                    height = 1,
                    width = 1
                }
            end
        end
    end

    -- Push the animations for this car type.
    data:extend(carBodyRotationsInVoid)
    data:extend(tintableCarBodyRotationsInVoid)
    data:extend(carTurretRotationsInVoid)
    data:extend(tintableCarTurretRotationsInVoid)

    ::EndOfCarPrototype::
end
