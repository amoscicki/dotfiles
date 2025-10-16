<#
.SYNOPSIS
    Writes a timestamped log message to both console and log file.

.DESCRIPTION
    Formats and writes log messages with ISO 8601 timestamps to both the console
    (with color-coded levels) and a specified log file. Creates the log file and
    parent directories if they don't exist.

.PARAMETER Message
    The log message content to write.

.PARAMETER Level
    The log level: INFO, WARN, ERROR, or DEBUG. Default is INFO.
    - INFO: Normal operations (Green)
    - WARN: Non-fatal issues (Yellow)
    - ERROR: Fatal errors (Red)
    - DEBUG: Detailed diagnostics (Cyan)

.PARAMETER LogFile
    Path to the log file. If not specified, logs only to console.

.OUTPUTS
    None. Writes to console and/or log file.

.EXAMPLE
    PS> Write-Log -Message "Starting installation" -Level INFO -LogFile "logs/install.log"
    [2025-10-16 14:32:10] [INFO] Starting installation

.EXAMPLE
    PS> Write-Log "Package already installed, skipping" -Level WARN -LogFile $logPath

.EXAMPLE
    PS> Write-Log "Installation failed: Access denied" -Level ERROR -LogFile $logPath

.NOTES
    Log file format: [YYYY-MM-DD HH:mm:ss] [LEVEL] Message
    UTF-8 encoding with append mode for international characters.
    Creates parent directories automatically if missing.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
    [string]$Level = 'INFO',

    [Parameter(Mandatory = $false)]
    [string]$LogFile
)

# Format timestamp in ISO 8601 format
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Build log entry
$logEntry = "[$timestamp] [$Level] $Message"

# Color mapping for console output
$colors = @{
    'INFO'  = 'Green'
    'WARN'  = 'Yellow'
    'ERROR' = 'Red'
    'DEBUG' = 'Cyan'
}

# Write to console with appropriate color
Write-Host $logEntry -ForegroundColor $colors[$Level]

# Write to log file if specified
if ($LogFile) {
    try {
        # Ensure parent directory exists
        $logDir = Split-Path -Path $LogFile -Parent
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        # Append to log file with UTF-8 encoding
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to write to log file '$LogFile': $_"
    }
}
