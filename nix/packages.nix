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
  optional = with pkgs; let
    matugen = builtins.tryEval python3Packages.materialyoucolor;
  in lib.optionals (matugen.success && matugen.value != null) [
    python3Packages.materialyoucolor
  ];
}
