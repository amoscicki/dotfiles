<#
.SYNOPSIS
    Installs Chocolatey package manager if not already installed.

.DESCRIPTION
    Checks if Chocolatey is already installed (idempotency check), and installs
    it from https://chocolatey.org/install if needed. Requires Administrator
    privileges and internet connectivity.

.PARAMETER WhatIf
    Preview actions without executing them (dry-run mode).

.PARAMETER Verbose
    Enable detailed diagnostic output.

.PARAMETER LogPath
    Path to the log file. Defaults to logs/install-choco-YYYYMMDD-HHmmss.log

.OUTPUTS
    Exit code 0 on success, 1 on failure, 2 if prerequisites not met.

.EXAMPLE
    PS> .\install-choco.ps1
    Installs Chocolatey with default settings.

.EXAMPLE
    PS> .\install-choco.ps1 -WhatIf
    Previews what would be installed without making changes.

.EXAMPLE
    PS> .\install-choco.ps1 -Verbose -LogPath "C:\Logs\choco.log"
    Installs with detailed logging to a custom log file.

.NOTES
    Part of User Story 1 (P1): Install Core Development Tools
    Requires: Administrator privileges, internet connectivity
    See: specs/001-windows-setup-automation/spec.md FR-001, FR-008, FR-009
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$WhatIf,
    [switch]$Verbose,
    [string]$LogPath
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Resolve script directory and import utilities
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\utils\Test-Administrator.ps1"
. "$scriptRoot\utils\Write-Log.ps1"
. "$scriptRoot\utils\Test-Idempotent.ps1"

# Setup logging
if (-not $LogPath) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogPath = Join-Path $scriptRoot "..\logs\install-choco-$timestamp.log"
}

# Ensure log directory exists
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Log "=== Chocolatey Installation Script Started ===" -Level INFO -LogFile $LogPath

# Check Administrator privileges (FR-008)
if (-not (Test-Administrator)) {
    Write-Log "ERROR: Administrator privileges required. Please run PowerShell as Administrator." -Level ERROR -LogFile $LogPath
    exit 2
}

Write-Log "Administrator check: PASS" -Level INFO -LogFile $LogPath

# Check if Chocolatey already installed (FR-009: Idempotency)
$chocoInstalled = Test-Idempotent -Check {
    Get-Command choco -ErrorAction SilentlyContinue
}

if ($chocoInstalled) {
    Write-Log "Chocolatey is already installed. Skipping installation." -Level WARN -LogFile $LogPath
    $chocoVersion = choco --version
    Write-Log "Installed version: $chocoVersion" -Level INFO -LogFile $LogPath
    exit 0
}

# WhatIf mode (FR-011)
if ($WhatIf) {
    Write-Log "WhatIf: Would install Chocolatey from https://chocolatey.org/install" -Level INFO -LogFile $LogPath
    exit 0
}

# Install Chocolatey
Write-Log "Installing Chocolatey package manager..." -Level INFO -LogFile $LogPath

try {
    # Download and execute Chocolatey install script
    Write-Log "Downloading Chocolatey installer..." -Level INFO -LogFile $LogPath

    $installScript = Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing

    Write-Log "Executing Chocolatey installer..." -Level INFO -LogFile $LogPath

    Invoke-Expression $installScript.Content

    # Refresh environment variables for current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # Validate installation (FR-015)
    $chocoCommand = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoCommand) {
        throw "Chocolatey installation completed but 'choco' command not found in PATH"
    }

    $chocoVersion = choco --version
    Write-Log "Chocolatey installed successfully. Version: $chocoVersion" -Level INFO -LogFile $LogPath

    Write-Log "=== Chocolatey Installation Script Completed Successfully ===" -Level INFO -LogFile $LogPath
    exit 0
}
catch {
    Write-Log "ERROR: Chocolatey installation failed: $($_.Exception.Message)" -Level ERROR -LogFile $LogPath
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -LogFile $LogPath
    exit 1
}
