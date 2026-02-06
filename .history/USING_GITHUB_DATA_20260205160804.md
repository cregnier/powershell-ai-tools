# Using GitHub's Actual Usage Report with AICostCalculator

## ✅ SUCCESS: Your Real Data Is Now Integrated!

The script now **automatically reads GitHub's billing export CSV** and generates comprehensive reports!

---

## What Was Analyzed

### Your January 2026 Copilot Usage

**Summary:**
- **Total Requests:** 704.63 (both copilot_premium_request + coding_agent_premium_request)
- **Usage Period:** Jan 2 - Jan 31, 2026 (20 active days)
- **Base Plan:** 300 requests/month @ $10
- **Overage:** 405 requests @ $0.04 each = **$16.20**
- **Total Cost:** **$26.20**

**Pattern Analysis:**
- **Pattern:** Moderate variability (CV: 0.498)
- **Trend:** Decreasing (good news!)
- **Peak Day:** Jan 12 with 63.73 requests
- **Weekly Pattern:** Highest on Thursday (48.2 avg), lowest on Friday (26.5 avg)

**Current Status for Jan 21-Feb 20 Cycle:**
- 278 requests used (92.67% of base plan)
- **CRITICAL alert:** You're at 93% - throttle non-essential requests!

---

## How To Use Going Forward

### Step 1: Export Usage Report from GitHub

1. Go to GitHub Settings → Billing and plans
2. Click "Usage this month" or "View usage report"
3. Export CSV (it will have a name like `usageReport_1_*.csv`)
4. Save to your downloads folder

### Step 2: Run the Script

```powershell
cd c:\Source\powershell-ai-tools

# Use the actual file path from your downloads
$reportPath = "./usageReport_1_*.csv"

.\AICostCalculator.ps1 `
    -FetchMode `
    -GitHubUsageReportCsv $reportPath `
    -DailyReportPath './copilot_daily_report.csv' `
    -ComprehensiveReportPath './copilot_comprehensive.csv' `
    -CycleStartDay 21
```

### Step 3: Review Reports in Excel

**Daily Report:** `copilot_daily_report.csv`
- Day-by-day breakdown
- Alert levels (OK → WARNING → CRITICAL → OVER)
- Recommended pacing for remaining days

**Comprehensive Report:** `copilot_comprehensive.csv`
- Executive summary
- Cost analysis
- Usage patterns
- Actionable recommendations

---

## What The Script Does Automatically

### Data Conversion
The GitHub export has columns like:
```csv
date,product,sku,quantity,unit_type,applied_cost_per_quantity,...
2026-01-02,copilot,copilot_premium_request,37,requests,0.04,...
2026-01-19,copilot,coding_agent_premium_request,3,requests,0.04,...
```

The script:
1. ✅ Filters for `product = copilot`
2. ✅ Includes both `copilot_premium_request` AND `coding_agent_premium_request`
3. ✅ Groups by date and sums quantities
4. ✅ Converts to simple Date,Requests format
5. ✅ Analyzes patterns and generates reports

---

## Key Findings from Your Data

### ⚠️ **IMMEDIATE ACTION NEEDED**

You're at **92.67%** of your base plan (278 of 300 requests used) with **18 days remaining** in the cycle (Jan 21 - Feb 20).

**Recommendations:**
1. **Throttle immediately:** You have only 22 requests left for 18 days
2. **Target:** ~1.2 requests/day to stay under base plan
3. **Current pace:** You averaged 34.8 requests/day in Jan (259% above sustainable)
4. **Good news:** Usage is trending downward (decreasing pattern detected)

### 💰 **Cost Optimization**

Your January usage (704 requests) cost **$26.20**:
- Base plan: $10
- Overage: 405 requests × $0.04 = $16.20

**Should you upgrade to 1500-request plan ($39.99/mo)?**
- At 704 requests/month: NO - you'd pay $40 vs $26
- Breakpoint: ~1,250 requests/month makes the upgrade worthwhile

### 📊 **Usage Patterns**

**Weekly Pattern Detected:**
- Thursday: 48.2 requests average (HIGHEST)
- Friday: 26.5 requests average (LOWEST)

**Recommendation:** Schedule heavy AI workloads on **Fridays** to smooth distribution

---

## Monthly Workflow

### Week 1 (After Cycle Start - Day 21)
✅ Export GitHub usage report  
✅ Run FetchMode analysis  
✅ Review comprehensive report  
✅ Set daily budget for month  

### Weeks 2-3 (Mid-Cycle)
✅ Export usage report weekly  
✅ Check daily report for alerts  
✅ Adjust pacing if WARNING alert appears  

### Week 4 (End of Cycle)
✅ Final export before cycle ends  
✅ Compare projected vs actual cost  
✅ Plan next cycle budget  

---

## Example Commands

### Current Month Analysis
```powershell
.\AICostCalculator.ps1 `
    -FetchMode `
    -GitHubUsageReportCsv "./usageReport_*.csv" `
    -CycleStartDay 21
```

### Specific Cycle Analysis
```powershell
# For Dec 21, 2025 - Jan 20, 2026 cycle
.\AICostCalculator.ps1 `
    -FetchMode `
    -GitHubUsageReportCsv "./december_january_usage.csv" `
    -CycleStartDay 21 `
    -DailyReportPath './reports/dec21_jan20_daily.csv' `
    -ComprehensiveReportPath './reports/dec21_jan20_summary.csv'
```

### Compare Multiple Cycles
```powershell
# Run for each month's export, save to different paths
.\AICostCalculator.ps1 -FetchMode -GitHubUsageReportCsv "./jan_export.csv" -DailyReportPath './jan_daily.csv'
.\AICostCalculator.ps1 -FetchMode -GitHubUsageReportCsv "./feb_export.csv" -DailyReportPath './feb_daily.csv'
.\AICostCalculator.ps1 -FetchMode -GitHubUsageReportCsv "./mar_export.csv" -DailyReportPath './mar_daily.csv'

# Then compare in Excel
```

---

## What Changed in the Script

### New Parameter
```powershell
-GitHubUsageReportCsv 'path/to/usageReport.csv'
```

### New Function
```powershell
Convert-GitHubUsageReport($path)
```
- Reads GitHub's billing export format
- Filters for Copilot SKUs (premium_request + coding_agent_premium_request)
- Aggregates by date
- Returns simple Date,Requests format

### Updated FetchMode
- Now detects GitHub usage report format automatically
- Converts on-the-fly
- Displays conversion summary (days, date range, total requests)

---

## Files Generated from Your Data

1. **copilot_daily_report_jan2026.csv**
   - 31 rows (one per day in cycle)
   - Shows alerts: 23 days with warnings/overages detected
   - Pacing recommendations per day

2. **copilot_comprehensive_jan2026.csv**
   - Executive summary
   - 5 actionable recommendations
   - Cost breakdown: $10 base + $16.20 overage = $26.20

---

## Questions Answered

### ✅ "Are we getting real API/billing data?"

**YES!** You can now:
1. Export GitHub's official usage report CSV
2. Point the script to it with `-GitHubUsageReportCsv`
3. Get comprehensive analysis automatically

### ✅ "Can it handle both copilot requests and coding agent requests?"

**YES!** The script sums:
- `copilot_premium_request` (your main usage)
- `coding_agent_premium_request` (your Jan 19, 27, 28, 31 usage)

Total: 704.63 requests

### ✅ "Does it work with the actual GitHub CSV format?"

**YES!** No manual conversion needed. Just export from GitHub and run.

---

## Next Steps

1. ✅ **Immediate:** Throttle usage - you're at 93% with 18 days left
2. ✅ **This Week:** Aim for <2 requests/day to stay under 300
3. ✅ **Next Cycle:** Export report weekly to track pacing
4. ✅ **Monthly:** Review comprehensive report for pattern insights

---

🎉 **You're all set! The script now works with real GitHub billing data!**
