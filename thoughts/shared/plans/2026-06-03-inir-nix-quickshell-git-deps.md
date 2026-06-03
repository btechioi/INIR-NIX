# Quickshell from Git + Auto-install Runtime Dependencies

**Goal:** Add `quickshell` flake input (git) so INIR uses latest QS; auto-install all runtime deps when `programs.inir.enable = true`.

**Architecture:** Three changes to INIR-NIX + one to My-NixOS:
- Add `quickshell` flake input (parallel to `niri-flake`)
- Parameterize `packages.nix` to accept `quickshellPkg` argument
- Both modules (NixOS + HM) import deps and add a toggleable `installDeps` option
- My-NixOS gets `chromium` + `onlyoffice` in `home.packages`

**Design:** `thoughts/shared/designs/2026-06-03-inir-nix-quickshell-git-deps-design.md`

---

## Dependency Graph

```
Batch 1 (parallel): A, B, E     [independent — no cross-deps]
Batch 2 (parallel): C, D         [both depend on B for packages.nix changes]
```

---

## Batch 1: Foundation (parallel — 3 implementers)

All tasks in this batch have NO dependencies on each other and can run simultaneously.

### Task A: Add `quickshell` flake input

**File:** `flake.nix`
**Test:** `nix flake check --no-build` (verification only)
**Depends:** none

**Change:** Add `quickshell.url = "github:outfoxxed/quickshell"` to the `inputs` block, right after `niri-flake` (keeping alphabetical/grouping with other git flake inputs).

**Before (line 5-12):**
```nix
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    niri-flake.url = "github:sodiboo/niri-flake";
    nix-colors.url = "github:misterio77/nix-colors";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
```

**After:**
```nix
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    niri-flake.url = "github:sodiboo/niri-flake";
    quickshell.url = "github:outfoxxed/quickshell";
    nix-colors.url = "github:misterio77/nix-colors";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
```

**Implementation:** Simple `edit` on `flake.nix` — insert the line after `niri-flake.url` line.

**Verification:** `nix flake check --no-build` passes (the new input resolves and is available).

---

### Task B: Parameterize `packages.nix` with `quickshellPkg`

**File:** `nix/packages.nix`
**Test:** `nix eval --file nix/packages.nix --arg pkgs 'import <nixpkgs> {}' --json` (verification only)
**Depends:** none

**Changes:**

1. **Line 1:** Change signature from `{ pkgs }:` to `{ pkgs, quickshellPkg ? pkgs.quickshell }:`

2. **Line 13:** In the `quickshell` category list, replace `pkgs.quickshell` with `quickshellPkg`

**Before (line 1, line 12-13):**
```nix
{ pkgs }:
let
  inherit (pkgs) callPackage;
in rec {
  ...
  quickshell = with pkgs; [
    quickshell qt6.qtdeclarative qt6.qtbase qt6.qtsvg
```

**After:**
```nix
{ pkgs, quickshellPkg ? pkgs.quickshell }:
let
  inherit (pkgs) callPackage;
in rec {
  ...
  quickshell = with pkgs; [
    quickshellPkg qt6.qtdeclarative qt6.qtbase qt6.qtsvg
```

**Logic:** 
- Design says "parameterize packages.nix to accept quickshellPkg". The default `pkgs.quickshell` ensures backward compatibility for anyone calling this directly without the argument.
- Only `quickshell` is changed to `quickshellPkg` in the list — everything else stays as `pkgs.XXX`.

**Verification:** `nix eval` should still produce the same attrset since `quickshellPkg` defaults to `pkgs.quickshell`.

---

### Task E: My-NixOS — add chromium and onlyoffice to home.packages

**File:** `/home/banumath/Projects/My-NixOS/standard/home-manager/home.nix`
**Test:** `home-manager build` (manual)
**Depends:** none (separate repo, no relation to INIR-NIX tasks)

**Change:** Add `chromium` and `onlyoffice-bin` to the `home.packages` list at line 176.

**Before (line 176-178):**
```nix
  # ── User packages ───────────────────────────────────────────────────────
  home.packages = with pkgs; [
    git alejandra
  ];
```

**After:**
```nix
  # ── User packages ───────────────────────────────────────────────────────
  home.packages = with pkgs; [
    git alejandra chromium onlyoffice-bin
  ];
```

**Implementation decision:** Design says `onlyoffice-bin` (or `onlyoffice`). I'm using `onlyoffice-bin` because it's the pre-built binary package in nixpkgs, avoiding the lengthy source build. If it's unavailable on the user's system, they can switch to `onlyoffice` (source build).

**Verification:** `home-manager build` succeeds; check that `chromium` and `onlyoffice-bin` are in the built derivation's `home.packages`.

---

## Batch 2: Module Enhancements (parallel — 2 implementers)

Both tasks depend on **Task B** (packages.nix signature change) and **Task A** (quickshell input being available for the conditional check).

### Task C: NixOS module — import deps + installDeps option

**File:** `nix/nixos-module.nix`
**Test:** `nix flake check --no-build` + NixOS eval (verification)
**Depends:** Task A, Task B

**Three changes:**

1. **Let block (after line 4):** Add `inirDeps` import that resolves quickshell from the flake or falls back to nixpkgs.

2. **Options section (after line 75):** Add `programs.inir.installDeps` option.

3. **Config section (line 88):** Change `environment.systemPackages` line.

**Change 1 — Let block (after line 5: `hasNiriFlake`):**
```nix
  inirDeps = import ./packages.nix {
    inherit pkgs;
    quickshellPkg = if builtins.hasAttr "quickshell" inputs
      && inputs.quickshell ? packages.${pkgs.system}.default
      then inputs.quickshell.packages.${pkgs.system}.default
      else pkgs.quickshell;
  };
```

**Implementation detail:** The `builtins.hasAttr "quickshell" inputs` check prevents errors when the quickshell input is not in the flake. The `inputs.quickshell ? packages.${pkgs.system}.default` check verifies the resolved flake actually has a default package for the current system. Falls back to `pkgs.quickshell` from nixpkgs if either check fails.

**Change 2 — Options (after line 75, before `useCache`):**
Add inside the `options.programs.inir` block:
```nix
    installDeps = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to automatically install runtime dependencies for iNiR";
    };
```

**Before (line 87-89):**
```nix
    # Install the inir package
    environment.systemPackages = [ inirPkg ];
```

**After:**
```nix
    # Install the inir package + runtime dependencies
    environment.systemPackages = [ inirPkg ]
      ++ lib.optionals cfg.installDeps (inirDeps.all ++ inirDeps.optional);
```

**Logic:**
- `inirDeps.all` = all required packages (core, quickshell, audio, screencapture, toolkit, fonts)
- `inirDeps.optional` = materialyoucolor if available (wrapped in tryEval in packages.nix)
- `lib.optionals` returns empty list when `cfg.installDeps = false`
- Advanced users can set `installDeps = false` and manage deps manually

**Verification:** `nix flake check --no-build` passes. Evaluate a NixOS config with `programs.inir.enable = true` and confirm `environment.systemPackages` includes packages from both `all` and `optional` (e.g., `cliphist`, `quickshell`, `pipewire`, etc.).

---

### Task D: Home Manager module — import deps + installDeps option

**File:** `nix/home-module.nix`
**Test:** `nix flake check --no-build` + HM eval (verification)
**Depends:** Task A, Task B

**Three changes:**

1. **Let block (after line 7):** Add `inirDeps` import (same pattern as Task C).

2. **Options section (after line 165):** Add `programs.inir.installDeps` option.

3. **Config section (line 174):** Change `home.packages` line.

**Change 1 — Let block (after line 7: `colorPipeline`):**
```nix
  inirDeps = import ./packages.nix {
    inherit pkgs;
    quickshellPkg = if builtins.hasAttr "quickshell" inputs
      && inputs.quickshell ? packages.${pkgs.system}.default
      then inputs.quickshell.packages.${pkgs.system}.default
      else pkgs.quickshell;
  };
```

**Change 2 — Options (after line 165, before closing `}` of `options.programs.inir`):**
```nix
    installDeps = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to automatically install runtime dependencies for iNiR";
    };
```

**Before (line 173-175):**
```nix
  config = lib.mkIf cfg.enable {
    # Install the inir package
    home.packages = [ inirPkg ];
```

**After:**
```nix
  config = lib.mkIf cfg.enable {
    # Install the inir package + runtime dependencies
    home.packages = [ inirPkg ]
      ++ lib.optionals cfg.installDeps (inirDeps.all ++ inirDeps.optional);
```

**Logic:** Identical to Task C but for `home.packages` instead of `environment.systemPackages`. The `inirDeps` import uses the same resolution logic.

**Verification:** `nix flake check --no-build` passes. Evaluate a HM config with `programs.inir.enable = true` and confirm `home.packages` includes dep packages.

---

## Complete Verification

After all tasks are implemented:

| # | Command | Expected |
|---|---------|----------|
| 1 | `nix flake check --no-build` | Clean pass (no errors) |
| 2 | `nix build '.#packages.x86_64-linux.inir'` | Build succeeds with QS from flake |
| 3 | `nix eval '.#nixosConfigurations.example.config.environment.systemPackages' --apply 'x: builtins.length x'` | Package count > 1 (includes deps) |
| 4 | `nix eval '.#nixosConfigurations.example.config.programs.inir.installDeps'` | `true` |

---

## Rollback Plan

If any task breaks the flake:

1. Revert each file independently (each task touches a single file)
2. Run `nix flake check --no-build` after each revert
3. If My-NixOS breaks, simply remove the two added package names from `home.packages`

---

## Commit Strategy

Each task is a single commit with a descriptive message:

| Task | Commit Message |
|------|---------------|
| A | `feat(flake): add quickshell input from outfoxxed/quickshell` |
| B | `refactor(packages): parameterize quickshellPkg with fallback to pkgs.quickshell` |
| C | `feat(nixos): add installDeps option with auto-installed runtime deps` |
| D | `feat(home-manager): add installDeps option with auto-installed runtime deps` |
| E | `chore(home): add chromium and onlyoffice-bin to user packages` |
