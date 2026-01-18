--[[
    free-restaurants Client Main
    
    Core initialization script that provides:
    - Resource initialization and dependency validation
    - Zone management using ox_lib
    - Map blip creation and management
    - Player state tracking (location, duty status, active station)
    - Event handlers for player lifecycle
    - Exports for cross-script communication
    
    DEPENDENCIES:
    - qbx_core (QBox framework)
    - ox_lib (zones, notifications, callbacks)
    - ox_target (interaction system)
    - ox_inventory (inventory management)
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local isResourceReady = false
local isPlayerLoaded = false
local zones = {}
local blips = {}
local currentLocation = nil         -- Current restaurant location key
local currentLocationData = nil     -- Full location data table

-- Helper function to count table entries
local function tableSize(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- Player state stored in statebags for cross-script access
-- Access via: LocalPlayer.state.freeRestaurants

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

---@class PlayerRestaurantState
---@field isOnDuty boolean Whether player is clocked in
---@field currentLocation string|nil Current restaurant location key
---@field activeStation string|nil Current station being used
---@field job string|nil Current job name
---@field grade number|nil Current job grade

--- Initialize player state
local function initializePlayerState()
    LocalPlayer.state:set('freeRestaurants', {
        isOnDuty = false,
        currentLocation = nil,
        activeStation = nil,
        job = nil,
        grade = nil,
    }, false)
    
    FreeRestaurants.Utils.Debug('Player state initialized')
end

--- Update player state
---@param key string State key to update
---@param value any New value
local function updatePlayerState(key, value)
    local state = LocalPlayer.state.freeRestaurants or {}
    state[key] = value
    LocalPlayer.state:set('freeRestaurants', state, false)
end

--- Get player state
---@param key? string Specific key to get (nil returns full state)
---@return any
local function getPlayerState(key)
    local state = LocalPlayer.state.freeRestaurants or {}
    if key then
        return state[key]
    end
    return state
end

-- ============================================================================
-- DEPENDENCY VALIDATION
-- ============================================================================

--- Validate required dependencies are available
---@return boolean success
---@return string? errorMessage
local function validateDependencies()
    local required = {
        { name = 'qbx_core', check = function() return exports.qbx_core end },
        { name = 'ox_lib', check = function() return lib end },
        { name = 'ox_target', check = function() return exports.ox_target end },
        { name = 'ox_inventory', check = function() return exports.ox_inventory end },
    }
    
    for _, dep in ipairs(required) do
        local success, _ = pcall(dep.check)
        if not success then
            return false, ('Missing required dependency: %s'):format(dep.name)
        end
    end
    
    return true, nil
end

-- ============================================================================
-- ZONE MANAGEMENT
-- ============================================================================

--- Create a zone for a restaurant location
---@param locationKey string Unique location identifier
---@param locationData table Location configuration
---@return table|nil zone The created zone object
local function createLocationZone(locationKey, locationData)
    if not locationData.zone or not locationData.enabled then
        return nil
    end
    
    local zoneData = locationData.zone
    local debug = Config.Debug or Config.Locations.Settings.zoneDetection.debugZones
    
    local zone
    
    if zoneData.type == 'poly' and zoneData.points then
        -- Convert vec2 points to vec3 with minZ
        local points = {}
        for i, point in ipairs(zoneData.points) do
            if type(point) == 'vector2' then
                points[i] = vec3(point.x, point.y, zoneData.minZ or 0)
            else
                points[i] = point
            end
        end
        
        zone = lib.zones.poly({
            name = locationKey,
            points = points,
            thickness = (zoneData.maxZ or 20) - (zoneData.minZ or 0),
            debug = debug,
            onEnter = function(self)
                onEnterRestaurant(locationKey, locationData)
            end,
            onExit = function(self)
                onExitRestaurant(locationKey)
            end,
        })
    elseif zoneData.type == 'circle' or zoneData.type == 'sphere' then
        zone = lib.zones.sphere({
            name = locationKey,
            coords = zoneData.center or locationData.entrance.coords,
            radius = zoneData.radius or 30.0,
            debug = debug,
            onEnter = function(self)
                onEnterRestaurant(locationKey, locationData)
            end,
            onExit = function(self)
                onExitRestaurant(locationKey)
            end,
        })
    elseif zoneData.type == 'box' then
        zone = lib.zones.box({
            name = locationKey,
            coords = zoneData.center or locationData.entrance.coords,
            size = zoneData.size or vec3(30, 30, 10),
            rotation = zoneData.rotation or 0,
            debug = debug,
            onEnter = function(self)
                onEnterRestaurant(locationKey, locationData)
            end,
            onExit = function(self)
                onExitRestaurant(locationKey)
            end,
        })
    end
    
    if zone then
        FreeRestaurants.Utils.Debug(('Created zone for %s'):format(locationKey))
    end
    
    return zone
end

--- Initialize all restaurant zones
local function initializeZones()
    -- Remove existing zones
    for key, zone in pairs(zones) do
        if zone.remove then
            zone:remove()
        end
    end
    zones = {}
    
    -- Create zones for each restaurant type
    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' and locationData.enabled then
                    local key = ('%s_%s'):format(restaurantType, locationId)
                    zones[key] = createLocationZone(key, locationData)
                end
            end
        end
    end
    
    FreeRestaurants.Utils.Debug(('Initialized %d restaurant zones'):format(tableSize(zones)))
end

-- ============================================================================
-- ZONE EVENT HANDLERS
-- ============================================================================

--- Called when player enters a restaurant zone
---@param locationKey string Location identifier
---@param locationData table Location configuration
function onEnterRestaurant(locationKey, locationData)
    currentLocation = locationKey
    currentLocationData = locationData
    
    updatePlayerState('currentLocation', locationKey)
    
    FreeRestaurants.Utils.Debug(('Entered restaurant: %s'):format(locationData.label or locationKey))
    
    -- Trigger event for other scripts
    TriggerEvent('free-restaurants:client:enteredRestaurant', locationKey, locationData)
    
    -- Show notification for employees
    local playerData = exports.qbx_core:GetPlayerData()
    local playerJob = playerData and playerData.job
    if playerJob and playerJob.name == locationData.job then
        if not getPlayerState('isOnDuty') then
            lib.notify({
                title = locationData.label,
                description = 'You are off duty. Clock in to start working!',
                type = 'inform',
                icon = 'briefcase',
            })
        end
    end
end

--- Called when player exits a restaurant zone
---@param locationKey string Location identifier
function onExitRestaurant(locationKey)
    local wasLocation = currentLocation
    
    currentLocation = nil
    currentLocationData = nil
    
    updatePlayerState('currentLocation', nil)
    updatePlayerState('activeStation', nil)
    
    FreeRestaurants.Utils.Debug(('Exited restaurant: %s'):format(locationKey))
    
    -- Trigger event for other scripts
    TriggerEvent('free-restaurants:client:exitedRestaurant', wasLocation)
end

-- ============================================================================
-- BLIP MANAGEMENT
-- ============================================================================

--- Create a map blip for a restaurant location
---@param locationKey string Location identifier
---@param locationData table Location configuration
---@return number|nil blipHandle
local function createLocationBlip(locationKey, locationData)
    if not locationData.blip or not locationData.blip.enabled then
        return nil
    end
    
    local blipData = locationData.blip
    local coords = blipData.coords or locationData.entrance.coords
    
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    
    -- Get default sprite/color from settings if not specified
    local sprite = blipData.sprite or Config.Locations.Settings.blipSprites[locationData.restaurantType] or 106
    local color = blipData.color or Config.Locations.Settings.blipColors[locationData.restaurantType] or 0
    local scale = blipData.scale or Config.Locations.Settings.blips.scale or 0.8
    local label = blipData.label or locationData.label
    
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale)
    SetBlipAsShortRange(blip, Config.Locations.Settings.blips.shortRange ~= false)
    SetBlipDisplay(blip, 4) -- Display on both map and minimap
    
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    
    FreeRestaurants.Utils.Debug(('Created blip for %s'):format(label))
    
    return blip
end

--- Initialize all restaurant blips
local function initializeBlips()
    -- Remove existing blips
    for key, blip in pairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    blips = {}
    
    if not Config.Locations.Settings.blips.enabled then
        return
    end
    
    -- Create blips for each enabled restaurant
    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' and locationData.enabled then
                    local key = ('%s_%s'):format(restaurantType, locationId)
                    blips[key] = createLocationBlip(key, locationData)
                end
            end
        end
    end
    
    FreeRestaurants.Utils.Debug(('Created %d restaurant blips'):format(tableSize(blips)))
end

-- ============================================================================
-- JOB & PLAYER DATA
-- ============================================================================

--- Update player job state
local function updateJobState()
    local playerData = exports.qbx_core:GetPlayerData()
    if not playerData or not playerData.job then return end

    updatePlayerState('job', playerData.job.name)
    updatePlayerState('grade', playerData.job.grade.level)

    FreeRestaurants.Utils.Debug(('Job state updated: %s (grade %d)'):format(
        playerData.job.name,
        playerData.job.grade.level
    ))
end

--- Check if player has a restaurant job
---@return boolean
local function hasRestaurantJob()
    local job = getPlayerState('job')
    return job and Config.Jobs[job] ~= nil
end

--- Get player's restaurant job data
---@return table|nil
local function getRestaurantJobData()
    local job = getPlayerState('job')
    if not job then return nil end
    return Config.Jobs[job]
end

--- Check if player has specific permission
---@param permission string Permission key from jobs.lua
---@return boolean
local function hasPermission(permission)
    print(('[free-restaurants] >>> hasPermission CALLED with: %s'):format(permission))

    local job = getPlayerState('job')
    local grade = getPlayerState('grade') or 0

    print(('[free-restaurants] hasPermission: job=%s, grade=%s'):format(tostring(job), tostring(grade)))

    if not job or not Config.Jobs[job] then
        print(('[free-restaurants] hasPermission(%s): no job or job not in Config.Jobs'):format(permission))
        return false
    end

    local gradeData = Config.Jobs[job].grades[grade]
    print(('[free-restaurants] hasPermission: gradeData exists = %s'):format(tostring(gradeData ~= nil)))

    -- If grade doesn't exist in config, fall back to highest available grade
    if not gradeData then
        local maxGrade = -1
        for g, _ in pairs(Config.Jobs[job].grades) do
            if type(g) == 'number' and g > maxGrade then
                maxGrade = g
            end
        end
        print(('[free-restaurants] hasPermission: maxGrade found = %d'):format(maxGrade))
        if maxGrade >= 0 then
            gradeData = Config.Jobs[job].grades[maxGrade]
            print(('[free-restaurants] hasPermission(%s): grade %d not found, using highest grade %d'):format(permission, grade, maxGrade))
        end
    end

    if not gradeData or not gradeData.permissions then
        print(('[free-restaurants] hasPermission(%s): no grade data available'):format(permission))
        return false
    end

    -- Debug: print all permissions
    print(('[free-restaurants] hasPermission: checking permissions table, all=%s'):format(tostring(gradeData.permissions.all)))

    -- Check for "all" permission (owner/admin access)
    if gradeData.permissions.all == true then
        print(('[free-restaurants] hasPermission(%s): granted via all=true'):format(permission))
        return true
    end

    local result = gradeData.permissions[permission] == true
    print(('[free-restaurants] hasPermission(%s): %s'):format(permission, tostring(result)))
    return result
end

-- ============================================================================
-- LOCATION UTILITIES
-- ============================================================================

--- Get location data by key
---@param locationKey string Full location key (e.g., "burgershot_vespucci")
---@return table|nil locationData
local function getLocationByKey(locationKey)
    local restaurantType, locationId = locationKey:match('(.+)_(.+)')
    if not restaurantType or not locationId then return nil end
    
    local locations = Config.Locations[restaurantType]
    if not locations then return nil end
    
    return locations[locationId]
end

--- Get nearest restaurant location
---@param coords? vector3 Optional coords (defaults to player position)
---@param maxDistance? number Maximum search distance (default: 100.0)
---@return string|nil locationKey
---@return table|nil locationData
---@return number|nil distance
local function getNearestRestaurant(coords, maxDistance)
    coords = coords or GetEntityCoords(cache.ped)
    maxDistance = maxDistance or 100.0
    
    local nearest = nil
    local nearestData = nil
    local nearestDist = maxDistance
    
    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' and locationData.enabled then
                    local entrance = locationData.entrance
                    if entrance and entrance.coords then
                        local dist = #(coords - entrance.coords)
                        if dist < nearestDist then
                            nearestDist = dist
                            nearest = ('%s_%s'):format(restaurantType, locationId)
                            nearestData = locationData
                        end
                    end
                end
            end
        end
    end
    
    return nearest, nearestData, nearestDist < maxDistance and nearestDist or nil
end

--- Get all enabled locations for a specific job
---@param jobName string Job name
---@return table locations Array of {key, data} pairs
local function getLocationsForJob(jobName)
    local result = {}
    
    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' 
                   and locationData.enabled 
                   and locationData.job == jobName then
                    table.insert(result, {
                        key = ('%s_%s'):format(restaurantType, locationId),
                        data = locationData,
                    })
                end
            end
        end
    end
    
    return result
end

-- ============================================================================
-- RESOURCE LIFECYCLE
-- ============================================================================

--- Full initialization after player loads
local function onPlayerLoaded()
    if isPlayerLoaded then return end
    
    isPlayerLoaded = true
    
    -- Initialize player state
    initializePlayerState()
    updateJobState()
    
    -- Initialize zones and blips
    initializeZones()
    initializeBlips()
    
    FreeRestaurants.Utils.Debug('Player fully loaded and initialized')
    
    -- Trigger ready event
    TriggerEvent('free-restaurants:client:ready')
end

--- Resource start handler
local function onResourceStart()
    local success, err = validateDependencies()
    if not success then
        FreeRestaurants.Utils.Error(err)
        return
    end
    
    isResourceReady = true
    FreeRestaurants.Utils.Debug('Resource initialized successfully')
    
    -- If player is already loaded, initialize immediately
    if LocalPlayer.state.isLoggedIn then
        onPlayerLoaded()
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    onResourceStart()
end)

-- QBX player loaded (new character selected)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if isResourceReady then
        onPlayerLoaded()
    end
end)

-- QBX player unloaded (logout/disconnect)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isPlayerLoaded = false
    
    -- Clean up zones
    for key, zone in pairs(zones) do
        if zone.remove then
            zone:remove()
        end
    end
    zones = {}
    
    -- Clean up blips
    for key, blip in pairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    blips = {}
    
    -- Reset state
    currentLocation = nil
    currentLocationData = nil
    
    FreeRestaurants.Utils.Debug('Player unloaded, cleaned up')
end)

-- Job update event
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    updatePlayerState('job', job.name)
    updatePlayerState('grade', job.grade.level)
    
    -- If now off-duty and was on restaurant duty, clock out
    if getPlayerState('isOnDuty') and not Config.Jobs[job.name] then
        updatePlayerState('isOnDuty', false)
        TriggerEvent('free-restaurants:client:clockedOut')
    end
    
    FreeRestaurants.Utils.Debug(('Job updated: %s (grade %d)'):format(job.name, job.grade.level))
end)

-- Server signals player session is ready
RegisterNetEvent('free-restaurants:client:playerReady', function()
    isPlayerLoaded = true
    FreeRestaurants.Utils.Debug('Player session ready on server')
    
    -- Trigger ready event for other client scripts
    TriggerEvent('free-restaurants:client:ready')
end)

-- Initial resource load (if resource is already started when player joins)
CreateThread(function()
    -- Wait a frame for everything to initialize
    Wait(100)
    onResourceStart()
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

-- State getters
exports('GetPlayerState', getPlayerState)
exports('IsOnDuty', function() return getPlayerState('isOnDuty') end)
exports('GetCurrentLocation', function() return currentLocation, currentLocationData end)
exports('GetActiveStation', function() return getPlayerState('activeStation') end)

-- State setters (for internal use by other scripts)
exports('UpdatePlayerState', updatePlayerState)
exports('SetOnDuty', function(status) updatePlayerState('isOnDuty', status) end)
exports('SetActiveStation', function(station) updatePlayerState('activeStation', station) end)

-- Job utilities
exports('HasRestaurantJob', hasRestaurantJob)
exports('GetRestaurantJobData', getRestaurantJobData)
exports('HasPermission', hasPermission)
exports('GetRestaurantJobs', function() return Config.Jobs end)

-- Location utilities
exports('GetLocationByKey', getLocationByKey)
exports('GetNearestRestaurant', getNearestRestaurant)
exports('GetLocationsForJob', getLocationsForJob)
exports('IsInRestaurant', function() return currentLocation ~= nil end)

-- Zone utilities
exports('GetZone', function(key) return zones[key] end)
exports('GetAllZones', function() return zones end)

-- Blip utilities
exports('GetBlip', function(key) return blips[key] end)
exports('RefreshBlips', initializeBlips)

-- Full initialization check
exports('IsReady', function() return isResourceReady and isPlayerLoaded end)

-- ============================================================================
-- GLOBAL TABLE SETUP
-- ============================================================================

-- Extend the FreeRestaurants global for client-side access
FreeRestaurants.Client = {
    GetPlayerState = getPlayerState,
    UpdatePlayerState = updatePlayerState,
    IsOnDuty = function() return getPlayerState('isOnDuty') end,
    GetCurrentLocation = function() return currentLocation, currentLocationData end,
    HasRestaurantJob = hasRestaurantJob,
    GetRestaurantJobData = getRestaurantJobData,
    HasPermission = hasPermission,
    GetLocationByKey = getLocationByKey,
    GetNearestRestaurant = getNearestRestaurant,
    IsInRestaurant = function() return currentLocation ~= nil end,
}

FreeRestaurants.Utils.Debug('client/main.lua loaded')
