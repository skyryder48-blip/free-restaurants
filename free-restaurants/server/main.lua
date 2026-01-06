--[[
    free-restaurants Server Main
    
    Core server initialization providing:
    - Resource initialization
    - Player state management
    - Database setup
    - Core utility callbacks
    - Global state management
    
    DEPENDENCIES:
    - qbx_core
    - ox_lib
    - oxmysql
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local isInitialized = false

-- Player restaurant data cache
-- [source] = { onDuty = bool, location = string, sessionStart = timestamp, ... }
local playerData = {}

-- Business financial data cache
-- [job] = { balance = number, todaySales = number, ... }
local businessData = {}

-- ============================================================================
-- DATABASE INITIALIZATION
-- ============================================================================

--- Create database tables if they don't exist
local function initializeDatabase()
    -- Restaurant business accounts
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `restaurant_business` (
            `job` VARCHAR(50) PRIMARY KEY,
            `balance` INT DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
    
    -- Transaction history
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `restaurant_transactions` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `job` VARCHAR(50) NOT NULL,
            `type` VARCHAR(20) NOT NULL,
            `amount` INT NOT NULL,
            `description` TEXT,
            `player_citizenid` VARCHAR(50),
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_job` (`job`),
            INDEX `idx_created` (`created_at`)
        )
    ]])
    
    -- Player restaurant data (progression, stats)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `restaurant_player_data` (
            `citizenid` VARCHAR(50) PRIMARY KEY,
            `cooking_level` INT DEFAULT 1,
            `cooking_xp` INT DEFAULT 0,
            `total_crafts` INT DEFAULT 0,
            `total_orders` INT DEFAULT 0,
            `total_tips` INT DEFAULT 0,
            `skills` JSON,
            `unlocked_recipes` JSON,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
    
    -- Order history
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `restaurant_orders` (
            `id` VARCHAR(10) PRIMARY KEY,
            `job` VARCHAR(50) NOT NULL,
            `customer_citizenid` VARCHAR(50),
            `customer_name` VARCHAR(100),
            `items` JSON NOT NULL,
            `total` INT NOT NULL,
            `tip` INT DEFAULT 0,
            `status` VARCHAR(20) DEFAULT 'pending',
            `employee_citizenid` VARCHAR(50),
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `completed_at` TIMESTAMP NULL,
            INDEX `idx_job` (`job`),
            INDEX `idx_status` (`status`),
            INDEX `idx_created` (`created_at`)
        )
    ]])
    
    -- Menu pricing overrides
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `restaurant_pricing` (
            `job` VARCHAR(50) NOT NULL,
            `item_id` VARCHAR(50) NOT NULL,
            `price` INT NOT NULL,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`job`, `item_id`)
        )
    ]])
    
    -- Duty sessions
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `restaurant_duty_sessions` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `job` VARCHAR(50) NOT NULL,
            `location` VARCHAR(100),
            `clock_in` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `clock_out` TIMESTAMP NULL,
            `earnings` INT DEFAULT 0,
            `tasks_completed` INT DEFAULT 0,
            INDEX `idx_citizenid` (`citizenid`),
            INDEX `idx_job` (`job`)
        )
    ]])
    
    print('[free-restaurants] Database tables initialized')
end

--- Load business data from database
local function loadBusinessData()
    -- Initialize business accounts for all configured jobs
    for jobName, jobConfig in pairs(Config.Jobs) do
        local result = MySQL.single.await('SELECT * FROM restaurant_business WHERE job = ?', { jobName })
        
        if result then
            businessData[jobName] = {
                balance = result.balance,
                todaySales = 0,
                weekSales = 0,
            }
        else
            -- Create new business account
            MySQL.insert.await('INSERT INTO restaurant_business (job, balance) VALUES (?, ?)', { jobName, 0 })
            businessData[jobName] = {
                balance = 0,
                todaySales = 0,
                weekSales = 0,
            }
        end
    end
    
    -- Load today's and this week's sales
    local todayStart = os.date('%Y-%m-%d 00:00:00')
    local weekStart = os.date('%Y-%m-%d 00:00:00', os.time() - 7 * 24 * 60 * 60)
    
    for jobName, _ in pairs(businessData) do
        -- Today's sales
        local todayResult = MySQL.scalar.await([[
            SELECT COALESCE(SUM(amount), 0) FROM restaurant_transactions 
            WHERE job = ? AND type = 'sale' AND created_at >= ?
        ]], { jobName, todayStart })
        
        businessData[jobName].todaySales = todayResult or 0
        
        -- This week's sales
        local weekResult = MySQL.scalar.await([[
            SELECT COALESCE(SUM(amount), 0) FROM restaurant_transactions 
            WHERE job = ? AND type = 'sale' AND created_at >= ?
        ]], { jobName, weekStart })
        
        businessData[jobName].weekSales = weekResult or 0
    end
    
    print('[free-restaurants] Business data loaded')
end

-- ============================================================================
-- PLAYER DATA MANAGEMENT
-- ============================================================================

--- Get or create player restaurant data
---@param citizenid string
---@return table
local function getPlayerRestaurantData(citizenid)
    local result = MySQL.single.await('SELECT * FROM restaurant_player_data WHERE citizenid = ?', { citizenid })
    
    if result then
        return {
            cookingLevel = result.cooking_level,
            cookingXp = result.cooking_xp,
            totalCrafts = result.total_crafts,
            totalOrders = result.total_orders,
            totalTips = result.total_tips,
            skills = result.skills and json.decode(result.skills) or {},
            unlockedRecipes = result.unlocked_recipes and json.decode(result.unlocked_recipes) or {},
        }
    else
        -- Create new player data
        MySQL.insert.await([[
            INSERT INTO restaurant_player_data (citizenid, cooking_level, cooking_xp, skills, unlocked_recipes) 
            VALUES (?, 1, 0, '{}', '[]')
        ]], { citizenid })
        
        return {
            cookingLevel = 1,
            cookingXp = 0,
            totalCrafts = 0,
            totalOrders = 0,
            totalTips = 0,
            skills = {},
            unlockedRecipes = {},
        }
    end
end

--- Save player restaurant data
---@param citizenid string
---@param data table
local function savePlayerRestaurantData(citizenid, data)
    MySQL.update.await([[
        UPDATE restaurant_player_data SET 
            cooking_level = ?,
            cooking_xp = ?,
            total_crafts = ?,
            total_orders = ?,
            total_tips = ?,
            skills = ?,
            unlocked_recipes = ?
        WHERE citizenid = ?
    ]], {
        data.cookingLevel,
        data.cookingXp,
        data.totalCrafts,
        data.totalOrders,
        data.totalTips,
        json.encode(data.skills or {}),
        json.encode(data.unlockedRecipes or {}),
        citizenid
    })
end

--- Initialize player session data
---@param source number
---@param citizenid string
local function initializePlayerSession(source, citizenid)
    playerData[source] = {
        citizenid = citizenid,
        onDuty = false,
        location = nil,
        sessionStart = nil,
        earnings = 0,
        tasksCompleted = 0,
        dutySessionId = nil,
    }
end

--- Clean up player session data
---@param source number
local function cleanupPlayerSession(source)
    local data = playerData[source]
    
    if data and data.onDuty then
        -- Force clock out
        if data.dutySessionId then
            MySQL.update.await([[
                UPDATE restaurant_duty_sessions SET 
                    clock_out = NOW(),
                    earnings = ?,
                    tasks_completed = ?
                WHERE id = ?
            ]], { data.earnings, data.tasksCompleted, data.dutySessionId })
        end
    end
    
    playerData[source] = nil
end

-- ============================================================================
-- BUSINESS FINANCE HELPERS
-- ============================================================================

--- Get business balance
---@param job string
---@return number
local function getBusinessBalance(job)
    if businessData[job] then
        return businessData[job].balance
    end
    return 0
end

--- Update business balance
---@param job string
---@param amount number (positive = add, negative = remove)
---@param type string Transaction type
---@param description string
---@param citizenid string|nil
---@return boolean success
local function updateBusinessBalance(job, amount, type, description, citizenid)
    if not businessData[job] then
        return false
    end
    
    local newBalance = businessData[job].balance + amount
    
    if newBalance < 0 then
        return false
    end
    
    -- Update cache
    businessData[job].balance = newBalance
    
    if amount > 0 and type == 'sale' then
        businessData[job].todaySales = (businessData[job].todaySales or 0) + amount
        businessData[job].weekSales = (businessData[job].weekSales or 0) + amount
    end
    
    -- Update database
    MySQL.update.await('UPDATE restaurant_business SET balance = ? WHERE job = ?', { newBalance, job })
    
    -- Record transaction
    MySQL.insert.await([[
        INSERT INTO restaurant_transactions (job, type, amount, description, player_citizenid)
        VALUES (?, ?, ?, ?, ?)
    ]], { job, type, amount, description, citizenid })
    
    return true
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

--- Get nearby players for hiring
lib.callback.register('free-restaurants:server:getNearbyPlayers', function(source, radius)
    local sourcePlayer = exports.qbx_core:GetPlayer(source)
    if not sourcePlayer then return {} end
    
    local sourcePed = GetPlayerPed(source)
    local sourceCoords = GetEntityCoords(sourcePed)
    
    local nearbyPlayers = {}
    local players = exports.qbx_core:GetQBPlayers()
    
    for _, player in pairs(players) do
        if player.PlayerData.source ~= source then
            local targetPed = GetPlayerPed(player.PlayerData.source)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(sourceCoords - targetCoords)
            
            if distance <= radius then
                table.insert(nearbyPlayers, {
                    id = player.PlayerData.source,
                    name = ('%s %s'):format(
                        player.PlayerData.charinfo.firstname,
                        player.PlayerData.charinfo.lastname
                    ),
                    citizenid = player.PlayerData.citizenid,
                    job = player.PlayerData.job.name,
                })
            end
        end
    end
    
    return nearbyPlayers
end)

--- Get player skill level
lib.callback.register('free-restaurants:server:getSkillLevel', function(source, category)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return 0 end
    
    local restaurantData = getPlayerRestaurantData(player.PlayerData.citizenid)
    
    -- Return specific skill or general cooking level
    if category and restaurantData.skills[category] then
        return restaurantData.skills[category]
    end
    
    return restaurantData.cookingLevel or 1
end)

--- Get player restaurant data
lib.callback.register('free-restaurants:server:getPlayerData', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    
    return getPlayerRestaurantData(player.PlayerData.citizenid)
end)

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--- Player loaded
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local source = source
    local player = exports.qbx_core:GetPlayer(source)
    
    if player then
        initializePlayerSession(source, player.PlayerData.citizenid)
        
        -- Trigger client ready
        TriggerClientEvent('free-restaurants:client:playerReady', source)
    end
end)

--- Player dropped
AddEventHandler('playerDropped', function(reason)
    local source = source
    cleanupPlayerSession(source)
end)

--- Resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Initialize database
    initializeDatabase()
    
    -- Load business data
    SetTimeout(1000, function()
        loadBusinessData()
        isInitialized = true
        print('[free-restaurants] Server initialized')
    end)
    
    -- Initialize existing players
    SetTimeout(2000, function()
        local players = exports.qbx_core:GetQBPlayers()
        for _, player in pairs(players) do
            initializePlayerSession(player.PlayerData.source, player.PlayerData.citizenid)
            TriggerClientEvent('free-restaurants:client:playerReady', player.PlayerData.source)
        end
    end)
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

-- Format money helper (duplicated from shared for server-side use)
local function formatMoney(amount)
    return ('$%s'):format(lib.math.groupdigits(amount))
end

exports('GetPlayerData', function(source)
    return playerData[source]
end)

exports('FormatMoney', formatMoney)

exports('GetBusinessData', function(job)
    return businessData[job]
end)

exports('GetBusinessBalance', getBusinessBalance)
exports('UpdateBusinessBalance', updateBusinessBalance)
exports('GetPlayerRestaurantData', getPlayerRestaurantData)
exports('SavePlayerRestaurantData', savePlayerRestaurantData)
exports('IsInitialized', function() return isInitialized end)

-- ============================================================================
-- GLOBAL TABLE
-- ============================================================================

FreeRestaurants = FreeRestaurants or {}
FreeRestaurants.Server = {
    GetPlayerData = function(source) return playerData[source] end,
    GetBusinessData = function(job) return businessData[job] end,
    GetBusinessBalance = getBusinessBalance,
    UpdateBusinessBalance = updateBusinessBalance,
    GetPlayerRestaurantData = getPlayerRestaurantData,
    SavePlayerRestaurantData = savePlayerRestaurantData,
}

print('[free-restaurants] server/main.lua loaded')
