import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    // Connessione ai cambiamenti delle finestre
    Connections {
        target: Hyprland.toplevels
        
        function onValuesChanged() {
            dock.updateWindowList()
        }
    }

    PanelWindow {
        id: dock
        
        property var windowList: []
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
            interval: 500 // Attendi 500ms prima di nascondere
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
        
        // Aggiorna la lista delle finestre
        function updateWindowList() {
            var allWindows = []
            
            if (Hyprland.toplevels && Hyprland.toplevels.values) {
                for (var i = 0; i < Hyprland.toplevels.values.length; i++) {
                    var win = Hyprland.toplevels.values[i]
                    // Mostra tutte le finestre, incluse quelle nascoste (id === -99)
                    allWindows.push(win)
                }
            }
            
            windowList = allWindows
            windowRepeater.model = allWindows
        }
        
        Component.onCompleted: {
            updateWindowList()
        }
        
        // Timer per aggiornamento periodico (fallback)
        Timer {
            interval: 2000 // Aggiorna ogni 2 secondi
            running: true
            repeat: true
            onTriggered: {
                dock.updateWindowList()
            }
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
                    model: []
                    
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        
                        width: 48
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
                            source: modelData && modelData.lastIpcObject ? dock.getAppIcon(modelData.lastIpcObject.class) : ""
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
        
        function getAppIcon(appClass) {
            if (!appClass) return ""
            
            var iconMap = {
                "firefox": "/usr/share/icons/hicolor/48x48/apps/firefox.png",
                "firefox-esr": "/usr/share/icons/hicolor/48x48/apps/firefox-esr.png",
                "chromium": "/usr/share/icons/hicolor/48x48/apps/chromium.png",
                "google-chrome": "/usr/share/icons/hicolor/48x48/apps/google-chrome.png",
                "brave-browser": "/usr/share/icons/hicolor/48x48/apps/brave-browser.png",
                "kitty": "/usr/share/icons/hicolor/48x48/apps/kitty.png",
                "alacritty": "/usr/share/icons/hicolor/48x48/apps/Alacritty.png",
                "wezterm": "/usr/share/icons/hicolor/48x48/apps/wezterm.png",
                "code": "/usr/share/icons/hicolor/48x48/apps/code.png",
                "vscodium": "/usr/share/icons/hicolor/48x48/apps/vscodium.png",
                "org.kde.dolphin": "/usr/share/icons/hicolor/48x48/apps/dolphin.png",
                "org.gnome.nautilus": "/usr/share/icons/hicolor/48x48/apps/nautilus.png",
                "thunar": "/usr/share/icons/hicolor/48x48/apps/thunar.png",
                "discord": "/usr/share/icons/hicolor/48x48/apps/discord.png",
                "spotify": "/usr/share/icons/hicolor/48x48/apps/spotify.png",
                "slack": "/usr/share/icons/hicolor/48x48/apps/slack.png",
                "telegram-desktop": "/usr/share/icons/hicolor/48x48/apps/telegram.png",
                "gimp-2.10": "/usr/share/icons/hicolor/48x48/apps/gimp.png",
                "inkscape": "/usr/share/icons/hicolor/48x48/apps/inkscape.png",
                "com.obsproject.studio": "/usr/share/icons/hicolor/48x48/apps/obs.png",
                "vlc": "/usr/share/icons/hicolor/48x48/apps/vlc.png",
                "org.keepassxc.keepassxc": "/usr/share/icons/hicolor/48x48/apps/keepassxc.png",
                "thunderbird": "/usr/share/icons/hicolor/48x48/apps/thunderbird.png"
            }
            
            return iconMap[appClass.toLowerCase()] || ""
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
