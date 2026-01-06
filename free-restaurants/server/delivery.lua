--[[
    free-restaurants Server Delivery System
    
    Handles:
    - Delivery mission creation
    - Catering order management
    - Delivery tracking
    - Payment processing for deliveries
    
    DEPENDENCIES:
    - server/main.lua
    - server/customers.lua
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

-- Active deliveries: [deliveryId] = deliveryData
local activeDeliveries = {}

-- Delivery counter
local deliveryCounter = 0

-- Available delivery destinations (loaded from config)
local deliveryDestinations = {}

-- Available catering destinations
local cateringDestinations = {}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Load delivery destinations from config
local function loadDestinations()
    -- Load delivery destinations
    if Config.Locations and Config.Locations.DeliveryDestinations then
        for key, dest in pairs(Config.Locations.DeliveryDestinations) do
            deliveryDestinations[key] = dest
        end
    end
    
    -- Load catering destinations
    if Config.Locations and Config.Locations.CateringDestinations then
        for key, dest in pairs(Config.Locations.CateringDestinations) do
            cateringDestinations[key] = dest
        end
    end
    
    print(('[free-restaurants] Loaded %d delivery and %d catering destinations'):format(
        tableCount(deliveryDestinations),
        tableCount(cateringDestinations)
    ))
end

local function tableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- ============================================================================
-- DELIVERY GENERATION
-- ============================================================================

--- Generate a delivery ID
---@return string
local function generateDeliveryId()
    deliveryCounter = deliveryCounter + 1
    return ('DEL%06d'):format(deliveryCounter)
end

--- Get random delivery destination
---@return string key
---@return table destination
local function getRandomDeliveryDestination()
    local keys = {}
    for key, _ in pairs(deliveryDestinations) do
        table.insert(keys, key)
    end
    
    if #keys == 0 then return nil, nil end
    
    local randomKey = keys[math.random(#keys)]
    return randomKey, deliveryDestinations[randomKey]
end

--- Generate delivery items based on destination
---@param destination table
---@param job string
---@return table items
---@return number total
local function generateDeliveryItems(destination, job)
    local items = {}
    local total = 0
    
    -- Get random menu items appropriate for the restaurant
    local menuItems = {}
    for recipeId, recipe in pairs(Config.Recipes) do
        if recipe.canDeliver ~= false then -- Default to deliverable
            local matchesJob = false
            if recipe.restaurantType then
                if type(recipe.restaurantType) == 'table' then
                    for _, rt in ipairs(recipe.restaurantType) do
                        if rt == job then matchesJob = true break end
                    end
                else
                    matchesJob = recipe.restaurantType == job
                end
            else
                matchesJob = true -- Generic item
            end
            
            if matchesJob then
                table.insert(menuItems, {
                    id = recipeId,
                    label = recipe.label,
                    price = recipe.price or 10,
                    resultItem = recipe.result and (type(recipe.result) == 'table' and recipe.result.item or recipe.result),
                })
            end
        end
    end
    
    -- Generate 1-5 items for delivery
    local itemCount = math.random(1, 5)
    
    for i = 1, math.min(itemCount, #menuItems) do
        local item = menuItems[math.random(#menuItems)]
        local quantity = math.random(1, 3)
        
        table.insert(items, {
            id = item.id,
            label = item.label,
            amount = quantity,
            price = item.price,
            resultItem = item.resultItem,
        })
        
        total = total + (item.price * quantity)
    end
    
    return items, total
end

--- Create a new delivery mission
---@param job string Restaurant job
---@param locationKey string Source location
---@param employeeSource number Employee taking delivery
---@return table|nil delivery
---@return string|nil error
local function createDelivery(job, locationKey, employeeSource)
    local employee = exports.qbx_core:GetPlayer(employeeSource)
    if not employee then return nil, 'Invalid employee' end
    
    -- Get random destination
    local destKey, destination = getRandomDeliveryDestination()
    if not destKey or not destination then
        return nil, 'No delivery destinations available'
    end
    
    -- Generate items
    local items, baseTotal = generateDeliveryItems(destination, job)
    if #items == 0 then
        return nil, 'No deliverable items available'
    end
    
    -- Calculate delivery fee and tip potential
    local deliveryFee = destination.deliveryFee or 50
    local tipMultiplier = destination.tipMultiplier or 1.0
    local estimatedTip = math.floor(baseTotal * 0.15 * tipMultiplier)
    
    -- Create delivery record
    local deliveryId = generateDeliveryId()
    local delivery = {
        id = deliveryId,
        job = job,
        sourceLocation = locationKey,
        destinationKey = destKey,
        destination = destination,
        items = items,
        itemsTotal = baseTotal,
        deliveryFee = deliveryFee,
        estimatedTip = estimatedTip,
        totalPayout = baseTotal + deliveryFee + estimatedTip,
        employeeSource = employeeSource,
        employeeCitizenid = employee.PlayerData.citizenid,
        status = 'pending', -- pending, accepted, picked_up, delivered
        createdAt = os.time(),
        expiresAt = os.time() + 600, -- 10 minute timeout
    }
    
    activeDeliveries[deliveryId] = delivery
    
    print(('[free-restaurants] Created delivery %s to %s for %s'):format(
        deliveryId, destKey, job
    ))
    
    return delivery, nil
end

-- ============================================================================
-- DELIVERY MANAGEMENT
-- ============================================================================

--- Accept a delivery
---@param deliveryId string
---@param employeeSource number
---@return boolean success
local function acceptDelivery(deliveryId, employeeSource)
    local delivery = activeDeliveries[deliveryId]
    if not delivery then return false end
    
    if delivery.status ~= 'pending' then return false end
    
    delivery.status = 'accepted'
    delivery.acceptedAt = os.time()
    delivery.employeeSource = employeeSource
    
    local employee = exports.qbx_core:GetPlayer(employeeSource)
    if employee then
        delivery.employeeCitizenid = employee.PlayerData.citizenid
    end
    
    return true
end

--- Mark items as picked up
---@param deliveryId string
---@param employeeSource number
---@return boolean success
local function pickupDeliveryItems(deliveryId, employeeSource)
    local delivery = activeDeliveries[deliveryId]
    if not delivery then return false end
    
    if delivery.status ~= 'accepted' then return false end
    if delivery.employeeSource ~= employeeSource then return false end
    
    -- Check employee has all items
    for _, item in ipairs(delivery.items) do
        local itemName = item.resultItem or item.id
        local count = exports.ox_inventory:Search(employeeSource, 'count', itemName)
        if count < item.amount then
            return false
        end
    end
    
    -- Remove items from inventory
    for _, item in ipairs(delivery.items) do
        local itemName = item.resultItem or item.id
        exports.ox_inventory:RemoveItem(employeeSource, itemName, item.amount)
    end
    
    delivery.status = 'picked_up'
    delivery.pickedUpAt = os.time()
    
    return true
end

--- Complete a delivery
---@param deliveryId string
---@param employeeSource number
---@param customerSatisfaction? number 0-100 satisfaction rating
---@return boolean success
---@return number earnings
local function completeDelivery(deliveryId, employeeSource, customerSatisfaction)
    local delivery = activeDeliveries[deliveryId]
    if not delivery then return false, 0 end
    
    if delivery.status ~= 'picked_up' then return false, 0 end
    if delivery.employeeSource ~= employeeSource then return false, 0 end
    
    customerSatisfaction = customerSatisfaction or math.random(70, 100)
    
    -- Calculate final tip based on satisfaction and time
    local timeElapsed = os.time() - delivery.acceptedAt
    local expectedTime = 300 -- 5 minutes expected
    local timeBonus = math.max(0, 1 - (timeElapsed / (expectedTime * 2)))
    
    local satisfactionMultiplier = customerSatisfaction / 100
    local actualTip = math.floor(delivery.estimatedTip * satisfactionMultiplier * (1 + timeBonus * 0.5))
    
    local totalEarnings = delivery.deliveryFee + actualTip
    
    -- Pay employee
    local employee = exports.qbx_core:GetPlayer(employeeSource)
    if employee then
        employee.Functions.AddMoney('cash', totalEarnings, 'restaurant-delivery')
        
        -- Track earnings
        exports['free-restaurants']:AddSessionEarnings(employeeSource, totalEarnings, 'delivery')
        exports['free-restaurants']:IncrementTasks(employeeSource)
        
        -- Award XP
        exports['free-restaurants']:AwardXP(employeeSource, 25, 'Delivery completed', 'delivery')
    end
    
    -- Add revenue to business
    exports['free-restaurants']:UpdateBusinessBalance(
        delivery.job,
        delivery.itemsTotal,
        'delivery_sale',
        ('Delivery #%s'):format(deliveryId),
        delivery.employeeCitizenid
    )
    
    delivery.status = 'delivered'
    delivery.deliveredAt = os.time()
    delivery.actualTip = actualTip
    delivery.totalEarnings = totalEarnings
    
    print(('[free-restaurants] Delivery %s completed, earnings: %d'):format(
        deliveryId, totalEarnings
    ))
    
    -- Remove from active after brief delay
    SetTimeout(5000, function()
        activeDeliveries[deliveryId] = nil
    end)
    
    return true, totalEarnings
end

--- Cancel a delivery
---@param deliveryId string
---@param reason? string
---@return boolean success
local function cancelDelivery(deliveryId, reason)
    local delivery = activeDeliveries[deliveryId]
    if not delivery then return false end
    
    -- Return items if picked up
    if delivery.status == 'picked_up' and delivery.employeeSource then
        for _, item in ipairs(delivery.items) do
            local itemName = item.resultItem or item.id
            exports.ox_inventory:AddItem(delivery.employeeSource, itemName, item.amount)
        end
    end
    
    delivery.status = 'cancelled'
    delivery.cancelledAt = os.time()
    delivery.cancelReason = reason
    
    -- Remove from active
    activeDeliveries[deliveryId] = nil
    
    return true
end

-- ============================================================================
-- CATERING SYSTEM
-- ============================================================================

--- Create a catering order
---@param job string
---@param locationKey string
---@param cateringDestKey string
---@param items table Custom items for catering
---@return table|nil catering
---@return string|nil error
local function createCateringOrder(job, locationKey, cateringDestKey, items)
    local destination = cateringDestinations[cateringDestKey]
    if not destination then return nil, 'Invalid catering destination' end
    
    -- Calculate totals
    local total = 0
    for _, item in ipairs(items) do
        total = total + (item.price * item.amount)
    end
    
    -- Catering premium
    local cateringFee = destination.cateringFee or math.floor(total * 0.25)
    
    local cateringId = ('CAT%06d'):format(deliveryCounter + 1)
    deliveryCounter = deliveryCounter + 1
    
    local catering = {
        id = cateringId,
        type = 'catering',
        job = job,
        sourceLocation = locationKey,
        destinationKey = cateringDestKey,
        destination = destination,
        items = items,
        itemsTotal = total,
        cateringFee = cateringFee,
        totalValue = total + cateringFee,
        status = 'pending',
        createdAt = os.time(),
        deadline = destination.deadline or (os.time() + 3600), -- 1 hour default
    }
    
    activeDeliveries[cateringId] = catering
    
    return catering, nil
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

--- Get available deliveries
lib.callback.register('free-restaurants:server:getAvailableDeliveries', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or player.PlayerData.job.name ~= job then
        return {}
    end
    
    local available = {}
    for id, delivery in pairs(activeDeliveries) do
        if delivery.job == job and delivery.status == 'pending' then
            if os.time() < delivery.expiresAt then
                table.insert(available, delivery)
            else
                -- Expired, clean up
                activeDeliveries[id] = nil
            end
        end
    end
    
    return available
end)

--- Request new delivery
lib.callback.register('free-restaurants:server:requestDelivery', function(source, locationKey)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil, 'Invalid player' end
    
    local job = player.PlayerData.job.name
    
    -- Check if employee already has active delivery
    for _, delivery in pairs(activeDeliveries) do
        if delivery.employeeSource == source and delivery.status ~= 'delivered' then
            return nil, 'You already have an active delivery'
        end
    end
    
    return createDelivery(job, locationKey, source)
end)

--- Accept delivery
lib.callback.register('free-restaurants:server:acceptDelivery', function(source, deliveryId)
    return acceptDelivery(deliveryId, source)
end)

--- Pickup delivery items
lib.callback.register('free-restaurants:server:pickupDelivery', function(source, deliveryId)
    return pickupDeliveryItems(deliveryId, source)
end)

--- Complete delivery
lib.callback.register('free-restaurants:server:completeDelivery', function(source, deliveryId)
    return completeDelivery(deliveryId, source)
end)

--- Cancel delivery
lib.callback.register('free-restaurants:server:cancelDelivery', function(source, deliveryId, reason)
    local delivery = activeDeliveries[deliveryId]
    if not delivery then return false end
    
    -- Only the assigned employee or managers can cancel
    if delivery.employeeSource ~= source then
        local player = exports.qbx_core:GetPlayer(source)
        if not player or player.PlayerData.job.grade.level < 3 then
            return false
        end
    end
    
    return cancelDelivery(deliveryId, reason)
end)

--- Get delivery destinations
lib.callback.register('free-restaurants:server:getDeliveryDestinations', function(source)
    return deliveryDestinations
end)

--- Get catering destinations
lib.callback.register('free-restaurants:server:getCateringDestinations', function(source)
    return cateringDestinations
end)

--- Get my active delivery
lib.callback.register('free-restaurants:server:getMyDelivery', function(source)
    for id, delivery in pairs(activeDeliveries) do
        if delivery.employeeSource == source and delivery.status ~= 'delivered' then
            return delivery
        end
    end
    return nil
end)

-- ============================================================================
-- DELIVERY SPAWN THREAD
-- ============================================================================

--- Automatically generate deliveries for staffed restaurants
CreateThread(function()
    Wait(10000) -- Wait for initialization
    loadDestinations()
    
    while true do
        Wait(120000) -- Check every 2 minutes
        
        -- For each restaurant with staff on duty, maybe spawn a delivery
        local staffedJobs = {}
        local players = exports.qbx_core:GetQBPlayers()
        
        for _, player in pairs(players) do
            if player.PlayerData.job.onduty and Config.Jobs[player.PlayerData.job.name] then
                staffedJobs[player.PlayerData.job.name] = true
            end
        end
        
        for job, _ in pairs(staffedJobs) do
            -- 30% chance to spawn a delivery
            if math.random() < 0.3 then
                -- Count existing pending deliveries for this job
                local pendingCount = 0
                for _, delivery in pairs(activeDeliveries) do
                    if delivery.job == job and delivery.status == 'pending' then
                        pendingCount = pendingCount + 1
                    end
                end
                
                -- Max 3 pending deliveries per restaurant
                if pendingCount < 3 then
                    local locationKey = job .. '_main' -- Default location
                    createDelivery(job, locationKey, 0) -- 0 = unassigned
                end
            end
        end
    end
end)

-- ============================================================================
-- CLEANUP THREAD
-- ============================================================================

CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        
        local currentTime = os.time()
        
        for id, delivery in pairs(activeDeliveries) do
            -- Clean up expired pending deliveries
            if delivery.status == 'pending' and currentTime > delivery.expiresAt then
                activeDeliveries[id] = nil
            end
            
            -- Clean up very old deliveries
            if currentTime - delivery.createdAt > 7200 then -- 2 hours
                activeDeliveries[id] = nil
            end
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('CreateDelivery', createDelivery)
exports('AcceptDelivery', acceptDelivery)
exports('CompleteDelivery', completeDelivery)
exports('CancelDelivery', cancelDelivery)
exports('GetActiveDeliveries', function() return activeDeliveries end)
exports('CreateCateringOrder', createCateringOrder)

print('[free-restaurants] server/delivery.lua loaded')
