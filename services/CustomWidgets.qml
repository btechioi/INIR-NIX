pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    // Discovered custom widgets: [{ id, name, icon, qmlPath, dirPath, ... }]
    property list<var> widgets: []
    readonly property bool ready: _scanDone
    readonly property string widgetsDir: `${Directories.configPath}/inir/widgets`

    property bool _scanDone: false

    Component.onCompleted: _scan()

    function reload(): void {
        root._scanDone = false;
        root.widgets = [];
        _scan();
    }

    function _scan(): void {
        _scanProcess.running = true;
    }

    // Single process that finds and reads all manifests, outputs JSON array
    Process {
        id: _scanProcess
        command: [Directories.scriptsPath + "/scan-widgets.sh", root.widgetsDir]
        running: false

        stdout: StdioCollector {
            id: _scanCollector
            onStreamFinished: {
                const output = (_scanCollector.text ?? "").trim();
                root._parseResults(output || "[]");
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !root._scanDone) {
                root._scanDone = true;
            }
        }
    }

    function _parseResults(jsonStr: string): void {
        try {
            const entries = JSON.parse(jsonStr);
            const result = [];
            for (const entry of entries) {
                const m = entry.manifest;
                const qmlFile = m.main || (entry.id.charAt(0).toUpperCase() + entry.id.slice(1) + ".qml");
                result.push({
                    id: entry.id,
                    name: m.name || entry.id,
                    icon: m.icon || "widgets",
                    version: m.version || "1.0",
                    author: m.author || "",
                    qmlPath: `file://${entry.dir}/${qmlFile}`,
                    dirPath: entry.dir,
                    configKeys: m.configKeys || {},
                    resizableAxes: m.resizableAxes || {},
                    defaultSize: m.defaultSize || { width: 200, height: 100 }
                });
            }
            root.widgets = result;
        } catch (e) {
            console.warn("[CustomWidgets] Failed to parse manifests:", e);
        }
        root._scanDone = true;
    }

    IpcHandler {
        target: "customWidgets"

        function reload(): string {
            root.reload();
            return "Reloading custom widgets...";
        }

        function list(): string {
            return JSON.stringify(root.widgets.map(w => ({ id: w.id, name: w.name, path: w.dirPath })), null, 2);
        }
    }
}
