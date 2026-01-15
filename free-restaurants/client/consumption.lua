--[[
    free-restaurants Consumption System

    Handles item consumption with:
    - Multi-use items (multiple bites/sips)
    - Key press to continue eating/drinking
    - Quality-based effect scaling
    - Animations and props
    - Temporary buffs/debuffs

    DEPENDENCIES:
    - config/item_effects.lua
    - ox_inventory
    - qbx_core (for status effects)
]]

print('[free-restaurants] client/consumption.lua loading...')

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local isConsuming = false
local currentConsumption = nil
local consumptionProp = nil
local activeTemporaryEffects = {}

-- ============================================================================
-- ANIMATION HELPERS
-- ============================================================================

--- Load animation dictionary
---@param dict string
local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local timeout = 5000
    local startTime = GetGameTimer()

    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() - startTime > timeout then
            return false
        end
    end

    return true
end

--- Play consumption animation
---@param animConfig table
---@return boolean
local function playConsumptionAnim(animConfig)
    if not animConfig then return false end

    if not loadAnimDict(animConfig.dict) then
        return false
    end

    local ped = PlayerPedId()
    TaskPlayAnim(ped, animConfig.dict, animConfig.anim, 8.0, -8.0, -1, animConfig.flag or 49, 0, false, false, false)

    return true
end

--- Stop consumption animation
local function stopConsumptionAnim()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
end

-- ============================================================================
-- PROP HELPERS
-- ============================================================================

--- Attach consumption prop
---@param propName string
---@return number|nil entity
local function attachConsumptionProp(propName)
    if not propName then return nil end

    local propModel = Config.ItemEffects.Props[propName]
    if not propModel then return nil end

    local hash = joaat(propModel)
    lib.requestModel(hash, 5000)

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local prop = CreateObject(hash, coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 18905), 0.12, 0.028, 0.001, 10.0, 175.0, 0.0, true, true, false, true, 1, true)

    return prop
end

--- Delete consumption prop
---@param prop number
local function deleteConsumptionProp(prop)
    if prop and DoesEntityExist(prop) then
        DeleteEntity(prop)
    end
end

-- ============================================================================
-- EFFECT APPLICATION
-- ============================================================================

--- Apply immediate effects (hunger, thirst, stress, health, armor)
---@param effects table
---@param quality number
---@param useNumber number Current use number
---@param totalUses number Total uses
local function applyImmediateEffects(effects, quality, useNumber, totalUses)
    local player = exports.qbx_core:GetPlayerData()
    if not player then return end

    -- Calculate effects scaled by quality
    if effects.hunger then
        local hungerGain = Config.ItemEffects.ScaleEffect(effects.hunger, quality)
        if hungerGain ~= 0 then
            TriggerServerEvent('hud:server:SetNeed', 'hunger', math.min(100, player.metadata.hunger + hungerGain))
        end
    end

    if effects.thirst then
        local thirstGain = Config.ItemEffects.ScaleEffect(effects.thirst, quality)
        if thirstGain ~= 0 then
            TriggerServerEvent('hud:server:SetNeed', 'thirst', math.min(100, player.metadata.thirst + thirstGain))
        end
    end

    if effects.stress then
        local stressChange = Config.ItemEffects.ScaleEffect(effects.stress, quality)
        if stressChange ~= 0 then
            local newStress = math.max(0, math.min(100, (player.metadata.stress or 0) + stressChange))
            TriggerServerEvent('hud:server:SetNeed', 'stress', newStress)
        end
    end

    if effects.health then
        local healthChange = Config.ItemEffects.ScaleEffect(effects.health, quality)
        if healthChange ~= 0 then
            local ped = PlayerPedId()
            local currentHealth = GetEntityHealth(ped)
            local maxHealth = GetEntityMaxHealth(ped)
            SetEntityHealth(ped, math.max(0, math.min(maxHealth, currentHealth + math.floor(healthChange))))
        end
    end

    if effects.armor then
        local armorChange = Config.ItemEffects.ScaleEffect(effects.armor, quality)
        if armorChange ~= 0 then
            local ped = PlayerPedId()
            local currentArmor = GetPedArmour(ped)
            SetPedArmour(ped, math.max(0, math.min(100, currentArmor + math.floor(armorChange))))
        end
    end
end

--- Apply temporary effects (speed, strength)
---@param tempEffects table
---@param quality number
local function applyTemporaryEffects(tempEffects, quality)
    if not tempEffects then return end

    local effectKey = GetGameTimer()

    if tempEffects.speed then
        local speedMod = Config.ItemEffects.ScaleEffect(tempEffects.speed, quality)
        -- Store the effect
        activeTemporaryEffects[effectKey .. '_speed'] = {
            type = 'speed',
            modifier = speedMod,
            endTime = GetGameTimer() + (tempEffects.duration or 60000),
        }
    end

    if tempEffects.strength then
        local strengthMod = Config.ItemEffects.ScaleEffect(tempEffects.strength, quality)
        activeTemporaryEffects[effectKey .. '_strength'] = {
            type = 'strength',
            modifier = strengthMod,
            endTime = GetGameTimer() + (tempEffects.duration or 60000),
        }
    end

    -- Apply movement speed modifier
    if tempEffects.speed then
        local speedMod = Config.ItemEffects.ScaleEffect(tempEffects.speed, quality) / 100
        SetPedMoveRateOverride(PlayerPedId(), speedMod)

        -- Schedule removal
        SetTimeout(tempEffects.duration or 60000, function()
            SetPedMoveRateOverride(PlayerPedId(), 1.0)
        end)
    end
end

-- ============================================================================
-- CONSUMPTION FLOW
-- ============================================================================

--- Start consuming an item
---@param itemName string
---@param itemData table Item data from inventory
---@return boolean
local function startConsumption(itemName, itemData)
    if isConsuming then
        lib.notify({
            title = 'Busy',
            description = 'You are already eating or drinking something.',
            type = 'error',
        })
        return false
    end

    local itemConfig = Config.ItemEffects.GetItem(itemName)
    if not itemConfig then
        -- Fallback to default consumption
        itemConfig = {
            label = itemData.label or itemName,
            type = 'food',
            uses = Config.ItemEffects.Defaults.uses,
            useTime = Config.ItemEffects.Defaults.useTime,
            animation = Config.ItemEffects.Defaults.animation,
            effects = {
                hunger = Config.ItemEffects.Defaults.hunger,
                thirst = Config.ItemEffects.Defaults.thirst,
            },
        }
    end

    -- Get quality from item metadata
    local quality = itemData.metadata and itemData.metadata.quality or 75
    local durability = itemData.metadata and itemData.metadata.durability or 100

    -- Check if item is depleted (already consumed all uses)
    if itemData.metadata and itemData.metadata.depleted then
        lib.notify({
            title = 'Empty',
            description = 'This item is empty. Dispose of it at a trash bin.',
            type = 'warning',
        })
        return false
    end

    -- Get remaining uses from metadata (for partially consumed items)
    local remainingUses = itemData.metadata and itemData.metadata.usesRemaining
    local totalUses = itemConfig.uses or 1
    if not remainingUses then
        remainingUses = totalUses
    end

    -- Check if item has any uses left
    if remainingUses <= 0 then
        lib.notify({
            title = 'Empty',
            description = 'This item has no uses remaining. Dispose of it.',
            type = 'warning',
        })
        return false
    end

    -- Check if item is ruined
    if quality <= 0 or durability <= 0 then
        local confirm = lib.alertDialog({
            header = 'Ruined Item',
            content = 'This item is ruined and may make you sick. Consume anyway?',
            centered = true,
            cancel = true,
        })

        if confirm ~= 'confirm' then
            return false
        end
    end

    -- Check if item is spoiled
    if itemData.metadata and itemData.metadata.spoiled then
        local confirm = lib.alertDialog({
            header = 'Spoiled Food',
            content = 'This food has spoiled and may make you sick. Consume anyway?',
            centered = true,
            cancel = true,
        })

        if confirm ~= 'confirm' then
            return false
        end
    end

    isConsuming = true
    currentConsumption = {
        itemName = itemName,
        itemData = itemData,
        itemConfig = itemConfig,
        quality = quality,
        currentUse = 0,
        totalUses = totalUses,
        remainingUses = remainingUses,
        slot = itemData.slot,
    }

    -- Get animation config
    local animConfig = Config.ItemEffects.Animations[itemConfig.animation or 'eat']

    -- Attach prop if configured
    if itemConfig.prop then
        consumptionProp = attachConsumptionProp(itemConfig.prop)
    end

    -- Start first use
    consumeUse()

    return true
end

--- Consume one use of the item
function consumeUse()
    if not currentConsumption then return end

    local config = currentConsumption.itemConfig
    local quality = currentConsumption.quality

    currentConsumption.currentUse = currentConsumption.currentUse + 1

    -- Play animation
    local animConfig = Config.ItemEffects.Animations[config.animation or 'eat']
    playConsumptionAnim(animConfig)

    -- Show progress bar
    local useLabel = config.type == 'drink' and 'Drinking' or 'Eating'
    local progressSuccess = lib.progressBar({
        duration = config.useTime or 3000,
        label = ('%s %s (%d/%d)'):format(useLabel, config.label, currentConsumption.currentUse, currentConsumption.totalUses),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = false,
            car = true,
            combat = true,
        },
    })

    if not progressSuccess then
        -- Cancelled
        finishConsumption(false)
        return
    end

    -- Apply effects for this use
    if config.effects then
        applyImmediateEffects(config.effects, quality, currentConsumption.currentUse, currentConsumption.totalUses)
    end

    -- Check if more uses remain (use remainingUses for partially consumed items)
    local usesLeft = currentConsumption.remainingUses - currentConsumption.currentUse
    if usesLeft > 0 then
        -- Prompt to continue
        promptContinueConsumption()
    else
        -- Finished all uses
        finishConsumption(true)
    end
end

--- Prompt player to continue eating/drinking
function promptContinueConsumption()
    if not currentConsumption then return end

    local config = currentConsumption.itemConfig
    local usesLeft = currentConsumption.remainingUses - currentConsumption.currentUse

    -- Show prompt
    lib.showTextUI(('[E] Continue %s (%d more)  [X] Stop'):format(
        config.type == 'drink' and 'drinking' or 'eating',
        usesLeft
    ), {
        position = 'bottom-center',
        icon = config.type == 'drink' and 'fa-solid fa-glass-water' or 'fa-solid fa-utensils',
    })

    -- Wait for input
    local promptTimeout = 10000 -- 10 seconds to decide
    local startTime = GetGameTimer()

    CreateThread(function()
        while isConsuming and currentConsumption do
            Wait(0)

            -- Check for timeout
            if GetGameTimer() - startTime > promptTimeout then
                lib.hideTextUI()
                finishConsumption(true, true) -- Partial completion
                return
            end

            -- Check for E key (continue)
            if IsControlJustPressed(0, 38) then -- E key
                lib.hideTextUI()
                consumeUse()
                return
            end

            -- Check for X key (stop)
            if IsControlJustPressed(0, 73) then -- X key
                lib.hideTextUI()
                finishConsumption(true, true) -- Partial completion
                return
            end

            -- Check for movement that might cancel
            if IsControlPressed(0, 21) then -- Sprint
                -- Allow moving while deciding
            end
        end
    end)
end

--- Finish consumption
---@param success boolean Whether consumption was successful
---@param partial boolean Whether only some uses were consumed
function finishConsumption(success, partial)
    if not currentConsumption then return end

    local config = currentConsumption.itemConfig
    local quality = currentConsumption.quality
    local usesConsumed = currentConsumption.currentUse
    local usesLeft = currentConsumption.remainingUses - usesConsumed

    -- Stop animation
    stopConsumptionAnim()

    -- Delete prop
    if consumptionProp then
        deleteConsumptionProp(consumptionProp)
        consumptionProp = nil
    end

    if success and usesConsumed > 0 then
        -- Apply temporary effects (only on full completion of item)
        if config.temporary and usesLeft <= 0 then
            applyTemporaryEffects(config.temporary, quality)
        end

        -- Update item metadata (item stays in inventory)
        TriggerServerEvent('free-restaurants:server:consumeItem', {
            itemName = currentConsumption.itemName,
            slot = currentConsumption.slot,
            usesConsumed = usesConsumed,
            totalUses = currentConsumption.totalUses,
            partial = partial or usesLeft > 0,
        })

        -- Show completion notification
        local qualityLabel = Config.ItemEffects.GetQualityLabel(quality)
        if usesLeft > 0 then
            lib.notify({
                title = 'Partially Consumed',
                description = ('Consumed %d uses of %s (%d remaining)'):format(
                    usesConsumed, config.label, usesLeft
                ),
                type = 'inform',
            })
        else
            lib.notify({
                title = config.type == 'drink' and 'Drink Finished' or 'Meal Finished',
                description = ('Finished %s (%s quality) - dispose of container'):format(config.label, qualityLabel),
                type = 'success',
            })
        end
    else
        lib.notify({
            title = 'Cancelled',
            description = 'Stopped ' .. (config.type == 'drink' and 'drinking' or 'eating'),
            type = 'inform',
        })
    end

    -- Clear state
    isConsuming = false
    currentConsumption = nil
end

-- ============================================================================
-- INVENTORY INTEGRATION
-- ============================================================================

--- Register useable items with ox_inventory
local function registerUseableItems()
    -- Register all items in the effects config as useable
    for itemName, itemConfig in pairs(Config.ItemEffects.Items) do
        exports.ox_inventory:AddItemHook(itemName, function(data)
            startConsumption(itemName, data.item)
            return false -- Don't remove item yet (we handle it in finishConsumption)
        end, 'usingItem')
    end
end

-- ============================================================================
-- SERVER EVENT HANDLER
-- ============================================================================

-- Server will handle actual item removal
RegisterNetEvent('free-restaurants:client:consumptionComplete', function(data)
    if data.success then
        -- Item was successfully consumed/removed
    else
        lib.notify({
            title = 'Error',
            description = data.error or 'Failed to consume item',
            type = 'error',
        })
    end
end)

-- ============================================================================
-- DISPOSAL SYSTEM
-- ============================================================================

--- Dispose of an item (for empty containers, spoiled food, etc.)
---@param slot number Inventory slot
---@param force boolean Force disposal even if item has uses
local function disposeItem(slot, force)
    TriggerServerEvent('free-restaurants:server:disposeItem', {
        slot = slot,
        force = force or false,
    })
end

--- Check if item can be disposed
---@param itemData table Item data from inventory
---@return boolean canDispose
---@return string reason
local function canDisposeItem(itemData)
    if not itemData or not itemData.metadata then
        return false, 'Invalid item'
    end

    if itemData.metadata.depleted then
        return true, 'Empty container'
    end

    if itemData.metadata.ruined then
        return true, 'Ruined item'
    end

    if itemData.metadata.spoiled then
        return true, 'Spoiled food'
    end

    if itemData.metadata.usesRemaining and itemData.metadata.usesRemaining <= 0 then
        return true, 'Empty item'
    end

    return false, 'Item still has uses'
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('StartConsumption', startConsumption)
exports('IsConsuming', function() return isConsuming end)
exports('GetCurrentConsumption', function() return currentConsumption end)
exports('CancelConsumption', function()
    if isConsuming then
        finishConsumption(false)
        return true
    end
    return false
end)
exports('DisposeItem', disposeItem)
exports('CanDisposeItem', canDisposeItem)

-- ============================================================================
-- GLOBAL TABLE
-- ============================================================================

FreeRestaurants.Consumption = {
    Start = startConsumption,
    IsConsuming = function() return isConsuming end,
    Cancel = function()
        if isConsuming then
            finishConsumption(false)
            return true
        end
        return false
    end,
    Dispose = disposeItem,
    CanDispose = canDisposeItem,
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    Wait(1000) -- Wait for other scripts to load

    -- Note: Item registration should be done via ox_inventory's items.lua
    -- This file handles the consumption logic when items are used

    print('[free-restaurants] client/consumption.lua loaded - item consumption system ready')
end)

print('[free-restaurants] client/consumption.lua loaded')
