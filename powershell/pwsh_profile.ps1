# PowerShell 7 Profile - Full Development Environment
# Location: C:\.config\pwsh_profile.ps1 (symlinked from dotfiles)
# See: README.md for installation instructions


# Ensure PSReadLine is loaded
Import-Module PSReadLine
Remove-PSReadLineKeyHandler -Key Ctrl+r -ErrorAction SilentlyContinue

Set-PSReadLineKeyHandler -Key Ctrl+r -BriefDescription 'FuzzyHistorySearch' -ScriptBlock {
    $historyFile = (Get-PSReadLineOption).HistorySavePath
    if (-not (Test-Path $historyFile)) { return }

    $history = Get-Content $historyFile | Sort-Object -Unique
    if (-not $history) { return }

    $selected = $history |
        rg --no-heading --color never '' |
        fzf --height 40% --reverse --border `
            --prompt 'History> ' `
            --preview 'echo {} | bat --language powershell --style=numbers --color always --paging=never' `
            --preview-window=up:wrap

    if ($selected) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected)
    }
}

# Ctrl+T: Fuzzy file picker
    Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock {
        $file = fd --type f | fzf --height 40% --reverse --border `
            --prompt 'Files> ' `
            --preview 'bat --style=numbers --color always --paging=never {}' `
            --preview-window=up:wrap
        if ($file) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($file)
        }
    }

    # Alt+C: Fuzzy directory switch
    Set-PSReadLineKeyHandler -Chord Alt+c -ScriptBlock {
        $dir = fd --type d | fzf --height 40% --reverse --border `
            --prompt 'Directories> ' `
            --preview 'ls {}'
        
        function list {
            Get-ChildItem | ForEach-Object { $n=$_.Name; $c=if ($_.PSIsContainer){'Cyan'}else{'White'}; Write-Host -NoNewline $n -ForegroundColor $c; Write-Host -NoNewline "`t" } ; Write-Host ""
        }    

        if ($dir) {
            cd $dir # Change directory
            # Show directory contents using the helper 'list' function (Write-Host prints to console)
            list
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        }
    }


# ============================================================================
# Oh My Posh - Powerline Prompt Customization (FR-016)
# ============================================================================
# Initialize Oh My Posh with powerlevel10k_rainbow theme
# Requires: oh-my-posh installed via Chocolatey (install-tools.ps1)

# Profile loads successfully
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

# Python 3.12 aliases
Set-Alias -Name python312 -Value "C:\Users\ArkadiuszMoscicki\AppData\Local\Programs\Python\Python312\python.exe" -ErrorAction SilentlyContinue
Set-Alias -Name pip312 -Value "C:\Users\ArkadiuszMoscicki\AppData\Local\Programs\Python\Python312\Scripts\pip.exe" -ErrorAction SilentlyContinue

# Git shortcuts
# Hashtable for our aliases
if (-not $Global:GitAliases) { $Global:GitAliases = @{} }

# Register a Git alias function and remember it in $Global:GitAliases
function Register-GitAlias {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [string]$Description = ''
    )

    # If an alias with the same name exists, remove it so our function takes precedence
    try {
        $existingAlias = Get-Command -Name $Name -CommandType Alias -ErrorAction SilentlyContinue
        if ($existingAlias) {
            Remove-Item -Path "Alias:\$Name" -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # ignore
    }

    # Create/update the function in the Global scope
    try {
        New-Item -Path "Function:\Global:$Name" -Value $Action -Force | Out-Null
    } catch {
        Write-Warning "Failed to create function ${Name}: $_"
        return
    }

    # Store metadata so gal can list only our aliases
    $Global:GitAliases[$Name] = @{
        Script      = $Action
        ScriptText  = $Action.ToString()
        Description = $Description
    }
}

# Register aliases (use arrays for message/args to preserve multi-word values)
Register-GitAlias gcm  { 
    param([Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)][string[]]$Message)
    git commit -m ($Message -join ' ')
} "commit with message"
Register-GitAlias gamd { git commit --amend --no-edit } "amend without edit"
Register-GitAlias gaa  { git add . } "add all changes"
Register-GitAlias gpsh { 
    param([Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)][string[]]$Args)
    if ($Args) { & git push @Args } else { git push }
} "push to remote (forwards args)"
Register-GitAlias gst  { git stash } "stash changes"
Register-GitAlias gsp  { git stash pop } "apply stash"
Register-GitAlias gpl  { 
    param([Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)][string[]]$Args)
    if ($Args) { & git pull @Args } else { git pull }
} "pull (forwards args)"
Register-GitAlias gft  { git fetch } "fetch from remotes"

# Ensure we don't accidentally call the built-in 'gal' alias (Get-Alias)
# Remove the alias if it exists so the function below has precedence
try {
    $aliasGal = Get-Command -Name gal -CommandType Alias -ErrorAction SilentlyContinue
    if ($aliasGal) {
        Remove-Item -Path Alias:\gal -Force -ErrorAction SilentlyContinue
    }
} catch {
    # ignore
}

# Show only our registered git aliases
function global:gal {
    param(
        [Switch]$fzf,        # Open fzf to choose one entry
        [Switch]$insert,     # If used with -fzf, insert the chosen alias into the current command line
        [Switch]$namesOnly   # Output only alias names (useful for piping to fzf)
    )

    if (($null -eq $Global:GitAliases) -or ($Global:GitAliases.Count -eq 0)) {
        Write-Host "(no git aliases registered)" -ForegroundColor DarkYellow
        return
    }

    $items = $Global:GitAliases.GetEnumerator() |
        Sort-Object -Property Name |
        ForEach-Object {
            $meta = $_.Value
            $desc = if ($meta.Description) { " - $($meta.Description)" } else { "" }
            [PSCustomObject]@{
                Name        = $_.Key
                ScriptText  = $meta.ScriptText
                Description = $meta.Description
                Line        = "$($_.Key) -> $($meta.ScriptText)$desc"
            }
        }

    if ($namesOnly) {
        $items | Select-Object -ExpandProperty Name
        return
    }

    if ($fzf) {
        # Show description in the list, no preview
        $selected = $items |
            Select-Object -ExpandProperty Line |
            fzf --height 40% --reverse --border `
                --prompt 'gal> ' |
            ForEach-Object { $_.Trim() }

        if (-not $selected) { return }

        # Extract alias name from selected line: "name -> script..."
        $aliasName = ($selected -split '\s+->\s+', 2)[0].Trim()

        if ([string]::IsNullOrWhiteSpace($aliasName)) { return }

        if ($insert -and (Get-Module -ListAvailable PSReadLine)) {
            try {
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($aliasName + ' ')
            } catch {
                Write-Warning "PSReadLine not available or insertion failed. Outputting alias instead."
                Write-Output $aliasName
            }
        } else {
            Write-Output $aliasName
        }
        return
    }

    # Default: print human-friendly list with descriptions
    foreach ($it in $items) {
        $desc = if ($it.Description) { " - $($it.Description)" } else { "" }
        Write-Host "$($it.Name) -> $($it.ScriptText)$desc"
    }
}

# Helper function to open gal in fzf and insert the selection in the prompt:
Set-PSReadLineKeyHandler -Chord Alt+g -ScriptBlock {
    # Clear the current line first
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    
    $items = $Global:GitAliases.GetEnumerator() |
        Sort-Object -Property Name |
        ForEach-Object {
            $meta = $_.Value
            $desc = if ($meta.Description) { " - $($meta.Description)" } else { "" }
            "$($_.Key) -> $($meta.ScriptText)$desc"
        }
    
    if ($items) {
        $selected = $items | fzf --height 40% --reverse --border --prompt 'gal> '
        
        if ($selected) {
            $aliasName = ($selected -split '\s+->\s+', 2)[0].Trim()
            if ($aliasName) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($aliasName + ' ')
            }
        }
    }
}
# Alt+g now accepts the line after insertion
Set-PSReadLineKeyHandler -Chord Alt+g -ScriptBlock {
    # Clear the current line first
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    
    $items = $Global:GitAliases.GetEnumerator() |
        Sort-Object -Property Name |
        ForEach-Object {
            $meta = $_.Value
            $desc = if ($meta.Description) { " - $($meta.Description)" } else { "" }
            "$($_.Key) -> $($meta.ScriptText)$desc"
        }
    
    if ($items) {
        $selected = $items | fzf --height 40% --reverse --border --prompt 'gal> '
        
        if ($selected) {
            $aliasName = ($selected -split '\s+->\s+', 2)[0].Trim()
            if ($aliasName) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($aliasName + ' ')
                [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            }
        }
    }
}

# npm -> pnpm alias (redirect all npm commands to pnpm)
function NPM-PNPM-Alias {
    pnpm $args
}
Set-Alias -Name npm -Value NPM-PNPM-Alias -Option AllScope -ErrorAction SilentlyContinue

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

# ASCII Art Banner
Write-Host @"
                                                                                                                               
                                                                                                                               
                                                             90005                                                             
                                                           009  508                                                            
                                                       60005      001                                                          
                 I'm IN!                          300087           600000047                                                   
                                               2008                        6000003                                             
                                             000                                 500002                                        
                                          6003                                        50004       20007                        
                                        008                                               500000002 700                        
                                     3002                                                            00                        
                                   6007             309                                              00                        
          900000843              908                506   3                                         907                        
                 72900000843   609                        380005                                   505                         
                         2549000                                77                                700                          
                        5   100                                            900                    801                          
                       5 37 3003       7290000800000062                                            007                         
                      6  1117 10000000093      32552332600000062                                    905                        
                     2  1 71317 117 1    7 7  71        35553313600000095   805                      905                       
                    73      3 31  13777  733     31 7131         354537 39000                         903                      
                    5  7  37 17227 333   7 7 333  3373  13  3337         100                7403       00                      
                   51 2137 33 3  31  7  7 7  7 317 73133 3377  737   733  500      36000000000000092   505                     
                   5  3 377 727 2 71   7   13 7133  2 711  3173 7133         9000043      15657    3900000083                  
                  17         311 1    73337 3313  33  3323 73111  13 71331137        171         54         390000008          
                  5  7 13             17      3333 123   13  31227 2317  12  3323 13117  73  333   4                           
                  5  71171  37 3              7  73  3313  33 3  37 71313 733 1 73  33337 3337  7  4                           
                   2553      11          17           1 73  33 73 13 1  31  13737 33 1  37 73333  5                            
                          72553         3  37 71337          77777 73  3731  3717  12 73733 77 7 13                            
                                  735537     7 77 33  1  17          77 2  37 71337 331 7  3  3  4                             
                                           32521        1  73  3337            3  37  1311 133  5                              
                                                   12521          13  7  17            7 37  7 31                              
                                                           12521        3  31 73311            5                               
                                                                   3553         3 33  3  111  6                                
                                                                          35537          7 1 31                                
                                                                                 725537      1                                 
                                                                                  77      732                                  
"@ -ForegroundColor Cyan


Write-Host ""
Write-Host "PowerShell $($PSVersionTable.PSVersion) - Windows 11 Development Environment" -ForegroundColor Cyan
Write-Host "Dotfiles: https://github.com/amoscicki/dotfiles" -ForegroundColor DarkGray