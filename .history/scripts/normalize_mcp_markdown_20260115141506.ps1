# Normalize all .mcp.md files by regenerating them from corresponding .mcp.json
param(
    [string]$TemplatesDir = (Join-Path -Path (Get-Location) -ChildPath 'mcp_templates'),
    [switch]$Force
)

if (-not (Test-Path $TemplatesDir)) { Write-Host "Templates directory not found: $TemplatesDir" -ForegroundColor Red; exit 1 }

Get-ChildItem -Path $TemplatesDir -Filter '*.mcp.json' | ForEach-Object {
    $jsonPath = $_.FullName
    try {
        $content = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host "Skipping invalid JSON: $jsonPath" -ForegroundColor Yellow
        return
    }

    $name = $content.id
    if (-not $name) { $name = $_.BaseName }
    $safeName = $name -replace '[\\/:*?""<>|]', '_' -replace '\s+', '_'
    $mdOut = Join-Path $TemplatesDir ($safeName + '.mcp.md')

    if ((Test-Path $mdOut) -and -not $Force.IsPresent) {
        Write-Host "Skipping existing markdown (use -Force to overwrite): $mdOut" -ForegroundColor Yellow
        return
    }

    # Frontmatter using allowed keys only: name, description, agent, model, tools, argument-hint
    $front = @()
    $front += '---'
    $nameVal = if ($content.displayName) { $content.displayName } else { $content.id }
    $front += "name: $nameVal"
    if ($content.description) { $front += "description: $($content.description)" }
    $front += "agent: agent"
    if ($content.tags) {
        $front += 'tools:'
        foreach ($t in $content.tags) { $front += "  - $t" }
    }
    $front += '---'

    $body = $content.body -replace '\r\n','`n' -replace '\r','`n'
    $bodyLines = $body -split "`n"
    $mdLines = $front + '' + $bodyLines
    $mdLines -join "`n" | Out-File -FilePath $mdOut -Encoding UTF8
    Write-Host "Regenerated: $mdOut"
}

Write-Host "Normalization complete." -ForegroundColor Green
