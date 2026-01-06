---@class FreeRestaurants
---@field Utils table Utility functions
---@field Stations table Station management
---@field Recipes table Recipe management
---@field Locations table Location data

FreeRestaurants = FreeRestaurants or {}
FreeRestaurants.Utils = {}

--- Check if a value exists in a table
---@param tbl table The table to search
---@param value any The value to find
---@return boolean
function FreeRestaurants.Utils.TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

--- Deep copy a table
---@param tbl table The table to copy
---@return table
function FreeRestaurants.Utils.DeepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[FreeRestaurants.Utils.DeepCopy(k)] = FreeRestaurants.Utils.DeepCopy(v)
    end
    return setmetatable(copy, getmetatable(tbl))
end

--- Get current timestamp in seconds
---@return integer
function FreeRestaurants.Utils.GetTimestamp()
    return os.time()
end

--- Format money with currency symbol
---@param amount number The amount to format
---@return string
function FreeRestaurants.Utils.FormatMoney(amount)
    return ('$%s'):format(lib.math.groupdigits(amount))
end

--- Format time duration from seconds
---@param seconds number Duration in seconds
---@return string
function FreeRestaurants.Utils.FormatDuration(seconds)
    if seconds < 60 then
        return ('%d seconds'):format(seconds)
    elseif seconds < 3600 then
        local mins = math.floor(seconds / 60)
        return ('%d minute%s'):format(mins, mins > 1 and 's' or '')
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        return ('%d hour%s %d min%s'):format(hours, hours > 1 and 's' or '', mins, mins > 1 and 's' or '')
    end
end

--- Calculate quality multiplier based on freshness percentage
---@param freshness number Freshness percentage (0-100)
---@return number multiplier Between 0.5 and 1.0
function FreeRestaurants.Utils.GetQualityMultiplier(freshness)
    if freshness >= 80 then
        return 1.0
    elseif freshness >= 60 then
        return 0.9
    elseif freshness >= 40 then
        return 0.75
    elseif freshness >= 20 then
        return 0.6
    else
        return 0.5
    end
end

--- Get quality label from percentage
---@param quality number Quality percentage (0-100)
---@return string label
---@return string color Hex color for UI
function FreeRestaurants.Utils.GetQualityLabel(quality)
    if quality >= 90 then
        return 'Excellent', '#22c55e'
    elseif quality >= 75 then
        return 'Good', '#84cc16'
    elseif quality >= 50 then
        return 'Average', '#eab308'
    elseif quality >= 25 then
        return 'Poor', '#f97316'
    else
        return 'Terrible', '#ef4444'
    end
end

--- Check if current time is during rush hour
---@return boolean isRushHour
---@return number multiplier Order frequency multiplier
function FreeRestaurants.Utils.IsRushHour()
    local hour = tonumber(os.date('%H'))
    
    -- Lunch rush: 11:00 - 14:00
    if hour >= 11 and hour < 14 then
        return true, 2.0
    end
    
    -- Dinner rush: 17:00 - 21:00
    if hour >= 17 and hour < 21 then
        return true, 2.5
    end
    
    -- Late night: 22:00 - 02:00
    if hour >= 22 or hour < 2 then
        return true, 1.5
    end
    
    return false, 1.0
end

--- Validate that player has required job and grade
---@param playerJob table Player's job data
---@param requiredJob string Required job name
---@param requiredGrade? number Minimum grade required (default: 0)
---@return boolean
function FreeRestaurants.Utils.HasJobAccess(playerJob, requiredJob, requiredGrade)
    if not playerJob or playerJob.name ~= requiredJob then
        return false
    end
    
    requiredGrade = requiredGrade or 0
    return playerJob.grade.level >= requiredGrade
end

--- Generate a unique order ID
---@return string
function FreeRestaurants.Utils.GenerateOrderId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = ''
    for i = 1, 6 do
        local idx = math.random(1, #chars)
        id = id .. chars:sub(idx, idx)
    end
    return id
end

--- Safely get nested table value
---@param tbl table The table to search
---@param ... string Keys to traverse
---@return any|nil
function FreeRestaurants.Utils.SafeGet(tbl, ...)
    local value = tbl
    for _, key in ipairs({...}) do
        if type(value) ~= 'table' then return nil end
        value = value[key]
    end
    return value
end

-- Debug logging (respects Config.Debug setting)
---@param ... any Values to print
function FreeRestaurants.Utils.Debug(...)
    if Config and Config.Debug then
        print(('[^3free-restaurants^7] %s'):format(table.concat({...}, ' ')))
    end
end

--- Error logging (always prints)
---@param ... any Values to print
function FreeRestaurants.Utils.Error(...)
    print(('[^1free-restaurants ERROR^7] %s'):format(table.concat({...}, ' ')))
end

return FreeRestaurants.Utils
