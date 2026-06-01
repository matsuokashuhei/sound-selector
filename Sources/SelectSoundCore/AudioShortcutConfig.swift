import Foundation

struct AudioShortcutConfig: Decodable, Equatable {
    let shortcuts: [String: String]

    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/audio-selector/shortcuts.json")
    }

    static func loadDefault() throws -> AudioShortcutConfig {
        try load(from: defaultURL)
    }

    static func load(from url: URL) throws -> AudioShortcutConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioShortcutConfigError.missingConfig(url)
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AudioShortcutConfig.self, from: data)
        } catch {
            throw AudioShortcutConfigError.invalidConfig(url, error.localizedDescription)
        }
    }

    init(shortcuts: [String: String]) {
        self.shortcuts = shortcuts
    }
}

enum AudioShortcutConfigError: Error {
    case missingConfig(URL)
    case invalidConfig(URL, String)
}
