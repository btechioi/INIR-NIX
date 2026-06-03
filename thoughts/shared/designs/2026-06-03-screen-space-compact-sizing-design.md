---
date: 2026-06-03
topic: "Screen Space Optimization — Compact Sizing"
status: validated
---

## Problem Statement

On smaller screens (1366×768 and below), the iNiR shell consumes too much screen real estate:
- **63px bar height** = 8.2% of vertical space
- **460px sidebar width** = 33.7% of horizontal space
- **85px dock** = 11% of vertical space
- **30px total margins** from elevationMargin (10px) + hyprlandGapsOut (5px) × 2 sides

The existing `fontSizeScale` (appearance.typography.sizeScale) scales everything including fonts, which makes text *harder* to read on small screens — the opposite of what we want.

## Constraints

- Font sizes must remain at the user's chosen scale — only chrome/padding should shrink
- Must adapt when external monitors are connected (no hardcoded values)
- Must work with both `ii` and `waffle` panel families
- Must not break the existing responsive shortening thresholds (1200px/1000px)
- Config overrides must always win over compact defaults
- Compact mode should be noticeable but not extreme — keep content usable

## Approach

Add an `appearance.compact` option with three modes that independently controls chrome dimensions:

- **`"auto"`** (default) — detects primary screen size at runtime
- **`true`** — force compact mode
- **`false`** — force normal mode

The auto-detection uses the primary screen's geometry:
- Height ≤ 800px → compact
- Width ≤ 1400px → compact

This gives a smooth experience: plug into a big monitor → normal mode, disconnect → compact mode.

## Architecture

### Data flow

```
Config.options.appearance.compact ("auto"|true|false)
    ↓
Appearance.qml
    ├── computes compactMode boolean
    │   [auto-detect via GlobalStates.primaryScreen | forced true | forced false]
    │
    └── sizes object uses compactMode to choose values:
        ├── baseBarHeight: compact ? 32 : 40 (× fontSizeScale)
        ├── sidebarWidth: compact ? 340 : 460 (× fontSizeScale)
        ├── elevationMargin: compact ? 6 : 10 (× fontSizeScale)
        └── ... etc

Each panel reads from Appearance.sizes as before
  → Bar, SidebarLeft, SidebarRight, VerticalBar (no changes needed)
  → Dock.qml updated to use Appearance.sizes.dockHeight
```

### Compact detection (Appearance.qml)

```qml
// Evaluates to true/false based on config + screen detection
readonly property bool compactMode: {
    const setting = Config.options?.appearance?.compact;
    if (setting === true) return true;
    if (setting === false) return false;
    // "auto": detect from primary screen
    const screen = GlobalStates?.primaryScreen;
    if (!screen) return false;
    return (screen.height ?? 1080) <= 800 || (screen.width ?? 1920) <= 1400;
}
```

Falls back to `false` when screen info isn't available (early startup), avoiding a flash of compact-then-normal.

### Size values

All values still multiply by `fontSizeScale`:

| Property | Normal | Compact |
|---|---|---|
| `baseBarHeight` | `Math.round(40 * fontSizeScale)` | `Math.round(32 * fontSizeScale)` |
| `sidebarWidth` | `Math.round(460 * fontSizeScale)` | `Math.round(340 * fontSizeScale)` |
| `sidebarWidthExtended` | `Math.round(750 * fontSizeScale)` | `Math.round(540 * fontSizeScale)` |
| `baseVerticalBarWidth` | `Math.round(46 * fontSizeScale)` | `Math.round(36 * fontSizeScale)` |
| `elevationMargin` | `Math.round(10 * fontSizeScale)` | `Math.round(6 * fontSizeScale)` |
| `hyprlandGapsOut` | 5 | **3** (no font scaling — this is a fixed pixel gap) |
| `barCenterSideModuleWidth` | `Math.round(360 * fontSizeScale)` | `Math.round(280 * fontSizeScale)` |
| `mediaControlsWidth` | `Math.round(380 * fontSizeScale)` | `Math.round(300 * fontSizeScale)` |
| `mediaControlsHeight` | `Math.round(150 * fontSizeScale)` | `Math.round(120 * fontSizeScale)` |
| `notificationPopupWidth` | `Math.round(410 * fontSizeScale)` | `Math.round(340 * fontSizeScale)` |
| `osdWidth` | `Math.round(180 * fontSizeScale)` | `Math.round(150 * fontSizeScale)` |
| `searchWidthCollapsed` | `Math.round(210 * fontSizeScale)` | `Math.round(170 * fontSizeScale)` |
| `searchWidth` | `Math.round(360 * fontSizeScale)` | `Math.round(290 * fontSizeScale)` |
| `spacingSmall` | `Math.round(8 * fontSizeScale)` | `Math.round(6 * fontSizeScale)` |
| `spacingMedium` | `Math.round(12 * fontSizeScale)` | `Math.round(8 * fontSizeScale)` |
| `spacingLarge` | `Math.round(16 * fontSizeScale)` | `Math.round(12 * fontSizeScale)` |

Dock height (new addition to Appearance.sizes):

| `dockHeight` | `Math.round(60 * fontSizeScale)` | `Math.round(48 * fontSizeScale)` |

The dock config override (`Config.options.dock.height`) takes priority over `Appearance.sizes.dockHeight` when explicitly set.

## Components

### 1. Config.qml — New option

Add `appearance.compact` to the JsonAdapter at the appropriate location.

- **Type:** `variant` (string or boolean)
- **Default:** `"auto"`
- **Valid values:** `"auto"`, `true`, `false`
- **Location:** Under `appearance` section, near `appearance.globalStyle`

### 2. Appearance.qml — Compact mode logic

Add:
- `compactMode` readonly property (boolean with auto-detect logic)
- Modify all `sizes` properties to ternary on `compactMode`

### 3. Dock.qml — Use Appearance.sizes.dockHeight

Currently reads:
```qml
readonly property int dockHeight: Config.options?.dock?.height ?? 70
```

Change to:
```qml
readonly property int dockHeight: Appearance.sizes.dockHeight
```

The config override path is still available via `Appearance.sizes.dockHeight` (which will defer to compact mode or normal mode).

Wait — this changes behavior: currently the dock respects `Config.options.dock.height` as a direct override. If I remove that, the user loses the ability to set dock height independently.

**Better approach:** Keep the config override in Dock.qml, but add it also to Appearance.sizes for the default:

```qml
// In Dock.qml
readonly property int dockHeight: Config.options?.dock?.height ?? Appearance.sizes.dockHeight
```

This way:
- User sets `dock.height` → that value is used
- User doesn't set it → `Appearance.sizes.dockHeight` (which respects compact mode)

### 4. ThemesConfig.qml — Settings UI toggle

Add a compact mode toggle (switch/checkbox) in the appearance settings page. This lets users switch between auto/on/off without editing JSON.

The switch should have 3 states: "Auto" (default), "On", "Off".

Label it as "Compact mode" with a description: "Reduce chrome size on smaller screens".

## Data Flow

```
User config (JSON)
  → Config.qml (parses options)
    → Appearance.qml (reads appearance.compact + primary screen)
      → compactMode boolean
        → sizes.{baseBarHeight, sidebarWidth, ...} (compact variants)
          → Bar.qml, SidebarLeft.qml, etc. (consume sizes as before)
```

For auto mode:
```
GlobalStates.primaryScreen.{width, height}
  → (binding recomputes when screen changes)
    → compactMode may flip
      → sizes recompute
        → panels resize reactively
```

## Error Handling

- **Screen not available at startup:** `compactMode` returns `false` (safe default, no flash of weird sizing). It will reactively update when `GlobalStates.primaryScreen` is set.
- **Invalid config value:** If user sets `compact: "yes"` instead of true/false/"auto", the detection treats it as `false` (normal mode). The `=== true` check is strict.
- **Multiple monitors:** Uses `GlobalStates.primaryScreen` which respects `config.options.display.primaryMonitor`. All panels on all screens share the same compact mode based on the primary screen's size.

## Testing Strategy

1. **Build verification** — `nix build` succeeds
2. **Config parsing** — verify `appearance.compact` accepts "auto", true, false
3. **Auto-detect** — test with mocked screen sizes:
   - 1366×768 → compact should activate
   - 1920×1080 → compact should not activate
   - 2560×1440 → compact should not activate
   - 1366×900 → compact should not activate (height > 800)
4. **Manual override** — `compact: true` activates on all screens; `compact: false` never activates
5. **Dock height** — verify explicit `dock.height` config still overrides compact defaults
6. **Visual validation** — compact mode at 1366×768 should feel noticeably less cramped

## Open Questions

None. The design is straightforward and self-contained.
