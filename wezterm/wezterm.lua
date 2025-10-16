-- Wezterm Configuration
-- Location: ~/.wezterm.lua (symlinked from dotfiles/wezterm/wezterm.lua)
-- See: https://wezfurlong.org/wezterm/config/files.html

-- Import the wezterm API
local wezterm = require 'wezterm'

-- Initialize config object (compatible with wezterm >= 20220101)
local config = {}
if wezterm.config_builder then
    config = wezterm.config_builder()
end

-- ============================================================================
-- Font Configuration
-- ============================================================================
-- Requires a Nerd Font for proper icon rendering with Oh My Posh
-- Install: choco install cascadia-code-nerd-font -y
-- Or download from: https://www.nerdfonts.com/

config.font = wezterm.font 'CascadiaCode Nerd Font'
config.font_size = 11.0

-- Enable ligatures for programming symbols (=>  !=  etc.)
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }

-- ============================================================================
-- Color Scheme
-- ============================================================================
-- Preview themes: https://wezfurlong.org/wezterm/colorschemes/index.html
-- Popular alternatives: 'Catppuccin Mocha', 'Dracula', 'Gruvbox Dark', 'Nord'

config.color_scheme = 'Tokyo Night'

-- ============================================================================
-- Window & Appearance
-- ============================================================================

-- Tab bar settings
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false  -- Use native tab bar (cleaner look)

-- Window padding (adjust for comfortable spacing)
config.window_padding = {
    left = 8,
    right = 8,
    top = 8,
    bottom = 8,
}

-- Window transparency (optional - set to 1.0 for opaque)
config.window_background_opacity = 1.0

-- Starting window size (columns x rows)
config.initial_cols = 120
config.initial_rows = 30

-- ============================================================================
-- Behavior Settings
-- ============================================================================

-- Scrollback buffer (number of lines to keep in history)
config.scrollback_lines = 10000

-- Cursor style
config.default_cursor_style = 'SteadyBar'

-- Close confirmation when pane has a running process
config.window_close_confirmation = 'NeverPrompt'

-- ============================================================================
-- Key Bindings (Optional Customization)
-- ============================================================================
-- Uncomment to add custom key bindings
-- config.keys = {
--     -- Example: Ctrl+Shift+T to create new tab
--     { key = 'T', mods = 'CTRL|SHIFT', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
-- }

-- ============================================================================
-- Default Shell (Optional)
-- ============================================================================
-- Uncomment to set PowerShell 7 as default shell
-- Requires: choco install powershell-core -y

-- config.default_prog = { 'pwsh.exe', '-NoLogo' }

-- ============================================================================
-- Return Configuration
-- ============================================================================

return config
