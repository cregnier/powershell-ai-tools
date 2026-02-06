# AICostCalculator.ps1 - Usage Guide

## Overview

AICostCalculator.ps1 is a comprehensive PowerShell tool for managing GitHub Copilot costs with two distinct modes of operation:

1. **Fetch Mode** - Automated billing analysis with Excel-ready reports
2. **Daily-Use Mode** - Interactive daily planning and forecasting

---

## Mode 1: Fetch Mode (Comprehensive Billing Analysis)

### Purpose
Fetch Mode retrieves your GitHub/Copilot billing data and generates comprehensive Excel-ready reports including:
- Daily usage breakdown with alerts and pacing recommendations
- Pattern analysis (steady/bursty/spiky usage detection)
- Timing recommendations (when to schedule heavy workloads)
- Cost optimization advice (plan comparison, overage warnings)
- Comprehensive summary report for management review

### Usage

#### From GitHub Repository
```powershell
.\AICostCalculator.ps1 `
    -FetchMode `
    -GitHubOwner 'your-username' `
    -GitHubRepo 'your-repo' `
    -GitHubPath 'path/to/daily_usage.csv' `
    -PromptForToken `
    -DailyReportPath './reports/daily_report.csv' `
    -ComprehensiveReportPath './reports/comprehensive_report.csv' `
    -CycleStartDay 21
```

#### From Local CSV File
```powershell
.\AICostCalculator.ps1 `
    -FetchMode `
    -DailyUsageCsv './data/daily_usage.csv' `
    -DailyReportPath './reports/daily_report.csv' `
    -ComprehensiveReportPath './reports/comprehensive_report.csv' `
    -CycleStartDay 21
```

### Required CSV Format

Your daily usage CSV must have these columns:

| Date | Requests |
|------|----------|
| 2026-01-01 | 25.5 |
| 2026-01-02 | 18.2 |
| 2026-01-03 | 32.7 |

- **Date**: Format `yyyy-MM-dd`
- **Requests**: Decimal number of API requests

### Generated Reports

#### 1. Daily Report (`daily_report.csv`)
Contains per-day breakdown with:
- Date
- Requests (for that day)
- Cumulative (running total)
- PercentOfBase (% of 300-request base plan consumed)
- RecommendedRemainingPerDay (pacing guide for remaining days)
- AlertLevel (OK, WARNING, CRITICAL, OVER)
- AlertMessage

**Open in Excel** to:
- Create charts of daily usage trends
- Identify spike days
- Track cumulative progress vs budget
- See color-coded alerts

#### 2. Comprehensive Report (`comprehensive_report.csv`)
Contains high-level summary with sections:
- **REPORT_INFO**: Generation time, cycle period
- **USAGE**: Total requests, averages, peak usage, active days
- **COST**: Base plan cost, overage, total cost, plan comparison
- **PATTERNS**: Usage pattern classification, trend analysis, variability
- **RECOMMENDATIONS**: Actionable advice for cost optimization

**Open in Excel** to:
- Review executive summary
- Share with management
- Track month-over-month trends
- Identify cost-saving opportunities

### Pattern Analysis

Fetch Mode automatically detects:

- **Steady**: Low variability (CV < 0.3) - predictable usage
- **Moderate**: Medium variability (0.3 ≤ CV < 0.7) - some fluctuation
- **Bursty**: High variability (CV ≥ 0.7) - irregular spikes

### Timing Recommendations

Based on your usage patterns, the tool suggests:
- When to schedule heavy AI workloads (early in cycle preferred)
- Which days of the week have lowest usage (for batch jobs)
- When you're exceeding sustainable pacing
- Whether upgrading to higher-tier plan ($39.99/1500 requests) would save money

### Example Output

```
══════════════════════════════════════════════════════
  FETCH MODE: Comprehensive Billing Analysis
══════════════════════════════════════════════════════

[1/6] Fetching usage data...
  ✓ Fetched from GitHub: cregnier/powershell-ai-tools/daily_dec21_jan20.csv

[2/6] Importing daily usage data...
  ✓ Loaded 31 days of usage data
  ✓ Date range: 2025-12-21 to 2026-01-20

[3/6] Analyzing billing cycle...
  ✓ Current cycle: 2026-01-21 to 2026-02-20

[4/6] Generating daily usage report with alerts...
  ✓ Daily report exported: ./daily_report_dec21_jan20.csv
  ⚠ Alert days detected: 5 days with warnings/overages

[5/6] Analyzing usage patterns and trends...
  ✓ Pattern: Bursty | Trend: Increasing
  ✓ Avg daily: 12.5 requests (StdDev: 8.3)
  ⚠ Spike days: 2026-01-15, 2026-01-18

[6/6] Generating recommendations and comprehensive report...

══════════════════════════════════════════════════════
  FETCH MODE COMPLETE - Reports Generated
══════════════════════════════════════════════════════

Generated Reports:
  1. Daily Report:         ./daily_report_dec21_jan20.csv
  2. Comprehensive Report: ./comprehensive_report_dec21_jan20.csv

Key Findings:

  Usage Summary:
    • Total Requests:     387.5
    • Base Plan:          300 requests
    • Overage:            87.5 requests
    • Total Cost:         $13.50

  Usage Pattern:
    • Pattern:            Bursty
    • Trend:              Increasing
    • Avg Daily:          12.5 requests
    • Variability:        0.664 (CV)

  Top Recommendations:
    1. USAGE PATTERN: Bursty/irregular usage detected. Consider smoothing workload distribution across days.
    2. TREND ALERT: Usage is trending upward. Review workload and consider upgrading plan if trend continues.
    3. PACING WARNING: Current daily average (12.5) is 29% above sustainable target (9.7). Reduce usage or plan for overage costs.

Open the generated CSV files in Excel for detailed analysis.
```

---

## Mode 2: Daily-Use Mode (Interactive Planning)

### Purpose
Quick interactive mode for checking if you're on track today. Provides immediate hourly rate calculations and recommendations based on current time and usage.

### Usage

Simply run without `-FetchMode`:

```powershell
.\AICostCalculator.ps1
```

The script will prompt you for:
1. Start time (HH:mm) - when you started work today
2. Current time (HH:mm) - press Enter to use system time
3. Date (yyyy-MM-dd) - press Enter for today
4. Base plan requests - press Enter for 300
5. Requests month-to-date
6. Input mode selection:
   - Mode 1: Month-to-date only (simple)
   - Mode 2: Provide month-to-date at start of day
   - Mode 3: Provide today's current count (detailed)

### Example Interactive Session

```
Start time (HH:mm): 09:00
Current time (HH:mm): [Enter for system time]
Requests month-to-date so far: 145.5
Date (yyyy-MM-dd): [Enter for today]
Base plan requests (300 default): [Enter]

Select input mode for today's usage:
  1) Month-to-date only
  2) Provide month-to-date at start of day
  3) Provide today's current count
> 1

====================================
==== Forecast Summary ====
====================================
Given date: 2026-02-02
Start: 09:00   Current: 14:30   Elapsed hrs: 5.50
Requests month-to-date: 145.50
Requests today (computed): 0.00

-- Projections --
Current hourly rate (req/hr): 12.20
Projected monthly (from current): 244

Recommendation: keep average <= 10.50 req/hr for remaining hours

-- Rate Comparison (req/hr) --
Allowed  : [████████████████████] 10.50 req/hr
Current  : [██████████████████████] 12.20 req/hr
```

### When to Use Each Mode

| Scenario | Mode to Use |
|----------|-------------|
| Monthly review / management report | Fetch Mode |
| Validate last cycle's billing | Fetch Mode |
| Identify usage patterns | Fetch Mode |
| Quick check: "Am I on track today?" | Daily-Use Mode |
| Real-time hourly rate calculation | Daily-Use Mode |
| Ad-hoc forecasting | Daily-Use Mode |

---

## Parameters Reference

### Common Parameters
- `-CycleStartDay` - Day of month when your billing cycle starts (default: 21)
- `-AlertThresholds` - Alert thresholds as decimal array (default: @(0.7, 0.9, 1.0))

### Fetch Mode Parameters
- `-FetchMode` - Enable Fetch Mode
- `-GitHubOwner` - GitHub username or org
- `-GitHubRepo` - Repository name
- `-GitHubPath` - Path to CSV in repo
- `-GitHubBranch` - Branch name (default: 'main')
- `-DailyUsageCsv` - Local CSV path (alternative to GitHub)
- `-PromptForToken` - Securely prompt for GitHub token
- `-GitHubTokenEnvVar` - Environment variable name for token (default: 'GITHUB_TOKEN')
- `-DailyReportPath` - Output path for daily report (default: './daily_report.csv')
- `-ComprehensiveReportPath` - Output path for summary (default: './comprehensive_report.csv')
- `-PatternAnalysisWindowDays` - Days to analyze for patterns (default: 7)

### Billing API Parameters
- `-FetchBilling` - Fetch org billing data from GitHub API
- `-BillingOrg` - Organization name for billing fetch
- `-BillingOutPath` - JSON output path for billing data (default: './billing_invoices.json')

### Legacy/Export Parameters
- `-ExportCsv` - Export simple usage summary
- `-ExportPath` - Path for simple export (default: './usage_summary.csv')
- `-ShowExamples` - Show example scenarios

---

## Creating Your Daily Usage CSV

### Manual Tracking

Create a CSV file with daily request counts:

```csv
Date,Requests
2026-01-21,15.2
2026-01-22,18.7
2026-01-23,12.3
...
```

### From GitHub Copilot API (Future)

GitHub is working on APIs to export usage data. When available, you can automate CSV creation.

### From Manual Logs

If you're logging usage elsewhere:
1. Export to CSV with Date, Requests columns
2. Use yyyy-MM-dd format for dates
3. Decimal numbers for requests allowed

---

## Tips & Best Practices

### Cost Management
1. **Run Fetch Mode weekly** - Check comprehensive report every Friday
2. **Watch for "Bursty" patterns** - These lead to surprise overages
3. **Schedule heavy workloads** - Early in cycle (days 21-27 of month) when quota is fresh
4. **Review spike days** - Understand what caused high usage
5. **Compare plans** - If monthly overage > $30, consider 1500-request plan

### Excel Analysis
1. **Create charts** from daily_report.csv:
   - Line chart: Date vs Cumulative
   - Column chart: Date vs Requests (daily)
   - Color code by AlertLevel
2. **Pivot tables** from comprehensive_report.csv:
   - Group by Section
   - Filter recommendations
3. **Conditional formatting**:
   - Red: AlertLevel = "OVER"
   - Yellow: AlertLevel = "WARNING" or "CRITICAL"
   - Green: AlertLevel = "OK"

### Automation
Add to your weekly automation:
```powershell
# Weekly billing report automation
.\AICostCalculator.ps1 `
    -FetchMode `
    -DailyUsageCsv "\\shared\copilot\usage_$(Get-Date -Format 'yyyyMM').csv" `
    -DailyReportPath "\\shared\reports\daily_$(Get-Date -Format 'yyyyMMdd').csv" `
    -ComprehensiveReportPath "\\shared\reports\summary_$(Get-Date -Format 'yyyyMMdd').csv"
```

---

## Troubleshooting

### "Failed to fetch CSV from GitHub"
- Verify repo exists and is accessible
- Check CSV path (use forward slashes: `data/usage.csv`)
- For private repos, use `-PromptForToken`
- Verify token has `repo` scope

### "No valid daily rows found in CSV"
- Check CSV format: must have `Date` and `Requests` columns
- Verify dates are yyyy-MM-dd format
- Ensure no blank rows

### "Alert days detected" but actual usage seems fine
- Check cycle dates align with your billing period
- Verify `-CycleStartDay` parameter matches your plan
- Review threshold settings with `-AlertThresholds`

---

## Support

For issues or questions:
1. Check CSV format matches examples
2. Verify date ranges cover your billing cycle
3. Run with `-Verbose` for detailed logging
4. Review generated reports in Excel for data validation

---

## Version History

- **v2.0** - Added Fetch Mode with comprehensive reports, pattern analysis, and timing recommendations
- **v1.0** - Original interactive forecasting tool

---

## License

See LICENSE file in repository root.
