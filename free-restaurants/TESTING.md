# 🧪 free-restaurants Testing & Debug Plan

A comprehensive testing guide to verify all components function correctly after installation.

---

## 📋 Table of Contents

1. [Pre-Installation Checklist](#1-pre-installation-checklist)
2. [Installation Verification](#2-installation-verification)
3. [Debug Mode Setup](#3-debug-mode-setup)
4. [Component Testing](#4-component-testing)
5. [Integration Testing](#5-integration-testing)
6. [Performance Testing](#6-performance-testing)
7. [Edge Case Testing](#7-edge-case-testing)
8. [Multi-Player Testing](#8-multi-player-testing)
9. [Debug Commands Reference](#9-debug-commands-reference)
10. [Troubleshooting Checklist](#10-troubleshooting-checklist)
11. [Test Log Template](#11-test-log-template)

---

## 1. Pre-Installation Checklist

Before installing, verify these prerequisites:

### Dependencies Check
| Dependency | Required Version | Check Command | Status |
|------------|------------------|---------------|--------|
| qbx_core | Latest | `ensure qbx_core` | ☐ |
| ox_lib | v3.0.0+ | `ensure ox_lib` | ☐ |
| ox_inventory | Latest | `ensure ox_inventory` | ☐ |
| ox_target | Latest | `ensure ox_target` | ☐ |
| oxmysql | Latest | `ensure oxmysql` | ☐ |
| Renewed-Banking (optional) | Latest | `ensure Renewed-Banking` | ☐ |
| lb-tablet (optional) | Latest | `ensure lb-tablet` | ☐ |

### Database Connection
```sql
-- Run this in your MySQL client to verify connection
SELECT VERSION();
SHOW DATABASES;
```
☐ MySQL server is running and accessible

### Server Configuration
☐ FiveM server build 6116 or higher
☐ Lua 5.4 enabled in server.cfg (`set lua54 'yes'`)
☐ OneSync enabled

---

## 2. Installation Verification

### Step 2.1: Job Setup (CRITICAL)

**Run the job setup SQL BEFORE starting the resource:**
```bash
mysql -u your_user -p your_database < sql/jobs_setup.sql
```

**Verify jobs were created:**
```sql
SELECT * FROM jobs WHERE type = 'restaurant';
-- Expected: 4 rows (burgershot, pizzathis, beanmachine, tacofarmer)

SELECT COUNT(*) FROM job_grades WHERE job_name = 'burgershot';
-- Expected: 6 (grades 0-5)
```

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| burgershot job exists | Yes | | ☐ |
| pizzathis job exists | Yes | | ☐ |
| beanmachine job exists | Yes | | ☐ |
| tacofarmer job exists | Yes | | ☐ |
| Each job has 6 grades | Yes | | ☐ |

### Step 2.2: Resource Load Check

**Server Console Commands:**
```
refresh
ensure free-restaurants
```

**Expected Output:**
```
[free-restaurants] server/jobs.lua loaded
[free-restaurants] Checking restaurant jobs...
[free-restaurants] All jobs already registered
[free-restaurants] server/banking.lua loaded
[free-restaurants] Renewed-Banking detected - using society accounts
   (OR: Renewed-Banking not found - using internal banking)
[free-restaurants] server/main.lua loaded
[free-restaurants] server/duty.lua loaded
[free-restaurants] server/stations.lua loaded
[free-restaurants] server/crafting.lua loaded
[free-restaurants] server/customers.lua loaded
[free-restaurants] server/management.lua loaded
[free-restaurants] server/progression.lua loaded
[free-restaurants] server/decay.lua loaded
[free-restaurants] server/delivery.lua loaded
[free-restaurants] server/inspection.lua loaded
[free-restaurants] server/npc-customers.lua loaded
[free-restaurants] Server initialized
```

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| No Lua errors in console | Clean load | | ☐ |
| All server scripts loaded | 13 scripts | | ☐ |
| Jobs check message | Yes | | ☐ |
| Banking mode detected | Yes | | ☐ |
| "Server initialized" message | Yes | | ☐ |

### Step 2.3: Database Table Verification

**Run in MySQL:**
```sql
USE your_database_name;

SHOW TABLES LIKE 'restaurant_%';
```

**Expected Tables:**
| Table Name | Status |
|------------|--------|
| restaurant_business | ☐ |
| restaurant_transactions | ☐ |
| restaurant_player_data | ☐ |
| restaurant_orders | ☐ |
| restaurant_pricing | ☐ |
| restaurant_duty_sessions | ☐ |
| restaurant_inspections | ☐ |
| restaurant_cleanliness | ☐ |

**Verify Table Structure:**
```sql
DESCRIBE restaurant_business;
DESCRIBE restaurant_player_data;
DESCRIBE restaurant_orders;
```

### Step 2.3: Client Load Check

**In-Game (F8 Console):**
```
-- Check if resource is running
GetResourceState('free-restaurants')
```

**Expected:** `started`

---

## 3. Debug Mode Setup

### Enable Debug Logging

Edit `config/settings.lua`:
```lua
Config.Settings = {
    Debug = true,  -- Set to true
    -- ...
}
```

### Monitor Resource Performance

**Server Console:**
```
resmon 1
```

**Look for:**
- `free-restaurants` resource time
- Target: < 0.05ms idle, < 0.5ms active

### Enable Client Debug Output

**F8 Console:**
```lua
-- This will show debug messages
LocalPlayer.state.freeRestaurantsDebug = true
```

---

## 4. Component Testing

### 4.1 Job System Testing

#### Test 4.1.1: Job Assignment
**Steps:**
1. Open admin menu or use command: `/setjob [playerid] burgershot 0`
2. Check player job: `/job`

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Job assigned | burgershot | | ☐ |
| Grade correct | 0 (Trainee) | | ☐ |
| Job label shows | Burger Shot | | ☐ |

#### Test 4.1.2: Grade Permissions
**Test each grade level:**
```
/setjob [id] burgershot 0  -- Trainee
/setjob [id] burgershot 3  -- Shift Manager
/setjob [id] burgershot 5  -- Owner
```

| Grade | Can Cook | Can Manage | Can Access Boss Menu | Status |
|-------|----------|------------|----------------------|--------|
| 0 | ☐ Yes | ☐ No | ☐ No | |
| 3 | ☐ Yes | ☐ Yes | ☐ Limited | |
| 5 | ☐ Yes | ☐ Yes | ☐ Full | |

---

### 4.2 Duty System Testing

#### Test 4.2.1: Clock In/Out
**Steps:**
1. Go to restaurant duty point
2. Use ox_target on duty point
3. Select "Clock In"

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Target option appears | "Clock In" visible | | ☐ |
| Clock in succeeds | Notification shown | | ☐ |
| Uniform changes | Player model updates | | ☐ |
| Duty status updates | job.onduty = true | | ☐ |

**Verify in F8:**
```lua
print(LocalPlayer.state.isOnDuty)
-- Expected: true
```

#### Test 4.2.2: Clock Out
**Steps:**
1. Use duty point again
2. Select "Clock Out"

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Option shows "Clock Out" | Yes | | ☐ |
| Uniform reverts | Original clothes | | ☐ |
| Session saved | Check database | | ☐ |

**Database Verification:**
```sql
SELECT * FROM restaurant_duty_sessions 
ORDER BY id DESC LIMIT 1;
```

#### Test 4.2.3: Paycheck System
**Steps:**
1. Clock in
2. Wait 60+ seconds
3. Perform tasks (cook items)
4. Clock out

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Paycheck received | Cash added | | ☐ |
| Amount correct | Base × multiplier | | ☐ |
| Session recorded | In database | | ☐ |

---

### 4.3 Station System Testing

#### Test 4.3.1: Station Target Zones
**Steps:**
1. Clock in at restaurant
2. Approach cooking station (grill, fryer, etc.)
3. Look at station

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Target eye appears | Yes | | ☐ |
| Options show | "Use Slot 1", etc. | | ☐ |
| Multiple slots visible | Based on config | | ☐ |

#### Test 4.3.2: Slot Claiming
**Steps:**
1. Select a slot
2. Choose a recipe

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Slot claimed | Server confirms | | ☐ |
| Other players see claimed | State synced | | ☐ |
| HUD appears | Slot status shown | | ☐ |

**F8 Debug:**
```lua
print(json.encode(GlobalState['stations']))
```

#### Test 4.3.3: Prop Spawning
**Steps:**
1. Start cooking an item
2. Observe station surface

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Food prop appears | On station surface | | ☐ |
| Prop positioned correctly | Not floating/clipping | | ☐ |
| Prop deleted after | When cooking ends | | ☐ |

#### Test 4.3.4: Particle Effects
**Steps:**
1. Start cooking
2. Let item cook through stages

| Stage | Expected Effect | Actual | Status |
|-------|-----------------|--------|--------|
| Cooking Start | Light steam | | ☐ |
| Mid Cooking | Steam + sizzle | | ☐ |
| Almost Done | More visible steam | | ☐ |
| Burning | Smoke particles | | ☐ |

#### Test 4.3.5: Fire System
**Steps:**
1. Start cooking
2. Let item burn completely
3. Continue ignoring

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Smoke appears | After burn | | ☐ |
| Small fire starts | After continued neglect | | ☐ |
| Fire escalates | Level increases | | ☐ |
| Fire spreads | Script fire natives | | ☐ |

**Note:** Have a way to extinguish or restart resource!

---

### 4.4 Cooking System Testing

#### Test 4.4.1: Ingredient Check
**Steps:**
1. Attempt recipe without ingredients
2. Attempt recipe with ingredients

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| No ingredients = error | "Missing ingredients" | | ☐ |
| Has ingredients = proceed | Crafting starts | | ☐ |
| Correct items removed | Inventory updated | | ☐ |

#### Test 4.4.2: Skill Check Mini-Game
**Steps:**
1. Start a recipe that requires skill check
2. Complete/fail the skill check

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Skill check appears | ox_lib skillcheck | | ☐ |
| Keys randomized | Different each time | | ☐ |
| Success = quality item | Higher quality | | ☐ |
| Partial = lower quality | Reduced quality | | ☐ |
| Fail = item lost | Ingredients gone | | ☐ |

#### Test 4.4.3: Quality System
**Steps:**
1. Craft item with fresh ingredients + perfect skill check
2. Craft item with old ingredients + poor skill check

| Condition | Expected Quality | Actual | Status |
|-----------|------------------|--------|--------|
| Fresh + Perfect | 90-100 | | ☐ |
| Fresh + Good | 70-89 | | ☐ |
| Old + Perfect | 60-80 | | ☐ |
| Old + Poor | 20-50 | | ☐ |

**Check Item Metadata:**
```lua
-- In F8 after receiving item
local items = exports.ox_inventory:GetPlayerItems()
print(json.encode(items))
-- Look for quality, freshness, craftedAt
```

#### Test 4.4.4: Batch Crafting
**Steps:**
1. Have ingredients for 5+ of same item
2. Use batch craft option
3. Set quantity to 3

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Max calculated | Shows correct max | | ☐ |
| Batch starts | Progress for total time | | ☐ |
| All items received | 3 items in inventory | | ☐ |
| All ingredients removed | Correct amount gone | | ☐ |

---

### 4.5 Order System Testing

#### Test 4.5.1: Customer Ordering (Player as Customer)
**Setup:** Need a second player or test without restaurant job

**Steps:**
1. Approach customer ordering point
2. Open menu
3. Add items to cart
4. Complete order

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Menu opens | Items displayed | | ☐ |
| Prices correct | Match config | | ☐ |
| Cart works | Add/remove items | | ☐ |
| Payment processes | Money deducted | | ☐ |
| Order created | Appears for staff | | ☐ |

#### Test 4.5.2: Kitchen Display System (Staff)
**Steps:**
1. Clock in as staff
2. Open KDS (orders menu)
3. View incoming order

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Orders visible | Shows pending | | ☐ |
| Order details | Items, customer, time | | ☐ |
| Claim works | Status → In Progress | | ☐ |
| Ready works | Status → Ready | | ☐ |
| Complete works | Order finished | | ☐ |

#### Test 4.5.3: Order Status Flow
**Full order lifecycle:**

| Step | Action | Expected Status | Status |
|------|--------|-----------------|--------|
| 1 | Customer orders | PENDING | ☐ |
| 2 | Staff claims | IN_PROGRESS | ☐ |
| 3 | Staff marks ready | READY | ☐ |
| 4 | Customer notified | Notification | ☐ |
| 5 | Customer picks up | COMPLETED | ☐ |

---

### 4.6 Delivery System Testing

#### Test 4.6.1: Delivery Generation
**Steps:**
1. Clock in at restaurant
2. Wait for delivery to spawn (or use debug command)
3. Open delivery menu

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Deliveries appear | After ~2 min | | ☐ |
| Details shown | Items, payout, distance | | ☐ |
| Accept works | Delivery assigned | | ☐ |

#### Test 4.6.2: Delivery Workflow
**Steps:**
1. Accept delivery
2. Go to restaurant (pickup)
3. Drive to destination
4. Complete delivery

| Step | Expected | Actual | Status |
|------|----------|--------|--------|
| GPS set | Waypoint to restaurant | | ☐ |
| Pickup prompt | At restaurant | | ☐ |
| Items received | In inventory | | ☐ |
| GPS updates | Waypoint to customer | | ☐ |
| Complete prompt | At destination | | ☐ |
| Payment received | Cash + tip | | ☐ |
| XP awarded | Notification | | ☐ |

#### Test 4.6.3: Delivery Timeout
**Steps:**
1. Accept delivery
2. Don't complete within 10 minutes

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Timeout warning | At 8 min? | | ☐ |
| Delivery cancelled | At 10 min | | ☐ |
| Items removed | From inventory | | ☐ |
| No payment | Nothing received | | ☐ |

---

### 4.7 Progression System Testing

#### Test 4.7.1: XP Gain
**Steps:**
1. Complete various actions
2. Watch for XP notifications

| Action | Expected XP | Actual | Status |
|--------|-------------|--------|--------|
| Craft basic item | 10 XP | | ☐ |
| Craft complex item | 25+ XP | | ☐ |
| Complete order | 15 XP | | ☐ |
| Complete delivery | 20 XP | | ☐ |
| Clean station | 10 XP | | ☐ |

#### Test 4.7.2: Level Up
**Steps:**
1. Accumulate enough XP for level 2 (500 XP)
2. Watch for level up notification

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Level up notification | Shows new level | | ☐ |
| Sound plays | Celebration sound | | ☐ |
| Bonuses apply | Check /cookingprogression | | ☐ |

#### Test 4.7.3: Progression Menu
**Command:** `/cookingprogression` or `/chefstats`

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Menu opens | ox_lib context | | ☐ |
| Level shown | Current level | | ☐ |
| XP bar | Progress to next | | ☐ |
| Skills listed | Categories | | ☐ |
| Leaderboard | Top players | | ☐ |

---

### 4.8 Health Inspection Testing

#### Test 4.8.1: Cleanliness Score
**Steps:**
1. Check initial cleanliness
2. Perform cleaning actions
3. Wait for decay

**Command:** `/inspectionstatus`

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Initial score | 100 | | ☐ |
| After cleaning | Increase | | ☐ |
| After 1 hour | Slight decrease | | ☐ |

#### Test 4.8.2: Cleaning Actions
**Steps:**
1. Have cleaning supplies in inventory
2. Use cleaning target zones
3. Complete cleaning progress

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Clean option appears | When on duty | | ☐ |
| Requires supplies | Check inventory | | ☐ |
| Progress bar | 8-15 seconds | | ☐ |
| Score increases | After completion | | ☐ |
| XP awarded | 10 XP | | ☐ |

#### Test 4.8.3: Force Inspection (Admin)
**Admin Command:**
```lua
-- Server console or admin tool
exports['free-restaurants']:ConductInspection('burgershot')
```

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Inspection triggers | All staff notified | | ☐ |
| Grade calculated | A-F based on score | | ☐ |
| Violations listed | If any found | | ☐ |
| History saved | In database | | ☐ |

---

### 4.9 NPC Customer Testing

#### Test 4.9.1: NPC Spawn
**Conditions:** Staff on duty, not at max orders

**Steps:**
1. Clock in
2. Wait 1-3 minutes

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| NPC spawns | At customer area | | ☐ |
| Order created | Visible in KDS | | ☐ |
| Marker visible | Above NPC head | | ☐ |
| NPC animates | Waiting animation | | ☐ |

#### Test 4.9.2: NPC Order Completion
**Steps:**
1. Complete NPC order
2. Mark as ready
3. Complete order

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| NPC reacts | Happy/satisfied anim | | ☐ |
| Tip received | Based on wait time | | ☐ |
| NPC leaves | Walks away, despawns | | ☐ |
| Order cleared | Removed from system | | ☐ |

#### Test 4.9.3: NPC Timeout
**Steps:**
1. Let NPC order expire (5 min)

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Warning at 4 min? | Notification | | ☐ |
| NPC frustrated | Animation change | | ☐ |
| NPC leaves | At 5 min | | ☐ |
| Cleanliness hit | -2 points | | ☐ |
| No payment | No tip | | ☐ |

---

### 4.10 Management System Testing

#### Test 4.10.1: Boss Menu Access
**Steps:**
1. Set job grade to manager (3+)
2. Access boss menu point

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Menu appears | For grade 3+ | | ☐ |
| Denied for low grade | For grade 0-2 | | ☐ |
| All tabs visible | Employees, Finances, etc. | | ☐ |

#### Test 4.10.2: Employee Management
**Steps:**
1. Open employee list
2. Modify employee grade
3. Fire employee

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Employees listed | All job holders | | ☐ |
| Online status shown | Green/gray dot | | ☐ |
| Promote works | Grade increases | | ☐ |
| Demote works | Grade decreases | | ☐ |
| Fire works | Removes from job | | ☐ |

#### Test 4.10.3: Financial Management
**Steps:**
1. Check business balance
2. Deposit funds
3. Withdraw funds
4. View transactions

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Balance shown | Current amount | | ☐ |
| Deposit works | Balance increases | | ☐ |
| Withdraw works | Balance decreases | | ☐ |
| Transaction logged | In history | | ☐ |

#### Test 4.10.4: Stock Ordering
**Steps:**
1. Open stock menu
2. Order supplies
3. Check stash

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Items listed | With prices | | ☐ |
| Order processes | Balance deducted | | ☐ |
| Items appear | In restaurant stash | | ☐ |

---

### 4.11 lb-tablet Integration Testing

**Skip if lb-tablet not installed**

#### Test 4.11.1: App Registration
**Steps:**
1. Start lb-tablet
2. Open tablet
3. Look for Kitchen Manager app

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| App appears | In app list | | ☐ |
| Icon correct | Restaurant icon | | ☐ |
| Opens without error | Shows dashboard | | ☐ |

#### Test 4.11.2: Dashboard Data
**Steps:**
1. Open Kitchen Manager app
2. Review dashboard

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Order counts | Pending/cooking/ready | | ☐ |
| Sales data | Today/week | | ☐ |
| Staff status | Online/on duty | | ☐ |
| Health grade | Current grade | | ☐ |
| Player level | XP progress | | ☐ |

#### Test 4.11.3: App Actions
**Steps:**
1. Use tablet to manage orders
2. Accept delivery via tablet

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Start order | Status updates | | ☐ |
| Ready order | Customer notified | | ☐ |
| Accept delivery | Assigned to player | | ☐ |
| Withdraw funds | Balance updates | | ☐ |

---

### 4.12 Food Decay Testing

#### Test 4.12.1: Decay Rate
**Steps:**
1. Craft food item
2. Note initial freshness
3. Wait 30-60 minutes
4. Check freshness again

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Initial freshness | 100 or quality-based | | ☐ |
| After 30 min | Slight decrease | | ☐ |
| After 60 min | Noticeable decrease | | ☐ |

**Database Check:**
```sql
-- Check item metadata changes
SELECT * FROM restaurant_player_data 
WHERE citizenid = 'YOUR_CITIZENID';
```

#### Test 4.12.2: Storage Modifiers
**Steps:**
1. Place item in regular stash
2. Place item in refrigerator (if configured)
3. Compare decay rates

| Storage | Expected Decay Rate | Actual | Status |
|---------|---------------------|--------|--------|
| Player inventory | 1.0x | | ☐ |
| Regular stash | 0.8x | | ☐ |
| Refrigerator | 0.3x | | ☐ |
| Freezer | 0.1x | | ☐ |

---

## 5. Integration Testing

### 5.1 Full Customer Experience
**Scenario:** Complete customer journey

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Customer approaches counter | Target options appear | ☐ |
| 2 | Opens menu | Items with prices | ☐ |
| 3 | Adds items to cart | Total updates | ☐ |
| 4 | Pays for order | Money deducted | ☐ |
| 5 | Waits for order | Can check status | ☐ |
| 6 | Staff prepares | Customer sees progress | ☐ |
| 7 | Order ready | Customer notified | ☐ |
| 8 | Picks up order | Items in inventory | ☐ |

### 5.2 Full Staff Shift
**Scenario:** Complete work shift

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Clock in | Uniform changes | ☐ |
| 2 | View orders | KDS shows queue | ☐ |
| 3 | Claim order | Status updates | ☐ |
| 4 | Cook items | Skill checks work | ☐ |
| 5 | Complete order | Tips received | ☐ |
| 6 | Take delivery | GPS works | ☐ |
| 7 | Complete delivery | Payment received | ☐ |
| 8 | Clean station | XP gained | ☐ |
| 9 | Clock out | Paycheck received | ☐ |

### 5.3 Business Day Cycle
**Scenario:** Full business operation

| Time | Event | Expected | Status |
|------|-------|----------|--------|
| Morning | Staff clocks in | Duty session starts | ☐ |
| Morning | NPC customers | Orders generate | ☐ |
| Midday | Deliveries available | Can accept | ☐ |
| Afternoon | Inspection possible | Random trigger | ☐ |
| Evening | Manager withdraws | Funds accessible | ☐ |
| Night | Staff clocks out | Paycheck issued | ☐ |

---

## 6. Performance Testing

### 6.1 Resource Monitor
**Command:** `resmon 1`

| Metric | Target | Measured | Status |
|--------|--------|----------|--------|
| Idle time | < 0.05ms | | ☐ |
| Active cooking | < 0.2ms | | ☐ |
| With particles | < 0.3ms | | ☐ |
| Peak (fire + props) | < 0.5ms | | ☐ |

### 6.2 Entity Count
**Monitor during operation:**

| Condition | Max Entities | Actual | Status |
|-----------|--------------|--------|--------|
| Idle | 0 | | ☐ |
| 1 cooking slot | 1-2 | | ☐ |
| 4 cooking slots | 4-8 | | ☐ |
| With NPC customers | +1 per NPC | | ☐ |

### 6.3 Network Traffic
**Check for excessive events:**

| Event | Frequency | Expected | Status |
|-------|-----------|----------|--------|
| State bag updates | On change only | | ☐ |
| Order updates | On status change | | ☐ |
| HUD updates | Every 100ms when active | | ☐ |

### 6.4 Database Query Performance
**Monitor MySQL slow query log:**

| Query Type | Expected Time | Actual | Status |
|------------|---------------|--------|--------|
| Player data load | < 10ms | | ☐ |
| Order creation | < 20ms | | ☐ |
| Transaction insert | < 10ms | | ☐ |

---

## 7. Edge Case Testing

### 7.1 Player Disconnect During Activity
| Scenario | Expected Behavior | Status |
|----------|-------------------|--------|
| Disconnect while cooking | Slot released | ☐ |
| Disconnect while on delivery | Delivery cancelled | ☐ |
| Disconnect while ordering | Order preserved or cancelled | ☐ |
| Disconnect while clocked in | Session ends gracefully | ☐ |

### 7.2 Resource Restart
| Scenario | Expected Behavior | Status |
|----------|-------------------|--------|
| Restart during cooking | Props cleaned up | ☐ |
| Restart with active orders | Orders preserved in DB | ☐ |
| Restart with fires | Fires extinguished | ☐ |
| Restart with NPCs | NPCs cleaned up | ☐ |

### 7.3 Inventory Edge Cases
| Scenario | Expected Behavior | Status |
|----------|-------------------|--------|
| Inventory full during craft | Error message, ingredients returned | ☐ |
| Partial ingredients | Cannot start craft | ☐ |
| Remove items mid-craft | Craft fails gracefully | ☐ |

### 7.4 Permission Edge Cases
| Scenario | Expected Behavior | Status |
|----------|-------------------|--------|
| Grade change while on duty | Permissions update | ☐ |
| Job change while cooking | Cooking cancelled | ☐ |
| Fired while on delivery | Delivery cancelled | ☐ |

---

## 8. Multi-Player Testing

### 8.1 Simultaneous Slot Usage
**Test with 2+ players:**

| Scenario | Expected | Status |
|----------|----------|--------|
| Different slots, same station | Both work | ☐ |
| Same slot attempt | Second player rejected | ☐ |
| Slot state synced | All see correct state | ☐ |

### 8.2 Order Competition
**Test with 2+ staff:**

| Scenario | Expected | Status |
|----------|----------|--------|
| Both claim same order | First wins | ☐ |
| Order list synced | Same view for all | ☐ |
| Completion by one | Others see update | ☐ |

### 8.3 Delivery Competition
| Scenario | Expected | Status |
|----------|----------|--------|
| Both accept same delivery | First wins | ☐ |
| Delivery list updates | Second sees removal | ☐ |

---

## 9. Debug Commands Reference

### Server Console Commands
```bash
# Check player data
free-restaurants:debug:player [serverId]

# Force inspection
free-restaurants:debug:inspect [job]

# Force NPC order
free-restaurants:debug:npcorder [job]

# Clear all fires
free-restaurants:debug:clearfires

# Reset cleanliness
free-restaurants:debug:resetcleanliness [job]
```

### Client Commands (F8)
```lua
-- Check player state
print(json.encode(exports['free-restaurants']:GetPlayerState()))

-- Check if on duty
print(exports['free-restaurants']:IsOnDuty())

-- Check current location
local loc, data = exports['free-restaurants']:GetCurrentLocation()
print(loc, json.encode(data))

-- Check active station
print(json.encode(exports['free-restaurants']:GetActiveStation()))
```

### SQL Debug Queries
```sql
-- View all orders
SELECT * FROM restaurant_orders ORDER BY created_at DESC LIMIT 20;

-- View player progression
SELECT * FROM restaurant_player_data;

-- View business balances
SELECT * FROM restaurant_business;

-- View recent transactions
SELECT * FROM restaurant_transactions ORDER BY created_at DESC LIMIT 50;

-- View inspection history
SELECT * FROM restaurant_inspections ORDER BY inspected_at DESC LIMIT 10;

-- View duty sessions
SELECT * FROM restaurant_duty_sessions ORDER BY id DESC LIMIT 20;
```

---

## 10. Troubleshooting Checklist

### Issue: Script won't start
- [ ] Check all dependencies are ensured before free-restaurants
- [ ] Verify no Lua syntax errors in console
- [ ] Confirm database connection working
- [ ] Check for conflicting resources

### Issue: Stations not working
- [ ] Verify player has correct job
- [ ] Confirm player is clocked in
- [ ] Check station coordinates in config
- [ ] Verify ox_target is working
- [ ] Check for zone conflicts

### Issue: Orders not appearing
- [ ] Confirm staff is on duty
- [ ] Check job name matches config
- [ ] Verify order was created (check database)
- [ ] Check for JavaScript console errors (NUI)

### Issue: Items not crafting
- [ ] Verify ingredients in ox_inventory items.lua
- [ ] Check result item exists in inventory config
- [ ] Confirm player has required ingredients
- [ ] Check player inventory has space

### Issue: No XP/progression
- [ ] Verify database table exists
- [ ] Check for callback errors in console
- [ ] Confirm player citizenid is correct
- [ ] Test with manual XP award

### Issue: Performance problems
- [ ] Enable resmon, identify spike source
- [ ] Check for excessive particle effects
- [ ] Monitor entity count
- [ ] Check database query times

---

## 11. Test Log Template

Use this template to document your testing session:

```
===========================================
FREE-RESTAURANTS TEST LOG
===========================================

Date: _______________
Tester: _______________
Server Build: _______________
Resource Version: 1.0.0

ENVIRONMENT
-----------
qbx_core version: _______________
ox_lib version: _______________
ox_inventory version: _______________
Database: _______________

INSTALLATION TESTS
------------------
[ ] Resource loads without errors
[ ] All database tables created
[ ] Client loads without errors

COMPONENT TESTS
---------------
Duty System:
[ ] Clock in works
[ ] Clock out works  
[ ] Paycheck received

Stations:
[ ] Target zones appear
[ ] Slot claiming works
[ ] Props spawn correctly
[ ] Particles display

Cooking:
[ ] Skill checks work
[ ] Items created with quality
[ ] Batch crafting works

Orders:
[ ] Customer can order
[ ] Staff sees orders
[ ] Full workflow completes

Deliveries:
[ ] Deliveries generate
[ ] GPS works
[ ] Completion works

Progression:
[ ] XP gained
[ ] Level up works
[ ] Menu displays

Inspections:
[ ] Status viewable
[ ] Cleaning works
[ ] Inspection triggers

NPCs:
[ ] NPCs spawn
[ ] Orders created
[ ] Timeout works

Management:
[ ] Employee list works
[ ] Finances work
[ ] Stock ordering works

INTEGRATION TESTS
-----------------
[ ] Full customer journey
[ ] Full staff shift
[ ] Multi-player scenarios

PERFORMANCE
-----------
Idle resource time: _____ms
Active resource time: _____ms
Peak resource time: _____ms

ISSUES FOUND
------------
1. _______________
2. _______________
3. _______________

NOTES
-----
_______________________________________________
_______________________________________________

SIGN-OFF
--------
All tests passed: [ ] Yes  [ ] No
Ready for production: [ ] Yes  [ ] No
```

---

## ✅ Testing Complete Checklist

Before going live, ensure:

- [ ] All installation checks passed
- [ ] All component tests passed
- [ ] Integration tests passed
- [ ] Performance within targets
- [ ] Multi-player scenarios tested
- [ ] Edge cases handled
- [ ] No critical issues remaining
- [ ] Debug mode disabled in config
- [ ] Backup database created

---

**Document Version:** 1.0  
**Last Updated:** January 2026  
**For Resource Version:** free-restaurants 1.0.0
