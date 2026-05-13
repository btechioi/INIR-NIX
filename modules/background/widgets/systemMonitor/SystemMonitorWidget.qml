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

    configEntryName: "systemMonitor"
    defaultConfig: ({ placementStrategy: "free", preset: "default", displayMode: "bars", showCpu: true, showMemory: true, showGpu: true, showLabels: true, contentWidth: 320, contentHeight: 120, dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true, showBorder: true, colorMode: "auto", x: 50, y: 400 })

    implicitWidth: Math.round((Config.options?.background?.widgets?.systemMonitor?.contentWidth ?? 320) * scaleFactor)
    implicitHeight: Math.round((Config.options?.background?.widgets?.systemMonitor?.contentHeight ?? 120) * scaleFactor)

    visibleWhenLocked: false
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })

    // ── Popover: mode + resource toggles ──
    editPopoverContent: Component {
        Item {
            implicitWidth: _sysMonCol.implicitWidth
            implicitHeight: _sysMonCol.implicitHeight
            Column {
                id: _sysMonCol
                spacing: 6
                Row {
                    spacing: 4
                    Repeater {
                        model: [
                            { label: "Bars", value: "bars" },
                            { label: "Graph", value: "graph" },
                            { label: "Rings", value: "rings" },
                            { label: "Text", value: "text" }
                        ]
                        RippleButton {
                            required property var modelData
                            width: 56; height: 28
                            buttonRadius: Appearance.rounding.small
                            toggled: root.displayMode === modelData.value
                            colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
                            colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                            colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                            downAction: () => Config.setNestedValue("background.widgets.systemMonitor.displayMode", modelData.value)
                            contentItem: StyledText { anchors.centerIn: parent; text: modelData.label; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small }
                        }
                    }
                }
                Row {
                    spacing: 8
                    Repeater {
                        model: [
                            { label: "CPU", key: "showCpu", active: root.showCpu },
                            { label: "MEM", key: "showMemory", active: root.showMemory },
                            { label: "GPU", key: "showGpu", active: root.showGpu }
                        ]
                        RippleButton {
                            required property var modelData
                            width: 56; height: 28
                            buttonRadius: Appearance.rounding.small
                            toggled: modelData.active
                            colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
                            colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                            colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                            downAction: () => Config.setNestedValue("background.widgets.systemMonitor." + modelData.key, !modelData.active)
                            contentItem: StyledText { anchors.centerIn: parent; text: modelData.label; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small }
                        }
                    }
                }
            }
        }
    }

    // ── Config properties ──
    readonly property bool _active: Config.options?.background?.widgets?.systemMonitor?.enable ?? false
    readonly property string displayMode: Config.options?.background?.widgets?.systemMonitor?.displayMode ?? "bars"
    readonly property bool showCpu: Config.options?.background?.widgets?.systemMonitor?.showCpu ?? true
    readonly property bool showMemory: Config.options?.background?.widgets?.systemMonitor?.showMemory ?? true
    readonly property bool showGpu: Config.options?.background?.widgets?.systemMonitor?.showGpu ?? true
    readonly property bool showLabels: Config.options?.background?.widgets?.systemMonitor?.showLabels ?? true
    readonly property real trackAlpha: Config.options?.background?.widgets?.systemMonitor?.trackAlpha ?? 0.08
    readonly property real fillOpacity: Config.options?.background?.widgets?.systemMonitor?.fillOpacity ?? 0.7
    readonly property real graphFillOpacity: Config.options?.background?.widgets?.systemMonitor?.graphFillOpacity ?? 0.3

    property real dimFactor: {
        const v = Config.options?.background?.widgets?.systemMonitor?.dim ?? 0;
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    // ── Shared resource model builder ──
    readonly property var _resourceModel: {
        const items = [];
        if (root.showCpu) items.push({ icon: "memory", label: "CPU", value: ResourceUsage.cpuUsage, color: root.cpuColor });
        if (root.showMemory) items.push({ icon: "storage", label: "RAM", value: ResourceUsage.memoryUsedPercentage, color: root.memColor });
        if (root.showGpu) items.push({ icon: "developer_board", label: "GPU", value: ResourceUsage.gpuUsage, color: root.gpuColor });
        return items;
    }

    // ── Style tokens ──
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property int _innerMargin: Appearance.angelEverywhere || Appearance.inirEverywhere ? 6 : 2

    readonly property color cpuColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
        : Appearance.colors.colPrimary
    readonly property color memColor: Appearance.angelEverywhere ? Appearance.angel.colSecondaryContainer
        : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3secondaryContainer
        : Appearance.colors.colSecondaryContainer
    readonly property color gpuColor: Appearance.angelEverywhere ? Appearance.angel.colTertiary
        : Appearance.inirEverywhere ? Appearance.inir.colTertiary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3tertiary
        : Appearance.colors.colTertiary

    Component.onCompleted: if (root._active) ResourceUsage.keepAlive()
    Component.onDestruction: if (root._active) ResourceUsage.releaseKeepAlive()
    on_ActiveChanged: {
        if (_active) ResourceUsage.keepAlive();
        else ResourceUsage.releaseKeepAlive();
    }

    // ── Card background ──
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        color: root.backgroundOpacity > 0 ? ColorUtils.applyAlpha(root.colText, root.backgroundOpacity) : "transparent"
        border { width: root.borderWidth; color: ColorUtils.applyAlpha(root.colText, root.borderOpacity) }
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0
    }

    // ══════════════════════════════════════════════════════════
    // BARS MODE — horizontal fill bars with icon + percentage
    // ══════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root._innerMargin
        spacing: Appearance.sizes.spacingSmall ?? 4
        opacity: 1.0 - root.dimFactor * 0.6
        visible: root.displayMode === "bars"

        Repeater {
            model: root._resourceModel

            RowLayout {
                id: barRow
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Appearance.sizes.spacingSmall ?? 4

                MaterialSymbol {
                    visible: root.showLabels
                    text: barRow.modelData.icon
                    iconSize: Appearance.font.pixelSize.small
                    color: barRow.modelData.color
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        color: ColorUtils.applyAlpha(barRow.modelData.color, root.trackAlpha)
                    }

                    Rectangle {
                        width: parent.width * Math.min(1, barRow.modelData.value)
                        height: parent.height
                        radius: Appearance.rounding.verysmall
                        color: barRow.modelData.color
                        opacity: root.fillOpacity

                        Behavior on width {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Easing.InOutCubic }
                        }
                    }
                }

                StyledText {
                    visible: root.showLabels
                    text: Math.round(barRow.modelData.value * 100) + "%"
                    color: ColorUtils.applyAlpha(root.colText, root.fillOpacity)
                    font {
                        pixelSize: Appearance.font.pixelSize.smaller
                        family: Appearance.font.family.numbers
                    }
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 32
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // GRAPH MODE — area fills with legend overlay
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        anchors.margins: root._innerMargin
        opacity: 1.0 - root.dimFactor * 0.6
        visible: root.displayMode === "graph"

        readonly property int _legendH: root.showLabels ? 16 : 0

        Row {
            visible: root.showLabels
            z: 1
            spacing: Appearance.sizes.spacingSmall ?? 4
            anchors { top: parent.top; left: parent.left; margins: 2 }

            Repeater {
                model: root._resourceModel
                Row {
                    required property var modelData
                    spacing: 2
                    MaterialSymbol {
                        text: modelData.icon
                        iconSize: Appearance.font.pixelSize.smaller
                        color: modelData.color
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Math.round(modelData.value * 100) + "%"
                        color: modelData.color
                        font { pixelSize: Appearance.font.pixelSize.smaller; family: Appearance.font.family.numbers }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Y-axis labels
        Repeater {
            model: [
                { pct: 0, label: "0%" },
                { pct: 0.5, label: "50%" },
                { pct: 1.0, label: "100%" }
            ]
            StyledText {
                required property var modelData
                text: modelData.label
                color: ColorUtils.applyAlpha(root.colText, 0.3)
                font { pixelSize: Appearance.font.pixelSize.smaller - 2; family: Appearance.font.family.numbers }
                anchors.right: parent.right
                anchors.rightMargin: 2
                y: parent._legendH + (parent.height - parent._legendH) * (1.0 - modelData.pct) - height / 2
            }
        }

        // Grid lines at 25/50/75%
        Repeater {
            model: [0.25, 0.50, 0.75]
            Rectangle {
                required property real modelData
                anchors { left: parent.left; right: parent.right }
                y: parent._legendH + (parent.height - parent._legendH) * (1.0 - modelData)
                height: 1
                color: ColorUtils.applyAlpha(root.colText, 0.06)
            }
        }

        Graph {
            anchors.fill: parent
            anchors.topMargin: parent._legendH
            values: root.showCpu ? ResourceUsage.cpuUsageHistory : []
            color: root.cpuColor
            fillOpacity: root.graphFillOpacity + 0.05
            alignment: Graph.Alignment.Right
            visible: root.showCpu
        }

        Graph {
            anchors.fill: parent
            anchors.topMargin: parent._legendH
            values: root.showMemory ? ResourceUsage.memoryUsageHistory : []
            color: root.memColor
            fillOpacity: root.graphFillOpacity
            alignment: Graph.Alignment.Right
            visible: root.showMemory
        }

        Graph {
            anchors.fill: parent
            anchors.topMargin: parent._legendH
            values: root.showGpu ? ResourceUsage.gpuUsageHistory : []
            color: root.gpuColor
            fillOpacity: root.graphFillOpacity - 0.05
            alignment: Graph.Alignment.Right
            visible: root.showGpu
        }
    }

    // ══════════════════════════════════════════════════════════
    // RINGS MODE — circular gauges per resource
    // ══════════════════════════════════════════════════════════
    Row {
        anchors.centerIn: parent
        spacing: Appearance.sizes.spacingNormal ?? 8
        opacity: 1.0 - root.dimFactor * 0.6
        visible: root.displayMode === "rings"

        Repeater {
            model: root._resourceModel

            Column {
                id: ringCol
                required property var modelData
                spacing: Appearance.sizes.spacingSmall ?? 4
                readonly property int _ringSize: Math.min(
                    Math.round((root.height - root._innerMargin * 2 - (root.showLabels ? 20 : 0)) * 0.85),
                    Math.round((root.width - root._innerMargin * 2) / Math.max(1, root._resourceModel.length) - (Appearance.sizes.spacingNormal ?? 8))
                )

                Item {
                    width: ringCol._ringSize
                    height: ringCol._ringSize
                    anchors.horizontalCenter: parent.horizontalCenter

                    CircularProgress {
                        anchors.centerIn: parent
                        implicitSize: parent.width
                        lineWidth: Math.max(2, Math.round(parent.width * 0.08))
                        value: ringCol.modelData.value
                        colPrimary: ringCol.modelData.color
                        colSecondary: ColorUtils.applyAlpha(ringCol.modelData.color, root.trackAlpha)

                        Behavior on value {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Easing.InOutCubic }
                        }
                    }

                    // Percentage inside the ring
                    StyledText {
                        anchors.centerIn: parent
                        text: Math.round(ringCol.modelData.value * 100)
                        color: ringCol.modelData.color
                        font {
                            pixelSize: Math.max(10, Math.round(ringCol._ringSize * 0.28))
                            family: Appearance.font.family.numbers
                            weight: Font.DemiBold
                        }
                    }
                }

                // Label below ring
                Row {
                    visible: root.showLabels
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    MaterialSymbol {
                        text: ringCol.modelData.icon
                        iconSize: Appearance.font.pixelSize.smaller
                        color: ColorUtils.applyAlpha(root.colText, 0.6)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: ringCol.modelData.label
                        color: ColorUtils.applyAlpha(root.colText, 0.6)
                        font { pixelSize: Appearance.font.pixelSize.smaller; family: Appearance.font.family.main }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // TEXT MODE — compact numeric readout with chip style
    // ══════════════════════════════════════════════════════════
    Flow {
        anchors.centerIn: parent
        spacing: Appearance.sizes.spacingSmall ?? 4
        opacity: 1.0 - root.dimFactor * 0.6
        visible: root.displayMode === "text"
        width: parent.width - root._innerMargin * 2

        Repeater {
            model: root._resourceModel

            Rectangle {
                id: textChip
                required property var modelData
                width: chipRow.implicitWidth + 12
                height: chipRow.implicitHeight + 8
                radius: Appearance.rounding.small
                color: ColorUtils.applyAlpha(textChip.modelData.color, root.trackAlpha)

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Appearance.sizes.spacingSmall ?? 4

                    MaterialSymbol {
                        text: textChip.modelData.icon
                        iconSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                        color: textChip.modelData.color
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: textChip.modelData.label
                        color: ColorUtils.applyAlpha(root.colText, 0.6)
                        font {
                            pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                            family: Appearance.font.family.main
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: Math.round(textChip.modelData.value * 100) + "%"
                        color: textChip.modelData.color
                        font {
                            pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                            family: Appearance.font.family.numbers
                            weight: Font.DemiBold
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
