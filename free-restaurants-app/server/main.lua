--[[
    Food Hub - Restaurant App Server
    Handles order processing and data retrieval
]]

-- ============================================================================
-- STATE
-- ============================================================================

-- Restaurant open/close status: { [job] = { open, acceptsPickup, acceptsDelivery } }
local restaurantStatus = {}

-- Active app orders: { [orderId] = orderData }
local activeAppOrders = {}

-- Order counter for unique IDs
local appOrderCounter = 0

-- ============================================================================
-- DATABASE INITIALIZATION
-- ============================================================================

CreateThread(function()
    Wait(1000)

    -- Create app orders table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `restaurant_app_orders` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `order_id` VARCHAR(20) NOT NULL UNIQUE,
            `job` VARCHAR(50) NOT NULL,
            `customer_citizenid` VARCHAR(50) NOT NULL,
            `customer_name` VARCHAR(100),
            `customer_phone` VARCHAR(20),
            `order_type` ENUM('pickup', 'delivery') NOT NULL,
            `items` JSON NOT NULL,
            `total` INT NOT NULL,
            `delivery_fee` INT DEFAULT 0,
            `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
            `delivery_coords` VARCHAR(100),
            `assigned_to` VARCHAR(50),
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `completed_at` TIMESTAMP NULL,
            INDEX `idx_job_status` (`job`, `status`),
            INDEX `idx_customer` (`customer_citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Create restaurant status table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `restaurant_app_status` (
            `job` VARCHAR(50) PRIMARY KEY,
            `is_open` BOOLEAN DEFAULT FALSE,
            `accepts_pickup` BOOLEAN DEFAULT FALSE,
            `accepts_delivery` BOOLEAN DEFAULT FALSE,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `updated_by` VARCHAR(50)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Load saved restaurant statuses
    local statuses = MySQL.query.await('SELECT * FROM restaurant_app_status')
    if statuses then
        for _, row in ipairs(statuses) do
            restaurantStatus[row.job] = {
                open = row.is_open,
                acceptsPickup = row.accepts_pickup,
                acceptsDelivery = row.accepts_delivery,
            }
        end
        print(('[Food Hub] Loaded status for %d restaurants'):format(#statuses))
    end

    -- Load pending orders
    local orders = MySQL.query.await([[
        SELECT * FROM restaurant_app_orders
        WHERE status NOT IN ('delivered', 'picked_up', 'cancelled')
    ]])
    if orders then
        for _, row in ipairs(orders) do
            activeAppOrders[row.order_id] = {
                orderId = row.order_id,
                job = row.job,
                customerCitizenid = row.customer_citizenid,
                customerName = row.customer_name,
                customerPhone = row.customer_phone,
                orderType = row.order_type,
                items = json.decode(row.items) or {},
                total = row.total,
                deliveryFee = row.delivery_fee,
                status = row.status,
                deliveryCoords = row.delivery_coords,
                assignedTo = row.assigned_to,
                createdAt = row.created_at,
            }
        end
        print(('[Food Hub] Loaded %d pending app orders'):format(#orders))
    end
end)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Generate unique order ID
local function generateOrderId()
    appOrderCounter = appOrderCounter + 1
    local timestamp = GetGameTimer() % 100000
    return ('APP%05d%03d'):format(timestamp, appOrderCounter % 1000)
end

--- Get player's phone number
local function getPlayerPhone(source)
    local player = exports.qbx_core:GetPlayer(source)
    if player then
        return player.PlayerData.charinfo.phone
    end
    return nil
end

--- Notify all on-duty employees of a job
local function notifyJobEmployees(job, eventName, data)
    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.job.name == job and player.PlayerData.job.onduty then
            TriggerClientEvent(eventName, player.PlayerData.source, data)
        end
    end
end

--- Notify customer
local function notifyCustomer(citizenid, eventName, data)
    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.citizenid == citizenid then
            TriggerClientEvent(eventName, player.PlayerData.source, data)
            return true
        end
    end
    return false
end

--- Calculate delivery fee
local function calculateDeliveryFee(restaurantCoords, deliveryCoords)
    if not restaurantCoords or not deliveryCoords then
        return Config.App.baseDeliveryFee
    end

    local distance = #(
        vector3(restaurantCoords.x, restaurantCoords.y, restaurantCoords.z) -
        vector3(deliveryCoords.x, deliveryCoords.y, deliveryCoords.z)
    )

    local distanceKm = distance / 1000
    return math.floor(Config.App.baseDeliveryFee + (distanceKm * Config.App.deliveryFeePerKm))
end

-- ============================================================================
-- CALLBACKS - CUSTOMER
-- ============================================================================

--- Get open restaurants
lib.callback.register('free-restaurants-app:getOpenRestaurants', function(source)
    local restaurants = {}

    -- Get restaurant jobs from free-restaurants
    local restaurantJobs = exports['free-restaurants']:GetRestaurantJobs()
    if not restaurantJobs then return restaurants end

    -- Check which restaurants have staff on duty
    local staffOnDuty = {}
    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.job.onduty then
            local job = player.PlayerData.job.name
            staffOnDuty[job] = (staffOnDuty[job] or 0) + 1
        end
    end

    for jobName, jobConfig in pairs(restaurantJobs) do
        local status = restaurantStatus[jobName]
        local hasStaff = staffOnDuty[jobName] and staffOnDuty[jobName] > 0

        -- Restaurant is available if:
        -- 1. Explicitly set to open via status toggle, OR
        -- 2. Has staff on duty (auto-open mode)
        local isOpen = (status and status.open) or hasStaff
        local acceptsPickup = (status and status.acceptsPickup) or hasStaff
        local acceptsDelivery = (status and status.acceptsDelivery) or false -- Delivery needs explicit enable

        if isOpen then
            -- Find restaurant location for coords
            local locationCoords = nil
            local locations = exports['free-restaurants']:GetRestaurantLocations()
            if locations then
                for _, typeLocations in pairs(locations) do
                    if type(typeLocations) == 'table' then
                        for _, loc in pairs(typeLocations) do
                            if type(loc) == 'table' and loc.job == jobName and loc.enabled then
                                if loc.coords then
                                    locationCoords = loc.coords
                                end
                                break
                            end
                        end
                    end
                end
            end

            table.insert(restaurants, {
                id = jobName,
                name = jobConfig.label or jobName,
                type = jobConfig.type or 'default',
                isOpen = true,
                acceptsPickup = acceptsPickup,
                acceptsDelivery = acceptsDelivery,
                coords = locationCoords,
                staffCount = staffOnDuty[jobName] or 0,
            })
        end
    end

    return restaurants
end)

--- Get restaurant menu
lib.callback.register('free-restaurants-app:getRestaurantMenu', function(source, job)
    if not job then return {} end

    -- Get menu with custom pricing from free-restaurants
    local pricing = exports['free-restaurants']:GetPricing(job) or {}
    local menu = {}
    local categories = {}
    local seenCategories = {}

    -- Get job config
    local restaurantJobs = exports['free-restaurants']:GetRestaurantJobs()
    local jobConfig = restaurantJobs and restaurantJobs[job]
    local jobRestaurantType = jobConfig and jobConfig.type

    -- Get recipes
    local recipes = exports['free-restaurants']:GetRecipes()
    if not recipes or not recipes.Items then return { items = {}, categories = {} } end

    for recipeId, recipe in pairs(recipes.Items) do
        local shouldInclude = false

        -- Check if recipe matches restaurant type
        if recipe.restaurantTypes then
            for _, rType in ipairs(recipe.restaurantTypes) do
                if rType == jobRestaurantType or rType == 'all' then
                    shouldInclude = true
                    break
                end
            end
        end

        if shouldInclude and recipe.sellable ~= false and recipe.basePrice then
            local category = 'Other'
            if recipe.categories and #recipe.categories > 0 then
                category = recipe.categories[1]
            end

            -- Get custom price if available
            local price = recipe.basePrice
            if pricing and pricing[recipeId] and pricing[recipeId].price then
                price = pricing[recipeId].price
            end

            table.insert(menu, {
                id = recipeId,
                name = recipe.label,
                description = recipe.description or '',
                price = price,
                category = category,
                image = recipe.image,
                available = true,
            })

            if not seenCategories[category] then
                seenCategories[category] = true
                table.insert(categories, category)
            end
        end
    end

    table.sort(categories)

    return {
        items = menu,
        categories = categories,
        restaurantName = jobConfig and jobConfig.label or job,
    }
end)

--- Place order
lib.callback.register('free-restaurants-app:placeOrder', function(source, data)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return { success = false, error = 'Player not found' } end

    local job = data.restaurantId
    local status = restaurantStatus[job]

    -- Check if staff are on duty (same logic as getOpenRestaurants)
    local hasStaff = false
    local players = exports.qbx_core:GetQBPlayers()
    for _, p in pairs(players) do
        if p.PlayerData.job.name == job and p.PlayerData.job.onduty then
            hasStaff = true
            break
        end
    end

    -- Restaurant is open if explicitly set OR has staff on duty
    local isOpen = (status and status.open) or hasStaff
    local acceptsPickup = (status and status.acceptsPickup) or hasStaff
    local acceptsDelivery = status and status.acceptsDelivery or false

    if not isOpen then
        return { success = false, error = 'Restaurant is closed' }
    end

    if data.orderType == 'pickup' and not acceptsPickup then
        return { success = false, error = 'Pickup not available' }
    end

    if data.orderType == 'delivery' and not acceptsDelivery then
        return { success = false, error = 'Delivery not available' }
    end

    -- Calculate total
    local total = 0
    for _, item in ipairs(data.items) do
        total = total + (item.price * item.quantity)
    end

    -- Calculate delivery fee
    local deliveryFee = 0
    if data.orderType == 'delivery' then
        -- Get restaurant coords
        local locations = exports['free-restaurants']:GetRestaurantLocations()
        local restaurantCoords = nil
        if locations then
            for _, typeLocations in pairs(locations) do
                if type(typeLocations) == 'table' then
                    for _, loc in pairs(typeLocations) do
                        if type(loc) == 'table' and loc.job == job and loc.enabled and loc.coords then
                            restaurantCoords = loc.coords
                            break
                        end
                    end
                end
            end
        end
        deliveryFee = calculateDeliveryFee(restaurantCoords, data.deliveryCoords)
        total = total + deliveryFee
    end

    -- Check player can afford
    local playerMoney = player.Functions.GetMoney('bank')
    if playerMoney < total then
        return { success = false, error = 'Insufficient funds' }
    end

    -- Charge player
    player.Functions.RemoveMoney('bank', total, 'food-hub-order')

    -- Add money to restaurant business account (same as kiosk orders)
    local businessCut = 1.0 -- 100% goes to business, can be adjusted if needed
    local businessAmount = math.floor(total * businessCut)

    exports['free-restaurants']:UpdateBusinessBalance(
        job,
        businessAmount,
        'sale',
        ('App Order - %s'):format(data.orderType == 'delivery' and 'Delivery' or 'Pickup'),
        player.PlayerData.citizenid
    )

    -- Generate order
    local orderId = generateOrderId()
    local orderData = {
        orderId = orderId,
        job = job,
        customerCitizenid = player.PlayerData.citizenid,
        customerName = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname),
        customerPhone = player.PlayerData.charinfo.phone,
        orderType = data.orderType,
        items = data.items,
        total = total,
        deliveryFee = deliveryFee,
        status = 'pending',
        deliveryCoords = data.orderType == 'delivery' and
            ('%s,%s,%s'):format(data.deliveryCoords.x, data.deliveryCoords.y, data.deliveryCoords.z) or nil,
        createdAt = GetGameTimer(),
    }

    -- Save to memory and database
    activeAppOrders[orderId] = orderData

    MySQL.insert.await([[
        INSERT INTO restaurant_app_orders
        (order_id, job, customer_citizenid, customer_name, customer_phone, order_type, items, total, delivery_fee, status, delivery_coords)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        orderId,
        job,
        orderData.customerCitizenid,
        orderData.customerName,
        orderData.customerPhone,
        data.orderType,
        json.encode(data.items),
        total,
        deliveryFee,
        'pending',
        orderData.deliveryCoords,
    })

    -- Notify restaurant employees
    notifyJobEmployees(job, 'free-restaurants-app:newOrderReceived', {
        orderId = orderId,
        orderType = data.orderType,
        customerName = orderData.customerName,
        total = total,
        itemCount = #data.items,
    })

    print(('[Food Hub] Order %s placed by %s for %s ($%d)'):format(
        orderId, orderData.customerName, job, total
    ))

    return {
        success = true,
        orderId = orderId,
        total = total,
        deliveryFee = deliveryFee,
    }
end)

--- Get customer orders
lib.callback.register('free-restaurants-app:getCustomerOrders', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end

    local orders = MySQL.query.await([[
        SELECT * FROM restaurant_app_orders
        WHERE customer_citizenid = ?
        ORDER BY created_at DESC
        LIMIT ?
    ]], { player.PlayerData.citizenid, Config.App.maxOrderHistory or 20 })

    local result = {}
    for _, row in ipairs(orders or {}) do
        -- Get restaurant name
        local restaurantJobs = exports['free-restaurants']:GetRestaurantJobs()
        local restaurantName = restaurantJobs and restaurantJobs[row.job] and restaurantJobs[row.job].label or row.job

        table.insert(result, {
            orderId = row.order_id,
            restaurantId = row.job,
            restaurantName = restaurantName,
            orderType = row.order_type,
            items = json.decode(row.items) or {},
            total = row.total,
            deliveryFee = row.delivery_fee,
            status = row.status,
            createdAt = row.created_at,
        })
    end

    return result
end)

-- ============================================================================
-- CALLBACKS - EMPLOYEE
-- ============================================================================

--- Get employee dashboard
lib.callback.register('free-restaurants-app:getEmployeeDashboard', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or player.PlayerData.job.name ~= job then return nil end

    local status = restaurantStatus[job] or { open = false, acceptsPickup = false, acceptsDelivery = false }

    -- Count pending orders
    local pendingOrders = 0
    for _, order in pairs(activeAppOrders) do
        if order.job == job and order.status == 'pending' then
            pendingOrders = pendingOrders + 1
        end
    end

    -- Count active deliveries
    local activeDeliveries = 0
    for _, order in pairs(activeAppOrders) do
        if order.job == job and order.orderType == 'delivery' and
           (order.status == 'ready' or order.status == 'on_the_way') then
            activeDeliveries = activeDeliveries + 1
        end
    end

    -- Get on-duty staff count
    local onDutyCount = 0
    local players = exports.qbx_core:GetQBPlayers()
    for _, p in pairs(players) do
        if p.PlayerData.job.name == job and p.PlayerData.job.onduty then
            onDutyCount = onDutyCount + 1
        end
    end

    -- Get restaurant name
    local restaurantJobs = exports['free-restaurants']:GetRestaurantJobs()
    local restaurantName = restaurantJobs and restaurantJobs[job] and restaurantJobs[job].label or job

    return {
        restaurantName = restaurantName,
        isOpen = status.open,
        acceptsPickup = status.acceptsPickup,
        acceptsDelivery = status.acceptsDelivery,
        pendingOrders = pendingOrders,
        activeDeliveries = activeDeliveries,
        onDutyStaff = onDutyCount,
    }
end)

--- Get on-duty staff
lib.callback.register('free-restaurants-app:getOnDutyStaff', function(source, job)
    local staff = {}
    local players = exports.qbx_core:GetQBPlayers()

    for _, player in pairs(players) do
        if player.PlayerData.job.name == job and player.PlayerData.job.onduty then
            table.insert(staff, {
                name = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname),
                grade = player.PlayerData.job.grade.name,
                gradeLevel = player.PlayerData.job.grade.level,
            })
        end
    end

    -- Sort by grade level
    table.sort(staff, function(a, b) return a.gradeLevel > b.gradeLevel end)

    return staff
end)

--- Set restaurant status
lib.callback.register('free-restaurants-app:setRestaurantStatus', function(source, data)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return { success = false } end

    local job = player.PlayerData.job.name

    -- Check permissions
    if player.PlayerData.job.grade.level < (Config.App.minGradeForStatusToggle or 3) then
        return { success = false, error = 'Insufficient permissions' }
    end

    -- Handle both 'isOpen' (from UI) and 'open' (legacy) field names
    local isOpen = data.isOpen
    if isOpen == nil then
        isOpen = data.open
    end
    if isOpen == nil then
        isOpen = false
    end

    -- When opening, default to accepting pickup orders; when closing, disable all
    local acceptsPickup = data.acceptsPickup
    local acceptsDelivery = data.acceptsDelivery
    if acceptsPickup == nil then
        acceptsPickup = isOpen -- Default: accept pickup when open
    end
    if acceptsDelivery == nil then
        acceptsDelivery = isOpen -- Default: accept delivery when open
    end

    -- Update status
    restaurantStatus[job] = {
        open = isOpen,
        acceptsPickup = acceptsPickup,
        acceptsDelivery = acceptsDelivery,
    }

    -- Save to database
    MySQL.query.await([[
        INSERT INTO restaurant_app_status (job, is_open, accepts_pickup, accepts_delivery, updated_by)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            is_open = VALUES(is_open),
            accepts_pickup = VALUES(accepts_pickup),
            accepts_delivery = VALUES(accepts_delivery),
            updated_by = VALUES(updated_by)
    ]], {
        job,
        isOpen,
        acceptsPickup,
        acceptsDelivery,
        player.PlayerData.citizenid,
    })

    -- Notify staff
    notifyJobEmployees(job, 'free-restaurants-app:statusChanged', restaurantStatus[job])

    print(('[Food Hub] %s set restaurant status: open=%s, pickup=%s, delivery=%s'):format(
        job, tostring(isOpen), tostring(acceptsPickup), tostring(acceptsDelivery)
    ))

    return { success = true, status = restaurantStatus[job], isOpen = isOpen }
end)

--- Get pending app orders
lib.callback.register('free-restaurants-app:getPendingAppOrders', function(source, job)
    local orders = {}

    for orderId, order in pairs(activeAppOrders) do
        if order.job == job and order.status ~= 'delivered' and
           order.status ~= 'picked_up' and order.status ~= 'cancelled' then
            table.insert(orders, order)
        end
    end

    -- Sort by created time
    table.sort(orders, function(a, b) return a.createdAt < b.createdAt end)

    return orders
end)

--- Handle app order (accept/reject)
lib.callback.register('free-restaurants-app:handleAppOrder', function(source, data)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return { success = false } end

    local order = activeAppOrders[data.orderId]
    if not order then return { success = false, error = 'Order not found' } end

    if order.job ~= player.PlayerData.job.name then
        return { success = false, error = 'Not your restaurant' }
    end

    if data.action == 'accept' then
        order.status = 'accepted'

        -- Send to KDS with delivery coords for delivery orders
        exports['free-restaurants']:CreateKDSOrder({
            orderId = order.orderId,
            job = order.job,
            items = order.items,
            orderType = order.orderType == 'delivery' and 'delivery' or 'takeout',
            customerName = order.customerName,
            customerCitizenid = order.customerCitizenid,
            customerSource = nil, -- App orders don't have a source
            deliveryCoords = order.deliveryCoords, -- Customer location for delivery
            source = 'app',
        })

    elseif data.action == 'reject' then
        order.status = 'cancelled'

        -- Deduct from business account (reverse the sale)
        exports['free-restaurants']:UpdateBusinessBalance(
            order.job,
            -order.total,
            'refund',
            ('App Order Refund - #%s'):format(order.orderId),
            player.PlayerData.citizenid
        )

        -- Refund customer
        local players = exports.qbx_core:GetQBPlayers()
        for _, p in pairs(players) do
            if p.PlayerData.citizenid == order.customerCitizenid then
                p.Functions.AddMoney('bank', order.total, 'food-hub-refund')
                break
            end
        end
    end

    -- Update database
    MySQL.update.await([[
        UPDATE restaurant_app_orders SET status = ? WHERE order_id = ?
    ]], { order.status, data.orderId })

    -- Notify customer
    notifyCustomer(order.customerCitizenid, 'free-restaurants-app:orderStatusUpdate', {
        orderId = order.orderId,
        status = order.status,
    })

    return { success = true, status = order.status }
end)

--- Get available deliveries
lib.callback.register('free-restaurants-app:getAvailableDeliveries', function(source, job)
    local deliveries = {}

    -- Get app delivery orders that are ready
    for orderId, order in pairs(activeAppOrders) do
        if order.job == job and order.orderType == 'delivery' and order.status == 'ready' then
            table.insert(deliveries, {
                orderId = order.orderId,
                customerName = order.customerName,
                total = order.total,
                itemCount = #order.items,
                source = 'app',
            })
        end
    end

    -- Also get NPC delivery orders from free-restaurants
    local npcDeliveries = exports['free-restaurants']:GetAvailableDeliveries(job)
    if npcDeliveries then
        for _, delivery in ipairs(npcDeliveries) do
            table.insert(deliveries, {
                orderId = delivery.orderId or delivery.deliveryId,
                destination = delivery.destination,
                total = delivery.total or delivery.reward,
                source = 'npc',
            })
        end
    end

    return deliveries
end)

--- Accept delivery
lib.callback.register('free-restaurants-app:acceptDelivery', function(source, orderId)
    -- Check if it's an app order
    local order = activeAppOrders[orderId]
    if order then
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return { success = false } end

        order.status = 'on_the_way'
        order.assignedTo = player.PlayerData.citizenid

        MySQL.update.await([[
            UPDATE restaurant_app_orders SET status = ?, assigned_to = ? WHERE order_id = ?
        ]], { 'on_the_way', player.PlayerData.citizenid, orderId })

        -- Notify customer
        notifyCustomer(order.customerCitizenid, 'free-restaurants-app:orderStatusUpdate', {
            orderId = orderId,
            status = 'on_the_way',
        })

        -- Create delivery blip for driver
        TriggerClientEvent('free-restaurants-app:startDelivery', source, {
            orderId = orderId,
            customerName = order.customerName,
            customerPhone = order.customerPhone,
            deliveryCoords = order.deliveryCoords,
        })

        return { success = true }
    end

    -- Try NPC delivery
    local result = exports['free-restaurants']:AcceptDelivery(source, orderId)
    return { success = result }
end)

--- Message customer
lib.callback.register('free-restaurants-app:messageCustomer', function(source, data)
    local order = activeAppOrders[data.orderId]
    if not order then
        return { success = false, error = 'Order not found' }
    end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then
        return { success = false, error = 'Player not found' }
    end

    local staffName = ('%s %s'):format(
        player.PlayerData.charinfo.firstname,
        player.PlayerData.charinfo.lastname
    )

    -- Try to send SMS via lb-phone first
    if GetResourceState('lb-phone') == 'started' and order.customerPhone then
        exports['lb-phone']:SendMessage(player.PlayerData.charinfo.phone, order.customerPhone, data.message)
        return { success = true, method = 'sms' }
    end

    -- Fallback: Send in-game notification to customer
    local sent = notifyCustomer(order.customerCitizenid, 'free-restaurants-app:staffMessage', {
        orderId = order.orderId,
        staffName = staffName,
        message = data.message,
        restaurantJob = order.job,
    })

    if sent then
        return { success = true, method = 'notification' }
    end

    return { success = false, error = 'Customer is offline' }
end)

--- Complete delivery (triggered by driver confirming delivery in app)
RegisterNetEvent('free-restaurants-app:server:completeDelivery', function(orderId)
    local source = source
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local order = activeAppOrders[orderId]
    if not order then
        print(('[Food Hub] completeDelivery: Order %s not found'):format(orderId))
        return
    end

    -- Verify this player is the assigned driver
    if order.assignedTo ~= player.PlayerData.citizenid then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'This delivery is not assigned to you',
            type = 'error',
        })
        return
    end

    -- Mark order as delivered
    order.status = 'delivered'
    order.completedAt = GetGameTimer()

    -- Update database
    MySQL.update.await([[
        UPDATE restaurant_app_orders SET status = 'delivered', completed_at = NOW() WHERE order_id = ?
    ]], { orderId })

    -- No payment to driver - tips handled through roleplay

    -- Also update the main restaurant KDS order status
    exports['free-restaurants']:UpdateOrderStatus(orderId, 'delivered', source)

    -- Notify customer
    notifyCustomer(order.customerCitizenid, 'free-restaurants-app:orderStatusUpdate', {
        orderId = orderId,
        status = 'delivered',
    })

    -- Notify the driver
    TriggerClientEvent('free-restaurants-app:completeDelivery', source, orderId)

    print(('[Food Hub] Delivery %s completed by %s, earned $%d'):format(
        orderId, player.PlayerData.citizenid, deliveryEarnings
    ))
end)

-- ============================================================================
-- KDS INTEGRATION
-- ============================================================================

-- Listen for KDS status updates
RegisterNetEvent('free-restaurants:kds:orderStatusChanged', function(orderId, newStatus, extraData)
    local order = activeAppOrders[orderId]
    if not order then return end

    -- Map KDS status to app status
    local statusMap = {
        ['pending'] = 'pending',
        ['in_progress'] = 'preparing',
        ['preparing'] = 'preparing',
        ['ready'] = 'ready',
        ['out_for_delivery'] = 'on_the_way',
        ['completed'] = order.orderType == 'pickup' and 'picked_up' or 'delivered',
        ['delivered'] = 'delivered',
        ['cancelled'] = 'cancelled',
    }

    local appStatus = statusMap[newStatus]
    if appStatus then
        order.status = appStatus

        -- Track delivery start time and driver for timeout
        if newStatus == 'out_for_delivery' then
            order.deliveryStartedAt = os.time()
            -- Set the assigned driver from the extra data
            if extraData and extraData.driverCitizenid then
                order.assignedTo = extraData.driverCitizenid
            end
        end

        -- Update database
        MySQL.update.await([[
            UPDATE restaurant_app_orders SET status = ? WHERE order_id = ?
        ]], { appStatus, orderId })

        -- Notify customer
        notifyCustomer(order.customerCitizenid, 'free-restaurants-app:orderStatusUpdate', {
            orderId = orderId,
            status = appStatus,
        })

        print(('[Food Hub] Order %s status updated to %s (from KDS: %s)'):format(orderId, appStatus, newStatus))
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetRestaurantStatus', function(job)
    return restaurantStatus[job]
end)

exports('IsRestaurantOpen', function(job)
    local status = restaurantStatus[job]
    return status and status.open or false
end)

-- ============================================================================
-- DELIVERY TIMEOUT CLEANUP
-- ============================================================================

local DELIVERY_TIMEOUT_MINUTES = 10

--- Cancel a delivery due to timeout and refund customer
---@param orderId string
local function cancelDeliveryTimeout(orderId)
    local order = activeAppOrders[orderId]
    if not order then return end

    print(('[Food Hub] Delivery timeout for order %s - refunding customer'):format(orderId))

    -- Refund the customer
    local players = exports.qbx_core:GetQBPlayers()
    for _, p in pairs(players) do
        if p.PlayerData.citizenid == order.customerCitizenid then
            p.Functions.AddMoney('bank', order.total, 'food-hub-delivery-timeout-refund')

            TriggerClientEvent('ox_lib:notify', p.PlayerData.source, {
                title = 'Delivery Failed',
                description = ('Order #%s could not be delivered. You have been refunded $%d.'):format(orderId, order.total),
                type = 'error',
                duration = 10000,
            })
            break
        end
    end

    -- Deduct from business account
    exports['free-restaurants']:UpdateBusinessBalance(
        order.job,
        -order.total,
        'refund',
        ('Delivery Timeout Refund - #%s'):format(orderId),
        nil
    )

    -- Notify the driver if online
    if order.assignedTo then
        for _, p in pairs(players) do
            if p.PlayerData.citizenid == order.assignedTo then
                TriggerClientEvent('ox_lib:notify', p.PlayerData.source, {
                    title = 'Delivery Expired',
                    description = ('Order #%s delivery timed out and has been cancelled.'):format(orderId),
                    type = 'error',
                    duration = 10000,
                })

                -- Clear the driver's delivery blip
                TriggerClientEvent('free-restaurants-app:clearDelivery', p.PlayerData.source)
                break
            end
        end
    end

    -- Update order status
    order.status = 'cancelled'

    -- Update database
    MySQL.update.await([[
        UPDATE restaurant_app_orders SET status = 'cancelled' WHERE order_id = ?
    ]], { orderId })

    -- Also cancel in main restaurant KDS
    exports['free-restaurants']:CancelOrder(orderId, 'Delivery timeout', false)

    -- Remove from active orders
    activeAppOrders[orderId] = nil
end

-- Cleanup thread for expired deliveries
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute

        local currentTime = os.time()
        local timeoutSeconds = DELIVERY_TIMEOUT_MINUTES * 60

        for orderId, order in pairs(activeAppOrders) do
            -- Check if order is out for delivery and has timed out
            if order.status == 'on_the_way' and order.deliveryStartedAt then
                local elapsed = currentTime - order.deliveryStartedAt
                if elapsed > timeoutSeconds then
                    cancelDeliveryTimeout(orderId)
                end
            end
        end
    end
end)

print('[Food Hub] server/main.lua loaded')
