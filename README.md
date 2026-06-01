# audio-selector

`audio-selector` は、macOS の音声入力デバイスと通常の音声出力デバイスをキーボードで選ぶためのCLIです。

## 使い方

```sh
audio-selector
```

1. 音声入力デバイスを番号で選びます。
2. 音声出力デバイスを番号で選びます。
3. 選択内容を確認します。
4. 確認画面で Enter を押すと設定を反映します。Esc を押すとキャンセルです。

各デバイス選択では、Enter で現在のデバイスを維持できます。`q` または Ctrl-C でキャンセルできます。

内蔵の音声入力デバイスと音声出力デバイスへすぐに切り替える場合は、非対話モードを使えます。

```sh
audio-selector --built-in
audio-selector -b
```

よく使う外部デバイスも、ショートカット設定を作ると非対話で切り替えられます。

```sh
mkdir -p ~/.config/audio-selector
$EDITOR ~/.config/audio-selector/shortcuts.json
```

```json
{
  "shortcuts": {
    "1": "AirPods",
    "2": "Bose CP",
    "3": "Shokz OpenMeet"
  }
}
```

```sh
audio-selector -1
audio-selector -2
audio-selector -3
```

ショートカットのデバイス名は、大文字小文字を区別せず、空白区切りの単語がすべて含まれるデバイスに一致します。例えば `Shokz OpenMeet` は `OpenMeet by Shokz` に一致します。入力側または出力側で一致しない場合や、複数のデバイスに一致する場合は、設定を変更せずにエラーで終了します。

このツールは通常の音声出力デバイスだけを変更します。システム効果音や通知音の出力先は変更しません。

## インストール

必要環境: macOS 15 以降、Swift 6.0 以降。

### Homebrew

```sh
brew tap matsuokashuhei/audio-selector
brew install audio-selector
```

### SwiftPM

```sh
swift build -c release
install .build/release/audio-selector /usr/local/bin/audio-selector
```

## Raycast

Raycast 画面内で完結するUIではなく、Raycast から Terminal.app を開いて `audio-selector` を実行します。

`raycast/audio-selector.sh` を Raycast Script Commands のディレクトリにコピーし、実行権限を付けて使います。

```sh
chmod +x raycast/audio-selector.sh
```

## 開発

```sh
swift test
swift run audio-selector --version
```

自動テストでは CoreAudio を fake 化しており、実際のMac音声設定は変更しません。

リリース前には、tag 作成と Homebrew tap 更新の前に実機 smoke test を実行します。

```sh
swift build -c release
scripts/release-smoke-audio.sh --built-in
```

この smoke test は現在の音声入力/出力を保存し、`--built-in` が実機で安定して反映されるか確認してから元の設定へ戻します。詳細は [Release Checklist](docs/release-checklist.md) を参照してください。

## English usage

`audio-selector` is a macOS-only CLI for selecting the default audio input device and the normal audio output device by keyboard.

```sh
audio-selector
```

Press Enter to keep the current device during input/output selection. Enter `q` or press Ctrl-C to cancel. On the confirmation screen, Enter applies the selected devices and Esc cancels.

Use `audio-selector --built-in` or `audio-selector -b` to immediately apply the built-in audio input and output devices without prompts.

Create `~/.config/audio-selector/shortcuts.json` to define shortcut options for frequently used devices:

```json
{
  "shortcuts": {
    "1": "AirPods",
    "2": "Bose CP",
    "3": "Shokz OpenMeet"
  }
}
```

Then run `audio-selector -1`, `audio-selector -2`, or `audio-selector -3`. Shortcut matching is case-insensitive and requires every whitespace-separated token to appear in the device name, so `Shokz OpenMeet` matches `OpenMeet by Shokz`. If the input or output side has no match or multiple matches, no audio settings are changed.
