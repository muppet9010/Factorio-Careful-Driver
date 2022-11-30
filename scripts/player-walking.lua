--[[
    This tracks a players movement when they are not in a vehicle.
]]

--[[
CODE NOTES:

]]

local WalkingPlayer = {} ---@class WalkingPlayer_Class
local Events = require("utility.manager-libraries.events")
local EventScheduler = require("utility.manager-libraries.event-scheduler")

---@class PlayerCurrentlyWalking
---@field index uint
---@field player LuaPlayer
---@field character LuaEntity

WalkingPlayer.OnLoad = function()
    EventScheduler.RegisterScheduler()
    EventScheduler.RegisterScheduledEventType("WalkingPlayer.CheckWalkingPlayer_EachTick", WalkingPlayer.CheckWalkingPlayer_EachTick)

    Events.RegisterHandlerEvent(defines.events.on_player_respawned, "WalkingPlayer.On_PlayerRespawned_PlayerGenerated", WalkingPlayer.PlayerGenerated)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "WalkingPlayer.On_PlayerCreated_PlayerGenerated", WalkingPlayer.PlayerGenerated)
end

WalkingPlayer.CreateGlobals = function()
    global.walkingPlayer = global.walkingPlayer or {} ---@class WalkingPlayer_Global
    global.walkingPlayer.walkingPlayers = global.walkingPlayer.walkingPlayers or {} ---@type table<uint, PlayerCurrentlyWalking> # Keyed by the player's index.
end

WalkingPlayer.OnStartup = function()
    if not EventScheduler.IsEventScheduledEachTick("WalkingPlayer.CheckWalkingPlayer_EachTick", "") then
        EventScheduler.ScheduleEventEachTick("WalkingPlayer.CheckWalkingPlayer_EachTick", "", nil)
    end
end

-- TODO: Track when players get in/out of vehicles, plus die, spawn, etc. And add/remove them from the check each tick.

--- Called when the player is generated via some events. We assume they are out of a vehicle at this point and check to confirm this.
---@param event EventData.on_player_respawned|EventData.on_player_created
WalkingPlayer.PlayerGenerated = function(event)
    WalkingPlayer.CheckIfPlayerIsNowWalking(event.player_index)
end

--- Call when a player may be walking based on an event.
---@param playerIndex uint
WalkingPlayer.CheckIfPlayerIsNowWalking = function(playerIndex)
    local player = game.get_player(playerIndex) ---@cast player -nil
    if not player.driving and player.character then
        ---@type PlayerCurrentlyWalking
        local walkingPlayer = {
            index = playerIndex,
            player = player,
            character = player.character
        }
        global.walkingPlayer.walkingPlayers[playerIndex] = walkingPlayer
    end
end

--- Called every tick to process any players that are walking around.
---@param event UtilityScheduledEvent_CallbackObject
WalkingPlayer.CheckWalkingPlayer_EachTick = function(event)
    for _, walkingPlayer in pairs(global.walkingPlayer.walkingPlayers) do
        -- TODO
    end
end

return WalkingPlayer
