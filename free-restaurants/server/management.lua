--[[
    free-restaurants Server Management System

    Handles:
    - Employee management (hire, fire, promote, demote)
    - Business finances (withdraw, deposit, transactions)
    - Stock ordering
    - Menu pricing adjustments
    - Wage management

    DEPENDENCIES:
    - server/main.lua
    - qbx_core
    - oxmysql
]]

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Get effective grade permissions with fallback to highest available grade
---@param job string
---@param gradeLevel number
---@return table|nil permissions
---@return number effectiveGrade
local function getEffectivePermissions(job, gradeLevel)
    local jobConfig = Config.Jobs[job]
    if not jobConfig then return nil, gradeLevel end

    -- Try the exact grade first
    local gradeData = jobConfig.grades[gradeLevel]
    if gradeData and gradeData.permissions then
        return gradeData.permissions, gradeLevel
    end

    -- Fallback to highest available grade
    local maxGrade = -1
    local maxGradeData = nil
    for g, data in pairs(jobConfig.grades) do
        if type(g) == 'number' and g > maxGrade then
            maxGrade = g
            maxGradeData = data
        end
    end

    if maxGradeData and maxGradeData.permissions then
        print(('[free-restaurants] Using fallback grade %d instead of %d for %s'):format(maxGrade, gradeLevel, job))
        return maxGradeData.permissions, maxGrade
    end

    return nil, gradeLevel
end

--- Check if player has permission
---@param source number
---@param job string
---@param permission string
---@return boolean
local function hasServerPermission(source, job, permission)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then
        print(('[free-restaurants] hasServerPermission: player not found for source %d'):format(source))
        return false
    end

    if player.PlayerData.job.name ~= job then
        print(('[free-restaurants] hasServerPermission: job mismatch - player has %s, needed %s'):format(player.PlayerData.job.name, job))
        return false
    end

    local gradeLevel = player.PlayerData.job.grade.level
    local perms, effectiveGrade = getEffectivePermissions(job, gradeLevel)

    if not perms then
        print(('[free-restaurants] hasServerPermission: no permissions found for %s grade %d'):format(job, gradeLevel))
        return false
    end

    if perms.all == true then
        print(('[free-restaurants] hasServerPermission: %s has ALL permissions'):format(permission))
        return true
    end

    local hasIt = perms[permission] == true
    print(('[free-restaurants] hasServerPermission: %s = %s'):format(permission, tostring(hasIt)))
    return hasIt
end

-- ============================================================================
-- EMPLOYEE MANAGEMENT
-- ============================================================================

--- Get all employees for a job
---@param job string
---@return table employees
local function getEmployees(job)
    local employees = {}
    
    -- Get from database (players table)
    local results = MySQL.query.await([[
        SELECT citizenid, charinfo, job 
        FROM players 
        WHERE JSON_EXTRACT(job, '$.name') = ?
    ]], { job })
    
    if results then
        for _, row in ipairs(results) do
            local charinfo = json.decode(row.charinfo)
            local jobData = json.decode(row.job)
            
            -- Check if player is online
            local onlinePlayer = nil
            local players = exports.qbx_core:GetQBPlayers()
            for _, p in pairs(players) do
                if p.PlayerData.citizenid == row.citizenid then
                    onlinePlayer = p
                    break
                end
            end
            
            table.insert(employees, {
                citizenid = row.citizenid,
                name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''),
                firstname = charinfo.firstname,
                lastname = charinfo.lastname,
                grade = jobData.grade.level,
                gradeLabel = jobData.grade.name,
                gradeName = jobData.grade.name,
                onduty = onlinePlayer and onlinePlayer.PlayerData.job.onduty or false,
                onDuty = onlinePlayer and onlinePlayer.PlayerData.job.onduty or false,
                online = onlinePlayer ~= nil,
            })
        end
    end
    
    return employees
end

--- Hire a player
---@param targetSource number
---@param job string
---@param grade number
---@return boolean success
local function hireEmployee(targetSource, job, grade)
    local player = exports.qbx_core:GetPlayer(targetSource)
    if not player then return false end
    
    -- Set job
    player.Functions.SetJob(job, grade)
    
    print(('[free-restaurants] Hired %s as %s grade %d'):format(
        player.PlayerData.citizenid, job, grade
    ))
    
    return true
end

--- Fire an employee
---@param citizenid string
---@param job string
---@return boolean success
local function fireEmployee(citizenid, job)
    -- Check if online
    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.citizenid == citizenid then
            -- Set to unemployed
            player.Functions.SetJob('unemployed', 0)
            
            TriggerClientEvent('ox_lib:notify', player.PlayerData.source, {
                title = 'Employment',
                description = 'You have been fired from ' .. job,
                type = 'error',
            })
            
            return true
        end
    end
    
    -- Offline player - update database directly
    MySQL.update.await([[
        UPDATE players 
        SET job = JSON_SET(job, '$.name', 'unemployed', '$.grade', JSON_OBJECT('level', 0, 'name', 'Unemployed'))
        WHERE citizenid = ?
    ]], { citizenid })
    
    return true
end

--- Set employee grade
---@param citizenid string
---@param job string
---@param grade number
---@return boolean success
local function setEmployeeGrade(citizenid, job, grade)
    -- Check if online
    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.citizenid == citizenid then
            player.Functions.SetJob(job, grade)
            
            local gradeData = Config.Jobs[job] and Config.Jobs[job].grades[grade]
            local gradeName = gradeData and gradeData.label or ('Grade %d'):format(grade)
            
            TriggerClientEvent('ox_lib:notify', player.PlayerData.source, {
                title = 'Promotion',
                description = ('Your position is now: %s'):format(gradeName),
                type = 'inform',
            })
            
            return true
        end
    end
    
    -- Offline player - update database
    local jobConfig = Config.Jobs[job]
    if not jobConfig then return false end
    
    local gradeData = jobConfig.grades[grade]
    if not gradeData then return false end
    
    MySQL.update.await([[
        UPDATE players 
        SET job = JSON_SET(job, '$.grade', JSON_OBJECT('level', ?, 'name', ?))
        WHERE citizenid = ? AND JSON_EXTRACT(job, '$.name') = ?
    ]], { grade, gradeData.label, citizenid, job })
    
    return true
end

-- ============================================================================
-- FINANCE CALLBACKS
-- ============================================================================

--- Get finances for a job
lib.callback.register('free-restaurants:server:getFinances', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    
    -- Verify player has access
    if player.PlayerData.job.name ~= job then return nil end
    
    local businessData = exports['free-restaurants']:GetBusinessData(job)
    if not businessData then return nil end
    
    return {
        balance = businessData.balance,
        todaySales = businessData.todaySales,
        weekSales = businessData.weekSales,
    }
end)

--- Withdraw funds
lib.callback.register('free-restaurants:server:withdrawFunds', function(source, job, amount)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    if not hasServerPermission(source, job, 'canAccessFinances') then
        return false
    end

    -- Check balance
    local balance = exports['free-restaurants']:GetBusinessBalance(job)
    if not balance or amount > balance then return false end

    -- Process withdrawal
    local success = exports['free-restaurants']:UpdateBusinessBalance(
        job,
        -amount,
        'withdrawal',
        ('Withdrawal by %s %s'):format(
            player.PlayerData.charinfo.firstname,
            player.PlayerData.charinfo.lastname
        ),
        player.PlayerData.citizenid
    )

    if success then
        player.Functions.AddMoney('cash', amount, 'restaurant-withdrawal')
    end

    return success
end)

--- Deposit funds
lib.callback.register('free-restaurants:server:depositFunds', function(source, job, amount)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    -- Verify permission
    if player.PlayerData.job.name ~= job then return false end
    
    -- Check player has money
    if player.PlayerData.money.cash < amount then return false end
    
    -- Process deposit
    player.Functions.RemoveMoney('cash', amount, 'restaurant-deposit')
    
    local success = exports['free-restaurants']:UpdateBusinessBalance(
        job,
        amount,
        'deposit',
        ('Deposit by %s %s'):format(
            player.PlayerData.charinfo.firstname,
            player.PlayerData.charinfo.lastname
        ),
        player.PlayerData.citizenid
    )
    
    return success
end)

--- Get transaction history
lib.callback.register('free-restaurants:server:getTransactions', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    
    if player.PlayerData.job.name ~= job then return {} end
    
    local results = MySQL.query.await([[
        SELECT * FROM restaurant_transactions 
        WHERE job = ? 
        ORDER BY created_at DESC 
        LIMIT 50
    ]], { job })
    
    local transactions = {}
    if results then
        for _, row in ipairs(results) do
            table.insert(transactions, {
                type = row.type,
                amount = row.amount,
                description = row.description,
                by = row.player_citizenid,
                date = row.created_at,
            })
        end
    end
    
    return transactions
end)

-- ============================================================================
-- UTILITY CALLBACKS
-- ============================================================================

--- Get nearby players for hiring
lib.callback.register('free-restaurants:server:getNearbyPlayers', function(source, radius)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    radius = radius or 10.0

    local nearbyPlayers = {}
    local players = exports.qbx_core:GetQBPlayers()

    for _, targetPlayer in pairs(players) do
        local targetSource = targetPlayer.PlayerData.source
        if targetSource ~= source then
            local targetPed = GetPlayerPed(targetSource)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)

            if distance <= radius then
                -- Check if player doesn't already work at a restaurant
                local targetJob = targetPlayer.PlayerData.job.name
                local isRestaurantEmployee = Config.Jobs[targetJob] ~= nil

                table.insert(nearbyPlayers, {
                    id = targetSource,
                    name = ('%s %s'):format(
                        targetPlayer.PlayerData.charinfo.firstname,
                        targetPlayer.PlayerData.charinfo.lastname
                    ),
                    citizenid = targetPlayer.PlayerData.citizenid,
                    currentJob = targetJob,
                    isRestaurantEmployee = isRestaurantEmployee,
                    distance = distance,
                })
            end
        end
    end

    -- Sort by distance
    table.sort(nearbyPlayers, function(a, b) return a.distance < b.distance end)

    return nearbyPlayers
end)

-- ============================================================================
-- EMPLOYEE CALLBACKS
-- ============================================================================

lib.callback.register('free-restaurants:server:getEmployees', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    
    if player.PlayerData.job.name ~= job then return {} end
    
    return getEmployees(job)
end)

lib.callback.register('free-restaurants:server:hireEmployee', function(source, targetId, job, grade)
    print(('[free-restaurants] hireEmployee callback: source=%d, target=%d, job=%s, grade=%s'):format(source, targetId, job, tostring(grade)))

    if not hasServerPermission(source, job, 'canHire') then
        print('[free-restaurants] hireEmployee: permission denied')
        return false
    end

    local result = hireEmployee(targetId, job, grade)
    print(('[free-restaurants] hireEmployee result: %s'):format(tostring(result)))
    return result
end)

lib.callback.register('free-restaurants:server:fireEmployee', function(source, citizenid, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    if not hasServerPermission(source, job, 'canFire') then
        return false
    end

    -- Can't fire yourself
    if player.PlayerData.citizenid == citizenid then return false end

    return fireEmployee(citizenid, job)
end)

lib.callback.register('free-restaurants:server:setEmployeeGrade', function(source, citizenid, job, grade)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local gradeLevel = player.PlayerData.job.grade.level
    local perms, effectiveGrade = getEffectivePermissions(job, gradeLevel)

    if not perms or not (perms.canHire or perms.all) then
        return false
    end

    -- Can't set higher grade than self (unless owner)
    if grade >= effectiveGrade and not perms.all then
        return false
    end

    return setEmployeeGrade(citizenid, job, grade)
end)

-- ============================================================================
-- STOCK ORDERING
-- ============================================================================

--- Get available stock items for ordering
lib.callback.register('free-restaurants:server:getStockItems', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    
    if player.PlayerData.job.name ~= job then return {} end
    
    -- Get stock items from config or define defaults
    local stockItems = Config.Stock and Config.Stock[job] or {
        { name = 'bun', label = 'Burger Buns', price = 5 },
        { name = 'patty_raw', label = 'Raw Patties', price = 10 },
        { name = 'lettuce', label = 'Lettuce', price = 3 },
        { name = 'tomato', label = 'Tomatoes', price = 3 },
        { name = 'cheese', label = 'Cheese Slices', price = 4 },
        { name = 'fries_raw', label = 'Frozen Fries', price = 8 },
        { name = 'soda_syrup', label = 'Soda Syrup', price = 15 },
        { name = 'napkins', label = 'Napkins', price = 2 },
    }
    
    return stockItems
end)

-- Active stock pickup missions (keyed by order_id)
local activeStockOrders = {}

--- Generate unique stock order ID
local stockOrderCounter = 0
local function generateStockOrderId()
    stockOrderCounter = stockOrderCounter + 1
    -- Use GetGameTimer() which returns ms since resource start - FiveM compatible
    local timestamp = GetGameTimer() % 100000
    return ('SO%05d%03d'):format(timestamp, stockOrderCounter % 1000)
end

--- Get random pickup location
local function getRandomPickupLocation()
    local locations = Config.Business and Config.Business.Stock and Config.Business.Stock.pickup and Config.Business.Stock.pickup.locations
    if not locations or #locations == 0 then
        -- Default location if none configured
        return {
            label = 'Warehouse',
            coords = vec3(863.4, -2977.5, 5.9),
            heading = 270.0,
        }
    end
    return locations[math.random(#locations)]
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

--- Order stock - Creates pickup mission
lib.callback.register('free-restaurants:server:orderStock', function(source, job, itemName, quantity)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    if not hasServerPermission(source, job, 'canOrderStock') then
        return false
    end

    -- Find item and price from default list or config
    local defaultStockItems = {
        { name = 'bun', label = 'Burger Buns', price = 5, weight = 50 },
        { name = 'patty_raw', label = 'Raw Patties', price = 10, weight = 200 },
        { name = 'lettuce', label = 'Lettuce', price = 3, weight = 100 },
        { name = 'tomato', label = 'Tomatoes', price = 3, weight = 150 },
        { name = 'cheese', label = 'Cheese Slices', price = 4, weight = 50 },
        { name = 'fries_raw', label = 'Frozen Fries', price = 8, weight = 500 },
        { name = 'soda_syrup', label = 'Soda Syrup', price = 15, weight = 1000 },
        { name = 'napkins', label = 'Napkins', price = 2, weight = 20 },
    }

    local stockItems = Config.Stock and Config.Stock[job] or defaultStockItems
    local itemData = nil

    for _, item in ipairs(stockItems) do
        if item.name == itemName then
            itemData = item
            break
        end
    end

    if not itemData then
        print(('[free-restaurants] Stock order failed: item %s not found'):format(itemName))
        return false
    end

    local totalCost = itemData.price * quantity

    -- Check business balance
    local balance = exports['free-restaurants']:GetBusinessBalance(job)
    if not balance or totalCost > balance then
        print(('[free-restaurants] Stock order failed: insufficient balance (need %d, have %s)'):format(totalCost, tostring(balance)))
        return false
    end

    -- Deduct from business
    local success = exports['free-restaurants']:UpdateBusinessBalance(
        job,
        -totalCost,
        'stock_order',
        ('Ordered %dx %s'):format(quantity, itemData.label),
        player.PlayerData.citizenid
    )

    if not success then
        return false
    end

    -- Generate order ID and get pickup location
    local orderId = generateStockOrderId()
    local pickupLocation = getRandomPickupLocation()

    -- Calculate item weight and create crates
    local itemWeight = itemData.weight or 100 -- default 100g if not specified
    local totalWeight = itemWeight * quantity
    local maxCrateWeight = Config.Business and Config.Business.Stock and Config.Business.Stock.pickup and Config.Business.Stock.pickup.maxCrateWeight or 10000

    -- Bundle items into crates (max 10kg each)
    local crates = {}
    local remainingQty = quantity
    while remainingQty > 0 do
        local crateQty = math.min(remainingQty, math.floor(maxCrateWeight / itemWeight))
        if crateQty < 1 then crateQty = 1 end
        table.insert(crates, {
            item = itemName,
            label = itemData.label,
            quantity = crateQty,
            weight = crateQty * itemWeight,
        })
        remainingQty = remainingQty - crateQty
    end

    -- Store the order
    local expiryTime = Config.Business and Config.Business.Stock and Config.Business.Stock.pickup and Config.Business.Stock.pickup.expiryTime or 60
    -- Use GetGameTimer() for relative expiry tracking (ms from now)
    local expiryMs = GetGameTimer() + (expiryTime * 60 * 1000)
    local orderData = {
        orderId = orderId,
        job = job,
        items = crates,
        totalCost = totalCost,
        location = pickupLocation,
        orderedBy = player.PlayerData.citizenid,
        orderedByName = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname),
        createdAt = GetGameTimer(),
        expiresAt = expiryMs,
        pickedUp = false,
        cratesRemaining = #crates,
    }

    activeStockOrders[orderId] = orderData

    -- Save to database using MySQL DATE_ADD for expiry
    MySQL.query.await([[
        INSERT INTO restaurant_stock_orders (order_id, job, items, total_cost, status, pickup_coords, ordered_by, expires_at)
        VALUES (?, ?, ?, ?, 'ready', ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], {
        orderId,
        job,
        json.encode(crates),
        totalCost,
        ('%s,%s,%s'):format(pickupLocation.coords.x, pickupLocation.coords.y, pickupLocation.coords.z),
        player.PlayerData.citizenid,
        expiryTime,
    })

    -- Notify all on-duty employees
    notifyJobEmployees(job, 'free-restaurants:client:stockOrderReady', {
        orderId = orderId,
        location = pickupLocation,
        crateCount = #crates,
        itemLabel = itemData.label,
        quantity = quantity,
    })

    print(('[free-restaurants] Stock order %s created: %dx %s, %d crates at %s'):format(
        orderId, quantity, itemData.label, #crates, pickupLocation.label
    ))

    return true, orderId
end)

--- Get active stock orders for a job
lib.callback.register('free-restaurants:server:getActiveStockOrders', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end

    if player.PlayerData.job.name ~= job then return {} end

    local orders = {}
    for orderId, orderData in pairs(activeStockOrders) do
        if orderData.job == job and not orderData.pickedUp and orderData.cratesRemaining > 0 then
            table.insert(orders, {
                orderId = orderId,
                location = orderData.location,
                cratesRemaining = orderData.cratesRemaining,
                items = orderData.items,
                expiresAt = orderData.expiresAt,
            })
        end
    end

    return orders
end)

--- Pickup a stock crate
lib.callback.register('free-restaurants:server:pickupStockCrate', function(source, orderId)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local orderData = activeStockOrders[orderId]
    if not orderData then
        return false, 'Order not found'
    end

    if player.PlayerData.job.name ~= orderData.job then
        return false, 'Wrong job'
    end

    if not player.PlayerData.job.onduty then
        return false, 'Not on duty'
    end

    if orderData.cratesRemaining <= 0 then
        return false, 'No crates remaining'
    end

    -- Get the next crate to pickup
    local crateIndex = #orderData.items - orderData.cratesRemaining + 1
    local crateData = orderData.items[crateIndex]

    if not crateData then
        return false, 'Crate data missing'
    end

    -- Create the stock_crate item with metadata
    local crateMetadata = {
        orderId = orderId,
        contents = {
            item = crateData.item,
            label = crateData.label,
            quantity = crateData.quantity,
        },
        job = orderData.job,
        description = ('Contains %dx %s'):format(crateData.quantity, crateData.label),
    }

    -- Check if player can carry the crate
    local canCarry = exports.ox_inventory:CanCarryItem(source, 'stock_crate', 1)
    if not canCarry then
        return false, 'Inventory full'
    end

    -- Give the crate to the player
    local success = exports.ox_inventory:AddItem(source, 'stock_crate', 1, crateMetadata)
    if not success then
        return false, 'Failed to add crate'
    end

    -- Update remaining crates
    orderData.cratesRemaining = orderData.cratesRemaining - 1

    -- Check if all crates picked up
    if orderData.cratesRemaining <= 0 then
        orderData.pickedUp = true

        -- Update database
        MySQL.query.await([[
            UPDATE restaurant_stock_orders SET status = 'picked_up', picked_up_by = ? WHERE order_id = ?
        ]], { player.PlayerData.citizenid, orderId })

        -- Notify all employees that order is complete
        notifyJobEmployees(orderData.job, 'free-restaurants:client:stockOrderComplete', {
            orderId = orderId,
            pickedUpBy = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname),
        })

        -- Remove from active orders after a delay
        SetTimeout(5000, function()
            activeStockOrders[orderId] = nil
        end)
    else
        -- Notify remaining crates
        notifyJobEmployees(orderData.job, 'free-restaurants:client:stockCratePickedUp', {
            orderId = orderId,
            remaining = orderData.cratesRemaining,
            pickedUpBy = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname),
        })
    end

    print(('[free-restaurants] %s picked up crate from order %s (%d remaining)'):format(
        player.PlayerData.citizenid, orderId, orderData.cratesRemaining
    ))

    return true, orderData.cratesRemaining
end)

--- Open stock crate - extract contents
lib.callback.register('free-restaurants:server:openStockCrate', function(source, slot)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    -- Get the crate item from the slot
    local inventory = exports.ox_inventory:GetInventory(source)
    if not inventory then return false end

    local crateItem = exports.ox_inventory:GetSlot(source, slot)
    if not crateItem or crateItem.name ~= 'stock_crate' then
        return false, 'Invalid crate'
    end

    local metadata = crateItem.metadata
    if not metadata or not metadata.contents then
        return false, 'Crate has no contents'
    end

    local contents = metadata.contents

    -- Check if player can carry the contents
    local canCarry = exports.ox_inventory:CanCarryItem(source, contents.item, contents.quantity)
    if not canCarry then
        return false, 'Cannot carry contents - inventory full'
    end

    -- Remove the crate
    local removed = exports.ox_inventory:RemoveItem(source, 'stock_crate', 1, nil, slot)
    if not removed then
        return false, 'Failed to remove crate'
    end

    -- Add the contents
    local added = exports.ox_inventory:AddItem(source, contents.item, contents.quantity)
    if not added then
        -- Refund the crate if we fail to add contents
        exports.ox_inventory:AddItem(source, 'stock_crate', 1, metadata)
        return false, 'Failed to add contents'
    end

    print(('[free-restaurants] %s opened stock crate: %dx %s'):format(
        player.PlayerData.citizenid, contents.quantity, contents.item
    ))

    return true, contents
end)

--- Cleanup expired stock orders
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute

        local now = GetGameTimer()
        for orderId, orderData in pairs(activeStockOrders) do
            if orderData.expiresAt and now > orderData.expiresAt and not orderData.pickedUp then
                -- Mark as expired
                MySQL.query.await([[
                    UPDATE restaurant_stock_orders SET status = 'expired' WHERE order_id = ?
                ]], { orderId })

                -- Notify employees
                notifyJobEmployees(orderData.job, 'free-restaurants:client:stockOrderExpired', {
                    orderId = orderId,
                })

                -- Remove from active orders
                activeStockOrders[orderId] = nil

                print(('[free-restaurants] Stock order %s expired'):format(orderId))
            end
        end

        -- Also check database for any orders that expired (backup check using MySQL time)
        MySQL.query.await([[
            UPDATE restaurant_stock_orders SET status = 'expired'
            WHERE status = 'ready' AND expires_at < NOW()
        ]])
    end
end)

--- Load pending stock orders on resource start
CreateThread(function()
    Wait(2000) -- Wait for database connection

    -- Query includes seconds until expiry so we can calculate relative expiry time
    local results = MySQL.query.await([[
        SELECT *, TIMESTAMPDIFF(SECOND, NOW(), expires_at) as seconds_until_expiry
        FROM restaurant_stock_orders
        WHERE status = 'ready' AND expires_at > NOW()
    ]])

    if results then
        local currentTime = GetGameTimer()
        for _, row in ipairs(results) do
            local coords = row.pickup_coords and row.pickup_coords:gmatch('[^,]+')
            local x, y, z = coords(), coords(), coords()

            -- Calculate expiry time relative to current GetGameTimer()
            local secondsUntilExpiry = row.seconds_until_expiry or 0
            local expiryMs = currentTime + (secondsUntilExpiry * 1000)

            activeStockOrders[row.order_id] = {
                orderId = row.order_id,
                job = row.job,
                items = json.decode(row.items) or {},
                totalCost = row.total_cost,
                location = {
                    label = 'Pickup Location',
                    coords = vec3(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0),
                },
                orderedBy = row.ordered_by,
                createdAt = currentTime,
                expiresAt = expiryMs,
                pickedUp = false,
                cratesRemaining = #(json.decode(row.items) or {}),
            }
        end

        print(('[free-restaurants] Loaded %d pending stock orders'):format(#results))
    end
end)

-- ============================================================================
-- PRICING MANAGEMENT
-- ============================================================================

--- Get current pricing
lib.callback.register('free-restaurants:server:getPricing', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end

    if player.PlayerData.job.name ~= job then return {} end

    -- Get custom prices from database
    local results = MySQL.query.await('SELECT * FROM restaurant_pricing WHERE job = ?', { job })

    local pricing = {}
    local count = 0

    -- Debug: Check if Config.Recipes.Items exists
    if not Config.Recipes or not Config.Recipes.Items then
        print('[free-restaurants] getPricing: Config.Recipes.Items is nil!')
        return {}
    end

    -- Get the restaurant type from job config
    local jobConfig = Config.Jobs[job]
    local jobRestaurantType = jobConfig and jobConfig.type or nil

    -- Start with base recipe prices - include all recipes for this job
    for recipeId, recipe in pairs(Config.Recipes.Items) do
        local shouldInclude = false

        -- Check if recipe has no restaurantTypes (generic) or matches the job's type
        if not recipe.restaurantTypes or #recipe.restaurantTypes == 0 then
            -- Generic recipe - include for all
            shouldInclude = true
        elseif jobRestaurantType then
            -- Check if job's restaurant type is in the recipe's restaurantTypes array
            for _, rType in ipairs(recipe.restaurantTypes) do
                if rType == jobRestaurantType then
                    shouldInclude = true
                    break
                end
            end
        end

        if shouldInclude and recipe.basePrice then
            pricing[recipeId] = {
                price = recipe.basePrice,
                basePrice = recipe.basePrice,
            }
            count = count + 1
        end
    end

    print(('[free-restaurants] getPricing: found %d recipes for job %s (type: %s)'):format(count, job, tostring(jobRestaurantType)))

    -- Override with custom prices
    if results then
        for _, row in ipairs(results) do
            if pricing[row.item_id] then
                pricing[row.item_id].price = row.price
            end
        end
    end

    return pricing
end)

--- Set item price
lib.callback.register('free-restaurants:server:setPrice', function(source, job, itemId, price)
    if not hasServerPermission(source, job, 'canEditMenu') then
        return false
    end

    -- Validate price range
    local recipe = Config.Recipes and Config.Recipes.Items and Config.Recipes.Items[itemId]
    if recipe then
        local basePrice = recipe.basePrice or 0
        local minPrice = math.floor(basePrice * (Config.Economy and Config.Economy.Pricing and Config.Economy.Pricing.priceFloor or 0.5))
        local maxPrice = math.floor(basePrice * (Config.Economy and Config.Economy.Pricing and Config.Economy.Pricing.priceCeiling or 2.0))

        if price < minPrice or price > maxPrice then
            return false
        end
    end

    -- Update database
    MySQL.query.await([[
        INSERT INTO restaurant_pricing (job, item_id, price)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE price = ?
    ]], { job, itemId, price, price })

    return true
end)

-- ============================================================================
-- WAGE MANAGEMENT
-- ============================================================================

--- Set wage for a grade
lib.callback.register('free-restaurants:server:setWage', function(source, job, grade, wage)
    if not hasServerPermission(source, job, 'canSetWages') then
        return false
    end

    -- Update runtime config
    if Config.Jobs[job] and Config.Jobs[job].grades[grade] then
        Config.Jobs[job].grades[grade].payment = wage

        -- Persist to database
        MySQL.query.await([[
            INSERT INTO restaurant_payroll (job, grade, wage)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE wage = ?
        ]], { job, grade, wage, wage })

        print(('[free-restaurants] Wage updated for %s grade %d to $%d'):format(job, grade, wage))
        return true
    end

    return false
end)

--- Load saved payroll settings on resource start
local function loadPayrollSettings()
    local results = MySQL.query.await('SELECT * FROM restaurant_payroll')

    if results then
        for _, row in ipairs(results) do
            if Config.Jobs[row.job] and Config.Jobs[row.job].grades[row.grade] then
                Config.Jobs[row.job].grades[row.grade].payment = row.wage
                print(('[free-restaurants] Loaded wage for %s grade %d: $%d'):format(row.job, row.grade, row.wage))
            end
        end
    end
end

-- Load payroll on startup
CreateThread(function()
    Wait(1000) -- Wait for database connection
    loadPayrollSettings()
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetEmployees', getEmployees)
exports('HireEmployee', hireEmployee)
exports('FireEmployee', fireEmployee)
exports('SetEmployeeGrade', setEmployeeGrade)

--- Get pricing for a job (exported for cross-resource access)
exports('GetPricing', function(job)
    -- Get custom prices from database
    local results = MySQL.query.await('SELECT * FROM restaurant_pricing WHERE job = ?', { job })

    local pricing = {}

    -- Check if Config.Recipes.Items exists
    if not Config.Recipes or not Config.Recipes.Items then
        return {}
    end

    -- Get the restaurant type from job config
    local jobConfig = Config.Jobs[job]
    local jobRestaurantType = jobConfig and jobConfig.type or nil

    -- Start with base recipe prices - include all recipes for this job
    for recipeId, recipe in pairs(Config.Recipes.Items) do
        local shouldInclude = false

        if not recipe.restaurantTypes or #recipe.restaurantTypes == 0 then
            shouldInclude = true
        elseif jobRestaurantType then
            for _, rType in ipairs(recipe.restaurantTypes) do
                if rType == jobRestaurantType then
                    shouldInclude = true
                    break
                end
            end
        end

        if shouldInclude and recipe.basePrice then
            pricing[recipeId] = {
                price = recipe.basePrice,
                basePrice = recipe.basePrice,
            }
        end
    end

    -- Override with custom prices
    if results then
        for _, row in ipairs(results) do
            if pricing[row.item_id] then
                pricing[row.item_id].price = row.price
            end
        end
    end

    return pricing
end)

print('[free-restaurants] server/management.lua loaded')
