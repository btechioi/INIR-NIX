---
date: 2026-06-03
topic: "iNiR Nix Flake — Dotfiles Deployment"
status: draft
---

# Dotfiles Deployment for iNiR HM Module

## Problem Statement

The iNiR Nix flake's Home Manager module currently deploys only 6 template dotfiles (alacritty, foot, fuzzel, kitty, gtk3, gtk4). The upstream `./setup install` script deploys ~25+ config items from `dots/.config/` and `defaults/`, along with wallpapers, state files, and the runtime QML payload. Users who enable `programs.inir.enable = true` in HM get a broken shell because `~/.config/quickshell/inir/` doesn't exist and most app configs are missing.

## Constraints

- Must pass `nix flake check` — no external dependencies, no impure operations
- Must not duplicate or conflict with the generated niri config (`niri-config.nix`)
- Must not replicate complex installer logic (polkit detection, service enabling, SDDM install)
- The 6 `nix/dotfiles/` template files must still work (they embed nix-colors palette references)
- Wallpapers are large files (40+ MB total) — store in the package, symlink from there

## Chosen Approach: Hybrid xdg.configFile + home.activation

We extend `home-module.nix` with three mechanisms:
1. **`xdg.configFile`** for config files and directories from `dots/.config/` and `defaults/`
2. **`home.file`** for the runtime payload symlink
3. **`home.activation`** for state initialization and wallpaper deployment

### Alternatives Rejected

- **Reimplement installer bash as Nix**: Too fragile. The installer does imperative detection (polkit agent, plasma-integration) that doesn't belong in declarative Nix.
- **Pure symlinks to the repo source**: `nix flake check` would require the source path to exist in the Nix build sandbox. `xdg.configFile` with `source` handles this correctly by copying to the Nix store.
- **Copy everything in package.nix**: The package already ships runtime payload + dotfile copies to `$out/share/inir/`. We should use `xdg.configFile` from the source directly, not from the package, so changes don't require a package rebuild.

## Architecture

### Module structure (home-module.nix)

```
home-module.nix
├── options (unchanged)
├── imports (unchanged)
└── config = mkIf cfg.enable {
    ├── home.packages = [ inirPkg ]  (unchanged)
    ├── home.file (NEW)
    │   └── ".config/quickshell/inir" → symlink to inirPkg/share/quickshell/inir
    ├── xdg.configFile
    │   ├── generated configs (unchanged)
    │   │   ├── niri/config.kdl
    │   │   ├── inir/config.json
    │   │   └── inir/wallpaper
    │   ├── generated palette dotfiles (unchanged — from nix/dotfiles/)
    │   │   ├── alacritty/alacritty.toml
    │   │   ├── foot/foot.ini
    │   │   ├── ... (6 files)
    │   └── (NEW) source-based dotfiles from dots/.config/ and defaults/
    │       ├── fish/config.fish
    │       ├── fish/auto-Niri.fish
    │       ├── mpv/mpv.conf
    │       ├── Kvantum/kvantum.kvconfig
    │       ├── fontconfig/fonts.conf
    │       ├── chrome-flags.conf
    │       ├── code-flags.conf
    │       ├── vesktop/themes/*.css
    │       ├── matugen/config.toml
    │       ├── matugen/templates.json
    │       ├── matugen/templates/*
    │       ├── xdg-desktop-portal/niri-portals.conf
    │       ├── kdeglobals (from defaults/kde/)
    │       ├── dolphinrc
    │       ├── kservicemenurc
    │       ├── starship.toml
    │       ├── fuzzel/fuzzel.ini (from defaults/)
    │       ├── gtk-3.0/settings.ini (from defaults/)
    │       ├── gtk-4.0/settings.ini (from defaults/)
    │       └── inir/config.json (from defaults/config.json)
    ├── home.activation (NEW)
    │   ├── createStateDirs — mkdir -p ~/.local/state/quickshell/user/generated/{wallpaper,terminal}
    │   ├── createStateFiles — touch gamemode_active, notepad.txt; echo [] > todo.json, notifications.json
    │   └── deployWallpapers — cp -a from inirPkg/share/inir/wallpapers to ~/Pictures/Wallpapers/
    ├── home.sessionVariables (NEW)
    │   └── ILLOGICAL_IMPULSE_VIRTUAL_ENV = "${config.xdg.stateHome}/quickshell/.venv"
    └── programs.niri.extraConfig (unchanged)
```

## Components

### 1. Runtime Payload Symlink (`home.file`)

Creates a symlink from `~/.config/quickshell/inir` to the store path:

```nix
home.file.".config/quickshell/inir" = {
  source = "${inirPkg}/share/quickshell/inir";
  recursive = true;  # Ensure directory symlink
};
```

This makes the QML shell runtime available at the path it expects.

### 2. Extended Dotfile Configs (`xdg.configFile`)

Each `dots/.config/` entry maps to an `xdg.configFile` entry with `source` pointing to the actual file/dir in the repo. The key set:

| Source (in repo) | Target (in ~/.config/) | Notes |
|---|---|---|
| `dots/.config/fish/config.fish` | `fish/config.fish` | Single file |
| `dots/.config/fish/auto-Niri.fish` | `fish/auto-Niri.fish` | Single file |
| `dots/.config/mpv/mpv.conf` | `mpv/mpv.conf` | Single file |
| `dots/.config/Kvantum/kvantum.kvconfig` | `Kvantum/kvantum.kvconfig` | Single file |
| `dots/.config/fontconfig/fonts.conf` | `fontconfig/fonts.conf` | Single file |
| `dots/.config/chrome-flags.conf` | `chrome-flags.conf` | Single file |
| `dots/.config/code-flags.conf` | `code-flags.conf` | Single file |
| `dots/.config/vesktop/themes` | `vesktop/themes` | Directory recurse |
| `dots/.config/matugen` | `matugen` | Directory recurse |
| `dots/.config/xdg-desktop-portal/niri-portals.conf` | `xdg-desktop-portal/niri-portals.conf` | Single file |
| `defaults/kde/kdeglobals` | `kdeglobals` | Single file |
| `defaults/kde/dolphinrc` | `dolphinrc` | Single file |
| `defaults/kde/kservicemenurc` | `kservicemenurc` | Single file |
| `defaults/starship/starship.toml` | `starship.toml` | Single file |
| `defaults/fuzzel/fuzzel.ini` | `fuzzel/fuzzel.ini` | Single file |
| `defaults/gtk-3.0/settings.ini` | `gtk-3.0/settings.ini` | Single file |
| `defaults/gtk-4.0/settings.ini` | `gtk-4.0/settings.ini` | Single file |
| `defaults/config.json` | `inir/config.json` | **Note: different target** — this goes to `illogical-impulse/config.json` in the old config dir name |

### 3. State Initialization (`home.activation`)

A lightweight activation script that:
- Creates state directories (`XDG_STATE_HOME/quickshell/user/generated/{wallpaper,terminal}`)
- Creates empty state files (gamemode_active, notepad.txt)
- Initializes JSON state files (todo.json → `[]`, notifications.json → `[]`)

Uses `home.activation` with `lib.hm.dag.entryAfter ["writeBoundary"]` to run after config files are written.

### 4. Wallpaper Deployment (`home.activation`)

Wallpapers ship in the package at `$out/share/inir/wallpapers/`. On activation:
- Copy wallpapers to `~/Pictures/Wallpapers/inir/` (or configurable path)
- Only copies if the target doesn't already have files (avoid overwriting user's collection)

### 5. Session Environment Variables

```nix
home.sessionVariables = {
  ILLOGICAL_IMPULSE_VIRTUAL_ENV = "${config.xdg.stateHome}/quickshell/.venv";
};
```

## Data Flow

```
flake.nix → home-manager module
                │
                ├── inirPkg (from package.nix)
                │   ├── $out/bin/inir
                │   ├── $out/share/quickshell/inir/  →  home.file → ~/.config/quickshell/inir
                │   └── $out/share/inir/wallpapers/  →  activation → ~/Pictures/Wallpapers/
                │
                ├── dots/.config/*  →  xdg.configFile  →  ~/.config/*
                │
                ├── defaults/*  →  xdg.configFile  →  ~/.config/*
                │
                ├── nix/dotfiles/*  →  xdg.configFile  →  ~/.config/* (with palette, if nix-colors available)
                │
                └── activation  →  state dirs/files
```

## Error Handling

- **Missing source files**: If a `dots/.config/` file doesn't exist (e.g., user pruned it from their checkout), the module will fail at evaluation time with a clear error from `builtins.readFile` or `source`. This is acceptable — users should have a complete checkout.
- **Palette not available**: The palette-based dotfiles (nix/dotfiles/) are already guarded by `lib.mkIf (palette != null)`.
- **Wallpaper deployment failure**: The activation script uses `|| true` to avoid blocking the entire activation.
- **State file creation failure**: Uses `|| true` for each file — state files are non-critical.

## Testing Strategy

1. **`nix flake check`** validates the module evaluates correctly
2. **Manual test**: Enable the module in a home-manager configuration, verify files appear in `~/.config/`
3. **Snapshot test**: The existing `nix/tests/snapshot.nix` can be extended to verify xdg.configFile entries exist

## Open Questions

1. **`darklyrc`**: The installer copies `dots/.config/darklyrc` but this file is KDE/Qt specific. Should we deploy it? I'm leaning **no** — it's a KDE theming detail that's dynamic (written by the Material You pipeline), not a static config.
2. **`konsolerc`**: Similarly KDE-specific. **Skipping** — users who use Konsole can enable it themselves.
3. **`dolphinstaterc`**: This is a state file, not a config file. The installer writes it only on fresh install. **Skipping** — HM shouldn't manage state, only config.
4. **Shell env vars (bashrc/zshrc)**: The installer writes env vars to shell profiles. HM should handle this via `home.sessionVariables` instead. **Done**.
5. **AI prompts** (`defaults/ai/`): Optional content. **Skipping** — users who want AI prompts can add them via extraConfig.
6. **Plugins** (`defaults/plugins/`): Disabled in the installer too (webengine dependency). **Skipping**.
