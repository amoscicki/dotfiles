<!--
Sync Impact Report
==================
Version Change: [NEW] → 1.0.0
Reason: Initial constitution creation for dotfiles project

Modified Principles: N/A (initial version)
Added Sections:
  - Core Principles (5 principles defined)
  - Security & Privacy Requirements
  - Quality Standards
  - Governance

Templates Status:
  ⚠ plan-template.md - Review pending
  ⚠ spec-template.md - Review pending
  ⚠ tasks-template.md - Review pending
  ⚠ checklist-template.md - Review pending
  ⚠ agent-file-template.md - Review pending

Follow-up TODOs:
  - Validate template alignment with new constitution principles
  - Ensure all SpecKit commands reference correct principle names
-->

# Dotfiles Constitution

## Core Principles

### I. Public by Default
All configuration files, scripts, and documentation MUST be safe for public repositories.
Sensitive data (API keys, passwords, SSH keys, personal tokens) MUST be excluded via
`.gitignore` or stored externally using secure credential management. The project serves
as a shareable reference for Windows 11 development environment setup.

**Rationale**: This enables community sharing, forces good security practices, and ensures
the dotfiles can be safely published to GitHub without risk of credential exposure.

### II. Automation First
Manual setup steps MUST be minimized through PowerShell scripts, Chocolatey package
managers, and symlink automation. Every configuration change SHOULD have a corresponding
script that can reproduce it on a fresh system. Installation MUST be achievable through
a single master script execution.

**Rationale**: Reduces recovery time from hours to minutes when setting up new machines
or recovering from hardware failure. Eliminates human error in manual configuration.

### III. Modular & Independent
Each tool's configuration MUST be self-contained in its own directory (e.g.,
`powershell/`, `git/`, `wezterm/`). Configurations MUST NOT have hidden dependencies on
other configurations. Each module SHOULD be installable independently via its own script.

**Rationale**: Allows selective adoption of configurations, easier testing of individual
components, and simplified troubleshooting when issues arise.

### IV. Spec-Driven Development
All significant features or configuration additions MUST follow SpecKit workflow:
specification → planning → tasks → implementation. Changes MUST be documented in spec
files before implementation. The `/speckit.*` commands MUST be used for feature planning.

**Rationale**: Ensures thoughtful design, maintains project consistency, provides clear
documentation of intent, and leverages Claude Code integration for AI-assisted development.

### V. Documentation as Code
Every script MUST include comments explaining its purpose and usage. Every configuration
directory MUST contain a README or inline comments describing the configuration's purpose.
The main README MUST be kept current with actual repository structure and capabilities.

**Rationale**: Future you (and others) will need to understand what each file does when
recovery or updates are needed months or years later.

## Security & Privacy Requirements

**MUST NOT be committed:**
- SSH private keys (any `id_*` files without `.pub` extension)
- API keys, tokens, or credentials
- `.env` files containing secrets
- Browser cookies, session data, or cached credentials
- Personal email addresses or identifying information in git configs (use generic or
  placeholder values, document required manual substitution in README)

**MUST be in `.gitignore`:**
- `.specify/specs/` (working files)
- `*.key`, `*.secret`, `credentials.*`, `.env.local`
- SSH key patterns: `*.pem`, `*.ppk`, `id_rsa*`, `id_ed25519*`, `id_ecdsa*`

**MUST document in README:**
- Which files require manual customization (e.g., git user.name, user.email)
- How to securely manage secrets (e.g., "Store in Windows Credential Manager")

## Quality Standards

### Scripts
- PowerShell scripts MUST check prerequisites before execution
- Scripts MUST provide clear success/failure messages
- Scripts MUST be idempotent (safe to run multiple times)
- Scripts MUST support `-WhatIf` for dry-run testing where applicable

### Configuration Files
- Config files MUST include comments explaining non-obvious settings
- Config files SHOULD use relative paths or environment variables (not hardcoded paths)
- Config files MUST be tested on a clean Windows 11 installation before commit

### Git Commits
- Commit messages MUST follow conventional commits format:
  `<type>: <description>` (e.g., `feat: add neovim configuration`)
- Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`
- Breaking changes MUST include `BREAKING CHANGE:` in commit body

## Governance

### Constitution Authority
This constitution supersedes all other development practices. When conflicts arise between
convenience and principles, principles MUST prevail. Exceptions require documented
justification in commit messages or PR descriptions.

### Amendment Process
1. Amendments MUST be proposed via spec document using `/speckit.specify`
2. Amendment spec MUST include rationale and impact analysis
3. Version bump follows semantic versioning:
   - **MAJOR**: Principle removal or backward-incompatible governance change
   - **MINOR**: New principle added or existing principle materially expanded
   - **PATCH**: Clarifications, wording improvements, typo fixes
4. After approval, constitution MUST be updated via `/speckit.constitution`
5. All dependent templates MUST be reviewed for consistency

### Compliance Review
- All pull requests MUST verify alignment with Core Principles I-V
- Configuration additions MUST pass Security & Privacy review
- New scripts MUST meet Quality Standards before merge
- Template updates MUST maintain constitution references

### Runtime Guidance
For development workflow guidance, refer to `.claude/commands/` slash command
implementations. For SpecKit usage patterns, see `.specify/templates/`.

**Version**: 1.0.0 | **Ratified**: 2025-10-16 | **Last Amended**: 2025-10-16
