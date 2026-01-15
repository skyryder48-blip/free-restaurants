--[[
    free-restaurants Client Cooking System (Reworked)

    NEW FLOW:
    1. Player selects station and chooses recipe
    2. Skill check runs IMMEDIATELY based on recipe difficulty
    3. If passed, server starts autonomous cooking timer
    4. Player is FREE to leave - can use other slots/stations
    5. Item cooks autonomously (synced visuals for all players)
    6. Item stays at station until picked up
    7. Burns/spills/fires if not collected in time (configurable)

    DEPENDENCIES:
    - client/main.lua (state management)
    - client/stations.lua (station management)
    - ox_lib (skill checks)
    - server/crafting.lua (cooking timers)
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local isInSkillCheck = false  -- Only locked during skill check, not cooking

-- ============================================================================
-- DIFFICULTY SYSTEM
-- ============================================================================

-- Tier to base difficulty mapping
local TierDifficultyMap = {
    basic = 'easy',
    standard = 'medium',
    advanced = 'hard',
    signature = 'expert',
}

-- Station type difficulty modifiers
local StationDifficultyModifiers = {
    grill = 0,           -- Standard
    fryer = 0,           -- Standard
    prep_counter = -1,   -- Easier (simple prep work)
    drink_station = 0,   -- Standard
    coffee_machine = 1,  -- Harder (precision required)
    oven = 0,            -- Standard
    pizza_station = 1,   -- Harder (technique required)
    plating = -1,        -- Easier (final touches)
}

-- Difficulty parameters
local DifficultyParams = {
    easy = {
        areaSize = 50,
        speedMultiplier = 0.75,
        zones = 1,
    },
    medium = {
        areaSize = 40,
        speedMultiplier = 1.0,
        zones = 2,
    },
    hard = {
        areaSize = 30,
        speedMultiplier = 1.25,
        zones = 3,
    },
    expert = {
        areaSize = 22,
        speedMultiplier = 1.5,
        zones = 4,
    },
}

-- Station type to minigame style mapping
local StationMinigameStyles = {
    grill = { keys = { 'w', 'a', 's', 'd' }, style = 'bar' },
    fryer = { keys = { 'e' }, style = 'circle' },
    prep_counter = { keys = { 'w', 'a', 's', 'd' }, style = 'rapid' },
    drink_station = { keys = { 'e' }, style = 'circle' },
    coffee_machine = { keys = { 'e', 'q' }, style = 'sequence' },
    oven = { keys = { 'e' }, style = 'hold' },
    pizza_station = { keys = { 'w', 'a', 's', 'd' }, style = 'sequence' },
    plating = { keys = { 'e' }, style = 'bar' },
}

-- ============================================================================
-- SKILL CHECK FUNCTIONS
-- ============================================================================

--- Calculate final difficulty based on recipe tier, station type, and player skill
---@param recipeTier string Recipe tier ('basic', 'standard', 'advanced', 'signature')
---@param stationType string Station type
---@param playerSkill number Player's cooking skill level (0-100)
---@return string difficulty Final difficulty level
---@return table params Difficulty parameters
local function calculateDifficulty(recipeTier, stationType, playerSkill)
    local difficulties = { 'easy', 'medium', 'hard', 'expert' }
    local difficultyIndex = {
        easy = 1,
        medium = 2,
        hard = 3,
        expert = 4,
    }

    -- Start with tier-based difficulty
    local baseDifficulty = TierDifficultyMap[recipeTier] or 'medium'
    local baseIndex = difficultyIndex[baseDifficulty] or 2

    -- Apply station modifier
    local stationMod = StationDifficultyModifiers[stationType] or 0
    local modifiedIndex = baseIndex + stationMod

    -- Apply player skill reduction (every 25 skill points reduces difficulty by 1)
    local skillReduction = math.floor(playerSkill / 25)
    modifiedIndex = modifiedIndex - skillReduction

    -- Clamp to valid range
    modifiedIndex = math.max(1, math.min(4, modifiedIndex))

    local finalDifficulty = difficulties[modifiedIndex]
    local params = DifficultyParams[finalDifficulty]

    return finalDifficulty, params
end

--- Execute the skill check for a recipe
---@param recipeData table Recipe configuration
---@param stationType string Station type
---@param batchSize number Number of items being crafted
---@return boolean success Whether the skill check was passed
---@return number quality Quality multiplier (0.5-1.0) based on performance
local function executeSkillCheck(recipeData, stationType, batchSize)
    -- Check if skill checks are enabled
    if Config.Cooking and Config.Cooking.SkillChecks and not Config.Cooking.SkillChecks.enabled then
        return true, 1.0
    end

    -- Get player skill level
    local playerSkill = lib.callback.await('free-restaurants:server:getSkillLevel', false, recipeData.category) or 0

    -- Calculate difficulty
    local recipeTier = recipeData.tier or 'basic'
    local difficulty, params = calculateDifficulty(recipeTier, stationType, playerSkill)

    -- Scale for batch size
    if batchSize > 1 then
        local scaleFactor = 1 + (math.log(batchSize) * 0.12)
        params = {
            areaSize = math.max(18, math.floor(params.areaSize / scaleFactor)),
            speedMultiplier = params.speedMultiplier * scaleFactor,
            zones = math.min(5, params.zones + math.floor(batchSize / 3)),
        }
    end

    -- Get minigame style for this station
    local styleConfig = StationMinigameStyles[stationType] or StationMinigameStyles.grill
    local keys = styleConfig.keys

    -- Show difficulty notification
    local tierLabels = {
        easy = 'Easy',
        medium = 'Medium',
        hard = 'Hard',
        expert = 'Expert',
    }

    lib.notify({
        title = ('Preparing: %s'):format(recipeData.label),
        description = ('Difficulty: %s'):format(tierLabels[difficulty] or 'Medium'),
        type = difficulty == 'expert' and 'error' or (difficulty == 'hard' and 'warning' or 'inform'),
        duration = 2000,
    })

    Wait(500)

    -- Build skill check zones
    local zones = {}
    for i = 1, params.zones do
        local zoneSize = params.areaSize - ((i - 1) * 4)
        zones[i] = { areaSize = math.max(15, zoneSize), speedMultiplier = params.speedMultiplier }
    end

    -- Execute the skill check
    isInSkillCheck = true
    local success = lib.skillCheck(zones, keys)
    isInSkillCheck = false

    -- Calculate quality based on result
    local quality = success and 1.0 or 0.6

    -- Play feedback sound
    if success then
        PlaySoundFrontend(-1, 'PICK_UP_MONEY', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        lib.notify({
            title = 'Skill Check Passed!',
            description = 'Cooking has begun.',
            type = 'success',
            duration = 2000,
        })
    else
        PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

        -- Check if failure should cancel or just reduce quality
        local failOnMiss = Config.Cooking and Config.Cooking.SkillChecks and Config.Cooking.SkillChecks.failOnMiss
        if failOnMiss then
            lib.notify({
                title = 'Skill Check Failed!',
                description = 'You messed up the preparation.',
                type = 'error',
                duration = 2000,
            })
            return false, 0
        else
            lib.notify({
                title = 'Imperfect Start',
                description = 'Quality reduced, but cooking continues.',
                type = 'warning',
                duration = 2000,
            })
        end
    end

    return true, quality
end

-- ============================================================================
-- MAIN CRAFTING FUNCTION
-- ============================================================================

--- Start crafting a recipe at a station
--- This runs the skill check, then hands off to server for autonomous cooking
---@param recipeId string Recipe identifier
---@param recipeData table Recipe configuration
---@param stationData table Station data including location, station key, slot
local function startCrafting(recipeId, recipeData, stationData)
    if isInSkillCheck then
        lib.notify({
            title = 'Busy',
            description = 'Complete the current skill check first!',
            type = 'error',
        })
        return
    end

    local batchSize = stationData.batchAmount or 1
    local stationType = stationData.stationData and stationData.stationData.type or 'grill'

    -- Step 1: Consume ingredients on server
    local consumeSuccess, avgFreshness = lib.callback.await(
        'free-restaurants:server:consumeIngredients',
        false,
        recipeId,
        batchSize
    )

    if not consumeSuccess then
        lib.notify({
            title = 'Cannot Craft',
            description = avgFreshness or 'Missing ingredients',
            type = 'error',
        })
        return
    end

    -- Step 2: Run the skill check (player must pass this before cooking starts)
    local skillPassed, quality = executeSkillCheck(recipeData, stationType, batchSize)

    if not skillPassed then
        -- Return ingredients on failure
        lib.callback.await(
            'free-restaurants:server:returnIngredients',
            false,
            recipeId,
            batchSize
        )

        -- Release the slot
        TriggerServerEvent('free-restaurants:server:releaseSlot', {
            locationKey = stationData.locationKey,
            stationKey = stationData.stationKey,
            slotIndex = stationData.slotIndex,
            status = 'failed',
        })
        return
    end

    -- Step 3: Hand off to server for autonomous cooking
    -- Player is now FREE to leave and do other things!
    local cookingStarted = lib.callback.await(
        'free-restaurants:server:startAutonomousCooking',
        false,
        {
            recipeId = recipeId,
            locationKey = stationData.locationKey,
            stationKey = stationData.stationKey,
            slotIndex = stationData.slotIndex,
            quality = quality,
            avgFreshness = avgFreshness,
            batchSize = batchSize,
            craftTime = recipeData.craftTime or 10000,
        }
    )

    if cookingStarted then
        lib.notify({
            title = 'Cooking Started',
            description = ('Your %s is now cooking. You can leave and come back!'):format(recipeData.label),
            type = 'success',
            duration = 3000,
        })
    else
        lib.notify({
            title = 'Error',
            description = 'Failed to start cooking. Please try again.',
            type = 'error',
        })
        -- Return ingredients
        lib.callback.await('free-restaurants:server:returnIngredients', false, recipeId, batchSize)
    end
end

--- Start batch crafting at multiple slots
---@param recipeId string Recipe identifier
---@param recipeData table Recipe configuration
---@param stationData table Station data with claimedSlots array
local function startBatchCrafting(recipeId, recipeData, stationData)
    if isInSkillCheck then
        lib.notify({
            title = 'Busy',
            description = 'Complete the current skill check first!',
            type = 'error',
        })
        return
    end

    local amount = stationData.batchAmount or 1
    local claimedSlots = stationData.claimedSlots or { stationData.slotIndex }
    local stationType = stationData.stationData and stationData.stationData.type or 'grill'

    -- Step 1: Consume ingredients for entire batch
    local consumeSuccess, avgFreshness = lib.callback.await(
        'free-restaurants:server:consumeBatchIngredients',
        false,
        recipeId,
        amount
    )

    if not consumeSuccess then
        -- Release all claimed slots
        for _, slotIndex in ipairs(claimedSlots) do
            TriggerServerEvent('free-restaurants:server:releaseSlot', {
                locationKey = stationData.locationKey,
                stationKey = stationData.stationKey,
                slotIndex = slotIndex,
                status = 'cancelled',
            })
        end

        lib.notify({
            title = 'Cannot Craft',
            description = avgFreshness or 'Missing ingredients',
            type = 'error',
        })
        return
    end

    -- Step 2: Run ONE skill check for the entire batch (scaled difficulty)
    local skillPassed, quality = executeSkillCheck(recipeData, stationType, amount)

    if not skillPassed then
        -- Return ingredients and release slots
        lib.callback.await('free-restaurants:server:returnBatchIngredients', false, recipeId, amount)

        for _, slotIndex in ipairs(claimedSlots) do
            TriggerServerEvent('free-restaurants:server:releaseSlot', {
                locationKey = stationData.locationKey,
                stationKey = stationData.stationKey,
                slotIndex = slotIndex,
                status = 'failed',
            })
        end
        return
    end

    -- Step 3: Start autonomous cooking for each slot
    local cookingStarted = lib.callback.await(
        'free-restaurants:server:startBatchAutonomousCooking',
        false,
        {
            recipeId = recipeId,
            locationKey = stationData.locationKey,
            stationKey = stationData.stationKey,
            slots = claimedSlots,
            quality = quality,
            avgFreshness = avgFreshness,
            craftTime = recipeData.craftTime or 10000,
        }
    )

    if cookingStarted then
        lib.notify({
            title = 'Batch Cooking Started',
            description = ('%dx %s now cooking. You can leave!'):format(amount, recipeData.label),
            type = 'success',
            duration = 3000,
        })
    else
        lib.notify({
            title = 'Error',
            description = 'Failed to start batch cooking.',
            type = 'error',
        })
        lib.callback.await('free-restaurants:server:returnBatchIngredients', false, recipeId, amount)
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Start single item crafting
RegisterNetEvent('free-restaurants:client:startCrafting', function(recipeId, recipeData, stationData)
    startCrafting(recipeId, recipeData, stationData)
end)

-- Start batch crafting
RegisterNetEvent('free-restaurants:client:startBatchCrafting', function(recipeId, recipeData, stationData)
    startBatchCrafting(recipeId, recipeData, stationData)
end)

-- Legacy batch craft dialog
RegisterNetEvent('free-restaurants:client:batchCraft', function(recipeId, recipeData, stationData)
    startBatchCrafting(recipeId, recipeData, stationData)
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsInSkillCheck', function() return isInSkillCheck end)
exports('StartCrafting', startCrafting)
exports('StartBatchCrafting', startBatchCrafting)
exports('ExecuteSkillCheck', executeSkillCheck)

FreeRestaurants.Utils.Debug('client/cooking.lua loaded (reworked autonomous system)')
