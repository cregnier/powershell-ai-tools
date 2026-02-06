# GitHub Copilot Billing - Quick Reference Guide

## 📊 Part A: When to Fetch Data & Warning States

### **When should you download fresh GitHub data?**

1. **🔴 After Day 20** (Billing cycle ended)
   - New cycle started (21st→20th)
   - Missing tracking for new quota period
   - **Action**: Download IMMEDIATELY

2. **🟡 Month changed** (e.g., March 1st but data through Feb 28)
   - Need to calculate previous month's FINAL overages
   - Start tracking new month
   - **Action**: Download to see final costs

3. **🟡 Data >2 days old**
   - Stale visibility into current usage
   - **Action**: Download for current status

4. **✅ Data current** (updated today or yesterday)
   - No action needed

### **Warning states = about to incur costs:**

- **70-90% quota**: 🟡 WARNING - Slow down non-essential usage
- **90-100% quota**: 🟠 CRITICAL - Stop non-essential usage immediately  
- **>100% quota**: 🔴 OVER - Accept costs (billed at month end)
- **Month trending high**: 🟡 Forecast shows overage at month end

---

## 📊 Part B: The Dual-Window Billing Zones

### **Think of the month in TWO ZONES:**

#### **🟡 YELLOW ZONE (Days 1-20): HIGH RISK**
```
Days 1-20 of the month
├─ Counts toward CYCLE quota (finishing previous cycle)
└─ Counts toward MONTH overage (current month total)

Risk: DOUBLE-TRACKED
- Every request counts in TWO places
- Cycle quota may be running low (Day 16+)
- Building up month total simultaneously

Strategy: MONITOR CLOSELY
```

#### **🟢 GREEN ZONE (Days 21-End): LOW RISK**  
```
Days 21-28/31 of the month
├─ NEW cycle just started (fresh 300 quota)
└─ Counts toward MONTH overage only

Risk: SINGLE-TRACKED
- Plenty of quota remaining (just reset on 21st)
- Only affects month total

Strategy: SAFER TO USE HEAVILY
```

---

## 🗓️ Visual Map

```
Feb 1━━━━━━━━━━━━━━━━━━━━20┃21━━━━━━━28
🟡🟡🟡🟡🟡 YELLOW 🟡🟡🟡🟡🟡┃🟢🟢GREEN🟢🟢
Old cycle ending here ←──┘└──→ New cycle starts
Month total accumulating ←──────────────→
```

### **Detailed Zone Breakdown**

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

## 🎯 Key Insights

### **BEST DAYS to use Copilot heavily:**
```
✅ Days 21-25 of the month
   - Fresh 300 quota just reset
   - Only counts toward month (not finishing old cycle)
   - Lowest risk of exhausting quota
```

### **HIGHEST RISK days:**
```
⚠️ Days 15-20 of the month
   - Cycle quota nearly depleted
   - Month total building up
   - Both windows approaching limits
```

### **Why the 21st is special:**
- **Cycle quota RESETS** to fresh 300 requests
- **New cycle begins** (e.g., Feb 21 → Mar 20)
- Previous cycle closes (final quota usage locked in)
- Month overage calculation continues (Feb 1-28)

---

## 🚦 Quick Decision Tree

### **"Should I reduce usage today?"**

```
Step 1: What day is it?
├─ Days 1-14: Check quota percentage
│  ├─ <50% → ✅ Safe to continue
│  └─ >50% → 🟡 Monitor pace
│
├─ Days 15-20: Higher risk zone
│  ├─ <80% quota → 🟡 Proceed cautiously
│  ├─ >80% quota → 🟠 Reduce usage
│  └─ >90% quota → 🔴 Stop non-essential
│
└─ Days 21-End: Green zone
   ├─ <70% quota → ✅ Safe to use
   └─ >70% quota → 🟡 Monitor (unlikely early in cycle)
```

### **"Should I fetch new data today?"**

```
Check 1: Last data date
├─ Today or yesterday → ✅ Current, no fetch needed
├─ 2 days ago → 🟡 Consider fetching
└─ 3+ days ago → 🔴 Fetch now

Check 2: Is today the 21st or later?
└─ Yes, and data stops at 20th → 🔴 URGENT: Fetch now

Check 3: Did the month change?
└─ Yes (e.g., today = Mar 1, data = Feb 28) → 🟡 Fetch to see final costs
```

---

## 💰 Cost Timeline

### **When are overages actually charged?**

```
Timeline for February 2026 Example:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feb 1-28: Usage accumulates
  ├─ Every request tracked
  ├─ Running total visible in script
  └─ No charges yet

Feb 28 11:59 PM: Month closes
  └─ Final overage calculated: (Total - 300) × $0.04

March 1: Overage is FINAL
  ├─ Cannot change February usage
  ├─ Charge appears on next billing statement
  └─ New month counter resets to 0

Key Point: Overages are "in the past" once month ends!
```

---

## 📋 Daily Checklist

When running the script, look for these indicators:

```
✅ Good Signs:
- "Data is current (last updated: YYYY-MM-DD)"
- Alert Level: OK
- Percent Used: <70%
- "Month trending toward" shows $0 or low overage

🟡 Warning Signs:
- Alert Level: WARNING (70-90%)
- "Month trending toward overage"
- "Data is X days old" (X > 2)
- Forecast shows high monthly cost

🔴 Critical Signs:
- Alert Level: CRITICAL or OVER
- "TIME TO FETCH NEW DATA"
- "Billing cycle ENDED X days ago"
- Projected overage >$20
```

---

## 🔔 Script Alert Translations

| Alert Message | Meaning | Action |
|---------------|---------|--------|
| ✅ "Data is current" | Analysis up-to-date | Continue as normal |
| 🟡 "TIME TO FETCH NEW DATA" | Data stale/cycle ended | Download fresh CSV |
| 🔴 "Billing cycle ENDED" | Missing new cycle data | **URGENT** fetch now |
| ⚠️ "Month trending toward overage" | Forecast shows costs | Reduce usage |
| 🔴 "CRITICAL: Reduce usage" | >90% quota or high overage | Stop non-essential |
| 🟡 "WARNING" | 70-90% quota | Slow down usage |
| 🔴 "OVER" | >100% quota | Accept costs or stop |

---

## 💡 Pro Tips

1. **Schedule weekly data downloads** (every Monday)
   - Keeps analysis current
   - Catch trends early

2. **Always fetch after the 20th**
   - New cycle needs tracking
   - Shows fresh 300 quota

3. **Check forecast on Day 15**
   - Mid-month checkpoint
   - Time to adjust if needed

4. **Heavy usage = Days 21-25**
   - Safest time for batch jobs
   - Fresh quota available

5. **Light usage = Days 15-20**
   - End of cycle, quota low
   - Avoid surprises

---

## 📖 See Also

- Full detailed guide: `BILLING_ZONES_AND_DATA_FRESHNESS.md`
- Original billing clarification: `FINAL_BILLING_CLARIFICATION.md`
- Data freshness prompts: `DATA_FRESHNESS_PROMPTS.md`

---

**Remember**: The script will alert you! Watch for colored warnings and "TIME TO FETCH NEW DATA" prompts.
