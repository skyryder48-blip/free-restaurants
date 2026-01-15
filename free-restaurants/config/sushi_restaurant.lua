--[[
    free-restaurants Sushi Restaurant Configuration
    Benihana-style Japanese restaurant with sushi bar and teppanyaki grill
]]

Config = Config or {}
Config.Locations = Config.Locations or {}

-- ============================================================================
-- SUSHI RESTAURANT - STATION TYPES
-- ============================================================================

Config.Stations = Config.Stations or {}
Config.Stations.Types = Config.Stations.Types or {}

-- Sushi preparation station
Config.Stations.Types['sushi_prep'] = {
    label = 'Sushi Preparation',
    description = 'Prepare sushi rolls and nigiri',
    icon = 'fa-solid fa-fish',
    skillRequired = 0,

    canCraft = { 'sushi_rolls', 'nigiri', 'sashimi' },

    slots = 4,
    craftTime = {
        base = 8000,
        perIngredient = 1500,
    },

    cooking = {
        type = 'preparation',
        requiresHeat = false,
        qualityFactors = {
            ingredientFreshness = 0.4,
            timing = 0.3,
            skill = 0.3,
        },
    },

    animations = {
        working = {
            dict = 'anim@amb@business@coc@coc_unpack_cut_left@',
            anim = 'coke_cut_v1_coccutter',
            flag = 1,
        },
    },
}

-- Rice cooker station
Config.Stations.Types['rice_cooker'] = {
    label = 'Rice Cooker',
    description = 'Prepare sushi rice',
    icon = 'fa-solid fa-bowl-rice',
    skillRequired = 0,

    canCraft = { 'rice_prep' },

    slots = 2,
    craftTime = {
        base = 15000,
        perIngredient = 2000,
    },

    cooking = {
        type = 'cooking',
        requiresHeat = true,
        stages = {
            { name = 'cooking', duration = 0.7, temp = 'medium' },
            { name = 'steaming', duration = 0.3, temp = 'low' },
        },
    },
}

-- Teppanyaki grill (hibachi)
Config.Stations.Types['teppanyaki_grill'] = {
    label = 'Teppanyaki Grill',
    description = 'Hibachi-style flat top grill',
    icon = 'fa-solid fa-fire-burner',
    skillRequired = 2,

    canCraft = { 'hibachi', 'fried_rice', 'grilled' },

    slots = 6,
    craftTime = {
        base = 12000,
        perIngredient = 2000,
    },

    cooking = {
        type = 'grilling',
        requiresHeat = true,
        heatSource = 'gas',
        stages = {
            { name = 'searing', duration = 0.3, temp = 'high' },
            { name = 'cooking', duration = 0.5, temp = 'medium' },
            { name = 'resting', duration = 0.2, temp = 'low' },
        },
        qualityFactors = {
            timing = 0.35,
            temperature = 0.35,
            skill = 0.3,
        },
    },

    visuals = {
        fire = true,
        smoke = true,
        particles = 'core',
    },

    fire = {
        type = 'gas',
        maxChildren = 15,
        autoExtinguish = 180,
        extinguisherEffective = 45,
    },
}

-- Tempura fryer
Config.Stations.Types['tempura_fryer'] = {
    label = 'Tempura Fryer',
    description = 'Deep fryer for tempura',
    icon = 'fa-solid fa-drumstick-bite',
    skillRequired = 1,

    canCraft = { 'tempura', 'fried' },

    slots = 3,
    craftTime = {
        base = 6000,
        perIngredient = 1500,
    },

    cooking = {
        type = 'frying',
        requiresHeat = true,
        heatSource = 'oil',
        oilTemp = 350,
        stages = {
            { name = 'coating', duration = 0.2, temp = 'none' },
            { name = 'frying', duration = 0.6, temp = 'high' },
            { name = 'draining', duration = 0.2, temp = 'none' },
        },
    },

    fire = {
        type = 'gas',
        maxChildren = 25,
        autoExtinguish = 0,
        extinguisherEffective = 30,
    },
}

-- Soup station
Config.Stations.Types['soup_station'] = {
    label = 'Soup Station',
    description = 'Prepare miso soup and broths',
    icon = 'fa-solid fa-mug-hot',
    skillRequired = 0,

    canCraft = { 'soup', 'broth' },

    slots = 4,
    craftTime = {
        base = 8000,
        perIngredient = 1000,
    },

    cooking = {
        type = 'simmering',
        requiresHeat = true,
        stages = {
            { name = 'heating', duration = 0.3, temp = 'medium' },
            { name = 'simmering', duration = 0.7, temp = 'low' },
        },
    },
}

-- Sake bar
Config.Stations.Types['sake_bar'] = {
    label = 'Sake Bar',
    description = 'Serve sake and Japanese beverages',
    icon = 'fa-solid fa-wine-glass',
    skillRequired = 0,

    canCraft = { 'beverages', 'sake' },

    slots = 6,
    craftTime = {
        base = 3000,
        perIngredient = 500,
    },

    cooking = {
        type = 'beverage',
        requiresHeat = false,
    },
}

-- ============================================================================
-- SUSHI RESTAURANT - RECIPES
-- ============================================================================

Config.Recipes = Config.Recipes or {}
Config.Recipes.Items = Config.Recipes.Items or {}

-- Sushi Rice
Config.Recipes.Items['sushi_rice'] = {
    label = 'Sushi Rice',
    category = 'rice_prep',
    station = 'rice_cooker',
    result = { item = 'sushi_rice', count = 5 },
    time = 15000,

    ingredients = {
        { item = 'fried_rice_base', count = 2 },
        { item = 'rice_vinegar', count = 1 },
    },

    skill = {
        required = 0,
        bonus = { 50, 0.1 },
    },
}

-- Miso Soup
Config.Recipes.Items['miso_soup'] = {
    label = 'Miso Soup',
    category = 'soup',
    station = 'soup_station',
    result = { item = 'miso_soup', count = 1 },
    time = 8000,

    ingredients = {
        { item = 'miso_paste', count = 1 },
        { item = 'dashi_stock', count = 1 },
        { item = 'tofu', count = 1 },
        { item = 'wakame', count = 1 },
    },
}

-- California Roll
Config.Recipes.Items['california_roll'] = {
    label = 'California Roll',
    category = 'sushi_rolls',
    station = 'sushi_prep',
    result = { item = 'california_roll', count = 1 },
    time = 10000,

    ingredients = {
        { item = 'sushi_rice', count = 1 },
        { item = 'nori_sheets', count = 1 },
        { item = 'crab_meat', count = 1 },
        { item = 'avocado', count = 1 },
        { item = 'cucumber', count = 1 },
    },

    skill = {
        required = 1,
        bonus = { 75, 0.15 },
    },
}

-- Spicy Tuna Roll
Config.Recipes.Items['spicy_tuna_roll'] = {
    label = 'Spicy Tuna Roll',
    category = 'sushi_rolls',
    station = 'sushi_prep',
    result = { item = 'spicy_tuna_roll', count = 1 },
    time = 10000,

    ingredients = {
        { item = 'sushi_rice', count = 1 },
        { item = 'nori_sheets', count = 1 },
        { item = 'tuna_raw', count = 1 },
        { item = 'sesame_seeds', count = 1 },
    },

    skill = {
        required = 1,
        bonus = { 75, 0.15 },
    },
}

-- Salmon Roll
Config.Recipes.Items['salmon_roll'] = {
    label = 'Salmon Roll',
    category = 'sushi_rolls',
    station = 'sushi_prep',
    result = { item = 'salmon_roll', count = 1 },
    time = 10000,

    ingredients = {
        { item = 'sushi_rice', count = 1 },
        { item = 'nori_sheets', count = 1 },
        { item = 'salmon_raw', count = 1 },
    },

    skill = {
        required = 1,
        bonus = { 75, 0.15 },
    },
}

-- Dragon Roll
Config.Recipes.Items['dragon_roll'] = {
    label = 'Dragon Roll',
    category = 'sushi_rolls',
    station = 'sushi_prep',
    result = { item = 'dragon_roll', count = 1 },
    time = 15000,

    ingredients = {
        { item = 'sushi_rice', count = 1 },
        { item = 'nori_sheets', count = 1 },
        { item = 'eel_raw', count = 1 },
        { item = 'avocado', count = 1 },
        { item = 'tobiko', count = 1 },
    },

    skill = {
        required = 3,
        bonus = { 85, 0.2 },
    },
}

-- Rainbow Roll
Config.Recipes.Items['rainbow_roll'] = {
    label = 'Rainbow Roll',
    category = 'sushi_rolls',
    station = 'sushi_prep',
    result = { item = 'rainbow_roll', count = 1 },
    time = 18000,

    ingredients = {
        { item = 'sushi_rice', count = 1 },
        { item = 'nori_sheets', count = 1 },
        { item = 'crab_meat', count = 1 },
        { item = 'salmon_raw', count = 1 },
        { item = 'tuna_raw', count = 1 },
        { item = 'yellowtail_raw', count = 1 },
        { item = 'avocado', count = 1 },
    },

    skill = {
        required = 4,
        bonus = { 90, 0.25 },
    },
}

-- Salmon Nigiri
Config.Recipes.Items['salmon_nigiri'] = {
    label = 'Salmon Nigiri',
    category = 'nigiri',
    station = 'sushi_prep',
    result = { item = 'salmon_nigiri', count = 2 },
    time = 6000,

    ingredients = {
        { item = 'sushi_rice', count = 1 },
        { item = 'salmon_raw', count = 1 },
    },

    skill = {
        required = 2,
        bonus = { 80, 0.15 },
    },
}

-- Tuna Nigiri
Config.Recipes.Items['tuna_nigiri'] = {
    label = 'Tuna Nigiri',
    category = 'nigiri',
    station = 'sushi_prep',
    result = { item = 'tuna_nigiri', count = 2 },
    time = 6000,

    ingredients = {
        { item = 'sushi_rice', count = 1 },
        { item = 'tuna_raw', count = 1 },
    },

    skill = {
        required = 2,
        bonus = { 80, 0.15 },
    },
}

-- Sashimi Platter
Config.Recipes.Items['sashimi_platter'] = {
    label = 'Sashimi Platter',
    category = 'sashimi',
    station = 'sushi_prep',
    result = { item = 'sashimi_platter', count = 1 },
    time = 12000,

    ingredients = {
        { item = 'salmon_raw', count = 2 },
        { item = 'tuna_raw', count = 2 },
        { item = 'yellowtail_raw', count = 1 },
    },

    skill = {
        required = 3,
        bonus = { 85, 0.2 },
    },
}

-- Omakase Platter (Chef's Choice)
Config.Recipes.Items['omakase_platter'] = {
    label = 'Omakase Platter',
    category = 'sashimi',
    station = 'sushi_prep',
    result = { item = 'omakase_platter', count = 1 },
    time = 25000,

    ingredients = {
        { item = 'sushi_rice', count = 2 },
        { item = 'salmon_raw', count = 2 },
        { item = 'tuna_raw', count = 2 },
        { item = 'yellowtail_raw', count = 1 },
        { item = 'shrimp_raw', count = 2 },
        { item = 'tobiko', count = 1 },
    },

    skill = {
        required = 5,
        bonus = { 95, 0.3 },
    },
}

-- Shrimp Tempura
Config.Recipes.Items['tempura_shrimp'] = {
    label = 'Shrimp Tempura',
    category = 'tempura',
    station = 'tempura_fryer',
    result = { item = 'tempura_shrimp', count = 1 },
    time = 8000,

    ingredients = {
        { item = 'shrimp_raw', count = 5 },
        { item = 'tempura_batter', count = 1 },
    },

    skill = {
        required = 1,
        bonus = { 70, 0.1 },
    },
}

-- Vegetable Tempura
Config.Recipes.Items['tempura_vegetables'] = {
    label = 'Vegetable Tempura',
    category = 'tempura',
    station = 'tempura_fryer',
    result = { item = 'tempura_vegetables', count = 1 },
    time = 7000,

    ingredients = {
        { item = 'zucchini', count = 1 },
        { item = 'mushrooms', count = 1 },
        { item = 'tempura_batter', count = 1 },
    },
}

-- Gyoza
Config.Recipes.Items['gyoza'] = {
    label = 'Gyoza',
    category = 'appetizers',
    station = 'teppanyaki_grill',
    result = { item = 'gyoza', count = 1 },
    time = 10000,

    ingredients = {
        { item = 'ground_beef', count = 1 },
        { item = 'onion', count = 1 },
    },
}

-- Edamame
Config.Recipes.Items['edamame'] = {
    label = 'Edamame',
    category = 'appetizers',
    station = 'soup_station',
    result = { item = 'edamame', count = 1 },
    time = 5000,

    ingredients = {
        { item = 'edamame_raw', count = 1 },
    },
}

-- Hibachi Steak
Config.Recipes.Items['hibachi_steak'] = {
    label = 'Hibachi Steak',
    category = 'hibachi',
    station = 'teppanyaki_grill',
    result = { item = 'hibachi_steak', count = 1 },
    time = 15000,

    ingredients = {
        { item = 'steak_raw', count = 1 },
        { item = 'fried_rice_base', count = 1 },
        { item = 'zucchini', count = 1 },
        { item = 'mushrooms', count = 1 },
        { item = 'teriyaki_sauce', count = 1 },
    },

    skill = {
        required = 2,
        bonus = { 80, 0.15 },
    },
}

-- Hibachi Chicken
Config.Recipes.Items['hibachi_chicken'] = {
    label = 'Hibachi Chicken',
    category = 'hibachi',
    station = 'teppanyaki_grill',
    result = { item = 'hibachi_chicken', count = 1 },
    time = 12000,

    ingredients = {
        { item = 'chicken_teriyaki_raw', count = 1 },
        { item = 'fried_rice_base', count = 1 },
        { item = 'zucchini', count = 1 },
        { item = 'mushrooms', count = 1 },
        { item = 'teriyaki_sauce', count = 1 },
    },

    skill = {
        required = 1,
        bonus = { 75, 0.1 },
    },
}

-- Hibachi Shrimp
Config.Recipes.Items['hibachi_shrimp'] = {
    label = 'Hibachi Shrimp',
    category = 'hibachi',
    station = 'teppanyaki_grill',
    result = { item = 'hibachi_shrimp', count = 1 },
    time = 10000,

    ingredients = {
        { item = 'shrimp_raw', count = 5 },
        { item = 'fried_rice_base', count = 1 },
        { item = 'zucchini', count = 1 },
        { item = 'teriyaki_sauce', count = 1 },
    },

    skill = {
        required = 1,
        bonus = { 75, 0.1 },
    },
}

-- Hibachi Wagyu
Config.Recipes.Items['hibachi_wagyu'] = {
    label = 'Hibachi Wagyu',
    category = 'hibachi',
    station = 'teppanyaki_grill',
    result = { item = 'hibachi_wagyu', count = 1 },
    time = 20000,

    ingredients = {
        { item = 'wagyu_beef', count = 1 },
        { item = 'fried_rice_base', count = 1 },
        { item = 'zucchini', count = 1 },
        { item = 'mushrooms', count = 1 },
        { item = 'bean_sprouts', count = 1 },
    },

    skill = {
        required = 5,
        bonus = { 95, 0.25 },
    },
}

-- Hibachi Fried Rice
Config.Recipes.Items['hibachi_fried_rice'] = {
    label = 'Hibachi Fried Rice',
    category = 'fried_rice',
    station = 'teppanyaki_grill',
    result = { item = 'hibachi_fried_rice', count = 1 },
    time = 8000,

    ingredients = {
        { item = 'fried_rice_base', count = 2 },
        { item = 'eggs', count = 1 },
        { item = 'bean_sprouts', count = 1 },
        { item = 'soy_sauce', count = 1 },
    },
}

-- Green Tea
Config.Recipes.Items['green_tea'] = {
    label = 'Green Tea',
    category = 'beverages',
    station = 'sake_bar',
    result = { item = 'green_tea', count = 1 },
    time = 3000,

    ingredients = {
        { item = 'water', count = 1 },
    },
}

-- Sake
Config.Recipes.Items['sake_cup'] = {
    label = 'Sake',
    category = 'sake',
    station = 'sake_bar',
    result = { item = 'sake_cup', count = 2 },
    time = 2000,

    ingredients = {
        { item = 'sake_bottle', count = 1 },
    },
}

-- Mochi Ice Cream
Config.Recipes.Items['mochi_ice_cream'] = {
    label = 'Mochi Ice Cream',
    category = 'desserts',
    station = 'sushi_prep',
    result = { item = 'mochi_ice_cream', count = 1 },
    time = 8000,

    ingredients = {
        { item = 'ice_cream', count = 1 },
    },
}

-- ============================================================================
-- SUSHI RESTAURANT - LOCATION
-- ============================================================================

Config.Locations['benihana'] = {
    -- Downtown Vinewood location (fictional Benihana)
    ['downtown'] = {
        label = 'Sakura Teppanyaki',
        description = 'Japanese steakhouse and sushi bar',
        blip = {
            sprite = 93,
            color = 47,
            scale = 0.8,
            label = 'Sakura Teppanyaki',
        },

        job = 'benihana',
        grades = {
            [0] = 'Host',
            [1] = 'Server',
            [2] = 'Sushi Chef',
            [3] = 'Teppanyaki Chef',
            [4] = 'Head Chef',
            [5] = 'Manager',
        },

        duty = {
            coords = vec3(-571.23, -1051.67, 22.35),
            heading = 180.0,
            targetSize = vec3(1.0, 1.0, 2.0),
        },

        stations = {
            -- Sushi Bar
            ['sushi_prep_1'] = {
                type = 'sushi_prep',
                label = 'Sushi Station 1',
                coords = vec3(-575.45, -1048.23, 22.35),
                heading = 270.0,
                targetSize = vec3(2.0, 1.5, 1.5),
                slots = 4,
                requiredGrade = 2,
            },
            ['sushi_prep_2'] = {
                type = 'sushi_prep',
                label = 'Sushi Station 2',
                coords = vec3(-575.45, -1045.67, 22.35),
                heading = 270.0,
                targetSize = vec3(2.0, 1.5, 1.5),
                slots = 4,
                requiredGrade = 2,
            },

            -- Rice Cookers
            ['rice_cooker_1'] = {
                type = 'rice_cooker',
                label = 'Rice Cooker',
                coords = vec3(-578.34, -1047.45, 22.35),
                heading = 180.0,
                targetSize = vec3(1.0, 1.0, 1.0),
                slots = 2,
            },

            -- Teppanyaki Grills (Hibachi tables)
            ['teppan_1'] = {
                type = 'teppanyaki_grill',
                label = 'Teppanyaki Table 1',
                coords = vec3(-568.12, -1052.34, 22.35),
                heading = 0.0,
                targetSize = vec3(3.0, 2.0, 1.5),
                slots = 6,
                requiredGrade = 3,
            },
            ['teppan_2'] = {
                type = 'teppanyaki_grill',
                label = 'Teppanyaki Table 2',
                coords = vec3(-568.12, -1046.78, 22.35),
                heading = 0.0,
                targetSize = vec3(3.0, 2.0, 1.5),
                slots = 6,
                requiredGrade = 3,
            },

            -- Tempura Fryer
            ['tempura_1'] = {
                type = 'tempura_fryer',
                label = 'Tempura Station',
                coords = vec3(-580.67, -1049.23, 22.35),
                heading = 90.0,
                targetSize = vec3(1.5, 1.0, 1.5),
                slots = 3,
                requiredGrade = 1,
            },

            -- Soup Station
            ['soup_1'] = {
                type = 'soup_station',
                label = 'Soup Station',
                coords = vec3(-580.67, -1052.45, 22.35),
                heading = 90.0,
                targetSize = vec3(1.5, 1.0, 1.5),
                slots = 4,
            },

            -- Sake Bar
            ['sake_bar'] = {
                type = 'sake_bar',
                label = 'Sake Bar',
                coords = vec3(-572.34, -1055.67, 22.35),
                heading = 180.0,
                targetSize = vec3(2.5, 1.0, 1.5),
                slots = 6,
                requiredGrade = 1,
            },
        },

        -- Storage Areas
        storage = {
            ['main_storage'] = {
                label = 'Ingredient Storage',
                coords = vec3(-582.45, -1048.34, 22.35),
                heading = 90.0,
                targetSize = vec3(1.5, 1.5, 2.0),
                inventoryType = 'storage',
                storageType = 'stash',
                slots = 50,
                weight = 100000,
                groups = { benihana = 1 },
            },
            ['freezer'] = {
                label = 'Walk-in Freezer',
                coords = vec3(-582.45, -1051.56, 22.35),
                heading = 90.0,
                targetSize = vec3(2.0, 2.0, 2.5),
                inventoryType = 'storage',
                storageType = 'freezer',
                slots = 75,
                weight = 150000,
                groups = { benihana = 1 },
            },
            ['fish_fridge'] = {
                label = 'Fish Refrigerator',
                coords = vec3(-582.45, -1045.12, 22.35),
                heading = 90.0,
                targetSize = vec3(1.5, 1.5, 2.0),
                inventoryType = 'storage',
                storageType = 'refrigerator',
                slots = 40,
                weight = 80000,
                groups = { benihana = 2 },
            },
            ['sake_storage'] = {
                label = 'Sake Storage',
                coords = vec3(-572.34, -1058.23, 22.35),
                heading = 180.0,
                targetSize = vec3(1.5, 1.5, 2.0),
                inventoryType = 'storage',
                storageType = 'stash',
                slots = 30,
                weight = 50000,
                groups = { benihana = 1 },
            },
        },

        -- Serving counter
        counter = {
            coords = vec3(-570.12, -1050.45, 22.35),
            heading = 270.0,
            targetSize = vec3(2.0, 1.0, 1.5),
        },

        -- Cash register
        register = {
            coords = vec3(-569.45, -1055.23, 22.35),
            heading = 180.0,
            targetSize = vec3(1.0, 1.0, 1.5),
        },
    },
}

print('[free-restaurants] config/sushi_restaurant.lua loaded')

-- ============================================================================
-- ORDERING CONFIG (embedded here since ordering_config.lua won't load)
-- ============================================================================

print('[free-restaurants] Setting up Config.Ordering...')

Config.Ordering = Config.Ordering or {}

Config.Ordering.Settings = {
    orderPrefix = '',
    orderNumberLength = 4,
    receipt = { printSound = true, showOnKDS = true, notifyStaff = true, expiryMinutes = 30 },
    kiosk = { idleTimeout = 60, maxItemsPerOrder = 20, allowCustomizations = true, paymentMethods = {'cash', 'card'} },
    register = { requireDuty = true, minGrade = 0, canTakePayment = true, canCreateTabs = false },
    kds = { autoRefresh = 5, soundOnNew = true, flashUrgent = true, urgentThreshold = 300, maxDisplayed = 12 },
}

-- Burger Shot ordering locations
Config.Ordering['burgershot'] = {
    ['vespucci'] = {
        kiosks = {
            ['kiosk_1'] = {
                coords = vec3(-1192.45, -894.32, 14.0),
                heading = 35.0,
                label = 'Self-Order Kiosk #1',
                targetSize = vec3(0.8, 0.3, 1.5),
                enabled = true,
            },
        },
        registers = {
            ['register_1'] = {
                coords = vec3(-1195.67, -897.89, 14.0),
                heading = 215.0,
                label = 'Register #1',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
        },
        kdsMonitors = {
            ['kds_main'] = {
                coords = vec3(-1201.34, -899.23, 15.2),
                heading = 35.0,
                label = 'Kitchen Display',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_01',
                renderTarget = true,
                minGrade = 0,
                enabled = true,
            },
        },
        pickupCounter = {
            coords = vec3(-1194.67, -899.71, 14.0),
            heading = 215.0,
            label = 'Order Pickup',
            targetSize = vec3(2.0, 1.0, 1.5),
            enabled = true,
        },
    },
}

-- Utility functions for ordering
function Config.GetOrderingConfig(jobName, locationKey)
    if not Config.Ordering[jobName] then return nil end
    return Config.Ordering[jobName][locationKey]
end

function Config.GetKiosks(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return {} end
    return orderingConfig.kiosks or {}
end

function Config.GetRegisters(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return {} end
    return orderingConfig.registers or {}
end

function Config.GetKDSMonitors(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return {} end
    return orderingConfig.kdsMonitors or {}
end

function Config.GetPickupCounter(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return nil end
    return orderingConfig.pickupCounter
end

print('[free-restaurants] Config.Ordering setup complete')
