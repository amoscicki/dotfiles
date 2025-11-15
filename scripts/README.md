# Windows Installation Scripts

PowerShell scripts for automated Windows 11 development environment setup using Chocolatey package manager.

## Overview

This collection of scripts automates the installation and configuration of a complete Windows development environment, including package managers, development tools, terminal emulators, and configuration file management via symbolic links.

## Scripts

### Core Installation Scripts

#### `install.ps1`
**Master orchestration script** that runs the complete setup process.

```powershell
.\install.ps1                    # Interactive installation
.\install.ps1 -Unattended        # Fully automated (no prompts)
.\install.ps1 -Force             # Skip symlink confirmations
.\install.ps1 -WhatIf            # Preview without making changes
```

**Features:**
- Runs all setup scripts in sequence
- Handles prerequisites and error recovery
- Idempotent execution (safe to re-run)
- Comprehensive logging to `logs/install-*.log`

**Execution order:**
1. Install Chocolatey
2. Install core tools (Git, Node.js, pnpm)
3. Install extended packages
4. Create configuration symlinks

---

#### `install-choco.ps1`
Installs Chocolatey package manager if not already present.

```powershell
.\install-choco.ps1              # Install Chocolatey
.\install-choco.ps1 -WhatIf      # Preview installation
```

**Requirements:**
- Administrator privileges
- Internet connectivity

---

#### `install-core-tools.ps1`
Installs essential development tools via Chocolatey.

```powershell
.\install-core-tools.ps1         # Install Git, Node.js, pnpm
```

**Installed tools:**
- Git (version control)
- Node.js (JavaScript runtime)
- pnpm (fast package manager)

**Features:**
- Idempotency checks
- PATH validation after installation
- Exit code 3010 handling (reboot required)

---

#### `install-tools.ps1`
Installs extended development packages from curated lists.

```powershell
# File-based mode (reads choco-packages.txt)
.\install-tools.ps1

# Interactive mode (select from packages.json)
.\install-tools.ps1 -Interactive

# Custom package list
.\install-tools.ps1 -PackageListPath "custom-list.txt"
```

**Two modes:**

1. **File-based mode** (default)
   - Reads packages from `choco-packages.txt`
   - Supports comments and inline annotations
   - One package per line

2. **Interactive mode** (`-Interactive`)
   - Multi-select UI with checkbox navigation
   - Group-based package organization
   - Select multiple groups and packages
   - Keyboard controls: ↑/↓ arrows, SPACE to toggle, ENTER to confirm, A/N for all/none

**Features:**
- Resilient mode (continues on individual package failures)
- Reboot tracking for packages requiring restart
- Duplicate detection
- Comprehensive logging

---

#### `symlink.ps1`
Creates symbolic links from dotfiles to system configuration locations.

```powershell
.\symlink.ps1                    # Create symlinks (with prompts)
.\symlink.ps1 -Force             # Skip confirmation prompts
.\symlink.ps1 -WhatIf            # Preview symlink creation
```

**Symlinks created:**
- `powershell/Microsoft.PowerShell_profile.ps1` → `$PROFILE`
- `git/.gitconfig` → `~/.gitconfig`
- `wezterm/wezterm.lua` → `~/.wezterm.lua`

**Features:**
- Automatic backup of existing files (`*.backup.YYYYMMDD-HHmmss`)
- Idempotency (skips if correct symlink exists)
- Parent directory creation
- Symlink validation

---

### Package Management

#### `manage-packages.ps1`
Interactive tool for browsing Chocolatey packages and managing `packages.json` configuration.

```powershell
.\manage-packages.ps1
```

**Features:**

1. **Search and Add Packages**
   - Search Chocolatey repository
   - Browse search results
   - Add packages to existing/new groups
   - Specify package descriptions

2. **Browse and Remove Packages**
   - Navigate package groups
   - Remove packages from groups
   - Delete entire groups
   - View package counts

3. **View Configuration**
   - Display current `packages.json` structure
   - Show all groups and packages

**Keyboard controls:**
- ↑/↓ arrows: Navigate
- ENTER: Select
- ESC: Go back

---

## Configuration Files

### `packages.json`
JSON configuration defining package groups for interactive installation.

**Structure:**
```json
{
  "groups": [
    {
      "name": "Development Tools",
      "description": "Essential development tools and utilities",
      "packages": [
        { "name": "python", "description": "Python programming language" },
        { "name": "golang", "description": "Go programming language" }
      ]
    }
  ]
}
```

**Default groups:**
- Development Tools (Python, Go, Rust, Docker, Postman, Insomnia)
- CLI Tools (fzf, ripgrep, bat, fd, jq, yq, gh)
- Terminal & Shell (oh-my-posh, starship, wezterm, Nerd Fonts)
- Editors & IDEs (VS Code, Neovim, Vim)
- Database Tools (DBeaver, PostgreSQL, Redis)
- Utilities (7zip, Everything, PowerToys, Sysinternals)

---

### `choco-packages.txt`
Simple text file listing packages for file-based installation mode.

**Format:**
```text
# Comments start with #
package-name          # Inline comments supported

# Groups can be organized with comment headers
# Development Tools
python
golang
```

---

## Common Parameters

All scripts support the following PowerShell common parameters:

- `-WhatIf`: Preview changes without executing
- `-Verbose`: Enable detailed diagnostic output
- `-LogPath <path>`: Custom log file location

**Examples:**
```powershell
.\install.ps1 -WhatIf -Verbose
.\install-tools.ps1 -Interactive -Verbose
.\symlink.ps1 -Force -WhatIf
```

---

## Requirements

- **Operating System:** Windows 11 (Windows 10 compatible)
- **PowerShell:** 5.1 or later
- **Privileges:** Administrator (required for Chocolatey and symlinks)
- **Internet:** Required for package downloads
- **Disk Space:** ~5GB for full installation

---

## Logging

All scripts generate timestamped log files in `logs/` directory:

```
logs/
├── install-YYYYMMDD-HHmmss.log
├── install-choco-YYYYMMDD-HHmmss.log
├── install-core-tools-YYYYMMDD-HHmmss.log
├── install-tools-YYYYMMDD-HHmmss.log
└── symlink-YYYYMMDD-HHmmss.log
```

Log levels: `INFO`, `WARN`, `ERROR`, `DEBUG`

---

## Error Handling

### Exit Codes

- `0`: Success
- `1`: General failure
- `2`: Prerequisites not met (missing admin privileges, Chocolatey not installed)
- `3`: Configuration error (missing files, invalid JSON)
- `3010`: Success with reboot required (Windows installer standard)

### Idempotency

All scripts are idempotent and safe to re-run:
- Skip already installed packages
- Skip existing correct symlinks
- Resume after interruptions
- No duplicate installations

### Resilient Mode

`install-tools.ps1` continues installing remaining packages even if some fail, with complete summary reporting.

---

## Quick Start

### Full Automated Setup
```powershell
# Run as Administrator
cd dotfiles/scripts
.\install.ps1 -Unattended
```

### Custom Interactive Setup
```powershell
# Run as Administrator
cd dotfiles/scripts

# 1. Install Chocolatey
.\install-choco.ps1

# 2. Install core tools
.\install-core-tools.ps1

# 3. Interactively select packages
.\install-tools.ps1 -Interactive

# 4. Create symlinks
.\symlink.ps1
```

### Post-Installation
```powershell
# Update Git configuration
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Restart PowerShell to load new profile
exit
```

---

## Troubleshooting

### "Execution of scripts is disabled"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Administrator privileges required"
Right-click PowerShell and select "Run as Administrator"

### Package installation fails
- Check internet connectivity
- Review logs in `logs/` directory
- Try installing package individually: `choco install <package-name> -y`
- Some packages may require reboot (exit code 3010)

### Symlink creation fails
- Ensure running as Administrator
- Check source files exist in dotfiles repository
- Backup files are created automatically before overwriting

---

## Development

### Adding New Packages

**To `packages.json`:**
```powershell
.\manage-packages.ps1  # Use interactive tool
```

**To `choco-packages.txt`:**
```text
# Add package name (one per line)
new-package-name
```

### Customization

Scripts use relative paths and are location-independent. Customize by:
- Editing package lists (`packages.json`, `choco-packages.txt`)
- Modifying symlink mappings in `symlink.ps1`
- Adjusting tool lists in `install-core-tools.ps1`

---

## License

Part of the personal dotfiles repository. See repository LICENSE for details.

## References

- [Chocolatey Documentation](https://docs.chocolatey.org/)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Project Specification](../specs/001-windows-setup-automation/spec.md)
