import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "custom.example-widget"
    defaultConfig: ({
        placementStrategy: "free",
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        x: 300, y: 300
    })

    implicitWidth: Math.round(200 * scaleFactor)
    implicitHeight: Math.round(60 * scaleFactor)

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: ColorUtils.applyAlpha(Appearance.colors.colPrimaryContainer, 0.6)
        border { width: 1; color: ColorUtils.applyAlpha(Appearance.colors.colOnPrimaryContainer, 0.1) }

        StyledText {
            anchors.centerIn: parent
            text: "Hello from custom widget!"
            color: Appearance.colors.colOnPrimaryContainer
            font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
        }
    }
}
