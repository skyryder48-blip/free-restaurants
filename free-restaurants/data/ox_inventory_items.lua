--[[
    free-restaurants ox_inventory Items Configuration

    This file defines all items used by the restaurant system.
    Copy these items to your ox_inventory/data/items.lua file.

    Categories:
    - Depleted containers (wrappers, plates, cups, etc.)
    - Raw ingredients
    - Cooked/prepared foods
    - Beverages
    - Sushi restaurant items
    - Medical items (food poisoning treatment)
]]

-- ============================================================================
-- DEPLETED CONTAINERS (Empty items after consumption)
-- ============================================================================

-- Food Wrappers & Containers
['food_wrapper'] = {
    label = 'Food Wrapper',
    weight = 5,
    stack = true,
    close = true,
    description = 'An empty food wrapper. Dispose of properly.',
    client = {
        image = 'food_wrapper.png',
    },
},

['burger_wrapper'] = {
    label = 'Burger Wrapper',
    weight = 8,
    stack = true,
    close = true,
    description = 'A greasy burger wrapper. Dispose of properly.',
    client = {
        image = 'burger_wrapper.png',
    },
},

['taco_wrapper'] = {
    label = 'Taco Wrapper',
    weight = 5,
    stack = true,
    close = true,
    description = 'An empty taco wrapper.',
    client = {
        image = 'taco_wrapper.png',
    },
},

['pizza_box'] = {
    label = 'Empty Pizza Box',
    weight = 50,
    stack = true,
    close = true,
    description = 'An empty pizza box with some grease stains.',
    client = {
        image = 'pizza_box.png',
    },
},

['fry_container'] = {
    label = 'Empty Fry Container',
    weight = 10,
    stack = true,
    close = true,
    description = 'An empty cardboard fry container.',
    client = {
        image = 'fry_container.png',
    },
},

-- Plates & Utensils
['dirty_plate'] = {
    label = 'Dirty Plate',
    weight = 150,
    stack = true,
    close = true,
    description = 'A dirty plate with food residue. Return for washing.',
    client = {
        image = 'dirty_plate.png',
    },
},

['plate_fork'] = {
    label = 'Used Plate & Fork',
    weight = 180,
    stack = true,
    close = true,
    description = 'A used plate with a fork. Return to restaurant.',
    client = {
        image = 'plate_fork.png',
    },
},

['bowl_spoon'] = {
    label = 'Used Bowl & Spoon',
    weight = 200,
    stack = true,
    close = true,
    description = 'A used bowl with a spoon. Return to restaurant.',
    client = {
        image = 'bowl_spoon.png',
    },
},

['chopsticks_used'] = {
    label = 'Used Chopsticks',
    weight = 20,
    stack = true,
    close = true,
    description = 'A pair of used disposable chopsticks.',
    client = {
        image = 'chopsticks_used.png',
    },
},

['sushi_tray_empty'] = {
    label = 'Empty Sushi Tray',
    weight = 50,
    stack = true,
    close = true,
    description = 'An empty wooden sushi serving tray.',
    client = {
        image = 'sushi_tray_empty.png',
    },
},

-- Peels & Food Waste
['banana_peel'] = {
    label = 'Banana Peel',
    weight = 30,
    stack = true,
    close = true,
    description = 'A slippery banana peel. Dispose of properly!',
    client = {
        image = 'banana_peel.png',
    },
},

['orange_peel'] = {
    label = 'Orange Peel',
    weight = 40,
    stack = true,
    close = true,
    description = 'Orange peel fragments.',
    client = {
        image = 'orange_peel.png',
    },
},

['fruit_peel'] = {
    label = 'Fruit Peel',
    weight = 25,
    stack = true,
    close = true,
    description = 'Leftover fruit peel.',
    client = {
        image = 'fruit_peel.png',
    },
},

['popsicle_stick'] = {
    label = 'Popsicle Stick',
    weight = 5,
    stack = true,
    close = true,
    description = 'A wooden popsicle stick.',
    client = {
        image = 'popsicle_stick.png',
    },
},

-- Empty Drink Containers
['empty_cup'] = {
    label = 'Empty Cup',
    weight = 15,
    stack = true,
    close = true,
    description = 'An empty paper/plastic cup.',
    client = {
        image = 'empty_cup.png',
    },
},

['empty_cup_lid'] = {
    label = 'Empty Cup with Lid',
    weight = 20,
    stack = true,
    close = true,
    description = 'An empty drink cup with lid and straw.',
    client = {
        image = 'empty_cup_lid.png',
    },
},

['empty_coffee_cup'] = {
    label = 'Empty Coffee Cup',
    weight = 25,
    stack = true,
    close = true,
    description = 'An empty coffee cup. Still smells like coffee.',
    client = {
        image = 'empty_coffee_cup.png',
    },
},

['empty_glass'] = {
    label = 'Empty Glass',
    weight = 150,
    stack = true,
    close = true,
    description = 'An empty drinking glass. Return to bar.',
    client = {
        image = 'empty_glass.png',
    },
},

['empty_bottle'] = {
    label = 'Empty Bottle',
    weight = 100,
    stack = true,
    close = true,
    description = 'An empty glass bottle. Can be recycled.',
    client = {
        image = 'empty_bottle.png',
    },
},

['empty_can'] = {
    label = 'Empty Can',
    weight = 15,
    stack = true,
    close = true,
    description = 'An empty aluminum can. Recyclable!',
    client = {
        image = 'empty_can.png',
    },
},

['empty_wine_glass'] = {
    label = 'Empty Wine Glass',
    weight = 120,
    stack = true,
    close = true,
    description = 'An empty wine glass with residue.',
    client = {
        image = 'empty_wine_glass.png',
    },
},

['empty_cocktail_glass'] = {
    label = 'Empty Cocktail Glass',
    weight = 100,
    stack = true,
    close = true,
    description = 'An empty cocktail glass.',
    client = {
        image = 'empty_cocktail_glass.png',
    },
},

['empty_sake_cup'] = {
    label = 'Empty Sake Cup',
    weight = 50,
    stack = true,
    close = true,
    description = 'A small empty sake cup.',
    client = {
        image = 'empty_sake_cup.png',
    },
},

['empty_mug'] = {
    label = 'Empty Mug',
    weight = 200,
    stack = true,
    close = true,
    description = 'An empty ceramic mug.',
    client = {
        image = 'empty_mug.png',
    },
},

-- ============================================================================
-- SUSHI RESTAURANT - RAW INGREDIENTS
-- ============================================================================

['sushi_rice'] = {
    label = 'Sushi Rice',
    weight = 200,
    stack = true,
    close = true,
    description = 'Properly seasoned sushi rice.',
    client = {
        image = 'sushi_rice.png',
    },
},

['nori_sheets'] = {
    label = 'Nori Sheets',
    weight = 20,
    stack = true,
    close = true,
    description = 'Dried seaweed sheets for sushi rolls.',
    client = {
        image = 'nori_sheets.png',
    },
},

['salmon_raw'] = {
    label = 'Raw Salmon',
    weight = 300,
    stack = true,
    close = true,
    description = 'Fresh raw salmon fillet, sashimi grade.',
    client = {
        image = 'salmon_raw.png',
    },
},

['tuna_raw'] = {
    label = 'Raw Tuna',
    weight = 300,
    stack = true,
    close = true,
    description = 'Fresh raw tuna, sashimi grade.',
    client = {
        image = 'tuna_raw.png',
    },
},

['yellowtail_raw'] = {
    label = 'Raw Yellowtail',
    weight = 280,
    stack = true,
    close = true,
    description = 'Fresh hamachi (yellowtail), sashimi grade.',
    client = {
        image = 'yellowtail_raw.png',
    },
},

['shrimp_raw'] = {
    label = 'Raw Shrimp',
    weight = 150,
    stack = true,
    close = true,
    description = 'Fresh raw shrimp, cleaned and deveined.',
    client = {
        image = 'shrimp_raw.png',
    },
},

['eel_raw'] = {
    label = 'Fresh Eel',
    weight = 250,
    stack = true,
    close = true,
    description = 'Fresh unagi (eel), ready for grilling.',
    client = {
        image = 'eel_raw.png',
    },
},

['crab_meat'] = {
    label = 'Crab Meat',
    weight = 200,
    stack = true,
    close = true,
    description = 'Fresh picked crab meat.',
    client = {
        image = 'crab_meat.png',
    },
},

['octopus_raw'] = {
    label = 'Raw Octopus',
    weight = 220,
    stack = true,
    close = true,
    description = 'Cleaned and prepared octopus.',
    client = {
        image = 'octopus_raw.png',
    },
},

['tobiko'] = {
    label = 'Tobiko',
    weight = 50,
    stack = true,
    close = true,
    description = 'Flying fish roe - orange fish eggs.',
    client = {
        image = 'tobiko.png',
    },
},

['masago'] = {
    label = 'Masago',
    weight = 50,
    stack = true,
    close = true,
    description = 'Capelin roe - small fish eggs.',
    client = {
        image = 'masago.png',
    },
},

['wasabi'] = {
    label = 'Wasabi',
    weight = 30,
    stack = true,
    close = true,
    description = 'Fresh wasabi paste - very spicy!',
    client = {
        image = 'wasabi.png',
    },
},

['pickled_ginger'] = {
    label = 'Pickled Ginger',
    weight = 50,
    stack = true,
    close = true,
    description = 'Pink pickled ginger (gari) for sushi.',
    client = {
        image = 'pickled_ginger.png',
    },
},

['soy_sauce'] = {
    label = 'Soy Sauce',
    weight = 100,
    stack = true,
    close = true,
    description = 'Traditional Japanese soy sauce.',
    client = {
        image = 'soy_sauce.png',
    },
},

['rice_vinegar'] = {
    label = 'Rice Vinegar',
    weight = 150,
    stack = true,
    close = true,
    description = 'Japanese rice vinegar for sushi rice.',
    client = {
        image = 'rice_vinegar.png',
    },
},

['sesame_seeds'] = {
    label = 'Sesame Seeds',
    weight = 30,
    stack = true,
    close = true,
    description = 'Toasted sesame seeds.',
    client = {
        image = 'sesame_seeds.png',
    },
},

['tempura_batter'] = {
    label = 'Tempura Batter',
    weight = 200,
    stack = true,
    close = true,
    description = 'Light and crispy tempura batter mix.',
    client = {
        image = 'tempura_batter.png',
    },
},

['miso_paste'] = {
    label = 'Miso Paste',
    weight = 250,
    stack = true,
    close = true,
    description = 'Fermented soybean paste for soup.',
    client = {
        image = 'miso_paste.png',
    },
},

['dashi_stock'] = {
    label = 'Dashi Stock',
    weight = 300,
    stack = true,
    close = true,
    description = 'Japanese soup stock made from kelp and bonito.',
    client = {
        image = 'dashi_stock.png',
    },
},

['tofu'] = {
    label = 'Tofu',
    weight = 200,
    stack = true,
    close = true,
    description = 'Silken tofu block.',
    client = {
        image = 'tofu.png',
    },
},

['wakame'] = {
    label = 'Wakame Seaweed',
    weight = 30,
    stack = true,
    close = true,
    description = 'Dried wakame seaweed for soup.',
    client = {
        image = 'wakame.png',
    },
},

['edamame_raw'] = {
    label = 'Edamame',
    weight = 150,
    stack = true,
    close = true,
    description = 'Fresh soybeans in pods.',
    client = {
        image = 'edamame_raw.png',
    },
},

-- Teppanyaki/Hibachi ingredients
['wagyu_beef'] = {
    label = 'Wagyu Beef',
    weight = 400,
    stack = true,
    close = true,
    description = 'Premium Japanese Wagyu beef.',
    client = {
        image = 'wagyu_beef.png',
    },
},

['filet_mignon_raw'] = {
    label = 'Filet Mignon',
    weight = 350,
    stack = true,
    close = true,
    description = 'Premium cut filet mignon.',
    client = {
        image = 'filet_mignon_raw.png',
    },
},

['chicken_teriyaki_raw'] = {
    label = 'Chicken (for Teriyaki)',
    weight = 300,
    stack = true,
    close = true,
    description = 'Chicken breast ready for teriyaki.',
    client = {
        image = 'chicken_teriyaki_raw.png',
    },
},

['lobster_tail_raw'] = {
    label = 'Lobster Tail',
    weight = 250,
    stack = true,
    close = true,
    description = 'Fresh lobster tail.',
    client = {
        image = 'lobster_tail_raw.png',
    },
},

['scallops_raw'] = {
    label = 'Sea Scallops',
    weight = 200,
    stack = true,
    close = true,
    description = 'Fresh sea scallops.',
    client = {
        image = 'scallops_raw.png',
    },
},

['bean_sprouts'] = {
    label = 'Bean Sprouts',
    weight = 100,
    stack = true,
    close = true,
    description = 'Fresh bean sprouts.',
    client = {
        image = 'bean_sprouts.png',
    },
},

['zucchini'] = {
    label = 'Zucchini',
    weight = 150,
    stack = true,
    close = true,
    description = 'Fresh zucchini.',
    client = {
        image = 'zucchini.png',
    },
},

['mushrooms'] = {
    label = 'Mushrooms',
    weight = 100,
    stack = true,
    close = true,
    description = 'Fresh button mushrooms.',
    client = {
        image = 'mushrooms.png',
    },
},

['fried_rice_base'] = {
    label = 'Steamed Rice (for Fried Rice)',
    weight = 250,
    stack = true,
    close = true,
    description = 'Day-old rice perfect for fried rice.',
    client = {
        image = 'fried_rice_base.png',
    },
},

['teriyaki_sauce'] = {
    label = 'Teriyaki Sauce',
    weight = 150,
    stack = true,
    close = true,
    description = 'Sweet and savory teriyaki glaze.',
    client = {
        image = 'teriyaki_sauce.png',
    },
},

['ginger_sauce'] = {
    label = 'Ginger Sauce',
    weight = 100,
    stack = true,
    close = true,
    description = 'Tangy ginger dipping sauce.',
    client = {
        image = 'ginger_sauce.png',
    },
},

['yum_yum_sauce'] = {
    label = 'Yum Yum Sauce',
    weight = 100,
    stack = true,
    close = true,
    description = 'Creamy Japanese steakhouse sauce.',
    client = {
        image = 'yum_yum_sauce.png',
    },
},

-- Sake & Japanese drinks
['sake_bottle'] = {
    label = 'Sake Bottle',
    weight = 500,
    stack = true,
    close = true,
    description = 'A bottle of premium Japanese sake.',
    client = {
        image = 'sake_bottle.png',
    },
},

['sake_cup'] = {
    label = 'Sake',
    weight = 80,
    stack = true,
    close = true,
    description = 'A small cup of warm sake.',
    client = {
        image = 'sake_cup.png',
    },
},

['japanese_beer'] = {
    label = 'Japanese Beer',
    weight = 350,
    stack = true,
    close = true,
    description = 'Imported Japanese lager.',
    client = {
        image = 'japanese_beer.png',
    },
},

['green_tea'] = {
    label = 'Green Tea',
    weight = 200,
    stack = true,
    close = true,
    description = 'Hot Japanese green tea.',
    client = {
        image = 'green_tea.png',
    },
},

['ramune'] = {
    label = 'Ramune Soda',
    weight = 250,
    stack = true,
    close = true,
    description = 'Japanese marble soda.',
    client = {
        image = 'ramune.png',
    },
},

-- ============================================================================
-- SUSHI RESTAURANT - FINISHED DISHES
-- ============================================================================

-- Sushi Rolls
['california_roll'] = {
    label = 'California Roll',
    weight = 250,
    stack = true,
    close = true,
    description = 'Crab, avocado, and cucumber roll. 8 pieces.',
    client = {
        image = 'california_roll.png',
    },
},

['spicy_tuna_roll'] = {
    label = 'Spicy Tuna Roll',
    weight = 250,
    stack = true,
    close = true,
    description = 'Spicy tuna with sriracha mayo. 8 pieces.',
    client = {
        image = 'spicy_tuna_roll.png',
    },
},

['salmon_roll'] = {
    label = 'Salmon Roll',
    weight = 250,
    stack = true,
    close = true,
    description = 'Fresh salmon maki roll. 8 pieces.',
    client = {
        image = 'salmon_roll.png',
    },
},

['dragon_roll'] = {
    label = 'Dragon Roll',
    weight = 300,
    stack = true,
    close = true,
    description = 'Eel and avocado topped roll. 8 pieces.',
    client = {
        image = 'dragon_roll.png',
    },
},

['rainbow_roll'] = {
    label = 'Rainbow Roll',
    weight = 350,
    stack = true,
    close = true,
    description = 'California roll topped with assorted sashimi.',
    client = {
        image = 'rainbow_roll.png',
    },
},

['philadelphia_roll'] = {
    label = 'Philadelphia Roll',
    weight = 250,
    stack = true,
    close = true,
    description = 'Salmon and cream cheese roll. 8 pieces.',
    client = {
        image = 'philadelphia_roll.png',
    },
},

['shrimp_tempura_roll'] = {
    label = 'Shrimp Tempura Roll',
    weight = 280,
    stack = true,
    close = true,
    description = 'Crispy tempura shrimp roll. 8 pieces.',
    client = {
        image = 'shrimp_tempura_roll.png',
    },
},

['volcano_roll'] = {
    label = 'Volcano Roll',
    weight = 300,
    stack = true,
    close = true,
    description = 'Baked seafood topped roll with spicy sauce.',
    client = {
        image = 'volcano_roll.png',
    },
},

-- Nigiri & Sashimi
['salmon_nigiri'] = {
    label = 'Salmon Nigiri',
    weight = 100,
    stack = true,
    close = true,
    description = 'Fresh salmon over pressed rice. 2 pieces.',
    client = {
        image = 'salmon_nigiri.png',
    },
},

['tuna_nigiri'] = {
    label = 'Tuna Nigiri',
    weight = 100,
    stack = true,
    close = true,
    description = 'Fresh tuna over pressed rice. 2 pieces.',
    client = {
        image = 'tuna_nigiri.png',
    },
},

['yellowtail_nigiri'] = {
    label = 'Yellowtail Nigiri',
    weight = 100,
    stack = true,
    close = true,
    description = 'Fresh hamachi over pressed rice. 2 pieces.',
    client = {
        image = 'yellowtail_nigiri.png',
    },
},

['shrimp_nigiri'] = {
    label = 'Shrimp Nigiri',
    weight = 100,
    stack = true,
    close = true,
    description = 'Butterflied shrimp over rice. 2 pieces.',
    client = {
        image = 'shrimp_nigiri.png',
    },
},

['eel_nigiri'] = {
    label = 'Eel Nigiri',
    weight = 100,
    stack = true,
    close = true,
    description = 'Grilled eel with sweet sauce. 2 pieces.',
    client = {
        image = 'eel_nigiri.png',
    },
},

['sashimi_platter'] = {
    label = 'Sashimi Platter',
    weight = 400,
    stack = true,
    close = true,
    description = 'Assorted fresh sashimi - 12 pieces.',
    client = {
        image = 'sashimi_platter.png',
    },
},

['omakase_platter'] = {
    label = 'Omakase Platter',
    weight = 600,
    stack = true,
    close = true,
    description = "Chef's choice premium selection.",
    client = {
        image = 'omakase_platter.png',
    },
},

-- Hibachi/Teppanyaki Dishes
['hibachi_steak'] = {
    label = 'Hibachi Steak',
    weight = 500,
    stack = true,
    close = true,
    description = 'Grilled steak with vegetables and fried rice.',
    client = {
        image = 'hibachi_steak.png',
    },
},

['hibachi_chicken'] = {
    label = 'Hibachi Chicken',
    weight = 450,
    stack = true,
    close = true,
    description = 'Grilled chicken with vegetables and fried rice.',
    client = {
        image = 'hibachi_chicken.png',
    },
},

['hibachi_shrimp'] = {
    label = 'Hibachi Shrimp',
    weight = 400,
    stack = true,
    close = true,
    description = 'Grilled shrimp with vegetables and fried rice.',
    client = {
        image = 'hibachi_shrimp.png',
    },
},

['hibachi_lobster'] = {
    label = 'Hibachi Lobster',
    weight = 500,
    stack = true,
    close = true,
    description = 'Grilled lobster tail with vegetables.',
    client = {
        image = 'hibachi_lobster.png',
    },
},

['hibachi_scallops'] = {
    label = 'Hibachi Scallops',
    weight = 400,
    stack = true,
    close = true,
    description = 'Seared scallops with vegetables.',
    client = {
        image = 'hibachi_scallops.png',
    },
},

['hibachi_filet_mignon'] = {
    label = 'Hibachi Filet Mignon',
    weight = 550,
    stack = true,
    close = true,
    description = 'Premium filet with vegetables and fried rice.',
    client = {
        image = 'hibachi_filet_mignon.png',
    },
},

['hibachi_wagyu'] = {
    label = 'Hibachi Wagyu',
    weight = 600,
    stack = true,
    close = true,
    description = 'A5 Wagyu beef, grilled to perfection.',
    client = {
        image = 'hibachi_wagyu.png',
    },
},

['hibachi_combo'] = {
    label = 'Hibachi Combination',
    weight = 650,
    stack = true,
    close = true,
    description = 'Steak and shrimp combination plate.',
    client = {
        image = 'hibachi_combo.png',
    },
},

['hibachi_vegetables'] = {
    label = 'Hibachi Vegetables',
    weight = 350,
    stack = true,
    close = true,
    description = 'Grilled seasonal vegetables.',
    client = {
        image = 'hibachi_vegetables.png',
    },
},

['hibachi_fried_rice'] = {
    label = 'Hibachi Fried Rice',
    weight = 300,
    stack = true,
    close = true,
    description = 'Egg fried rice with vegetables.',
    client = {
        image = 'hibachi_fried_rice.png',
    },
},

['hibachi_noodles'] = {
    label = 'Hibachi Noodles',
    weight = 350,
    stack = true,
    close = true,
    description = 'Stir-fried noodles with vegetables.',
    client = {
        image = 'hibachi_noodles.png',
    },
},

-- Japanese Appetizers & Sides
['miso_soup'] = {
    label = 'Miso Soup',
    weight = 250,
    stack = true,
    close = true,
    description = 'Traditional Japanese miso soup.',
    client = {
        image = 'miso_soup.png',
    },
},

['edamame'] = {
    label = 'Edamame',
    weight = 200,
    stack = true,
    close = true,
    description = 'Steamed and salted soybeans.',
    client = {
        image = 'edamame.png',
    },
},

['gyoza'] = {
    label = 'Gyoza',
    weight = 200,
    stack = true,
    close = true,
    description = 'Pan-fried pork dumplings. 6 pieces.',
    client = {
        image = 'gyoza.png',
    },
},

['tempura_shrimp'] = {
    label = 'Shrimp Tempura',
    weight = 250,
    stack = true,
    close = true,
    description = 'Light and crispy fried shrimp. 5 pieces.',
    client = {
        image = 'tempura_shrimp.png',
    },
},

['tempura_vegetables'] = {
    label = 'Vegetable Tempura',
    weight = 200,
    stack = true,
    close = true,
    description = 'Assorted vegetables in tempura batter.',
    client = {
        image = 'tempura_vegetables.png',
    },
},

['agedashi_tofu'] = {
    label = 'Agedashi Tofu',
    weight = 200,
    stack = true,
    close = true,
    description = 'Fried tofu in dashi broth.',
    client = {
        image = 'agedashi_tofu.png',
    },
},

['seaweed_salad'] = {
    label = 'Seaweed Salad',
    weight = 150,
    stack = true,
    close = true,
    description = 'Marinated wakame seaweed salad.',
    client = {
        image = 'seaweed_salad.png',
    },
},

['onion_soup'] = {
    label = 'Japanese Onion Soup',
    weight = 250,
    stack = true,
    close = true,
    description = 'Clear onion soup with mushrooms.',
    client = {
        image = 'onion_soup.png',
    },
},

['ginger_salad'] = {
    label = 'Ginger Salad',
    weight = 150,
    stack = true,
    close = true,
    description = 'Fresh salad with ginger dressing.',
    client = {
        image = 'ginger_salad.png',
    },
},

-- Desserts
['mochi_ice_cream'] = {
    label = 'Mochi Ice Cream',
    weight = 150,
    stack = true,
    close = true,
    description = 'Ice cream wrapped in sweet rice dough. 3 pieces.',
    client = {
        image = 'mochi_ice_cream.png',
    },
},

['tempura_ice_cream'] = {
    label = 'Tempura Ice Cream',
    weight = 200,
    stack = true,
    close = true,
    description = 'Fried ice cream with chocolate drizzle.',
    client = {
        image = 'tempura_ice_cream.png',
    },
},

['green_tea_ice_cream'] = {
    label = 'Green Tea Ice Cream',
    weight = 150,
    stack = true,
    close = true,
    description = 'Traditional matcha flavored ice cream.',
    client = {
        image = 'green_tea_ice_cream.png',
    },
},

-- ============================================================================
-- MEDICAL ITEMS - FOOD POISONING TREATMENT
-- ============================================================================

['antacid'] = {
    label = 'Antacid Tablets',
    weight = 20,
    stack = true,
    close = true,
    description = 'Over-the-counter antacid for mild stomach issues.',
    client = {
        image = 'antacid.png',
    },
},

['pepto_bismol'] = {
    label = 'Stomach Relief Medicine',
    weight = 50,
    stack = true,
    close = true,
    description = 'Pink liquid medicine for upset stomach and nausea.',
    client = {
        image = 'pepto_bismol.png',
    },
},

['anti_nausea_pills'] = {
    label = 'Anti-Nausea Pills',
    weight = 15,
    stack = true,
    close = true,
    description = 'Medication to reduce nausea and vomiting.',
    client = {
        image = 'anti_nausea_pills.png',
    },
},

['activated_charcoal'] = {
    label = 'Activated Charcoal',
    weight = 30,
    stack = true,
    close = true,
    description = 'Emergency treatment for food poisoning. Hospital use recommended.',
    client = {
        image = 'activated_charcoal.png',
    },
},

['prescription_antiemetic'] = {
    label = 'Prescription Antiemetic',
    weight = 25,
    stack = true,
    close = true,
    description = 'Prescription-strength anti-vomiting medication.',
    client = {
        image = 'prescription_antiemetic.png',
    },
},

['iv_fluids'] = {
    label = 'IV Fluid Bag',
    weight = 500,
    stack = true,
    close = true,
    description = 'Intravenous rehydration fluids. Hospital use only.',
    client = {
        image = 'iv_fluids.png',
    },
},

['electrolyte_drink'] = {
    label = 'Electrolyte Drink',
    weight = 350,
    stack = true,
    close = true,
    description = 'Sports drink for rehydration after illness.',
    client = {
        image = 'electrolyte_drink.png',
    },
},

['food_poisoning_kit'] = {
    label = 'Food Poisoning Treatment Kit',
    weight = 200,
    stack = true,
    close = true,
    description = 'Complete kit with medications for severe food poisoning.',
    client = {
        image = 'food_poisoning_kit.png',
    },
},

-- ============================================================================
-- STOCK CRATES (Stock order pickup containers)
-- ============================================================================

['stock_crate'] = {
    label = 'Stock Crate',
    weight = 500, -- Base weight, actual weight determined by contents
    stack = false,
    close = false,
    description = 'A sealed crate containing restaurant supplies. Use to open and retrieve contents.',
    client = {
        image = 'stock_crate.png',
        usetime = 3000,
        anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
        export = 'free-restaurants.openStockCrate',
    },
},
