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
├── .claude/commands/    # SpecKit slash commands for Claude Code
├── .specify/            # Spec-driven development templates
├── scripts/             # PowerShell automation scripts (planned)
├── powershell/          # PowerShell profile config (planned)
├── git/                 # Git configuration (planned)
├── plugin.json          # Claude Code plugin definition
└── .gitignore           # Excludes secrets and working files
```

**Note**: Installation scripts and configuration files are currently in development (see `specs/001-windows-setup-automation/` for implementation plan)

## 🚀 Quick Start

### Install as Claude Code Plugin

**From GitHub**:
```
/plugin install github.com/YourUsername/dotfiles
```

**Local development**:
```
/plugin install file:///path/to/dotfiles
```

**Verify**:
```
/plugin list
/speckit.constitution
```

This makes all SpecKit commands (`/speckit.*`) available globally in Claude Code.

### Clone for Development

```powershell
git clone <your-repo-url> dotfiles
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

This dotfiles repo follows these principles:

1. **Public by default** - Share knowledge, keep secrets separate
2. **Spec-driven** - Use SpecKit for planned development
3. **Automation first** - Minimize manual setup steps
4. **Modular** - Each tool's config is independent
5. **Documented** - Every decision explained

## 📚 Resources

- [SpecKit Documentation](https://github.com/github/spec-kit)
- [Claude Code Docs](https://docs.claude.com/en/docs/claude-code)
- [Claude Code Plugin System](https://www.anthropic.com/news/claude-code-plugins)

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
