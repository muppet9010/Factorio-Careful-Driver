local PlayerVehicle = {} ---@class PlayerVehicle_Class
local Events = require("utility.manager-libraries.events")

PlayerVehicle.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_player_driving_changed_state, "PlayerVehicle.OnPlayerDrivingChangedState_Event", PlayerVehicle.OnPlayerDrivingChangedState_Event)
end

--- Called when a player's vehicle driving state changes (players gets in/out of vehicle).
---@param event EventData.on_player_driving_changed_state
PlayerVehicle.OnPlayerDrivingChangedState_Event = function(event)
    local entity = event.entity

    -- If vehicle was removed ignore the event.
    if entity == nil then return end

    -- If vehicle is one of our special ones ignore it.
    local vehicleName = entity.name
    if string.find(vehicleName, "careful_driver-", 1, true) then return end

    -- If no driver in vehicle then either the driver just got out or a passenger just got in, both can be ignored.
    if entity.get_driver() == nil then return end

    local vehicleType = event.entity.type
    if vehicleType == "spider-vehicle" then
        -- We don't do anything with spiders.
        return
    elseif vehicleType == "car" then
        MOD.Interfaces.DrivenCar.OnPlayerGotInCar(entity, vehicleName)
    else
        -- Is a train of some type.
        MOD.Interfaces.DrivenTrain.OnPlayerGotInTrain(entity, vehicleName)
    end
end



return PlayerVehicle
