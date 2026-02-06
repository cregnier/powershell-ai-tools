# AICostCalculator - Quick Reference

## Two Modes

### 🔍 FETCH MODE
**Purpose:** Generate comprehensive Excel reports from historical usage data  
**When to use:** Weekly reviews, management reports, pattern analysis

```powershell
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv './my_usage.csv'
```

**Outputs:**
- `daily_report.csv` - Per-day breakdown with alerts
- `comprehensive_report.csv` - Executive summary

---

### ⚡ DAILY-USE MODE
**Purpose:** Quick interactive check - "Am I on track today?"  
**When to use:** Daily check-ins, real-time forecasting

```powershell
.\AICostCalculator.ps1
```

---

## Common Commands

### Test with sample data
```powershell
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv './sample_daily_usage.csv'
```

### Analyze from GitHub
```powershell
.\AICostCalculator.ps1 `
    -FetchMode `
    -GitHubOwner 'username' `
    -GitHubRepo 'repo' `
    -GitHubPath 'data/usage.csv' `
    -PromptForToken
```

### Custom cycle start date (e.g., 15th of month)
```powershell
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv './usage.csv' -CycleStartDay 15
```

### Generate reports with custom paths
```powershell
.\AICostCalculator.ps1 `
    -FetchMode `
    -DailyUsageCsv './usage.csv' `
    -DailyReportPath './reports/daily.csv' `
    -ComprehensiveReportPath './reports/summary.csv'
```

---

## CSV Format

Your daily usage CSV must have these columns:

```csv
Date,Requests
2026-01-21,15.2
2026-01-22,18.7
2026-01-23,12.3
```

- **Date:** yyyy-MM-dd format
- **Requests:** Decimal number

---

## Alert Levels

| Level | Threshold | Color | Meaning |
|-------|-----------|-------|---------|
| OK | < 70% | Green | Normal operations |
| WARNING | 70-89% | Yellow | Approaching limit |
| CRITICAL | 90-99% | Orange | Very close to limit |
| OVER | ≥ 100% | Red | Exceeded base plan |

---

## Usage Patterns

| Pattern | CV Range | Characteristics |
|---------|----------|-----------------|
| Steady | < 0.3 | Predictable, consistent usage |
| Moderate | 0.3 - 0.7 | Some variability, manageable |
| Bursty | ≥ 0.7 | High spikes, unpredictable |

**CV** = Coefficient of Variation (StdDev / Mean)

---

## Cost Calculation

- **Base Plan:** $10.00/month for 300 requests
- **Overage:** $0.04 per request beyond 300
- **1500-tier:** $39.99/month for 1500 requests

**Example:** 450 requests = $10 + (150 × $0.04) = $16.00

---

## Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Parser error | Check param block has commas between all parameters |
| CSV not found | Verify path, use absolute path if needed |
| No data loaded | Check CSV format, ensure Date column is yyyy-MM-dd |
| Wrong cycle dates | Use `-CycleStartDay` parameter (default: 21) |
| GitHub 404 | Verify owner/repo/path, use `-PromptForToken` for private repos |

---

## Files Generated

### daily_report.csv
- One row per day in cycle
- Columns: Date, Requests, Cumulative, PercentOfBase, RecommendedRemainingPerDay, AlertLevel, AlertMessage
- **Use for:** Charts, daily tracking, identifying spike days

### comprehensive_report.csv
- Summary sections: REPORT_INFO, USAGE, COST, PATTERNS, RECOMMENDATIONS
- Columns: Section, Metric, Value, Details
- **Use for:** Executive summary, management reports, trend analysis

---

## Excel Tips

1. **Daily Report:**
   - Create line chart: Date vs Cumulative
   - Create column chart: Date vs Requests
   - Conditional format AlertLevel column (red=OVER, yellow=WARNING, green=OK)

2. **Comprehensive Report:**
   - Filter by Section
   - Create pivot table grouping by Section
   - Extract RECOMMENDATIONS section for action items

---

## More Help

📖 Full documentation: `USAGE_GUIDE.md`  
💡 Examples: `.\AICostCalculator.ps1 -ShowExamples`  
📊 Sample data: `sample_daily_usage.csv`
