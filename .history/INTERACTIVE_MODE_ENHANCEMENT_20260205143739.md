# Interactive Mode Enhancement Proposal

## Current State vs Enhanced State

### Current Interactive Mode
```powershell
.\AICostCalculator.ps1
# Prompts for:
# - Requests used this month so far
# - Requests used today so far  
# - Today's start time
# Output: Hourly rates, projections, recommendations
```

**Limitations:**
- No historical context - you must remember/calculate totals manually
- No pattern awareness - treats every day the same
- No business day intelligence - weekends counted equally
- No automatic quota tracking - must check GitHub manually

### Enhanced Interactive Mode (Proposed)
```powershell
.\AICostCalculator.ps1 -DailyUsageCsv "path/to/last_export.csv"
# Automatically calculates:
# - Your historical daily average (from CSV)
# - Business day vs weekend patterns  
# - Current billing cycle status
# - Remaining quota
# Then prompts for:
# - Today's current usage (just this number!)
# Output: Context-aware guidance
```

**Benefits:**
- ✅ **Historical context**: "You average 35.2 requests/business day"
- ✅ **Pattern awareness**: "Mondays you average 42, Fridays 28"
- ✅ **Business day intelligence**: "15 business days left (excludes weekends)"
- ✅ **Automatic quota tracking**: "22 requests remaining in cycle"
- ✅ **Smarter guidance**: "At current pace (12/day), you'll use 16 today - SLOW DOWN!"

## Implementation Plan

### 1. Add Historical Context Loading
```powershell
if ($DailyUsageCsv -and (Test-Path $DailyUsageCsv)) {
    Write-Host "Loading historical context from: $DailyUsageCsv" -ForegroundColor Cyan
    
    $historicalData = Import-Csv $DailyUsageCsv
    $cycle = Get-CycleWindow (Get-Date) $CycleStartDay
    
    # Calculate historical metrics
    $avgDaily = ($historicalData | Measure-Object -Property Requests -Average).Average
    $businessDayAvg = Calculate-BusinessDayAverage $historicalData
    $weekendAvg = Calculate-WeekendAverage $historicalData
    
    # Get current cycle status
    $cycleData = $historicalData | Where-Object { 
        ([datetime]$_.Date) -ge $cycle.Start -and 
        ([datetime]$_.Date) -le $cycle.End 
    }
    $usedInCycle = ($cycleData | Measure-Object -Property Requests -Sum).Sum
    $remainingQuota = 300 - $usedInCycle
    
    # Calculate remaining business days
    $businessDaysRemaining = Get-BusinessDaysInRange (Get-Date) $cycle.End
    
    # Display context
    Write-Host ""
    Write-Host "═══ HISTORICAL CONTEXT ═══" -ForegroundColor Yellow
    Write-Host "  Overall Avg:      $([math]::Round($avgDaily, 1)) requests/day" -ForegroundColor White
    Write-Host "  Business Day Avg: $([math]::Round($businessDayAvg, 1)) requests/day" -ForegroundColor White
    Write-Host "  Weekend Avg:      $([math]::Round($weekendAvg, 1)) requests/day" -ForegroundColor White
    Write-Host ""
    Write-Host "═══ CURRENT CYCLE STATUS ═══" -ForegroundColor Cyan
    Write-Host "  Cycle:            $($cycle.Start.ToString('MMM dd')) → $($cycle.End.ToString('MMM dd'))" -ForegroundColor White
    Write-Host "  Used So Far:      $usedInCycle / 300 ($([math]::Round($usedInCycle/300*100,1))%)" -ForegroundColor White
    Write-Host "  Remaining Quota:  $remainingQuota requests" -ForegroundColor Green
    Write-Host "  Business Days Left: $businessDaysRemaining days" -ForegroundColor Cyan
    Write-Host "  Target Per Day:   $([math]::Round($remainingQuota / $businessDaysRemaining, 1)) requests/business day" -ForegroundColor Yellow
    Write-Host ""
}
```

### 2. Enhanced Real-Time Guidance
```powershell
# After user enters today's usage
Write-Host ""
Write-Host "═══ TODAY'S ANALYSIS ═══" -ForegroundColor Cyan

$currentTime = Get-Date
$hoursElapsed = ToHours($currentTime - $startDt)
$currentHourlyRate = $requestsToday / $hoursElapsed

# Compare to historical patterns
$dayOfWeek = $currentTime.DayOfWeek
$historicalDayAvg = Get-HistoricalAverageForDay $historicalData $dayOfWeek
$expectedByNow = $historicalDayAvg * ($hoursElapsed / $workingHours)

Write-Host "  Current Usage:    $requestsToday requests" -ForegroundColor White
Write-Host "  Time Elapsed:     $([math]::Round($hoursElapsed, 1)) hours" -ForegroundColor White
Write-Host "  Hourly Rate:      $([math]::Round($currentHourlyRate, 1)) requests/hour" -ForegroundColor White
Write-Host ""
Write-Host "  Historical $dayOfWeek Avg: $([math]::Round($historicalDayAvg, 1)) requests/day" -ForegroundColor Gray
Write-Host "  Expected by now:  $([math]::Round($expectedByNow, 1)) requests" -ForegroundColor Gray

if ($requestsToday > $expectedByNow * 1.2) {
    Write-Host "  ⚠️  ALERT: 20% above typical $dayOfWeek pace!" -ForegroundColor Red
    $remainingHours = $workingHours - $hoursElapsed
    $projectedToday = $requestsToday + ($currentHourlyRate * $remainingHours)
    Write-Host "  Projected today:  $([math]::Round($projectedToday, 1)) requests" -ForegroundColor Yellow
    Write-Host "  Recommendation:   Slow down to $([math]::Round($targetPerDay / $workingHours, 1)) requests/hour" -ForegroundColor Red
} elseif ($requestsToday < $expectedByNow * 0.8) {
    Write-Host "  ✓ GOOD: 20% below typical $dayOfWeek pace" -ForegroundColor Green
    Write-Host "  Status:           You're pacing well today!" -ForegroundColor Green
} else {
    Write-Host "  ✓ ON TRACK: Within normal $dayOfWeek range" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "═══ QUOTA IMPACT ═══" -ForegroundColor Yellow

$projectedEndOfDay = $requestsToday + ($currentHourlyRate * ($workingHours - $hoursElapsed))
$quotaAfterToday = $remainingQuota - $projectedEndOfDay
$daysAfterToday = $businessDaysRemaining - 1

Write-Host "  Projected end-of-day:     $([math]::Round($projectedEndOfDay, 1)) requests" -ForegroundColor White
Write-Host "  Quota after today:        $([math]::Round($quotaAfterToday, 1)) requests" -ForegroundColor White
Write-Host "  Business days after today: $daysAfterToday days" -ForegroundColor White

if ($daysAfterToday -gt 0) {
    $newTargetPerDay = $quotaAfterToday / $daysAfterToday
    Write-Host "  New daily target:         $([math]::Round($newTargetPerDay, 1)) requests/day" -ForegroundColor Cyan
    
    if ($newTargetPerDay < 0) {
        Write-Host ""
        Write-Host "  ⚠️  CRITICAL: Will exceed quota even if you stop today!" -ForegroundColor Red
    } elseif ($newTargetPerDay < $businessDayAvg * 0.3) {
        Write-Host ""
        Write-Host "  ⚠️  WARNING: Tomorrow must be <30% of normal usage" -ForegroundColor Yellow
    }
}
```

### 3. Smart Recommendations
```powershell
Write-Host ""
Write-Host "═══ RECOMMENDATIONS ═══" -ForegroundColor Cyan

# Based on current pace vs historical
if ($currentHourlyRate > ($businessDayAvg / $workingHours) * 1.5) {
    Write-Host "  🛑 STOP: You're at 150% of normal hourly rate" -ForegroundColor Red
    Write-Host "     Pause Copilot usage for the rest of today" -ForegroundColor Red
} elseif ($quotaAfterToday < $daysAfterToday * ($businessDayAvg * 0.5)) {
    Write-Host "  ⚠️  REDUCE: Cut usage to 50% of normal for remainder of cycle" -ForegroundColor Yellow
    Write-Host "     Target <$([math]::Round($businessDayAvg * 0.5, 1)) requests/day going forward" -ForegroundColor Yellow
} elseif ($quotaAfterToday > $daysAfterToday * $businessDayAvg) {
    Write-Host "  ✓ GOOD: You have buffer to maintain normal usage" -ForegroundColor Green
    Write-Host "     Continue at current pace (~$([math]::Round($businessDayAvg, 1)) requests/day)" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  MONITOR: Stay close to $([math]::Round($newTargetPerDay, 1)) requests/day" -ForegroundColor Cyan
    Write-Host "     Check in daily to avoid exceeding quota" -ForegroundColor Cyan
}
```

## Usage Examples

### Example 1: Morning Check-In
```powershell
PS> .\AICostCalculator.ps1 -DailyUsageCsv ".\last_export.csv"

Loading historical context from: .\last_export.csv

═══ HISTORICAL CONTEXT ═══
  Overall Avg:      35.2 requests/day
  Business Day Avg: 41.8 requests/day
  Weekend Avg:      8.3 requests/day

═══ CURRENT CYCLE STATUS ═══
  Cycle:            Jan 21 → Feb 20
  Used So Far:      278 / 300 (92.7%)
  Remaining Quota:  22 requests
  Business Days Left: 15 days
  Target Per Day:   1.5 requests/business day

Enter requests month-to-date: [Auto-filled from CSV: 278]
Enter requests so far today: 3
Today's work start time (HH:mm): 09:00

═══ TODAY'S ANALYSIS ═══
  Current Usage:    3 requests
  Time Elapsed:     2.5 hours
  Hourly Rate:      1.2 requests/hour

  Historical Monday Avg: 42.5 requests/day
  Expected by now:  12.4 requests
  ✓ GOOD: 76% below typical Monday pace

═══ QUOTA IMPACT ═══
  Projected end-of-day:     10 requests
  Quota after today:        12 requests
  Business days after today: 14 days
  New daily target:         0.9 requests/day

  ⚠️  WARNING: Tomorrow must be <30% of normal usage

═══ RECOMMENDATIONS ═══
  ⚠️  REDUCE: Cut usage to 50% of normal for remainder of cycle
     Target <21 requests/day going forward
     Or plan for overage charges (~$13-20)
```

### Example 2: Afternoon Check-In (Pace Too High)
```powershell
PS> .\AICostCalculator.ps1 -DailyUsageCsv ".\last_export.csv"

[... context loading ...]

Enter requests so far today: 18
Today's work start time (HH:mm): 09:00

═══ TODAY'S ANALYSIS ═══
  Current Usage:    18 requests
  Time Elapsed:     5.0 hours
  Hourly Rate:      3.6 requests/hour

  Historical Wednesday Avg: 39.5 requests/day
  Expected by now:  24.7 requests
  ✓ ON TRACK: Within normal Wednesday range

  Projected today:  28.8 requests

═══ QUOTA IMPACT ═══
  Projected end-of-day:     28.8 requests
  Quota after today:        -6.8 requests  ← NEGATIVE!
  Business days after today: 14 days
  New daily target:         -0.5 requests/day  ← IMPOSSIBLE!

  ⚠️  CRITICAL: Will exceed quota even if you stop today!

═══ RECOMMENDATIONS ═══
  🛑 STOP: You've already exceeded today's target (1.5)
     PAUSE Copilot for rest of today
     Plan for overage: ~$0.50-1.00
```

## Benefits Summary

### For Daily Workflow
- ✅ **One number to input**: Just today's current usage
- ✅ **Instant context**: See how you compare to history
- ✅ **Smart alerts**: Get warnings BEFORE exceeding quota
- ✅ **Actionable guidance**: Clear "stop"/"slow down"/"you're good" messages

### For Quota Management
- ✅ **Proactive monitoring**: Catch overages before they happen
- ✅ **Pattern-aware**: Knows Mondays ≠ Fridays
- ✅ **Business day intelligence**: Excludes weekends from calculations
- ✅ **Realistic targets**: Adjusts recommendations based on actual patterns

### For Cost Control
- ✅ **Early warnings**: Know when to stop to avoid overages
- ✅ **Cost projections**: See potential overage costs in real-time
- ✅ **Historical comparison**: Understand if today is unusual
- ✅ **Buffer visibility**: Know when you have room vs when you're tight

## Implementation Effort

### Low Complexity (2-3 hours):
- Load historical CSV and calculate averages
- Display historical context at start
- Compare today's usage to historical patterns

### Medium Complexity (4-6 hours):
- Add business day pattern detection (weekday vs weekend)
- Implement day-of-week averages
- Add smart recommendations based on pace

### High Complexity (8-10 hours):
- Full pattern analysis (spike detection, trending)
- Hourly pace predictions based on time of day
- Integration with FetchMode for automatic CSV refresh

## Recommendation

**Start with Low Complexity** to validate the concept:
1. Load CSV and show historical averages
2. Compare today's usage to historical patterns
3. Provide simple "above/below/on-track" guidance

If valuable, **expand to Medium Complexity**:
1. Add day-of-week intelligence
2. Implement business day filtering
3. Provide specific hourly rate targets

**Only add High Complexity if needed**:
1. Most value comes from Low/Medium features
2. High Complexity adds polish but not essential functionality

## Conclusion

Enhanced Interactive Mode transforms a manual calculator into an **intelligent daily coach**:
- **Historical context**: Knows your patterns
- **Smart guidance**: Tells you exactly what to do
- **Proactive alerts**: Warns before problems occur
- **Business day aware**: Realistic targets excluding weekends

This makes Interactive Mode complementary to FetchMode:
- **FetchMode**: Weekly/monthly comprehensive analysis
- **Interactive Mode (Enhanced)**: Daily real-time guidance with historical intelligence

Worth implementing! 🎯
