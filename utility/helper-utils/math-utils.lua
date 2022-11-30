--[[
    All maths related utils functions.
]]

-- cSpell:words Nixie

local MathUtils = {} ---@class Utility_MathUtils_Class
local math_min, math_max, math_floor, math_random, math_sin, math_cos, math_atan2, math_pi = math.min, math.max, math.floor, math.random, math.sin, math.cos, math.atan2, math.pi
local math_pi2 = math_pi * 2

--- Round the value to the given number of decimal places.
---@param value double
---@param numberOfDecimalPlaces uint
---@return double
MathUtils.RoundNumberToDecimalPlaces = function(value, numberOfDecimalPlaces)
    local result
    if numberOfDecimalPlaces ~= nil and numberOfDecimalPlaces > 0 then
        local multiplier = 10 ^ numberOfDecimalPlaces
        result = math_floor((value * multiplier) + 0.5) / multiplier
    else
        result = math_floor(value + 0.5)
    end
    if result ~= result then
        -- Result is NaN so set it to 0.
        result = 0
    end
    return result
end

--- Checks if the provided number is a NaN value.
---
--- Should be done locally if called frequently.
---@param value double
---@return boolean valueIsANan
MathUtils.IsNumberNan = function(value)
    if value ~= value then
        return true
    else
        return false
    end
end

--- This steps through the ints with min and max being separate steps.
---@param value int
---@param min int
---@param max int
---@return int
MathUtils.LoopIntValueWithinRange = function(value, min, max)
    if value > max then
        return min - (max - value) - 1
    elseif value < min then
        return max + (value - min) + 1
    else
        return value
    end
end

--- This treats the min and max values as equal when looping: max - 0.1, max/min, min + 0.1. Depending on starting input value you get either the min or max value at the border.
---@param value double
---@param min double
---@param max double
---@return double
MathUtils.LoopFloatValueWithinRange = function(value, min, max)
    if value > max then
        return min + (value - max)
    elseif value < min then
        return max - (value - min)
    else
        return value
    end
end

--- This treats the min and max values as equal when looping: max - 0.1, max/min, min + 0.1. But maxExclusive will give the minInclusive value. So maxExclusive can never be returned.
---
--- Should be done locally if called frequently.
---@param value double
---@param minInclusive double
---@param maxExclusive double
---@return double
MathUtils.LoopFloatValueWithinRangeMaxExclusive = function(value, minInclusive, maxExclusive)
    if value >= maxExclusive then
        return minInclusive + (value - maxExclusive)
    elseif value < minInclusive then
        return maxExclusive - (value - minInclusive)
    else
        return value
    end
end

--- Return the passed in number clamped to within the max and min limits inclusively.
---@param value double
---@param min double
---@param max double
---@return double
---@return boolean valueWasOutsideRange
MathUtils.ClampNumber = function(value, min, max)
    local newValue = math_min(math_max(value, min), max)
    if newValue ~= value then
        return newValue, true
    else
        return newValue, false
    end
end

--- Returns the passed in number clamped to within the range of an int, with optional additional min and max's applied.
--- Use Int over Integer as this is the Factorio data type and Lua 5.2 doesn't have real `integer` types. Although Sumneko does have some numeric values of the Integer type to aid usage limitations detection.
---@param value int
---@param min? int
---@param max? int
---@return int
---@return boolean valueWasOutsideRange
MathUtils.ClampToInt = function(value, min, max)
    min = min or MathUtils.intMin
    max = max or MathUtils.intMax
    local newValue = math_min(math_max(value, min), max) --[[@as int]]
    if newValue ~= value then
        return newValue, true
    else
        return newValue, false
    end
end

--- Returns the passed in number clamped to within the range of an int8, with optional additional min and max's applied.
--- Use Int over Integer as this is the Factorio data type and Lua 5.2 doesn't have real `integer` types. Although Sumneko does have some numeric values of the Integer type to aid usage limitations detection.
---@param value int
---@param min? int
---@param max? int
---@return int8
---@return boolean valueWasOutsideRange
MathUtils.ClampToInt8 = function(value, min, max)
    min = min or MathUtils.int8Min
    max = max or MathUtils.int8Max
    local newValue = math_min(math_max(value, min), max) --[[@as int8]]
    if newValue ~= value then
        return newValue, true
    else
        return newValue, false
    end
end

--- Returns the passed in number clamped to within the range of an uint (min 0), with optional additional min and max's applied.
---@param value int
---@param min? uint
---@param max? uint
---@return uint clampedValue
---@return boolean valueWasOutsideRange
MathUtils.ClampToUInt = function(value, min, max)
    min = min or 0
    max = max or MathUtils.uintMax
    local newValue = math_min(math_max(value, min), max) --[[@as uint]]
    if newValue ~= value then
        return newValue, true
    else
        return newValue, false
    end
end

--- Returns the passed in number clamped to within the range of an uint 64 (min 0), with optional additional min and max's applied.
---@param value int
---@param min? uint64
---@param max? uint64
---@return uint64 clampedValue
---@return boolean valueWasOutsideRange
MathUtils.ClampToUInt64 = function(value, min, max)
    min = min or 0
    max = max or MathUtils.uint64Max
    local newValue = math_min(math_max(value, min), max) --[[@as uint64]]
    if newValue ~= value then
        return newValue, true
    else
        return newValue, false
    end
end

--- Returns the passed in number clamped to within the range of an uint 16 (min 0), with optional additional min and max's applied.
---@param value int
---@param min? uint16
---@param max? uint16
---@return uint16 clampedValue
---@return boolean valueWasOutsideRange
MathUtils.ClampToUInt16 = function(value, min, max)
    min = min or 0
    max = max or MathUtils.uint16Max
    local newValue = math_min(math_max(value, min), max) --[[@as uint16]]
    if newValue ~= value then
        return newValue, true
    else
        return newValue, false
    end
end

--- Returns the passed in number clamped to within the range of an uint 8 (min 0), with optional additional min and max's applied.
---@param value int
---@param min? uint8
---@param max? uint8
---@return uint8 clampedValue
---@return boolean valueWasOutsideRange
MathUtils.ClampToUInt8 = function(value, min, max)
    min = min or 0
    max = max or MathUtils.uint8Max
    local newValue = math_min(math_max(value, min), max) --[[@as uint8]]
    if newValue ~= value then
        return newValue, true
    else
        return newValue, false
    end
end

--- Returns the passed in number clamped to within the range of a float, with optional additional min and max's applied.
---@param value double
---@param min? float
---@param max? float
---@return float clampedValue
---@return boolean valueWasOutsideRange
MathUtils.ClampToFloat = function(value, min, max)
    min = min or MathUtils.floatMin
    max = max or MathUtils.floatMax
    local newValue = math_min(math_max(value, min), max) --[[@as float]]
    if newValue ~= value then
        return newValue, true
    else
        return newValue, false
    end
end

--- This doesn't guarantee correct on some of the edge cases, but is as close as possible assuming that 1/256 is the variance for the same number (Bilka, Dev on Discord)
---@param value1 double
---@param logic "="|"!="|"<"|"<="|">"|">="
---@param value2 double
---@return boolean
MathUtils.FuzzyCompareDoubles = function(value1, logic, value2)
    local valueDif = value1 - value2
    local variance = 1 / 256
    if logic == "=" then
        if valueDif < variance and valueDif > -variance then
            return true
        else
            return false
        end
    elseif logic == "!=" then
        if valueDif < variance and valueDif > -variance then
            return false
        else
            return true
        end
    elseif logic == ">" then
        if valueDif > variance then
            return true
        else
            return false
        end
    elseif logic == ">=" then
        if valueDif > -variance then
            return true
        else
            return false
        end
    elseif logic == "<" then
        if valueDif < -variance then
            return true
        else
            return false
        end
    elseif logic == "<=" then
        if valueDif < variance then
            return true
        else
            return false
        end
    else
        error("unsupported logic operator: " .. tostring(logic))
    end
end

--- Gets a random double (decimal) number between the provided upper and lower double numbers.
---@param lower double
---@param upper double
---@return double
MathUtils.GetRandomDoubleInRange = function(lower, upper)
    return lower + math_random() * (upper - lower)
end

MathUtils.intMin = -2147483648 ---@type int # 32bit -2,147,483,648
MathUtils.intMax = 2147483647 ---@type int # 32bit 2,147,483,647
MathUtils.uintMax = 4294967295 ---@type uint # 32bit 4,294,967,295
MathUtils.floatMin = 1.17549e-038 ---@type float
MathUtils.floatMax = 3.40282e+038 ---@type float
MathUtils.doubleMin = 2.22507e-308 ---@type double
MathUtils.doubleMax = 1.79769e+308 ---@type double
MathUtils.int8Min = -128 ---@type int
MathUtils.int8Max = 127 ---@type int
MathUtils.int32Min = -2147483648 ---@type int # -2,147,483,648
MathUtils.int32Max = 2147483647 ---@type int # 2,147,483,647
MathUtils.uint64Max = 18446744073709551615 ---@type uint64 # 18,446,744,073,709,551,615
MathUtils.uint32Max = 4294967295 ---@type uint # 4,294,967,295
MathUtils.uint16Max = 65535 ---@type uint16 # 65,535
MathUtils.uint8Max = 255 ---@type uint8

--- Get a rotation number from an in game (ellipse) orientation.
---
--- As there's not a direct mapping of orientation to rotation due to Factorio's view angle, meaning some rotations have larger/smaller orientation ranges than others. Its not circular rotation, it's around an ellipse because of the projection.
---@param factorioOrientation RealOrientation # Factorio's in-game ellipse orientation.
---@param maxRotationCount uint
---@return uint rotationNumber # 1-64
MathUtils.GetRotationFromInGameOrientation = function(factorioOrientation, maxRotationCount)
    local naturalOrientation = MathUtils.GetCircularOrientationForInGameOrientation(factorioOrientation)

    local upperOrientation = naturalOrientation + 0.0078125 -- Half of the orientation per rotation. This is to get us up to the upper band as 0 is actually the middle of the first rotation.
    local rotation = math_floor(upperOrientation / 0.015625) + 1 --[[@as uint]]
    if rotation == 65 then rotation = 1 end

    return rotation
end

--- Get an in game (ellipse) orientation value from a rotation count number.
---
--- As there's not a direct mapping of orientation to rotation due to Factorio's view angle, meaning some rotations have larger/smaller orientation ranges than others. Its not circular rotation, it's around an ellipse because of the projection.
---@param rotationNumber uint # 1-64
---@param maxRotationCount uint
---@return RealOrientation factorioOrientation # Factorio's in-game ellipse orientation.
MathUtils.GetInGameOrientationForRotation = function(rotationNumber, maxRotationCount)
    local naturalOrientation = (rotationNumber - 1) * (1 / maxRotationCount) --[[@as RealOrientation]]
    return MathUtils.GetInGameOrientationForCircularOrientation(naturalOrientation)
end

--- Get a conceptual (circular) orientation from an in game (ellipse) orientation value.
---
--- As there's not a direct mapping of orientation to rotation due to Factorio's view angle, meaning some rotations have larger/smaller orientation ranges than others. Its not circular rotation, it's around an ellipse because of the projection.
---@param factorioOrientation RealOrientation  # Factorio's in-game ellipse orientation.
---@return RealOrientation naturalOrientation # The circular orientation.
MathUtils.GetCircularOrientationForInGameOrientation = function(factorioOrientation)
    -- Code breaks with 1 or more orientation value.
    if factorioOrientation >= 1 then factorioOrientation = factorioOrientation - 1 end

    -- Code inverse from Nixie Tube mod 0.15.18 as suggested by JustARandomGeek.
    local factorioOrientation_radians = factorioOrientation * math_pi2
    local x = math_sin(factorioOrientation_radians)
    local y = -math_cos(factorioOrientation_radians)
    y = y / math_cos(math_pi / 4) -- This is the conversation ratio from elliptical to circular.
    local naturalOrientation_radians = math_atan2(x, -y)
    local naturalOrientation = naturalOrientation_radians / math_pi2 --[[@as RealOrientation]]

    -- The default result is -0.5 to 0.5
    if naturalOrientation < 0 then naturalOrientation = 1 + naturalOrientation --[[@as RealOrientation]] end

    return naturalOrientation
end

--- Get an in game (ellipse) orientation value from a conceptual (circular) orientation.
---
--- As there's not a direct mapping of orientation to rotation due to Factorio's view angle, meaning some rotations have larger/smaller orientation ranges than others. Its not circular rotation, it's around an ellipse because of the projection.
---@param naturalOrientation RealOrientation # The circular orientation.
---@return RealOrientation factorioOrientation # Factorio's in-game ellipse orientation.
MathUtils.GetInGameOrientationForCircularOrientation = function(naturalOrientation)
    -- Code breaks with 1 or more orientation value.
    if naturalOrientation >= 1 then naturalOrientation = naturalOrientation - 1 end

    -- Code from Nixie Tube mod 0.15.18 as suggested by JustARandomGeek.
    local naturalOrientation_radians = naturalOrientation * math_pi2
    local x = math_sin(naturalOrientation_radians)
    local y = -math_cos(naturalOrientation_radians)
    y = y * math_cos(math_pi / 4) -- This is the conversation ratio from circular to elliptical.
    local factorioOrientation_radians = math_atan2(x, -y)
    local factorioOrientation = factorioOrientation_radians / math_pi2 --[[@as RealOrientation]]

    -- The default result is -0.5 to 0.5
    if factorioOrientation < 0 then factorioOrientation = 1 + factorioOrientation --[[@as RealOrientation]] end

    return factorioOrientation
end

return MathUtils
