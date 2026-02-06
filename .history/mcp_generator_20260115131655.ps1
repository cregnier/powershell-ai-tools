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

.PARAMETER AddSystemPrompt
If provided, the script will prepend a system prompt to the user body. Use this when you want the MCP to include instructions for the LLM.

.PARAMETER SystemPromptText
Optional custom single-line system prompt text to prepend when `-AddSystemPrompt` is used. If omitted, the script uses the default expert-Azure prompt (Summary/Action Plan/Files/Todos/Tests format).

.PARAMETER SystemPromptFile
Optional path to a file containing a multi-line system prompt to use when `-AddSystemPrompt` is set. This overrides `-SystemPromptText` when provided.

.PARAMETER AsMarkdown
If provided the script will also emit a Markdown template (`.mcp.md`) with YAML frontmatter and the raw body as content. Useful for VS Code LLM extensions that expect markdown templates.

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
	[string]$OutDir = (Join-Path -Path (Get-Location) -ChildPath 'mcp_templates'),
	[switch]$AddSystemPrompt,
	[string]$SystemPromptText,
	[string]$SystemPromptFile,
	[switch]$AsMarkdown,
	[switch]$Force
)

function Read-MultilineInput {
	param(
		[string]$EndMarker = 'EOF'
	)
	Write-Host "Paste the body now. Enter a single line with '$EndMarker' to finish:`n"
	$lines = @()
	while ($true) {
		$line = Read-Host
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

	# Robust tag parsing: accept array or string, always split on commas or whitespace
	$tags = @()
	if (-not [string]::IsNullOrWhiteSpace($tagsInput)) {
		$raw = $tagsInput
		$all = @()
		if ($raw -is [System.Array]) {
			foreach ($r in $raw) { $all += ($r -split '[,\s]+') }
		} else {
			$all += ($raw -split '[,\s]+')
		}
		$tags = $all | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
	}
	if (-not $tags) { $tags = @() }

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

	function Build-MCPBody {
		param(
			[string]$RawBody,
			[bool]$UseSystemPrompt,
			[string]$CustomPrompt
		)
		if (-not $UseSystemPrompt) { return $RawBody }

		if (-not [string]::IsNullOrWhiteSpace($CustomPrompt)) {
			$systemHeader = $CustomPrompt
		}
		else {
			$systemHeader = "You are an expert Azure security engineer."
			$systemHeader += " For each numbered requirement produce the following sections:\n"
			$systemHeader += "- Summary: one-paragraph explanation of the requirement and risk/goal.\n"
			$systemHeader += "- Action Plan: step-by-step concrete actions with exact commands (az/ARM/Bicep/PowerShell) or code snippets.\n"
			$systemHeader += "- Files/Patches: list of files to create or patch; provide unified diffs where applicable.\n"
			$systemHeader += "- Todos: markdown-ready entries for todos.md including file path and commands.\n"
			$systemHeader += "- Tests/Verification: exact commands and checks to validate success.\n\n"
		}

		if ($RawBody -match "^\s*1\)" -or $RawBody -match "^\s*1\.") {
			return ($systemHeader + "Context:" + "\n\n" + $RawBody)
		}
		else {
			return ($systemHeader + "Body:" + "\n\n" + $RawBody)
		}
	}

	# Normalize tags: ensure an array is written to JSON
	if ($tags -is [string]) { $tags = @($tags) }
	elseif (-not $tags) { $tags = @() }

	# If the provided body is not numbered, offer an interactive mode to enter the 9 items one-by-one
	if (-not ($body -match "^\s*1\)" -or $body -match "^\s*1\.")) {
		$enterIndividually = Read-Host 'Body does not appear to contain numbered items. Enter the 9 items one-by-one instead? (Y/N)'
		if ($enterIndividually -match '^[Yy]') {
			$items = @()
			for ($i = 1; $i -le 9; $i++) {
				$line = Read-Host "Enter item $i"
				$items += ("$i) " + ($line -replace '\r|\n',' '))
			}
			$body = ($items -join "`n")
		}
	}

	# If a SystemPromptFile is provided, load it (overrides SystemPromptText)
	if ($SystemPromptFile) {
		if (-not (Test-Path $SystemPromptFile)) { throw "System prompt file not found: $SystemPromptFile" }
		$SystemPromptText = Get-Content -Path $SystemPromptFile -Raw
	}

	# Build the final body used in the MCP template; pass switch value and optional custom prompt
	$body = Build-MCPBody -RawBody $body -UseSystemPrompt:($AddSystemPrompt.IsPresent) -CustomPrompt $SystemPromptText

	# Debug/validate collected metadata before creating template
	Write-Host "DEBUG: Collected metadata -> Name='$Name' Description='$Description' Author='$Author' Tags='$(($tags -join ','))'" -ForegroundColor DarkGreen

	# Final normalization: split every tag token on commas or whitespace and build final array
	$finalTags = @()
	foreach ($t in @($tags)) {
		$parts = $t -split '[,\s]+'
		foreach ($p in $parts) {
			$token = $p.Trim()
			if ($token -ne '') { $finalTags += $token }
		}
	}
	$tagsArray = $finalTags | ForEach-Object { [string]$_ }

	# Build as a hashtable to ensure consistent JSON output
	$template = @{
		schemaVersion = '1.0'
		id = $Name
		displayName = $Name
		description = $Description
		author = $Author
		tags = $tagsArray
		body = $body
	}

	if (-not (Test-Path $OutDir)) { New-Item -Path $OutDir -ItemType Directory | Out-Null }

	# sanitize file name
	$safeName = $Name -replace '[\\/:*?""<>|]', '_' -replace '\s+', '_'
	$outFile = Join-Path $OutDir ($safeName + '.mcp.json')

	$json = ConvertTo-Json $template -Depth 10
	$json | Out-File -FilePath $outFile -Encoding UTF8

	Write-Host "`nWrote template to: $outFile"

	# Optionally also write a Markdown version with YAML frontmatter
	if ($AsMarkdown.IsPresent) {
		$mdOut = Join-Path $OutDir ($safeName + '.mcp.md')
		$front = @()
		$front += '---'
		$front += "id: $($template.id)"
		$front += "displayName: $($template.displayName)"
		$front += 'tags:'
		foreach ($t in $template.tags) { $front += "  - $t" }
		$front += "description: $($template.description)"
		$front += "author: $($template.author)"
		$front += "schemaVersion: $($template.schemaVersion)"
		$front += '---'

		$bodyLines = $template.body -split "`n"
		$mdLines = $front + '' + $bodyLines
		$mdLines -join "`n" | Out-File -FilePath $mdOut -Encoding UTF8
		Write-Host "Wrote markdown template to: $mdOut"
	}

	# Post-generation guidance for VS Code
	Write-Host "`nNext steps for VS Code usage:" -ForegroundColor Cyan
	Write-Host "- Open the file in the workspace: $outFile"
	Write-Host "- If your VS Code LLM/chat extension supports templates, use its 'Load template' or 'Import' command and point to the file." 
	Write-Host "- Otherwise, open the file, copy the 'body' field value, and paste it into the chat extension's system prompt or template field." 
	Write-Host "- You can also programmatically read the JSON 'body' and inject it as the system prompt when initializing a chat session." -ForegroundColor Gray
}
catch {
	Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
	Write-Host "Full exception details:" -ForegroundColor Yellow
	$_.Exception | Format-List -Force
	if ($_.InvocationInfo) { Write-Host "InvocationInfo:"; $_.InvocationInfo | Format-List -Force }
	exit 1
}

return 0

