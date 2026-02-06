# AICostCalculator.ps1 - Enhancement Summary

## Overview

AICostCalculator.ps1 has been enhanced to support **two distinct operational modes** as requested:

1. **Fetch Mode** - Comprehensive billing analysis with Excel-ready reports
2. **Daily-Use Mode** - Quick interactive planning (original functionality preserved)

---

## What Changed

### 1. Enhanced Script Capabilities

#### New Fetch Mode Features
- **Automated data import** from GitHub or local CSV files
- **Pattern analysis** to detect steady/moderate/bursty usage patterns
- **Trend detection** comparing first-half vs second-half of dataset
- **Spike day identification** using statistical analysis (2σ threshold)
- **Timing recommendations** for workload scheduling
- **Cost optimization advice** including plan comparison
- **Weekly pattern analysis** to find best days for batch jobs
- **Comprehensive reporting** in Excel-ready CSV format

#### New Functions Added
1. `Analyze-UsagePatterns` - Statistical analysis of usage data
   - Pattern classification (Steady/Moderate/Bursty)
   - Trend detection (Increasing/Stable/Decreasing)
   - Spike day identification
   - High-risk day detection
   - Coefficient of variation calculation

2. `Get-TimingRecommendations` - Generates actionable advice
   - Pattern-specific recommendations
   - Trend alerts
   - Pacing warnings
   - Day-of-week optimization
   - Cost optimization suggestions

3. `Generate-ComprehensiveSummary` - Creates executive summary
   - Report metadata section
   - Usage metrics summary
   - Cost analysis with plan comparison
   - Pattern analysis results
   - Comprehensive recommendations list

#### Enhanced Existing Functions
- `Generate-DailyReport` - Now includes better alert messages and pacing recommendations
- Fetch Mode block - Complete rewrite with 6-step workflow and progress reporting

### 2. New Parameters

```powershell
-ComprehensiveReportPath    # Path for comprehensive summary CSV
-PatternAnalysisWindowDays  # Days to analyze (default: 7)
```

### 3. User Experience Improvements

#### Fetch Mode Output
- Professional Unicode box-drawing characters
- Color-coded progress indicators (✓, ✗, ⚠)
- Step-by-step progress (1/6, 2/6, etc.)
- Summary dashboard at completion
- Immediate key findings display
- Clear file paths for generated reports

#### Daily-Use Mode (Unchanged)
- All existing interactive functionality preserved
- Same prompts and calculations
- Same output format
- Backward compatible

---

## New Files Created

### Documentation
1. **USAGE_GUIDE.md** - Comprehensive 400+ line guide covering:
   - Both modes with detailed examples
   - Parameter reference
   - CSV format specifications
   - Troubleshooting guide
   - Excel analysis tips
   - Automation examples

2. **QUICK_REFERENCE.md** - One-page cheat sheet with:
   - Common commands
   - Alert levels table
   - Pattern types explanation
   - Cost calculation formula
   - Quick troubleshooting

3. **README.md** - Updated with:
   - Feature highlights
   - Quick start guide
   - Use case matrix
   - File structure

### Sample Data
4. **sample_daily_usage.csv** - 31 days of sample data demonstrating:
   - Bursty usage pattern
   - Weekend gaps (0 usage)
   - Spike days
   - Increasing trend
   - Total overage scenario

---

## Generated Reports

### 1. Daily Report (daily_report.csv)

**Columns:**
- `Date` - yyyy-MM-dd
- `Requests` - Daily request count
- `Cumulative` - Running total
- `PercentOfBase` - % of 300-request base plan
- `RecommendedRemainingPerDay` - Pacing guide
- `AlertLevel` - OK / WARNING / CRITICAL / OVER
- `AlertMessage` - Human-readable alert

**Excel Use:**
- Create time-series charts
- Apply conditional formatting to AlertLevel
- Identify trends and spikes
- Track cumulative progress

### 2. Comprehensive Report (comprehensive_report.csv)

**Sections:**
- `REPORT_INFO` - Generation time, cycle period
- `USAGE` - Total, average, peak, active days, percent consumed
- `COST` - Base, overage, total, plan comparison
- `PATTERNS` - Pattern type, trend, std deviation, spike days
- `RECOMMENDATIONS` - Numbered actionable recommendations

**Excel Use:**
- Filter by Section for focused analysis
- Extract RECOMMENDATIONS for action items
- Create executive summary slides
- Track month-over-month metrics

---

## Usage Examples

### Example 1: Weekly Billing Review (Fetch Mode)

```powershell
# Every Friday, generate reports for review
.\AICostCalculator.ps1 `
    -FetchMode `
    -DailyUsageCsv "\\shared\copilot\usage_january.csv" `
    -DailyReportPath "\\shared\reports\daily_$(Get-Date -Format 'yyyyMMdd').csv" `
    -ComprehensiveReportPath "\\shared\reports\summary_$(Get-Date -Format 'yyyyMMdd').csv"
```

**Output:**
```
[1/6] Fetching usage data...
  ✓ Using local CSV: \\shared\copilot\usage_january.csv
[2/6] Importing daily usage data...
  ✓ Loaded 31 days of usage data
  ✓ Date range: 2026-01-01 to 2026-01-31
[3/6] Analyzing billing cycle...
  ✓ Current cycle: 2026-01-21 to 2026-02-20
[4/6] Generating daily usage report with alerts...
  ✓ Daily report exported
  ⚠ Alert days detected: 5 days with warnings/overages
[5/6] Analyzing usage patterns and trends...
  ✓ Pattern: Bursty | Trend: Increasing
  ✓ Avg daily: 15.1 requests (StdDev: 12.8)
  ⚠ Spike days: 2026-01-15
[6/6] Generating recommendations...

Key Findings:
  Usage Summary:
    • Total Requests:     468.5
    • Base Plan:          300 requests
    • Overage:            168 requests
    • Total Cost:         $16.72

  Top Recommendations:
    1. USAGE PATTERN: Bursty/irregular usage detected
    2. TIMING: Schedule heavy AI workloads early in cycle
    3. TREND ALERT: Usage trending upward
```

### Example 2: Quick Daily Check (Daily-Use Mode)

```powershell
# Quick morning check
.\AICostCalculator.ps1
```

**Interaction:**
```
Start time (HH:mm): 09:00
Current time (HH:mm): [Enter]
Requests month-to-date: 145
Date: [Enter]
Base plan: [Enter]

Select input mode:
  1) Month-to-date only
> 1

====================================
Given date: 2026-02-02
Elapsed hrs: 2.50
Current hourly rate: 12.20 req/hr
Projected monthly: 244 requests

Recommendation: keep <= 10.50 req/hr

Allowed  : [████████████] 10.50 req/hr
Current  : [██████████████] 12.20 req/hr
```

### Example 3: Validate Billing Cycle

```powershell
# Check Dec 21, 2025 - Jan 20, 2026 cycle
.\AICostCalculator.ps1 `
    -FetchMode `
    -DailyUsageCsv './daily_dec21_jan20.csv' `
    -CycleStartDay 21 `
    -DailyReportPath './report_dec21cycle.csv'
```

---

## Technical Details

### Pattern Analysis Algorithm

**Pattern Classification:**
```
CV = StdDev / Mean

Steady:   CV < 0.3   (low variability)
Moderate: 0.3 ≤ CV < 0.7  (medium variability)
Bursty:   CV ≥ 0.7   (high variability)
```

**Spike Detection:**
```
Spike = Daily Requests > (Mean + 2 × StdDev)
```

**Trend Analysis:**
```
Compare: First-Half Average vs Second-Half Average
Increasing: Second > First × 1.2
Decreasing: Second < First × 0.8
Stable: Otherwise
```

### Cost Optimization Logic

**Plan Comparison:**
- Base Plan: $10/month, 300 requests, $0.04/request overage
- 1500 Plan: $39.99/month, 1500 requests, $0.04/request overage
- Recommendation: Switch to 1500-plan if overage > $30/month

---

## Backward Compatibility

✅ **All existing functionality preserved:**
- Interactive prompts unchanged
- Same calculation logic
- Same output format for daily-use mode
- Existing parameters still work
- Test-mode environment variables honored

✅ **No breaking changes:**
- Default behavior (no flags) = Daily-Use Mode
- `-FetchMode` must be explicitly enabled
- Existing scripts continue to work

---

## Testing Performed

### Test 1: Fetch Mode with Sample Data
```powershell
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv './sample_daily_usage.csv'
```
✅ **Result:** Successfully generated both reports  
✅ **Validation:** Detected Bursty pattern, Increasing trend, 1 spike day  
✅ **Cost:** $16.72 total ($10 base + $6.72 overage)

### Test 2: Daily-Use Mode (Interactive)
```powershell
.\AICostCalculator.ps1
```
✅ **Result:** Prompts work as before  
✅ **Validation:** Calculations match expected values  
✅ **Output:** Same format as previous version

### Test 3: Parameter Validation
✅ Missing CSV in FetchMode: Proper error message  
✅ Invalid CSV format: Graceful error handling  
✅ Missing parameters: Sensible defaults applied

---

## What to Do Next

### 1. Test with Your Data

Create your daily usage CSV:
```csv
Date,Requests
2026-01-21,15.2
2026-01-22,18.7
...
```

Run Fetch Mode:
```powershell
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv './my_usage.csv'
```

### 2. Review Generated Reports

Open in Excel:
- `daily_report.csv` - Look for spike days, alert patterns
- `comprehensive_report.csv` - Review recommendations

### 3. Set Up Weekly Automation

Schedule a weekly task to run Fetch Mode and email reports to team.

### 4. Continue Using Daily-Use Mode

For quick daily checks, just run:
```powershell
.\AICostCalculator.ps1
```

---

## Questions Answered

### Original Request:
> "I am looking for 2 modes or logic:
> 1) Fetch mode that get github/copilot billing data and populates an MS office spreadsheet"

✅ **Implemented:** Fetch Mode generates two Excel-ready CSV files with comprehensive analysis

> "with recommendations regarding timing, costs, workload usage patterns and other helpful advice"

✅ **Implemented:** 
- Timing recommendations (when to schedule heavy workloads)
- Cost analysis (overage costs, plan comparison)
- Pattern analysis (steady/moderate/bursty classification)
- Trend detection (increasing/stable/decreasing)
- Spike day identification
- Day-of-week optimization
- Pacing warnings

> "2) daily-use mode (the previous logic) to enter direct values"

✅ **Implemented:** Original interactive mode preserved exactly as-is

---

## Files Modified

- ✏️ `AICostCalculator.ps1` - Enhanced with Fetch Mode and analysis functions
- ✏️ `README.md` - Updated with new features and examples

## Files Created

- ➕ `USAGE_GUIDE.md` - Comprehensive 400+ line documentation
- ➕ `QUICK_REFERENCE.md` - One-page cheat sheet
- ➕ `sample_daily_usage.csv` - 31 days of sample data
- ➕ `CHANGES.md` - This file

---

## Support

📖 **Full documentation:** USAGE_GUIDE.md  
📋 **Quick reference:** QUICK_REFERENCE.md  
📊 **Sample data:** sample_daily_usage.csv  
📝 **Main README:** README.md
