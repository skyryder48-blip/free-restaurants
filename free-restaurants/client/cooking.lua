--[[
    free-restaurants Client Cooking System

    Handles:
    - Crafting workflows with multi-step processes
    - Skill check minigames (skillbar, circle, keys, rapid, sequence)
    - Progress bar animations with immersive feedback
    - Quality calculations based on performance
    - XP rewards and progression
    - Ingredient validation
    - Batch crafting with scaled difficulty

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
local activeSounds = {}

-- Forward declarations for functions used before definition
local executeCraftingSteps
local completeCrafting
local failCrafting
local clearCraftingProps
local openBatchCraft
local batchCraft
local playCookingSound
local stopCookingSound

-- ============================================================================
-- COOKING SOUNDS SYSTEM
-- ============================================================================

-- Sound definitions for different cooking actions
local CookingSounds = {
    grill = { name = 'grill_sizzle', ref = 'DLC_CASINO_NIGHTCLUB_SFX_SOUNDS' },
    fry = { name = 'fry_bubbling', ref = 'DLC_CASINO_NIGHTCLUB_SFX_SOUNDS' },
    chop = { name = 'knife_chop', ref = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    blend = { name = 'blender_whir', ref = 'DLC_CASINO_NIGHTCLUB_SFX_SOUNDS' },
    pour = { name = 'liquid_pour', ref = 'HUD_LIQUOR_SOUNDSET' },
    steam = { name = 'steam_hiss', ref = 'DLC_CASINO_NIGHTCLUB_SFX_SOUNDS' },
    plate = { name = 'plate_clink', ref = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    success = { name = 'PICK_UP_MONEY', ref = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    fail = { name = 'ERROR', ref = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    timer_warning = { name = 'TIMER_STOP', ref = 'HUD_MINI_GAME_SOUNDSET' },
}

--- Play a cooking sound effect
---@param soundType string The type of sound to play
---@param loop boolean|nil Whether to loop the sound
playCookingSound = function(soundType, loop)
    if not Config.Immersion.Sounds.enabled then return end

    local sound = CookingSounds[soundType]
    if not sound then return end

    local soundId = GetSoundId()
    if loop then
        -- For looping sounds, we'll use ambient approach
        PlaySoundFromEntity(soundId, sound.name, cache.ped, sound.ref, false, 0)
        activeSounds[soundType] = soundId
    else
        PlaySoundFrontend(soundId, sound.name, sound.ref, true)
        ReleaseSoundId(soundId)
    end
end

--- Stop a looping cooking sound
---@param soundType string The type of sound to stop
stopCookingSound = function(soundType)
    local soundId = activeSounds[soundType]
    if soundId then
        StopSound(soundId)
        ReleaseSoundId(soundId)
        activeSounds[soundType] = nil
    end
end

--- Stop all active cooking sounds
local function stopAllCookingSounds()
    for soundType, soundId in pairs(activeSounds) do
        StopSound(soundId)
        ReleaseSoundId(soundId)
    end
    activeSounds = {}
end

-- ============================================================================
-- TIER-BASED DIFFICULTY SYSTEM
-- ============================================================================

-- Tier to base difficulty mapping
local TierDifficultyMap = {
    basic = 'easy',
    standard = 'medium',
    advanced = 'hard',
    signature = 'expert',
}

-- Extended difficulty parameters including 'expert' level
local DifficultyParams = {
    easy = {
        areaSize = 50,
        speedMultiplier = 0.7,
        zones = 1,          -- Number of skill check zones
        keyCount = 3,       -- Number of keys for rapid/sequence checks
        timePerKey = 800,   -- ms per key press
        mistakesAllowed = 2,
    },
    medium = {
        areaSize = 40,
        speedMultiplier = 1.0,
        zones = 2,
        keyCount = 4,
        timePerKey = 650,
        mistakesAllowed = 1,
    },
    hard = {
        areaSize = 28,
        speedMultiplier = 1.3,
        zones = 3,
        keyCount = 5,
        timePerKey = 500,
        mistakesAllowed = 1,
    },
    expert = {
        areaSize = 20,
        speedMultiplier = 1.6,
        zones = 4,
        keyCount = 6,
        timePerKey = 400,
        mistakesAllowed = 0,
    },
}

-- Action to minigame type mapping for immersive cooking experience
local ActionMinigameMap = {
    -- Grill actions - timing-based (hit the sweet spot)
    cook_patty = { type = 'skillbar', sound = 'grill' },
    cook_patties = { type = 'skillbar', sound = 'grill' },
    grill = { type = 'skillbar', sound = 'grill' },
    cook_bacon = { type = 'skillbar', sound = 'grill' },
    cook_sausage = { type = 'skillbar', sound = 'grill' },

    -- Frying actions - precision timing (multiple zones)
    fry = { type = 'circle', sound = 'fry' },
    fry_chicken = { type = 'circle', sound = 'fry' },
    fry_fish = { type = 'circle', sound = 'fry' },
    fry_fries = { type = 'circle', sound = 'fry' },
    fry_onion_rings = { type = 'circle', sound = 'fry' },

    -- Prep actions - rapid key presses (chopping motion)
    prep = { type = 'rapid', sound = 'chop' },
    chop = { type = 'rapid', sound = 'chop' },
    prep_veggies = { type = 'rapid', sound = 'chop' },
    dice = { type = 'rapid', sound = 'chop' },
    slice = { type = 'rapid', sound = 'chop' },
    bread_chicken = { type = 'keys', sound = 'chop' },
    bread_fish = { type = 'keys', sound = 'chop' },

    -- Assembly actions - sequence memory (assembly order)
    assemble = { type = 'sequence', sound = 'plate' },
    build = { type = 'sequence', sound = 'plate' },
    stack = { type = 'sequence', sound = 'plate' },
    fold_and_seal = { type = 'keys', sound = 'plate' },

    -- Blending actions - hold steady (keep in zone)
    blend = { type = 'hold', sound = 'blend' },
    mix = { type = 'hold', sound = 'blend' },
    shake = { type = 'hold', sound = 'blend' },

    -- Coffee/Drink actions - precision pour
    brew_espresso = { type = 'skillbar', sound = 'steam' },
    brew_double = { type = 'skillbar', sound = 'steam' },
    steam_milk = { type = 'hold', sound = 'steam' },
    microfoam = { type = 'hold', sound = 'steam' },
    pour = { type = 'circle', sound = 'pour' },
    pour_art = { type = 'sequence', sound = 'pour' },
    layer = { type = 'sequence', sound = 'pour' },

    -- Baking actions - timing
    bake = { type = 'skillbar', sound = 'steam' },

    -- Plating/Finishing - precision
    plate = { type = 'keys', sound = 'plate' },
    finish = { type = 'keys', sound = 'plate' },
    garnish = { type = 'keys', sound = 'plate' },
    add_toppings = { type = 'keys', sound = 'plate' },
    stretch_dough = { type = 'hold', sound = 'chop' },
}

-- ============================================================================
-- SKILL CHECK SYSTEM
-- ============================================================================

--- Get difficulty based on recipe tier with player skill adjustment
---@param playerSkill number Player's skill level (0-100)
---@param recipeTier string Recipe tier ('basic', 'standard', 'advanced', 'signature')
---@param explicitDifficulty string|nil Explicit difficulty override
---@return string difficulty Adjusted difficulty
local function getAdjustedDifficulty(playerSkill, recipeTier, explicitDifficulty)
    -- Use explicit difficulty if provided
    local baseDifficulty = explicitDifficulty or TierDifficultyMap[recipeTier] or 'medium'

    if not Config.Cooking.SkillChecks.difficulty.skillScaling then
        return baseDifficulty
    end

    local scalingFactor = Config.Cooking.SkillChecks.difficulty.scalingFactor or 0.05
    local reduction = playerSkill * scalingFactor

    local difficulties = { 'easy', 'medium', 'hard', 'expert' }
    local difficultyIndex = {
        easy = 1,
        medium = 2,
        hard = 3,
        expert = 4,
    }

    local currentIndex = difficultyIndex[baseDifficulty] or 2
    -- Each 20 skill levels reduces difficulty by 1 tier
    local newIndex = math.max(1, currentIndex - math.floor(reduction / 0.20))

    local minDifficulty = Config.Cooking.SkillChecks.difficulty.minimumDifficulty or 'easy'
    local minIndex = difficultyIndex[minDifficulty] or 1
    newIndex = math.max(minIndex, newIndex)

    return difficulties[newIndex]
end

--- Get skill check parameters based on difficulty
---@param difficulty string 'easy', 'medium', 'hard', 'expert'
---@return table params Skill check parameters
local function getSkillCheckParams(difficulty)
    return DifficultyParams[difficulty] or DifficultyParams.medium
end

--- Scale difficulty for batch crafting
---@param baseParams table Base difficulty parameters
---@param batchSize number Number of items being crafted
---@return table scaledParams Scaled parameters
local function scaleDifficultyForBatch(baseParams, batchSize)
    if batchSize <= 1 then return baseParams end

    local scaled = {}
    for k, v in pairs(baseParams) do
        scaled[k] = v
    end

    -- Scale difficulty based on batch size (diminishing returns)
    local scaleFactor = 1 + (math.log(batchSize) * 0.15)

    -- Smaller target area
    scaled.areaSize = math.max(15, math.floor(baseParams.areaSize / scaleFactor))
    -- Faster speed
    scaled.speedMultiplier = baseParams.speedMultiplier * scaleFactor
    -- More keys/zones for larger batches
    scaled.keyCount = math.min(8, baseParams.keyCount + math.floor(batchSize / 3))
    scaled.zones = math.min(5, baseParams.zones + math.floor(batchSize / 4))
    -- Less time per action
    scaled.timePerKey = math.max(300, math.floor(baseParams.timePerKey / scaleFactor))

    return scaled
end

--- Execute a multi-zone skill check (for advanced/signature recipes)
---@param zones number Number of zones to complete
---@param params table Skill check parameters
---@param keys table Keys to use
---@return boolean success
---@return number quality Quality based on performance (0.0-1.0)
local function doMultiZoneSkillCheck(zones, params, keys)
    local successCount = 0
    local totalQuality = 0

    for i = 1, zones do
        -- Vary zone sizes for difficulty progression
        local zoneSize = params.areaSize - ((i - 1) * 3)
        zoneSize = math.max(15, zoneSize)

        local zoneParams = { zoneSize }

        -- Add speed multiplier for harder zones
        if i > 1 then
            zoneParams = { { areaSize = zoneSize, speedMultiplier = params.speedMultiplier + ((i - 1) * 0.1) } }
        end

        local success = lib.skillCheck(zoneParams, keys)

        if success then
            successCount = successCount + 1
            totalQuality = totalQuality + 1.0
        else
            totalQuality = totalQuality + 0.4
            if params.mistakesAllowed == 0 then
                -- Expert mode: any failure ends the check
                return false, totalQuality / zones
            end
        end

        -- Small delay between zones for rhythm
        if i < zones then
            Wait(200)
        end
    end

    local quality = totalQuality / zones
    local success = successCount >= (zones - (params.mistakesAllowed or 1))

    return success, quality
end

--- Execute a rapid key press skill check (for chopping/prep actions)
---@param params table Skill check parameters
---@return boolean success
---@return number quality Quality based on performance (0.0-1.0)
local function doRapidKeySkillCheck(params)
    local keys = { 'w', 'a', 's', 'd' }
    local keySequence = {}

    -- Generate random key sequence
    for i = 1, params.keyCount do
        keySequence[i] = keys[math.random(1, #keys)]
    end

    -- Build skill check with progressively smaller zones
    local zones = {}
    for i = 1, params.keyCount do
        local zoneSize = params.areaSize - ((i - 1) * 2)
        zones[i] = math.max(20, zoneSize)
    end

    local success = lib.skillCheck(zones, keySequence)
    local quality = success and 1.0 or 0.5

    return success, quality
end

--- Execute a sequence memory skill check (for assembly actions)
---@param params table Skill check parameters
---@return boolean success
---@return number quality Quality based on performance (0.0-1.0)
local function doSequenceSkillCheck(params)
    local keys = { 'w', 'a', 's', 'd' }
    local sequence = {}

    -- Generate a sequence the player must follow
    for i = 1, params.keyCount do
        sequence[i] = keys[math.random(1, #keys)]
    end

    -- Show the sequence to memorize briefly via notification
    lib.notify({
        title = 'Assembly Order',
        description = 'Follow: ' .. table.concat(sequence, ' → '),
        type = 'inform',
        duration = 2000 + (params.keyCount * 300),
    })

    Wait(2000 + (params.keyCount * 300))

    -- Now player must input the sequence
    local zones = {}
    for i = 1, params.keyCount do
        zones[i] = params.areaSize
    end

    local success = lib.skillCheck(zones, sequence)
    local quality = success and 1.0 or 0.5

    return success, quality
end

--- Execute a hold-steady skill check (for blending/steaming actions)
---@param params table Skill check parameters
---@return boolean success
---@return number quality Quality based on performance (0.0-1.0)
local function doHoldSkillCheck(params)
    -- Use circle style with two zones that require holding
    local primarySize = params.areaSize + 10
    local secondarySize = params.areaSize

    local success = lib.skillCheck(
        { primarySize, secondarySize },
        { 'e', 'e' }
    )

    local quality = success and 1.0 or 0.6
    return success, quality
end

--- Execute a skill check based on action type
---@param action string Action type (prep, cook, plate, etc.)
---@param difficulty string Difficulty level
---@param recipeSkillCheck table|nil Optional recipe-specific skill check config
---@param batchSize number|nil Batch size for scaling (default 1)
---@return boolean success
---@return number quality Quality multiplier (0.0-1.0)
local function doSkillCheck(action, difficulty, recipeSkillCheck, batchSize)
    local settings = Config.Cooking.SkillChecks
    batchSize = batchSize or 1

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

    -- Get parameters based on difficulty
    local useDifficulty = (recipeSkillCheck and recipeSkillCheck.difficulty) or difficulty
    local params = getSkillCheckParams(useDifficulty)

    -- Scale for batch crafting
    if batchSize > 1 then
        params = scaleDifficultyForBatch(params, batchSize)
    end

    -- Recipe can override individual parameters
    if recipeSkillCheck then
        if recipeSkillCheck.areaSize then params.areaSize = recipeSkillCheck.areaSize end
        if recipeSkillCheck.speedMultiplier then params.speedMultiplier = recipeSkillCheck.speedMultiplier end
        if recipeSkillCheck.zones then params.zones = recipeSkillCheck.zones end
        if recipeSkillCheck.keyCount then params.keyCount = recipeSkillCheck.keyCount end
    end

    -- Determine minigame type based on action or recipe override
    local actionConfig = ActionMinigameMap[action] or { type = 'skillbar', sound = nil }
    local minigameType = (recipeSkillCheck and recipeSkillCheck.type) or actionConfig.type or settings.style.type or 'skillbar'
    local keys = (recipeSkillCheck and recipeSkillCheck.keys) or settings.style.keys or { 'w', 'a', 's', 'd' }

    -- Play action-specific sound
    if actionConfig.sound then
        playCookingSound(actionConfig.sound, false)
    end

    local success, quality = false, 0.5

    if minigameType == 'skillbar' then
        -- Standard timing-based skill check
        if params.zones > 1 then
            success, quality = doMultiZoneSkillCheck(params.zones, params, keys)
        else
            success = lib.skillCheck(
                { params.areaSize },
                keys
            )
            quality = success and 1.0 or 0.5
        end

    elseif minigameType == 'circle' then
        -- Precision timing with multiple zones
        local secondSize = (recipeSkillCheck and recipeSkillCheck.areaSize2) or (params.areaSize - 10)
        secondSize = math.max(10, secondSize)

        if params.zones > 2 then
            -- Multiple precision zones
            local zones = {}
            for i = 1, params.zones do
                zones[i] = params.areaSize - ((i - 1) * 5)
            end
            success = lib.skillCheck(zones, { 'e' })
        else
            success = lib.skillCheck(
                { params.areaSize, secondSize },
                { 'e' }
            )
        end
        quality = success and 1.0 or 0.5

    elseif minigameType == 'keys' then
        -- Standard multi-key skill check
        success = lib.skillCheck(
            { params.areaSize },
            keys
        )
        quality = success and 1.0 or 0.5

    elseif minigameType == 'rapid' then
        -- Rapid key press sequence (chopping)
        success, quality = doRapidKeySkillCheck(params)

    elseif minigameType == 'sequence' then
        -- Memory sequence (assembly)
        success, quality = doSequenceSkillCheck(params)

    elseif minigameType == 'hold' then
        -- Hold steady (blending/steaming)
        success, quality = doHoldSkillCheck(params)
    end

    -- Play success/fail sound
    if success then
        playCookingSound('success', false)
    else
        playCookingSound('fail', false)
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
---@param batchSize number|nil Batch size for scaling (default 1)
---@return boolean success
---@return number quality Final quality multiplier
executeCraftingSteps = function(recipeData, stationData, batchSize)
    batchSize = batchSize or 1
    local steps = recipeData.steps or recipeData.stations or { { action = 'cook', label = 'Cooking...' } }
    local totalQuality = 0
    local stepCount = #steps
    local skillCheckResults = {}  -- Track results for quality feedback

    -- Get player skill level for this recipe type
    local playerSkill = lib.callback.await('free-restaurants:server:getSkillLevel', false, recipeData.category) or 0

    -- Get recipe tier for difficulty calculation
    local recipeTier = recipeData.tier or 'basic'

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

    -- Show tier-based difficulty notification
    local tierLabels = {
        basic = 'Basic',
        standard = 'Standard',
        advanced = 'Advanced',
        signature = 'Signature',
    }
    local tierColors = {
        basic = 'inform',
        standard = 'success',
        advanced = 'warning',
        signature = 'error',
    }

    if batchSize > 1 then
        lib.notify({
            title = ('Batch Crafting: %dx %s'):format(batchSize, recipeData.label),
            description = ('%s difficulty - Increased challenge for batch!'):format(tierLabels[recipeTier] or 'Standard'),
            type = tierColors[recipeTier] or 'inform',
            duration = 3000,
        })
    else
        lib.notify({
            title = ('Crafting: %s'):format(recipeData.label),
            description = ('%s difficulty recipe'):format(tierLabels[recipeTier] or 'Standard'),
            type = tierColors[recipeTier] or 'inform',
            duration = 2000,
        })
    end

    for i, step in ipairs(steps) do
        -- Show step progress with batch info
        local stepLabel = step.label or ('Step %d/%d'):format(i, stepCount)
        if batchSize > 1 then
            stepLabel = stepLabel .. (' (Batch: %dx)'):format(batchSize)
        end

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
            quality = math.floor((totalQuality / math.max(1, i - 1)) * 100),
        })

        -- Get action for sound and minigame type
        local action = step.action or step.step or step.type or 'cook'
        local actionConfig = ActionMinigameMap[action] or {}

        -- Check if this step requires a skill check
        local requiresSkillCheck = step.skillCheck ~= false

        if requiresSkillCheck then
            -- SKILL CHECK STEP: The skill check IS the cooking action
            -- Get difficulty based on tier with player skill adjustment
            local explicitDifficulty = nil
            if type(step.skillCheck) == 'table' and step.skillCheck.difficulty then
                explicitDifficulty = step.skillCheck.difficulty
            elseif recipeData.skillCheck and recipeData.skillCheck.difficulty then
                explicitDifficulty = recipeData.skillCheck.difficulty
            end

            local difficulty = getAdjustedDifficulty(playerSkill, recipeTier, explicitDifficulty)

            -- Build skill check config from recipe and step overrides
            local skillCheckConfig = nil
            if type(step.skillCheck) == 'table' then
                skillCheckConfig = step.skillCheck
            elseif recipeData.skillCheck then
                skillCheckConfig = recipeData.skillCheck
            end

            -- Start looping cooking sound
            if actionConfig.sound then
                playCookingSound(actionConfig.sound, true)
            end

            -- Show what we're doing with a brief prep progress
            local prepDuration = math.min(2000, (step.duration or 5000) * 0.3)
            local prepSuccess = lib.progressCircle({
                duration = prepDuration,
                label = 'Preparing: ' .. stepLabel,
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
            })

            if not prepSuccess then
                stopAllCookingSounds()
                return false, 0
            end

            -- Now the skill check IS the cooking action
            lib.notify({
                title = stepLabel,
                description = 'Complete the action!',
                type = 'inform',
                duration = 1500,
            })
            Wait(300)

            local checkSuccess, quality = doSkillCheck(action, difficulty, skillCheckConfig, batchSize)

            -- Stop looping sound
            if actionConfig.sound then
                stopCookingSound(actionConfig.sound)
            end

            -- Track result
            table.insert(skillCheckResults, {
                step = i,
                action = action,
                success = checkSuccess,
                quality = quality,
            })

            if not checkSuccess then
                -- Skill check failed
                local failOnMiss = (skillCheckConfig and skillCheckConfig.failOnMiss ~= nil)
                    and skillCheckConfig.failOnMiss
                    or Config.Cooking.SkillChecks.failOnMiss

                if failOnMiss then
                    lib.notify({
                        title = 'Failed!',
                        description = 'You messed up the ' .. (step.failText or action) .. '!',
                        type = 'error',
                    })
                    stopAllCookingSounds()
                    return false, 0
                else
                    -- Reduce quality but continue
                    lib.notify({
                        title = 'Imperfect',
                        description = 'Quality reduced - continue with care!',
                        type = 'warning',
                        duration = 2000,
                    })
                    quality = 0.5
                end
            else
                -- Success feedback
                lib.notify({
                    title = 'Perfect!',
                    description = 'Well done!',
                    type = 'success',
                    duration = 1500,
                })
            end

            -- Finish progress for this step (remaining time)
            local finishDuration = math.max(1000, (step.duration or 5000) * 0.4)
            if batchSize > 1 then
                finishDuration = finishDuration * (1 + 0.2 * math.log(batchSize))
            end

            local finishSuccess = lib.progressCircle({
                duration = finishDuration,
                label = 'Finishing: ' .. stepLabel,
                useWhileDead = false,
                canCancel = true,
                disable = {
                    move = not step.allowMove,
                    car = true,
                    combat = true,
                },
            })

            if not finishSuccess then
                stopAllCookingSounds()
                return false, 0
            end

            totalQuality = totalQuality + quality
        else
            -- NO SKILL CHECK: Just progress bar with cooking sounds
            local baseDuration = step.duration or (recipeData.craftTime or 5000) / stepCount
            local scaledDuration = baseDuration
            if batchSize > 1 then
                scaledDuration = baseDuration * (1 + 0.3 * math.log(batchSize))
            end

            -- Start looping cooking sound for this step
            if actionConfig.sound then
                playCookingSound(actionConfig.sound, true)
            end

            -- Play progress bar
            local progressSuccess = lib.progressCircle({
                duration = scaledDuration,
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

            -- Stop looping sound
            if actionConfig.sound then
                stopCookingSound(actionConfig.sound)
            end

            if not progressSuccess then
                stopAllCookingSounds()
                return false, 0
            end

            totalQuality = totalQuality + 1.0
        end
    end

    -- Stop any remaining sounds
    stopAllCookingSounds()

    -- Calculate average quality
    local avgQuality = totalQuality / stepCount

    -- Show final quality summary
    local qualityLabel, _ = FreeRestaurants.Utils.GetQualityLabel(avgQuality * 100)
    local successCount = 0
    for _, result in ipairs(skillCheckResults) do
        if result.success then successCount = successCount + 1 end
    end

    if #skillCheckResults > 0 then
        lib.notify({
            title = 'Cooking Complete',
            description = ('Quality: %s (%d/%d skill checks passed)'):format(
                qualityLabel,
                successCount,
                #skillCheckResults
            ),
            type = avgQuality >= 0.75 and 'success' or (avgQuality >= 0.5 and 'warning' or 'error'),
            duration = 3000,
        })
    end

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

    -- Stop all cooking sounds
    stopAllCookingSounds()

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
openBatchCraft = function(recipeId, recipeData, stationData)
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

--- Execute batch crafting with skill checks
---@param recipeId string
---@param recipeData table
---@param stationData table
---@param amount number
batchCraft = function(recipeId, recipeData, stationData, amount)
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

    FreeRestaurants.Utils.Debug(('Starting batch craft: %dx %s'):format(amount, recipeId))

    -- Use the full crafting steps with skill checks (scaled for batch size)
    local hasSteps = recipeData.steps or recipeData.stations
    local success, finalQuality

    if hasSteps and #hasSteps > 0 then
        -- Execute crafting steps with batch scaling
        success, finalQuality = executeCraftingSteps(recipeData, stationData, amount)
    else
        -- Fallback for recipes without defined steps - use simple progress with periodic skill checks
        local recipeTier = recipeData.tier or 'basic'
        local playerSkill = lib.callback.await('free-restaurants:server:getSkillLevel', false, recipeData.category) or 0
        local difficulty = getAdjustedDifficulty(playerSkill, recipeTier, nil)

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

        -- Calculate total time with diminishing returns: baseTime * amount * (1 + 0.15 * ln(amount))
        local baseTime = recipeData.craftTime or 5000
        local totalTime = baseTime * amount * (1 + 0.15 * math.log(amount))

        -- For batches, do periodic skill checks (one per ~3 items, minimum 1)
        local skillCheckCount = math.max(1, math.floor(amount / 3))
        local timePerCheck = totalTime / (skillCheckCount + 1)

        local totalQuality = 0
        local checksPassed = 0
        success = true

        lib.notify({
            title = ('Batch Crafting: %dx %s'):format(amount, recipeData.label),
            description = ('Difficulty scaled for batch - %d skill checks required'):format(skillCheckCount),
            type = 'warning',
            duration = 3000,
        })

        for i = 1, skillCheckCount do
            -- Progress phase
            local progressLabel = ('Batch %d/%d (Check %d coming up...)'):format(
                math.floor((i - 1) * amount / skillCheckCount) + 1,
                amount,
                i
            )

            local progressSuccess = lib.progressCircle({
                duration = timePerCheck,
                label = progressLabel,
                useWhileDead = false,
                canCancel = true,
                disable = {
                    move = true,
                    combat = true,
                },
            })

            if not progressSuccess then
                success = false
                break
            end

            -- Update cooking state
            local stepProgress = math.floor((i / (skillCheckCount + 1)) * 100)
            TriggerEvent('free-restaurants:client:cookingStateUpdate', {
                locationKey = stationData.locationKey,
                stationKey = stationData.stationKey,
                slotIndex = stationData.slotIndex,
                stationType = stationData.stationData and stationData.stationData.type or 'grill',
                slotCoords = stationData.slotCoords,
                status = 'cooking',
                progress = stepProgress,
                quality = math.floor((totalQuality / math.max(1, i - 1)) * 100),
            })

            -- Skill check phase
            lib.notify({
                title = ('Skill Check %d/%d'):format(i, skillCheckCount),
                description = 'Batch quality check!',
                type = 'inform',
                duration = 1500,
            })
            Wait(500)

            local checkSuccess, quality = doSkillCheck('cook', difficulty, nil, amount)

            if checkSuccess then
                checksPassed = checksPassed + 1
                totalQuality = totalQuality + 1.0
                lib.notify({
                    title = 'Check Passed!',
                    description = ('Quality maintained - %d/%d'):format(checksPassed, i),
                    type = 'success',
                    duration = 1500,
                })
            else
                totalQuality = totalQuality + 0.5
                lib.notify({
                    title = 'Check Failed',
                    description = 'Quality reduced for this batch!',
                    type = 'warning',
                    duration = 1500,
                })
            end
        end

        -- Final progress phase
        if success then
            local finalProgressSuccess = lib.progressCircle({
                duration = timePerCheck,
                label = ('Finishing batch of %d...'):format(amount),
                useWhileDead = false,
                canCancel = true,
                disable = {
                    move = true,
                    combat = true,
                },
            })

            if not finalProgressSuccess then
                success = false
            end
        end

        if success then
            finalQuality = totalQuality / skillCheckCount

            -- Notify stations.lua that cooking is complete
            TriggerEvent('free-restaurants:client:cookingStateUpdate', {
                locationKey = stationData.locationKey,
                stationKey = stationData.stationKey,
                slotIndex = stationData.slotIndex,
                stationType = stationData.stationData and stationData.stationData.type or 'grill',
                slotCoords = stationData.slotCoords,
                status = 'ready',
                progress = 100,
                quality = math.floor(finalQuality * 100),
            })

            local qualityLabel, _ = FreeRestaurants.Utils.GetQualityLabel(finalQuality * 100)
            lib.notify({
                title = 'Batch Complete!',
                description = ('Quality: %s (%d/%d checks passed)'):format(qualityLabel, checksPassed, skillCheckCount),
                type = finalQuality >= 0.75 and 'success' or 'warning',
                duration = 3000,
            })
        end
    end

    -- Save station data before clearing for the completion event
    local completionData = {
        locationKey = stationData.locationKey,
        stationKey = stationData.stationKey,
        slotIndex = stationData.slotIndex,
        status = success and 'completed' or 'cancelled',
    }

    if success then
        -- Complete batch on server (give items)
        local serverSuccess, message = lib.callback.await(
            'free-restaurants:server:completeBatchCraft',
            false,
            recipeId,
            amount,
            stationData.locationKey,
            avgFreshness,
            finalQuality  -- Pass quality to server
        )

        if serverSuccess then
            lib.notify({
                title = 'Items Ready',
                description = ('Crafted %dx %s'):format(amount, recipeData.label),
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

-- Batch craft request (old method)
RegisterNetEvent('free-restaurants:client:batchCraft', function(recipeId, recipeData, stationData)
    openBatchCraft(recipeId, recipeData, stationData)
end)

-- New slot-based batch crafting (from stations.lua)
RegisterNetEvent('free-restaurants:client:startBatchCrafting', function(recipeId, recipeData, stationData)
    if isCrafting then
        lib.notify({
            title = 'Busy',
            description = 'You are already crafting something!',
            type = 'error',
        })
        return
    end

    local amount = stationData.batchAmount or 1
    local claimedSlots = stationData.claimedSlots or {}

    -- Consume ingredients for batch FIRST
    local consumeSuccess, avgFreshness = lib.callback.await(
        'free-restaurants:server:consumeBatchIngredients',
        false,
        recipeId,
        amount
    )

    if not consumeSuccess then
        -- Release all claimed slots
        for _, slotIndex in ipairs(claimedSlots) do
            lib.callback.await('free-restaurants:server:releaseSlot', false, {
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

    -- Start batch crafting
    isCrafting = true
    currentCraft = {
        recipeId = recipeId,
        recipeData = recipeData,
        stationData = stationData,
        batchAmount = amount,
        claimedSlots = claimedSlots,
        avgFreshness = avgFreshness,
        ingredientsConsumed = true,
    }

    FreeRestaurants.Utils.Debug(('Starting slot-based batch craft: %dx %s across slots %s'):format(
        amount, recipeId, table.concat(claimedSlots, ', ')
    ))

    -- Execute crafting steps with batch size
    local success, finalQuality = executeCraftingSteps(recipeData, {
        locationKey = stationData.locationKey,
        stationKey = stationData.stationKey,
        slotIndex = stationData.primarySlot,
        stationData = stationData.stationData,
        slotCoords = stationData.slotCoords,
    }, amount)

    if success then
        -- Complete batch - give items and mark all slots as ready for pickup
        local serverSuccess, message = lib.callback.await(
            'free-restaurants:server:completeBatchCraftMultiSlot',
            false,
            recipeId,
            amount,
            stationData.locationKey,
            stationData.stationKey,
            claimedSlots,
            avgFreshness,
            finalQuality
        )

        if serverSuccess then
            lib.notify({
                title = 'Batch Complete!',
                description = ('Crafted %dx %s - ready for pickup at station'):format(amount, recipeData.label),
                type = 'success',
            })

            -- Update all slot props to cooked state
            local fullStationKey = ('%s_%s'):format(stationData.locationKey, stationData.stationKey)
            for _, slotIndex in ipairs(claimedSlots) do
                TriggerEvent('free-restaurants:client:cookingStateUpdate', {
                    locationKey = stationData.locationKey,
                    stationKey = stationData.stationKey,
                    slotIndex = slotIndex,
                    stationType = stationData.stationData and stationData.stationData.type or 'grill',
                    status = 'ready',
                    progress = 100,
                    quality = math.floor((finalQuality or 1.0) * 100),
                })
            end
        else
            lib.notify({
                title = 'Batch Failed',
                description = message or 'Something went wrong!',
                type = 'error',
            })
        end
    else
        -- Cancelled - return ingredients and release slots
        lib.callback.await(
            'free-restaurants:server:returnBatchIngredients',
            false,
            recipeId,
            amount
        )

        for _, slotIndex in ipairs(claimedSlots) do
            lib.callback.await('free-restaurants:server:releaseSlot', false, {
                locationKey = stationData.locationKey,
                stationKey = stationData.stationKey,
                slotIndex = slotIndex,
                status = 'cancelled',
            })
        end

        lib.notify({
            title = 'Cancelled',
            description = 'Batch crafting cancelled. Ingredients returned.',
            type = 'inform',
        })
    end

    isCrafting = false
    currentCraft = nil
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
