# iNiR Code Style & Conventions

> Coding patterns and conventions observed across the iNiR codebase. Follow these when modifying or adding code.

**Languages**: QML (primary), Bash, Python, Go, JavaScript (QML modules), Makefile

---

## Naming Conventions

### By Language

| Language | Files | Classes/Types | Functions | Variables | Constants |
|---|---|---|---|---|---|
| **QML** | PascalCase (components), lowercase (roots) | PascalCase | camelCase | camelCase | `SCREAMING_SNAKE` (env) |
| **JavaScript (.js)** | kebab-case | PascalCase | camelCase | camelCase, `_`private | — |
| **Go** | snake_case | PascalCase | PascalCase (exported), camelCase (private) | camelCase | camelCase |
| **Python** | snake_case | PascalCase | snake_case, `_`private | snake_case | `SCREAMING_SNAKE` |
| **Bash** | kebab-case, `NNN-` prefixed | — | snake_case | lowercase (local), `SCREAMING_SNAKE` (global) | `SCREAMING_SNAKE` |
| **Makefile** | kebab-case | — | kebab-case (targets) | `SCREAMING_SNAKE` | `SCREAMING_SNAKE` |
| **JSON** | `{lang}_{REGION}.json` (locale) | — | — | — | camelCase (keys) |

### File Naming

```yaml
QML components:        PascalCase.qml               # GlobalStates.qml, Weather.qml
QML entry points:      lowercase.qml                 # shell.qml, settings.qml
QML services:          PascalCase.qml                # NiriService.qml, Audio.qml
QML strategy pattern:  {Provider}ApiStrategy.qml     # GeminiApiStrategy.qml
QML deferred services: PascalCase.qml                # SongRec.qml, Cliphist.qml
JavaScript modules:    kebab-case.js                 # calendar_layout.js, material-shapes.js
Python scripts:        snake_case.py                 # generate_colors_material.py
Shell scripts:         kebab-case.sh                 # switchwall.sh, applycolor.sh
Shell migrations:      001-descriptive-name.sh       # Numbered sequential
Make targets:          kebab-case                    # install-shell, test-local
Translation files:     {lang}_{REGION}.json          # en_US.json, zh_CN.json
```

### QML Naming

```qml
// Properties — camelCase
readonly property bool hideLocation: ...
property var location: ({ valid: false })

// State booleans — camelCase, descriptive
property bool shellEntryReady: false
property bool sidebarLeftOpen: false
property bool requestWifiDialog: false

// Functions — camelCase
function buildEndpoint(model: AiModel): string { ... }
function handleWorkspacesChanged() { ... }

// Signals — camelCase (no "on" prefix — that's for handlers)
signal windowUrgentChanged
signal notify(notification: var)

// Signal handlers — on<Signal>Changed
onWindowUrgentChanged: { ... }

// Types in function signatures — always annotate
function getData(): string { return String(value) }
function doThing(amount: real, name: string): void { ... }

// Config access — optional chaining
Config.options?.bar?.weather?.enable ?? false
Config.options?.waffles?.widgetsPanel?.weatherHideLocation ?? false

// IpcHandler targets — lowercase, descriptive
IpcHandler { target: "myService" }
```

### Bash Naming

```bash
# Functions — snake_case
doctor_detect_compositor_service() { ... }

# Global variables — SCREAMING_SNAKE
doctor_passed=0
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Local variables — lowercase
local missing=()
local p

# Helper/group prefixes — prefix_groupName
doctor_pass() { ... }
doctor_fail() { ... }
```

### Python Naming

```python
# Classes — PascalCase
@dataclass
class IpcTarget:
    name: str
    functions: list[IpcFunction] = field(default_factory=list)

# Functions — snake_case
rgba_to_hex = lambda rgba: ...

# Private/Internal — underscore prefix
def _scan_qml_file(path: Path) -> list[IpcTarget]: ...

# Module constants — SCREAMING_SNAKE
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
QML_DIRS = [...]
```

### Go Naming

```go
// Exported functions — PascalCase
func ReadStringMapJSON(path string) (map[string]string, error) {}

// Unexported functions — camelCase
func isHexColor(v string) bool {}

// Types — PascalCase
type syntaxToken struct {
    Color      string
    FontStyle  any
}
```

---

## File Organization

### QML Component Structure

One component per file, one file per component:

```qml
pragma Singleton
pragma ComponentBehavior: Bound

// Imports: Qt → Quickshell → project modules (grouped)
import QtQuick
import Quickshell
import Quickshell.Io

import qs.modules.common
import qs.modules.common.widgets
import qs.services

// Root element — always `id: root`
Singleton {
    id: root

    // 1. Properties (readonly first, then mutable)
    readonly property int fetchInterval: 5000
    property var data: ({})

    // 2. Signals
    signal dataRefreshed()

    // 3. Qt bindings / child components
    Timer {
        interval: root.fetchInterval
        onTriggered: root.refresh()
    }

    // 4. Functions
    function refresh() { ... }

    // 5. Component lifecycle
    Component.onCompleted: { ... }
}
```

### QML Import Order

```qml
1. pragma statements
2. Qt modules (QtQuick, QtQml, QtQuick.Controls)
3. Quickshell modules (Quickshell, Quickshell.Io)
4. qs.modules.* (project internal modules)
5. qs.services (service singletons)
```

### JavaScript Module Structure

```js
// 1. Import statements
.import "shapes/point.js" as Point
.import "shapes/corner-rounding.js" as CornerRounding

// 2. Module-private variables (_prefix)
var _circle = null
var _square = null

// 3. Classes (PascalCase)
class Feature {
    constructor() { ... }
    getDistance() { ... }
}

// 4. Factory functions (camelCase)
function createPoint(x, y) { ... }
```

### Bash Script Structure

```bash
#!/usr/bin/env bash

# 1. Config/global variables
PREFIX ?= /usr/local
SHELL_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"

# 2. Helper functions
try { "$@" || sleep 0; }

# 3. Named functions (grouped by prefix)
doctor_pass() { ... }
doctor_fail() { ... }

# 4. Main execution flow
if [[ $# -eq 0 ]]; then
    show_tui
else
    handle_command "$@"
fi
```

---

## Mandatory Code Patterns

### Config Reads & Writes

```qml
// ✅ READ — always with null-safe chain
Config.options?.bar?.weather?.enable ?? false

// ✅ WRITE — ALWAYS via setNestedValue (never direct assignment)
Config.setNestedValue("bar.autoHide.enable", true)

// ❌ NEVER — direct mutation does NOT persist
Config.options.bar.autoHide.enable = true
```

### Visual Tokens — Never Hardcode

```qml
// ✅ ii family — use Appearance tokens
color: Appearance.colors.colPrimary
radius: Appearance.rounding.normal
font.pixelSize: Appearance.typography.bodyFontSize

// ✅ waffle family — use Looks tokens
color: Looks.surfaceColor

// ✅ Five-style dispatch (priority: angel > inir > aurora > material)
color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
     : Appearance.inirEverywhere ? Appearance.inir.colLayer1
     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
     : Appearance.colors.colLayer1

// ❌ NEVER
color: "#FF6200EE"
radius: 8
```

### Animations

```qml
// ✅ Use Appearance.animation tokens
Behavior on opacity {
    NumberAnimation {
        duration: Appearance.animation.fast.duration
        easing.type: Appearance.animation.fast.type
    }
}

// ✅ Gate with animationsEnabled
visible: Appearance.animationsEnabled ? someCondition : true

// ❌ NEVER hardcode animation durations
duration: 300
```

### Compositor Guards

```qml
// ✅ Always guard compositor-specific code
if (CompositorService.isNiri) {
    // niri-specific socket calls
}
if (CompositorService.isHyprland) {
    // hyprland-specific hyprctl calls
}
```

### Null Safety

```qml
// ✅ Use ?? operator with sensible defaults
property var windows: NiriService.windows ?? []
property string name: NiriService.focusedWindow?.title ?? ""
property real volume: sink?.audio?.volume ?? 0.0

// ✅ Guard against missing services
if (GlobalStates?.sidebarRightOpen ?? false) { ... }
```

### IPC Functions — Declare Return Types

```qml
// ✅ ALL IPC functions must declare return types
IpcHandler {
    target: "myService"
    function getData(): string { return String(value) }
    function doThing(): void { /* ... */ }
    function count(): int { return list.length }
}
```

### Immutable State Updates

```qml
// ✅ Array — spread to new instance (triggers binding reevaluation)
root.list = [...root.list, newItem]

// ✅ Object — replace entirely
root.workspaces = newWorkspaces

// ✅ Force binding update after mutation
root.list.splice(index, 1)
root.list = root.list    // reassign to same array
triggerListChange()      // or use explicit signal
```

### Service Registration

```qml
// ✅ Services register in qmldir
module qs.services
singleton MyService 1.0 MyService.qml

// ✅ Use for non-singleton types
MyDataType 1.0 MyDataType.qml
```

### Config-Gated Loading

```qml
// ✅ Gate panel visibility by config
Loader {
    active: Config.options?.bar?.modules?.media ?? true
    sourceComponent: Media {}
}
```

### Translations

```qml
// ✅ Always use Translation.tr()
label: Translation.tr("settings.general", "General settings")

// ❌ NEVER hardcode user-facing strings
label: "General settings"
```

---

## Error Handling

### QML

```qml
// Non-fatal errors — console.warn (not console.error)
console.warn("Failed to parse output:", e)

// Expected failures — silent discard
if (parseError) return  // silently keep previous state

// Rate limiting — silent discard
if (tooFast) return

// File loading — handle gracefully
onLoadFailed: {
    if (error === FileNotFound) {
        // Create + init empty
    } else {
        console.warn("Unexpected load error:", error)
        initEmpty()
    }
}
```

### Bash

```bash
# Soft failure wrapper
try { "$@" || sleep 0; }

# Retry with interactive recovery
x "$@"  # On failure: retry/exit/ignore menu

# Non-critical failure — log + continue
if ! python_script; then
    log_warning "Color gen failed, keeping previous"
fi

# Critical failure — exit with message
if ! command -v jq &>/dev/null; then
    log_error "jq is required"
    exit 1
fi
```

### Python

```python
# Non-fatal — log and continue
logger.warning(f"Skipping unknown scheme: {scheme}")

# Private helpers for internal logic
def _ensure_contrast(color: str, background: str) -> str: ...
```

### Go

```go
// Return errors explicitly
func ReadStringMapJSON(path string) (map[string]string, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("reading %s: %w", path, err)
    }
    // ...
}
```

---

## Logging

### QML
```qml
console.log("debug message")       // Debug (gated by env var)
console.warn("non-fatal error:", e)   // Warnings
// console.error is rarely used — prefer warn for non-fatal
```

Debug logging gated by environment:
```qml
function _log(msg: string): void {
    if (Quickshell.env("QS_DEBUG") === "1") console.log(msg)
}
```

### Bash
```bash
log_info "Processing..."           # Info
log_success "Done"                 # Success
log_warning "Something odd"        # Warning
log_error "Something failed"       # Error (stderr)
log_header "=== Section ==="       # Section headers
```

---

## Testing Patterns

### Test Infrastructure
- **Primary**: `scripts/test-local-distribution.sh` (invoked via `make test-local`)
- **Lint**: `scripts/qml-check.fish` (QML syntax patterns)
- **ShellCheck**: `.shellcheckrc` configuration

### Test Approach
```bash
# Shell syntax checking
bash -n setup
bash -n scripts/inir

# Runtime payload validation
check_manifest_integrity

# Config validation
jq . config.json > /dev/null

# Version consistency
check_version_matches_pkgbuild

# IPC registry freshness
check_ipc_registry_uptodate
```

There is **no** structured unit/integration test framework. Testing is shell-based and manual. Install changes are tested via `inir restart && inir logs | tail -50`.

---

## Config Sync Groups

When you change one, always update the others:

| Change | Also update |
|---|---|
| Config schema | `defaults/config.json` + consumer(s) |
| New service | `services/qmldir` (if new) |
| New shared widget | `modules/common/widgets/qmldir` (if new) |
| IPC targets | `docs/IPC.md` |
| Dependencies | `docs/PACKAGES.md` |
| Config key | Settings UI if user-facing |
| Migration script | Increment number in sequence |

---

## Commit Conventions

- **Imperative mood**, max 72 chars: `Fix bar crash when weather widget is disabled`
- Be specific — not "fix bug" or "update code"
- One logical change per commit
- Body (optional): explain **why**, not what

### Branch Naming

| Type | Format | Example |
|---|---|---|
| Feature | `feat/short-description` | `feat/bluetooth-battery-level` |
| Bug fix | `fix/short-description` | `fix/bar-crash-on-resize` |
| Refactor | `refactor/short-description` | `refactor/audio-service-cleanup` |

---

## Do's and Don'ts Quick Reference

| ✅ Do | ❌ Don't |
|---|---|
| Use `Config.setNestedValue()` for writes | Direct config property mutation |
| Use `Appearance.colors.*` / `Looks.*` for visuals | Hardcode colors (`#FF6200EE`) |
| Use `Appearance.rounding.*` for corner radii | Hardcode pixel radii |
| Use `Appearance.animation.*` for durations | Hardcode animation durations |
| Declare IPC function return types | `function doThing() { }` (no return type) |
| Guard compositor code with `CompositorService.isNiri/isHyprland` | Assume single compositor |
| Gate features behind config keys | Hardcode feature toggles |
| Use `Translation.tr()` for user-facing strings | Hardcode display strings |
| Use null-safe `?.` and `??` | Assume properties exist |
| Replace arrays/objects entirely to trigger bindings | Mutate in-place without reassignment |
| `console.warn()` for non-fatal errors | `console.error()` for recoverable issues |
| One component per QML file | Multiple components in one file unless trivial |
| `id: root` for root elements | Non-standard id names |
| Append-only migrations (never delete/reorder) | Rename or delete existing migrations |
| Prefix bash helper groups (`doctor_*`, `ensure_*`) | Inconsistent naming |
| Parallel tool calls where possible | Sequential shell commands when batchable |
