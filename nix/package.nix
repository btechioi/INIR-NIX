{ lib, stdenv, buildGoModule, installShellFiles }:
let
  goPackage = buildGoModule rec {
    pname = "inir-go-tools";
    version = "2.25.2";
    src = ./..;
    subPackages = [ "scripts/colors/zed_themegen" ];
    vendorHash = null;
    doCheck = false;
    postInstall = ''
      mv $out/bin/zed_themegen $out/bin/inir-zed-themegen
    '';
  };
in
stdenv.mkDerivation rec {
  pname = "inir";
  version = "2.25.2";
  src = ./..;

  nativeBuildInputs = [ installShellFiles ];
  buildInputs = [ ];

  dontBuild = true;
  dontConfigure = true;
  dontPatchShebangs = true;

  installPhase = ''
    # 1. Install the main launcher binary
    install -Dm755 scripts/inir $out/bin/inir

    # 2. Install the Go-built tools
    install -Dm755 ${goPackage}/bin/inir-zed-themegen $out/bin/inir-zed-themegen

    # 3. Install QML shell files to share/quickshell/inir/
    shellDir=$out/share/quickshell/inir
    mkdir -p $shellDir

    # Root QML files
    for f in *.qml; do
      install -Dm644 "$f" "$shellDir/$f"
    done

    # Root files listed in runtime-root-files.txt
    for f in setup VERSION CHANGELOG.md go.mod; do
      if [ -f "$f" ]; then
        install -Dm644 "$f" "$shellDir/$f"
      fi
    done
    chmod +x "$shellDir/setup" 2>/dev/null || true

    # Runtime payload directories (from sdata/runtime-payload-dirs.txt)
    for dir in modules services scripts assets translations defaults dots sdata; do
      if [ -d "$dir" ]; then
        mkdir -p "$shellDir/$dir"
        cp -a "$dir"/. "$shellDir/$dir/"
      fi
    done

    # Make scripts executable
    find $shellDir/scripts -type f \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) -exec chmod +x {} + 2>/dev/null || true

    # 4. Install desktop entries
    install -Dm644 assets/applications/inir.desktop \
      $out/share/applications/inir.desktop
    install -Dm644 assets/applications/inir-settings.desktop \
      $out/share/applications/inir-settings.desktop

    # 5. Install icons
    install -Dm644 assets/icons/desktop-symbolic.svg \
      $out/share/icons/hicolor/scalable/apps/inir.svg

    # 6. Install systemd service template (with store path substituted)
    mkdir -p $out/lib/systemd/user
    sed "s|/usr/bin/inir|$out/bin/inir|g" \
      assets/systemd/inir.service > $out/lib/systemd/user/inir.service
    chmod 644 $out/lib/systemd/user/inir.service

    # 7. Create version.json metadata
    cat > $shellDir/version.json << VJSON
    {
      "version": "${version}",
      "commit": "nixos-flake",
      "installed_at": "$(date -Iseconds)",
      "source": "nixos-flake",
      "install_mode": "nixos-package",
      "update_strategy": "nixos-rebuild"
    }
    VJSON

    # 8. Install wallpapers
    if [ -d assets/wallpapers ]; then
      mkdir -p $out/share/inir/wallpapers
      cp -a assets/wallpapers/. $out/share/inir/wallpapers/
    fi

    # 9. Install defaults as reference
    mkdir -p $out/share/inir/defaults
    cp -a defaults/. $out/share/inir/defaults/

    # 10. Install dotfile references
    mkdir -p $out/share/inir/dotfiles
    cp -a dots/. $out/share/inir/dotfiles/

    # 11. Install completion scripts
    installShellCompletion --bash scripts/completions/inir.bash 2>/dev/null || true
    installShellCompletion --fish scripts/completions/inir.fish 2>/dev/null || true
    installShellCompletion --zsh scripts/completions/inir.zsh 2>/dev/null || true
  '';

  meta = with lib; {
    description = "A complete desktop shell for Niri, built on Quickshell";
    homepage = "https://github.com/snowarch/inir";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
