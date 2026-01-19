--[[
    free-restaurants Client Orders System
    
    Handles:
    - Order queue display (Kitchen Display System / KDS)
    - Order status tracking
    - Order completion workflow
    - Order history
    - Customer notifications
    
    DEPENDENCIES:
    - client/main.lua (state management)
    - ox_lib (UI components)
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local activeOrders = {}             -- Current active orders
local orderHistory = {}             -- Completed orders (recent)
local kdsVisible = false            -- KDS panel visibility
local selectedOrder = nil           -- Currently selected order in KDS

-- Order statuses
local ORDER_STATUS = {
    PENDING = 'pending',
    IN_PROGRESS = 'in_progress',
    READY = 'ready',
    DELIVERED = 'delivered',
    CANCELLED = 'cancelled',
}

-- Forward declarations for functions used before definition
local openKDS
local closeKDS
local openOrderDetails
local refreshKDS

-- ============================================================================
-- ORDER MANAGEMENT
-- ============================================================================

--- Add a new order to the queue
---@param orderData table Order data from server
local function addOrder(orderData)
    activeOrders[orderData.id] = {
        id = orderData.id,
        items = orderData.items,
        customerId = orderData.customerId,
        customerName = orderData.customerName,
        status = ORDER_STATUS.PENDING,
        createdAt = GetGameTimer(),
        priority = orderData.priority or 1,
        notes = orderData.notes,
        total = orderData.total,
        tip = orderData.tip,
    }
    
    FreeRestaurants.Utils.Debug(('New order received: %s'):format(orderData.id))
    
    -- Notify staff
    if FreeRestaurants.Client.IsOnDuty() then
        lib.notify({
            title = 'New Order',
            description = ('Order #%s from %s'):format(orderData.id, orderData.customerName or 'Customer'),
            type = 'inform',
            icon = 'bell',
            duration = 5000,
        })
        
        -- Play sound
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
    
    -- Update KDS if visible
    if kdsVisible then
        refreshKDS()
    end
    
    -- Trigger event
    TriggerEvent('free-restaurants:client:newOrder', orderData)
end

--- Update order status
---@param orderId string Order ID
---@param status string New status
---@param data? table Additional data
local function updateOrderStatus(orderId, status, data)
    local order = activeOrders[orderId]
    if not order then return end
    
    order.status = status
    order.updatedAt = GetGameTimer()
    
    if data then
        for k, v in pairs(data) do
            order[k] = v
        end
    end
    
    FreeRestaurants.Utils.Debug(('Order %s status: %s'):format(orderId, status))
    
    -- Update KDS if visible
    if kdsVisible then
        refreshKDS()
    end
    
    -- Trigger event
    TriggerEvent('free-restaurants:client:orderUpdated', orderId, status, order)
end

--- Start working on an order
---@param orderId string Order ID
local function claimOrder(orderId)
    local order = activeOrders[orderId]
    if not order then
        lib.notify({
            title = 'Order Not Found',
            description = 'This order no longer exists.',
            type = 'error',
        })
        return
    end
    
    if order.status ~= ORDER_STATUS.PENDING then
        lib.notify({
            title = 'Order Unavailable',
            description = 'This order is already being worked on.',
            type = 'error',
        })
        return
    end
    
    -- Claim on server
    local success = lib.callback.await('free-restaurants:server:claimOrder', false, orderId)
    
    if success then
        local playerData = exports.qbx_core:GetPlayerData()
        updateOrderStatus(orderId, ORDER_STATUS.IN_PROGRESS, {
            claimedBy = playerData and playerData.citizenid,
            claimedAt = GetGameTimer(),
        })
        
        lib.notify({
            title = 'Order Claimed',
            description = ('You are now working on order #%s'):format(orderId),
            type = 'success',
        })
    else
        lib.notify({
            title = 'Failed',
            description = 'Could not claim this order.',
            type = 'error',
        })
    end
end

--- Mark order as ready for pickup
---@param orderId string Order ID
local function markOrderReady(orderId)
    local order = activeOrders[orderId]
    if not order then return end
    
    if order.status ~= ORDER_STATUS.IN_PROGRESS then
        lib.notify({
            title = 'Invalid Status',
            description = 'This order is not in progress.',
            type = 'error',
        })
        return
    end
    
    -- Confirm items are ready
    local confirm = lib.alertDialog({
        header = 'Mark Order Ready',
        content = ('Mark order #%s as ready for pickup?'):format(orderId),
        centered = true,
        cancel = true,
    })
    
    if confirm ~= 'confirm' then return end
    
    -- Update on server
    local success = lib.callback.await('free-restaurants:server:readyOrder', false, orderId)
    
    if success then
        updateOrderStatus(orderId, ORDER_STATUS.READY, {
            readyAt = GetGameTimer(),
        })
        
        lib.notify({
            title = 'Order Ready',
            description = ('Order #%s is ready for pickup!'):format(orderId),
            type = 'success',
        })
    end
end

--- Complete order delivery
---@param orderId string Order ID
local function completeOrder(orderId)
    local order = activeOrders[orderId]
    if not order then return end
    
    -- Update on server
    local success, earnings = lib.callback.await('free-restaurants:server:completeOrder', false, orderId)
    
    if success then
        -- Move to history
        order.status = ORDER_STATUS.DELIVERED
        order.completedAt = GetGameTimer()
        orderHistory[orderId] = order
        activeOrders[orderId] = nil
        
        local message = ('Order #%s completed!'):format(orderId)
        if earnings and earnings > 0 then
            message = message .. (' You earned %s'):format(FreeRestaurants.Utils.FormatMoney(earnings))
        end
        
        lib.notify({
            title = 'Order Complete',
            description = message,
            type = 'success',
        })
        
        -- Update KDS
        if kdsVisible then
            refreshKDS()
        end
    end
end

--- Cancel an order
---@param orderId string Order ID
---@param reason? string Cancellation reason
local function cancelOrder(orderId, reason)
    local order = activeOrders[orderId]
    if not order then return end
    
    -- Confirm cancellation
    local input = lib.inputDialog('Cancel Order', {
        {
            type = 'input',
            label = 'Reason (optional)',
            placeholder = 'Why is this order being cancelled?',
        },
    })
    
    reason = input and input[1] or reason
    
    -- Update on server
    local success = lib.callback.await('free-restaurants:server:cancelOrder', false, orderId, reason)
    
    if success then
        order.status = ORDER_STATUS.CANCELLED
        order.cancelledAt = GetGameTimer()
        order.cancelReason = reason
        orderHistory[orderId] = order
        activeOrders[orderId] = nil
        
        lib.notify({
            title = 'Order Cancelled',
            description = ('Order #%s has been cancelled.'):format(orderId),
            type = 'inform',
        })
        
        if kdsVisible then
            refreshKDS()
        end
    end
end

-- ============================================================================
-- KITCHEN DISPLAY SYSTEM (KDS)
-- ============================================================================

--- Build KDS menu options
---@return table options
local function buildKDSOptions()
    local options = {}
    local sortedOrders = {}
    
    -- Sort orders by priority and time
    for id, order in pairs(activeOrders) do
        table.insert(sortedOrders, order)
    end
    
    table.sort(sortedOrders, function(a, b)
        -- Ready orders first
        if a.status == ORDER_STATUS.READY and b.status ~= ORDER_STATUS.READY then
            return true
        elseif a.status ~= ORDER_STATUS.READY and b.status == ORDER_STATUS.READY then
            return false
        end
        -- Then by priority
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        -- Then by age
        return a.createdAt < b.createdAt
    end)
    
    -- Add order count header
    local pendingCount = 0
    local inProgressCount = 0
    local readyCount = 0
    
    for _, order in ipairs(sortedOrders) do
        if order.status == ORDER_STATUS.PENDING then
            pendingCount = pendingCount + 1
        elseif order.status == ORDER_STATUS.IN_PROGRESS then
            inProgressCount = inProgressCount + 1
        elseif order.status == ORDER_STATUS.READY then
            readyCount = readyCount + 1
        end
    end
    
    table.insert(options, {
        title = ('ðŸ“‹ %d Pending | ðŸ”„ %d In Progress | âœ… %d Ready'):format(
            pendingCount, inProgressCount, readyCount
        ),
        disabled = true,
    })
    
    -- Add each order
    for _, order in ipairs(sortedOrders) do
        local statusIcon = 'ðŸ“‹'
        local statusColor = '#ffffff'
        
        if order.status == ORDER_STATUS.IN_PROGRESS then
            statusIcon = 'ðŸ”„'
            statusColor = '#f59e0b'
        elseif order.status == ORDER_STATUS.READY then
            statusIcon = 'âœ…'
            statusColor = '#22c55e'
        end
        
        -- Build item list
        local itemList = {}
        for _, item in ipairs(order.items) do
            table.insert(itemList, ('%dx %s'):format(item.amount, item.label))
        end
        
        -- Calculate wait time
        local waitTime = math.floor((GetGameTimer() - order.createdAt) / 1000)
        local waitStr = waitTime < 60 and ('%ds'):format(waitTime) or ('%dm'):format(math.floor(waitTime / 60))
        
        table.insert(options, {
            title = ('%s Order #%s - %s'):format(statusIcon, order.id, order.customerName or 'Customer'),
            description = table.concat(itemList, ', '),
            icon = 'receipt',
            iconColor = statusColor,
            metadata = {
                { label = 'Wait Time', value = waitStr },
                { label = 'Total', value = FreeRestaurants.Utils.FormatMoney(order.total or 0) },
            },
            onSelect = function()
                openOrderDetails(order.id)
            end,
        })
    end
    
    if #sortedOrders == 0 then
        table.insert(options, {
            title = 'No Active Orders',
            description = 'Orders will appear here when placed.',
            icon = 'inbox',
            disabled = true,
        })
    end
    
    -- Add close option
    table.insert(options, {
        title = 'Close KDS',
        icon = 'times',
        onSelect = function()
            closeKDS()
        end,
    })
    
    return options
end

--- Open order details
---@param orderId string Order ID
function openOrderDetails(orderId)
    local order = activeOrders[orderId]
    if not order then return end
    
    local options = {}
    
    -- Order info header
    table.insert(options, {
        title = ('Order #%s'):format(order.id),
        description = ('From: %s'):format(order.customerName or 'Customer'),
        disabled = true,
    })
    
    -- Items list
    table.insert(options, {
        title = '--- Items ---',
        disabled = true,
    })
    
    for _, item in ipairs(order.items) do
        local customizations = ''
        if item.customizations and #item.customizations > 0 then
            customizations = ' (' .. table.concat(item.customizations, ', ') .. ')'
        end
        
        table.insert(options, {
            title = ('%dx %s%s'):format(item.amount, item.label, customizations),
            icon = 'utensils',
            disabled = true,
        })
    end
    
    -- Notes
    if order.notes and order.notes ~= '' then
        table.insert(options, {
            title = ('ðŸ“ Notes: %s'):format(order.notes),
            disabled = true,
        })
    end
    
    -- Actions based on status
    table.insert(options, {
        title = '--- Actions ---',
        disabled = true,
    })
    
    if order.status == ORDER_STATUS.PENDING then
        table.insert(options, {
            title = 'Start Order',
            description = 'Begin preparing this order',
            icon = 'play',
            onSelect = function()
                claimOrder(orderId)
            end,
        })
    elseif order.status == ORDER_STATUS.IN_PROGRESS then
        table.insert(options, {
            title = 'Mark Ready',
            description = 'Order is ready for pickup',
            icon = 'check',
            onSelect = function()
                markOrderReady(orderId)
            end,
        })
    elseif order.status == ORDER_STATUS.READY then
        table.insert(options, {
            title = 'Complete Order',
            description = 'Hand order to customer',
            icon = 'hand-holding',
            onSelect = function()
                completeOrder(orderId)
            end,
        })
    end
    
    table.insert(options, {
        title = 'Cancel Order',
        description = 'Cancel and refund this order',
        icon = 'ban',
        onSelect = function()
            cancelOrder(orderId)
        end,
    })
    
    table.insert(options, {
        title = 'Back to KDS',
        icon = 'arrow-left',
        onSelect = function()
            openKDS()
        end,
    })
    
    lib.registerContext({
        id = 'order_details',
        title = 'Order Details',
        menu = 'kds_menu',
        options = options,
    })
    
    lib.showContext('order_details')
end

--- Open KDS display
function openKDS()
    if not FreeRestaurants.Client.IsOnDuty() then
        lib.notify({
            title = 'Not On Duty',
            description = 'You must be on duty to view orders.',
            type = 'error',
        })
        return
    end
    
    kdsVisible = true
    
    lib.registerContext({
        id = 'kds_menu',
        title = 'Kitchen Display System',
        options = buildKDSOptions(),
    })
    
    lib.showContext('kds_menu')
end

--- Refresh KDS display
function refreshKDS()
    if not kdsVisible then return end
    
    lib.registerContext({
        id = 'kds_menu',
        title = 'Kitchen Display System',
        options = buildKDSOptions(),
    })
    
    -- Don't reshow if player has submenu open
end

--- Close KDS
function closeKDS()
    kdsVisible = false
    lib.hideContext()
end

-- ============================================================================
-- TARGET SETUP
-- ============================================================================

--- Setup KDS access points
local function setupKDSTargets()
    -- KDS targets are set up per-location in stations.lua
    -- This function provides the interaction handler
end

-- ============================================================================
-- SYNC FROM SERVER
-- ============================================================================

--- Sync orders from server
local function syncOrders()
    local locationKey = FreeRestaurants.Client.GetPlayerState('currentLocation')
    if not locationKey then return end
    
    local orders = lib.callback.await('free-restaurants:server:getOrders', false, locationKey)
    
    if orders then
        activeOrders = {}
        for _, order in ipairs(orders) do
            activeOrders[order.id] = order
        end
        
        FreeRestaurants.Utils.Debug(('Synced %d orders'):format(#orders))
        
        if kdsVisible then
            refreshKDS()
        end
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- New order from server
RegisterNetEvent('free-restaurants:client:newOrder', function(orderData)
    addOrder(orderData)
end)

-- Order update from server
RegisterNetEvent('free-restaurants:client:orderUpdate', function(orderId, status, data)
    updateOrderStatus(orderId, status, data)
end)

-- Order removed
RegisterNetEvent('free-restaurants:client:orderRemoved', function(orderId)
    activeOrders[orderId] = nil
    if kdsVisible then
        refreshKDS()
    end
end)

-- Sync orders on enter restaurant
RegisterNetEvent('free-restaurants:client:enteredRestaurant', function(locationKey, locationData)
    if FreeRestaurants.Client.IsOnDuty() then
        syncOrders()
    end
end)

-- Sync orders on clock in
RegisterNetEvent('free-restaurants:client:clockedIn', function()
    syncOrders()
end)

-- Clear orders on clock out
RegisterNetEvent('free-restaurants:client:clockedOut', function()
    activeOrders = {}
    closeKDS()
end)

-- Command to open KDS
RegisterCommand('kds', function()
    openKDS()
end, false)

-- Keybind for KDS (optional)
lib.addKeybind({
    name = 'free_restaurants_kds',
    description = 'Open Kitchen Display System',
    defaultKey = 'F6',
    onPressed = function()
        if FreeRestaurants.Client.IsOnDuty() then
            openKDS()
        end
    end,
})

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetActiveOrders', function() return activeOrders end)
exports('GetOrderById', function(id) return activeOrders[id] end)
exports('OpenKDS', openKDS)
exports('CloseKDS', closeKDS)
exports('ClaimOrder', claimOrder)
exports('MarkOrderReady', markOrderReady)
exports('CompleteOrder', completeOrder)
exports('CancelOrder', cancelOrder)
exports('SyncOrders', syncOrders)

-- Constants
exports('ORDER_STATUS', function() return ORDER_STATUS end)

FreeRestaurants.Utils.Debug('client/orders.lua loaded')
