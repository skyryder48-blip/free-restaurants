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
    
    -- Verify permission
    if player.PlayerData.job.name ~= job then return false end
    
    local grade = player.PlayerData.job.grade.level
    local jobConfig = Config.Jobs[job]
    if not jobConfig then return false end
    
    local gradePerms = jobConfig.grades[grade] and jobConfig.grades[grade].permissions
    if not gradePerms or not (gradePerms.canAccessFinances or gradePerms.all) then
        return false
    end
    
    -- Check balance
    local balance = exports['free-restaurants']:GetBusinessBalance(job)
    if amount > balance then return false end
    
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
-- EMPLOYEE CALLBACKS
-- ============================================================================

lib.callback.register('free-restaurants:server:getEmployees', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    
    if player.PlayerData.job.name ~= job then return {} end
    
    return getEmployees(job)
end)

lib.callback.register('free-restaurants:server:hireEmployee', function(source, targetId, job, grade)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    -- Verify permission
    if player.PlayerData.job.name ~= job then return false end
    
    local gradeLevel = player.PlayerData.job.grade.level
    local jobConfig = Config.Jobs[job]
    if not jobConfig then return false end
    
    local gradePerms = jobConfig.grades[gradeLevel] and jobConfig.grades[gradeLevel].permissions
    if not gradePerms or not (gradePerms.canHire or gradePerms.all) then
        return false
    end
    
    return hireEmployee(targetId, job, grade)
end)

lib.callback.register('free-restaurants:server:fireEmployee', function(source, citizenid, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    -- Verify permission
    if player.PlayerData.job.name ~= job then return false end
    
    local gradeLevel = player.PlayerData.job.grade.level
    local jobConfig = Config.Jobs[job]
    if not jobConfig then return false end
    
    local gradePerms = jobConfig.grades[gradeLevel] and jobConfig.grades[gradeLevel].permissions
    if not gradePerms or not (gradePerms.canFire or gradePerms.all) then
        return false
    end
    
    -- Can't fire yourself
    if player.PlayerData.citizenid == citizenid then return false end
    
    return fireEmployee(citizenid, job)
end)

lib.callback.register('free-restaurants:server:setEmployeeGrade', function(source, citizenid, job, grade)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    -- Verify permission
    if player.PlayerData.job.name ~= job then return false end
    
    local gradeLevel = player.PlayerData.job.grade.level
    local jobConfig = Config.Jobs[job]
    if not jobConfig then return false end
    
    local gradePerms = jobConfig.grades[gradeLevel] and jobConfig.grades[gradeLevel].permissions
    if not gradePerms or not (gradePerms.canHire or gradePerms.all) then
        return false
    end
    
    -- Can't set higher grade than self (unless owner)
    if grade >= gradeLevel and not gradePerms.all then
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
    
    -- Verify permission
    if player.PlayerData.job.name ~= job then return false end
    
    local gradeLevel = player.PlayerData.job.grade.level
    local jobConfig = Config.Jobs[job]
    if not jobConfig then return false end
    
    local gradePerms = jobConfig.grades[gradeLevel] and jobConfig.grades[gradeLevel].permissions
    if not gradePerms or not (gradePerms.canOrderStock or gradePerms.all) then
        return false
    end
    
    -- Find item and price
    local stockItems = Config.Stock and Config.Stock[job] or {}
    local itemData = nil
    
    for _, item in ipairs(stockItems) do
        if item.name == itemName then
            itemData = item
            break
        end
    end
    
    -- Default price if not found
    local price = itemData and itemData.price or 10
    local totalCost = price * quantity
    
    -- Check business balance
    local balance = exports['free-restaurants']:GetBusinessBalance(job)
    if totalCost > balance then
        return false
    end
    
    -- Deduct from business
    local success = exports['free-restaurants']:UpdateBusinessBalance(
        job,
        -totalCost,
        'stock_order',
        ('Ordered %dx %s'):format(quantity, itemName),
        player.PlayerData.citizenid
    )
    
    if success then
        -- Add items to business storage
        local stashId = ('restaurant_business_%s_main'):format(job)
        exports.ox_inventory:AddItem(stashId, itemName, quantity)
        
        print(('[free-restaurants] %s ordered %dx %s for %s'):format(
            player.PlayerData.citizenid, quantity, itemName, job
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
    
    -- Start with base recipe prices
    for recipeId, recipe in pairs(Config.Recipes) do
        if recipe.restaurantType and recipe.restaurantType == job or not recipe.restaurantType then
            pricing[recipeId] = {
                price = recipe.price or 0,
                basePrice = recipe.price or 0,
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

--- Set item price
lib.callback.register('free-restaurants:server:setPrice', function(source, job, itemId, price)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    -- Verify permission
    if player.PlayerData.job.name ~= job then return false end
    
    local gradeLevel = player.PlayerData.job.grade.level
    local jobConfig = Config.Jobs[job]
    if not jobConfig then return false end
    
    local gradePerms = jobConfig.grades[gradeLevel] and jobConfig.grades[gradeLevel].permissions
    if not gradePerms or not (gradePerms.canEditMenu or gradePerms.all) then
        return false
    end
    
    -- Validate price range
    local recipe = Config.Recipes[itemId]
    if recipe then
        local basePrice = recipe.price or 0
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
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    -- Verify permission
    if player.PlayerData.job.name ~= job then return false end
    
    local gradeLevel = player.PlayerData.job.grade.level
    local jobConfig = Config.Jobs[job]
    if not jobConfig then return false end
    
    local gradePerms = jobConfig.grades[gradeLevel] and jobConfig.grades[gradeLevel].permissions
    if not gradePerms or not (gradePerms.canSetWages or gradePerms.all) then
        return false
    end
    
    -- Update config (runtime only - would need separate persistence for permanent changes)
    if Config.Jobs[job].grades[grade] then
        Config.Jobs[job].grades[grade].payment = wage
    end
    
    -- Could also save to database for persistence across restarts
    
    return true
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetEmployees', getEmployees)
exports('HireEmployee', hireEmployee)
exports('FireEmployee', fireEmployee)
exports('SetEmployeeGrade', setEmployeeGrade)

print('[free-restaurants] server/management.lua loaded')
