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
    [switch]$ShowExamples
)

# Optional: import a CSV of daily usage (columns: Date, Requests)
[string]$DailyUsageCsv = '';
[string]$DailyReportPath = './daily_usage_report.csv';

# GitHub fetch options: if provided, the script will download the file and use it as DailyUsageCsv
[string]$GitHubOwner = '';
[string]$GitHubRepo = '';
[string]$GitHubPath = '';
[string]$GitHubBranch = 'main';
[string]$GitHubTokenEnvVar = 'GITHUB_TOKEN';
    [switch]$PromptForToken

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

# Test-mode: allow automated runs by setting env vars early (overrides prompts)
# Only auto-apply AI_TEST when input is redirected (non-interactive) or when forced via AI_FORCE=1
if ($env:AI_TEST -eq '1' -and ([Console]::IsInputRedirected -or $env:AI_FORCE -eq '1')) {
    if ($env:AI_START) { $startDt = Parse-HHMM $env:AI_START }
    if ($env:AI_CURRENT) {
        if ([string]::IsNullOrWhiteSpace($env:AI_CURRENT)) { $currentDt = Get-Date } else { $currentDt = Parse-HHMM $env:AI_CURRENT }
    }
    if ($env:AI_REQUESTS_MONTH) { $requestsMonth = [double]$env:AI_REQUESTS_MONTH }
    if ($env:AI_DATE) { try { $givenDate = [datetime]::ParseExact($env:AI_DATE,'yyyy-MM-dd',$null) } catch { Write-Host 'Invalid date format in AI_DATE'; exit 1 } }
    if ($env:AI_BASEPLAN) { $bpv=0; if (-not [int]::TryParse($env:AI_BASEPLAN,[ref]$bpv)) { Write-Host 'Invalid AI_BASEPLAN' ; exit 1 } ; $basePlanRequests=[int]$bpv }
    if ($env:AI_MODE) { $mode = $env:AI_MODE }
    if ($env:AI_TODAY_CURRENT) { $envToday = $env:AI_TODAY_CURRENT } else { $envToday = $null }
} elseif ($env:AI_TEST -eq '1') {
    Write-Host "AI_TEST=1 detected but ignored because session appears interactive. To force test values, set AI_FORCE=1." -ForegroundColor Yellow
}

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
    $token = $env:$TokenEnvVar
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
