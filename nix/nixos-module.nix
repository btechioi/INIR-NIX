{ lib, config, pkgs, inputs ? { }, ... }:
let
  cfg = config.programs.inir;
  inirPkg = pkgs.callPackage ./package.nix { };
  hasNiriFlake = builtins.hasAttr "niri-flake" inputs;
in {
  meta.maintainers = [ ];

  # Niri compositor via niri-flake (conditional on inputs availability)
  imports = lib.optionals hasNiriFlake [
    inputs.niri-flake.nixosModules.niri
  ];

  options.programs.inir = {
    enable = lib.mkEnableOption "iNiR desktop shell";

    niri = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable the Niri compositor via niri-flake";
      };
    };

    graphics = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable hardware graphics acceleration";
      };
      enable32Bit = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable 32-bit graphics support";
      };
    };

    nvidia = {
      enable = lib.mkEnableOption "NVIDIA GPU support";
      open = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to use the open-source NVIDIA kernel module";
      };
      modesetting = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable NVIDIA modesetting";
        };
      };
    };

    pipewire = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable PipeWire audio";
      };
    };

    portals = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to configure XDG Desktop Portals for Wayland";
      };
    };

    useCache = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to add niri.cachix.org binary cache";
    };
  };

  config = lib.mkIf cfg.enable {
    # Assert that niri-flake is available if niri is enabled
    assertions = [{
      assertion = !cfg.niri.enable || (builtins.hasAttr "niri-flake" inputs);
      message = ''
        niri-flake is required when programs.inir.niri.enable = true.
        Add `niri.url = "github:sodiboo/niri-flake"` to your flake inputs.
      '';
    }];

    # Install the inir package
    environment.systemPackages = [ inirPkg ];

    # Graphics
    hardware.graphics = lib.mkIf cfg.graphics.enable {
      enable = true;
      enable32Bit = cfg.graphics.enable32Bit;
    };

    # NVIDIA
    hardware.nvidia = lib.mkIf cfg.nvidia.enable {
      open = cfg.nvidia.open;
      modesetting.enable = cfg.nvidia.modesetting.enable;
    };

    # PipeWire audio
    security.rtkit.enable = lib.mkIf cfg.pipewire.enable true;
    services.pipewire = lib.mkIf cfg.pipewire.enable {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # XDG Desktop Portals
    xdg.portal = lib.mkIf cfg.portals.enable {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      # Explicitly avoid gnome portal
      configPackages = lib.mkForce [ ];
    };

    # Binary cache (Cachix for niri)
    nix.settings = lib.mkIf cfg.useCache {
      substituters = [ "https://niri.cachix.org" ];
      trusted-public-keys = [ "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=" ];
    };

    # Niri user service for inir (systemd)
    systemd.user.services.inir = lib.mkIf (cfg.niri.enable) {
      description = "iNiR shell";
      after = [ "graphical-session.target" ];
      wantedBy = [ "niri.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${inirPkg}/bin/inir run --session";
        Restart = "on-failure";
        RestartSec = "5";
        TimeoutStopSec = "15";
      };
    };
  };
}
