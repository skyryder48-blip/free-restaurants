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
    - config/pos_order.lua (ordering configurations)
    - ox_lib (UI components)
    - ox_target (interaction zones)
]]

print('[free-restaurants] Loading client/ordering.lua...')

-- Verify Config.Ordering is available from pos_order.lua
if Config and Config.Ordering then
    print('[free-restaurants] Config.Ordering loaded successfully from pos_order.lua')
    -- Debug: show available restaurant types
    local types = {}
    for k, v in pairs(Config.Ordering) do
        if type(v) == 'table' and k ~= 'Settings' and k ~= 'KDSProps' and k ~= 'DefaultTemplate' and k ~= 'ReceiptTemplate' then
            table.insert(types, k)
        end
    end
    print(('[free-restaurants] Available ordering configs: %s'):format(table.concat(types, ', ')))
else
    print('[free-restaurants] WARNING: Config.Ordering not found - check pos_order.lua loading')
end

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local kiosks = {}                       -- Spawned kiosk props
local kdsMonitors = {}                  -- Spawned KDS monitor props
local kdsVisible = false                -- KDS overlay visibility
local kioskVisible = false              -- Kiosk overlay visibility
local currentLocation = nil             -- Current location key
local currentJob = nil                  -- Current job name
local orderingTargets = {}              -- Track created ox_target zones for cleanup

-- Forward declarations for functions that reference each other
local openKiosk, closeKiosk
local openRegister
local showQuickOrderMenu, showQuickOrderCategory, quickAddItem
local openKDS, closeKDS
local setupOrderingTargets, initializeTargets, removeOrderingTargets
local checkOrderPickup
local getNearbyPlayers
local showRegisterFullOrderMenu, showRegisterCategoryItems

--- Remove all ordering targets
removeOrderingTargets = function()
    for targetId in pairs(orderingTargets) do
        exports.ox_target:removeZone(targetId)
    end
    orderingTargets = {}
    print('[free-restaurants] Removed all ordering targets')
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get location menu for kiosk/register with custom pricing
---@param locationData table Location configuration
---@return table menu, table categories
local function getLocationMenu(locationData)
    local menu = {}
    local categories = {}
    local seenCategories = {}
    local restaurantType = locationData.restaurantType
    local job = locationData.job

    -- Fetch custom prices from server
    local customPrices = {}
    if job then
        customPrices = lib.callback.await('free-restaurants:server:getPricing', false, job) or {}
    end

    -- Recipes are stored in Config.Recipes.Items, not Config.Recipes directly
    local recipesTable = Config.Recipes and Config.Recipes.Items or {}

    for recipeId, recipeData in pairs(recipesTable) do
        -- Check if recipe belongs to this restaurant type
        -- Recipes use 'restaurantTypes' (plural array), not 'restaurantType' (singular)
        local matchesType = false
        if recipeData.restaurantTypes then
            for _, rType in ipairs(recipeData.restaurantTypes) do
                if rType == restaurantType or rType == 'all' then
                    matchesType = true
                    break
                end
            end
        end

        if matchesType and recipeData.sellable ~= false then
            -- Get first category from categories array, or use 'Other'
            local category = 'Other'
            if recipeData.categories and #recipeData.categories > 0 then
                category = recipeData.categories[1]
            end

            -- Use custom price if available, otherwise base price
            local price = recipeData.basePrice or 0
            if customPrices[recipeId] and customPrices[recipeId].price then
                price = customPrices[recipeId].price
            end

            table.insert(menu, {
                id = recipeId,
                label = recipeData.label,
                description = recipeData.description or '',
                price = price,
                category = category,
                icon = recipeData.icon,
                customizations = recipeData.customizations,
            })

            if not seenCategories[category] then
                seenCategories[category] = true
                table.insert(categories, category)
            end
        end
    end

    table.sort(categories)

    if Config.Debug then
        print(('[free-restaurants] getLocationMenu for %s: found %d items in %d categories'):format(
            restaurantType or 'unknown', #menu, #categories
        ))
    end

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
openKiosk = function(locationKey, locationData)
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
closeKiosk = function()
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

--- Selected customer for register orders (persists during order taking)
local selectedCustomer = nil

--- Open register customer selection then full order menu
---@param locationKey string
---@param locationData table
local function openRegisterOrderMenu(locationKey, locationData)
    -- Get nearby customers
    local nearbyPlayers = getNearbyPlayers()

    if #nearbyPlayers == 0 then
        lib.notify({
            title = 'No Customers',
            description = 'No customers nearby to take an order from.',
            type = 'error',
        })
        return
    end

    local customerOptions = {}
    for _, player in ipairs(nearbyPlayers) do
        table.insert(customerOptions, {
            value = player.serverId,
            label = ('%s (%.1fm)'):format(player.name, player.distance),
        })
    end

    local input = lib.inputDialog('Select Customer', {
        { type = 'select', label = 'Customer to Bill', options = customerOptions, required = true },
        { type = 'select', label = 'Payment Method', options = {
            { value = 'cash', label = 'Cash' },
            { value = 'card', label = 'Card' },
        }, required = true },
    })

    if not input then return end

    selectedCustomer = {
        serverId = input[1],
        paymentMethod = input[2],
        name = nil,
    }

    -- Find customer name
    for _, p in ipairs(nearbyPlayers) do
        if p.serverId == input[1] then
            selectedCustomer.name = p.name
            break
        end
    end

    -- Now show the full order menu for building the order
    showRegisterFullOrderMenu(locationKey, locationData)
end

--- Show full order menu for register (multi-item order builder)
---@param locationKey string
---@param locationData table
showRegisterFullOrderMenu = function(locationKey, locationData)
    local menu, categories = getLocationMenu(locationData)

    -- Build category options
    local options = {
        {
            title = ('Customer: %s'):format(selectedCustomer.name or 'Unknown'),
            description = ('Payment: %s'):format(selectedCustomer.paymentMethod == 'cash' and 'Cash' or 'Card'),
            icon = 'fa-solid fa-user',
            disabled = true,
        },
    }

    for _, category in ipairs(categories) do
        table.insert(options, {
            title = category,
            icon = 'fa-solid fa-utensils',
            arrow = true,
            onSelect = function()
                showRegisterCategoryItems(locationKey, locationData, menu, category)
            end,
        })
    end

    lib.registerContext({
        id = 'register_full_order',
        title = 'Take Order',
        menu = 'register_menu',
        options = options,
    })

    lib.showContext('register_full_order')
end

--- Show items in a category for register ordering
---@param locationKey string
---@param locationData table
---@param menu table
---@param category string
showRegisterCategoryItems = function(locationKey, locationData, menu, category)
    local options = {}

    for _, item in ipairs(menu) do
        if item.category == category then
            table.insert(options, {
                title = item.label,
                description = FreeRestaurants.Utils.FormatMoney(item.price),
                icon = 'fa-solid fa-plus',
                onSelect = function()
                    -- Add item for the selected customer
                    local input = lib.inputDialog(item.label, {
                        { type = 'number', label = 'Quantity', default = 1, min = 1, max = 10 },
                    })

                    if not input then return end

                    local qty = input[1] or 1

                    local success, orderId, errorMsg = lib.callback.await(
                        'free-restaurants:server:placeRegisterOrder',
                        false,
                        locationKey,
                        {{ id = item.id, label = item.label, amount = qty, price = item.price }},
                        selectedCustomer.paymentMethod,
                        selectedCustomer.serverId
                    )

                    if success then
                        lib.notify({
                            title = 'Order Created',
                            description = ('Order #%s for %s'):format(orderId, selectedCustomer.name),
                            type = 'success',
                        })
                        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    else
                        lib.notify({
                            title = 'Order Failed',
                            description = errorMsg or 'Could not create order.',
                            type = 'error',
                        })
                    end
                end,
            })
        end
    end

    lib.registerContext({
        id = 'register_category_items',
        title = category,
        menu = 'register_full_order',
        options = options,
    })

    lib.showContext('register_category_items')
end

--- Open register ordering interface for employee
---@param locationKey string
---@param locationData table
openRegister = function(locationKey, locationData)
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
            description = 'Select customer and enter their order',
            icon = 'fa-solid fa-receipt',
            onSelect = function()
                openRegisterOrderMenu(locationKey, locationData)
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
            description = 'Add single item quickly',
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
showQuickOrderMenu = function(locationKey, locationData, menu, categories)
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
showQuickOrderCategory = function(locationKey, locationData, menu, category)
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

--- Get nearby players for customer selection
---@return table players Array of { serverId, name, distance }
getNearbyPlayers = function()
    local players = {}
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local myServerId = GetPlayerServerId(PlayerId())

    for _, playerId in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(playerId)
        if serverId ~= myServerId then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)

            if distance <= 10.0 then -- Within 10 meters
                table.insert(players, {
                    serverId = serverId,
                    name = GetPlayerName(playerId),
                    distance = distance,
                })
            end
        end
    end

    table.sort(players, function(a, b) return a.distance < b.distance end)
    return players
end

--- Quick add item (employee enters customer payment)
---@param locationKey string
---@param item table
quickAddItem = function(locationKey, item)
    -- Get nearby customers
    local nearbyPlayers = getNearbyPlayers()
    local customerOptions = {}

    for _, player in ipairs(nearbyPlayers) do
        table.insert(customerOptions, {
            value = player.serverId,
            label = ('%s (%.1fm)'):format(player.name, player.distance),
        })
    end

    if #customerOptions == 0 then
        lib.notify({
            title = 'No Customers',
            description = 'No customers nearby to bill.',
            type = 'error',
        })
        return
    end

    local input = lib.inputDialog('Quick Order', {
        { type = 'select', label = 'Customer', options = customerOptions, required = true },
        { type = 'number', label = 'Quantity', default = 1, min = 1, max = 10 },
        { type = 'select', label = 'Payment Method', options = {
            { value = 'cash', label = 'Cash' },
            { value = 'card', label = 'Card' },
        }},
    })

    if not input then return end

    local customerId = input[1]
    local qty = input[2] or 1
    local paymentMethod = input[3] or 'cash'
    local total = item.price * qty * (1 + getTaxRate())

    local success, orderId, errorMsg = lib.callback.await(
        'free-restaurants:server:placeRegisterOrder',
        false,
        locationKey,
        {{ id = item.id, label = item.label, amount = qty, price = item.price }},
        paymentMethod,
        customerId
    )

    if success then
        lib.notify({
            title = 'Order Created',
            description = ('Order #%s - %dx %s'):format(orderId, qty, item.label),
            type = 'success',
        })
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    else
        lib.notify({
            title = 'Order Failed',
            description = errorMsg or 'Could not create order.',
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
openKDS = function(locationKey, locationData)
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
closeKDS = function()
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
setupOrderingTargets = function()
    local totalKiosks = 0
    local totalRegisters = 0
    local totalKDS = 0

    -- Check if Config.Ordering exists
    if not Config.Ordering then
        print('[free-restaurants] ERROR: Config.Ordering is nil!')
        return
    end

    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' and locationData.enabled then
                    local key = ('%s_%s'):format(restaurantType, locationId)

                    -- Try to get ordering config - check both by restaurantType and by job name
                    local orderingConfig = nil
                    if Config.Ordering[restaurantType] and Config.Ordering[restaurantType][locationId] then
                        orderingConfig = Config.Ordering[restaurantType][locationId]
                    elseif locationData.job and Config.Ordering[locationData.job] and Config.Ordering[locationData.job][locationId] then
                        orderingConfig = Config.Ordering[locationData.job][locationId]
                    end

                    if orderingConfig then
                        print(('[free-restaurants] Setting up ordering for %s'):format(key))

                        -- Capture loop variables for closures
                        local capturedKey = key
                        local capturedLocationData = locationData

                        -- Setup kiosks
                        if orderingConfig.kiosks then
                            for kioskId, kioskData in pairs(orderingConfig.kiosks) do
                                if kioskData.enabled then
                                    local targetName = ('%s_kiosk_%s'):format(key, kioskId)
                                    totalKiosks = totalKiosks + 1

                                    -- Store data for callback
                                    local kioskKey = capturedKey
                                    local kioskLocData = capturedLocationData

                                    exports.ox_target:addBoxZone({
                                        name = targetName,
                                        coords = kioskData.coords,
                                        size = kioskData.targetSize or vec3(1.0, 1.0, 1.5),
                                        rotation = kioskData.heading or 0,
                                        debug = Config.Debug,
                                        options = {
                                            {
                                                name = 'use_kiosk_' .. targetName,
                                                label = kioskData.label or 'Self-Order Kiosk',
                                                icon = 'fa-solid fa-tablet',
                                                canInteract = function()
                                                    return true
                                                end,
                                                onSelect = function()
                                                    print('[free-restaurants] Kiosk selected: ' .. kioskKey)
                                                    openKiosk(kioskKey, kioskLocData)
                                                end,
                                            },
                                        },
                                    })

                                    orderingTargets[targetName] = true
                                    print(('[free-restaurants]   + Kiosk: %s at %s'):format(kioskId, kioskData.coords))
                                end
                            end
                        end

                        -- Setup registers
                        if orderingConfig.registers then
                            for registerId, registerData in pairs(orderingConfig.registers) do
                                if registerData.enabled then
                                    local targetName = ('%s_register_%s'):format(key, registerId)
                                    local job = locationData.job
                                    totalRegisters = totalRegisters + 1

                                    -- Store data for callback
                                    local regKey = capturedKey
                                    local regLocData = capturedLocationData

                                    exports.ox_target:addBoxZone({
                                        name = targetName,
                                        coords = registerData.coords,
                                        size = registerData.targetSize or vec3(1.0, 1.0, 1.0),
                                        rotation = registerData.heading or 0,
                                        debug = Config.Debug,
                                        options = {
                                            {
                                                name = 'use_register_' .. targetName,
                                                label = registerData.label or 'Register',
                                                icon = 'fa-solid fa-cash-register',
                                                groups = job and { [job] = registerData.minGrade or 0 } or nil,
                                                canInteract = function()
                                                    return true
                                                end,
                                                onSelect = function()
                                                    print('[free-restaurants] Register selected: ' .. regKey)
                                                    openRegister(regKey, regLocData)
                                                end,
                                            },
                                        },
                                    })

                                    orderingTargets[targetName] = true
                                    print(('[free-restaurants]   + Register: %s (job: %s) at %s'):format(registerId, job or 'any', registerData.coords))
                                end
                            end
                        end

                        -- Setup KDS monitors
                        if orderingConfig.kdsMonitors then
                            for kdsId, kdsData in pairs(orderingConfig.kdsMonitors) do
                                if kdsData.enabled then
                                    local targetName = ('%s_kds_%s'):format(key, kdsId)
                                    local job = locationData.job
                                    totalKDS = totalKDS + 1

                                    -- Store data for callback
                                    local kdsKey = capturedKey
                                    local kdsLocData = capturedLocationData

                                    exports.ox_target:addBoxZone({
                                        name = targetName,
                                        coords = kdsData.coords,
                                        size = kdsData.targetSize or vec3(1.0, 0.5, 1.0),
                                        rotation = kdsData.heading or 0,
                                        debug = Config.Debug,
                                        options = {
                                            {
                                                name = 'view_kds_' .. targetName,
                                                label = kdsData.label or 'Kitchen Display',
                                                icon = 'fa-solid fa-tv',
                                                groups = job and { [job] = kdsData.minGrade or 0 } or nil,
                                                canInteract = function()
                                                    return true
                                                end,
                                                onSelect = function()
                                                    print('[free-restaurants] KDS selected: ' .. kdsKey)
                                                    openKDS(kdsKey, kdsLocData)
                                                end,
                                            },
                                        },
                                    })

                                    orderingTargets[targetName] = true
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
                                        name = 'pickup_order_' .. targetName,
                                        label = pickupData.label or 'Pickup Order',
                                        icon = 'fa-solid fa-box-open',
                                        canInteract = function()
                                            return true
                                        end,
                                        onSelect = function()
                                            -- Open pickup stash directly for customers
                                            TriggerServerEvent('free-restaurants:server:openCustomerPickupStash', capturedKey)
                                        end,
                                    },
                                },
                            })

                            orderingTargets[targetName] = true
                            print(('[free-restaurants]   + Pickup counter at %s'):format(pickupData.coords))
                        end
                    else
                        print(('[free-restaurants] No ordering config found for %s'):format(key))
                    end
                end
            end
        end
    end

    print(('[free-restaurants] Total targets created: %d kiosks, %d registers, %d KDS monitors'):format(
        totalKiosks, totalRegisters, totalKDS
    ))
end

--- Check if player has a ready order to pickup
---@param locationKey string
checkOrderPickup = function(locationKey)
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

    local success, errorMsg = lib.callback.await('free-restaurants:server:pickupOrder', false, myOrder.id)

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
            description = errorMsg or 'Could not pickup your order.',
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

local targetsInitialized = false

--- Initialize targets (removes old targets and creates new ones)
initializeTargets = function()
    -- Always clean up existing targets first (like duty.lua does)
    removeOrderingTargets()

    print('[free-restaurants] Initializing ordering targets...')
    setupOrderingTargets()
    targetsInitialized = true
    print('[free-restaurants] Ordering targets initialized')
end

--- Initialize on resource start (main initialization point)
RegisterNetEvent('free-restaurants:client:ready', function()
    initializeTargets()
end)

--- Fallback initialization if ready event doesn't fire
CreateThread(function()
    -- Wait for player to be loaded
    while not LocalPlayer.state.isLoggedIn do
        Wait(500)
    end

    -- Give a moment for other systems to initialize
    Wait(2000)

    -- Initialize targets if not already done by the ready event
    if not targetsInitialized then
        print('[free-restaurants] Fallback initialization of ordering targets')
        initializeTargets()
    end
end)

--- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Close any open UIs
    if kdsVisible then closeKDS() end
    if kioskVisible then closeKiosk() end

    -- Remove all ordering targets
    removeOrderingTargets()
end)

-- ============================================================================
-- RECEIPT ITEM HANDLER
-- ============================================================================
-- NOTE: Receipt viewing via ox_inventory item hook is not supported.
-- To enable receipt viewing, register the item as usable on the server side
-- using exports.ox_inventory:registerUsableItem() and trigger a client event.

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
print('[free-restaurants] client/ordering.lua loaded successfully')
