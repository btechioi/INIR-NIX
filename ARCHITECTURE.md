# iNiR Architecture

> A complete desktop shell built on [Quickshell](https://quickshell.outfoxxed.me/) for the [Niri](https://github.com/YaLTeR/niri) Wayland compositor.

**Version**: 2.25.2 · **Stack**: QML (Quickshell), Bash, Python, Go

Originally forked from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse). Secondary Hyprland support is maintained.

---

## System Overview

```
your apps
   ↓
iNiR (shell: bar, sidebars, dock, notifications, settings...)
   ↓
Quickshell (runs QML shells)
   ↓
Niri (compositor: windows, rendering)
   ↓
Wayland → GPU
```

**Three-layer architecture**:
1. **Shell Layer** (`modules/` + root QML) — UI components under two panel families
2. **Service Layer** (`services/`) — 70+ singleton QML services providing backend logic
3. **Infrastructure Layer** (`scripts/`, `sdata/`, `defaults/`, `dots/`) — installation, theming, CLI

---

## Entry Point & Startup Flow

`shell.qml` → `ShellRoot` (Quickshell-specific root).

Startup sequence:
1. Environment pragmas configure Qt scale, render loop, memory
2. Tier 1 singletons force-instantiated via dummy `property var _idleService: Idle`
3. `Config.ready` triggers `PanelLoader` activation
4. Tier 2 (T+0ms): core services (Config, InputRemapper, GlobalStates)
5. Tier 3 (T+500ms): display/interaction services (GameMode, WindowPreview, Weather, VoiceSearch, FontSync, CavaTheme)
6. Tier 4 (T+1500ms): background services (ShellUpdates, Autostart, CalendarSync, Todo, Notepad)
7. Theme and icon services applied via `Qt.callLater`

Boot timing tracked in `~/.cache/inir/last-boot.json` for `inir status`.

---

## Panel Families

Two mutually exclusive UI families, switchable at runtime (`Super+Shift+W`):

| Aspect | **Material ii** | **Waffle** |
|---|---|---|
| Active when | `panelFamily !== "waffle"` | `panelFamily === "waffle"` |
| Visual tokens | `Appearance.*` (400+ props) | `Looks.*` (41 tokens) |
| Styles | material, cards, aurora, inir, angel | Single fluent style |
| Bar | Top (or vertical) | Bottom (Win11 taskbar) |
| App launcher | Overview | StartMenu with search |
| Right panel | SidebarRight | ActionCenter + NotificationCenter |
| Modules | 24 panels | 24 panels (shared + waffle-specific) |

Each panel uses `PanelLoader` (LazyLoader wrapper):
```qml
PanelLoader {
    identifier: "iiBar"
    extraCondition: !(Config.options?.bar?.vertical ?? false)
    component: Bar {}
}
```
Loads when ALL conditions: `Config.ready` + identifier in `enabledPanels` + `extraCondition`.

Style dispatch priority: **angel > inir > aurora > material > cards**.

---

## Directory Structure

```
shell.qml                     # Root entry — loads services, selects panel family
ShellIiPanels.qml             # Material Design family (24 panels)
ShellWafflePanels.qml         # Windows 11 family (24 panels)
GlobalStates.qml              # Central UI state (panel open/closed booleans)
FamilyTransitionOverlay.qml   # Animated family switch animation
settings.qml                  # Settings GUI (standalone Quickshell window)
welcome.qml                   # First-run wizard (standalone window)
killDialog.qml                # Process kill confirmation dialog

modules/                      # 30+ UI module directories
├── common/                   # Shared infrastructure (HIGH RISK)
│   ├── Appearance.qml        # ii visual tokens (881 lines, 400+ properties)
│   ├── Config.qml            # Central config system (1385+ lines, JsonAdapter)
│   ├── widgets/              # 129 reusable widgets + qmldir
│   │   ├── RippleButton.qml  # Foundational button for all interactive elements
│   │   ├── ContextMenu.qml   # Model-based context menu
│   │   ├── Revealer.qml      # GTK-style animated show/hide
│   │   └── [125+ more]
│   ├── functions/            # 14 utility modules (ColorUtils, StringUtils, etc.)
│   └── models/               # Data models + quickToggles/
├── bar/                      # Top bar (ii family, 33 files)
├── ii/                       # ii panel family specifics
│   ├── overlay/              # ii panel overlays
│   └── sidebarRight/         # ii right sidebar
├── waffle/                   # Windows 11 family (19 subdirectories)
│   ├── bar/                  # Bottom taskbar
│   ├── startMenu/            # Start menu with search
│   ├── actionCenter/         # Quick settings panel
│   ├── notificationCenter/   # Notification list + calendar
│   ├── looks/Looks.qml       # Waffle visual tokens
│   └── [14 more subdirs]
├── sidebarLeft/              # Left sidebar (AI chat, YT Music, widgets)
├── sidebarRight/             # Right sidebar (toggles, calendar, tools)
├── settings/                 # All config UI pages
├── dock/                     # App dock (all 4 positions)
├── overview/                 # Workspace overview + app search
├── lock/                     # Lock screen + PAM config
├── clipboard/                # Clipboard manager with history
├── notificationPopup/        # Notification popup toasts
├── onScreenDisplay/          # Volume/brightness OSD
├── cheatsheet/               # Keybind viewer
├── controlPanel/             # Quick settings panel
├── mediaControls/            # MPRIS media player controls
├── screenCorners/            # Hot corner triggers
├── regionSelector/           # Screenshot/OCR region selector
├── sessionScreen/            # Logout/reboot/shutdown screen
├── polkit/                   # PolicyKit authentication agent
├── wallpaperSelector/        # Wallpaper picker UI
├── altSwitcher/              # Alt+Tab window switcher
├── bootGreeting/             # Boot/splash greeting
├── closeConfirm/             # Close confirmation dialog
├── shellUpdate/              # Shell update notification
├── tilingOverlay/            # Window tiling overlay
├── verticalBar/              # Vertical bar variant
├── onScreenKeyboard/         # On-screen keyboard
└── recordingOsd/             # Screen recording indicator

services/                     # 70+ runtime singletons
├── qmldir                    # Service module registration (56 singletons + 3 types)
├── deferred/                 # Lazy-loaded services (18 total)
│   ├── qmldir                # Sub-module qs.services.deferred
│   ├── Cliphist.qml          # Clipboard history
│   ├── SongRec.qml           # Music recognition
│   ├── EasyEffects.qml       # PipeWire effects
│   └── [15 more]
├── NiriService.qml           # Niri compositor IPC (1376 lines)
├── Audio.qml                 # PipeWire volume, mute, per-app mixer
├── Notifications.qml         # Notification system with persistence
├── CompositorService.qml     # Compositor detection + abstraction
├── DankSocket.qml            # Reusable Unix socket wrapper
├── GlobalActions.qml         # System actions (screenshot, record, etc.)
├── ThemeService.qml          # Theme application orchestration
├── MaterialThemeLoader.qml   # Watches colors.json, triggers regeneration
├── Weather.qml               # Open-Meteo polling + GPS/city config
├── Network.qml               # NetworkManager integration
├── Battery.qml               # UPower battery + charge limits
├── Translation.qml           # i18n lookup (15 languages)
├── Events.qml                # Calendar events with file persistence
├── GameMode.qml              # Fullscreen app detection + effects suppression
├── [50+ more]
└── ai/                       # AI service strategies
    ├── ApiStrategy.qml       # Abstract strategy interface
    ├── GeminiApiStrategy.qml # Google Gemini implementation
    ├── MistralApiStrategy.qml# Mistral AI implementation
    └── [2 more]

scripts/                      # Shell/fish/python/go helpers
├── inir                      # CLI launcher (30KB bash, 40+ commands)
├── colors/                   # Material You theming pipeline
│   ├── switchwall.sh         # Primary entry: wallpaper → color generation
│   ├── applycolor.sh         # Orchestrator: runs enabled theming modules
│   ├── generate_colors_material.py  # Material You color science (1231 lines)
│   ├── modules/              # Per-app theming scripts (10-terminal, 20-gtk-kde, etc.)
│   ├── targets/              # JSON manifests mapping config keys → module scripts
│   └── lib/                  # Shared runtime (module-runtime.sh, etc.)
├── daemon/                   # Background daemons
├── lib/                      # Shared bash libraries (config-path.sh, ipc-registry.sh)
├── systemd/                  # Systemd service definitions
├── ai/                       # AI integration scripts
├── kvantum/                  # Kvantum theme scripts
├── images/                   # Image processing
├── sddm/                     # SDDM theme sync
└── [20+ more subdirectories]

sdata/                        # Install/update lifecycle
├── lib/                      # Shared bash libraries (functions.sh, doctor.sh, etc.)
├── migrations/               # Numbered upgrade scripts (001–020+)
├── subcmd-install/           # Install phases
├── subcmd-uninstall/         # Uninstall phases
├── dist-arch/                # Arch PKGBUILD subpackages
├── dist-debian/              # Debian packaging
├── dist-fedora/              # Fedora packaging
└── dist-generic/             # Universal install data

defaults/                     # Shipped default configurations
├── config.json               # Shell config (1100+ lines, 51 sections)
├── app-catalog.json          # Known application catalog
├── niri/                     # Niri compositor config templates
├── widgets/                  # Default widget definitions
├── plugins/                  # Plugin manifests (music, discord)
├── matugen/                  # Material You template configs
├── gtk-{3,4}.0/             # GTK settings
├── fuzzel/                   # Fuzzel launcher default
├── starship/                 # Starship prompt default
└── kde/                      # KDE/Qt defaults

dots/                         # Dotfiles deployed to $HOME
├── .config/                  # User configs (gtk, kitty, mpv, niri, vesktop, etc.)
└── sddm/                     # SDDM login theme

translations/                 # i18n strings (15 languages: en, ar, de, es, fr, he, hi, it, ja, ko, pt, ru, uk, vi, zh)
assets/                       # Static assets
├── icons/                    # Application icons
├── wallpapers/               # 15 bundled wallpapers
├── systemd/                  # Systemd unit files
└── applications/             # .desktop launcher files

docs/                         # User documentation (31 files)
patches/                      # Quickshell patches
distro/arch/                  # Arch Linux PKGBUILDs (inir-shell, inir-shell-git, inir-meta)
```

---

## Service Layer Architecture

### Registration Pattern

All services are registered via `services/qmldir` as a Quickshell module (`qs.services`):

```qml
// services/qmldir
module qs.services
singleton Audio 1.0 Audio.qml
singleton NiriService 1.0 NiriService.qml
DankSocket 1.0 DankSocket.qml        // Non-singleton (manually instantiated)
```

- **56 singletons** (auto-instantiated on first `import qs.services`)
- **3 non-singleton types** (DankSocket, BooruResponseData, PolkitServiceImpl, HyprlandData)
- **18 deferred singletons** under `qs.services.deferred` (lazy-loaded by panel consumers)

### IPC Communication Mechanisms

| Mechanism | Direction | Purpose | Example |
|---|---|---|---|
| Unix Socket (DankSocket) | bidirectional | Niri compositor events + commands | `NiriService.qml` — workspace/window events |
| IpcHandler (Quickshell) | external → shell | CLI-to-service calls | `inir audio volumeUp` |
| Process (subprocess) | shell → external | CLI tool execution | `niri msg`, `wpctl`, `notify-send` |
| FileView (FileView) | persistent | Disk-backed state | Notifications, Events |

#### 1. Unix Socket IPC (Niri)

`services/DankSocket.qml` — reusable socket wrapper with:
- Line-delimited JSON parsing via `SplitParser`
- Exponential backoff reconnection (base^min(attempt,10) + jitter)
- Separate event stream + request sockets

Event dispatch in `NiriService.qml` handles 14+ event types (`WorkspacesChanged`, `WindowFocusChanged`, `WindowsChanged`, `ConfigLoaded`, `KeyboardLayoutSwitched`, etc.)

#### 2. IpcHandler (Quickshell Framework)

```qml
IpcHandler {
    target: "audio"
    function volumeUp(): void { /* ... */ }
    function getVolume(): string { return String(value) }
}
```
Called externally: `inir audio volumeUp` — all functions must declare return types.

#### 3. Process-based IPC

Patterns used:
- **Fire-and-forget**: `Quickshell.execDetached(["notify-send", ...])`
- **Capture stdout**: `Process { command: ["niri", "msg", "-j", "outputs"] }` + `StdioCollector`
- **Sequential chaining**: `onExited` → next command

### Data Flow: Service → UI

```qml
// 1. Reactive properties
readonly property bool isLow: percentage < lowThreshold && !isCharging

// 2. Signals for transient events
signal notify(notification: var)

// 3. Immutable state updates (trigger bindings)
root.list = [...root.list, newItem]           // Spread to new array
root.workspaces = newWorkspaces                // Replace entire object
root.list.splice(index, 1); root.list = root.list  // Reassign to trigger

// 4. File persistence
notifFileView.setText(JSON.stringify(root.list))
```

### Service Tiers

| Tier | Count | Loading | Purpose |
|---|---|---|---|
| 1 — Core | 56 | On `import qs.services` | System integration (Audio, NiriService, Notifications, etc.) |
| 2 — Utility | 4 | Manual instantiation | Socket wrapper, data models |
| 3 — Deferred | 18 | On UI demand | Cliphist, SongRec, CavaService, Emojis, KeyringStorage, etc. |

### Compositor Abstraction

`CompositorService.qml` detects compositor via environment variables:
- Priority: `HYPRLAND_INSTANCE_SIGNATURE` > `NIRI_SOCKET` > `XDG_CURRENT_DESKTOP`
- All services branch via `CompositorService.isNiri` / `isHyprland` guards

---

## Config System

| Aspect | Details |
|---|---|
| Schema | `modules/common/Config.qml` — JsonAdapter, 1385+ lines, 51 top-level sections |
| Defaults | `defaults/config.json` — 1100+ lines |
| User file | `~/.config/illogical-impulse/config.json` (legacy namespace) |
| Read | `Config.options.path.to.key` — typed QML properties with defaults |
| Write | `Config.setNestedValue("path.to.key", value)` — persisted + fires `configChanged()` |
| Ready gate | `Config.ready` — true after JSON loaded (or created if missing) |
| Hot-reload | `watchChanges: true` — external edits auto-apply |
| Debounce | 50ms for reads and writes |
| Locking | File-level `flock -w 5` in bash scripts; 100ms debounce in `MaterialThemeLoader` |

**Never write via direct assignment** — `Config.options.bar.autoHide.enable = true` is NOT persisted. Always use `Config.setNestedValue()`.

### Adding a new config key (always update together):
1. `modules/common/Config.qml` — schema definition
2. `defaults/config.json` — default value
3. Consumer(s) — read/write the key
4. Settings UI if user-facing

---

## Theming Pipeline

### Complete Data Flow

```
User picks wallpaper
        │
        ▼
switchwall.sh ──► Config batch read (24 values, single jq call)
        │
        ├── Video? → ffmpeg extract thumbnail frame
        ├── Backdrop mode? → use backdrop image as source
        ├── Per-monitor? → skip color generation
        │
        ▼
generate_colors_material.py (1231 lines, Python + materialyoucolor)
        │
        ├── Open image, resize to 128×128
        ├── Auto-detect scheme (colorfulness, HSV spread, hue variance)
        ├── QuantizeCelebi + Score → seed color
        ├── MaterialDynamicColors → 60+ color tokens
        ├── Harmonize terminal colors from scheme-base.json
        │     └── ensure_contrast() → WCAG AA 4.5:1
        └── Render matugen templates (mustache-style {{colors.TOKEN.MODE.PROP}})
              └── SDDM sync (optional)
        │
        ▼
  Writes: colors.json, palette.json, app-palette.json,
          terminal.json, theme-meta.json, material_colors.scss,
          chromium.theme
        │
        ├── system24_palette.sh (Vesktop/Discord theme)
        │
        ▼
applycolor.sh (called by MaterialThemeLoader when colors.json changes)
        │
        ├── For each target manifest (targets/*.json):
        │   ├── Check configKey enabled gate
        │   ├── Resolve module script path
        │   └── Run in parallel (max 2-4 jobs, ionice + nice)
        │
        ├── 10-terminals.sh     → escape sequences to /dev/pts/* + config files
        ├── 20-gtk-kde.sh       → GTK3/4 CSS + KDE/Qt color scheme
        ├── 30-editors.sh       → VS Code (15 forks) + Neovim + OpenCode
        ├── 40-chrome.sh        → Chrome/Chromium theme
        ├── 50-spicetify.sh     → Spotify
        ├── 60-sddm.sh          → Login screen
        ├── 70-steam.sh         → Steam (Millennium)
        ├── 80-pear-desktop.sh  → Pear desktop
        ├── 90-cava.sh          → Audio visualizer
        └── 31-zed.sh           → Zed editor
```

### Theming outputs installed to `$XDG_STATE_HOME/quickshell/user/generated/`

### Key design decisions:
- **Single batch config read** — `switchwall.sh` reads 24 values in one `jq` call
- **Atomic file writes** — via `.tmp` + `mv` pattern in `switchwall.sh`
- **Debounced triggers** — `MaterialThemeLoader` debounces 100ms to avoid racing file writes
- **Parallel module execution** — `applycolor.sh` runs 2-4 jobs concurrently
- **Module gating** — Each theming module reads its config key; disabled = skipped

---

## IPC System (External Commands)

Handlers registered via `IpcHandler { target: "name" }` in QML services.

Called externally: `inir <target> <function> [args]`

Key targets:
| Target | Functions | Service |
|---|---|---|
| `audio` | `volumeUp`, `volumeDown`, `mute`, `micMute` | `Audio.qml` |
| `keyboard` | `switchLayout`, `getCurrentLayout`, `getLayouts` | `NiriService.qml` |
| `notifications` | `test`, `clearAll`, `toggleSilent` | `Notifications.qml` |
| `globalActions` | `run`, `runWithArgs`, `list`, `search` | `GlobalActions.qml` |

Full reference: `docs/IPC.md`

---

## Installation & Update System

### Two install modes (tracked in `version.json`):
- **Repo-sync**: `./setup install` — syncs to `~/.config/quickshell/inir/`
- **Package-managed**: `make install` — copies to `/usr/share/quickshell/inir/`

### CLI Entry Points
| Command | Purpose |
|---|---|
| `./setup` | Interactive TUI (install, update, doctor, rollback) |
| `./setup install -y` | Fully automated installation |
| `./setup doctor` | 22-step diagnosis + auto-repair |
| `./setup rollback` | Restore previous snapshot |
| `make install` | System-level install |
| `scripts/inir` | Runtime CLI (run, settings, logs, doctor, update, restart, IPC) |

### Core Installer Architecture (`sdata/lib/`)
- `functions.sh` — `v()` verbose executor + interactive prompt, `x()` retry executor, `try()` soft wrapper
- `doctor.sh` — 22 diagnostic checks (dependencies, fonts, files, systemd, ABI, Python, config, etc.)
- `migrations.sh` — Numbered migration runner
- `snapshots.sh` — Pre-update backup + rollback
- `user-modifications.sh` — Preserves user changes across updates

### Multi-Distro Support
| Distro | Strategy |
|---|---|
| **Arch** | pacman + AUR helper for fonts |
| **Fedora** | dnf + COPR repos |
| **Debian/Ubuntu** | apt + compile from source |
| **Generic** | Guidance-only dependency checking |

### Migrations (`sdata/migrations/`)
- Numbered scripts: `001-descriptive-name.sh` through `026+`
- Append-only, idempotent, never delete or reorder
- Next number: `NEXT-descriptive-name.sh`

---

## Key Stability Boundaries (High-Risk Files)

These files have hundreds of consumers — prefer add-only changes:

| File | Consumers | Domain |
|---|---|---|
| `modules/common/Appearance.qml` | 352+ | All ii module visual tokens |
| `modules/common/Config.qml` | 200+ | All config read/write |
| `GlobalStates.qml` | 129+ | Panel visibility state |
| `services/Translation.qml` | 260+ | All i18n strings |
| `modules/waffle/looks/Looks.qml` | waffle modules | Waffle visual tokens |
| `services/NiriService.qml` | compositor modules | Niri IPC, workspaces, windows |
| `services/GameMode.qml` | many | Fullscreen detection + effects suppression |

---

## Key Patterns

### Panel Management
- `PanelLoader` wraps every panel as a lazy-loaded component
- `GlobalStates` tracks open/closed state via booleans (`bootGreetingOpen`, `sidebarLeftOpen`, etc.)
- Panel visibility controlled by `Config.options?.bar?.modules?.<name> ?? true`

### Visual Tokens
- **ii family**: `Appearance.colors.*` (Material You), `Appearance.rounding.*`, `Appearance.animation.*`
- **waffle family**: `Looks.*` (41 design tokens)
- Five-style dispatch: `angel > inir > aurora > material > cards`
- Never hardcode colors or rounding

### Animation System
- `Appearance.animation.*` with named types, `.duration`, `.type`, `.bezierCurve`
- Gated by `Appearance.animationsEnabled` (disabled in GameMode)
- `Revealer.qml` for animated show/hide
- `FluidRipple.qml` for GL shader-based ripple effects

### Error Handling Pattern
```qml
// QML: console.warn on non-fatal errors, silent discard for expected failures
console.warn("Failed to parse output:", e)
// Immutable state: reassign to trigger bindings
root.list = root.list  // force binding update
// Services: onLoadFailed → create + init empty
```

---

## Known Harmless Warnings

- `Failed to create DBusObjectManagerInterface for "org.bluez"` — no Bluetooth adapter
- `failed to register listener: ...PolicyKit1...` — another polkit agent running
- `QSGPlainTexture: Mipmap settings changed` — Qt cosmetic
- `Cannot open: file:///...coverart/...` — missing album art cache
- `$HYPRLAND_INSTANCE_SIGNATURE is unset` — expected when running on Niri
