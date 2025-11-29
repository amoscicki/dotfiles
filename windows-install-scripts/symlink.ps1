<#
.SYNOPSIS
    Sets up dotfiles configuration with idempotent symlink management.

.DESCRIPTION
    Idempotent configuration script that:
    1. Copies profiles from dotfiles to C:\.config (only on fresh install)
    2. Creates reverse symlinks: dotfiles -> C:\.config (for git tracking)
    3. Creates symlinks for Git and Wezterm configs

    Architecture:
    - C:\.config = source of truth (real files)
    - P:\dotfiles\config\ = symlinks TO C:\.config (for git)
    - $PSHOME\profile.ps1 = dot-sources C:\.config (no Documents dependency)

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

.NOTES
    Requires: Administrator privileges
    Flow: Clone -> Install (copy to C:\.config) -> Symlinks (repo -> C:\.config)
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

function New-SymlinkSafe {
    param(
        [string]$Path,
        [string]$Target,
        [string]$Description,
        [bool]$Force,
        [string]$LogFile
    )

    # Check if symlink already exists and points to correct target
    if (Test-Path $Path) {
        $existingItem = Get-Item $Path -Force -ErrorAction SilentlyContinue

        if ($existingItem.LinkType -eq 'SymbolicLink') {
            if ($existingItem.Target -eq $Target) {
                Write-Log "Symlink already correct: $Path -> $Target" -Level DEBUG -LogFile $LogFile
                return @{ Status = 'Skipped'; Reason = 'Already correct' }
            }
            Write-Log "Symlink exists but points to: $($existingItem.Target)" -Level WARN -LogFile $LogFile
        } else {
            Write-Log "Regular file exists at: $Path" -Level WARN -LogFile $LogFile
        }

        # Prompt for confirmation unless -Force
        if (-not $Force) {
            $confirmation = Read-Host "Overwrite $Path? (y/N)"
            if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                return @{ Status = 'Skipped'; Reason = 'User declined' }
            }
        }

        # Backup if regular file
        if ($existingItem.LinkType -ne 'SymbolicLink') {
            $backupPath = "$Path.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item -Path $Path -Destination $backupPath -Force
            Write-Log "Backed up to: $backupPath" -Level INFO -LogFile $LogFile
        }

        Remove-Item -Path $Path -Force
    }

    # Ensure parent directory exists
    $parentDir = Split-Path -Parent $Path
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    # Create symlink
    New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null

    # Validate
    $newItem = Get-Item $Path -Force
    if ($newItem.LinkType -eq 'SymbolicLink' -and $newItem.Target -eq $Target) {
        return @{ Status = 'Created' }
    }

    return @{ Status = 'Failed'; Reason = 'Validation failed' }
}

#endregion

# Setup logging
if (-not $LogPath) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogPath = Join-Path $scriptRoot "..\logs\symlink-$timestamp.log"
}

$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Log "=== Symlink Configuration Script Started ===" -Level INFO -LogFile $LogPath
Write-Log "Dotfiles root: $dotfilesRoot" -Level INFO -LogFile $LogPath

# Check Administrator privileges
if (-not (Test-Administrator)) {
    Write-Log "ERROR: Administrator privileges required. Run as Administrator." -Level ERROR -LogFile $LogPath
    exit 2
}

Write-Log "Administrator check: PASS" -Level INFO -LogFile $LogPath

# ============================================================================
# STEP 1: Setup C:\.config (source of truth)
# ============================================================================
Write-Log "=== Step 1: Setting up C:\\.config ===" -Level INFO -LogFile $LogPath

$configDir = "C:\.config"
$dotfilesConfigDir = Join-Path $dotfilesRoot "config"

# Check if C:\.config already has profiles (existing installation)
$ps7ConfigExists = Test-Path (Join-Path $configDir "pwsh_profile.ps1")

if ($ps7ConfigExists) {
    Write-Log "C:\\.config already has profiles - skipping copy (re-clone scenario)" -Level INFO -LogFile $LogPath
} else {
    # Fresh install - copy from dotfiles
    Write-Log "Fresh install detected - copying profiles to C:\\.config" -Level INFO -LogFile $LogPath

    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        Write-Log "Created: $configDir" -Level INFO -LogFile $LogPath
    }

    # Copy profiles from dotfiles/config to C:\.config
    $profilesToCopy = @(
        @{ Source = "pwsh_profile.ps1"; Target = "pwsh_profile.ps1" }
        @{ Source = "powershell_profile.ps1"; Target = "powershell_profile.ps1" }
    )

    foreach ($profile in $profilesToCopy) {
        $sourcePath = Join-Path $dotfilesConfigDir $profile.Source
        $targetPath = Join-Path $configDir $profile.Target

        if (Test-Path $sourcePath) {
            # Check if source is a symlink (re-clone after install)
            $sourceItem = Get-Item $sourcePath -Force
            if ($sourceItem.LinkType -eq 'SymbolicLink') {
                Write-Log "Source is already a symlink, skipping: $sourcePath" -Level DEBUG -LogFile $LogPath
                continue
            }

            Copy-Item -Path $sourcePath -Destination $targetPath -Force
            Write-Log "Copied: $($profile.Source) -> $targetPath" -Level INFO -LogFile $LogPath
        } else {
            Write-Log "Source not found: $sourcePath" -Level WARN -LogFile $LogPath
        }
    }
}

# ============================================================================
# STEP 2: Create reverse symlinks in dotfiles (for git tracking)
# ============================================================================
Write-Log "=== Step 2: Creating reverse symlinks in dotfiles ===" -Level INFO -LogFile $LogPath

$reverseSymlinks = @(
    @{
        Path = Join-Path $dotfilesConfigDir "pwsh_profile.ps1"
        Target = Join-Path $configDir "pwsh_profile.ps1"
        Description = "PS7 profile (dotfiles -> C:\.config)"
    }
    @{
        Path = Join-Path $dotfilesConfigDir "powershell_profile.ps1"
        Target = Join-Path $configDir "powershell_profile.ps1"
        Description = "PS5.1 profile (dotfiles -> C:\.config)"
    }
)

$results = @{ Created = @(); Skipped = @(); Failed = @() }

foreach ($link in $reverseSymlinks) {
    Write-Log "Processing: $($link.Description)" -Level INFO -LogFile $LogPath

    # Check if target exists in C:\.config
    if (-not (Test-Path $link.Target)) {
        Write-Log "Target not found: $($link.Target)" -Level ERROR -LogFile $LogPath
        $results.Failed += $link.Description
        continue
    }

    # Check if source is a regular file (not symlink) - need to delete it first
    if (Test-Path $link.Path) {
        $item = Get-Item $link.Path -Force
        if ($item.LinkType -ne 'SymbolicLink') {
            Write-Log "Removing regular file to create symlink: $($link.Path)" -Level INFO -LogFile $LogPath
            Remove-Item -Path $link.Path -Force
        }
    }

    $result = New-SymlinkSafe -Path $link.Path -Target $link.Target -Description $link.Description -Force $Force -LogFile $LogPath

    switch ($result.Status) {
        'Created' { $results.Created += $link.Description }
        'Skipped' { $results.Skipped += $link.Description }
        'Failed'  { $results.Failed += $link.Description }
    }
}

# ============================================================================
# STEP 3: Create symlinks for other configs (Git, Wezterm)
# ============================================================================
Write-Log "=== Step 3: Creating symlinks for Git and Wezterm ===" -Level INFO -LogFile $LogPath

$otherSymlinks = @(
    @{
        Path = Join-Path $HOME ".gitconfig"
        Target = Join-Path $dotfilesRoot "git\.gitconfig"
        Description = "Git global configuration"
    }
    @{
        Path = Join-Path $HOME ".wezterm.lua"
        Target = Join-Path $dotfilesRoot "wezterm\wezterm.lua"
        Description = "Wezterm terminal configuration"
    }
)

foreach ($link in $otherSymlinks) {
    Write-Log "Processing: $($link.Description)" -Level INFO -LogFile $LogPath

    if (-not (Test-Path $link.Target)) {
        Write-Log "Source not found: $($link.Target)" -Level WARN -LogFile $LogPath
        $results.Skipped += $link.Description
        continue
    }

    $result = New-SymlinkSafe -Path $link.Path -Target $link.Target -Description $link.Description -Force $Force -LogFile $LogPath

    switch ($result.Status) {
        'Created' { $results.Created += $link.Description }
        'Skipped' { $results.Skipped += $link.Description }
        'Failed'  { $results.Failed += $link.Description }
    }
}

# ============================================================================
# Summary
# ============================================================================
Write-Log "=== Summary ===" -Level INFO -LogFile $LogPath
Write-Log "Created: $($results.Created.Count)" -Level INFO -LogFile $LogPath
$results.Created | ForEach-Object { Write-Log "  - $_" -Level INFO -LogFile $LogPath }

Write-Log "Skipped: $($results.Skipped.Count)" -Level INFO -LogFile $LogPath
$results.Skipped | ForEach-Object { Write-Log "  - $_" -Level WARN -LogFile $LogPath }

Write-Log "Failed: $($results.Failed.Count)" -Level INFO -LogFile $LogPath
$results.Failed | ForEach-Object { Write-Log "  - $_" -Level ERROR -LogFile $LogPath }

if ($results.Failed.Count -gt 0) {
    Write-Log "=== Completed with Errors ===" -Level ERROR -LogFile $LogPath
    exit 1
}

Write-Log "=== Completed Successfully ===" -Level INFO -LogFile $LogPath
Write-Log "" -Level INFO -LogFile $LogPath
Write-Log "Architecture now:" -Level INFO -LogFile $LogPath
Write-Log "  C:\\.config\\*.ps1        = Source of truth (edit here)" -Level INFO -LogFile $LogPath
Write-Log "  P:\\dotfiles\\config\\*    = Symlinks to C:\\.config (for git)" -Level INFO -LogFile $LogPath
Write-Log "  \$PSHOME\\profile.ps1     = Dot-sources C:\\.config" -Level INFO -LogFile $LogPath
Write-Log "" -Level INFO -LogFile $LogPath
Write-Log "To update profiles: Edit C:\\.config\\pwsh_profile.ps1" -Level INFO -LogFile $LogPath
Write-Log "Changes appear in git automatically via symlinks." -Level INFO -LogFile $LogPath

exit 0
