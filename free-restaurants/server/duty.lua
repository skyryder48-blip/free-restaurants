--[[
    free-restaurants Server Duty System
    
    Handles:
    - Clock in/out processing
    - Duty state persistence
    - Session tracking and earnings
    - Paycheck calculations
    
    DEPENDENCIES:
    - server/main.lua
    - qbx_core
    - oxmysql
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

-- Active duty sessions: [source] = { sessionId, clockIn, location, ... }
local activeSessions = {}

-- Paycheck timer
local paycheckInterval = (Config.Settings and Config.Settings.Economy and Config.Settings.Economy.paycheckInterval) or 15 -- minutes

-- ============================================================================
-- SESSION MANAGEMENT
-- ============================================================================

--- Start a duty session
---@param source number
---@param locationKey string
---@return number|nil sessionId
local function startDutySession(source, locationKey)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    
    local citizenid = player.PlayerData.citizenid
    local job = player.PlayerData.job.name
    
    -- Create database record
    local sessionId = MySQL.insert.await([[
        INSERT INTO restaurant_duty_sessions (citizenid, job, location, clock_in)
        VALUES (?, ?, ?, NOW())
    ]], { citizenid, job, locationKey })
    
    -- Track active session
    activeSessions[source] = {
        sessionId = sessionId,
        citizenid = citizenid,
        job = job,
        location = locationKey,
        clockIn = os.time(),
        earnings = 0,
        tasksCompleted = 0,
        lastPaycheck = os.time(),
    }
    
    -- Update player data cache
    local playerData = exports['free-restaurants']:GetPlayerData(source)
    if playerData then
        playerData.onDuty = true
        playerData.location = locationKey
        playerData.sessionStart = os.time()
        playerData.dutySessionId = sessionId
    end
    
    return sessionId
end

--- End a duty session
---@param source number
---@return number earnings Total earnings for the session
local function endDutySession(source)
    local session = activeSessions[source]
    if not session then return 0 end
    
    local duration = os.time() - session.clockIn
    local earnings = session.earnings
    
    -- Update database record
    MySQL.update.await([[
        UPDATE restaurant_duty_sessions SET 
            clock_out = NOW(),
            earnings = ?,
            tasks_completed = ?
        WHERE id = ?
    ]], { earnings, session.tasksCompleted, session.sessionId })
    
    -- Update player data cache
    local playerData = exports['free-restaurants']:GetPlayerData(source)
    if playerData then
        playerData.onDuty = false
        playerData.location = nil
        playerData.sessionStart = nil
        playerData.dutySessionId = nil
    end
    
    -- Clear active session
    activeSessions[source] = nil
    
    return earnings
end

--- Add earnings to current session
---@param source number
---@param amount number
---@param reason? string
local function addSessionEarnings(source, amount, reason)
    local session = activeSessions[source]
    if not session then return end
    
    session.earnings = session.earnings + amount
    
    -- Also update player data cache
    local playerData = exports['free-restaurants']:GetPlayerData(source)
    if playerData then
        playerData.earnings = (playerData.earnings or 0) + amount
    end
end

--- Increment tasks completed
---@param source number
local function incrementTasks(source)
    local session = activeSessions[source]
    if not session then return end
    
    session.tasksCompleted = session.tasksCompleted + 1
    
    local playerData = exports['free-restaurants']:GetPlayerData(source)
    if playerData then
        playerData.tasksCompleted = (playerData.tasksCompleted or 0) + 1
    end
end

-- ============================================================================
-- PAYCHECK SYSTEM
-- ============================================================================

--- Calculate paycheck for player
---@param source number
---@return number paycheck
local function calculatePaycheck(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return 0 end
    
    local job = player.PlayerData.job.name
    local grade = player.PlayerData.job.grade.level
    
    -- Get wage from config
    local jobConfig = Config.Jobs[job]
    if not jobConfig then return 0 end
    
    local gradeData = jobConfig.grades[grade]
    if not gradeData then return 0 end
    
    local basePayment = gradeData.payment or 0
    
    -- Apply activity multiplier if configured
    local session = activeSessions[source]
    local activityMultiplier = 1.0
    
    if session and Config.Settings and Config.Settings.Economy then
        local minTasks = Config.Settings.Economy.minimumTasksForPay or 0
        if session.tasksCompleted >= minTasks then
            activityMultiplier = 1.0 + (session.tasksCompleted * 0.05) -- 5% bonus per task
            activityMultiplier = math.min(activityMultiplier, 2.0) -- Cap at 2x
        else
            activityMultiplier = 0.5 -- Reduced pay if not meeting minimum
        end
    end
    
    return math.floor(basePayment * activityMultiplier)
end

--- Process paycheck for player
---@param source number
local function processPaycheck(source)
    local session = activeSessions[source]
    if not session then return end
    
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    
    local paycheck = calculatePaycheck(source)
    
    if paycheck > 0 then
        -- Check if business pays or server pays
        local businessPays = Config.Settings and Config.Settings.Economy and Config.Settings.Economy.businessPaysEmployees
        
        if businessPays then
            -- Deduct from business account
            local success = exports['free-restaurants']:UpdateBusinessBalance(
                session.job,
                -paycheck,
                'payroll',
                ('Paycheck for %s'):format(player.PlayerData.charinfo.firstname),
                player.PlayerData.citizenid
            )
            
            if not success then
                -- Business can't afford, reduced pay or notify
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Paycheck Delayed',
                    description = 'Business funds insufficient.',
                    type = 'warning',
                })
                return
            end
        end
        
        -- Add to player
        player.Functions.AddMoney('bank', paycheck, 'restaurant-paycheck')
        
        -- Track earnings
        addSessionEarnings(source, paycheck, 'paycheck')
        
        -- Notify
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Paycheck',
            description = ('You received %s'):format(exports['free-restaurants']:FormatMoney(paycheck)),
            type = 'success',
        })
        
        -- Update last paycheck time
        session.lastPaycheck = os.time()
    end
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

--- Clock in callback
lib.callback.register('free-restaurants:server:clockIn', function(source, locationKey)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    -- Verify player has a restaurant job
    local job = player.PlayerData.job.name
    if not Config.Jobs[job] then
        return false
    end
    
    -- Check if already on duty
    if activeSessions[source] then
        return false
    end
    
    -- Start session
    local sessionId = startDutySession(source, locationKey)
    
    if sessionId then
        -- Set duty status in QBX
        player.Functions.SetJobDuty(true)
        
        print(('[free-restaurants] Player %s clocked in at %s'):format(
            player.PlayerData.citizenid, locationKey
        ))
        
        return true
    end
    
    return false
end)

--- Clock out callback
lib.callback.register('free-restaurants:server:clockOut', function(source, locationKey)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 0 end
    
    -- Check if on duty
    if not activeSessions[source] then
        return false, 0
    end
    
    -- Process final paycheck if earned
    local session = activeSessions[source]
    local timeSinceLastPay = os.time() - session.lastPaycheck
    local partialPayInterval = (paycheckInterval * 60) / 2 -- Half interval earns partial
    
    if timeSinceLastPay >= partialPayInterval then
        local partialMultiplier = math.min(timeSinceLastPay / (paycheckInterval * 60), 1.0)
        local partialPay = math.floor(calculatePaycheck(source) * partialMultiplier)
        
        if partialPay > 0 then
            local businessPays = Config.Settings and Config.Settings.Economy and Config.Settings.Economy.businessPaysEmployees
            
            if businessPays then
                exports['free-restaurants']:UpdateBusinessBalance(
                    session.job,
                    -partialPay,
                    'payroll',
                    ('Clock out pay for %s'):format(player.PlayerData.charinfo.firstname),
                    player.PlayerData.citizenid
                )
            end
            
            player.Functions.AddMoney('bank', partialPay, 'restaurant-clockout-pay')
            addSessionEarnings(source, partialPay, 'clock-out')
        end
    end
    
    -- End session
    local totalEarnings = endDutySession(source)
    
    -- Set duty status in QBX
    player.Functions.SetJobDuty(false)
    
    print(('[free-restaurants] Player %s clocked out, earned %d'):format(
        player.PlayerData.citizenid, totalEarnings
    ))
    
    return true, totalEarnings
end)

--- Get duty status
lib.callback.register('free-restaurants:server:getDutyStatus', function(source)
    return activeSessions[source] ~= nil
end)

--- Get session info
lib.callback.register('free-restaurants:server:getSessionInfo', function(source)
    local session = activeSessions[source]
    if not session then return nil end
    
    return {
        clockIn = session.clockIn,
        location = session.location,
        earnings = session.earnings,
        tasksCompleted = session.tasksCompleted,
        duration = os.time() - session.clockIn,
    }
end)

-- ============================================================================
-- PAYCHECK THREAD
-- ============================================================================

CreateThread(function()
    while true do
        Wait(60000) -- Check every minute
        
        local currentTime = os.time()
        local paycheckIntervalSeconds = paycheckInterval * 60
        
        for source, session in pairs(activeSessions) do
            local timeSinceLastPay = currentTime - session.lastPaycheck
            
            if timeSinceLastPay >= paycheckIntervalSeconds then
                processPaycheck(source)
            end
        end
    end
end)

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--- Player dropped - clean up session
AddEventHandler('playerDropped', function(reason)
    local source = source
    
    if activeSessions[source] then
        endDutySession(source)
    end
end)

--- Task completed event
RegisterNetEvent('free-restaurants:server:taskCompleted', function(taskType)
    local source = source
    incrementTasks(source)
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsOnDuty', function(source)
    return activeSessions[source] ~= nil
end)

exports('GetSession', function(source)
    return activeSessions[source]
end)

exports('AddSessionEarnings', addSessionEarnings)
exports('IncrementTasks', incrementTasks)

print('[free-restaurants] server/duty.lua loaded')
