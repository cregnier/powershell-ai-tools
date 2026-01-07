param([int]$case)

function Set-CommonEnv {
    # Ensure all runs start at 09:00 and avoid prompts by providing required AI_ env vars
    $env:AI_START = '09:00'
    $env:AI_BASEPLAN = '300'
    # Provide a current clock time so script won't prompt; use system time if not provided by scenario
    if (-not $env:AI_CURRENT) { $env:AI_CURRENT = (Get-Date -Format 'HH:mm') }
}

switch ($case) {
    1 {
        $env:AI_TEST='1'; $env:AI_MODE='1'; $env:AI_DATE='2026-01-06'; $env:AI_REQUESTS_MONTH='10'
        Set-CommonEnv
    }
    2 {
        $env:AI_TEST='1'; $env:AI_MODE='2'; $env:AI_DATE='2026-01-06'; $env:AI_REQUESTS_MONTH='100'; $env:AI_MONTHSTART='95'
        Set-CommonEnv
    }
    3 {
        $env:AI_TEST='1'; $env:AI_MODE='3'; $env:AI_DATE='2026-01-06'; $env:AI_REQUESTS_MONTH='30.9'; $env:AI_TODAY_CURRENT='75.9'
        Set-CommonEnv
    }
    4 {
        $env:AI_TEST='1'; $env:AI_MODE='3'; $env:AI_DATE='2026-01-06'; $env:AI_REQUESTS_MONTH='30.9'; $env:AI_TODAY_CURRENT='71'
        Set-CommonEnv
    }
    5 {
        $env:AI_TEST='1'; $env:AI_MODE='3'; $env:AI_DATE='2026-01-06'; $env:AI_REQUESTS_MONTH='200'; $env:AI_TODAY_CURRENT='90'; $env:AI_BASEPLAN='1500'
        Set-CommonEnv
    }
    6 {
        # Zero-elapsed edge: set current same as start so elapsed=0
        $env:AI_TEST='1'; $env:AI_MODE='3'; $env:AI_DATE='2026-01-06'; $env:AI_REQUESTS_MONTH='0'; $env:AI_TODAY_CURRENT='1'
        Set-CommonEnv
    }
    default {
        Write-Host "Unknown case: $case"; exit 2
    }
}

Write-Host "\n--- Running scenario $case ---\n"
. 'c:\ai_tookit\AICostCalculator.ps1'
