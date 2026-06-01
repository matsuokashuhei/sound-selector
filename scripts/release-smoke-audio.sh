#!/usr/bin/env bash
set -euo pipefail

helper="$(mktemp -t release-smoke-audio.XXXXXX).swift"
cleanup() {
  rm -f "$helper"
}
trap cleanup EXIT

cat > "$helper" <<'SWIFT'
import CoreAudio
import Foundation

struct Options {
    var mode = "built-in"
    var output = "release-smoke.json"
    var audioSelector: String?
    var fixture: String?
}

struct DeviceInfo: Codable {
    let id: UInt32
    let uid: String
    let name: String
    let isBuiltIn: Bool
    let inputChannels: Int
    let outputChannels: Int
    let canDefaultInput: Bool
    let canDefaultOutput: Bool
}

struct Snapshot: Codable {
    let defaultInput: DeviceInfo?
    let defaultOutput: DeviceInfo?
    let devices: [DeviceInfo]
}

struct CommandResult: Codable {
    let exitCode: Int?
    let stdout: String
    let stderr: String
}

struct RestoreResult: Codable {
    let ok: Bool
    let error: String?
    let snapshot: Snapshot
}

struct SmokeResult: Codable {
    let ok: Bool
    let mode: String
    let fixture: String?
    let audioSelectorCommand: String
    let audioSelectorExitCode: Int?
    let before: Snapshot
    let after: Snapshot
    let restore: RestoreResult
    let command: CommandResult
    let errors: [String]
}

enum SmokeError: Error, CustomStringConvertible {
    case usage(String)
    case coreAudio(String, OSStatus)
    case missingDeviceUID(String)

    var description: String {
        switch self {
        case .usage(let message):
            return message
        case .coreAudio(let operation, let status):
            return "CoreAudio \(operation) failed with status \(status)"
        case .missingDeviceUID(let uid):
            return "Could not find audio device with UID \(uid)"
        }
    }
}

func parseOptions(_ arguments: [String]) throws -> Options {
    var options = Options()
    var index = 0

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--built-in":
            options.mode = "built-in"
        case "--output":
            index += 1
            guard index < arguments.count else {
                throw SmokeError.usage("--output requires a path")
            }
            options.output = arguments[index]
        case "--audio-selector":
            index += 1
            guard index < arguments.count else {
                throw SmokeError.usage("--audio-selector requires a command path")
            }
            options.audioSelector = arguments[index]
        case "--fixture":
            index += 1
            guard index < arguments.count else {
                throw SmokeError.usage("--fixture requires a fixture name")
            }
            options.fixture = arguments[index]
        case "--help", "-h":
            print("""
            Usage:
              scripts/release-smoke-audio.sh --built-in [--output release-smoke.json] [--audio-selector path]

            Runs the real-device release smoke test and restores the original input/output defaults.
            """)
            exit(0)
        default:
            throw SmokeError.usage("Unknown argument: \(argument)")
        }
        index += 1
    }

    guard options.mode == "built-in" else {
        throw SmokeError.usage("Unsupported mode: \(options.mode)")
    }

    return options
}

func write(_ result: SmokeResult, to path: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(result)
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url)
}

func makeDevice(
    id: UInt32,
    uid: String,
    name: String,
    isBuiltIn: Bool,
    inputChannels: Int,
    outputChannels: Int,
    canDefaultInput: Bool,
    canDefaultOutput: Bool
) -> DeviceInfo {
    DeviceInfo(
        id: id,
        uid: uid,
        name: name,
        isBuiltIn: isBuiltIn,
        inputChannels: inputChannels,
        outputChannels: outputChannels,
        canDefaultInput: canDefaultInput,
        canDefaultOutput: canDefaultOutput
    )
}

func fixtureResult(named fixture: String, options: Options) throws -> SmokeResult {
    let builtInInput = makeDevice(
        id: 1,
        uid: "builtin-input",
        name: "MacBook Pro Microphone",
        isBuiltIn: true,
        inputChannels: 1,
        outputChannels: 0,
        canDefaultInput: true,
        canDefaultOutput: false
    )
    let builtInOutput = makeDevice(
        id: 2,
        uid: "builtin-output",
        name: "MacBook Pro Speakers",
        isBuiltIn: true,
        inputChannels: 0,
        outputChannels: 2,
        canDefaultInput: false,
        canDefaultOutput: true
    )
    let openMeetInput = makeDevice(
        id: 3,
        uid: "openmeet-input",
        name: "OpenMeet by Shokz",
        isBuiltIn: false,
        inputChannels: 1,
        outputChannels: 0,
        canDefaultInput: true,
        canDefaultOutput: false
    )
    let externalOutput = makeDevice(
        id: 4,
        uid: "external-output",
        name: "LG ULTRAWIDE",
        isBuiltIn: false,
        inputChannels: 0,
        outputChannels: 2,
        canDefaultInput: false,
        canDefaultOutput: true
    )

    let allDevices = [builtInInput, builtInOutput, openMeetInput, externalOutput]
    let before = Snapshot(defaultInput: openMeetInput, defaultOutput: externalOutput, devices: allDevices)
    let restored = Snapshot(defaultInput: openMeetInput, defaultOutput: externalOutput, devices: allDevices)

    switch fixture {
    case "success":
        let after = Snapshot(defaultInput: builtInInput, defaultOutput: builtInOutput, devices: allDevices)
        return SmokeResult(
            ok: true,
            mode: options.mode,
            fixture: fixture,
            audioSelectorCommand: options.audioSelector ?? "fixture-audio-selector",
            audioSelectorExitCode: 0,
            before: before,
            after: after,
            restore: RestoreResult(ok: true, error: nil, snapshot: restored),
            command: CommandResult(exitCode: 0, stdout: "Applied devices:\n", stderr: ""),
            errors: []
        )
    case "external-reselection":
        let after = Snapshot(defaultInput: openMeetInput, defaultOutput: builtInOutput, devices: allDevices)
        let errors = [
            "audio-selector --built-in exited with 1",
            "Default audio input is not built-in after smoke command. Current device: OpenMeet by Shokz"
        ]
        return SmokeResult(
            ok: false,
            mode: options.mode,
            fixture: fixture,
            audioSelectorCommand: options.audioSelector ?? "fixture-audio-selector",
            audioSelectorExitCode: 1,
            before: before,
            after: after,
            restore: RestoreResult(ok: true, error: nil, snapshot: restored),
            command: CommandResult(
                exitCode: 1,
                stdout: "",
                stderr: "The audio input device did not change to \"MacBook Pro Microphone\". Current device: \"OpenMeet by Shokz\"."
            ),
            errors: errors
        )
    case "no-built-in-input":
        let devices = [builtInOutput, openMeetInput, externalOutput]
        let snapshot = Snapshot(defaultInput: openMeetInput, defaultOutput: externalOutput, devices: devices)
        return SmokeResult(
            ok: false,
            mode: options.mode,
            fixture: fixture,
            audioSelectorCommand: options.audioSelector ?? "fixture-audio-selector",
            audioSelectorExitCode: nil,
            before: snapshot,
            after: snapshot,
            restore: RestoreResult(ok: true, error: nil, snapshot: snapshot),
            command: CommandResult(exitCode: nil, stdout: "", stderr: ""),
            errors: ["No built-in audio input device found."]
        )
    case "no-built-in-output":
        let devices = [builtInInput, openMeetInput, externalOutput]
        let snapshot = Snapshot(defaultInput: openMeetInput, defaultOutput: externalOutput, devices: devices)
        return SmokeResult(
            ok: false,
            mode: options.mode,
            fixture: fixture,
            audioSelectorCommand: options.audioSelector ?? "fixture-audio-selector",
            audioSelectorExitCode: nil,
            before: snapshot,
            after: snapshot,
            restore: RestoreResult(ok: true, error: nil, snapshot: snapshot),
            command: CommandResult(exitCode: nil, stdout: "", stderr: ""),
            errors: ["No built-in audio output device found."]
        )
    default:
        throw SmokeError.usage("Unknown fixture: \(fixture)")
    }
}

func propertyAddress(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
}

func check(_ status: OSStatus, operation: String) throws {
    guard status == noErr else {
        throw SmokeError.coreAudio(operation, status)
    }
}

func stringProperty(
    objectID: AudioObjectID,
    selector: AudioObjectPropertySelector
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
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, rawPointer),
        operation: "get string property"
    )
    return (valuePointer.pointee as String?) ?? ""
}

func uint32Property(
    objectID: AudioObjectID,
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) throws -> UInt32 {
    var address = propertyAddress(selector, scope: scope)
    var value: UInt32 = 0
    var dataSize = UInt32(MemoryLayout<UInt32>.size)
    try check(
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value),
        operation: "get UInt32 property"
    )
    return value
}

func channelCount(
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
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, rawPointer),
        operation: "get stream configuration"
    )

    let bufferList = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
    return UnsafeMutableAudioBufferListPointer(bufferList).reduce(0) { total, buffer in
        total + Int(buffer.mNumberChannels)
    }
}

func allDeviceIDs() throws -> [AudioDeviceID] {
    let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
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

func deviceInfo(for deviceID: AudioDeviceID) throws -> DeviceInfo {
    let uid = try stringProperty(objectID: deviceID, selector: kAudioDevicePropertyDeviceUID)
    let name = try stringProperty(objectID: deviceID, selector: kAudioObjectPropertyName)
    let transportType = try uint32Property(
        objectID: deviceID,
        selector: kAudioDevicePropertyTransportType
    )
    let inputChannels = (try? channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput)) ?? 0
    let outputChannels = (try? channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput)) ?? 0
    let canDefaultInput = ((try? uint32Property(
        objectID: deviceID,
        selector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
        scope: kAudioDevicePropertyScopeInput
    )) ?? 0) == 1
    let canDefaultOutput = ((try? uint32Property(
        objectID: deviceID,
        selector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
        scope: kAudioDevicePropertyScopeOutput
    )) ?? 0) == 1

    return DeviceInfo(
        id: UInt32(deviceID),
        uid: uid,
        name: name.isEmpty ? uid : name,
        isBuiltIn: transportType == kAudioDeviceTransportTypeBuiltIn,
        inputChannels: inputChannels,
        outputChannels: outputChannels,
        canDefaultInput: canDefaultInput,
        canDefaultOutput: canDefaultOutput
    )
}

func defaultDeviceID(selector: AudioObjectPropertySelector) throws -> AudioDeviceID? {
    let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
    var address = propertyAddress(selector)
    var deviceID = AudioDeviceID(kAudioObjectUnknown)
    var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    try check(
        AudioObjectGetPropertyData(systemObjectID, &address, 0, nil, &dataSize, &deviceID),
        operation: "get default device"
    )

    guard deviceID != AudioDeviceID(kAudioObjectUnknown) else {
        return nil
    }
    return deviceID
}

func snapshot() throws -> Snapshot {
    let devices = try allDeviceIDs().compactMap { deviceID -> DeviceInfo? in
        guard ((try? uint32Property(
            objectID: deviceID,
            selector: kAudioDevicePropertyDeviceIsAlive
        )) ?? 0) == 1 else {
            return nil
        }
        return try deviceInfo(for: deviceID)
    }

    let defaultInputID = try defaultDeviceID(selector: kAudioHardwarePropertyDefaultInputDevice)
    let defaultOutputID = try defaultDeviceID(selector: kAudioHardwarePropertyDefaultOutputDevice)
    let defaultInput = defaultInputID.flatMap { id in devices.first { $0.id == UInt32(id) } }
    let defaultOutput = defaultOutputID.flatMap { id in devices.first { $0.id == UInt32(id) } }

    return Snapshot(defaultInput: defaultInput, defaultOutput: defaultOutput, devices: devices)
}

func deviceID(withUID uid: String) throws -> AudioDeviceID {
    for deviceID in try allDeviceIDs() {
        let deviceUID = try stringProperty(objectID: deviceID, selector: kAudioDevicePropertyDeviceUID)
        if deviceUID == uid {
            return deviceID
        }
    }
    throw SmokeError.missingDeviceUID(uid)
}

func setDefaultDevice(
    uid: String,
    selector: AudioObjectPropertySelector
) throws {
    let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
    var address = propertyAddress(selector)
    var deviceID = try deviceID(withUID: uid)
    try check(
        AudioObjectSetPropertyData(
            systemObjectID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceID
        ),
        operation: "set default device"
    )
}

func restoreDefaults(inputUID: String?, outputUID: String?) -> RestoreResult {
    do {
        if let inputUID {
            try setDefaultDevice(uid: inputUID, selector: kAudioHardwarePropertyDefaultInputDevice)
        }
        if let outputUID {
            try setDefaultDevice(uid: outputUID, selector: kAudioHardwarePropertyDefaultOutputDevice)
        }
        usleep(300_000)
        let restored = try snapshot()
        let inputMatches = inputUID == nil || restored.defaultInput?.uid == inputUID
        let outputMatches = outputUID == nil || restored.defaultOutput?.uid == outputUID
        let ok = inputMatches && outputMatches
        let error = ok ? nil : "Restored defaults do not match original defaults."
        return RestoreResult(ok: ok, error: error, snapshot: restored)
    } catch {
        let fallbackSnapshot = (try? snapshot()) ?? Snapshot(defaultInput: nil, defaultOutput: nil, devices: [])
        return RestoreResult(ok: false, error: String(describing: error), snapshot: fallbackSnapshot)
    }
}

func defaultAudioSelectorCommand(_ explicit: String?) -> String {
    if let explicit {
        return explicit
    }

    let releasePath = ".build/release/audio-selector"
    if FileManager.default.isExecutableFile(atPath: releasePath) {
        return releasePath
    }

    let debugPath = ".build/debug/audio-selector"
    if FileManager.default.isExecutableFile(atPath: debugPath) {
        return debugPath
    }

    return "audio-selector"
}

func runAudioSelector(_ command: String) -> CommandResult {
    let process = Process()
    if command.contains("/") {
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = ["--built-in"]
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command, "--built-in"]
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return CommandResult(exitCode: nil, stdout: "", stderr: String(describing: error))
    }

    let stdout = String(
        data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    let stderr = String(
        data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""

    return CommandResult(exitCode: Int(process.terminationStatus), stdout: stdout, stderr: stderr)
}

func smoke(options: Options) throws -> SmokeResult {
    if let fixture = options.fixture {
        return try fixtureResult(named: fixture, options: options)
    }

    let before = try snapshot()
    let originalInputUID = before.defaultInput?.uid
    let originalOutputUID = before.defaultOutput?.uid
    var errors: [String] = []

    let hasBuiltInInput = before.devices.contains { device in
        device.isBuiltIn && device.inputChannels > 0 && device.canDefaultInput
    }
    let hasBuiltInOutput = before.devices.contains { device in
        device.isBuiltIn && device.outputChannels > 0 && device.canDefaultOutput
    }

    let audioSelector = defaultAudioSelectorCommand(options.audioSelector)
    var command = CommandResult(exitCode: nil, stdout: "", stderr: "")

    if !hasBuiltInInput {
        errors.append("No built-in audio input device found.")
    }
    if !hasBuiltInOutput {
        errors.append("No built-in audio output device found.")
    }

    if errors.isEmpty {
        command = runAudioSelector(audioSelector)
    }

    usleep(300_000)
    let after = try snapshot()

    if let exitCode = command.exitCode, exitCode != 0 {
        errors.append("audio-selector --built-in exited with \(exitCode).")
    } else if command.exitCode == nil && errors.isEmpty {
        errors.append("audio-selector --built-in could not be started.")
    }

    if command.exitCode == 0 {
        if after.defaultInput?.isBuiltIn != true {
            let current = after.defaultInput?.name ?? "none"
            errors.append("Default audio input is not built-in after smoke command. Current device: \(current)")
        }
        if after.defaultOutput?.isBuiltIn != true {
            let current = after.defaultOutput?.name ?? "none"
            errors.append("Default audio output is not built-in after smoke command. Current device: \(current)")
        }
    }

    let restore = restoreDefaults(inputUID: originalInputUID, outputUID: originalOutputUID)
    if !restore.ok {
        errors.append(restore.error ?? "Could not restore original audio defaults.")
    }

    return SmokeResult(
        ok: errors.isEmpty && restore.ok,
        mode: options.mode,
        fixture: nil,
        audioSelectorCommand: audioSelector,
        audioSelectorExitCode: command.exitCode,
        before: before,
        after: after,
        restore: restore,
        command: command,
        errors: errors
    )
}

do {
    let options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
    let result = try smoke(options: options)
    try write(result, to: options.output)
    exit(result.ok ? 0 : 1)
} catch {
    let options = (try? parseOptions(Array(CommandLine.arguments.dropFirst()))) ?? Options()
    let empty = Snapshot(defaultInput: nil, defaultOutput: nil, devices: [])
    let result = SmokeResult(
        ok: false,
        mode: options.mode,
        fixture: options.fixture,
        audioSelectorCommand: options.audioSelector ?? "",
        audioSelectorExitCode: nil,
        before: empty,
        after: empty,
        restore: RestoreResult(ok: false, error: nil, snapshot: empty),
        command: CommandResult(exitCode: nil, stdout: "", stderr: ""),
        errors: [String(describing: error)]
    )
    try? write(result, to: options.output)
    fputs("\(error)\n", stderr)
    exit(1)
}
SWIFT

swift "$helper" "$@"
