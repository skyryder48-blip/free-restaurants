--[[
    free-restaurants Client Duty System
    
    Handles:
    - Clock in/out functionality
    - Uniform management (illenium-appearance integration)
    - Employee locker access
    - Duty state persistence
    - ox_target interactions for duty points
    
    DEPENDENCIES:
    - client/main.lua (state management)
    - ox_target (interaction)
    - illenium-appearance (optional, for uniforms)
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local storedClothing = nil          -- Stored civilian clothing when on duty
local dutyTargets = {}              -- Track created target zones for cleanup
local isChangingClothes = false     -- Prevent spam clicking

-- Helper function to count table entries
local function tableSize(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- ============================================================================
-- UNIFORM MANAGEMENT
-- ============================================================================

--- Check if illenium-appearance is available
---@return boolean
local function hasAppearanceResource()
    return GetResourceState('illenium-appearance') == 'started'
end

--- Store current clothing
local function storeCurrentClothing()
    if not hasAppearanceResource() then
        storedClothing = nil
        return
    end
    
    -- Use illenium-appearance export to get current outfit
    local success, outfit = pcall(function()
        return exports['illenium-appearance']:getPedAppearance(cache.ped)
    end)
    
    if success and outfit then
        storedClothing = outfit
        FreeRestaurants.Utils.Debug('Stored civilian clothing')
    end
end

--- Restore stored clothing
local function restoreStoredClothing()
    if not hasAppearanceResource() or not storedClothing then
        return false
    end
    
    local success = pcall(function()
        exports['illenium-appearance']:setPedAppearance(cache.ped, storedClothing)
    end)
    
    if success then
        storedClothing = nil
        FreeRestaurants.Utils.Debug('Restored civilian clothing')
    end
    
    return success
end

--- Apply work uniform
---@param uniformData table Uniform configuration from jobs.lua
---@return boolean success
local function applyUniform(uniformData)
    if not uniformData then return false end
    
    if not hasAppearanceResource() then
        FreeRestaurants.Utils.Debug('illenium-appearance not available, skipping uniform')
        return true -- Continue without uniform
    end
    
    -- Store current clothing first
    storeCurrentClothing()
    
    local gender = IsPedMale(cache.ped) and 'male' or 'female'
    local outfit = uniformData[gender]
    
    if not outfit then
        FreeRestaurants.Utils.Debug('No uniform defined for gender: ' .. gender)
        return true
    end
    
    local success = pcall(function()
        exports['illenium-appearance']:setPedAppearance(cache.ped, outfit)
    end)
    
    if success then
        FreeRestaurants.Utils.Debug('Applied work uniform')
    else
        FreeRestaurants.Utils.Error('Failed to apply uniform')
    end
    
    return success
end

--- Get uniform for current job and grade
---@return table|nil uniformData
local function getCurrentUniform()
    local job = FreeRestaurants.Client.GetPlayerState('job')
    local grade = FreeRestaurants.Client.GetPlayerState('grade') or 0
    
    if not job or not Config.Jobs[job] then return nil end
    
    local jobConfig = Config.Jobs[job]
    local gradeData = jobConfig.grades[grade]
    
    -- Try grade-specific uniform first
    if gradeData and gradeData.uniform then
        return gradeData.uniform
    end
    
    -- Fall back to default job uniform
    if jobConfig.defaultUniform then
        return jobConfig.defaultUniform
    end
    
    return nil
end

-- ============================================================================
-- CLOCK IN/OUT
-- ============================================================================

--- Clock in to work
---@param locationKey string Location identifier
---@param locationData table Location configuration
local function clockIn(locationKey, locationData)
    if FreeRestaurants.Client.IsOnDuty() then
        lib.notify({
            title = 'Already On Duty',
            description = 'You are already clocked in!',
            type = 'error',
        })
        return
    end
    
    -- Verify player has the correct job
    local playerJob = FreeRestaurants.Client.GetPlayerState('job')
    if not playerJob or playerJob ~= locationData.job then
        lib.notify({
            title = 'Cannot Clock In',
            description = 'You don\'t work here!',
            type = 'error',
        })
        return
    end
    
    -- Show loading
    lib.showTextUI('Clocking in...', { icon = 'clock' })
    
    -- Request clock in from server
    local success = lib.callback.await('free-restaurants:server:clockIn', false, locationKey)
    
    lib.hideTextUI()
    
    if not success then
        lib.notify({
            title = 'Clock In Failed',
            description = 'Unable to clock in at this time.',
            type = 'error',
        })
        return
    end
    
    -- Update local state
    exports['free-restaurants']:SetOnDuty(true)
    
    -- Apply uniform if configured
    if Config.Settings and Config.Settings.requireUniform then
        local uniform = getCurrentUniform()
        if uniform then
            applyUniform(uniform)
        end
    end
    
    -- Notify player
    lib.notify({
        title = locationData.label,
        description = 'You are now on duty!',
        type = 'success',
        icon = 'briefcase',
    })
    
    -- Trigger event for other systems
    TriggerEvent('free-restaurants:client:clockedIn', locationKey, locationData)
    
    FreeRestaurants.Utils.Debug('Clocked in at ' .. locationKey)
end

--- Clock out from work
---@param locationKey string Location identifier
---@param locationData table Location configuration
local function clockOut(locationKey, locationData)
    if not FreeRestaurants.Client.IsOnDuty() then
        lib.notify({
            title = 'Not On Duty',
            description = 'You are not clocked in!',
            type = 'error',
        })
        return
    end
    
    -- Confirm clock out
    local confirm = lib.alertDialog({
        header = 'Clock Out',
        content = 'Are you sure you want to clock out?',
        centered = true,
        cancel = true,
    })
    
    if confirm ~= 'confirm' then return end
    
    -- Show loading
    lib.showTextUI('Clocking out...', { icon = 'clock' })
    
    -- Request clock out from server
    local success, earnings = lib.callback.await('free-restaurants:server:clockOut', false, locationKey)
    
    lib.hideTextUI()
    
    if not success then
        lib.notify({
            title = 'Clock Out Failed',
            description = 'Unable to clock out at this time.',
            type = 'error',
        })
        return
    end
    
    -- Update local state
    exports['free-restaurants']:SetOnDuty(false)
    exports['free-restaurants']:SetActiveStation(nil)
    
    -- Restore civilian clothing
    if Config.Settings and Config.Settings.requireUniform then
        restoreStoredClothing()
    end
    
    -- Build notification message
    local message = 'You are now off duty.'
    if earnings and earnings > 0 then
        message = message .. (' You earned %s this shift!'):format(
            FreeRestaurants.Utils.FormatMoney(earnings)
        )
    end
    
    lib.notify({
        title = locationData.label,
        description = message,
        type = 'inform',
        icon = 'briefcase',
    })
    
    -- Trigger event for other systems
    TriggerEvent('free-restaurants:client:clockedOut', locationKey)
    
    FreeRestaurants.Utils.Debug('Clocked out at ' .. locationKey)
end

--- Toggle duty status
---@param locationKey string Location identifier
---@param locationData table Location configuration
local function toggleDuty(locationKey, locationData)
    if FreeRestaurants.Client.IsOnDuty() then
        clockOut(locationKey, locationData)
    else
        clockIn(locationKey, locationData)
    end
end

-- ============================================================================
-- LOCKER SYSTEM
-- ============================================================================

--- Open locker menu
---@param locationKey string Location identifier
---@param locationData table Location configuration
local function openLocker(locationKey, locationData)
    -- Verify player has the correct job
    local playerJob = FreeRestaurants.Client.GetPlayerState('job')
    if not playerJob or playerJob ~= locationData.job then
        lib.notify({
            title = 'Access Denied',
            description = 'You don\'t have access to these lockers.',
            type = 'error',
        })
        return
    end
    
    -- Build locker options
    local options = {
        {
            title = 'Change Into Uniform',
            description = 'Put on your work uniform',
            icon = 'shirt',
            onSelect = function()
                if isChangingClothes then return end
                isChangingClothes = true
                
                local uniform = getCurrentUniform()
                if uniform then
                    -- Play changing animation
                    lib.progressCircle({
                        duration = 3000,
                        label = 'Changing clothes...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = {
                            move = true,
                            combat = true,
                        },
                        anim = {
                            dict = 'anim@mp_yacht@locker@',
                            clip = 'player_open_locker',
                        },
                    })
                    
                    applyUniform(uniform)
                    
                    lib.notify({
                        title = 'Locker',
                        description = 'Changed into work uniform.',
                        type = 'success',
                    })
                else
                    lib.notify({
                        title = 'Locker',
                        description = 'No uniform available for your position.',
                        type = 'inform',
                    })
                end
                
                isChangingClothes = false
            end,
        },
        {
            title = 'Change Into Civilian Clothes',
            description = 'Put on your regular clothes',
            icon = 'user',
            onSelect = function()
                if isChangingClothes then return end
                isChangingClothes = true
                
                -- Play changing animation
                lib.progressCircle({
                    duration = 3000,
                    label = 'Changing clothes...',
                    useWhileDead = false,
                    canCancel = true,
                    disable = {
                        move = true,
                        combat = true,
                    },
                    anim = {
                        dict = 'anim@mp_yacht@locker@',
                        clip = 'player_open_locker',
                    },
                })
                
                if storedClothing then
                    restoreStoredClothing()
                    lib.notify({
                        title = 'Locker',
                        description = 'Changed into civilian clothes.',
                        type = 'success',
                    })
                else
                    lib.notify({
                        title = 'Locker',
                        description = 'No stored clothing found.',
                        type = 'inform',
                    })
                end
                
                isChangingClothes = false
            end,
        },
    }
    
    -- Add personal stash option if configured
    if locationData.duty and locationData.duty.locker and locationData.duty.locker.hasStash then
        table.insert(options, {
            title = 'Personal Stash',
            description = 'Access your personal storage',
            icon = 'box',
            onSelect = function()
                local playerData = exports.qbx_core:GetPlayerData()
                local stashId = ('restaurant_locker_%s_%s'):format(
                    locationKey,
                    playerData and playerData.citizenid or 'unknown'
                )
                exports.ox_inventory:openInventory('stash', stashId)
            end,
        })
    end
    
    -- Show context menu
    lib.registerContext({
        id = 'restaurant_locker',
        title = 'Employee Locker',
        options = options,
    })
    
    lib.showContext('restaurant_locker')
end

-- ============================================================================
-- TARGET SETUP
-- ============================================================================

--- Setup ox_target zones for a location's duty points
---@param locationKey string Location identifier
---@param locationData table Location configuration
local function setupDutyTargets(locationKey, locationData)
    if not locationData.duty then return end
    
    local job = locationData.job
    
    -- Clock in/out point
    if locationData.duty.clockIn then
        local clockData = locationData.duty.clockIn
        local targetId = ('%s_clock'):format(locationKey)
        
        exports.ox_target:addBoxZone({
            name = targetId,
            coords = clockData.coords,
            size = clockData.targetSize or vec3(1.0, 1.0, 2.0),
            rotation = clockData.heading or 0,
            debug = Config.Debug,
            options = {
                {
                    name = 'clock_toggle',
                    label = 'Clock In/Out',
                    icon = 'fa-solid fa-clock',
                    groups = { [job] = 0 },
                    onSelect = function()
                        toggleDuty(locationKey, locationData)
                    end,
                },
            },
        })
        
        dutyTargets[targetId] = true
        FreeRestaurants.Utils.Debug(('Created clock target: %s'):format(targetId))
    end
    
    -- Locker point
    if locationData.duty.locker then
        local lockerData = locationData.duty.locker
        local targetId = ('%s_locker'):format(locationKey)
        
        exports.ox_target:addBoxZone({
            name = targetId,
            coords = lockerData.coords,
            size = lockerData.targetSize or vec3(1.5, 0.5, 2.0),
            rotation = lockerData.heading or 0,
            debug = Config.Debug,
            options = {
                {
                    name = 'locker_open',
                    label = 'Open Locker',
                    icon = 'fa-solid fa-door-open',
                    groups = { [job] = 0 },
                    onSelect = function()
                        openLocker(locationKey, locationData)
                    end,
                },
            },
        })
        
        dutyTargets[targetId] = true
        FreeRestaurants.Utils.Debug(('Created locker target: %s'):format(targetId))
    end
end

--- Remove all duty targets
local function removeDutyTargets()
    for targetId in pairs(dutyTargets) do
        exports.ox_target:removeZone(targetId)
    end
    dutyTargets = {}
end

--- Initialize duty targets for all locations
local function initializeDutyTargets()
    -- Remove existing targets
    removeDutyTargets()
    
    -- Create targets for each enabled location
    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' and locationData.enabled then
                    local key = ('%s_%s'):format(restaurantType, locationId)
                    setupDutyTargets(key, locationData)
                end
            end
        end
    end
    
    FreeRestaurants.Utils.Debug(('Initialized %d duty targets'):format(tableSize(dutyTargets)))
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Initialize when ready
RegisterNetEvent('free-restaurants:client:ready', function()
    initializeDutyTargets()
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    removeDutyTargets()
end)

-- Handle player logout
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    -- Auto clock out if on duty
    if FreeRestaurants.Client.IsOnDuty() then
        local locationKey, locationData = FreeRestaurants.Client.GetCurrentLocation()
        if locationKey and locationData then
            -- Silent clock out (no confirmation dialog)
            lib.callback.await('free-restaurants:server:clockOut', false, locationKey)
        end
        exports['free-restaurants']:SetOnDuty(false)
    end
    
    -- Restore clothing if changed
    if storedClothing then
        restoreStoredClothing()
    end
end)

-- Handle entering restaurant while on duty elsewhere
RegisterNetEvent('free-restaurants:client:enteredRestaurant', function(locationKey, locationData)
    -- If on duty but at wrong location, warn player
    if FreeRestaurants.Client.IsOnDuty() then
        local playerJob = FreeRestaurants.Client.GetPlayerState('job')
        if playerJob and playerJob ~= locationData.job then
            lib.notify({
                title = 'Wrong Location',
                description = 'You are clocked in at a different restaurant!',
                type = 'warning',
            })
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('ClockIn', function(locationKey)
    local locationData = exports['free-restaurants']:GetLocationByKey(locationKey)
    if locationData then
        clockIn(locationKey, locationData)
    end
end)

exports('ClockOut', function(locationKey)
    local locationData = exports['free-restaurants']:GetLocationByKey(locationKey)
    if locationData then
        clockOut(locationKey, locationData)
    end
end)

exports('ToggleDuty', function(locationKey)
    local locationData = exports['free-restaurants']:GetLocationByKey(locationKey)
    if locationData then
        toggleDuty(locationKey, locationData)
    end
end)

exports('OpenLocker', function(locationKey)
    local locationData = exports['free-restaurants']:GetLocationByKey(locationKey)
    if locationData then
        openLocker(locationKey, locationData)
    end
end)

exports('ApplyUniform', function()
    local uniform = getCurrentUniform()
    if uniform then
        return applyUniform(uniform)
    end
    return false
end)

exports('RestoreClothing', restoreStoredClothing)

FreeRestaurants.Utils.Debug('client/duty.lua loaded')
