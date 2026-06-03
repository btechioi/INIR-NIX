# INIR-NIX: Flake Polish Implementation Plan

**Goal:** Add dev tooling (formatter + devShell), fix `tryEval` conditional dependency, eliminate XDG portal eval warning, and clarify palette-comment semantics — all with zero external API changes.

**Architecture:** Four independent one-file edits, no cross-cutting concerns. Each change is self-contained with a clear before/after diff.

**Design:** `thoughts/shared/designs/2026-06-03-inir-nix-polish-design.md`

---

## Dependency Graph

```
Batch 1 (parallel): 1.1, 1.2, 1.3, 1.4    [all independent — start simultaneously]
```

---

## Batch 1: Polish Fixes (parallel — 4 implementers)

All 4 tasks modify different files with zero dependencies between them. Run simultaneously.

---

### Task 1.1: `flake.nix` — Add `formatter` + `devShells` outputs

**File:** `flake.nix`
**Test:** none (verified by `nix flake check` and `nix develop`)
**Depends:** none

**Change description:** Add two new standard flake outputs — `formatter` (enables `nix fmt`) and `devShells.default` (development shell with lint/format tooling). Preserves all existing outputs.

**Exact diff:**
Insert after line 32 (closing `});` of the `packages` block) and before line 34 (comment `# Example NixOS configuration`):

```nix

    # Formatter — enables `nix fmt` to format all Nix files
    formatter = forAllSystems (system: (mkPkgs system).nixpkgs-fmt);

    # Development shell — tools for working on this flake
    devShells = forAllSystems (system: let
      pkgs = mkPkgs system;
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [ nixpkgs-fmt statix deadnix ];
        shellHook = ''
          echo "=== iNiR Nix development shell ==="
          echo "Available tools:"
          echo "  nixpkgs-fmt  — Nix formatter (run: nix fmt)"
          echo "  statix        — Nix linter (run: statix .)"
          echo "  deadnix       — Dead Nix code finder"
        '';
      };
    });
```

**Resulting `flake.nix` (full file for reference):**

```nix
{
  description = "iNiR — A complete desktop shell for Niri, built on Quickshell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    niri-flake.url = "github:sodiboo/niri-flake";
    nix-colors.url = "github:misterio77/nix-colors";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, niri-flake, nix-colors, home-manager }@inputs: let
    systems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    mkPkgs = system: import nixpkgs { inherit system; };
  in {
    # NixOS module — add to your imports
    nixosModules.inir = import ./nix/nixos-module.nix;
    # Also export under the flake module path (for flake-parts style)
    nixosModules.default = self.nixosModules.inir;

    # Home Manager module — add to home-manager.sharedModules
    homeManagerModules.inir = import ./nix/home-module.nix;
    homeManagerModules.default = self.homeManagerModules.inir;

    # Package
    packages = forAllSystems (system: {
      inir = (mkPkgs system).callPackage ./nix/package.nix { };
      default = self.packages.${system}.inir;
    });

    # Formatter — enables `nix fmt` to format all Nix files
    formatter = forAllSystems (system: (mkPkgs system).nixpkgs-fmt);

    # Development shell — tools for working on this flake
    devShells = forAllSystems (system: let
      pkgs = mkPkgs system;
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [ nixpkgs-fmt statix deadnix ];
        shellHook = ''
          echo "=== iNiR Nix development shell ==="
          echo "Available tools:"
          echo "  nixpkgs-fmt  — Nix formatter (run: nix fmt)"
          echo "  statix        — Nix linter (run: statix .)"
          echo "  deadnix       — Dead Nix code finder"
        '';
      };
    });

    # Example NixOS configuration (see docs/HOWTO.md for full usage)
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        self.nixosModules.inir
        ({ config, pkgs, ... }: {
          # Minimal system config so flake check can evaluate
          system.stateVersion = "24.11";
          fileSystems."/" = { device = "/dev/null"; fsType = "tmpfs"; };
          boot.loader.grub.devices = [ "/dev/null" ];

          programs.inir = {
            enable = true;
            niri.enable = true;
            graphics.enable = true;
            pipewire.enable = true;
            portals.enable = true;
            useCache = true;
          };
        })
      ];
    };
  };
}
```

**Verify:**
1. `nix flake check --no-build` must pass
2. `nix develop --command which nixpkgs-fmt` must succeed
3. `nix fmt -- --check` must run without errors

**Commit:** `feat(flake): add formatter (nixpkgs-fmt) and devShell with lint tools`

---

### Task 1.2: `nix/packages.nix` — Fix `tryEval` optional dependency detection

**File:** `nix/packages.nix`
**Test:** `nix build '.#packages.x86_64-linux.inir'` must succeed
**Depends:** none

**Problem:** The current pattern `builtins.tryEval (builtins.hasAttr "materialyoucolor" python3Packages)` always returns `{ success = true; }` because `hasAttr` never throws — it returns `false` if the attr is missing. So `materialyoucolor` is always included even when not available.

**Fix:** Evaluate the attribute access directly inside `tryEval` so it fails correctly when the package is missing.

**Exact edit:** Replace lines 49-52 with:

```nix
  # Optional packages (only if available in nixpkgs)
  optional = let
    matugen = builtins.tryEval pkgs.python3Packages.materialyoucolor;
  in lib.optionals (matugen.success && matugen.value != null) [
    pkgs.python3Packages.materialyoucolor
  ];
```

**Resulting file (`nix/packages.nix`):**

```nix
{ pkgs }:
let
  inherit (pkgs) callPackage;
in rec {
  # Core shell dependencies
  core = with pkgs; [
    cliphist curl jq ripgrep wl-clipboard libnotify wlsunset
    nautilus networkmanager gnome-keyring polkit_gnome
    fish xwayland-satellite
  ];

  # Quickshell and Qt dependencies
  quickshell = with pkgs; [
    quickshell qt6.qtdeclarative qt6.qtbase qt6.qtsvg
    qt6.qtwayland qt6.qtmultimedia qt6.qtpositioning
    qt6.qtvirtualkeyboard kirigami
    libsForQt5.plasma-integration
    breeze-icons
  ];

  # Audio
  audio = with pkgs; [
    pipewire wireplumber playerctl pavucontrol
    mpv yt-dlp
  ];

  # Screenshot and recording
  screencapture = with pkgs; [
    grim slurp swappy tesseract5 wf-recorder
    imagemagick ffmpeg
  ];

  # Toolkit
  toolkit = with pkgs; [
    upower wtype ydotool python3Packages.evdev
    brightnessctl ddcutil geoclue2 swayidle swaylock
    blueman libqalculate
  ];

  # Fonts and launcher
  fonts = with pkgs; [
    nerd-fonts.jetbrains-mono dejavu_fonts liberation_ttf
    fuzzel translate-shell
  ];

  # All combined for convenience
  all = core ++ quickshell ++ audio ++ screencapture ++ toolkit ++ fonts;

  # Optional packages (only if available in nixpkgs)
  optional = let
    matugen = builtins.tryEval pkgs.python3Packages.materialyoucolor;
  in lib.optionals (matugen.success && matugen.value != null) [
    pkgs.python3Packages.materialyoucolor
  ];
}
```

**How it works:**
- If `python3Packages.materialyoucolor` doesn't exist, `tryEval` catches the eval error and returns `{ success = false; value = false; }`
- If it exists but is `null`, returns `{ success = true; value = null; }`
- The guard `matugen.success && matugen.value != null` correctly excludes it in both failure cases
- If the package exists and is a valid derivation, it's included

**Verify:** `nix build '.#packages.x86_64-linux.inir'` must succeed

**Commit:** `fix(packages): correct tryEval detection of materialyoucolor`

---

### Task 1.3: `nix/nixos-module.nix` — Add XDG portal `config.common.default`

**File:** `nix/nixos-module.nix`
**Test:** `nix flake check --no-build` must pass clean (no portal eval warning)
**Depends:** none

**Problem:** xdg-desktop-portal 1.17+ requires `config.common.default` to be set. Without it, an eval warning is emitted during `nix flake check`.

**Fix:** Add `config.common.default = "*";` inside the `xdg.portal` `mkIf` block. This tells the portal to use the first available backend — same behavior as pre-1.17 but without the warning.

**Exact edit:** Insert one line after line 117 (`configPackages = lib.mkForce [ ];`) inside the `xdg.portal` block.

**Change:** Lines 112-118 become:

```nix
    # XDG Desktop Portals
    xdg.portal = lib.mkIf cfg.portals.enable {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      # Explicitly avoid gnome portal
      configPackages = lib.mkForce [ ];
      # Set default portal to avoid xdg-desktop-portal 1.17+ warning
      config.common.default = "*";
    };
```

**Verify:** `nix flake check --no-build` must show no portal-related warnings

**Commit:** `fix(nixos): add xdg.portal.config.common.default to suppress 1.17+ warning`

---

### Task 1.4: `nix/home-module.nix` — Clarify palette-conditional dotfile comment

**File:** `nix/home-module.nix`
**Test:** none (comment-only change)
**Depends:** none

**Problem:** The comment `# App dotfiles (only when palette is available via nix-colors)` on line 207 misleadingly suggests the files are palette-interpolated templates. They are actually static, theme-optimized defaults that complement the Material You color scheme.

**Fix:** Replace the comment with clearer documentation explaining what these files are and why they exist behind the conditional.

**Exact edit:** Replace line 207:

**Before:**
```nix
      # App dotfiles (only when palette is available via nix-colors)
```

**After:**
```nix
      # Theme-optimized static defaults deployed when a nix-colors palette is set.
      # These files are NOT palette-interpolated templates — they are hand-picked
      # defaults that complement the Material You color scheme (e.g., dark-themed
      # terminal configs, GTK/Qt theme overrides). They provide a cohesive visual
      # starting point without injecting dynamic color values at build time.
```

**Verify:** Whitespace and indentation preserved. File still parseable by `nix-instantiate --parse`.

**Commit:** `docs(home): clarify palette-conditional dotfiles are static defaults, not templates`

---

## Verification (run after all tasks applied)

```bash
# 1. Flake check must pass clean (no portal warning)
nix --extra-experimental-features 'nix-command flakes' flake check --no-build

# 2. Dev shell must provide nixpkgs-fmt
nix --extra-experimental-features 'nix-command flakes' develop --command which nixpkgs-fmt

# 3. Package build must succeed
nix --extra-experimental-features 'nix-command flakes' build '.#packages.x86_64-linux.inir'

# 4. No new statix lint warnings
statix .
```
