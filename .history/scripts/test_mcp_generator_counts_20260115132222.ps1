param(
    [int[]]$Counts = @(1,9,50),
    [string]$OutDir = (Join-Path -Path (Get-Location) -ChildPath 'mcp_templates'),
    [string]$SystemPromptFile = 'c:\Temp\.github\prompts\test.prompt.md'
)

if (-not (Test-Path $OutDir)) { New-Item -Path $OutDir -ItemType Directory | Out-Null }

foreach ($n in $Counts) {
    $bodyFile = Join-Path $env:TEMP ("mcp_test_body_$n.txt")
    $lines = for ($i=1; $i -le $n; $i++) { "$i) Test item $i" }
    $lines -join "`n" | Out-File -FilePath $bodyFile -Encoding UTF8

    $name = "count_test_${n}"
    Write-Host "Generating template for $n items -> $name"
    $generatorPath = Join-Path $PSScriptRoot '..\mcp_generator.ps1'
    if (-not (Test-Path $generatorPath)) {
        Write-Host "Generator script not found at: $generatorPath" -ForegroundColor Red
        continue
    }
    & $generatorPath -Name $name -Description "Count test $n" -Author "Tester" -Tags "count,test" -BodyFile $bodyFile -OutDir $OutDir -AddSystemPrompt -SystemPromptFile $SystemPromptFile -AsMarkdown -Force

    $mdPath = Join-Path $OutDir ($name + '.mcp.md')
    if (-not (Test-Path $mdPath)) { Write-Host "Missing markdown output for $name" -ForegroundColor Red; continue }

    $content = Get-Content -Path $mdPath -Raw
    # Count numbered lines starting with digits then ')'
    $matches = ([regex]::Matches($content, '^[ \t]*\d+\)', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    if ($matches -eq $n) {
        Write-Host "OK: Found $matches numbered lines in $mdPath" -ForegroundColor Green
    }
    else {
        Write-Host "WARN: Expected $n numbered lines but found $matches in $mdPath" -ForegroundColor Yellow
    }
}

Write-Host "Count tests complete." -ForegroundColor Cyan
