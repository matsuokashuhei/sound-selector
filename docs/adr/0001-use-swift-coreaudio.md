# Use Swift and CoreAudio for macOS audio control

The `select-sound` command will be implemented as a native Swift CLI that talks to CoreAudio directly. This avoids requiring users to install a separate audio-switching command, keeps the tool aligned with macOS system APIs, and makes device listing and default-device changes part of the same codebase.
