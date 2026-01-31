<#
.SYNOPSIS
  Remove all files uploaded to Google's Gemini API storage using the GEMINI_API_KEY.

.DESCRIPTION
  This script lists files from the Gemini generativelanguage API, handles pagination,
  and deletes each file. By default it asks for confirmation. Use -Force to skip prompts,
  and -DryRun to only list which files would be deleted.

.PARAMETER DryRun
  If specified, only list files that would be deleted (no deletion is performed).

.PARAMETER Force
  If specified, do not prompt for confirmation before deleting.

.EXAMPLE
  .\gcp-gemini-apistorage-reset.ps1
  Prompts and then deletes files.

.EXAMPLE
  $env:GEMINI_API_KEY = "YOUR_KEY"
  .\gcp-gemini-apistorage-reset.ps1 -Force
  Uses the env var and deletes all files without interactive prompts.

#>

param(
    [switch]$DryRun,
    [switch]$Force
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    # ISO 8601 sortable timestamp format
    $timestamp = (Get-Date).ToString("s")
    Write-Host "[$timestamp] [$Level] $Message"
}

# Ensure environment variable is present
if (-not $env:GEMINI_API_KEY -or [string]::IsNullOrWhiteSpace($env:GEMINI_API_KEY)) {
    Write-Error "GEMINI_API_KEY environment variable is not set. Please set it and re-run the script."
    exit 2
}

$ApiKey = $env:GEMINI_API_KEY
$BaseUrl = "https://generativelanguage.googleapis.com/v1beta/files"

# Helper: escape each path segment so slashes are preserved but segments are URL-encoded
function Escape-PathSegments {
    param([string]$value)
    if ($null -eq $value) { return $null }
    return ($value -split '/') | ForEach-Object { [System.Uri]::EscapeDataString($_) } -join '/'
}

# Ask for confirmation unless forced or dry-run
if (-not $Force -and -not $DryRun) {
    $confirm = Read-Host "This will DELETE ALL uploaded Gemini files in the configured account. Type 'yes' to continue"
    if ($confirm -ne "yes") {
        Write-Log "Aborted by user." "WARN"
        exit 0
    }
}

$headers = @{
    "x-goog-api-key" = $ApiKey
    "Accept" = "application/json"
}

$pageToken = $null
$totalListed = 0
$totalDeleted = 0
$errors = @()

try {
    do {
        $uri = $BaseUrl
        if ($pageToken) {
            # Add pageToken parameter; adjust if API requires pageSize etc.
            $uri = "$BaseUrl?pageToken=$([System.Uri]::EscapeDataString($pageToken))"
        }

        Write-Log "Listing files from: $uri"
        try {
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop
        } catch {
            Write-Error "Failed to list files: $($_.Exception.Message)"
            throw
        }

        # The API may return an array in 'files' or 'items' depending on the version
        $files = @()
        if ($null -ne $response.files) { $files = $response.files }
        elseif ($null -ne $response.items) { $files = $response.items }
        else {
            # Some APIs return top-level entries directly
            if ($response -is [System.Collections.IEnumerable]) {
                $files = $response
            }
        }

        if ($files.Count -eq 0) {
            Write-Log "No files found on this page." "INFO"
        } else {
            foreach ($file in $files) {
                # The 'name' field is assumed to be present per API examples
                $name = if ($file.name) { $file.name } else { $null }
                $displayId = if ($file.name) { $file.name } elseif ($file.id) { $file.id } else { $file | ConvertTo-Json -Depth 2 }
                $totalListed++

                Write-Log "Found file: $displayId"

                if ($DryRun) { continue }

                # Build safe URL: escape each path segment but preserve slashes
                $encodedName = Escape-PathSegments $name
                $deleteUrl = "$BaseUrl/$encodedName"

                Write-Log "Deleting: $deleteUrl"
                try {
                    # Use -Method Delete. Some APIs return no body (204) on success.
                    $delResponse = Invoke-RestMethod -Method Delete -Uri $deleteUrl -Headers $headers -ErrorAction Stop
                    Write-Log "Deleted: $displayId" "INFO"
                    $totalDeleted++
                } catch {
                    # Capture more details if available
                    $errMsg = $_.Exception.Message
                    Write-Log "Failed to delete ${displayId}: $errMsg" "ERROR"
                    $errors += [PSCustomObject]@{
                        File = $displayId
                        Error = $errMsg
                    }
                }
            }
        }

        # Determine pagination token name (API may use nextPageToken)
        if ($null -ne $response.nextPageToken) {
            $pageToken = $response.nextPageToken
            Write-Log "Next page token: $pageToken"
        } else {
            $pageToken = $null
        }

    } while ($pageToken)

    Write-Log "Done. Listed $totalListed files. Deleted $totalDeleted files."

    if ($errors.Count -gt 0) {
        Write-Log "There were $($errors.Count) errors during deletion. See details below:" "WARN"
        $errors | Format-Table -AutoSize
        exit 3
    } else {
        exit 0
    }
}
catch {
    Write-Error "Unexpected error: $($_.Exception.Message)"
    exit 1
}
