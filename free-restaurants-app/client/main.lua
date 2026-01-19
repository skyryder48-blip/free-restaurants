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
    print('[Food Hub] openApp() called')
    local access = getEmployeeAccess()
    local player = getPlayerInfo()

    -- Determine initial view
    if access.canAccessEmployee then
        currentView = 'employee'
    else
        currentView = 'customer'
    end

    print('[Food Hub] Sending appOpened event to UI, view=' .. currentView)
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

    if Config.Debug then
        print(('[Food Hub] sendToUI event=%s phoneType=%s'):format(event, tostring(phoneType)))
    end

    if phoneType == 'phone' and GetResourceState('lb-phone') == 'started' then
        if Config.Debug then
            print('[Food Hub] Sending via lb-phone SendCustomAppMessage')
        end
        exports['lb-phone']:SendCustomAppMessage(Config.App.identifier, message)
    elseif phoneType == 'tablet' and GetResourceState('lb-tablet') == 'started' then
        if Config.Debug then
            print('[Food Hub] Sending via lb-tablet SendCustomAppMessage')
        end
        exports['lb-tablet']:SendCustomAppMessage(Config.App.identifier, message)
    else
        if Config.Debug then
            print('[Food Hub] Sending via standard SendNUIMessage (fallback)')
        end
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
-- MANAGEMENT CALLBACKS
-- ============================================================================

-- Get employees list
RegisterNUICallback('getEmployees', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({ error = 'No access' })
        return
    end

    local employees = lib.callback.await('free-restaurants:server:getEmployees', false, access.job)
    cb(employees or {})
end)

-- Get job grades
RegisterNUICallback('getJobGrades', function(data, cb)
    local access = getEmployeeAccess()
    if not access.isEmployee then
        cb({})
        return
    end

    -- Get grades from config
    local jobConfig = exports['free-restaurants']:GetRestaurantJobs()
    local job = jobConfig and jobConfig[access.job]
    local grades = {}

    if job and job.grades then
        for level, gradeData in pairs(job.grades) do
            table.insert(grades, {
                level = level,
                name = gradeData.name or gradeData.label or ('Grade ' .. level),
                payment = gradeData.payment,
            })
        end
        table.sort(grades, function(a, b) return a.level < b.level end)
    else
        -- Default grades if not configured
        grades = {
            { level = 0, name = 'Trainee' },
            { level = 1, name = 'Worker' },
            { level = 2, name = 'Chef' },
            { level = 3, name = 'Shift Manager' },
            { level = 4, name = 'Assistant Manager' },
            { level = 5, name = 'Owner' },
        }
    end

    cb(grades)
end)

-- Get nearby players for hiring
RegisterNUICallback('getNearbyPlayers', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({})
        return
    end

    local players = lib.callback.await('free-restaurants:server:getNearbyPlayers', false, 10.0)
    cb(players or {})
end)

-- Hire employee
RegisterNUICallback('hireEmployee', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({ success = false, error = 'No permission' })
        return
    end

    local result = lib.callback.await('free-restaurants:server:hireEmployee', false, data.playerId, access.job, data.grade)
    cb({ success = result })
end)

-- Fire employee
RegisterNUICallback('fireEmployee', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({ success = false, error = 'No permission' })
        return
    end

    local result = lib.callback.await('free-restaurants:server:fireEmployee', false, data.citizenid, access.job)
    cb({ success = result })
end)

-- Set employee grade (promote/demote)
RegisterNUICallback('setEmployeeGrade', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({ success = false, error = 'No permission' })
        return
    end

    local result = lib.callback.await('free-restaurants:server:setEmployeeGrade', false, data.citizenid, access.job, data.grade)
    cb({ success = result })
end)

-- Get finances
RegisterNUICallback('getFinances', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({ error = 'No access' })
        return
    end

    local finances = lib.callback.await('free-restaurants:server:getFinances', false, access.job)
    cb(finances or {})
end)

-- Get transactions
RegisterNUICallback('getTransactions', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({})
        return
    end

    local transactions = lib.callback.await('free-restaurants:server:getTransactions', false, access.job)
    cb(transactions or {})
end)

-- Withdraw funds
RegisterNUICallback('withdrawFunds', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({ success = false, error = 'No permission' })
        return
    end

    local result = lib.callback.await('free-restaurants:server:withdrawFunds', false, access.job, data.amount)
    cb({ success = result })
end)

-- Deposit funds
RegisterNUICallback('depositFunds', function(data, cb)
    local access = getEmployeeAccess()
    if not access.isEmployee then
        cb({ success = false, error = 'No permission' })
        return
    end

    local result = lib.callback.await('free-restaurants:server:depositFunds', false, access.job, data.amount)
    cb({ success = result })
end)

-- Get pricing
RegisterNUICallback('getPricing', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({})
        return
    end

    local pricing = lib.callback.await('free-restaurants:server:getPricing', false, access.job)

    -- Transform pricing data for UI
    local items = {}
    if pricing then
        for itemId, priceData in pairs(pricing) do
            table.insert(items, {
                itemId = itemId,
                name = itemId, -- Will be replaced with proper name from config
                category = 'Menu',
                basePrice = priceData.basePrice or priceData.price,
                currentPrice = priceData.price,
            })
        end
    end

    cb(items)
end)

-- Set price
RegisterNUICallback('setPrice', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({ success = false, error = 'No permission' })
        return
    end

    local result = lib.callback.await('free-restaurants:server:setPrice', false, access.job, data.itemId, data.price)
    cb({ success = result })
end)

-- Get stock items
RegisterNUICallback('getStockItems', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({})
        return
    end

    local items = lib.callback.await('free-restaurants:server:getStockItems', false, access.job)
    cb(items or {})
end)

-- Get active stock orders
RegisterNUICallback('getActiveStockOrders', function(data, cb)
    local access = getEmployeeAccess()
    if not access.isEmployee then
        cb({})
        return
    end

    local orders = lib.callback.await('free-restaurants:server:getActiveStockOrders', false, access.job)
    cb(orders or {})
end)

-- Order stock
RegisterNUICallback('orderStock', function(data, cb)
    local access = getEmployeeAccess()
    if not access.canManage then
        cb({ success = false, error = 'No permission' })
        return
    end

    local success, orderId = lib.callback.await('free-restaurants:server:orderStock', false, access.job, data.itemName, data.quantity)
    cb({ success = success, orderId = orderId })
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
-- DELIVERY TRACKING
-- ============================================================================

local activeDeliveryBlip = nil
local activeDeliveryData = nil
local activeDeliveryCoords = nil
local deliveryArrivalRadius = 15.0 -- Distance in meters to trigger arrival
local arrivedAtDelivery = false -- Flag for when driver has arrived

-- Start delivery - set GPS waypoint
RegisterNetEvent('free-restaurants-app:startDelivery', function(data)
    activeDeliveryData = data
    arrivedAtDelivery = false

    -- Parse delivery coords
    local coords = nil
    if data.deliveryCoords and type(data.deliveryCoords) == 'string' then
        local x, y, z = data.deliveryCoords:match('([^,]+),([^,]+),([^,]+)')
        if x and y and z then
            coords = vector3(tonumber(x), tonumber(y), tonumber(z))
        end
    elseif data.deliveryCoords and type(data.deliveryCoords) == 'table' then
        coords = vector3(data.deliveryCoords.x, data.deliveryCoords.y, data.deliveryCoords.z)
    end

    if not coords then
        lib.notify({
            title = 'Delivery Error',
            description = 'Could not get delivery location',
            type = 'error',
        })
        return
    end

    -- Store coords for proximity check
    activeDeliveryCoords = coords

    -- Remove old blip if exists
    if activeDeliveryBlip then
        RemoveBlip(activeDeliveryBlip)
    end

    -- Create delivery blip
    activeDeliveryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(activeDeliveryBlip, 1) -- Standard waypoint
    SetBlipDisplay(activeDeliveryBlip, 4)
    SetBlipScale(activeDeliveryBlip, 1.0)
    SetBlipColour(activeDeliveryBlip, 5) -- Yellow
    SetBlipAsShortRange(activeDeliveryBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Delivery: ' .. (data.customerName or 'Customer'))
    EndTextCommandSetBlipName(activeDeliveryBlip)

    -- Set waypoint
    SetNewWaypoint(coords.x, coords.y)

    -- Notify driver
    lib.notify({
        title = 'Delivery Started',
        description = ('Deliver to %s\nGPS waypoint has been set'):format(data.customerName or 'customer'),
        type = 'success',
        duration = 8000,
    })

    if Config.Debug then
        print(('[Food Hub] Delivery started to %s at coords: %s'):format(
            data.customerName or 'unknown',
            data.deliveryCoords
        ))
    end
end)

-- Monitor delivery arrival
CreateThread(function()
    while true do
        Wait(1000) -- Check every second

        if activeDeliveryCoords and activeDeliveryData and not arrivedAtDelivery then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - activeDeliveryCoords)

            if distance <= deliveryArrivalRadius then
                -- Player has arrived at delivery location
                arrivedAtDelivery = true

                -- Clear the blip
                if activeDeliveryBlip then
                    RemoveBlip(activeDeliveryBlip)
                    activeDeliveryBlip = nil
                end
                activeDeliveryCoords = nil

                -- Clear waypoint
                SetWaypointOff()

                -- Notify driver to confirm in app
                lib.notify({
                    title = 'Arrived at Delivery',
                    description = 'Open the Food Hub app to confirm delivery',
                    type = 'success',
                    duration = 10000,
                })

                -- Play sound
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

                if Config.Debug then
                    print(('[Food Hub] Driver arrived at delivery location for order %s'):format(activeDeliveryData.orderId))
                end
            end
        end
    end
end)

-- Complete delivery - triggered from server after confirmation
RegisterNetEvent('free-restaurants-app:completeDelivery', function(orderId)
    if activeDeliveryBlip then
        RemoveBlip(activeDeliveryBlip)
        activeDeliveryBlip = nil
    end
    activeDeliveryData = nil
    activeDeliveryCoords = nil
    arrivedAtDelivery = false

    lib.notify({
        title = 'Delivery Complete',
        description = 'Order delivered successfully!',
        type = 'success',
    })
end)

-- Cancel/clear active delivery
RegisterNetEvent('free-restaurants-app:clearDelivery', function()
    if activeDeliveryBlip then
        RemoveBlip(activeDeliveryBlip)
        activeDeliveryBlip = nil
    end
    activeDeliveryData = nil
    activeDeliveryCoords = nil
    arrivedAtDelivery = false
end)

-- NUI callback for confirming delivery in app
RegisterNUICallback('confirmDelivery', function(data, cb)
    if not activeDeliveryData then
        cb({ success = false, error = 'No active delivery' })
        return
    end

    if not arrivedAtDelivery then
        cb({ success = false, error = 'You have not arrived at the delivery location yet' })
        return
    end

    -- Complete the delivery on server
    TriggerServerEvent('free-restaurants-app:server:completeDelivery', activeDeliveryData.orderId)

    -- Clear local state
    activeDeliveryData = nil
    arrivedAtDelivery = false

    cb({ success = true })
end)

-- NUI callback to get current delivery status
RegisterNUICallback('getActiveDelivery', function(data, cb)
    if activeDeliveryData then
        cb({
            hasDelivery = true,
            orderId = activeDeliveryData.orderId,
            customerName = activeDeliveryData.customerName,
            arrivedAtLocation = arrivedAtDelivery,
        })
    else
        cb({ hasDelivery = false })
    end
end)

-- Staff message notification (fallback when lb-phone not available)
RegisterNetEvent('free-restaurants-app:staffMessage', function(data)
    -- Get restaurant name
    local restaurantJobs = exports['free-restaurants']:GetRestaurantJobs()
    local restaurantName = restaurantJobs and restaurantJobs[data.restaurantJob] and
        restaurantJobs[data.restaurantJob].label or data.restaurantJob

    lib.notify({
        title = ('Message from %s'):format(restaurantName),
        description = ('%s: %s'):format(data.staffName or 'Staff', data.message),
        type = 'inform',
        duration = 10000,
        icon = 'comment',
    })

    -- Play notification sound
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
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
