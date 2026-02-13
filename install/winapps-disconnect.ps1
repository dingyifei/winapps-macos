# winapps-disconnect.ps1
# Wrapper script for WinApps RemoteApp auto-disconnect.
# Launches the target application, waits for it to exit, then disconnects
# the RDP session (via tsdiscon) if no other WinApps apps are still running.

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$AppPath,

    [Parameter(Mandatory = $false, Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$AppArgs
)

# Directory for marker files that track active WinApps instances.
$MarkerDir = Join-Path $env:TEMP "winapps_active"
if (-not (Test-Path $MarkerDir)) {
    New-Item -ItemType Directory -Path $MarkerDir -Force | Out-Null
}

# Create a unique marker file for this instance.
$MarkerFile = Join-Path $MarkerDir ("winapps_" + [System.Guid]::NewGuid().ToString("N") + ".marker")
New-Item -ItemType File -Path $MarkerFile -Force | Out-Null

try {
    # Build Start-Process arguments.
    $startArgs = @{
        FilePath = $AppPath
        PassThru = $true
    }
    if ($AppArgs -and $AppArgs.Count -gt 0) {
        $startArgs.ArgumentList = $AppArgs
    }

    # Launch the application and wait for it to exit.
    $proc = Start-Process @startArgs
    $proc.WaitForExit()

    # Grace period: some apps restart themselves (e.g. updaters).
    Start-Sleep -Seconds 5
}
finally {
    # Remove this instance's marker.
    if (Test-Path $MarkerFile) {
        Remove-Item $MarkerFile -Force
    }

    # Check if any other WinApps markers remain.
    $remaining = @(Get-ChildItem -Path $MarkerDir -Filter "winapps_*.marker" -ErrorAction SilentlyContinue)
    if ($remaining.Count -eq 0) {
        # Last app closed — disconnect the RDP session (not logoff).
        & tsdiscon.exe
    }
}
