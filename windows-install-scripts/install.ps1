<#
.SYNOPSIS
    Master orchestration script for Windows 11 development environment setup.

.DESCRIPTION
    Orchestrates the complete setup process by running all installation and
    configuration scripts in sequence. Handles prerequisites checking, error
    recovery, and displays post-installation instructions. Supports idempotent
    execution for safe resumption after interruptions.

.PARAMETER Force
    Skip confirmations in child scripts (passed to symlink.ps1).

.PARAMETER Unattended
    Full automation mode - no user interaction required. Implies -Force for
    symlink operations. Suitable for CI/CD or scripted deployments.

.PARAMETER LogPath
    Path to the master log file. Defaults to logs/install-YYYYMMDD-HHmmss.log

.OUTPUTS
    Exit code 0 on success, 1 on failure, 2 if prerequisites not met.

.EXAMPLE
    PS> .\install.ps1
    Interactive installation with confirmation prompts.

.EXAMPLE
    PS> .\install.ps1 -Unattended
    Fully automated installation for CI/CD or unattended scenarios.

.EXAMPLE
    PS> .\install.ps1 -WhatIf
    Preview the complete installation process without making changes.

.EXAMPLE
    PS> .\install.ps1 -Verbose
    Install with detailed logging and diagnostic output.

.NOTES
    Part of User Story 5 (P5): Master Setup Script (End-to-End)
    Requires: Administrator privileges, internet connectivity, Windows 11
    See: specs/001-windows-setup-automation/spec.md FR-007, FR-012, SC-001
    Execution time: ~30 minutes (excluding package downloads)
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force,
    [switch]$Unattended,
    [string]$LogPath
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Resolve script directory
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$dotfilesRoot = Split-Path -Parent $scriptRoot

#region Utility Functions

# Test-Administrator: Check if running with admin privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Write-Log: Write timestamped log messages to console and file
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

    $colors = @{
        'INFO'  = 'Green'
        'WARN'  = 'Yellow'
        'ERROR' = 'Red'
        'DEBUG' = 'Cyan'
    }

    Write-Host $logEntry -ForegroundColor $colors[$Level]

    if ($LogFile) {
        try {
            $logDir = Split-Path -Path $LogFile -Parent
            if ($logDir -and -not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write to log file '$LogFile': $_"
        }
    }
}

#endregion

# Setup logging
if (-not $LogPath) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogPath = Join-Path $scriptRoot "..\logs\install-$timestamp.log"
}

# Ensure log directory exists
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Log "===============================================================================" -Level INFO -LogFile $LogPath
Write-Log "  Windows 11 Development Environment Setup" -Level INFO -LogFile $LogPath
Write-Log "  Master Installation Script" -Level INFO -LogFile $LogPath
Write-Log "===============================================================================" -Level INFO -LogFile $LogPath
Write-Log "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level INFO -LogFile $LogPath
Write-Log "Dotfiles root: $dotfilesRoot" -Level INFO -LogFile $LogPath
Write-Log "Log file: $LogPath" -Level INFO -LogFile $LogPath
Write-Log "Parameters: WhatIf=$WhatIfPreference, Force=$Force, Unattended=$Unattended, Verbose=$($VerbosePreference -ne 'SilentlyContinue')" -Level INFO -LogFile $LogPath
Write-Log "===============================================================================" -Level INFO -LogFile $LogPath

# Check Administrator privileges (FR-008)
Write-Log "Checking prerequisites..." -Level INFO -LogFile $LogPath

if (-not (Test-Administrator)) {
    Write-Log "ERROR: Administrator privileges required." -Level ERROR -LogFile $LogPath
    Write-Log "Please right-click PowerShell and select 'Run as Administrator'" -Level ERROR -LogFile $LogPath
    exit 2
}

Write-Log "Administrator privileges: PASS" -Level INFO -LogFile $LogPath

# Check Windows version (Edge Case - warn if not Windows 11)
$osVersion = [System.Environment]::OSVersion.Version
Write-Log "Detected OS version: $($osVersion.Major).$($osVersion.Minor).$($osVersion.Build)" -Level INFO -LogFile $LogPath

# Windows 11 is version 10.0.22000 or higher
# Windows 10 is version 10.0.10240-19045
if ($osVersion.Major -eq 10 -and $osVersion.Build -ge 22000) {
    Write-Log "Windows 11 detected: PASS" -Level INFO -LogFile $LogPath
}
elseif ($osVersion.Major -eq 10) {
    Write-Log "WARNING: Windows 10 detected (Build $($osVersion.Build)). This script is optimized for Windows 11." -Level WARN -LogFile $LogPath
    Write-Log "Continuing installation, but some features may behave differently." -Level WARN -LogFile $LogPath
}
else {
    Write-Log "WARNING: Unexpected Windows version detected. Proceed with caution." -Level WARN -LogFile $LogPath
}

# Define installation steps
$steps = @(
    @{
        Name = "Install Chocolatey Package Manager"
        Script = "install-choco.ps1"
        Critical = $true
    }
    @{
        Name = "Install Core Development Tools (Git, Node.js, pnpm)"
        Script = "install-core-tools.ps1"
        Critical = $true
    }
    @{
        Name = "Install Extended Development Packages"
        Script = "install-tools.ps1"
        Critical = $false  # Can continue if some packages fail
    }
    @{
        Name = "Create Configuration Symlinks"
        Script = "symlink.ps1"
        Critical = $true
    }
)

# Track execution results
$results = @{
    Success = @()
    Failed = @()
    Skipped = @()
}

$startTime = Get-Date

# Execute each installation step
foreach ($step in $steps) {
    $stepNum = $steps.IndexOf($step) + 1
    $totalSteps = $steps.Count

    Write-Log "" -Level INFO -LogFile $LogPath
    Write-Log "===============================================================================" -Level INFO -LogFile $LogPath
    Write-Log "Step ${stepNum}/${totalSteps}: $($step.Name)" -Level INFO -LogFile $LogPath
    Write-Log "===============================================================================" -Level INFO -LogFile $LogPath

    $scriptPath = Join-Path $scriptRoot $step.Script

    if (-not (Test-Path $scriptPath)) {
        Write-Log "ERROR: Script not found: $scriptPath" -Level ERROR -LogFile $LogPath

        if ($step.Critical) {
            Write-Log "This is a critical step. Aborting installation." -Level ERROR -LogFile $LogPath
            $results.Failed += $step.Name
            break
        }
        else {
            Write-Log "This is a non-critical step. Continuing with next step." -Level WARN -LogFile $LogPath
            $results.Skipped += $step.Name
            continue
        }
    }

    # Build parameter list for child script
    $scriptParams = @{
        LogPath = $LogPath
    }

    if ($WhatIfPreference -eq 'Continue') {
        $scriptParams['WhatIf'] = $true
    }

    if ($VerbosePreference -ne 'SilentlyContinue') {
        $scriptParams['Verbose'] = $true
    }

    # Special handling for symlink.ps1: pass -Force if -Unattended specified (FR-007)
    if ($step.Script -eq 'symlink.ps1') {
        if ($Unattended -or $Force) {
            $scriptParams['Force'] = $true
            Write-Log "Symlink script will run with -Force (no confirmations)" -Level INFO -LogFile $LogPath
        }
    }

    # Execute the script
    try {
        Write-Log "Executing: $scriptPath" -Level INFO -LogFile $LogPath

        $scriptBlock = {
            param($Path, $Params)
            & $Path @Params
        }

        # Execute and capture exit code
        & $scriptBlock -Path $scriptPath -Params $scriptParams

        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Log "Step completed successfully (exit code: $exitCode)" -Level INFO -LogFile $LogPath
            $results.Success += $step.Name
        }
        else {
            Write-Log "Step completed with exit code: $exitCode" -Level WARN -LogFile $LogPath

            if ($step.Critical) {
                Write-Log "Critical step failed. Aborting installation." -Level ERROR -LogFile $LogPath
                $results.Failed += $step.Name
                break
            }
            else {
                Write-Log "Non-critical step failed. Continuing with next step." -Level WARN -LogFile $LogPath
                $results.Failed += $step.Name
            }
        }
    }
    catch {
        Write-Log "ERROR: Exception during step execution: $($_.Exception.Message)" -Level ERROR -LogFile $LogPath
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -LogFile $LogPath

        if ($step.Critical) {
            Write-Log "Critical step failed with exception. Aborting installation." -Level ERROR -LogFile $LogPath
            $results.Failed += $step.Name
            break
        }
        else {
            Write-Log "Non-critical step failed with exception. Continuing with next step." -Level WARN -LogFile $LogPath
            $results.Failed += $step.Name
        }
    }
}

$endTime = Get-Date
$duration = $endTime - $startTime

# Final summary
Write-Log "" -Level INFO -LogFile $LogPath
Write-Log "===============================================================================" -Level INFO -LogFile $LogPath
Write-Log "  Installation Summary" -Level INFO -LogFile $LogPath
Write-Log "===============================================================================" -Level INFO -LogFile $LogPath
Write-Log "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level INFO -LogFile $LogPath
Write-Log "Duration: $($duration.Minutes) minutes, $($duration.Seconds) seconds" -Level INFO -LogFile $LogPath
Write-Log "" -Level INFO -LogFile $LogPath
Write-Log "Successful steps: $($results.Success.Count)" -Level INFO -LogFile $LogPath
foreach ($item in $results.Success) {
    Write-Log "  [OK] $item" -Level INFO -LogFile $LogPath
}

if ($results.Failed.Count -gt 0) {
    Write-Log "" -Level INFO -LogFile $LogPath
    Write-Log "Failed steps: $($results.Failed.Count)" -Level ERROR -LogFile $LogPath
    foreach ($item in $results.Failed) {
        Write-Log "  [FAIL] $item" -Level ERROR -LogFile $LogPath
    }
}

if ($results.Skipped.Count -gt 0) {
    Write-Log "" -Level INFO -LogFile $LogPath
    Write-Log "Skipped steps: $($results.Skipped.Count)" -Level WARN -LogFile $LogPath
    foreach ($item in $results.Skipped) {
        Write-Log "  - $item" -Level WARN -LogFile $LogPath
    }
}

# Post-installation instructions (FR-012, FR-014, FR-018)
if ($results.Failed.Count -eq 0 -and $WhatIfPreference -ne 'Continue') {
    Write-Log "" -Level INFO -LogFile $LogPath
    Write-Log "===============================================================================" -Level INFO -LogFile $LogPath
    Write-Log "  Post-Installation Steps (REQUIRED)" -Level INFO -LogFile $LogPath
    Write-Log "===============================================================================" -Level INFO -LogFile $LogPath
    Write-Log "" -Level INFO -LogFile $LogPath
    Write-Log "1. UPDATE GIT CONFIGURATION (Required):" -Level INFO -LogFile $LogPath
    Write-Log "   Run these commands to set your Git identity:" -Level INFO -LogFile $LogPath
    Write-Log "   git config --global user.name `"Your Name`"" -Level INFO -LogFile $LogPath
    Write-Log "   git config --global user.email `"your.email@example.com`"" -Level INFO -LogFile $LogPath
    Write-Log "" -Level INFO -LogFile $LogPath
    Write-Log "2. INSTALL CLAUDE CODE PLUGIN (Optional):" -Level INFO -LogFile $LogPath
    Write-Log "   If you have Claude Code installed, run:" -Level INFO -LogFile $LogPath
    Write-Log "   /plugin install file://$dotfilesRoot" -Level INFO -LogFile $LogPath
    Write-Log "   Or from GitHub:" -Level INFO -LogFile $LogPath
    Write-Log "   /plugin install github.com/amoscicki/dotfiles" -Level INFO -LogFile $LogPath
    Write-Log "" -Level INFO -LogFile $LogPath
    Write-Log "3. RESTART POWERSHELL (Required):" -Level INFO -LogFile $LogPath
    Write-Log "   Close and reopen PowerShell to load the new profile" -Level INFO -LogFile $LogPath
    Write-Log "   with Oh My Posh theme and Chocolatey helpers" -Level INFO -LogFile $LogPath
    Write-Log "" -Level INFO -LogFile $LogPath
    Write-Log "4. VERIFY INSTALLATION:" -Level INFO -LogFile $LogPath
    Write-Log "   Run these commands to verify tools are installed:" -Level INFO -LogFile $LogPath
    Write-Log "   choco --version" -Level INFO -LogFile $LogPath
    Write-Log "   git --version" -Level INFO -LogFile $LogPath
    Write-Log "   node --version" -Level INFO -LogFile $LogPath
    Write-Log "   pnpm --version" -Level INFO -LogFile $LogPath
    Write-Log "   gh --version" -Level INFO -LogFile $LogPath
    Write-Log "   fzf --version" -Level INFO -LogFile $LogPath
    Write-Log "   oh-my-posh --version" -Level INFO -LogFile $LogPath
    Write-Log "" -Level INFO -LogFile $LogPath
    Write-Log "===============================================================================" -Level INFO -LogFile $LogPath
}

# Exit with appropriate code
if ($results.Failed.Count -gt 0) {
    Write-Log "Installation completed with errors. Check log for details: $LogPath" -Level ERROR -LogFile $LogPath
    exit 1
}
else {
    Write-Log "Installation completed successfully!" -Level INFO -LogFile $LogPath
    Write-Log "Log saved to: $LogPath" -Level INFO -LogFile $LogPath
    exit 0
}
