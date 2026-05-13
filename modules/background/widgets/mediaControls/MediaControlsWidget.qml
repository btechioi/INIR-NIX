pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import qs.services
import qs
import qs.modules.common.functions
import qs.modules.background.widgets
import qs.modules.mediaControls.presets

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

AbstractBackgroundWidget {
    id: root

    configEntryName: "mediaControls"
    defaultConfig: ({
        placementStrategy: "leastBusy", playerPreset: "full",
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        x: 100, y: 100
    })

    readonly property real widgetWidth: Math.round(Appearance.sizes.mediaControlsWidth * scaleFactor)
    readonly property real widgetHeight: Math.round(Appearance.sizes.mediaControlsHeight * scaleFactor)
    property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

    editPopoverContent: Component {
        Item {
            implicitWidth: 200
            implicitHeight: _mediaFlow.implicitHeight
            Flow {
                id: _mediaFlow
                width: parent.width
                spacing: 4
                Repeater {
                    model: [{ label: "Full", value: "full" }, { label: "Compact", value: "compact" }, { label: "Minimal", value: "minimal" }, { label: "Album", value: "albumart" }, { label: "Viz", value: "visualizer" }, { label: "Classic", value: "classic" }]
                    RippleButton {
                        required property var modelData
                        width: 62; height: 28
                        buttonRadius: Appearance.rounding.small
                        toggled: root.selectedPreset === modelData.value
                        colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        downAction: () => Config.setNestedValue("background.widgets.mediaControls.playerPreset", modelData.value)
                        contentItem: StyledText { anchors.centerIn: parent; text: modelData.label; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small }
                    }
                }
            }
        }
    }

    // Use MprisController.displayPlayers - centralized filtering
    readonly property var meaningfulPlayers: MprisController.displayPlayers

    implicitWidth: widgetWidth
    implicitHeight: playerColumnLayout.implicitHeight

    readonly property bool visualizerActive: (Config.options?.background?.widgets?.mediaControls?.enable ?? false)
        && (root.meaningfulPlayers?.length ?? 0) > 0

    CavaProcess {
        id: cavaProcess
        active: root.visualizerActive
    }

    property list<real> visualizerPoints: cavaProcess.points

    // Dim factor (0..1)
    property real dimFactor: {
        const v = Config.options?.background?.widgets?.mediaControls?.dim ?? 0;
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    readonly property point widgetScreenPos: root.mapToItem(null, 0, 0)
    
    // Get selected preset component
    readonly property string selectedPreset: Config.options?.background?.widgets?.mediaControls?.playerPreset ?? "full"
    readonly property Component presetComponent: {
        switch (selectedPreset) {
            case "compact": return compactPlayerComponent
            case "minimal": return minimalPlayerComponent
            case "albumart": return albumArtPlayerComponent
            case "visualizer": return visualizerPlayerComponent
            case "classic": return classicPlayerComponent
            case "full":
            default: return fullPlayerComponent
        }
    }
    
    // Preset components
    Component {
        id: fullPlayerComponent
        FullPlayer {}
    }
    
    Component {
        id: compactPlayerComponent
        CompactPlayer {}
    }
    
    Component {
        id: minimalPlayerComponent
        MinimalPlayer {}
    }
    
    Component {
        id: albumArtPlayerComponent
        AlbumArtPlayer {}
    }
    
    Component {
        id: visualizerPlayerComponent
        VisualizerPlayer {}
    }
    
    Component {
        id: classicPlayerComponent
        ClassicPlayer {}
    }

    ColumnLayout {
        id: playerColumnLayout
        anchors.fill: parent
        spacing: -Appearance.sizes.elevationMargin
        opacity: 1.0 - root.dimFactor * 0.6

        Repeater {
            model: ScriptModel {
                values: root.meaningfulPlayers
            }
            delegate: Loader {
                required property MprisPlayer modelData
                sourceComponent: root.presetComponent
                Layout.preferredWidth: root.widgetWidth
                Layout.preferredHeight: root.widgetHeight
                
                onLoaded: {
                    item.player = modelData
                    item.visualizerPoints = Qt.binding(() => root.visualizerPoints)
                    item.radius = root.popupRounding
                    item.screenX = Qt.binding(() => root.widgetScreenPos.x)
                    item.screenY = Qt.binding(() => root.widgetScreenPos.y)
                }
            }
        }

        Item {
            Layout.fillWidth: true
            visible: root.meaningfulPlayers.length === 0
            implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
            implicitHeight: placeholderBackground.implicitHeight + Appearance.sizes.elevationMargin

            StyledRectangularShadow {
                target: placeholderBackground
                visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere)
            }

            Rectangle {
                id: placeholderBackground
                anchors.centerIn: parent
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface
                     : Appearance.colors.colLayer0
                radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : root.popupRounding
                border.width: Appearance.inirEverywhere || Appearance.auroraEverywhere ? 1 : 0
                border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
                            : "transparent"
                property real padding: 20
                implicitWidth: placeholderLayout.implicitWidth + padding * 2
                implicitHeight: placeholderLayout.implicitHeight + padding * 2

                ColumnLayout {
                    id: placeholderLayout
                    anchors.centerIn: parent

                    StyledText {
                        text: Translation.tr("No active player")
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.inirEverywhere ? Appearance.inir.colText
                            : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                            : Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                            : Appearance.auroraEverywhere ? Appearance.aurora.colTextSecondary
                            : Appearance.colors.colSubtext
                        text: Translation.tr("Make sure your player has MPRIS support\nor try turning off duplicate player filtering")
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
