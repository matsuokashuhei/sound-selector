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

このツールは通常の音声出力デバイスだけを変更します。システム効果音や通知音の出力先は変更しません。

## インストール

必要環境: macOS 15 以降、Swift 6.0 以降。

### Homebrew

```sh
brew install matsuokashuhei/audio-selector/audio-selector
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

## English usage

`audio-selector` is a macOS-only CLI for selecting the default audio input device and the normal audio output device by keyboard.

```sh
audio-selector
```

Press Enter to keep the current device during input/output selection. Enter `q` or press Ctrl-C to cancel. On the confirmation screen, Enter applies the selected devices and Esc cancels.
