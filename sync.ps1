# Sync config files from C:\.config to this repo
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configDir = Join-Path $scriptRoot "config"
$sourceDir = "C:\.config"

$files = @("pwsh_profile.ps1", "powershell_profile.ps1")

foreach ($f in $files) {
    $src = Join-Path $sourceDir $f
    $dst = Join-Path $configDir $f
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "Synced: $f" -ForegroundColor Green
    } else {
        Write-Host "Not found: $src" -ForegroundColor Yellow
    }
}

Write-Host "`nGit status:" -ForegroundColor Cyan
git -C $scriptRoot status --short config/
