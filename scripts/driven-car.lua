--[[
    This tracks a car from the point a player gets in to the car until the player gets out of the car and the car reaches 0 speed.
]]

local DrivenCar = {} ---@class DrivenCar
local Events = require("utility.manager-libraries.events")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local PositionUtils = require("utility.helper-utils.position-utils")
local Common = require("common")
local MathUtils = require("utility.helper-utils.math-utils")
local PrototypeAttributes = require("utility.functions.prototype-attributes")

--- The details about a moving player car we need to track.
---@class MovingCar
---@field entity LuaEntity
---@field name string # Prototype name of the real car prototype.
---@field oldSpeed float
---@field oldPosition MapPosition
---@field oldSurface LuaSurface

---@class CarEnteringWater
---@field id int
---@field entity LuaEntity
---@field oldSpeedAbs float
---@field speedPositive boolean
---@field oldPosition MapPosition
---@field orientation RealOrientation
---@field surface LuaSurface
---@field name string # Prototype name of the car in water.

---@class CarEnteringVoid
---@field id int
---@field graphicId uint64
---@field speedAbs float
---@field speedPositive boolean
---@field oldPosition MapPosition
---@field oldScale double

DrivenCar.OnLoad = function()
    EventScheduler.RegisterScheduler()
    EventScheduler.RegisterScheduledEventType("DrivenCar.CheckTrackedCars_EachTick", DrivenCar.CheckTrackedCars_EachTick)

    MOD.Interfaces.DrivenCar = {
        OnPlayerGotInCar = DrivenCar.OnPlayerGotInCar
    }
end

DrivenCar.CreateGlobals = function()
    global.drivenCar = global.drivenCar or {} ---@class DrivenCar_Global
    global.drivenCar.movingCars = global.drivenCar.movingCars or {} ---@type table<LuaEntity, MovingCar> # Keyed by the vehicle entity.
    global.drivenCar.enteringWater = global.drivenCar.enteringWater or {} ---@type table<int, CarEnteringWater> # Keyed by a sequential integer number.
    global.drivenCar.enteringVoid = global.drivenCar.enteringVoid or {} ---@type table<int, CarEnteringVoid> # Keyed by a sequential integer number.
end

DrivenCar.OnStartup = function()
    if not EventScheduler.IsEventScheduledEachTick("DrivenCar.CheckTrackedCars_EachTick", "") then
        EventScheduler.ScheduleEventEachTick("DrivenCar.CheckTrackedCars_EachTick", "", nil)
    end
end

--- Called when a player has got in to a car.
---@param carEntity LuaEntity
DrivenCar.OnPlayerGotInCar = function(carEntity)
    if global.drivenCar.movingCars[carEntity] ~= nil then
        -- Car is already being tracked.
        return
    end

    -- Record the initial details for the car.
    global.drivenCar.movingCars[carEntity] = { entity = carEntity, oldSpeed = carEntity.speed, oldPosition = carEntity.position, oldSurface = carEntity.surface, name = carEntity.name }
end

--- Called every tick to process any cars that are being tracked.
---@param event UtilityScheduledEvent_CallbackObject
DrivenCar.CheckTrackedCars_EachTick = function(event)
    local carEntity, currentSpeed, carHitThing
    for _, movingCarDetails in pairs(global.drivenCar.movingCars) do
        carEntity = movingCarDetails.entity

        -- Check if the car has been removed from the map.
        if not carEntity.valid then
            global.drivenCar.movingCars[carEntity] = nil
            goto EndOfMovingCarDetailsLoop
        end

        -- Check the car is on the same surface and hasn't been teleported.
        if carEntity.surface ~= movingCarDetails.oldSurface then
            -- Car has changed surface, so just update the current details this tick.
            movingCarDetails.oldSurface = carEntity.surface
            goto UpdateCarDataInMovingCarDetailsLoop
        end

        currentSpeed = carEntity.speed ---@cast currentSpeed - nil # Cars always have a speed field.

        -- Check if the car was not moving last tick. As if not then it can't have stopped this tick due to a collision.
        if movingCarDetails.oldSpeed == 0 then
            -- Car wasn't moving last tick.

            -- If there's no player in the vehicle any more and the vehicle has no speed then stop tracking it. As it won't gain speed.
            if carEntity.get_driver() == nil and currentSpeed == 0.0 then
                global.drivenCar.movingCars[carEntity] = nil
                goto EndOfMovingCarDetailsLoop
            end

            -- Otherwise update its data for this tick and check again next tick.
            goto UpdateCarDataInMovingCarDetailsLoop
        end

        -- Check if the car is still moving we always need to continue tracking it.
        if currentSpeed ~= 0.0 then
            -- Car still moving this tick so nothing to do than update cached details ready for checks next tick.
            goto UpdateCarDataInMovingCarDetailsLoop
        end

        -- Current speed has reached 0.

        -- Check if the car has hit something to stop it.
        carHitThing = DrivenCar.DidCarHitSomethingToStop(carEntity, movingCarDetails.oldPosition, movingCarDetails.oldSpeed, movingCarDetails.oldSurface, movingCarDetails.name)
        if carHitThing ~= "nothing" then
            if carHitThing == "water" then
                DrivenCar.HitWater(carEntity, movingCarDetails.oldSpeed, movingCarDetails.oldPosition, movingCarDetails.oldSurface, movingCarDetails.name)

                -- Car is done, so no need to process it any further.
                global.drivenCar.movingCars[carEntity] = nil
                goto EndOfMovingCarDetailsLoop
            elseif carHitThing == "void" then
                DrivenCar.HitVoid(carEntity, movingCarDetails.oldSpeed, movingCarDetails.oldPosition, movingCarDetails.oldSurface, movingCarDetails.name)

                -- Car is done, so no need to process it any further.
                global.drivenCar.movingCars[carEntity] = nil
                goto EndOfMovingCarDetailsLoop
            elseif carHitThing == "cliff" then
                game.print("hit cliff entity")

                -- Car stopped, but needs to continue being monitored in future ticks.
                goto UpdateCarDataInMovingCarDetailsLoop
            end
        end

        -- Car didn't hit something so it just stopped naturally.

        -- If there's no driver in the car we can just forget about the car from now on. If there is still a player in it we will need to continue monitoring it in future ticks. If a passenger wants to get in to the drivers seat this will raise an event we monitor.
        if carEntity.get_driver() == nil then
            global.drivenCar.movingCars[carEntity] = nil
            goto EndOfMovingCarDetailsLoop
        end

        -- The car has stopped naturally so continue monitoring it.

        ::UpdateCarDataInMovingCarDetailsLoop::
        -- Update the standard data for this ticks state, as we need to continue monitoring it for future ticks.
        movingCarDetails.oldSpeed = currentSpeed
        movingCarDetails.oldPosition = carEntity.position

        ::EndOfMovingCarDetailsLoop::
    end

    -- Progress any cars that are entering the water.
    for index, carEnteringWater in pairs(global.drivenCar.enteringWater) do
        if not DrivenCar.CarContinuingToEnterWater(carEnteringWater) then
            global.drivenCar.enteringWater[index] = nil
        end
    end

    -- Progress any cars that are entering the void.
    for index, carEnteringVoid in pairs(global.drivenCar.enteringVoid) do
        if not DrivenCar.CarContinuingToEnterVoid(carEnteringVoid) then
            global.drivenCar.enteringVoid[index] = nil
        end
    end
end

--- A car has just stopped, did it hit something?
---@param carEntity LuaEntity
---@param oldPosition MapPosition
---@param oldSpeed double # will never be 0.
---@param surface LuaSurface
---@param entityName string # Prototype name of the real car prototype.
---@return "water"|"void"|"cliff"|"nothing"
DrivenCar.DidCarHitSomethingToStop = function(carEntity, oldPosition, oldSpeed, surface, entityName)
    -- Work out where the car would be if it had continued at its old speed from its old position on its current orientation.
    local futurePosition = PositionUtils.GetPositionForOrientationDistance(oldPosition, oldSpeed, carEntity.orientation)

    -- Entities are collided with by a vehicle on their collision box. While tiles are collided with by the vehicles position and which tile this lands on. This means we would collide with an entity prior to a tile.

    -- Detect if it was a tile we hit. This is easier to check so do it first.
    local futureTile = surface.get_tile(futurePosition--[[@as TilePosition]] )
    local futureTile_name = futureTile.name
    local futureTile_collidesMask = PrototypeAttributes.GetAttribute("tile", futureTile_name, "collision_mask") --[[@as CollisionMask]]
    local carPrototype_collisionMask = PrototypeAttributes.GetAttribute("entity", entityName, "collision_mask") --[[@as CollisionMask]]
    for tileCollisionMask in pairs(futureTile_collidesMask) do
        if carPrototype_collisionMask[tileCollisionMask] ~= nil then
            -- Collision between car and tile has occurred.

            -- Use the collision layers to detect the tile type. Based on vanilla tiles, but should handle any modded ones as well.
            if futureTile_collidesMask["ground-tile"] or futureTile_collidesMask["floor-layer"] or futureTile_collidesMask["object"] then
                -- These are the layers vanilla out-of-map tiles have that waters don't.
                return "void"
            elseif futureTile_collidesMask["water-tile"] or futureTile_collidesMask["item-layer"] or futureTile_collidesMask["resource-layer"] or futureTile_collidesMask["player-layer"] or futureTile_collidesMask["doodad-layer"] or futureTile_collidesMask["object-layer"] then
                -- These are the layers vanilla water tile have across the walkable and non-walkable tile types.
                return "water"
            else
                -- No idea so error.
                error("a car has collided with a tile that isn't on the tile layer of void or water...")
            end
        end
    end

    -- FUTURE: detecting cliff collisions will require handling odd orientation collision boxes.

    return "nothing"
end

--- When a car has first hit water and stopped.
---@param carEntity LuaEntity
---@param speed float
---@param position MapPosition
---@param surface LuaSurface
---@param entityName string # Prototype name of the real car prototype.
DrivenCar.HitWater = function(carEntity, speed, position, surface, entityName)
    -- Work out how much damage will be done by this crash. Halve the impact damage amount as crashing in to water is "gentle". The damage to be done is halved before any resistance is taken in to account. So resistances then still get to reduce damage.
    local damageToCar = DrivenCar.CalculateCarImpactDamage(entityName, speed) / 2
    local carsHealthBeforeCrash = carEntity.health
    local damageDoneToCar = carEntity.damage(damageToCar, carEntity.force, "impact")
    -- If the car is going to be killed by the damage it isn't done until later in the tick. So we have to manually check if the damage has killed the entity, as if it has the entities health wasn't reduced by the damage, it's just been marked as to-be-dead.
    if carsHealthBeforeCrash <= damageDoneToCar then
        -- Car was killed by the impact damage, so no need to handle it further.
        return
    end

    -- Explicitly kick any players out of the car before we place the new one so that the game's natural placement logic can work. As having 2 cars on top of one another prevents this logic from working.
    local driver = carEntity.get_driver()
    if driver ~= nil then
        carEntity.set_driver(nil) -- Must do this from car's view and not player.driving as that doesn't get the driver out quick enough.
    end
    local passenger = carEntity.get_passenger()
    if passenger ~= nil then
        carEntity.set_passenger(nil) -- Must do this from car's view and not player.driving as that doesn't get the driver out quick enough.
    end

    -- Place the stuck in water car where the real car was.
    local carInWaterEntityName = Common.GetCarInWaterName(entityName)
    local carInWaterOrientation = carEntity.orientation
    local carInWaterEntity = surface.create_entity({ name = carInWaterEntityName, position = position, force = carEntity.force, player = carEntity.last_user, create_build_effect_smoke = false, raise_built = true })
    if carInWaterEntity == nil then error("failed to make car type in water") end
    carInWaterEntity.orientation = carInWaterOrientation
    carInWaterEntity.color = carEntity.color
    carInWaterEntity.health = carEntity.health

    -- Transfer the main inventory across.
    local carEntity_mainInventory = carEntity.get_inventory(defines.inventory.car_trunk)
    if carEntity_mainInventory ~= nil and not carEntity_mainInventory.is_empty() then
        local carInWaterEntity_mainInventory = carInWaterEntity.get_inventory(defines.inventory.car_trunk) ---@cast carInWaterEntity_mainInventory - nil # If the real carEntity has an inventory so will the water copy of it.
        ---@type uint
        for stackIndex = 1, #carEntity_mainInventory do
            carEntity_mainInventory[stackIndex].swap_stack(carInWaterEntity_mainInventory[stackIndex])
        end
    end

    -- Transfer any fuel across.
    local carEntity_burner = carEntity.burner
    if carEntity_burner ~= nil then
        local carInWaterEntity_burner = carInWaterEntity.burner ---@cast carInWaterEntity_burner - nil # If the real carEntity has an inventory so will the water copy of it.

        local carEntity_burnerInputInventory = carEntity_burner.inventory
        if carEntity_burnerInputInventory ~= nil and not carEntity_burnerInputInventory.is_empty() then
            local carInWaterEntity_BurnerInputInventory = carInWaterEntity_burner.inventory ---@cast carInWaterEntity_BurnerInputInventory - nil # If the real carEntity has an inventory so will the water copy of it.
            ---@type uint
            for stackIndex = 1, #carEntity_burnerInputInventory do
                carEntity_burnerInputInventory[stackIndex].swap_stack(carInWaterEntity_BurnerInputInventory[stackIndex])
            end
        end

        local carEntity_burnerResultInventory = carEntity_burner.burnt_result_inventory
        if carEntity_burnerResultInventory ~= nil and not carEntity_burnerResultInventory.is_empty() then
            local carInWaterEntity_BurnerResultInventory = carInWaterEntity_burner.burnt_result_inventory ---@cast carInWaterEntity_BurnerResultInventory - nil # If the real carEntity has an inventory so will the water copy of it.
            ---@type uint
            for stackIndex = 1, #carEntity_burnerResultInventory do
                carEntity_burnerResultInventory[stackIndex].swap_stack(carInWaterEntity_BurnerResultInventory[stackIndex])
            end
        end
    end

    -- Transfer any ammo across.
    local carEntity_ammoInventory = carEntity.get_inventory(defines.inventory.car_ammo)
    if carEntity_ammoInventory ~= nil and not carEntity_ammoInventory.is_empty() then
        local carInWaterEntity_ammoInventory = carInWaterEntity.get_inventory(defines.inventory.car_ammo) ---@cast carInWaterEntity_ammoInventory - nil # If the real carEntity has an inventory so will the water copy of it.
        ---@type uint
        for stackIndex = 1, #carEntity_ammoInventory do
            carEntity_ammoInventory[stackIndex].swap_stack(carInWaterEntity_ammoInventory[stackIndex])
        end
    end

    -- Remove the real vehicle.
    carEntity.destroy({ raise_destroy = true })

    -- The progression of the vehicle each tick will handle its initial movement and creation of water splash effects etc.
    global.drivenCar.enteringWater[#global.drivenCar.enteringWater + 1] = { id = #global.drivenCar.enteringWater + 1, entity = carInWaterEntity, oldPosition = position, oldSpeedAbs = math.abs(speed) --[[@as float]] , speedPositive = speed > 0, orientation = carInWaterOrientation, surface = surface, name = carInWaterEntityName }
end

--- Called each tick for a car that is entering the water currently.
---@param carEnteringWater CarEnteringWater
---@return boolean continueMovingCar
DrivenCar.CarContinuingToEnterWater = function(carEnteringWater)
    -- Check the car in water entity hasn't been removed.
    if not carEnteringWater.entity.valid then return false end

    -- Get the forwards moving orientation and then use the absolute speed when required with it.
    local movingOrientation = carEnteringWater.speedPositive and carEnteringWater.orientation or MathUtils.LoopFloatValueWithinRange(carEnteringWater.orientation - 0.5, 0, 1) --[[@as RealOrientation]]

    -- Move the car based on the current speed.
    local newPosition = PositionUtils.GetPositionForOrientationDistance(carEnteringWater.oldPosition, carEnteringWater.oldSpeedAbs, movingOrientation)
    carEnteringWater.entity.teleport(newPosition)
    carEnteringWater.oldPosition = newPosition

    -- Add a water splash at the front of the vehicle based on the speed.
    local splashesToAdd = math.ceil(carEnteringWater.oldSpeedAbs / 0.05)
    local boundingBox = PrototypeAttributes.GetAttribute("entity", carEnteringWater.name, "collision_box") --[[@as BoundingBox]]
    for _ = 1, splashesToAdd do
        local offset = {
            x = (math.random() * (boundingBox.left_top.x - 1)) + ((boundingBox.right_bottom.x + 1) / 2),
            y = boundingBox.left_top.y - 0.5 -- Put this a bit in front of the vehicle.
        }
        local waterSplashPosition = PositionUtils.RotateOffsetAroundPosition(movingOrientation, offset, newPosition)
        carEnteringWater.surface.create_entity({ name = "careful_driver-water_splash-off_grid", position = waterSplashPosition })
    end

    -- Record the reduced speed for next tick. Reduce by the greater reduction between 33% of current or 0.02. Speed of 0.5 is 108km/h
    -- TODO: this should probably account for the weight of the vehicle, so that a tank goes further than a car at the same speed. Base off car's distance as present value and then see how a tank ends up with nothing and weight applied. Car speed tested at is 0.5 which is half max car speed on dirt with solid fuel. So a tank should be tested at 0.25 as its max speed is roughly half a cars.
    carEnteringWater.oldSpeedAbs = math.max(carEnteringWater.oldSpeedAbs - math.max(carEnteringWater.oldSpeedAbs / 3, 0.02), 0)

    if carEnteringWater.oldSpeedAbs > 0 then
        return true
    else
        return false
    end
end

--- Work out how much damage the car should take from colliding with an indestructible entity.
---@param carName string
---@param speed float
---@return float
DrivenCar.CalculateCarImpactDamage = function(carName, speed)
    -- This doesn't quite match base game logic, however we don't need to account for a vehicle accelerating from 0 in to something this tick or worry about it turning in to a target.
    local remainingEnergy = speed * speed * PrototypeAttributes.GetAttribute("entity", carName, "weight") --[[@as double]]
    local energyPerHitPoint = PrototypeAttributes.GetAttribute("entity", carName, "energy_per_hit_point") --[[@as double]]
    return remainingEnergy / energyPerHitPoint --[[@as float]]
end

--- When a car has first hit void and stopped.
---@param carEntity LuaEntity
---@param speed float
---@param position MapPosition
---@param surface LuaSurface
---@param entityName string # Prototype name of the real car prototype.
DrivenCar.HitVoid = function(carEntity, speed, position, surface, entityName)
    -- Explicitly kick any players out of the car before we do the void effect.
    local driver = carEntity.get_driver()
    if driver ~= nil then
        carEntity.set_driver(nil) -- Must do this from car's view and not player.driving as that doesn't get the driver out quick enough.
    end
    local passenger = carEntity.get_passenger()
    if passenger ~= nil then
        carEntity.set_passenger(nil) -- Must do this from car's view and not player.driving as that doesn't get the driver out quick enough.
    end

    -- Create the visual of the vehicle.
    local rotationNumber = DrivenCar.OrientationToRotation(carEntity.orientation)
    local graphicId = rendering.draw_animation({ name = Common.GetCarInVoidName(entityName, rotationNumber), x_scale = 1.0, y_scale = 1.0, tint = carEntity.color, render_layer = "object", target = position, surface = surface })

    -- Remove the real vehicle.
    carEntity.destroy({ raise_destroy = true })

    -- The progression of the vehicle each tick will handle its initial movement..
    global.drivenCar.enteringVoid[#global.drivenCar.enteringVoid + 1] = { id = #global.drivenCar.enteringVoid + 1, oldPosition = position, speedAbs = math.abs(speed) --[[@as float]] , speedPositive = speed > 0, graphicId = graphicId, oldScale = 1 }
end

--- Called each tick for a car that is entering the void currently.
---@param carEnteringVoid CarEnteringVoid
---@return boolean continueMovingCar
DrivenCar.CarContinuingToEnterVoid = function(carEnteringVoid)
    -- TODO: Continue moving the car forward at its speed for 1 tile and then have it stop. It can shrink during this time and afterwards.

    -- Testing code, but right concept.
    local newScale = carEnteringVoid.oldScale - 0.01
    if newScale == 0 then
        -- Reached end of vanishing.
        rendering.destroy(carEnteringVoid.graphicId)
        return false
    end

    local newPosition = carEnteringVoid.oldPosition
    newPosition.x = newPosition.x + 0.1

    rendering.set_target(carEnteringVoid.graphicId, newPosition)
    rendering.set_x_scale(carEnteringVoid.graphicId, newScale)
    rendering.set_y_scale(carEnteringVoid.graphicId, newScale)

    carEnteringVoid.oldScale = newScale
    carEnteringVoid.oldPosition = newPosition

    return true
end

--- Get a rotation number from an orientation value. We assume all cars have the full 64 rotations.
---@param orientation RealOrientation
---@return uint rotationNumber # 1-64
DrivenCar.OrientationToRotation = function(orientation)
    local upperOrientation = orientation + 0.0078125 -- Half of the orientation per rotation. This is to get us up to the upper band as 0 is actually the middle of the first rotation.
    local rotation = math.floor(upperOrientation / 0.015625) + 1 --[[@as uint]]
    if rotation == 65 then rotation = 1 end -- To catch the upper bound of orientation.
    return rotation
end

return DrivenCar
