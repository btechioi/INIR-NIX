---
date: 2026-06-03
topic: "INIR-NIX as a Declarative NixOS Flake"
status: validated
---

## Problem Statement

INIR-NIX (a fork of [snowarch/inir](https://github.com/snowarch/inir) v2.25.2) is a complete desktop shell for the Niri compositor, built on Quickshell. Currently it's installed via a bash script (`./setup`) or `make install` — both imperative, Arch-centric flows. On NixOS, none of this works out of the box.

The goal is to transform this repo into a **fully declarative NixOS flake** where:
- Adding `programs.inir.enable = true` to your NixOS config is all you need
- Niri and iNiR are configured together from Nix options
- Color schemes are reproducible via nix-colors
- The entire desktop is declared in config, not set up at runtime

## Constraints

- **No runtime installer scripts** — the `setup` script and `make install` are bypassed on NixOS
- **Must coexist with upstream** — we wrap the existing project with Nix; we don't rewrite the QML/Python/Go code
- **Niri must use `sodiboo/niri-flake`** — that's the canonical community flake, provides both NixOS and Home Manager modules
- **Quickshell from nixpkgs** — prefer the nixpkgs `quickshell` package; fall back to outfoxxed's flake if too old
- **Must support both static (nix-colors) and dynamic (Material You) theming**
- **Must handle 70+ dependencies** categorized into groups: core, quickshell, audio, screencapture, toolkit, fonts

## Approach

**Chosen: Full NixOS flake with Home Manager integration.**

Three approaches were considered:

| Approach | Scope | Why rejected |
|----------|-------|-------------|
| Minimal (package only) | Just package the files, give example snippets | Not declarative — still manual runtime config |
| Home Manager only | Package + HM module for user config | Misses system deps (niri, portals, pipewire, drivers) |
| **Full NixOS + HM module** | Package + NixOS module + HM module + niri integration | Most declarative — single `enable = true` and everything works |

The chosen approach gives users one flake input, one enable toggle, and the entire niri + iNiR desktop is declared in Nix. No runtime JSON editing, no setup scripts.

## Architecture

### Layer Diagram

```
flake.nix
├── inputs: nixpkgs, niri-flake, nix-colors
│
├── nixosModules.inir (system-level)
│   ├── Enables niri compositor (via niri-flake)
│   ├── Installs all system packages (portals, pipewire, audio, GPU drivers)
│   ├── Configures xdg.portal for Wayland
│   ├── Sets up binary caches (niri.cachix.org)
│   └── Installs inir systemd user service (wants niri.service)
│
├── homeManagerModules.inir (user-level)
│   ├── Installs inir package (QML shell, Go binary, scripts, dotfiles)
│   ├── Generates ~/.config/niri/config.kdl from Nix options
│   ├── Generates ~/.config/inir/config.json from Nix options
│   ├── Applies color scheme (nix-colors or Material You)
│   ├── Manages app dotfiles (alacritty, foot, fuzzel, fish, kitty, etc.)
│   └── Autostarts inir shell via niri's spawn-at-startup
│
└── packages.inir (the package)
    ├── Builds Go launcher binary (scripts/inir)
    ├── Installs QML shell files to share/quickshell/inir/
    ├── Installs scripts (Python, Bash, Fish)
    ├── Installs defaults (config.json, app-catalog, presets)
    └── Installs desktop entries and icons
```

### File Structure

```
📁 inir-nix/
├── flake.nix                  # Top-level flake
├── nix/
│   ├── package.nix            # Inir package derivation
│   ├── nixos-module.nix       # NixOS module
│   ├── home-module.nix        # Home Manager module
│   ├── niri-config.nix        # KDL config generator
│   ├── inir-config.nix        # JSON config generator
│   └── color-pipeline.nix     # Color scheme integration
├── (all existing files unchanged)
│   ├── modules/               # 30 QML modules
│   ├── scripts/               # Go/Python/Bash scripts
│   ├── defaults/              # Reference configs
│   ├── dots/                  # Dotfile templates
│   └── assets/                # Icons, systemd service
```

## Components

### `flake.nix` — Wiring

**Inputs:**
- `nixpkgs` (nixos-unstable — recent QML6/Quickshell packages)
- `niri-flake` from `github:sodiboo/niri-flake`
- `nix-colors` from `github:misterio77/nix-colors`

**Outputs:**
- `nixosModules.inir` — add to `imports` in configuration.nix
- `homeManagerModules.inir` — add to `home-manager.sharedModules`
- `packages.<system>.inir` — standalone package
- `nixosConfigurations.*` — example reference config

Passes inputs via `specialArgs` to both NixOS and HM modules (same pattern as the reference blog post).

### Package (`nix/package.nix`)

Bundles the existing project into a Nix derivation without modifying source files:

- **Go binary**: Build `scripts/inir/` with `buildGoModule`. Uses `go.mod` (Go 1.26).
- **QML shell**: Copies `*.qml` + all 30 `modules/*/` into the store at `$out/share/quickshell/inir/`
- **Scripts**: Installs `scripts/`, `sdata/lib/`, `sdata/subcmd-install/` with executable bits
- **Defaults**: Installs `defaults/` as reference under `$out/share/inir/defaults/`
- **Assets**: Installs icons, desktop entries, systemd service template
- **Dots**: Installs `dots/.config/*` as reference under `$out/share/inir/dotfiles/`

Key challenge: The Go binary path in nixpkgs is `scripts/inir` (a directory). Needs a Go package name that matches. We may need to move or alias the Go module path.

### NixOS Module (`nix/nixos-module.nix`)

```nix
programs.inir = {
  enable = true;          # Master toggle
  
  # Niri compositor
  niri.enable = true;     # Enable niri via niri-flake module (default: true)
  
  # Hardware
  graphics.enable = true;
  graphics.enable32Bit = true;
  nvidia = {
    enable = false;
    open = false;
    modesetting.enable = true;
  };
  
  # System services
  pipewire.enable = true;
  portals.enable = true;
  
  # Binary cache
  useCache = true;        # Adds niri.cachix.org to substituters
};
```

When enabled:
1. Imports and enables `niri-flake.nixosModules.niri`
2. Sets `hardware.graphics.enable = true`
3. Enables PipeWire with ALSA/Pulse/JACK support
4. Configures `xdg.portal` with GTK portal (explicitly avoids GNOME portal)
5. Sets up `security.rtkit.enable = true` (for PipeWire)
6. Adds Cachix substituter for niri (`niri.cachix.org`)
7. Installs all system-level dependencies from PACKAGES.md groups

### Home Manager Module (`nix/home-module.nix`)

```nix
programs.inir = {
  enable = true;
  
  # Color scheme
  colorScheme = "tokyo-night";    # or use nix-colors directly
  colorSchemeModule = null;       # Set to nix-colors colorSchemes.dracula to use nix-colors
  
  # Panel
  panelFamily = "ii";             # "ii" or "waffle"
  style = "material";             # material, cards, aurora, inir, angel
  
  # Apps
  terminal = "alacritty";
  launcher = "fuzzel";
  browser = "firefox";
  fileManager = "nautilus";
  
  # Niri config (generated into config.kdl)
  niri = {
    prefer-no-csd = true;
    layout.gaps = 5;
    layout.focus-ring.width = 1.5;
    layout.focus-ring.active-color = "#7fc8ff";
    binds = {
      "Mod+Return" = { action = "spawn"; args = [ "alacritty" ]; };
      "Mod+D" = { action = "spawn"; args = [ "fuzzel" ]; };
      "Mod+Q" = { action = "close-window"; };
      "Mod+1" = { action = "focus-workspace"; args = [ "1" ]; };
      "Mod+Shift+1" = { action = "move-column-to-workspace"; args = [ "1" ]; };
      "Mod+T" = { action = "switch-layout"; };
      "Mod+S" = { action = "screenshot"; };
      "Mod+F" = { action = "maximize-column"; };
      "Mod+Shift+F" = { action = "fullscreen-window"; };
    };
  };
  
  # Window rules
  windowRules = [
    { app-id = "firefox"; open-maximized = true; }
    { app-id = "Alacritty"; geometry-corner-radius = 4; }
    { app-id = "org.gnome.Nautilus"; open-on-workspace = "2"; }
  ];
  
  # Wallpaper
  wallpaper = null;               # null = bundled default, or a path
  wallpaperDirectory = null;      # Directory for wallpaper rotation
};
```

When enabled:
1. Installs the `inir` package
2. Generates `~/.config/niri/config.kdl` from the `niri` options subtree
3. Generates `~/.config/inir/config.json` from panel/style/app options
4. Generates all application dotfiles (alacritty, foot, fuzzel, kitty, fish, etc.) with colors applied
5. Adds `spawn-at-startup` entry for the iNiR shell
6. If using nix-colors, propagates color palette to all config templates
7. Sets up wallpaper directory with bundled fallback
8. Configures the iNiR systemd user service to start with niri

### Niri Config Generator (`nix/niri-config.nix`)

Converts the Nix option tree into a valid KDL file:

- Flat keys like `prefer-no-csd` → `prefer-no-csd` in KDL
- Nested blocks like `layout.focus-ring.active-color` → properly indented KDL blocks
- Keybinds with complex actions (spawn, focus-workspace, move-column-to-workspace) → proper KDL syntax
- Window rules → `window-rule { match ... }` blocks
- Monitors → `output "eDP-1" { ... }` blocks from hardware detection
- Includes the cheatsheet keybind labels for the built-in help overlay

### Config Generator (`nix/inir-config.nix`)

Generates the `~/.config/inir/config.json`:

- Panel family, bar position, clock format
- Visual style selection
- Application preferences (terminal, browser, launcher, file manager)
- Search engine, weather location
- Animation and blur toggles
- Color hex values from nix-colors palette

### Color Pipeline (`nix/color-pipeline.nix`)

Two modes:

1. **Static mode (default)**: Uses nix-colors to set all colors at build time. Reproducible, no runtime dependencies. The color scheme is baked into all generated configs.

2. **Dynamic mode (optional)**: Preserves the existing Material You pipeline. At runtime, the wallpaper triggers `generate_colors_material.py` → `applycolor.sh` which updates dotfiles. This mode requires Python, Pillow, and the Material You libraries at runtime.

The module exports a `palette` attrset that both niri and iNiR configs consume, keeping colors in sync everywhere.

## Data Flow

```
Build time (Nix):
  flake.nix
    → nixpkgs builds inir package (Go binary + QML files + scripts)
    → nixos-module.nix installs system packages
    → home-module.nix generates config files:
        → ~/.config/niri/config.kdl   (from niri options)
        → ~/.config/inir/config.json  (from panel/style options)
        → ~/.config/alacritty/...     (templates with colors)
        → ~/.config/foot/...
        → ~/.config/fuzzel/...
        → ~/.config/fish/...
        → ~/.config/kitty/...
        → ~/.config/gtk-3.0/settings.ini

Boot time (systemd):
  systemd → niri compositor (started as display-manager or user service)
            → reads /etc/niri/config.kdl (or ~/.config/niri/config.kdl)
            → spawn-at-startup: inir run
              → quickshell loads shell.qml
              → reads ~/.config/inir/config.json
              → (optional) Material You pipeline generates theme

Runtime (optional dynamic theming):
  wallpaper change → switchwall.sh → generate_colors_material.py
    → writes colors.json → applycolor.sh updates all dotfiles
    → inir shell reloads QML with new colors
```

## Package Groups (from PACKAGES.md → Nix)

The module maps existing package groups to Nix packages:

| Group | Key Nix Packages |
|-------|-----------------|
| **core** | `niri`, `cliphist`, `curl`, `jq`, `ripgrep`, `python3`, `wl-clipboard`, `libnotify`, `wlsunset`, `nautilus`, `networkmanager`, `gnome-keyring`, `polkit_gnome`, `fish`, `xwayland-satellite` |
| **quickshell** | `quickshell`, `qt6.qtdeclarative`, `qt6.qtbase`, `qt6.qtsvg`, `qt6.qtwayland`, `qt6.qtmultimedia`, `qt6.qtpositioning`, `qt6.qtvirtualkeyboard`, `kirigami`, `libsForQt5.plasma-integration`, `breeze-icons` |
| **audio** | `pipewire`, `wireplumber`, `playerctl`, `pavucontrol`, `mpv`, `yt-dlp` |
| **screencapture** | `grim`, `slurp`, `swappy`, `tesseract5`, `wf-recorder`, `imagemagick`, `ffmpeg` |
| **toolkit** | `upower`, `wtype`, `ydotool`, `python3Packages.evdev`, `brightnessctl`, `ddcutil`, `geoclue2`, `swayidle`, `swaylock`, `blueman`, `libqalculate` |
| **fonts** | `nerd-fonts.jetbrains-mono`, `dejavu_fonts`, `liberation_ttf`, `fuzzel`, `translate-shell` |

AUR-only packages (darkly-bin, ttf-material-symbols, etc.) need to either be packaged in nixpkgs or provided via the quickshell flake. Where unavailable, we fall back gracefully.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| niri-flake not in inputs | Assertion error: "niri-flake is required. Add `niri.url = github:sodiboo/niri-flake` to your flake inputs" |
| Unsupported GPU | Fall back to modesetting, log eval warning |
| nix-colors not in use | Skip color propagation, use hardcoded defaults from `defaults/config.json` |
| Missing wallpaper | Use bundled wallpapers from `$out/share/inir/wallpapers/` |
| Quickshell too old in nixpkgs | Offer `quickshell` flake input as alternative |
| Invalid panel family | Schema validation in HM module options (type check on enum) |
| AUR-only package unavailable | Graceful degradation — feature disables, log warning at eval time |

## Testing Strategy

1. **Build test**: `nix build .#inir` — verifies Go compilation and file layout
2. **NixOS VM test**: `nixos-test` with `programs.inir.enable = true` — boots niri, verifies iNiR starts
3. **Config generation test**: Snapshot tests for generated `config.kdl` and `config.json` against known-good outputs
4. **Color propagation test**: Verify nix-colors palette values appear in all generated configs (alacritty, foot, niri, gtk, etc.)
5. **Upgrade test**: Existing non-Nix config detected and preserved gracefully

## Open Questions

1. **Go module path**: The Go binary is at `scripts/inir/` with `go.mod` declaring `module inir`. Nixpkgs `buildGoModule` expects the module path to match the source path. May need to restructure or alias — to be resolved during planning.
2. **Quickshell version**: Need to verify which version of quickshell is in nixpkgs unstable and whether it's new enough for iNiR's QML features. If not, we add a quickshell flake input.
3. **darkly-bin availability**: The Qt theming package `darkly-bin` is AUR-only. Need to check nixpkgs for `darkly` or package it ourselves as a Nix derivation.
4. **Material You dynamic mode**: The Python color pipeline (matugen/material-you) isn't in nixpkgs. Dynamic mode may require packaging Python dependencies or pinning to the bundled scripts.
5. **niri version compatibility**: iNiR 2.25.2 expects certain niri features. Need to pin niri-flake to a compatible version.
