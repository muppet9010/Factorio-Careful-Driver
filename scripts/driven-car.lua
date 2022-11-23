--[[
    This tracks a car from the point a player gets in to the car until the player gets out of the car and the car reaches 0 speed.
]]

--[[
FUTURE:
    - To kill the car without corpse or explosion, we'd need to remove the real car, create a dummy car with a cloned prototype that doesn't have a corpse or death explosion, put the players in this car, then kill it via damage. That way the on_entity_death events would look natural to other mods and the  other mods could see who was driving the car from looking at its get_driver(). Alternatively the other mods could make an interface my mod can just call. Damage events we currently create a cause entity for, although in reality this could also be done via API, but it was very simple so done here first. Same concept issue with when we vanish (destroy) a players character to avoid creating a body.
]]

local DrivenCar = {} ---@class DrivenCar
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
---@field graphicIds uint64[]
---@field speedAbs float
---@field speedPositive boolean
---@field oldPosition MapPosition
---@field oldScale double
---@field distanceToFallPosition double # How far the target needs to move to reach where it will just fall straight down.
---@field orientation RealOrientation

---@alias PlayerInVoidCarOutcomes "vanish"|"die"|"eject"

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

    global.drivenCar.settings = global.drivenCar.settings or {} ---@class DrivenCar_Global_Settings
    global.drivenCar.settings.cliffCollision = global.drivenCar.settings.cliffCollision or true
    global.drivenCar.settings.cliffCollisionDamageMultiplier = global.drivenCar.settings.cliffCollisionDamageMultiplier or 1.0
    global.drivenCar.settings.waterCollision = global.drivenCar.settings.waterCollision or true
    global.drivenCar.settings.waterCollisionDamageMultiplier = global.drivenCar.settings.waterCollisionDamageMultiplier or 1.0
    global.drivenCar.settings.voidCollision = global.drivenCar.settings.voidCollision or true
    global.drivenCar.settings.voidCollisionPlayerOutcome = global.drivenCar.settings.voidCollisionPlayerOutcome or "vanish" ---@type PlayerInVoidCarOutcomes
end

DrivenCar.OnStartup = function()
    if not EventScheduler.IsEventScheduledEachTick("DrivenCar.CheckTrackedCars_EachTick", "") then
        EventScheduler.ScheduleEventEachTick("DrivenCar.CheckTrackedCars_EachTick", "", nil)
    end
end

---@param event EventData.on_runtime_mod_setting_changed|nil # nil value when called from OnStartup (on_init & on_configuration_changed)
DrivenCar.OnSettingChanged = function(event)
    if event == nil or event.setting == "careful_driver-car_cliff_collision" then
        global.drivenCar.settings.cliffCollision = settings.global["careful_driver-car_cliff_collision"].value --[[@as boolean]]
    end
    if event == nil or event.setting == "careful_driver-car_water_collision" then
        global.drivenCar.settings.waterCollision = settings.global["careful_driver-car_water_collision"].value --[[@as boolean]]
    end
    if event == nil or event.setting == "careful_driver-car_void_collision" then
        global.drivenCar.settings.voidCollision = settings.global["careful_driver-car_void_collision"].value --[[@as boolean]]
    end
    if event == nil or event.setting == "careful_driver-car_cliff_damage_multiplier" then
        global.drivenCar.settings.cliffCollisionDamageMultiplier = settings.global["careful_driver-car_cliff_damage_multiplier"].value --[[@as double]] / 100
    end
    if event == nil or event.setting == "careful_driver-car_water_damage_multiplier" then
        global.drivenCar.settings.waterCollisionDamageMultiplier = settings.global["careful_driver-car_water_damage_multiplier"].value --[[@as double]] / 100
    end
    if event == nil or event.setting == "careful_driver-player_in_car_void_collision" then
        global.drivenCar.settings.voidCollisionPlayerOutcome = settings.global["careful_driver-player_in_car_void_collision"].value --[[@as PlayerInVoidCarOutcomes]]
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
    local carEntity, currentSpeed, carHitName, carHitThing
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
        -- CODE NOTE: As the car has 0 speed this tick, it hasn't moved from its last tick position. So some of the cached data remains unchanged (position) that wouldn't if the car was still moving.
        -- We attribute damage to an entity so that other mods can react accurately to the cause. For tiles we create a fake entity for this.
        carHitName, carHitThing = DrivenCar.DidCarHitSomethingToStop(carEntity, movingCarDetails.oldPosition, movingCarDetails.oldSpeed, movingCarDetails.oldSurface, movingCarDetails.name)
        if carHitName ~= "nothing" then
            if carHitName == "water" then
                DrivenCar.HitWater(carEntity, movingCarDetails.oldSpeed, movingCarDetails.oldPosition, movingCarDetails.oldSurface, movingCarDetails.name)

                -- Car is done, so no need to process it any further.
                global.drivenCar.movingCars[carEntity] = nil
                goto EndOfMovingCarDetailsLoop
            elseif carHitName == "void" then
                DrivenCar.HitVoid(carEntity, movingCarDetails.oldSpeed, movingCarDetails.oldPosition, movingCarDetails.oldSurface, movingCarDetails.name)

                -- Car is done, so no need to process it any further.
                global.drivenCar.movingCars[carEntity] = nil
                goto EndOfMovingCarDetailsLoop
            elseif carHitName == "cliff" then
                -- Work out how much damage will be done by this crash. The vehicles resistances will reduce this value.
                local damageToCar = DrivenCar.CalculateCarImpactDamage(movingCarDetails.name, movingCarDetails.oldSpeed) * global.drivenCar.settings.cliffCollisionDamageMultiplier
                carEntity.damage(damageToCar, carEntity.force, "impact", carHitThing)
                if not carEntity.valid then
                    -- Car was killed by the impact damage, so no need to handle it further.
                    global.drivenCar.movingCars[carEntity] = nil
                    goto EndOfMovingCarDetailsLoop
                end

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
---@return "water"|"void"|"cliff"|"nothing" nameOfThingHit
---@return LuaEntity? thingHit # Only populated if the thing hit was an entity.
DrivenCar.DidCarHitSomethingToStop = function(carEntity, oldPosition, oldSpeed, surface, entityName)
    local orientation = carEntity.orientation

    -- Work out where the car would be if it had continued at its old speed from its old position on its current orientation.
    local futurePosition = PositionUtils.GetPositionForOrientationDistance(oldPosition, oldSpeed, orientation)

    -- Entities are collided with by a vehicle on their collision box. While tiles are collided with by the vehicles position and which tile this lands on. This means we would collide with an entity prior to a tile.

    -- Detect if it was a tile we hit. This is easier to check so do it first.
    if global.drivenCar.settings.waterCollision or global.drivenCar.settings.voidCollision then
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
                    if global.drivenCar.settings.voidCollision then
                        return "void"
                    else
                        return "nothing"
                    end
                elseif futureTile_collidesMask["water-tile"] or futureTile_collidesMask["item-layer"] or futureTile_collidesMask["resource-layer"] or futureTile_collidesMask["player-layer"] or futureTile_collidesMask["doodad-layer"] or futureTile_collidesMask["object-layer"] then
                    -- These are the layers vanilla water tile have across the walkable and non-walkable tile types.
                    if global.drivenCar.settings.waterCollision then
                        return "water"
                    else
                        return "nothing"
                    end
                else
                    -- No idea so error.
                    error("a car has collided with a tile that isn't on the tile layer of void or water...")
                end
            end
        end
    end

    -- See if it stopped from hitting a cliff in its travelling direction.
    if global.drivenCar.settings.cliffCollision then
        -- CODE NOTE: Factorio doesn't support us passing in an orientation as part of a BoundingBox to any of its API functions, so we have to do it as a square area and then manually check any results for diagonal collisions.
        local carsCollisionBox = PrototypeAttributes.GetAttribute("entity", entityName, "collision_box") --[[@as BoundingBox]]
        -- Get the front edge of the car as we will need to check for any cliffs in this width. Add 10% as the car may have been turning at the point and so it will be slightly wider on that side. At worst this would just find a cliff beyond our own collision box and we will check each result anyways.
        local frontBoundingBoxEdgeDistance
        if oldSpeed > 0 then
            frontBoundingBoxEdgeDistance = -carsCollisionBox.left_top.y * 1.1
        else
            frontBoundingBoxEdgeDistance = carsCollisionBox.right_bottom.y * 1.1
        end
        local vehicleWidth = carsCollisionBox.right_bottom.x - carsCollisionBox.left_top.x
        local futureFrontBoundingBoxCenter = PositionUtils.GetPositionForOrientationDistance(futurePosition, frontBoundingBoxEdgeDistance, orientation)
        -- Do an area search as we want to check cliff collision boxes and not for their center.
        ---@type BoundingBox
        local searchArea = { left_top = { x = futureFrontBoundingBoxCenter.x - vehicleWidth, y = futureFrontBoundingBoxCenter.y - vehicleWidth }, right_bottom = { x = futureFrontBoundingBoxCenter.x + vehicleWidth, y = futureFrontBoundingBoxCenter.y + vehicleWidth } }
        local cliffsAroundFutureFrontEdge = surface.find_entities_filtered({ type = "cliff", area = searchArea })
        if #cliffsAroundFutureFrontEdge > 0 then
            -- Cliffs found to check

            -- Get the car's future bounding box, but as a Polygon of MapPositions for later manual comparison.
            local futureCarCollisionPolygon = PositionUtils.MakePolygonMapPointsFromOrientatedCollisionBox(carsCollisionBox, orientation, futurePosition)

            -- Check each cliff for if it collides with the car.
            for _, cliffEntity in pairs(cliffsAroundFutureFrontEdge) do
                -- Have to use the bounding box as the different cliff-orientations have different collision boxes, but these aren't accessible via the entities prototype.
                local cliffCollisionPolygon = PositionUtils.MakePolygonMapPointsFromOrientatedBoundingBox(cliffEntity.bounding_box, cliffEntity.orientation, cliffEntity.position)
                if PositionUtils.Do2RotatedBoundingBoxesCollide(futureCarCollisionPolygon, cliffCollisionPolygon) then
                    return "cliff", cliffEntity
                end
            end
        end
    end

    return "nothing"
end

--- When a car has first hit water and stopped.
---@param carEntity LuaEntity
---@param speed float
---@param position MapPosition
---@param surface LuaSurface
---@param entityName string # Prototype name of the real car prototype.
DrivenCar.HitWater = function(carEntity, speed, position, surface, entityName)
    -- Work out how much damage will be done by this crash. Resistances then get to reduce damage actually suffered.
    local damageToCar = DrivenCar.CalculateCarImpactDamage(entityName, speed) * global.drivenCar.settings.waterCollisionDamageMultiplier
    local tokenWaterEntity = surface.create_entity({ name = "careful_driver-token_water_entity", position = position, force = carEntity.force, raise_built = false, create_build_effect_smoke = false }) ---@cast tokenWaterEntity - nil # Have to make this every time, as can't leave it anywhere sensible; as it must be on the cars surface and it needs to have graphics for when other mods reference it.
    carEntity.damage(damageToCar, carEntity.force, "impact", tokenWaterEntity)
    tokenWaterEntity.destroy({ raise_destroy = false })
    if not carEntity.valid then
        -- Car was killed by the impact damage, so no need to handle it further.
        return
    end

    -- Explicitly kick any players out of the car before we place the new one so that the game's natural placement logic can work. As having 2 cars on top of one another prevents this logic from working.
    -- CODE NOTE: any player ejecting must be done from the car's view and not player.driving as that doesn't get the driver out quick enough.
    local driver = carEntity.get_driver()
    if driver ~= nil then
        carEntity.set_driver(nil)
    end
    local passenger = carEntity.get_passenger()
    if passenger ~= nil then
        carEntity.set_passenger(nil)
    end

    -- Place the stuck in water car where the real car was.
    local carInWaterEntityName = Common.GetCarInWaterName(entityName)
    local carInWaterOrientation = carEntity.orientation
    local carInWaterEntity = surface.create_entity({ name = carInWaterEntityName, position = position, force = carEntity.force, player = carEntity.last_user, create_build_effect_smoke = false, raise_built = true })
    if carInWaterEntity == nil then error("failed to make car type in water") end
    carInWaterEntity.orientation = carInWaterOrientation
    carInWaterEntity.color = carEntity.color
    carInWaterEntity.health = carEntity.health
    carInWaterEntity.rotatable = false
    carInWaterEntity.active = false

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

        -- Transfer the fuel input slots.
        local carEntity_burnerInputInventory = carEntity_burner.inventory
        if carEntity_burnerInputInventory ~= nil and not carEntity_burnerInputInventory.is_empty() then
            local carInWaterEntity_BurnerInputInventory = carInWaterEntity_burner.inventory ---@cast carInWaterEntity_BurnerInputInventory - nil # If the real carEntity has an inventory so will the water copy of it.
            ---@type uint
            for stackIndex = 1, #carEntity_burnerInputInventory do
                carEntity_burnerInputInventory[stackIndex].swap_stack(carInWaterEntity_BurnerInputInventory[stackIndex])
            end
        end

        -- Transfer any burnt fuel inventory slots.
        local carEntity_burnerResultInventory = carEntity_burner.burnt_result_inventory
        if carEntity_burnerResultInventory ~= nil and not carEntity_burnerResultInventory.is_empty() then
            local carInWaterEntity_BurnerResultInventory = carInWaterEntity_burner.burnt_result_inventory ---@cast carInWaterEntity_BurnerResultInventory - nil # If the real carEntity has an inventory so will the water copy of it.
            ---@type uint
            for stackIndex = 1, #carEntity_burnerResultInventory do
                carEntity_burnerResultInventory[stackIndex].swap_stack(carInWaterEntity_BurnerResultInventory[stackIndex])
            end
        end

        -- Transfer any fuel currently being burnt.
        local carEntity_burnerCurrentlyBurning = carEntity_burner.currently_burning
        if carEntity_burnerCurrentlyBurning ~= nil then
            carInWaterEntity_burner.currently_burning = carEntity_burnerCurrentlyBurning
        end
        local carEntity_burnerRemainingBurningFuel = carEntity_burner.remaining_burning_fuel
        if carEntity_burnerRemainingBurningFuel ~= nil then
            carInWaterEntity_burner.remaining_burning_fuel = carEntity_burnerRemainingBurningFuel
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

    -- Transfer any equipment grid items across if the vehicle has one.
    local carEntity_grid = carEntity.grid
    if carEntity_grid ~= nil then
        local carInWaterEntity_grid = carInWaterEntity.grid ---@cast carInWaterEntity_grid - nil # If the real car entity prototype has one so will our stuck in water prototype.
        local movedEquipment, energy, shield
        for _, equipment in pairs(carEntity_grid.equipment) do
            movedEquipment = carInWaterEntity_grid.put({ name = equipment.name, position = equipment.position })
            -- These values are 0 when empty but also when the Equipment prototype doesn't support having the value set.
            energy = equipment.energy
            if energy ~= 0 then movedEquipment.energy = energy end
            shield = equipment.shield
            if shield ~= 0 then movedEquipment.shield = shield end
        end

        -- Remove everything from the grid in the lost vehicle.
        carEntity_grid.clear()
    end

    -- Remove the real vehicle. We have moved everything out of it, so if another mod reacts to its death, there will be no items or equipment in it and the driver has been removed also.
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

    -- Record the reduced speed for next tick. Reduce by the greater reduction between 1/6 of current speed or 0.02. Speed of 0.5 is 108km/h
    -- We don't include the vehicles weight as the variation between a car and tank is huge. And a logarithmic approach would have no real affect on similar weighted vehicles.
    local speedReduction = math.max(carEnteringWater.oldSpeedAbs / 6, 0.02)
    carEnteringWater.oldSpeedAbs = math.max(carEnteringWater.oldSpeedAbs - speedReduction, 0)

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
    local weight, prototype = PrototypeAttributes.GetAttribute("entity", carName, "weight") ---@cast weight double
    local remainingEnergy = speed * speed * weight
    local energyPerHitPoint = PrototypeAttributes.GetAttribute("entity", carName, "energy_per_hit_point", prototype) ---@cast energyPerHitPoint double
    return (remainingEnergy / energyPerHitPoint) --[[@as float]]
end

--- When a car has first hit void and stopped.
---@param carEntity LuaEntity
---@param speed float
---@param position MapPosition
---@param surface LuaSurface
---@param entityName string # Prototype name of the real car prototype.
DrivenCar.HitVoid = function(carEntity, speed, position, surface, entityName)
    -- Handle the players in the vehicle based on setting.
    -- CODE NOTE: any player ejecting must be done from the car's view and not player.driving as that doesn't get the driver out quick enough.
    if global.drivenCar.settings.voidCollisionPlayerOutcome == "eject" then
        -- Explicitly kick any players out of the car before we do the void effect.
        local driver = carEntity.get_driver()
        if driver ~= nil then
            carEntity.set_driver(nil)
        end
        local passenger = carEntity.get_passenger()
        if passenger ~= nil then
            carEntity.set_passenger(nil)
        end
    elseif global.drivenCar.settings.voidCollisionPlayerOutcome == "corpse" then
        -- Players die in the process but leave a corpse behind.
        local tokenVoidEntity = surface.create_entity({ name = "careful_driver-token_void_entity", position = position, force = carEntity.force, raise_built = false, create_build_effect_smoke = false }) ---@cast tokenVoidEntity - nil # Have to make this every time, as can't leave it anywhere sensible; as it must be on the cars surface and it needs to have graphics for when other mods reference it.
        local driver = carEntity.get_driver()
        if driver ~= nil then
            carEntity.set_driver(nil)
            if not driver.is_player() then
                -- Driver is a character and not a god player.
                ---@cast driver LuaEntity
                driver.die("neutral", tokenVoidEntity)
            end
        end
        local passenger = carEntity.get_passenger()
        if passenger ~= nil then
            carEntity.set_passenger(nil)
            if not passenger.is_player() then
                -- Passenger is a character and not a god player.
                ---@cast passenger LuaEntity
                passenger.die("neutral", tokenVoidEntity)
            end
        end
        tokenVoidEntity.destroy({ raise_destroy = false })
    elseif global.drivenCar.settings.voidCollisionPlayerOutcome == "vanish" then
        -- Players fall in to the void with their vehicle.
        local driver = carEntity.get_driver()
        if driver ~= nil then
            if not driver.is_player() then
                -- Driver is a character and not a god player.
                ---@cast driver LuaEntity
                local respawnTime = PrototypeAttributes.GetAttribute("entity", driver.name, "respawn_time") ---@cast respawnTime uint
                local drivingPlayer = driver.player
                driver.destroy({ raise_destroy = true })
                drivingPlayer.ticks_to_respawn = respawnTime * 60
            end
        end
        local passenger = carEntity.get_passenger()
        if passenger ~= nil then
            if not passenger.is_player() then
                -- Passenger is a character and not a god player.
                ---@cast passenger LuaEntity
                local respawnTime = PrototypeAttributes.GetAttribute("entity", passenger.name, "respawn_time") ---@cast respawnTime uint
                local drivingPlayer = passenger.player
                passenger.destroy({ raise_destroy = true })
                drivingPlayer.ticks_to_respawn = respawnTime * 60
            end
        end
    else
        error("unsupported voidCollisionPlayerOutcome option: " .. global.drivenCar.settings.voidCollisionPlayerOutcome)
    end

    -- Create the visual of the vehicle.
    local rotationNumber = DrivenCar.OrientationToRotation(carEntity.orientation)
    local baseGraphicId = rendering.draw_animation({ animation = Common.GetCarInVoidName(entityName, rotationNumber, "body", "nonTinted"), x_scale = 1.0, y_scale = 1.0, render_layer = "object", target = position, surface = surface })
    local tintedBaseGraphicId = rendering.draw_animation({ animation = Common.GetCarInVoidName(entityName, rotationNumber, "body", "tinted"), x_scale = 1.0, y_scale = 1.0, tint = carEntity.color, render_layer = "object", target = position, surface = surface })
    local turretGraphicId = rendering.draw_animation({ animation = Common.GetCarInVoidName(entityName, rotationNumber, "turret", "nonTinted"), x_scale = 1.0, y_scale = 1.0, render_layer = "object", target = position, surface = surface })
    local tintedTurretGraphicId = rendering.draw_animation({ animation = Common.GetCarInVoidName(entityName, rotationNumber, "turret", "tinted"), x_scale = 1.0, y_scale = 1.0, tint = carEntity.color, render_layer = "object", target = position, surface = surface })

    local orientation = carEntity.orientation

    -- Remove the real vehicle.
    carEntity.destroy({ raise_destroy = true })

    -- The progression of the vehicle each tick will handle its initial movement.
    global.drivenCar.enteringVoid[#global.drivenCar.enteringVoid + 1] = { id = #global.drivenCar.enteringVoid + 1, oldPosition = position, speedAbs = math.abs(speed) --[[@as float]] , speedPositive = speed > 0, graphicIds = { baseGraphicId, tintedBaseGraphicId, turretGraphicId, tintedTurretGraphicId }, oldScale = 1, distanceToFallPosition = 2, orientation = orientation }
end

--- Called each tick for a car that is entering the void currently.
---@param carEnteringVoid CarEnteringVoid
---@return boolean continueMovingCar
DrivenCar.CarContinuingToEnterVoid = function(carEnteringVoid)
    -- Check the rendered graphics hasn't been removed.
    local aGraphicInvalid = false
    for _, graphicId in pairs(carEnteringVoid.graphicIds) do
        if not rendering.is_valid(graphicId) then
            -- A graphic has been removed.
            aGraphicInvalid = true
            break
        end
    end
    if aGraphicInvalid then
        -- A graphic has been removed so remove all of them.
        for _, graphicId in pairs(carEnteringVoid.graphicIds) do
            if not rendering.is_valid(graphicId) then rendering.destroy(graphicId) end
        end
        return false
    end

    -- Reduce the scale steadily.
    local newScale = carEnteringVoid.oldScale - 0.01
    if newScale <= 0 then -- Do 0 or less as due to rounding issues the result may not actually ever be exactly 0.
        -- Reached end of vanishing.
        for _, graphicId in pairs(carEnteringVoid.graphicIds) do
            rendering.destroy(graphicId)
        end
        return false
    end

    for _, graphicId in pairs(carEnteringVoid.graphicIds) do
        rendering.set_x_scale(graphicId, newScale)
        rendering.set_y_scale(graphicId, newScale)
    end
    carEnteringVoid.oldScale = newScale

    if carEnteringVoid.distanceToFallPosition > 0 then
        local newSpeedAbs = math.min(math.max(carEnteringVoid.speedAbs * 0.6, 0.05), carEnteringVoid.distanceToFallPosition)
        local newPosition = PositionUtils.GetPositionForOrientationDistance(carEnteringVoid.oldPosition, carEnteringVoid.speedPositive and newSpeedAbs or -newSpeedAbs, carEnteringVoid.orientation)
        for _, graphicId in pairs(carEnteringVoid.graphicIds) do
            rendering.set_target(graphicId, newPosition)
        end
        carEnteringVoid.oldPosition = newPosition
        carEnteringVoid.speedAbs = newSpeedAbs
        carEnteringVoid.distanceToFallPosition = carEnteringVoid.distanceToFallPosition - newSpeedAbs
    end

    return true
end

--- Get a rotation number from an orientation value. We assume all cars have the full 64 rotations.
---@param orientation RealOrientation
---@return uint rotationNumber # 1-64
DrivenCar.OrientationToRotation = function(orientation)
    --local rotation = MathUtils.RoundNumberToDecimalPlaces(orientation / 0.015625, 0) + 1 --[[@as uint]]
    --local x = MathUtils.RoundNumberToDecimalPlaces(orientation / 0.015625, 0) --[[@as uint]]
    -- 0.703125
    --if rotation == 0 then rotation = 64 end

    --local upperOrientation = orientation + 0.0078125 -- Half of the orientation per rotation. This is to get us up to the upper band as 0 is actually the middle of the first rotation.
    --local rotation = math.floor(upperOrientation / 0.015625) + 1 --[[@as uint]]
    --if rotation == 0 then rotation = 64 end -- To catch the upper bound of orientation.
    --if rotation == 65 then rotation = 1 end -- To catch the upper bound of orientation.

    local x = math.sin(orientation * math.pi * 2)
    local y = -math.cos(orientation * math.pi * 2)

    y = y * math.cos(math.pi / 4)

    local rotation = math.atan2(x, -y) / (math.pi * 2)

    return rotation
end

return DrivenCar
