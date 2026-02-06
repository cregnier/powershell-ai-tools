#!/usr/bin/env pwsh
# Simple, robust AI Cost Calculator (clean rebuild)
# - accepts decimal inputs
# - provides menu modes for today's input
# - computes current and today hourly rates, projections, recommendation, ASCII graph

param(
    [switch]$ExportCsv,
    [string]$ExportPath = "./usage_export.csv",
    [int]$CycleStartDay = 21,
    [double[]]$AlertThresholds = @(0.7,0.9,1.0),
    [switch]$NonInteractive,
    [double]$CurrentRequestsMonthFromSource,
    [switch]$ShowExamples,
    [switch]$FetchMode,
    [switch]$PromptForToken,
    [string]$DailyUsageCsv = '',
    [string]$GitHubUsageReportCsv = '',
    [string]$DailyReportPath = './daily_usage_report.csv',
    [string]$GitHubOwner = '',
    [string]$GitHubRepo = '',
    [string]$GitHubPath = '',
    [string]$GitHubBranch = 'main',
    [string]$GitHubTokenEnvVar = 'GITHUB_TOKEN',
    [switch]$FetchBilling,
    [string]$BillingOrg = '',
    [string]$BillingOutPath = './billing_invoices.json',
    [string]$ComprehensiveReportPath = './comprehensive_report.csv',
    [int]$PatternAnalysisWindowDays = 7
)

    # If FetchMode was requested, pre-populate minimal interactive variables so the script
    # doesn't prompt before we fetch/import daily data later.
    if ($FetchMode) {
        $NonInteractive = $true
        $startDt = [datetime]::ParseExact('09:00','HH:mm',$null)
        $currentDt = [datetime]::ParseExact((Get-Date).ToString('HH:mm'),'HH:mm',$null)
        $givenDate = Get-Date
        # Pre-set numeric inputs so early interactive prompts are skipped; these will be replaced
        # by real values once the CSV is fetched and imported later in the script.
        $requestsMonth = 0.0
        $requestsToday = 0.0
        $basePlanRequests = 300
        # Auto-set input mode to 'month-to-date only' to avoid the interactive menu
        $mode = '1'
    }




function Parse-HHMM($s) {
    try { return [datetime]::ParseExact($s, 'HH:mm', $null) }
    catch { return $null }
}

function ToHours($dt) { return $dt.Hour + ($dt.Minute / 60.0) }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# US federal holidays helper (observed dates)
function Get-USFederalHolidays($year) {
    $h = @()
    # New Year's Day
    $h += (Get-Date -Year $year -Month 1 -Day 1)
    # Martin Luther King Jr. Day: third Monday in January
    $h += (Get-NthWeekdayOfMonth $year 1 'Monday' 3)
    # Presidents' Day: third Monday in February
    $h += (Get-NthWeekdayOfMonth $year 2 'Monday' 3)
    # Memorial Day: last Monday in May
    $h += (Get-LastWeekdayOfMonth $year 5 'Monday')
    # Juneteenth: June 19
    $h += (Get-Date -Year $year -Month 6 -Day 19)
    # Independence Day: July 4
    $h += (Get-Date -Year $year -Month 7 -Day 4)
    # Labor Day: first Monday in September
    $h += (Get-NthWeekdayOfMonth $year 9 'Monday' 1)
    # Columbus Day / Indigenous Peoples' Day: second Monday in October
    $h += (Get-NthWeekdayOfMonth $year 10 'Monday' 2)
    # Veterans Day: Nov 11
    $h += (Get-Date -Year $year -Month 11 -Day 11)
    # Thanksgiving: fourth Thursday in November
    $h += (Get-NthWeekdayOfMonth $year 11 'Thursday' 4)
    # Christmas: Dec 25
    $h += (Get-Date -Year $year -Month 12 -Day 25)

    # Apply observed rule: if holiday falls on weekend, adjust
    $observed = @()
    foreach ($dt in $h) {
        if ($dt.DayOfWeek -eq 'Saturday') { $observed += $dt.AddDays(-1).Date }
        elseif ($dt.DayOfWeek -eq 'Sunday') { $observed += $dt.AddDays(1).Date }
        else { $observed += $dt.Date }
    }
    return $observed | Sort-Object
}

# Config
$BasePlanPrice = 10.00
$OveragePricePerRequest = 0.04
$MonthlyBudget = 20.00
$HoursPerWorkday = 8.0
$DefaultBasePlanRequests = 300

# Optional higher tier: 1500 requests for $39.99/month
$Plan1500Requests = 1500
$Plan1500Price = 39.99
# Threshold where switching to 1500-plan usually makes sense
$Plan1500Threshold = 1250

# Optional next tier (example): large/enterprise plan you might buy preemptively
$PlanNextRequests = 5000
$PlanNextPrice = 500.00
$PlanNextName = 'NextTier'

# MODE SELECTION MENU
# Present user with 3 clear options for operation mode
if (-not $env:AI_MODE_OVERRIDE) {
    Write-Host "\n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  GitHub Copilot Cost Management Tool" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "\nSelect operational mode:\n" -ForegroundColor White
    Write-Host "  [1] Day-to-Day Interactive Mode" -ForegroundColor Green
    Write-Host "      Enter values manually for daily cost forecasting" -ForegroundColor Gray
    Write-Host "\n  [2] Real Usage Analysis (GitHub Export CSV)" -ForegroundColor Yellow
    Write-Host "      Analyze actual usage data from GitHub billing export" -ForegroundColor Gray
    Write-Host "\n  [3] Test Mode (Automated Values)" -ForegroundColor Magenta
    Write-Host "      Use AI_* environment variables for testing" -ForegroundColor Gray
    Write-Host "\n" -NoNewline
    
    $modeChoice = Read-Host "Enter choice (1, 2, or 3)"
    
    switch ($modeChoice) {
        "1" {
            Write-Host "\nStarting Day-to-Day Interactive Mode..." -ForegroundColor Green
            $operationalMode = "interactive"
            # Will proceed with normal interactive flow below
        }
        "2" {
            Write-Host "\nStarting Real Usage Analysis Mode..." -ForegroundColor Yellow
            if (-not $GitHubUsageReportCsv) {
                Write-Host "Please provide GitHub usage report CSV path:" -NoNewline
                $GitHubUsageReportCsv = Read-Host
                if (-not (Test-Path $GitHubUsageReportCsv)) {
                    Write-Host "ERROR: File not found: $GitHubUsageReportCsv" -ForegroundColor Red
                    exit 1
                }
            }
            $operationalMode = "analysis"
            $FetchMode = $true  # Activate FetchMode for comprehensive analysis
        }
        "3" {
            Write-Host "\nStarting Test Mode (using AI_* environment variables)..." -ForegroundColor Magenta
            $operationalMode = "test"
            # Load test values from environment
            if ($env:AI_START) { $startDt = Parse-HHMM $env:AI_START }
            if ($env:AI_CURRENT) {
                if ([string]::IsNullOrWhiteSpace($env:AI_CURRENT)) { $currentDt = Get-Date } else { $currentDt = Parse-HHMM $env:AI_CURRENT }
            }
            if ($env:AI_REQUESTS_MONTH) { $requestsMonth = [double]$env:AI_REQUESTS_MONTH }
            if ($env:AI_DATE) { try { $givenDate = [datetime]::ParseExact($env:AI_DATE,'yyyy-MM-dd',$null) } catch { Write-Host 'Invalid date format in AI_DATE'; exit 1 } }
            if ($env:AI_BASEPLAN) { $bpv=0; if (-not [int]::TryParse($env:AI_BASEPLAN,[ref]$bpv)) { Write-Host 'Invalid AI_BASEPLAN' ; exit 1 } ; $basePlanRequests=[int]$bpv }
            if ($env:AI_MODE) { $mode = $env:AI_MODE }
            if ($env:AI_TODAY_CURRENT) { $envToday = $env:AI_TODAY_CURRENT } else { $envToday = $null }
        }
        default {
            Write-Host "\nERROR: Invalid choice. Exiting." -ForegroundColor Red
            exit 1
        }
    }
} else {
    # Allow override for scripted/automated runs
    $operationalMode = $env:AI_MODE_OVERRIDE
    Write-Host "Mode override detected: $operationalMode" -ForegroundColor Cyan
    if ($operationalMode -eq "analysis") {
        $FetchMode = $true  # Activate FetchMode for analysis mode
    }
}

# Skip all interactive prompts if in FetchMode (analysis mode)
if (-not $FetchMode) {

if (-not $startDt) {
    # Check for last-run inputs and offer to reuse them (preserve most config/month values,
    # but still prompt for today's interactive inputs such as current time and today's counts).
    try {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
        $lastInputsPath = Join-Path $scriptDir '.aicost_last_inputs.json'
        if (Test-Path $lastInputsPath) {
            $usePrev = Read-Host "Reuse previous inputs from last run (Y/N)?"
            if ($usePrev -match '^[Yy]') {
                try {
                    $saved = Get-Content $lastInputsPath -Raw | ConvertFrom-Json
                    if ($saved.requestsMonth) { $requestsMonth = [double]$saved.requestsMonth }
                    if ($saved.basePlanRequests) { $basePlanRequests = [int]$saved.basePlanRequests }
                    if ($saved.givenDate) { try { $givenDate = [datetime]::ParseExact($saved.givenDate,'yyyy-MM-dd',$null) } catch { $givenDate = Get-Date } }
                    if ($saved.BasePlanPrice) { $BasePlanPrice = [double]$saved.BasePlanPrice }
                    if ($saved.OveragePricePerRequest) { $OveragePricePerRequest = [double]$saved.OveragePricePerRequest }
                    if ($saved.MonthlyBudget) { $MonthlyBudget = [double]$saved.MonthlyBudget }
                    if ($saved.HoursPerWorkday) { $HoursPerWorkday = [double]$saved.HoursPerWorkday }
                    Write-Host "Loaded previous inputs: requestsMonth=$requestsMonth, basePlanRequests=$basePlanRequests, date=$($givenDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
                } catch {
                    Write-Host "Failed to load previous inputs, continuing interactive." -ForegroundColor Yellow
                }
            }
        }
    } catch {
        # non-fatal: continue interactively
    }
    Write-Host "Start time (HH:mm):" -NoNewline; $startInput = Read-Host
    $startDt = Parse-HHMM $startInput
    if (-not $startDt) { Write-Host 'Invalid start time'; exit 1 }
} else {
    Write-Host "Start time (HH:mm): $($startDt.ToString('HH:mm')) (from AI_TEST)"
}

if (-not $currentDt) {
    Write-Host "Current clock time (HH:mm) or leave blank for system time:" -NoNewline; $currentTimeInput = Read-Host
    if ([string]::IsNullOrWhiteSpace($currentTimeInput)) {
        $currentDt = Get-Date
    } else {
        $currentDt = Parse-HHMM $currentTimeInput
        if (-not $currentDt) { Write-Host 'Invalid current time'; exit 1 }
    }
} else {
    Write-Host "Current clock time: $($currentDt.ToString('HH:mm')) (from AI_TEST)"
}

if (-not ($requestsMonth -ne $null -and $requestsMonth -is [double])) {
    Write-Host "Requests month-to-date (number, decimals allowed):" -NoNewline; $requestsMonthInput = Read-Host
    $requestsMonthVal = 0.0
    if (-not [double]::TryParse($requestsMonthInput, [ref]$requestsMonthVal)) { Write-Host 'Invalid number for requests month-to-date'; exit 1 }
    $requestsMonth = [double]$requestsMonthVal
} else {
    Write-Host "Requests month-to-date: $([math]::Round($requestsMonth,2)) (from AI_TEST)"
}

if (-not $givenDate) {
    Write-Host "Full date (YYYY-MM-DD):" -NoNewline; $dateInput = Read-Host
    try { $givenDate = [datetime]::ParseExact($dateInput,'yyyy-MM-dd',$null) } catch { Write-Host 'Invalid date format'; exit 1 }
} else {
    Write-Host "Full date: $($givenDate.ToString('yyyy-MM-dd')) (from AI_TEST)"
}

if (-not $basePlanRequests) {
    Write-Host "Base plan requests for this month (leave blank for $DefaultBasePlanRequests):" -NoNewline; $bpi = Read-Host
    if ([string]::IsNullOrWhiteSpace($bpi)) { $basePlanRequests = $DefaultBasePlanRequests } else { $bpv=0; if (-not [int]::TryParse($bpi,[ref]$bpv)) { Write-Host 'Invalid integer for base plan'; exit 1 } ; $basePlanRequests=[int]$bpv }
} else {
    Write-Host "Base plan requests: $basePlanRequests (from AI_TEST)"
}



# Compute workdays in month (simple: exclude weekends only)
function Get-WorkdaysInMonth($year,$month) {
    $cnt=0; $days=[datetime]::DaysInMonth($year,$month)
    for ($d=1;$d -le $days;$d++) { $dt=Get-Date -Year $year -Month $month -Day $d; if ($dt.DayOfWeek -ne 'Saturday' -and $dt.DayOfWeek -ne 'Sunday') { $cnt++ } }
    return $cnt
}

$year=$givenDate.Year; $month=$givenDate.Month; $dayOfMonth=$givenDate.Day
$workdaysInMonth = Get-WorkdaysInMonth $year $month

# normalize start/current to givenDate
$startRef = Get-Date -Year $givenDate.Year -Month $givenDate.Month -Day $givenDate.Day -Hour $startDt.Hour -Minute $startDt.Minute -Second 0
$currentRef = Get-Date -Year $givenDate.Year -Month $givenDate.Month -Day $givenDate.Day -Hour $currentDt.Hour -Minute $currentDt.Minute -Second 0
$curH = ToHours($currentRef)
$startH = ToHours($startRef)
$elapsedSoFar = [math]::Max(0.0, $curH - $startH)
$hoursRemainingToday = [math]::Max(0.0, $HoursPerWorkday - $elapsedSoFar)

# initialize today's counters; detailed input menu appears later in the script
# menu
Write-Host ""; Write-Host "Select input mode for today's usage:" -ForegroundColor Cyan
Write-Host "  1) Month-to-date only"; Write-Host "  2) Provide month-to-date at start of day"; Write-Host "  3) Provide today's current count"
if (-not $mode) {
    $mode = Read-Host "Enter 1/2/3 (default 1)"
    if ([string]::IsNullOrWhiteSpace($mode)) { $mode = '1' }
} else {
    Write-Host "Enter 1/2/3 (default 1): $mode (from AI_TEST)"
}

$requestsToday = 0.0; $todayHourlyRate = $null; $projectedMonthlyFromTodayRate = $null
if ($mode -eq '2') {
    if ($env:AI_MONTHSTART) {
        $mv = [double]$env:AI_MONTHSTART
        $requestsToday = [math]::Max(0.0, $requestsMonth - $mv)
        Write-Host "Month-to-date at start of day (number): $mv (from AI_TEST)"
    } else {
        $ms = Read-Host 'Month-to-date at start of day (number)'
        $mv=0.0; if (-not [double]::TryParse($ms,[ref]$mv)) { Write-Host 'Invalid number' ; exit 1 }
        $requestsToday = [math]::Max(0.0, $requestsMonth - $mv)
    }
} elseif ($mode -eq '3') {
    if ($envToday) {
        $cv=[double]$envToday
        Write-Host "Today's current count (number): $cv (from AI_TEST)"
        $requestsToday = [math]::Max(0.0, $cv - $requestsMonth)
    } else {
        $cur = Read-Host "Today's current count (number)"
        $cv=0.0; if (-not [double]::TryParse($cur,[ref]$cv)) { Write-Host 'Invalid number' ; exit 1 }
        $requestsToday = [math]::Max(0.0, $cv - $requestsMonth)
    }
    if ($elapsedSoFar -gt 0) { $todayHourlyRate = $requestsToday / $elapsedSoFar; $projectedMonthlyFromTodayRate = $todayHourlyRate * $HoursPerWorkday * $workdaysInMonth }
}

# calculations
$workedFullDays = [math]::Max(0, ([math]::Floor(($dayOfMonth-1)/1))) # simple: days before today
$workedHoursSoFar = ($workedFullDays * $HoursPerWorkday) + $elapsedSoFar
if ($workedHoursSoFar -le 0) { $currentHourlyRate = 0 } else { $currentHourlyRate = $requestsMonth / $workedHoursSoFar }
$projectedMonthlyFromCurrentRate = $currentHourlyRate * $HoursPerWorkday * $workdaysInMonth

$allowedOverage = [math]::Max(0.0, $MonthlyBudget - $BasePlanPrice)
$allowedExtraRequests = [math]::Floor($allowedOverage / $OveragePricePerRequest)
$monthlyTargetRequests = $basePlanRequests + $allowedExtraRequests
$remainingMonthlyRequests = [math]::Max(0.0, $monthlyTargetRequests - $requestsMonth)

$daysLeftWorking = [math]::Max(0, $workdaysInMonth - [math]::Floor($dayOfMonth))
if ($daysLeftWorking -gt 0) { $projectedDailyNeeded = [math]::Ceiling($remainingMonthlyRequests / $daysLeftWorking) } else { $projectedDailyNeeded = $remainingMonthlyRequests }

$todayRemainingRequests = [math]::Max(0.0, $projectedDailyNeeded - $requestsToday)
if ($hoursRemainingToday -gt 0) { $projectedHourlyNeededToday = [math]::Ceiling($todayRemainingRequests / $hoursRemainingToday) } else { $projectedHourlyNeededToday = 0 }

# projected costs
if ($projectedMonthlyFromCurrentRate -le $basePlanRequests) {
    $projectedCostFromCurrentRate = $BasePlanPrice
} else {
    $cand = $BasePlanPrice + (($projectedMonthlyFromCurrentRate - $basePlanRequests) * $OveragePricePerRequest)
    if ($projectedMonthlyFromCurrentRate -ge $Plan1500Threshold) { $projectedCostFromCurrentRate = [math]::Min($cand, $Plan1500Price) } else { $projectedCostFromCurrentRate = $cand }
}
if ($projectedMonthlyFromTodayRate -ne $null) {
    if ($projectedMonthlyFromTodayRate -le $basePlanRequests) {
        $projectedCostFromTodayRate = $BasePlanPrice
    } else {
        $candT = $BasePlanPrice + (($projectedMonthlyFromTodayRate - $basePlanRequests) * $OveragePricePerRequest)
        if ($projectedMonthlyFromTodayRate -ge $Plan1500Threshold) { $projectedCostFromTodayRate = [math]::Min($candT, $Plan1500Price) } else { $projectedCostFromTodayRate = $candT }
    }
} else { $projectedCostFromTodayRate = $null }

# recommendation
$remainingWorkingHours = ($daysLeftWorking * $HoursPerWorkday) + $hoursRemainingToday
if ($remainingWorkingHours -le 0) { $allowedHourlyRateForRemaining = 0 } else { $allowedHourlyRateForRemaining = $remainingMonthlyRequests / $remainingWorkingHours }

# small helper for bars
function Get-Bar([double]$val, [double]$max) {
    $width = 40
    if ($max -le 0 -or [double]::IsNaN($max) -or [double]::IsInfinity($max)) { $max = 1.0 }
    $ratio = 0.0
    if ($val -gt 0) { $ratio = $val / $max }
    if ($ratio -lt 0) { $ratio = 0 }
    if ($ratio -gt 1) { $ratio = 1 }
    $len = [int]([math]::Round($ratio * $width))
    return ('=' * $len) + (' ' * ($width - $len))
}

# graph max
if ($todayHourlyRate -ne $null) { $todayVal = [double]$todayHourlyRate } else { $todayVal = 0.0 }
$graphMax = [math]::Max(1.0, [math]::Max($allowedHourlyRateForRemaining, [math]::Max($currentHourlyRate, $todayVal)))

# output
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "==== Forecast Summary ====" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Given date: $($givenDate.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
Write-Host "Start: $($startDt.ToString('HH:mm'))   Current: $($currentRef.ToString('HH:mm'))   Elapsed hrs: $([math]::Round($elapsedSoFar,2))" -ForegroundColor White
Write-Host "Requests month-to-date: $([math]::Round($requestsMonth,2))" -ForegroundColor Green
Write-Host "Requests today (computed): $([math]::Round($requestsToday,2))" -ForegroundColor Green
Write-Host "-- Projections --" -ForegroundColor DarkCyan
Write-Host "Current hourly rate (req/hr): $([math]::Round($currentHourlyRate,2))" -ForegroundColor Yellow
Write-Host "Projected monthly (from current): $([math]::Round($projectedMonthlyFromCurrentRate,0))" -ForegroundColor Yellow
if ($projectedMonthlyFromTodayRate -ne $null) { Write-Host "Today hourly rate (req/hr): $([math]::Round($todayHourlyRate,2))" -ForegroundColor Cyan; Write-Host "Projected monthly (from today): $([math]::Round($projectedMonthlyFromTodayRate,0))" -ForegroundColor Cyan }
Write-Host "Recommendation: keep average <= $([math]::Round($allowedHourlyRateForRemaining,2)) req/hr for remaining hours" -ForegroundColor Green

Write-Host ""; Write-Host "-- Rate Comparison (req/hr) --" -ForegroundColor DarkCyan
Write-Host "Legend: Allowed = allowed avg for remaining hours; Current = month avg; Today = today's run-rate" -ForegroundColor White
$allowedLine = ('Allowed  : [{0}] {1:N2} req/hr' -f (Get-Bar $allowedHourlyRateForRemaining $graphMax), $allowedHourlyRateForRemaining)
Write-Host $allowedLine -ForegroundColor Green
$currentLine = ('Current  : [{0}] {1:N2} req/hr' -f (Get-Bar $currentHourlyRate $graphMax), $currentHourlyRate)
Write-Host $currentLine -ForegroundColor Yellow
if ($todayHourlyRate -ne $null) {
    $col='Cyan'; if ($todayHourlyRate -gt $allowedHourlyRateForRemaining) { $col='Red' }
    $todayLine = ('Today    : [{0}] {1:N2} req/hr' -f (Get-Bar $todayHourlyRate $graphMax), $todayHourlyRate)
    Write-Host $todayLine -ForegroundColor $col
}
Write-Host "====================================" -ForegroundColor Cyan

# --- New: timeline, alerts, export helpers ---
function Get-CycleWindow([datetime]$refDate, [int]$cycleStartDay) {
    # Returns start and end DateTime of the seat billing cycle that contains refDate
    $year = $refDate.Year
    $month = $refDate.Month
    if ($refDate.Day -ge $cycleStartDay) {
        $start = Get-Date -Year $year -Month $month -Day $cycleStartDay -Hour 0 -Minute 0 -Second 0
        $end = $start.AddMonths(1).AddDays(-1)
    } else {
        $end = Get-Date -Year $year -Month $month -Day ($cycleStartDay - 1) -Hour 23 -Minute 59 -Second 59
        $start = $end.AddMonths(-1).AddDays(1 - ($end.Day - ($cycleStartDay - 1))) # adjust safely
        # simpler: go to previous month's cycle start
        $start = (Get-Date -Year $refDate.AddMonths(-1).Year -Month $refDate.AddMonths(-1).Month -Day $cycleStartDay -Hour 0 -Minute 0 -Second 0)
        $end = $start.AddMonths(1).AddDays(-1)
    }
    return @{ Start = $start; End = $end }
}

function Render-TimelineASCII([datetime]$refDate, [int]$cycleStartDay) {
    $cw = Get-CycleWindow $refDate $cycleStartDay
    $cycleStart = $cw.Start; $cycleEnd = $cw.End
    $calPrev = Get-Date -Year $refDate.Year -Month $refDate.Month -Day 1
    $calNext = $calPrev.AddMonths(1)
    Write-Host "-- Timeline --" -ForegroundColor Cyan
    Write-Host ("Cycle: {0:yyyy-MM-dd} → {1:yyyy-MM-dd}" -f $cycleStart, $cycleEnd) -ForegroundColor Yellow
    Write-Host ("Calendar prev month: {0:yyyy-MM-dd} → {1:yyyy-MM-dd}" -f $calPrev, $calPrev.AddMonths(1).AddDays(-1)) -ForegroundColor DarkCyan
    Write-Host ("Calendar this month: {0:yyyy-MM-dd} → {1:yyyy-MM-dd}" -f $calNext, $calNext.AddMonths(1).AddDays(-1)) -ForegroundColor DarkCyan
    # compact ASCII visual
    $line = ""
    $line += $cycleStart.ToString('MM-dd') + ' ['
    $totalDays = ($cycleEnd - $cycleStart).Days + 1
    for ($i=0; $i -lt $totalDays; $i++) {
        $d = $cycleStart.AddDays($i)
        if ($d -eq $refDate.Date) { $line += '|' } else { $line += '-' }
    }
    $line += "] " + $cycleEnd.ToString('MM-dd')
    Write-Host $line -ForegroundColor Gray
}

function Evaluate-Alerts([double]$requestsMonth, [int]$basePlanRequests, [double[]]$thresholds) {
    $pct = 0.0
    if ($basePlanRequests -gt 0) { $pct = $requestsMonth / $basePlanRequests }
    $level = 'OK'
    $msg = ''
    if ($pct -ge $thresholds[2]) { $level = 'OVER'; $msg = "Usage >= 100% of base plan - immediate action required (overage possible)." }
    elseif ($pct -ge $thresholds[1]) { $level = 'CRITICAL'; $msg = "Usage >= 90% - stop non-essential requests and throttle." }
    elseif ($pct -ge $thresholds[0]) { $level = 'WARNING'; $msg = "Usage >= 70% - slow down non-essential, prepare to split or defer jobs." }
    else { $level = 'OK'; $msg = "Usage below thresholds - normal operations." }
    return @{ Level = $level; Percent = $pct; Message = $msg }
}

function Suggest-Actions($alert, $requestsMonth, $basePlanRequests, $cycleStartDay) {
    switch ($alert.Level) {
        'OK' { return 'No immediate action. You can run scheduled jobs. Prefer to run heavy jobs early in the cycle (days 21-25).' }
        'WARNING' { return 'Slow non-critical automation, consolidate requests, consider splitting larger jobs across cycles.' }
        'CRITICAL' { return 'Throttle heavy jobs, postpone non-urgent runs until after cycle start, split tasks; enable stricter rate-limiter.' }
        'OVER' { $over = [math]::Max(0, $requestsMonth - $basePlanRequests); $cost = $over * $OveragePricePerRequest; return ("Overage: {0} requests → approx ${1:N2}. Consider pausing usage or upgrading plan." -f $over, $cost) }
        default { return 'Unknown state' }
    }
}

function Export-UsageCsv([string]$path, [hashtable]$row) {
    $obj = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString('s')
        GivenDate = $row.GivenDate
        RequestsMonthToDate = $row.RequestsMonth
        RequestsToday = $row.RequestsToday
        CycleStart = $row.CycleStart
        CycleEnd = $row.CycleEnd
        PercentOfBase = $row.PercentOfBase
        AlertLevel = $row.AlertLevel
        Recommendation = $row.Recommendation
    }
    if (-not (Test-Path $path)) { $obj | Export-Csv -Path $path -NoTypeInformation }
    else { $obj | Export-Csv -Path $path -NoTypeInformation -Append }
    Write-Host ("Exported usage summary to {0}" -f $path) -ForegroundColor DarkCyan
}

function Get-CurrentUsageFromSource([string]$csvPath) {
    # Try environment override first
    if ($CurrentRequestsMonthFromSource) { return [double]$CurrentRequestsMonthFromSource }
    if ($env:CURRENT_REQUESTS_MONTH) { return [double]$env:CURRENT_REQUESTS_MONTH }
    if ($csvPath -and (Test-Path $csvPath)) {
        try {
            $first = Import-Csv $csvPath | Select-Object -First 1
            if ($first -and $first.requestsMonth) { return [double]$first.requestsMonth }
        } catch { }
    }
    return $null
}

function Get-GitHubFileContent {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Path,
        [string]$Branch = 'main',
        [string]$TokenEnvVar = 'GITHUB_TOKEN'
    )
    if (-not $Owner -or -not $Repo -or -not $Path) { throw 'Owner, Repo and Path are required' }
    $token = [System.Environment]::GetEnvironmentVariable($TokenEnvVar)
    $uri = "https://api.github.com/repos/$Owner/$Repo/contents/$Path?ref=$Branch"
    $headers = @{ 'User-Agent' = 'AICostCalculator' }
    if ($token) { $headers['Authorization'] = "token $token" }
    try {
        $resp = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop
        if ($resp -and $resp.content) {
            $content = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($resp.content))
            return $content
        } else { throw 'No content returned' }
    } catch {
        Write-Host "Failed to fetch GitHub file: $_" -ForegroundColor Yellow
        return $null
    }
}

function Prompt-ForToken([string]$envVarName) {
    try {
        $secure = Read-Host -Prompt 'Paste GitHub token (one-time)' -AsSecureString
        if (-not $secure) { return $false }
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try {
            $tok = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
        if ($tok) { [System.Environment]::SetEnvironmentVariable($envVarName, $tok, 'Process'); return $true } else { return $false }
    } catch {
        Write-Host "Token prompt failed: $_" -ForegroundColor Yellow
        return $false
    }
}

function Get-OrgBillingInvoices {
    param(
        [string]$Org,
        [string]$TokenEnvVar = 'GITHUB_TOKEN',
        [string]$OutPath = './billing_invoices.json'
    )
    if (-not $Org) { throw 'Org is required' }
    $token = [System.Environment]::GetEnvironmentVariable($TokenEnvVar)
    if (-not $token) { Write-Host 'No token found in environment for billing fetch' -ForegroundColor Yellow; return $null }
    $headers = @{ Authorization = "token $token"; 'User-Agent' = 'AICostCalculator' }
    $results = @{}
    $tried = 0

    # Try common invoice endpoints (best-effort - may require org owner/billing scope)
    $endpoints = @(
        "https://api.github.com/orgs/$Org/invoices",
        "https://api.github.com/orgs/$Org/settings/billing",
        "https://api.github.com/orgs/$Org/settings/billing/advanced",
        "https://api.github.com/orgs/$Org/settings/billing/actions",
        "https://api.github.com/orgs/$Org/settings/billing/packages"
    )
    foreach ($ep in $endpoints) {
        try {
            $tried++
            $resp = Invoke-RestMethod -Uri $ep -Headers $headers -ErrorAction Stop
            $results[$ep] = $resp
            Write-Host ("Fetched billing endpoint: {0}" -f $ep) -ForegroundColor DarkCyan
        } catch {
            $results[$ep] = @{ error = $_.Exception.Message }
            Write-Host ("Billing endpoint {0} returned: {1}" -f $ep, $_.Exception.Message) -ForegroundColor Yellow
        }
    }

    try {
        $results | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutPath -Encoding UTF8 -Force
        Write-Host ("Saved billing fetch results to {0}" -f $OutPath) -ForegroundColor DarkCyan
    } catch {
        Write-Host "Failed to save billing results: $_" -ForegroundColor Yellow
    }
    return $results
}

function Import-DailyUsage([string]$path) {
    if (-not $path) { return $null }
    if (-not (Test-Path $path)) { Write-Host "Daily usage CSV not found: $path" -ForegroundColor Yellow; return $null }
    try {
        $rows = Import-Csv $path | ForEach-Object {
            $d = $null
            try { $d = [datetime]::ParseExact($_.Date,'yyyy-MM-dd',$null) } catch { try { $d = [datetime]$_.Date } catch { $d = $null } }
            if (-not $d) { return }
            [PSCustomObject]@{ Date = $d.Date; Requests = [double]$_.Requests }
        }
        return $rows | Sort-Object Date
    } catch {
        Write-Host "Failed to read daily usage CSV: $_" -ForegroundColor Red
        return $null
    }
}

function Analyze-UsagePatterns($dailyRows, [int]$windowDays) {
    if (-not $dailyRows -or $dailyRows.Count -eq 0) { return $null }
    
    $sorted = $dailyRows | Sort-Object Date
    $reqs = $sorted | Select-Object -ExpandProperty Requests
    $avg = ($reqs | Measure-Object -Average).Average
    $max = ($reqs | Measure-Object -Maximum).Maximum
    $min = ($reqs | Measure-Object -Minimum).Minimum
    $stdDev = if ($reqs.Count -gt 1) { [math]::Sqrt((($reqs | ForEach-Object { [math]::Pow($_ - $avg, 2) }) | Measure-Object -Average).Average) } else { 0 }
    
    # Pattern classification
    $cv = if ($avg -gt 0) { $stdDev / $avg } else { 0 }
    $pattern = if ($cv -lt 0.3) { 'Steady' } elseif ($cv -lt 0.7) { 'Moderate' } else { 'Bursty' }
    
    # Identify spikes (days > 2 std dev above mean)
    $spikeDays = @()
    foreach ($row in $sorted) {
        if ($row.Requests -gt ($avg + 2 * $stdDev)) {
            $spikeDays += $row.Date.ToString('yyyy-MM-dd')
        }
    }
    
    # Detect trends (simple: compare first half vs second half)
    $mid = [math]::Floor($sorted.Count / 2)
    $firstHalf = $sorted | Select-Object -First $mid | Measure-Object -Property Requests -Average
    $secondHalf = $sorted | Select-Object -Last ($sorted.Count - $mid) | Measure-Object -Property Requests -Average
    $trend = if ($secondHalf.Average -gt ($firstHalf.Average * 1.2)) { 'Increasing' } elseif ($secondHalf.Average -lt ($firstHalf.Average * 0.8)) { 'Decreasing' } else { 'Stable' }
    
    # High-risk days (days with usage in top 25%)
    $p75 = ($reqs | Sort-Object | Select-Object -Skip ([math]::Floor($reqs.Count * 0.75)) -First 1)
    $highRiskDays = @()
    foreach ($row in $sorted) {
        if ($row.Requests -ge $p75) {
            $highRiskDays += $row.Date.ToString('yyyy-MM-dd')
        }
    }
    
    return [PSCustomObject]@{
        Pattern = $pattern
        Trend = $trend
        AverageDailyRequests = [math]::Round($avg, 2)
        StdDeviation = [math]::Round($stdDev, 2)
        CoefficientOfVariation = [math]::Round($cv, 3)
        MinRequests = $min
        MaxRequests = $max
        SpikeDays = $spikeDays
        HighRiskDays = $highRiskDays
    }
}

function Get-TimingRecommendations($patternAnalysis, [datetime]$cycleStart, [int]$cycleStartDay, $dailyRows, [int]$basePlanRequests) {
    $recommendations = @()
    
    if ($patternAnalysis.Pattern -eq 'Bursty') {
        $recommendations += 'USAGE PATTERN: Bursty/irregular usage detected. Consider smoothing workload distribution across days.'
        $recommendations += 'TIMING: Schedule heavy AI workloads in the first week after cycle start (day ' + $cycleStartDay + ') when quota is fresh.'
    } elseif ($patternAnalysis.Pattern -eq 'Steady') {
        $recommendations += 'USAGE PATTERN: Steady usage detected. Maintain current pacing to avoid surprises.'
    } else {
        $recommendations += 'USAGE PATTERN: Moderate variability. Monitor daily usage to prevent unexpected spikes.'
    }
    
    if ($patternAnalysis.Trend -eq 'Increasing') {
        $recommendations += 'TREND ALERT: Usage is trending upward. Review workload and consider upgrading plan if trend continues.'
        $recommendations += 'COST OPTIMIZATION: Evaluate whether higher-tier plan ($39.99/month for 1500 requests) becomes cost-effective.'
    } elseif ($patternAnalysis.Trend -eq 'Decreasing') {
        $recommendations += 'TREND: Usage is trending downward. Current plan should remain sufficient.'
    }
    
    if ($patternAnalysis.SpikeDays.Count -gt 0) {
        $recommendations += ('SPIKE DAYS DETECTED: {0} days with unusual high usage: {1}' -f $patternAnalysis.SpikeDays.Count, ($patternAnalysis.SpikeDays -join ', '))
        $recommendations += 'ACTION: Investigate spike causes. Defer non-critical batch jobs to low-usage days.'
    }
    
    # Calculate cycle progress and pacing
    if ($dailyRows) {
        $cycleRows = $dailyRows | Where-Object { $_.Date -ge $cycleStart.Date -and $_.Date -le $cycleStart.AddDays(30).Date }
        $cycleTotal = ($cycleRows | Measure-Object -Property Requests -Sum).Sum
        $daysInCycle = ($dailyRows | Where-Object { $_.Date -ge $cycleStart.Date } | Measure-Object).Count
        
        if ($cycleTotal -gt 0 -and $daysInCycle -gt 0) {
            $avgPerDay = $cycleTotal / $daysInCycle
            $projectedCycle = $avgPerDay * 31
            $targetDailyAvg = $basePlanRequests / 31
            
            if ($avgPerDay -gt ($targetDailyAvg * 1.5)) {
                $recommendations += ('PACING WARNING: Current daily average ({0:N1}) is {1:N0}% above sustainable target ({2:N1}). Reduce usage or plan for overage costs.' -f $avgPerDay, (($avgPerDay / $targetDailyAvg - 1) * 100), $targetDailyAvg)
            } elseif ($avgPerDay -gt $targetDailyAvg) {
                $recommendations += ('PACING CAUTION: Current daily average ({0:N1}) exceeds target ({1:N1}). Monitor closely to avoid month-end overages.' -f $avgPerDay, $targetDailyAvg)
            } else {
                $recommendations += ('PACING: Current daily average ({0:N1}) is within sustainable target ({1:N1}). Continue at current pace.' -f $avgPerDay, $targetDailyAvg)
            }
        }
    }
    
    # Day-of-week recommendations (if enough data)
    if ($dailyRows.Count -ge 14) {
        $byDayOfWeek = $dailyRows | Group-Object { $_.Date.DayOfWeek } | ForEach-Object {
            [PSCustomObject]@{
                DayOfWeek = $_.Name
                AvgRequests = ($_.Group | Measure-Object -Property Requests -Average).Average
            }
        } | Sort-Object AvgRequests -Descending
        
        if ($byDayOfWeek.Count -gt 0) {
            $highestDay = $byDayOfWeek[0]
            $lowestDay = $byDayOfWeek[-1]
            $recommendations += ('WEEKLY PATTERN: Highest usage on {0} (avg {1:N1}), lowest on {2} (avg {3:N1}).' -f $highestDay.DayOfWeek, $highestDay.AvgRequests, $lowestDay.DayOfWeek, $lowestDay.AvgRequests)
            $recommendations += ('OPTIMIZATION: Schedule batch/heavy workloads on {0} if possible to smooth weekly distribution.' -f $lowestDay.DayOfWeek)
        }
    }
    
    return $recommendations
}

function Calculate-DualWindowCosts($dailyRows, [int]$cycleStartDay, [int]$basePlanRequests, [double]$basePlanPrice, [double]$overagePrice) {
    # Copilot has TWO different windows:
    # 1. BILLING CYCLE (21st of month A to 20th of month B): Determines if you stay within 300 included requests
    # 2. CALENDAR MONTH: Determines overage costs for requests beyond the monthly 300 quota
    
    if (-not $dailyRows) { return $null }
    
    $now = Get-Date
    $currentYear = $now.Year
    $currentMonth = $now.Month
    
    # Determine current billing cycle (e.g., Jan 21 - Feb 20)
    if ($now.Day -ge $cycleStartDay) {
        $cycleStart = Get-Date -Year $currentYear -Month $currentMonth -Day $cycleStartDay
        $cycleEnd = $cycleStart.AddDays(30)  # Approx 31-day cycle
    } else {
        $cycleEnd = Get-Date -Year $currentYear -Month $currentMonth -Day ($cycleStartDay - 1)
        $cycleStart = $cycleEnd.AddDays(-30)
    }
    
    # BILLING CYCLE (21st-20th): Count requests to see if within 300 included
    $cycleRows = $dailyRows | Where-Object { $_.Date -ge $cycleStart.Date -and $_.Date -le $cycleEnd.Date }
    $cycleTotal = ($cycleRows | Measure-Object -Property Requests -Sum).Sum
    if (-not $cycleTotal) { $cycleTotal = 0 }
    
    # CALENDAR MONTHS: Calculate overage costs per month
    $monthlyOverages = @{}
    $monthGroups = $dailyRows | Group-Object { $_.Date.ToString('yyyy-MM') }
    
    foreach ($monthGroup in $monthGroups) {
        $monthKey = $monthGroup.Name
        $monthTotal = ($monthGroup.Group | Measure-Object -Property Requests -Sum).Sum
        $monthOverage = [math]::Max(0, $monthTotal - $basePlanRequests)
        $monthOverageCost = $monthOverage * $overagePrice
        
        $monthlyOverages[$monthKey] = @{
            Total = $monthTotal
            Overage = $monthOverage
            OverageCost = $monthOverageCost
        }
    }
    
    # Calculate costs
    $totalOverageCost = ($monthlyOverages.Values | ForEach-Object { $_.OverageCost }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    if (-not $totalOverageCost) { $totalOverageCost = 0 }
    
    $cycleIncludedUsed = [math]::Min($cycleTotal, $basePlanRequests)
    $cycleOverage = [math]::Max(0, $cycleTotal - $basePlanRequests)
    
    return [PSCustomObject]@{
        # Billing Cycle Window (21st-20th)
        CycleStart = $cycleStart
        CycleEnd = $cycleEnd
        CycleTotal = $cycleTotal
        CycleIncludedUsed = $cycleIncludedUsed
        CycleOverage = $cycleOverage
        CyclePercentUsed = if ($basePlanRequests -gt 0) { $cycleTotal / $basePlanRequests } else { 0 }
        
        # Calendar Month Breakdown
        MonthlyOverages = $monthlyOverages
        TotalOverageCost = $totalOverageCost
        TotalCost = $basePlanPrice + $totalOverageCost
        
        # Summary
        BasePlanCost = $basePlanPrice
    }
}

function Generate-ComprehensiveSummary($dailyRows, $patternAnalysis, $recommendations, [int]$basePlanRequests, [double]$basePlanPrice, [double]$overagePrice, [datetime]$cycleStart, [datetime]$cycleEnd, [string]$outPath, [int]$cycleStartDay) {
    $summary = @()
    
    # Calculate dual-window costs
    $dualCosts = Calculate-DualWindowCosts -dailyRows $dailyRows -cycleStartDay $cycleStartDay -basePlanRequests $basePlanRequests -basePlanPrice $basePlanPrice -overagePrice $overagePrice
    
    # Header section
    $summary += [PSCustomObject]@{
        Section = 'REPORT_INFO'
        Metric = 'Generated'
        Value = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Details = 'Comprehensive Copilot Usage & Cost Analysis'
    }
    $summary += [PSCustomObject]@{
        Section = 'REPORT_INFO'
        Metric = 'IMPORTANT'
        Value = 'Dual-Window Billing'
        Details = "Base plan (300 requests): Billing cycle ${cycleStartDay}th-${cycleStartDay-1}th | Overages: Calendar month"
    }
    $summary += [PSCustomObject]@{
        Section = 'REPORT_INFO'
        Metric = 'Current Billing Cycle'
        Value = ('{0} to {1}' -f $dualCosts.CycleStart.ToString('yyyy-MM-dd'), $dualCosts.CycleEnd.ToString('yyyy-MM-dd'))
        Details = 'Period for 300 included requests'
    }
    
    # Usage metrics
    if ($dailyRows) {
        $totalRequests = ($dailyRows | Measure-Object -Property Requests -Sum).Sum
        $avgDaily = ($dailyRows | Measure-Object -Property Requests -Average).Average
        $maxDaily = ($dailyRows | Measure-Object -Property Requests -Maximum).Maximum
        $daysWithUsage = ($dailyRows | Where-Object { $_.Requests -gt 0 } | Measure-Object).Count
        
        $summary += [PSCustomObject]@{ Section = 'USAGE'; Metric = 'Total Requests'; Value = [math]::Round($totalRequests, 2); Details = 'Sum across all days' }
        $summary += [PSCustomObject]@{ Section = 'USAGE'; Metric = 'Average Daily'; Value = [math]::Round($avgDaily, 2); Details = 'Mean requests per day' }
        $summary += [PSCustomObject]@{ Section = 'USAGE'; Metric = 'Peak Daily'; Value = $maxDaily; Details = 'Highest single-day usage' }
        $summary += [PSCustomObject]@{ Section = 'USAGE'; Metric = 'Active Days'; Value = $daysWithUsage; Details = 'Days with non-zero usage' }
        $summary += [PSCustomObject]@{ Section = 'USAGE'; Metric = 'Percent of Base'; Value = ('{0:P2}' -f ($totalRequests / $basePlanRequests)); Details = "$basePlanRequests request base plan" }
    }
    
    # Billing Cycle Usage (21st-20th for base 300 requests)
    if ($dualCosts) {
        $summary += [PSCustomObject]@{ Section = 'BILLING_CYCLE'; Metric = 'Cycle Total Requests'; Value = [math]::Round($dualCosts.CycleTotal, 2); Details = "From ${cycleStartDay}th to ${cycleStartDay-1}th" }
        $summary += [PSCustomObject]@{ Section = 'BILLING_CYCLE'; Metric = 'Included Requests Used'; Value = [math]::Round($dualCosts.CycleIncludedUsed, 2); Details = "Of 300 included in \$$basePlanPrice base plan" }
        $summary += [PSCustomObject]@{ Section = 'BILLING_CYCLE'; Metric = 'Cycle Percent Used'; Value = ('{0:P2}' -f $dualCosts.CyclePercentUsed); Details = 'Of base plan quota' }
        $summary += [PSCustomObject]@{ Section = 'BILLING_CYCLE'; Metric = 'Requests Beyond 300'; Value = [math]::Round($dualCosts.CycleOverage, 2); Details = 'Exceeds included quota (billed monthly)' }
    }
    
    # Calendar Month Overages (actual charges)
    if ($dualCosts -and $dualCosts.MonthlyOverages) {
        $summary += [PSCustomObject]@{ Section = 'MONTHLY_COSTS'; Metric = 'Base Plan Cost'; Value = ('${0:N2}' -f $basePlanPrice); Details = "$basePlanRequests requests included per billing cycle" }
        
        foreach ($monthKey in ($dualCosts.MonthlyOverages.Keys | Sort-Object)) {
            $monthData = $dualCosts.MonthlyOverages[$monthKey]
            $summary += [PSCustomObject]@{ 
                Section = 'MONTHLY_COSTS'
                Metric = "$monthKey Overage"
                Value = "$([math]::Round($monthData.Overage, 2)) requests"
                Details = "\$$($monthData.OverageCost.ToString('N2')) charged"
            }
        }
        
        $summary += [PSCustomObject]@{ Section = 'MONTHLY_COSTS'; Metric = 'Total Overage Cost'; Value = ('${0:N2}' -f $dualCosts.TotalOverageCost); Details = 'Sum of all monthly overage charges' }
        $summary += [PSCustomObject]@{ Section = 'MONTHLY_COSTS'; Metric = 'TOTAL COST'; Value = ('${0:N2}' -f $dualCosts.TotalCost); Details = "Base (\$$basePlanPrice) + Overages (\$$($dualCosts.TotalOverageCost.ToString('N2')))" }
    }
    
    # Pattern analysis
    if ($patternAnalysis) {
        $summary += [PSCustomObject]@{ Section = 'PATTERNS'; Metric = 'Usage Pattern'; Value = $patternAnalysis.Pattern; Details = "CV: $($patternAnalysis.CoefficientOfVariation)" }
        $summary += [PSCustomObject]@{ Section = 'PATTERNS'; Metric = 'Trend'; Value = $patternAnalysis.Trend; Details = 'First-half vs second-half comparison' }
        $summary += [PSCustomObject]@{ Section = 'PATTERNS'; Metric = 'Std Deviation'; Value = [math]::Round($patternAnalysis.StdDeviation, 2); Details = 'Daily request variability' }
        $summary += [PSCustomObject]@{ Section = 'PATTERNS'; Metric = 'Spike Days'; Value = $patternAnalysis.SpikeDays.Count; Details = ($patternAnalysis.SpikeDays -join ', ') }
    }
    
    # Recommendations
    if ($recommendations) {
        for ($i = 0; $i -lt $recommendations.Count; $i++) {
            $summary += [PSCustomObject]@{
                Section = 'RECOMMENDATIONS'
                Metric = "Rec $($i + 1)"
                Value = $recommendations[$i]
                Details = ''
            }
        }
    }
    
    try {
        $summary | Export-Csv -Path $outPath -NoTypeInformation -Force
        Write-Host "Comprehensive summary exported to $outPath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to export comprehensive summary: $_" -ForegroundColor Red
    }
    
    return $summary
}

function Calculate-DualWindowCosts {
    param(
        [Parameter(Mandatory=$true)]
        [array]$DailyRows,
        
        [Parameter(Mandatory=$true)]
        [datetime]$CurrentDate,
        
        [double]$BasePlanRequests = 300,
        [double]$OveragePricePerRequest = 0.04,
        [double]$BasePlanPrice = 10.00
    )
    
    # WINDOW 1: Billing Cycle (21st of previous month to 20th of current month)
    # This determines usage against the 300 included requests
    $cycleStartDay = 21
    $currentMonth = $CurrentDate.Month
    $currentYear = $CurrentDate.Year
    
    if ($CurrentDate.Day -ge 21) {
        # Cycle is from 21st of this month to 20th of next month
        $cycleStart = Get-Date -Year $currentYear -Month $currentMonth -Day $cycleStartDay
        $cycleEnd = (Get-Date -Year $currentYear -Month $currentMonth -Day 1).AddMonths(1).AddDays(19)
    } else {
        # Cycle is from 21st of last month to 20th of this month
        $prevMonth = (Get-Date -Year $currentYear -Month $currentMonth -Day 1).AddMonths(-1)
        $cycleStart = Get-Date -Year $prevMonth.Year -Month $prevMonth.Month -Day $cycleStartDay
        $cycleEnd = Get-Date -Year $currentYear -Month $currentMonth -Day 20
    }
    
    # Filter daily rows for current billing cycle
    $cycleRows = $DailyRows | Where-Object {
        $rowDate = [datetime]::ParseExact($_.Date, 'yyyy-MM-dd', $null)
        $rowDate -ge $cycleStart -and $rowDate -le $cycleEnd
    }
    
    $cycleTotalRequests = ($cycleRows | Measure-Object -Property Requests -Sum).Sum
    if (-not $cycleTotalRequests) { $cycleTotalRequests = 0 }
    
    $cyclePercentUsed = if ($BasePlanRequests -gt 0) { ($cycleTotalRequests / $BasePlanRequests) * 100 } else { 0 }
    $cycleRemaining = [Math]::Max(0, $BasePlanRequests - $cycleTotalRequests)
    
    $cycleAlertLevel = if ($cyclePercentUsed -ge 100) { "OVER" }
                       elseif ($cyclePercentUsed -ge 90) { "CRITICAL" }
                       elseif ($cyclePercentUsed -ge 70) { "WARNING" }
                       else { "OK" }
    
    # WINDOW 2: Calendar Month Overages (each month 1st to end)
    # Group by calendar month and calculate overage charges
    $monthlyOverages = $DailyRows | Group-Object { ([datetime]::ParseExact($_.Date, 'yyyy-MM-dd', $null)).ToString('yyyy-MM') } | ForEach-Object {
        $monthKey = $_.Name
        $monthRows = $_.Group
        $monthTotal = ($monthRows | Measure-Object -Property Requests -Sum).Sum
        if (-not $monthTotal) { $monthTotal = 0 }
        
        $overage = [Math]::Max(0, $monthTotal - $BasePlanRequests)
        $overageCost = $overage * $OveragePricePerRequest
        
        [PSCustomObject]@{
            Month = $monthKey
            TotalRequests = $monthTotal
            Overage = $overage
            Cost = $overageCost
        }
    } | Sort-Object Month
    
    $totalOverageCost = ($monthlyOverages | Measure-Object -Property Cost -Sum).Sum
    if (-not $totalOverageCost) { $totalOverageCost = 0 }
    
    $totalCost = $BasePlanPrice + $totalOverageCost
    
    return [PSCustomObject]@{
        BillingCycle = [PSCustomObject]@{
            Start = $cycleStart.ToString('yyyy-MM-dd')
            End = $cycleEnd.ToString('yyyy-MM-dd')
            TotalRequests = $cycleTotalRequests
            IncludedRequests = $BasePlanRequests
            PercentUsed = [Math]::Round($cyclePercentUsed, 2)
            Remaining = $cycleRemaining
            AlertLevel = $cycleAlertLevel
        }
        MonthlyOverages = $monthlyOverages
        TotalCost = [PSCustomObject]@{
            BasePlan = $BasePlanPrice
            TotalOverages = [Math]::Round($totalOverageCost, 2)
            GrandTotal = [Math]::Round($totalCost, 2)
        }
    }
}

function Convert-GitHubUsageReport($path) {
    # Converts GitHub's billing usage report CSV to simple Date,Requests format
    # GitHub format has columns: date, product, sku, quantity, unit_type, applied_cost_per_quantity, etc.
    # We want: Date, Requests (aggregated by date for all copilot SKUs)
    
    if (-not $path) { return $null }
    if (-not (Test-Path $path)) { 
        Write-Host "GitHub usage report CSV not found: $path" -ForegroundColor Yellow
        return $null 
    }
    
    try {
        Write-Host "Converting GitHub usage report format..." -ForegroundColor DarkCyan
        $rawData = Import-Csv $path
        
        # Filter for Copilot products only (both regular and coding agent)
        $copilotRows = $rawData | Where-Object { 
            $_.product -eq 'copilot' -and 
            ($_.sku -eq 'copilot_premium_request' -or $_.sku -eq 'coding_agent_premium_request')
        }
        
        if (-not $copilotRows) {
            Write-Host "No Copilot usage found in GitHub report" -ForegroundColor Yellow
            return $null
        }
        
        # Group by date and sum quantities
        $dailyAggregated = $copilotRows | Group-Object -Property date | ForEach-Object {
            $dateStr = $_.Name
            $totalRequests = ($_.Group | Measure-Object -Property quantity -Sum).Sum
            
            $d = $null
            try { 
                $d = [datetime]::ParseExact($dateStr, 'yyyy-MM-dd', $null) 
            } catch { 
                try { $d = [datetime]$dateStr } catch { $d = $null }
            }
            
            if ($d) {
                [PSCustomObject]@{
                    Date = $d.Date
                    Requests = [double]$totalRequests
                }
            }
        } | Where-Object { $_ -ne $null } | Sort-Object Date
        
        $totalCopilot = ($dailyAggregated | Measure-Object -Property Requests -Sum).Sum
        $dateRange = ($dailyAggregated | Measure-Object -Property Date -Minimum -Maximum)
        
        Write-Host "  ✓ Converted GitHub usage report" -ForegroundColor Green
        Write-Host "  ✓ Found $($dailyAggregated.Count) days with Copilot usage" -ForegroundColor Green
        Write-Host "  ✓ Date range: $($dateRange.Minimum.ToString('yyyy-MM-dd')) to $($dateRange.Maximum.ToString('yyyy-MM-dd'))\" -ForegroundColor Green
        Write-Host "  ✓ Total requests: $([math]::Round($totalCopilot, 2))\" -ForegroundColor Green
        
        return $dailyAggregated
        
    } catch {
        Write-Host "Failed to convert GitHub usage report: $_" -ForegroundColor Red
        return $null
    }
}

function Generate-DailyReport([datetime]$cycleStart, [datetime]$cycleEnd, $dailyRows, [int]$basePlanRequests, [double]$overagePrice, [double[]]$thresholds, [string]$outPath) {
    $days = ([int]($cycleEnd.Date - $cycleStart.Date).TotalDays) + 1
    $dateRange = for ($i=0; $i -lt $days; $i++) { $cycleStart.AddDays($i).Date }
    $rowsByDate = @{}
    foreach ($r in $dailyRows) { $rowsByDate[$r.Date.ToString('yyyy-MM-dd')] = $r.Requests }

    $cumulative = 0.0
    $out = @()
    for ($i=0; $i -lt $dateRange.Count; $i++) {
        $d = $dateRange[$i]
        $req = 0.0
        $key = $d.ToString('yyyy-MM-dd')
        if ($rowsByDate.ContainsKey($key)) { $req = [double]$rowsByDate[$key] }
        $cumulative += $req
        $daysRemaining = $dateRange.Count - ($i + 1)
        $remainingReq = [math]::Max(0.0, $basePlanRequests - $cumulative)
        if ($daysRemaining -gt 0) { $recommendedPerDay = [math]::Round($remainingReq / $daysRemaining,2) } else { $recommendedPerDay = $remainingReq }
        $percentOfBase = if ($basePlanRequests -gt 0) { $cumulative / $basePlanRequests } else { 0 }
        $alertObj = Evaluate-Alerts $cumulative $basePlanRequests $thresholds
        $row = [PSCustomObject]@{
            Date = $d.ToString('yyyy-MM-dd')
            Requests = $req
            Cumulative = [math]::Round($cumulative,2)
            PercentOfBase = [math]::Round($percentOfBase * 100,2)
            RecommendedRemainingPerDay = $recommendedPerDay
            AlertLevel = $alertObj.Level
            AlertMessage = $alertObj.Message
        }
        $out += $row
    }
    try {
        $out | Export-Csv -Path $outPath -NoTypeInformation -Force
        Write-Host "Daily usage report exported to $outPath" -ForegroundColor DarkCyan
    } catch { Write-Host "Failed to export daily report: $_" -ForegroundColor Red }
    return $out
}

# End of interactive-only section - close conditional opened near line 180
} # end if (-not $FetchMode)

# ========================================
# MODE 1: FETCH MODE - Comprehensive Billing Analysis
# ========================================
# Fetches GitHub/Copilot billing data and generates Excel-ready reports with:
# - Daily usage breakdown with alerts and pacing recommendations
# - Pattern analysis (steady/bursty/spiky usage detection)
# - Timing recommendations (when to schedule heavy workloads)
# - Cost optimization advice (plan comparison, overage warnings)
# - Comprehensive summary report for management review
# ========================================
if ($FetchMode) {
    Write-Host "" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  FETCH MODE: Comprehensive Billing Analysis" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    
    # Step 1: Fetch CSV data (GitHub usage report, custom CSV from GitHub, or local)
    Write-Host "[1/6] Fetching usage data..." -ForegroundColor Yellow
    $fetchedCsv = $null
    $isGitHubUsageReport = $false
    
    # Check if user provided GitHub's official usage report export
    if ($GitHubUsageReportCsv -and (Test-Path $GitHubUsageReportCsv)) {
        Write-Host "  ✓ Using GitHub usage report export: $GitHubUsageReportCsv" -ForegroundColor Green
        $dailyRows = Convert-GitHubUsageReport $GitHubUsageReportCsv
        if (-not $dailyRows) {
            Write-Host "  ✗ Failed to convert GitHub usage report" -ForegroundColor Red
            exit 1
        }
        # Skip to step 3 since we already have the data converted
        $isGitHubUsageReport = $true
    } elseif ($GitHubOwner -and $GitHubRepo -and $GitHubPath) {
        if ($PromptForToken) { Prompt-ForToken -envVarName $GitHubTokenEnvVar | Out-Null }
        $content = Get-GitHubFileContent -Owner $GitHubOwner -Repo $GitHubRepo -Path $GitHubPath -Branch $GitHubBranch -TokenEnvVar $GitHubTokenEnvVar
        if ($content) {
            $tmp = [System.IO.Path]::GetTempFileName()
            $tmpCsv = [System.IO.Path]::ChangeExtension($tmp, '.csv')
            Remove-Item $tmp -ErrorAction SilentlyContinue
            $tmpCsvFull = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetFileName($tmpCsv))
            Set-Content -Path $tmpCsvFull -Value $content -Encoding UTF8
            Write-Host "  ✓ Fetched from GitHub: $GitHubOwner/$GitHubRepo/$GitHubPath" -ForegroundColor Green
            $fetchedCsv = $tmpCsvFull
        } else {
            Write-Host "  ✗ Failed to fetch CSV from GitHub" -ForegroundColor Red
        }
    }
    if (-not $fetchedCsv -and $DailyUsageCsv -and (Test-Path $DailyUsageCsv)) {
        $fetchedCsv = $DailyUsageCsv
        Write-Host "  ✓ Using local CSV: $DailyUsageCsv" -ForegroundColor Green
    }
    if (-not $fetchedCsv -and -not $isGitHubUsageReport) {
        Write-Host "  ✗ FetchMode requires either -GitHubUsageReportCsv, GitHubOwner/Repo/Path, or a local -DailyUsageCsv" -ForegroundColor Red
        exit 1
    }

    # Step 2: Import and validate data (skip if already converted from GitHub usage report)
    if (-not $isGitHubUsageReport) {
        Write-Host "[2/6] Importing daily usage data..." -ForegroundColor Yellow
        $dailyRows = Import-DailyUsage $fetchedCsv
        if (-not $dailyRows) {
            Write-Host "  ✗ No valid daily rows found in CSV" -ForegroundColor Red
            exit 1
        }
        Write-Host "  ✓ Loaded $($dailyRows.Count) days of usage data" -ForegroundColor Green
        $dateRange = ($dailyRows | Measure-Object -Property Date -Minimum -Maximum)
        Write-Host "  ✓ Date range: $($dateRange.Minimum.ToString('yyyy-MM-dd')) to $($dateRange.Maximum.ToString('yyyy-MM-dd'))" -ForegroundColor Green
    } else {
        Write-Host "[2/6] Data already imported from GitHub usage report" -ForegroundColor Green
    }

    # Step 3: Determine cycle window
    Write-Host "[3/6] Analyzing billing cycle..." -ForegroundColor Yellow
    $givenDate = Get-Date
    $cycle = Get-CycleWindow $givenDate $CycleStartDay
    Write-Host "  ✓ Current cycle: $($cycle.Start.ToString('yyyy-MM-dd')) to $($cycle.End.ToString('yyyy-MM-dd'))" -ForegroundColor Green

    # Step 4: Generate daily report with alerts and pacing
    Write-Host "[4/6] Generating daily usage report with alerts..." -ForegroundColor Yellow
    $dailyReport = Generate-DailyReport -cycleStart $cycle.Start -cycleEnd $cycle.End -dailyRows $dailyRows -basePlanRequests $DefaultBasePlanRequests -overagePrice $OveragePricePerRequest -thresholds $AlertThresholds -outPath $DailyReportPath
    if ($dailyReport) {
        Write-Host "  ✓ Daily report exported: $DailyReportPath" -ForegroundColor Green
        $alertDays = $dailyReport | Where-Object { $_.AlertLevel -ne 'OK' }
        if ($alertDays) {
            Write-Host "  ⚠ Alert days detected: $($alertDays.Count) days with warnings/overages" -ForegroundColor Yellow
        }
    }

    # Step 5: Analyze usage patterns
    Write-Host "[5/6] Analyzing usage patterns and trends..." -ForegroundColor Yellow
    $patternAnalysis = Analyze-UsagePatterns -dailyRows $dailyRows -windowDays $PatternAnalysisWindowDays
    if ($patternAnalysis) {
        Write-Host "  ✓ Pattern: $($patternAnalysis.Pattern) | Trend: $($patternAnalysis.Trend)" -ForegroundColor Green
        Write-Host "  ✓ Avg daily: $($patternAnalysis.AverageDailyRequests) requests (StdDev: $($patternAnalysis.StdDeviation))" -ForegroundColor Green
        if ($patternAnalysis.SpikeDays.Count -gt 0) {
            Write-Host "  ⚠ Spike days: $($patternAnalysis.SpikeDays -join ', ')" -ForegroundColor Yellow
        }
    }

    # Step 6: Generate timing recommendations
    Write-Host "[6/6] Generating recommendations and comprehensive report..." -ForegroundColor Yellow
    $recommendations = Get-TimingRecommendations -patternAnalysis $patternAnalysis -cycleStart $cycle.Start -cycleStartDay $CycleStartDay -dailyRows $dailyRows -basePlanRequests $DefaultBasePlanRequests
    $comprehensiveSummary = Generate-ComprehensiveSummary -dailyRows $dailyRows -patternAnalysis $patternAnalysis -recommendations $recommendations -basePlanRequests $DefaultBasePlanRequests -basePlanPrice $BasePlanPrice -overagePrice $OveragePricePerRequest -cycleStart $cycle.Start -cycleEnd $cycle.End -outPath $ComprehensiveReportPath -cycleStartDay $CycleStartDay
    
    Write-Host "" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  FETCH MODE COMPLETE - Reports Generated" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    Write-Host "Generated Reports:" -ForegroundColor Green
    Write-Host "  1. Daily Report:         $DailyReportPath" -ForegroundColor White
    Write-Host "  2. Comprehensive Report: $ComprehensiveReportPath" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    
    # Display key findings with dual-window breakdown
    Write-Host "Key Findings:" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    
    $currentDate = Get-Date
    $dualCosts = Calculate-DualWindowCosts -DailyRows $dailyRows -CurrentDate $currentDate -BasePlanRequests $DefaultBasePlanRequests -OveragePricePerRequest $OveragePricePerRequest -BasePlanPrice $BasePlanPrice
    
    Write-Host "  BILLING CYCLE ($($dualCosts.BillingCycle.Start) to $($dualCosts.BillingCycle.End)):" -ForegroundColor Yellow
    Write-Host "    • Total Requests:     $([math]::Round($dualCosts.BillingCycle.TotalRequests, 2)) / $($dualCosts.BillingCycle.IncludedRequests) included" -ForegroundColor White
    Write-Host "    • Percent Used:       $($dualCosts.BillingCycle.PercentUsed)%" -ForegroundColor $(if ($dualCosts.BillingCycle.PercentUsed -ge 100) { 'Red' } elseif ($dualCosts.BillingCycle.PercentUsed -ge 90) { 'Yellow' } else { 'Green' })
    Write-Host "    • Remaining Quota:    $([math]::Round($dualCosts.BillingCycle.Remaining, 2)) requests" -ForegroundColor $(if ($dualCosts.BillingCycle.Remaining -le 0) { 'Red' } else { 'Green' })
    Write-Host "    • Alert Level:        $($dualCosts.BillingCycle.AlertLevel)" -ForegroundColor $(switch ($dualCosts.BillingCycle.AlertLevel) { 'OK' { 'Green' } 'WARNING' { 'Yellow' } 'CRITICAL' { 'Red' } 'OVER' { 'Red' } default { 'White' } })
    Write-Host "" -ForegroundColor White
    
    Write-Host "  MONTHLY OVERAGE COSTS (Calendar Month):" -ForegroundColor Yellow
    if ($dualCosts.MonthlyOverages -and $dualCosts.MonthlyOverages.Count -gt 0) {
        foreach ($monthData in $dualCosts.MonthlyOverages) {
            if ($monthData.Overage -gt 0) {
                Write-Host "    • $($monthData.Month):          $([math]::Round($monthData.TotalRequests, 2)) total | $([math]::Round($monthData.Overage, 2)) overage = `$$($monthData.Cost.ToString('N2'))" -ForegroundColor Red
            } else {
                Write-Host "    • $($monthData.Month):          $([math]::Round($monthData.TotalRequests, 2)) total | No overage" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "    • No overage charges" -ForegroundColor Green
    }
    Write-Host "" -ForegroundColor White
    
    Write-Host "  TOTAL COSTS:" -ForegroundColor Yellow
    Write-Host "    • Base Plan:          `$$($dualCosts.TotalCost.BasePlan.ToString('N2')) /month" -ForegroundColor White
    Write-Host "    • Total Overages:     `$$($dualCosts.TotalCost.TotalOverages.ToString('N2'))" -ForegroundColor $(if ($dualCosts.TotalCost.TotalOverages -gt 0) { 'Red' } else { 'Green' })
    Write-Host "    • GRAND TOTAL:        `$$($dualCosts.TotalCost.GrandTotal.ToString('N2'))" -ForegroundColor $(if ($dualCosts.TotalCost.GrandTotal -gt 20) { 'Red' } else { 'Green' })
    Write-Host "" -ForegroundColor White
    
    Write-Host "  Usage Pattern:" -ForegroundColor Yellow
    Write-Host "    • Pattern:            $($patternAnalysis.Pattern)" -ForegroundColor White
    Write-Host "    • Trend:              $($patternAnalysis.Trend)" -ForegroundColor White
    Write-Host "    • Avg Daily:          $($patternAnalysis.AverageDailyRequests) requests" -ForegroundColor White
    Write-Host "    • Variability:        $($patternAnalysis.CoefficientOfVariation) (CV)" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    
    Write-Host "  Top Recommendations:" -ForegroundColor Yellow
    $topRecs = $recommendations | Select-Object -First 3
    for ($i = 0; $i -lt $topRecs.Count; $i++) {
        Write-Host "    $($i + 1). $($topRecs[$i])" -ForegroundColor White
    }
    Write-Host "" -ForegroundColor White
    Write-Host "Open the generated CSV files in Excel for detailed analysis." -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    
    # Exit after FetchMode completes (don't run interactive mode)
    exit 0
}
# ========================================
# MODE 2: DAILY-USE MODE - Interactive Planning
# ========================================
# Quick interactive mode for daily usage planning and forecasting.
# Prompts for today's usage and provides immediate recommendations.
# Use this mode when you want to check if you're on track today.
# ========================================
# (Daily-use mode continues with the existing interactive logic below)

if ($FetchBilling) {
    # Ensure token is present or prompt for one-time token
    $tokenWasSet = $false
    if ($PromptForToken) { $ok = Prompt-ForToken -envVarName $GitHubTokenEnvVar; if ($ok) { $tokenWasSet = $true } }
    if (-not (Get-ChildItem Env: | Where-Object { $_.Name -eq $GitHubTokenEnvVar })) { Write-Host 'Warning: no token found in env; PromptForToken recommended for private/org billing.' -ForegroundColor Yellow }
    if (-not $BillingOrg) { Write-Host 'BillingOrg not specified; use -BillingOrg <orgname>' -ForegroundColor Red } else {
        Get-OrgBillingInvoices -Org $BillingOrg -TokenEnvVar $GitHubTokenEnvVar -OutPath $BillingOutPath | Out-Null
    }
    if ($tokenWasSet) { [System.Environment]::SetEnvironmentVariable($GitHubTokenEnvVar, $null, 'Process') }
}

# Wire up evaluation + optional export
try {
    $cycle = Get-CycleWindow $givenDate $CycleStartDay
    $timeline = Render-TimelineASCII $givenDate $CycleStartDay
    $alerts = Evaluate-Alerts $requestsMonth $basePlanRequests $AlertThresholds
    $recommend = Suggest-Actions $alerts $requestsMonth $basePlanRequests $CycleStartDay
    Write-Host "\n-- Checklist & Quick Rules --" -ForegroundColor DarkMagenta
    Write-Host "- Track both windows: Seat cycle ($CycleStartDay→$((($CycleStartDay+29) % 31)+1)) and calendar months." -ForegroundColor White
    Write-Host "- Alerts: 70% (warning), 90% (critical), 100% (overage)." -ForegroundColor White
    Write-Host "- When WARNING: slow non-essential jobs; when CRITICAL: stop non-essential; when OVER: accept cost or upgrade plan." -ForegroundColor White
    Write-Host "- Prefer heavy jobs on cycle days shortly after the $CycleStartDay (early-cycle)." -ForegroundColor White

    Write-Host "\n-- Alert Summary --" -ForegroundColor DarkMagenta
    Write-Host ("Percent of base plan used: {0:P2}" -f $alerts.Percent) -ForegroundColor Yellow
    Write-Host ("Level: {0} - {1}" -f $alerts.Level, $alerts.Message) -ForegroundColor (if ($alerts.Level -eq 'OK') {'Green'} elseif ($alerts.Level -eq 'WARNING') {'Yellow'} elseif ($alerts.Level -eq 'CRITICAL') {'DarkYellow'} else {'Red'})
    Write-Host ("Recommendation: {0}" -f $recommend) -ForegroundColor Cyan

    if ($ExportCsv) {
        $row = @{
            GivenDate = $givenDate.ToString('yyyy-MM-dd')
            RequestsMonth = $requestsMonth
            RequestsToday = $requestsToday
            CycleStart = $cycle.Start.ToString('yyyy-MM-dd')
            CycleEnd = $cycle.End.ToString('yyyy-MM-dd')
            PercentOfBase = [math]::Round($alerts.Percent,4)
            AlertLevel = $alerts.Level
            Recommendation = $recommend
        }
        Export-UsageCsv -path $ExportPath -row $row
    }
    # If user provided a daily usage CSV, build the per-day report for the cycle
    if ($DailyUsageCsv -or ($GitHubOwner -and $GitHubRepo -and $GitHubPath)) {
        # If GitHub parameters provided, fetch remote CSV and write to temp file
        if ($GitHubOwner -and $GitHubRepo -and $GitHubPath) {
            $tokenWasSetByPrompt = $false
            if ($PromptForToken) {
                $ok = Prompt-ForToken -envVarName $GitHubTokenEnvVar
                if ($ok) { $tokenWasSetByPrompt = $true }
            }
            $content = Get-GitHubFileContent -Owner $GitHubOwner -Repo $GitHubRepo -Path $GitHubPath -Branch $GitHubBranch -TokenEnvVar $GitHubTokenEnvVar
            if ($content) {
                $tmp = [System.IO.Path]::GetTempFileName()
                $tmpCsv = [System.IO.Path]::ChangeExtension($tmp, '.csv')
                Remove-Item $tmp -ErrorAction SilentlyContinue
                $tmpCsvFull = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetFileName($tmpCsv))
                Set-Content -Path $tmpCsvFull -Value $content -Encoding UTF8
                Write-Host ("Fetched GitHub file to {0}" -f $tmpCsvFull) -ForegroundColor DarkCyan
                $DailyUsageCsv = $tmpCsvFull
            } else { Write-Host 'Unable to fetch remote GitHub CSV; skipping daily report.' -ForegroundColor Yellow }
            if ($tokenWasSetByPrompt) { [System.Environment]::SetEnvironmentVariable($GitHubTokenEnvVar, $null, 'Process') }
        }

        if ($DailyUsageCsv) {
            $dailyRows = Import-DailyUsage $DailyUsageCsv
            if ($dailyRows) {
                $report = Generate-DailyReport -cycleStart $cycle.Start -cycleEnd $cycle.End -dailyRows $dailyRows -basePlanRequests $DefaultBasePlanRequests -overagePrice $OveragePricePerRequest -thresholds $AlertThresholds -outPath $DailyReportPath
                # Print a short summary
                Write-Host "\nDaily report summary (first/last rows):" -ForegroundColor DarkMagenta
                $report | Select-Object -First 3 | Format-Table -AutoSize
                Write-Host "..." -ForegroundColor DarkCyan
                $report | Select-Object -Last 3 | Format-Table -AutoSize
            }
        }
    }
} catch {
    Write-Host "Error running enhanced outputs: $_" -ForegroundColor Red
}

function Show-ExampleScenarios() {
    Write-Host "\n=== Example Scenarios ===" -ForegroundColor Cyan

    # Scenario 1: Steady usage (150/300) - OK
    $gdate = Get-Date -Year 2026 -Month 2 -Day 2
    $req = 150.0
    $cycle = Get-CycleWindow $gdate $CycleStartDay
    $alerts = Evaluate-Alerts $req $DefaultBasePlanRequests $AlertThresholds
    $recommend = Suggest-Actions $alerts $req $DefaultBasePlanRequests $CycleStartDay
    Write-Host "\nScenario: Steady usage" -ForegroundColor Green
    Write-Host (" Given date: {0:yyyy-MM-dd}  Requests MTD: {1:N0} ({2:P2} of {3})" -f $gdate, $req, ($req / $DefaultBasePlanRequests), $DefaultBasePlanRequests) -ForegroundColor Yellow
    Write-Host (" Alert Level: {0}  Message: {1}" -f $alerts.Level, $alerts.Message) -ForegroundColor White
    Write-Host (" Recommendation: {0}" -f $recommend) -ForegroundColor Cyan

    # Scenario 2: Burst (320/300) - OVER
    $gdate2 = Get-Date -Year 2026 -Month 2 -Day 10
    $req2 = 320.0
    $cycle2 = Get-CycleWindow $gdate2 $CycleStartDay
    $alerts2 = Evaluate-Alerts $req2 $DefaultBasePlanRequests $AlertThresholds
    $recommend2 = Suggest-Actions $alerts2 $req2 $DefaultBasePlanRequests $CycleStartDay
    $over = [math]::Max(0, $req2 - $DefaultBasePlanRequests)
    $cost = $over * $OveragePricePerRequest
    Write-Host "\nScenario: Burst / possible overage" -ForegroundColor Red
    Write-Host (" Given date: {0:yyyy-MM-dd}  Requests MTD: {1:N0} ({2:P2} of {3})" -f $gdate2, $req2, ($req2 / $DefaultBasePlanRequests), $DefaultBasePlanRequests) -ForegroundColor Yellow
    Write-Host (" Alert Level: {0}  Message: {1}" -f $alerts2.Level, $alerts2.Message) -ForegroundColor White
    Write-Host (" Overage: {0} requests → approx ${1:N2}" -f $over, $cost) -ForegroundColor Magenta
    Write-Host (" Recommendation: {0}" -f $recommend2) -ForegroundColor Cyan
}

if ($ShowExamples) { Show-ExampleScenarios }

Write-Host "Done." -ForegroundColor Cyan
try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $lastInputsPath = Join-Path $scriptDir '.aicost_last_inputs.json'
    $save = @{ 
        requestsMonth = $requestsMonth
        basePlanRequests = $basePlanRequests
        givenDate = $givenDate.ToString('yyyy-MM-dd')
        BasePlanPrice = $BasePlanPrice
        OveragePricePerRequest = $OveragePricePerRequest
        MonthlyBudget = $MonthlyBudget
        HoursPerWorkday = $HoursPerWorkday
    }
    $save | ConvertTo-Json | Out-File -FilePath $lastInputsPath -Encoding UTF8
    Write-Host "Saved inputs to $lastInputsPath" -ForegroundColor DarkCyan
} catch {
    # ignore save failures
}
# forecast_full.ps1
# Prompts:
#  - Start time (HH:mm)
#  - Current clock time (HH:mm) (or leave blank to use system current time)
#  - Requests so far today (number, decimals allowed)
#  - Requests month-to-date (number, decimals allowed)
#  - Full date (YYYY-MM-DD)
$cmpCount = 0
Write-Host "-- Comparisons & Alerts --" -ForegroundColor DarkMagenta
if ($projectedMonthlyFromTodayRate -ne $null) {
    $diff = $projectedMonthlyFromTodayRate - $monthlyTargetRequests
    if ($diff -gt 0) { $m = ("ALERT: Today's-rate projection exceeds monthly target by {0:N0} requests" -f $diff); Write-Host $m -ForegroundColor Red; $cmpCount++ } else { $m = ("OK: Today's-rate projection is {0:N0} requests below monthly target" -f ([math]::Abs($diff))); Write-Host $m -ForegroundColor Green }
}

$diffCurrent = $projectedMonthlyFromCurrentRate - $monthlyTargetRequests
if ($diffCurrent -gt 0) { $m = ("WARN: Current-rate projection exceeds monthly target by {0:N0} requests" -f $diffCurrent); Write-Host $m -ForegroundColor Yellow; $cmpCount++ } else { $m = ("OK: Current-rate projection is {0:N0} requests below monthly target" -f ([math]::Abs($diffCurrent))); Write-Host $m -ForegroundColor Green }

if ($projectedCostFromTodayRate -ne $null) {
    $costDiff = $projectedCostFromTodayRate - $MonthlyBudget
    if ($costDiff -gt 0) { $m = ("ALERT: Projected monthly cost (today's rate) exceeds budget by {0:N2}" -f $costDiff); Write-Host $m -ForegroundColor Red; $cmpCount++ } else { $m = ("OK: Projected monthly cost (today's rate) is {0:N2} below budget" -f ([math]::Abs($costDiff))); Write-Host $m -ForegroundColor Green }
}

$costDiffCur = $projectedCostFromCurrentRate - $MonthlyBudget
if ($costDiffCur -gt 0) { $m = ("WARN: Projected monthly cost (current rate) exceeds budget by {0:N2}" -f $costDiffCur); Write-Host $m -ForegroundColor Yellow; $cmpCount++ } else { $m = ("OK: Projected monthly cost (current rate) is {0:N2} below budget" -f ([math]::Abs($costDiffCur))); Write-Host $m -ForegroundColor Green }

if ($cmpCount -eq 0) { Write-Host "No alerts - projections are within targets/budget." -ForegroundColor Cyan }

# Explanation: why Today and Current projections can differ
Write-Host "" -ForegroundColor White
Write-Host "-- Why Today vs Current may differ --" -ForegroundColor DarkMagenta
Write-Host "Today is a short-term run-rate (requests today / elapsed hours)." -ForegroundColor White
Write-Host "Current is the month-to-date average (total requestsMonth / hours worked so far)." -ForegroundColor White
Write-Host "Consequences:" -ForegroundColor Yellow
Write-Host " - A high burst today can make the Today-based projection exceed the monthly target even if the historical Current rate remains below it." -ForegroundColor Yellow
Write-Host " - The Recommendation (Allowed) is computed from remaining requests divided by remaining hours — it's the average rate you must hold from now on to hit the monthly target." -ForegroundColor Yellow
Write-Host " - Use Today for immediate throttling decisions; use Current to understand the overall trend." -ForegroundColor Yellow

# Recommendation: compute allowed average hourly rate for remaining work hours to stay within monthly target
$remainingWorkingHours = ($daysLeftWorking * $HoursPerWorkday) + $hoursRemainingToday
if ($remainingWorkingHours -le 0) { $allowedHourlyRateForRemaining = 0 } else { $allowedHourlyRateForRemaining = $remainingMonthlyRequests / $remainingWorkingHours }
$allowedDailyEquivalent = $allowedHourlyRateForRemaining * $HoursPerWorkday

# Show recommendation and color it red if current hourly rate or today's hourly rate exceed allowable
$recColor = 'Green'
if ($currentHourlyRate -gt $allowedHourlyRateForRemaining) { $recColor = 'Red' }
if ($todayHourlyRate -ne $null -and $todayHourlyRate -gt $allowedHourlyRateForRemaining) { $recColor = 'Red' }
$recLine = ("Recommendation: To stay within monthly target, average ≤ {0:N2} req/hr for remaining work hours (~ {1:N2} req/day)" -f $allowedHourlyRateForRemaining, $allowedDailyEquivalent)
Write-Host $recLine -ForegroundColor $recColor

# Per-hour throttle recommendation for the remainder of today
if ($hoursRemainingToday -gt 0) {
    $allowedHourlyToday = $remainingMonthlyRequests / $hoursRemainingToday
    # Conservative suggestion: min of allowedHourlyRateForRemaining and allowedHourlyToday
    $throttleRec = [math]::Min($allowedHourlyRateForRemaining, $allowedHourlyToday)
    $throttleColor = 'Green'
    if ($todayHourlyRate -ne $null -and $throttleRec -lt $todayHourlyRate) { $throttleColor = 'Red' }
    # If the throttle recommendation is effectively the same as the overall allowed hourly rate, skip duplicate line
    if ([math]::Abs($throttleRec - $allowedHourlyRateForRemaining) -ge 0.01) {
        $thLine = ("Throttle recommendation (remainder of today): limit to ≤ {0:N2} req/hr" -f $throttleRec)
        Write-Host $thLine -ForegroundColor $throttleColor
    }
}

# Simple ASCII bar graph comparing allowed vs current vs today's hourly rates
if ($todayHourlyRate -ne $null) { $todayRateVal = $todayHourlyRate } else { $todayRateVal = 0.0 }
# Nested Max and guard against non-finite values
$graphMax = [math]::Max([math]::Max([math]::Max($allowedHourlyRateForRemaining, $currentHourlyRate), $todayRateVal), 1.0)
if ([double]::IsInfinity($graphMax) -or [double]::IsNaN($graphMax) -or $graphMax -le 0) { $graphMax = 1.0 }

function Get-Bar([double]$val, [double]$max) {
    $width = 40
    if ([double]::IsInfinity($val) -or [double]::IsNaN($val)) { $val = 0.0 }
    if ([double]::IsInfinity($max) -or [double]::IsNaN($max) -or $max -le 0) { $max = 1.0 }
    $ratio = $val / $max
    if ([double]::IsInfinity($ratio) -or [double]::IsNaN($ratio)) { $ratio = 0.0 }
    $len = [int]([math]::Round($ratio * $width))
    if ($len -lt 0) { $len = 0 }
    if ($len -gt $width) { $len = $width }
    return ('=' * $len) + (' ' * ($width - $len))
}

Write-Host "" -ForegroundColor White
Write-Host "-- Rate Comparison (req/hr) --" -ForegroundColor DarkCyan
Write-Host "Legend:" -ForegroundColor DarkCyan
Write-Host "  - Allowed : avg req/hr you can sustain for all remaining work hours (green)" -ForegroundColor Green
Write-Host "  - Current : month-to-date average req/hr so far (yellow)" -ForegroundColor Yellow
Write-Host "  - Today   : current day's run-rate (req/hr) - noisy early; turns red if above Allowed" -ForegroundColor Cyan

$allowedLine = ('Allowed  : [{0}] {1:N2} req/hr' -f (Get-Bar $allowedHourlyRateForRemaining $graphMax), $allowedHourlyRateForRemaining)
Write-Host $allowedLine -ForegroundColor Green
$currentLine = ('Current  : [{0}] {1:N2} req/hr' -f (Get-Bar $currentHourlyRate $graphMax), $currentHourlyRate)
Write-Host $currentLine -ForegroundColor Yellow
if ($todayHourlyRate -ne $null) {
    $todayColor = 'Cyan'
    # Use a small tolerance to avoid floating-point rounding hiding slight overruns
    if ($todayHourlyRate -gt ($allowedHourlyRateForRemaining + 0.0001)) { $todayColor = 'Red' }
    $todayLine = ('Today    : [{0}] {1:N2} req/hr' -f (Get-Bar $todayHourlyRate $graphMax), $todayHourlyRate)
    Write-Host $todayLine -ForegroundColor $todayColor
}
Write-Host "====================================" -ForegroundColor Cyan


function Get-NthWeekdayOfMonth($year, $month, $weekdayName, $n) {
    $first = Get-Date -Year $year -Month $month -Day 1
    $weekday = [System.DayOfWeek]::Parse([System.DayOfWeek], $weekdayName)
    $offset = ( ([int]$weekday - [int]$first.DayOfWeek) + 7 ) % 7
    $day = 1 + $offset + 7 * ($n - 1)
    return (Get-Date -Year $year -Month $month -Day $day).Date
}

function Get-LastWeekdayOfMonth($year, $month, $weekdayName) {
    $days = [datetime]::DaysInMonth($year, $month)
    for ($d = $days; $d -ge 1; $d--) {
        $dt = Get-Date -Year $year -Month $month -Day $d
        if ($dt.DayOfWeek -eq ([System.DayOfWeek]::Parse([System.DayOfWeek], $weekdayName))) {
            return $dt.Date
        }
    }
}

# --- Workday helpers ---
function Get-WorkdaysInMonth($year, $month, $holidays) {
    $count = 0
    $days = [datetime]::DaysInMonth($year, $month)
    for ($d = 1; $d -le $days; $d++) {
        $dt = Get-Date -Year $year -Month $month -Day $d
        if ($dt.DayOfWeek -ne 'Saturday' -and $dt.DayOfWeek -ne 'Sunday' -and -not ($holidays -contains $dt.Date)) {
            $count++
        }
    }
    return $count
}

function Get-CompletedWorkdays($year, $month, $day, $holidays) {
    $count = 0
    for ($d = 1; $d -le $day; $d++) {
        $dt = Get-Date -Year $year -Month $month -Day $d
        if ($dt.DayOfWeek -ne 'Saturday' -and $dt.DayOfWeek -ne 'Sunday' -and -not ($holidays -contains $dt.Date)) {
            $count++
        }
    }
    return $count
}

# --- Prepare dates/holidays ---
$year = $givenDate.Year
$month = $givenDate.Month
$dayOfMonth = $givenDate.Day

$holidays = Get-USFederalHolidays $year
# Filter holidays to this month for display/calculation convenience
$holThisMonth = $holidays | Where-Object { $_.Month -eq $month }

$workdaysInMonth = Get-WorkdaysInMonth $year $month $holidays
$completedWorkdays = Get-CompletedWorkdays $year $month $dayOfMonth $holidays
$daysLeftWorking = [math]::Max(0, $workdaysInMonth - $completedWorkdays)

# --- End-of-day calculation ---
$startH = ToHours($startDt)
$endOfDayH = $startH + $HoursPerWorkday
if ($endOfDayH -ge 24) { $endOfDayH = 23.999 }
# Build end time as HH:mm
$endHour = [int]([math]::Floor($endOfDayH))
$endMinute = [int]([math]::Floor((($endOfDayH - $endHour) * 60)))
$endDt = Get-Date -Year $givenDate.Year -Month $givenDate.Month -Day $givenDate.Day -Hour $endHour -Minute $endMinute -Second 0

# --- Calculations ---
# Determine elapsed so far using times on the same reference day
# Normalize start and current to same date (use givenDate)
$startRef = Get-Date -Year $givenDate.Year -Month $givenDate.Month -Day $givenDate.Day -Hour $startDt.Hour -Minute $startDt.Minute -Second 0
$currentRef = Get-Date -Year $givenDate.Year -Month $givenDate.Month -Day $givenDate.Day -Hour $currentDt.Hour -Minute $currentDt.Minute -Second 0

# If current time is earlier than start, assume current is next day? For simplicity cap elapsed at 0
$currentHours = ToHours($currentRef)
$elapsedSoFar = [math]::Max(0.0, $currentHours - $startH)
$hoursRemainingToday = [math]::Max(0.0, $HoursPerWorkday - $elapsedSoFar)

# Monthly budget math
$allowedOverage = [math]::Max(0.0, $MonthlyBudget - $BasePlanPrice)
$allowedExtraRequests = [math]::Floor($allowedOverage / $OveragePricePerRequest)
$monthlyTargetRequests = $basePlanRequests + $allowedExtraRequests
$remainingMonthlyRequests = [math]::Max(0.0, $monthlyTargetRequests - $requestsMonth)

if ($daysLeftWorking -gt 0) {
    $projectedDailyNeeded = [math]::Ceiling($remainingMonthlyRequests / $daysLeftWorking)
} else {
    $projectedDailyNeeded = $remainingMonthlyRequests
}

# Today's remaining requests target = projectedDailyNeeded - requestsToday (not negative)
$todayRemainingRequests = [math]::Max(0.0, $projectedDailyNeeded - $requestsToday)
if ($hoursRemainingToday -gt 0) {
    $projectedHourlyNeededToday = [math]::Ceiling($todayRemainingRequests / $hoursRemainingToday)
} else {
    $projectedHourlyNeededToday = 0
}

# Current hourly rate = requestsMonth-to-date divided by total worked hours so far (completedWorkdays-1 full days + elapsedSoFar)
$workedFullDays = [math]::Max(0, $completedWorkdays - 1)
$workedHoursSoFar = ($workedFullDays * $HoursPerWorkday) + $elapsedSoFar
if ($workedHoursSoFar -le 0) { $currentHourlyRate = 0 } else { $currentHourlyRate = $requestsMonth / $workedHoursSoFar }

# projection from current month-average rate
$projectedMonthlyFromCurrentRate = $currentHourlyRate * $HoursPerWorkday * $workdaysInMonth

# (menu removed here; input-mode menu appears earlier before calculations)

# --- Additional metrics ---
# Cost to date: base price plus overage if month-to-date exceeds base plan
if ($requestsMonth -le $basePlanRequests) {
    $costToDate = $BasePlanPrice
} else {
    $costToDate = $BasePlanPrice + (($requestsMonth - $basePlanRequests) * $OveragePricePerRequest)
}

# Remaining average requests needed per remaining working day
if ($daysLeftWorking -gt 0) {
    $remainingAvgPerWorkday = $remainingMonthlyRequests / $daysLeftWorking
} else {
    $remainingAvgPerWorkday = $remainingMonthlyRequests
}

# Current daily rate estimated from current hourly rate
$currentDailyFromRate = $currentHourlyRate * $HoursPerWorkday

# Projected cost if current rate continues for the month
if ($projectedMonthlyFromCurrentRate -le $basePlanRequests) {
    $projectedCostFromCurrentRate = $BasePlanPrice
} else {
    $projectedCostFromCurrentRate = $BasePlanPrice + (($projectedMonthlyFromCurrentRate - $basePlanRequests) * $OveragePricePerRequest)
}

# If we haven't computed a today's-based projection yet, but we do have requestsToday and elapsedSoFar,
# derive today's hourly rate and projection so we can display it in the summary.
if (($projectedMonthlyFromTodayRate -eq $null) -and ($requestsToday -gt 0) -and ($elapsedSoFar -gt 0)) {
    $todayHourlyRate = $requestsToday / $elapsedSoFar
    $currentDailyFromRate_today = $todayHourlyRate * $HoursPerWorkday
    $projectedMonthlyFromTodayRate = $todayHourlyRate * $HoursPerWorkday * $workdaysInMonth
}

# Projected cost if today's rate continues for the month (when available)
if ($projectedMonthlyFromTodayRate -ne $null) {
    if ($projectedMonthlyFromTodayRate -le $basePlanRequests) { $projectedCostFromTodayRate = $BasePlanPrice } else { $projectedCostFromTodayRate = $BasePlanPrice + (($projectedMonthlyFromTodayRate - $basePlanRequests) * $OveragePricePerRequest) }
} else { $projectedCostFromTodayRate = $null }

# --- Output (structured & colorized) ---
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "==== Forecast Summary ====" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

Write-Host "-- Input / Time --" -ForegroundColor DarkCyan
$s = ("Given date: {0:yyyy-MM-dd}" -f $givenDate)
Write-Host $s -ForegroundColor Yellow
$s = ("Start: {0:HH:mm}   Current: {1:HH:mm}   End-of-day: {2:HH:mm}" -f $startDt, $currentRef, $endDt)
Write-Host $s -ForegroundColor White
$s = ("Elapsed today (hrs): {0:N2}   Hours remaining today: {1:N2}" -f $elapsedSoFar, $hoursRemainingToday)
Write-Host $s -ForegroundColor White
Write-Host "" -ForegroundColor White

Write-Host "-- Usage --" -ForegroundColor DarkCyan
 $s = ("Requests month-to-date: {0:N2}" -f $requestsMonth)
 Write-Host $s -ForegroundColor Green
 $s = ("Requests today (computed): {0:N2}" -f $requestsToday)
 Write-Host $s -ForegroundColor Green
Write-Host "" -ForegroundColor White

Write-Host "-- Workdays / Holidays --" -ForegroundColor DarkCyan
$s = ("Day of month: {0}   Workdays this month: {1}   Completed: {2}   Left: {3}" -f $dayOfMonth, $workdaysInMonth, $completedWorkdays, $daysLeftWorking)
Write-Host $s -ForegroundColor Yellow
$s = ("US federal holidays this month: {0}" -f (($holThisMonth | ForEach-Object { ([datetime]$_).ToString('yyyy-MM-dd') }) -join ', '))
Write-Host $s -ForegroundColor DarkCyan
Write-Host "" -ForegroundColor White

Write-Host "-- Budget / Plan --" -ForegroundColor DarkCyan
$s = ('Base plan requests: {0}   Base plan price: ${1:N2}' -f $basePlanRequests, $BasePlanPrice)
Write-Host $s -ForegroundColor Green
$s = ('Overage price/request: ${0:N2}   Monthly budget cap: ${1:N2}' -f $OveragePricePerRequest, $MonthlyBudget)
Write-Host $s -ForegroundColor Green
$s = ('Allowed extra requests under budget: {0}' -f $allowedExtraRequests)
Write-Host $s -ForegroundColor Yellow
$s = ('Monthly target requests to stay ≤ budget: {0}' -f $monthlyTargetRequests)
Write-Host $s -ForegroundColor Yellow
$s = ('Remaining monthly requests available: {0:N2}' -f $remainingMonthlyRequests)
Write-Host $s -ForegroundColor Green
$s = ('Cost to date: ${0:N2}' -f $costToDate)
Write-Host $s -ForegroundColor Green
$projCurColor = 'Yellow'
if ($projectedCostFromCurrentRate -gt $MonthlyBudget) { $projCurColor = 'Red' }
Write-Host ('Projected monthly cost (from month-average rate): ${0:N2}' -f $projectedCostFromCurrentRate) -ForegroundColor $projCurColor
Write-Host "" -ForegroundColor White

if ($projectedMonthlyFromTodayRate -ne $null) {
    Write-Host "-- Today's Run Projection --" -ForegroundColor DarkCyan
    $s = ("Requests so far today: {0:N2}   Hourly rate (req/hr): {1:N2}" -f $requestsToday, $todayHourlyRate)
    Write-Host $s -ForegroundColor White
    $s = ("Projected monthly requests if today's rate continues: {0:N0}" -f $projectedMonthlyFromTodayRate)
    Write-Host $s -ForegroundColor Yellow
    $projTodayColor = 'Yellow'
    if ($projectedCostFromTodayRate -gt $MonthlyBudget) { $projTodayColor = 'Red' }
    Write-Host ('Projected monthly cost if today''s rate continues: ${0:N2}' -f $projectedCostFromTodayRate) -ForegroundColor $projTodayColor
    Write-Host "" -ForegroundColor White
}

Write-Host "-- Projections & Targets --" -ForegroundColor DarkCyan
$s = ('Projected monthly requests if current rate continues: {0:N0}' -f $projectedMonthlyFromCurrentRate)
Write-Host $s -ForegroundColor Yellow
$s = ('Projected daily requests needed (remaining workdays): {0}' -f $projectedDailyNeeded)
Write-Host $s -ForegroundColor Yellow
$s = ('Today''s remaining requests to hit daily target: {0:N2}' -f $todayRemainingRequests)
Write-Host $s -ForegroundColor Yellow
$s = ('Projected hourly requests needed for rest of today: {0}' -f $projectedHourlyNeededToday)
Write-Host $s -ForegroundColor Yellow

# Extra clarity: today vs daily target, and projected monthly vs monthly target (today-based)
$deltaTodayVsDailyTarget = $requestsToday - $projectedDailyNeeded
if ($deltaTodayVsDailyTarget -gt 0) { $deltaMsg = ('Today vs daily target: +{0:N2} requests (over target)' -f $deltaTodayVsDailyTarget); $deltaColor='Red' } else { $deltaMsg = ('Today vs daily target: {0:N2} requests (under target)' -f $deltaTodayVsDailyTarget); $deltaColor='Green' }
Write-Host $deltaMsg -ForegroundColor $deltaColor

if ($projectedMonthlyFromTodayRate -ne $null) {
    $diffTodayMonthly = [math]::Round($projectedMonthlyFromTodayRate - $monthlyTargetRequests,0)
    if ($diffTodayMonthly -gt 0) { $diffMsg = ('Projected monthly vs target (today-rate): +{0:N0} requests (over)' -f $diffTodayMonthly); $diffColor='Red' } else { $diffMsg = ('Projected monthly vs target (today-rate): {0:N0} requests (below)' -f [math]::Abs($diffTodayMonthly)); $diffColor='Green' }
    Write-Host $diffMsg -ForegroundColor $diffColor
}
Write-Host "" -ForegroundColor White

# Purple alert: tracking to go over monthly budget (today-based projection)
$overBudget = $null
if ($projectedCostFromTodayRate -ne $null) { $overBudget = [math]::Round($projectedCostFromTodayRate - $MonthlyBudget,2) }
if ($overBudget -ne $null -and $overBudget -gt 0) {
    $m = ('Tracking: projected monthly cost (today-rate) is ${0:N2} OVER budget' -f $overBudget)
    Write-Host $m -ForegroundColor Magenta
    # Also show the projected total and breakdown (budget + overage)
    $totalProjected = [math]::Round($projectedCostFromTodayRate,2)
    $detail = ('Projected total monthly cost: ${0:N2} (Budget ${1:N2} + Overage ${2:N2})' -f $totalProjected, $MonthlyBudget, $overBudget)
    Write-Host $detail -ForegroundColor Magenta
}

# Evaluate whether switching plans is cheaper than staying on projected overage
if ($projectedMonthlyFromTodayRate -ne $null) {
    $stayCost = $projectedCostFromTodayRate
    if ($projectedMonthlyFromTodayRate -le $Plan1500Requests) { $cost1500 = $Plan1500Price } else { $cost1500 = $Plan1500Price + (($projectedMonthlyFromTodayRate - $Plan1500Requests) * $OveragePricePerRequest) }
    if ($projectedMonthlyFromTodayRate -le $PlanNextRequests) { $costNext = $PlanNextPrice } else { $costNext = $PlanNextPrice + (($projectedMonthlyFromTodayRate - $PlanNextRequests) * $OveragePricePerRequest) }

    $options = @()
    $options += [pscustomobject]@{ Name = 'Stay'; Price = $stayCost }
    $options += [pscustomobject]@{ Name = '1500-plan'; Price = $cost1500 }
    $options += [pscustomobject]@{ Name = $PlanNextName; Price = $costNext }

    $best = $options | Sort-Object Price | Select-Object -First 1
    if ($best.Name -ne 'Stay' -and $best.Price -lt $stayCost) {
        $planPretty = $best.Name
        $planPrice = [math]::Round($best.Price,2)
        $planPriceStr = ('${0:N2}' -f $planPrice)
        $msg = ("Suggestion: consider switching to {0} — estimated monthly cost if switched: {1}" -f $planPretty, $planPriceStr)
        # If recommending next tier and projected monthly is already near/above 1500, mention preemptive buy
        if ($best.Name -eq $PlanNextName -and $projectedMonthlyFromTodayRate -ge $Plan1500Threshold) {
            $msg = $msg + ' (consider buying now before exceeding 1500)'
        }
        Write-Host $msg -ForegroundColor DarkYellow
    }
}

# Comparisons / Alerts
$cmpCount = 0
Write-Host "-- Comparisons & Alerts --" -ForegroundColor DarkMagenta
if ($projectedMonthlyFromTodayRate -ne $null) {
    $diff = $projectedMonthlyFromTodayRate - $monthlyTargetRequests
    if ($diff -gt 0) { Write-Host ("ALERT: Today's-rate projection exceeds monthly target by {0:N0} requests" -f $diff) -ForegroundColor Red; $cmpCount++ } else { Write-Host ("OK: Today's-rate projection is {0:N0} requests below monthly target" -f ([math]::Abs($diff))) -ForegroundColor Green }
}

$diffCurrent = $projectedMonthlyFromCurrentRate - $monthlyTargetRequests
if ($diffCurrent -gt 0) { Write-Host ("WARN: Current-rate projection exceeds monthly target by {0:N0} requests" -f $diffCurrent) -ForegroundColor Yellow; $cmpCount++ } else { Write-Host ("OK: Current-rate projection is {0:N0} requests below monthly target" -f ([math]::Abs($diffCurrent))) -ForegroundColor Green }

if ($projectedCostFromTodayRate -ne $null) {
    $costDiff = $projectedCostFromTodayRate - $MonthlyBudget
    if ($costDiff -gt 0) { Write-Host ("ALERT: Projected monthly cost (today's rate) exceeds budget by {0:N2}" -f $costDiff) -ForegroundColor Red; $cmpCount++ } else { Write-Host ("OK: Projected monthly cost (today's rate) is {0:N2} below budget" -f ([math]::Abs($costDiff))) -ForegroundColor Green }
}

$costDiffCur = $projectedCostFromCurrentRate - $MonthlyBudget
if ($costDiffCur -gt 0) { Write-Host ("WARN: Projected monthly cost (current rate) exceeds budget by {0:N2}" -f $costDiffCur) -ForegroundColor Yellow; $cmpCount++ } else { Write-Host ("OK: Projected monthly cost (current rate) is {0:N2} below budget" -f ([math]::Abs($costDiffCur))) -ForegroundColor Green }

if ($cmpCount -eq 0) { Write-Host "No alerts - projections are within targets/budget." -ForegroundColor Cyan }

# Explanation: why Today's and Current projections can differ
Write-Host "" -ForegroundColor White
Write-Host "-- Why Today's vs Current may differ --" -ForegroundColor DarkMagenta
Write-Host "Today's rate is a short-term run-rate (requests today / elapsed hours)." -ForegroundColor White
Write-Host "Current rate is the month-to-date average (total requestsMonth / hours worked so far)." -ForegroundColor White
Write-Host "Consequences:" -ForegroundColor Yellow
Write-Host " - A high burst today can make Today's projection (extrapolating this day's rate) exceed the monthly target even if the historical Current rate remains below it." -ForegroundColor Yellow
Write-Host " - The Recommendation (Allowed) is computed from remaining requests divided by remaining hours — it's the average rate you must hold from now on to hit the monthly target." -ForegroundColor Yellow
Write-Host " - Use Today's rate for immediate throttling decisions; use Current rate to understand the overall trend." -ForegroundColor Yellow

# Recommendation: compute allowed average hourly rate for remaining work hours to stay within monthly target
$remainingWorkingHours = ($daysLeftWorking * $HoursPerWorkday) + $hoursRemainingToday
if ($remainingWorkingHours -le 0) { $allowedHourlyRateForRemaining = 0 } else { $allowedHourlyRateForRemaining = $remainingMonthlyRequests / $remainingWorkingHours }
$allowedDailyEquivalent = $allowedHourlyRateForRemaining * $HoursPerWorkday

# Show recommendation and color it red if current hourly rate or today's hourly rate exceed allowable
$recColor = 'Green'
if ($currentHourlyRate -gt $allowedHourlyRateForRemaining) { $recColor = 'Red' }
if ($todayHourlyRate -ne $null -and $todayHourlyRate -gt $allowedHourlyRateForRemaining) { $recColor = 'Red' }
Write-Host ("Recommendation: To stay within monthly target, average ≤ {0:N2} req/hr for remaining work hours (~ {1:N2} req/day)" -f $allowedHourlyRateForRemaining, $allowedDailyEquivalent) -ForegroundColor $recColor

# Per-hour throttle recommendation for the remainder of today
if ($hoursRemainingToday -gt 0) {
    $allowedHourlyToday = $remainingMonthlyRequests / $hoursRemainingToday
    # Keep a conservative suggestion: min of allowedHourlyRateForRemaining and allowedHourlyToday
    $throttleRec = [math]::Min($allowedHourlyRateForRemaining, $allowedHourlyToday)
    $throttleColor = 'Green'
    if ($todayHourlyRate -ne $null -and $throttleRec -lt $todayHourlyRate) { $throttleColor = 'Red' }
    # If the throttle recommendation is effectively the same as the overall allowed hourly rate, skip duplicate line
    if ([math]::Abs($throttleRec - $allowedHourlyRateForRemaining) -ge 0.01) {
        Write-Host ("Throttle recommendation (remainder of today): limit to ≤ {0:N2} req/hr" -f $throttleRec) -ForegroundColor $throttleColor
    }
}

# Simple ASCII bar graph comparing allowed vs current vs today's hourly rates
if ($todayHourlyRate -ne $null) { $todayRateVal = $todayHourlyRate } else { $todayRateVal = 0.0 }
# Nested Max (PowerShell/.NET Math.Max supports two args only) and guard against non-finite values
$graphMax = [math]::Max([math]::Max([math]::Max($allowedHourlyRateForRemaining, $currentHourlyRate), $todayRateVal), 1.0)
if ([double]::IsInfinity($graphMax) -or [double]::IsNaN($graphMax) -or $graphMax -le 0) { $graphMax = 1.0 }

function Get-Bar([double]$val, [double]$max) {
    $width = 40
    if ([double]::IsInfinity($val) -or [double]::IsNaN($val)) { $val = 0.0 }
    if ([double]::IsInfinity($max) -or [double]::IsNaN($max) -or $max -le 0) { $max = 1.0 }
    $ratio = $val / $max
    if ([double]::IsInfinity($ratio) -or [double]::IsNaN($ratio)) { $ratio = 0.0 }
    $len = [int]([math]::Round($ratio * $width))
    if ($len -lt 0) { $len = 0 }
    if ($len -gt $width) { $len = $width }
    return ('=' * $len) + (' ' * ($width - $len))
}
Write-Host "" -ForegroundColor White
Write-Host "-- Rate Comparison (req/hr) --" -ForegroundColor DarkCyan
Write-Host "Legend:" -ForegroundColor DarkCyan
Write-Host "  - Allowed : avg req/hr you can sustain for all remaining work hours (green)" -ForegroundColor Green
Write-Host "  - Current : month-to-date average req/hr so far (yellow)" -ForegroundColor Yellow
Write-Host "  - Today's  : current day's run-rate (req/hr) - noisy early; turns red if above Allowed" -ForegroundColor Cyan
$allowedLine = ('Allowed  : [{0}] {1:N2} req/hr' -f (Get-Bar $allowedHourlyRateForRemaining $graphMax), $allowedHourlyRateForRemaining)
Write-Host $allowedLine -ForegroundColor Green
$currentLine = ('Current  : [{0}] {1:N2} req/hr' -f (Get-Bar $currentHourlyRate $graphMax), $currentHourlyRate)
Write-Host $currentLine -ForegroundColor Yellow
if ($todayHourlyRate -ne $null) {
    $todayColor = 'Cyan'
    # Use a small tolerance to avoid floating-point rounding hiding slight overruns
    if ($todayHourlyRate -gt ($allowedHourlyRateForRemaining + 0.0001)) { $todayColor = 'Red' }
    $todayLine = ('Today    : [{0}] {1:N2} req/hr' -f (Get-Bar $todayHourlyRate $graphMax), $todayHourlyRate)
    Write-Host $todayLine -ForegroundColor $todayColor
}
Write-Host "====================================" -ForegroundColor Cyan
