--[[
    All position concept related utils functions, including bounding boxes.

    Future Tasks:
        - In the past I haven't had to deal with complicated orientated bounding boxes in detail, at most I just passed them back in to Factorio via na API call. Factorio API doesn't accept orientation on its BoundingBox specifications when we pass them in to the game via API. This is likely why we don't handle it in the past. This needs to be clearly defined and born in mind when adding documentation and enhancements. This means there are a number of limitations that I've found when trying to do detailed BoundingBox work:
            - All of these functions that return a BoundingBox lose any passed in orientation value.
            - Many of the functions ignore orientation, either explicitly or implicitly. Some handle it in specific listed ways.
]]
--

local PositionUtils = {} ---@class Utility_PositionUtils_Class
local MathUtils = require("utility.helper-utils.math-utils")
local math_rad, math_cos, math_sin, math_floor, math_sqrt, math_abs, math_random = math.rad, math.cos, math.sin, math.floor, math.sqrt, math.abs, math.random

---@param pos1 MapPosition
---@param pos2 MapPosition
---@return boolean
PositionUtils.ArePositionsTheSame = function(pos1, pos2)
    if (pos1.x or pos1[1]) == (pos2.x or pos2[1]) and (pos1.y or pos1[2]) == (pos2.y or pos2[2]) then
        return true
    else
        return false
    end
end

---@param thing table
---@return boolean
PositionUtils.IsTableValidPosition = function(thing)
    if thing.x ~= nil and thing.y ~= nil then
        if type(thing.x) == "number" and type(thing.y) == "number" then
            return true
        else
            return false
        end
    end
    if #thing ~= 2 then
        return false
    end
    if type(thing[1]) == "number" and type(thing[2]) == "number" then
        return true
    else
        return false
    end
end

-- Returns the table as an x|y table rather than an [1]|[2] table.
---@param thing table
---@return MapPosition? position # x,y keyed table or nil if not a valid MapPosition.
PositionUtils.TableToProperPosition = function(thing)
    if thing.x ~= nil and thing.y ~= nil then
        if type(thing.x) == "number" and type(thing.y) == "number" then
            return thing
        else
            return nil
        end
    end
    if #thing ~= 2 then
        return nil
    end
    if type(thing[1]) == "number" and type(thing[2]) == "number" then
        return { x = thing[1] --[[@as double]] , y = thing[2] --[[@as double]] }
    else
        return nil
    end
end

---@param thing table
---@return boolean
PositionUtils.IsTableValidBoundingBox = function(thing)
    if thing.left_top ~= nil and thing.right_bottom ~= nil then
        if PositionUtils.IsTableValidPosition(thing.left_top) and PositionUtils.IsTableValidPosition(thing.right_bottom) then
            return true
        else
            return false
        end
    end
    if #thing ~= 2 then
        return false
    end
    if PositionUtils.IsTableValidPosition(thing[1]) and PositionUtils.IsTableValidPosition(thing[2]) then
        return true
    else
        return false
    end
end

-- Returns a clean bounding box object or nil if invalid.
---@param thing table
---@return BoundingBox?
PositionUtils.TableToProperBoundingBox = function(thing)
    if not PositionUtils.IsTableValidBoundingBox(thing) then
        return nil
    elseif thing.left_top ~= nil and thing.right_bottom ~= nil then
        return { left_top = PositionUtils.TableToProperPosition(thing.left_top), right_bottom = PositionUtils.TableToProperPosition(thing.right_bottom) }
    else
        return { left_top = PositionUtils.TableToProperPosition(thing[1]), right_bottom = PositionUtils.TableToProperPosition(thing[2]) }
    end
end

--- Return the positioned bounding box (collision box) of a bounding box applied to a position. Or nil if invalid data.
---@param centerPos MapPosition
---@param boundingBox BoundingBox
---@param orientation RealOrientation # Only supports 0, 0.25, 0.5, 0.75 and 1.
---@return BoundingBox?
PositionUtils.ApplyBoundingBoxToPosition = function(centerPos, boundingBox, orientation)
    local checked_centerPos = PositionUtils.TableToProperPosition(centerPos)
    if checked_centerPos == nil then
        return nil
    end
    local checked_boundingBox = PositionUtils.TableToProperBoundingBox(boundingBox)
    if checked_boundingBox == nil then
        return nil
    end
    if orientation == nil or orientation == 0 or orientation == 1 then
        return {
            left_top = {
                x = checked_centerPos.x + checked_boundingBox.left_top.x,
                y = checked_centerPos.y + checked_boundingBox.left_top.y
            },
            right_bottom = {
                x = checked_centerPos.x + checked_boundingBox.right_bottom.x,
                y = checked_centerPos.y + checked_boundingBox.right_bottom.y
            }
        }
    elseif orientation == 0.25 or orientation == 0.5 or orientation == 0.75 then
        local rotatedPoint1 = PositionUtils.RotatePositionAround0(orientation, checked_boundingBox.left_top)
        local rotatedPoint2 = PositionUtils.RotatePositionAround0(orientation, checked_boundingBox.right_bottom)
        local rotatedBoundingBox = PositionUtils.CalculateBoundingBoxFrom2Points(rotatedPoint1, rotatedPoint2)
        return {
            left_top = {
                x = checked_centerPos.x + rotatedBoundingBox.left_top.x,
                y = checked_centerPos.y + rotatedBoundingBox.left_top.y
            },
            right_bottom = {
                x = checked_centerPos.x + rotatedBoundingBox.right_bottom.x,
                y = checked_centerPos.y + rotatedBoundingBox.right_bottom.y
            }
        }
    end
end

--- Round a number to set a set number of decimal places. This rounds rather than always floor/ceiling.
---@param pos MapPosition
---@param numberOfDecimalPlaces uint
---@return MapPosition
PositionUtils.RoundPosition = function(pos, numberOfDecimalPlaces)
    return { x = MathUtils.RoundNumberToDecimalPlaces(pos.x, numberOfDecimalPlaces), y = MathUtils.RoundNumberToDecimalPlaces(pos.y, numberOfDecimalPlaces) }
end

--- Gets the Chunk Position for a Map Position.
---
--- If called frequently should be done inline to avoid excessive function calls.
---@param pos MapPosition
---@return ChunkPosition
PositionUtils.GetChunkPositionForTilePosition = function(pos)
    return { x = math_floor(pos.x / 32), y = math_floor(pos.y / 32) }
end

--- Gets the top left Map Position for a Chunk Position.
---
--- If called frequently should be done inline to avoid excessive function calls.
---@param chunkPos ChunkPosition
---@return MapPosition
PositionUtils.GetLeftTopTilePositionForChunkPosition = function(chunkPos)
    return { x = chunkPos.x * 32, y = chunkPos.y * 32 }
end

--- Create a new position at a rotated offset around position of {0,0}.
---@param orientation RealOrientation
---@param position MapPosition
---@return MapPosition
PositionUtils.RotatePositionAround0 = function(orientation, position)
    -- Handle simple cardinal direction rotations.
    if orientation == 0 then
        return position
    elseif orientation == 0.25 then
        return {
            x = -position.y,
            y = position.x
        }
    elseif orientation == 0.5 then
        return {
            x = -position.x,
            y = -position.y
        }
    elseif orientation == 0.75 then
        return {
            x = position.y,
            y = -position.x
        }
    end

    -- Handle any non cardinal direction orientation.
    local rad = math_rad(orientation * 360)
    local cosValue = math_cos(rad)
    local sinValue = math_sin(rad)
    local rotatedX = (position.x * cosValue) - (position.y * sinValue)
    local rotatedY = (position.x * sinValue) + (position.y * cosValue)
    return { x = rotatedX, y = rotatedY }
end

--- Create a new position at a rotated offset to an existing position. Rotates an offset around a position. Combines PositionUtils.RotatePositionAround0() and PositionUtils.ApplyOffsetToPosition() to save UPS.
---@param orientation RealOrientation
---@param offset MapPosition # the position to be rotated by the orientation.
---@param position MapPosition # the position the rotated offset is applied to.
---@return MapPosition
PositionUtils.RotateOffsetAroundPosition = function(orientation, offset, position)
    -- Handle simple cardinal direction rotations.
    if orientation == 0 then
        return {
            x = position.x + offset.x,
            y = position.y + offset.y
        }
    elseif orientation == 0.25 then
        return {
            x = position.x - offset.y,
            y = position.y + offset.x
        }
    elseif orientation == 0.5 then
        return {
            x = position.x - offset.x,
            y = position.y - offset.y
        }
    elseif orientation == 0.75 then
        return {
            x = position.x + offset.y,
            y = position.y - offset.x
        }
    end

    -- Handle any non cardinal direction orientation.
    local rad = math_rad(orientation * 360)
    local cosValue = math_cos(rad)
    local sinValue = math_sin(rad)
    local rotatedX = (offset.x * cosValue) - (offset.y * sinValue)
    local rotatedY = (offset.x * sinValue) + (offset.y * cosValue)
    return { x = position.x + rotatedX, y = position.y + rotatedY }
end

---@param point1 MapPosition
---@param point2 MapPosition
---@return BoundingBox
PositionUtils.CalculateBoundingBoxFrom2Points = function(point1, point2)
    local minX, maxX, minY, maxY
    if minX == nil or point1.x < minX then
        minX = point1.x
    end
    if maxX == nil or point1.x > maxX then
        maxX = point1.x
    end
    if minY == nil or point1.y < minY then
        minY = point1.y
    end
    if maxY == nil or point1.y > maxY then
        maxY = point1.y
    end
    if minX == nil or point2.x < minX then
        minX = point2.x
    end
    if maxX == nil or point2.x > maxX then
        maxX = point2.x
    end
    if minY == nil or point2.y < minY then
        minY = point2.y
    end
    if maxY == nil or point2.y > maxY then
        maxY = point2.y
    end
    return { left_top = { x = minX, y = minY }, right_bottom = { x = maxX, y = maxY } }
end

---@param listOfBoundingBoxes BoundingBox[]
---@return BoundingBox
PositionUtils.CalculateBoundingBoxToIncludeAllBoundingBoxes = function(listOfBoundingBoxes)
    local minX, maxX, minY, maxY
    for _, boundingBox in pairs(listOfBoundingBoxes) do
        for _, point in pairs({ boundingBox.left_top, boundingBox.right_bottom }) do
            if minX == nil or point.x < minX then
                minX = point.x
            end
            if maxX == nil or point.x > maxX then
                maxX = point.x
            end
            if minY == nil or point.y < minY then
                minY = point.y
            end
            if maxY == nil or point.y > maxY then
                maxY = point.y
            end
        end
    end
    return { left_top = { x = minX, y = minY }, right_bottom = { x = maxX, y = maxY } }
end

-- Create a new position at an offset to an existing position. If you are rotating the offset first consider using PositionUtils.RotateOffsetAroundPosition() as lower UPS than the 2 separate function calls.
---@param position MapPosition
---@param offset MapPosition
---@return MapPosition newPosition
PositionUtils.ApplyOffsetToPosition = function(position, offset)
    return {
        x = position.x + offset.x,
        y = position.y + offset.y
    }
end

-- Create a new boundingBox at an offset to an existing boundingBox.
---@param boundingBox BoundingBox
---@param offset MapPosition
---@return BoundingBox newBoundingBox
PositionUtils.ApplyOffsetToBoundingBox = function(boundingBox, offset)
    ---@type BoundingBox
    return {
        left_top = {
            x = boundingBox.left_top.x + offset.x,
            y = boundingBox.left_top.y + offset.y
        },
        right_bottom = {
            x = boundingBox.right_bottom.x + offset.x,
            y = boundingBox.right_bottom.y + offset.y
        }
    }
end

--- Return a copy of the BoundingBox with the growth values added to both sides.
---@param boundingBox BoundingBox
---@param growthX double
---@param growthY double
---@return BoundingBox
PositionUtils.GrowBoundingBox = function(boundingBox, growthX, growthY)
    return {
        left_top = {
            x = boundingBox.left_top.x - growthX,
            y = boundingBox.left_top.y - growthY
        },
        right_bottom = {
            x = boundingBox.right_bottom.x + growthX,
            y = boundingBox.right_bottom.y + growthY
        }
    }
end

--- Checks if a bounding box is populated with valid data. This means not nil or a 0 sized area in one or more dimensions.
---@param boundingBox BoundingBox
---@return boolean
PositionUtils.IsBoundingBoxPopulated = function(boundingBox)
    if boundingBox == nil then
        return false
    elseif boundingBox.right_bottom.x - boundingBox.left_top.x ~= 0 and boundingBox.right_bottom.y - boundingBox.left_top.y ~= 0 then
        return true
    else
        return false
    end
end

--- Generate a positioned bounding box (collision box) for a position and an equal distance on each side.
---@param position MapPosition
---@param range double
---@return BoundingBox
PositionUtils.CalculateBoundingBoxFromPositionAndRange = function(position, range)
    return {
        left_top = {
            x = position.x - range,
            y = position.y - range
        },
        right_bottom = {
            x = position.x + range,
            y = position.y + range
        }
    }
end

--- Calculate a list of tile positions that are within a bounding box.
---
--- Ignores the `orientation` field of the positionedBoundingBox, and assumes its always 0.
---@param positionedBoundingBox BoundingBox
---@return MapPosition[]
PositionUtils.CalculateTilesUnderPositionedBoundingBox = function(positionedBoundingBox)
    local tiles = {} ---@type MapPosition[]
    for x = positionedBoundingBox.left_top.x, positionedBoundingBox.right_bottom.x do
        for y = positionedBoundingBox.left_top.y, positionedBoundingBox.right_bottom.y do
            tiles[#tiles + 1] = { x = math_floor(x), y = math_floor(y) }
        end
    end
    return tiles
end

-- Gets the distance between the 2 positions.
---@param pos1 MapPosition|ChunkPosition
---@param pos2 MapPosition|ChunkPosition
---@return double # is inherently a positive number.
PositionUtils.GetDistance = function(pos1, pos2)
    local distanceX, distanceY = (pos1.x - pos2.x), (pos1.y - pos2.y)
    return ((distanceX * distanceX) + (distanceY * distanceY)) ^ 0.5
end

---@alias Axis "'x'"|"'y'"

-- Gets the distance between a single axis of 2 positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@param axis Axis
---@return double # is inherently a positive number.
PositionUtils.GetDistanceSingleAxis = function(pos1, pos2, axis)
    return math_abs(pos1[axis] - pos2[axis])
end

--- Gets the nearest thing in a list based on the distance to its position, defined by its positionFieldName. Selects the first one found if multiple are of equal distance.
---
--- It's significantly quicker (x5-10) to use LuaSurface.get_closest() if you can (requires entities to be valid), over feeding this with existing objects with positional data.
---@param startPosition MapPosition|ChunkPosition
---@param list table<any,table>
---@param positionFieldName string # The field name in each entry in the `list` table that has the position.
---@param acceptFirstRange? double # A value that will mean the first thing found within this range is returned. For use when you'll accept anything near, otherwise want the true nearest thing beyond that.
---@return table nearestThing
---@return any nearestThingsKeyInList
PositionUtils.GetNearest = function(startPosition, list, positionFieldName, acceptFirstRange)
    ---@type any, double, double, double, MapPosition
    local nearestThingsKey, distance, distanceX, distanceY, thing_position
    local nearestDistance = MathUtils.doubleMax
    local start_x, start_y = startPosition.x, startPosition.y
    acceptFirstRange = acceptFirstRange or MathUtils.doubleMax -- Use a massive number as default so that FOR loop logic can be simpler.
    for key, thing in pairs(list) do
        thing_position = thing[positionFieldName] --[[@as MapPosition]]
        distanceX, distanceY = (start_x - thing_position.x), (start_y - thing_position.y)
        distance = ((distanceX * distanceX) + (distanceY * distanceY)) ^ 0.5
        if distance < nearestDistance then
            nearestThingsKey = key
            nearestDistance = distance
            if distance < acceptFirstRange then
                break
            end
        end
    end
    return list[nearestThingsKey], nearestThingsKey
end

-- Returns the offset for the first position in relation to the second position.
---@param newPosition MapPosition
---@param basePosition MapPosition
---@return MapPosition
PositionUtils.GetOffsetForPositionFromPosition = function(newPosition, basePosition)
    return { x = newPosition.x - basePosition.x, y = newPosition.y - basePosition.y }
end

--- Check if a position is within a BoundingBox. Ignores any orientation on the BoundingBox.
---@param position MapPosition
---@param boundingBox BoundingBox
---@param safeTiling? boolean # If enabled the BoundingBox can be tiled without risk of an entity on the border being in 2 result sets, i.e. for use on each chunk.
---@return boolean
PositionUtils.IsPositionInBoundingBox = function(position, boundingBox, safeTiling)
    if safeTiling == nil or not safeTiling then
        if position.x >= boundingBox.left_top.x and position.x <= boundingBox.right_bottom.x and position.y >= boundingBox.left_top.y and position.y <= boundingBox.right_bottom.y then
            return true
        else
            return false
        end
    else
        if position.x > boundingBox.left_top.x and position.x <= boundingBox.right_bottom.x and position.y > boundingBox.left_top.y and position.y <= boundingBox.right_bottom.y then
            return true
        else
            return false
        end
    end
end

--- Get a random location within a radius (circle) of a target.
---@param centerPos MapPosition
---@param maxRadius double
---@param minRadius? double # Defaults to 0.
---@return MapPosition
PositionUtils.RandomLocationInRadius = function(centerPos, maxRadius, minRadius)
    local angle = math_random(0, 360)
    minRadius = minRadius or 0
    local radiusMultiplier = maxRadius - minRadius
    local distance = minRadius + (math_random() * radiusMultiplier)
    return PositionUtils.GetPositionForAngledDistance(centerPos, distance, angle)
end

--- Gets a map position for an angled distance from a position.
---@param startingPos MapPosition
---@param distance double
---@param angle double
---@return MapPosition
PositionUtils.GetPositionForAngledDistance = function(startingPos, distance, angle)
    if angle < 0 then
        angle = 360 + angle
    end
    local angleRad = math_rad(angle)
    local newPos = {
        x = (distance * math_sin(angleRad)) + startingPos.x,
        y = (distance * -math_cos(angleRad)) + startingPos.y
    }
    return newPos
end

---@param startingPos MapPosition
---@param distance double
---@param orientation RealOrientation
---@return MapPosition
PositionUtils.GetPositionForOrientationDistance = function(startingPos, distance, orientation)
    local angle = orientation * 360 ---@type double
    if angle < 0 then
        angle = 360 + angle
    end
    local angleRad = math_rad(angle)
    local newPos = {
        x = (distance * math_sin(angleRad)) + startingPos.x,
        y = (distance * -math_cos(angleRad)) + startingPos.y
    }
    return newPos
end

--- Gets the position for a distance along a line from a starting position towards a target position.
---@param startingPos MapPosition
---@param targetPos MapPosition
---@param distance double
---@return MapPosition
PositionUtils.GetPositionForDistanceBetween2Points = function(startingPos, targetPos, distance)
    local angleRad = -math.atan2(startingPos.y - targetPos.y, targetPos.x - startingPos.x) + 1.5707963267949 -- Static value is to re-align it from east to north as 0 value.
    -- equivalent to: math.rad(math.deg(-math.atan2(startingPos.y - targetPos.y, targetPos.x - startingPos.x)) + 90)

    local newPos = {
        x = (distance * math_sin(angleRad)) + startingPos.x,
        y = (distance * -math_cos(angleRad)) + startingPos.y
    }
    return newPos
end

--- Find where a line cross a circle at a set radius from a 0 position.
---@param radius double
---@param slope double # the x value per 1 Y. so 1 is a 45 degree SW to NE line. 2 is a steeper line. -1 would be a 45 degree line SE to NW line. -- I THINK...
---@param yIntercept double # Where on the Y axis the line crosses.
---@return MapPosition? firstCrossingPosition # Position if the line crossed or touched the edge of the circle. Nil if the line never crosses the circle.
---@return MapPosition? secondCrossingPosition # Only a position if the line crossed the circle in 2 places. Nil if the line just touched the edge of the circle or never crossed it.
PositionUtils.FindWhereLineCrossesCircle = function(radius, slope, yIntercept)
    local centerPos = { x = 0, y = 0 }
    local A = 1 + slope * slope
    local B = -2 * centerPos.x + 2 * slope * yIntercept - 2 * centerPos.y * slope
    local C = centerPos.x * centerPos.x + yIntercept * yIntercept + centerPos.y * centerPos.y - 2 * centerPos.y * yIntercept - radius * radius
    local delta = B * B - 4 * A * C

    if delta < 0 then
        return nil, nil
    else
        local x1 = (-B + math_sqrt(delta)) / (2 * A)
        local x2 = (-B - math_sqrt(delta)) / (2 * A)
        local y1 = slope * x1 + yIntercept
        local y2 = slope * x2 + yIntercept

        local pos1 = { x = x1, y = y1 }
        local pos2 = { x = x2, y = y2 }
        if pos1 == pos2 then
            return pos1, nil
        else
            return pos1, pos2
        end
    end
end

--- See if 2 polygons collide with each other.
---
--- Code from: https://stackoverflow.com/a/10965077
---@param polygonAPoints MapPosition[]
---@param polygonBPoints MapPosition[]
---@return boolean boundingBoxesCollide
PositionUtils.Do2RotatedBoundingBoxesCollide = function(polygonAPoints, polygonBPoints)
    for _, polygon in pairs({ polygonAPoints, polygonBPoints }) do
        for i1 = 1, #polygon do
            local i2 = (i1 % #polygon) + 1
            local p1 = polygon[i1]
            local p2 = polygon[i2]

            local normal = { x = p2.y - p1.y, y = p1.x - p2.x } --[[@as MapPosition]]

            local minA, maxA
            for _, p in pairs(polygonAPoints) do
                local projected = normal.x * p.x + normal.y * p.y
                if (minA == nil or projected < minA) then
                    minA = projected
                end
                if (maxA == nil or projected > maxA) then
                    maxA = projected
                end
            end

            local minB, maxB
            for _, p in pairs(polygonBPoints) do
                local projected = normal.x * p.x + normal.y * p.y
                if (minB == nil or projected < minB) then
                    minB = projected
                end
                if (maxB == nil or projected > maxB) then
                    maxB = projected
                end
            end

            if (maxA < minB or maxB < minA) then
                return false
            end
        end
    end
    return true
end

--- Get an array of MapPosition points from a collision box at a given position, handles all orientations.
---@param collisionBox BoundingBox
---@param centerPosition MapPosition
---@param orientation RealOrientation
---@return MapPosition[]
PositionUtils.MakePolygonMapPointsFromOrientatedCollisionBox = function(collisionBox, orientation, centerPosition)
    local polygon = {} ---@type MapPosition[]

    polygon[1] = PositionUtils.RotateOffsetAroundPosition(orientation, collisionBox.left_top, centerPosition)
    polygon[2] = PositionUtils.RotateOffsetAroundPosition(orientation, { x = collisionBox.right_bottom.x, y = collisionBox.left_top.y }, centerPosition)
    polygon[3] = PositionUtils.RotateOffsetAroundPosition(orientation, collisionBox.right_bottom, centerPosition)
    polygon[4] = PositionUtils.RotateOffsetAroundPosition(orientation, { x = collisionBox.left_top.x, y = collisionBox.right_bottom.y }, centerPosition)

    return polygon
end

--- Get an array of MapPosition points from a bounding box (positioned collision box) rotated around a given position, handles all orientations.
---
--- If the position is outside of the bounding box then it will appear to rotate the bounding box as an offset from this. It is technically the same as if the position is within the bounding box, but the effects can feel quite different. Best seen with some polygon renders of the results.
---@param boundingBox BoundingBox
---@param centerPosition MapPosition
---@param orientation RealOrientation
---@return MapPosition[]
PositionUtils.MakePolygonMapPointsFromOrientatedBoundingBox = function(boundingBox, orientation, centerPosition)
    local polygon = {} ---@type MapPosition[]

    polygon[1] = PositionUtils.RotateOffsetAroundPosition(orientation, { x = boundingBox.left_top.x - centerPosition.x, y = boundingBox.left_top.y - centerPosition.y }, centerPosition)
    polygon[2] = PositionUtils.RotateOffsetAroundPosition(orientation, { x = boundingBox.right_bottom.x - centerPosition.x, y = boundingBox.left_top.y - centerPosition.y }, centerPosition)
    polygon[3] = PositionUtils.RotateOffsetAroundPosition(orientation, { x = boundingBox.right_bottom.x - centerPosition.x, y = boundingBox.right_bottom.y - centerPosition.y }, centerPosition)
    polygon[4] = PositionUtils.RotateOffsetAroundPosition(orientation, { x = boundingBox.left_top.x - centerPosition.x, y = boundingBox.right_bottom.y - centerPosition.y }, centerPosition)

    return polygon

    -- Test code to demonstrate how it behaves. Change `centerPos` to be inside or outside of the `boundingBox`.
    --[[
        ---@type BoundingBox
        local boundingBox = { left_top = { x = -3, y = -2 }, right_bottom = { x = 2, y = 1 } }
        local centerPos = { x = 5, y = 5 }

        local surface = game.surfaces[1] --[ [@as LuaSurface] ]
        rendering.draw_circle({ surface = surface, color = { 0.0, 0.0, 0.0, 1.0 }, radius = 0.1, filled = true, target = centerPos })


        local colorCount = 1
        local colors = { { 1.0, 0.0, 0.0, 1.0 }, { 0.0, 1.0, 0.0, 1.0 }, { 0.0, 0.0, 1.0, 1.0 } }
        local rotationCount = 24
        for rotation = 0, rotationCount - 1 do
            local orientation = rotation / rotationCount --[ [@as RealOrientation] ]
            if rotation == 0 then orientation = 0.0 end

            local vertices = {} ---@type table[]
            for i, pos in pairs(PositionUtils.MakePolygonMapPointsFromOrientatedBoundingBox(boundingBox, orientation, centerPos)) do
                vertices[i] = { target = pos }
            end
            vertices[5] = vertices[1]

            local color = colors[colorCount]
            rendering.draw_polygon({ surface = surface, color = color, vertices = vertices, draw_on_ground = true })

            colorCount = colorCount + 1
            if colorCount > 3 then colorCount = 1 end
        end
    ]]
end

--- Check if a position is within a circles area.
---@param circleCenter MapPosition
---@param radius double
---@param position MapPosition
---@return boolean
PositionUtils.IsPositionWithinCircled = function(circleCenter, radius, position)
    local deltaX = math_abs(position.x - circleCenter.x)
    local deltaY = math_abs(position.y - circleCenter.y)
    if deltaX + deltaY <= radius then
        return true
    elseif deltaX > radius then
        return false
    elseif deltaY > radius then
        return false
    elseif deltaX ^ 2 + deltaY ^ 2 <= radius ^ 2 then
        return true
    else
        return false
    end
end

--- The valid key names in a table that can be converted in to a MapPosition with PositionUtils.TableToProperPosition(). Useful when you want to just check that no unexpected keys are present, i.e. command argument checking.
---@type table<string|uint, string|uint>
PositionUtils.MapPositionConvertibleTableValidKeysList = {
    [1] = 1,
    [2] = 2,
    x = "x",
    y = "y"
}

return PositionUtils
