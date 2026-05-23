import Foundation

public struct AudioDevice: Equatable, Hashable, Sendable {
    public let id: UInt32
    public let uid: String
    public let name: String

    public init(id: UInt32, uid: String, name: String) {
        self.id = id
        self.uid = uid
        self.name = name
    }
}

enum DeviceDirection: Sendable {
    case input
    case output
}

extension Array where Element == AudioDevice {
    func first(withUID uid: String) -> AudioDevice? {
        first { $0.uid == uid }
    }
}
