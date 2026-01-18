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
                firstname = charinfo.firstname,
                lastname = charinfo.lastname,
                grade = jobData.grade.level,
                gradeName = jobData.grade.name,
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

--- Order stock
lib.callback.register('free-restaurants:server:orderStock', function(source, job, itemName, quantity)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    if not hasServerPermission(source, job, 'canOrderStock') then
        return false
    end

    -- Find item and price from default list or config
    local defaultStockItems = {
        { name = 'bun', label = 'Burger Buns', price = 5 },
        { name = 'patty_raw', label = 'Raw Patties', price = 10 },
        { name = 'lettuce', label = 'Lettuce', price = 3 },
        { name = 'tomato', label = 'Tomatoes', price = 3 },
        { name = 'cheese', label = 'Cheese Slices', price = 4 },
        { name = 'fries_raw', label = 'Frozen Fries', price = 8 },
        { name = 'soda_syrup', label = 'Soda Syrup', price = 15 },
        { name = 'napkins', label = 'Napkins', price = 2 },
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

    if success then
        -- Add items to business storage - use location-based stash
        -- Find the first enabled location for this job
        for restaurantType, locations in pairs(Config.Locations) do
            if type(locations) == 'table' then
                for locationId, locationData in pairs(locations) do
                    if type(locationData) == 'table' and locationData.enabled and locationData.job == job then
                        local stashId = ('restaurant_%s_%s_storage'):format(restaurantType, locationId)
                        exports.ox_inventory:AddItem(stashId, itemName, quantity)
                        print(('[free-restaurants] %s ordered %dx %s ($%d) for %s -> %s'):format(
                            player.PlayerData.citizenid, quantity, itemData.label, totalCost, job, stashId
                        ))
                        return true
                    end
                end
            end
        end

        -- Fallback stash if no location found
        local stashId = ('restaurant_business_%s'):format(job)
        exports.ox_inventory:AddItem(stashId, itemName, quantity)
        print(('[free-restaurants] %s ordered %dx %s ($%d) for %s'):format(
            player.PlayerData.citizenid, quantity, itemData.label, totalCost, job
        ))
    end

    return success
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

    -- Update config (runtime only - would need separate persistence for permanent changes)
    if Config.Jobs[job] and Config.Jobs[job].grades[grade] then
        Config.Jobs[job].grades[grade].payment = wage
        print(('[free-restaurants] Wage updated for %s grade %d to $%d'):format(job, grade, wage))
        return true
    end

    return false
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetEmployees', getEmployees)
exports('HireEmployee', hireEmployee)
exports('FireEmployee', fireEmployee)
exports('SetEmployeeGrade', setEmployeeGrade)

print('[free-restaurants] server/management.lua loaded')
