# PowerShell AI Tools

A collection of PowerShell tools for managing GitHub Copilot costs and AI service automation.

## Main Tool: AICostCalculator.ps1

Comprehensive GitHub Copilot cost management tool with two modes:

### 🔍 Fetch Mode - Comprehensive Billing Analysis
Generate Excel-ready reports with pattern analysis, cost optimization, and timing recommendations.

```powershell
# Analyze usage from CSV and generate reports
.\AICostCalculator.ps1 `
    -FetchMode `
    -DailyUsageCsv './sample_daily_usage.csv' `
    -DailyReportPath './reports/daily_report.csv' `
    -ComprehensiveReportPath './reports/comprehensive_report.csv'
```

**Features:**
- 📊 Daily usage breakdown with alerts
- 📈 Pattern analysis (steady/bursty/spiky)
- 💡 Timing recommendations for workload scheduling
- 💰 Cost optimization and plan comparison
- 📋 Excel-ready CSV reports

### ⚡ Daily-Use Mode - Quick Interactive Planning
Check if you're on track today with real-time hourly rate calculations.

```powershell
# Interactive mode - just run it
.\AICostCalculator.ps1
```

**Features:**
- ⏱️ Real-time hourly rate tracking
- 🎯 Daily target recommendations
- 📉 Immediate forecast adjustments
- 🚦 Color-coded alerts

## Quick Start

### 1. Test with Sample Data
```powershell
# Run Fetch Mode with included sample data
.\AICostCalculator.ps1 -FetchMode -DailyUsageCsv './sample_daily_usage.csv'
```

### 2. Create Your Usage CSV
Create a CSV with your daily Copilot usage:
```csv
Date,Requests
2026-01-21,15.2
2026-01-22,18.7
2026-01-23,12.3
```

### 3. Generate Reports
```powershell
.\AICostCalculator.ps1 `
    -FetchMode `
    -DailyUsageCsv './my_usage.csv' `
    -CycleStartDay 21
```

### 4. Review in Excel
Open the generated CSV files:
- `daily_report.csv` - Per-day breakdown with alerts
- `comprehensive_report.csv` - Executive summary with recommendations

## Documentation

📖 **[Full Usage Guide](USAGE_GUIDE.md)** - Comprehensive documentation with examples

## File Structure

```
AICostCalculator.ps1         # Main cost management tool
USAGE_GUIDE.md               # Detailed documentation
sample_daily_usage.csv       # Sample data for testing
scripts/                     # Additional helper scripts
  └── Invoke-AITools.ps1     # AI tool wrapper
mcp_templates/               # MCP configuration templates
```

## Requirements

- PowerShell 7.0 or higher
- Excel (for viewing CSV reports)
- GitHub token (optional, for fetching from private repos)

## Use Cases

✅ **Weekly Billing Review** - Run Fetch Mode to analyze past week's usage  
✅ **Cost Forecasting** - Predict month-end costs and identify overages  
✅ **Pattern Detection** - Find bursty usage patterns that cause surprise costs  
✅ **Workload Planning** - Get timing recommendations for heavy AI jobs  
✅ **Daily Check-ins** - Quick interactive mode to stay on track  
✅ **Management Reports** - Generate executive summaries with Excel charts  

## Getting Help

```powershell
# View all parameters
Get-Help .\AICostCalculator.ps1 -Detailed

# Run examples
.\AICostCalculator.ps1 -ShowExamples
```

## License

See [LICENSE](LICENSE) file for details.
