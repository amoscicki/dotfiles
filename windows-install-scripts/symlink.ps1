<#
.SYNOPSIS
    Creates symbolic links from dotfiles to system configuration locations.

.DESCRIPTION
    Creates symlinks for PowerShell profile, Git configuration, and Wezterm config
    from the dotfiles repository to their respective system locations. Backs up
    existing files with timestamps before creating symlinks. Supports confirmation
    prompts unless -Force is specified.

.PARAMETER Force
    Skip confirmation prompts when overwriting existing files.

.PARAMETER LogPath
    Path to the log file. Defaults to logs/symlink-YYYYMMDD-HHmmss.log

.OUTPUTS
    Exit code 0 on success, 1 on failure, 2 if prerequisites not met.

.EXAMPLE
    PS> .\symlink.ps1
    Creates symlinks with confirmation prompts for existing files.

.EXAMPLE
    PS> .\symlink.ps1 -Force
    Creates symlinks without confirmation prompts.

.EXAMPLE
    PS> .\symlink.ps1 -WhatIf
    Previews what symlinks would be created without making changes.

.NOTES
    Part of User Story 3 (P3): Apply Configuration Files via Symlinks
    Requires: Administrator privileges, configuration files exist in dotfiles/
    See: specs/001-windows-setup-automation/spec.md FR-005, FR-006, data-model.md §4
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force,
    [string]$LogPath
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Resolve script directory
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$dotfilesRoot = Split-Path -Parent $scriptRoot

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
    $LogPath = Join-Path $scriptRoot "..\logs\symlink-$timestamp.log"
}

# Ensure log directory exists
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Log "=== Symlink Configuration Script Started ===" -Level INFO -LogFile $LogPath
Write-Log "Dotfiles root: $dotfilesRoot" -Level INFO -LogFile $LogPath

# Check Administrator privileges (FR-008)
if (-not (Test-Administrator)) {
    Write-Log "ERROR: Administrator privileges required for symlink creation. Please run PowerShell as Administrator." -Level ERROR -LogFile $LogPath
    exit 2
}

Write-Log "Administrator check: PASS" -Level INFO -LogFile $LogPath

# Define symlink mappings (data-model.md §4)
$symlinkMappings = @(
    @{
        Source = Join-Path $dotfilesRoot "powershell\Microsoft.PowerShell_profile.ps1"
        Target = $PROFILE.CurrentUserAllHosts
        Description = "PowerShell 5.1 profile (Windows PowerShell)"
    }
    @{
        Source = Join-Path $dotfilesRoot "powershell\Microsoft.PowerShell_profile.ps1"
        Target = Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        Description = "PowerShell 7+ profile (pwsh)"
    }
    @{
        Source = Join-Path $dotfilesRoot "git\.gitconfig"
        Target = Join-Path $HOME ".gitconfig"
        Description = "Git global configuration"
    }
    @{
        Source = Join-Path $dotfilesRoot "wezterm\wezterm.lua"
        Target = Join-Path $HOME ".wezterm.lua"
        Description = "Wezterm terminal configuration"
    }
)

# Validate all source files exist before proceeding
Write-Log "Validating source files..." -Level INFO -LogFile $LogPath
$missingFiles = @()

foreach ($mapping in $symlinkMappings) {
    if (-not (Test-Path $mapping.Source)) {
        $missingFiles += $mapping.Source
        Write-Log "ERROR: Source file missing: $($mapping.Source)" -Level ERROR -LogFile $LogPath
    } else {
        Write-Log "Source exists: $($mapping.Source)" -Level DEBUG -LogFile $LogPath
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Log "ERROR: $($missingFiles.Count) source file(s) missing. Cannot proceed." -Level ERROR -LogFile $LogPath
    exit 3
}

Write-Log "All source files validated successfully." -Level INFO -LogFile $LogPath

# Track results
$results = @{
    Created = @()
    Skipped = @()
    Failed = @()
}

# Process each symlink mapping
foreach ($mapping in $symlinkMappings) {
    Write-Log "=== Processing: $($mapping.Description) ===" -Level INFO -LogFile $LogPath
    Write-Log "Source: $($mapping.Source)" -Level INFO -LogFile $LogPath
    Write-Log "Target: $($mapping.Target)" -Level INFO -LogFile $LogPath

    # Ensure target parent directory exists (Edge Case from spec)
    $targetDir = Split-Path -Parent $mapping.Target
    if (-not (Test-Path $targetDir)) {
        Write-Log "Creating target directory: $targetDir" -Level INFO -LogFile $LogPath

        if ($WhatIfPreference -ne 'Continue') {
            try {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                Write-Log "Target directory created successfully." -Level INFO -LogFile $LogPath
            }
            catch {
                Write-Log "ERROR: Failed to create target directory: $($_.Exception.Message)" -Level ERROR -LogFile $LogPath
                $results.Failed += $mapping.Description
                continue
            }
        }
    }

    # Check if symlink already exists and points to correct source (idempotency - FR-009)
    if (Test-Path $mapping.Target) {
        $existingItem = Get-Item $mapping.Target -Force -ErrorAction SilentlyContinue

        # Check if it's already a symlink pointing to our source
        if ($existingItem.LinkType -eq 'SymbolicLink') {
            $existingTarget = $existingItem.Target

            if ($existingTarget -eq $mapping.Source) {
                Write-Log "Symlink already exists and points to correct source. Skipping." -Level WARN -LogFile $LogPath
                $results.Skipped += $mapping.Description
                continue
            }
            else {
                Write-Log "Symlink exists but points to: $existingTarget" -Level WARN -LogFile $LogPath
            }
        }
        else {
            Write-Log "Target exists as a regular file (not a symlink)." -Level WARN -LogFile $LogPath
        }

        # Target exists but is not the correct symlink
        # Prompt for confirmation unless -Force specified (FR-006)
        if (-not $Force -and $WhatIfPreference -ne 'Continue') {
            $confirmation = Read-Host "Target file exists. Overwrite? (y/N)"
            if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                Write-Log "User declined to overwrite. Skipping." -Level WARN -LogFile $LogPath
                $results.Skipped += $mapping.Description
                continue
            }
        }

        # Backup existing file (data-model.md §3)
        $backupTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "$($mapping.Target).backup.$backupTimestamp"

        Write-Log "Backing up existing file to: $backupPath" -Level INFO -LogFile $LogPath

        if ($WhatIfPreference -ne 'Continue') {
            try {
                # Backup original file BEFORE removing it
                if ($existingItem.LinkType -ne 'SymbolicLink') {
                    Copy-Item -Path $existingItem.FullName -Destination $backupPath -Force -ErrorAction Stop
                    Write-Log "Backup created successfully." -Level INFO -LogFile $LogPath
                }
                else {
                    Write-Log "Existing item was a symlink, no backup needed." -Level INFO -LogFile $LogPath
                }

                # Now remove existing item (file or symlink)
                Remove-Item -Path $mapping.Target -Force -ErrorAction Stop
            }
            catch {
                Write-Log "ERROR: Failed to backup existing file: $($_.Exception.Message)" -Level ERROR -LogFile $LogPath
                $results.Failed += $mapping.Description
                continue
            }
        }
    }

    # Create the symlink
    if ($WhatIfPreference -eq 'Continue') {
        Write-Log "WhatIf: Would create symlink from '$($mapping.Target)' to '$($mapping.Source)'" -Level INFO -LogFile $LogPath
        continue
    }

    try {
        Write-Log "Creating symlink..." -Level INFO -LogFile $LogPath

        New-Item -ItemType SymbolicLink -Path $mapping.Target -Target $mapping.Source -Force | Out-Null

        # Validate symlink creation
        if (Test-Path $mapping.Target) {
            $newItem = Get-Item $mapping.Target -Force
            if ($newItem.LinkType -eq 'SymbolicLink' -and $newItem.Target -eq $mapping.Source) {
                Write-Log "Symlink created and validated successfully." -Level INFO -LogFile $LogPath
                $results.Created += $mapping.Description
            }
            else {
                throw "Symlink validation failed: Link type=$($newItem.LinkType), Target=$($newItem.Target)"
            }
        }
        else {
            throw "Symlink was not created (target path does not exist after creation)"
        }
    }
    catch {
        Write-Log "ERROR: Failed to create symlink: $($_.Exception.Message)" -Level ERROR -LogFile $LogPath
        $results.Failed += $mapping.Description
    }
}

# Summary
Write-Log "=== Symlink Creation Summary ===" -Level INFO -LogFile $LogPath
Write-Log "Successfully created: $($results.Created.Count)" -Level INFO -LogFile $LogPath
if ($results.Created.Count -gt 0) {
    $results.Created | ForEach-Object { Write-Log "  - $_" -Level INFO -LogFile $LogPath }
}

Write-Log "Skipped (already correct): $($results.Skipped.Count)" -Level INFO -LogFile $LogPath
if ($results.Skipped.Count -gt 0) {
    $results.Skipped | ForEach-Object { Write-Log "  - $_" -Level INFO -LogFile $LogPath }
}

Write-Log "Failed: $($results.Failed.Count)" -Level INFO -LogFile $LogPath
if ($results.Failed.Count -gt 0) {
    $results.Failed | ForEach-Object { Write-Log "  - $_" -Level ERROR -LogFile $LogPath }
}

if ($results.Failed.Count -gt 0) {
    Write-Log "=== Symlink Configuration Script Completed with Errors ===" -Level ERROR -LogFile $LogPath
    exit 1
}

Write-Log "=== Symlink Configuration Script Completed Successfully ===" -Level INFO -LogFile $LogPath
Write-Log "Next steps:" -Level INFO -LogFile $LogPath
Write-Log "  1. Update Git config: git config --global user.name 'Your Name'" -Level INFO -LogFile $LogPath
Write-Log "  2. Update Git config: git config --global user.email 'your.email@example.com'" -Level INFO -LogFile $LogPath
Write-Log "  3. Restart PowerShell to load new profile with Oh My Posh theme" -Level INFO -LogFile $LogPath

exit 0
