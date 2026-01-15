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
        - depletedContainer: Item to replace with when fully consumed

    QUALITY SCALING:
        - minEffect: Effect at 0% quality (ruined/burnt items)
        - maxEffect: Effect at 100% quality (perfect items)
        - Actual effect = minEffect + (maxEffect - minEffect) * (quality / 100)

    SPECIAL EFFECTS:
        - duration: How long temporary effects last (speed, strength, etc.)
        - afterEffect: Effects applied after consumption completes
        - alcoholContent: Alcohol percentage for intoxication system
        - foodPoisoningRisk: Chance of food poisoning when spoiled/low quality
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
    eat_chopsticks = {
        dict = 'anim@scripted@island@special_peds@pavel@hs4_pavel_ig5_caviar_craig',
        anim = 'base_idle',
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
    drink_sake = {
        dict = 'amb@world_human_drinking@coffee@male@idle_a',
        anim = 'idle_c',
        flag = 49,
    },
    drink_soup = {
        dict = 'mp_player_intdrink',
        anim = 'intro_bottle',
        flag = 49,
    },
    smoke = {
        dict = 'amb@world_human_smoking@male@male_a@enter',
        anim = 'enter',
        flag = 49,
    },
    pill = {
        dict = 'mp_suicide',
        anim = 'pill',
        flag = 49,
    },
    medicine = {
        dict = 'mp_player_intdrink',
        anim = 'intro_bottle',
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
    chopsticks = 'prop_cs_chopstick',
    sake_cup = 'prop_cocktail',
    soup_bowl = 'prop_food_bs_soup1',
    sushi_plate = 'prop_food_bs_sushi_01',
    pill_bottle = 'prop_cs_pills',
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

    -- Food poisoning risk based on freshness
    foodPoisoningRisk = {
        spoiled = 0.8,      -- 80% chance if spoiled
        veryLow = 0.5,      -- 50% if very low quality (<10)
        low = 0.25,         -- 25% if low quality (<25)
        normal = 0.0,       -- 0% normally
    },

    -- Default depleted container
    defaultFoodContainer = 'food_wrapper',
    defaultDrinkContainer = 'empty_cup',
}

-- ============================================================================
-- CONTAINER REPLACEMENT MAPPING
-- ============================================================================

Config.ItemEffects.ContainerMappings = {
    -- Food wrappers
    burger = 'burger_wrapper',
    sandwich = 'food_wrapper',
    taco = 'taco_wrapper',
    burrito = 'food_wrapper',
    hotdog = 'food_wrapper',
    fries = 'fry_container',
    nuggets = 'fry_container',

    -- Plates
    plate = 'dirty_plate',
    plate_fork = 'plate_fork',
    bowl_spoon = 'bowl_spoon',
    sushi_tray = 'sushi_tray_empty',
    chopsticks = 'chopsticks_used',

    -- Pizza
    pizza_slice = 'food_wrapper',
    pizza_box = 'pizza_box',

    -- Fruit
    banana = 'banana_peel',
    orange = 'orange_peel',
    fruit = 'fruit_peel',

    -- Ice cream / desserts
    ice_cream = 'food_wrapper',
    popsicle = 'popsicle_stick',
    donut = 'food_wrapper',

    -- Drink containers
    soda_cup = 'empty_cup_lid',
    coffee_cup = 'empty_coffee_cup',
    glass = 'empty_glass',
    bottle = 'empty_bottle',
    can = 'empty_can',
    wine_glass = 'empty_wine_glass',
    cocktail_glass = 'empty_cocktail_glass',
    sake_cup = 'empty_sake_cup',
    mug = 'empty_mug',
    water_bottle = 'empty_bottle',
}

-- ============================================================================
-- FOOD ITEMS
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
        depletedContainer = 'burger_wrapper',

        effects = {
            hunger = { min = 5, max = 12 },
            thirst = { min = -2, max = -1 },
        },
    },

    ['bleeder_burger_premium'] = {
        label = 'The Bleeder (Premium)',
        type = 'food',
        uses = 4,
        useTime = 3500,
        animation = 'eat',
        prop = 'burger',
        depletedContainer = 'burger_wrapper',

        effects = {
            hunger = { min = 8, max = 18 },
            thirst = { min = -1, max = 0 },
            stress = { min = 0, max = -3 },
        },
    },

    ['double_barreled_burger'] = {
        label = 'Double Barreled',
        type = 'food',
        uses = 6,
        useTime = 4000,
        animation = 'eat',
        prop = 'burger',
        depletedContainer = 'burger_wrapper',

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
        depletedContainer = 'burger_wrapper',

        effects = {
            hunger = { min = 8, max = 16 },
            thirst = { min = -4, max = -2 },
            stress = { min = -5, max = -10 },
            health = { min = -2, max = 0 },
        },

        temporary = {
            speed = { min = 90, max = 95 },
            duration = 60000,
        },
    },

    ['murder_burger'] = {
        label = 'The Murder Burger',
        type = 'food',
        uses = 10,
        useTime = 5000,
        animation = 'eat',
        prop = 'burger',
        depletedContainer = 'burger_wrapper',

        effects = {
            hunger = { min = 10, max = 20 },
            thirst = { min = -5, max = -3 },
            stress = { min = -8, max = -15 },
            health = { min = -5, max = 5 },
        },

        temporary = {
            speed = { min = 85, max = 90 },
            strength = { min = 105, max = 115 },
            duration = 120000,
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
        depletedContainer = 'fry_container',

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
        depletedContainer = 'fry_container',

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
        depletedContainer = 'fry_container',

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
        depletedContainer = 'fry_container',

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
        depletedContainer = 'empty_cup_lid',

        effects = {
            thirst = { min = 8, max = 15 },
            hunger = { min = 1, max = 3 },
            stress = { min = -2, max = -5 },
        },

        temporary = {
            speed = { min = 102, max = 105 },
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
        depletedContainer = 'empty_cup_lid',

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
        depletedContainer = 'empty_bottle',

        effects = {
            thirst = { min = 15, max = 25 },
            health = { min = 1, max = 3 },
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
        depletedContainer = 'empty_coffee_cup',

        effects = {
            thirst = { min = 5, max = 12 },
            stress = { min = -5, max = -10 },
        },

        temporary = {
            speed = { min = 105, max = 110 },
            duration = 120000,
        },
    },

    ['espresso'] = {
        label = 'Espresso',
        type = 'drink',
        uses = 2,
        useTime = 2000,
        animation = 'drink_coffee',
        prop = 'coffee_cup',
        depletedContainer = 'empty_coffee_cup',

        effects = {
            thirst = { min = 3, max = 8 },
            stress = { min = -8, max = -15 },
        },

        temporary = {
            speed = { min = 108, max = 115 },
            duration = 180000,
        },
    },

    ['latte'] = {
        label = 'Latte',
        type = 'drink',
        uses = 5,
        useTime = 3500,
        animation = 'drink_coffee',
        prop = 'coffee_cup',
        depletedContainer = 'empty_coffee_cup',

        effects = {
            thirst = { min = 8, max = 15 },
            hunger = { min = 2, max = 5 },
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
        depletedContainer = 'empty_bottle',
        alcoholContent = 5,

        effects = {
            thirst = { min = 10, max = 18 },
            hunger = { min = 2, max = 5 },
            stress = { min = -8, max = -15 },
            health = { min = -1, max = 0 },
        },

        temporary = {
            speed = { min = 95, max = 98 },
            strength = { min = 102, max = 105 },
            duration = 300000,
        },
    },

    ['whiskey'] = {
        label = 'Whiskey',
        type = 'drink',
        uses = 3,
        useTime = 2500,
        animation = 'drink_alcohol',
        prop = 'wine_glass',
        depletedContainer = 'empty_glass',
        alcoholContent = 40,

        effects = {
            thirst = { min = 5, max = 10 },
            stress = { min = -12, max = -20 },
            health = { min = -3, max = -1 },
        },

        temporary = {
            speed = { min = 90, max = 95 },
            strength = { min = 105, max = 112 },
            duration = 600000,
        },
    },

    ['cocktail_margarita'] = {
        label = 'Margarita',
        type = 'drink',
        uses = 4,
        useTime = 3000,
        animation = 'drink_alcohol',
        prop = 'cocktail_glass',
        depletedContainer = 'empty_cocktail_glass',
        alcoholContent = 15,

        effects = {
            thirst = { min = 12, max = 20 },
            hunger = { min = 1, max = 3 },
            stress = { min = -10, max = -18 },
        },

        temporary = {
            speed = { min = 93, max = 97 },
            duration = 480000,
        },
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
        depletedContainer = 'food_wrapper',

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
        depletedContainer = 'food_wrapper',

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
        depletedContainer = 'pizza_box',

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
        depletedContainer = 'taco_wrapper',

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
        depletedContainer = 'food_wrapper',

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
        depletedContainer = 'dirty_plate',

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
        depletedContainer = 'food_wrapper',

        effects = {
            hunger = { min = 3, max = 8 },
            thirst = { min = 5, max = 10 },
            stress = { min = -5, max = -12 },
        },
    },

    ['donut'] = {
        label = 'Donut',
        type = 'food',
        uses = 2,
        useTime = 2500,
        animation = 'eat',
        prop = 'donut',
        depletedContainer = 'food_wrapper',

        effects = {
            hunger = { min = 5, max = 10 },
            thirst = { min = -3, max = -1 },
            stress = { min = -3, max = -8 },
        },

        temporary = {
            speed = { min = 102, max = 105 },
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
        depletedContainer = 'empty_can',

        effects = {
            thirst = { min = 8, max = 15 },
            stress = { min = -5, max = -10 },
            health = { min = -2, max = 0 },
        },

        temporary = {
            speed = { min = 110, max = 120 },
            strength = { min = 105, max = 110 },
            duration = 180000,
        },
    },

    -- ========================================================================
    -- SUSHI RESTAURANT - APPETIZERS
    -- ========================================================================

    ['miso_soup'] = {
        label = 'Miso Soup',
        type = 'food',
        uses = 3,
        useTime = 3000,
        animation = 'drink_soup',
        prop = 'soup_bowl',
        depletedContainer = 'bowl_spoon',

        effects = {
            hunger = { min = 4, max = 8 },
            thirst = { min = 8, max = 15 },
            health = { min = 2, max = 5 },
            stress = { min = -3, max = -6 },
        },
    },

    ['edamame'] = {
        label = 'Edamame',
        type = 'food',
        uses = 5,
        useTime = 2000,
        animation = 'eat_fast',
        depletedContainer = 'bowl_spoon',

        effects = {
            hunger = { min = 3, max = 7 },
            thirst = { min = -1, max = 0 },
            health = { min = 1, max = 3 },
        },
    },

    ['gyoza'] = {
        label = 'Gyoza',
        type = 'food',
        uses = 6,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 5, max = 10 },
            thirst = { min = -2, max = -1 },
            stress = { min = -2, max = -5 },
        },
    },

    ['tempura_shrimp'] = {
        label = 'Shrimp Tempura',
        type = 'food',
        uses = 5,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 6, max = 12 },
            thirst = { min = -2, max = -1 },
            stress = { min = -3, max = -6 },
        },
    },

    ['tempura_vegetables'] = {
        label = 'Vegetable Tempura',
        type = 'food',
        uses = 5,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 4, max = 9 },
            thirst = { min = -1, max = 0 },
            health = { min = 1, max = 3 },
        },
    },

    ['seaweed_salad'] = {
        label = 'Seaweed Salad',
        type = 'food',
        uses = 3,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'bowl_spoon',

        effects = {
            hunger = { min = 3, max = 6 },
            thirst = { min = 2, max = 5 },
            health = { min = 2, max = 5 },
        },
    },

    ['ginger_salad'] = {
        label = 'Ginger Salad',
        type = 'food',
        uses = 3,
        useTime = 2500,
        animation = 'eat',
        depletedContainer = 'bowl_spoon',

        effects = {
            hunger = { min = 2, max = 5 },
            thirst = { min = 3, max = 6 },
            health = { min = 1, max = 3 },
        },
    },

    ['onion_soup'] = {
        label = 'Japanese Onion Soup',
        type = 'food',
        uses = 3,
        useTime = 3000,
        animation = 'drink_soup',
        prop = 'soup_bowl',
        depletedContainer = 'bowl_spoon',

        effects = {
            hunger = { min = 3, max = 7 },
            thirst = { min = 10, max = 15 },
            stress = { min = -2, max = -5 },
        },
    },

    ['agedashi_tofu'] = {
        label = 'Agedashi Tofu',
        type = 'food',
        uses = 4,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'bowl_spoon',

        effects = {
            hunger = { min = 4, max = 8 },
            thirst = { min = 3, max = 6 },
            health = { min = 2, max = 4 },
        },
    },

    -- ========================================================================
    -- SUSHI RESTAURANT - SUSHI ROLLS
    -- ========================================================================

    ['california_roll'] = {
        label = 'California Roll',
        type = 'food',
        uses = 8,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 5, max = 10 },
            thirst = { min = -1, max = 0 },
            stress = { min = -2, max = -5 },
            health = { min = 1, max = 3 },
        },
    },

    ['spicy_tuna_roll'] = {
        label = 'Spicy Tuna Roll',
        type = 'food',
        uses = 8,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 6, max = 12 },
            thirst = { min = -2, max = -1 },
            stress = { min = -3, max = -6 },
            health = { min = 2, max = 4 },
        },
    },

    ['salmon_roll'] = {
        label = 'Salmon Roll',
        type = 'food',
        uses = 8,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 5, max = 11 },
            thirst = { min = -1, max = 0 },
            stress = { min = -2, max = -5 },
            health = { min = 3, max = 6 },
        },
    },

    ['dragon_roll'] = {
        label = 'Dragon Roll',
        type = 'food',
        uses = 8,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 7, max = 14 },
            thirst = { min = -1, max = 0 },
            stress = { min = -4, max = -8 },
            health = { min = 2, max = 5 },
        },
    },

    ['rainbow_roll'] = {
        label = 'Rainbow Roll',
        type = 'food',
        uses = 8,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 8, max = 16 },
            thirst = { min = -1, max = 0 },
            stress = { min = -5, max = -10 },
            health = { min = 4, max = 8 },
        },
    },

    ['philadelphia_roll'] = {
        label = 'Philadelphia Roll',
        type = 'food',
        uses = 8,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 6, max = 12 },
            thirst = { min = -1, max = 0 },
            stress = { min = -3, max = -6 },
            health = { min = 2, max = 4 },
        },
    },

    ['shrimp_tempura_roll'] = {
        label = 'Shrimp Tempura Roll',
        type = 'food',
        uses = 8,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 6, max = 13 },
            thirst = { min = -2, max = -1 },
            stress = { min = -3, max = -7 },
        },
    },

    ['volcano_roll'] = {
        label = 'Volcano Roll',
        type = 'food',
        uses = 8,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 7, max = 15 },
            thirst = { min = -3, max = -1 },
            stress = { min = -4, max = -8 },
        },
    },

    -- ========================================================================
    -- SUSHI RESTAURANT - NIGIRI & SASHIMI
    -- ========================================================================

    ['salmon_nigiri'] = {
        label = 'Salmon Nigiri',
        type = 'food',
        uses = 2,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 4, max = 8 },
            health = { min = 3, max = 6 },
        },
    },

    ['tuna_nigiri'] = {
        label = 'Tuna Nigiri',
        type = 'food',
        uses = 2,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 4, max = 9 },
            health = { min = 3, max = 7 },
        },
    },

    ['yellowtail_nigiri'] = {
        label = 'Yellowtail Nigiri',
        type = 'food',
        uses = 2,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 4, max = 8 },
            health = { min = 3, max = 6 },
        },
    },

    ['shrimp_nigiri'] = {
        label = 'Shrimp Nigiri',
        type = 'food',
        uses = 2,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 3, max = 7 },
            health = { min = 2, max = 4 },
        },
    },

    ['eel_nigiri'] = {
        label = 'Eel Nigiri',
        type = 'food',
        uses = 2,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 5, max = 10 },
            health = { min = 2, max = 5 },
            stress = { min = -2, max = -4 },
        },
    },

    ['sashimi_platter'] = {
        label = 'Sashimi Platter',
        type = 'food',
        uses = 12,
        useTime = 2000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 5, max = 10 },
            health = { min = 4, max = 8 },
            stress = { min = -3, max = -6 },
        },
    },

    ['omakase_platter'] = {
        label = 'Omakase Platter',
        type = 'food',
        uses = 15,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'sushi_tray_empty',

        effects = {
            hunger = { min = 6, max = 12 },
            health = { min = 5, max = 10 },
            stress = { min = -5, max = -10 },
        },

        temporary = {
            speed = { min = 102, max = 105 },
            duration = 120000,
        },
    },

    -- ========================================================================
    -- SUSHI RESTAURANT - HIBACHI/TEPPANYAKI
    -- ========================================================================

    ['hibachi_steak'] = {
        label = 'Hibachi Steak',
        type = 'food',
        uses = 8,
        useTime = 3500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 10, max = 20 },
            thirst = { min = -3, max = -1 },
            stress = { min = -5, max = -10 },
            health = { min = 2, max = 5 },
        },

        temporary = {
            strength = { min = 105, max = 110 },
            duration = 180000,
        },
    },

    ['hibachi_chicken'] = {
        label = 'Hibachi Chicken',
        type = 'food',
        uses = 7,
        useTime = 3000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 8, max = 16 },
            thirst = { min = -2, max = -1 },
            stress = { min = -4, max = -8 },
            health = { min = 3, max = 6 },
        },
    },

    ['hibachi_shrimp'] = {
        label = 'Hibachi Shrimp',
        type = 'food',
        uses = 6,
        useTime = 3000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 7, max = 14 },
            thirst = { min = -2, max = -1 },
            stress = { min = -3, max = -7 },
            health = { min = 3, max = 6 },
        },
    },

    ['hibachi_lobster'] = {
        label = 'Hibachi Lobster',
        type = 'food',
        uses = 6,
        useTime = 3500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 8, max = 16 },
            thirst = { min = -2, max = -1 },
            stress = { min = -6, max = -12 },
            health = { min = 3, max = 7 },
        },
    },

    ['hibachi_scallops'] = {
        label = 'Hibachi Scallops',
        type = 'food',
        uses = 5,
        useTime = 3000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 6, max = 12 },
            thirst = { min = -1, max = 0 },
            stress = { min = -4, max = -8 },
            health = { min = 3, max = 6 },
        },
    },

    ['hibachi_filet_mignon'] = {
        label = 'Hibachi Filet Mignon',
        type = 'food',
        uses = 8,
        useTime = 4000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 12, max = 22 },
            thirst = { min = -3, max = -1 },
            stress = { min = -8, max = -15 },
            health = { min = 2, max = 5 },
        },

        temporary = {
            strength = { min = 108, max = 115 },
            duration = 240000,
        },
    },

    ['hibachi_wagyu'] = {
        label = 'Hibachi Wagyu',
        type = 'food',
        uses = 10,
        useTime = 4500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 15, max = 25 },
            thirst = { min = -3, max = -1 },
            stress = { min = -10, max = -20 },
            health = { min = 3, max = 8 },
        },

        temporary = {
            strength = { min = 110, max = 120 },
            speed = { min = 102, max = 105 },
            duration = 300000,
        },
    },

    ['hibachi_combo'] = {
        label = 'Hibachi Combination',
        type = 'food',
        uses = 10,
        useTime = 3500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 12, max = 22 },
            thirst = { min = -3, max = -2 },
            stress = { min = -6, max = -12 },
            health = { min = 3, max = 6 },
        },

        temporary = {
            strength = { min = 105, max = 110 },
            duration = 180000,
        },
    },

    ['hibachi_vegetables'] = {
        label = 'Hibachi Vegetables',
        type = 'food',
        uses = 5,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 5, max = 10 },
            thirst = { min = 0, max = 2 },
            health = { min = 4, max = 8 },
        },
    },

    ['hibachi_fried_rice'] = {
        label = 'Hibachi Fried Rice',
        type = 'food',
        uses = 6,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'bowl_spoon',

        effects = {
            hunger = { min = 8, max = 15 },
            thirst = { min = -2, max = -1 },
            stress = { min = -2, max = -5 },
        },
    },

    ['hibachi_noodles'] = {
        label = 'Hibachi Noodles',
        type = 'food',
        uses = 6,
        useTime = 3000,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'bowl_spoon',

        effects = {
            hunger = { min = 8, max = 16 },
            thirst = { min = -2, max = -1 },
            stress = { min = -2, max = -5 },
        },
    },

    -- ========================================================================
    -- SUSHI RESTAURANT - DESSERTS
    -- ========================================================================

    ['mochi_ice_cream'] = {
        label = 'Mochi Ice Cream',
        type = 'food',
        uses = 3,
        useTime = 2500,
        animation = 'eat_chopsticks',
        prop = 'chopsticks',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 3, max = 6 },
            thirst = { min = 3, max = 6 },
            stress = { min = -5, max = -10 },
        },
    },

    ['tempura_ice_cream'] = {
        label = 'Tempura Ice Cream',
        type = 'food',
        uses = 4,
        useTime = 3000,
        animation = 'eat',
        depletedContainer = 'plate_fork',

        effects = {
            hunger = { min = 4, max = 8 },
            thirst = { min = 4, max = 8 },
            stress = { min = -6, max = -12 },
        },
    },

    ['green_tea_ice_cream'] = {
        label = 'Green Tea Ice Cream',
        type = 'food',
        uses = 3,
        useTime = 2500,
        animation = 'eat',
        depletedContainer = 'bowl_spoon',

        effects = {
            hunger = { min = 3, max = 6 },
            thirst = { min = 4, max = 8 },
            stress = { min = -5, max = -10 },
            health = { min = 1, max = 2 },
        },
    },

    -- ========================================================================
    -- SUSHI RESTAURANT - BEVERAGES
    -- ========================================================================

    ['sake_cup'] = {
        label = 'Sake',
        type = 'drink',
        uses = 2,
        useTime = 2000,
        animation = 'drink_sake',
        prop = 'sake_cup',
        depletedContainer = 'empty_sake_cup',
        alcoholContent = 15,

        effects = {
            thirst = { min = 5, max = 10 },
            stress = { min = -8, max = -15 },
        },

        temporary = {
            speed = { min = 95, max = 98 },
            strength = { min = 103, max = 107 },
            duration = 300000,
        },
    },

    ['japanese_beer'] = {
        label = 'Japanese Beer',
        type = 'drink',
        uses = 4,
        useTime = 2500,
        animation = 'drink_alcohol',
        prop = 'beer_bottle',
        depletedContainer = 'empty_bottle',
        alcoholContent = 5,

        effects = {
            thirst = { min = 10, max = 18 },
            hunger = { min = 1, max = 3 },
            stress = { min = -6, max = -12 },
        },

        temporary = {
            speed = { min = 96, max = 99 },
            duration = 240000,
        },
    },

    ['green_tea'] = {
        label = 'Green Tea',
        type = 'drink',
        uses = 4,
        useTime = 2500,
        animation = 'drink_coffee',
        prop = 'coffee_cup',
        depletedContainer = 'empty_cup',

        effects = {
            thirst = { min = 10, max = 18 },
            stress = { min = -5, max = -10 },
            health = { min = 2, max = 5 },
        },
    },

    ['ramune'] = {
        label = 'Ramune Soda',
        type = 'drink',
        uses = 4,
        useTime = 2500,
        animation = 'drink',
        depletedContainer = 'empty_bottle',

        effects = {
            thirst = { min = 12, max = 20 },
            hunger = { min = 1, max = 3 },
            stress = { min = -3, max = -6 },
        },
    },

    -- ========================================================================
    -- MEDICAL ITEMS - FOOD POISONING TREATMENT
    -- ========================================================================

    ['antacid'] = {
        label = 'Antacid Tablets',
        type = 'medicine',
        uses = 1,
        useTime = 2000,
        animation = 'pill',
        depletedContainer = nil, -- No container for pills

        effects = {
            health = { min = 2, max = 5 },
        },

        -- Reduces mild food poisoning effects
        curesFoodPoisoning = 'mild',
        removesNausea = true,
    },

    ['pepto_bismol'] = {
        label = 'Stomach Relief Medicine',
        type = 'medicine',
        uses = 3,
        useTime = 2500,
        animation = 'medicine',
        depletedContainer = 'empty_bottle',

        effects = {
            health = { min = 3, max = 8 },
            thirst = { min = 2, max = 5 },
        },

        curesFoodPoisoning = 'mild',
        removesNausea = true,
    },

    ['anti_nausea_pills'] = {
        label = 'Anti-Nausea Pills',
        type = 'medicine',
        uses = 2,
        useTime = 2000,
        animation = 'pill',
        depletedContainer = nil,

        effects = {
            health = { min = 5, max = 10 },
        },

        curesFoodPoisoning = 'moderate',
        removesNausea = true,
    },

    ['activated_charcoal'] = {
        label = 'Activated Charcoal',
        type = 'medicine',
        uses = 1,
        useTime = 3000,
        animation = 'pill',
        depletedContainer = nil,

        effects = {
            health = { min = 10, max = 20 },
        },

        curesFoodPoisoning = 'severe',
        removesNausea = true,
    },

    ['prescription_antiemetic'] = {
        label = 'Prescription Antiemetic',
        type = 'medicine',
        uses = 2,
        useTime = 2000,
        animation = 'pill',
        depletedContainer = nil,

        effects = {
            health = { min = 15, max = 25 },
            stress = { min = -5, max = -10 },
        },

        curesFoodPoisoning = 'severe',
        removesNausea = true,
        prescription = true, -- Requires hospital/pharmacy
    },

    ['iv_fluids'] = {
        label = 'IV Fluid Bag',
        type = 'medicine',
        uses = 1,
        useTime = 10000,
        animation = 'medicine',
        depletedContainer = nil,

        effects = {
            health = { min = 30, max = 50 },
            thirst = { min = 50, max = 75 },
        },

        curesFoodPoisoning = 'severe',
        removesNausea = true,
        removesDehydration = true,
        hospitalOnly = true, -- Can only be used at hospital
    },

    ['electrolyte_drink'] = {
        label = 'Electrolyte Drink',
        type = 'drink',
        uses = 3,
        useTime = 2500,
        animation = 'drink',
        depletedContainer = 'empty_bottle',

        effects = {
            thirst = { min = 20, max = 35 },
            health = { min = 5, max = 10 },
        },

        reducesDehydration = true,
        helpsFoodPoisoning = true,
    },

    ['food_poisoning_kit'] = {
        label = 'Food Poisoning Treatment Kit',
        type = 'medicine',
        uses = 1,
        useTime = 5000,
        animation = 'medicine',
        depletedContainer = nil,

        effects = {
            health = { min = 25, max = 40 },
            thirst = { min = 10, max = 20 },
        },

        curesFoodPoisoning = 'severe',
        removesNausea = true,
        removesDehydration = true,
    },

    -- ========================================================================
    -- BURNT/RUINED ITEMS
    -- ========================================================================

    ['burnt_food'] = {
        label = 'Burnt Food',
        type = 'food',
        uses = 1,
        useTime = 5000,
        animation = 'eat',
        depletedContainer = 'food_wrapper',
        foodPoisoningRisk = 0.5,

        effects = {
            hunger = { min = 2, max = 5 },
            thirst = { min = -5, max = -3 },
            stress = { min = 5, max = 10 },
            health = { min = -5, max = -2 },
        },
    },
}

-- ============================================================================
-- RECYCLING VALUES
-- ============================================================================

Config.ItemEffects.RecyclingValues = {
    -- Bottles/cans give money back
    ['empty_bottle'] = { money = 5, item = nil },
    ['empty_can'] = { money = 3, item = nil },
    ['empty_glass'] = { money = 2, item = nil },

    -- Some items can be converted to other items
    ['dirty_plate'] = { money = 0, item = nil, returnToRestaurant = true },
    ['plate_fork'] = { money = 0, item = nil, returnToRestaurant = true },
    ['bowl_spoon'] = { money = 0, item = nil, returnToRestaurant = true },
    ['sushi_tray_empty'] = { money = 0, item = nil, returnToRestaurant = true },

    -- Wrappers just get disposed
    ['food_wrapper'] = { money = 0, item = nil },
    ['burger_wrapper'] = { money = 0, item = nil },
    ['taco_wrapper'] = { money = 0, item = nil },
    ['fry_container'] = { money = 0, item = nil },
    ['pizza_box'] = { money = 0, item = nil },

    -- Peels (compost)
    ['banana_peel'] = { money = 0, item = nil },
    ['orange_peel'] = { money = 0, item = nil },
    ['fruit_peel'] = { money = 0, item = nil },
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

--- Get depleted container for an item
---@param itemName string
---@return string|nil
function Config.ItemEffects.GetDepletedContainer(itemName)
    local item = Config.ItemEffects.Items[itemName]
    if item and item.depletedContainer then
        return item.depletedContainer
    end

    -- Default based on type
    if item then
        if item.type == 'food' then
            return Config.ItemEffects.Defaults.defaultFoodContainer
        elseif item.type == 'drink' then
            return Config.ItemEffects.Defaults.defaultDrinkContainer
        end
    end

    return nil
end

--- Get recycling value for container
---@param containerName string
---@return table|nil
function Config.ItemEffects.GetRecyclingValue(containerName)
    return Config.ItemEffects.RecyclingValues[containerName]
end

--- Check if item is medicine
---@param itemName string
---@return boolean
function Config.ItemEffects.IsMedicine(itemName)
    local item = Config.ItemEffects.Items[itemName]
    return item and item.type == 'medicine'
end

--- Check if item can cure food poisoning
---@param itemName string
---@param severity string 'mild', 'moderate', 'severe'
---@return boolean
function Config.ItemEffects.CanCureFoodPoisoning(itemName, severity)
    local item = Config.ItemEffects.Items[itemName]
    if not item or not item.curesFoodPoisoning then
        return false
    end

    local severityLevels = { mild = 1, moderate = 2, severe = 3 }
    local itemLevel = severityLevels[item.curesFoodPoisoning] or 0
    local requiredLevel = severityLevels[severity] or 0

    return itemLevel >= requiredLevel
end

print('[free-restaurants] config/item_effects.lua loaded')
