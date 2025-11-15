<#
.SYNOPSIS
    Installs development tools and packages from a curated list via Chocolatey.

.DESCRIPTION
    Reads a package list file (default: choco-packages.txt) and installs each
    package via Chocolatey. Handles comment lines, empty lines, and inline
    comments. Performs idempotency checks for each package and continues with
    remaining packages if some fail. Provides a summary report at completion.

.PARAMETER LogPath
    Path to the log file. Defaults to logs/install-tools-YYYYMMDD-HHmmss.log

.PARAMETER PackageListPath
    Path to the package list file. Defaults to scripts/choco-packages.txt
    Supports relative paths (resolved from script directory).

.OUTPUTS
    Exit code 0 even if some packages fail (resilient mode), 1 on fatal error.

.EXAMPLE
    PS> .\install-tools.ps1
    Installs all packages from choco-packages.txt

.EXAMPLE
    PS> .\install-tools.ps1 -PackageListPath "custom-packages.txt"
    Installs packages from a custom list file.

.EXAMPLE
    PS> .\install-tools.ps1 -WhatIf
    Previews what packages would be installed.

.NOTES
    Part of User Story 2 (P2): Install Extended Development Packages
    Requires: Administrator privileges, Chocolatey installed
    See: specs/001-windows-setup-automation/spec.md FR-004, data-model.md §1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [string]$PackageListPath = "choco-packages.txt"
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Resolve script directory
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

#region Utility Functions

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $colors = @{ 'INFO' = 'Green'; 'WARN' = 'Yellow'; 'ERROR' = 'Red'; 'DEBUG' = 'Cyan' }
    Write-Host $logEntry -ForegroundColor $colors[$Level]
    if ($LogFile) {
        try {
            $logDir = Split-Path -Path $LogFile -Parent
            if ($logDir -and -not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
        } catch {
            Write-Warning "Failed to write to log file '$LogFile': $_"
        }
    }
}

#endregion

# Setup logging
if (-not $LogPath) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogPath = Join-Path $scriptRoot "..\logs\install-tools-$timestamp.log"
}

# Ensure log directory exists
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Log "=== Extended Tools Installation Script Started ===" -Level INFO -LogFile $LogPath

# Check Administrator privileges (FR-008)
if (-not (Test-Administrator)) {
    Write-Log "ERROR: Administrator privileges required. Please run PowerShell as Administrator." -Level ERROR -LogFile $LogPath
    exit 2
}

Write-Log "Administrator check: PASS" -Level INFO -LogFile $LogPath

# Check Chocolatey is installed
$chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
if (-not $chocoCmd) {
    Write-Log "ERROR: Chocolatey is not installed. Please run install-choco.ps1 first." -Level ERROR -LogFile $LogPath
    exit 2
}

Write-Log "Chocolatey prerequisite check: PASS" -Level INFO -LogFile $LogPath

# Resolve package list path (support relative paths)
if (-not [System.IO.Path]::IsPathRooted($PackageListPath)) {
    $PackageListPath = Join-Path $scriptRoot $PackageListPath
}

# Check package list file exists
if (-not (Test-Path $PackageListPath)) {
    Write-Log "ERROR: Package list file not found: $PackageListPath" -Level ERROR -LogFile $LogPath
    exit 3
}

Write-Log "Package list file: $PackageListPath" -Level INFO -LogFile $LogPath

# Read and parse package list (data-model.md §1)
try {
    $allLines = Get-Content $PackageListPath -Encoding UTF8
    $packages = $allLines |
        Where-Object {
            # Filter out empty lines and comment lines
            $line = $_.Trim()
            $line -ne '' -and -not $line.StartsWith('#')
        } |
        ForEach-Object {
            # Remove inline comments and trim whitespace
            $line = $_.Trim()
            $commentIndex = $line.IndexOf('#')
            if ($commentIndex -ge 0) {
                $line = $line.Substring(0, $commentIndex).Trim()
            }
            $line
        } |
        Where-Object { $_ -ne '' } |
        Select-Object -Unique  # Remove duplicates

    Write-Log "Parsed $($packages.Count) unique packages from list" -Level INFO -LogFile $LogPath
}
catch {
    Write-Log "ERROR: Failed to read package list: $($_.Exception.Message)" -Level ERROR -LogFile $LogPath
    exit 3
}

if ($packages.Count -eq 0) {
    Write-Log "WARNING: No packages found in list file. Nothing to install." -Level WARN -LogFile $LogPath
    exit 0
}

# Track installation results
$installResults = @{
    Success = @()
    Skipped = @()
    Failed = @()
}

# Install each package
foreach ($package in $packages) {
    Write-Log "Processing package: $package" -Level INFO -LogFile $LogPath

    # Check if package is already installed (idempotency - FR-009)
    $localPackage = choco list --local-only --exact $package 2>&1 | Select-String -Pattern "^$package "
    if ($localPackage) {
        Write-Log "$package is already installed. Skipping." -Level WARN -LogFile $LogPath
        $installResults.Skipped += $package
        continue
    }

    # WhatIf mode (FR-011)
    if ($WhatIfPreference -eq 'Continue') {
        Write-Log "WhatIf: Would install $package via 'choco install $package -y'" -Level INFO -LogFile $LogPath
        continue
    }

    # Install the package
    try {
        Write-Log "Installing $package..." -Level INFO -LogFile $LogPath

        $installOutput = choco install $package -y 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Chocolatey install command failed with exit code $LASTEXITCODE"
        }

        Write-Log "$package installation completed successfully." -Level INFO -LogFile $LogPath
        $installResults.Success += $package
    }
    catch {
        Write-Log "ERROR: Failed to install ${package}: $($_.Exception.Message)" -Level ERROR -LogFile $LogPath
        $installResults.Failed += $package
        # Continue with next package (resilient mode - continue on failure)
    }
}

# Refresh environment variables for current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Validate oh-my-posh is accessible (FR-015, US2 acceptance scenario 4)
$ohMyPoshCommand = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($ohMyPoshCommand) {
    Write-Log "oh-my-posh is available in PATH: $($ohMyPoshCommand.Source)" -Level INFO -LogFile $LogPath
} else {
    Write-Log "WARNING: oh-my-posh not found in PATH. May require session restart if it was just installed." -Level WARN -LogFile $LogPath
}

# Summary report
Write-Log "=== Installation Summary ===" -Level INFO -LogFile $LogPath
Write-Log "Total packages processed: $($packages.Count)" -Level INFO -LogFile $LogPath
Write-Log "Successfully installed: $($installResults.Success.Count)" -Level INFO -LogFile $LogPath
if ($installResults.Success.Count -gt 0) {
    Write-Log "  - $($installResults.Success -join ', ')" -Level INFO -LogFile $LogPath
}
Write-Log "Skipped (already installed): $($installResults.Skipped.Count)" -Level INFO -LogFile $LogPath
if ($installResults.Skipped.Count -gt 0) {
    Write-Log "  - $($installResults.Skipped -join ', ')" -Level INFO -LogFile $LogPath
}
Write-Log "Failed: $($installResults.Failed.Count)" -Level INFO -LogFile $LogPath
if ($installResults.Failed.Count -gt 0) {
    Write-Log "  - $($installResults.Failed -join ', ')" -Level ERROR -LogFile $LogPath
}

# Exit with code 0 even if some packages failed (resilient mode)
# Fatal errors (missing prerequisites, file not found) exit with non-zero earlier
if ($installResults.Failed.Count -gt 0) {
    Write-Log "=== Extended Tools Installation Script Completed with Some Failures ===" -Level WARN -LogFile $LogPath
} else {
    Write-Log "=== Extended Tools Installation Script Completed Successfully ===" -Level INFO -LogFile $LogPath
}

exit 0
