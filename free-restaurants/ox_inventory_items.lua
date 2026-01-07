--[[
    FREE-RESTAURANTS OX_INVENTORY ITEMS

    Add these items to your ox_inventory items.lua file.

    Categories:
    - Raw Ingredients (proteins, dairy, produce, bakery, condiments)
    - Prepared Foods (burgers, pizzas, drinks, etc.)
    - Supplies (cups, containers, etc.)
    - Bar Items (alcohol, mixers, garnishes)
]]

-- ============================================================================
-- RAW INGREDIENTS - PROTEINS
-- ============================================================================
['beef_patty'] = { label = 'Beef Patty', weight = 200, stack = true, close = true, description = 'Raw beef patty for cooking' },
['beef_patty_mini'] = { label = 'Mini Beef Patty', weight = 100, stack = true, close = true, description = 'Small beef patty for sliders' },
['chicken_breast'] = { label = 'Chicken Breast', weight = 250, stack = true, close = true, description = 'Raw chicken breast' },
['chicken_wings'] = { label = 'Chicken Wings', weight = 300, stack = true, close = true, description = 'Raw chicken wings' },
['fish_fillet'] = { label = 'Fish Fillet', weight = 200, stack = true, close = true, description = 'Fresh fish fillet' },
['bacon'] = { label = 'Bacon', weight = 150, stack = true, close = true, description = 'Strips of bacon' },
['ham'] = { label = 'Ham', weight = 200, stack = true, close = true, description = 'Sliced ham' },
['pepperoni'] = { label = 'Pepperoni', weight = 100, stack = true, close = true, description = 'Sliced pepperoni' },
['italian_sausage'] = { label = 'Italian Sausage', weight = 200, stack = true, close = true, description = 'Italian sausage' },
['prosciutto'] = { label = 'Prosciutto', weight = 100, stack = true, close = true, description = 'Aged prosciutto' },
['ground_beef'] = { label = 'Ground Beef', weight = 250, stack = true, close = true, description = 'Ground beef' },
['steak'] = { label = 'Steak', weight = 300, stack = true, close = true, description = 'Raw steak for grilling' },
['pork'] = { label = 'Pork', weight = 300, stack = true, close = true, description = 'Raw pork for cooking' },

-- ============================================================================
-- RAW INGREDIENTS - DAIRY
-- ============================================================================
['cheese_slice'] = { label = 'Cheese Slice', weight = 30, stack = true, close = true, description = 'American cheese slice' },
['mozzarella'] = { label = 'Mozzarella', weight = 150, stack = true, close = true, description = 'Fresh mozzarella cheese' },
['cheddar_cheese'] = { label = 'Cheddar Cheese', weight = 150, stack = true, close = true, description = 'Sharp cheddar cheese' },
['parmesan'] = { label = 'Parmesan', weight = 100, stack = true, close = true, description = 'Aged parmesan cheese' },
['ricotta'] = { label = 'Ricotta', weight = 200, stack = true, close = true, description = 'Ricotta cheese' },
['cream_cheese'] = { label = 'Cream Cheese', weight = 150, stack = true, close = true, description = 'Cream cheese spread' },
['sour_cream'] = { label = 'Sour Cream', weight = 150, stack = true, close = true, description = 'Sour cream' },
['milk'] = { label = 'Milk', weight = 250, stack = true, close = true, description = 'Fresh milk' },
['butter'] = { label = 'Butter', weight = 100, stack = true, close = true, description = 'Butter' },
['whipped_cream'] = { label = 'Whipped Cream', weight = 100, stack = true, close = true, description = 'Whipped cream' },
['cheese_sauce'] = { label = 'Cheese Sauce', weight = 200, stack = true, close = true, description = 'Nacho cheese sauce' },
['cotija_cheese'] = { label = 'Cotija Cheese', weight = 100, stack = true, close = true, description = 'Mexican crumbling cheese' },

-- ============================================================================
-- RAW INGREDIENTS - PRODUCE
-- ============================================================================
['lettuce'] = { label = 'Lettuce', weight = 50, stack = true, close = true, description = 'Fresh lettuce' },
['romaine_lettuce'] = { label = 'Romaine Lettuce', weight = 75, stack = true, close = true, description = 'Fresh romaine lettuce' },
['arugula'] = { label = 'Arugula', weight = 50, stack = true, close = true, description = 'Fresh arugula' },
['tomato_slice'] = { label = 'Tomato Slice', weight = 30, stack = true, close = true, description = 'Fresh tomato slice' },
['onion'] = { label = 'Onion', weight = 100, stack = true, close = true, description = 'Fresh onion' },
['onion_slice'] = { label = 'Onion Slice', weight = 20, stack = true, close = true, description = 'Sliced onion' },
['red_onion'] = { label = 'Red Onion', weight = 100, stack = true, close = true, description = 'Fresh red onion' },
['pickles'] = { label = 'Pickles', weight = 50, stack = true, close = true, description = 'Dill pickles' },
['jalapeno'] = { label = 'Jalapeno', weight = 30, stack = true, close = true, description = 'Fresh jalapeno peppers' },
['bell_pepper'] = { label = 'Bell Pepper', weight = 100, stack = true, close = true, description = 'Fresh bell pepper' },
['mushroom'] = { label = 'Mushrooms', weight = 75, stack = true, close = true, description = 'Fresh mushrooms' },
['black_olives'] = { label = 'Black Olives', weight = 50, stack = true, close = true, description = 'Sliced black olives' },
['potato'] = { label = 'Potato', weight = 200, stack = true, close = true, description = 'Fresh potato' },
['basil'] = { label = 'Fresh Basil', weight = 20, stack = true, close = true, description = 'Fresh basil leaves' },
['mint_leaves'] = { label = 'Mint Leaves', weight = 20, stack = true, close = true, description = 'Fresh mint leaves' },
['cilantro'] = { label = 'Cilantro', weight = 20, stack = true, close = true, description = 'Fresh cilantro' },
['parsley'] = { label = 'Parsley', weight = 20, stack = true, close = true, description = 'Fresh parsley' },
['chives'] = { label = 'Chives', weight = 20, stack = true, close = true, description = 'Fresh chives' },
['lime'] = { label = 'Lime', weight = 50, stack = true, close = true, description = 'Fresh lime' },
['lime_wedge'] = { label = 'Lime Wedge', weight = 10, stack = true, close = true, description = 'Lime wedge for garnish' },
['lemon_juice'] = { label = 'Lemon Juice', weight = 50, stack = true, close = true, description = 'Fresh lemon juice' },
['orange_peel'] = { label = 'Orange Peel', weight = 10, stack = true, close = true, description = 'Orange peel for garnish' },
['orange_zest'] = { label = 'Orange Zest', weight = 10, stack = true, close = true, description = 'Orange zest' },
['orange_juice'] = { label = 'Orange Juice', weight = 200, stack = true, close = true, description = 'Fresh orange juice' },
['pineapple'] = { label = 'Pineapple', weight = 300, stack = true, close = true, description = 'Fresh pineapple chunks' },
['pineapple_juice'] = { label = 'Pineapple Juice', weight = 200, stack = true, close = true, description = 'Pineapple juice' },
['passion_fruit'] = { label = 'Passion Fruit', weight = 50, stack = true, close = true, description = 'Fresh passion fruit' },
['blueberries'] = { label = 'Blueberries', weight = 100, stack = true, close = true, description = 'Fresh blueberries' },
['celery'] = { label = 'Celery', weight = 50, stack = true, close = true, description = 'Fresh celery sticks' },
['cabbage'] = { label = 'Cabbage', weight = 200, stack = true, close = true, description = 'Fresh cabbage' },
['olive'] = { label = 'Olive', weight = 10, stack = true, close = true, description = 'Cocktail olive' },
['edible_flower'] = { label = 'Edible Flower', weight = 5, stack = true, close = true, description = 'Edible flower garnish' },
['avocado'] = { label = 'Avocado', weight = 150, stack = true, close = true, description = 'Fresh avocado' },
['corn'] = { label = 'Corn', weight = 200, stack = true, close = true, description = 'Fresh corn on the cob' },
['chili_powder'] = { label = 'Chili Powder', weight = 20, stack = true, close = true, description = 'Chili powder seasoning' },

-- ============================================================================
-- RAW INGREDIENTS - BAKERY/DOUGH
-- ============================================================================
['burger_bun'] = { label = 'Burger Bun', weight = 75, stack = true, close = true, description = 'Fresh burger bun' },
['slider_bun'] = { label = 'Slider Bun', weight = 40, stack = true, close = true, description = 'Mini slider bun' },
['pizza_dough'] = { label = 'Pizza Dough', weight = 300, stack = true, close = true, description = 'Fresh pizza dough' },
['flour_tortilla'] = { label = 'Flour Tortilla', weight = 50, stack = true, close = true, description = 'Flour tortilla' },
['corn_tortilla'] = { label = 'Corn Tortilla', weight = 40, stack = true, close = true, description = 'Corn tortilla' },
['bagel'] = { label = 'Bagel', weight = 100, stack = true, close = true, description = 'Fresh bagel' },
['croissant_dough'] = { label = 'Croissant Dough', weight = 150, stack = true, close = true, description = 'Laminated croissant dough' },
['danish_dough'] = { label = 'Danish Dough', weight = 150, stack = true, close = true, description = 'Danish pastry dough' },
['cinnamon_roll_dough'] = { label = 'Cinnamon Roll Dough', weight = 200, stack = true, close = true, description = 'Cinnamon roll dough' },
['muffin_batter'] = { label = 'Muffin Batter', weight = 150, stack = true, close = true, description = 'Muffin batter' },
['croutons'] = { label = 'Croutons', weight = 50, stack = true, close = true, description = 'Crispy croutons' },
['tortilla_chips'] = { label = 'Tortilla Chips', weight = 100, stack = true, close = true, description = 'Crispy tortilla chips' },

-- ============================================================================
-- RAW INGREDIENTS - SAUCES/CONDIMENTS
-- ============================================================================
['ketchup'] = { label = 'Ketchup', weight = 50, stack = true, close = true, description = 'Ketchup' },
['mayo'] = { label = 'Mayonnaise', weight = 50, stack = true, close = true, description = 'Mayonnaise' },
['special_sauce'] = { label = 'Special Sauce', weight = 50, stack = true, close = true, description = 'Secret special sauce' },
['tomato_sauce'] = { label = 'Tomato Sauce', weight = 150, stack = true, close = true, description = 'Tomato sauce' },
['marinara_sauce'] = { label = 'Marinara Sauce', weight = 150, stack = true, close = true, description = 'Marinara sauce' },
['bbq_sauce'] = { label = 'BBQ Sauce', weight = 100, stack = true, close = true, description = 'BBQ sauce' },
['buffalo_sauce'] = { label = 'Buffalo Sauce', weight = 100, stack = true, close = true, description = 'Spicy buffalo sauce' },
['tartar_sauce'] = { label = 'Tartar Sauce', weight = 50, stack = true, close = true, description = 'Tartar sauce' },
['caesar_dressing'] = { label = 'Caesar Dressing', weight = 100, stack = true, close = true, description = 'Caesar salad dressing' },
['ranch_dressing'] = { label = 'Ranch Dressing', weight = 100, stack = true, close = true, description = 'Ranch dressing' },
['garlic_butter'] = { label = 'Garlic Butter', weight = 75, stack = true, close = true, description = 'Garlic herb butter' },
['olive_oil'] = { label = 'Olive Oil', weight = 100, stack = true, close = true, description = 'Extra virgin olive oil' },
['truffle_oil'] = { label = 'Truffle Oil', weight = 50, stack = true, close = true, description = 'White truffle oil' },
['balsamic_glaze'] = { label = 'Balsamic Glaze', weight = 50, stack = true, close = true, description = 'Aged balsamic glaze' },
['gravy'] = { label = 'Gravy', weight = 100, stack = true, close = true, description = 'Brown gravy' },
['salsa'] = { label = 'Salsa', weight = 100, stack = true, close = true, description = 'Fresh salsa' },
['chipotle_mayo'] = { label = 'Chipotle Mayo', weight = 50, stack = true, close = true, description = 'Spicy chipotle mayo' },

-- ============================================================================
-- RAW INGREDIENTS - MISCELLANEOUS
-- ============================================================================
['breading'] = { label = 'Breading', weight = 100, stack = true, close = true, description = 'Seasoned breading mix' },
['salt'] = { label = 'Salt', weight = 20, stack = true, close = true, description = 'Salt' },
['sugar'] = { label = 'Sugar', weight = 50, stack = true, close = true, description = 'Sugar' },
['sugar_cube'] = { label = 'Sugar Cube', weight = 5, stack = true, close = true, description = 'Sugar cube for drinks' },
['cinnamon_sugar'] = { label = 'Cinnamon Sugar', weight = 50, stack = true, close = true, description = 'Cinnamon sugar mix' },
['cream_cheese_frosting'] = { label = 'Cream Cheese Frosting', weight = 100, stack = true, close = true, description = 'Cream cheese frosting' },
['sugar_glaze'] = { label = 'Sugar Glaze', weight = 50, stack = true, close = true, description = 'Sweet sugar glaze' },
['ice'] = { label = 'Ice', weight = 50, stack = true, close = true, description = 'Ice cubes' },
['hot_water'] = { label = 'Hot Water', weight = 100, stack = true, close = true, description = 'Hot water' },
['rice'] = { label = 'Rice', weight = 150, stack = true, close = true, description = 'Cooked rice' },
['beans'] = { label = 'Beans', weight = 150, stack = true, close = true, description = 'Cooked beans' },

-- ============================================================================
-- RAW INGREDIENTS - COFFEE/TEA
-- ============================================================================
['coffee_beans'] = { label = 'Coffee Beans', weight = 50, stack = true, close = true, description = 'Fresh roasted coffee beans' },
['tea_bag_black'] = { label = 'Black Tea Bag', weight = 10, stack = true, close = true, description = 'Black tea bag' },
['chai_concentrate'] = { label = 'Chai Concentrate', weight = 150, stack = true, close = true, description = 'Spiced chai concentrate' },
['chocolate_syrup'] = { label = 'Chocolate Syrup', weight = 100, stack = true, close = true, description = 'Chocolate syrup' },
['vanilla_syrup'] = { label = 'Vanilla Syrup', weight = 100, stack = true, close = true, description = 'Vanilla syrup' },
['caramel_syrup'] = { label = 'Caramel Syrup', weight = 100, stack = true, close = true, description = 'Caramel syrup' },
['ice_cream_vanilla'] = { label = 'Vanilla Ice Cream', weight = 150, stack = true, close = true, description = 'Vanilla ice cream' },
['ice_cream_chocolate'] = { label = 'Chocolate Ice Cream', weight = 150, stack = true, close = true, description = 'Chocolate ice cream' },
['coconut_cream'] = { label = 'Coconut Cream', weight = 100, stack = true, close = true, description = 'Coconut cream' },

-- ============================================================================
-- RAW INGREDIENTS - ALCOHOL/BAR
-- ============================================================================
['vodka'] = { label = 'Vodka', weight = 200, stack = true, close = true, description = 'Premium vodka' },
['gin'] = { label = 'Gin', weight = 200, stack = true, close = true, description = 'London dry gin' },
['white_rum'] = { label = 'White Rum', weight = 200, stack = true, close = true, description = 'White rum' },
['tequila'] = { label = 'Tequila', weight = 200, stack = true, close = true, description = 'Premium tequila' },
['whiskey'] = { label = 'Whiskey', weight = 200, stack = true, close = true, description = 'Bourbon whiskey' },
['bourbon'] = { label = 'Bourbon', weight = 200, stack = true, close = true, description = 'Kentucky bourbon' },
['triple_sec'] = { label = 'Triple Sec', weight = 150, stack = true, close = true, description = 'Orange liqueur' },
['dry_vermouth'] = { label = 'Dry Vermouth', weight = 150, stack = true, close = true, description = 'Dry vermouth' },
['simple_syrup'] = { label = 'Simple Syrup', weight = 100, stack = true, close = true, description = 'Simple syrup' },
['grenadine'] = { label = 'Grenadine', weight = 100, stack = true, close = true, description = 'Grenadine syrup' },
['agave_nectar'] = { label = 'Agave Nectar', weight = 100, stack = true, close = true, description = 'Agave nectar sweetener' },
['angostura_bitters'] = { label = 'Angostura Bitters', weight = 50, stack = true, close = true, description = 'Angostura bitters' },
['cranberry_juice'] = { label = 'Cranberry Juice', weight = 150, stack = true, close = true, description = 'Cranberry juice' },
['lime_juice'] = { label = 'Lime Juice', weight = 100, stack = true, close = true, description = 'Fresh lime juice' },
['soda_water'] = { label = 'Soda Water', weight = 150, stack = true, close = true, description = 'Sparkling soda water' },
['cola'] = { label = 'Cola', weight = 150, stack = true, close = true, description = 'Cola for mixing' },
['beer_domestic'] = { label = 'Domestic Beer', weight = 200, stack = true, close = true, description = 'Domestic beer tap' },
['beer_import'] = { label = 'Imported Beer', weight = 200, stack = true, close = true, description = 'Imported beer' },
['beer_tap'] = { label = 'Draft Beer', weight = 300, stack = true, close = true, description = 'Beer from tap' },

-- ============================================================================
-- SUPPLIES - CUPS/CONTAINERS
-- ============================================================================
['cup_small'] = { label = 'Small Cup', weight = 10, stack = true, close = true, description = 'Small drink cup' },
['cup_medium'] = { label = 'Medium Cup', weight = 15, stack = true, close = true, description = 'Medium drink cup' },
['cup_large'] = { label = 'Large Cup', weight = 20, stack = true, close = true, description = 'Large drink cup' },
['cup_espresso'] = { label = 'Espresso Cup', weight = 10, stack = true, close = true, description = 'Small espresso cup' },
['shot_glass'] = { label = 'Shot Glass', weight = 20, stack = true, close = true, description = 'Shot glass' },
['pint_glass'] = { label = 'Pint Glass', weight = 50, stack = true, close = true, description = 'Pint glass for beer' },
['kids_toy'] = { label = 'Kids Toy', weight = 50, stack = true, close = true, description = 'Happy meal toy' },
['onion_rings'] = { label = 'Onion Rings', weight = 100, stack = true, close = true, description = 'Crispy onion rings' },

-- ============================================================================
-- DRINK SYRUPS
-- ============================================================================
['sprunk_syrup'] = { label = 'Sprunk Syrup', weight = 100, stack = true, close = true, description = 'Sprunk soda syrup' },
['ecola_syrup'] = { label = 'eCola Syrup', weight = 100, stack = true, close = true, description = 'eCola soda syrup' },

-- ============================================================================
-- PREPARED FOODS - BURGERS
-- ============================================================================
['bleeder_burger'] = { label = 'The Bleeder', weight = 350, stack = true, close = true, description = 'Classic Burger Shot burger', client = { status = { hunger = 250000 } } },
['bleeder_burger_premium'] = { label = 'The Bleeder (Premium)', weight = 400, stack = true, close = true, description = 'Premium version with fresh ingredients', client = { status = { hunger = 350000 } } },
['double_barreled_burger'] = { label = 'Double Barreled', weight = 450, stack = true, close = true, description = 'Double patty burger', client = { status = { hunger = 400000 } } },
['meat_stack_burger'] = { label = 'Meat Stack', weight = 550, stack = true, close = true, description = 'Triple patty monster', client = { status = { hunger = 500000 } } },
['beef_tower_burger'] = { label = 'Beef Tower', weight = 700, stack = true, close = true, description = 'Four patty behemoth', client = { status = { hunger = 600000 } } },
['heart_stopper_burger'] = { label = 'Heart Stopper', weight = 1000, stack = true, close = true, description = 'The legendary seven patty challenge', client = { status = { hunger = 900000 } } },
['chicken_burger'] = { label = 'Chicken Burger', weight = 350, stack = true, close = true, description = 'Crispy chicken sandwich', client = { status = { hunger = 250000 } } },
['fish_sandwich'] = { label = 'Fishy Shit Sandwich', weight = 300, stack = true, close = true, description = 'Fish fillet sandwich', client = { status = { hunger = 200000 } } },
['sliders'] = { label = 'Sliders', weight = 200, stack = true, close = true, description = 'Mini burgers', client = { status = { hunger = 150000 } } },

-- ============================================================================
-- PREPARED FOODS - SIDES
-- ============================================================================
['fries_small'] = { label = 'Small Fries', weight = 100, stack = true, close = true, description = 'Small order of fries', client = { status = { hunger = 100000 } } },
['fries_large'] = { label = 'Large Fries', weight = 200, stack = true, close = true, description = 'Large order of fries', client = { status = { hunger = 200000 } } },
['loaded_fries'] = { label = 'Loaded Fries', weight = 350, stack = true, close = true, description = 'Fries with all the toppings', client = { status = { hunger = 350000 } } },
['chicken_nuggets_6'] = { label = 'Chicken Nuggets (6pc)', weight = 150, stack = true, close = true, description = '6 piece chicken nuggets', client = { status = { hunger = 150000 } } },
['chicken_nuggets_12'] = { label = 'Chicken Nuggets (12pc)', weight = 300, stack = true, close = true, description = '12 piece chicken nuggets', client = { status = { hunger = 300000 } } },
['mozzarella_sticks'] = { label = 'Mozzarella Sticks', weight = 200, stack = true, close = true, description = 'Fried mozzarella sticks', client = { status = { hunger = 200000 } } },

-- ============================================================================
-- PREPARED FOODS - COMBO MEALS
-- ============================================================================
['moo_kids_meal'] = { label = 'Moo Kids Meal', weight = 400, stack = true, close = true, description = 'Kids meal with toy', client = { status = { hunger = 350000, thirst = 100000 } } },
['bleeder_meal'] = { label = 'Bleeder Meal', weight = 600, stack = true, close = true, description = 'Combo with fries and drink', client = { status = { hunger = 450000, thirst = 150000 } } },

-- ============================================================================
-- PREPARED FOODS - DRINKS (SODA)
-- ============================================================================
['sprunk_small'] = { label = 'Sprunk (Small)', weight = 200, stack = true, close = true, description = 'Small Sprunk soda', client = { status = { thirst = 150000 } } },
['sprunk_large'] = { label = 'Sprunk (Large)', weight = 400, stack = true, close = true, description = 'Large Sprunk soda', client = { status = { thirst = 300000 } } },
['ecola_small'] = { label = 'eCola (Small)', weight = 200, stack = true, close = true, description = 'Small eCola', client = { status = { thirst = 150000 } } },
['ecola_large'] = { label = 'eCola (Large)', weight = 400, stack = true, close = true, description = 'Large eCola', client = { status = { thirst = 300000 } } },

-- ============================================================================
-- PREPARED FOODS - MILKSHAKES
-- ============================================================================
['milkshake_vanilla'] = { label = 'Vanilla Milkshake', weight = 400, stack = true, close = true, description = 'Creamy vanilla milkshake', client = { status = { hunger = 150000, thirst = 200000 } } },
['milkshake_chocolate'] = { label = 'Chocolate Milkshake', weight = 400, stack = true, close = true, description = 'Rich chocolate milkshake', client = { status = { hunger = 150000, thirst = 200000 } } },
['meat_shake'] = { label = 'Meat Shake', weight = 400, stack = true, close = true, description = 'The infamous meat shake', client = { status = { hunger = 200000, thirst = 100000 } } },

-- ============================================================================
-- PREPARED FOODS - PIZZA
-- ============================================================================
['pizza_cheese'] = { label = 'Cheese Pizza', weight = 600, stack = true, close = true, description = 'Classic cheese pizza', client = { status = { hunger = 500000 } } },
['pizza_cheese_premium'] = { label = 'Premium Cheese Pizza', weight = 650, stack = true, close = true, description = 'Margherita with buffalo mozzarella', client = { status = { hunger = 600000 } } },
['pizza_pepperoni'] = { label = 'Pepperoni Pizza', weight = 650, stack = true, close = true, description = 'Pepperoni pizza', client = { status = { hunger = 550000 } } },
['pizza_meat_lovers'] = { label = 'Meat Lovers Pizza', weight = 750, stack = true, close = true, description = 'Loaded with all the meats', client = { status = { hunger = 700000 } } },
['pizza_supreme'] = { label = 'Supreme Pizza', weight = 750, stack = true, close = true, description = 'Everything on it', client = { status = { hunger = 700000 } } },
['pizza_margherita'] = { label = 'Margherita Pizza', weight = 600, stack = true, close = true, description = 'Traditional margherita', client = { status = { hunger = 500000 } } },
['pizza_hawaiian'] = { label = 'Hawaiian Pizza', weight = 650, stack = true, close = true, description = 'Controversial but delicious', client = { status = { hunger = 550000 } } },
['pizza_bbq_chicken'] = { label = 'BBQ Chicken Pizza', weight = 700, stack = true, close = true, description = 'BBQ chicken pizza', client = { status = { hunger = 600000 } } },
['pizza_vinewood'] = { label = 'Vinewood Special', weight = 700, stack = true, close = true, description = 'Premium gourmet pizza', client = { status = { hunger = 650000 } } },
['calzone'] = { label = 'Calzone', weight = 500, stack = true, close = true, description = 'Folded pizza pocket', client = { status = { hunger = 450000 } } },

-- ============================================================================
-- PREPARED FOODS - PIZZA SIDES
-- ============================================================================
['breadsticks'] = { label = 'Breadsticks', weight = 200, stack = true, close = true, description = 'Garlic breadsticks', client = { status = { hunger = 150000 } } },
['garlic_knots'] = { label = 'Garlic Knots', weight = 200, stack = true, close = true, description = 'Garlic knots', client = { status = { hunger = 150000 } } },
['wings_buffalo'] = { label = 'Buffalo Wings', weight = 350, stack = true, close = true, description = 'Spicy buffalo wings', client = { status = { hunger = 300000 } } },
['caesar_salad'] = { label = 'Caesar Salad', weight = 250, stack = true, close = true, description = 'Classic caesar salad', client = { status = { hunger = 150000 } } },

-- ============================================================================
-- PREPARED FOODS - COFFEE/TEA
-- ============================================================================
['espresso'] = { label = 'Espresso', weight = 50, stack = true, close = true, description = 'Single shot espresso', client = { status = { thirst = 50000 } } },
['espresso_double'] = { label = 'Double Espresso', weight = 75, stack = true, close = true, description = 'Double shot espresso', client = { status = { thirst = 75000 } } },
['americano'] = { label = 'Americano', weight = 200, stack = true, close = true, description = 'Espresso with hot water', client = { status = { thirst = 200000 } } },
['latte'] = { label = 'Latte', weight = 300, stack = true, close = true, description = 'Espresso with steamed milk', client = { status = { thirst = 250000 } } },
['latte_premium'] = { label = 'Premium Latte', weight = 300, stack = true, close = true, description = 'Single origin latte', client = { status = { thirst = 300000 } } },
['cappuccino'] = { label = 'Cappuccino', weight = 250, stack = true, close = true, description = 'Espresso with foamed milk', client = { status = { thirst = 200000 } } },
['mocha'] = { label = 'Mocha', weight = 350, stack = true, close = true, description = 'Chocolate espresso drink', client = { status = { hunger = 100000, thirst = 250000 } } },
['macchiato'] = { label = 'Macchiato', weight = 100, stack = true, close = true, description = 'Espresso marked with foam', client = { status = { thirst = 75000 } } },
['flat_white'] = { label = 'Flat White', weight = 250, stack = true, close = true, description = 'Double shot with microfoam', client = { status = { thirst = 200000 } } },
['hot_chocolate'] = { label = 'Hot Chocolate', weight = 300, stack = true, close = true, description = 'Rich hot chocolate', client = { status = { hunger = 50000, thirst = 200000 } } },
['chai_latte'] = { label = 'Chai Latte', weight = 300, stack = true, close = true, description = 'Spiced chai with milk', client = { status = { thirst = 250000 } } },
['tea_black'] = { label = 'Black Tea', weight = 200, stack = true, close = true, description = 'Hot black tea', client = { status = { thirst = 200000 } } },
['iced_coffee'] = { label = 'Iced Coffee', weight = 350, stack = true, close = true, description = 'Cold brewed coffee', client = { status = { thirst = 300000 } } },
['iced_latte'] = { label = 'Iced Latte', weight = 350, stack = true, close = true, description = 'Cold espresso with milk', client = { status = { thirst = 300000 } } },
['cold_brew'] = { label = 'Cold Brew', weight = 350, stack = true, close = true, description = 'Smooth cold brew', client = { status = { thirst = 300000 } } },
['frappuccino'] = { label = 'Frappuccino', weight = 400, stack = true, close = true, description = 'Blended iced coffee', client = { status = { hunger = 100000, thirst = 300000 } } },

-- ============================================================================
-- PREPARED FOODS - BAKERY
-- ============================================================================
['croissant'] = { label = 'Croissant', weight = 100, stack = true, close = true, description = 'Buttery croissant', client = { status = { hunger = 100000 } } },
['danish_cheese'] = { label = 'Cheese Danish', weight = 120, stack = true, close = true, description = 'Sweet cheese danish', client = { status = { hunger = 120000 } } },
['cinnamon_roll'] = { label = 'Cinnamon Roll', weight = 150, stack = true, close = true, description = 'Warm cinnamon roll', client = { status = { hunger = 150000 } } },
['muffin_blueberry'] = { label = 'Blueberry Muffin', weight = 120, stack = true, close = true, description = 'Fresh blueberry muffin', client = { status = { hunger = 120000 } } },
['bagel_cream_cheese'] = { label = 'Bagel with Cream Cheese', weight = 200, stack = true, close = true, description = 'Bagel with cream cheese', client = { status = { hunger = 200000 } } },

-- ============================================================================
-- PREPARED FOODS - MEXICAN/TACOS
-- ============================================================================
['carne_asada_taco'] = { label = 'Carne Asada Taco', weight = 150, stack = true, close = true, description = 'Grilled steak taco', client = { status = { hunger = 200000 } } },
['chicken_taco'] = { label = 'Chicken Taco', weight = 150, stack = true, close = true, description = 'Seasoned chicken taco', client = { status = { hunger = 180000 } } },
['carnitas_taco'] = { label = 'Carnitas Taco', weight = 175, stack = true, close = true, description = 'Slow-cooked pork taco', client = { status = { hunger = 250000 } } },
['burrito'] = { label = 'Burrito', weight = 500, stack = true, close = true, description = 'Stuffed burrito', client = { status = { hunger = 450000 } } },
['quesadilla'] = { label = 'Quesadilla', weight = 350, stack = true, close = true, description = 'Cheese quesadilla', client = { status = { hunger = 300000 } } },
['nachos'] = { label = 'Nachos', weight = 400, stack = true, close = true, description = 'Loaded nachos', client = { status = { hunger = 250000 } } },
['guacamole'] = { label = 'Fresh Guacamole', weight = 250, stack = true, close = true, description = 'Fresh guacamole with chips', client = { status = { hunger = 150000 } } },
['street_corn'] = { label = 'Street Corn (Elote)', weight = 200, stack = true, close = true, description = 'Mexican street corn', client = { status = { hunger = 150000 } } },
['fish_tacos'] = { label = 'Fish Tacos', weight = 300, stack = true, close = true, description = 'Crispy fish tacos', client = { status = { hunger = 400000 } } },

-- ============================================================================
-- PREPARED FOODS - BAR COCKTAILS
-- ============================================================================
['margarita'] = { label = 'Margarita', weight = 250, stack = true, close = true, description = 'Classic lime margarita', client = { status = { thirst = 200000 } } },
['margarita_premium'] = { label = 'Premium Margarita', weight = 300, stack = true, close = true, description = 'Top shelf margarita', client = { status = { thirst = 250000 } } },
['martini'] = { label = 'Martini', weight = 150, stack = true, close = true, description = 'Classic gin martini', client = { status = { thirst = 100000 } } },
['cosmopolitan'] = { label = 'Cosmopolitan', weight = 200, stack = true, close = true, description = 'Vodka cosmopolitan', client = { status = { thirst = 150000 } } },
['mojito'] = { label = 'Mojito', weight = 300, stack = true, close = true, description = 'Fresh mint mojito', client = { status = { thirst = 250000 } } },
['old_fashioned'] = { label = 'Old Fashioned', weight = 150, stack = true, close = true, description = 'Bourbon old fashioned', client = { status = { thirst = 100000 } } },
['whiskey_sour'] = { label = 'Whiskey Sour', weight = 200, stack = true, close = true, description = 'Classic whiskey sour', client = { status = { thirst = 150000 } } },
['long_island'] = { label = 'Long Island Iced Tea', weight = 400, stack = true, close = true, description = 'The strong one', client = { status = { thirst = 300000 } } },
['pina_colada'] = { label = 'Pina Colada', weight = 350, stack = true, close = true, description = 'Tropical pina colada', client = { status = { hunger = 50000, thirst = 250000 } } },
['tequila_sunset'] = { label = 'Tequila Sunset', weight = 300, stack = true, close = true, description = 'Beautiful layered cocktail', client = { status = { thirst = 200000 } } },
['los_santos_sunrise'] = { label = 'Los Santos Sunrise', weight = 300, stack = true, close = true, description = 'Signature house cocktail', client = { status = { thirst = 200000 } } },

-- ============================================================================
-- PREPARED FOODS - BAR SHOTS/BEER
-- ============================================================================
['shot_tequila'] = { label = 'Tequila Shot', weight = 50, stack = true, close = true, description = 'Shot of tequila', client = { status = { thirst = 25000 } } },
['shot_whiskey'] = { label = 'Whiskey Shot', weight = 50, stack = true, close = true, description = 'Shot of whiskey', client = { status = { thirst = 25000 } } },
['beer_draft'] = { label = 'Draft Beer', weight = 400, stack = true, close = true, description = 'Cold draft beer', client = { status = { thirst = 300000 } } },
['beer_bottle_domestic'] = { label = 'Domestic Beer', weight = 350, stack = true, close = true, description = 'Domestic beer bottle', client = { status = { thirst = 250000 } } },
['beer_bottle_import'] = { label = 'Imported Beer', weight = 350, stack = true, close = true, description = 'Imported beer bottle', client = { status = { thirst = 250000 } } },

-- ============================================================================
-- SPECIAL ITEMS
-- ============================================================================
['big_smoke_special'] = { label = 'Big Smoke Special', weight = 2000, stack = false, close = true, description = 'Two number 9s, a number 9 large...', client = { status = { hunger = 1000000, thirst = 500000 } } },
