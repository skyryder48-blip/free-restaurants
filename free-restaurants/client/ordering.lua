--[[
    free-restaurants Client Ordering System

    Handles:
    - Self-service kiosk interactions
    - Employee register operations
    - KDS (Kitchen Display System) rendering
    - Order flow from customer to kitchen
    - Receipt generation and display

    DEPENDENCIES:
    - client/main.lua (state management)
    - config/ordering.lua (ordering configurations)
    - ox_lib (UI components)
    - ox_target (interaction zones)
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local kiosks = {}                       -- Spawned kiosk props
local kdsMonitors = {}                  -- Spawned KDS monitor props
local kdsVisible = false                -- KDS overlay visibility
local kioskVisible = false              -- Kiosk overlay visibility
local currentLocation = nil             -- Current location key
local currentJob = nil                  -- Current job name

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get location menu for kiosk/register
---@param locationData table Location configuration
---@return table menu, table categories
local function getLocationMenu(locationData)
    local menu = {}
    local categories = {}
    local seenCategories = {}
    local restaurantType = locationData.restaurantType

    for recipeId, recipeData in pairs(Config.Recipes or {}) do
        if recipeData.restaurantType == restaurantType or recipeData.restaurantType == 'all' then
            if recipeData.sellable ~= false then
                table.insert(menu, {
                    id = recipeId,
                    label = recipeData.label,
                    description = recipeData.description or '',
                    price = recipeData.price or 0,
                    category = recipeData.category or 'Other',
                    icon = recipeData.icon,
                    customizations = recipeData.customizations,
                })

                if not seenCategories[recipeData.category] then
                    seenCategories[recipeData.category] = true
                    table.insert(categories, recipeData.category)
                end
            end
        end
    end

    table.sort(categories)

    return menu, categories
end

--- Get tax rate from config
---@return number taxRate
local function getTaxRate()
    if Config.Settings and Config.Settings.Economy then
        return Config.Settings.Economy.taxRate or 0
    end
    return 0
end

-- ============================================================================
-- KIOSK SYSTEM
-- ============================================================================

--- Open kiosk ordering interface
---@param locationKey string
---@param locationData table
local function openKiosk(locationKey, locationData)
    if kioskVisible then return end

    currentLocation = locationKey
    kioskVisible = true

    local menu, categories = getLocationMenu(locationData)

    SetNuiFocus(true, true)

    SendNUIMessage({
        type = 'kiosk:show',
        data = {
            restaurantName = locationData.label or 'Restaurant',
            locationKey = locationKey,
            menu = menu,
            categories = categories,
            taxRate = getTaxRate(),
        }
    })
end

--- Close kiosk interface
local function closeKiosk()
    if not kioskVisible then return end

    kioskVisible = false
    currentLocation = nil

    SetNuiFocus(false, false)

    SendNUIMessage({
        type = 'kiosk:hide',
        data = {}
    })
end

-- NUI Callbacks for Kiosk
RegisterNUICallback('kiosk:cancel', function(data, cb)
    closeKiosk()
    cb('ok')
end)

RegisterNUICallback('kiosk:placeOrder', function(data, cb)
    -- Process order through server
    local success, orderId, message = lib.callback.await(
        'free-restaurants:server:placeOrder',
        false,
        data.locationKey,
        data.items,
        data.paymentMethod,
        data.total
    )

    if success then
        -- Get location data for restaurant name
        local restaurantName = 'Restaurant'
        for restaurantType, locations in pairs(Config.Locations) do
            if type(locations) == 'table' and restaurantType ~= 'Settings' then
                for locId, locData in pairs(locations) do
                    local key = ('%s_%s'):format(restaurantType, locId)
                    if key == data.locationKey then
                        restaurantName = locData.label or restaurantName
                        break
                    end
                end
            end
        end

        -- Show receipt
        SendNUIMessage({
            type = 'receipt:show',
            data = {
                restaurantName = restaurantName,
                orderId = orderId,
                items = data.items,
                subtotal = data.subtotal,
                tax = data.tax,
                total = data.total,
                estimatedWait = 'Estimated wait: 5-10 mins',
            }
        })

        -- Play sound
        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)

        lib.notify({
            title = 'Order Placed',
            description = ('Order #%s has been submitted!'):format(orderId),
            type = 'success',
            duration = 5000,
        })
    else
        lib.notify({
            title = 'Order Failed',
            description = message or 'Could not place your order.',
            type = 'error',
        })
    end

    cb({ success = success, orderId = orderId })
end)

RegisterNUICallback('receipt:close', function(data, cb)
    closeKiosk()
    cb('ok')
end)

-- ============================================================================
-- REGISTER SYSTEM (Employee)
-- ============================================================================

--- Open register ordering interface for employee
---@param locationKey string
---@param locationData table
local function openRegister(locationKey, locationData)
    -- Check if on duty
    local PlayerData = exports.qbx_core:GetPlayerData()
    if not PlayerData.job.onduty then
        lib.notify({
            title = 'Not On Duty',
            description = 'You must be on duty to use the register.',
            type = 'error',
        })
        return
    end

    -- Open similar interface to kiosk but with employee options
    local menu, categories = getLocationMenu(locationData)

    local options = {
        {
            title = 'Take New Order',
            description = 'Enter a customer order',
            icon = 'fa-solid fa-receipt',
            onSelect = function()
                openKiosk(locationKey, locationData)
            end,
        },
        {
            title = 'View Active Orders',
            description = 'See orders on the KDS',
            icon = 'fa-solid fa-display',
            onSelect = function()
                openKDS(locationKey, locationData)
            end,
        },
        {
            title = 'Quick Order',
            description = 'Add items directly',
            icon = 'fa-solid fa-bolt',
            arrow = true,
            onSelect = function()
                showQuickOrderMenu(locationKey, locationData, menu, categories)
            end,
        },
    }

    lib.registerContext({
        id = 'register_menu',
        title = ('Register - %s'):format(locationData.shortName or locationData.label),
        options = options,
    })

    lib.showContext('register_menu')
end

--- Show quick order menu for employees
---@param locationKey string
---@param locationData table
---@param menu table
---@param categories table
local function showQuickOrderMenu(locationKey, locationData, menu, categories)
    local options = {}

    for _, category in ipairs(categories) do
        table.insert(options, {
            title = category,
            icon = 'fa-solid fa-utensils',
            onSelect = function()
                showQuickOrderCategory(locationKey, locationData, menu, category)
            end,
        })
    end

    lib.registerContext({
        id = 'quick_order_categories',
        title = 'Quick Order - Categories',
        menu = 'register_menu',
        options = options,
    })

    lib.showContext('quick_order_categories')
end

--- Show items in category for quick order
---@param locationKey string
---@param locationData table
---@param menu table
---@param category string
local function showQuickOrderCategory(locationKey, locationData, menu, category)
    local options = {}

    for _, item in ipairs(menu) do
        if item.category == category then
            table.insert(options, {
                title = item.label,
                description = FreeRestaurants.Utils.FormatMoney(item.price),
                icon = 'fa-solid fa-plus',
                onSelect = function()
                    quickAddItem(locationKey, item)
                end,
            })
        end
    end

    lib.registerContext({
        id = 'quick_order_items',
        title = category,
        menu = 'quick_order_categories',
        options = options,
    })

    lib.showContext('quick_order_items')
end

--- Quick add item (employee enters customer payment)
---@param locationKey string
---@param item table
local function quickAddItem(locationKey, item)
    local input = lib.inputDialog('Quick Order', {
        { type = 'number', label = 'Quantity', default = 1, min = 1, max = 10 },
        { type = 'select', label = 'Payment Method', options = {
            { value = 'cash', label = 'Cash' },
            { value = 'card', label = 'Card' },
        }},
    })

    if not input then return end

    local qty = input[1] or 1
    local paymentMethod = input[2] or 'cash'
    local total = item.price * qty * (1 + getTaxRate())

    local success, orderId = lib.callback.await(
        'free-restaurants:server:placeOrder',
        false,
        locationKey,
        {{ id = item.id, label = item.label, amount = qty, price = item.price }},
        paymentMethod,
        total
    )

    if success then
        lib.notify({
            title = 'Order Created',
            description = ('Order #%s - %dx %s'):format(orderId, qty, item.label),
            type = 'success',
        })
    else
        lib.notify({
            title = 'Order Failed',
            description = 'Could not create order.',
            type = 'error',
        })
    end
end

-- ============================================================================
-- KDS SYSTEM
-- ============================================================================

--- Open KDS overlay
---@param locationKey string
---@param locationData table
local function openKDS(locationKey, locationData)
    if kdsVisible then return end

    local PlayerData = exports.qbx_core:GetPlayerData()
    if not PlayerData.job.onduty then
        lib.notify({
            title = 'Not On Duty',
            description = 'You must be on duty to use the KDS.',
            type = 'error',
        })
        return
    end

    currentLocation = locationKey
    currentJob = PlayerData.job.name
    kdsVisible = true

    -- Get active orders
    local orders = lib.callback.await('free-restaurants:server:getOrders', false, currentJob)

    SetNuiFocus(true, true)

    SendNUIMessage({
        type = 'kds:show',
        data = {
            location = locationData.label or 'Kitchen',
            job = currentJob,
            orders = orders or {},
            settings = Config.Ordering and Config.Ordering.Settings and Config.Ordering.Settings.kds or {},
        }
    })
end

--- Close KDS overlay
local function closeKDS()
    if not kdsVisible then return end

    kdsVisible = false
    currentLocation = nil

    SetNuiFocus(false, false)

    SendNUIMessage({
        type = 'kds:hide',
        data = {}
    })
end

-- NUI Callbacks for KDS
RegisterNUICallback('kds:close', function(data, cb)
    closeKDS()
    cb('ok')
end)

RegisterNUICallback('kds:action', function(data, cb)
    local orderId = data.orderId
    local action = data.action

    local success = false
    local callbackName = nil

    if action == 'start' then
        callbackName = 'free-restaurants:server:startOrder'
    elseif action == 'ready' then
        callbackName = 'free-restaurants:server:readyOrder'
    elseif action == 'complete' then
        callbackName = 'free-restaurants:server:completeOrder'
    elseif action == 'cancel' then
        callbackName = 'free-restaurants:server:cancelOrder'
    end

    if callbackName then
        success = lib.callback.await(callbackName, false, orderId)
    end

    if success then
        -- Play confirmation sound
        PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end

    cb({ success = success })
end)

RegisterNUICallback('kds:playSound', function(data, cb)
    if data.sound == 'new_order' then
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
    cb('ok')
end)

-- ============================================================================
-- ORDER EVENT HANDLERS
-- ============================================================================

--- Handle new order event (for KDS update)
RegisterNetEvent('free-restaurants:client:orderEvent', function(eventType, orderData)
    if not kdsVisible then return end

    if eventType == 'new_order' then
        SendNUIMessage({
            type = 'kds:newOrder',
            data = { order = orderData }
        })
    elseif eventType == 'order_update' then
        SendNUIMessage({
            type = 'kds:orderUpdate',
            data = {
                orderId = orderData.id,
                status = orderData.status,
            }
        })
    elseif eventType == 'order_cancelled' then
        SendNUIMessage({
            type = 'kds:removeOrder',
            data = { orderId = orderData.id }
        })
    end
end)

-- ============================================================================
-- TARGET SETUP
-- ============================================================================

--- Setup ordering interaction targets
local function setupOrderingTargets()
    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' and locationData.enabled then
                    local key = ('%s_%s'):format(restaurantType, locationId)
                    local orderingConfig = Config.GetOrderingConfig and Config.GetOrderingConfig(restaurantType, locationId)

                    if orderingConfig then
                        -- Setup kiosks
                        if orderingConfig.kiosks then
                            for kioskId, kioskData in pairs(orderingConfig.kiosks) do
                                if kioskData.enabled then
                                    local targetName = ('%s_kiosk_%s'):format(key, kioskId)

                                    exports.ox_target:addBoxZone({
                                        name = targetName,
                                        coords = kioskData.coords,
                                        size = kioskData.targetSize or vec3(0.8, 0.3, 1.5),
                                        rotation = kioskData.heading or 0,
                                        debug = Config.Debug,
                                        options = {
                                            {
                                                name = 'use_kiosk',
                                                label = kioskData.label or 'Self-Order Kiosk',
                                                icon = 'fa-solid fa-tablet-screen-button',
                                                onSelect = function()
                                                    openKiosk(key, locationData)
                                                end,
                                            },
                                        },
                                    })
                                end
                            end
                        end

                        -- Setup registers
                        if orderingConfig.registers then
                            for registerId, registerData in pairs(orderingConfig.registers) do
                                if registerData.enabled then
                                    local targetName = ('%s_register_%s'):format(key, registerId)
                                    local job = locationData.job

                                    exports.ox_target:addBoxZone({
                                        name = targetName,
                                        coords = registerData.coords,
                                        size = registerData.targetSize or vec3(0.6, 0.4, 0.5),
                                        rotation = registerData.heading or 0,
                                        debug = Config.Debug,
                                        options = {
                                            {
                                                name = 'use_register',
                                                label = registerData.label or 'Register',
                                                icon = 'fa-solid fa-cash-register',
                                                groups = job and { [job] = registerData.minGrade or 0 } or nil,
                                                onSelect = function()
                                                    openRegister(key, locationData)
                                                end,
                                            },
                                        },
                                    })
                                end
                            end
                        end

                        -- Setup KDS monitors
                        if orderingConfig.kdsMonitors then
                            for kdsId, kdsData in pairs(orderingConfig.kdsMonitors) do
                                if kdsData.enabled then
                                    local targetName = ('%s_kds_%s'):format(key, kdsId)
                                    local job = locationData.job

                                    exports.ox_target:addBoxZone({
                                        name = targetName,
                                        coords = kdsData.coords,
                                        size = kdsData.targetSize or vec3(0.8, 0.1, 0.6),
                                        rotation = kdsData.heading or 0,
                                        debug = Config.Debug,
                                        options = {
                                            {
                                                name = 'view_kds',
                                                label = kdsData.label or 'Kitchen Display',
                                                icon = 'fa-solid fa-display',
                                                groups = job and { [job] = kdsData.minGrade or 0 } or nil,
                                                onSelect = function()
                                                    openKDS(key, locationData)
                                                end,
                                            },
                                        },
                                    })
                                end
                            end
                        end

                        -- Setup pickup counter
                        if orderingConfig.pickupCounter and orderingConfig.pickupCounter.enabled then
                            local pickupData = orderingConfig.pickupCounter
                            local targetName = ('%s_pickup'):format(key)

                            exports.ox_target:addBoxZone({
                                name = targetName,
                                coords = pickupData.coords,
                                size = pickupData.targetSize or vec3(2.0, 1.0, 1.5),
                                rotation = pickupData.heading or 0,
                                debug = Config.Debug,
                                options = {
                                    {
                                        name = 'pickup_order',
                                        label = pickupData.label or 'Pickup Order',
                                        icon = 'fa-solid fa-hand-holding',
                                        onSelect = function()
                                            checkOrderPickup(key)
                                        end,
                                    },
                                },
                            })
                        end
                    end
                end
            end
        end
    end
end

--- Check if player has a ready order to pickup
---@param locationKey string
local function checkOrderPickup(locationKey)
    local myOrder = lib.callback.await('free-restaurants:server:getMyOrder', false)

    if not myOrder then
        lib.notify({
            title = 'No Order',
            description = 'You don\'t have any pending orders here.',
            type = 'inform',
        })
        return
    end

    if myOrder.status ~= 'ready' then
        lib.notify({
            title = 'Order Not Ready',
            description = ('Order #%s is still being prepared.'):format(myOrder.id),
            type = 'inform',
        })
        return
    end

    local success = lib.callback.await('free-restaurants:server:pickupOrder', false, myOrder.id)

    if success then
        lib.notify({
            title = 'Order Received',
            description = 'Enjoy your food!',
            type = 'success',
        })
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    else
        lib.notify({
            title = 'Pickup Failed',
            description = 'Could not pickup your order.',
            type = 'error',
        })
    end
end

-- ============================================================================
-- COMMANDS
-- ============================================================================

--- Command to open KDS for on-duty staff
RegisterCommand('kds', function()
    local PlayerData = exports.qbx_core:GetPlayerData()

    if not PlayerData.job.onduty then
        lib.notify({
            title = 'Not On Duty',
            description = 'Clock in to use the KDS.',
            type = 'error',
        })
        return
    end

    -- Find nearest restaurant for this job
    local playerCoords = GetEntityCoords(cache.ped)
    local nearestLocation = nil
    local nearestDist = math.huge

    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' and locationData.enabled then
                    if locationData.job == PlayerData.job.name then
                        if locationData.entrance and locationData.entrance.coords then
                            local dist = #(playerCoords - locationData.entrance.coords)
                            if dist < nearestDist then
                                nearestDist = dist
                                nearestLocation = {
                                    key = ('%s_%s'):format(restaurantType, locationId),
                                    data = locationData,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if nearestLocation and nearestDist < 100.0 then
        openKDS(nearestLocation.key, nearestLocation.data)
    else
        lib.notify({
            title = 'Too Far',
            description = 'You\'re not at a restaurant.',
            type = 'error',
        })
    end
end, false)

-- Keybind for KDS
lib.addKeybind({
    name = 'restaurant_kds',
    description = 'Open Kitchen Display System',
    defaultKey = 'F6',
    onPressed = function()
        ExecuteCommand('kds')
    end,
})

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize on resource start
RegisterNetEvent('free-restaurants:client:ready', function()
    setupOrderingTargets()
end)

--- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Close any open UIs
    if kdsVisible then closeKDS() end
    if kioskVisible then closeKiosk() end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('OpenKiosk', openKiosk)
exports('CloseKiosk', closeKiosk)
exports('OpenKDS', openKDS)
exports('CloseKDS', closeKDS)
exports('OpenRegister', openRegister)
exports('IsKDSVisible', function() return kdsVisible end)
exports('IsKioskVisible', function() return kioskVisible end)

FreeRestaurants.Utils.Debug('client/ordering.lua loaded')
