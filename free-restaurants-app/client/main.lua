--[[
    Food Hub - Restaurant App Client
    LB Phone/Tablet Integration
]]

local isAppOpen = false
local currentView = 'customer' -- 'customer' or 'employee'
local phoneType = nil -- 'phone' or 'tablet'

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Check if player is a restaurant employee
---@return boolean
local function isRestaurantEmployee()
    local PlayerData = exports.qbx_core:GetPlayerData()
    if not PlayerData or not PlayerData.job then return false end

    -- Check against free-restaurants Config.Jobs
    local restaurantJobs = exports['free-restaurants']:GetRestaurantJobs()
    if restaurantJobs and restaurantJobs[PlayerData.job.name] then
        return true
    end

    return false
end

--- Check if player is in a restaurant zone
---@return boolean, string|nil locationKey
local function isInRestaurantZone()
    local location, locationData = exports['free-restaurants']:GetCurrentLocation()
    return location ~= nil, location
end

--- Get employee access information
---@return table
local function getEmployeeAccess()
    local PlayerData = exports.qbx_core:GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return {
            isEmployee = false,
            canAccessEmployee = false,
        }
    end

    local job = PlayerData.job.name
    local grade = PlayerData.job.grade.level
    local onduty = PlayerData.job.onduty
    local inZone, locationKey = isInRestaurantZone()
    local isEmployee = isRestaurantEmployee()

    -- Check if can access employee features
    local canAccessEmployee = isEmployee
    if Config.App.requireOnDutyForEmployee then
        canAccessEmployee = canAccessEmployee and onduty
    end
    if Config.App.requireZoneForEmployee then
        canAccessEmployee = canAccessEmployee and inZone
    end

    return {
        isEmployee = isEmployee,
        job = job,
        jobLabel = PlayerData.job.label,
        grade = grade,
        gradeLabel = PlayerData.job.grade.name,
        onduty = onduty,
        inZone = inZone,
        locationKey = locationKey,
        canAccessEmployee = canAccessEmployee,
        canManage = grade >= Config.App.minGradeForManagement,
        canToggleStatus = grade >= Config.App.minGradeForStatusToggle,
    }
end

--- Get player info for the app
---@return table
local function getPlayerInfo()
    local PlayerData = exports.qbx_core:GetPlayerData()
    if not PlayerData then return {} end

    return {
        name = ('%s %s'):format(PlayerData.charinfo.firstname, PlayerData.charinfo.lastname),
        phone = PlayerData.charinfo.phone,
        citizenid = PlayerData.citizenid,
    }
end

-- ============================================================================
-- LB PHONE/TABLET REGISTRATION
-- ============================================================================

local function registerApp()
    -- Try to register with LB Phone
    local phoneSuccess = false
    local tabletSuccess = false

    -- Register with LB Phone
    if GetResourceState('lb-phone') == 'started' then
        local success, err = exports['lb-phone']:AddCustomApp({
            identifier = Config.App.identifier,
            name = Config.App.name,
            description = Config.App.description,
            defaultApp = Config.App.defaultApp,
            size = Config.App.size,
            ui = GetCurrentResourceName() .. '/ui/dist/index.html',
            icon = 'https://cfx-nui-' .. GetCurrentResourceName() .. '/ui/dist/app-icon.png',

            onOpen = function(data)
                isAppOpen = true
                phoneType = 'phone'
                openApp()
            end,

            onClose = function()
                isAppOpen = false
                closeApp()
            end,
        })

        if success then
            phoneSuccess = true
            if Config.Debug then
                print('[Food Hub] Registered with LB Phone')
            end
        else
            print('[Food Hub] Failed to register with LB Phone: ' .. tostring(err))
        end
    end

    -- Register with LB Tablet
    if GetResourceState('lb-tablet') == 'started' then
        local success, err = exports['lb-tablet']:AddCustomApp({
            identifier = Config.App.identifier,
            name = Config.App.name,
            description = Config.App.description,
            defaultApp = Config.App.defaultApp,
            size = Config.App.size,
            ui = GetCurrentResourceName() .. '/ui/dist/index.html',
            icon = 'https://cfx-nui-' .. GetCurrentResourceName() .. '/ui/dist/app-icon.png',

            onOpen = function(data)
                isAppOpen = true
                phoneType = 'tablet'
                openApp()
            end,

            onClose = function()
                isAppOpen = false
                closeApp()
            end,
        })

        if success then
            tabletSuccess = true
            if Config.Debug then
                print('[Food Hub] Registered with LB Tablet')
            end
        else
            print('[Food Hub] Failed to register with LB Tablet: ' .. tostring(err))
        end
    end

    return phoneSuccess or tabletSuccess
end

-- ============================================================================
-- APP OPEN/CLOSE
-- ============================================================================

function openApp()
    local access = getEmployeeAccess()
    local player = getPlayerInfo()

    -- Determine initial view
    if access.canAccessEmployee then
        currentView = 'employee'
    else
        currentView = 'customer'
    end

    -- Send initial data to UI
    sendToUI('appOpened', {
        view = currentView,
        access = access,
        player = player,
        config = {
            statuses = Config.OrderStatuses,
            restaurantTypes = Config.RestaurantTypes,
            features = {
                customerOrdering = Config.App.enableCustomerOrdering,
                deliveryTracking = Config.App.enableDeliveryTracking,
                employeeManagement = Config.App.enableEmployeeManagement,
                pickupOrders = Config.App.enablePickupOrders,
                deliveryOrders = Config.App.enableDeliveryOrders,
            },
            delivery = {
                maxDistance = Config.App.maxDeliveryDistance,
                baseFee = Config.App.baseDeliveryFee,
                feePerKm = Config.App.deliveryFeePerKm,
            },
        },
    })
end

function closeApp()
    sendToUI('appClosed', {})
end

-- ============================================================================
-- NUI COMMUNICATION
-- ============================================================================

--- Send message to UI (handles both phone types)
---@param event string
---@param data table
function sendToUI(event, data)
    local message = {
        type = event,
        data = data,
    }

    if phoneType == 'phone' and GetResourceState('lb-phone') == 'started' then
        exports['lb-phone']:SendCustomAppMessage(Config.App.identifier, message)
    elseif phoneType == 'tablet' and GetResourceState('lb-tablet') == 'started' then
        exports['lb-tablet']:SendCustomAppMessage(Config.App.identifier, message)
    else
        -- Fallback to standard NUI
        SendNUIMessage(message)
    end
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

-- Get open restaurants
RegisterNUICallback('getRestaurants', function(data, cb)
    local restaurants = lib.callback.await('free-restaurants-app:getOpenRestaurants', false)
    cb(restaurants or {})
end)

-- Get restaurant menu
RegisterNUICallback('getMenu', function(data, cb)
    local menu = lib.callback.await('free-restaurants-app:getRestaurantMenu', false, data.restaurantId)
    cb(menu or {})
end)

-- Place order
RegisterNUICallback('placeOrder', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    data.deliveryCoords = { x = coords.x, y = coords.y, z = coords.z }

    local result = lib.callback.await('free-restaurants-app:placeOrder', false, data)
    cb(result)
end)

-- Get customer orders
RegisterNUICallback('getMyOrders', function(data, cb)
    local orders = lib.callback.await('free-restaurants-app:getCustomerOrders', false)
    cb(orders or {})
end)

-- Get employee dashboard
RegisterNUICallback('getEmployeeDashboard', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canAccessEmployee then
        cb({ error = 'No access' })
        return
    end

    local dashboard = lib.callback.await('free-restaurants-app:getEmployeeDashboard', false, access.job)
    cb(dashboard or {})
end)

-- Get on-duty staff
RegisterNUICallback('getOnDutyStaff', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canAccessEmployee then
        cb({ error = 'No access' })
        return
    end

    local staff = lib.callback.await('free-restaurants-app:getOnDutyStaff', false, access.job)
    cb(staff or {})
end)

-- Toggle restaurant status
RegisterNUICallback('toggleRestaurantStatus', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canToggleStatus then
        cb({ success = false, error = 'Insufficient permissions' })
        return
    end

    local result = lib.callback.await('free-restaurants-app:setRestaurantStatus', false, data)
    cb(result)
end)

-- Get available deliveries
RegisterNUICallback('getAvailableDeliveries', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canAccessEmployee then
        cb({ error = 'No access' })
        return
    end

    local deliveries = lib.callback.await('free-restaurants-app:getAvailableDeliveries', false, access.job)
    cb(deliveries or {})
end)

-- Accept delivery
RegisterNUICallback('acceptDelivery', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canAccessEmployee or not access.inZone then
        cb({ success = false, error = 'Must be on duty and in restaurant zone' })
        return
    end

    local result = lib.callback.await('free-restaurants-app:acceptDelivery', false, data.orderId)
    cb(result)
end)

-- Get catering orders
RegisterNUICallback('getCateringOrders', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canAccessEmployee then
        cb({ error = 'No access' })
        return
    end

    local orders = lib.callback.await('free-restaurants-app:getCateringOrders', false, access.job)
    cb(orders or {})
end)

-- Get pending app orders (for employees)
RegisterNUICallback('getPendingOrders', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canAccessEmployee then
        cb({ error = 'No access' })
        return
    end

    local orders = lib.callback.await('free-restaurants-app:getPendingAppOrders', false, access.job)
    cb(orders or {})
end)

-- Accept/reject app order
RegisterNUICallback('handleAppOrder', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canAccessEmployee then
        cb({ success = false, error = 'No access' })
        return
    end

    local result = lib.callback.await('free-restaurants-app:handleAppOrder', false, data)
    cb(result)
end)

-- Call customer
RegisterNUICallback('callCustomer', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canAccessEmployee then
        cb({ success = false })
        return
    end

    -- Use LB Phone to start call
    if GetResourceState('lb-phone') == 'started' and data.phone then
        exports['lb-phone']:StartCall(data.phone)
        cb({ success = true })
    else
        cb({ success = false, error = 'Phone not available' })
    end
end)

-- Message customer
RegisterNUICallback('messageCustomer', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canAccessEmployee then
        cb({ success = false })
        return
    end

    local result = lib.callback.await('free-restaurants-app:messageCustomer', false, data)
    cb(result)
end)

-- Get access info (for view switching)
RegisterNUICallback('getAccessInfo', function(data, cb)
    local access = getEmployeeAccess()
    local player = getPlayerInfo()
    cb({
        access = access,
        player = player,
    })
end)

-- Switch view
RegisterNUICallback('switchView', function(data, cb)
    local access = getEmployeeAccess()

    if data.view == 'employee' and not access.canAccessEmployee then
        cb({ success = false, error = 'Cannot access employee view' })
        return
    end

    currentView = data.view
    cb({ success = true, view = currentView })
end)

-- Close app from UI
RegisterNUICallback('closeApp', function(data, cb)
    if phoneType == 'phone' and GetResourceState('lb-phone') == 'started' then
        exports['lb-phone']:CloseApp()
    elseif phoneType == 'tablet' and GetResourceState('lb-tablet') == 'started' then
        exports['lb-tablet']:CloseApp()
    end
    cb({ success = true })
end)

-- ============================================================================
-- EVENTS
-- ============================================================================

-- Order status update from server
RegisterNetEvent('free-restaurants-app:orderStatusUpdate', function(data)
    if isAppOpen then
        sendToUI('orderStatusUpdate', data)
    end

    -- Show notification
    if Config.App.notifyOnStatusChange then
        local status = Config.OrderStatuses[data.status]
        lib.notify({
            title = 'Order Update',
            description = ('Order #%s: %s'):format(data.orderId, status and status.label or data.status),
            type = 'inform',
            duration = 5000,
        })
    end
end)

-- New order notification for employees
RegisterNetEvent('free-restaurants-app:newOrderReceived', function(data)
    if isAppOpen and currentView == 'employee' then
        sendToUI('newOrderReceived', data)
    end

    if Config.App.notifyOnNewOrder then
        lib.notify({
            title = 'New App Order',
            description = ('New %s order received!'):format(data.orderType),
            type = 'inform',
            duration = 8000,
        })

        if Config.App.soundOnNewOrder then
            PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
        end
    end
end)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    -- Wait for phone resources to start
    Wait(2000)

    -- Register the app
    local success = registerApp()

    if success then
        print('[Food Hub] App registered successfully')
    else
        print('[Food Hub] Warning: Could not register with LB Phone or LB Tablet')
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Remove app from phone
    if GetResourceState('lb-phone') == 'started' then
        exports['lb-phone']:RemoveCustomApp(Config.App.identifier)
    end

    if GetResourceState('lb-tablet') == 'started' then
        exports['lb-tablet']:RemoveCustomApp(Config.App.identifier)
    end
end)

print('[Food Hub] client/main.lua loaded')
