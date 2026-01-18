--[[
    free-restaurants Server NPC Customer System
    
    Handles:
    - Automatic NPC order generation
    - Customer spawn/despawn management
    - Order queue for NPC customers
    - Tip calculations based on service
    
    DEPENDENCIES:
    - server/main.lua
    - server/customers.lua
]]

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local NPCConfig = {
    -- Enable/disable NPC customers
    enabled = true,
    
    -- Order generation settings
    orders = {
        -- Base chance to generate order when staff on duty (per minute)
        baseChance = 0.15, -- 15% per minute
        
        -- Maximum pending NPC orders per restaurant
        maxPending = 5,
        
        -- Minimum staff required for NPC orders
        minStaff = 1,
        
        -- Order timeout before NPC leaves (seconds)
        orderTimeout = 300, -- 5 minutes
        
        -- Tip percentage range (of order total)
        tipMin = 0.10, -- 10%
        tipMax = 0.25, -- 25%
        
        -- Satisfaction modifiers
        satisfaction = {
            fast = 1.5,      -- Under 2 minutes
            normal = 1.0,    -- 2-5 minutes
            slow = 0.5,      -- Over 5 minutes
            timeout = 0.0,   -- Order expired
        },
    },
    
    -- NPC appearance settings
    appearance = {
        -- Model pools by restaurant type
        models = {
            default = {
                'a_f_y_hipster_01', 'a_f_y_business_01', 'a_f_y_tourist_01',
                'a_m_y_hipster_01', 'a_m_y_business_01', 'a_m_y_tourist_01',
                'a_f_m_business_02', 'a_m_m_business_01', 'a_f_y_runner_01',
            },
            burgershot = {
                'a_m_y_skater_01', 'a_f_y_skater_01', 'a_m_y_genstreet_01',
                'a_f_y_genhot_01', 'a_m_y_cyclist_01',
            },
            pizzeria = {
                'a_f_y_hipster_02', 'a_m_y_hipster_02', 'a_f_y_tourist_02',
            },
            cafe = {
                'a_f_y_business_02', 'a_m_y_business_02', 'a_f_y_hipster_03',
            },
        },
        
        -- Wait positions (offsets from counter)
        waitOffset = vec3(0.0, -1.5, 0.0),
    },
    
    -- NPC names pool
    names = {
        first = {
            'James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael', 'Linda',
            'William', 'Elizabeth', 'David', 'Barbara', 'Richard', 'Susan', 'Joseph', 'Jessica',
            'Thomas', 'Sarah', 'Charles', 'Karen', 'Daniel', 'Nancy', 'Matthew', 'Lisa',
        },
        last = {
            'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
            'Rodriguez', 'Martinez', 'Anderson', 'Taylor', 'Thomas', 'Moore', 'Jackson', 'Martin',
        },
    },
}

-- ============================================================================
-- STATE
-- ============================================================================

-- Active NPC orders: [orderId] = { npcData, orderData, status }
local npcOrders = {}

-- NPC counter for unique IDs
local npcCounter = 0

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Generate random NPC name
---@return string firstName
---@return string lastName
local function generateNPCName()
    local first = NPCConfig.names.first[math.random(#NPCConfig.names.first)]
    local last = NPCConfig.names.last[math.random(#NPCConfig.names.last)]
    return first, last
end

--- Get random NPC model for restaurant type
---@param restaurantType string
---@return string model
local function getRandomModel(restaurantType)
    local pool = NPCConfig.appearance.models[restaurantType] or NPCConfig.appearance.models.default
    return pool[math.random(#pool)]
end

--- Generate NPC order items
---@param job string Restaurant job
---@return table items
---@return number total
local function generateOrderItems(job)
    local items = {}
    local total = 0

    -- Get the restaurant type for this job
    local jobConfig = Config.Jobs and Config.Jobs[job]
    local jobRestaurantType = jobConfig and jobConfig.type or nil

    -- Get menu items for this restaurant - use Config.Recipes.Items
    local menuItems = {}
    local recipesTable = Config.Recipes and Config.Recipes.Items or {}

    for recipeId, recipe in pairs(recipesTable) do
        if recipe.canOrder ~= false and recipe.sellable ~= false then
            local matches = false

            -- Check restaurantTypes (plural array)
            if recipe.restaurantTypes then
                for _, rType in ipairs(recipe.restaurantTypes) do
                    if rType == jobRestaurantType or rType == 'all' then
                        matches = true
                        break
                    end
                end
            else
                -- No restriction, available to all
                matches = true
            end

            -- Use basePrice instead of price
            if matches and recipe.basePrice then
                table.insert(menuItems, {
                    id = recipeId,
                    label = recipe.label,
                    price = recipe.basePrice,
                    result = recipe.result,
                })
            end
        end
    end

    if #menuItems == 0 then
        print(('[free-restaurants] NPC order generation: No menu items found for job %s (type: %s)'):format(job, tostring(jobRestaurantType)))
        return items, 0
    end

    -- Generate 1-4 items
    local itemCount = math.random(1, 4)
    local usedItems = {}

    for i = 1, itemCount do
        local attempts = 0
        local item

        repeat
            item = menuItems[math.random(#menuItems)]
            attempts = attempts + 1
        until not usedItems[item.id] or attempts > 10

        if not usedItems[item.id] then
            usedItems[item.id] = true
            local amount = math.random(1, 2)

            table.insert(items, {
                id = item.id,
                label = item.label,
                amount = amount,
                price = item.price,
                resultItem = type(item.result) == 'table' and item.result.item or item.result,
            })

            total = total + (item.price * amount)
        end
    end

    return items, total
end

--- Calculate tip based on service quality
---@param orderTotal number
---@param waitTime number Seconds waited
---@return number tip
local function calculateTip(orderTotal, waitTime)
    local baseTip = orderTotal * (NPCConfig.orders.tipMin + 
        math.random() * (NPCConfig.orders.tipMax - NPCConfig.orders.tipMin))
    
    local multiplier = NPCConfig.orders.satisfaction.normal
    
    if waitTime < 120 then -- Under 2 minutes
        multiplier = NPCConfig.orders.satisfaction.fast
    elseif waitTime > 300 then -- Over 5 minutes
        multiplier = NPCConfig.orders.satisfaction.slow
    end
    
    return math.floor(baseTip * multiplier)
end

--- Get count of pending NPC orders for a job
---@param job string
---@return number
local function getPendingNPCOrders(job)
    local count = 0
    for _, order in pairs(npcOrders) do
        if order.job == job and order.status == 'pending' then
            count = count + 1
        end
    end
    return count
end

--- Get on-duty staff count for a job
---@param job string
---@return number
local function getOnDutyCount(job)
    local count = 0
    local players = exports.qbx_core:GetQBPlayers()
    
    for _, player in pairs(players) do
        if player.PlayerData.job.name == job and player.PlayerData.job.onduty then
            count = count + 1
        end
    end
    
    return count
end

-- ============================================================================
-- ORDER GENERATION
-- ============================================================================

--- Create an NPC order
---@param job string
---@param locationKey string
---@return table|nil order
local function createNPCOrder(job, locationKey)
    -- Check limits
    if getPendingNPCOrders(job) >= NPCConfig.orders.maxPending then
        return nil
    end
    
    -- Generate order
    local items, total = generateOrderItems(job)
    if #items == 0 then return nil end
    
    -- Generate NPC data
    npcCounter = npcCounter + 1
    local firstName, lastName = generateNPCName()
    local model = getRandomModel(job)
    
    local npcData = {
        id = ('NPC%06d'):format(npcCounter),
        firstName = firstName,
        lastName = lastName,
        fullName = firstName .. ' ' .. lastName,
        model = model,
    }
    
    -- Use customer order system
    local orderId = exports['free-restaurants']:CreateOrder(
        0, -- No player source
        job,
        locationKey,
        items,
        'cash'
    )
    
    if not orderId then return nil end
    
    -- Track NPC order - use GetGameTimer() for FiveM compatibility
    local currentTime = GetGameTimer()
    npcOrders[orderId] = {
        orderId = orderId,
        npc = npcData,
        job = job,
        locationKey = locationKey,
        items = items,
        total = total,
        status = 'pending',
        createdAt = currentTime,
        expiresAt = currentTime + (NPCConfig.orders.orderTimeout * 1000), -- Convert to ms
    }
    
    -- Notify staff
    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.job.name == job and player.PlayerData.job.onduty then
            TriggerClientEvent('free-restaurants:client:npcOrderCreated', player.PlayerData.source, {
                orderId = orderId,
                npc = npcData,
                items = items,
                total = total,
                locationKey = locationKey,
            })
        end
    end
    
    print(('[free-restaurants] NPC order created: %s from %s at %s'):format(
        orderId, npcData.fullName, job
    ))
    
    return npcOrders[orderId]
end

--- Process NPC order completion
---@param orderId string
---@param employeeSource number
local function completeNPCOrder(orderId, employeeSource)
    local npcOrder = npcOrders[orderId]
    if not npcOrder then return end

    -- Calculate wait time in seconds (GetGameTimer returns ms)
    local waitTime = (GetGameTimer() - npcOrder.createdAt) / 1000
    local tip = calculateTip(npcOrder.total, waitTime)
    
    -- Update order with tip
    local activeOrders = exports['free-restaurants']:GetActiveOrders()
    if activeOrders[orderId] then
        activeOrders[orderId].tip = tip
    end
    
    -- Complete via normal order system
    local success, earnings = exports['free-restaurants']:CompleteOrder(orderId, employeeSource)
    
    if success then
        npcOrders[orderId] = nil
        
        -- Notify about NPC leaving satisfied
        TriggerClientEvent('free-restaurants:client:npcOrderCompleted', employeeSource, {
            orderId = orderId,
            npc = npcOrder.npc,
            tip = tip,
            satisfaction = waitTime < 120 and 'happy' or (waitTime > 300 and 'frustrated' or 'satisfied'),
        })
    end
end

--- Handle expired NPC orders
local function checkExpiredOrders()
    local currentTime = GetGameTimer()

    for orderId, npcOrder in pairs(npcOrders) do
        if currentTime > npcOrder.expiresAt then
            -- NPC leaves unhappy
            npcOrders[orderId] = nil
            
            -- Cancel the order
            exports['free-restaurants']:CancelOrder(orderId, 'Customer left - order timeout', false)
            
            -- Reduce cleanliness/reputation slightly
            exports['free-restaurants']:UpdateCleanliness(npcOrder.job, -2, 'unhappy_customer')
            
            -- Notify staff
            local players = exports.qbx_core:GetQBPlayers()
            for _, player in pairs(players) do
                if player.PlayerData.job.name == npcOrder.job and player.PlayerData.job.onduty then
                    TriggerClientEvent('ox_lib:notify', player.PlayerData.source, {
                        title = 'Customer Left',
                        description = ('%s left without their order!'):format(npcOrder.npc.fullName),
                        type = 'warning',
                    })
                end
            end
            
            print(('[free-restaurants] NPC order expired: %s'):format(orderId))
        end
    end
end

-- ============================================================================
-- ORDER GENERATION LOOP
-- ============================================================================

CreateThread(function()
    if not NPCConfig.enabled then return end
    
    while true do
        Wait(60000) -- Check every minute
        
        -- Find staffed restaurants
        local staffedJobs = {}
        local players = exports.qbx_core:GetQBPlayers()
        
        for _, player in pairs(players) do
            local job = player.PlayerData.job.name
            if player.PlayerData.job.onduty and Config.Jobs[job] then
                if not staffedJobs[job] then
                    staffedJobs[job] = {
                        count = 0,
                        locations = {},
                    }
                end
                staffedJobs[job].count = staffedJobs[job].count + 1
            end
        end
        
        -- Generate orders for staffed restaurants
        for job, data in pairs(staffedJobs) do
            if data.count >= NPCConfig.orders.minStaff then
                -- Scale chance with staff count
                local chance = NPCConfig.orders.baseChance * math.min(data.count, 3)
                
                if math.random() < chance then
                    local locationKey = job .. '_main' -- Default location
                    createNPCOrder(job, locationKey)
                end
            end
        end
        
        -- Check for expired orders
        checkExpiredOrders()
    end
end)

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Listen for order completion to check if it's an NPC order
AddEventHandler('free-restaurants:server:orderCompleted', function(orderId, employeeSource)
    if npcOrders[orderId] then
        completeNPCOrder(orderId, employeeSource)
    end
end)

-- ============================================================================
-- CALLBACKS
-- ============================================================================

lib.callback.register('free-restaurants:server:getNPCOrders', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    
    job = job or player.PlayerData.job.name
    
    local orders = {}
    for orderId, order in pairs(npcOrders) do
        if order.job == job then
            table.insert(orders, order)
        end
    end
    
    return orders
end)

lib.callback.register('free-restaurants:server:isNPCOrder', function(source, orderId)
    return npcOrders[orderId] ~= nil
end)

-- Admin: Force NPC order
lib.callback.register('free-restaurants:server:forceNPCOrder', function(source, job, locationKey)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    
    if not exports.qbx_core:HasPermission(source, 'admin') then
        return nil
    end
    
    return createNPCOrder(job, locationKey or (job .. '_main'))
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('CreateNPCOrder', createNPCOrder)
exports('GetNPCOrders', function() return npcOrders end)
exports('IsNPCOrder', function(orderId) return npcOrders[orderId] ~= nil end)

print('[free-restaurants] server/npc-customers.lua loaded')
