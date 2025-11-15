<#
.SYNOPSIS
    Installs PowerShell Core (pwsh) via Chocolatey.

.DESCRIPTION
    Installs the latest version of PowerShell 7+ using Chocolatey package manager.
    PowerShell Core is required for modern PowerShell modules and enhanced functionality.
    Performs idempotency check to skip if already installed.

.PARAMETER LogPath
    Path to the log file. Defaults to logs/install-pwsh-YYYYMMDD-HHmmss.log

.OUTPUTS
    Exit code 0 on success, 2 if prerequisites not met, 3 on installation failure.

.EXAMPLE
    PS> .\install-pwsh.ps1
    Installs PowerShell Core via Chocolatey

.NOTES
    Requires: Administrator privileges, Chocolatey installed
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
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = '[' + $timestamp + '] [' + $Level + '] ' + $Message
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
            $warnMsg = 'Failed to write to log file ' + $LogFile + ': ' + $_
            Write-Warning $warnMsg
        }
    }
}

#endregion

# Setup logging
if (-not $LogPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logFileName = 'install-pwsh-' + $timestamp + '.log'
    $LogPath = Join-Path $scriptRoot ('..\logs\' + $logFileName)
}

# Ensure log directory exists
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Log '=== PowerShell Core Installation Script Started ===' -Level INFO -LogFile $LogPath

# Check Administrator privileges
if (-not (Test-Administrator)) {
    Write-Log 'ERROR: Administrator privileges required. Please run PowerShell as Administrator.' -Level ERROR -LogFile $LogPath
    exit 2
}

Write-Log 'Administrator check: PASS' -Level INFO -LogFile $LogPath

# Check Chocolatey is installed
$chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
if (-not $chocoCmd) {
    Write-Log 'ERROR: Chocolatey is not installed. Please run install-choco.ps1 first.' -Level ERROR -LogFile $LogPath
    exit 2
}

Write-Log 'Chocolatey prerequisite check: PASS' -Level INFO -LogFile $LogPath

# Check if PowerShell Core is already installed
$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshCmd) {
    $version = & pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
    Write-Log 'PowerShell Core is already installed. Skipping.' -Level WARN -LogFile $LogPath
    $versionMsg = 'Installed version: ' + $version
    Write-Log $versionMsg -Level INFO -LogFile $LogPath
    exit 0
}

# WhatIf mode
if ($WhatIfPreference -eq 'Continue') {
    Write-Log 'WhatIf: Would install PowerShell Core via choco install powershell-core -y' -Level INFO -LogFile $LogPath
    exit 0
}

# Install PowerShell Core
try {
    Write-Log 'Installing PowerShell Core...' -Level INFO -LogFile $LogPath

    $installOutput = choco install powershell-core -y 2>&1

    # Exit codes: 0 = success, 3010 = success but reboot required
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
        $errorMsg = 'Chocolatey install command failed with exit code ' + $LASTEXITCODE
        throw $errorMsg
    }

    if ($LASTEXITCODE -eq 3010) {
        Write-Log 'PowerShell Core installation completed successfully (reboot required).' -Level WARN -LogFile $LogPath
    }
    else {
        Write-Log 'PowerShell Core installation completed successfully.' -Level INFO -LogFile $LogPath
    }

    # Refresh environment variables
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = $machinePath + ';' + $userPath

    # Verify installation
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        $version = & pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
        $verifyMsg = 'PowerShell Core is now available: ' + $pwshCmd.Source
        Write-Log $verifyMsg -Level INFO -LogFile $LogPath
        $versionMsg = 'Version: ' + $version
        Write-Log $versionMsg -Level INFO -LogFile $LogPath
    } else {
        Write-Log 'WARNING: pwsh not found in PATH. May require session restart.' -Level WARN -LogFile $LogPath
    }
}
catch {
    $errorMsg = 'ERROR: Failed to install PowerShell Core: ' + $_.Exception.Message
    Write-Log $errorMsg -Level ERROR -LogFile $LogPath
    exit 3
}

Write-Log '=== PowerShell Core Installation Script Completed Successfully ===' -Level INFO -LogFile $LogPath
exit 0
