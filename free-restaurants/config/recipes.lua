--[[
    free-restaurants Recipe Configuration
    
    This file defines all craftable food and drink items, their ingredients,
    required stations, cooking parameters, and unlock requirements.
    
    RECIPE ORGANIZATION:
        - By Restaurant Type (fastfood, pizzeria, coffeeshop, bar)
        - By Food Category (burgers, sides, drinks, desserts, etc.)
        - Items can belong to multiple categories for flexible filtering
    
    INGREDIENT FORMATS:
        Simple:  { item = 'ingredient_name', count = 1 }
        Premium: { item = 'ingredient_name', count = 1, minQuality = 50, label = 'Fresh Lettuce' }
    
    COMPLEXITY TIERS:
        basic     - 1-2 steps, few ingredients, unlocked at start
        standard  - 3-4 steps, moderate ingredients, level 10+
        advanced  - 5+ steps, many ingredients, level 25+
        signature - Complex recipes, unique to locations, level 50+
    
    LOCATION EXCLUSIVITY:
        Set 'exclusive' to a location key to hide from other restaurants
        Set 'hidden' = true to completely hide from menus (secret recipes)
]]

Config = Config or {}
Config.Recipes = Config.Recipes or {}

-- ============================================================================
-- COMPLEXITY TIER DEFINITIONS
-- ============================================================================

Config.Recipes.Tiers = {
    basic = {
        label = 'Basic',
        color = '#6b7280',              -- Gray
        levelRequired = 0,
        maxSteps = 2,
        maxIngredients = 4,
        xpMultiplier = 1.0,
        priceMultiplier = 1.0,
        description = 'Simple recipes anyone can make',
    },
    standard = {
        label = 'Standard',
        color = '#22c55e',              -- Green
        levelRequired = 10,
        maxSteps = 4,
        maxIngredients = 6,
        xpMultiplier = 1.25,
        priceMultiplier = 1.5,
        description = 'Requires some experience to master',
    },
    advanced = {
        label = 'Advanced',
        color = '#3b82f6',              -- Blue
        levelRequired = 25,
        maxSteps = 6,
        maxIngredients = 10,
        xpMultiplier = 1.75,
        priceMultiplier = 2.5,
        description = 'Complex recipes for skilled cooks',
    },
    signature = {
        label = 'Signature',
        color = '#f59e0b',              -- Amber/Gold
        levelRequired = 50,
        maxSteps = 8,
        maxIngredients = 15,
        xpMultiplier = 2.5,
        priceMultiplier = 4.0,
        description = 'Legendary recipes that define the restaurant',
    },
}

-- ============================================================================
-- FOOD CATEGORIES
-- ============================================================================

Config.Recipes.Categories = {
    -- Main dishes
    burgers = { label = 'Burgers', icon = 'burger', sortOrder = 1 },
    chicken = { label = 'Chicken', icon = 'drumstick', sortOrder = 2 },
    pizza = { label = 'Pizza', icon = 'pizza', sortOrder = 3 },
    mexican = { label = 'Mexican', icon = 'taco', sortOrder = 4 },
    
    -- Sides
    sides = { label = 'Sides', icon = 'fries', sortOrder = 10 },
    salads = { label = 'Salads', icon = 'salad', sortOrder = 11 },
    appetizers = { label = 'Appetizers', icon = 'utensils', sortOrder = 12 },
    
    -- Drinks
    hotdrinks = { label = 'Hot Drinks', icon = 'coffee', sortOrder = 20 },
    colddrinks = { label = 'Cold Drinks', icon = 'cup-soda', sortOrder = 21 },
    smoothies = { label = 'Smoothies & Shakes', icon = 'blender', sortOrder = 22 },
    alcohol = { label = 'Alcoholic Drinks', icon = 'wine-glass', sortOrder = 23 },
    cocktails = { label = 'Cocktails', icon = 'martini-glass', sortOrder = 24 },
    
    -- Desserts
    desserts = { label = 'Desserts', icon = 'ice-cream', sortOrder = 30 },
    bakery = { label = 'Bakery', icon = 'cake', sortOrder = 31 },
    
    -- Special
    combos = { label = 'Combo Meals', icon = 'box', sortOrder = 40 },
    kids = { label = 'Kids Menu', icon = 'child', sortOrder = 41 },
    breakfast = { label = 'Breakfast', icon = 'egg', sortOrder = 42 },
}

-- ============================================================================
-- RECIPE DEFINITIONS
-- ============================================================================

Config.Recipes.Items = {
    
    -- ========================================================================
    -- BURGER SHOT MENU (Fast Food)
    -- Based on GTA V/IV Burger Shot lore
    -- ========================================================================
    
    --[[
        BURGERS - Burger Shot Signature Items
    ]]
    
    ['bleeder'] = {
        label = 'The Bleeder',
        description = 'Our classic single patty burger. Cheap, greasy, and satisfying.',
        
        -- Categorization
        restaurantTypes = { 'fastfood' },
        categories = { 'burgers' },
        tier = 'basic',
        
        -- Result
        result = {
            item = 'bleeder_burger',
            count = 1,
        },
        
        -- Pricing
        basePrice = 5,
        
        -- Simple ingredient format
        ingredients = {
            { item = 'burger_bun', count = 1 },
            { item = 'beef_patty', count = 1 },
            { item = 'lettuce', count = 1 },
            { item = 'ketchup', count = 1 },
        },
        
        -- Cooking workflow
        stations = {
            { type = 'grill', step = 'cook_patty', duration = 8000 },
            { type = 'prep_counter', step = 'assemble', duration = 3000 },
        },
        
        -- Effects when consumed
        effects = {
            hunger = 25,
            thirst = -5,
        },
        
        -- Unlock requirements
        levelRequired = 0,
    },
    
    ['bleeder_premium'] = {
        label = 'The Bleeder (Premium)',
        description = 'Our classic burger made with premium fresh ingredients.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'burgers' },
        tier = 'standard',
        
        result = {
            item = 'bleeder_burger_premium',
            count = 1,
            metadata = { quality = 'premium' },
        },
        
        basePrice = 12,
        
        -- Premium ingredient format with quality requirements
        ingredients = {
            { item = 'burger_bun', count = 1, minQuality = 70, label = 'Fresh Brioche Bun' },
            { item = 'beef_patty', count = 1, minQuality = 80, label = 'Prime Beef Patty' },
            { item = 'lettuce', count = 1, minQuality = 75, label = 'Crisp Lettuce' },
            { item = 'tomato_slice', count = 2, minQuality = 75, label = 'Vine-Ripened Tomato' },
            { item = 'special_sauce', count = 1, label = 'House Special Sauce' },
        },
        
        stations = {
            { type = 'grill', step = 'cook_patty', duration = 10000, skillCheck = true },
            { type = 'prep_counter', step = 'assemble', duration = 4000, skillCheck = true },
        },
        
        effects = {
            hunger = 35,
            thirst = -5,
        },
        
        levelRequired = 10,
    },
    
    ['double_barreled'] = {
        label = 'Double Barreled',
        description = 'Two patties, double the grease, double the satisfaction.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'burgers' },
        tier = 'basic',
        
        result = {
            item = 'double_barreled_burger',
            count = 1,
        },
        
        basePrice = 8,
        
        ingredients = {
            { item = 'burger_bun', count = 1 },
            { item = 'beef_patty', count = 2 },
            { item = 'cheese_slice', count = 2 },
            { item = 'lettuce', count = 1 },
            { item = 'pickles', count = 1 },
        },
        
        stations = {
            { type = 'grill', step = 'cook_patties', duration = 10000 },
            { type = 'prep_counter', step = 'assemble', duration = 4000 },
        },
        
        effects = {
            hunger = 40,
            thirst = -10,
        },
        
        levelRequired = 0,
    },
    
    ['meat_stack'] = {
        label = 'Meat Stack',
        description = 'Three patties stacked high. For when one burger just isn\'t enough.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'burgers' },
        tier = 'standard',
        
        result = {
            item = 'meat_stack_burger',
            count = 1,
        },
        
        basePrice = 12,
        
        ingredients = {
            { item = 'burger_bun', count = 1 },
            { item = 'beef_patty', count = 3 },
            { item = 'cheese_slice', count = 3 },
            { item = 'bacon', count = 2 },
            { item = 'lettuce', count = 1 },
            { item = 'onion_rings', count = 1 },
        },
        
        stations = {
            { type = 'grill', step = 'cook_patties', duration = 12000 },
            { type = 'fryer', step = 'fry_onion_rings', duration = 6000 },
            { type = 'prep_counter', step = 'assemble', duration = 5000 },
        },
        
        effects = {
            hunger = 55,
            thirst = -15,
        },
        
        levelRequired = 10,
    },
    
    ['beef_tower'] = {
        label = 'Beef Tower',
        description = 'Four patties of pure beef madness. Structural integrity not guaranteed.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'burgers' },
        tier = 'advanced',
        
        result = {
            item = 'beef_tower_burger',
            count = 1,
        },
        
        basePrice = 18,
        
        ingredients = {
            { item = 'burger_bun', count = 2 },
            { item = 'beef_patty', count = 4 },
            { item = 'cheese_slice', count = 4 },
            { item = 'bacon', count = 4 },
            { item = 'lettuce', count = 2 },
            { item = 'tomato_slice', count = 2 },
            { item = 'pickles', count = 2 },
            { item = 'special_sauce', count = 1 },
        },
        
        stations = {
            { type = 'grill', step = 'cook_patties', duration = 15000, skillCheck = true },
            { type = 'grill', step = 'cook_bacon', duration = 6000 },
            { type = 'prep_counter', step = 'assemble', duration = 6000, skillCheck = true },
        },
        
        effects = {
            hunger = 75,
            thirst = -20,
        },
        
        levelRequired = 25,
    },
    
    ['heart_stopper'] = {
        label = 'The Heart Stopper',
        description = 'SIX POUNDS OF MEAT AND CHEESE! We are not responsible for cardiac events.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'burgers' },
        tier = 'signature',
        
        -- Exclusive to Burger Shot locations
        exclusive = 'burgershot',
        
        result = {
            item = 'heart_stopper_burger',
            count = 1,
            metadata = { legendary = true },
        },
        
        basePrice = 35,
        
        -- Premium ingredients required for signature item
        ingredients = {
            { item = 'burger_bun', count = 3, minQuality = 60, label = 'Triple-Stacked Buns' },
            { item = 'beef_patty', count = 7, minQuality = 70, label = 'Premium Beef Patties' },
            { item = 'cheese_slice', count = 7, minQuality = 60, label = 'American Cheese' },
            { item = 'bacon', count = 6, minQuality = 70, label = 'Thick-Cut Bacon' },
            { item = 'lettuce', count = 3, label = 'Shredded Lettuce' },
            { item = 'tomato_slice', count = 4, label = 'Tomato Slices' },
            { item = 'onion_slice', count = 2, label = 'Onion Rings' },
            { item = 'pickles', count = 4, label = 'Dill Pickles' },
            { item = 'special_sauce', count = 2, label = 'Heart Stopper Sauce' },
        },
        
        stations = {
            { type = 'grill', step = 'cook_patties_batch1', duration = 15000, skillCheck = true },
            { type = 'grill', step = 'cook_patties_batch2', duration = 15000, skillCheck = true },
            { type = 'grill', step = 'cook_bacon', duration = 8000 },
            { type = 'prep_counter', step = 'prep_veggies', duration = 4000 },
            { type = 'plating_station', step = 'assemble', duration = 8000, skillCheck = true },
        },
        
        effects = {
            hunger = 100,
            thirst = -30,
            stress = 10,           -- So much food causes stress
        },
        
        levelRequired = 50,
    },
    
    ['chicken_burger'] = {
        label = 'Clucky Burger',
        description = 'Crispy fried chicken breast on a toasted bun.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'burgers', 'chicken' },
        tier = 'basic',
        
        result = {
            item = 'chicken_burger',
            count = 1,
        },
        
        basePrice = 7,
        
        ingredients = {
            { item = 'burger_bun', count = 1 },
            { item = 'chicken_breast', count = 1 },
            { item = 'breading', count = 1 },
            { item = 'lettuce', count = 1 },
            { item = 'mayo', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'bread_chicken', duration = 4000 },
            { type = 'fryer', step = 'fry_chicken', duration = 10000 },
            { type = 'prep_counter', step = 'assemble', duration = 3000 },
        },
        
        effects = {
            hunger = 30,
            thirst = -5,
        },
        
        levelRequired = 0,
    },
    
    ['fishy_shit'] = {
        label = 'Fishy Sh*t',
        description = 'Our famous fish sandwich. Don\'t ask what kind of fish.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'burgers' },
        tier = 'basic',
        
        result = {
            item = 'fish_sandwich',
            count = 1,
        },
        
        basePrice = 6,
        
        ingredients = {
            { item = 'burger_bun', count = 1 },
            { item = 'fish_fillet', count = 1 },
            { item = 'breading', count = 1 },
            { item = 'tartar_sauce', count = 1 },
            { item = 'lettuce', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'bread_fish', duration = 3000 },
            { type = 'fryer', step = 'fry_fish', duration = 8000 },
            { type = 'prep_counter', step = 'assemble', duration = 3000 },
        },
        
        effects = {
            hunger = 25,
            thirst = -5,
        },
        
        levelRequired = 0,
    },
    
    --[[
        SIDES - Burger Shot
    ]]
    
    ['fries_small'] = {
        label = 'Small Fries',
        description = 'Golden crispy fries. Small but satisfying.',
        
        restaurantTypes = { 'fastfood', 'bar' },
        categories = { 'sides' },
        tier = 'basic',
        
        result = {
            item = 'fries_small',
            count = 1,
        },
        
        basePrice = 3,
        
        ingredients = {
            { item = 'potato', count = 1 },
            { item = 'salt', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'cut_fries', duration = 3000 },
            { type = 'fryer', step = 'fry', duration = 6000 },
        },
        
        effects = {
            hunger = 10,
        },
        
        levelRequired = 0,
    },
    
    ['fries_large'] = {
        label = 'Large Fries',
        description = 'A mountain of golden crispy goodness.',
        
        restaurantTypes = { 'fastfood', 'bar' },
        categories = { 'sides' },
        tier = 'basic',
        
        result = {
            item = 'fries_large',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'potato', count = 2 },
            { item = 'salt', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'cut_fries', duration = 4000 },
            { type = 'fryer', step = 'fry', duration = 8000 },
        },
        
        effects = {
            hunger = 20,
        },
        
        levelRequired = 0,
    },
    
    ['loaded_fries'] = {
        label = 'Loaded Fries',
        description = 'Fries smothered in cheese, bacon, and sour cream.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'sides' },
        tier = 'standard',
        
        result = {
            item = 'loaded_fries',
            count = 1,
        },
        
        basePrice = 8,
        
        ingredients = {
            { item = 'potato', count = 2 },
            { item = 'cheese_sauce', count = 1 },
            { item = 'bacon', count = 2 },
            { item = 'sour_cream', count = 1 },
            { item = 'chives', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'cut_fries', duration = 4000 },
            { type = 'fryer', step = 'fry', duration = 8000 },
            { type = 'grill', step = 'cook_bacon', duration = 5000 },
            { type = 'plating_station', step = 'assemble', duration = 4000 },
        },
        
        effects = {
            hunger = 35,
            thirst = -5,
        },
        
        levelRequired = 10,
    },
    
    ['onion_rings'] = {
        label = 'Onion Rings',
        description = 'Thick-cut onions in crispy batter.',
        
        restaurantTypes = { 'fastfood', 'bar' },
        categories = { 'sides', 'appetizers' },
        tier = 'basic',
        
        result = {
            item = 'onion_rings',
            count = 1,
        },
        
        basePrice = 4,
        
        ingredients = {
            { item = 'onion', count = 1 },
            { item = 'breading', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'slice_onions', duration = 3000 },
            { type = 'prep_counter', step = 'batter', duration = 2000 },
            { type = 'fryer', step = 'fry', duration = 6000 },
        },
        
        effects = {
            hunger = 15,
        },
        
        levelRequired = 0,
    },
    
    ['chicken_nuggets'] = {
        label = 'Chicken Nuggets (6pc)',
        description = 'Bite-sized pieces of breaded chicken.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'sides', 'chicken', 'kids' },
        tier = 'basic',
        
        result = {
            item = 'chicken_nuggets_6',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'chicken_breast', count = 1 },
            { item = 'breading', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'cut_nuggets', duration = 4000 },
            { type = 'prep_counter', step = 'bread', duration = 3000 },
            { type = 'fryer', step = 'fry', duration = 7000 },
        },
        
        effects = {
            hunger = 20,
        },
        
        levelRequired = 0,
    },
    
    ['chicken_nuggets_large'] = {
        label = 'Chicken Nuggets (12pc)',
        description = 'Double the nuggets, double the happiness.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'sides', 'chicken' },
        tier = 'basic',
        
        result = {
            item = 'chicken_nuggets_12',
            count = 1,
        },
        
        basePrice = 9,
        
        ingredients = {
            { item = 'chicken_breast', count = 2 },
            { item = 'breading', count = 2 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'cut_nuggets', duration = 6000 },
            { type = 'prep_counter', step = 'bread', duration = 4000 },
            { type = 'fryer', step = 'fry', duration = 10000 },
        },
        
        effects = {
            hunger = 35,
        },
        
        levelRequired = 0,
    },
    
    ['mozzarella_sticks'] = {
        label = 'Mozzarella Sticks',
        description = 'Breaded mozzarella, fried to gooey perfection.',
        
        restaurantTypes = { 'fastfood', 'bar' },
        categories = { 'sides', 'appetizers' },
        tier = 'basic',
        
        result = {
            item = 'mozzarella_sticks',
            count = 1,
        },
        
        basePrice = 6,
        
        ingredients = {
            { item = 'mozzarella', count = 1 },
            { item = 'breading', count = 1 },
            { item = 'marinara_sauce', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'cut_cheese', duration = 2000 },
            { type = 'prep_counter', step = 'bread', duration = 3000 },
            { type = 'fryer', step = 'fry', duration = 5000 },
        },
        
        effects = {
            hunger = 18,
        },
        
        levelRequired = 0,
    },
    
    --[[
        DRINKS - Burger Shot
    ]]
    
    ['soda_small'] = {
        label = 'Small Sprunk',
        description = 'The essence of life. Small size.',
        
        restaurantTypes = { 'fastfood', 'pizzeria' },
        categories = { 'colddrinks' },
        tier = 'basic',
        
        result = {
            item = 'sprunk_small',
            count = 1,
        },
        
        basePrice = 2,
        
        ingredients = {
            { item = 'cup_small', count = 1 },
            { item = 'sprunk_syrup', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'soda_fountain', step = 'fill', duration = 3000 },
        },
        
        effects = {
            thirst = 25,
            hunger = -5,
        },
        
        levelRequired = 0,
    },
    
    ['soda_large'] = {
        label = 'Large Sprunk',
        description = 'Maximum refreshment. Large size.',
        
        restaurantTypes = { 'fastfood', 'pizzeria' },
        categories = { 'colddrinks' },
        tier = 'basic',
        
        result = {
            item = 'sprunk_large',
            count = 1,
        },
        
        basePrice = 3,
        
        ingredients = {
            { item = 'cup_large', count = 1 },
            { item = 'sprunk_syrup', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'soda_fountain', step = 'fill', duration = 4000 },
        },
        
        effects = {
            thirst = 40,
            hunger = -5,
        },
        
        levelRequired = 0,
    },
    
    ['ecola_small'] = {
        label = 'Small eCola',
        description = 'Deliciously infectious. Small size.',
        
        restaurantTypes = { 'fastfood', 'pizzeria' },
        categories = { 'colddrinks' },
        tier = 'basic',
        
        result = {
            item = 'ecola_small',
            count = 1,
        },
        
        basePrice = 2,
        
        ingredients = {
            { item = 'cup_small', count = 1 },
            { item = 'ecola_syrup', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'soda_fountain', step = 'fill', duration = 3000 },
        },
        
        effects = {
            thirst = 25,
            hunger = -5,
        },
        
        levelRequired = 0,
    },
    
    ['ecola_large'] = {
        label = 'Large eCola',
        description = 'Deliciously infectious. Large size.',
        
        restaurantTypes = { 'fastfood', 'pizzeria' },
        categories = { 'colddrinks' },
        tier = 'basic',
        
        result = {
            item = 'ecola_large',
            count = 1,
        },
        
        basePrice = 3,
        
        ingredients = {
            { item = 'cup_large', count = 1 },
            { item = 'ecola_syrup', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'soda_fountain', step = 'fill', duration = 4000 },
        },
        
        effects = {
            thirst = 40,
            hunger = -5,
        },
        
        levelRequired = 0,
    },
    
    ['meat_shake'] = {
        label = 'Meat Shake',
        description = 'All the protein of a burger in liquid form. Don\'t think about it.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'smoothies' },
        tier = 'advanced',
        
        exclusive = 'burgershot',
        
        result = {
            item = 'meat_shake',
            count = 1,
        },
        
        basePrice = 8,
        
        ingredients = {
            { item = 'beef_patty', count = 1 },
            { item = 'milk', count = 1 },
            { item = 'ice', count = 1 },
            { item = 'gravy', count = 1 },
        },
        
        stations = {
            { type = 'grill', step = 'cook_patty', duration = 8000 },
            { type = 'blender', step = 'blend', duration = 6000, skillCheck = true },
        },
        
        effects = {
            hunger = 40,
            thirst = 20,
            stress = 5,
        },
        
        levelRequired = 25,
    },
    
    ['milkshake_vanilla'] = {
        label = 'Vanilla Shake',
        description = 'Classic creamy vanilla milkshake.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'smoothies', 'desserts' },
        tier = 'basic',
        
        result = {
            item = 'milkshake_vanilla',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'ice_cream_vanilla', count = 2 },
            { item = 'milk', count = 1 },
            { item = 'whipped_cream', count = 1 },
        },
        
        stations = {
            { type = 'blender', step = 'blend', duration = 5000 },
            { type = 'plating_station', step = 'top', duration = 2000 },
        },
        
        effects = {
            hunger = 15,
            thirst = 30,
        },
        
        levelRequired = 0,
    },
    
    ['milkshake_chocolate'] = {
        label = 'Chocolate Shake',
        description = 'Rich chocolate milkshake.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'smoothies', 'desserts' },
        tier = 'basic',
        
        result = {
            item = 'milkshake_chocolate',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'ice_cream_chocolate', count = 2 },
            { item = 'milk', count = 1 },
            { item = 'chocolate_syrup', count = 1 },
            { item = 'whipped_cream', count = 1 },
        },
        
        stations = {
            { type = 'blender', step = 'blend', duration = 5000 },
            { type = 'plating_station', step = 'top', duration = 2000 },
        },
        
        effects = {
            hunger = 15,
            thirst = 30,
        },
        
        levelRequired = 0,
    },
    
    --[[
        COMBO MEALS - Burger Shot
    ]]
    
    ['moo_kids_meal'] = {
        label = 'Moo Kids Meal',
        description = 'A kid-sized meal with toy! Ages 3 and up.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'combos', 'kids' },
        tier = 'standard',
        
        result = {
            item = 'moo_kids_meal',
            count = 1,
        },
        
        basePrice = 8,
        
        ingredients = {
            { item = 'burger_bun', count = 1 },
            { item = 'beef_patty', count = 1 },
            { item = 'cheese_slice', count = 1 },
            { item = 'potato', count = 1 },
            { item = 'cup_small', count = 1 },
            { item = 'sprunk_syrup', count = 1 },
            { item = 'kids_toy', count = 1 },
        },
        
        stations = {
            { type = 'grill', step = 'cook_patty', duration = 8000 },
            { type = 'fryer', step = 'fry_fries', duration = 6000 },
            { type = 'soda_fountain', step = 'fill_drink', duration = 3000 },
            { type = 'packaging_station', step = 'package', duration = 4000 },
        },
        
        effects = {
            hunger = 40,
            thirst = 25,
        },
        
        levelRequired = 10,
    },
    
    ['bleeder_meal'] = {
        label = 'Bleeder Meal',
        description = 'The Bleeder burger with fries and a drink.',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'combos' },
        tier = 'standard',
        
        result = {
            item = 'bleeder_meal',
            count = 1,
        },
        
        basePrice = 10,
        
        ingredients = {
            { item = 'burger_bun', count = 1 },
            { item = 'beef_patty', count = 1 },
            { item = 'lettuce', count = 1 },
            { item = 'ketchup', count = 1 },
            { item = 'potato', count = 1 },
            { item = 'cup_large', count = 1 },
            { item = 'sprunk_syrup', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'grill', step = 'cook_patty', duration = 8000 },
            { type = 'prep_counter', step = 'assemble_burger', duration = 3000 },
            { type = 'fryer', step = 'fry_fries', duration = 6000 },
            { type = 'soda_fountain', step = 'fill_drink', duration = 3000 },
            { type = 'packaging_station', step = 'package', duration = 3000 },
        },
        
        effects = {
            hunger = 50,
            thirst = 40,
        },
        
        levelRequired = 10,
    },
    
    -- ========================================================================
    -- PIZZA THIS... MENU (Pizzeria)
    -- ========================================================================
    
    --[[
        PIZZAS - Pizza This...
    ]]
    
    ['pizza_cheese'] = {
        label = 'Classic Cheese Pizza',
        description = 'Simple, cheesy perfection.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'pizza' },
        tier = 'basic',
        
        result = {
            item = 'pizza_cheese',
            count = 1,
        },
        
        basePrice = 12,
        
        ingredients = {
            { item = 'pizza_dough', count = 1 },
            { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 2 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'stretch_dough', duration = 4000 },
            { type = 'prep_counter', step = 'add_sauce', duration = 2000 },
            { type = 'prep_counter', step = 'add_cheese', duration = 2000 },
            { type = 'pizza_oven', step = 'bake', duration = 12000 },
        },
        
        effects = {
            hunger = 45,
            thirst = -10,
        },
        
        levelRequired = 0,
    },
    
    ['pizza_cheese_premium'] = {
        label = 'Classic Cheese Pizza (Premium)',
        description = 'Made with fresh mozzarella and San Marzano tomatoes.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'pizza' },
        tier = 'standard',
        
        result = {
            item = 'pizza_cheese_premium',
            count = 1,
            metadata = { quality = 'premium' },
        },
        
        basePrice = 20,
        
        ingredients = {
            { item = 'pizza_dough', count = 1, minQuality = 80, label = 'Fresh Pizza Dough' },
            { item = 'tomato_sauce', count = 1, minQuality = 85, label = 'San Marzano Sauce' },
            { item = 'mozzarella', count = 2, minQuality = 90, label = 'Fresh Buffalo Mozzarella' },
            { item = 'basil', count = 1, minQuality = 75, label = 'Fresh Basil' },
            { item = 'olive_oil', count = 1, label = 'Extra Virgin Olive Oil' },
        },
        
        stations = {
            { type = 'prep_counter', step = 'stretch_dough', duration = 5000, skillCheck = true },
            { type = 'prep_counter', step = 'add_sauce', duration = 3000 },
            { type = 'prep_counter', step = 'add_cheese', duration = 3000 },
            { type = 'pizza_oven', step = 'bake', duration = 10000, skillCheck = true },
            { type = 'plating_station', step = 'finish', duration = 2000 },
        },
        
        effects = {
            hunger = 55,
            thirst = -10,
        },
        
        levelRequired = 10,
    },
    
    ['pizza_pepperoni'] = {
        label = 'Pepperoni Pizza',
        description = 'America\'s favorite topping.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'pizza' },
        tier = 'basic',
        
        result = {
            item = 'pizza_pepperoni',
            count = 1,
        },
        
        basePrice = 14,
        
        ingredients = {
            { item = 'pizza_dough', count = 1 },
            { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 2 },
            { item = 'pepperoni', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'stretch_dough', duration = 4000 },
            { type = 'prep_counter', step = 'add_toppings', duration = 4000 },
            { type = 'pizza_oven', step = 'bake', duration = 12000 },
        },
        
        effects = {
            hunger = 50,
            thirst = -10,
        },
        
        levelRequired = 0,
    },
    
    ['pizza_meat_lovers'] = {
        label = 'Meat Lovers Pizza',
        description = 'Pepperoni, sausage, bacon, and ham. For carnivores only.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'pizza' },
        tier = 'standard',
        
        result = {
            item = 'pizza_meat_lovers',
            count = 1,
        },
        
        basePrice = 18,
        
        ingredients = {
            { item = 'pizza_dough', count = 1 },
            { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 2 },
            { item = 'pepperoni', count = 1 },
            { item = 'italian_sausage', count = 1 },
            { item = 'bacon', count = 1 },
            { item = 'ham', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'stretch_dough', duration = 4000 },
            { type = 'grill', step = 'cook_sausage', duration = 6000 },
            { type = 'prep_counter', step = 'add_toppings', duration = 5000 },
            { type = 'pizza_oven', step = 'bake', duration = 14000 },
        },
        
        effects = {
            hunger = 65,
            thirst = -15,
        },
        
        levelRequired = 10,
    },
    
    ['pizza_supreme'] = {
        label = 'Supreme Pizza',
        description = 'Loaded with everything. The works.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'pizza' },
        tier = 'advanced',
        
        result = {
            item = 'pizza_supreme',
            count = 1,
        },
        
        basePrice = 22,
        
        ingredients = {
            { item = 'pizza_dough', count = 1 },
            { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 2 },
            { item = 'pepperoni', count = 1 },
            { item = 'italian_sausage', count = 1 },
            { item = 'bell_pepper', count = 1 },
            { item = 'onion', count = 1 },
            { item = 'mushroom', count = 1 },
            { item = 'black_olives', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'stretch_dough', duration = 4000, skillCheck = true },
            { type = 'prep_counter', step = 'prep_veggies', duration = 5000 },
            { type = 'grill', step = 'cook_sausage', duration = 6000 },
            { type = 'prep_counter', step = 'add_toppings', duration = 6000 },
            { type = 'pizza_oven', step = 'bake', duration = 15000, skillCheck = true },
        },
        
        effects = {
            hunger = 70,
            thirst = -15,
        },
        
        levelRequired = 25,
    },
    
    ['pizza_margherita'] = {
        label = 'Margherita Pizza',
        description = 'Traditional Italian style with fresh tomato, mozzarella, and basil.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'pizza' },
        tier = 'standard',
        
        result = {
            item = 'pizza_margherita',
            count = 1,
        },
        
        basePrice = 16,
        
        ingredients = {
            { item = 'pizza_dough', count = 1 },
            { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 2 },
            { item = 'tomato_slice', count = 2 },
            { item = 'basil', count = 1 },
            { item = 'olive_oil', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'stretch_dough', duration = 4000 },
            { type = 'prep_counter', step = 'add_toppings', duration = 4000 },
            { type = 'pizza_oven', step = 'bake', duration = 11000 },
            { type = 'plating_station', step = 'finish', duration = 2000 },
        },
        
        effects = {
            hunger = 50,
            thirst = -10,
        },
        
        levelRequired = 10,
    },
    
    ['pizza_hawaiian'] = {
        label = 'Hawaiian Pizza',
        description = 'Pineapple on pizza. Fight about it.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'pizza' },
        tier = 'basic',
        
        result = {
            item = 'pizza_hawaiian',
            count = 1,
        },
        
        basePrice = 15,
        
        ingredients = {
            { item = 'pizza_dough', count = 1 },
            { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 2 },
            { item = 'ham', count = 1 },
            { item = 'pineapple', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'stretch_dough', duration = 4000 },
            { type = 'prep_counter', step = 'add_toppings', duration = 4000 },
            { type = 'pizza_oven', step = 'bake', duration = 12000 },
        },
        
        effects = {
            hunger = 50,
            thirst = -10,
        },
        
        levelRequired = 0,
    },
    
    ['pizza_bbq_chicken'] = {
        label = 'BBQ Chicken Pizza',
        description = 'Tangy BBQ sauce, grilled chicken, red onion, and cilantro.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'pizza', 'chicken' },
        tier = 'standard',
        
        result = {
            item = 'pizza_bbq_chicken',
            count = 1,
        },
        
        basePrice = 17,
        
        ingredients = {
            { item = 'pizza_dough', count = 1 },
            { item = 'bbq_sauce', count = 1 },
            { item = 'mozzarella', count = 2 },
            { item = 'chicken_breast', count = 1 },
            { item = 'red_onion', count = 1 },
            { item = 'cilantro', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'stretch_dough', duration = 4000 },
            { type = 'grill', step = 'grill_chicken', duration = 10000 },
            { type = 'prep_counter', step = 'add_toppings', duration = 5000 },
            { type = 'pizza_oven', step = 'bake', duration = 12000 },
        },
        
        effects = {
            hunger = 55,
            thirst = -10,
        },
        
        levelRequired = 10,
    },
    
    ['pizza_vinewood'] = {
        label = 'Vinewood Special',
        description = 'Our signature pizza with prosciutto, arugula, and truffle oil.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'pizza' },
        tier = 'signature',
        
        exclusive = 'pizzathis',
        
        result = {
            item = 'pizza_vinewood',
            count = 1,
            metadata = { legendary = true },
        },
        
        basePrice = 35,
        
        ingredients = {
            { item = 'pizza_dough', count = 1, minQuality = 85, label = 'Artisan Pizza Dough' },
            { item = 'tomato_sauce', count = 1, minQuality = 85, label = 'San Marzano Sauce' },
            { item = 'mozzarella', count = 2, minQuality = 90, label = 'Burrata Cheese' },
            { item = 'prosciutto', count = 1, minQuality = 90, label = 'Aged Prosciutto' },
            { item = 'arugula', count = 1, minQuality = 80, label = 'Fresh Arugula' },
            { item = 'parmesan', count = 1, minQuality = 85, label = 'Parmigiano-Reggiano' },
            { item = 'truffle_oil', count = 1, label = 'White Truffle Oil' },
            { item = 'balsamic_glaze', count = 1, label = 'Aged Balsamic Glaze' },
        },
        
        stations = {
            { type = 'prep_counter', step = 'stretch_dough', duration = 5000, skillCheck = true },
            { type = 'prep_counter', step = 'add_base', duration = 3000 },
            { type = 'pizza_oven', step = 'bake', duration = 10000, skillCheck = true },
            { type = 'plating_station', step = 'add_toppings', duration = 4000, skillCheck = true },
            { type = 'plating_station', step = 'finish', duration = 3000 },
        },
        
        effects = {
            hunger = 60,
            thirst = -10,
        },
        
        levelRequired = 50,
    },
    
    --[[
        SIDES & APPETIZERS - Pizza This...
    ]]
    
    ['breadsticks'] = {
        label = 'Garlic Breadsticks',
        description = 'Warm breadsticks brushed with garlic butter.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'sides', 'appetizers' },
        tier = 'basic',
        
        result = {
            item = 'breadsticks',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'pizza_dough', count = 1 },
            { item = 'garlic_butter', count = 1 },
            { item = 'parmesan', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'shape_dough', duration = 3000 },
            { type = 'pizza_oven', step = 'bake', duration = 8000 },
            { type = 'prep_counter', step = 'brush_butter', duration = 2000 },
        },
        
        effects = {
            hunger = 20,
            thirst = -5,
        },
        
        levelRequired = 0,
    },
    
    ['garlic_knots'] = {
        label = 'Garlic Knots',
        description = 'Twisted dough knots drenched in garlic butter.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'sides', 'appetizers' },
        tier = 'basic',
        
        result = {
            item = 'garlic_knots',
            count = 1,
        },
        
        basePrice = 6,
        
        ingredients = {
            { item = 'pizza_dough', count = 1 },
            { item = 'garlic_butter', count = 1 },
            { item = 'parsley', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'tie_knots', duration = 5000 },
            { type = 'pizza_oven', step = 'bake', duration = 8000 },
            { type = 'prep_counter', step = 'toss_in_butter', duration = 2000 },
        },
        
        effects = {
            hunger = 22,
            thirst = -5,
        },
        
        levelRequired = 0,
    },
    
    ['wings_buffalo'] = {
        label = 'Buffalo Wings',
        description = 'Crispy wings tossed in spicy buffalo sauce.',
        
        restaurantTypes = { 'pizzeria', 'bar' },
        categories = { 'appetizers', 'chicken' },
        tier = 'standard',
        
        result = {
            item = 'wings_buffalo',
            count = 1,
        },
        
        basePrice = 12,
        
        ingredients = {
            { item = 'chicken_wings', count = 1 },
            { item = 'breading', count = 1 },
            { item = 'buffalo_sauce', count = 1 },
            { item = 'celery', count = 1 },
            { item = 'ranch_dressing', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'bread_wings', duration = 4000 },
            { type = 'fryer', step = 'fry', duration = 12000 },
            { type = 'prep_counter', step = 'toss_in_sauce', duration = 2000 },
            { type = 'plating_station', step = 'plate', duration = 2000 },
        },
        
        effects = {
            hunger = 35,
            thirst = -10,
        },
        
        levelRequired = 10,
    },
    
    ['calzone'] = {
        label = 'Calzone',
        description = 'Folded pizza stuffed with ricotta, mozzarella, and pepperoni.',
        
        restaurantTypes = { 'pizzeria' },
        categories = { 'pizza' },
        tier = 'standard',
        
        result = {
            item = 'calzone',
            count = 1,
        },
        
        basePrice = 14,
        
        ingredients = {
            { item = 'pizza_dough', count = 1 },
            { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 1 },
            { item = 'ricotta', count = 1 },
            { item = 'pepperoni', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'stretch_dough', duration = 4000 },
            { type = 'prep_counter', step = 'add_filling', duration = 4000 },
            { type = 'prep_counter', step = 'fold_and_seal', duration = 3000, skillCheck = true },
            { type = 'pizza_oven', step = 'bake', duration = 14000 },
        },
        
        effects = {
            hunger = 55,
            thirst = -10,
        },
        
        levelRequired = 10,
    },
    
    ['caesar_salad'] = {
        label = 'Caesar Salad',
        description = 'Crisp romaine with caesar dressing, croutons, and parmesan.',
        
        restaurantTypes = { 'pizzeria', 'bar' },
        categories = { 'salads' },
        tier = 'basic',
        
        result = {
            item = 'caesar_salad',
            count = 1,
        },
        
        basePrice = 10,
        
        ingredients = {
            { item = 'romaine_lettuce', count = 1 },
            { item = 'caesar_dressing', count = 1 },
            { item = 'croutons', count = 1 },
            { item = 'parmesan', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'chop_lettuce', duration = 3000 },
            { type = 'prep_counter', step = 'toss_salad', duration = 3000 },
            { type = 'plating_station', step = 'plate', duration = 2000 },
        },
        
        effects = {
            hunger = 20,
            thirst = 5,
        },
        
        levelRequired = 0,
    },
    
    -- ========================================================================
    -- BEAN MACHINE MENU (Coffee Shop)
    -- ========================================================================
    
    --[[
        HOT DRINKS - Bean Machine
    ]]
    
    ['espresso'] = {
        label = 'Espresso',
        description = 'A shot of pure, concentrated coffee.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'basic',
        
        result = {
            item = 'espresso',
            count = 1,
        },
        
        basePrice = 3,
        
        ingredients = {
            { item = 'coffee_beans', count = 1 },
            { item = 'cup_espresso', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_espresso', duration = 4000 },
        },
        
        effects = {
            thirst = 10,
            stress = -10,
        },
        
        levelRequired = 0,
    },
    
    ['espresso_double'] = {
        label = 'Double Espresso',
        description = 'Two shots for when you really need it.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'basic',
        
        result = {
            item = 'espresso_double',
            count = 1,
        },
        
        basePrice = 4,
        
        ingredients = {
            { item = 'coffee_beans', count = 2 },
            { item = 'cup_espresso', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_double', duration = 5000 },
        },
        
        effects = {
            thirst = 15,
            stress = -15,
        },
        
        levelRequired = 0,
    },
    
    ['americano'] = {
        label = 'Americano',
        description = 'Espresso with hot water. Simple and strong.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'basic',
        
        result = {
            item = 'americano',
            count = 1,
        },
        
        basePrice = 4,
        
        ingredients = {
            { item = 'coffee_beans', count = 1 },
            { item = 'cup_medium', count = 1 },
            { item = 'hot_water', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_espresso', duration = 4000 },
            { type = 'coffee_machine', step = 'add_water', duration = 2000 },
        },
        
        effects = {
            thirst = 25,
            stress = -10,
        },
        
        levelRequired = 0,
    },
    
    ['latte'] = {
        label = 'CaffÃ¨ Latte',
        description = 'Espresso with steamed milk and light foam.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'basic',
        
        result = {
            item = 'latte',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'coffee_beans', count = 1 },
            { item = 'milk', count = 1 },
            { item = 'cup_medium', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_espresso', duration = 4000 },
            { type = 'coffee_machine', step = 'steam_milk', duration = 4000 },
            { type = 'coffee_machine', step = 'pour', duration = 3000 },
        },
        
        effects = {
            thirst = 30,
            stress = -10,
            hunger = 5,
        },
        
        levelRequired = 0,
    },
    
    ['latte_premium'] = {
        label = 'CaffÃ¨ Latte (Premium)',
        description = 'Artisan latte with latte art.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'standard',
        
        result = {
            item = 'latte_premium',
            count = 1,
            metadata = { quality = 'premium' },
        },
        
        basePrice = 8,
        
        ingredients = {
            { item = 'coffee_beans', count = 1, minQuality = 80, label = 'Single Origin Beans' },
            { item = 'milk', count = 1, minQuality = 75, label = 'Organic Whole Milk' },
            { item = 'cup_medium', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_espresso', duration = 5000, skillCheck = true },
            { type = 'coffee_machine', step = 'steam_milk', duration = 5000, skillCheck = true },
            { type = 'coffee_machine', step = 'pour_art', duration = 5000, skillCheck = true },
        },
        
        effects = {
            thirst = 35,
            stress = -15,
            hunger = 5,
        },
        
        levelRequired = 10,
    },
    
    ['cappuccino'] = {
        label = 'Cappuccino',
        description = 'Equal parts espresso, steamed milk, and foam.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'basic',
        
        result = {
            item = 'cappuccino',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'coffee_beans', count = 1 },
            { item = 'milk', count = 1 },
            { item = 'cup_medium', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_espresso', duration = 4000 },
            { type = 'coffee_machine', step = 'steam_milk_foam', duration = 5000 },
            { type = 'coffee_machine', step = 'pour', duration = 3000 },
        },
        
        effects = {
            thirst = 28,
            stress = -10,
            hunger = 5,
        },
        
        levelRequired = 0,
    },
    
    ['mocha'] = {
        label = 'CaffÃ¨ Mocha',
        description = 'Espresso with chocolate and steamed milk.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'standard',
        
        result = {
            item = 'mocha',
            count = 1,
        },
        
        basePrice = 6,
        
        ingredients = {
            { item = 'coffee_beans', count = 1 },
            { item = 'milk', count = 1 },
            { item = 'chocolate_syrup', count = 1 },
            { item = 'whipped_cream', count = 1 },
            { item = 'cup_medium', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_espresso', duration = 4000 },
            { type = 'coffee_machine', step = 'add_chocolate', duration = 2000 },
            { type = 'coffee_machine', step = 'steam_milk', duration = 4000 },
            { type = 'coffee_machine', step = 'pour', duration = 3000 },
            { type = 'plating_station', step = 'top', duration = 2000 },
        },
        
        effects = {
            thirst = 30,
            stress = -10,
            hunger = 10,
        },
        
        levelRequired = 10,
    },
    
    ['macchiato'] = {
        label = 'Espresso Macchiato',
        description = 'Espresso "stained" with a dash of foamed milk.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'basic',
        
        result = {
            item = 'macchiato',
            count = 1,
        },
        
        basePrice = 4,
        
        ingredients = {
            { item = 'coffee_beans', count = 1 },
            { item = 'milk', count = 1 },
            { item = 'cup_espresso', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_espresso', duration = 4000 },
            { type = 'coffee_machine', step = 'add_foam', duration = 2000 },
        },
        
        effects = {
            thirst = 12,
            stress = -12,
        },
        
        levelRequired = 0,
    },
    
    ['flat_white'] = {
        label = 'Flat White',
        description = 'Double espresso with velvety microfoam milk.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'standard',
        
        result = {
            item = 'flat_white',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'coffee_beans', count = 2 },
            { item = 'milk', count = 1 },
            { item = 'cup_medium', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_double', duration = 5000 },
            { type = 'coffee_machine', step = 'microfoam', duration = 5000, skillCheck = true },
            { type = 'coffee_machine', step = 'pour', duration = 3000 },
        },
        
        effects = {
            thirst = 28,
            stress = -12,
            hunger = 5,
        },
        
        levelRequired = 10,
    },
    
    ['hot_chocolate'] = {
        label = 'Hot Chocolate',
        description = 'Rich chocolate drink topped with whipped cream.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'basic',
        
        result = {
            item = 'hot_chocolate',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'milk', count = 1 },
            { item = 'chocolate_syrup', count = 2 },
            { item = 'whipped_cream', count = 1 },
            { item = 'cup_medium', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'steam_milk', duration = 4000 },
            { type = 'coffee_machine', step = 'add_chocolate', duration = 2000 },
            { type = 'plating_station', step = 'top', duration = 2000 },
        },
        
        effects = {
            thirst = 30,
            hunger = 15,
        },
        
        levelRequired = 0,
    },
    
    ['tea_black'] = {
        label = 'Black Tea',
        description = 'Classic brewed black tea.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'basic',
        
        result = {
            item = 'tea_black',
            count = 1,
        },
        
        basePrice = 3,
        
        ingredients = {
            { item = 'tea_bag_black', count = 1 },
            { item = 'hot_water', count = 1 },
            { item = 'cup_medium', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_tea', duration = 5000 },
        },
        
        effects = {
            thirst = 30,
            stress = -5,
        },
        
        levelRequired = 0,
    },
    
    ['chai_latte'] = {
        label = 'Chai Latte',
        description = 'Spiced chai tea with steamed milk.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'hotdrinks' },
        tier = 'standard',
        
        result = {
            item = 'chai_latte',
            count = 1,
        },
        
        basePrice = 6,
        
        ingredients = {
            { item = 'chai_concentrate', count = 1 },
            { item = 'milk', count = 1 },
            { item = 'cup_medium', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'steam_milk', duration = 4000 },
            { type = 'coffee_machine', step = 'combine', duration = 3000 },
        },
        
        effects = {
            thirst = 30,
            stress = -8,
            hunger = 5,
        },
        
        levelRequired = 10,
    },
    
    --[[
        COLD DRINKS - Bean Machine
    ]]
    
    ['iced_coffee'] = {
        label = 'Iced Coffee',
        description = 'Cold-brewed coffee over ice.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'colddrinks' },
        tier = 'basic',
        
        result = {
            item = 'iced_coffee',
            count = 1,
        },
        
        basePrice = 4,
        
        ingredients = {
            { item = 'cold_brew', count = 1 },
            { item = 'ice', count = 1 },
            { item = 'cup_large', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'pour_cold_brew', duration = 3000 },
        },
        
        effects = {
            thirst = 35,
            stress = -8,
        },
        
        levelRequired = 0,
    },
    
    ['iced_latte'] = {
        label = 'Iced Latte',
        description = 'Espresso with cold milk over ice.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'colddrinks' },
        tier = 'basic',
        
        result = {
            item = 'iced_latte',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'coffee_beans', count = 1 },
            { item = 'milk', count = 1 },
            { item = 'ice', count = 1 },
            { item = 'cup_large', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_espresso', duration = 4000 },
            { type = 'coffee_machine', step = 'pour_over_ice', duration = 3000 },
        },
        
        effects = {
            thirst = 35,
            stress = -8,
            hunger = 5,
        },
        
        levelRequired = 0,
    },
    
    ['frappuccino'] = {
        label = 'Bean Machine FrappÃ©',
        description = 'Blended iced coffee drink topped with whipped cream.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'colddrinks', 'smoothies' },
        tier = 'standard',
        
        result = {
            item = 'frappuccino',
            count = 1,
        },
        
        basePrice = 6,
        
        ingredients = {
            { item = 'cold_brew', count = 1 },
            { item = 'milk', count = 1 },
            { item = 'ice', count = 2 },
            { item = 'whipped_cream', count = 1 },
            { item = 'cup_large', count = 1 },
        },
        
        stations = {
            { type = 'blender', step = 'blend', duration = 6000 },
            { type = 'plating_station', step = 'top', duration = 2000 },
        },
        
        effects = {
            thirst = 40,
            stress = -8,
            hunger = 10,
        },
        
        levelRequired = 10,
    },
    
    ['los_santos_sunrise'] = {
        label = 'Los Santos Sunrise',
        description = 'Our signature iced drink with caramel, vanilla, and a hint of orange.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'colddrinks', 'smoothies' },
        tier = 'signature',
        
        exclusive = 'beanmachine',
        
        result = {
            item = 'los_santos_sunrise',
            count = 1,
            metadata = { legendary = true },
        },
        
        basePrice = 12,
        
        ingredients = {
            { item = 'cold_brew', count = 1, minQuality = 85, label = 'Premium Cold Brew' },
            { item = 'milk', count = 1, minQuality = 80, label = 'Oat Milk' },
            { item = 'caramel_syrup', count = 1, label = 'House Caramel' },
            { item = 'vanilla_syrup', count = 1, label = 'Madagascar Vanilla' },
            { item = 'orange_zest', count = 1, minQuality = 90, label = 'Fresh Orange Zest' },
            { item = 'ice', count = 2 },
            { item = 'whipped_cream', count = 1 },
            { item = 'cup_large', count = 1 },
        },
        
        stations = {
            { type = 'coffee_machine', step = 'brew_espresso', duration = 5000, skillCheck = true },
            { type = 'blender', step = 'blend', duration = 6000, skillCheck = true },
            { type = 'plating_station', step = 'layer', duration = 4000, skillCheck = true },
            { type = 'plating_station', step = 'garnish', duration = 3000 },
        },
        
        effects = {
            thirst = 50,
            stress = -20,
            hunger = 10,
        },
        
        levelRequired = 50,
    },
    
    --[[
        BAKERY - Bean Machine
    ]]
    
    ['croissant'] = {
        label = 'Butter Croissant',
        description = 'Flaky, buttery French pastry.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'bakery', 'breakfast' },
        tier = 'basic',
        
        result = {
            item = 'croissant',
            count = 1,
        },
        
        basePrice = 4,
        
        ingredients = {
            { item = 'croissant_dough', count = 1 },
            { item = 'butter', count = 1 },
        },
        
        stations = {
            { type = 'oven', step = 'bake', duration = 10000 },
        },
        
        effects = {
            hunger = 20,
        },
        
        levelRequired = 0,
    },
    
    ['muffin_blueberry'] = {
        label = 'Blueberry Muffin',
        description = 'Fresh-baked muffin loaded with blueberries.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'bakery', 'breakfast' },
        tier = 'basic',
        
        result = {
            item = 'muffin_blueberry',
            count = 1,
        },
        
        basePrice = 4,
        
        ingredients = {
            { item = 'muffin_batter', count = 1 },
            { item = 'blueberries', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'mix', duration = 3000 },
            { type = 'oven', step = 'bake', duration = 12000 },
        },
        
        effects = {
            hunger = 22,
        },
        
        levelRequired = 0,
    },
    
    ['bagel_cream_cheese'] = {
        label = 'Bagel with Cream Cheese',
        description = 'Toasted bagel with a generous spread of cream cheese.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'bakery', 'breakfast' },
        tier = 'basic',
        
        result = {
            item = 'bagel_cream_cheese',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'bagel', count = 1 },
            { item = 'cream_cheese', count = 1 },
        },
        
        stations = {
            { type = 'oven', step = 'toast', duration = 4000 },
            { type = 'prep_counter', step = 'spread', duration = 2000 },
        },
        
        effects = {
            hunger = 25,
        },
        
        levelRequired = 0,
    },
    
    ['danish_cheese'] = {
        label = 'Cheese Danish',
        description = 'Sweet pastry with cream cheese filling.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'bakery', 'desserts' },
        tier = 'standard',
        
        result = {
            item = 'danish_cheese',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'danish_dough', count = 1 },
            { item = 'cream_cheese', count = 1 },
            { item = 'sugar_glaze', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'fill', duration = 3000 },
            { type = 'oven', step = 'bake', duration = 12000 },
            { type = 'plating_station', step = 'glaze', duration = 2000 },
        },
        
        effects = {
            hunger = 25,
        },
        
        levelRequired = 10,
    },
    
    ['cinnamon_roll'] = {
        label = 'Cinnamon Roll',
        description = 'Warm cinnamon roll with cream cheese frosting.',
        
        restaurantTypes = { 'coffeeshop' },
        categories = { 'bakery', 'desserts' },
        tier = 'standard',
        
        result = {
            item = 'cinnamon_roll',
            count = 1,
        },
        
        basePrice = 6,
        
        ingredients = {
            { item = 'cinnamon_roll_dough', count = 1 },
            { item = 'cinnamon_sugar', count = 1 },
            { item = 'cream_cheese_frosting', count = 1 },
        },
        
        stations = {
            { type = 'oven', step = 'bake', duration = 15000 },
            { type = 'plating_station', step = 'frost', duration = 2000 },
        },
        
        effects = {
            hunger = 30,
        },
        
        levelRequired = 10,
    },
    
    -- ========================================================================
    -- TEQUI-LA-LA MENU (Bar)
    -- ========================================================================
    
    --[[
        COCKTAILS - Tequi-la-la
    ]]
    
    ['margarita'] = {
        label = 'Classic Margarita',
        description = 'Tequila, lime, and triple sec. Salted rim.',
        
        restaurantTypes = { 'bar' },
        categories = { 'cocktails', 'alcohol' },
        tier = 'basic',
        
        result = {
            item = 'margarita',
            count = 1,
        },
        
        basePrice = 10,
        
        ingredients = {
            { item = 'tequila', count = 1 },
            { item = 'triple_sec', count = 1 },
            { item = 'lime_juice', count = 1 },
            { item = 'salt', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'shake', duration = 5000 },
            { type = 'drink_mixer', step = 'strain', duration = 3000 },
        },
        
        effects = {
            thirst = 25,
            stress = -15,
        },
        
        levelRequired = 0,
    },
    
    ['margarita_premium'] = {
        label = 'Top Shelf Margarita',
        description = 'Made with premium tequila and fresh-squeezed lime.',
        
        restaurantTypes = { 'bar' },
        categories = { 'cocktails', 'alcohol' },
        tier = 'standard',
        
        result = {
            item = 'margarita_premium',
            count = 1,
            metadata = { quality = 'premium' },
        },
        
        basePrice = 18,
        
        ingredients = {
            { item = 'tequila', count = 1, minQuality = 90, label = 'AÃ±ejo Tequila' },
            { item = 'triple_sec', count = 1, minQuality = 80, label = 'Grand Marnier' },
            { item = 'lime', count = 2, minQuality = 85, label = 'Fresh Limes' },
            { item = 'agave_nectar', count = 1, label = 'Organic Agave' },
            { item = 'salt', count = 1, label = 'Himalayan Pink Salt' },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'juice_limes', duration = 4000 },
            { type = 'drink_mixer', step = 'shake', duration = 5000, skillCheck = true },
            { type = 'drink_mixer', step = 'strain', duration = 3000 },
            { type = 'plating_station', step = 'garnish', duration = 2000 },
        },
        
        effects = {
            thirst = 30,
            stress = -25,
        },
        
        levelRequired = 10,
    },
    
    ['mojito'] = {
        label = 'Mojito',
        description = 'Rum, mint, lime, sugar, and soda. Refreshing.',
        
        restaurantTypes = { 'bar' },
        categories = { 'cocktails', 'alcohol' },
        tier = 'standard',
        
        result = {
            item = 'mojito',
            count = 1,
        },
        
        basePrice = 11,
        
        ingredients = {
            { item = 'white_rum', count = 1 },
            { item = 'mint_leaves', count = 1 },
            { item = 'lime_juice', count = 1 },
            { item = 'sugar', count = 1 },
            { item = 'soda_water', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'muddle', duration = 4000 },
            { type = 'drink_mixer', step = 'mix', duration = 4000 },
            { type = 'plating_station', step = 'garnish', duration = 2000 },
        },
        
        effects = {
            thirst = 30,
            stress = -15,
        },
        
        levelRequired = 10,
    },
    
    ['old_fashioned'] = {
        label = 'Old Fashioned',
        description = 'Bourbon, bitters, sugar, and orange peel. Timeless.',
        
        restaurantTypes = { 'bar' },
        categories = { 'cocktails', 'alcohol' },
        tier = 'standard',
        
        result = {
            item = 'old_fashioned',
            count = 1,
        },
        
        basePrice = 12,
        
        ingredients = {
            { item = 'bourbon', count = 2 },
            { item = 'angostura_bitters', count = 1 },
            { item = 'sugar_cube', count = 1 },
            { item = 'orange_peel', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'muddle', duration = 3000 },
            { type = 'drink_mixer', step = 'stir', duration = 4000 },
            { type = 'plating_station', step = 'garnish', duration = 2000 },
        },
        
        effects = {
            thirst = 15,
            stress = -20,
        },
        
        levelRequired = 10,
    },
    
    ['whiskey_sour'] = {
        label = 'Whiskey Sour',
        description = 'Whiskey, lemon juice, and simple syrup.',
        
        restaurantTypes = { 'bar' },
        categories = { 'cocktails', 'alcohol' },
        tier = 'basic',
        
        result = {
            item = 'whiskey_sour',
            count = 1,
        },
        
        basePrice = 10,
        
        ingredients = {
            { item = 'whiskey', count = 2 },
            { item = 'lemon_juice', count = 1 },
            { item = 'simple_syrup', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'shake', duration = 5000 },
            { type = 'drink_mixer', step = 'strain', duration = 3000 },
        },
        
        effects = {
            thirst = 20,
            stress = -15,
        },
        
        levelRequired = 0,
    },
    
    ['long_island'] = {
        label = 'Long Island Iced Tea',
        description = 'Five spirits that somehow taste like iced tea. Dangerous.',
        
        restaurantTypes = { 'bar' },
        categories = { 'cocktails', 'alcohol' },
        tier = 'advanced',
        
        result = {
            item = 'long_island',
            count = 1,
        },
        
        basePrice = 14,
        
        ingredients = {
            { item = 'vodka', count = 1 },
            { item = 'tequila', count = 1 },
            { item = 'white_rum', count = 1 },
            { item = 'gin', count = 1 },
            { item = 'triple_sec', count = 1 },
            { item = 'lemon_juice', count = 1 },
            { item = 'cola', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'combine', duration = 5000, skillCheck = true },
            { type = 'drink_mixer', step = 'stir', duration = 3000 },
            { type = 'plating_station', step = 'garnish', duration = 2000 },
        },
        
        effects = {
            thirst = 30,
            stress = -25,
        },
        
        levelRequired = 25,
    },
    
    ['cosmopolitan'] = {
        label = 'Cosmopolitan',
        description = 'Vodka, triple sec, cranberry, and lime.',
        
        restaurantTypes = { 'bar' },
        categories = { 'cocktails', 'alcohol' },
        tier = 'standard',
        
        result = {
            item = 'cosmopolitan',
            count = 1,
        },
        
        basePrice = 12,
        
        ingredients = {
            { item = 'vodka', count = 2 },
            { item = 'triple_sec', count = 1 },
            { item = 'cranberry_juice', count = 1 },
            { item = 'lime_juice', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'shake', duration = 5000, skillCheck = true },
            { type = 'drink_mixer', step = 'strain', duration = 3000 },
            { type = 'plating_station', step = 'garnish', duration = 2000 },
        },
        
        effects = {
            thirst = 25,
            stress = -15,
        },
        
        levelRequired = 10,
    },
    
    ['martini'] = {
        label = 'Classic Martini',
        description = 'Gin and dry vermouth. Shaken or stirred.',
        
        restaurantTypes = { 'bar' },
        categories = { 'cocktails', 'alcohol' },
        tier = 'standard',
        
        result = {
            item = 'martini',
            count = 1,
        },
        
        basePrice = 13,
        
        ingredients = {
            { item = 'gin', count = 2 },
            { item = 'dry_vermouth', count = 1 },
            { item = 'olive', count = 1 },
            { item = 'ice', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'stir', duration = 4000 },
            { type = 'drink_mixer', step = 'strain', duration = 3000 },
            { type = 'plating_station', step = 'garnish', duration = 2000 },
        },
        
        effects = {
            thirst = 15,
            stress = -18,
        },
        
        levelRequired = 10,
    },
    
    ['pina_colada'] = {
        label = 'PiÃ±a Colada',
        description = 'Rum, coconut cream, and pineapple. Tropical bliss.',
        
        restaurantTypes = { 'bar' },
        categories = { 'cocktails', 'alcohol' },
        tier = 'standard',
        
        result = {
            item = 'pina_colada',
            count = 1,
        },
        
        basePrice = 12,
        
        ingredients = {
            { item = 'white_rum', count = 2 },
            { item = 'coconut_cream', count = 1 },
            { item = 'pineapple_juice', count = 1 },
            { item = 'ice', count = 2 },
        },
        
        stations = {
            { type = 'blender', step = 'blend', duration = 6000 },
            { type = 'plating_station', step = 'garnish', duration = 2000 },
        },
        
        effects = {
            thirst = 35,
            stress = -15,
            hunger = 5,
        },
        
        levelRequired = 10,
    },
    
    ['tequila_sunset'] = {
        label = 'Tequila Sunset',
        description = 'Our signature cocktail. Tequila, passion fruit, and a splash of grenadine.',
        
        restaurantTypes = { 'bar' },
        categories = { 'cocktails', 'alcohol' },
        tier = 'signature',
        
        exclusive = 'tequilala',
        
        result = {
            item = 'tequila_sunset',
            count = 1,
            metadata = { legendary = true },
        },
        
        basePrice = 25,
        
        ingredients = {
            { item = 'tequila', count = 2, minQuality = 90, label = 'Reposado Tequila' },
            { item = 'passion_fruit', count = 2, minQuality = 85, label = 'Fresh Passion Fruit' },
            { item = 'orange_juice', count = 1, minQuality = 80, label = 'Fresh OJ' },
            { item = 'grenadine', count = 1, label = 'House Grenadine' },
            { item = 'lime_juice', count = 1, minQuality = 85, label = 'Fresh Lime' },
            { item = 'agave_nectar', count = 1, label = 'Organic Agave' },
            { item = 'ice', count = 2 },
            { item = 'edible_flower', count = 1, label = 'Edible Orchid' },
        },
        
        stations = {
            { type = 'prep_counter', step = 'prep_fruit', duration = 4000 },
            { type = 'drink_mixer', step = 'muddle', duration = 3000, skillCheck = true },
            { type = 'drink_mixer', step = 'shake', duration = 5000, skillCheck = true },
            { type = 'drink_mixer', step = 'strain', duration = 3000 },
            { type = 'plating_station', step = 'layer_grenadine', duration = 3000, skillCheck = true },
            { type = 'plating_station', step = 'garnish', duration = 2000 },
        },
        
        effects = {
            thirst = 40,
            stress = -30,
        },
        
        levelRequired = 50,
    },
    
    --[[
        SIMPLE DRINKS - Tequi-la-la
    ]]
    
    ['beer_domestic'] = {
        label = 'Domestic Beer',
        description = 'A cold piÃŸwasser or Logger.',
        
        restaurantTypes = { 'bar' },
        categories = { 'alcohol' },
        tier = 'basic',
        
        result = {
            item = 'beer_domestic',
            count = 1,
        },
        
        basePrice = 5,
        
        ingredients = {
            { item = 'beer_bottle_domestic', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'pour', duration = 2000 },
        },
        
        effects = {
            thirst = 25,
            stress = -5,
        },
        
        levelRequired = 0,
    },
    
    ['beer_import'] = {
        label = 'Import Beer',
        description = 'Premium imported beer.',
        
        restaurantTypes = { 'bar' },
        categories = { 'alcohol' },
        tier = 'basic',
        
        result = {
            item = 'beer_import',
            count = 1,
        },
        
        basePrice = 7,
        
        ingredients = {
            { item = 'beer_bottle_import', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'pour', duration = 2000 },
        },
        
        effects = {
            thirst = 28,
            stress = -8,
        },
        
        levelRequired = 0,
    },
    
    ['beer_draft'] = {
        label = 'Draft Beer',
        description = 'Fresh from the tap.',
        
        restaurantTypes = { 'bar' },
        categories = { 'alcohol' },
        tier = 'basic',
        
        result = {
            item = 'beer_draft',
            count = 1,
        },
        
        basePrice = 6,
        
        ingredients = {
            { item = 'beer_tap', count = 1 },
            { item = 'pint_glass', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'pour_draft', duration = 4000 },
        },
        
        effects = {
            thirst = 30,
            stress = -8,
        },
        
        levelRequired = 0,
    },
    
    ['shot_tequila'] = {
        label = 'Tequila Shot',
        description = 'A shot of tequila with salt and lime.',
        
        restaurantTypes = { 'bar' },
        categories = { 'alcohol' },
        tier = 'basic',
        
        result = {
            item = 'shot_tequila',
            count = 1,
        },
        
        basePrice = 6,
        
        ingredients = {
            { item = 'tequila', count = 1 },
            { item = 'lime_wedge', count = 1 },
            { item = 'salt', count = 1 },
            { item = 'shot_glass', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'pour', duration = 2000 },
        },
        
        effects = {
            thirst = 5,
            stress = -10,
        },
        
        levelRequired = 0,
    },
    
    ['shot_whiskey'] = {
        label = 'Whiskey Shot',
        description = 'A shot of whiskey. Neat.',
        
        restaurantTypes = { 'bar' },
        categories = { 'alcohol' },
        tier = 'basic',
        
        result = {
            item = 'shot_whiskey',
            count = 1,
        },
        
        basePrice = 7,
        
        ingredients = {
            { item = 'whiskey', count = 1 },
            { item = 'shot_glass', count = 1 },
        },
        
        stations = {
            { type = 'drink_mixer', step = 'pour', duration = 2000 },
        },
        
        effects = {
            thirst = 5,
            stress = -12,
        },
        
        levelRequired = 0,
    },
    
    --[[
        BAR FOOD - Tequi-la-la
    ]]
    
    ['nachos'] = {
        label = 'Loaded Nachos',
        description = 'Tortilla chips covered in cheese, jalapeÃ±os, and all the fixings.',
        
        restaurantTypes = { 'bar' },
        categories = { 'appetizers', 'mexican' },
        tier = 'standard',
        
        result = {
            item = 'nachos',
            count = 1,
        },
        
        basePrice = 12,
        
        ingredients = {
            { item = 'tortilla_chips', count = 1 },
            { item = 'cheese_sauce', count = 1 },
            { item = 'ground_beef', count = 1 },
            { item = 'jalapeno', count = 1 },
            { item = 'sour_cream', count = 1 },
            { item = 'salsa', count = 1 },
        },
        
        stations = {
            { type = 'grill', step = 'cook_beef', duration = 8000 },
            { type = 'prep_counter', step = 'layer', duration = 4000 },
            { type = 'oven', step = 'melt_cheese', duration = 5000 },
            { type = 'plating_station', step = 'top', duration = 3000 },
        },
        
        effects = {
            hunger = 45,
            thirst = -10,
        },
        
        levelRequired = 10,
    },
    
    ['sliders'] = {
        label = 'Slider Trio',
        description = 'Three mini burgers. Perfect for sharing (or not).',
        
        restaurantTypes = { 'bar' },
        categories = { 'appetizers', 'burgers' },
        tier = 'standard',
        
        result = {
            item = 'sliders',
            count = 1,
        },
        
        basePrice = 14,
        
        ingredients = {
            { item = 'slider_bun', count = 3 },
            { item = 'beef_patty_mini', count = 3 },
            { item = 'cheese_slice', count = 3 },
            { item = 'pickles', count = 1 },
            { item = 'onion', count = 1 },
        },
        
        stations = {
            { type = 'grill', step = 'cook_patties', duration = 8000 },
            { type = 'prep_counter', step = 'assemble', duration = 5000 },
        },
        
        effects = {
            hunger = 40,
            thirst = -10,
        },
        
        levelRequired = 10,
    },
    
    ['quesadilla'] = {
        label = 'Chicken Quesadilla',
        description = 'Grilled tortilla stuffed with chicken and melted cheese.',
        
        restaurantTypes = { 'bar' },
        categories = { 'mexican', 'chicken' },
        tier = 'basic',
        
        result = {
            item = 'quesadilla',
            count = 1,
        },
        
        basePrice = 10,
        
        ingredients = {
            { item = 'flour_tortilla', count = 1 },
            { item = 'chicken_breast', count = 1 },
            { item = 'cheddar_cheese', count = 1 },
            { item = 'salsa', count = 1 },
        },
        
        stations = {
            { type = 'grill', step = 'grill_chicken', duration = 10000 },
            { type = 'prep_counter', step = 'assemble', duration = 3000 },
            { type = 'grill', step = 'grill_quesadilla', duration = 5000 },
        },
        
        effects = {
            hunger = 35,
            thirst = -5,
        },
        
        levelRequired = 0,
    },
    
    ['fish_tacos'] = {
        label = 'Fish Tacos',
        description = 'Crispy fish, cabbage slaw, and chipotle mayo.',
        
        restaurantTypes = { 'bar' },
        categories = { 'mexican' },
        tier = 'standard',
        
        result = {
            item = 'fish_tacos',
            count = 1,
        },
        
        basePrice = 14,
        
        ingredients = {
            { item = 'corn_tortilla', count = 2 },
            { item = 'fish_fillet', count = 1 },
            { item = 'breading', count = 1 },
            { item = 'cabbage', count = 1 },
            { item = 'chipotle_mayo', count = 1 },
            { item = 'lime', count = 1 },
        },
        
        stations = {
            { type = 'prep_counter', step = 'bread_fish', duration = 3000 },
            { type = 'fryer', step = 'fry', duration = 8000 },
            { type = 'prep_counter', step = 'make_slaw', duration = 3000 },
            { type = 'plating_station', step = 'assemble', duration = 4000 },
        },
        
        effects = {
            hunger = 40,
            thirst = -5,
        },
        
        levelRequired = 10,
    },
    
    -- ========================================================================
    -- SECRET / HIDDEN RECIPES
    -- ========================================================================
    
    ['secret_burger'] = {
        label = 'The Big Smoke Special',
        description = 'Two number 9s, a number 9 large, a number 6 with extra dip...',
        
        restaurantTypes = { 'fastfood' },
        categories = { 'burgers', 'combos' },
        tier = 'signature',
        
        -- Hidden recipe - not shown in menu, must be discovered
        hidden = true,
        exclusive = 'burgershot',
        
        result = {
            item = 'big_smoke_special',
            count = 1,
            metadata = { legendary = true, secret = true },
        },
        
        basePrice = 50,
        
        ingredients = {
            { item = 'burger_bun', count = 4 },
            { item = 'beef_patty', count = 6 },
            { item = 'cheese_slice', count = 6 },
            { item = 'chicken_breast', count = 2 },
            { item = 'breading', count = 2 },
            { item = 'potato', count = 4 },
            { item = 'cup_large', count = 2 },
            { item = 'sprunk_syrup', count = 2 },
            { item = 'ice', count = 2 },
            { item = 'special_sauce', count = 2 },
        },
        
        stations = {
            { type = 'grill', step = 'cook_patties', duration = 15000, skillCheck = true },
            { type = 'fryer', step = 'fry_chicken', duration = 12000, skillCheck = true },
            { type = 'fryer', step = 'fry_fries', duration = 8000 },
            { type = 'prep_counter', step = 'assemble_burgers', duration = 8000, skillCheck = true },
            { type = 'soda_fountain', step = 'fill_drinks', duration = 4000 },
            { type = 'packaging_station', step = 'package', duration = 5000 },
        },
        
        effects = {
            hunger = 100,
            thirst = 50,
            stress = 15,
        },
        
        levelRequired = 75,
    },

    -- ========================================================================
    -- TACO FARMER MENU (Mexican Restaurant)
    -- ========================================================================

    ['carne_asada_taco'] = {
        label = 'Carne Asada Taco',
        description = 'Grilled steak taco with onions and cilantro.',

        restaurantTypes = { 'mexican' },
        categories = { 'mexican' },
        tier = 'basic',

        result = {
            item = 'carne_asada_taco',
            count = 1,
        },

        basePrice = 4,

        ingredients = {
            { item = 'corn_tortilla', count = 1 },
            { item = 'steak', count = 1 },
            { item = 'onion', count = 1 },
            { item = 'cilantro', count = 1 },
        },

        stations = {
            { type = 'grill', step = 'grill_steak', duration = 8000 },
            { type = 'taco_station', step = 'assemble', duration = 3000 },
        },

        effects = {
            hunger = 20,
            thirst = -5,
        },

        levelRequired = 0,
    },

    ['chicken_taco'] = {
        label = 'Chicken Taco',
        description = 'Seasoned grilled chicken taco with salsa.',

        restaurantTypes = { 'mexican' },
        categories = { 'mexican', 'chicken' },
        tier = 'basic',

        result = {
            item = 'chicken_taco',
            count = 1,
        },

        basePrice = 3,

        ingredients = {
            { item = 'corn_tortilla', count = 1 },
            { item = 'chicken_breast', count = 1 },
            { item = 'salsa', count = 1 },
        },

        stations = {
            { type = 'grill', step = 'grill_chicken', duration = 7000 },
            { type = 'taco_station', step = 'assemble', duration = 3000 },
        },

        effects = {
            hunger = 18,
            thirst = -5,
        },

        levelRequired = 0,
    },

    ['carnitas_taco'] = {
        label = 'Carnitas Taco',
        description = 'Slow-cooked pulled pork taco with lime.',

        restaurantTypes = { 'mexican' },
        categories = { 'mexican' },
        tier = 'standard',

        result = {
            item = 'carnitas_taco',
            count = 1,
        },

        basePrice = 5,

        ingredients = {
            { item = 'corn_tortilla', count = 1 },
            { item = 'pork', count = 1 },
            { item = 'onion', count = 1 },
            { item = 'lime', count = 1 },
        },

        stations = {
            { type = 'prep_counter', step = 'season_pork', duration = 3000 },
            { type = 'grill', step = 'cook_pork', duration = 10000 },
            { type = 'taco_station', step = 'assemble', duration = 4000 },
        },

        effects = {
            hunger = 25,
            thirst = -5,
        },

        levelRequired = 5,
    },

    ['burrito'] = {
        label = 'Burrito',
        description = 'Large flour tortilla stuffed with rice, beans, and meat.',

        restaurantTypes = { 'mexican' },
        categories = { 'mexican' },
        tier = 'standard',

        result = {
            item = 'burrito',
            count = 1,
        },

        basePrice = 8,

        ingredients = {
            { item = 'flour_tortilla', count = 1 },
            { item = 'rice', count = 1 },
            { item = 'beans', count = 1 },
            { item = 'steak', count = 1 },
            { item = 'cheese_slice', count = 1 },
            { item = 'sour_cream', count = 1 },
        },

        stations = {
            { type = 'grill', step = 'grill_steak', duration = 8000 },
            { type = 'prep_counter', step = 'prepare_fillings', duration = 4000 },
            { type = 'taco_station', step = 'wrap_burrito', duration = 5000 },
        },

        effects = {
            hunger = 45,
            thirst = -10,
        },

        levelRequired = 10,
    },

    ['quesadilla'] = {
        label = 'Quesadilla',
        description = 'Grilled flour tortilla with melted cheese and meat.',

        restaurantTypes = { 'mexican' },
        categories = { 'mexican' },
        tier = 'basic',

        result = {
            item = 'quesadilla',
            count = 1,
        },

        basePrice = 6,

        ingredients = {
            { item = 'flour_tortilla', count = 2 },
            { item = 'cheese_slice', count = 2 },
            { item = 'chicken_breast', count = 1 },
        },

        stations = {
            { type = 'grill', step = 'grill_chicken', duration = 6000 },
            { type = 'grill', step = 'grill_quesadilla', duration = 4000 },
            { type = 'prep_counter', step = 'slice', duration = 2000 },
        },

        effects = {
            hunger = 30,
            thirst = -5,
        },

        levelRequired = 0,
    },

    ['nachos'] = {
        label = 'Nachos',
        description = 'Tortilla chips with cheese, jalapeños, and toppings.',

        restaurantTypes = { 'mexican' },
        categories = { 'mexican', 'appetizers' },
        tier = 'basic',

        result = {
            item = 'nachos',
            count = 1,
        },

        basePrice = 7,

        ingredients = {
            { item = 'tortilla_chips', count = 1 },
            { item = 'cheese_sauce', count = 1 },
            { item = 'jalapeno', count = 1 },
            { item = 'sour_cream', count = 1 },
        },

        stations = {
            { type = 'prep_counter', step = 'arrange_chips', duration = 3000 },
            { type = 'grill', step = 'melt_cheese', duration = 4000 },
            { type = 'taco_station', step = 'add_toppings', duration = 3000 },
        },

        effects = {
            hunger = 25,
            thirst = -10,
        },

        levelRequired = 0,
    },

    ['guacamole'] = {
        label = 'Fresh Guacamole',
        description = 'Freshly made guacamole with chips.',

        restaurantTypes = { 'mexican' },
        categories = { 'mexican', 'appetizers' },
        tier = 'basic',

        result = {
            item = 'guacamole',
            count = 1,
        },

        basePrice = 5,

        ingredients = {
            { item = 'avocado', count = 2 },
            { item = 'lime', count = 1 },
            { item = 'onion', count = 1 },
            { item = 'cilantro', count = 1 },
            { item = 'tortilla_chips', count = 1 },
        },

        stations = {
            { type = 'prep_counter', step = 'mash_avocado', duration = 4000 },
            { type = 'prep_counter', step = 'mix_ingredients', duration = 3000 },
        },

        effects = {
            hunger = 15,
            thirst = -5,
        },

        levelRequired = 0,
    },

    ['street_corn'] = {
        label = 'Street Corn (Elote)',
        description = 'Grilled corn on the cob with mayo, cheese, and lime.',

        restaurantTypes = { 'mexican' },
        categories = { 'mexican', 'sides' },
        tier = 'basic',

        result = {
            item = 'street_corn',
            count = 1,
        },

        basePrice = 4,

        ingredients = {
            { item = 'corn', count = 1 },
            { item = 'mayo', count = 1 },
            { item = 'cotija_cheese', count = 1 },
            { item = 'lime', count = 1 },
            { item = 'chili_powder', count = 1 },
        },

        stations = {
            { type = 'grill', step = 'grill_corn', duration = 6000 },
            { type = 'prep_counter', step = 'add_toppings', duration = 3000 },
        },

        effects = {
            hunger = 15,
            thirst = -5,
        },

        levelRequired = 0,
    },
}

-- ============================================================================
-- INGREDIENT DEFINITIONS
-- Defines all raw ingredients used in recipes
-- ============================================================================

Config.Recipes.Ingredients = {
    -- Proteins
    ['beef_patty'] = { label = 'Beef Patty', category = 'meat', baseDecay = 24 },
    ['beef_patty_mini'] = { label = 'Mini Beef Patty', category = 'meat', baseDecay = 24 },
    ['chicken_breast'] = { label = 'Chicken Breast', category = 'meat', baseDecay = 24 },
    ['chicken_wings'] = { label = 'Chicken Wings', category = 'meat', baseDecay = 24 },
    ['fish_fillet'] = { label = 'Fish Fillet', category = 'meat', baseDecay = 18 },
    ['bacon'] = { label = 'Bacon', category = 'meat', baseDecay = 48 },
    ['ham'] = { label = 'Ham', category = 'meat', baseDecay = 48 },
    ['pepperoni'] = { label = 'Pepperoni', category = 'meat', baseDecay = 72 },
    ['italian_sausage'] = { label = 'Italian Sausage', category = 'meat', baseDecay = 48 },
    ['prosciutto'] = { label = 'Prosciutto', category = 'meat', baseDecay = 72 },
    ['ground_beef'] = { label = 'Ground Beef', category = 'meat', baseDecay = 24 },
    
    -- Dairy
    ['cheese_slice'] = { label = 'Cheese Slice', category = 'dairy', baseDecay = 72 },
    ['mozzarella'] = { label = 'Mozzarella', category = 'dairy', baseDecay = 48 },
    ['cheddar_cheese'] = { label = 'Cheddar Cheese', category = 'dairy', baseDecay = 72 },
    ['parmesan'] = { label = 'Parmesan', category = 'dairy', baseDecay = 168 },
    ['ricotta'] = { label = 'Ricotta', category = 'dairy', baseDecay = 48 },
    ['cream_cheese'] = { label = 'Cream Cheese', category = 'dairy', baseDecay = 72 },
    ['sour_cream'] = { label = 'Sour Cream', category = 'dairy', baseDecay = 72 },
    ['milk'] = { label = 'Milk', category = 'dairy', baseDecay = 48 },
    ['butter'] = { label = 'Butter', category = 'dairy', baseDecay = 168 },
    ['whipped_cream'] = { label = 'Whipped Cream', category = 'dairy', baseDecay = 24 },
    ['cheese_sauce'] = { label = 'Cheese Sauce', category = 'dairy', baseDecay = 24 },
    
    -- Produce
    ['lettuce'] = { label = 'Lettuce', category = 'produce', baseDecay = 48 },
    ['romaine_lettuce'] = { label = 'Romaine Lettuce', category = 'produce', baseDecay = 48 },
    ['arugula'] = { label = 'Arugula', category = 'produce', baseDecay = 36 },
    ['tomato_slice'] = { label = 'Tomato Slice', category = 'produce', baseDecay = 36 },
    ['onion'] = { label = 'Onion', category = 'produce', baseDecay = 168 },
    ['onion_slice'] = { label = 'Onion Slice', category = 'produce', baseDecay = 24 },
    ['red_onion'] = { label = 'Red Onion', category = 'produce', baseDecay = 168 },
    ['pickles'] = { label = 'Pickles', category = 'produce', baseDecay = 720 },
    ['jalapeno'] = { label = 'JalapeÃ±o', category = 'produce', baseDecay = 72 },
    ['bell_pepper'] = { label = 'Bell Pepper', category = 'produce', baseDecay = 72 },
    ['mushroom'] = { label = 'Mushrooms', category = 'produce', baseDecay = 48 },
    ['black_olives'] = { label = 'Black Olives', category = 'produce', baseDecay = 720 },
    ['potato'] = { label = 'Potato', category = 'produce', baseDecay = 336 },
    ['basil'] = { label = 'Fresh Basil', category = 'produce', baseDecay = 36 },
    ['mint_leaves'] = { label = 'Mint Leaves', category = 'produce', baseDecay = 36 },
    ['cilantro'] = { label = 'Cilantro', category = 'produce', baseDecay = 36 },
    ['parsley'] = { label = 'Parsley', category = 'produce', baseDecay = 36 },
    ['chives'] = { label = 'Chives', category = 'produce', baseDecay = 36 },
    ['lime'] = { label = 'Lime', category = 'produce', baseDecay = 168 },
    ['lime_wedge'] = { label = 'Lime Wedge', category = 'produce', baseDecay = 24 },
    ['lemon'] = { label = 'Lemon', category = 'produce', baseDecay = 168 },
    ['orange_peel'] = { label = 'Orange Peel', category = 'produce', baseDecay = 24 },
    ['orange_zest'] = { label = 'Orange Zest', category = 'produce', baseDecay = 24 },
    ['pineapple'] = { label = 'Pineapple', category = 'produce', baseDecay = 72 },
    ['passion_fruit'] = { label = 'Passion Fruit', category = 'produce', baseDecay = 48 },
    ['blueberries'] = { label = 'Blueberries', category = 'produce', baseDecay = 48 },
    ['celery'] = { label = 'Celery', category = 'produce', baseDecay = 72 },
    ['cabbage'] = { label = 'Cabbage', category = 'produce', baseDecay = 168 },
    ['olive'] = { label = 'Olive', category = 'produce', baseDecay = 720 },
    ['edible_flower'] = { label = 'Edible Flower', category = 'produce', baseDecay = 24 },
    
    -- Bread/Dough
    ['burger_bun'] = { label = 'Burger Bun', category = 'bakery', baseDecay = 72 },
    ['slider_bun'] = { label = 'Slider Bun', category = 'bakery', baseDecay = 72 },
    ['pizza_dough'] = { label = 'Pizza Dough', category = 'bakery', baseDecay = 48 },
    ['flour_tortilla'] = { label = 'Flour Tortilla', category = 'bakery', baseDecay = 168 },
    ['corn_tortilla'] = { label = 'Corn Tortilla', category = 'bakery', baseDecay = 168 },
    ['bagel'] = { label = 'Bagel', category = 'bakery', baseDecay = 72 },
    ['croissant_dough'] = { label = 'Croissant Dough', category = 'bakery', baseDecay = 48 },
    ['danish_dough'] = { label = 'Danish Dough', category = 'bakery', baseDecay = 48 },
    ['cinnamon_roll_dough'] = { label = 'Cinnamon Roll Dough', category = 'bakery', baseDecay = 48 },
    ['muffin_batter'] = { label = 'Muffin Batter', category = 'bakery', baseDecay = 24 },
    ['croutons'] = { label = 'Croutons', category = 'bakery', baseDecay = 336 },
    ['tortilla_chips'] = { label = 'Tortilla Chips', category = 'bakery', baseDecay = 336 },
    
    -- Sauces/Condiments
    ['ketchup'] = { label = 'Ketchup', category = 'condiment', baseDecay = 720 },
    ['mayo'] = { label = 'Mayonnaise', category = 'condiment', baseDecay = 336 },
    ['special_sauce'] = { label = 'Special Sauce', category = 'condiment', baseDecay = 168 },
    ['tomato_sauce'] = { label = 'Tomato Sauce', category = 'condiment', baseDecay = 168 },
    ['marinara_sauce'] = { label = 'Marinara Sauce', category = 'condiment', baseDecay = 168 },
    ['bbq_sauce'] = { label = 'BBQ Sauce', category = 'condiment', baseDecay = 336 },
    ['buffalo_sauce'] = { label = 'Buffalo Sauce', category = 'condiment', baseDecay = 336 },
    ['tartar_sauce'] = { label = 'Tartar Sauce', category = 'condiment', baseDecay = 168 },
    ['ranch_dressing'] = { label = 'Ranch Dressing', category = 'condiment', baseDecay = 168 },
    ['caesar_dressing'] = { label = 'Caesar Dressing', category = 'condiment', baseDecay = 168 },
    ['salsa'] = { label = 'Salsa', category = 'condiment', baseDecay = 168 },
    ['chipotle_mayo'] = { label = 'Chipotle Mayo', category = 'condiment', baseDecay = 168 },
    ['garlic_butter'] = { label = 'Garlic Butter', category = 'condiment', baseDecay = 168 },
    ['olive_oil'] = { label = 'Olive Oil', category = 'condiment', baseDecay = 720 },
    ['truffle_oil'] = { label = 'Truffle Oil', category = 'condiment', baseDecay = 336 },
    ['balsamic_glaze'] = { label = 'Balsamic Glaze', category = 'condiment', baseDecay = 720 },
    ['gravy'] = { label = 'Gravy', category = 'condiment', baseDecay = 48 },
    
    -- Dry Goods
    ['breading'] = { label = 'Breading Mix', category = 'dry', baseDecay = 720 },
    ['salt'] = { label = 'Salt', category = 'dry', baseDecay = 9999 },
    ['sugar'] = { label = 'Sugar', category = 'dry', baseDecay = 9999 },
    ['cinnamon_sugar'] = { label = 'Cinnamon Sugar', category = 'dry', baseDecay = 720 },
    ['sugar_glaze'] = { label = 'Sugar Glaze', category = 'dry', baseDecay = 168 },
    ['cream_cheese_frosting'] = { label = 'Cream Cheese Frosting', category = 'dairy', baseDecay = 168 },
    
    -- Coffee/Tea
    ['coffee_beans'] = { label = 'Coffee Beans', category = 'dry', baseDecay = 720 },
    ['cold_brew'] = { label = 'Cold Brew Concentrate', category = 'prepared', baseDecay = 168 },
    ['tea_bag_black'] = { label = 'Black Tea Bag', category = 'dry', baseDecay = 720 },
    ['chai_concentrate'] = { label = 'Chai Concentrate', category = 'prepared', baseDecay = 168 },
    ['hot_water'] = { label = 'Hot Water', category = 'prepared', baseDecay = 1 },
    
    -- Syrups
    ['chocolate_syrup'] = { label = 'Chocolate Syrup', category = 'condiment', baseDecay = 336 },
    ['caramel_syrup'] = { label = 'Caramel Syrup', category = 'condiment', baseDecay = 336 },
    ['vanilla_syrup'] = { label = 'Vanilla Syrup', category = 'condiment', baseDecay = 336 },
    ['simple_syrup'] = { label = 'Simple Syrup', category = 'condiment', baseDecay = 336 },
    ['grenadine'] = { label = 'Grenadine', category = 'condiment', baseDecay = 336 },
    ['agave_nectar'] = { label = 'Agave Nectar', category = 'condiment', baseDecay = 720 },
    ['sprunk_syrup'] = { label = 'Sprunk Syrup', category = 'condiment', baseDecay = 720 },
    ['ecola_syrup'] = { label = 'eCola Syrup', category = 'condiment', baseDecay = 720 },
    
    -- Alcohol
    ['tequila'] = { label = 'Tequila', category = 'alcohol', baseDecay = 9999 },
    ['vodka'] = { label = 'Vodka', category = 'alcohol', baseDecay = 9999 },
    ['white_rum'] = { label = 'White Rum', category = 'alcohol', baseDecay = 9999 },
    ['gin'] = { label = 'Gin', category = 'alcohol', baseDecay = 9999 },
    ['whiskey'] = { label = 'Whiskey', category = 'alcohol', baseDecay = 9999 },
    ['bourbon'] = { label = 'Bourbon', category = 'alcohol', baseDecay = 9999 },
    ['triple_sec'] = { label = 'Triple Sec', category = 'alcohol', baseDecay = 9999 },
    ['dry_vermouth'] = { label = 'Dry Vermouth', category = 'alcohol', baseDecay = 720 },
    ['beer_bottle_domestic'] = { label = 'Domestic Beer Bottle', category = 'alcohol', baseDecay = 720 },
    ['beer_bottle_import'] = { label = 'Import Beer Bottle', category = 'alcohol', baseDecay = 720 },
    ['beer_tap'] = { label = 'Draft Beer', category = 'alcohol', baseDecay = 24 },
    
    -- Mixers
    ['lime_juice'] = { label = 'Lime Juice', category = 'prepared', baseDecay = 168 },
    ['lemon_juice'] = { label = 'Lemon Juice', category = 'prepared', baseDecay = 168 },
    ['orange_juice'] = { label = 'Orange Juice', category = 'prepared', baseDecay = 72 },
    ['pineapple_juice'] = { label = 'Pineapple Juice', category = 'prepared', baseDecay = 72 },
    ['cranberry_juice'] = { label = 'Cranberry Juice', category = 'prepared', baseDecay = 168 },
    ['soda_water'] = { label = 'Soda Water', category = 'prepared', baseDecay = 720 },
    ['cola'] = { label = 'Cola', category = 'prepared', baseDecay = 720 },
    ['coconut_cream'] = { label = 'Coconut Cream', category = 'prepared', baseDecay = 336 },
    ['angostura_bitters'] = { label = 'Angostura Bitters', category = 'prepared', baseDecay = 9999 },
    ['sugar_cube'] = { label = 'Sugar Cube', category = 'dry', baseDecay = 9999 },
    
    -- Ice Cream
    ['ice_cream_vanilla'] = { label = 'Vanilla Ice Cream', category = 'frozen', baseDecay = 720 },
    ['ice_cream_chocolate'] = { label = 'Chocolate Ice Cream', category = 'frozen', baseDecay = 720 },
    
    -- Supplies
    ['ice'] = { label = 'Ice', category = 'supply', baseDecay = 1 },
    ['cup_small'] = { label = 'Small Cup', category = 'supply', baseDecay = 9999 },
    ['cup_medium'] = { label = 'Medium Cup', category = 'supply', baseDecay = 9999 },
    ['cup_large'] = { label = 'Large Cup', category = 'supply', baseDecay = 9999 },
    ['cup_espresso'] = { label = 'Espresso Cup', category = 'supply', baseDecay = 9999 },
    ['pint_glass'] = { label = 'Pint Glass', category = 'supply', baseDecay = 9999 },
    ['shot_glass'] = { label = 'Shot Glass', category = 'supply', baseDecay = 9999 },
    ['kids_toy'] = { label = 'Kids Meal Toy', category = 'supply', baseDecay = 9999 },
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get a recipe by its key
---@param recipeKey string The recipe identifier
---@return table|nil Recipe data or nil if not found
function Config.GetRecipe(recipeKey)
    return Config.Recipes.Items[recipeKey]
end

--- Get all recipes for a specific restaurant type
---@param restaurantType string The restaurant type (fastfood, pizzeria, etc.)
---@param includeExclusive? boolean Include location-exclusive items (default: true)
---@return table Array of recipe keys
function Config.GetRecipesByRestaurantType(restaurantType, includeExclusive)
    if includeExclusive == nil then includeExclusive = true end
    
    local recipes = {}
    for key, recipe in pairs(Config.Recipes.Items) do
        -- Skip hidden recipes
        if recipe.hidden then goto continue end
        
        -- Check restaurant type
        local matchesType = false
        for _, rType in ipairs(recipe.restaurantTypes or {}) do
            if rType == restaurantType then
                matchesType = true
                break
            end
        end
        
        if matchesType then
            -- Handle exclusivity
            if recipe.exclusive and not includeExclusive then
                goto continue
            end
            
            recipes[#recipes + 1] = key
        end
        
        ::continue::
    end
    return recipes
end

--- Get all recipes in a specific category
---@param category string The food category
---@return table Array of recipe keys
function Config.GetRecipesByCategory(category)
    local recipes = {}
    for key, recipe in pairs(Config.Recipes.Items) do
        if recipe.hidden then goto continue end
        
        for _, cat in ipairs(recipe.categories or {}) do
            if cat == category then
                recipes[#recipes + 1] = key
                break
            end
        end
        
        ::continue::
    end
    return recipes
end

--- Get all recipes available at a specific location
---@param locationJob string The job name for the location
---@param restaurantType string The restaurant type
---@return table Array of recipe keys
function Config.GetRecipesForLocation(locationJob, restaurantType)
    local recipes = {}
    for key, recipe in pairs(Config.Recipes.Items) do
        -- Skip hidden recipes
        if recipe.hidden then goto continue end
        
        -- Check restaurant type match
        local matchesType = false
        for _, rType in ipairs(recipe.restaurantTypes or {}) do
            if rType == restaurantType then
                matchesType = true
                break
            end
        end
        
        if not matchesType then goto continue end
        
        -- Check exclusivity
        if recipe.exclusive then
            -- Only include if this is the exclusive location
            if recipe.exclusive == locationJob then
                recipes[#recipes + 1] = key
            end
        else
            -- Include non-exclusive recipes
            recipes[#recipes + 1] = key
        end
        
        ::continue::
    end
    return recipes
end

--- Get all recipes of a specific tier
---@param tier string The tier name (basic, standard, advanced, signature)
---@return table Array of recipe keys
function Config.GetRecipesByTier(tier)
    local recipes = {}
    for key, recipe in pairs(Config.Recipes.Items) do
        if recipe.hidden then goto continue end
        
        if recipe.tier == tier then
            recipes[#recipes + 1] = key
        end
        
        ::continue::
    end
    return recipes
end

--- Check if a recipe is available based on player level
---@param recipeKey string The recipe identifier
---@param playerLevel number The player's cooking skill level
---@return boolean isAvailable
---@return string|nil reason Reason if not available
function Config.CanCraftRecipe(recipeKey, playerLevel)
    local recipe = Config.GetRecipe(recipeKey)
    if not recipe then
        return false, 'Recipe not found'
    end
    
    if recipe.hidden then
        return false, 'Recipe is hidden'
    end
    
    local levelReq = recipe.levelRequired or 0
    if playerLevel < levelReq then
        return false, ('Requires level %d'):format(levelReq)
    end
    
    return true, nil
end

--- Get ingredient data
---@param ingredientKey string The ingredient identifier
---@return table|nil Ingredient data or nil
function Config.GetIngredient(ingredientKey)
    return Config.Recipes.Ingredients[ingredientKey]
end

--- Get tier configuration
---@param tierName string The tier name
---@return table|nil Tier config or nil
function Config.GetTier(tierName)
    return Config.Recipes.Tiers[tierName]
end

--- Calculate recipe price with quality and tier multipliers
---@param recipeKey string The recipe identifier
---@param quality? number Quality percentage (0-100)
---@return number Final price
function Config.CalculateRecipePrice(recipeKey, quality)
    local recipe = Config.GetRecipe(recipeKey)
    if not recipe then return 0 end
    
    quality = quality or 75
    
    local basePrice = recipe.basePrice or 10
    local tier = Config.GetTier(recipe.tier)
    local tierMultiplier = tier and tier.priceMultiplier or 1.0
    
    -- Quality multiplier (70-130% based on quality)
    local qualityMultiplier = 0.7 + (quality / 100) * 0.6
    
    return math.floor(basePrice * tierMultiplier * qualityMultiplier)
end

--- Check if a recipe requires premium ingredients
---@param recipeKey string The recipe identifier
---@return boolean
function Config.RecipeRequiresPremiumIngredients(recipeKey)
    local recipe = Config.GetRecipe(recipeKey)
    if not recipe then return false end
    
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        if ingredient.minQuality then
            return true
        end
    end
    
    return false
end

return Config
