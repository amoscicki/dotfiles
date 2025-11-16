# PowerShell 5.1 Profile - Minimal launcher
# Purpose: Launch PowerShell 7 (pwsh) automatically
# Location: C:\.config\powershell_profile.ps1 (symlinked from dotfiles)

# Check if we haven't already auto-launched to prevent infinite loops
if (-not $env:PWSH_AUTO_LAUNCHED) {
    # Check if PowerShell 7 is available and launch it
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $env:PWSH_AUTO_LAUNCHED = $true
        pwsh
        exit
    } else {
        Write-Warning "PowerShell 7 (pwsh) not found. Please install it first."
        Write-Host "Install with: winget install Microsoft.PowerShell" -ForegroundColor Yellow
    }
} else {
    # PS 5.1 - Auto-launch already completed
    Write-Host ""
}