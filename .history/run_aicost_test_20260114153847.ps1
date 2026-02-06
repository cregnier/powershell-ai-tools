$env:AI_TEST='1'
$env:AI_FORCE='1'
$env:AI_START='09:00'
$env:AI_CURRENT='12:00'
$env:AI_REQUESTS_MONTH='1000'
$env:AI_DATE='2026-01-14'
$env:AI_BASEPLAN='300'
$env:AI_MODE='1'

& "$PSScriptRoot\AICostCalculator.ps1"
