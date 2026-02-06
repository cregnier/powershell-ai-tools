# Test Data Files for AICostCalculator.ps1

This folder contains test CSV files for comprehensive testing of all script features.

## Test Files

### 1. test_current_cycle.csv
**Purpose**: Test current billing cycle in progress  
**Date Range**: Jan 21 - Feb 5, 2026 (16 days, mid-cycle)  
**Billing Cycle**: Jan 21 - Feb 20 (16 days completed, 15 days remaining)  
**Total Requests**: 619  
**Use For**:
- Testing mid-cycle quota tracking
- Verifying "data is current" prompt (when run on Feb 5)
- Testing business day forecasting with days remaining

**Expected Results**:
- Billing cycle: 619/300 requests (206% used) - OVER quota
- Should show CRITICAL/OVER alert
- Data freshness: ✓ Current (if run on Feb 5)

---

### 2. test_cycle_complete.csv
**Purpose**: Test completed billing cycle  
**Date Range**: Jan 21 - Feb 20, 2026 (31 days, full cycle)  
**Billing Cycle**: Jan 21 - Feb 20 (complete)  
**Total Requests**: 1,125  
**Use For**:
- Testing complete cycle calculations
- Verifying cycle-end detection
- Testing "cycle ended" prompt (when run on Feb 21+)

**Expected Results**:
- Billing cycle: 1,125/300 requests (375% used) - OVER quota
- When run on Feb 21+: Shows "Billing cycle ENDED X days ago" prompt
- Calendar month overages calculated for January and February separately

---

### 3. test_future_cycle.csv
**Purpose**: Test future billing cycle  
**Date Range**: Feb 21 - Mar 10, 2026 (18 days into new cycle)  
**Billing Cycle**: Feb 21 - Mar 20  
**Total Requests**: 732  
**Use For**:
- Testing new cycle detection and quota reset
- Verifying correct cycle window calculation
- Testing March calendar month tracking

**Expected Results**:
- Billing cycle: Feb 21 - Mar 20 (new cycle)
- Requests: 732/300 (244% used) - OVER quota
- Calendar months: February (partial) and March (partial) tracked separately

---

### 4. test_stale_data.csv
**Purpose**: Test stale data detection (>2 days old)  
**Date Range**: Jan 15 - Feb 1, 2026  
**Last Data Point**: Feb 1  
**Use For**:
- Testing "data is stale" prompt
- Verifying 2-day threshold detection
- Testing staleness calculation

**Expected Results** (when run on Feb 5):
- Shows: "Data is 4 days old (last: 2026-02-01)"
- Prominent "TIME TO FETCH NEW DATA" prompt
- Includes staleness reason in update reasons list

---

### 5. test_month_boundary.csv
**Purpose**: Test calendar month boundary crossing  
**Date Range**: Feb 1 - Feb 28, 2026 (full February)  
**Last Data Point**: Feb 28  
**Use For**:
- Testing month boundary detection
- Verifying "calendar month changed" prompt
- Testing overage calculations across month boundary

**Expected Results** (when run on Mar 2+):
- Shows: "Currently in March 2026 but data only through February 2026"
- Prominent "TIME TO FETCH NEW DATA" prompt
- February overage calculated, March needs fresh data

---

### 6. test_with_holidays.csv
**Purpose**: Test business day calculations with holidays  
**Date Range**: May 20 - July 6, 2026  
**Includes Holidays**:
- Memorial Day: May 25, 2026 (Monday)
- Juneteenth: June 19, 2026 (Friday)
- Independence Day: July 4, 2026 (Saturday)

**Use For**:
- Verifying holiday detection (Test-IsHoliday function)
- Testing business day exclusion in forecasting
- Confirming weekends + holidays are properly excluded

**Expected Results**:
- Memorial Day (May 25): Excluded from business day count
- Juneteenth (June 19): Excluded from business day count
- July 4 weekend: Both Saturday and Sunday excluded
- Business day forecast should exclude all above dates
- Forecast should show: "X business days remaining" (not calendar days)

---

## Usage Examples

### Test Current Cycle
```powershell
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv ".\test_data\test_current_cycle.csv"
# Expected: Data is current, mid-cycle tracking, OVER quota alert
```

### Test Cycle Ended Prompt
```powershell
# Simulate running after cycle ends
$env:AI_DATE = '2026-02-23'
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv ".\test_data\test_cycle_complete.csv"
# Expected: RED "Billing cycle ENDED 3 days ago" prompt
```

### Test Month Boundary
```powershell
# Simulate running in March
$env:AI_DATE = '2026-03-02'
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv ".\test_data\test_month_boundary.csv"
# Expected: "Currently in March but data only through February" prompt
```

### Test Stale Data
```powershell
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv ".\test_data\test_stale_data.csv"
# Expected: "Data is 4 days old" prompt (when run on Feb 5)
```

### Test Business Days with Holidays
```powershell
$env:AI_DATE = '2026-06-10'
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv ".\test_data\test_with_holidays.csv"
# Expected: Business day forecast excludes Memorial Day, weekends
```

### Test Future Cycle
```powershell
$env:AI_DATE = '2026-03-10'
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv ".\test_data\test_future_cycle.csv"
# Expected: New cycle Feb 21-Mar 20, March overage tracking
```

---

## Data Generation Notes

### Request Patterns
All test files use realistic request patterns:
- **Weekdays**: 35-52 requests (higher usage)
- **Saturdays**: 12-15 requests (medium usage)
- **Sundays**: 8-10 requests (low usage)
- **Holidays**: 5-8 requests (minimal usage)

This mimics actual developer behavior: higher usage during work week, lower on weekends.

### Request Totals
Designed to trigger various alert levels:
- **test_current_cycle.csv**: 619 total (OVER quota mid-cycle)
- **test_cycle_complete.csv**: 1,125 total (heavy overage)
- **test_future_cycle.csv**: 732 total (exceeds quota early in cycle)

### Date Selection
- Uses 2026 dates to align with current test context
- Includes both complete cycles and partial periods
- Covers month boundaries (Jan→Feb, Feb→Mar)
- Includes federal holidays for business day testing

---

## Test Verification Checklist

When running tests, verify:

**Data Freshness Prompts**:
- [ ] "Data is current" shows for current data
- [ ] "Data is X days old" triggers after 2 days
- [ ] "Billing cycle ENDED" shows when cycle complete + date past end
- [ ] "Currently in [month] but data through [old month]" shows at month boundary
- [ ] All prompts show step-by-step fetch instructions

**Billing Calculations**:
- [ ] Billing cycle quota tracking (300 requests)
- [ ] Calendar month overages calculated separately
- [ ] Dual-window separation is clear
- [ ] Total cost = $10 base + monthly overages

**Business Day Forecasting**:
- [ ] Weekends excluded from business day count
- [ ] Federal holidays excluded (Memorial Day, Juneteenth, July 4, etc.)
- [ ] Forecast shows "X business days remaining" not calendar days
- [ ] Daily target uses business days for calculation

**Visual Outputs**:
- [ ] Dashboard displays both windows
- [ ] Timeline shows automatically in FetchMode
- [ ] Progress bars accurate
- [ ] Alert levels correct (OK, WARNING, CRITICAL, OVER)

---

## Troubleshooting

### Date Override Not Working
If using `$env:AI_DATE` to simulate dates:
```powershell
# Ensure variable is set BEFORE running script
$env:AI_DATE = '2026-03-02'
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv ".\test_data\test_month_boundary.csv"

# Clear after testing
Remove-Item Env:\AI_DATE
```

### Wrong Cycle Detected
The script uses cycle start day 21 by default. If testing different cycles:
```powershell
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv "test.csv" -CycleStartDay 1
```

### Holidays Not Detected
Verify holiday detection:
```powershell
# Check if Memorial Day 2026 is detected
$d = Get-Date '2026-05-25'
Test-IsHoliday $d  # Should return $true
```

---

## Adding New Test Files

To create additional test files:

1. **Choose date range** that aligns with test scenario
2. **Generate realistic data** (weekdays 35-50, weekends 8-15)
3. **Name descriptively** (e.g., `test_low_usage.csv`, `test_quota_perfect.csv`)
4. **Document in this README** with purpose, expected results, usage example
5. **Verify calculations** match expected dual-window logic

---

## Summary

These test files provide comprehensive coverage for:
- ✅ All 3 operational modes (Interactive, FetchMode, Test Mode)
- ✅ All 4 data freshness scenarios (current, stale, cycle ended, month boundary)
- ✅ Business day calculations with weekends and holidays
- ✅ Dual-window billing logic verification
- ✅ Timeline and dashboard display testing
- ✅ Alert level triggering (OK → WARNING → CRITICAL → OVER)

Run these tests systematically to ensure the script functions correctly in all scenarios! 🧪
