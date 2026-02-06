# GitHub Copilot Billing: Zones & Data Freshness Guide

## 📅 Part A: When to Fetch New Data & Warning States

### **When Should I Download New GitHub Usage Data?**

You should fetch fresh data from GitHub in these scenarios:

#### 1️⃣ **Billing Cycle Ended** (After 20th of Month)
```
Today: Feb 23, 2026
Last data: Feb 20, 2026
Status: 🔴 URGENT - NEW CYCLE STARTED

Action: Download NOW to track new cycle (Feb 21-Mar 20)
```

#### 2️⃣ **Calendar Month Changed**
```
Today: Mar 2, 2026
Last data: Feb 28, 2026
Status: 🟡 IMPORTANT - New month for overage billing

Action: Download to calculate February overages and start March tracking
```

#### 3️⃣ **Data Stale (>2 Days Old)**
```
Today: Feb 8, 2026
Last data: Feb 5, 2026
Status: 🟡 Data is 3 days old

Action: Download for current usage visibility
```

#### 4️⃣ **Data Current** ✅
```
Today: Feb 5, 2026
Last data: Feb 5, 2026
Status: ✅ Data is current

Action: No download needed - analysis is up-to-date
```

### **How to Download Fresh Data**
1. Visit: https://github.com/settings/copilot
2. Click: **Usage** → **Export CSV**
3. Select date range through TODAY
4. Run: `.\AICostCalculator.ps1 -FetchMode -GitHubUsageReportCsv 'downloaded_file.csv'`

---

## ⚠️ Warning States: When You're About to Incur Costs

### **Warning Level 1: Approaching Quota (70-90%)**
```
Billing Cycle: Jan 21 - Feb 20
Used: 210 / 300 requests (70%)
Status: 🟡 WARNING

What this means:
- You've used 70% of your included quota
- Still within free tier for this cycle
- Need to slow down to avoid exceeding 300

Action: Reduce non-essential Copilot usage
```

### **Warning Level 2: Critical Quota (90-100%)**
```
Billing Cycle: Jan 21 - Feb 20
Used: 285 / 300 requests (95%)
Status: 🟠 CRITICAL

What this means:
- Only 15 requests left in quota
- Very close to overage threshold
- High risk of costs this cycle

Action: Stop non-essential usage immediately
```

### **Warning Level 3: Over Quota (>100%)**
```
Billing Cycle: Jan 21 - Feb 20
Used: 325 / 300 requests (108%)
Status: 🔴 OVER

What this means:
- Exceeded free quota by 25 requests
- Will be billed at END of calendar month
- $1.00 overage charge (25 × $0.04)

Action: Accept costs OR reduce usage for rest of month
```

### **Warning Level 4: Month Trending Toward Overage**
```
Calendar Month: February 2026
Used: 450 requests (Day 15 of 28)
Forecast: 840 requests by month end
Projected Overage: $21.60

Status: 🟡 MONTH TRENDING HIGH

What this means:
- Current pace will exceed 300/month
- Overage charges billed at month END
- Can still course-correct

Action: Monitor daily usage, reduce if needed
```

---

## 📊 Part B: Dual-Window Billing Zones (Visual Guide)

### **The Two Billing Windows Explained**

```
┌─────────────────────────────────────────────────────────────┐
│          WINDOW 1: Billing Cycle (21st→20th)               │
│          Purpose: 300 QUOTA TRACKING                        │
│          Resets: Every 21st of the month                    │
│          Billing: Tracked but charged at MONTH END          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│          WINDOW 2: Calendar Month (1st→end)                 │
│          Purpose: OVERAGE CALCULATION                       │
│          Resets: Every 1st of the month                     │
│          Billing: Charged at MONTH END (includes quota)     │
└─────────────────────────────────────────────────────────────┘
```

### **How They Overlap: January 21 - February 20 Example**

```
         January 2026        │      February 2026
  ────────────────────────────────────────────────────
  1   2   3  ...  20  [21  22  23 ... 31]  [1  2 ... 20]  21
  │                    │                     │           │
  │                    ◄──────── CYCLE ──────────────────►
  │                    │    (300 quota)     │           │
  │                                         │
  ◄──── MONTH 1 ────────────────────────────►
  │   (Jan overages)                        │
                                            │
                      ◄──── MONTH 2 ────────────────────►
                      │   (Feb overages)
```

### **Billing Zones by Day of Month**

#### **Days 1-20: OVERLAP ZONE** 🟡⚠️

```
Calendar: [============== Days 1-20 ==============]
Cycle:              [== Days 1-20 ==]
                    (previous cycle ending)

RISK LEVEL: 🟡 YELLOW (MEDIUM)
- Counts toward TWO windows
- Affects current month overage
- Affects current cycle quota

Example: Feb 15, 2026
- Counts toward: Feb 21-Mar 20 cycle quota
- Counts toward: February month overage
- Impact: DOUBLE-TRACKED
```

#### **Days 21-End: SINGLE WINDOW** 🟢✅

```
Calendar: [== Days 21-28/31 ==]
Cycle:    [== Days 21-28/31 ==] (start of NEW cycle)

RISK LEVEL: 🟢 GREEN (LOW)
- Counts toward ONE window only (month overage)
- NEW cycle just started (plenty of quota)
- Safe to use more heavily

Example: Feb 25, 2026
- Counts toward: February month overage only
- New cycle (Feb 21-Mar 20) has fresh 300 quota
- Impact: SINGLE-TRACKED, fresh quota
```

### **Visual Zone Map for Any Month**

```
DAY OF MONTH:   1  2  3  4  5 ... 15 16 17 18 19 20|21 22 23 ... 28/31
                                                    |
QUOTA WINDOW:   [========== OLD CYCLE =============]|[== NEW CYCLE ==]
                (Finishing previous cycle)          |(Fresh 300 quota)
                                                    |
MONTH WINDOW:   [============= CURRENT MONTH ========================]
                (Accumulating for overage calc)
                                                    |
RISK ZONES:     🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡🟡|🟢🟢🟢🟢🟢🟢🟢
                YELLOW: OVERLAP (Double-counted)    |GREEN: Fresh quota
```

---

## 🎯 Strategic Usage Recommendations

### **Best Days to Use Copilot Heavily**

```
✅ Days 21-25 of the month
   - Fresh cycle quota (300 available)
   - Only counts toward month overage
   - Lowest risk of quota exhaustion
```

### **Days to Monitor/Reduce Usage**

```
⚠️ Days 15-20 of the month
   - End of billing cycle (quota running low)
   - Still counts toward month total
   - Highest risk of exceeding quota
```

### **Critical Decision Points**

```
Day 10: Mid-cycle checkpoint
   └─ Check: Am I at 50% quota? (150 requests)
   └─ If YES: On track ✅
   └─ If NO:  Adjust pace ⚠️

Day 20: Cycle end - FETCH NEW DATA
   └─ Download fresh GitHub CSV
   └─ Calculate final cycle usage
   └─ Prepare for new cycle (21st)

Day 1 of Month: Month boundary - OVERAGE BILLING
   └─ Previous month overage is now FINAL
   └─ Cannot change February costs on March 1st
   └─ Download data to see final charges
```

---

## 💰 Cost Impact Examples

### **Example 1: Exceeding Quota Mid-Cycle**
```
Cycle: Jan 21-Feb 20 (31 days)
Day: Feb 5 (Day 16 of 31)
Usage: 310 / 300 requests
Status: 🔴 OVER QUOTA

Impact:
- ✅ Cycle quota: EXCEEDED by 10 requests
- ⚠️ Month overage: Only 5 days into February
- 💰 Cost: $0.00 (not billed until Feb 28/29)
- 📊 Forecast: If pace continues, ~$25 February overage
```

### **Example 2: High Usage in Green Zone**
```
Cycle: Jan 21-Feb 20
Day: Feb 23 (NEW CYCLE: Feb 21-Mar 20)
Usage: 150 requests on Feb 21-23
Quota: 150 / 300 used (50%)
Status: ✅ GREEN ZONE

Impact:
- ✅ Cycle quota: Plenty remaining (150 left)
- ⚠️ Month overage: Counts toward February
- 💰 Cost: Not billed until Feb 28/29
- 📊 Safe to continue at this pace
```

### **Example 3: Last Days of Month**
```
Cycle: Feb 21-Mar 20
Day: Feb 28 (Last day of February)
Month total: 450 requests
Status: 🟡 MONTH ENDING

Impact:
- 💰 February overage: (450 - 300) × $0.04 = $6.00
- 🔒 FINAL - Cannot change after Feb 28
- ✅ March starts fresh tomorrow
- 📊 New month = new overage counter
```

---

## 🚦 Quick Reference: Zone Status Colors

| Zone | Days | Quota Status | Month Status | Risk Level | Action |
|------|------|--------------|--------------|------------|--------|
| 🟢 **GREEN** | 21-end | Fresh cycle | Building up | **LOW** | Safe to use |
| 🟡 **YELLOW** | 1-15 | Mid-cycle | Accumulating | **MEDIUM** | Monitor pace |
| 🟠 **ORANGE** | 16-20 | Cycle ending | Near month end | **HIGH** | Reduce usage |
| 🔴 **RED** | Any | >90% quota OR trending high overage | **CRITICAL** | Stop non-essential |

---

## 📋 Checklist: Daily Monitoring

- [ ] Check quota usage: `Am I below 70% of 300?`
- [ ] Check day of month: `Am I in Yellow Zone (1-20)?`
- [ ] Check data freshness: `Is data <2 days old?`
- [ ] Check forecast: `Will I exceed budget by month end?`
- [ ] After Day 20: `Did I fetch new cycle data?`

---

## 🔔 Alert Meanings in Script Output

```
✅ "Data is current"
   → Your analysis is up-to-date, no action needed

🟡 "TIME TO FETCH NEW DATA"
   → Data is stale OR cycle ended OR month changed
   → Download fresh GitHub CSV

🔴 "Billing cycle ENDED X days ago"
   → New cycle started, data missing new tracking
   → URGENT: Fetch new data now

⚠️ "Month trending toward overage"
   → Current pace will exceed 300/month
   → Consider reducing usage

🔴 "CRITICAL: Reduce usage immediately"
   → >90% quota used OR major overage forecasted
   → Stop non-essential Copilot requests
```

---

**Remember**: Overages are charged **at the END of each calendar month**, not when you exceed the quota. The billing cycle quota is tracked for your awareness, but actual charges happen monthly.
