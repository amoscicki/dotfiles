# Dotfiles - Windows 11 Development Environment

Automated Windows 11 development environment setup using PowerShell scripts and configuration management.

## 🎯 Purpose

Transform a factory-reset Windows 11 machine into a fully configured development workstation:
- Automated installation of development tools via Chocolatey
- Configuration management through symlinked dotfiles
- PowerShell profile with Oh My Posh and custom tooling
- Reproducible setup in under 30 minutes

## 📁 What's Inside

```
dotfiles/
├── .claude/commands/         # SpecKit slash commands for Claude Code
├── .specify/                 # Spec-driven development templates
├── windows-install-scripts/  # PowerShell Windows automation scripts
├── powershell/               # PowerShell profile config (planned)
├── git/                      # Git configuration (planned)
├── plugin.json               # Claude Code plugin definition
└── .gitignore                # Excludes secrets and working files
```

**Current Status**: Implementation complete! All scripts and configuration files are ready for use.

## 🚀 Quick Start

### Option 1: Full Windows 11 Environment Setup

**Prerequisites**:
- Windows 11 (Windows 10 supported with warnings)
- Administrator privileges
- Internet connectivity
- 20GB free disk space

**Installation Steps**:

1. **Clone the repository**:
   ```powershell
   git clone https://github.com/amoscicki/dotfiles.git
   cd dotfiles
   ```

2. **Run the master installation script**:
   ```powershell
   # Interactive installation (with confirmations)
   .\windows-install-scripts\install.ps1

   # Fully automated installation (no prompts)
   .\windows-install-scripts\install.ps1 -Unattended

   # Preview what would be installed (dry-run)
   .\windows-install-scripts\install.ps1 -WhatIf
   ```

3. **Complete manual post-installation steps**:
   ```powershell
   # Update Git user configuration (REQUIRED)
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"

   # Install Claude Code plugin (if Claude Code installed)
   # In Claude Code, run:
   /plugin install file://P:/dotfiles
   # Or from GitHub:
   /plugin install github.com/amoscicki/dotfiles

   # Restart PowerShell to load profile with Oh My Posh
   ```

4. **Verify installation**:
   ```powershell
   choco --version
   git --version
   node --version
   pnpm --version
   gh --version
   fzf --version
   oh-my-posh --version
   ```

**Time Estimate**: ~30 minutes (excluding download times)

### Option 2: Install as Claude Code Plugin Only

**From GitHub**:
```
/plugin install github.com/amoscicki/dotfiles
```

**Local development**:
```
/plugin install file://P:/dotfiles
```

**Verify**:
```
/plugin list
/speckit.constitution
```

This makes all SpecKit commands (`/speckit.*`) available globally in Claude Code.

### Option 3: Clone for Development

```powershell
git clone https://github.com/amoscicki/dotfiles.git dotfiles
cd dotfiles
```

Commands in `.claude/commands/` are available when working in this directory.

## 🛠️ Technology Stack

- **Platform**: Windows 11
- **Package Manager**: Chocolatey
- **Scripting**: PowerShell 7+
- **Prompt Theme**: Oh My Posh (powerlevel10k_rainbow)
- **Development**: SpecKit for spec-driven workflow

## 🎓 Philosophy

This dotfiles repository follows the principles defined in [.specify/memory/constitution.md](.specify/memory/constitution.md):

1. **Public by Default** - All configuration files, scripts, and documentation are safe for public repositories. Sensitive data excluded via `.gitignore` or stored externally using secure credential management.

2. **Automation First** - Manual setup steps minimized through PowerShell scripts, Chocolatey package managers, and symlink automation. Installation achievable through a single master script execution.

3. **Modular & Independent** - Each tool's configuration is self-contained in its own directory. Configurations have no hidden dependencies on other configurations. Each module is installable independently via its own script.

4. **Spec-Driven Development** - All significant features follow SpecKit workflow: specification → planning → tasks → implementation. Changes are documented in spec files before implementation.

5. **Documentation as Code** - Every script includes comments explaining its purpose and usage. Every configuration directory contains a README or inline comments describing the configuration's purpose. The main README is kept current with actual repository structure and capabilities.

## 🔧 Troubleshooting

### Common Issues

**Chocolatey Installation Fails**:
- Check internet connectivity and proxy settings
- Verify Windows Defender or antivirus isn't blocking the installer
- Manual install: Visit https://chocolatey.org/install
- Check logs in `logs/` directory for detailed error messages

**Package Installation Fails**:
- Review logs in `logs/install-tools-YYYYMMDD-HHmmss.log`
- Try manual installation: `choco install <package-name> --force -y`
- Some packages may require a system restart to complete installation

**Symlink Creation Fails**:
- Verify you're running PowerShell as Administrator
- Check that target directories exist (created automatically by script)
- Ensure source files exist in dotfiles repository directories

**Oh My Posh Theme Not Showing**:
- Install a Nerd Font: `choco install cascadia-code-nerd-font -y`
- Restart your terminal after font installation
- Verify Oh My Posh is in PATH: `oh-my-posh --version`
- Check theme path: `$env:POSH_THEMES_PATH`

**PowerShell Execution Policy Blocking Scripts**:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Installation Interrupted - How to Resume**:
- Simply re-run `.\windows-install-scripts\install.ps1`
- All scripts are idempotent (safe to run multiple times)
- Already-installed components will be skipped automatically

### Getting Help

- Check log files in `logs/` directory for detailed error information
- Review the specification: `specs/001-windows-setup-automation/spec.md`
- Open an issue on GitHub with log contents and error details

## 📚 Resources

- [SpecKit Documentation](https://github.com/github/spec-kit)
- [Claude Code Docs](https://docs.claude.com/en/docs/claude-code)
- [Claude Code Plugin System](https://www.anthropic.com/news/claude-code-plugins)
- [Chocolatey Package Gallery](https://community.chocolatey.org/packages)
- [Oh My Posh Themes](https://ohmyposh.dev/docs/themes)

## 🤝 Contributing

This is a personal dotfiles repo, but if you find it useful:
- Feel free to fork and adapt
- Issues and suggestions welcome
- Share your own dotfiles setup!

## 📄 License

MIT (or your preferred license)

---

**Last Updated:** 2025-10-15
**Location:** `P:\dotfiles`
**Owner:** Arkadiusz Moscicki
