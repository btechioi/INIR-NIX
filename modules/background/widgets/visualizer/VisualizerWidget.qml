pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "visualizer"
    defaultConfig: ({ placementStrategy: "free", preset: "default", barCount: 48, barSpacing: 2, barRadius: 2, barMinHeight: 1, contentWidth: 304, contentHeight: 104, dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true, showBorder: true, colorMode: "auto", x: 100, y: 100 })

    implicitWidth: Math.round((Config.options?.background?.widgets?.visualizer?.contentWidth ?? 304) * scaleFactor)
    implicitHeight: Math.round((Config.options?.background?.widgets?.visualizer?.contentHeight ?? 104) * scaleFactor)

    visibleWhenLocked: false
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })

    editPopoverContent: Component {
        Item {
            implicitWidth: _vizPopRow.implicitWidth
            implicitHeight: _vizPopRow.implicitHeight
            Row {
                id: _vizPopRow
                spacing: 8
                StyledText { text: Translation.tr("Bars"); color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small; anchors.verticalCenter: parent.verticalCenter }
                StyledSpinBox {
                    from: 8; to: 128; stepSize: 4
                    value: Config.options?.background?.widgets?.visualizer?.barCount ?? 48
                    onValueModified: Config.setNestedValue("background.widgets.visualizer.barCount", value)
                }
            }
        }
    }

    readonly property bool _active: Config.options?.background?.widgets?.visualizer?.enable ?? false

    // ── Dim factor (0..1) ──────────────────────────────────────
    property real dimFactor: {
        const v = Config.options?.background?.widgets?.visualizer?.dim ?? 0;
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    // ── 5-style tokens ─────────────────────────────────────────
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1
    readonly property color colBorder: Appearance.angelEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    // Dimmed text color for overlay
    property color dimTextColor: ColorUtils.mix(root.colText, Qt.rgba(0, 0, 0, 1), dimFactor)

    CavaProcess {
        id: cavaProcess
        active: root._active
    }

    // ── Card background ────────────────────────────────────────
    Rectangle {
        id: cardBg
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        color: root.backgroundOpacity > 0 ? ColorUtils.applyAlpha(root.colText, root.backgroundOpacity) : "transparent"
        border { width: root.borderWidth; color: ColorUtils.applyAlpha(root.colText, root.borderOpacity) }
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0
    }

    // ── Visualizer bars ────────────────────────────────────────
    CavaVisualizer {
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
        points: cavaProcess.points
        live: root._active
        barCount: Config.options?.background?.widgets?.visualizer?.barCount ?? 48
        barSpacing: Config.options?.background?.widgets?.visualizer?.barSpacing ?? 2
        barMinHeight: Config.options?.background?.widgets?.visualizer?.barMinHeight ?? 1
        barRadius: Config.options?.background?.widgets?.visualizer?.barRadius ?? 2
        // Multi-color visualizer: low freq = secondary, mid = primary, high = tertiary
        colorLow: Appearance.angelEverywhere ? Appearance.angel.colSecondaryContainer
            : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
            : Appearance.auroraEverywhere ? Appearance.m3colors.m3secondaryContainer
            : Appearance.colors.colSecondaryContainer
        colorMed: Appearance.angelEverywhere ? Appearance.angel.colPrimary
            : Appearance.inirEverywhere ? Appearance.inir.colPrimary
            : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
            : Appearance.colors.colPrimary
        colorHigh: Appearance.angelEverywhere ? Appearance.angel.colTertiary
            : Appearance.inirEverywhere ? Appearance.inir.colTertiary
            : Appearance.auroraEverywhere ? Appearance.m3colors.m3tertiary
            : Appearance.colors.colTertiary
        opacity: 1.0 - dimFactor * 0.6
    }
}
