--[[
    free-restaurants Server Customers System
    
    Handles:
    - Order placement and validation
    - Payment processing
    - Order queue management
    - Order completion and delivery
    - Customer notifications
    
    DEPENDENCIES:
    - server/main.lua
    - qbx_core
    - ox_inventory
    - oxmysql
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

-- Active orders: [orderId] = orderData
local activeOrders = {}

-- Order counter for generating IDs
local orderCounter = 0

-- Forward declarations for functions used before definition
local notifyStaff, notifyCustomer

-- ============================================================================
-- ORDER ID GENERATION
-- ============================================================================

--- Generate a unique order ID
---@return string orderId
local function generateOrderId()
    orderCounter = orderCounter + 1
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    local id = ''
    
    -- Add timestamp component
    local time = os.time() % 10000
    
    for i = 1, 4 do
        local idx = math.random(1, #chars)
        id = id .. chars:sub(idx, idx)
    end
    
    return id .. tostring(time):sub(-2)
end

-- ============================================================================
-- PRICING
-- ============================================================================

--- Get item price (with custom pricing support)
---@param job string
---@param itemId string
---@return number price
local function getItemPrice(job, itemId)
    -- Check custom pricing first
    local customPrice = MySQL.scalar.await([[
        SELECT price FROM restaurant_pricing WHERE job = ? AND item_id = ?
    ]], { job, itemId })

    if customPrice then
        return customPrice
    end

    -- Fall back to recipe base price (recipes are in Config.Recipes.Items)
    local recipe = Config.Recipes and Config.Recipes.Items and Config.Recipes.Items[itemId]
    if recipe then
        return recipe.basePrice or recipe.price or 0
    end

    return 0
end

--- Calculate order total
---@param job string
---@param items table Array of { id, amount }
---@return number subtotal
---@return number tax
---@return number total
local function calculateOrderTotal(job, items)
    local subtotal = 0

    for _, item in ipairs(items) do
        local itemId = item.id or item.item
        local price = getItemPrice(job, itemId)
        local amount = item.amount or item.quantity or 1
        local itemTotal = price * amount

        print(('[free-restaurants] calculateOrderTotal: itemId=%s, price=%d, amount=%d, itemTotal=%d'):format(
            itemId or 'nil', price or 0, amount, itemTotal
        ))

        subtotal = subtotal + itemTotal
    end

    local taxRate = Config.Settings and Config.Settings.Economy and Config.Settings.Economy.taxRate or 0
    local tax = math.floor(subtotal * taxRate)
    local total = subtotal + tax

    return subtotal, tax, total
end

-- ============================================================================
-- ORDER MANAGEMENT
-- ============================================================================

--- Create a new order
---@param customerSource number
---@param job string
---@param locationKey string
---@param items table
---@param paymentMethod string 'cash' or 'card'
---@return string|nil orderId
---@return string|nil error
local function createOrder(customerSource, job, locationKey, items, paymentMethod)
    local customer = exports.qbx_core:GetPlayer(customerSource)
    if not customer then return nil, 'Invalid customer' end

    -- Calculate total
    local subtotal, tax, total = calculateOrderTotal(job, items)

    print(('[free-restaurants] createOrder: job=%s, subtotal=%d, tax=%d, total=%d'):format(
        job or 'nil', subtotal or 0, tax or 0, total or 0
    ))

    -- Validate payment
    local moneyType = paymentMethod == 'cash' and 'cash' or 'bank'
    local customerMoney = customer.PlayerData.money[moneyType] or 0

    print(('[free-restaurants] createOrder: paymentMethod=%s, moneyType=%s, customerMoney=%d, total=%d'):format(
        paymentMethod or 'nil', moneyType, customerMoney, total or 0
    ))

    if customerMoney < total then
        return nil, ('Insufficient funds (has $%d, needs $%d)'):format(customerMoney, total)
    end
    
    -- Generate order ID
    local orderId = generateOrderId()
    
    -- Process payment
    customer.Functions.RemoveMoney(moneyType, total, 'restaurant-order')
    
    -- Add to business (minus employee cut if configured)
    local businessCut = Config.Settings and Config.Settings.Economy and Config.Settings.Economy.businessCut or 1.0
    local businessAmount = math.floor(total * businessCut)
    
    exports['free-restaurants']:UpdateBusinessBalance(
        job,
        businessAmount,
        'sale',
        ('Order #%s'):format(orderId),
        customer.PlayerData.citizenid
    )
    
    -- Create order record
    local orderData = {
        id = orderId,
        job = job,
        locationKey = locationKey,
        customerId = customer.PlayerData.citizenid,
        customerName = ('%s %s'):format(
            customer.PlayerData.charinfo.firstname,
            customer.PlayerData.charinfo.lastname
        ),
        customerSource = customerSource,
        items = items,
        subtotal = subtotal,
        tax = tax,
        total = total,
        tip = 0,
        status = 'pending',
        createdAt = os.time(),
        paymentMethod = paymentMethod,
    }
    
    -- Store in memory
    activeOrders[orderId] = orderData
    
    -- Store in database
    MySQL.insert.await([[
        INSERT INTO restaurant_orders (id, job, customer_citizenid, customer_name, items, total, status)
        VALUES (?, ?, ?, ?, ?, ?, 'pending')
    ]], {
        orderId,
        job,
        customer.PlayerData.citizenid,
        orderData.customerName,
        json.encode(items),
        total
    })
    
    -- Notify restaurant staff
    notifyStaff(job, 'new_order', orderData)

    -- Give customer a receipt item with order metadata
    local receiptMetadata = {
        orderId = orderId,
        restaurant = job,
        locationKey = locationKey,
        customerName = orderData.customerName,
        items = items,
        subtotal = subtotal,
        tax = tax,
        total = total,
        paymentMethod = paymentMethod,
        timestamp = os.time(),
        description = ('Order #%s - $%d'):format(orderId, total),
    }

    -- Try to give receipt item (won't error if item doesn't exist)
    local receiptGiven = exports.ox_inventory:AddItem(customerSource, 'restaurant_receipt', 1, receiptMetadata)
    if receiptGiven then
        print(('[free-restaurants] Receipt given to customer for order #%s'):format(orderId))
    end

    print(('[free-restaurants] New order #%s from %s at %s (total: %d)'):format(
        orderId, customer.PlayerData.citizenid, job, total
    ))

    return orderId, nil
end

--- Update order status
---@param orderId string
---@param status string
---@param employeeSource? number
---@return boolean success
local function updateOrderStatus(orderId, status, employeeSource)
    local order = activeOrders[orderId]
    if not order then return false end
    
    order.status = status
    order.updatedAt = os.time()
    
    if employeeSource then
        local employee = exports.qbx_core:GetPlayer(employeeSource)
        if employee then
            order.employeeCitizenid = employee.PlayerData.citizenid
            order.employeeName = ('%s %s'):format(
                employee.PlayerData.charinfo.firstname,
                employee.PlayerData.charinfo.lastname
            )
        end
    end
    
    -- Update database
    MySQL.update.await([[
        UPDATE restaurant_orders SET status = ?, employee_citizenid = ? WHERE id = ?
    ]], { status, order.employeeCitizenid, orderId })
    
    -- Notify relevant parties
    if status == 'ready' then
        -- Notify customer their order is ready
        notifyCustomer(order.customerSource, 'order_ready', order)
    end
    
    -- Notify staff of status change
    notifyStaff(order.job, 'order_update', order)
    
    return true
end

--- Complete an order
---@param orderId string
---@param employeeSource number
---@return boolean success
---@return number earnings
local function completeOrder(orderId, employeeSource)
    local order = activeOrders[orderId]
    if not order then return false, 0 end
    
    local employee = exports.qbx_core:GetPlayer(employeeSource)
    if not employee then return false, 0 end
    
    -- Calculate employee earnings
    local employeeCut = Config.Settings and Config.Settings.Economy and (1 - Config.Settings.Economy.businessCut) or 0
    local baseEarnings = math.floor(order.total * employeeCut)
    local tipEarnings = order.tip or 0
    local totalEarnings = baseEarnings + tipEarnings
    
    -- Pay employee
    if totalEarnings > 0 then
        employee.Functions.AddMoney('cash', totalEarnings, 'restaurant-order-completion')
        
        -- Track session earnings
        exports['free-restaurants']:AddSessionEarnings(employeeSource, totalEarnings, 'order')
    end
    
    -- Update order status
    order.status = 'completed'
    order.completedAt = os.time()
    order.employeeCitizenid = employee.PlayerData.citizenid
    
    -- Update database
    MySQL.update.await([[
        UPDATE restaurant_orders SET 
            status = 'completed',
            completed_at = NOW(),
            employee_citizenid = ?,
            tip = ?
        WHERE id = ?
    ]], { employee.PlayerData.citizenid, tipEarnings, orderId })
    
    -- Track task completion
    exports['free-restaurants']:IncrementTasks(employeeSource)
    
    -- Move to completed (remove from active)
    activeOrders[orderId] = nil
    
    print(('[free-restaurants] Order #%s completed by %s (earnings: %d)'):format(
        orderId, employee.PlayerData.citizenid, totalEarnings
    ))
    
    return true, totalEarnings
end

--- Cancel an order
---@param orderId string
---@param reason? string
---@param refund? boolean
---@return boolean success
local function cancelOrder(orderId, reason, refund)
    local order = activeOrders[orderId]
    if not order then return false end
    
    -- Process refund if requested and customer is online
    if refund then
        local customer = exports.qbx_core:GetPlayer(order.customerSource)
        if customer then
            customer.Functions.AddMoney('bank', order.total, 'restaurant-refund')
            
            -- Deduct from business
            exports['free-restaurants']:UpdateBusinessBalance(
                order.job,
                -order.total,
                'refund',
                ('Refund for order #%s'):format(orderId),
                nil
            )
            
            TriggerClientEvent('ox_lib:notify', order.customerSource, {
                title = 'Order Refunded',
                description = ('Order #%s has been cancelled and refunded.'):format(orderId),
                type = 'inform',
            })
        end
    end
    
    -- Update status
    order.status = 'cancelled'
    order.cancelledAt = os.time()
    order.cancelReason = reason
    
    -- Update database
    MySQL.update.await([[
        UPDATE restaurant_orders SET status = 'cancelled' WHERE id = ?
    ]], { orderId })
    
    -- Remove from active
    activeOrders[orderId] = nil
    
    -- Notify staff
    notifyStaff(order.job, 'order_cancelled', order)
    
    return true
end

--- Get pickup stash ID for a location
---@param job string
---@param locationKey string
---@return string stashId
local function getPickupStashId(job, locationKey)
    return ('restaurant_pickup_%s'):format(locationKey or job)
end

--- Customer picks up order
---@param orderId string
---@param customerSource number
---@return boolean success
---@return string|nil message
local function pickupOrder(orderId, customerSource)
    local order = activeOrders[orderId]
    if not order then return false, 'Order not found' end

    -- Verify customer
    local customer = exports.qbx_core:GetPlayer(customerSource)
    if not customer or customer.PlayerData.citizenid ~= order.customerId then
        return false, 'Not your order'
    end

    -- Verify order is ready
    if order.status ~= 'ready' then
        return false, 'Order not ready'
    end

    -- Get pickup stash for this location
    local stashId = getPickupStashId(order.job, order.locationKey)

    -- Check if items are available in pickup stash
    local stashItems = exports.ox_inventory:GetInventoryItems(stashId)
    local missingItems = {}

    for _, orderItem in ipairs(order.items) do
        local itemName = orderItem.resultItem or orderItem.id or orderItem.item
        local neededAmount = orderItem.amount or orderItem.quantity or 1

        -- Check if item exists in stash with this order ID
        local foundAmount = 0
        if stashItems then
            for _, stashItem in pairs(stashItems) do
                if stashItem.name == itemName then
                    -- Check if metadata matches this order (optional - for strict matching)
                    if stashItem.metadata and stashItem.metadata.orderId == orderId then
                        foundAmount = foundAmount + stashItem.count
                    elseif not stashItem.metadata or not stashItem.metadata.orderId then
                        -- Allow items without order metadata (simpler workflow)
                        foundAmount = foundAmount + stashItem.count
                    end
                end
            end
        end

        if foundAmount < neededAmount then
            table.insert(missingItems, {
                name = itemName,
                label = orderItem.label or itemName,
                needed = neededAmount,
                found = foundAmount
            })
        end
    end

    -- If items are missing, notify and fail
    if #missingItems > 0 then
        local missingStr = table.concat(
            lib.table.map(missingItems, function(i) return i.label end),
            ', '
        )
        return false, ('Items not ready: %s'):format(missingStr)
    end

    -- Transfer items from pickup stash to customer
    for _, orderItem in ipairs(order.items) do
        local itemName = orderItem.resultItem or orderItem.id or orderItem.item
        local amount = orderItem.amount or orderItem.quantity or 1

        -- Remove from stash
        exports.ox_inventory:RemoveItem(stashId, itemName, amount)

        -- Give to customer with fresh metadata
        local metadata = {
            quality = 100,
            freshness = 100,
        }
        exports.ox_inventory:AddItem(customerSource, itemName, amount, metadata)
    end

    -- Mark as delivered
    order.status = 'delivered'
    order.deliveredAt = os.time()

    -- Update database
    MySQL.update.await([[
        UPDATE restaurant_orders SET status = 'delivered', completed_at = NOW() WHERE id = ?
    ]], { orderId })

    -- Remove from active
    activeOrders[orderId] = nil

    print(('[free-restaurants] Order #%s picked up by %s'):format(orderId, customer.PlayerData.citizenid))

    return true, nil
end

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================

--- Notify restaurant staff
---@param job string
---@param eventType string
---@param data table
notifyStaff = function(job, eventType, data)
    local players = exports.qbx_core:GetQBPlayers()

    for _, player in pairs(players) do
        if player.PlayerData.job.name == job and player.PlayerData.job.onduty then
            TriggerClientEvent('free-restaurants:client:orderEvent', player.PlayerData.source, eventType, data)
        end
    end
end

--- Notify customer
---@param customerSource number
---@param eventType string
---@param data table
notifyCustomer = function(customerSource, eventType, data)
    if not customerSource then return end
    
    local player = exports.qbx_core:GetPlayer(customerSource)
    if not player then return end
    
    if eventType == 'order_ready' then
        TriggerClientEvent('ox_lib:notify', customerSource, {
            title = 'Order Ready',
            description = ('Order #%s is ready for pickup!'):format(data.id),
            type = 'success',
            icon = 'bell',
            duration = 10000,
        })
        
        TriggerClientEvent('free-restaurants:client:orderReady', customerSource, data)
    end
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

--- Place order callback
lib.callback.register('free-restaurants:server:placeOrder', function(source, locationKey, items, paymentMethod, expectedTotal)
    -- Get job from location
    local job = nil
    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' then
            for locId, locData in pairs(locations) do
                local key = ('%s_%s'):format(restaurantType, locId)
                if key == locationKey and locData.job then
                    job = locData.job
                    break
                end
            end
        end
        if job then break end
    end
    
    if not job then
        -- Try to extract from location key
        job = locationKey:match('^([^_]+)')
    end
    
    if not job then
        return false, nil, 'Invalid location'
    end
    
    local orderId, error = createOrder(source, job, locationKey, items, paymentMethod)
    
    if orderId then
        return true, orderId, nil
    else
        return false, nil, error
    end
end)

--- Place register order (staff places order, bills specific customer)
lib.callback.register('free-restaurants:server:placeRegisterOrder', function(source, locationKey, items, paymentMethod, customerServerId)
    -- Verify staff is on duty
    local staff = exports.qbx_core:GetPlayer(source)
    if not staff or not staff.PlayerData.job.onduty then
        return false, nil, 'Must be on duty'
    end

    -- Verify customer exists
    local customer = exports.qbx_core:GetPlayer(customerServerId)
    if not customer then
        return false, nil, 'Customer not found'
    end

    -- Get job from location
    local job = nil
    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' then
            for locId, locData in pairs(locations) do
                local key = ('%s_%s'):format(restaurantType, locId)
                if key == locationKey and locData.job then
                    job = locData.job
                    break
                end
            end
        end
        if job then break end
    end

    if not job then
        job = locationKey:match('^([^_]+)')
    end

    if not job then
        return false, nil, 'Invalid location'
    end

    -- Create order (bills the customer)
    local orderId, error = createOrder(customerServerId, job, locationKey, items, paymentMethod)

    if orderId then
        -- Notify customer
        TriggerClientEvent('ox_lib:notify', customerServerId, {
            title = 'Order Placed',
            description = ('Order #%s has been placed for you'):format(orderId),
            type = 'success',
        })
        return true, orderId, nil
    else
        return false, nil, error
    end
end)

--- Start working on order
lib.callback.register('free-restaurants:server:startOrder', function(source, orderId)
    return updateOrderStatus(orderId, 'in_progress', source)
end)

--- Claim order (alias for startOrder - staff claims to work on it)
lib.callback.register('free-restaurants:server:claimOrder', function(source, orderId)
    return updateOrderStatus(orderId, 'in_progress', source)
end)

--- Mark order as ready
lib.callback.register('free-restaurants:server:readyOrder', function(source, orderId)
    return updateOrderStatus(orderId, 'ready', source)
end)

--- Complete order (staff side)
lib.callback.register('free-restaurants:server:completeOrder', function(source, orderId)
    return completeOrder(orderId, source)
end)

--- Cancel order
lib.callback.register('free-restaurants:server:cancelOrder', function(source, orderId, reason)
    local order = activeOrders[orderId]
    if not order then return false end
    
    -- Verify employee has permission
    local player = exports.qbx_core:GetPlayer(source)
    if not player or player.PlayerData.job.name ~= order.job then
        return false
    end
    
    -- Orders in progress or ready get refunded
    local shouldRefund = order.status ~= 'pending'
    
    return cancelOrder(orderId, reason, shouldRefund)
end)

--- Pickup order (customer side)
lib.callback.register('free-restaurants:server:pickupOrder', function(source, orderId)
    return pickupOrder(orderId, source)
end)

--- Get active orders for location
lib.callback.register('free-restaurants:server:getOrders', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or player.PlayerData.job.name ~= job then
        return {}
    end
    
    local orders = {}
    for orderId, order in pairs(activeOrders) do
        if order.job == job then
            table.insert(orders, order)
        end
    end
    
    -- Sort by creation time
    table.sort(orders, function(a, b)
        return a.createdAt < b.createdAt
    end)
    
    return orders
end)

--- Get customer's pending order
lib.callback.register('free-restaurants:server:getMyOrder', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    
    for orderId, order in pairs(activeOrders) do
        if order.customerId == player.PlayerData.citizenid then
            return order
        end
    end
    
    return nil
end)

--- Add tip to order
lib.callback.register('free-restaurants:server:addTip', function(source, orderId, tipAmount)
    local order = activeOrders[orderId]
    if not order then return false end
    
    local customer = exports.qbx_core:GetPlayer(source)
    if not customer or customer.PlayerData.citizenid ~= order.customerId then
        return false
    end
    
    -- Check customer has money
    if customer.PlayerData.money.cash < tipAmount then
        return false
    end
    
    -- Process tip
    customer.Functions.RemoveMoney('cash', tipAmount, 'restaurant-tip')
    order.tip = (order.tip or 0) + tipAmount
    
    -- Notify staff
    notifyStaff(order.job, 'tip_received', {
        orderId = orderId,
        amount = tipAmount,
    })
    
    return true
end)

--- Open pickup stash for staff
RegisterNetEvent('free-restaurants:server:openPickupStash', function(locationKey)
    local source = source
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    -- Check if on duty
    if not player.PlayerData.job.onduty then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Not On Duty',
            description = 'You must be on duty to access the pickup area.',
            type = 'error',
        })
        return
    end

    local job = player.PlayerData.job.name
    local stashId = getPickupStashId(job, locationKey)

    -- Register stash if not already registered (staff access)
    exports.ox_inventory:RegisterStash(stashId, 'Order Pickup', 20, 50000, nil, { [job] = 0 })

    -- Open the stash
    exports.ox_inventory:forceOpenInventory(source, 'stash', stashId)
end)

--- Open pickup stash for customers (no job restriction)
RegisterNetEvent('free-restaurants:server:openCustomerPickupStash', function(locationKey)
    local source = source
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    -- Get job from location key
    local job = locationKey:match('^([^_]+)')
    if not job then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Invalid pickup location.',
            type = 'error',
        })
        return
    end

    local stashId = getPickupStashId(job, locationKey)

    -- Register stash without job restrictions for customer access
    exports.ox_inventory:RegisterStash(stashId, 'Order Pickup', 20, 50000)

    -- Open the stash
    exports.ox_inventory:forceOpenInventory(source, 'stash', stashId)
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

--- Clean up old orders periodically
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        
        local currentTime = os.time()
        local expireTime = 3600 -- 1 hour
        
        for orderId, order in pairs(activeOrders) do
            if currentTime - order.createdAt > expireTime then
                -- Cancel expired orders
                cancelOrder(orderId, 'Order expired', true)
            end
        end
    end
end)

-- ============================================================================
-- DELIVERY ORDER CREATION
-- ============================================================================

--- Create a delivery order (no payment required - goes to KDS for cooking)
---@param job string
---@param locationKey string
---@param deliveryId string
---@param items table
---@param destination table
---@param employeeSource number The delivery driver who accepted
---@return string|nil orderId
---@return string|nil error
local function createDeliveryOrder(job, locationKey, deliveryId, items, destination, employeeSource)
    local employee = exports.qbx_core:GetPlayer(employeeSource)
    if not employee then return nil, 'Invalid employee' end

    -- Use delivery ID directly as order ID (already has DEL prefix)
    local orderId = deliveryId

    -- Create order record (no payment processing)
    local orderData = {
        id = orderId,
        job = job,
        locationKey = locationKey,
        customerId = 'DELIVERY',
        customerName = ('Delivery: %s'):format(destination.label or 'Customer'),
        customerSource = nil, -- No customer source for deliveries
        items = items,
        subtotal = 0,
        tax = 0,
        total = 0,
        tip = 0,
        status = 'pending',
        createdAt = os.time(),
        paymentMethod = 'delivery',
        isDelivery = true,
        deliveryId = deliveryId,
        deliveryDestination = destination,
        deliveryDriverSource = employeeSource,
        deliveryDriverCitizenid = employee.PlayerData.citizenid,
    }

    -- Store in memory
    activeOrders[orderId] = orderData

    -- Store in database
    MySQL.insert.await([[
        INSERT INTO restaurant_orders (id, job, customer_citizenid, customer_name, items, total, status)
        VALUES (?, ?, 'DELIVERY', ?, ?, 0, 'pending')
    ]], {
        orderId,
        job,
        orderData.customerName,
        json.encode(items),
    })

    -- Notify restaurant staff
    notifyStaff(job, 'new_order', orderData)

    print(('[free-restaurants] New DELIVERY order #%s for delivery %s at %s'):format(
        orderId, deliveryId, job
    ))

    return orderId, nil
end

--- Check if delivery order is ready for pickup
---@param deliveryId string
---@return boolean ready
---@return string|nil orderId
local function isDeliveryOrderReady(deliveryId)
    local orderId = ('DEL-%s'):format(deliveryId)
    local order = activeOrders[orderId]

    if not order then return false, nil end

    return order.status == 'ready', orderId
end

--- Get delivery order by delivery ID
---@param deliveryId string
---@return table|nil order
local function getDeliveryOrder(deliveryId)
    local orderId = ('DEL-%s'):format(deliveryId)
    return activeOrders[orderId]
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('CreateOrder', createOrder)
exports('UpdateOrderStatus', updateOrderStatus)
exports('CompleteOrder', completeOrder)
exports('CancelOrder', cancelOrder)
exports('GetActiveOrders', function() return activeOrders end)
exports('CreateDeliveryOrder', createDeliveryOrder)
exports('IsDeliveryOrderReady', isDeliveryOrderReady)
exports('GetDeliveryOrder', getDeliveryOrder)

print('[free-restaurants] server/customers.lua loaded')
