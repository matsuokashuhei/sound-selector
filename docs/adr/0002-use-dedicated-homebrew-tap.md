# Use a dedicated Homebrew tap

The Homebrew formula for `select-sound` will live in a separate public tap repository, `matsuokashuhei/homebrew-sound-selector`, instead of the main source repository. A formula stored in the same repository cannot safely point at that repository's own tagged GitHub archive because the formula's `sha256` would be part of the archive it is trying to verify, so the tap keeps distribution metadata separate from source code.
