--[[
    free-restaurants Configuration
    
    This file contains all global settings, toggles, and parameters.
    Adjust these values to customize the script for your server.
    
    IMPORTANT: Location-specific overrides can be set in config/locations.lua
]]

Config = Config or {}

-- ============================================================================
-- CORE SETTINGS
-- ============================================================================

Config.Debug = false                    -- Enable debug logging to console
Config.DefaultLocale = 'en'             -- Default language (en, es, de, fr, etc.)
Config.UseRealTime = true               -- true = real world time, false = in-game time
                                        -- Affects rush hours, decay calculations, etc.

-- ============================================================================
-- ECONOMY SETTINGS
-- ============================================================================

Config.Economy = {
    -- Payment Split Configuration
    -- Set enabled = false to send all revenue to business only
    PaymentSplit = {
        enabled = true,                 -- Toggle payment splitting
        employeePercent = 40,           -- Percentage to employee (tip/commission)
        businessPercent = 60,           -- Percentage to business funds
        -- Note: These should total 100 when enabled
    },
    
    -- Paycheck System
    Paycheck = {
        enabled = true,                 -- Toggle automatic paychecks for on-duty staff
        interval = 15,                  -- Minutes between paychecks
        requireActivity = true,         -- Must have completed tasks to receive paycheck
        minimumActivity = 3,            -- Minimum tasks completed per pay period
    },
    
    -- Tip System
    Tips = {
        enabled = true,                 -- Allow customers to tip employees
        baseMultiplier = 1.0,           -- Base tip multiplier
        qualityBonus = true,            -- Better food quality = better tips
        speedBonus = true,              -- Faster service = better tips
        maxMultiplier = 2.5,            -- Maximum tip multiplier achievable
    },
    
    -- Pricing
    Pricing = {
        taxRate = 0.0,                  -- Tax percentage on sales (0.08 = 8%)
        allowDynamicPricing = true,     -- Allow business owners to set custom prices
        priceFloor = 0.5,               -- Minimum price multiplier (50% of base)
        priceCeiling = 3.0,             -- Maximum price multiplier (300% of base)
    },
}

-- ============================================================================
-- COOKING & CRAFTING SETTINGS
-- ============================================================================

Config.Cooking = {
    -- Skill Check Configuration
    SkillChecks = {
        enabled = true,                 -- Master toggle for all skill checks
        
        -- Per-action toggles (only apply if enabled = true above)
        actions = {
            prep = true,                -- Skill check when preparing ingredients
            cook = true,                -- Skill check when cooking
            plate = true,               -- Skill check when plating/finishing
            blend = true,               -- Skill check for blender/mixer items
            fry = true,                 -- Skill check for deep frying
            grill = true,               -- Skill check for grilling
            bake = true,                -- Skill check for oven items
        },
        
        -- Difficulty Settings
        difficulty = {
            base = 'medium',            -- Base difficulty: 'easy', 'medium', 'hard'
            skillScaling = true,        -- Higher player skill = easier checks
            scalingFactor = 0.05,       -- Difficulty reduction per skill level (5%)
            minimumDifficulty = 'easy', -- Lowest difficulty achievable through scaling
        },
        
        -- Skill Check Style
        style = {
            type = 'skillbar',          -- 'skillbar', 'circle', 'keys'
            keys = {'w', 'a', 's', 'd'},-- Keys used for 'keys' type
            duration = 5000,            -- Base duration in ms
        },
    },
    
    -- Quality System
    Quality = {
        enabled = true,                 -- Toggle quality mechanics
        
        -- Quality calculation factors
        factors = {
            skillCheckResult = true,    -- Skill check success affects quality
            ingredientFreshness = true, -- Ingredient freshness affects quality
            playerSkillLevel = true,    -- Player's cooking skill affects quality
            equipmentCondition = false, -- Equipment condition affects quality (future)
        },
        
        -- Quality outcome weights (should total 100)
        weights = {
            skillCheckResult = 40,      -- 40% weight from skill check performance
            ingredientFreshness = 35,   -- 35% weight from ingredient quality
            playerSkillLevel = 25,      -- 25% weight from player skill level
        },
        
        -- Quality thresholds (percentage)
        thresholds = {
            excellent = 90,             -- 90%+ = Excellent
            good = 75,                  -- 75-89% = Good
            average = 50,               -- 50-74% = Average
            poor = 25,                  -- 25-49% = Poor
            terrible = 0,               -- 0-24% = Terrible
        },
        
        -- Quality decay after cooking
        decay = {
            enabled = true,             -- Cooked food quality degrades over time
            rate = 1,                   -- Quality points lost per minute
            minimumQuality = 10,        -- Quality floor (won't go below this)
        },
    },
    
    -- Ingredient Waste System
    IngredientWaste = {
        enabled = true,                 -- Toggle ingredient waste on failures
        
        -- Waste triggers
        triggers = {
            skillCheckFail = true,      -- Failed skill check wastes ingredients
            burnt = true,               -- Overcooked/burnt items waste ingredients
            expired = true,             -- Expired ingredients are wasted
        },
        
        -- Waste amounts (percentage of ingredients lost)
        amounts = {
            skillCheckFail = {
                minor = 25,             -- Minor fail: 25% ingredients lost
                major = 50,             -- Major fail: 50% ingredients lost
                critical = 100,         -- Critical fail: 100% ingredients lost
            },
            burnt = 100,                -- Burnt always loses all ingredients
            expired = 100,              -- Expired always loses all ingredients
        },
        
        -- Waste item creation
        createWasteItem = true,         -- Create a 'waste' item instead of just deleting
        wasteItemName = 'food_waste',   -- Item name for waste
    },
    
    -- Burning/Overcooking
    Burning = {
        enabled = true,                 -- Toggle burning mechanics
        timerVisible = true,            -- Show cooking timer to player
        warningTime = 5,                -- Seconds before burning to show warning
        graceTime = 3,                  -- Seconds of "perfect" window
        
        -- Consequences
        consequences = {
            createBurntItem = true,     -- Create a burnt version of the item
            firePossible = false,       -- Can cause kitchen fire (future feature)
            fireChance = 0.05,          -- 5% chance of fire if enabled
        },
    },
    
    -- Cooking Animations
    Animations = {
        enabled = true,                 -- Play cooking animations
        lockMovement = true,            -- Player can't move while cooking
        showProps = true,               -- Show cooking props (utensils, etc.)
        cancelable = true,              -- Allow canceling cooking actions
        cancelKey = 'x',                -- Key to cancel
    },
}

-- ============================================================================
-- INGREDIENT & INVENTORY SETTINGS
-- ============================================================================

Config.Ingredients = {
    -- Freshness/Decay System
    Decay = {
        enabled = true,                 -- Toggle ingredient decay
        useOxInventoryDecay = true,     -- Use ox_inventory's built-in decay
        customDecayMultiplier = 1.0,    -- Multiplier for decay rate (2.0 = twice as fast)
        
        -- Freshness display
        showFreshness = true,           -- Show freshness in item tooltip
        freshnessFormat = 'percentage', -- 'percentage', 'time', 'label'
    },
    
    -- Storage Bonuses
    Storage = {
        refrigeratorBonus = 0.5,        -- Decay rate multiplier in fridge (50% slower)
        freezerBonus = 0.1,             -- Decay rate multiplier in freezer (90% slower)
        heatPenalty = 2.0,              -- Decay rate multiplier near heat (2x faster)
    },
    
    -- Ingredient Categories
    Categories = {
        produce = { decayRate = 1.0, refrigeratable = true },
        meat = { decayRate = 1.5, refrigeratable = true },
        dairy = { decayRate = 1.2, refrigeratable = true },
        dry = { decayRate = 0.2, refrigeratable = false },
        frozen = { decayRate = 0.1, refrigeratable = true },
        prepared = { decayRate = 1.0, refrigeratable = true },
    },
}

-- ============================================================================
-- ORDER & SERVICE SETTINGS
-- ============================================================================

Config.Orders = {
    -- Order Queue
    Queue = {
        maxActiveOrders = 20,           -- Maximum orders in queue per location
        orderExpiryTime = 15,           -- Minutes before uncompleted order expires
        showQueuePosition = true,       -- Show customers their queue position
    },
    
    -- Order Display
    Display = {
        useKDS = true,                  -- Use Kitchen Display System NUI
        use3DText = false,              -- Use 3D floating text for orders
        showOrderAge = true,            -- Show how long order has been waiting
        highlightUrgent = true,         -- Highlight orders nearing expiry
        urgentThreshold = 3,            -- Minutes remaining to be considered urgent
    },
    
    -- Order Claiming
    Claiming = {
        allowMultipleClaims = false,    -- Can one employee claim multiple orders
        maxClaimedOrders = 2,           -- Max orders per employee if allowed
        claimTimeout = 10,              -- Minutes before claimed order can be reclaimed
    },
    
    -- Player-to-Player Service
    PlayerService = {
        enabled = true,                 -- Primary mode: player customers
        proximityOrder = true,          -- Must be near counter to order
        proximityDistance = 3.0,        -- Distance in meters
        menuStyle = 'context',          -- 'context' (ox_lib) or 'nui' (custom)
    },
    
    -- NPC Catering System
    Catering = {
        enabled = true,                 -- Toggle NPC catering orders
        
        -- Order Generation
        spawnRate = {
            minimum = 10,               -- Minimum minutes between catering orders
            maximum = 30,               -- Maximum minutes between catering orders
        },
        
        -- Order Size
        orderSize = {
            minimum = 5,                -- Minimum items per catering order
            maximum = 20,               -- Maximum items per catering order
        },
        
        -- Delivery Requirements
        delivery = {
            required = true,            -- Must deliver catering orders
            timeLimit = 30,             -- Minutes to complete delivery
            bonusThreshold = 15,        -- Deliver under this time for bonus
            bonusMultiplier = 1.25,     -- 25% bonus for fast delivery
        },
        
        -- Catering Locations (coordinates set in locations.lua)
        useRandomLocations = true,      -- Random delivery locations
        usePresetLocations = true,      -- Use preset catering venues
    },
    
    -- NPC Delivery System (e.g., food delivery app orders)
    Delivery = {
        enabled = true,                 -- Toggle NPC delivery orders
        
        -- Order Generation
        spawnRate = {
            minimum = 5,                -- Minimum minutes between delivery orders
            maximum = 15,               -- Maximum minutes between delivery orders
            rushMultiplier = 0.5,       -- Spawn rate multiplier during rush (faster)
        },
        
        -- Order Size (smaller than catering)
        orderSize = {
            minimum = 1,
            maximum = 5,
        },
        
        -- Delivery Requirements
        requirements = {
            timeLimit = 20,             -- Minutes to complete delivery
            vehicleRequired = true,     -- Must use a vehicle
            allowedVehicles = {},       -- Empty = any vehicle, or specify models
        },
        
        -- Payment
        payment = {
            basePerItem = 15,           -- Base pay per item delivered
            distanceBonus = 0.5,        -- Bonus per 100m distance
            tipChance = 0.7,            -- 70% chance of customer tip
            tipRange = { min = 5, max = 25 },
        },
    },
}

-- ============================================================================
-- PROGRESSION & SKILL SETTINGS
-- ============================================================================

Config.Progression = {
    enabled = true,                     -- Master toggle for progression system
    
    -- Experience Points
    XP = {
        perSuccessfulCraft = 10,        -- Base XP per successful craft
        qualityMultiplier = true,       -- Higher quality = more XP
        difficultyMultiplier = true,    -- Harder recipes = more XP
        
        -- Multipliers
        multipliers = {
            excellent = 1.5,            -- 50% bonus for excellent quality
            good = 1.25,                -- 25% bonus for good quality
            average = 1.0,              -- No bonus for average
            poor = 0.75,                -- 25% penalty for poor
            terrible = 0.5,             -- 50% penalty for terrible
        },
        
        -- Additional XP sources
        sources = {
            deliveryComplete = 5,       -- XP for completing delivery
            cateringComplete = 15,      -- XP for completing catering order
            customerSatisfied = 3,      -- XP for satisfied customer feedback
            cleaningTask = 2,           -- XP for cleaning tasks
        },
    },
    
    -- Skill Levels
    Levels = {
        maxLevel = 100,                 -- Maximum skill level
        xpPerLevel = 100,               -- XP required per level (can be scaled)
        xpScaling = 1.1,                -- XP requirement multiplier per level
                                        -- Level 2 = 100, Level 3 = 110, Level 4 = 121, etc.
    },
    
    -- Recipe Unlocking
    RecipeUnlocks = {
        method = 'hybrid',              -- 'progression', 'blueprint', 'hybrid'
        
        -- Progression-based unlocks
        progression = {
            enabled = true,             -- Recipes unlock at certain levels
            showLockedRecipes = true,   -- Show locked recipes with level requirement
            showIngredients = false,    -- Show ingredients for locked recipes
        },
        
        -- Blueprint/Discovery unlocks
        blueprints = {
            enabled = true,             -- Can find recipe blueprints
            consumeOnUse = true,        -- Blueprint consumed when learned
            tradeable = true,           -- Blueprints can be traded between players
        },
    },
    
    -- Skill Benefits
    Benefits = {
        -- Crafting benefits
        crafting = {
            qualityBonus = 0.5,         -- +0.5% quality per skill level
            speedBonus = 0.3,           -- +0.3% crafting speed per skill level
            wasteReduction = 0.5,       -- +0.5% less waste chance per skill level
        },
        
        -- Skill check benefits
        skillCheck = {
            difficultyReduction = true, -- Higher skill = easier checks
            reductionPerLevel = 0.5,    -- 0.5% easier per level
            maxReduction = 30,          -- Maximum 30% difficulty reduction
        },
    },
    
    -- Skill Persistence
    Persistence = {
        saveToDatabase = true,          -- Save progression to database
        saveInterval = 5,               -- Minutes between auto-saves
        skillDecay = false,             -- Skills decrease over time if unused
        decayRate = 0,                  -- XP lost per day if decay enabled
    },
}

-- ============================================================================
-- BUSINESS MANAGEMENT SETTINGS
-- ============================================================================

Config.Business = {
    -- Ownership System
    Ownership = {
        enabled = true,                 -- Toggle player-owned businesses
        maxBusinessesPerPlayer = 2,     -- Max restaurants one player can own
        transferCooldown = 7,           -- Days before business can be transferred again
        
        -- Purchase
        purchase = {
            enabled = true,             -- Can buy businesses
            requireLicense = true,      -- Must have business license item
            basePriceMultiplier = 1.0,  -- Multiplier for location base prices
        },
        
        -- Sale
        sale = {
            enabled = true,             -- Can sell businesses
            sellBackPercent = 60,       -- Get 60% of purchase price back
            includeUpgrades = true,     -- Include upgrade value in sale
            upgradeValuePercent = 40,   -- Get 40% of upgrade costs back
        },
    },
    
    -- Employee Management
    Employees = {
        maxPerBusiness = 15,            -- Maximum employees per location
        
        -- Hiring
        hiring = {
            requireApplication = false, -- Must apply before being hired
            minGradeToHire = 3,         -- Minimum grade to hire others (manager)
            probationPeriod = 0,        -- Hours of probation (0 = none)
        },
        
        -- Roles (grades)
        roles = {
            -- Grade 0
            trainee = {
                canCook = true,
                canServe = true,
                canClean = true,
                canAccessStorage = false,
                canManageOrders = false,
            },
            -- Grade 1
            cook = {
                canCook = true,
                canServe = true,
                canClean = true,
                canAccessStorage = true,
                canManageOrders = false,
            },
            -- Grade 2
            chef = {
                canCook = true,
                canServe = true,
                canClean = true,
                canAccessStorage = true,
                canManageOrders = true,
            },
            -- Grade 3
            manager = {
                canCook = true,
                canServe = true,
                canClean = true,
                canAccessStorage = true,
                canManageOrders = true,
                canHire = true,
                canFire = true,
                canSetWages = true,
                canAccessFinances = true,
            },
            -- Grade 4
            owner = {
                all = true,             -- Full access to everything
            },
        },
        
        -- Wages
        wages = {
            allowCustomWages = true,    -- Owners can set custom wages
            minimumWage = 50,           -- Minimum wage per paycheck
            maximumWage = 500,          -- Maximum wage per paycheck
            defaultWages = {
                [0] = 50,               -- Trainee
                [1] = 75,               -- Cook
                [2] = 100,              -- Chef
                [3] = 150,              -- Manager
                [4] = 0,                -- Owner (doesn't get wage)
            },
        },
    },
    
    -- Financial Management
    Finances = {
        -- Business Account
        account = {
            startingBalance = 0,        -- Initial funds when purchased
            minimumBalance = -10000,    -- Can go into debt up to this amount
            interestRate = 0.05,        -- Daily interest on negative balance
        },
        
        -- Transactions
        transactions = {
            logAll = true,              -- Log all transactions
            retentionDays = 30,         -- Days to keep transaction history
        },
        
        -- Withdrawals
        withdrawals = {
            enabled = true,             -- Allow cash withdrawals
            minGradeToWithdraw = 3,     -- Manager+ can withdraw
            dailyLimit = 50000,         -- Maximum withdrawal per day
            cooldown = 60,              -- Minutes between withdrawals
        },
    },
    
    -- Stock/Inventory Management
    Stock = {
        enabled = true,                 -- Toggle stock system
        
        -- Ordering
        ordering = {
            minGradeToOrder = 2,        -- Chef+ can order stock
            deliveryTime = 5,           -- Minutes for stock delivery
            cooldown = 30,              -- Minutes between orders
            
            -- Pricing
            bulkDiscount = true,        -- Discount for large orders
            discountThreshold = 50,     -- Items needed for discount
            discountPercent = 10,       -- Percentage discount
        },
        
        -- Storage
        storage = {
            useOxInventory = true,      -- Use ox_inventory for storage
            limitedCapacity = true,     -- Storage has weight/slot limits
            spoilageInStorage = true,   -- Items can spoil in storage
        },
    },
    
    -- Menu Management
    Menu = {
        customizable = true,            -- Owners can customize menu
        minGradeToEdit = 3,             -- Manager+ can edit menu
        
        -- Pricing
        pricing = {
            allowCustomPrices = true,   -- Can change item prices
            minPrice = 1,               -- Minimum item price
            maxPrice = 1000,            -- Maximum item price
        },
        
        -- Availability
        availability = {
            canDisableItems = true,     -- Can mark items as unavailable
            autoDisableNoStock = true,  -- Auto-disable when out of ingredients
        },
    },
    
    -- Upgrades System
    Upgrades = {
        enabled = true,                 -- Toggle business upgrades
        
        -- Upgrade Categories (defined in detail per location)
        categories = {
            equipment = true,           -- Kitchen equipment upgrades
            storage = true,             -- Storage capacity upgrades
            aesthetics = true,          -- Visual upgrades
            efficiency = true,          -- Speed/quality bonuses
        },
    },
}

-- ============================================================================
-- HEALTH INSPECTION SETTINGS
-- ============================================================================

Config.HealthInspection = {
    enabled = true,                     -- Master toggle for health inspections
    
    -- Inspection Triggers
    triggers = {
        scheduled = true,               -- Regular scheduled inspections
        random = true,                  -- Random surprise inspections
        complaint = true,               -- Triggered by player complaints
    },
    
    -- Timing
    timing = {
        minimumInterval = 120,          -- Minimum minutes between inspections
        maximumInterval = 480,          -- Maximum minutes between inspections
        warningTime = 0,                -- Minutes warning before inspection (0 = surprise)
        inspectionDuration = 10,        -- Minutes the inspection takes
    },
    
    -- Violations & Scoring
    violations = {
        -- Violation types and point values
        types = {
            expired_ingredients = 10,   -- Points deducted for expired items
            dirty_station = 5,          -- Points for each dirty station
            improper_storage = 8,       -- Points for items stored incorrectly
            no_handwashing = 3,         -- Points for skipping handwash
            pest_evidence = 15,         -- Points for pest indicators
            temperature_violation = 12, -- Points for wrong storage temps
        },
        
        -- Passing score
        passingScore = 70,              -- Must score 70+ to pass
        
        -- Grade thresholds
        grades = {
            A = 90,                     -- 90-100 = A grade
            B = 80,                     -- 80-89 = B grade
            C = 70,                     -- 70-79 = C grade
            F = 0,                      -- Below 70 = Fail
        },
    },
    
    -- Consequences
    consequences = {
        -- Fines (immediate)
        fines = {
            enabled = true,
            perViolationPoint = 50,     -- $50 fine per violation point
            minimumFine = 500,          -- Minimum fine amount
            maximumFine = 10000,        -- Maximum fine amount
        },
        
        -- Grade display
        gradeDisplay = {
            enabled = true,             -- Show grade at business
            duration = 168,             -- Hours grade is displayed (168 = 1 week)
            affectsCustomers = true,    -- Grade affects customer willingness
        },
        
        -- Closure (for severe violations)
        closure = {
            enabled = true,
            threshold = 50,             -- Score below this = temporary closure
            duration = 60,              -- Minutes of forced closure
            requireReinspection = true, -- Must pass reinspection to reopen
        },
    },
    
    -- Cleanliness Tracking
    cleanliness = {
        trackDirtyStations = true,      -- Track station cleanliness
        dirtyAfterUses = 10,            -- Uses before station needs cleaning
        cleaningRequired = true,        -- Must clean to use dirty stations
        autoCleanCost = 100,            -- Cost if NPC cleans (if implemented)
    },
}

-- ============================================================================
-- IMMERSION SETTINGS
-- ============================================================================

Config.Immersion = {
    -- Uniform Requirements
    Uniform = {
        required = true,                -- Must wear uniform on duty
        checkInterval = 60,             -- Seconds between uniform checks
        graceTime = 60,                 -- Seconds to put on uniform after clocking in
        
        -- Consequences for no uniform
        consequences = {
            warning = true,             -- First offense: warning
            clockOut = false,           -- Force clock out if no uniform
            payPenalty = true,          -- Reduce pay while out of uniform
            penaltyPercent = 50,        -- Pay reduced by 50%
        },
    },
    
    -- Cleaning Tasks
    Cleaning = {
        enabled = true,                 -- Toggle cleaning mechanics
        
        -- Tasks
        tasks = {
            washDishes = true,
            mopFloors = true,
            wipeCounters = true,
            emptyTrash = true,
            cleanGrill = true,
        },
        
        -- Frequency
        frequency = {
            automatic = true,           -- Auto-generate cleaning tasks
            interval = 15,              -- Minutes between auto tasks
            maxPending = 5,             -- Max pending cleaning tasks
        },
        
        -- Rewards
        rewards = {
            xp = 2,                     -- XP per cleaning task
            payBonus = 5,               -- Bonus pay per task
        },
    },
    
    -- Handwashing
    Handwashing = {
        required = true,                -- Must wash hands
        afterToilet = true,             -- Required after using bathroom
        afterTrash = true,              -- Required after handling trash
        beforeCooking = true,           -- Required before cooking
        cooldown = 10,                  -- Minutes before hands are "dirty" again
    },
    
    -- Break System
    Breaks = {
        enabled = true,                 -- Toggle break system
        shiftLength = 60,               -- Minutes of shift before break required
        breakDuration = 5,              -- Required break duration in minutes
        maxBreaks = 2,                  -- Maximum breaks per shift
        breakArea = true,               -- Must be in designated break area
    },
    
    -- Sound Effects
    Sounds = {
        enabled = true,                 -- Toggle ambient sounds
        cookingSounds = true,           -- Sizzling, chopping, etc.
        orderBell = true,               -- Bell when new order arrives
        timerAlarm = true,              -- Alarm when cooking timer expires
        volume = 0.5,                   -- Sound volume (0.0 - 1.0)
    },
}

-- ============================================================================
-- RUSH HOUR SETTINGS
-- ============================================================================

Config.RushHour = {
    enabled = true,                     -- Toggle rush hour mechanics
    
    -- Time Periods (24-hour format)
    periods = {
        breakfast = {
            enabled = true,
            start = 7,                  -- 7:00 AM
            finish = 10,                -- 10:00 AM
            multiplier = 1.5,           -- Order frequency multiplier
        },
        lunch = {
            enabled = true,
            start = 11,                 -- 11:00 AM
            finish = 14,                -- 2:00 PM
            multiplier = 2.0,
        },
        dinner = {
            enabled = true,
            start = 17,                 -- 5:00 PM
            finish = 21,                -- 9:00 PM
            multiplier = 2.5,
        },
        latenight = {
            enabled = true,
            start = 22,                 -- 10:00 PM
            finish = 2,                 -- 2:00 AM (next day)
            multiplier = 1.5,
        },
    },
    
    -- Rush Hour Effects
    effects = {
        orderFrequency = true,          -- More frequent orders
        reducedPatience = true,         -- Customers less patient
        patienceReduction = 0.3,        -- 30% less patience
        tipBonus = true,                -- Better tips during rush
        tipBonusMultiplier = 1.25,      -- 25% better tips
        stressIncrease = true,          -- Increases player stress
        stressRate = 1.5,               -- Stress accumulation multiplier
    },
    
    -- Notifications
    notifications = {
        rushStarting = true,            -- Notify when rush hour begins
        rushEnding = true,              -- Notify when rush hour ends
        advanceWarning = 5,             -- Minutes warning before rush
    },
}

-- ============================================================================
-- UI SETTINGS
-- ============================================================================

Config.UI = {
    -- Kitchen Display System
    KDS = {
        enabled = true,
        position = 'right',             -- 'left', 'right', 'top', 'bottom'
        maxVisible = 8,                 -- Max orders visible at once
        soundOnNew = true,              -- Play sound on new order
        flashUrgent = true,             -- Flash urgent orders
    },
    
    -- Progress Bars
    ProgressBars = {
        style = 'circle',               -- 'bar', 'circle'
        position = 'bottom',            -- 'middle', 'bottom'
        showLabel = true,               -- Show action label
    },
    
    -- Notifications
    Notifications = {
        position = 'top-right',         -- ox_lib notification position
        duration = 5000,                -- Default duration in ms
    },
    
    -- 3D Text
    Text3D = {
        enabled = true,
        drawDistance = 5.0,             -- Distance to start rendering
        font = 4,                       -- GTA font ID
        scale = 0.35,                   -- Text scale
    },
    
    -- Menu Boards
    MenuBoards = {
        useDUI = true,                  -- Use Dynamic UI for menu boards
        updateInterval = 30,            -- Seconds between menu updates
    },
}

-- ============================================================================
-- INTEGRATION SETTINGS
-- ============================================================================

Config.Integration = {
    -- Inventory
    Inventory = {
        system = 'ox_inventory',        -- Inventory system to use
    },
    
    -- Target
    Target = {
        system = 'ox_target',           -- Target system to use
    },
    
    -- Phone (for delivery orders)
    Phone = {
        enabled = false,                -- Integration with phone apps
        system = 'auto',                -- 'auto', 'qb-phone', 'qs-smartphone', etc.
    },
    
    -- Banking
    -- Supported systems: 'internal', 'rx_banking', 'auto'
    -- 'internal' = Uses built-in restaurant_business table (default, no external dependency)
    -- 'rx_banking' = Integrates with rx_banking resource for shared business accounts
    -- 'auto' = Auto-detects rx_banking, falls back to internal
    Banking = {
        system = 'internal',            -- 'internal', 'rx_banking', 'auto'
        accountPrefix = 'restaurant_',  -- Prefix for rx_banking account names (e.g., restaurant_burgershot)
    },
    
    -- Status/Needs
    Status = {
        enabled = true,
        hungerKey = 'hunger',           -- Metadata key for hunger
        thirstKey = 'thirst',           -- Metadata key for thirst
        stressKey = 'stress',           -- Metadata key for stress
    },
}

-- ============================================================================
-- LOGGING SETTINGS  
-- ============================================================================

Config.Logging = {
    enabled = true,                     -- Enable logging
    
    -- Log Channels (configure your webhook/logging system)
    channels = {
        transactions = true,            -- Log financial transactions
        employment = true,              -- Log hiring/firing
        inspections = true,             -- Log health inspections
        errors = true,                  -- Log errors
    },
    
    -- Discord Webhooks (optional)
    discord = {
        enabled = false,
        webhooks = {
            transactions = '',
            employment = '',
            inspections = '',
            errors = '',
        },
    },
}

return Config
