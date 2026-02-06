<#
.SYNOPSIS
Interactive MCP template generator.

.DESCRIPTION
Prompts for template metadata, accepts a pasted body of text (end with a single line containing EOF),
and writes a JSON file into ./mcp_templates.

Usage: Run the script and follow prompts. To paste the body, paste your text and then on a new line type EOF and press Enter.
#>

function Read-MultilineInput {
	param(
		[string]$EndMarker = 'EOF'
	)
	Write-Host "Paste the body now. Enter a single line with '$EndMarker' to finish:`n"
	$lines = @()
	while ($true) {
		$line = Read-Host -Prompt ''
		if ($line -eq $EndMarker) { break }
		$lines += $line
	}
	return ($lines -join "`n")
}

try {
	$name = Read-Host 'Template name (used for filename)'
	if ([string]::IsNullOrWhiteSpace($name)) { throw 'Template name is required.' }

	$description = Read-Host 'Short description'
	$author = Read-Host 'Author (optional)'
	$tagsInput = Read-Host 'Tags (comma-separated, optional)'
	$tags = @()
	if (-not [string]::IsNullOrWhiteSpace($tagsInput)) { $tags = ($tagsInput -split ',') | ForEach-Object { $_.Trim() } }

	$body = Read-MultilineInput -EndMarker 'EOF'

	$template = [PSCustomObject]@{
		schemaVersion = '1.0'
		id = $name
		displayName = $name
		description = $description
		author = $author
		tags = $tags
		body = $body
	}

	$outDir = Join-Path -Path (Get-Location) -ChildPath 'mcp_templates'
	if (-not (Test-Path $outDir)) { New-Item -Path $outDir -ItemType Directory | Out-Null }

	# sanitize file name
	$safeName = $name -replace '[\\/:*?""<>|]', '_' -replace '\s+', '_'
	$outFile = Join-Path $outDir ($safeName + '.mcp.json')

	$json = $template | ConvertTo-Json -Depth 10
	$json | Out-File -FilePath $outFile -Encoding UTF8

	Write-Host "\nWrote template to: $outFile"
	Write-Host "Preview (first 400 chars):`n" -NoNewline
	$preview = Get-Content -Path $outFile -Raw
	if ($preview.Length -gt 400) { $preview = $preview.Substring(0,400) + '...'}
	Write-Host $preview
}
catch {
	Write-Host "Error: $_" -ForegroundColor Red
	exit 1
}

return 0

