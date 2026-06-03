{ lib, config, pkgs, inputs ? { }, ... }:
let
  cfg = config.programs.inir;
  inirPkg = pkgs.callPackage ./package.nix { };
  niriConfigGen = pkgs.callPackage ./niri-config.nix { };
  inirConfigGen = pkgs.callPackage ./inir-config.nix { };
  colorPipeline = import ./color-pipeline.nix { inherit lib inputs; };

  # Home directory reference (needed for xdg.configFile)
  homeDir = config.home.homeDirectory;

  # Generate a KDL config file for niri from the options tree
  generatedNiriConfig = niriConfigGen.generate (lib.filterAttrsRecursive (n: _: n != "_module" && n != "_type") cfg.niri);

  # Generate the inir config.json
  generatedInirConfig = inirConfigGen.generate cfg;

  # Resolve color palette
  palette = colorPipeline.palette { inherit (cfg) colorScheme colorSchemeModule; };
in {
  meta.maintainers = [ ];

  options.programs.inir = {
    enable = lib.mkEnableOption "iNiR desktop shell (Home Manager)";

    # Color scheme
    colorScheme = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "tokyo-night";
      description = "Name of a nix-colors color scheme to use";
    };

    colorSchemeModule = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "A nix-colors colorScheme attrset (e.g., colorSchemes.dracula) — takes priority over colorScheme name";
    };

    # Panel configuration
    panelFamily = lib.mkOption {
      type = lib.types.enum [ "ii" "waffle" ];
      default = "ii";
      description = "Panel family: ii (Material Design) or waffle (Windows 11)";
    };

    style = lib.mkOption {
      type = lib.types.enum [ "material" "cards" "aurora" "inir" "angel" ];
      default = "material";
      description = "Visual style for the ii panel family";
    };

    # App preferences
    terminal = lib.mkOption {
      type = lib.types.str;
      default = "alacritty";
      example = "foot";
      description = "Default terminal emulator";
    };

    launcher = lib.mkOption {
      type = lib.types.str;
      default = "fuzzel";
      example = "rofi";
      description = "Application launcher";
    };

    browser = lib.mkOption {
      type = lib.types.str;
      default = "firefox";
      example = "chromium";
      description = "Default web browser";
    };

    fileManager = lib.mkOption {
      type = lib.types.str;
      default = "nautilus";
      example = "dolphin";
      description = "Default file manager";
    };

    # Niri config options (converted to KDL)
    niri = {
      prefer-no-csd = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Prefer client-side decorations";
      };

      layout = {
        gaps = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Window gaps in pixels";
        };

        focus-ring = {
          width = lib.mkOption {
            type = lib.types.number;
            default = 1.5;
            description = "Focus ring width";
          };
          active-color = lib.mkOption {
            type = lib.types.str;
            default = "#7fc8ff";
            description = "Focus ring active color (hex)";
          };
        };
      };

      binds = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            action = lib.mkOption {
              type = lib.types.str;
              description = "Action to perform (spawn, close-window, etc.)";
            };
            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Arguments to the action";
            };
          };
        });
        default = { };
        example = lib.literalExpression ''
          {
            "Mod+Return" = { action = "spawn"; args = [ "alacritty" ]; };
            "Mod+D" = { action = "spawn"; args = [ "fuzzel" ]; };
          }
        '';
        description = "Niri keybindings";
      };

      windowRules = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Niri window rules";
      };
    };

    # Extra window rules (syntactic sugar for the HM module)
    windowRules = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Niri window rules (convenience, merged into niri config)";
    };

    # Wallpaper
    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to a wallpaper image. null = use bundled default";
    };

    wallpaperDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Directory for wallpaper rotation";
    };
  };

  # Niri-flake HM module (conditional on inputs availability — top-level, not inside config)
  imports = lib.optionals (builtins.hasAttr "niri-flake" inputs) [
    inputs.niri-flake.homeManagerModules.niri
  ];

  config = lib.mkIf cfg.enable {
    # Install the inir package
    home.packages = [ inirPkg ];

    # Home Manager config files (single merge to avoid infinite recursion)
    xdg.configFile = lib.mkMerge [
      {
        # Generate niri config.kdl
        "niri/config.kdl" = {
          text = generatedNiriConfig;
          onChange = lib.mkIf (config.programs.niri.enable or false) "niri msg quit 2>/dev/null || true";
        };

        # Generate inir config.json
        "inir/config.json" = {
          text = generatedInirConfig;
        };

        # Wallpaper
        "inir/wallpaper" = lib.mkIf (cfg.wallpaper != null) {
          source = cfg.wallpaper;
        };
      }

      # App dotfiles (only when palette is available via nix-colors)
      (lib.mkIf (palette != null) {
        "alacritty/alacritty.toml".text = builtins.readFile ./dotfiles/alacritty.toml;
        "foot/foot.ini".text = builtins.readFile ./dotfiles/foot.ini;
        "fuzzel/fuzzel.ini".text = builtins.readFile ./dotfiles/fuzzel.ini;
        "kitty/kitty.conf".text = builtins.readFile ./dotfiles/kitty.conf;
        "gtk-3.0/settings.ini".text = builtins.readFile ./dotfiles/gtk3-settings.ini;
        "gtk-4.0/settings.ini".text = builtins.readFile ./dotfiles/gtk4-settings.ini;
      })
    ];

    # Autostart inir as a niri spawn-at-startup entry
    # This is injected into the niri config via the KDL generator
    programs.niri = lib.mkIf (builtins.hasAttr "niri" config.programs) {
      extraConfig = ''
        spawn-at-startup "${inirPkg}/bin/inir" run --session
      '';
    };
  };
}
