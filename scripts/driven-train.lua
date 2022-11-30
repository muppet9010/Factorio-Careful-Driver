--[[
    This tracks a train from the point a player gets in to the train until the player gets out of the train and the train is set to non manual control.
]]

local DrivenTrain = {} ---@class DrivenTrain_Class
local Events = require("utility.manager-libraries.events")
local EventScheduler = require("utility.manager-libraries.event-scheduler")

--- The details about a moving player car we need to track.
---@class DrivenTrain
---@field trainId uint
---@field oldSpeed double

DrivenTrain.OnLoad = function()
    EventScheduler.RegisterScheduler()
    EventScheduler.RegisterScheduledEventType("DrivenTrain.CheckDrivenTrain_EachTick", DrivenTrain.CheckDrivenTrain_EachTick)

    MOD.Interfaces.DrivenTrain = {
        OnPlayerGotInTrain = DrivenTrain.OnPlayerGotInTrain
    }
end

DrivenTrain.CreateGlobals = function()
    global.drivenTrain = global.drivenTrain or {} ---@class DrivenTrain_Global
    global.drivenTrain.drivenTrains = global.drivenTrain.drivenTrains or {} ---@type table<uint, DrivenTrain> # Keyed by the train unit_number.
end


DrivenTrain.OnStartup = function()
    if not EventScheduler.IsEventScheduledEachTick("DrivenTrain.CheckDrivenTrain_EachTick", "") then
        EventScheduler.ScheduleEventEachTick("DrivenTrain.CheckDrivenTrain_EachTick", "", nil)
    end
end

--- Called when a player has got in to a train carriage.
---@param trainCarriageEntity LuaEntity
---@param trainCarriageName string
DrivenTrain.OnPlayerGotInTrain = function(trainCarriageEntity, trainCarriageName)

end

--- Called every tick to process any trains that are being manually driven.
---@param event UtilityScheduledEvent_CallbackObject
DrivenTrain.CheckDrivenTrain_EachTick = function(event)

end

return DrivenTrain
