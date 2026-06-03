---
date: 2026-06-03
topic: "Animation Smoothness Controls"
status: draft
---

## Problem Statement

The iNiR shell's animations have no speed control and the sidebar overshoot bounce (elastic/pop scale animations with a 0.88→1.04→1.0 two-phase sequence) can feel jarring. Users on smaller screens or sensitive to motion have no way to tune the feel.

## Constraints

- Must be backwards compatible — default behavior unchanged
- Speed multiplier must be reactive (apply immediately, no restart needed)
- Must work for all animation types (sidebar, dock, overlay, popups, etc.)
- Must integrate with existing GameMode/reduceAnimations disable logic

## Approach

Add two options:

1. **`appearance.animationSpeed`** — global duration multiplier (0.25–4.0, default 1.0)
2. **`sidebar.scaleAnimation`** — toggle sidebar overshoot bounce (bool, default true)

The speed multiplier is the primary smoothness control. The sidebar toggle addresses the most common source of perceived jank.

## Architecture

### Animation speed multiplier

```
Config.options.appearance.animationSpeed (0.25-4.0, default 1.0)
    ↓
Appearance.animationSpeed (clamped property)
    ↓
Appearance.calcEffectiveDuration(baseDuration)
    ├── if !animationsEnabled → return 0
    └── if enabled → Math.round(baseDuration / animationSpeed)
              ↓
    All animation sub-objects use calcEffectiveDuration():
    ─ elementMoveEnter.duration = calcEffectiveDuration(400)
    ─ elementMoveExit.duration  = calcEffectiveDuration(200)
    ─ elementMoveFast.duration  = calcEffectiveDuration(200)
    ─ elementMove.duration      = calcEffectiveDuration(500)
    ─ elementResize.duration    = calcEffectiveDuration(300)
    ─ clickBounce.duration      = calcEffectiveDuration(400)
    ─ scroll.duration           = calcEffectiveDuration(200)
    ─ menuDecel.duration        = calcEffectiveDuration(350)
              ↓
    All consumers read Appearance.animation.*.duration as before
```

The multiplier is transparent to consumers — they still read `Appearance.animation.elementMoveEnter.duration`. When `animationSpeed` changes, all bindings recalculate automatically via QML property bindings.

### Sidebar scale overshoot

In the sidebar open transitions, the scale animation currently has a two-phase SequentialAnimation:

- **Phase 1** (62% of duration): scale from 0.88 (elastic) or 0.94 (pop) → overshoots to 1.04 or 1.018
- **Phase 2** (38% of duration): scale settles to 1.0

When `sidebar.scaleAnimation` is false, the SequentialAnimation is replaced with a simpler animation that animates scale from 1.0 to 1.0 (essentially skipping the effect). The cleanest implementation is to gate the SequentialAnimation:

```qml
// Instead of always playing the 2-phase animation:
SequentialAnimation {
    enabled: Config.options?.sidebar?.scaleAnimation ?? true
    // ... phase 1 and 2
}
```

When disabled, scale simply stays at 1.0 throughout the main slide-in animation.

## Components

### 1. Config.qml — New options

- `appearance.animationSpeed`: real, default 1.0, in the appearance section
- `sidebar.scaleAnimation`: bool, default true, in the sidebar section

### 2. Appearance.qml — Speed multiplier

- Add `animationSpeed` property with clamping:
  ```qml
  property real animationSpeed: {
      const v = Config.options?.appearance?.animationSpeed
      if (typeof v === 'number' && v >= 0.25 && v <= 4) return v
      return 1.0
  }
  ```

- Update `calcEffectiveDuration`:
  ```qml
  function calcEffectiveDuration(baseDuration) {
      if (!animationsEnabled) return 0
      return Math.max(1, Math.round(baseDuration / root.animationSpeed))
  }
  ```
  Note: `Math.max(1, ...)` ensures duration is at least 1ms when animations are enabled, avoiding divide-by-zero or zero-duration issues.

- Apply to all animation sub-object durations (lines 459-553):
  ```
  elementMove:         duration = root.calcEffectiveDuration(500)
  elementMoveEnter:    duration = root.calcEffectiveDuration(400)
  elementMoveExit:     duration = root.calcEffectiveDuration(200)
  elementMoveFast:     duration = root.calcEffectiveDuration(200)
  elementResize:       duration = root.calcEffectiveDuration(300)
  clickBounce:         duration = root.calcEffectiveDuration(400)
  scroll:              duration = root.calcEffectiveDuration(200)
  menuDecel:           duration = root.calcEffectiveDuration(350)
  ```

### 3. SidebarLeft.qml / SidebarRight.qml — Scale overshoot gate

Add `enabled: Config.options?.sidebar?.scaleAnimation ?? true` to the SequentialAnimation block in both open transitions. When disabled, the scale simply remains at 1.0 (the default value of `animScale`).

### 4. PerformanceConfig.qml (or ThemesConfig.qml) — Settings UI

Add an animation speed slider in the Performance settings section (or a new Animation section). The slider should:
- Range: 0.5 to 2.0 (extreme values 0.25 and 4.0 are still accessible via JSON config)
- Label: "Animation speed"
- Description: "Controls how fast animations play. Higher = snappier."

## Data Flow

```
User tweaks animationSpeed in settings/JSON
    ↓
Config.options.appearance.animationSpeed updates
    ↓
Appearance.animationSpeed binding recalculates
    ↓
calcEffectiveDuration() returns new values
    ↓
All animation sub-object .duration properties update
    ↓
All active and future animations use new durations
```

## Error Handling

- **Invalid config value** (string, negative, etc.): `animationSpeed` clamps to 1.0
- **Out of range**: Values outside 0.25–4.0 are clamped to nearest bound
- **Sidebar scaleAnimation undefined**: defaults to `true` (existing behavior)
- **calcEffectiveDuration with animations disabled**: returns 0 (existing behavior, animations snap)

## Testing Strategy

1. **Config parsing** — verify `appearance.animationSpeed` accepts 0.5, 1.0, 2.0, rejects "abc", -1, etc.
2. **Binding reactivity** — change animationSpeed at runtime, verify sidebar open duration changes immediately
3. **Sidebar scale toggle** — set `sidebar.scaleAnimation: false`, verify sidebar opens without bounce
4. **GameMode integration** — verify GameMode still disables all animations regardless of speed setting
5. **Visual validation** — at 1.5×, shell should feel noticeably snappier without being jarring
