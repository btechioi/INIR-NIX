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
  # Also appends spawn-at-startup for inir (avoids depending on HM niri module)
  generatedNiriConfig = niriConfigGen.generate (lib.filterAttrsRecursive (n: _: n != "_module" && n != "_type") cfg.niri)
    + lib.optionalString cfg.enable ''
      spawn-at-startup "${inirPkg}/bin/inir" run --session
    '';

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

  # Niri-flake HM module (conditional on inputs AND output availability)
  imports = lib.optionals (builtins.hasAttr "niri-flake" inputs && builtins.hasAttr "homeManagerModules" inputs.niri-flake) [
    inputs.niri-flake.homeManagerModules.niri
  ];

  config = lib.mkIf cfg.enable {
    # Install the inir package
    home.packages = [ inirPkg ];

    # Runtime QML payload symlink — makes the shell runtime available
    # at the path Quickshell expects (~/.config/quickshell/inir)
    home.file = {
      ".config/quickshell/inir" = {
        source = "${inirPkg}/share/quickshell/inir";
      };
      # Dolphin panel layout state (installed to XDG_STATE_HOME per upstream)
      ".local/state/dolphinstaterc".source = ./../defaults/kde/dolphinstaterc;
    };

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

      # Source-based dotfiles from dots/.config/ and defaults/ (always deployed)
      # These are the config files the upstream `./setup install` copies.
      # Palette-based templates (above) override these when nix-colors is available.
      {
        "fish/config.fish".source = ./../dots/.config/fish/config.fish;
        "fish/auto-Niri.fish".source = ./../dots/.config/fish/auto-Niri.fish;
        "mpv/mpv.conf".source = ./../dots/.config/mpv/mpv.conf;
        "Kvantum/kvantum.kvconfig".source = ./../dots/.config/Kvantum/kvantum.kvconfig;
        "fontconfig/fonts.conf".source = ./../dots/.config/fontconfig/fonts.conf;
        "chrome-flags.conf".source = ./../dots/.config/chrome-flags.conf;
        "code-flags.conf".source = ./../dots/.config/code-flags.conf;
        "vesktop/themes".source = ./../dots/.config/vesktop/themes;
        "matugen".source = ./../dots/.config/matugen;
        "xdg-desktop-portal/niri-portals.conf".source = ./../dots/.config/xdg-desktop-portal/niri-portals.conf;
        "kdeglobals".source = ./../defaults/kde/kdeglobals;
        "dolphinrc".source = ./../defaults/kde/dolphinrc;
        "kservicemenurc".source = ./../defaults/kde/kservicemenurc;
        "starship.toml".source = ./../defaults/starship/starship.toml;
        "fuzzel/fuzzel.ini".source = ./../defaults/fuzzel/fuzzel.ini;
        "gtk-3.0/settings.ini".source = ./../defaults/gtk-3.0/settings.ini;
        "gtk-4.0/settings.ini".source = ./../defaults/gtk-4.0/settings.ini;
        "darklyrc".source = ./../dots/.config/darklyrc;
        "konsolerc".source = ./../dots/.config/konsolerc;
        # AI chat prompts for the sidebar AI feature
        "illogical-impulse/ai".source = ./../defaults/ai;
      }
    ];

    # State initialization: create dirs and files the shell expects at startup
    home.activation = {
      # Create state directories for generated content
      createStateDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p "${config.xdg.stateHome}/quickshell/user/generated/wallpaper" || true
        mkdir -p "${config.xdg.stateHome}/quickshell/user/generated/terminal" || true
      '';
      # Initialize empty state files
      createStateFiles = lib.hm.dag.entryAfter ["createStateDirs"] ''
        touch "${config.xdg.stateHome}/quickshell/user/generated/gamemode_active" || true
        touch "${config.xdg.stateHome}/quickshell/user/generated/notepad.txt" || true
        echo '[]' > "${config.xdg.stateHome}/quickshell/user/generated/todo.json" || true
        echo '[]' > "${config.xdg.stateHome}/quickshell/user/generated/notifications.json" || true
      '';
      # Deploy bundled wallpapers to ~/Pictures/Wallpapers/inir/
      # Only copies if target dir is empty (avoids overwriting user's collection)
      deployWallpapers = lib.hm.dag.entryAfter ["createStateFiles"] ''
        mkdir -p "${config.home.homeDirectory}/Pictures/Wallpapers/inir"
        if [ -z "$(ls -A "${config.home.homeDirectory}/Pictures/Wallpapers/inir" 2>/dev/null)" ]; then
          cp -a "${inirPkg}/share/inir/wallpapers/." "${config.home.homeDirectory}/Pictures/Wallpapers/inir/" || true
        fi
      '';
    };

    # Session environment variable for the Python venv path
    home.sessionVariables = {
      ILLOGICAL_IMPULSE_VIRTUAL_ENV = "${config.xdg.stateHome}/quickshell/.venv";
    };

    # Note: spawn-at-startup for inir is appended directly to the generated
    # niri config KDL above, avoiding a dependency on the HM niri module.
  };
}
