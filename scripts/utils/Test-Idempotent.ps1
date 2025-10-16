<#
.SYNOPSIS
    Tests if an operation has already been completed (idempotency check).

.DESCRIPTION
    Executes a provided ScriptBlock that checks whether an operation needs to
    be performed. Returns $true if the operation is already complete (skip it),
    $false if the operation needs to be executed.

.PARAMETER Check
    A ScriptBlock that performs the idempotency check. Should return $true if
    the operation is complete, $false if it needs to run.

.OUTPUTS
    System.Boolean
    Returns $true if operation is complete (idempotent), $false otherwise

.EXAMPLE
    PS> $isInstalled = Test-Idempotent -Check {
    >>     Get-Command choco -ErrorAction SilentlyContinue
    >> }
    PS> if (-not $isInstalled) {
    >>     # Install Chocolatey
    >> }

.EXAMPLE
    PS> if (Test-Idempotent -Check { Test-Path "C:\Program Files\Git\bin\git.exe" }) {
    >>     Write-Host "Git already installed, skipping"
    >> } else {
    >>     choco install git -y
    >> }

.NOTES
    This utility standardizes idempotency checks across all installation scripts.
    The Check scriptblock should be side-effect free (read-only operations).
    Used to implement FR-009 (idempotent script execution).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ScriptBlock]$Check
)

try {
    # Execute the check scriptblock and convert result to boolean
    $result = & $Check

    # Handle various return types
    if ($null -eq $result) {
        return $false
    }
    elseif ($result -is [bool]) {
        return $result
    }
    else {
        # Non-null, non-boolean result means operation exists/is complete
        return $true
    }
}
catch {
    # If check fails, assume operation is not complete
    Write-Verbose "Idempotency check failed: $_"
    return $false
}
