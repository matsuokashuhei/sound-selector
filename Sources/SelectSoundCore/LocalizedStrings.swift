import Foundation

public enum AppLanguage {
    case japanese
    case english

    public static func current() -> AppLanguage {
        if Locale.current.language.languageCode?.identifier == "ja" {
            return .japanese
        }
        return .english
    }
}

struct LocalizedStrings {
    let language: AppLanguage

    func deviceName(_ direction: DeviceDirection) -> String {
        switch (language, direction) {
        case (.japanese, .input):
            return "音声入力デバイス"
        case (.japanese, .output):
            return "音声出力デバイス"
        case (.english, .input):
            return "audio input device"
        case (.english, .output):
            return "audio output device"
        }
    }

    func listTitle(_ direction: DeviceDirection) -> String {
        switch language {
        case .japanese:
            return "\(deviceName(direction))を選択してください:"
        case .english:
            return "Select an \(deviceName(direction)):"
        }
    }

    func prompt(hasCurrentDevice: Bool) -> String {
        switch (language, hasCurrentDevice) {
        case (.japanese, true):
            return "番号を入力してください（Enter=現在のまま、q=キャンセル）: "
        case (.japanese, false):
            return "番号を入力してください（q=キャンセル）: "
        case (.english, true):
            return "Enter a number (Enter=keep current, q=cancel): "
        case (.english, false):
            return "Enter a number (q=cancel): "
        }
    }

    var currentMarker: String {
        switch language {
        case .japanese:
            return "現在"
        case .english:
            return "current"
        }
    }

    var invalidSelection: String {
        switch language {
        case .japanese:
            return "無効な選択です。もう一度入力してください。"
        case .english:
            return "Invalid selection. Try again."
        }
    }

    var currentDeviceUnavailable: String {
        switch language {
        case .japanese:
            return "現在のデバイスを維持できません。番号を選んでください。"
        case .english:
            return "The current device cannot be kept. Choose a number."
        }
    }

    var confirmationTitle: String {
        switch language {
        case .japanese:
            return "選択内容:"
        case .english:
            return "Selected devices:"
        }
    }

    var inputLabel: String {
        switch language {
        case .japanese:
            return "入力"
        case .english:
            return "Input"
        }
    }

    var outputLabel: String {
        switch language {
        case .japanese:
            return "出力"
        case .english:
            return "Output"
        }
    }

    var confirmationPrompt: String {
        switch language {
        case .japanese:
            return "[Enter] OK  [Esc] キャンセル: "
        case .english:
            return "[Enter] OK  [Esc] Cancel: "
        }
    }

    var cancelled: String {
        switch language {
        case .japanese:
            return "キャンセルしました。"
        case .english:
            return "Cancelled."
        }
    }

    var noChanges: String {
        switch language {
        case .japanese:
            return "変更はありません。"
        case .english:
            return "No changes."
        }
    }

    var appliedTitle: String {
        switch language {
        case .japanese:
            return "設定しました:"
        case .english:
            return "Applied devices:"
        }
    }

    func noDevices(_ direction: DeviceDirection) -> String {
        switch language {
        case .japanese:
            return "選択可能な\(deviceName(direction))がありません。"
        case .english:
            return "No selectable \(deviceName(direction))s found."
        }
    }

    func noBuiltInDevice(_ direction: DeviceDirection) -> String {
        switch language {
        case .japanese:
            return "内蔵\(deviceName(direction))が見つかりません。"
        case .english:
            return "No built-in \(deviceName(direction)) found."
        }
    }

    func selectedDeviceUnavailable(_ direction: DeviceDirection, name: String) -> String {
        switch language {
        case .japanese:
            return "選択した\(deviceName(direction))「\(name)」は現在利用できません。"
        case .english:
            return "The selected \(deviceName(direction)) \"\(name)\" is no longer available."
        }
    }

    func duplicateSuffix(uid: String) -> String {
        switch language {
        case .japanese:
            return "UID: \(uid)"
        case .english:
            return "UID: \(uid)"
        }
    }

    func unknownArgument(_ argument: String) -> String {
        switch language {
        case .japanese:
            return "不明な引数です: \(argument)"
        case .english:
            return "Unknown argument: \(argument)"
        }
    }

    func error(_ message: String) -> String {
        switch language {
        case .japanese:
            return "エラー: \(message)"
        case .english:
            return "Error: \(message)"
        }
    }

    func applyFailed(cause: String, rollbackFailures: [String]) -> String {
        switch language {
        case .japanese:
            if rollbackFailures.isEmpty {
                return "設定に失敗しました。元の設定へ戻しました。原因: \(cause)"
            }
            return "設定に失敗し、元の設定へ戻す処理にも失敗しました。原因: \(cause)。復旧エラー: \(rollbackFailures.joined(separator: "; "))"
        case .english:
            if rollbackFailures.isEmpty {
                return "Could not apply the selected devices. Restored the previous settings. Cause: \(cause)"
            }
            return "Could not apply the selected devices, and rollback also failed. Cause: \(cause). Rollback errors: \(rollbackFailures.joined(separator: "; "))"
        }
    }

    var help: String {
        switch language {
        case .japanese:
            return """
            \(AppCommand.name) \(AppVersion.current)

            macOS の音声入力デバイスと通常の音声出力デバイスを番号で選択します。

            使い方:
              \(AppCommand.name)
              \(AppCommand.name) --built-in
              \(AppCommand.name) -b
              \(AppCommand.name) --help
              \(AppCommand.name) --version

            オプション:
              --built-in, -b  内蔵の音声入力デバイスと音声出力デバイスを選択してすぐに反映

            操作:
              Enter  現在のデバイスを維持
              q      キャンセル
              Enter  確認画面でOK
              Esc    確認画面でキャンセル

            """
        case .english:
            return """
            \(AppCommand.name) \(AppVersion.current)

            Select the macOS audio input device and normal audio output device by number.

            Usage:
              \(AppCommand.name)
              \(AppCommand.name) --built-in
              \(AppCommand.name) -b
              \(AppCommand.name) --help
              \(AppCommand.name) --version

            Options:
              --built-in, -b  Apply the built-in audio input and output devices

            Controls:
              Enter  Keep the current device
              q      Cancel
              Enter  OK on the confirmation screen
              Esc    Cancel on the confirmation screen

            """
        }
    }
}
