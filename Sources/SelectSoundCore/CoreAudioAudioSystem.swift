import CoreAudio
import Foundation

public struct CoreAudioStatusError: Error, CustomStringConvertible {
    public let operation: String
    public let status: OSStatus

    public var description: String {
        "CoreAudio \(operation) failed with status \(status)"
    }
}

public final class CoreAudioAudioSystem: AudioSystem {
    private let systemObjectID = AudioObjectID(kAudioObjectSystemObject)

    public init() {}

    public func inputDevices() throws -> [AudioDevice] {
        try devices(for: .input)
    }

    public func outputDevices() throws -> [AudioDevice] {
        try devices(for: .output)
    }

    public func defaultInputDevice() throws -> AudioDevice? {
        try defaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice, direction: .input)
    }

    public func defaultOutputDevice() throws -> AudioDevice? {
        try defaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice, direction: .output)
    }

    public func setDefaultInputDevice(_ device: AudioDevice) throws {
        try setDefaultDevice(
            device,
            selector: kAudioHardwarePropertyDefaultInputDevice,
            operation: "set default input device"
        )
    }

    public func setDefaultOutputDevice(_ device: AudioDevice) throws {
        try setDefaultDevice(
            device,
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            operation: "set default output device"
        )
    }

    private func devices(for direction: DeviceDirection) throws -> [AudioDevice] {
        let scope: AudioObjectPropertyScope = direction == .input
            ? kAudioDevicePropertyScopeInput
            : kAudioDevicePropertyScopeOutput

        return try allDeviceIDs().compactMap { deviceID in
            guard try isAlive(deviceID),
                  try channelCount(deviceID: deviceID, scope: scope) > 0 else {
                return nil
            }

            return try makeDevice(deviceID: deviceID)
        }
    }

    private func defaultDevice(
        selector: AudioObjectPropertySelector,
        direction: DeviceDirection
    ) throws -> AudioDevice? {
        var address = propertyAddress(selector)
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        try check(
            AudioObjectGetPropertyData(
                systemObjectID,
                &address,
                0,
                nil,
                &dataSize,
                &deviceID
            ),
            operation: "get default \(direction) device"
        )

        guard deviceID != AudioDeviceID(kAudioObjectUnknown) else {
            return nil
        }

        return try makeDevice(deviceID: deviceID)
    }

    private func setDefaultDevice(
        _ device: AudioDevice,
        selector: AudioObjectPropertySelector,
        operation: String
    ) throws {
        var address = propertyAddress(selector)
        var deviceID = AudioDeviceID(device.id)

        try check(
            AudioObjectSetPropertyData(
                systemObjectID,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<AudioDeviceID>.size),
                &deviceID
            ),
            operation: operation
        )
    }

    private func allDeviceIDs() throws -> [AudioDeviceID] {
        var address = propertyAddress(kAudioHardwarePropertyDevices)
        var dataSize: UInt32 = 0

        try check(
            AudioObjectGetPropertyDataSize(systemObjectID, &address, 0, nil, &dataSize),
            operation: "get audio devices size"
        )

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else {
            return []
        }

        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        try deviceIDs.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return
            }
            try check(
                AudioObjectGetPropertyData(
                    systemObjectID,
                    &address,
                    0,
                    nil,
                    &dataSize,
                    baseAddress
                ),
                operation: "get audio devices"
            )
        }

        return deviceIDs
    }

    private func makeDevice(deviceID: AudioDeviceID) throws -> AudioDevice {
        let uid = try stringProperty(
            objectID: deviceID,
            selector: kAudioDevicePropertyDeviceUID,
            operation: "get device UID"
        )
        let name = try stringProperty(
            objectID: deviceID,
            selector: kAudioObjectPropertyName,
            operation: "get device name"
        )
        let isBuiltIn = try isBuiltIn(deviceID)

        return AudioDevice(
            id: UInt32(deviceID),
            uid: uid,
            name: name.isEmpty ? uid : name,
            isBuiltIn: isBuiltIn
        )
    }

    private func isAlive(_ deviceID: AudioDeviceID) throws -> Bool {
        var address = propertyAddress(kAudioDevicePropertyDeviceIsAlive)
        var isAlive: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        try check(
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                &isAlive
            ),
            operation: "get device alive state"
        )

        return isAlive == 1
    }

    private func isBuiltIn(_ deviceID: AudioDeviceID) throws -> Bool {
        var address = propertyAddress(kAudioDevicePropertyTransportType)
        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        try check(
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                &transportType
            ),
            operation: "get device transport type"
        )

        return transportType == kAudioDeviceTransportTypeBuiltIn
    }

    private func stringProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        operation: String
    ) throws -> String {
        var address = propertyAddress(selector)
        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<CFString?>.size,
            alignment: MemoryLayout<CFString?>.alignment
        )
        let valuePointer = rawPointer.bindMemory(to: CFString?.self, capacity: 1)
        valuePointer.initialize(to: nil)
        defer {
            valuePointer.deinitialize(count: 1)
            rawPointer.deallocate()
        }

        var dataSize = UInt32(MemoryLayout<CFString?>.size)

        try check(
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &dataSize,
                rawPointer
            ),
            operation: operation
        )

        guard let value = valuePointer.pointee else {
            return ""
        }
        return value as String
    }

    private func channelCount(
        deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) throws -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0

        try check(
            AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize),
            operation: "get stream configuration size"
        )

        guard dataSize > 0 else {
            return 0
        }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        try check(
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                rawPointer
            ),
            operation: "get stream configuration"
        )

        let bufferList = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.reduce(0) { total, buffer in
            total + Int(buffer.mNumberChannels)
        }
    }

    private func propertyAddress(
        _ selector: AudioObjectPropertySelector
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw CoreAudioStatusError(operation: operation, status: status)
        }
    }
}
