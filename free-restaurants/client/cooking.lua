--[[
    free-restaurants Client Cooking System
    
    Handles:
    - Crafting workflows with multi-step processes
    - Skill check minigames (skillbar, circle, keys)
    - Progress bar animations
    - Quality calculations
    - XP rewards and progression
    - Ingredient validation
    
    DEPENDENCIES:
    - client/main.lua (state management)
    - client/stations.lua (station management)
    - ox_lib (skill checks, progress bars)
    - ox_inventory (ingredient checks)
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local isCrafting = false
local currentCraft = nil
local craftingProps = {}

-- ============================================================================
-- SKILL CHECK SYSTEM
-- ============================================================================

--- Get skill check difficulty based on player skill and config
---@param baseSkill number Player's skill level
---@param recipeDifficulty string Recipe difficulty ('easy', 'medium', 'hard')
---@return string difficulty Adjusted difficulty
local function getAdjustedDifficulty(baseSkill, recipeDifficulty)
    if not Config.Cooking.SkillChecks.difficulty.skillScaling then
        return recipeDifficulty
    end
    
    local scalingFactor = Config.Cooking.SkillChecks.difficulty.scalingFactor or 0.05
    local reduction = baseSkill * scalingFactor
    
    local difficulties = { 'easy', 'medium', 'hard' }
    local difficultyIndex = {
        easy = 1,
        medium = 2,
        hard = 3,
    }
    
    local currentIndex = difficultyIndex[recipeDifficulty] or 2
    local newIndex = math.max(1, currentIndex - math.floor(reduction / 0.15))
    
    local minDifficulty = Config.Cooking.SkillChecks.difficulty.minimumDifficulty or 'easy'
    local minIndex = difficultyIndex[minDifficulty] or 1
    newIndex = math.max(minIndex, newIndex)
    
    return difficulties[newIndex]
end

--- Get skill check parameters based on difficulty
---@param difficulty string 'easy', 'medium', 'hard'
---@return table params Skill check parameters
local function getSkillCheckParams(difficulty)
    local params = {
        easy = {
            areaSize = 50,
            speedMultiplier = 0.8,
            duration = 6000,
        },
        medium = {
            areaSize = 40,
            speedMultiplier = 1.0,
            duration = 5000,
        },
        hard = {
            areaSize = 25,
            speedMultiplier = 1.3,
            duration = 4000,
        },
    }
    
    return params[difficulty] or params.medium
end

--- Execute a skill check
---@param action string Action type (prep, cook, plate, etc.)
---@param difficulty string Difficulty level
---@return boolean success
---@return number quality Quality multiplier (0.0-1.0)
local function doSkillCheck(action, difficulty)
    local settings = Config.Cooking.SkillChecks
    
    -- Check if skill checks are enabled
    if not settings.enabled then
        return true, 1.0
    end
    
    -- Check if this action requires skill check
    if settings.actions and not settings.actions[action] then
        return true, 1.0
    end
    
    local params = getSkillCheckParams(difficulty)
    local style = settings.style.type or 'skillbar'
    
    local success, quality = false, 0.5
    
    if style == 'skillbar' then
        success = lib.skillCheck(
            { params.areaSize },
            { 'w', 'a', 's', 'd' }
        )
        quality = success and 1.0 or 0.5
        
    elseif style == 'circle' then
        success = lib.skillCheck(
            { params.areaSize, params.areaSize - 10 },
            { 'e' }
        )
        quality = success and 1.0 or 0.5
        
    elseif style == 'keys' then
        local keys = settings.style.keys or { 'w', 'a', 's', 'd' }
        success = lib.skillCheck(
            { params.areaSize },
            keys
        )
        quality = success and 1.0 or 0.5
    end
    
    return success, quality
end

-- ============================================================================
-- INGREDIENT VALIDATION
-- ============================================================================

--- Check if player has all required ingredients
---@param ingredients table Recipe ingredients array { { item = 'name', count = n }, ... }
---@return boolean hasAll
---@return table missing Missing items { [item] = needed }
local function hasIngredients(ingredients)
    local missing = {}
    local hasAll = true

    for _, ingredient in ipairs(ingredients) do
        local itemName = ingredient.item
        local requiredCount = ingredient.count or 1

        if itemName then
            local count = exports.ox_inventory:Search('count', itemName)
            if not count or count < requiredCount then
                missing[itemName] = requiredCount - (count or 0)
                hasAll = false
            end
        end
    end

    return hasAll, missing
end

--- Format missing ingredients for display
---@param missing table Missing items
---@return string
local function formatMissingIngredients(missing)
    local parts = {}
    for item, amount in pairs(missing) do
        local itemLabel = exports.ox_inventory:Items()[item]?.label or item
        table.insert(parts, ('%dx %s'):format(amount, itemLabel))
    end
    return table.concat(parts, ', ')
end

-- ============================================================================
-- CRAFTING WORKFLOW
-- ============================================================================

--- Start crafting a recipe
---@param recipeId string Recipe identifier
---@param recipeData table Recipe configuration
---@param stationData table Active station data
local function startCrafting(recipeId, recipeData, stationData)
    if isCrafting then
        lib.notify({
            title = 'Busy',
            description = 'You are already crafting something!',
            type = 'error',
        })
        return
    end
    
    -- Check ingredients
    local hasAll, missing = hasIngredients(recipeData.ingredients)
    if not hasAll then
        lib.notify({
            title = 'Missing Ingredients',
            description = formatMissingIngredients(missing),
            type = 'error',
        })
        return
    end
    
    -- Start crafting
    isCrafting = true
    currentCraft = {
        recipeId = recipeId,
        recipeData = recipeData,
        stationData = stationData,
        qualityMultiplier = 1.0,
        startTime = GetGameTimer(),
    }
    
    FreeRestaurants.Utils.Debug(('Starting craft: %s'):format(recipeId))
    
    -- Execute crafting steps
    local success, finalQuality = executeCraftingSteps(recipeData, stationData)
    
    if success then
        -- Complete crafting on server
        completeCrafting(finalQuality)
    else
        -- Failed crafting
        failCrafting()
    end
end

--- Execute all crafting steps
---@param recipeData table Recipe configuration
---@param stationData table Station data
---@return boolean success
---@return number quality Final quality multiplier
local function executeCraftingSteps(recipeData, stationData)
    local steps = recipeData.steps or { { action = 'craft', label = 'Crafting...' } }
    local totalQuality = 0
    local stepCount = #steps
    
    -- Get player skill level for this recipe type
    local playerSkill = lib.callback.await('free-restaurants:server:getSkillLevel', false, recipeData.category) or 0
    
    for i, step in ipairs(steps) do
        -- Show step progress
        local stepLabel = step.label or ('Step %d/%d'):format(i, stepCount)
        
        -- Load animation if specified
        if step.anim then
            lib.requestAnimDict(step.anim.dict)
        end
        
        -- Play progress bar
        local progressSuccess = lib.progressCircle({
            duration = step.duration or (recipeData.craftTime or 5000) / stepCount,
            label = stepLabel,
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = not step.allowMove,
                car = true,
                combat = true,
            },
            anim = step.anim and {
                dict = step.anim.dict,
                clip = step.anim.clip,
                flag = step.anim.flag or 49,
            } or nil,
            prop = step.prop and {
                model = step.prop.model,
                bone = step.prop.bone,
                pos = step.prop.pos,
                rot = step.prop.rot,
            } or nil,
        })
        
        if not progressSuccess then
            -- Player cancelled
            return false, 0
        end
        
        -- Do skill check if required for this step
        if step.skillCheck ~= false then
            local action = step.action or 'craft'
            local difficulty = getAdjustedDifficulty(playerSkill, recipeData.difficulty or 'medium')
            
            local checkSuccess, quality = doSkillCheck(action, difficulty)
            
            if not checkSuccess then
                -- Skill check failed
                if Config.Cooking.SkillChecks.failOnMiss then
                    lib.notify({
                        title = 'Failed',
                        description = 'You messed up the ' .. (step.failText or 'process') .. '!',
                        type = 'error',
                    })
                    return false, 0
                else
                    -- Reduce quality but continue
                    quality = 0.5
                end
            end
            
            totalQuality = totalQuality + quality
        else
            totalQuality = totalQuality + 1.0
        end
    end
    
    -- Calculate average quality
    local avgQuality = totalQuality / stepCount
    
    return true, avgQuality
end

--- Complete crafting successfully
---@param quality number Quality multiplier
local function completeCrafting(quality)
    if not currentCraft then return end
    
    local recipeId = currentCraft.recipeId
    local recipeData = currentCraft.recipeData
    local stationData = currentCraft.stationData
    
    -- Send to server for item creation
    local success, message = lib.callback.await(
        'free-restaurants:server:completeCraft',
        false,
        recipeId,
        quality,
        stationData.locationKey
    )
    
    -- Clear crafting state
    isCrafting = false
    currentCraft = nil
    clearCraftingProps()
    
    if success then
        -- Success notification
        local qualityLabel, qualityColor = FreeRestaurants.Utils.GetQualityLabel(quality * 100)
        
        lib.notify({
            title = 'Crafting Complete',
            description = ('Created %s (%s quality)'):format(recipeData.label, qualityLabel),
            type = 'success',
        })
        
        -- XP notification if applicable
        if recipeData.xpReward then
            lib.notify({
                title = 'Experience',
                description = ('+%d XP'):format(recipeData.xpReward),
                type = 'inform',
                icon = 'star',
            })
        end
    else
        lib.notify({
            title = 'Crafting Failed',
            description = message or 'Something went wrong!',
            type = 'error',
        })
    end
    
    -- Trigger completion event
    TriggerEvent('free-restaurants:client:craftingComplete')
end

--- Handle failed crafting
local function failCrafting()
    if not currentCraft then return end
    
    local recipeData = currentCraft.recipeData
    
    -- Determine if ingredients are lost on failure
    local loseIngredients = Config.Cooking.Quality.failurePenalty ~= false
    
    if loseIngredients then
        -- Notify server to remove some ingredients
        lib.callback.await(
            'free-restaurants:server:craftFailed',
            false,
            currentCraft.recipeId,
            currentCraft.stationData.locationKey
        )
        
        lib.notify({
            title = 'Crafting Failed',
            description = 'You ruined the ' .. recipeData.label .. ' and lost some ingredients!',
            type = 'error',
        })
    else
        lib.notify({
            title = 'Crafting Cancelled',
            description = 'Crafting was cancelled.',
            type = 'inform',
        })
    end
    
    -- Clear state
    isCrafting = false
    currentCraft = nil
    clearCraftingProps()
    
    -- Clear animation
    ClearPedTasks(cache.ped)
    
    -- Trigger completion event (to reopen menu)
    TriggerEvent('free-restaurants:client:craftingComplete')
end

--- Clear crafting props
local function clearCraftingProps()
    for _, prop in ipairs(craftingProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    craftingProps = {}
end

-- ============================================================================
-- QUICK CRAFT (No skill checks, for simple items)
-- ============================================================================

--- Quick craft without skill checks
---@param recipeId string Recipe identifier
---@param recipeData table Recipe configuration
---@param stationData table Active station data
local function quickCraft(recipeId, recipeData, stationData)
    if isCrafting then
        lib.notify({
            title = 'Busy',
            description = 'You are already crafting something!',
            type = 'error',
        })
        return
    end
    
    -- Check ingredients
    local hasAll, missing = hasIngredients(recipeData.ingredients)
    if not hasAll then
        lib.notify({
            title = 'Missing Ingredients',
            description = formatMissingIngredients(missing),
            type = 'error',
        })
        return
    end
    
    isCrafting = true
    currentCraft = {
        recipeId = recipeId,
        recipeData = recipeData,
        stationData = stationData,
    }
    
    -- Simple progress bar
    local success = lib.progressCircle({
        duration = recipeData.craftTime or 3000,
        label = ('Making %s...'):format(recipeData.label),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            combat = true,
        },
    })
    
    if success then
        completeCrafting(1.0) -- Full quality for quick crafts
    else
        failCrafting()
    end
end

-- ============================================================================
-- BATCH CRAFTING
-- ============================================================================

--- Open batch crafting dialog
---@param recipeId string Recipe identifier
---@param recipeData table Recipe configuration
---@param stationData table Active station data
local function openBatchCraft(recipeId, recipeData, stationData)
    -- Calculate max craftable based on ingredients
    local maxCraftable = 999
    for item, amount in pairs(recipeData.ingredients) do
        local count = exports.ox_inventory:Search('count', item)
        local possible = math.floor(count / amount)
        maxCraftable = math.min(maxCraftable, possible)
    end
    
    if maxCraftable <= 0 then
        lib.notify({
            title = 'Missing Ingredients',
            description = 'You don\'t have enough ingredients!',
            type = 'error',
        })
        return
    end
    
    local input = lib.inputDialog('Batch Craft ' .. recipeData.label, {
        {
            type = 'number',
            label = 'Amount',
            description = ('Max: %d'):format(maxCraftable),
            default = 1,
            min = 1,
            max = maxCraftable,
        },
    })
    
    if not input then return end
    
    local amount = input[1]
    if amount < 1 or amount > maxCraftable then return end
    
    -- Start batch crafting
    batchCraft(recipeId, recipeData, stationData, amount)
end

--- Execute batch crafting
---@param recipeId string
---@param recipeData table
---@param stationData table
---@param amount number
local function batchCraft(recipeId, recipeData, stationData, amount)
    if isCrafting then return end
    
    isCrafting = true
    currentCraft = {
        recipeId = recipeId,
        recipeData = recipeData,
        stationData = stationData,
        batchAmount = amount,
    }
    
    local totalTime = (recipeData.craftTime or 5000) * amount
    local crafted = 0
    
    -- Progress with updates
    local success = lib.progressCircle({
        duration = totalTime,
        label = ('Crafting %d x %s...'):format(amount, recipeData.label),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            combat = true,
        },
    })
    
    if success then
        -- Complete batch on server
        local serverSuccess, message = lib.callback.await(
            'free-restaurants:server:completeBatchCraft',
            false,
            recipeId,
            amount,
            stationData.locationKey
        )
        
        if serverSuccess then
            lib.notify({
                title = 'Batch Complete',
                description = ('Crafted %d x %s'):format(amount, recipeData.label),
                type = 'success',
            })
        else
            lib.notify({
                title = 'Batch Failed',
                description = message or 'Something went wrong!',
                type = 'error',
            })
        end
    else
        lib.notify({
            title = 'Cancelled',
            description = 'Batch crafting cancelled.',
            type = 'inform',
        })
    end
    
    isCrafting = false
    currentCraft = nil
    
    TriggerEvent('free-restaurants:client:craftingComplete')
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Start crafting event (from stations.lua)
RegisterNetEvent('free-restaurants:client:startCrafting', function(recipeId, recipeData, stationData)
    -- Check if this is a quick craft recipe
    if recipeData.quickCraft then
        quickCraft(recipeId, recipeData, stationData)
    else
        startCrafting(recipeId, recipeData, stationData)
    end
end)

-- Batch craft request
RegisterNetEvent('free-restaurants:client:batchCraft', function(recipeId, recipeData, stationData)
    openBatchCraft(recipeId, recipeData, stationData)
end)

-- Cancel crafting (e.g., when leaving area)
RegisterNetEvent('free-restaurants:client:cancelCrafting', function()
    if isCrafting then
        failCrafting()
    end
end)

-- Clean up on clock out
RegisterNetEvent('free-restaurants:client:clockedOut', function()
    if isCrafting then
        failCrafting()
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsCrafting', function() return isCrafting end)
exports('GetCurrentCraft', function() return currentCraft end)
exports('StartCrafting', startCrafting)
exports('QuickCraft', quickCraft)
exports('BatchCraft', openBatchCraft)
exports('CancelCrafting', function()
    if isCrafting then
        failCrafting()
    end
end)
exports('HasIngredients', hasIngredients)
exports('DoSkillCheck', doSkillCheck)

FreeRestaurants.Utils.Debug('client/cooking.lua loaded')
