$templatesDir = Join-Path $PSScriptRoot '..\mcp_templates'
Get-ChildItem -Path $templatesDir -Filter '*.mcp.md' -File | Where-Object { $_.Name -ne 'AKVProject.mcp.md' } | ForEach-Object {
    try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop; Write-Host "Removed: $($_.FullName)" }
    catch { Write-Host "Failed to remove: $($_.FullName) - $($_.Exception.Message)" -ForegroundColor Yellow }
}
# Also remove stray folder '9' if present
$maybe = Join-Path (Join-Path $PSScriptRoot '..') '9\count_test_3.mcp.md'
if (Test-Path $maybe) { Remove-Item $maybe -Force -ErrorAction SilentlyContinue; Write-Host "Removed: $maybe" }
Write-Host 'Cleanup complete.'
