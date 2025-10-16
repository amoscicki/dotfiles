# PowerShell Profile - Windows 11 Development Environment
# Location: $PROFILE.CurrentUserAllHosts (symlinked from dotfiles/powershell/)
# See: README.md for installation instructions

# ============================================================================
# Oh My Posh - Powerline Prompt Customization (FR-016)
# ============================================================================
# Initialize Oh My Posh with powerlevel10k_rainbow theme
# Requires: oh-my-posh installed via Chocolatey (install-tools.ps1)

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $poshTheme = "$env:POSH_THEMES_PATH\powerlevel10k_rainbow.omp.json"

    if (Test-Path $poshTheme) {
        oh-my-posh init pwsh --config $poshTheme | Invoke-Expression
    } else {
        Write-Warning "Oh My Posh theme not found: $poshTheme"
        Write-Host "Available themes: $env:POSH_THEMES_PATH" -ForegroundColor Yellow
    }
} else {
    Write-Warning "Oh My Posh not installed. Run: choco install oh-my-posh -y"
}

# ============================================================================
# Chocolatey Profile Module (FR-017)
# ============================================================================
# Import Chocolatey helper functions (refreshenv, choco tab completion, etc.)
# Requires: Chocolatey installed (install-choco.ps1)

$chocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

if (Test-Path $chocolateyProfile) {
    Import-Module $chocolateyProfile
} else {
    Write-Warning "Chocolatey profile module not found: $chocolateyProfile"
    Write-Host "Install Chocolatey: https://chocolatey.org/install" -ForegroundColor Yellow
}

# ============================================================================
# Custom Aliases
# ============================================================================
# Short aliases for frequently used commands

# Git shortcuts
Set-Alias -Name g -Value git -ErrorAction SilentlyContinue

# Kubernetes shortcut (if kubectl installed)
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    Set-Alias -Name k -Value kubectl
}

# ============================================================================
# Custom Functions
# ============================================================================

# Function: which - Find the path of a command (Unix-like behavior)
# Usage: which git
function which {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Command
    )

    $cmd = Get-Command -Name $Command -ErrorAction SilentlyContinue

    if ($cmd) {
        $cmd | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
    } else {
        Write-Warning "Command '$Command' not found in PATH"
    }
}

# ============================================================================
# Welcome Message
# ============================================================================

Write-Host "PowerShell $($PSVersionTable.PSVersion) - Windows 11 Development Environment" -ForegroundColor Cyan
Write-Host "Dotfiles: https://github.com/amoscicki/dotfiles" -ForegroundColor DarkGray
