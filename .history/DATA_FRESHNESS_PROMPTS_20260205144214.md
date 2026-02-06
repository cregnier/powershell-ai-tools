# Data Freshness Prompts - Feature Documentation

## Overview
The script now **automatically detects when you need to fetch a new GitHub usage report** and prompts you with clear, actionable instructions.

## When Prompts Appear

### 1. **Billing Cycle Has Ended** 🔄
**Trigger**: Current date is past the billing cycle end (20th) AND your data doesn't include the new cycle

**Dashboard Shows**:
```
📋 NEXT ACTIONS:
   • 🔄 Billing cycle ENDED 3 day(s) ago - FETCH NEW REPORT NOW!
   • 📥 New cycle started on 2026-02-21 - update needed
```

**Why It Matters**: 
- New billing cycle quota needs tracking
- Previous cycle's final costs should be calculated
- Forecasting for new cycle requires current data

---

### 2. **Calendar Month Has Changed** 📅
**Trigger**: Current month/year differs from the last date in your CSV

**Example**: Today is March 5, but data only goes through February 28

**Prompt Shows**:
```
╔═══════════════════════════════════════════════════════════════════════╗
║                      ⏰ TIME TO FETCH NEW DATA ⏰                     ║
╚═══════════════════════════════════════════════════════════════════════╝

Your analysis may be OUTDATED:
  • Currently in March 2026 but data only through February 2026
```

**Why It Matters**:
- Calendar month overages are calculated monthly
- Need current month data for accurate overage forecasting
- Pattern analysis should include latest month

---

### 3. **Data Is Stale (>2 Days Old)** ⏰
**Trigger**: Last data point is more than 2 days old

**Example**: Today is Feb 8, but data ends on Feb 5

**Prompt Shows**:
```
Your analysis may be OUTDATED:
  • Data is 3 days old (last: 2026-02-05)
```

**Why It Matters**:
- Quota tracking becomes inaccurate quickly
- Daily forecasts drift from reality
- Real-time guidance loses value

---

### 4. **Cycle Ending Soon** 🔔
**Trigger**: 5 or fewer days until billing cycle ends

**Dashboard Shows**:
```
📋 NEXT ACTIONS:
   • 📅 Billing cycle ends soon (3 days) - prepare for next period
   • 📥 Plan to pull next usage report after: 2026-02-20
```

**Why It Matters**:
- Reminds you to prepare for cycle transition
- Plan ahead for the next cycle's data refresh
- Allows final quota management decisions

---

## What The Prompts Tell You

### Full "Time to Fetch" Prompt
```
╔═══════════════════════════════════════════════════════════════════════╗
║                      ⏰ TIME TO FETCH NEW DATA ⏰                     ║
╚═══════════════════════════════════════════════════════════════════════╝

Your analysis may be OUTDATED:
  • Billing cycle ended on 2026-02-20 - NEW CYCLE data needed
  • Currently in March 2026 but data only through February 2026
  • Data is 5 days old (last: 2026-02-28)

📥 FETCH A NEW GITHUB USAGE REPORT:
   1. Go to: https://github.com/settings/copilot
   2. Click 'Usage' → 'Export CSV'
   3. Select date range covering through TODAY
   4. Re-run: .\AICostCalculator.ps1 -FetchMode -GitHubUsageReportCsv 'new_report.csv'

💡 Fetching fresh data will:
   ✓ Include the latest billing cycle (if ended)
   ✓ Calculate current month's overage charges
   ✓ Update forecasts with recent usage patterns
   ✓ Provide accurate quota tracking for active cycle

═══════════════════════════════════════════════════════════════════════
```

### When Data Is Current
```
✓ Data is current (last updated: 2026-02-05)
```

---

## How It Works

### Detection Logic
```powershell
# 1. Find most recent data point
$mostRecentDate = [datetime]::ParseExact($mostRecentDataDate, 'yyyy-MM-dd', $null)

# 2. Calculate how old the data is
$daysSinceLastData = ([datetime]::Today - $mostRecentDate).Days

# 3. Check multiple conditions
if ([datetime]::Today -gt $cycleEnd -and $mostRecentDate -le $cycleEnd) {
    # Billing cycle has ended but data doesn't include new cycle
}

if ([datetime]::Today.Month -ne $mostRecentDate.Month) {
    # We're in a new calendar month
}

if ($daysSinceLastData -gt 2) {
    # Data is stale
}
```

### Prompt Assembly
- Collects ALL applicable reasons (can show multiple)
- Provides specific dates and timeframes
- Shows actionable step-by-step instructions
- Explains benefits of updating

---

## Usage Examples

### Example 1: Run Script After Cycle Ends (Feb 21+)
**Scenario**: Today is Feb 23, data ends Feb 20

**Dashboard Shows**:
```
📋 NEXT ACTIONS:
   • 🔄 Billing cycle ENDED 3 day(s) ago - FETCH NEW REPORT NOW!
   • 📥 New cycle started on 2026-02-21 - update needed
```

**Then at bottom**:
```
╔═══════════════════════════════════════════════════════════════════════╗
║                      ⏰ TIME TO FETCH NEW DATA ⏰                     ║
╚═══════════════════════════════════════════════════════════════════════╝

Your analysis may be OUTDATED:
  • Billing cycle ended on 2026-02-20 - NEW CYCLE data needed
  • Data is 3 days old (last: 2026-02-20)

[...instructions to fetch new report...]
```

**Action**: Export new CSV covering Feb 21-present to track new cycle

---

### Example 2: Run Script Mid-Cycle with Fresh Data (Feb 5)
**Scenario**: Today is Feb 5, data updated through Feb 5

**Shows**:
```
✓ Data is current (last updated: 2026-02-05)
```

**Action**: None needed - analysis is accurate

---

### Example 3: Run Script in New Month (March 2)
**Scenario**: Today is March 2, data ends Feb 28

**Shows**:
```
Your analysis may be OUTDATED:
  • Currently in March 2026 but data only through February 2026
  • Data is 2 days old (last: 2026-02-28)

[...instructions to fetch new report...]
```

**Action**: Export new CSV to include March data for current month overage tracking

---

### Example 4: Run Script 4 Days Before Cycle Ends (Feb 16)
**Scenario**: Today is Feb 16, data updated through Feb 16, cycle ends Feb 20

**Dashboard Shows**:
```
📋 NEXT ACTIONS:
   • 📅 Billing cycle ends soon (4 days) - prepare for next period
   • 📥 Plan to pull next usage report after: 2026-02-20
```

**Then at bottom**:
```
✓ Data is current (last updated: 2026-02-16)
```

**Action**: Note to fetch new data after Feb 20, but current data is fine for now

---

## Benefits

### ✅ Automatic Detection
- No manual tracking of when to update
- Smart logic considers multiple factors
- Clear distinction between "urgent" and "reminder"

### ✅ Actionable Guidance
- Step-by-step instructions to GitHub settings
- Exact command to re-run with new CSV
- Explains WHY updating matters

### ✅ Multi-Condition Awareness
- Billing cycle transitions
- Calendar month boundaries  
- General data staleness
- Upcoming cycle endings

### ✅ Context-Specific
- Shows only applicable reasons
- Different urgency levels (RED for ended cycle vs CYAN for upcoming)
- Adapts messaging based on situation

---

## Technical Details

### Where Prompts Appear

**1. Dashboard (Show-DualWindowDashboard)**
- Lines 627-643 in AICostCalculator.ps1
- Checks if cycle has ended
- Provides dashboard-level action items

**2. FetchMode Summary (End of Analysis)**
- Lines 1628-1677 in AICostCalculator.ps1
- Comprehensive data freshness check
- Full prompt with all reasons and instructions

### Configuration
- **Staleness threshold**: 2 days (hardcoded)
- **Cycle warning**: 5 days before end (configurable via $daysRemaining check)
- **Month check**: Any month/year mismatch

### Override Options
Currently none - prompts are informational only and don't block script execution.

**Possible enhancement**: Add `-SkipFreshnessCheck` parameter to suppress prompts if desired.

---

## Examples in Practice

### Fresh Data (No Prompt)
```powershell
PS> .\AICostCalculator.ps1 -FetchMode -DailyUsageCsv "current_data.csv"

[...normal output...]

✓ Data is current (last updated: 2026-02-05)

Open the generated CSV files in Excel for detailed analysis.
```

### Stale Data (Shows Prompt)
```powershell
PS> .\AICostCalculator.ps1 -FetchMode -DailyUsageCsv "old_data.csv"

[...normal output...]

╔═══════════════════════════════════════════════════════════════════════╗
║                      ⏰ TIME TO FETCH NEW DATA ⏰                     ║
╚═══════════════════════════════════════════════════════════════════════╝

Your analysis may be OUTDATED:
  • Data is 7 days old (last: 2026-01-29)
  • Currently in February 2026 but data only through January 2026

📥 FETCH A NEW GITHUB USAGE REPORT:
   1. Go to: https://github.com/settings/copilot
   2. Click 'Usage' → 'Export CSV'
   3. Select date range covering through TODAY
   4. Re-run: .\AICostCalculator.ps1 -FetchMode -GitHubUsageReportCsv 'new_report.csv'

💡 Fetching fresh data will:
   ✓ Include the latest billing cycle (if ended)
   ✓ Calculate current month's overage charges
   ✓ Update forecasts with recent usage patterns
   ✓ Provide accurate quota tracking for active cycle

═══════════════════════════════════════════════════════════════════════

Open the generated CSV files in Excel for detailed analysis.
```

---

## Summary

This feature ensures you're **always aware when your analysis is out of date** and need to fetch fresh GitHub usage data. It:

- ✅ **Detects** billing cycle transitions, month boundaries, and stale data
- ✅ **Alerts** you prominently with visual boxes and emojis
- ✅ **Guides** you step-by-step to fetch new data
- ✅ **Explains** why updating matters for accurate analysis
- ✅ **Adapts** messaging based on urgency (ended cycle vs upcoming)

**No more guessing when to update** - the script tells you! 🎯
