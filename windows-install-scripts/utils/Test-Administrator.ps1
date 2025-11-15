<#
.SYNOPSIS
    Tests if the current PowerShell session is running with Administrator privileges.

.DESCRIPTION
    Returns $true if the current user is a member of the Administrators group and
    the process is running elevated, $false otherwise.

.OUTPUTS
    System.Boolean
    Returns $true if running as Administrator, $false otherwise

.EXAMPLE
    PS> Test-Administrator
    True

.EXAMPLE
    PS> if (-not (Test-Administrator)) {
    >>     Write-Error "This script requires Administrator privileges"
    >>     exit 2
    >> }

.NOTES
    Used by all installation scripts to verify prerequisite Administrator access.
    Exit code convention: Scripts should exit with code 2 when prerequisites not met.
#>
[CmdletBinding()]
param()

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

return $isAdmin
