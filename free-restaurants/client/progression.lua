--[[
    free-restaurants Client Progression System
    
    Handles:
    - XP gain notifications
    - Level up celebrations
    - Progression UI display
    - Recipe unlock notifications
    
    DEPENDENCIES:
    - client/main.lua
    - ox_lib
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local currentLevel = 1
local currentXp = 0
local currentLevelXp = 0
local nextLevelXp = 100

-- ============================================================================
-- XP NOTIFICATIONS
-- ============================================================================

--- Show XP gain notification
---@param data table { amount, reason, totalXp, level, currentLevelXp, nextLevelXp }
local function showXpGain(data)
    -- Update local state
    currentXp = data.totalXp
    currentLevel = data.level
    currentLevelXp = data.currentLevelXp
    nextLevelXp = data.nextLevelXp
    
    -- Show notification
    lib.notify({
        title = '+' .. data.amount .. ' XP',
        description = data.reason or 'Experience gained',
        type = 'inform',
        icon = 'star',
        iconColor = '#FFD700',
        duration = 3000,
    })
end

--- Show level up notification
---@param data table { oldLevel, newLevel, bonuses }
local function showLevelUp(data)
    currentLevel = data.newLevel
    
    -- Play celebration sound
    PlaySoundFrontend(-1, 'MEDAL_UP', 'HUD_AWARDS', true)
    
    -- Show big notification
    lib.notify({
        title = '🎉 LEVEL UP!',
        description = ('You reached Cooking Level %d!'):format(data.newLevel),
        type = 'success',
        duration = 8000,
        icon = 'award',
    })
    
    -- Show bonuses if available
    if data.bonuses then
        Wait(1000)
        local bonusText = {}
        if data.bonuses.qualityBonus then
            table.insert(bonusText, ('+%.0f%% Quality'):format(data.bonuses.qualityBonus * 100))
        end
        if data.bonuses.speedBonus then
            table.insert(bonusText, ('+%.0f%% Speed'):format(data.bonuses.speedBonus * 100))
        end
        
        if #bonusText > 0 then
            lib.notify({
                title = 'New Bonuses',
                description = table.concat(bonusText, ', '),
                type = 'inform',
                icon = 'arrow-up',
                duration = 5000,
            })
        end
    end
    
    -- Screen effect
    AnimpostfxPlay('SuccessMichael', 1000, false)
end

--- Show recipe unlock notification
---@param recipes table Array of { id, label }
local function showRecipeUnlock(recipes)
    if not recipes or #recipes == 0 then return end
    
    for _, recipe in ipairs(recipes) do
        Wait(500)
        lib.notify({
            title = '🍳 New Recipe Unlocked!',
            description = recipe.label,
            type = 'success',
            icon = 'book-open',
            duration = 5000,
        })
    end
end

-- ============================================================================
-- PROGRESSION UI HELPERS (must be defined before showProgressionMenu)
-- ============================================================================

--- Build ASCII progress bar
---@param progress number 0-100
---@return string
local function buildProgressBar(progress)
    local filled = math.floor(progress / 10)
    local empty = 10 - filled
    return string.rep('█', filled) .. string.rep('░', empty)
end

--- Show skills submenu
---@param skills table
local function showSkillsMenu(skills)
    local options = {}

    local skillLabels = {
        general = 'General Cooking',
        grill = 'Grilling',
        fry = 'Frying',
        bake = 'Baking',
        prep = 'Food Prep',
        plate = 'Plating',
        blend = 'Blending',
        coffee = 'Coffee Making',
        cocktails = 'Mixology',
        delivery = 'Delivery',
    }

    for category, skillData in pairs(skills) do
        local label = skillLabels[category] or category:gsub('^%l', string.upper)

        table.insert(options, {
            title = label,
            description = ('Level %d (%d points)'):format(skillData.level, skillData.points),
            icon = 'utensils',
            progress = math.min(100, (skillData.points % 10) * 10),
        })
    end

    -- Sort alphabetically
    table.sort(options, function(a, b) return a.title < b.title end)

    lib.registerContext({
        id = 'skills_menu',
        title = 'Cooking Skills',
        menu = 'progression_menu',
        options = options,
    })

    lib.showContext('skills_menu')
end

--- Show leaderboard
local function showLeaderboard()
    local leaderboard = lib.callback.await('free-restaurants:server:getLeaderboard', false, 10)

    if not leaderboard or #leaderboard == 0 then
        lib.notify({
            title = 'Leaderboard',
            description = 'No data available',
            type = 'inform',
        })
        return
    end

    local options = {}

    for _, entry in ipairs(leaderboard) do
        local medal = ''
        if entry.rank == 1 then medal = '🥇 '
        elseif entry.rank == 2 then medal = '🥈 '
        elseif entry.rank == 3 then medal = '🥉 '
        end

        table.insert(options, {
            title = ('%s#%d %s'):format(medal, entry.rank, entry.name),
            description = ('Level %d - %d crafts'):format(entry.level, entry.crafts),
            icon = 'user',
            metadata = {
                { label = 'Total XP', value = tostring(entry.xp) },
            },
        })
    end

    lib.registerContext({
        id = 'leaderboard_menu',
        title = 'Top Chefs',
        menu = 'progression_menu',
        options = options,
    })

    lib.showContext('leaderboard_menu')
end

-- ============================================================================
-- PROGRESSION UI
-- ============================================================================

--- Show progression menu
local function showProgressionMenu()
    -- Get progression data from server
    local data = lib.callback.await('free-restaurants:server:getProgression', false)
    
    if not data then
        lib.notify({
            title = 'Error',
            description = 'Could not load progression data',
            type = 'error',
        })
        return
    end
    
    -- Update local state
    currentLevel = data.level
    currentXp = data.totalXp
    currentLevelXp = data.currentLevelXp
    nextLevelXp = data.nextLevelXp
    
    local options = {}
    
    -- Level info header
    local progressBar = buildProgressBar(data.progress)
    
    table.insert(options, {
        title = ('⭐ Level %d Chef'):format(data.level),
        description = ('XP: %d/%d (%d%%)'):format(data.currentLevelXp, data.nextLevelXp, math.floor(data.progress)),
        icon = 'award',
        disabled = true,
    })
    
    -- Stats
    table.insert(options, {
        title = 'Statistics',
        icon = 'chart-bar',
        metadata = {
            { label = 'Total XP', value = tostring(data.totalXp) },
            { label = 'Items Crafted', value = tostring(data.totalCrafts) },
            { label = 'Orders Completed', value = tostring(data.totalOrders) },
            { label = 'Total Tips', value = FreeRestaurants.Utils.FormatMoney(data.totalTips) },
        },
    })
    
    -- Current bonuses
    if data.bonuses then
        table.insert(options, {
            title = 'Active Bonuses',
            icon = 'arrow-trend-up',
            metadata = {
                { label = 'Quality Bonus', value = ('+%.0f%%'):format(data.bonuses.qualityBonus * 100) },
                { label = 'Speed Bonus', value = ('+%.0f%%'):format(data.bonuses.speedBonus * 100) },
                { label = 'XP Bonus', value = ('+%.0f%%'):format(data.bonuses.xpBonus * 100) },
            },
        })
    end
    
    -- Skills
    if data.skills and next(data.skills) then
        table.insert(options, {
            title = 'Cooking Skills',
            description = 'View your skill levels',
            icon = 'hand-fist',
            onSelect = function()
                showSkillsMenu(data.skills)
            end,
        })
    end
    
    -- Unlocked recipes count
    local unlockedCount = data.unlockedRecipes and #data.unlockedRecipes or 0
    table.insert(options, {
        title = ('Recipes Unlocked: %d'):format(unlockedCount),
        icon = 'book',
        disabled = true,
    })
    
    -- Leaderboard
    table.insert(options, {
        title = 'View Leaderboard',
        description = 'Top chefs in the city',
        icon = 'trophy',
        onSelect = function()
            showLeaderboard()
        end,
    })
    
    lib.registerContext({
        id = 'progression_menu',
        title = 'Cooking Progression',
        options = options,
    })
    
    lib.showContext('progression_menu')
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- XP gained event
RegisterNetEvent('free-restaurants:client:xpGained', function(data)
    showXpGain(data)
end)

-- Level up event
RegisterNetEvent('free-restaurants:client:levelUp', function(data)
    showLevelUp(data)
end)

-- Recipe unlocked event
RegisterNetEvent('free-restaurants:client:recipesUnlocked', function(recipes)
    showRecipeUnlock(recipes)
end)

-- Command to open progression menu
RegisterCommand('cookingprogression', function()
    showProgressionMenu()
end, false)

RegisterCommand('chefstats', function()
    showProgressionMenu()
end, false)

-- Keybind (optional)
-- lib.addKeybind({
--     name = 'cooking_progression',
--     description = 'View Cooking Progression',
--     defaultKey = 'F9',
--     onPressed = function()
--         showProgressionMenu()
--     end,
-- })

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Load progression on resource start
CreateThread(function()
    Wait(2000)
    
    local data = lib.callback.await('free-restaurants:server:getProgression', false)
    if data then
        currentLevel = data.level
        currentXp = data.totalXp
        currentLevelXp = data.currentLevelXp
        nextLevelXp = data.nextLevelXp
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetCurrentLevel', function() return currentLevel end)
exports('GetCurrentXP', function() return currentXp end)
exports('ShowProgressionMenu', showProgressionMenu)

-- Add to global table
FreeRestaurants.Progression = {
    GetLevel = function() return currentLevel end,
    GetXP = function() return currentXp end,
    ShowMenu = showProgressionMenu,
}

FreeRestaurants.Utils.Debug('client/progression.lua loaded')
