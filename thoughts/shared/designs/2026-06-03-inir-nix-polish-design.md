---
date: 2026-06-03
topic: "INIR-NIX Flake Polish — devShell, fixes, user experience"
status: validated
---

## Problem Statement

The INIR-NIX flake (NixOS module + HM module + package) is functional and passes `nix flake check`, but has several rough edges:

- **No development shell** — developers working on the flake have to manually install `nixpkgs-fmt`, `statix`, etc.
- **No formatter** — `nix fmt` doesn't work because there's no `formatter` output
- **Broken optional dependency detection** — `packages.nix` uses a `tryEval` pattern that always evaluates to `true`, so `materialyoucolor` is never conditionally excluded
- **XDG portal eval warning** — xdg-desktop-portal 1.17+ requires `config.common.default` to be set
- **Misleading palette conditional** — the HM module deploys "palette-based" dotfiles that are actually static files with no palette interpolation

The goal is to make this flake **easy to develop** (dev tooling) and **user-friendly to install** (no warnings, no broken conditionals).

## Constraints

- Must continue to pass `nix flake check`
- Must not change the external API (module options, package structure)
- Must work with the existing nixpkgs revision (nixos-unstable)
- Minimal changes — polish, not rewrite

## Approach

### Chosen: Targeted Fixes + Dev Tooling (all 4 items in parallel)

Each change is independent and self-contained. No risky refactoring.

**Alternatives considered:**
- **Rewrite color-pipeline** — not needed, the dynamic/runtime path works fine
- **Parameterize the dotfiles with palette** — would require template substitution engine, overkill for static theme-friendly defaults
- **Add nix-colors as required dependency** — would break the "no nix-colors" use case

## Architecture

The changes are spread across 4 files with no cross-cutting concerns:

| File | Change | Category |
|------|--------|----------|
| `flake.nix` | Add `formatter` + `devShells` outputs | Dev experience |
| `nix/packages.nix` | Fix `tryEval` detection of materialyoucolor | Correctness |
| `nix/nixos-module.nix` | Add `xdg.portal.config.common.default` | User experience |
| `nix/home-module.nix` | Clarify palette-conditional dotfile comment | Maintainability |

## Components

### 1. formatter + devShell (flake.nix)

Add two new flake outputs:

- **formatter**: `nixpkgs-fmt` — enables `nix fmt` to format all Nix files
- **devShells.default**: `mkShell` with `nixpkgs-fmt`, `statix`, `deadnix` + helpful shellHook banner

These are standard Nix flake patterns. No special logic needed.

### 2. packages.nix — optional detection fix

**Current (broken):**
```nix
optional = with pkgs; lib.optionals
  (builtins.tryEval (builtins.hasAttr "materialyoucolor" python3Packages)).success
  [ python3Packages.materialyoucolor ];
```

`hasAttr` never fails — it returns `false` if the attr is missing. `tryEval` wraps that in `{ success = true; value = false; }`. So `.success` is always `true` and the package list is always included, even if materialyoucolor doesn't exist.

**Fix:** Evaluate the attribute access directly inside `tryEval`:
```nix
optional = with pkgs; let
  matugen = builtins.tryEval python3Packages.materialyoucolor;
in lib.optionals (matugen.success && matugen.value != null) [
  python3Packages.materialyoucolor
];
```

If `materialyoucolor` is missing, `tryEval` returns `{ success = false; ... }`. If present and null, it returns `{ success = true; value = null; }`. The guard `matugen.success && matugen.value != null` handles both failure modes.

### 3. XDG portal config (nixos-module.nix)

**Current:**
```nix
xdg.portal = lib.mkIf cfg.portals.enable {
  enable = true;
  extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  configPackages = lib.mkForce [ ];
};
```

**Fix:** Add `config.common.default = "*"` inside the portal block. This tells xdg-desktop-portal to use the first available portal backend by default — same behavior as pre-1.17 but without the eval warning.

### 4. Palette conditional comment (home-module.nix)

The `lib.mkIf (palette != null)` block deploys static template files from `nix/dotfiles/` when a nix-colors scheme is specified. These files are not palette-interpolated — they provide theme-optimized defaults that look good with any Material You palette.

The fix is just better documentation so future developers understand why the conditional exists and what the files actually do.

## Data Flow

No data flow changes. All 4 fixes are local to their respective files.

## Error Handling

- **packages.nix**: `tryEval` already catches eval errors; the fix just makes the guard logic correct
- **flake.nix**: devShells/formatter are standard outputs — no error path beyond nixpkgs availability
- **nixos-module.nix**: `config.common.default` is optional and has no error state
- **home-module.nix**: comment-only change

## Testing Strategy

- Run `nix flake check` — must pass clean (no eval warnings for portal section)
- Run `nix develop` — must enter shell with `nixpkgs-fmt` available
- Run `nix fmt` — must format files with `nixpkgs-fmt`
- Build `.#packages.x86_64-linux.inir` — must succeed (verifies packages.nix change doesn't break)
- Verify `builtins.tryEval` logic manually: `nix eval --expr 'builtins.tryEval builtins.currentSystem'` should confirm the pattern works

## Open Questions

None — all 4 changes are well-understood standard Nix patterns.
