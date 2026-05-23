public protocol AudioSystem {
    func inputDevices() throws -> [AudioDevice]
    func outputDevices() throws -> [AudioDevice]
    func defaultInputDevice() throws -> AudioDevice?
    func defaultOutputDevice() throws -> AudioDevice?
    func setDefaultInputDevice(_ device: AudioDevice) throws
    func setDefaultOutputDevice(_ device: AudioDevice) throws
}
