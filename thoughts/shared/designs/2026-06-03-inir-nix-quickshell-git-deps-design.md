---
date: 2026-06-03
topic: "Quickshell from git flake + auto-install runtime deps"
status: validated
---

## Problem Statement

Two issues make INIR-NIX not "install and go":

1. **Quickshell version pinned to nixpkgs stable** — nixpkgs has `quickshell` v0.3.0 tagged release, but INIR's QML code may depend on features from the latest git. The upstream `quickshell-git` pattern (used on Arch) should be replicated via the outfoxxed/quickshell flake.

2. **Runtime deps not auto-installed** — `nix/packages.nix` defines ~40+ dependency packages across 7 categories, but neither the NixOS module nor the HM module installs them. Users must manually copy-paste these lists. Enabling `programs.inir.enable = true` should install everything needed.

## Constraints

- Must fall back gracefully if quickshell flake input is missing
- Must not break existing users who override packages manually
- autoInstallDeps must be toggleable (default: true) so advanced users can opt out
- Must pass `nix flake check` cleanly

## Approach

### Chosen: quickshell flake input + installDeps option

Three independent changes:

1. **Add `quickshell` flake input** — `github:outfoxxed/quickshell`, same pattern as `niri-flake`
2. **Parameterize `packages.nix`** — accept `quickshellPkg` arg, default to `pkgs.quickshell`
3. **Both modules import deps** — new `installDeps` option, adds `inirDeps.all` + `inirDeps.optional` to `environment.systemPackages` / `home.packages`

## Architecture

### flake.nix

Add input:
```nix
quickshell.url = "github:outfoxxed/quickshell";
```

The quickshell package is resolved inside each module based on input availability:
- If `inputs.quickshell` exists → `inputs.quickshell.packages.${system}.default`
- Otherwise → `pkgs.quickshell` (nixpkgs fallback)

### nix/packages.nix

Change signature:
```nix
{ pkgs, quickshellPkg ? pkgs.quickshell }:
```

Replace `pkgs.quickshell` in the `quickshell` category list with `quickshellPkg`.

Everything else stays the same.

### nix/nixos-module.nix

Add to let block:
```nix
inirDeps = import ./packages.nix {
  inherit pkgs;
  quickshellPkg = if inputs.quickshell ? packages.${pkgs.system}.default then
    inputs.quickshell.packages.${pkgs.system}.default
  else pkgs.quickshell;
};
```

Add option:
```nix
installDeps = lib.mkOption {
  type = lib.types.bool;
  default = true;
  description = "Whether to automatically install runtime dependencies";
};
```

Add to config:
```nix
environment.systemPackages = [ inirPkg ]
  ++ lib.optionals cfg.installDeps (inirDeps.all ++ inirDeps.optional);
```

### nix/home-module.nix

Same pattern but for `home.packages`:
```nix
home.packages = [ inirPkg ]
  ++ lib.optionals cfg.installDeps (inirDeps.all ++ inirDeps.optional);
```

Note: `inirDeps.optional` includes materialyoucolor — attempted via tryEval so it won't fail if unavailable in nixpkgs.

## Data Flow

```
User sets programs.inir.enable = true
  → Module detects quickshell flake availability
  → Imports packages.nix with correct quickshellPkg
  → If installDeps = true: adds all deps to system/user packages
  → The shell + all Qt/Wayland deps are installed in one shot
```

## Error Handling

| Failure | Behavior |
|---------|----------|
| quickshell flake not in inputs | Falls back to `pkgs.quickshell` silently |
| materialyoucolor missing in nixpkgs | tryEval catches it, not included |
| User sets installDeps = false | No deps auto-added, user manages manually |

## Testing Strategy

- `nix flake check` must pass
- Build `.#packages.x86_64-linux.inir` with quickshell from flake
- Verify NixOS eval: `programs.inir.installDeps` → deps in `environment.systemPackages`

## My-NixOS: Additional User Packages

Separate from INIR-NIX — the My-NixOS user config needs:

**home.nix** additions to `home.packages`:
- `chromium` — web browser
- `onlyoffice-bin` (or `onlyoffice`) — office suite

These are already present in system packages (zed-editor, gh) or home.packages (git).

## Open Questions

None.

## Files Changed

| File | Change |
|------|--------|
| `flake.nix` | Add `quickshell` input |
| `nix/packages.nix` | Accept `quickshellPkg` parameter |
| `nix/nixos-module.nix` | Import deps, add `installDeps` option + config |
| `nix/home-module.nix` | Import deps, add `installDeps` option + config |
| `.../My-NixOS/standard/home-manager/home.nix` | Add chromium, onlyoffice to home.packages |
