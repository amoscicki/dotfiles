<#
.SYNOPSIS
    Interactive package manager for browsing and managing Chocolatey packages.

.DESCRIPTION
    Allows searching the Chocolatey repository, browsing packages, and adding/
    removing them from packages.json configuration. Provides an interactive UI
    for package discovery and configuration management.

.EXAMPLE
    PS> .\manage-packages.ps1
    Opens the main menu for package management

.NOTES
    Requires Chocolatey to be installed for package searching
    Requires PwshSpectreConsole module for interactive UI
#>

# Set error action preference
$ErrorActionPreference = 'Stop'

# Set UTF-8 encoding for proper Spectre Console display
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# Resolve script directory
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$packagesJsonPath = Join-Path $scriptRoot "packages.json"

#region Spectre Console Setup

# Ensure PwshSpectreConsole module is installed and imported
try {
    Import-Module PwshSpectreConsole -ErrorAction Stop
}
catch {
    Write-Host 'Installing PwshSpectreConsole module...' -ForegroundColor Yellow
    Install-Module -Name PwshSpectreConsole -Scope CurrentUser -Force -SkipPublisherCheck
    Import-Module PwshSpectreConsole -Force
}

#endregion

#region Utility Functions

function Show-Menu {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [array]$Options
    )

    # Show selection prompt with Spectre
    $selected = Read-SpectreSelection -Title $Title -Choices $Options -PageSize 15

    # Find index of selected option
    for ($i = 0; $i -lt $Options.Count; $i++) {
        if ($Options[$i] -eq $selected) {
            return $i
        }
    }

    return -1
}

function Search-ChocoPackages {
    param([string]$SearchTerm)

    $searchMsg = 'Searching Chocolatey for ' + $SearchTerm + '...'
    Write-Host $searchMsg -ForegroundColor Yellow

    try {
        $results = choco search $SearchTerm --limit-output 2>&1 | Where-Object { $_ -match '\|' }
        $packages = @()

        foreach ($result in $results) {
            if ($result -match '^([^|]+)\|([^|]+)') {
                $packages += [PSCustomObject]@{
                    Name = $matches[1]
                    Version = $matches[2]
                }
            }
        }

        return $packages
    }
    catch {
        $errorMsg = 'Error searching packages: ' + $_
        Write-Host $errorMsg -ForegroundColor Red
        return @()
    }
}

function Load-Config {
    if (Test-Path $packagesJsonPath) {
        return Get-Content $packagesJsonPath -Raw | ConvertFrom-Json
    }
    else {
        # Create default config if it doesn't exist
        return [PSCustomObject]@{
            groups = @()
        }
    }
}

function Save-Config {
    param($Config)

    $json = $Config | ConvertTo-Json -Depth 10
    Set-Content -Path $packagesJsonPath -Value $json -Encoding UTF8
    Write-Host 'Configuration saved!' -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Show-SearchAndAdd {
    while ($true) {
        Clear-Host
        Write-Host '=== Search and Add Packages ===' -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'Enter search term (or back to return): ' -NoNewline -ForegroundColor Yellow
        $searchTerm = Read-Host

        if ($searchTerm -eq 'back' -or $searchTerm -eq '') {
            return
        }

        $packages = Search-ChocoPackages -SearchTerm $searchTerm

        if ($packages.Count -eq 0) {
            Write-Host 'No packages found' -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            continue
        }

        # Show search results
        $packageOptions = @()
        foreach ($pkg in $packages) {
            $pkgOption = $pkg.Name + ' (v' + $pkg.Version + ')'
            $packageOptions += $pkgOption
        }
        $packageOptions += '< Back to search'

        $menuTitle = 'Search Results for ' + $searchTerm + ' - Select package to add'
        $selected = Show-Menu -Title $menuTitle -Options $packageOptions

        if ($selected -eq -1 -or $selected -eq $packages.Count) {
            continue
        }

        $selectedPackage = $packages[$selected]

        # Prompt for package description
        Clear-Host
        $addMsg = 'Adding package: ' + $selectedPackage.Name
        Write-Host $addMsg -ForegroundColor Green
        Write-Host ''
        Write-Host 'Enter description: ' -NoNewline -ForegroundColor Yellow
        $description = Read-Host

        # Load config and show groups
        $config = Load-Config

        if ($config.groups.Count -eq 0) {
            Write-Host 'No groups found. Creating default group...' -ForegroundColor Yellow
            $config.groups = @([PSCustomObject]@{
                name = 'Custom Packages'
                description = 'Manually added packages'
                packages = @()
            })
        }

        $groupNames = @()
        foreach ($group in $config.groups) {
            $groupNames += $group.name
        }
        $groupNames += '< Create new group'

        $groupIndex = Show-Menu -Title 'Select group to add package to' -Options $groupNames

        if ($groupIndex -eq -1) {
            continue
        }

        if ($groupIndex -eq $config.groups.Count) {
            # Create new group
            Clear-Host
            Write-Host 'Create New Group' -ForegroundColor Cyan
            Write-Host ''
            Write-Host 'Group name: ' -NoNewline -ForegroundColor Yellow
            $newGroupName = Read-Host
            Write-Host 'Group description: ' -NoNewline -ForegroundColor Yellow
            $newGroupDesc = Read-Host

            $newGroup = [PSCustomObject]@{
                name = $newGroupName
                description = $newGroupDesc
                packages = @()
            }
            $config.groups += $newGroup
            $groupIndex = $config.groups.Count - 1
        }

        # Add package to group
        $newPackage = [PSCustomObject]@{
            name = $selectedPackage.Name
            description = $description
        }

        $config.groups[$groupIndex].packages += $newPackage
        Save-Config -Config $config

        $successMsg = 'Package added to ' + $config.groups[$groupIndex].name + '!'
        Write-Host $successMsg -ForegroundColor Green
        Start-Sleep -Seconds 2
    }
}

function Show-BrowseAndRemove {
    $config = Load-Config

    if ($config.groups.Count -eq 0) {
        Clear-Host
        Write-Host 'No groups found in configuration' -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }

    while ($true) {
        # Show groups
        $groupNames = @()
        foreach ($group in $config.groups) {
            $count = $group.packages.Count
            $displayText = $group.name + ' (' + $count + ' packages)'
            $groupNames += $displayText
        }
        $groupNames += '< Back'

        $groupIndex = Show-Menu -Title 'Browse Packages - Select Group' -Options $groupNames

        if ($groupIndex -eq -1 -or $groupIndex -eq $config.groups.Count) {
            return
        }

        $selectedGroup = $config.groups[$groupIndex]

        # Show packages in group
        while ($true) {
            $packageNames = @()
            foreach ($pkg in $selectedGroup.packages) {
                $pkgDisplay = $pkg.name + ' - ' + $pkg.description
                $packageNames += $pkgDisplay
            }
            $packageNames += '< Delete this group'
            $packageNames += '< Back to groups'

            if ($selectedGroup.packages.Count -eq 0) {
                $packageNames = @('< No packages in this group', '< Delete this group', '< Back to groups')
            }

            $menuTitle = $selectedGroup.name + ' - Select package to remove'
            $pkgIndex = Show-Menu -Title $menuTitle -Options $packageNames

            if ($pkgIndex -eq -1 -or $pkgIndex -eq $packageNames.Count - 1) {
                break
            }

            if ($pkgIndex -eq $packageNames.Count - 2) {
                # Delete group
                Clear-Host
                $deleteMsg = 'Delete group ' + $selectedGroup.name + '? (y/N): '
                Write-Host $deleteMsg -NoNewline -ForegroundColor Yellow
                $confirm = Read-Host

                if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                    $config.groups = @($config.groups | Where-Object { $_.name -ne $selectedGroup.name })
                    Save-Config -Config $config
                    Write-Host 'Group deleted!' -ForegroundColor Green
                    Start-Sleep -Seconds 1
                    break
                }
                continue
            }

            if ($selectedGroup.packages.Count -eq 0) {
                continue
            }

            # Remove package
            $packageToRemove = $selectedGroup.packages[$pkgIndex]
            Clear-Host
            $removeMsg = 'Remove ' + $packageToRemove.name + ' from ' + $selectedGroup.name + '? (y/N): '
            Write-Host $removeMsg -NoNewline -ForegroundColor Yellow
            $confirm = Read-Host

            if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                $selectedGroup.packages = @($selectedGroup.packages | Where-Object { $_.name -ne $packageToRemove.name })

                # Update the group in config
                for ($i = 0; $i -lt $config.groups.Count; $i++) {
                    if ($config.groups[$i].name -eq $selectedGroup.name) {
                        $config.groups[$i] = $selectedGroup
                        break
                    }
                }

                Save-Config -Config $config
                Write-Host 'Package removed!' -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
        }
    }
}

#endregion

# Main menu
while ($true) {
    $options = @(
        '1. Search and Add Packages'
        '2. Browse and Remove Packages'
        '3. View Current Configuration'
        '4. Exit'
    )

    $choice = Show-Menu -Title 'Package Manager' -Options $options

    switch ($choice) {
        0 { Show-SearchAndAdd }
        1 { Show-BrowseAndRemove }
        2 {
            Clear-Host
            $config = Load-Config
            Write-Host '=== Current Configuration ===' -ForegroundColor Cyan
            Write-Host ''
            foreach ($group in $config.groups) {
                $groupDisplay = $group.name + ' - ' + $group.description
                Write-Host $groupDisplay -ForegroundColor Green
                foreach ($pkg in $group.packages) {
                    $pkgDisplay = '  - ' + $pkg.name + ': ' + $pkg.description
                    Write-Host $pkgDisplay -ForegroundColor White
                }
                Write-Host ''
            }
            Write-Host 'Press any key to continue...' -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        3 { exit 0 }
        -1 { exit 0 }
    }
}
