{ lib, inputs ? { } }:
let
  inherit (lib) types hasAttr;
in rec {
  # Static mode: use nix-colors to produce palette at build time
  staticPalette = colorScheme: let
    # Import nix-colors scheme by name or use direct nix-colors scheme
    scheme = if builtins.isAttrs colorScheme then colorScheme
             else inputs.nix-colors.colorSchemes.${colorScheme};
  in rec {
    primary = "#${scheme.colors.base09}";    # Orange/Amber
    secondary = "#${scheme.colors.base0C}";  # Cyan
    tertiary = "#${scheme.colors.base0B}";   # Green
    error = "#${scheme.colors.base08}";      # Red
    surface = "#${scheme.colors.base00}";    # Dark bg
    surfaceContainerLow = "#${scheme.colors.base01}";
    surfaceContainer = "#${scheme.colors.base02}";
    surfaceContainerHigh = "#${scheme.colors.base03}";
    onSurface = "#${scheme.colors.base05}";
    onSurfaceVariant = "#${scheme.colors.base04}";
    outline = "#${scheme.colors.base04}";
    accent = primary;
  };

  # Dynamic mode: use Material You at runtime (Python pipeline)
  # This is the default when no nix-colors scheme is specified
  dynamicMode = {
    inherit (inputs) nix-colors;
    enable = true;
    pythonPackages = ps: with ps; [ pillow ];
    scriptPath = "/run/current-system/sw/share/inir/material-you/generate_colors_material.py";
  };

  # Produce a merged palette usable by all config generators
  palette = { colorScheme, colorSchemeModule }: 
    if colorSchemeModule != null then
      staticPalette colorSchemeModule
    else if colorScheme != null then
      staticPalette colorScheme
    else
      null; # No static palette — will use dynamic mode at runtime

  # Check if using nix-colors
  usingNixColors = opts: opts.colorSchemeModule != null || opts.colorScheme != null;
}
