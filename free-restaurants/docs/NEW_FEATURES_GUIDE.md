# Free Restaurants - New Features Guide

## Comprehensive Overview, Testing Guide, and Usage Walkthrough

This document covers all newly implemented features in the free-restaurants resource, including the container replacement system, trash can disposal, intoxication effects, food poisoning, medical items, and the Japanese sushi restaurant.

---

## Table of Contents

1. [Container Replacement System](#1-container-replacement-system)
2. [Trash Can & Recycling System](#2-trash-can--recycling-system)
3. [Alcohol Intoxication System](#3-alcohol-intoxication-system)
4. [Food Poisoning System](#4-food-poisoning-system)
5. [Medical Treatment Items](#5-medical-treatment-items)
6. [Japanese Sushi Restaurant](#6-japanese-sushi-restaurant)
7. [Testing Guide](#7-testing-guide)
8. [Configuration Reference](#8-configuration-reference)
9. [Exports Reference](#9-exports-reference)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Container Replacement System

### Overview
When players fully consume food or drink items, the original item is automatically replaced with an appropriate "depleted container" item. This adds realism and creates RP opportunities around waste disposal.

### How It Works
1. Player uses a food/drink item (e.g., `bleeder_burger`)
2. Player consumes all uses (e.g., 4 bites for a burger)
3. Server removes the original item from inventory
4. Server adds the corresponding container (e.g., `burger_wrapper`)
5. Player must dispose of container at a trash can

### Container Mapping

| Original Item Type | Depleted Container |
|-------------------|-------------------|
| Burgers | `burger_wrapper` |
| Tacos | `taco_wrapper` |
| Pizza slices | `food_wrapper` |
| Whole pizza | `pizza_box` |
| Fries, nuggets | `fry_container` |
| Plated meals | `plate_fork` or `dirty_plate` |
| Bowl dishes (soup, rice) | `bowl_spoon` |
| Sushi items | `sushi_tray_empty` |
| Chopstick dishes | `chopsticks_used` |
| Sodas (cup) | `empty_cup_lid` |
| Coffee | `empty_coffee_cup` |
| Water/Beer bottles | `empty_bottle` |
| Canned drinks | `empty_can` |
| Wine glasses | `empty_wine_glass` |
| Cocktails | `empty_cocktail_glass` |
| Sake | `empty_sake_cup` |
| Mugs | `empty_mug` |

### Partial Consumption
- Players can stop eating/drinking mid-way by pressing **X**
- Remaining uses are saved in item metadata (`usesRemaining`)
- Original item stays in inventory until fully consumed
- Resuming consumption uses the saved `usesRemaining` value

---

## 2. Trash Can & Recycling System

### Overview
Players can dispose of depleted containers, spoiled food, and ruined items at any trash can or dumpster in the game world. Certain containers give recycling rewards.

### Supported Trash Can Models
The system automatically targets 40+ trash can and dumpster prop models including:
- `prop_bin_01a` through `prop_bin_14b`
- `prop_bin_beach_01a`, `prop_bin_beach_01d`
- `prop_recyclebin_01a` through `prop_recyclebin_05_a`
- `prop_dumpster_01a` through `prop_dumpster_4b`
- `prop_cs_bin_01`, `prop_bin_delpiero`

### Interaction Options
When approaching a trash can, players see two ox_target options:

1. **Dispose of Trash** - Opens menu showing all disposable items
2. **Recycle** - Shows recyclable items with rewards

### Recycling Rewards

| Container | Reward |
|-----------|--------|
| `empty_bottle` | $5 |
| `empty_can` | $3 |
| `empty_glass` | $2 |
| `empty_wine_glass` | $2 |
| Food wrappers | $0 (disposal only) |
| Plates/bowls | $0 (disposal only) |

### What Can Be Disposed
- Depleted containers (from consumed food/drinks)
- Spoiled food items (`metadata.spoiled = true`)
- Ruined items (`metadata.ruined = true`)
- Items with no remaining uses

### Usage Flow
1. Approach any trash can or dumpster
2. Target interaction appears
3. Select "Dispose of Trash" or "Recycle"
4. Choose items from the menu
5. Items are removed, rewards given if applicable

---

## 3. Alcohol Intoxication System

### Overview
Consuming alcoholic beverages accumulates intoxication over time. Higher intoxication levels cause increasingly severe visual and movement impairments.

### Alcohol Content by Drink

| Drink | Alcohol Content | Intoxication per Use |
|-------|-----------------|---------------------|
| Beer | 5% | +0.5 |
| Japanese Beer | 5% | +0.5 |
| Sake | 15% | +1.5 |
| Margarita | 15% | +1.5 |
| Whiskey | 40% | +4.0 |

### Intoxication Levels

| Level | Threshold | Effects |
|-------|-----------|---------|
| **Sober** | 0-14 | No effects |
| **Buzzed** | 15-29 | Slight screen blur |
| **Tipsy** | 30-49 | Moderate blur, drunk walk animation |
| **Drunk** | 50-74 | Heavy blur, stumbling (10% chance) |
| **Wasted** | 75-94 | Severe impairment, vomiting (5% chance) |
| **Blackout** | 95-100 | Screen fades, collapse (10% chance) |

### Effects Details

**Visual Effects:**
- Screen blur using `DrugsMichaelAliensFight` screen effect
- Intensity scales with intoxication level (10% to 100%)
- Color tint using `drug_flying_base` timecycle modifier

**Movement Effects:**
- Drunk walk animations applied automatically
- `move_m@drunk@slightlydrunk` (Tipsy)
- `move_m@drunk@moderatedrunk` (Drunk)
- `move_m@drunk@verydrunk` (Wasted/Blackout)

**Random Events:**
- **Stumbling**: Ragdoll for 1 second (Drunk+)
- **Vomiting**: 5-second animation, reduces intoxication by 10
- **Blackout**: Screen fades, 8-second ragdoll, reduces intoxication by 20

### Sobering Up
- Intoxication decays at **5 points per minute** when not drinking
- Decay only starts 1+ minute after last drink
- Vomiting reduces intoxication by 10
- Blackouts reduce intoxication by 20

### Gameplay Tips
- Pace your drinking to stay at "Buzzed" level for stress relief without impairment
- Keep water or coffee handy to dilute alcohol effects (increases thirst without alcohol)
- If too drunk, wait it out or intentionally vomit to reduce faster

---

## 4. Food Poisoning System

### Overview
Consuming spoiled, ruined, or low-quality food carries a risk of food poisoning. Severity depends on how bad the food was.

### Risk Factors

| Food Condition | Poisoning Chance |
|----------------|------------------|
| Spoiled (`metadata.spoiled = true`) | 80% |
| Very low quality (< 10) | 50% |
| Low quality (< 25) | 25% |
| Normal quality (25+) | 0% |
| Item-specific risk (burnt food) | Varies |

### Severity Levels

| Severity | Duration | Health Drain | Vomit Chance | Other Effects |
|----------|----------|--------------|--------------|---------------|
| **Mild** | 1 minute | 1/tick | 2% | Light nausea visuals |
| **Moderate** | 3 minutes | 2/tick | 8% | Medium nausea |
| **Severe** | 5 minutes | 5/tick | 15% | Heavy nausea, 70% speed |

### Severity Determination
- Spoiled + Quality < 10 = **Severe**
- Spoiled OR Quality < 25 = **Moderate**
- Otherwise = **Mild**

### Effects

**Visual Effects:**
- Nausea screen effect using `drug_wobbly` timecycle
- Intensity: 10% (mild), 25% (moderate), 40% (severe)

**Health Effects:**
- Continuous health drain every tick interval
- Tick intervals: 10s (mild), 8s (moderate), 5s (severe)
- Will not kill player (minimum health: 100)

**Movement Effects:**
- Sprint disabled during severe poisoning
- Movement speed reduced to 70% (severe only)

**Vomiting:**
- Random vomit animations during illness
- Uses `oddjobs@assassinate@multi@` animation

### Recovery
- Food poisoning automatically clears after duration expires
- Use medical items to cure or reduce severity
- Each severity level can be reduced by weaker medicine

---

## 5. Medical Treatment Items

### Overview
Medical items are used to treat food poisoning and provide various health benefits.

### Item Reference

#### Over-the-Counter (No Restrictions)

| Item | Uses | Cures | Effects |
|------|------|-------|---------|
| `antacid` | 1 | Mild | +2-5 health |
| `pepto_bismol` | 3 | Mild | +3-8 health, +2-5 thirst |
| `anti_nausea_pills` | 2 | Moderate | +5-10 health |
| `electrolyte_drink` | 3 | Helps recovery | +20-35 thirst, +5-10 health |

#### Pharmacy/Hospital Items

| Item | Uses | Cures | Effects | Restriction |
|------|------|-------|---------|-------------|
| `activated_charcoal` | 1 | Severe | +10-20 health | Emergency use |
| `prescription_antiemetic` | 2 | Severe | +15-25 health, -5-10 stress | Prescription |
| `iv_fluids` | 1 | Severe | +30-50 health, +50-75 thirst | Hospital only |
| `food_poisoning_kit` | 1 | Severe | +25-40 health, +10-20 thirst | Complete kit |

### How Curing Works
- Medicine must match or exceed the severity level to fully cure
- If medicine is too weak, severity is reduced by one level instead
- Example: `anti_nausea_pills` (moderate) against severe = reduces to moderate

### Usage Tips
- Keep `antacid` or `pepto_bismol` in inventory for emergencies
- Restaurant workers should have access to `electrolyte_drink`
- Hospitals should stock `iv_fluids` and `prescription_antiemetic`
- `food_poisoning_kit` is the all-in-one solution for any severity

---

## 6. Japanese Sushi Restaurant

### Overview
A Benihana-inspired Japanese steakhouse featuring sushi bar, teppanyaki grills, and traditional Japanese cuisine.

### Restaurant: Sakura Teppanyaki
- **Location**: Downtown Vinewood (configurable coordinates)
- **Job Name**: `benihana`

### Job Grades

| Grade | Title | Access |
|-------|-------|--------|
| 0 | Host | Basic access, duty |
| 1 | Server | Sake bar, tempura, serving |
| 2 | Sushi Chef | Sushi preparation stations |
| 3 | Teppanyaki Chef | Hibachi grills |
| 4 | Head Chef | All stations |
| 5 | Manager | Full access, management |

### Station Types

#### Sushi Prep (`sushi_prep`)
- **Function**: Prepare sushi rolls, nigiri, and sashimi
- **Required Grade**: 2 (Sushi Chef)
- **Slots**: 4
- **No heat required**

#### Rice Cooker (`rice_cooker`)
- **Function**: Prepare sushi rice
- **Required Grade**: 0
- **Slots**: 2
- **Heat stages**: Cooking → Steaming

#### Teppanyaki Grill (`teppanyaki_grill`)
- **Function**: Hibachi-style cooking
- **Required Grade**: 3 (Teppanyaki Chef)
- **Slots**: 6
- **Heat stages**: Searing (high) → Cooking (medium) → Resting (low)
- **Fire type**: Gas (blue flame)

#### Tempura Fryer (`tempura_fryer`)
- **Function**: Deep fry tempura
- **Required Grade**: 1
- **Slots**: 3
- **Oil temperature**: 350°F
- **Fire risk**: Gas fire, aggressive spread

#### Soup Station (`soup_station`)
- **Function**: Miso soup and broths
- **Required Grade**: 0
- **Slots**: 4
- **Heat stages**: Heating → Simmering

#### Sake Bar (`sake_bar`)
- **Function**: Beverages and sake
- **Required Grade**: 1
- **Slots**: 6
- **No heat required**

### Menu Items

#### Appetizers
| Item | Station | Key Ingredients |
|------|---------|-----------------|
| Miso Soup | Soup Station | Miso paste, dashi, tofu, wakame |
| Edamame | Soup Station | Edamame raw |
| Gyoza | Teppanyaki | Ground beef, onion |
| Shrimp Tempura | Tempura Fryer | Shrimp, tempura batter |
| Vegetable Tempura | Tempura Fryer | Zucchini, mushrooms, batter |
| Seaweed Salad | Sushi Prep | (Pre-prepared) |

#### Sushi Rolls (8 pieces each)
| Item | Skill Req | Key Ingredients |
|------|-----------|-----------------|
| California Roll | 1 | Rice, nori, crab, avocado, cucumber |
| Spicy Tuna Roll | 1 | Rice, nori, tuna, sesame |
| Salmon Roll | 1 | Rice, nori, salmon |
| Philadelphia Roll | 2 | Rice, nori, salmon, cream cheese |
| Dragon Roll | 3 | Rice, nori, eel, avocado, tobiko |
| Rainbow Roll | 4 | Rice, nori, crab, multiple fish, avocado |
| Shrimp Tempura Roll | 2 | Rice, nori, tempura shrimp |
| Volcano Roll | 3 | Rice, nori, spicy seafood topping |

#### Nigiri & Sashimi
| Item | Pieces | Key Ingredients |
|------|--------|-----------------|
| Salmon Nigiri | 2 | Rice, salmon |
| Tuna Nigiri | 2 | Rice, tuna |
| Yellowtail Nigiri | 2 | Rice, yellowtail |
| Eel Nigiri | 2 | Rice, eel |
| Sashimi Platter | 12 | Salmon, tuna, yellowtail |
| Omakase Platter | 15 | Chef's selection |

#### Hibachi Entrees
| Item | Skill Req | Includes |
|------|-----------|----------|
| Hibachi Steak | 2 | Steak, fried rice, vegetables |
| Hibachi Chicken | 1 | Chicken teriyaki, rice, vegetables |
| Hibachi Shrimp | 1 | Shrimp, rice, vegetables |
| Hibachi Scallops | 2 | Scallops, vegetables |
| Hibachi Lobster | 3 | Lobster tail, vegetables |
| Hibachi Filet Mignon | 3 | Filet, rice, vegetables |
| Hibachi Wagyu | 5 | A5 Wagyu, rice, vegetables |
| Hibachi Combination | 2 | Steak + shrimp combo |

#### Sides
- Hibachi Fried Rice
- Hibachi Noodles
- Hibachi Vegetables

#### Desserts
- Mochi Ice Cream
- Tempura Ice Cream
- Green Tea Ice Cream

#### Beverages
- Green Tea (healthy, stress relief)
- Sake (15% alcohol)
- Japanese Beer (5% alcohol)
- Ramune Soda

### Storage Areas

| Storage | Type | Capacity | Access |
|---------|------|----------|--------|
| Main Storage | Standard | 50 slots | Grade 1+ |
| Walk-in Freezer | Freezer (95% decay reduction) | 75 slots | Grade 1+ |
| Fish Refrigerator | Refrigerator (75% decay reduction) | 40 slots | Grade 2+ |
| Sake Storage | Standard | 30 slots | Grade 1+ |

---

## 7. Testing Guide

### Prerequisites
1. Ensure all items are added to `ox_inventory/data/items.lua`
2. Copy contents from `data/ox_inventory_items.lua`
3. Restart the server after adding items

### Test 1: Container Replacement

**Steps:**
1. Give yourself a burger: `/giveitem [id] bleeder_burger 1`
2. Use the item from inventory
3. Consume all 4 bites (press E to continue each time)
4. Check inventory - should now have `burger_wrapper`

**Expected Results:**
- Original item removed
- `burger_wrapper` added to inventory
- Notification: "Finished The Bleeder - dispose of container"

### Test 2: Partial Consumption

**Steps:**
1. Give yourself a burger
2. Consume 2 bites, then press X to stop
3. Check item metadata in inventory
4. Use item again, should show "2 more" remaining

**Expected Results:**
- Item stays in inventory with `usesRemaining: 2`
- Resuming shows correct remaining count

### Test 3: Trash Can Disposal

**Steps:**
1. Have a `burger_wrapper` in inventory
2. Find any trash can (usually near restaurants/streets)
3. Target the trash can
4. Select "Dispose of Trash"
5. Choose the wrapper from menu

**Expected Results:**
- Menu shows disposable items
- Wrapper is removed
- Notification: "Disposed of Burger Wrapper"

### Test 4: Recycling Rewards

**Steps:**
1. Give yourself: `/giveitem [id] empty_bottle 5`
2. Find a trash can
3. Select "Recycle"
4. Choose "Recycle All" or individual bottles

**Expected Results:**
- Each bottle gives $5
- Total of $25 for 5 bottles
- Notification shows reward amount

### Test 5: Intoxication Effects

**Steps:**
1. Give yourself whiskey: `/giveitem [id] whiskey 3`
2. Consume one whiskey completely (3 uses)
3. Check for drunk walk animation
4. Consume second whiskey
5. Watch for stumbling/visual effects

**Expected Results:**
- After 1 whiskey (~12 intoxication): Tipsy, drunk walk
- After 2 whiskeys (~24 intoxication): Drunk, may stumble
- Screen effects visible
- Wait 5+ minutes to observe sobering

### Test 6: Food Poisoning

**Steps:**
1. Create spoiled food:
   ```lua
   -- In server console or script:
   exports.ox_inventory:AddItem(source, 'bleeder_burger', 1, {
       spoiled = true,
       quality = 5
   })
   ```
2. Consume the spoiled item (confirm warning dialog)
3. Observe food poisoning effects

**Expected Results:**
- Warning dialog appears
- 80% chance of food poisoning
- Nausea screen effects
- Health drain over time
- Possible vomiting
- Automatic recovery after duration

### Test 7: Medical Treatment

**Steps:**
1. Get food poisoning (see Test 6)
2. Give yourself medicine: `/giveitem [id] activated_charcoal 1`
3. Use the medicine
4. Observe cure

**Expected Results:**
- For matching severity: Immediate cure
- For lower severity medicine: Reduces by one level
- Notification confirms treatment

### Test 8: Sushi Restaurant Workflow

**Steps:**
1. Set job: `/setjob [id] benihana 2` (Sushi Chef)
2. Go on duty at the restaurant
3. Access ingredient storage (refrigerator for fish)
4. Craft sushi rice at rice cooker
5. Craft California Roll at sushi prep station
6. Serve to customer or self

**Expected Results:**
- Rice cooker shows cooking stages
- Sushi prep allows crafting with correct ingredients
- Quality based on skill and ingredients
- Completed roll has proper uses and container mapping

---

## 8. Configuration Reference

### Item Effects Configuration
File: `config/item_effects.lua`

Key sections:
- `Config.ItemEffects.Animations` - Eating/drinking animations
- `Config.ItemEffects.Props` - Items held during consumption
- `Config.ItemEffects.Defaults` - Default values
- `Config.ItemEffects.ContainerMappings` - Generic container maps
- `Config.ItemEffects.Items` - Per-item configuration
- `Config.ItemEffects.RecyclingValues` - Disposal rewards

### Sushi Restaurant Configuration
File: `config/sushi_restaurant.lua`

Key sections:
- Station type definitions
- Recipe configurations
- Location settings
- Storage configurations

### Decay Configuration
File: `server/decay.lua`

Key settings:
- `DecayConfig.storageModifiers.freezer = 0.05` (95% slower)
- `DecayConfig.storageModifiers.refrigerator = 0.25` (75% slower)
- `FreezerIncompatible` - Items damaged by freezing

---

## 9. Exports Reference

### Client Exports

```lua
-- Consumption
exports['free-restaurants']:StartConsumption(itemName, itemData)
exports['free-restaurants']:IsConsuming()
exports['free-restaurants']:CancelConsumption()
exports['free-restaurants']:DisposeItem(slot, force)
exports['free-restaurants']:CanDisposeItem(itemData)

-- Status Effects
exports['free-restaurants']:GetIntoxicationLevel()
exports['free-restaurants']:GetIntoxicationState() -- Returns level name
exports['free-restaurants']:AddIntoxication(alcoholContent, uses)
exports['free-restaurants']:SetIntoxication(level)
exports['free-restaurants']:GetFoodPoisoning()
exports['free-restaurants']:StartFoodPoisoning(severity)
exports['free-restaurants']:CureFoodPoisoning(medicineLevel)

-- UI
exports['free-restaurants']:OpenDisposalMenu()
exports['free-restaurants']:OpenRecyclingMenu()
exports['free-restaurants']:CheckStorageWarning(itemName, storageType)
```

### Server Exports

```lua
-- Decay System
exports['free-restaurants']:ProcessPlayerDecay(source)
exports['free-restaurants']:ProcessStashDecay(stashId, storageType)
exports['free-restaurants']:GetDecayableItems()
exports['free-restaurants']:AddDecayableItem(itemName, config)
exports['free-restaurants']:GetItemDecayRate(itemName)
exports['free-restaurants']:GetItemDecayCategory(itemName)
exports['free-restaurants']:IsFoodItem(itemName)
exports['free-restaurants']:GetStorageEffect(itemName, storageType)
```

---

## 10. Troubleshooting

### Items Not Appearing in Inventory
**Cause:** Items not added to ox_inventory
**Solution:** Copy items from `data/ox_inventory_items.lua` to `ox_inventory/data/items.lua`

### Container Not Given After Consumption
**Cause:** Container item not defined in ox_inventory
**Solution:** Ensure all container items are added to ox_inventory

### Trash Cans Not Interactive
**Cause:** ox_target not initialized or model not in list
**Solution:** Check console for errors, verify ox_target is loaded

### Intoxication Not Working
**Cause:** Item missing `alcoholContent` property
**Solution:** Check item config has `alcoholContent = X` value

### Food Poisoning Not Triggering
**Cause:** Item quality/spoiled metadata not set
**Solution:** Verify item has `metadata.spoiled = true` or low quality

### Sushi Station Not Available
**Cause:** Wrong job grade
**Solution:** Check required grade for station, use `/setjob` to adjust

### Decay Not Working in Freezer
**Cause:** Storage type not detected
**Solution:** Ensure storage ID contains "freezer" or has `storageType = 'freezer'` in config

---

## Version History

- **v1.1.0** - Added container replacement, trash cans, intoxication, food poisoning, sushi restaurant
- **v1.0.0** - Initial release with basic restaurant functionality
