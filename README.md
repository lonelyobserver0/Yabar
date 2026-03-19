# Yabar - A dock for Hyprland
It is an application bar with dynamic width and auto-hide, it can hide window.  
Being a QML file you can use in C application or with tool like [`quickshell`](https://git.outfoxxed.me/quickshell/quickshell)

# Setup
To use with quickshell just copy `shell.qml` into `~/.config/quickshell/yabar` and start it with `quickshell --config yabar`.
You can add icons to app just by modifying `iconMap` variable in the code.

# To use
Dock will appaer when you move the mouse on the bootom border of the screen. When you click an icon its app window will hide to return with a second click.
