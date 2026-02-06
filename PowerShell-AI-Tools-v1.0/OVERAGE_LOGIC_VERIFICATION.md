# OVERAGE LOGIC VERIFICATION - Is It Correct?

## Critical Question
**"When do overages really start kicking in given the different time windows?"**

## The Logic (Currently Implemented)

### Window 1: Billing Cycle (21st → 20th)
**Purpose**: Tracks usage against your **300 included requests**
**Code** (line 1125-1133):
```powershell
$cycleTotalRequests = ($cycleRows | Measure-Object -Property Requests -Sum).Sum
$cyclePercentUsed = ($cycleTotalRequests / $BasePlanRequests) * 100
$cycleRemaining = [Math]::Max(0, $BasePlanRequests - $cycleTotalRequests)
$cycleAlertLevel = if ($cyclePercentUsed >= 100) { "OVER" }
                   elseif ($cyclePercentUsed >= 90) { "CRITICAL" }
                   elseif ($cyclePercentUsed >= 70) { "WARNING" }
                   else { "OK" }
```

**What this does:**
- Tracks if you're staying within 300 included requests
- Shows alerts (WARNING/CRITICAL/OVER)
- **DOES NOT** directly calculate charges
- Just monitoring/quota tracking

### Window 2: Calendar Month Overages
**Purpose**: Calculates **actual overage charges**
**Code** (line 1139-1152):
```powershell
$monthlyOverages = $DailyRows | Group-Object { 
    ([datetime]::ParseExact($_.Date, 'yyyy-MM-dd', $null)).ToString('yyyy-MM') 
} | ForEach-Object {
    $monthKey = $_.Name
    $monthTotal = ($_.Group | Measure-Object -Property Requests -Sum).Sum
    
    $overage = [Math]::Max(0, $monthTotal - $BasePlanRequests)
    $overageCost = $overage * $OveragePricePerRequest
    
    [PSCustomObject]@{
        Month = $monthKey
        TotalRequests = $monthTotal
        Overage = $overage
        Cost = $overageCost
    }
}
```

**What this does:**
- Groups ALL requests by calendar month (yyyy-MM)
- For EACH month: overage = MAX(0, monthTotal - 300)
- Calculates cost: overage × $0.04

## ✅ THE LOGIC IS CORRECT!

### How Overages "Kick In"

**Scenario: Your January 2026 Data**

| Period | Requests | Overage Calculation | Charge |
|--------|----------|---------------------|--------|
| **Billing Cycle** (Jan 21 → Feb 20) | 278 (so far) | N/A - just quota tracking | $0 (part of $10 base) |
| **January Calendar Month** (Jan 1-31) | 704.63 | MAX(0, 704.63 - 300) = 404.63 | 404.63 × $0.04 = **$16.19** |
| **February Calendar Month** (Feb 1-28) | 0 (so far) | MAX(0, 0 - 300) = 0 | $0 |

### Key Points

1. **Billing Cycle Quota (300) ≠ Overage Limit**
   - The 300 from billing cycle is your "included" amount
   - You already paid $10/month for this
   - Going over 300 in the cycle triggers ALERTS but not direct charges

2. **Calendar Month Overage = Actual Charges**
   - **ANY** calendar month where total > 300 triggers charges
   - Formula: (monthTotal - 300) × $0.04
   - Each month calculated independently

3. **Requests Count in BOTH Windows**
   - Jan 21-31 requests (278): Count toward billing cycle quota AND January overage
   - Jan 1-20 requests (426.63): Do NOT count toward billing cycle, but DO count toward January overage

## Example: Understanding the Overlap

```
January 2026:
├─ Jan 1-20:   426.63 requests
│   └─ Counts: Calendar month overage only
│
├─ Jan 21-31:  278 requests
    └─ Counts: BOTH billing cycle quota AND calendar month overage

Total January: 426.63 + 278 = 704.63
Overage charge: (704.63 - 300) × $0.04 = $16.19 ✓ CORRECT
```

```
Billing Cycle (Jan 21 → Feb 20):
├─ Jan 21-31:  278 requests
├─ Feb 1-20:   ??? requests (future)
└─ Total:      278 + ??? 
    └─ Quota: 300 included (if exceeded, triggers ALERT)
    └─ But Feb requests will count toward FEBRUARY overage charges, not January
```

## When Do Overages "Kick In"?

**Answer**: Overages kick in **at the end of each calendar month** if that month's total > 300.

### Timeline of Charges:

| Date | Event | Charge Calculation |
|------|-------|-------------------|
| Jan 31, 2026 | End of January | January total = 704.63 → Overage = 404.63 × $0.04 = $16.19 |
| Feb 20, 2026 | End of billing cycle | Quota tracking only, no new charge (already counted in Jan/Feb overages) |
| Feb 28, 2026 | End of February | February total = ??? → If > 300, overage = (total - 300) × $0.04 |

## Critical Insight: Quota vs Overage

**The 300 quota serves TWO purposes:**

1. **Billing Cycle (Jan 21 → Feb 20)**: 
   - Monitoring/pacing tool
   - Shows if you're on track
   - Alert levels (WARNING/CRITICAL/OVER)
   - **No direct charge** (you already paid $10)

2. **Calendar Month Threshold**:
   - Any month > 300 triggers overage charges
   - Calculated per month
   - **Direct charges** at $0.04/request over 300

## Your Current Situation (Feb 2, 2026)

### Billing Cycle Window:
- Jan 21 → Feb 20 (31 days total)
- Used: 278 requests (Jan 21-31 = 11 days)
- Remaining: 22 requests (Feb 1-20 = 20 days)
- Status: 92.67% quota used - **CRITICAL ALERT**
- Charge: $0 (part of base plan)

### Calendar Month Window:
- **January** (Jan 1-31): 704.63 total → **$16.19 overage charge** ✓
- **February** (Feb 1-28): 0 total (so far) → $0 overage (yet)
- **Forecast**: If you use 35.2/day for remaining 26 days = ~916 total → **$24.64 overage**

### Total Bill:
- Base: $10.00/month
- January overage: $16.19
- February overage (projected): $24.64
- **Total: $50.83** (if projection holds)

## ✅ CONCLUSION: Logic is CORRECT

The current implementation properly handles both windows:

1. ✅ **Billing cycle quota** correctly tracks 300 included requests across Jan 21 → Feb 20
2. ✅ **Calendar month overages** correctly calculate charges for ANY month > 300
3. ✅ **Requests counted properly** in both windows where applicable
4. ✅ **Costs calculated correctly**: $10 base + monthly overages

**No changes needed to the overage logic!**
