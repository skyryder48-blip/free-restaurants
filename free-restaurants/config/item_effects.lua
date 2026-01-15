--[[
    free-restaurants Item Effects Configuration

    Defines consumption effects for all food and drink items.
    Effects scale based on item quality (0-100).

    EFFECT TYPES:
        - hunger: Increases hunger satisfaction (positive values)
        - thirst: Increases thirst satisfaction (positive values)
        - stress: Modifies stress level (negative = reduce stress, positive = add stress)
        - health: Modifies health (positive = heal, negative = damage)
        - armor: Adds/removes armor points
        - speed: Temporary speed modifier (percentage, 100 = normal)
        - strength: Temporary strength modifier (percentage, 100 = normal)

    CONSUMPTION SETTINGS:
        - uses: Number of uses before item is consumed (1 = single use)
        - useTime: Time per use in milliseconds
        - animation: Animation to play during consumption
        - prop: Prop to attach during consumption (optional)

    QUALITY SCALING:
        - minEffect: Effect at 0% quality (ruined/burnt items)
        - maxEffect: Effect at 100% quality (perfect items)
        - Actual effect = minEffect + (maxEffect - minEffect) * (quality / 100)

    SPECIAL EFFECTS:
        - duration: How long temporary effects last (speed, strength, etc.)
        - afterEffect: Effects applied after consumption completes
]]

Config = Config or {}
Config.ItemEffects = Config.ItemEffects or {}

-- ============================================================================
-- CONSUMPTION ANIMATIONS
-- ============================================================================

Config.ItemEffects.Animations = {
    eat = {
        dict = 'mp_player_inteat@burger',
        anim = 'mp_player_int_eat_burger',
        flag = 49,
    },
    eat_fast = {
        dict = 'mp_player_inteat@burger',
        anim = 'mp_player_int_eat_burger_fp',
        flag = 49,
    },
    drink = {
        dict = 'mp_player_intdrink',
        anim = 'intro_bottle',
        flag = 49,
    },
    drink_coffee = {
        dict = 'amb@world_human_drinking@coffee@male@idle_a',
        anim = 'idle_c',
        flag = 49,
    },
    drink_alcohol = {
        dict = 'amb@world_human_drinking@beer@male@idle_a',
        anim = 'idle_c',
        flag = 49,
    },
    smoke = {
        dict = 'amb@world_human_smoking@male@male_a@enter',
        anim = 'enter',
        flag = 49,
    },
}

-- ============================================================================
-- CONSUMPTION PROPS
-- ============================================================================

Config.ItemEffects.Props = {
    burger = 'prop_cs_burger_01',
    sandwich = 'prop_sandwich_01',
    donut = 'prop_donut_01',
    pizza_slice = 'prop_pizza_slice',
    taco = 'prop_taco_01',
    hotdog = 'prop_cs_hotdog_01',
    soda_cup = 'prop_food_cups1',
    coffee_cup = 'p_amb_coffeecup_01',
    beer_bottle = 'prop_amb_beer_bottle',
    wine_glass = 'prop_wine_glass',
    cocktail_glass = 'prop_cocktail',
    water_bottle = 'prop_ld_flow_bottle',
    energy_drink = 'prop_energy_drink',
    ice_cream = 'prop_cs_icecream_01',
    fries = 'prop_food_bs_chips',
    chicken_leg = 'prop_cs_chicken_leg',
}

-- ============================================================================
-- DEFAULT VALUES
-- ============================================================================

Config.ItemEffects.Defaults = {
    -- Default consumption settings
    uses = 3,                       -- 3 bites/sips per item
    useTime = 3000,                 -- 3 seconds per use
    animation = 'eat',              -- Default animation

    -- Default effect scaling (per use)
    hunger = { min = 5, max = 15 },
    thirst = { min = 3, max = 10 },

    -- Quality thresholds
    qualityThresholds = {
        ruined = 0,         -- 0% quality - item is ruined
        poor = 25,          -- Below 25% - poor quality
        average = 50,       -- 50% - average
        good = 75,          -- 75% - good quality
        excellent = 90,     -- 90%+ - excellent quality
    },
}

-- ============================================================================
-- FOOD ITEMS - BURGERS
-- ============================================================================

Config.ItemEffects.Items = {
    -- ========================================================================
    -- BURGER SHOT - BURGERS
    -- ========================================================================

    ['bleeder_burger'] = {
        label = 'The Bleeder',
        type = 'food',
        uses = 4,
        useTime = 3500,
        animation = 'eat',
        prop = 'burger',

        -- Effects per use (scales with quality)
        effects = {
            hunger = { min = 5, max = 12 },     -- 5-12 hunger per bite
            thirst = { min = -2, max = -1 },    -- Slightly reduces thirst (greasy)
        },

        -- Total effects at full quality: 48 hunger, -4 thirst
    },

    ['bleeder_burger_premium'] = {
        label = 'The Bleeder (Premium)',
        type = 'food',
        uses = 4,
        useTime = 3500,
        animation = 'eat',
        prop = 'burger',

        effects = {
            hunger = { min = 8, max = 18 },
            thirst = { min = -1, max = 0 },
            stress = { min = 0, max = -3 },     -- Good food reduces stress
        },
    },

    ['double_barreled_burger'] = {
        label = 'Double Barreled',
        type = 'food',
        uses = 6,
        useTime = 4000,
        animation = 'eat',
        prop = 'burger',

        effects = {
            hunger = { min = 6, max = 14 },
            thirst = { min = -3, max = -1 },
            stress = { min = 0, max = -2 },
        },
    },

    ['heart_stopper_burger'] = {
        label = 'Heart Stopper',
        type = 'food',
        uses = 8,
        useTime = 4500,
        animation = 'eat',
        prop = 'burger',

        effects = {
            hunger = { min = 8, max = 16 },
            thirst = { min = -4, max = -2 },
            stress = { min = -5, max = -10 },   -- Very satisfying
            health = { min = -2, max = 0 },     -- Unhealthy at low quality
        },

        -- Temporary effects
        temporary = {
            speed = { min = 90, max = 95 },     -- Slightly slower (food coma)
            duration = 60000,                    -- 1 minute
        },
    },

    ['murder_burger'] = {
        label = 'The Murder Burger',
        type = 'food',
        uses = 10,
        useTime = 5000,
        animation = 'eat',
        prop = 'burger',

        effects = {
            hunger = { min = 10, max = 20 },
            thirst = { min = -5, max = -3 },
            stress = { min = -8, max = -15 },
            health = { min = -5, max = 5 },     -- Risk vs reward
        },

        temporary = {
            speed = { min = 85, max = 90 },
            strength = { min = 105, max = 115 },
            duration = 120000,                   -- 2 minutes
        },
    },

    -- ========================================================================
    -- BURGER SHOT - SIDES
    -- ========================================================================

    ['fries'] = {
        label = 'Fries',
        type = 'food',
        uses = 5,
        useTime = 2000,
        animation = 'eat_fast',
        prop = 'fries',

        effects = {
            hunger = { min = 3, max = 8 },
            thirst = { min = -2, max = -1 },
        },
    },

    ['curly_fries'] = {
        label = 'Curly Fries',
        type = 'food',
        uses = 5,
        useTime = 2000,
        animation = 'eat_fast',
        prop = 'fries',

        effects = {
            hunger = { min = 4, max = 10 },
            thirst = { min = -2, max = -1 },
            stress = { min = 0, max = -2 },
        },
    },

    ['onion_rings'] = {
        label = 'Onion Rings',
        type = 'food',
        uses = 4,
        useTime = 2500,
        animation = 'eat_fast',

        effects = {
            hunger = { min = 4, max = 10 },
            thirst = { min = -3, max = -1 },
        },
    },

    ['chicken_nuggets'] = {
        label = 'Chicken Nuggets',
        type = 'food',
        uses = 6,
        useTime = 2000,
        animation = 'eat_fast',

        effects = {
            hunger = { min = 4, max = 9 },
            thirst = { min = -1, max = 0 },
        },
    },

    -- ========================================================================
    -- DRINKS - SODAS
    -- ========================================================================

    ['ecola'] = {
        label = 'eCola',
        type = 'drink',
        uses = 4,
        useTime = 2500,
        animation = 'drink',
        prop = 'soda_cup',

        effects = {
            thirst = { min = 8, max = 15 },
            hunger = { min = 1, max = 3 },      -- Sugar
            stress = { min = -2, max = -5 },    -- Caffeine pick-me-up
        },

        temporary = {
            speed = { min = 102, max = 105 },   -- Slight caffeine boost
            duration = 30000,
        },
    },

    ['sprunk'] = {
        label = 'Sprunk',
        type = 'drink',
        uses = 4,
        useTime = 2500,
        animation = 'drink',
        prop = 'soda_cup',

        effects = {
            thirst = { min = 10, max = 18 },
            hunger = { min = 0, max = 2 },
            stress = { min = -3, max = -6 },
        },

        temporary = {
            speed = { min = 103, max = 108 },
            duration = 45000,
        },
    },

    ['water'] = {
        label = 'Water',
        type = 'drink',
        uses = 3,
        useTime = 2000,
        animation = 'drink',
        prop = 'water_bottle',

        effects = {
            thirst = { min = 15, max = 25 },
            health = { min = 1, max = 3 },      -- Healthy
        },
    },

    -- ========================================================================
    -- DRINKS - COFFEE
    -- ========================================================================

    ['coffee'] = {
        label = 'Coffee',
        type = 'drink',
        uses = 4,
        useTime = 3000,
        animation = 'drink_coffee',
        prop = 'coffee_cup',

        effects = {
            thirst = { min = 5, max = 12 },
            stress = { min = -5, max = -10 },
        },

        temporary = {
            speed = { min = 105, max = 110 },
            duration = 120000,                   -- 2 minutes
        },
    },

    ['espresso'] = {
        label = 'Espresso',
        type = 'drink',
        uses = 2,
        useTime = 2000,
        animation = 'drink_coffee',
        prop = 'coffee_cup',

        effects = {
            thirst = { min = 3, max = 8 },
            stress = { min = -8, max = -15 },
        },

        temporary = {
            speed = { min = 108, max = 115 },
            duration = 180000,                   -- 3 minutes
        },
    },

    ['latte'] = {
        label = 'Latte',
        type = 'drink',
        uses = 5,
        useTime = 3500,
        animation = 'drink_coffee',
        prop = 'coffee_cup',

        effects = {
            thirst = { min = 8, max = 15 },
            hunger = { min = 2, max = 5 },      -- Milk content
            stress = { min = -6, max = -12 },
        },

        temporary = {
            speed = { min = 103, max = 108 },
            duration = 150000,
        },
    },

    -- ========================================================================
    -- ALCOHOLIC DRINKS
    -- ========================================================================

    ['beer'] = {
        label = 'Beer',
        type = 'drink',
        uses = 4,
        useTime = 3000,
        animation = 'drink_alcohol',
        prop = 'beer_bottle',

        effects = {
            thirst = { min = 10, max = 18 },
            hunger = { min = 2, max = 5 },
            stress = { min = -8, max = -15 },
            health = { min = -1, max = 0 },
        },

        temporary = {
            speed = { min = 95, max = 98 },     -- Slightly impaired
            strength = { min = 102, max = 105 }, -- Liquid courage
            duration = 300000,                   -- 5 minutes
        },

        -- Alcohol accumulation effect
        alcoholContent = 5,                      -- 5% ABV equivalent
    },

    ['whiskey'] = {
        label = 'Whiskey',
        type = 'drink',
        uses = 3,
        useTime = 2500,
        animation = 'drink_alcohol',
        prop = 'wine_glass',

        effects = {
            thirst = { min = 5, max = 10 },
            stress = { min = -12, max = -20 },
            health = { min = -3, max = -1 },
        },

        temporary = {
            speed = { min = 90, max = 95 },
            strength = { min = 105, max = 112 },
            duration = 600000,                   -- 10 minutes
        },

        alcoholContent = 40,
    },

    ['cocktail_margarita'] = {
        label = 'Margarita',
        type = 'drink',
        uses = 4,
        useTime = 3000,
        animation = 'drink_alcohol',
        prop = 'cocktail_glass',

        effects = {
            thirst = { min = 12, max = 20 },
            hunger = { min = 1, max = 3 },
            stress = { min = -10, max = -18 },
        },

        temporary = {
            speed = { min = 93, max = 97 },
            duration = 480000,
        },

        alcoholContent = 15,
    },

    -- ========================================================================
    -- PIZZA
    -- ========================================================================

    ['pizza_slice_cheese'] = {
        label = 'Cheese Pizza Slice',
        type = 'food',
        uses = 3,
        useTime = 3500,
        animation = 'eat',
        prop = 'pizza_slice',

        effects = {
            hunger = { min = 8, max = 15 },
            thirst = { min = -2, max = -1 },
            stress = { min = 0, max = -3 },
        },
    },

    ['pizza_slice_pepperoni'] = {
        label = 'Pepperoni Pizza Slice',
        type = 'food',
        uses = 3,
        useTime = 3500,
        animation = 'eat',
        prop = 'pizza_slice',

        effects = {
            hunger = { min = 10, max = 18 },
            thirst = { min = -3, max = -1 },
            stress = { min = -2, max = -5 },
        },
    },

    ['pizza_whole'] = {
        label = 'Whole Pizza',
        type = 'food',
        uses = 8,
        useTime = 4000,
        animation = 'eat',
        prop = 'pizza_slice',

        effects = {
            hunger = { min = 10, max = 20 },
            thirst = { min = -4, max = -2 },
            stress = { min = -3, max = -8 },
        },
    },

    -- ========================================================================
    -- MEXICAN FOOD
    -- ========================================================================

    ['taco'] = {
        label = 'Taco',
        type = 'food',
        uses = 2,
        useTime = 3000,
        animation = 'eat',
        prop = 'taco',

        effects = {
            hunger = { min = 8, max = 15 },
            thirst = { min = -2, max = 0 },
            stress = { min = 0, max = -3 },
        },
    },

    ['burrito'] = {
        label = 'Burrito',
        type = 'food',
        uses = 5,
        useTime = 4000,
        animation = 'eat',

        effects = {
            hunger = { min = 10, max = 20 },
            thirst = { min = -3, max = -1 },
            stress = { min = -2, max = -6 },
        },
    },

    ['nachos'] = {
        label = 'Nachos',
        type = 'food',
        uses = 6,
        useTime = 2500,
        animation = 'eat_fast',

        effects = {
            hunger = { min = 5, max = 12 },
            thirst = { min = -4, max = -2 },
            stress = { min = -2, max = -5 },
        },
    },

    -- ========================================================================
    -- DESSERTS
    -- ========================================================================

    ['ice_cream'] = {
        label = 'Ice Cream',
        type = 'food',
        uses = 4,
        useTime = 3000,
        animation = 'eat',
        prop = 'ice_cream',

        effects = {
            hunger = { min = 3, max = 8 },
            thirst = { min = 5, max = 10 },
            stress = { min = -5, max = -12 },   -- Very comforting
        },
    },

    ['donut'] = {
        label = 'Donut',
        type = 'food',
        uses = 2,
        useTime = 2500,
        animation = 'eat',
        prop = 'donut',

        effects = {
            hunger = { min = 5, max = 10 },
            thirst = { min = -3, max = -1 },
            stress = { min = -3, max = -8 },
        },

        temporary = {
            speed = { min = 102, max = 105 },   -- Sugar rush
            duration = 60000,
        },
    },

    -- ========================================================================
    -- ENERGY DRINKS
    -- ========================================================================

    ['energy_drink'] = {
        label = 'Energy Drink',
        type = 'drink',
        uses = 3,
        useTime = 2000,
        animation = 'drink',
        prop = 'energy_drink',

        effects = {
            thirst = { min = 8, max = 15 },
            stress = { min = -5, max = -10 },
            health = { min = -2, max = 0 },     -- Not healthy
        },

        temporary = {
            speed = { min = 110, max = 120 },
            strength = { min = 105, max = 110 },
            duration = 180000,                   -- 3 minutes
        },
    },

    -- ========================================================================
    -- BURNT/RUINED ITEMS (0 quality)
    -- ========================================================================

    ['burnt_food'] = {
        label = 'Burnt Food',
        type = 'food',
        uses = 1,
        useTime = 5000,
        animation = 'eat',

        effects = {
            hunger = { min = 2, max = 5 },
            thirst = { min = -5, max = -3 },
            stress = { min = 5, max = 10 },     -- Disgusting, adds stress
            health = { min = -5, max = -2 },    -- Bad for health
        },
    },
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Get item effects configuration
---@param itemName string
---@return table|nil
function Config.ItemEffects.GetItem(itemName)
    return Config.ItemEffects.Items[itemName]
end

--- Calculate scaled effect value based on quality
---@param effectConfig table { min = number, max = number }
---@param quality number 0-100
---@return number
function Config.ItemEffects.ScaleEffect(effectConfig, quality)
    if not effectConfig then return 0 end
    local min = effectConfig.min or 0
    local max = effectConfig.max or 0
    local qualityMultiplier = math.max(0, math.min(100, quality)) / 100
    return min + (max - min) * qualityMultiplier
end

--- Get quality label
---@param quality number
---@return string
function Config.ItemEffects.GetQualityLabel(quality)
    local thresholds = Config.ItemEffects.Defaults.qualityThresholds
    if quality <= thresholds.ruined then return 'Ruined' end
    if quality < thresholds.poor then return 'Poor' end
    if quality < thresholds.average then return 'Average' end
    if quality < thresholds.good then return 'Good' end
    if quality < thresholds.excellent then return 'Excellent' end
    return 'Perfect'
end

print('[free-restaurants] config/item_effects.lua loaded')
