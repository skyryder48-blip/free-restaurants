--[[
    free-restaurants Server Health Inspection System
    
    Handles:
    - Random health inspections
    - Cleanliness scoring
    - Violation tracking
    - Grade calculations
    - Inspection history
    
    DEPENDENCIES:
    - server/main.lua
    - oxmysql
]]

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local InspectionConfig = {
    -- How often to check for inspections (minutes)
    checkInterval = 30,
    
    -- Base chance of inspection per check when restaurant is staffed (0-1)
    baseChance = 0.05, -- 5% per check
    
    -- Minimum time between inspections (hours)
    minTimeBetween = 24,
    
    -- Score thresholds for grades
    grades = {
        A = 90,  -- 90-100
        B = 80,  -- 80-89
        C = 70,  -- 70-79
        D = 60,  -- 60-69
        F = 0,   -- 0-59
    },
    
    -- Violation categories and point deductions
    violations = {
        -- Critical violations (major point loss)
        critical = {
            { id = 'fire_hazard', label = 'Fire hazard detected', points = 20 },
            { id = 'raw_contamination', label = 'Raw food contamination risk', points = 15 },
            { id = 'expired_food', label = 'Expired food in storage', points = 15 },
            { id = 'pest_evidence', label = 'Evidence of pests', points = 20 },
        },
        -- Major violations
        major = {
            { id = 'temp_control', label = 'Improper temperature control', points = 10 },
            { id = 'cross_contamination', label = 'Cross-contamination risk', points = 10 },
            { id = 'handwashing', label = 'Inadequate handwashing facilities', points = 8 },
            { id = 'food_handling', label = 'Improper food handling', points = 8 },
        },
        -- Minor violations
        minor = {
            { id = 'cleanliness', label = 'General cleanliness issues', points = 5 },
            { id = 'labeling', label = 'Food labeling issues', points = 3 },
            { id = 'storage', label = 'Improper storage', points = 5 },
            { id = 'equipment', label = 'Equipment maintenance needed', points = 4 },
        },
    },
    
    -- Bonuses for good practices
    bonuses = {
        { id = 'clean_stations', label = 'Exceptionally clean stations', points = 5 },
        { id = 'organized', label = 'Well-organized kitchen', points = 3 },
        { id = 'trained_staff', label = 'Well-trained staff', points = 5 },
        { id = 'quick_response', label = 'Quick response to issues', points = 2 },
    },
}

-- ============================================================================
-- DATABASE
-- ============================================================================

--- Initialize inspection tables
local function initializeDatabase()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `restaurant_inspections` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `job` VARCHAR(50) NOT NULL,
            `location` VARCHAR(100),
            `score` INT NOT NULL,
            `grade` CHAR(1) NOT NULL,
            `violations` JSON,
            `bonuses` JSON,
            `inspector_notes` TEXT,
            `inspected_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_job` (`job`),
            INDEX `idx_date` (`inspected_at`)
        )
    ]])
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `restaurant_cleanliness` (
            `job` VARCHAR(50) PRIMARY KEY,
            `cleanliness_score` INT DEFAULT 100,
            `last_cleaned` TIMESTAMP NULL,
            `active_violations` JSON,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
end

-- ============================================================================
-- CLEANLINESS TRACKING
-- ============================================================================

--- Get current cleanliness state
---@param job string
---@return table
local function getCleanlinessState(job)
    local result = MySQL.single.await([[
        SELECT * FROM restaurant_cleanliness WHERE job = ?
    ]], { job })
    
    if result then
        return {
            score = result.cleanliness_score,
            lastCleaned = result.last_cleaned,
            violations = result.active_violations and json.decode(result.active_violations) or {},
        }
    else
        -- Initialize
        MySQL.insert.await([[
            INSERT INTO restaurant_cleanliness (job, cleanliness_score, active_violations)
            VALUES (?, 100, '[]')
        ]], { job })
        
        return {
            score = 100,
            lastCleaned = nil,
            violations = {},
        }
    end
end

--- Update cleanliness score
---@param job string
---@param delta number Change in score
---@param reason? string
local function updateCleanliness(job, delta, reason)
    local current = getCleanlinessState(job)
    local newScore = math.max(0, math.min(100, current.score + delta))
    
    MySQL.update.await([[
        UPDATE restaurant_cleanliness SET cleanliness_score = ? WHERE job = ?
    ]], { newScore, job })
    
    return newScore
end

--- Add active violation
---@param job string
---@param violationId string
local function addViolation(job, violationId)
    local current = getCleanlinessState(job)
    
    if not tableContains(current.violations, violationId) then
        table.insert(current.violations, violationId)
        
        MySQL.update.await([[
            UPDATE restaurant_cleanliness SET active_violations = ? WHERE job = ?
        ]], { json.encode(current.violations), job })
    end
end

--- Clear violation
---@param job string
---@param violationId string
local function clearViolation(job, violationId)
    local current = getCleanlinessState(job)
    
    for i, v in ipairs(current.violations) do
        if v == violationId then
            table.remove(current.violations, i)
            break
        end
    end
    
    MySQL.update.await([[
        UPDATE restaurant_cleanliness SET active_violations = ? WHERE job = ?
    ]], { json.encode(current.violations), job })
end

--- Mark restaurant as cleaned
---@param job string
---@param cleanerCitizenid string
local function markCleaned(job, cleanerCitizenid)
    MySQL.update.await([[
        UPDATE restaurant_cleanliness 
        SET last_cleaned = NOW(), cleanliness_score = LEAST(100, cleanliness_score + 10)
        WHERE job = ?
    ]], { job })
    
    -- Award XP to cleaner
    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.citizenid == cleanerCitizenid then
            exports['free-restaurants']:AwardXP(player.PlayerData.source, 10, 'Cleaned restaurant', 'cleaning')
            break
        end
    end
end

-- Helper
local function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

-- ============================================================================
-- INSPECTION LOGIC
-- ============================================================================

--- Calculate inspection score
---@param job string
---@return number score
---@return table violations Found violations
---@return table bonuses Applied bonuses
local function calculateInspectionScore(job)
    local score = 100
    local foundViolations = {}
    local appliedBonuses = {}
    
    local cleanliness = getCleanlinessState(job)
    
    -- Check for existing violations
    for _, violationId in ipairs(cleanliness.violations) do
        -- Find violation details
        for severity, list in pairs(InspectionConfig.violations) do
            for _, violation in ipairs(list) do
                if violation.id == violationId then
                    score = score - violation.points
                    table.insert(foundViolations, {
                        id = violation.id,
                        label = violation.label,
                        points = violation.points,
                        severity = severity,
                    })
                    break
                end
            end
        end
    end
    
    -- Random chance for additional violations based on cleanliness
    local randomViolationChance = (100 - cleanliness.score) / 200 -- 0 to 0.5
    
    for severity, list in pairs(InspectionConfig.violations) do
        for _, violation in ipairs(list) do
            if not tableContains(cleanliness.violations, violation.id) then
                local chance = randomViolationChance
                if severity == 'critical' then chance = chance * 0.3
                elseif severity == 'major' then chance = chance * 0.5
                end
                
                if math.random() < chance then
                    score = score - violation.points
                    table.insert(foundViolations, {
                        id = violation.id,
                        label = violation.label,
                        points = violation.points,
                        severity = severity,
                    })
                    addViolation(job, violation.id)
                end
            end
        end
    end
    
    -- Check for bonuses based on cleanliness
    if cleanliness.score >= 90 then
        for _, bonus in ipairs(InspectionConfig.bonuses) do
            if math.random() < 0.5 then -- 50% chance each
                score = score + bonus.points
                table.insert(appliedBonuses, bonus)
            end
        end
    end
    
    -- Apply base cleanliness modifier
    local cleanlinessModifier = (cleanliness.score - 50) / 10 -- -5 to +5
    score = score + cleanlinessModifier
    
    return math.max(0, math.min(100, math.floor(score))), foundViolations, appliedBonuses
end

--- Get letter grade from score
---@param score number
---@return string grade
local function getGrade(score)
    for grade, threshold in pairs(InspectionConfig.grades) do
        if score >= threshold then
            return grade
        end
    end
    return 'F'
end

--- Conduct an inspection
---@param job string
---@param locationKey? string
---@return table inspectionResult
local function conductInspection(job, locationKey)
    local score, violations, bonuses = calculateInspectionScore(job)
    local grade = getGrade(score)
    
    -- Generate inspector notes
    local notes = ''
    if #violations == 0 then
        notes = 'Excellent condition. No violations found.'
    elseif #violations <= 2 then
        notes = 'Good condition overall with minor issues to address.'
    elseif #violations <= 5 then
        notes = 'Several areas need improvement. Follow-up inspection recommended.'
    else
        notes = 'Multiple serious violations detected. Immediate action required.'
    end
    
    -- Save inspection
    local inspectionId = MySQL.insert.await([[
        INSERT INTO restaurant_inspections (job, location, score, grade, violations, bonuses, inspector_notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        job,
        locationKey or 'main',
        score,
        grade,
        json.encode(violations),
        json.encode(bonuses),
        notes
    })
    
    local result = {
        id = inspectionId,
        job = job,
        score = score,
        grade = grade,
        violations = violations,
        bonuses = bonuses,
        notes = notes,
        inspectedAt = os.time(),
    }
    
    -- Notify all staff
    notifyStaff(job, result)
    
    return result
end

--- Notify staff of inspection result
---@param job string
---@param result table
local function notifyStaff(job, result)
    local players = exports.qbx_core:GetQBPlayers()
    
    for _, player in pairs(players) do
        if player.PlayerData.job.name == job then
            TriggerClientEvent('free-restaurants:client:inspectionResult', player.PlayerData.source, result)
            
            local notifyType = 'inform'
            if result.grade == 'A' then notifyType = 'success'
            elseif result.grade == 'F' then notifyType = 'error'
            elseif result.grade == 'D' then notifyType = 'warning'
            end
            
            TriggerClientEvent('ox_lib:notify', player.PlayerData.source, {
                title = 'Health Inspection',
                description = ('Grade: %s (%d/100)'):format(result.grade, result.score),
                type = notifyType,
                duration = 10000,
            })
        end
    end
end

--- Get last inspection for a job
---@param job string
---@return table|nil
local function getLastInspection(job)
    return MySQL.single.await([[
        SELECT * FROM restaurant_inspections 
        WHERE job = ? 
        ORDER BY inspected_at DESC 
        LIMIT 1
    ]], { job })
end

--- Get inspection status for display
---@param job string
---@return table
local function getInspectionStatus(job)
    local last = getLastInspection(job)
    local cleanliness = getCleanlinessState(job)
    
    local status = {
        currentScore = cleanliness.score,
        activeViolations = cleanliness.violations,
        lastCleaned = cleanliness.lastCleaned,
    }
    
    if last then
        status.lastInspection = last.inspected_at
        status.lastGrade = last.grade
        status.lastScore = last.score
        
        -- Estimate next inspection
        local lastTime = os.time() -- Approximate from DB timestamp
        status.nextInspection = lastTime + (InspectionConfig.minTimeBetween * 3600)
    end
    
    return status
end

-- ============================================================================
-- INSPECTION SCHEDULER
-- ============================================================================

--- Check if inspection should occur
---@param job string
---@return boolean
local function shouldInspect(job)
    local last = getLastInspection(job)
    
    if last then
        -- Check minimum time between inspections
        local lastTime = os.time() -- Would need proper timestamp parsing
        local minInterval = InspectionConfig.minTimeBetween * 3600
        
        -- For now, just use random chance
        if math.random() > InspectionConfig.baseChance then
            return false
        end
    end
    
    return true
end

--- Run inspection check for all staffed restaurants
local function runInspectionCheck()
    local staffedJobs = {}
    local players = exports.qbx_core:GetQBPlayers()
    
    -- Find staffed restaurants
    for _, player in pairs(players) do
        local job = player.PlayerData.job.name
        if player.PlayerData.job.onduty and Config.Jobs[job] then
            staffedJobs[job] = true
        end
    end
    
    -- Check each for inspection
    for job, _ in pairs(staffedJobs) do
        if shouldInspect(job) then
            -- Announce inspection
            for _, player in pairs(players) do
                if player.PlayerData.job.name == job and player.PlayerData.job.onduty then
                    TriggerClientEvent('ox_lib:notify', player.PlayerData.source, {
                        title = 'Health Inspector',
                        description = 'A health inspector has arrived!',
                        type = 'warning',
                        duration = 8000,
                    })
                end
            end
            
            -- Delay then conduct inspection
            SetTimeout(30000, function() -- 30 second "inspection" period
                conductInspection(job)
            end)
            
            break -- Only one inspection per cycle
        end
    end
end

-- ============================================================================
-- CLEANLINESS DECAY
-- ============================================================================

--- Decrease cleanliness over time
local function decayCleanliness()
    for jobName, _ in pairs(Config.Jobs) do
        local current = getCleanlinessState(jobName)
        
        if current.score > 50 then
            -- Decay by 1-3 points
            local decay = math.random(1, 3)
            updateCleanliness(jobName, -decay, 'natural_decay')
        end
    end
end

-- ============================================================================
-- THREADS
-- ============================================================================

CreateThread(function()
    Wait(5000)
    initializeDatabase()
    
    while true do
        Wait(InspectionConfig.checkInterval * 60000)
        runInspectionCheck()
    end
end)

CreateThread(function()
    while true do
        Wait(3600000) -- Every hour
        decayCleanliness()
    end
end)

-- ============================================================================
-- CALLBACKS
-- ============================================================================

lib.callback.register('free-restaurants:server:getInspectionStatus', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    
    job = job or player.PlayerData.job.name
    
    return getInspectionStatus(job)
end)

lib.callback.register('free-restaurants:server:cleanStation', function(source, stationKey)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    local job = player.PlayerData.job.name
    
    -- Improve cleanliness
    updateCleanliness(job, 5, 'station_cleaned')
    markCleaned(job, player.PlayerData.citizenid)
    
    return true
end)

lib.callback.register('free-restaurants:server:fixViolation', function(source, violationId)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    local job = player.PlayerData.job.name
    clearViolation(job, violationId)
    updateCleanliness(job, 10, 'violation_fixed')
    
    -- Award XP
    exports['free-restaurants']:AwardXP(source, 15, 'Fixed violation', 'maintenance')
    
    return true
end)

lib.callback.register('free-restaurants:server:getInspectionHistory', function(source, job, limit)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    
    job = job or player.PlayerData.job.name
    limit = limit or 10
    
    local results = MySQL.query.await([[
        SELECT * FROM restaurant_inspections 
        WHERE job = ? 
        ORDER BY inspected_at DESC 
        LIMIT ?
    ]], { job, limit })
    
    return results or {}
end)

-- Admin: Force inspection
lib.callback.register('free-restaurants:server:forceInspection', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    
    -- Check admin permission
    if not exports.qbx_core:HasPermission(source, 'admin') then
        return nil
    end
    
    return conductInspection(job)
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetCleanlinessState', getCleanlinessState)
exports('UpdateCleanliness', updateCleanliness)
exports('ConductInspection', conductInspection)
exports('GetInspectionStatus', getInspectionStatus)

print('[free-restaurants] server/inspection.lua loaded')
