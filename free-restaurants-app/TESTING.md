# Food Hub App - Testing & Debug Guide

A comprehensive testing guide for the Food Hub mobile app (LB Phone/Tablet integration).

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Installation Verification](#2-installation-verification)
3. [Debug Mode Setup](#3-debug-mode-setup)
4. [Customer View Testing](#4-customer-view-testing)
5. [Employee View Testing](#5-employee-view-testing)
6. [Order Workflow Testing](#6-order-workflow-testing)
7. [Delivery System Testing](#7-delivery-system-testing)
8. [NUI Communication Testing](#8-nui-communication-testing)
9. [Multi-Player Testing](#9-multi-player-testing)
10. [Edge Cases & Error Handling](#10-edge-cases--error-handling)
11. [Troubleshooting](#11-troubleshooting)
12. [Test Log Template](#12-test-log-template)

---

## 1. Prerequisites

### Required Dependencies

| Dependency | Purpose | Check Command |
|------------|---------|---------------|
| free-restaurants | Core restaurant system | `ensure free-restaurants` |
| lb-phone OR lb-tablet | Phone/tablet UI framework | `ensure lb-phone` |
| ox_lib | UI components & callbacks | `ensure ox_lib` |
| oxmysql | Database access | `ensure oxmysql` |
| qbx_core | Framework | `ensure qbx_core` |

### Load Order

Add to `server.cfg` in this order:
```cfg
ensure ox_lib
ensure oxmysql
ensure qbx_core
ensure free-restaurants
ensure free-restaurants-app  # Must come AFTER free-restaurants
```

---

## 2. Installation Verification

### Step 2.1: Resource Load Check

**Server Console Output (Expected):**
```
[Food Hub] server/main.lua loaded
[Food Hub] client/main.lua loaded
[Food Hub] Registered with LB Phone
[Food Hub] App registered successfully
```

| Check | Expected | Status |
|-------|----------|--------|
| No Lua errors in F8 console | Clean | ☐ |
| "App registered successfully" message | Yes | ☐ |
| App appears in LB Phone | Visible in app list | ☐ |

### Step 2.2: App Icon Verification

Open LB Phone and locate "Food Hub" app.

| Check | Expected | Status |
|-------|----------|--------|
| App icon visible | Yes | ☐ |
| App name correct | "Food Hub" | ☐ |
| App opens without errors | Shows UI | ☐ |

### Step 2.3: Debug Messages

With `Config.Debug = true`, verify these messages appear in F8:

```
[Food Hub] openApp() called
[Food Hub] Sending appOpened event to UI, view=customer
[Food Hub] sendToUI event=appOpened phoneType=phone
[Food Hub] Sending via lb-phone SendCustomAppMessage
```

---

## 3. Debug Mode Setup

### Enable Debug Logging

Edit `free-restaurants-app/config.lua`:
```lua
Config.Debug = true  -- Set to true for testing
```

### F8 Console Debug Messages

When debug is enabled, you'll see:
- `[Food Hub] sendToUI event=X` - Messages sent to React UI
- `[Food Hub] openApp() called` - App opened event
- `[Food Hub] Sending via lb-phone SendCustomAppMessage` - Message routing

### Browser Console (LB Phone Dev Tools)

If your LB Phone has dev tools enabled:
```javascript
[Food Hub] Received message: {...}
[Food Hub] Parsed message type: X looking for: Y
[Food Hub] Matched event: X with data: {...}
```

---

## 4. Customer View Testing

### 4.1 Restaurant List

**Test as non-employee or off-duty employee:**

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open Food Hub app | Customer view loads | ☐ |
| 2 | View restaurant list | Shows all open restaurants | ☐ |
| 3 | Check restaurant status | Green = Open, Red = Closed | ☐ |
| 4 | Check restaurant badges | Pickup/Delivery icons shown | ☐ |

**Verification:**
- Restaurants should show current open/closed status
- Only restaurants with staff on duty show as "Open"
- Restaurant types show correct icons (burger, pizza, coffee, etc.)

### 4.2 Menu View

**Select a restaurant:**

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Tap on restaurant | Menu view opens | ☐ |
| 2 | Check categories | Categories display correctly | ☐ |
| 3 | View item details | Name, description, price shown | ☐ |
| 4 | Tap + to add item | Item added to cart | ☐ |
| 5 | Tap - to remove | Item removed from cart | ☐ |

### 4.3 Cart & Checkout

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Add items to cart | Cart badge updates | ☐ |
| 2 | Open cart | Items listed with quantities | ☐ |
| 3 | Check subtotal | Correct calculation | ☐ |
| 4 | Select delivery | Delivery fee added | ☐ |
| 5 | Check total | Subtotal + delivery fee | ☐ |
| 6 | Place order | Payment processed | ☐ |
| 7 | Order confirmation | Order ID shown | ☐ |

**Payment Verification:**
```lua
-- Check in F8 or server console
-- Player should have money deducted
```

### 4.4 Order Tracking

After placing an order:

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | View "My Orders" | Order appears in list | ☐ |
| 2 | Check order status | Shows "Pending" initially | ☐ |
| 3 | Staff accepts order | Status → "Accepted" | ☐ |
| 4 | Staff prepares | Status → "Preparing" | ☐ |
| 5 | Order ready | Status → "Ready" / "On The Way" | ☐ |
| 6 | Order complete | Status → "Picked Up" / "Delivered" | ☐ |

---

## 5. Employee View Testing

### 5.1 View Access Requirements

**Test with different player states:**

| Scenario | Expected Access | Status |
|----------|-----------------|--------|
| Not employee | Customer view only | ☐ |
| Employee, off duty | Customer view only (if requireOnDutyForEmployee=true) | ☐ |
| Employee, on duty, outside zone | Customer view only (if requireZoneForEmployee=true) | ☐ |
| Employee, on duty, in zone | Employee view accessible | ☐ |

**Config settings that affect access:**
```lua
Config.App.requireOnDutyForEmployee = true  -- Must be clocked in
Config.App.requireZoneForEmployee = true    -- Must be in restaurant
```

### 5.2 View Toggle

When employee access is granted:

| Check | Expected | Status |
|-------|----------|--------|
| Toggle buttons visible | "Order" and "Work" tabs | ☐ |
| Switch to Employee view | Dashboard loads | ☐ |
| Switch back to Customer | Restaurant list loads | ☐ |

### 5.3 Employee Dashboard

| Check | Expected | Status |
|-------|----------|--------|
| Restaurant name shown | Correct job label | ☐ |
| Open/Closed status | Matches restaurant state | ☐ |
| Pending orders count | Matches actual count | ☐ |
| Active deliveries | Shows count | ☐ |
| Staff on duty | Shows employee count | ☐ |

### 5.4 Order Queue (Employee)

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | View order queue | Pending orders listed | ☐ |
| 2 | Check order details | Items, customer info visible | ☐ |
| 3 | Accept order | Status changes to "Accepted" | ☐ |
| 4 | Start preparation | Status → "Preparing" | ☐ |
| 5 | Mark ready | Status → "Ready" | ☐ |
| 6 | Complete order | Order removed from queue | ☐ |

### 5.5 Delivery Management

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | View available deliveries | List shows pending deliveries | ☐ |
| 2 | Check delivery details | Distance, payout, items shown | ☐ |
| 3 | Accept delivery | Assigned to player | ☐ |
| 4 | GPS waypoint | Set to restaurant then customer | ☐ |
| 5 | Complete delivery | Payment received | ☐ |

### 5.6 Staff List

| Check | Expected | Status |
|-------|----------|--------|
| Shows all on-duty staff | Names and roles listed | ☐ |
| Role badges | Correct role colors | ☐ |
| Online indicator | Green dot for online | ☐ |

### 5.7 Restaurant Status Toggle

**Requires minimum grade (default: 3+):**

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Toggle open/closed | Status changes | ☐ |
| 2 | Toggle pickup orders | Setting updates | ☐ |
| 3 | Toggle delivery orders | Setting updates | ☐ |
| 4 | Low grade attempt | Permission denied | ☐ |

---

## 6. Order Workflow Testing

### 6.1 Full Pickup Order Flow

| Step | Actor | Action | Expected | Status |
|------|-------|--------|----------|--------|
| 1 | Customer | Place pickup order | Order created | ☐ |
| 2 | Employee | Receive notification | Sound + toast | ☐ |
| 3 | Employee | View in app | Order in queue | ☐ |
| 4 | Employee | Accept order | Status → Accepted | ☐ |
| 5 | Employee | Cook items | Use stations | ☐ |
| 6 | Employee | Mark ready | Status → Ready | ☐ |
| 7 | Customer | Get notification | "Order ready" | ☐ |
| 8 | Customer | Pick up at counter | Order completed | ☐ |

### 6.2 Full Delivery Order Flow

| Step | Actor | Action | Expected | Status |
|------|-------|--------|----------|--------|
| 1 | Customer | Place delivery order | Order created | ☐ |
| 2 | Employee | See in delivery list | Shows in app | ☐ |
| 3 | Employee | Accept delivery | Assigned to player | ☐ |
| 4 | Employee | Prepare food | Cook items | ☐ |
| 5 | Employee | Pick up order | Items in inventory | ☐ |
| 6 | Employee | Drive to customer | GPS waypoint | ☐ |
| 7 | Employee | Complete delivery | Payment + tip | ☐ |
| 8 | Customer | Receive food | Items in inventory | ☐ |

### 6.3 Order Status Notifications

| Status Change | Customer Gets | Employee Gets | Status |
|---------------|---------------|---------------|--------|
| Order placed | Confirmation | New order alert | ☐ |
| Accepted | Status update | - | ☐ |
| Preparing | Status update | - | ☐ |
| Ready | "Order ready" alert | - | ☐ |
| On the way | Delivery tracking | GPS to customer | ☐ |
| Completed | "Delivered" message | Payment notification | ☐ |

---

## 7. Delivery System Testing

### 7.1 Delivery Fee Calculation

**Config settings:**
```lua
Config.App.baseDeliveryFee = 50
Config.App.deliveryFeePerKm = 10
Config.App.maxDeliveryDistance = 5000  -- meters
```

| Distance | Expected Fee | Status |
|----------|--------------|--------|
| 0.5 km | $50 + $5 = $55 | ☐ |
| 1 km | $50 + $10 = $60 | ☐ |
| 3 km | $50 + $30 = $80 | ☐ |
| 5 km | $50 + $50 = $100 | ☐ |
| >5 km | Should be denied | ☐ |

### 7.2 Delivery Payout

| Component | Expected | Status |
|-----------|----------|--------|
| Base pay | Delivery fee portion | ☐ |
| Tip | Based on delivery time | ☐ |
| XP reward | Progression system | ☐ |

---

## 8. NUI Communication Testing

### 8.1 Message Format Verification

Debug messages should show this format:
```json
{
  "type": "appOpened",
  "data": {
    "view": "customer",
    "access": {...},
    "player": {...},
    "config": {...}
  }
}
```

### 8.2 Callback Testing

Test each NUI callback:

| Callback | Test | Expected | Status |
|----------|------|----------|--------|
| getRestaurants | Open app | Returns restaurant list | ☐ |
| getMenu | Select restaurant | Returns menu items | ☐ |
| placeOrder | Checkout | Creates order, returns ID | ☐ |
| getMyOrders | View orders | Returns customer orders | ☐ |
| getEmployeeDashboard | Employee view | Returns dashboard data | ☐ |
| getPendingOrders | Order queue | Returns pending orders | ☐ |
| acceptDelivery | Accept button | Assigns delivery | ☐ |
| toggleRestaurantStatus | Status toggle | Updates status | ☐ |

### 8.3 Event Testing

| Event | Trigger | Expected | Status |
|-------|---------|----------|--------|
| orderStatusUpdate | Status change | UI updates live | ☐ |
| newOrderReceived | New app order | Sound + notification | ☐ |

---

## 9. Multi-Player Testing

### 9.1 Order Competition

**With 2+ staff members:**

| Scenario | Expected | Status |
|----------|----------|--------|
| Both view same order | Both see it | ☐ |
| First accepts | Order assigned to first | ☐ |
| Second sees update | Order removed/assigned | ☐ |

### 9.2 Delivery Competition

| Scenario | Expected | Status |
|----------|----------|--------|
| Both view same delivery | Both see it | ☐ |
| First accepts | Delivery assigned to first | ☐ |
| Second refresh | Delivery not available | ☐ |

### 9.3 Real-time Updates

| Event | All Staff See | All Customers See | Status |
|-------|---------------|-------------------|--------|
| New order | In queue | - | ☐ |
| Order claimed | Updated status | Updated status | ☐ |
| Order ready | - | Notification | ☐ |
| Restaurant closes | Status change | Restaurant grayed | ☐ |

---

## 10. Edge Cases & Error Handling

### 10.1 Permission Edge Cases

| Scenario | Expected Behavior | Status |
|----------|-------------------|--------|
| Job change while app open | Access updates | ☐ |
| Clock out while in employee view | Switch to customer | ☐ |
| Grade change mid-session | Permissions update | ☐ |
| Walk out of zone | Access update if required | ☐ |

### 10.2 Payment Edge Cases

| Scenario | Expected | Status |
|----------|----------|--------|
| Insufficient funds | Order rejected, error shown | ☐ |
| Restaurant closed mid-order | Order fails gracefully | ☐ |
| Network timeout | Retry or error message | ☐ |

### 10.3 Disconnection Scenarios

| Scenario | Expected | Status |
|----------|----------|--------|
| Player disconnects as customer | Order preserved in DB | ☐ |
| Player disconnects as delivery driver | Delivery reassigned | ☐ |
| Staff disconnects | Orders become available | ☐ |

### 10.4 Resource Restart

| Check | Expected | Status |
|-------|----------|--------|
| App re-registers | No errors | ☐ |
| Active orders preserved | In database | ☐ |
| Delivery state cleared | Can be reclaimed | ☐ |

---

## 11. Troubleshooting

### Issue: App won't register

1. Check LB Phone/Tablet is running: `GetResourceState('lb-phone')`
2. Verify free-restaurants loads first
3. Check for Lua errors in F8 console
4. Verify fxmanifest.lua has no `ui_page` directive

### Issue: Black screen when opening app

1. Verify UI is built: Check `ui/dist/` folder exists
2. Check for React errors in browser console
3. Enable debug mode and check message flow
4. Verify NUI messages are being received

### Issue: "No such export GetRestaurantJobs"

1. Ensure free-restaurants starts before free-restaurants-app
2. Verify free-restaurants has the export defined
3. Check load order in server.cfg

### Issue: Orders not appearing

1. Check player has correct job
2. Verify player is on duty (if required)
3. Check server callbacks return data
4. Verify database queries work

### Issue: Status toggles not working

1. Check player grade meets minimum
2. Verify server callback permissions
3. Check for Lua errors on server

### Issue: Delivery not completing

1. Verify player is at correct location
2. Check delivery timeout hasn't expired
3. Verify order items exist

---

## 12. Test Log Template

```
============================================
FOOD HUB APP TEST LOG
============================================

Date: _______________
Tester: _______________
Version: 1.0.0

ENVIRONMENT
-----------
LB Phone Version: _______________
free-restaurants Version: _______________
Debug Mode: [ ] Enabled  [ ] Disabled

INSTALLATION
------------
[ ] Resource loads without errors
[ ] App registers with LB Phone/Tablet
[ ] App appears in app list
[ ] App opens without black screen

CUSTOMER VIEW
-------------
[ ] Restaurant list loads
[ ] Restaurant statuses accurate
[ ] Menu loads for selected restaurant
[ ] Cart functions correctly
[ ] Order placement works
[ ] Order tracking updates

EMPLOYEE VIEW
-------------
[ ] View toggle works
[ ] Dashboard loads with correct data
[ ] Order queue displays orders
[ ] Order status changes work
[ ] Delivery list loads
[ ] Delivery acceptance works
[ ] Staff list shows on-duty employees

NOTIFICATIONS
-------------
[ ] New order sound plays
[ ] Order status notifications work
[ ] Delivery notifications work

MULTI-PLAYER
------------
[ ] Orders sync between devices
[ ] Status updates propagate
[ ] Delivery claims work correctly

ISSUES FOUND
------------
1. _______________
2. _______________
3. _______________

NOTES
-----
_____________________________________________
_____________________________________________

SIGN-OFF
--------
All tests passed: [ ] Yes  [ ] No
Ready for production: [ ] Yes  [ ] No
```

---

## Quick Test Checklist

Before deployment, verify:

- [ ] Debug mode disabled (`Config.Debug = false`)
- [ ] App registers without errors
- [ ] Customer can browse and order
- [ ] Employee can view and manage orders
- [ ] Deliveries work end-to-end
- [ ] Notifications function
- [ ] No console errors during use
- [ ] Multi-player scenarios tested

---

**Document Version:** 1.0
**Last Updated:** January 2026
**For Resource Version:** free-restaurants-app 1.0.0
