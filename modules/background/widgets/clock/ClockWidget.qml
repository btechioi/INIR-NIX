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

    configEntryName: "clock"
    defaultConfig: ({
        placementStrategy: "leastBusy", style: "cookie",
        fontFamily: "Space Grotesk", timeFormat: "system",
        showSeconds: false, showDate: true, dateStyle: "long",
        timeScale: 100, dateScale: 100, showShadow: true, dim: 55,
        "digital.animateChange": true, "digital.fontWeight": 600,
        "digital.spacing": 6, "digital.preset": "default",
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto",
        x: 100, y: 100
    })

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth

    editPopoverContent: Component {
        Item {
            implicitWidth: _clockCol.implicitWidth
            implicitHeight: _clockCol.implicitHeight
            Column {
                id: _clockCol
                spacing: 6
                Row {
                    spacing: 4
                    RippleButton {
                        width: 86; height: 28
                        buttonRadius: Appearance.rounding.small
                        toggled: root.clockStyle === "digital"
                        colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        downAction: () => Config.setNestedValue("background.widgets.clock.style", "digital")
                        contentItem: StyledText { anchors.centerIn: parent; text: "Digital"; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small }
                    }
                    RippleButton {
                        width: 86; height: 28
                        buttonRadius: Appearance.rounding.small
                        toggled: root.clockStyle === "cookie"
                        colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        downAction: () => Config.setNestedValue("background.widgets.clock.style", "cookie")
                        contentItem: StyledText { anchors.centerIn: parent; text: "Cookie"; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small }
                    }
                }
                Row {
                    spacing: 4
                    visible: root.clockStyle === "digital"
                    RippleButton {
                        width: 56; height: 28
                        buttonRadius: Appearance.rounding.small
                        toggled: root.timeFormat === "system"
                        colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        downAction: () => Config.setNestedValue("background.widgets.clock.timeFormat", "system")
                        contentItem: StyledText { anchors.centerIn: parent; text: "Sys"; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small }
                    }
                    RippleButton {
                        width: 56; height: 28
                        buttonRadius: Appearance.rounding.small
                        toggled: root.timeFormat === "24h"
                        colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        downAction: () => Config.setNestedValue("background.widgets.clock.timeFormat", "24h")
                        contentItem: StyledText { anchors.centerIn: parent; text: "24h"; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small }
                    }
                    RippleButton {
                        width: 56; height: 28
                        buttonRadius: Appearance.rounding.small
                        toggled: root.timeFormat === "12h"
                        colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        downAction: () => Config.setNestedValue("background.widgets.clock.timeFormat", "12h")
                        contentItem: StyledText { anchors.centerIn: parent; text: "12h"; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small }
                    }
                }
            }
        }
    }

    property string clockStyle: Config.options?.background?.widgets?.clock?.style ?? "cookie"
    property bool forceCenter: (GlobalStates.screenLocked && (Config.options?.lock?.centerClock ?? false))
    property bool wallpaperSafetyTriggered: false
    needsColText: clockStyle === "digital"
    visibleWhenLocked: true

    // --- Clock customization config ---
    property string clockFontFamily: Config.options?.background?.widgets?.clock?.fontFamily ?? "Space Grotesk"
    property string timeFormat: Config.options?.background?.widgets?.clock?.timeFormat ?? "system"
    property bool showSeconds: Config.options?.background?.widgets?.clock?.showSeconds ?? false
    property bool showDate: Config.options?.background?.widgets?.clock?.showDate ?? true
    property string dateStyle: Config.options?.background?.widgets?.clock?.dateStyle ?? "long"
    property int timeScale: Config.options?.background?.widgets?.clock?.timeScale ?? 100
    property int dateScale: Config.options?.background?.widgets?.clock?.dateScale ?? 100
    property bool showShadow: Config.options?.background?.widgets?.clock?.showShadow ?? true
    property int digitalFontWeight: Config.options?.background?.widgets?.clock?.digital?.fontWeight ?? 600
    property int digitalSpacing: Config.options?.background?.widgets?.clock?.digital?.spacing ?? 6

    // Local clock with seconds precision when needed
    SystemClock {
        id: displayClock
        precision: root.showSeconds || GlobalStates.screenLocked ? SystemClock.Seconds : SystemClock.Minutes
    }

    // --- Resolved format patterns (reactive) ---
    property string _timePattern: {
        const fmt = root.timeFormat;
        const sec = root.showSeconds;
        if (fmt === "24h") return sec ? "HH:mm:ss" : "HH:mm";
        if (fmt === "12h") return sec ? "hh:mm:ss AP" : "hh:mm AP";
        // "system" — use global config format, smart seconds append
        const base = Config.options?.time?.format ?? "hh:mm";
        if (sec && !base.includes("s")) {
            const apIdx = base.indexOf(" AP");
            if (apIdx >= 0) return base.slice(0, apIdx) + ":ss" + base.slice(apIdx);
            return base + ":ss";
        }
        return base;
    }
    property string _datePattern: {
        const style = root.dateStyle;
        if (style === "weekday") return "dddd";
        if (style === "numeric") return Config.options?.time?.shortDateFormat ?? "dd/MM";
        if (style === "minimal") return "ddd, d MMM";
        // "long" or default
        return Config.options?.time?.dateFormat ?? "dddd, dd/MM";
    }

    property string timeText: Qt.locale().toString(displayClock.date, root._timePattern)
    property string dateText: Qt.locale().toString(displayClock.date, root._datePattern)

    Binding {
        target: root
        property: "x"
        value: (root.screenWidth - root.width) / 2
        when: root.forceCenter
    }
    Binding {
        target: root
        property: "y"
        value: (root.screenHeight - root.height) / 2
        when: root.forceCenter
    }

    property var textHorizontalAlignment: {
        if (root.forceCenter)
            return Text.AlignHCenter;
        if (root.x < root.scaledScreenWidth / 3)
            return Text.AlignLeft;
        if (root.x > root.scaledScreenWidth * 2 / 3)
            return Text.AlignRight;
        return Text.AlignHCenter;
    }

    // ── Style tokens ──
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    // Per-clock dim factor (0..1), independent from wallpaper dim
    property real dimFactor: {
        const v = Config.options?.background?.widgets?.clock?.dim ?? 0;
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    // Effective text color for clock based on palette + dim
    property color clockTextColor: {
        const dark = Qt.rgba(0, 0, 0, 1);
        return ColorUtils.mix(root.colText, dark, dimFactor);
    }

    // Card background (mainly for digital mode)
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Math.round(8 * root.scaleFactor)
        radius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        color: root.backgroundOpacity > 0 ? ColorUtils.applyAlpha(root.colText, root.backgroundOpacity) : "transparent"
        border { width: root.borderWidth; color: ColorUtils.applyAlpha(root.colText, root.borderOpacity) }
        visible: (root.backgroundOpacity > 0 || root.borderWidth > 0) && root.clockStyle === "digital"
    }

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: Math.round(6 * root.scaleFactor)

        FadeLoader {
            id: cookieClockLoader
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.clockStyle === "cookie"
            sourceComponent: Column {
                CookieClock {
                    anchors.horizontalCenter: parent.horizontalCenter
                    scaleFactor: root.scaleFactor
                }
                FadeLoader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    shown: (Config.options?.background?.widgets?.clock?.quote?.enable ?? false)
                        && (Config.options?.background?.widgets?.clock?.quote?.text ?? "") !== ""
                    sourceComponent: CookieQuote {}
                }
            }
        }

        FadeLoader {
            id: digitalClockLoader
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.clockStyle === "digital"
            sourceComponent: ColumnLayout {
                id: clockColumn
                spacing: Math.round(root.digitalSpacing * root.scaleFactor)

                ClockText {
                    font.pixelSize: Math.round(90 * Appearance.fontSizeScale * root.timeScale / 100 * root.scaleFactor)
                    text: root.timeText
                }
                ClockText {
                    visible: root.showDate
                    Layout.topMargin: Math.round(-5 * root.scaleFactor)
                    font.pixelSize: Math.round(20 * root.dateScale / 100 * root.scaleFactor)
                    text: root.dateText
                }
                StyledText {
                    // Somehow gets fucked up if made a ClockText???
                    visible: (Config.options?.background?.widgets?.clock?.quote?.enable ?? false)
                        && (Config.options?.background?.widgets?.clock?.quote?.text ?? "").length > 0
                    Layout.fillWidth: true
                    horizontalAlignment: root.textHorizontalAlignment
                    font {
                        pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                        weight: 350
                    }
                    color: root.clockTextColor
                    style: root.showShadow ? Text.Raised : Text.Normal
                    styleColor: Appearance.colors.colShadow
                    text: Config.options?.background?.widgets?.clock?.quote?.text ?? ""
                }
            }
        }
        Item {
            id: statusText
            anchors.horizontalCenter: parent.horizontalCenter
            implicitHeight: statusTextBg.implicitHeight
            implicitWidth: statusTextBg.implicitWidth
            StyledRectangularShadow {
                target: statusTextBg
                visible: statusTextBg.visible && root.clockStyle === "cookie"
                opacity: statusTextBg.opacity
            }
            Rectangle {
                id: statusTextBg
                anchors.centerIn: parent
                clip: true
                opacity: (safetyStatusText.shown || lockStatusText.shown) ? 1 : 0
                visible: opacity > 0
                implicitHeight: statusTextRow.implicitHeight + 5 * 2
                implicitWidth: statusTextRow.implicitWidth + 5 * 2
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, root.clockStyle === "cookie" ? 0 : 1)

                Behavior on implicitWidth {
                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                }
                Behavior on implicitHeight {
                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                }
                Behavior on opacity {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                RowLayout {
                    id: statusTextRow
                    anchors.centerIn: parent
                    spacing: 14
                    Item {
                        Layout.fillWidth: root.textHorizontalAlignment !== Text.AlignLeft
                        implicitWidth: 1
                    }
                    ClockStatusText {
                        id: safetyStatusText
                        shown: root.wallpaperSafetyTriggered
                        statusIcon: "hide_image"
                        statusText: Translation.tr("Wallpaper safety enforced")
                    }
                    ClockStatusText {
                        id: lockStatusText
                        shown: GlobalStates.screenLocked && (Config.options?.lock?.showLockedText ?? false)
                        statusIcon: "lock"
                        statusText: Translation.tr("Locked")
                    }
                    Item {
                        Layout.fillWidth: root.textHorizontalAlignment !== Text.AlignRight
                        implicitWidth: 1
                    }
                }
            }
        }
    }

    component ClockText: StyledText {
        Layout.fillWidth: true
        horizontalAlignment: root.textHorizontalAlignment
        font {
            family: root.clockFontFamily
            pixelSize: 20
            weight: root.digitalFontWeight
        }
        color: root.clockTextColor
        style: root.showShadow ? Text.Raised : Text.Normal
        styleColor: Appearance.colors.colShadow
        animateChange: Config.options?.background?.widgets?.clock?.digital?.animateChange ?? false
    }
    component ClockStatusText: Row {
        id: statusTextRow
        property alias statusIcon: statusIconWidget.text
        property alias statusText: statusTextWidget.text
        property bool shown: true
        property color textColor: {
            const base = root.clockStyle === "cookie" ? Appearance.colors.colOnSecondaryContainer : root.colText;
            const dark = Qt.rgba(0, 0, 0, 1);
            return ColorUtils.mix(base, dark, root.dimFactor);
        }
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        spacing: 4
        MaterialSymbol {
            id: statusIconWidget
            anchors.verticalCenter: statusTextRow.verticalCenter
            iconSize: Appearance.font.pixelSize.huge
            color: statusTextRow.textColor
            style: root.showShadow ? Text.Raised : Text.Normal
            styleColor: Appearance.colors.colShadow
        }
        ClockText {
            id: statusTextWidget
            color: statusTextRow.textColor
            anchors.verticalCenter: statusTextRow.verticalCenter
            font {
                pixelSize: Appearance.font.pixelSize.large
                weight: Font.Normal
            }
            style: root.showShadow ? Text.Raised : Text.Normal
            styleColor: Appearance.colors.colShadow
        }
    }
}
