# Test script to demonstrate weekend/holiday logic

# Source the functions
. .\AICostCalculator.ps1 -GitHubUsageReportCsv 'nonexistent.csv' 2>&1 | Out-Null

Write-Host "`n=== WEEKEND/HOLIDAY LOGIC VALIDATION ===" -ForegroundColor Cyan
$testDate = Get-Date "2026-02-02"
$endDate = Get-Date "2026-02-20"

Write-Host "`nCounting days from Feb 2 to Feb 20, 2026:" -ForegroundColor Yellow

# Calendar days
$calendarDays = ($endDate - $testDate).Days
Write-Host "  Total calendar days: $calendarDays" -ForegroundColor White

# Count weekends
$weekendCount = 0
$current = $testDate
Write-Host "`n  Weekends in range:" -ForegroundColor Gray
while ($current -le $endDate) {
    if ($current.DayOfWeek -eq 'Saturday' -or $current.DayOfWeek -eq 'Sunday') {
        Write-Host "    $($current.ToString('yyyy-MM-dd')) ($($current.DayOfWeek))" -ForegroundColor DarkGray
        $weekendCount++
    }
    $current = $current.AddDays(1)
}

# Test the function
$businessDays = Get-BusinessDaysInRange $testDate $endDate
Write-Host "`n  Business days calculated: $businessDays" -ForegroundColor Green
Write-Host "  Weekend days excluded: $weekendCount" -ForegroundColor Yellow
Write-Host "  Holidays excluded: $($calendarDays - $businessDays - $weekendCount)" -ForegroundColor Yellow

Write-Host "`n=== FORECAST IMPACT ===" -ForegroundColor Cyan
$avgDaily = 35.2
$currentTotal = 278
Write-Host "  Current requests: $currentTotal" -ForegroundColor White
Write-Host "  Average per business day: $avgDaily" -ForegroundColor White
Write-Host "`n  Forecast using calendar days ($calendarDays days):" -ForegroundColor Red
Write-Host "    $($currentTotal + ($avgDaily * $calendarDays)) requests" -ForegroundColor Red
Write-Host "`n  Forecast using business days ($businessDays days):" -ForegroundColor Green
Write-Host "    $($currentTotal + ($avgDaily * $businessDays)) requests" -ForegroundColor Green
Write-Host "`n  Accuracy improvement:" -ForegroundColor Yellow
Write-Host "    $([math]::Round(($avgDaily * ($calendarDays - $businessDays)), 0)) requests more accurate`n" -ForegroundColor Yellow
