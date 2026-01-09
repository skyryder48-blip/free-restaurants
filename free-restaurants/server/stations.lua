--[[
    free-restaurants Server Station Management
    
    Handles:
    - Server-authoritative slot claiming/releasing
    - State bag synchronization for all clients
    - Slot timeout and cleanup
    - Fire state synchronization
    
    DEPENDENCIES:
    - oxmysql (optional, for persistence)
    - ox_lib (callbacks)
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

-- Station slot data: [locationKey][stationKey][slotIndex] = SlotData
local stationSlots = {}

-- Player to slot mapping for quick lookup - now tracks MULTIPLE slots per player
-- [playerId] = { [slotKey] = { locationKey, stationKey, slotIndex }, ... }
local playerSlots = {}

-- Slot timeout handles
local slotTimeouts = {}

-- Fire state tracking
local activeFires = {}  -- [fireKey] = { stage, coords, startTime }

-- Forward declarations for functions used before definition
local setSlotTimeout
local clearSlotTimeout

-- Configuration
local SlotConfig = {
    timeoutDuration = 300000,    -- 5 minutes idle timeout
    cleanupInterval = 60000,     -- 1 minute cleanup check
}

-- ============================================================================
-- STATE BAG MANAGEMENT
-- ============================================================================

--- Get the state bag key for a station
---@param locationKey string
---@param stationKey string
---@return string
local function getStationStateKey(locationKey, stationKey)
    return ('restaurant:%s:%s'):format(locationKey, stationKey)
end

--- Update state bag for a station (broadcasts to all clients)
---@param locationKey string
---@param stationKey string
local function syncStationState(locationKey, stationKey)
    local stateKey = getStationStateKey(locationKey, stationKey)
    local slotData = stationSlots[locationKey] and stationSlots[locationKey][stationKey] or {}
    
    GlobalState[stateKey] = slotData
end

-- ============================================================================
-- SLOT MANAGEMENT
-- ============================================================================

--- Initialize slot data structure for a station
---@param locationKey string
---@param stationKey string
---@param numSlots number
local function initializeStation(locationKey, stationKey, numSlots)
    if not stationSlots[locationKey] then
        stationSlots[locationKey] = {}
    end

    if not stationSlots[locationKey][stationKey] then
        stationSlots[locationKey][stationKey] = {}
    end

    -- Create any missing slots (handles both new stations and expanding existing ones)
    local slotsAdded = false
    for i = 1, numSlots do
        if not stationSlots[locationKey][stationKey][i] then
            stationSlots[locationKey][stationKey][i] = {
                occupied = false,
                playerId = nil,
                playerName = nil,
                status = 'empty',
                recipeId = nil,
                startTime = nil,
                cookTime = nil,
                progress = 0,
                quality = 100,
            }
            slotsAdded = true
        end
    end

    if slotsAdded then
        syncStationState(locationKey, stationKey)
    end
end

--- Get slot data
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@return table|nil slotData
local function getSlotData(locationKey, stationKey, slotIndex)
    if stationSlots[locationKey] and 
       stationSlots[locationKey][stationKey] and 
       stationSlots[locationKey][stationKey][slotIndex] then
        return stationSlots[locationKey][stationKey][slotIndex]
    end
    return nil
end

--- Claim a slot for a player
---@param playerId number
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@param recipeId string
---@return boolean success
local function claimSlot(playerId, locationKey, stationKey, slotIndex, recipeId)
    print(('[free-restaurants] claimSlot called: player=%d, location=%s, station=%s, slot=%d'):format(
        playerId, locationKey, stationKey, slotIndex
    ))

    -- Generate a unique key for this slot
    local slotKey = ('%s:%s:%d'):format(locationKey, stationKey, slotIndex)

    -- Check if player already has THIS SPECIFIC slot (allow re-claim for recipe change)
    if playerSlots[playerId] and playerSlots[playerId][slotKey] then
        print(('[free-restaurants] Player %d re-claiming existing slot %s'):format(playerId, slotKey))
    end

    -- Get slot data
    local slotData = getSlotData(locationKey, stationKey, slotIndex)
    if not slotData then
        -- Initialize station if needed (get capacity from config)
        -- Get station type from location config, not by parsing the station key
        local stationType = nil
        local locationConfig = Config.Locations and Config.Locations[locationKey]
        if locationConfig and locationConfig.stations and locationConfig.stations[stationKey] then
            stationType = locationConfig.stations[stationKey].type
        end

        local stationConfig = stationType and Config.Stations.Types[stationType]
        local numSlots = stationConfig and stationConfig.capacity and stationConfig.capacity.slots or 1

        print(('[free-restaurants] Initializing station %s/%s with %d slots (type: %s)'):format(
            locationKey, stationKey, math.max(numSlots, slotIndex), tostring(stationType)
        ))

        initializeStation(locationKey, stationKey, math.max(numSlots, slotIndex))
        slotData = getSlotData(locationKey, stationKey, slotIndex)
    end

    if not slotData then
        print(('[free-restaurants] REJECTED: Could not get/create slot data'))
        return false
    end

    -- Check if slot is available (not occupied by another player)
    if slotData.occupied and slotData.playerId ~= playerId then
        print(('[free-restaurants] REJECTED: Slot occupied by player %s'):format(tostring(slotData.playerId)))
        return false
    end

    -- Get player name
    local player = exports.qbx_core:GetPlayer(playerId)
    local playerName = player and ('%s %s'):format(
        player.PlayerData.charinfo.firstname,
        player.PlayerData.charinfo.lastname
    ) or ('Player %d'):format(playerId)

    -- Claim the slot
    slotData.occupied = true
    slotData.playerId = playerId
    slotData.playerName = playerName
    slotData.status = 'preparing'
    slotData.recipeId = recipeId
    slotData.startTime = os.time()
    slotData.progress = 0
    slotData.quality = 100

    -- Track player's slot (allow multiple slots per player)
    if not playerSlots[playerId] then
        playerSlots[playerId] = {}
    end
    playerSlots[playerId][slotKey] = {
        locationKey = locationKey,
        stationKey = stationKey,
        slotIndex = slotIndex,
    }

    -- Set timeout for slot
    setSlotTimeout(playerId, locationKey, stationKey, slotIndex)

    -- Sync state
    syncStationState(locationKey, stationKey)

    local numSlots = 0
    for _ in pairs(playerSlots[playerId]) do numSlots = numSlots + 1 end
    print(('[free-restaurants] Player %d claimed slot %d at %s/%s (now has %d active slots)'):format(
        playerId, slotIndex, locationKey, stationKey, numSlots
    ))
    
    return true
end

--- Release a slot
---@param playerId number
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@param status? string Final status
---@return boolean success
local function releaseSlot(playerId, locationKey, stationKey, slotIndex, status)
    local slotData = getSlotData(locationKey, stationKey, slotIndex)

    if not slotData then
        return false
    end

    -- Verify ownership (or allow forced release with playerId = 0)
    if slotData.playerId and slotData.playerId ~= playerId and playerId ~= 0 then
        return false
    end

    -- Get the actual owner for clearing player tracking
    local ownerId = slotData.playerId

    -- Clear slot
    slotData.occupied = false
    slotData.playerId = nil
    slotData.playerName = nil
    slotData.status = 'empty'
    slotData.recipeId = nil
    slotData.startTime = nil
    slotData.cookTime = nil
    slotData.progress = 0
    slotData.quality = 100
    slotData.pendingPickupBy = nil

    -- Clear player tracking (remove this specific slot from player's slots)
    local slotKey = ('%s:%s:%d'):format(locationKey, stationKey, slotIndex)
    if ownerId and playerSlots[ownerId] and playerSlots[ownerId][slotKey] then
        playerSlots[ownerId][slotKey] = nil
        -- Clean up empty table
        if next(playerSlots[ownerId]) == nil then
            playerSlots[ownerId] = nil
        end
    end

    -- Clear timeout
    clearSlotTimeout(locationKey, stationKey, slotIndex)

    -- Sync state
    syncStationState(locationKey, stationKey)

    print(('[free-restaurants] Slot %d released at %s/%s (status: %s)'):format(
        slotIndex, locationKey, stationKey, status or 'unknown'
    ))

    return true
end

--- Mark a slot as ready for pickup (crafting complete, waiting for item pickup)
--- This clears playerSlots so the player can craft elsewhere, but keeps slot occupied for pickup
---@param playerId number
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@return boolean success
local function markSlotForPickup(playerId, locationKey, stationKey, slotIndex)
    print(('[free-restaurants] markSlotForPickup called: player=%d, location=%s, station=%s, slot=%d'):format(
        playerId, locationKey, stationKey, slotIndex
    ))

    local slotData = getSlotData(locationKey, stationKey, slotIndex)

    if not slotData then
        print(('[free-restaurants] markSlotForPickup FAILED: no slot data'))
        return false
    end

    -- Verify ownership
    if slotData.playerId and slotData.playerId ~= playerId then
        print(('[free-restaurants] markSlotForPickup FAILED: wrong owner (slot=%s, caller=%d)'):format(
            tostring(slotData.playerId), playerId
        ))
        return false
    end

    -- Update slot to ready_for_pickup status
    -- Keep occupied = true so no one can use the slot
    -- But remove from playerSlots so they can craft elsewhere
    slotData.status = 'ready_for_pickup'
    slotData.pendingPickupBy = playerId  -- Track who can pick up

    -- Clear player tracking for this specific slot - allows them to craft at other slots/stations
    local slotKey = ('%s:%s:%d'):format(locationKey, stationKey, slotIndex)
    if playerSlots[playerId] and playerSlots[playerId][slotKey] then
        playerSlots[playerId][slotKey] = nil
        print(('[free-restaurants] Removed slot %s from playerSlots[%d]'):format(slotKey, playerId))
        -- Clean up empty table
        if next(playerSlots[playerId]) == nil then
            playerSlots[playerId] = nil
            print(('[free-restaurants] Cleared empty playerSlots[%d]'):format(playerId))
        end
    else
        print(('[free-restaurants] playerSlots[%d][%s] was already nil'):format(playerId, slotKey))
    end

    -- Clear the cooking timeout since crafting is complete
    clearSlotTimeout(locationKey, stationKey, slotIndex)

    -- Sync state
    syncStationState(locationKey, stationKey)

    print(('[free-restaurants] Slot %d at %s/%s marked for pickup (player %d can now craft elsewhere)'):format(
        slotIndex, locationKey, stationKey, playerId
    ))

    return true
end

--- Update slot status
---@param playerId number
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@param updates table Fields to update
---@return boolean success
local function updateSlot(playerId, locationKey, stationKey, slotIndex, updates)
    local slotData = getSlotData(locationKey, stationKey, slotIndex)
    
    if not slotData then
        return false
    end
    
    -- Verify ownership
    if slotData.playerId ~= playerId then
        return false
    end
    
    -- Apply updates
    for key, value in pairs(updates) do
        if slotData[key] ~= nil then
            slotData[key] = value
        end
    end
    
    -- Reset timeout on activity
    setSlotTimeout(playerId, locationKey, stationKey, slotIndex)
    
    -- Sync state
    syncStationState(locationKey, stationKey)
    
    return true
end

-- ============================================================================
-- TIMEOUT MANAGEMENT
-- ============================================================================

--- Get timeout key
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@return string
local function getTimeoutKey(locationKey, stationKey, slotIndex)
    return ('%s_%s_%d'):format(locationKey, stationKey, slotIndex)
end

--- Set slot timeout
---@param playerId number
---@param locationKey string
---@param stationKey string
---@param slotIndex number
setSlotTimeout = function(playerId, locationKey, stationKey, slotIndex)
    local timeoutKey = getTimeoutKey(locationKey, stationKey, slotIndex)
    
    -- Clear existing timeout
    if slotTimeouts[timeoutKey] then
        -- Can't cancel SetTimeout, but we track state
    end
    
    -- Set new timeout
    slotTimeouts[timeoutKey] = {
        playerId = playerId,
        startTime = os.time(),
    }
    
    SetTimeout(SlotConfig.timeoutDuration, function()
        local current = slotTimeouts[timeoutKey]
        if current and current.playerId == playerId then
            -- Timeout expired, force release
            print(('[free-restaurants] Slot timeout for player %d at %s/%s slot %d'):format(
                playerId, locationKey, stationKey, slotIndex
            ))
            releaseSlot(0, locationKey, stationKey, slotIndex, 'timeout')
        end
    end)
end

--- Clear slot timeout
---@param locationKey string
---@param stationKey string
---@param slotIndex number
clearSlotTimeout = function(locationKey, stationKey, slotIndex)
    local timeoutKey = getTimeoutKey(locationKey, stationKey, slotIndex)
    slotTimeouts[timeoutKey] = nil
end

-- ============================================================================
-- FIRE SYNCHRONIZATION
-- ============================================================================

--- Get fire key
---@param stationKey string
---@param slotIndex number
---@return string
local function getFireKey(stationKey, slotIndex)
    return ('%s_slot%d'):format(stationKey, slotIndex)
end

--- Track fire state
---@param stationKey string
---@param slotIndex number
---@param coords vector3
---@param stage number
local function trackFire(stationKey, slotIndex, coords, stage)
    local fireKey = getFireKey(stationKey, slotIndex)
    
    activeFires[fireKey] = {
        stage = stage,
        coords = coords,
        startTime = os.time(),
    }
    
    -- Broadcast to all clients
    TriggerClientEvent('free-restaurants:client:syncFire', -1, {
        stationKey = stationKey,
        slotIndex = slotIndex,
        coords = coords,
        stage = stage,
    })
end

--- Clear fire state
---@param stationKey string
---@param slotIndex number
local function clearFire(stationKey, slotIndex)
    local fireKey = getFireKey(stationKey, slotIndex)
    activeFires[fireKey] = nil
    
    TriggerClientEvent('free-restaurants:client:syncFireExtinguished', -1, {
        stationKey = stationKey,
        slotIndex = slotIndex,
    })
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

-- Claim slot callback
lib.callback.register('free-restaurants:server:claimSlot', function(source, data)
    return claimSlot(
        source,
        data.locationKey,
        data.stationKey,
        data.slotIndex,
        data.recipeId
    )
end)

-- Release slot callback
lib.callback.register('free-restaurants:server:releaseSlot', function(source, data)
    return releaseSlot(
        source,
        data.locationKey,
        data.stationKey,
        data.slotIndex,
        data.status
    )
end)

-- Update slot callback
lib.callback.register('free-restaurants:server:updateSlot', function(source, data)
    return updateSlot(
        source,
        data.locationKey,
        data.stationKey,
        data.slotIndex,
        data.updates
    )
end)

-- Get station slots callback
lib.callback.register('free-restaurants:server:getStationSlots', function(source, locationKey, stationKey)
    if stationSlots[locationKey] and stationSlots[locationKey][stationKey] then
        return stationSlots[locationKey][stationKey]
    end
    return {}
end)

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Fire started event from client
RegisterNetEvent('free-restaurants:server:fireStarted', function(data)
    trackFire(data.stationKey, data.slotIndex, data.coords, data.stage)
end)

-- Fire escalated event from client
RegisterNetEvent('free-restaurants:server:fireEscalated', function(data)
    trackFire(data.stationKey, data.slotIndex, data.coords, data.stage)
end)

-- Fire extinguished event from client
RegisterNetEvent('free-restaurants:server:fireExtinguished', function(data)
    clearFire(data.stationKey, data.slotIndex)
end)

-- Player dropped - release all their slots
AddEventHandler('playerDropped', function(reason)
    local playerId = source

    if playerSlots[playerId] then
        -- Make a copy of keys to iterate since we're modifying during iteration
        local slotsToRelease = {}
        for slotKey, slot in pairs(playerSlots[playerId]) do
            table.insert(slotsToRelease, slot)
        end

        for _, slot in ipairs(slotsToRelease) do
            releaseSlot(
                playerId,
                slot.locationKey,
                slot.stationKey,
                slot.slotIndex,
                'disconnected'
            )
        end
    end
end)

-- Player joining - sync fire states
RegisterNetEvent('free-restaurants:server:playerReady', function()
    local playerId = source
    
    -- Send all active fires to new player
    for fireKey, fireData in pairs(activeFires) do
        local parts = {}
        for part in fireKey:gmatch('[^_slot]+') do
            table.insert(parts, part)
        end
        
        if #parts >= 2 then
            TriggerClientEvent('free-restaurants:client:syncFire', playerId, {
                stationKey = parts[1],
                slotIndex = tonumber(parts[2]) or 1,
                coords = fireData.coords,
                stage = fireData.stage,
            })
        end
    end
end)

-- ============================================================================
-- CLEANUP THREAD
-- ============================================================================

CreateThread(function()
    while true do
        Wait(SlotConfig.cleanupInterval)
        
        local currentTime = os.time()
        local expiredSlots = {}
        
        -- Find expired slots
        for timeoutKey, data in pairs(slotTimeouts) do
            if currentTime - data.startTime > (SlotConfig.timeoutDuration / 1000) then
                table.insert(expiredSlots, timeoutKey)
            end
        end
        
        -- Release expired slots
        for _, timeoutKey in ipairs(expiredSlots) do
            local parts = {}
            for part in timeoutKey:gmatch('[^_]+') do
                table.insert(parts, part)
            end
            
            if #parts >= 3 then
                local locationKey = parts[1]
                local stationKey = table.concat({parts[2]}, '_')  -- Handle station keys with underscores
                local slotIndex = tonumber(parts[#parts])
                
                if slotIndex then
                    releaseSlot(0, locationKey, stationKey, slotIndex, 'cleanup')
                end
            end
            
            slotTimeouts[timeoutKey] = nil
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('ClaimSlot', function(playerId, locationKey, stationKey, slotIndex, recipeId)
    return claimSlot(playerId, locationKey, stationKey, slotIndex, recipeId)
end)

exports('ReleaseSlot', function(playerId, locationKey, stationKey, slotIndex, status)
    return releaseSlot(playerId, locationKey, stationKey, slotIndex, status)
end)

exports('MarkSlotForPickup', function(playerId, locationKey, stationKey, slotIndex)
    return markSlotForPickup(playerId, locationKey, stationKey, slotIndex)
end)

exports('UpdateSlot', function(playerId, locationKey, stationKey, slotIndex, updates)
    return updateSlot(playerId, locationKey, stationKey, slotIndex, updates)
end)

exports('GetSlotData', getSlotData)

exports('GetPlayerSlots', function(playerId)
    return playerSlots[playerId]
end)

-- Legacy: Returns first slot if any (for backwards compatibility)
exports('GetPlayerSlot', function(playerId)
    if playerSlots[playerId] then
        for _, slot in pairs(playerSlots[playerId]) do
            return slot  -- Return first slot found
        end
    end
    return nil
end)

exports('GetActiveFires', function()
    return activeFires
end)

print('[free-restaurants] server/stations.lua loaded')
