--[[
    free-restaurants lb-tablet Integration
    
    Provides a custom tablet app for restaurant management featuring:
    - Dashboard with real-time stats
    - Order queue management
    - Employee management
    - Financial overview
    - Delivery tracking
    - Inventory levels
    
    DEPENDENCIES:
    - lb-tablet (optional - gracefully handles missing)
    - client/main.lua
    - server callbacks
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local isTabletAvailable = false
local appIdentifier = 'restaurant-manager'
local refreshInterval = 5000 -- ms between data refreshes
local refreshThread = nil

-- ============================================================================
-- TABLET AVAILABILITY CHECK
-- ============================================================================

--- Check if lb-tablet is available
---@return boolean
local function checkTabletAvailability()
    local resourceState = GetResourceState('lb-tablet')
    return resourceState == 'started'
end

-- ============================================================================
-- APP REGISTRATION
-- ============================================================================

--- Register the restaurant manager app with lb-tablet
local function registerApp()
    if not isTabletAvailable then return end
    
    local success, err = pcall(function()
        exports['lb-tablet']:AddCustomApp({
            identifier = appIdentifier,
            name = 'Kitchen Manager',
            description = 'Restaurant management and order tracking',
            ui = ('nui://%s/lb-tablet-app/ui/index.html'):format(GetCurrentResourceName()),
            icon = ('nui://%s/lb-tablet-app/ui/icon.png'):format(GetCurrentResourceName()),
            developer = 'Free Restaurants',
            defaultApp = false,
            size = { width = 600, height = 800 },
        })
    end)
    
    if success then
        FreeRestaurants.Utils.Debug('lb-tablet app registered successfully')
    else
        FreeRestaurants.Utils.Error('Failed to register lb-tablet app: ' .. tostring(err))
    end
end

-- ============================================================================
-- DATA GATHERING
-- ============================================================================

--- Get comprehensive restaurant data for tablet display
---@return table
local function getRestaurantData()
    local playerState = FreeRestaurants.Client.GetPlayerState()
    local job = playerState.job
    
    if not job or not Config.Jobs[job] then
        return { error = 'Not employed at a restaurant' }
    end
    
    -- Gather all data
    local data = {
        job = job,
        jobLabel = Config.Jobs[job].label,
        grade = playerState.grade,
        isOnDuty = playerState.isOnDuty,
        currentLocation = playerState.currentLocation,
    }
    
    -- Get financial data
    local finances = lib.callback.await('free-restaurants:server:getFinances', false, job)
    if finances then
        data.finances = finances
    end
    
    -- Get orders
    local orders = lib.callback.await('free-restaurants:server:getOrders', false, job)
    if orders then
        data.orders = orders
        data.orderCounts = {
            pending = 0,
            inProgress = 0,
            ready = 0,
        }
        for _, order in ipairs(orders) do
            if order.status == 'pending' then
                data.orderCounts.pending = data.orderCounts.pending + 1
            elseif order.status == 'in_progress' then
                data.orderCounts.inProgress = data.orderCounts.inProgress + 1
            elseif order.status == 'ready' then
                data.orderCounts.ready = data.orderCounts.ready + 1
            end
        end
    end
    
    -- Get employees (if manager)
    local gradeData = Config.Jobs[job].grades[playerState.grade]
    if gradeData and (gradeData.permissions.canHire or gradeData.permissions.all) then
        local employees = lib.callback.await('free-restaurants:server:getEmployees', false, job)
        if employees then
            data.employees = employees
            data.employeeCounts = {
                total = #employees,
                onDuty = 0,
                online = 0,
            }
            for _, emp in ipairs(employees) do
                if emp.onDuty then data.employeeCounts.onDuty = data.employeeCounts.onDuty + 1 end
                if emp.online then data.employeeCounts.online = data.employeeCounts.online + 1 end
            end
        end
    end
    
    -- Get deliveries
    local deliveries = lib.callback.await('free-restaurants:server:getAvailableDeliveries', false, job)
    if deliveries then
        data.deliveries = deliveries
    end
    
    -- Get player's active delivery
    local myDelivery = lib.callback.await('free-restaurants:server:getMyDelivery', false)
    if myDelivery then
        data.activeDelivery = myDelivery
    end
    
    -- Get progression
    local progression = lib.callback.await('free-restaurants:server:getProgression', false)
    if progression then
        data.progression = progression
    end
    
    -- Get health inspection status
    local inspection = lib.callback.await('free-restaurants:server:getInspectionStatus', false, job)
    if inspection then
        data.inspection = inspection
    end
    
    return data
end

--- Send data update to tablet app
local function sendDataToTablet()
    if not isTabletAvailable then return end
    
    local data = getRestaurantData()
    
    pcall(function()
        exports['lb-tablet']:SendCustomAppMessage(appIdentifier, {
            action = 'updateData',
            data = data,
        })
    end)
end

-- ============================================================================
-- APP MESSAGE HANDLERS
-- ============================================================================

--- Handle messages from the tablet app
---@param data table Message data
local function handleAppMessage(data)
    if not data or not data.action then return end
    
    local response = { success = false }
    
    if data.action == 'getData' then
        -- Initial data request
        response = getRestaurantData()
        response.success = true
        
    elseif data.action == 'clockIn' then
        local locationKey, locationData = FreeRestaurants.Client.GetCurrentLocation()
        if locationKey then
            TriggerEvent('free-restaurants:client:toggleDuty', locationKey, locationData)
            response.success = true
        else
            response.error = 'Not at a restaurant location'
        end
        
    elseif data.action == 'clockOut' then
        local locationKey, locationData = FreeRestaurants.Client.GetCurrentLocation()
        if locationKey then
            TriggerEvent('free-restaurants:client:toggleDuty', locationKey, locationData)
            response.success = true
        else
            response.error = 'Not at a restaurant location'
        end
        
    elseif data.action == 'startOrder' then
        local success = lib.callback.await('free-restaurants:server:startOrder', false, data.orderId)
        response.success = success
        
    elseif data.action == 'readyOrder' then
        local success = lib.callback.await('free-restaurants:server:readyOrder', false, data.orderId)
        response.success = success
        
    elseif data.action == 'completeOrder' then
        local success = lib.callback.await('free-restaurants:server:completeOrder', false, data.orderId)
        response.success = success
        
    elseif data.action == 'cancelOrder' then
        local success = lib.callback.await('free-restaurants:server:cancelOrder', false, data.orderId, data.reason)
        response.success = success
        
    elseif data.action == 'acceptDelivery' then
        local success = lib.callback.await('free-restaurants:server:acceptDelivery', false, data.deliveryId)
        response.success = success
        if success then
            -- Trigger client-side delivery tracking
            TriggerEvent('free-restaurants:client:deliveryAccepted', data.deliveryId)
        end
        
    elseif data.action == 'withdraw' then
        local playerState = FreeRestaurants.Client.GetPlayerState()
        local success = lib.callback.await('free-restaurants:server:withdrawFunds', false, playerState.job, data.amount)
        response.success = success
        
    elseif data.action == 'deposit' then
        local playerState = FreeRestaurants.Client.GetPlayerState()
        local success = lib.callback.await('free-restaurants:server:depositFunds', false, playerState.job, data.amount)
        response.success = success
        
    elseif data.action == 'setEmployeeGrade' then
        local playerState = FreeRestaurants.Client.GetPlayerState()
        local success = lib.callback.await('free-restaurants:server:setEmployeeGrade', false, data.citizenid, playerState.job, data.grade)
        response.success = success
        
    elseif data.action == 'fireEmployee' then
        local playerState = FreeRestaurants.Client.GetPlayerState()
        local success = lib.callback.await('free-restaurants:server:fireEmployee', false, data.citizenid, playerState.job)
        response.success = success
        
    elseif data.action == 'orderStock' then
        local playerState = FreeRestaurants.Client.GetPlayerState()
        local success = lib.callback.await('free-restaurants:server:orderStock', false, playerState.job, data.item, data.quantity)
        response.success = success
    end
    
    -- Send response back to tablet
    pcall(function()
        exports['lb-tablet']:SendCustomAppMessage(appIdentifier, {
            action = 'response',
            requestId = data.requestId,
            response = response,
        })
    end)
    
    -- Refresh data after any action
    if response.success then
        SetTimeout(500, sendDataToTablet)
    end
end

-- ============================================================================
-- REFRESH THREAD
-- ============================================================================

--- Start the data refresh thread
local function startRefreshThread()
    if refreshThread then return end
    
    refreshThread = CreateThread(function()
        while isTabletAvailable do
            Wait(refreshInterval)
            sendDataToTablet()
        end
    end)
end

--- Stop the refresh thread
local function stopRefreshThread()
    refreshThread = nil
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Resource start - register app
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Check if lb-tablet is available
    isTabletAvailable = checkTabletAvailability()
    
    if isTabletAvailable then
        -- Wait for tablet to fully initialize
        SetTimeout(2000, function()
            registerApp()
            startRefreshThread()
        end)
    else
        FreeRestaurants.Utils.Debug('lb-tablet not available, tablet features disabled')
    end
end)

-- lb-tablet started after us
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'lb-tablet' then return end
    
    isTabletAvailable = true
    SetTimeout(2000, function()
        registerApp()
        startRefreshThread()
    end)
end)

-- lb-tablet stopped
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= 'lb-tablet' then return end
    
    isTabletAvailable = false
    stopRefreshThread()
end)

-- Handle messages from tablet app
RegisterNUICallback('lb-tablet:' .. appIdentifier, function(data, cb)
    handleAppMessage(data)
    cb('ok')
end)

-- Alternative message handler (lb-tablet uses events in some versions)
RegisterNetEvent('lb-tablet:customAppMessage', function(identifier, data)
    if identifier ~= appIdentifier then return end
    handleAppMessage(data)
end)

-- Duty status changed - update tablet
RegisterNetEvent('free-restaurants:client:clockedIn', function()
    sendDataToTablet()
end)

RegisterNetEvent('free-restaurants:client:clockedOut', function()
    sendDataToTablet()
end)

-- New order - update tablet
RegisterNetEvent('free-restaurants:client:newOrder', function()
    sendDataToTablet()
end)

-- Order status changed - update tablet
RegisterNetEvent('free-restaurants:client:orderEvent', function()
    sendDataToTablet()
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsTabletAvailable', function() return isTabletAvailable end)
exports('SendTabletUpdate', sendDataToTablet)
exports('GetRestaurantData', getRestaurantData)

FreeRestaurants.Utils.Debug('client/tablet.lua loaded')
