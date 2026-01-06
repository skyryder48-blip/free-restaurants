# 🍔 free-restaurants

A comprehensive, feature-rich restaurant framework for FiveM servers running the **QBox (qbx_core)** framework. This script provides complete restaurant management with multi-location support, player jobs, NPC customers, health inspections, delivery systems, and lb-tablet integration.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Framework](https://img.shields.io/badge/framework-QBox-green)
![Lua](https://img.shields.io/badge/lua-5.4-yellow)

---

## 📋 Table of Contents

1. [Features](#-features)
2. [Dependencies](#-dependencies)
3. [Installation](#-installation)
4. [Configuration](#-configuration)
5. [Architecture](#-architecture)
6. [Component Documentation](#-component-documentation)
7. [Database Schema](#-database-schema)
8. [API Reference](#-api-reference)
9. [Troubleshooting](#-troubleshooting)
10. [Credits](#-credits)

---

## ✨ Features

### Core Features
- **Multi-Location Support** - Configure unlimited restaurant locations with unique settings
- **Multi-Slot Cooking Stations** - Multiple players can use different slots on the same station simultaneously
- **Quality-Based Crafting** - Skill checks, ingredient freshness, and crafting proficiency affect item quality
- **Dynamic Pricing** - Managers can adjust menu prices in real-time
- **Business Finances** - Full business account with deposits, withdrawals, and transaction history

### Job System
- **Configurable Grades** - Custom roles from trainee to owner with granular permissions
- **Duty System** - Clock in/out with automatic paycheck generation
- **Uniform System** - Automatic outfit changes when clocking in
- **Session Tracking** - Track hours worked, tasks completed, and earnings per session

### Cooking & Crafting
- **50+ Recipes** - Pre-configured recipes for burgers, pizza, coffee, and more
- **15+ Station Types** - Grills, fryers, ovens, coffee machines, blenders, etc.
- **Skill Check Mini-Games** - Success affects item quality
- **Batch Crafting** - Craft multiple items at once for efficiency
- **XP & Leveling** - Progress through 50 levels with bonuses

### Visual Systems
- **Food Props** - Visual props spawn on stations during cooking
- **Particle Effects** - Steam, smoke, and sizzle effects based on cooking state
- **Fire System** - Escalating fire mechanics that spread until extinguished
- **Modern HUD** - Glassmorphism-styled station slot display

### Advanced Systems
- **Delivery System** - Auto-generated delivery missions with GPS routing
- **NPC Customers** - Automatic NPC order generation when staff are on duty
- **Health Inspections** - Random inspections with grades A-F affecting reputation
- **Food Decay** - Items lose freshness over time with storage modifiers
- **lb-tablet Integration** - Full restaurant management app

---

## 📦 Dependencies

**Required:**
- [qbx_core](https://github.com/Qbox-project/qbx_core) - QBox Core Framework
- [ox_lib](https://github.com/overextended/ox_lib) - Utility library
- [ox_inventory](https://github.com/overextended/ox_inventory) - Inventory system
- [ox_target](https://github.com/overextended/ox_target) - Targeting system
- [oxmysql](https://github.com/overextended/oxmysql) - MySQL wrapper

**Optional:**
- [lb-tablet](https://lbscripts.com/) - For tablet management app

---

## 🔧 Installation

### Step 1: Download & Extract
```bash
# Extract the resource to your server's resources folder
/resources/[qbx]/free-restaurants/
```

### Step 2: Database Setup
The script automatically creates required tables on first start. Ensure your MySQL server is running and oxmysql is configured.

### Step 3: Add Items to ox_inventory
Add these items to your `ox_inventory/data/items.lua`:

```lua
-- Food Items (examples)
['burger'] = {
    label = 'Burger',
    weight = 250,
    stack = true,
    close = true,
    consume = 1,
},
['fries'] = {
    label = 'Fries',
    weight = 150,
    stack = true,
    close = true,
    consume = 1,
},
-- Add all items from Config.Recipes

-- Cleaning Supplies
['cleaning_spray'] = {
    label = 'Cleaning Spray',
    weight = 200,
    stack = true,
},
['cleaning_cloth'] = {
    label = 'Cleaning Cloth',
    weight = 50,
    stack = true,
},
['mop'] = {
    label = 'Mop',
    weight = 500,
    stack = false,
},
```

### Step 4: Configure Jobs
Add restaurant jobs to your QBCore shared jobs or qbx_core job configuration:

```lua
['burgershot'] = {
    label = 'Burger Shot',
    type = 'restaurant',
    defaultDuty = false,
    grades = {
        [0] = { name = 'Trainee', payment = 50 },
        [1] = { name = 'Employee', payment = 75 },
        [2] = { name = 'Senior Staff', payment = 100 },
        [3] = { name = 'Shift Manager', payment = 150 },
        [4] = { name = 'General Manager', payment = 200 },
        [5] = { name = 'Owner', payment = 300, isboss = true },
    },
},
```

### Step 5: Start the Resource
Add to your `server.cfg`:
```cfg
ensure ox_lib
ensure ox_inventory
ensure ox_target
ensure qbx_core
ensure free-restaurants
```

---

## ⚙️ Configuration

### config/settings.lua
Global settings for economy, cooking mechanics, and features.

```lua
Config.Settings = {
    Debug = false,                    -- Enable debug logging
    
    Economy = {
        businessCut = 0.30,           -- 30% goes to business account
        taxRate = 0.08,               -- 8% sales tax
        minWage = 50,                 -- Minimum hourly wage
        maxWage = 500,                -- Maximum hourly wage
    },
    
    Cooking = {
        burnTimeMultiplier = 1.5,     -- Time after completion before burning
        qualityDecayRate = 0.05,      -- Quality loss per hour
        skillCheckDifficulty = 0.7,   -- Base difficulty (0-1)
    },
    
    Orders = {
        maxPendingOrders = 20,        -- Max orders in queue
        orderTimeout = 600,           -- Seconds before order expires
        tipPercentage = 0.15,         -- Default tip percentage
    },
}
```

### config/jobs.lua
Restaurant job definitions with grades and permissions.

```lua
Config.Jobs = {
    ['burgershot'] = {
        label = 'Burger Shot',
        defaultGrade = 0,
        grades = {
            [0] = {
                name = 'Trainee',
                payment = 50,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canDeliver = false,
                },
            },
            -- More grades...
        },
    },
}
```

### config/stations.lua
Cooking station type definitions with slots, props, and effects.

```lua
Config.StationTypes = {
    ['grill'] = {
        label = 'Grill',
        slots = 4,
        model = 'prop_griddle_01',
        particleDict = 'core',
        particles = {
            idle = 'ent_amb_smoke_foundry',
            cooking = 'ent_amb_smoke_foundry_sm',
            burning = 'ent_amb_fire_med',
        },
    },
}
```

### config/recipes.lua
All craftable items with ingredients, stations, and requirements.

```lua
Config.Recipes = {
    ['burger_basic'] = {
        label = 'Basic Burger',
        result = { item = 'burger', amount = 1 },
        ingredients = {
            ['bun'] = 1,
            ['beef_patty'] = 1,
        },
        station = 'grill',
        craftTime = 8000,
        xpReward = 10,
        levelRequired = 0,
        price = 8,
    },
}
```

### config/locations.lua
Physical restaurant locations with coordinates and station placements.

```lua
Config.Locations['burgershot'] = {
    ['pillbox'] = {
        label = 'Burger Shot - Pillbox',
        job = 'burgershot',
        coords = vec3(-1196.67, -891.22, 13.98),
        radius = 30.0,
        blip = {
            sprite = 106,
            color = 1,
            scale = 0.8,
        },
        stations = {
            ['grill_1'] = {
                type = 'grill',
                coords = vec3(-1198.5, -896.8, 14.0),
                heading = 35.0,
                slots = {
                    [1] = { offset = vec3(0.0, 0.0, 0.9) },
                    [2] = { offset = vec3(0.5, 0.0, 0.9) },
                    [3] = { offset = vec3(1.0, 0.0, 0.9) },
                    [4] = { offset = vec3(1.5, 0.0, 0.9) },
                },
            },
        },
        dutyPoint = vec3(-1195.0, -892.0, 14.0),
        bossPoint = vec3(-1193.0, -890.0, 14.0),
        stashPoint = vec3(-1200.0, -895.0, 14.0),
        counterPoint = vec3(-1190.0, -893.0, 14.0),
    },
},
```

---

## 🏗️ Architecture

### File Structure

```
free-restaurants/
├── fxmanifest.lua              # Resource manifest
├── config/
│   ├── settings.lua            # Global settings
│   ├── jobs.lua                # Job definitions
│   ├── stations.lua            # Station type definitions
│   ├── recipes.lua             # Recipe definitions
│   └── locations.lua           # Physical locations
├── shared/
│   └── utils.lua               # Shared utility functions
├── client/
│   ├── main.lua                # Core client initialization
│   ├── duty.lua                # Clock in/out system
│   ├── stations.lua            # Station interaction & visuals
│   ├── cooking.lua             # Crafting & skill checks
│   ├── orders.lua              # Kitchen Display System
│   ├── customers.lua           # Customer ordering interface
│   ├── management.lua          # Boss menu & management
│   ├── delivery.lua            # Delivery missions
│   ├── progression.lua         # XP & level display
│   ├── tablet.lua              # lb-tablet integration
│   ├── npc-customers.lua       # NPC customer spawning
│   └── cleaning.lua            # Cleaning interactions
├── server/
│   ├── main.lua                # Core server initialization
│   ├── duty.lua                # Session & paycheck management
│   ├── stations.lua            # Slot synchronization
│   ├── crafting.lua            # Recipe validation & creation
│   ├── customers.lua           # Order processing
│   ├── management.lua          # Employee & finance callbacks
│   ├── progression.lua         # XP persistence
│   ├── decay.lua               # Food freshness system
│   ├── delivery.lua            # Delivery job logic
│   ├── inspection.lua          # Health inspection system
│   └── npc-customers.lua       # NPC order generation
├── ui/
│   ├── index.html              # Main NUI container
│   └── station-hud/            # Station slot HUD
│       ├── index.html
│       ├── styles.css
│       └── app.js
├── lb-tablet-app/              # lb-tablet integration
│   └── ui/
│       ├── index.html
│       ├── styles.css
│       └── app.js
└── locales/
    └── en.json                 # English translations
```

### Data Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Player Input   │────▶│  Client Script  │────▶│   ox_lib UI     │
└─────────────────┘     └────────┬────────┘     └─────────────────┘
                                 │
                    lib.callback.await()
                                 │
                                 ▼
                        ┌─────────────────┐
                        │  Server Script  │
                        └────────┬────────┘
                                 │
                    ┌────────────┼────────────┐
                    ▼            ▼            ▼
            ┌───────────┐ ┌───────────┐ ┌───────────┐
            │  oxmysql  │ │ox_inventory│ │ qbx_core │
            └───────────┘ └───────────┘ └───────────┘
```

---

## 📚 Component Documentation

### Duty System (duty.lua)

**Purpose:** Manages employee clock in/out, uniforms, and session tracking.

**Key Features:**
- Automatic uniform change on clock in
- Session earnings accumulation
- Activity-based paycheck multiplier
- Idle timeout (5 minutes)

**Usage:**
```lua
-- Clock in
TriggerEvent('free-restaurants:client:toggleDuty', locationKey, locationData)

-- Check duty status
local isOnDuty = exports['free-restaurants']:IsOnDuty()
```

### Station System (stations.lua)

**Purpose:** Handles multi-slot cooking stations with prop spawning and particle effects.

**Key Features:**
- Server-authoritative slot claiming
- State bag synchronization
- Visual food props during cooking
- Particle effects (steam, smoke, fire)
- Escalating fire system

**Slot States:**
| State | Description |
|-------|-------------|
| `empty` | Slot available |
| `claimed` | Reserved by player |
| `cooking` | Actively cooking |
| `ready` | Food complete, waiting |
| `burnt` | Food overcooked |
| `fire` | Station on fire |

### Cooking System (cooking.lua)

**Purpose:** Manages crafting workflow, skill checks, and quality calculations.

**Quality Formula:**
```
finalQuality = craftQuality × freshnessModifier × 100

Where:
- craftQuality = skill check result (0-1)
- freshnessModifier = average ingredient freshness (0-1)
```

**Skill Check:**
```lua
-- Difficulty scales with recipe complexity
local difficulty = {
    'easy',     -- 1-2 keys
    'medium',   -- 3 keys
    'hard',     -- 4 keys
    'expert',   -- 5+ keys
}

-- Speed scales with cooking level
local speedMultiplier = 1.0 + (playerLevel * 0.01)
```

### Order System (orders.lua + customers.lua)

**Purpose:** Manages customer orders and kitchen display system.

**Order Flow:**
```
Customer Places Order
        │
        ▼
   [PENDING] ──────────────────▶ Staff Claims Order
        │                              │
        │                              ▼
        │                        [IN_PROGRESS]
        │                              │
        │                              ▼
        │                    Staff Marks Ready
        │                              │
        ▼                              ▼
Order Timeout ◀──────────────────  [READY]
        │                              │
        │                              ▼
        ▼                    Customer Picks Up
   [CANCELLED]                         │
                                       ▼
                                 [COMPLETED]
```

### Delivery System (delivery.lua)

**Purpose:** Generates and tracks delivery missions.

**Features:**
- Auto-generated deliveries when staff on duty
- GPS waypoint tracking
- Distance-based progress updates
- Tip calculation based on delivery time

**Tip Formula:**
```
actualTip = estimatedTip × satisfactionMultiplier × (1 + timeBonus × 0.5)

Where:
- satisfactionMultiplier = 0.5 to 1.5 based on condition
- timeBonus = 0 to 0.5 based on speed
```

### Progression System (progression.lua)

**Purpose:** Tracks player XP, levels, and recipe unlocks.

**Level Formula:**
```
XP Required for Level N = Σ(i × 100 × i) for i = 1 to N

Level 1: 100 XP
Level 2: 500 XP (100 + 400)
Level 3: 1,400 XP (100 + 400 + 900)
...
Level 50: 4,292,500 XP
```

**Level Bonuses:**
| Bonus Type | Per Level |
|------------|-----------|
| Quality | +1% |
| Speed | +0.5% |
| XP Gain | +2% |

### Health Inspection System (inspection.lua)

**Purpose:** Random health inspections with grade-based outcomes.

**Grade Thresholds:**
| Grade | Score Range | Effect |
|-------|-------------|--------|
| A | 90-100 | Reputation boost |
| B | 80-89 | Normal operation |
| C | 70-79 | Warning |
| D | 60-69 | Fines possible |
| F | 0-59 | Shutdown risk |

**Violation Categories:**
- **Critical** (-15-20 pts): Fire hazards, contamination, pests
- **Major** (-8-10 pts): Temperature, handwashing, food handling
- **Minor** (-3-5 pts): Cleanliness, labeling, storage

### NPC Customer System (npc-customers.lua)

**Purpose:** Generates automated customer orders.

**Spawn Conditions:**
- Minimum 1 staff member on duty
- Restaurant not at max pending orders
- Random chance scales with staff count

**Tip Calculation:**
```
baseTip = orderTotal × random(10%-25%)
finalTip = baseTip × waitTimeMultiplier

Wait Time Multipliers:
- Under 2 min: 1.5x
- 2-5 min: 1.0x
- Over 5 min: 0.5x
```

### Food Decay System (decay.lua)

**Purpose:** Manages ingredient and food freshness over time.

**Decay Formula:**
```
newFreshness = currentFreshness - (baseRate × itemModifier × storageModifier × hoursElapsed)

Storage Modifiers:
- Player inventory: 1.0x
- Restaurant stash: 0.8x
- Refrigerator: 0.3x
- Freezer: 0.1x
```

---

## 🗄️ Database Schema

### restaurant_business
```sql
CREATE TABLE restaurant_business (
    job VARCHAR(50) PRIMARY KEY,
    balance INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### restaurant_transactions
```sql
CREATE TABLE restaurant_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job VARCHAR(50) NOT NULL,
    type ENUM('deposit', 'withdrawal', 'sale', 'purchase', 'payroll'),
    amount INT NOT NULL,
    description TEXT,
    player_citizenid VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### restaurant_player_data
```sql
CREATE TABLE restaurant_player_data (
    citizenid VARCHAR(50) PRIMARY KEY,
    cooking_level INT DEFAULT 1,
    cooking_xp INT DEFAULT 0,
    total_crafts INT DEFAULT 0,
    total_orders INT DEFAULT 0,
    total_tips INT DEFAULT 0,
    skills JSON,
    unlocked_recipes JSON
);
```

### restaurant_orders
```sql
CREATE TABLE restaurant_orders (
    id VARCHAR(10) PRIMARY KEY,
    job VARCHAR(50) NOT NULL,
    customer_citizenid VARCHAR(50),
    customer_name VARCHAR(100),
    items JSON,
    total INT,
    tip INT DEFAULT 0,
    status ENUM('pending', 'in_progress', 'ready', 'completed', 'cancelled'),
    employee_citizenid VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL
);
```

### restaurant_inspections
```sql
CREATE TABLE restaurant_inspections (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job VARCHAR(50) NOT NULL,
    location VARCHAR(100),
    score INT NOT NULL,
    grade CHAR(1) NOT NULL,
    violations JSON,
    bonuses JSON,
    inspector_notes TEXT,
    inspected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### restaurant_cleanliness
```sql
CREATE TABLE restaurant_cleanliness (
    job VARCHAR(50) PRIMARY KEY,
    cleanliness_score INT DEFAULT 100,
    last_cleaned TIMESTAMP NULL,
    active_violations JSON,
    updated_at TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

---

## 📖 API Reference

### Client Exports

```lua
-- Duty
exports['free-restaurants']:IsOnDuty() -- boolean
exports['free-restaurants']:GetCurrentLocation() -- locationKey, locationData

-- State
exports['free-restaurants']:GetPlayerState(key) -- any
exports['free-restaurants']:IsReady() -- boolean

-- Stations
exports['free-restaurants']:ClaimSlot(stationKey, slotIndex) -- boolean
exports['free-restaurants']:ReleaseSlot(stationKey, slotIndex) -- boolean
exports['free-restaurants']:StartFire(stationKey, slotIndex) -- void
exports['free-restaurants']:StopFire(stationKey, slotIndex) -- void

-- Cooking
exports['free-restaurants']:IsCrafting() -- boolean
exports['free-restaurants']:HasIngredients(ingredients) -- boolean, missing

-- Orders
exports['free-restaurants']:GetActiveOrders() -- table
exports['free-restaurants']:GetOrderById(orderId) -- order or nil
```

### Server Exports

```lua
-- Player Data
exports['free-restaurants']:GetPlayerData(source) -- table
exports['free-restaurants']:GetPlayerRestaurantData(citizenid) -- table
exports['free-restaurants']:SavePlayerRestaurantData(citizenid, data) -- boolean

-- Business
exports['free-restaurants']:GetBusinessBalance(job) -- number
exports['free-restaurants']:UpdateBusinessBalance(job, amount, type, desc) -- boolean
exports['free-restaurants']:GetBusinessData(job) -- table

-- Duty
exports['free-restaurants']:IsOnDuty(source) -- boolean
exports['free-restaurants']:GetSession(source) -- table
exports['free-restaurants']:AddSessionEarnings(source, amount, type) -- void
exports['free-restaurants']:IncrementTasks(source) -- void

-- Progression
exports['free-restaurants']:AwardXP(source, amount, reason, category) -- void
exports['free-restaurants']:GetSkillLevel(source, category) -- number
exports['free-restaurants']:CalculateLevel(xp) -- level, progress

-- Orders
exports['free-restaurants']:CreateOrder(source, job, location, items, payment) -- orderId
exports['free-restaurants']:CompleteOrder(orderId, employeeSource) -- success, earnings
exports['free-restaurants']:CancelOrder(orderId, reason, refund) -- boolean
exports['free-restaurants']:GetActiveOrders() -- table

-- Inspection
exports['free-restaurants']:ConductInspection(job) -- result
exports['free-restaurants']:GetCleanlinessState(job) -- table
exports['free-restaurants']:UpdateCleanliness(job, delta, reason) -- newScore
```

---

## 🔧 Troubleshooting

### Common Issues

**Script not starting:**
1. Check all dependencies are installed and started before free-restaurants
2. Verify oxmysql connection is working
3. Check server console for Lua errors

**Stations not working:**
1. Verify station coordinates in config/locations.lua
2. Ensure ox_target is running
3. Check if player has correct job assigned

**Orders not appearing:**
1. Verify job name matches between Config.Jobs and player job
2. Check if player is clocked in (on duty)
3. Ensure customer is at correct location

**Items not being created:**
1. Add all recipe result items to ox_inventory
2. Verify ingredient items exist in inventory
3. Check player has inventory space

**lb-tablet app not showing:**
1. Ensure lb-tablet is installed and running
2. Restart resource after lb-tablet starts
3. Check client console for registration errors

### Debug Mode

Enable debug logging in config/settings.lua:
```lua
Config.Settings = {
    Debug = true,
}
```

This will output detailed logs to client/server console.

### Performance Optimization

The script is optimized for performance:
- State bags for efficient slot synchronization
- Throttled particle effect updates
- Distance-based entity streaming
- Efficient database queries with indexing

Monitor resource usage with:
```
resmon 1
```

Target: < 0.05ms idle, < 0.2ms during active cooking

---

## 📄 License

This resource is provided as-is for personal and commercial use on FiveM servers. 

---

## 🙏 Credits

- **Framework:** [QBox Project](https://github.com/Qbox-project)
- **Libraries:** [Overextended](https://github.com/overextended)
- **Inspiration:** Various community cooking scripts

---

## 📞 Support

For issues and feature requests, please create an issue on GitHub or contact the developer.

---

**Version:** 1.0.0  
**Last Updated:** January 2026  
**Compatibility:** FiveM build 6116+, QBox, ox_lib v3+
