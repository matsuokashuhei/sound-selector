#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Audio Selector
# @raycast.mode silent
# @raycast.packageName Audio Selector
# @raycast.description Open audio-selector in Terminal.app

osascript <<'APPLESCRIPT'
tell application "Terminal"
  activate
  do script "audio-selector"
end tell
APPLESCRIPT
