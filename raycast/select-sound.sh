#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Select Sound
# @raycast.mode silent
# @raycast.packageName Sound Selector
# @raycast.description Open select-sound in Terminal.app

osascript <<'APPLESCRIPT'
tell application "Terminal"
  activate
  do script "select-sound"
end tell
APPLESCRIPT
