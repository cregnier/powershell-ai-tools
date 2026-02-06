# Critical: Dual-Window Billing for GitHub Copilot

## 🚨 The Problem We're Fixing

GitHub Copilot uses **TWO DIFFERENT TIME WINDOWS** for billing:

### Window 1: Billing Cycle (21st-20th) - For Base Plan
- **Purpose:** Determines if you stay within your 300 included requests
- **Period:** 21st of Month A to 20th of Month B
- **Cost:** $10/month flat fee includes 300 requests
- **Example:** Jan 21 - Feb 20 cycle includes 300 requests

### Window 2: Calendar Month (1st-End) - For Overages  
- **Purpose:** Calculates overage charges
- **Period:** 1st to last day of each calendar month
- **Cost:** $0.04 per request **beyond** the monthly 300 quota
- **Example:** January (Jan 1-31) and February (Feb 1-28) are billed separately for overages

## Why This Matters

### Scenario: Your Current Situation

**Data from GitHub Export (Jan 2-31, 2026):**
- Total January calendar month usage: **704.63 requests**
- Current billing cycle (Jan 21 - Feb 20): **278 requests** so far

### Incorrect Calculation (What we had):
```
Total: 704.63 requests
Minus base: 300 requests  
Overage: 404.63 requests × $0.04 = $16.19
Total cost: $10 + $16.19 = $26.19
```

### Correct Calculation (Dual-Window):

**Billing Cycle (Jan 21 - Feb 20):**
- You get 300 requests included in $10 base fee
- Currently used: 278 requests (Jan 21-31 portion)
- Remaining in base: 22 requests
- Status: Still within included quota ✅

**Calendar Month Overages:**

**January (Jan 1-31):**
- Total: 704.63 requests
- Monthly quota: 300 requests  
- Overage: 404.63 requests × $0.04 = $16.19

**February (Feb 1-28) - so far:**
- Jan 21-31 usage (9 days): Already counted in January
- Feb 1-20 usage: Part of current billing cycle
- Feb 1-28 total will be calculated at month end

**Current Total Cost:**
- Base plan: $10.00
- January overage: $16.19
- February overage: TBD (depends on Feb 1-28 usage)
- **Running total: $26.19** (will increase if Feb usage exceeds 300)

## The Fix Needed

### 1. Menu System ✅
```powershell
Select Mode:
  1) Day-to-Day Interactive Mode
  2) Real Usage Analysis (GitHub Export)
  3) Test Mode (Automated with AI_ values)
```

### 2. Dual-Window Tracking
```powershell
function Calculate-DualWindowCosts {
    # Track BOTH windows:
    # - Billing cycle (21st-20th) for base plan usage
    # - Each calendar month for overage calculations
}
```

### 3. Enhanced Reports

**Current (Incorrect):**
```
Total Requests: 704.63
Overage: 404.63
Total Cost: $26.19
```

**Fixed (Dual-Window):**
```
BILLING CYCLE (Jan 21 - Feb 20):
  Cycle Total: 278 requests
  Included Used: 278 of 300
  Status: Within base plan ✅
  Percent: 92.67%

CALENDAR MONTH OVERAGES:
  January 2026:
    Total: 704.63 requests
    Overage: 404.63 requests
    Cost: $16.19
  
  February 2026 (partial):
    Total: TBD (month not complete)
    Overage: TBD
    Cost: TBD

TOTAL COSTS:
  Base Plan: $10.00
  January Overage: $16.19
  February Overage: $0.00 (pending)
  RUNNING TOTAL: $26.19
```

## Visual Report Example

```
═══════════════════════════════════════════════════════════
  DUAL-WINDOW BILLING BREAKDOWN
═══════════════════════════════════════════════════════════

┌─ BILLING CYCLE: Jan 21 - Feb 20 ─────────────────────────┐
│                                                            │
│  Base Plan (300 requests @ $10/month)                     │
│  ██████████████████████████████░░ 278 / 300 (92.67%)      │
│                                                            │
│  Status: CRITICAL - 22 requests remaining                 │
│  Days left: 18 days                                       │
│  Recommended pace: ≤1.2 req/day                           │
│                                                            │
└────────────────────────────────────────────────────────────┘

┌─ CALENDAR MONTH OVERAGES ─────────────────────────────────┐
│                                                            │
│  January 2026 (Jan 1-31)                                  │
│    Total: 704.63 requests                                 │
│    Quota: 300 requests                                    │
│    █████████████████████████████████████ 234.88%          │
│    Overage: 404.63 × $0.04 = $16.19                       │
│                                                            │
│  February 2026 (Feb 1-28 - incomplete)                    │
│    Total: TBD                                             │
│    Overage charges calculated at month end                │
│                                                            │
└────────────────────────────────────────────────────────────┘

TOTAL COST: $26.19 (Base $10 + Jan overage $16.19 + Feb TBD)
```

## Implementation Status

### ✅ Completed
- Menu system for mode selection
- GitHub CSV converter function
- Pattern analysis

### 🔄 In Progress  
- Dual-window cost calculation function
- Enhanced comprehensive report with both windows
- Visual breakdown in terminal output

### 📋 TODO
- Update daily report to show both windows
- Add month-by-month overage breakdown
- Create Excel-friendly pivot format
- Add visual progress bars for both windows

## Testing

### Test Case: Your January Data

**Input:**
- GitHub export: Jan 2-31, 2026 (704.63 requests)
- Billing cycle: Jan 21 - Feb 20
- Today: Feb 2, 2026

**Expected Output:**
```
Billing Cycle (Jan 21 - Feb 20):
  ✓ Cycle used: 278 requests (92.67%)
  ✓ Remaining: 22 requests
  ⚠ CRITICAL: Throttle immediately

Monthly Overages:
  ✓ January: 404.63 overage = $16.19
  ⏳ February: Pending (month incomplete)

Total Cost: $26.19 + February pending
```

## Why Dual-Window Matters

1. **Accurate budgeting:** You need to know BOTH windows
2. **Pacing decisions:** Base plan (21st-20th) tells you to throttle NOW
3. **Cost forecasting:** Calendar months tell you actual charges
4. **Planning:** Schedule heavy work early in billing cycle, but watch monthly limits

## Next Steps

1. ✅ Finish dual-window calculation function
2. ✅ Update reports to show both windows clearly
3. ✅ Test with your actual January data
4. ✅ Generate side-by-side comparison report
5. ✅ Document in USAGE_GUIDE.md

