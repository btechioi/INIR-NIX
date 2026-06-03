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
    quickshell.url = "github:outfoxxed/quickshell";
  };

  outputs = { self, nixpkgs, niri-flake, nix-colors, home-manager, quickshell }@inputs: let
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

    formatter = forAllSystems (system: (mkPkgs system).nixpkgs-fmt);

    devShells = forAllSystems (system: {
      default = (mkPkgs system).mkShell {
        packages = with (mkPkgs system); [ nixpkgs-fmt statix deadnix ];
        shellHook = ''
          echo " iNiR dev shell"
          echo "  nixpkgs-fmt  — Nix formatter"
          echo "  statix       — Nix linter"
          echo "  deadnix      — Nix dead code analyzer"
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
