<#
.SYNOPSIS
    Installs development tools and packages from packages.json via Chocolatey.

.DESCRIPTION
    Installs packages from groups defined in packages.json. In interactive mode,
    allows selection of specific package groups and packages. In non-interactive
    mode, installs all packages from all groups. Performs idempotency checks for
    each package and continues with remaining packages if some fail.

.PARAMETER Interactive
    Enable interactive mode to select package groups and specific packages.
    Without this flag, all packages from packages.json will be installed.

.PARAMETER LogPath
    Path to the log file. Defaults to logs/install-tools-YYYYMMDD-HHmmss.log

.OUTPUTS
    Exit code 0 even if some packages fail (resilient mode), 1 on fatal error.

.EXAMPLE
    PS> .\install-tools.ps1 -Interactive
    Shows interactive menu to select package groups and packages

.EXAMPLE
    PS> .\install-tools.ps1
    Installs all packages from packages.json automatically

.NOTES
    Part of User Story 2 (P2): Install Extended Development Packages
    Requires: Administrator privileges, Chocolatey installed, PwshSpectreConsole module
    See: specs/001-windows-setup-automation/spec.md FR-004, data-model.md §1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Interactive,

    [string]$LogPath
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Resolve script directory
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

#region Spectre Console Setup

# Ensure PwshSpectreConsole module is installed
if (-not (Get-Module -ListAvailable -Name PwshSpectreConsole)) {
    Write-Host 'Installing PwshSpectreConsole module...' -ForegroundColor Yellow
    Install-Module -Name PwshSpectreConsole -Scope CurrentUser -Force -SkipPublisherCheck
}

# Import module
Import-Module PwshSpectreConsole -Force

#endregion

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

# Show-MultiSelectMenu: Display a checkbox-style menu for selecting items using Spectre Console
function Show-MultiSelectMenu {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [array]$Items,

        [Parameter(Mandatory = $false)]
        [string]$Property = $null,

        [Parameter(Mandatory = $false)]
        [bool]$AllSelected = $true
    )

    # Prepare choices for Spectre
    $choices = @()
    if ($Property) {
        foreach ($item in $Items) {
            $choices += $item.$Property
        }
    } else {
        $choices = $Items
    }

    # Show multi-selection prompt with Spectre
    $selectedChoices = Read-SpectreMultiSelection -Title $Title -Choices $choices -PageSize 15

    # Map selected choices back to original items
    $selectedItems = @()
    if ($Property) {
        foreach ($choice in $selectedChoices) {
            foreach ($item in $Items) {
                if ($item.$Property -eq $choice) {
                    $selectedItems += $item
                    break
                }
            }
        }
    } else {
        $selectedItems = $selectedChoices
    }

    return $selectedItems
}

#endregion

# Setup logging
if (-not $LogPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logFileName = 'install-tools-' + $timestamp + '.log'
    $LogPath = Join-Path $scriptRoot ('..\logs\' + $logFileName)
}

# Ensure log directory exists
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Log '=== Extended Tools Installation Script Started ===' -Level INFO -LogFile $LogPath

# Check Administrator privileges (FR-008)
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

# Load packages based on mode (Interactive or File-based)
$packages = @()

if ($Interactive) {
    Write-Log 'Interactive mode enabled' -Level INFO -LogFile $LogPath

    # Check if packages.json exists
    $packagesJsonPath = Join-Path $scriptRoot 'packages.json'
    if (-not (Test-Path $packagesJsonPath)) {
        $notFoundMsg = 'ERROR: packages.json not found at: ' + $packagesJsonPath
        Write-Log $notFoundMsg -Level ERROR -LogFile $LogPath
        Write-Log 'Interactive mode requires packages.json configuration file' -Level ERROR -LogFile $LogPath
        exit 3
    }

    try {
        # Load and parse JSON configuration
        $config = Get-Content $packagesJsonPath -Raw | ConvertFrom-Json

        # Show group selection menu
        Write-Host ''
        $selectedGroups = Show-MultiSelectMenu -Title 'Select Package Groups to Install' -Items $config.groups -Property 'name'

        if ($selectedGroups.Count -eq 0) {
            Write-Log 'No groups selected. Exiting.' -Level WARN -LogFile $LogPath
            exit 0
        }

        # For each selected group, show package selection menu
        foreach ($group in $selectedGroups) {
            Write-Host ''
            $groupName = $group.name
            $groupDesc = $group.description

            $menuTitle = $groupName + ' - ' + $groupDesc
            $packageObjects = @()
            foreach ($pkg in $group.packages) {
                $displayText = $pkg.name + ' - ' + $pkg.description
                $packageObjects += [PSCustomObject]@{
                    Display = $displayText
                    Name = $pkg.name
                }
            }

            $selectedPackages = Show-MultiSelectMenu -Title $menuTitle -Items $packageObjects -Property 'Display'

            foreach ($pkg in $selectedPackages) {
                $packages += $pkg.Name
            }
        }

        Write-Host ''
        $pkgCountMsg = 'Selected ' + $packages.Count + ' packages for installation'
        Write-Log $pkgCountMsg -Level INFO -LogFile $LogPath
    }
    catch {
        $errorMsg = 'ERROR: Failed to load packages.json: ' + $_.Exception.Message
        Write-Log $errorMsg -Level ERROR -LogFile $LogPath
        exit 3
    }
}
else {
    # Automatic mode - install all packages from packages.json
    Write-Log 'Automatic mode - installing all packages from packages.json' -Level INFO -LogFile $LogPath

    # Check if packages.json exists
    $packagesJsonPath = Join-Path $scriptRoot 'packages.json'
    if (-not (Test-Path $packagesJsonPath)) {
        $notFoundMsg = 'ERROR: packages.json not found at: ' + $packagesJsonPath
        Write-Log $notFoundMsg -Level ERROR -LogFile $LogPath
        exit 3
    }

    try {
        # Load and parse JSON configuration
        $config = Get-Content $packagesJsonPath -Raw | ConvertFrom-Json

        # Collect all packages from all groups
        foreach ($group in $config.groups) {
            foreach ($pkg in $group.packages) {
                $packages += $pkg.name
            }
        }

        $pkgCountMsg = 'Found ' + $packages.Count + ' packages across all groups'
        Write-Log $pkgCountMsg -Level INFO -LogFile $LogPath
    }
    catch {
        $errorMsg = 'ERROR: Failed to load packages.json: ' + $_.Exception.Message
        Write-Log $errorMsg -Level ERROR -LogFile $LogPath
        exit 3
    }
}

# Check if any packages were selected
if ($packages.Count -eq 0) {
    Write-Log 'WARNING: No packages selected. Nothing to install.' -Level WARN -LogFile $LogPath
    exit 0
}

# Track installation results
$installResults = @{
    Success = @()
    Skipped = @()
    Failed = @()
    RebootRequired = @()
}

# Install each package
foreach ($package in $packages) {
    $procMsg = 'Processing package: ' + $package
    Write-Log $procMsg -Level INFO -LogFile $LogPath

    # Check if package is already installed (idempotency - FR-009)
    $packagePattern = '^' + $package + ' '
    $localPackage = choco list --local-only --exact $package 2>&1 | Select-String -Pattern $packagePattern
    if ($localPackage) {
        $skipMsg = $package + ' is already installed. Skipping.'
        Write-Log $skipMsg -Level WARN -LogFile $LogPath
        $installResults.Skipped += $package
        continue
    }

    # WhatIf mode (FR-011)
    if ($WhatIfPreference -eq 'Continue') {
        $whatIfMsg = 'WhatIf: Would install ' + $package + ' via choco install ' + $package + ' -y'
        Write-Log $whatIfMsg -Level INFO -LogFile $LogPath
        continue
    }

    # Install the package
    try {
        $installMsg = 'Installing ' + $package + '...'
        Write-Log $installMsg -Level INFO -LogFile $LogPath

        $installOutput = choco install $package -y 2>&1

        # Exit codes: 0 = success, 3010 = success but reboot required
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
            $errorMsg = 'Chocolatey install command failed with exit code ' + $LASTEXITCODE
            throw $errorMsg
        }

        if ($LASTEXITCODE -eq 3010) {
            $rebootMsg = $package + ' installation completed successfully (reboot required).'
            Write-Log $rebootMsg -Level WARN -LogFile $LogPath
            $installResults.RebootRequired += $package
        }
        else {
            $successMsg = $package + ' installation completed successfully.'
            Write-Log $successMsg -Level INFO -LogFile $LogPath
        }

        $installResults.Success += $package
    }
    catch {
        $errorMsg = 'ERROR: Failed to install ' + $package + ': ' + $_.Exception.Message
        Write-Log $errorMsg -Level ERROR -LogFile $LogPath
        $installResults.Failed += $package
        # Continue with next package (resilient mode - continue on failure)
    }
}

# Refresh environment variables for current session
$machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = $machinePath + ';' + $userPath

# Validate oh-my-posh is accessible (FR-015, US2 acceptance scenario 4)
$ohMyPoshCommand = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($ohMyPoshCommand) {
    $poshPath = $ohMyPoshCommand.Source
    $logMsg = 'oh-my-posh is available in PATH: ' + $poshPath
    Write-Log $logMsg -Level INFO -LogFile $LogPath
} else {
    Write-Log 'WARNING: oh-my-posh not found in PATH. May require session restart if it was just installed.' -Level WARN -LogFile $LogPath
}

# Summary report
Write-Log '=== Installation Summary ===' -Level INFO -LogFile $LogPath
$totalMsg = 'Total packages processed: ' + $packages.Count
Write-Log $totalMsg -Level INFO -LogFile $LogPath
$successMsg = 'Successfully installed: ' + $installResults.Success.Count
Write-Log $successMsg -Level INFO -LogFile $LogPath
if ($installResults.Success.Count -gt 0) {
    $successList = '  - ' + ($installResults.Success -join ', ')
    Write-Log $successList -Level INFO -LogFile $LogPath
}
$skippedMsg = 'Skipped (already installed): ' + $installResults.Skipped.Count
Write-Log $skippedMsg -Level INFO -LogFile $LogPath
if ($installResults.Skipped.Count -gt 0) {
    $skippedList = '  - ' + ($installResults.Skipped -join ', ')
    Write-Log $skippedList -Level INFO -LogFile $LogPath
}
$failedMsg = 'Failed: ' + $installResults.Failed.Count
Write-Log $failedMsg -Level INFO -LogFile $LogPath
if ($installResults.Failed.Count -gt 0) {
    $failedList = '  - ' + ($installResults.Failed -join ', ')
    Write-Log $failedList -Level ERROR -LogFile $LogPath
}

# Display reboot warning if any packages require it
if ($installResults.RebootRequired.Count -gt 0) {
    Write-Log '' -Level INFO -LogFile $LogPath
    Write-Log 'IMPORTANT: System reboot required for the following packages:' -Level WARN -LogFile $LogPath
    $rebootList = '  - ' + ($installResults.RebootRequired -join ', ')
    Write-Log $rebootList -Level WARN -LogFile $LogPath
    Write-Log 'Please restart your computer to complete the installation.' -Level WARN -LogFile $LogPath
}

# Exit with code 0 even if some packages failed (resilient mode)
# Fatal errors (missing prerequisites, file not found) exit with non-zero earlier
if ($installResults.Failed.Count -gt 0) {
    Write-Log '=== Extended Tools Installation Script Completed with Some Failures ===' -Level WARN -LogFile $LogPath
} else {
    Write-Log '=== Extended Tools Installation Script Completed Successfully ===' -Level INFO -LogFile $LogPath
}

exit 0
