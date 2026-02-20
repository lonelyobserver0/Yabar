import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ShellRoot {
    // Ascolta gli eventi Hyprland per aggiornare la lista delle finestre
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            var n = event.name
            if (n.endsWith("v2")) return

            if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels()
                Hyprland.refreshWorkspaces()
            } else if (n.includes("window") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels()
            }
        }
    }

    PanelWindow {
        id: dock

        property var hiddenWindowsWorkspaces: ({}) // Mappa address -> workspace ID originale
        property bool isVisible: false
        
        anchors {
            bottom: true
            left: true
            right: true
        }
        
        margins {
            bottom: 0
        }
        
        implicitHeight: isVisible ? 60 : 5 // Solo 5px quando nascosto per la zona sensibile
        
        color: "transparent"
        
        exclusionMode: ExclusionMode.Ignore // Non riserva spazio
        exclusiveZone: 0 // Non riserva zona esclusiva
        
        // Area sensibile per mostrare il dock
        MouseArea {
            anchors.fill: parent
            anchors.bottomMargin: -20 // Estendi l'area oltre il bordo
            hoverEnabled: true
            propagateComposedEvents: true // Permetti click sui bottoni
            
            onEntered: {
                dock.isVisible = true
                hideTimer.stop()
            }
            
            onExited: {
                // Delay prima di nascondere
                hideTimer.restart()
            }
            
            onPressed: mouse.accepted = false // Passa i click ai figli
        }
        
        // Timer per nascondere il dock con delay
        Timer {
            id: hideTimer
            interval: 200 // Attendi 200ms prima di nascondere
            onTriggered: {
                dock.isVisible = false
            }
        }
        
        Behavior on margins.bottom {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        
        // Funzione helper per verificare se una finestra è valida
        function isValidWindow(win) {
            return win && win.lastIpcObject && win.lastIpcObject.class && win.lastIpcObject.class !== ""
        }
        
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(appRow.implicitWidth + 20, 100)
            height: 60
            visible: dock.isVisible
            opacity: dock.isVisible ? 1 : 0
            color: "#131317"
            radius: 15
            border.color: "#33ffffff"
            border.width: 1
            
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            
            // MouseArea per mantenere il dock visibile quando mouse è sopra il contenuto
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
                
                onEntered: {
                    dock.isVisible = true
                    hideTimer.stop()
                }
                
                onExited: {
                    hideTimer.restart()
                }
                
                onPressed: mouse.accepted = false
            }
            
            Text {
                anchors.centerIn: parent
                text: "Dock"
                color: "#666666"
                font.pixelSize: 14
                visible: windowRepeater.count === 0
            }
            
            RowLayout {
                id: appRow
                anchors.centerIn: parent
                spacing: 10
                
                Repeater {
                    id: windowRepeater
                    model: Hyprland.toplevels

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        // Filtra finestre senza class
                        property bool validWindow: dock.isValidWindow(modelData)
                        visible: validWindow
                        width: validWindow ? 48 : 0
                        height: 48
                        color: "transparent"
                        radius: 8
                        border.color: modelData && modelData.activated ? "#ffffff" : "transparent"
                        border.width: modelData && modelData.activated ? 2 : 0
                        
                        Image {
                            id: appIcon
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            // Riferimento esplicito a desktopIconMap per rendere il binding reattivo
                            source: modelData && modelData.lastIpcObject ? dock.getAppIcon(modelData.lastIpcObject.class, dock.desktopIconMap) : ""
                            smooth: true
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (!modelData || !modelData.lastIpcObject || !modelData.lastIpcObject.class) return "?"
                                return modelData.lastIpcObject.class.substring(0, 2).toUpperCase()
                            }
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                            visible: appIcon.status !== Image.Ready
                        }
                        
                        // Indicatore finestra nascosta
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: 4
                            width: 4
                            height: 4
                            radius: 2
                            color: "#ffaa00"
                            visible: modelData && modelData.workspace && modelData.workspace.id < 0
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData) {
                                    dock.toggleWindow(modelData)
                                }
                            }
                            hoverEnabled: true
                            
                            onEntered: parent.scale = 1.15
                            onExited: parent.scale = 1.0
                        }
                        
                        Behavior on scale {
                            NumberAnimation { 
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Behavior on border.width {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }
            }
        }
        
        property var desktopIconMap: ({})

        function getAppIcon(appClass, iconMap) {
            if (!appClass) return ""
            var key = appClass.toLowerCase()
            // Usa il nome icona dal .desktop file se disponibile, altrimenti il nome della classe
            var iconName = iconMap[key] || key
            return Quickshell.iconPath(iconName)
        }

        // Costruisci mappa class→icon dai .desktop files all'avvio
        Process {
            id: iconScanner
            running: true
            command: ["sh", "-c", "for f in /usr/share/applications/*.desktop ~/.local/share/applications/*.desktop; do [ -f \"$f\" ] || continue; icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2); wmc=$(grep -m1 '^StartupWMClass=' \"$f\" | cut -d= -f2); name=$(basename \"$f\" .desktop); [ -n \"$icon\" ] && echo \"$name|$wmc|$icon\"; done"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = text.trim().split("\n")
                    var map = {}
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].split("|")
                        if (parts.length < 3 || !parts[2]) continue
                        var name = parts[0].toLowerCase()
                        var wmclass = parts[1].toLowerCase()
                        var icon = parts[2]
                        map[name] = icon
                        if (wmclass) map[wmclass] = icon
                    }
                    dock.desktopIconMap = map
                }
            }
        }
        
        function toggleWindow(window) {
            if (!window || !window.workspace) return
            
            var addr = "address:0x" + window.address
            
            if (window.workspace.id < 0) {
                // Finestra nascosta (workspace speciale negativo), riportala al workspace originale
                var originalWs = hiddenWindowsWorkspaces[window.address]
                
                if (originalWs !== undefined) {
                    // Riporta al workspace originale
                    Hyprland.dispatch("movetoworkspacesilent " + originalWs + "," + addr)
                    Hyprland.dispatch("focuswindow " + addr)
                    
                    // Rimuovi dalla mappa
                    delete hiddenWindowsWorkspaces[window.address]
                    hiddenWindowsWorkspaces = hiddenWindowsWorkspaces // Trigger update
                } else {
                    // Fallback: riporta al workspace corrente
                    var currentWs = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
                    Hyprland.dispatch("movetoworkspacesilent " + currentWs + "," + addr)
                    Hyprland.dispatch("focuswindow " + addr)
                }
            } else {
                // Finestra visibile (attiva o no), salvare il workspace e nasconderla
                hiddenWindowsWorkspaces[window.address] = window.workspace.id
                hiddenWindowsWorkspaces = hiddenWindowsWorkspaces // Trigger update
                
                Hyprland.dispatch("movetoworkspacesilent special:hidden," + addr)
            }
        }
    }
}
