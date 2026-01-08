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

-- Forward declarations for functions used before definition
local executeCraftingSteps
local completeCrafting
local failCrafting
local clearCraftingProps

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
---@param recipeSkillCheck table|nil Optional recipe-specific skill check config
---@return boolean success
---@return number quality Quality multiplier (0.0-1.0)
local function doSkillCheck(action, difficulty, recipeSkillCheck)
    local settings = Config.Cooking.SkillChecks

    -- Check if skill checks are enabled globally
    if not settings.enabled then
        return true, 1.0
    end

    -- Recipe can override to skip skill check entirely
    if recipeSkillCheck and recipeSkillCheck.enabled == false then
        return true, 1.0
    end

    -- Check if this action requires skill check (unless recipe explicitly enables it)
    local actionEnabled = recipeSkillCheck and recipeSkillCheck.enabled
    if not actionEnabled and settings.actions and not settings.actions[action] then
        return true, 1.0
    end

    -- Get parameters - recipe config overrides global config
    local useDifficulty = (recipeSkillCheck and recipeSkillCheck.difficulty) or difficulty
    local params = getSkillCheckParams(useDifficulty)

    -- Recipe can override individual parameters
    if recipeSkillCheck then
        if recipeSkillCheck.areaSize then params.areaSize = recipeSkillCheck.areaSize end
        if recipeSkillCheck.speedMultiplier then params.speedMultiplier = recipeSkillCheck.speedMultiplier end
        if recipeSkillCheck.duration then params.duration = recipeSkillCheck.duration end
    end

    -- Determine skill check style (recipe overrides global)
    local style = (recipeSkillCheck and recipeSkillCheck.type) or settings.style.type or 'skillbar'
    local keys = (recipeSkillCheck and recipeSkillCheck.keys) or settings.style.keys or { 'w', 'a', 's', 'd' }

    local success, quality = false, 0.5

    if style == 'skillbar' then
        success = lib.skillCheck(
            { params.areaSize },
            keys
        )
        quality = success and 1.0 or 0.5

    elseif style == 'circle' then
        local secondSize = (recipeSkillCheck and recipeSkillCheck.areaSize2) or (params.areaSize - 10)
        success = lib.skillCheck(
            { params.areaSize, secondSize },
            { 'e' }
        )
        quality = success and 1.0 or 0.5

    elseif style == 'keys' then
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

    -- Consume ingredients FIRST (before progress starts)
    local consumeSuccess, avgFreshness = lib.callback.await(
        'free-restaurants:server:consumeIngredients',
        false,
        recipeId
    )

    if not consumeSuccess then
        lib.notify({
            title = 'Cannot Craft',
            description = avgFreshness or 'Missing ingredients',
            type = 'error',
        })
        return
    end

    -- Ingredients consumed - start crafting
    isCrafting = true
    currentCraft = {
        recipeId = recipeId,
        recipeData = recipeData,
        stationData = stationData,
        avgFreshness = avgFreshness, -- Store for quality calculation
        qualityMultiplier = 1.0,
        startTime = GetGameTimer(),
        ingredientsConsumed = true, -- Track that ingredients were taken
    }

    FreeRestaurants.Utils.Debug(('Starting craft: %s - ingredients consumed'):format(recipeId))

    -- Execute crafting steps
    local success, finalQuality = executeCraftingSteps(recipeData, stationData)

    if success then
        -- Complete crafting on server (give item)
        completeCrafting(finalQuality)
    else
        -- Cancelled - return ingredients
        failCrafting()
    end
end

--- Execute all crafting steps
---@param recipeData table Recipe configuration
---@param stationData table Station data
---@return boolean success
---@return number quality Final quality multiplier
executeCraftingSteps = function(recipeData, stationData)
    local steps = recipeData.steps or recipeData.stations or { { action = 'cook', label = 'Cooking...' } }
    local totalQuality = 0
    local stepCount = #steps

    -- Get player skill level for this recipe type
    local playerSkill = lib.callback.await('free-restaurants:server:getSkillLevel', false, recipeData.category) or 0

    -- Notify stations.lua that cooking is starting
    TriggerEvent('free-restaurants:client:cookingStateUpdate', {
        locationKey = stationData.locationKey,
        stationKey = stationData.stationKey,
        slotIndex = stationData.slotIndex,
        stationType = stationData.stationData and stationData.stationData.type or 'grill',
        slotCoords = stationData.slotCoords,
        status = 'cooking',
        progress = 0,
        quality = 100,
    })

    for i, step in ipairs(steps) do
        -- Show step progress
        local stepLabel = step.label or ('Step %d/%d'):format(i, stepCount)

        -- Load animation if specified
        if step.anim then
            lib.requestAnimDict(step.anim.dict)
        end

        -- Update cooking state for particles
        local stepProgress = math.floor((i - 1) / stepCount * 100)
        TriggerEvent('free-restaurants:client:cookingStateUpdate', {
            locationKey = stationData.locationKey,
            stationKey = stationData.stationKey,
            slotIndex = stationData.slotIndex,
            stationType = stationData.stationData and stationData.stationData.type or 'grill',
            slotCoords = stationData.slotCoords,
            status = 'cooking',
            progress = stepProgress,
            quality = 100,
        })

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
            local action = step.action or step.step or step.type or 'cook'
            local difficulty = getAdjustedDifficulty(playerSkill, recipeData.difficulty or 'medium')

            -- Build skill check config from recipe and step overrides
            -- Priority: step.skillCheck > recipeData.skillCheck > global config
            local skillCheckConfig = nil
            if type(step.skillCheck) == 'table' then
                -- Step has explicit skill check configuration
                skillCheckConfig = step.skillCheck
            elseif recipeData.skillCheck then
                -- Recipe has global skill check configuration
                skillCheckConfig = recipeData.skillCheck
            end

            local checkSuccess, quality = doSkillCheck(action, difficulty, skillCheckConfig)

            if not checkSuccess then
                -- Skill check failed
                local failOnMiss = (skillCheckConfig and skillCheckConfig.failOnMiss ~= nil)
                    and skillCheckConfig.failOnMiss
                    or Config.Cooking.SkillChecks.failOnMiss

                if failOnMiss then
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

    -- Notify stations.lua that cooking is complete
    TriggerEvent('free-restaurants:client:cookingStateUpdate', {
        locationKey = stationData.locationKey,
        stationKey = stationData.stationKey,
        slotIndex = stationData.slotIndex,
        stationType = stationData.stationData and stationData.stationData.type or 'grill',
        slotCoords = stationData.slotCoords,
        status = 'ready',
        progress = 100,
        quality = math.floor(avgQuality * 100),
    })

    return true, avgQuality
end

--- Complete crafting successfully
---@param quality number Quality multiplier
completeCrafting = function(quality)
    if not currentCraft then return end

    local recipeId = currentCraft.recipeId
    local recipeData = currentCraft.recipeData
    local stationData = currentCraft.stationData
    local avgFreshness = currentCraft.avgFreshness

    -- Get station type config for pickup settings
    local stationType = stationData.stationData and stationData.stationData.type or 'prep_counter'
    local stationTypeConfig = Config.Stations.Types[stationType]
    local pickupConfig = stationTypeConfig and stationTypeConfig.pickup

    -- Store item at station for pickup (instead of giving directly to player)
    local success, message = lib.callback.await(
        'free-restaurants:server:storeAtStation',
        false,
        recipeId,
        quality,
        stationData.locationKey,
        stationData.stationKey,
        stationData.slotIndex,
        avgFreshness
    )

    -- Save station data before clearing for the completion event
    local completionData = {
        locationKey = stationData.locationKey,
        stationKey = stationData.stationKey,
        slotIndex = stationData.slotIndex,
        slotCoords = stationData.slotCoords,
        stationType = stationType,
        status = success and 'ready_for_pickup' or 'failed',
        recipeId = recipeId,
        recipeLabel = recipeData.label,
        quality = quality,
        pickupConfig = pickupConfig,
    }

    -- Clear crafting state
    isCrafting = false
    currentCraft = nil
    clearCraftingProps()

    if success then
        -- Success notification - item is ready for pickup
        local qualityLabel, qualityColor = FreeRestaurants.Utils.GetQualityLabel(quality * 100)

        lib.notify({
            title = 'Ready for Pickup',
            description = ('%s is ready! Pick it up from the station.'):format(recipeData.label),
            type = 'success',
        })

        -- Show warning about burn/spill if applicable
        if pickupConfig and pickupConfig.timeout and pickupConfig.timeout > 0 then
            if pickupConfig.canBurn then
                lib.notify({
                    title = 'Warning',
                    description = ('Pick up within %d seconds or it will burn!'):format(pickupConfig.timeout),
                    type = 'warning',
                })
            elseif pickupConfig.canSpill then
                lib.notify({
                    title = 'Warning',
                    description = ('Pick up within %d seconds or it will spill!'):format(pickupConfig.timeout),
                    type = 'warning',
                })
            end
        end

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

    -- Trigger completion event with station data (item stays at station until pickup)
    TriggerEvent('free-restaurants:client:cookingComplete', completionData)
end

--- Handle failed/cancelled crafting
failCrafting = function()
    if not currentCraft then return end

    local recipeId = currentCraft.recipeId
    local recipeData = currentCraft.recipeData
    local stationData = currentCraft.stationData
    local ingredientsConsumed = currentCraft.ingredientsConsumed

    -- Save station data before clearing for the completion event
    local completionData = {
        locationKey = stationData.locationKey,
        stationKey = stationData.stationKey,
        slotIndex = stationData.slotIndex,
        status = 'cancelled',
    }

    -- Return ingredients if they were consumed
    if ingredientsConsumed then
        lib.callback.await(
            'free-restaurants:server:returnIngredients',
            false,
            recipeId
        )

        lib.notify({
            title = 'Crafting Cancelled',
            description = 'Ingredients have been returned.',
            type = 'inform',
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

    -- Trigger completion event with station data for slot release
    TriggerEvent('free-restaurants:client:cookingComplete', completionData)
end

--- Clear crafting props
clearCraftingProps = function()
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

    -- Consume ingredients FIRST (before progress starts)
    local consumeSuccess, avgFreshness = lib.callback.await(
        'free-restaurants:server:consumeIngredients',
        false,
        recipeId
    )

    if not consumeSuccess then
        lib.notify({
            title = 'Cannot Craft',
            description = avgFreshness or 'Missing ingredients',
            type = 'error',
        })
        return
    end

    isCrafting = true
    currentCraft = {
        recipeId = recipeId,
        recipeData = recipeData,
        stationData = stationData,
        avgFreshness = avgFreshness,
        ingredientsConsumed = true,
    }

    -- Notify stations.lua that cooking is starting
    TriggerEvent('free-restaurants:client:cookingStateUpdate', {
        locationKey = stationData.locationKey,
        stationKey = stationData.stationKey,
        slotIndex = stationData.slotIndex,
        stationType = stationData.stationData and stationData.stationData.type or 'grill',
        slotCoords = stationData.slotCoords,
        status = 'cooking',
        progress = 0,
        quality = 100,
    })

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
        -- Notify stations.lua that cooking is complete
        TriggerEvent('free-restaurants:client:cookingStateUpdate', {
            locationKey = stationData.locationKey,
            stationKey = stationData.stationKey,
            slotIndex = stationData.slotIndex,
            stationType = stationData.stationData and stationData.stationData.type or 'grill',
            slotCoords = stationData.slotCoords,
            status = 'ready',
            progress = 100,
            quality = 100,
        })
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
    -- Calculate max craftable based on ingredients (using array format)
    local maxCraftable = 999
    for _, ingredient in ipairs(recipeData.ingredients) do
        local item = ingredient.item
        local amount = ingredient.count or 1
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

    -- Consume ingredients FIRST (before progress starts)
    local consumeSuccess, avgFreshness = lib.callback.await(
        'free-restaurants:server:consumeBatchIngredients',
        false,
        recipeId,
        amount
    )

    if not consumeSuccess then
        lib.notify({
            title = 'Cannot Craft',
            description = avgFreshness or 'Missing ingredients',
            type = 'error',
        })
        return
    end

    isCrafting = true
    currentCraft = {
        recipeId = recipeId,
        recipeData = recipeData,
        stationData = stationData,
        batchAmount = amount,
        avgFreshness = avgFreshness,
        ingredientsConsumed = true,
    }

    -- Notify stations.lua that cooking is starting
    TriggerEvent('free-restaurants:client:cookingStateUpdate', {
        locationKey = stationData.locationKey,
        stationKey = stationData.stationKey,
        slotIndex = stationData.slotIndex,
        stationType = stationData.stationData and stationData.stationData.type or 'grill',
        slotCoords = stationData.slotCoords,
        status = 'cooking',
        progress = 0,
        quality = 100,
    })

    local totalTime = (recipeData.craftTime or 5000) * amount

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

    -- Save station data before clearing for the completion event
    local completionData = {
        locationKey = stationData.locationKey,
        stationKey = stationData.stationKey,
        slotIndex = stationData.slotIndex,
        status = success and 'completed' or 'cancelled',
    }

    if success then
        -- Notify stations.lua that cooking is complete
        TriggerEvent('free-restaurants:client:cookingStateUpdate', {
            locationKey = stationData.locationKey,
            stationKey = stationData.stationKey,
            slotIndex = stationData.slotIndex,
            stationType = stationData.stationData and stationData.stationData.type or 'grill',
            slotCoords = stationData.slotCoords,
            status = 'ready',
            progress = 100,
            quality = 90, -- Batch is slightly lower quality
        })

        -- Complete batch on server (give items)
        local serverSuccess, message = lib.callback.await(
            'free-restaurants:server:completeBatchCraft',
            false,
            recipeId,
            amount,
            stationData.locationKey,
            avgFreshness
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
        -- Cancelled - return ingredients
        lib.callback.await(
            'free-restaurants:server:returnBatchIngredients',
            false,
            recipeId,
            amount
        )

        lib.notify({
            title = 'Cancelled',
            description = 'Batch crafting cancelled. Ingredients returned.',
            type = 'inform',
        })
    end

    isCrafting = false
    currentCraft = nil

    -- Trigger completion event with station data for slot release
    TriggerEvent('free-restaurants:client:cookingComplete', completionData)
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
