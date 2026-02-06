<#
.SYNOPSIS
MCP template generator (interactive + non-interactive)

.DESCRIPTION
This script creates a Model Context Protocol (MCP) JSON template from console input
or from provided command-line arguments. It accepts a pasted body of text interactively
(type a single line containing EOF to finish) or reads a body from a file via `-BodyFile`.

.USAGE
- Interactive: run the script with no parameters and follow prompts.
- Non-interactive: pass `-Name -Description -Author -Tags -BodyFile`.

.EXAMPLE (non-interactive)
PowerShell:
	powershell -NoProfile -ExecutionPolicy Bypass -File .\mcp_generator.ps1 -Name "MyTemplate" -Description "Desc" -Author "Me" -Tags "a,b" -BodyFile .\scripts\body.txt

.VS CODE / LLM CHAT USAGE
- Save the generated MCP JSON under the workspace `mcp_templates/` folder.
- If your VS Code LLM/chat extension supports MCP templates, point the extension at the file
  or use the extension's "Load template" command to load the JSON as the system prompt.
- If the extension does not directly support MCP templates, open the JSON and copy the
  `body` field content into the LLM's system prompt or paste the full JSON into the chat
  system prompt field where supported.

The key steps:
1) Run this script to produce `mcp_templates/<name>.mcp.json`.
2) Open your LLM/chat extension and either load the file or paste the `body` value as
   the system prompt.

#>

param(
	[Parameter(Position=0)]
	[string]$Name,

	[string]$Description,

	[string]$Author,

	[string]$Tags,

	[string]$BodyFile,

	[string]$OutDir = (Join-Path -Path (Get-Location) -ChildPath 'mcp_templates')
)

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
	if (-not $PSBoundParameters.ContainsKey('Name')) {
		$Name = Read-Host 'Template name (used for filename)'
		if ([string]::IsNullOrWhiteSpace($Name)) { throw 'Template name is required.' }
	}

	if (-not $PSBoundParameters.ContainsKey('Description')) {
		$Description = Read-Host 'Short description'
	}
	if (-not $PSBoundParameters.ContainsKey('Author')) {
		$Author = Read-Host 'Author (optional)'
	}
	if (-not $PSBoundParameters.ContainsKey('Tags')) {
		$tagsInput = Read-Host 'Tags (comma-separated, optional)'
	} else {
		$tagsInput = $Tags
	}

	$tags = @()
	if (-not [string]::IsNullOrWhiteSpace($tagsInput)) { $tags = ($tagsInput -split ',') | ForEach-Object { $_.Trim() } }

	if ($BodyFile) {
		if (-not (Test-Path $BodyFile)) { throw "Body file not found: $BodyFile" }
		$body = Get-Content -Path $BodyFile -Raw
	}
	else {
		# Read body, allow retry if empty
		while ($true) {
			$body = Read-MultilineInput -EndMarker 'EOF'
			if (-not [string]::IsNullOrWhiteSpace($body)) { break }
			$tryAgain = Read-Host 'No body entered. Retry entering body? (Y/N)'
			if ($tryAgain -match '^[Nn]') { throw 'Body is required.' }
		}
	}

	$template = [PSCustomObject]@{
		schemaVersion = '1.0'
		id = $Name
		displayName = $Name
		description = $Description
		author = $Author
		tags = $tags
		body = $body
	}

	if (-not (Test-Path $OutDir)) { New-Item -Path $OutDir -ItemType Directory | Out-Null }

	# sanitize file name
	$safeName = $Name -replace '[\\/:*?""<>|]', '_' -replace '\s+', '_'
	$outFile = Join-Path $OutDir ($safeName + '.mcp.json')

	$json = $template | ConvertTo-Json -Depth 10
	$json | Out-File -FilePath $outFile -Encoding UTF8

	Write-Host "`nWrote template to: $outFile"
	Write-Host "Preview (first 400 chars):`n" -NoNewline
	$preview = Get-Content -Path $outFile -Raw
	if ($preview.Length -gt 400) { $preview = $preview.Substring(0,400) + '...'}
	Write-Host $preview

	# Post-generation guidance for VS Code
	Write-Host "`nNext steps for VS Code usage:" -ForegroundColor Cyan
	Write-Host "- Open the file in the workspace: $outFile"
	Write-Host "- If your VS Code LLM/chat extension supports templates, use its 'Load template' or 'Import' command and point to the file." 
	Write-Host "- Otherwise, open the file, copy the 'body' field value, and paste it into the chat extension's system prompt or template field." 
	Write-Host "- You can also programmatically read the JSON 'body' and inject it as the system prompt when initializing a chat session." -ForegroundColor Gray
}
catch {
	Write-Host "Error: $_" -ForegroundColor Red
	exit 1
}

return 0

