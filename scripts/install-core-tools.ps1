<#
.SYNOPSIS
    Installs core development tools (Git, Node.js, pnpm) via Chocolatey.

.DESCRIPTION
    Installs essential development tools required for software development work.
    Checks that Chocolatey is installed first (prerequisite), then installs
    git, nodejs, and pnpm with idempotency checks. Validates each tool is
    accessible in PATH after installation.

.PARAMETER LogPath
    Path to the log file. Defaults to logs/install-core-tools-YYYYMMDD-HHmmss.log

.OUTPUTS
    Exit code 0 on success, 1 on failure, 2 if prerequisites not met.

.EXAMPLE
    PS> .\install-core-tools.ps1
    Installs Git, Node.js, and pnpm with default settings.

.EXAMPLE
    PS> .\install-core-tools.ps1 -WhatIf
    Previews what tools would be installed without making changes.

.EXAMPLE
    PS> .\install-core-tools.ps1 -Verbose
    Installs with detailed diagnostic output.

.NOTES
    Part of User Story 1 (P1): Install Core Development Tools
    Requires: Administrator privileges, Chocolatey installed
    See: specs/001-windows-setup-automation/spec.md FR-002, FR-013, FR-015
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$LogPath
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
    $LogPath = Join-Path $scriptRoot "..\logs\install-core-tools-$timestamp.log"
}

# Ensure log directory exists
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Log "=== Core Tools Installation Script Started ===" -Level INFO -LogFile $LogPath

# Check Administrator privileges (FR-008)
if (-not (Test-Administrator)) {
    Write-Log "ERROR: Administrator privileges required. Please run PowerShell as Administrator." -Level ERROR -LogFile $LogPath
    exit 2
}

Write-Log "Administrator check: PASS" -Level INFO -LogFile $LogPath

# Check Chocolatey is installed (FR-013 prerequisite check)
$chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
if (-not $chocoCmd) {
    Write-Log "ERROR: Chocolatey is not installed. Please run install-choco.ps1 first." -Level ERROR -LogFile $LogPath
    exit 2
}

Write-Log "Chocolatey prerequisite check: PASS" -Level INFO -LogFile $LogPath

# Define core tools to install
$coreTools = @(
    @{ Name = 'git'; Command = 'git'; DisplayName = 'Git' }
    @{ Name = 'nodejs'; Command = 'node'; DisplayName = 'Node.js' }
    @{ Name = 'pnpm'; Command = 'pnpm'; DisplayName = 'pnpm' }
)

# Track installation results
$installResults = @{
    Success = @()
    Skipped = @()
    Failed = @()
}

# Install each tool
foreach ($tool in $coreTools) {
    Write-Log "Processing $($tool.DisplayName)..." -Level INFO -LogFile $LogPath

    # Check if already installed (idempotency - FR-009)
    $localPackage = choco list --local-only --exact $tool.Name 2>&1 | Select-String -Pattern "^$($tool.Name) "
    $toolCmd = Get-Command $tool.Command -ErrorAction SilentlyContinue
    $toolInstalled = ($localPackage -or $toolCmd)

    if ($toolInstalled) {
        Write-Log "$($tool.DisplayName) is already installed. Skipping." -Level WARN -LogFile $LogPath
        $installResults.Skipped += $tool.DisplayName
        continue
    }

    # WhatIf mode (FR-011)
    if ($WhatIfPreference -eq 'Continue') {
        Write-Log "WhatIf: Would install $($tool.DisplayName) via 'choco install $($tool.Name) -y'" -Level INFO -LogFile $LogPath
        continue
    }

    # Install the tool
    try {
        Write-Log "Installing $($tool.DisplayName)..." -Level INFO -LogFile $LogPath

        $installOutput = choco install $tool.Name -y 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Chocolatey install command failed with exit code $LASTEXITCODE"
        }

        Write-Log "$($tool.DisplayName) installation command completed." -Level INFO -LogFile $LogPath

        # Refresh environment variables for current session
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # Validate tool is in PATH (FR-015)
        $toolCommand = Get-Command $tool.Command -ErrorAction SilentlyContinue

        if (-not $toolCommand) {
            Write-Log "WARNING: $($tool.DisplayName) installed but '$($tool.Command)' not found in PATH. May require session restart." -Level WARN -LogFile $LogPath
        } else {
            Write-Log "$($tool.DisplayName) is now available in PATH: $($toolCommand.Source)" -Level INFO -LogFile $LogPath
        }

        $installResults.Success += $tool.DisplayName
    }
    catch {
        Write-Log "ERROR: Failed to install $($tool.DisplayName): $($_.Exception.Message)" -Level ERROR -LogFile $LogPath
        $installResults.Failed += $tool.DisplayName
    }
}

# Summary
Write-Log "=== Installation Summary ===" -Level INFO -LogFile $LogPath
Write-Log "Successfully installed: $($installResults.Success.Count) ($($installResults.Success -join ', '))" -Level INFO -LogFile $LogPath
Write-Log "Skipped (already installed): $($installResults.Skipped.Count) ($($installResults.Skipped -join ', '))" -Level INFO -LogFile $LogPath
Write-Log "Failed: $($installResults.Failed.Count) ($($installResults.Failed -join ', '))" -Level INFO -LogFile $LogPath

if ($installResults.Failed.Count -gt 0) {
    Write-Log "=== Core Tools Installation Script Completed with Errors ===" -Level ERROR -LogFile $LogPath
    exit 1
}

Write-Log "=== Core Tools Installation Script Completed Successfully ===" -Level INFO -LogFile $LogPath
exit 0
