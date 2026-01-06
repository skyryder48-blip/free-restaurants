--[[
    free-restaurants Client Cleaning System
    
    Handles:
    - Station cleaning interactions
    - Cleaning animations and progress
    - Violation fixing
    - Inspection result display
    
    DEPENDENCIES:
    - client/main.lua
    - ox_lib
    - ox_target
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local isCleaning = false
local cleaningTargets = {}

-- Cleaning tools
local CLEANING_TOOLS = {
    { name = 'cleaning_spray', label = 'Cleaning Spray' },
    { name = 'cleaning_cloth', label = 'Cleaning Cloth' },
    { name = 'mop', label = 'Mop' },
}

-- Animation sets
local CLEANING_ANIMS = {
    wipe = { dict = 'timetable@floyd@clean_kitchen@base', clip = 'base' },
    mop = { dict = 'anim@amb@business@coc@coc_packing_hi@', clip = 'full_cycle_v1_cokepacker' },
    spray = { dict = 'timetable@floyd@clean_kitchen@spray_bottle', clip = 'spray_loop' },
}

-- ============================================================================
-- CLEANING FUNCTIONS
-- ============================================================================

--- Check if player has cleaning supplies
---@return boolean hasTool
---@return string|nil toolName
local function hasCleaningTool()
    for _, tool in ipairs(CLEANING_TOOLS) do
        local count = exports.ox_inventory:Search('count', tool.name)
        if count > 0 then
            return true, tool.name
        end
    end
    return false, nil
end

--- Clean a station
---@param stationKey string
---@param stationData table
local function cleanStation(stationKey, stationData)
    if isCleaning then
        lib.notify({
            title = 'Busy',
            description = 'Already cleaning!',
            type = 'error',
        })
        return
    end
    
    -- Check for cleaning tool
    local hasTool, toolName = hasCleaningTool()
    if not hasTool then
        lib.notify({
            title = 'No Supplies',
            description = 'You need cleaning supplies!',
            type = 'error',
        })
        return
    end
    
    isCleaning = true
    
    -- Select animation based on tool
    local anim = CLEANING_ANIMS.wipe
    if toolName == 'mop' then
        anim = CLEANING_ANIMS.mop
    elseif toolName == 'cleaning_spray' then
        anim = CLEANING_ANIMS.spray
    end
    
    -- Request animation dict
    lib.requestAnimDict(anim.dict)
    
    -- Start cleaning progress
    local success = lib.progressCircle({
        duration = 8000,
        label = 'Cleaning station...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = anim.dict,
            clip = anim.clip,
            flag = 49,
        },
    })
    
    isCleaning = false
    ClearPedTasks(cache.ped)
    
    if success then
        -- Notify server
        local result = lib.callback.await('free-restaurants:server:cleanStation', false, stationKey)
        
        if result then
            lib.notify({
                title = 'Station Cleaned',
                description = 'The station is now spotless!',
                type = 'success',
            })
            
            -- Small chance to consume cleaning tool
            if math.random() < 0.3 then
                exports.ox_inventory:RemoveItem(toolName, 1)
            end
        end
    else
        lib.notify({
            title = 'Cancelled',
            description = 'Cleaning cancelled.',
            type = 'inform',
        })
    end
end

--- General area cleaning
---@param locationKey string
local function cleanArea(locationKey)
    if isCleaning then return end
    
    local hasTool, toolName = hasCleaningTool()
    if not hasTool then
        lib.notify({
            title = 'No Supplies',
            description = 'You need cleaning supplies!',
            type = 'error',
        })
        return
    end
    
    isCleaning = true
    
    lib.requestAnimDict('timetable@floyd@clean_kitchen@base')
    
    local success = lib.progressCircle({
        duration = 15000,
        label = 'Deep cleaning area...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            combat = true,
        },
        anim = {
            dict = 'timetable@floyd@clean_kitchen@base',
            clip = 'base',
            flag = 49,
        },
    })
    
    isCleaning = false
    ClearPedTasks(cache.ped)
    
    if success then
        local result = lib.callback.await('free-restaurants:server:cleanStation', false, 'general')
        
        if result then
            lib.notify({
                title = 'Area Cleaned',
                description = 'The area is now clean!',
                type = 'success',
            })
            
            -- Consume some cleaning tool durability
            if math.random() < 0.5 then
                exports.ox_inventory:RemoveItem(toolName, 1)
            end
        end
    end
end

-- ============================================================================
-- VIOLATION FIXING
-- ============================================================================

--- Show violations menu
---@param locationKey string
local function showViolationsMenu(locationKey)
    local status = lib.callback.await('free-restaurants:server:getInspectionStatus', false)
    
    if not status or not status.activeViolations or #status.activeViolations == 0 then
        lib.notify({
            title = 'No Violations',
            description = 'There are no active violations to fix.',
            type = 'inform',
        })
        return
    end
    
    local options = {}
    
    for _, violationId in ipairs(status.activeViolations) do
        local label = violationId:gsub('_', ' '):gsub('^%l', string.upper)
        
        table.insert(options, {
            title = label,
            description = 'Click to address this violation',
            icon = 'exclamation-triangle',
            iconColor = '#e74c3c',
            onSelect = function()
                fixViolation(violationId)
            end,
        })
    end
    
    lib.registerContext({
        id = 'violations_menu',
        title = 'Active Violations',
        options = options,
    })
    
    lib.showContext('violations_menu')
end

--- Fix a specific violation
---@param violationId string
local function fixViolation(violationId)
    if isCleaning then return end
    
    isCleaning = true
    
    -- Determine action based on violation type
    local duration = 10000
    local label = 'Addressing violation...'
    
    if violationId == 'fire_hazard' then
        label = 'Removing fire hazards...'
        duration = 15000
    elseif violationId == 'expired_food' then
        label = 'Disposing expired food...'
        duration = 8000
    elseif violationId == 'cleanliness' then
        label = 'Deep cleaning...'
        duration = 12000
    end
    
    lib.requestAnimDict('timetable@floyd@clean_kitchen@base')
    
    local success = lib.progressCircle({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            combat = true,
        },
        anim = {
            dict = 'timetable@floyd@clean_kitchen@base',
            clip = 'base',
            flag = 49,
        },
    })
    
    isCleaning = false
    ClearPedTasks(cache.ped)
    
    if success then
        local result = lib.callback.await('free-restaurants:server:fixViolation', false, violationId)
        
        if result then
            lib.notify({
                title = 'Violation Fixed',
                description = 'The issue has been addressed!',
                type = 'success',
            })
        end
    end
end

-- ============================================================================
-- INSPECTION DISPLAY
-- ============================================================================

--- Show inspection result
---@param result table
local function showInspectionResult(result)
    -- Build violations text
    local violationsText = ''
    if result.violations and #result.violations > 0 then
        violationsText = '\n\n**Violations Found:**\n'
        for _, v in ipairs(result.violations) do
            violationsText = violationsText .. ('• %s (-%d pts)\n'):format(v.label, v.points)
        end
    end
    
    -- Build bonuses text
    local bonusesText = ''
    if result.bonuses and #result.bonuses > 0 then
        bonusesText = '\n\n**Commendations:**\n'
        for _, b in ipairs(result.bonuses) do
            bonusesText = bonusesText .. ('• %s (+%d pts)\n'):format(b.label, b.points)
        end
    end
    
    -- Determine icon color
    local iconColor = '#27ae60' -- Green
    if result.grade == 'B' then iconColor = '#2ecc71'
    elseif result.grade == 'C' then iconColor = '#f39c12'
    elseif result.grade == 'D' then iconColor = '#e67e22'
    elseif result.grade == 'F' then iconColor = '#e74c3c'
    end
    
    lib.alertDialog({
        header = ('Health Inspection - Grade %s'):format(result.grade),
        content = ('**Score: %d/100**\n\n%s%s%s'):format(
            result.score,
            result.notes or '',
            violationsText,
            bonusesText
        ),
        centered = true,
        size = 'lg',
    })
end

--- Show current inspection status
local function showInspectionStatus()
    local status = lib.callback.await('free-restaurants:server:getInspectionStatus', false)
    
    if not status then
        lib.notify({
            title = 'Error',
            description = 'Could not get inspection status.',
            type = 'error',
        })
        return
    end
    
    local gradeText = status.lastGrade and ('Last Grade: **%s** (%d/100)'):format(status.lastGrade, status.lastScore or 0) or 'No inspections yet'
    
    local violationsText = ''
    if status.activeViolations and #status.activeViolations > 0 then
        violationsText = '\n\n**Active Violations:** ' .. #status.activeViolations
    end
    
    local options = {
        {
            title = 'Inspection Status',
            description = gradeText,
            icon = 'clipboard-check',
            disabled = true,
        },
        {
            title = 'Cleanliness Score',
            description = ('%d/100'):format(status.currentScore or 100),
            icon = 'broom',
            disabled = true,
        },
    }
    
    if status.activeViolations and #status.activeViolations > 0 then
        table.insert(options, {
            title = ('Fix Violations (%d)'):format(#status.activeViolations),
            description = 'Address active violations',
            icon = 'tools',
            iconColor = '#e74c3c',
            onSelect = function()
                showViolationsMenu()
            end,
        })
    end
    
    table.insert(options, {
        title = 'View Inspection History',
        icon = 'history',
        onSelect = function()
            showInspectionHistory()
        end,
    })
    
    lib.registerContext({
        id = 'inspection_status',
        title = 'Health & Safety',
        options = options,
    })
    
    lib.showContext('inspection_status')
end

--- Show inspection history
local function showInspectionHistory()
    local history = lib.callback.await('free-restaurants:server:getInspectionHistory', false, nil, 5)
    
    if not history or #history == 0 then
        lib.notify({
            title = 'No History',
            description = 'No inspection history found.',
            type = 'inform',
        })
        return
    end
    
    local options = {}
    
    for _, inspection in ipairs(history) do
        local icon = 'check-circle'
        local color = '#27ae60'
        
        if inspection.grade == 'B' then color = '#2ecc71'
        elseif inspection.grade == 'C' then color = '#f39c12'; icon = 'exclamation-circle'
        elseif inspection.grade == 'D' then color = '#e67e22'; icon = 'exclamation-triangle'
        elseif inspection.grade == 'F' then color = '#e74c3c'; icon = 'times-circle'
        end
        
        table.insert(options, {
            title = ('Grade %s - %d/100'):format(inspection.grade, inspection.score),
            description = inspection.inspected_at or 'Unknown date',
            icon = icon,
            iconColor = color,
        })
    end
    
    lib.registerContext({
        id = 'inspection_history',
        title = 'Inspection History',
        menu = 'inspection_status',
        options = options,
    })
    
    lib.showContext('inspection_history')
end

-- ============================================================================
-- TARGET SETUP
-- ============================================================================

--- Setup cleaning targets for a location
---@param locationKey string
---@param locationData table
local function setupCleaningTargets(locationKey, locationData)
    -- Add cleaning option to all stations
    if locationData.stations then
        for stationKey, stationData in pairs(locationData.stations) do
            -- Add to existing station targets
            table.insert(cleaningTargets, {
                location = locationKey,
                station = stationKey,
            })
        end
    end
    
    -- Add general cleaning zone if defined
    if locationData.cleaningArea then
        exports.ox_target:addBoxZone({
            name = ('%s_cleaning_area'):format(locationKey),
            coords = locationData.cleaningArea.coords,
            size = locationData.cleaningArea.size or vec3(2.0, 2.0, 2.0),
            rotation = 0,
            debug = Config.Debug,
            options = {
                {
                    name = 'clean_area',
                    label = 'Clean Area',
                    icon = 'fa-solid fa-broom',
                    canInteract = function()
                        return FreeRestaurants.Client.IsOnDuty()
                    end,
                    onSelect = function()
                        cleanArea(locationKey)
                    end,
                },
                {
                    name = 'check_inspection',
                    label = 'View Health Status',
                    icon = 'fa-solid fa-clipboard-check',
                    canInteract = function()
                        return FreeRestaurants.Client.IsOnDuty()
                    end,
                    onSelect = function()
                        showInspectionStatus()
                    end,
                },
            },
        })
    end
end

--- Remove cleaning targets
---@param locationKey string
local function removeCleaningTargets(locationKey)
    exports.ox_target:removeZone(('%s_cleaning_area'):format(locationKey))
    
    -- Remove tracked targets for this location
    for i = #cleaningTargets, 1, -1 do
        if cleaningTargets[i].location == locationKey then
            table.remove(cleaningTargets, i)
        end
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

RegisterNetEvent('free-restaurants:client:enteredRestaurant', function(locationKey, locationData)
    setupCleaningTargets(locationKey, locationData)
end)

RegisterNetEvent('free-restaurants:client:exitedRestaurant', function(locationKey)
    removeCleaningTargets(locationKey)
end)

RegisterNetEvent('free-restaurants:client:inspectionResult', function(result)
    showInspectionResult(result)
end)

-- Command to check inspection status
RegisterCommand('inspectionstatus', function()
    if FreeRestaurants.Client.IsOnDuty() then
        showInspectionStatus()
    else
        lib.notify({
            title = 'Not On Duty',
            description = 'You must be on duty to check inspection status.',
            type = 'error',
        })
    end
end, false)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('CleanStation', cleanStation)
exports('CleanArea', cleanArea)
exports('ShowViolationsMenu', showViolationsMenu)
exports('ShowInspectionStatus', showInspectionStatus)

FreeRestaurants.Utils.Debug('client/cleaning.lua loaded')
