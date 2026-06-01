# Release Checklist

Run these checks before creating a version tag or updating the Homebrew tap.

```sh
swift test
swift build -c release
swift run audio-selector --version
scripts/release-smoke-audio.sh --built-in
```

The audio smoke test intentionally runs on the release operator's Mac instead of GitHub Actions. It changes the default audio input/output, verifies that `--built-in` remains applied after CoreAudio settles, writes `release-smoke.json`, and restores the original defaults before exiting.

If `scripts/release-smoke-audio.sh --built-in` fails, stop the release. The failure usually means the local audio environment or a device driver reselected a different default device after `audio-selector` tried to apply the built-in devices.

After the tag exists, update the Homebrew tap and verify it:

```sh
brew audit --strict audio-selector
brew fetch --formula audio-selector
brew upgrade audio-selector
audio-selector --version
```
