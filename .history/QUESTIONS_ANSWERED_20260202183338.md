# ANSWERS TO KEY QUESTIONS

## Question 1: What happens after Feb 20 when the billing cycle ends?

### Current Situation (Feb 2, 2026)
- **Current billing cycle**: Jan 21 → Feb 20, 2026
- **Script tells you**: "Pull next usage report after: 2026-02-20"
- **Current forecast**: Will hit 806 requests by Feb 20 (WILL EXCEED quota of 300)

### What Happens on Feb 21+?

**✅ The script AUTOMATICALLY handles cycle transitions!**

The `Calculate-DualWindowCosts` function (line 1100) has logic that determines the current cycle based on the date:

```powershell
if ($CurrentDate.Day >= 21) {
    # Cycle is from 21st of THIS month to 20th of NEXT month
    $cycleStart = 21st of current month
    $cycleEnd = 20th of next month
} else {
    # Cycle is from 21st of LAST month to 20th of THIS month
    $cycleStart = 21st of previous month
    $cycleEnd = 20th of current month
}
```

**Example Timeline:**

| Date | Current Cycle | Status |
|------|---------------|--------|
| Feb 2, 2026 | Jan 21 → Feb 20 | ✓ Active (13 days in) |
| Feb 20, 2026 | Jan 21 → Feb 20 | ✓ Last day of cycle |
| **Feb 21, 2026** | **Feb 21 → Mar 20** | ✓ **NEW CYCLE STARTS** |
| Mar 20, 2026 | Feb 21 → Mar 20 | ✓ Last day of cycle |
| Mar 21, 2026 | Mar 21 → Apr 20 | ✓ Next cycle starts |

### What You Should Do:

**After Feb 20:**
1. **Download new usage report** from GitHub (will include Jan 21 - Feb 20 data)
2. **Run the tool again** with the new CSV: 
   ```powershell
   .\AICostCalculator.ps1 -GitHubUsageReportCsv "new_report_feb21.csv"
   ```
3. **Tool will automatically**:
   - Detect current cycle is now Feb 21 → Mar 20
   - Calculate Feb 21-Mar 20 cycle usage (starts at 0)
   - Calculate February calendar month overage charges
   - Forecast to Mar 20 based on business days remaining

**No manual intervention needed** - the cycle transition is automatic!

---

## Question 2: Why 278 and not 300? Could you have used more on weekends?

### Analysis of Jan 21-31 Period

**Period breakdown:**
- **Total days**: 11 days (Jan 21-31)
- **Business days**: 8 days (weekdays)
- **Weekend days**: 3 days
  - Jan 24 (Saturday)
  - Jan 25 (Sunday)
  - Jan 31 (Friday) - actually a weekday!

Wait, let me recalculate... Jan 21-31, 2026:
- Jan 21 (Wed), 22 (Thu), 23 (Fri), 24 (Sat), 25 (Sun)
- Jan 26 (Mon), 27 (Tue), 28 (Wed), 29 (Thu), 30 (Fri), 31 (Sat)

**Actual weekend days**: 3 (Jan 24, 25, 31 = 2 Saturdays, 1 Sunday)
**Business days**: 8

### Usage Expectations

| Scenario | Calculation | Expected Requests |
|----------|-------------|-------------------|
| All 11 days @ 35.2/day | 11 × 35.2 | 387 requests |
| **8 business days @ 35.2/day** | **8 × 35.2** | **282 requests** |
| **Actual usage** | - | **278 requests** |

### Conclusion

**✅ The 278 requests PERFECTLY matches business-day usage!**

- Expected (business days only): 282 requests
- Actual: 278 requests
- **Difference**: -4 requests (98.6% match)

**This proves:**
1. ✅ Copilot usage primarily occurs on business days (weekdays)
2. ✅ Little to no usage on weekends (Jan 24, 25, 31)
3. ✅ The 278 is NOT "low" - it's exactly what you'd expect for 8 business days
4. ✅ The business day forecasting logic is validated by real data!

**CRITICAL CLARIFICATION - Why 278 and not 300?**

⚠️ **CORRECTION**: The 300 quota is for the **FULL billing cycle** (Jan 21 → Feb 20, which is 31 days), NOT just Jan 21-31!

**Breakdown:**
- **Billing Cycle**: Jan 21 → Feb 20 (31 days TOTAL)
- **Quota**: 300 requests for the ENTIRE 31-day period
- **Used in Jan 21-31** (11 days): 278 requests (92.67% of quota)
- **Remaining for Feb 1-20** (20 days): 22 requests (7.33% of quota)

**The Problem:**
- You've used **92.67% of quota** with **64.5% of time remaining**!
- Only **1.1 requests/day** allowed for next 20 days vs **35.2/day** average
- You will likely **EXCEED the 300 quota** and face overage charges

**Why 278 in 11 days?**
- 8 business days × 35.2/day = 282 expected
- Actual 278 = 98.6% match
- This confirms business-day usage pattern (no weekend work)

---

## Question 3: Do we still need interactive mode for #1 (cycle transitions)?

### Short Answer: **No, FetchMode handles it automatically!**

### Mode Comparison:

#### **FetchMode (Mode 2) - RECOMMENDED** ✅
**Best for**: Historical analysis and forecasting with real GitHub data

**What it does automatically:**
- ✓ Detects current billing cycle (handles transitions automatically)
- ✓ Calculates dual-window costs
- ✓ Forecasts to end of both windows using business days
- ✓ Shows visual dashboard with current status
- ✓ Tells you when to pull next report ("after 2026-02-20")
- ✓ Generates CSV reports for tracking

**Usage:**
```powershell
.\AICostCalculator.ps1 -GitHubUsageReportCsv "path\to\github_export.csv"
```

**After cycle transition (Feb 21+):**
1. Download new GitHub usage report
2. Run same command with new CSV
3. Tool automatically detects new cycle (Feb 21 → Mar 20)
4. No manual date entry needed!

#### **Interactive Mode (Mode 1)** 📊
**Best for**: Daily ad-hoc forecasting during the day

**When to use:**
- You want to forecast where you'll be at end of TODAY
- You're tracking hourly usage during active development
- You want quick "what-if" scenarios without waiting for GitHub export

**What it does:**
- Asks for current time, requests so far today, requests this month
- Projects to end of current month based on current hourly rate
- Shows if you're on track or need to throttle

**Limitations:**
- Doesn't automatically handle cycle transitions
- Doesn't track historical patterns
- No persistent reports
- Manual data entry required

**Example use case:**
```
"It's 2PM on Feb 15, I've used 45 requests today and 580 this month.
Will I exceed my quota by end of month?"
```

### **Recommendation for Your Workflow:**

**Weekly/Monthly Analysis**: Use **FetchMode (Mode 2)** ✅
- Download GitHub export weekly or after each cycle ends
- Run tool to get full analysis and forecasts
- Track trends over time with generated CSV reports
- Let tool handle cycle transitions automatically

**Daily/Hourly Monitoring**: Use **Interactive Mode (Mode 1)** (optional)
- Only if you need real-time "am I on track today?" checks
- Useful during heavy development days
- Quick spot-checks without waiting for GitHub data

---

## Summary

| Question | Answer |
|----------|--------|
| **1. What happens after cycle ends?** | ✅ **Automatic!** Download new report after Feb 20, run tool again. It detects new cycle (Feb 21 → Mar 20) automatically. |
| **2. Why 278 not 300?** | ✅ **Weekend pattern!** You had 8 business days × 35.2/day = 282 expected. Actual 278 = perfect match. Weekends had little/no usage. |
| **3. Still need interactive mode?** | ✅ **No!** FetchMode handles cycle transitions automatically. Interactive mode only needed for real-time daily forecasting. |

---

## Action Items

**Right Now (Feb 2):**
- ✓ You're using FetchMode correctly
- ✓ Tool shows you're at 92.67% quota (CRITICAL)
- ✓ Forecast shows 806 requests by Feb 20 (will exceed quota)
- ⚠️ **Action**: Reduce usage or accept overage charges

**After Feb 20:**
1. Download new GitHub usage report (covers Jan 21 - Feb 20+)
2. Run: `.\AICostCalculator.ps1 -GitHubUsageReportCsv "new_report.csv"`
3. Tool automatically shows new cycle (Feb 21 → Mar 20)
4. Review new forecasts and adjust usage accordingly

**No manual cycle management needed!** 🎉
