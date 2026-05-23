import Darwin
import Foundation

enum AppVersion {
    static let current = "0.1.2"
}

enum ConfirmationKey: Equatable {
    case enter
    case escape
    case other

    init(byte: UInt8) {
        switch byte {
        case 10, 13:
            self = .enter
        case 27:
            self = .escape
        default:
            self = .other
        }
    }
}

enum SelectSoundCommandError: Error {
    case cancelled
    case invalidArgument(String)
    case noDevices(DeviceDirection)
    case selectedDeviceUnavailable(DeviceDirection, AudioDevice)
    case applyFailed(cause: Error, rollbackFailures: [String])
}

public final class SelectSoundCommand {
    private let audioSystem: AudioSystem
    private let strings: LocalizedStrings
    private let readInput: () -> String?
    private let readConfirmationKey: () -> ConfirmationKey?
    private let writeOutput: (String) -> Void
    private let flushOutput: () -> Void
    private let writeErrorOutput: (String) -> Void

    public init(
        audioSystem: AudioSystem,
        language: AppLanguage = .current(),
        readInput: @escaping () -> String? = { Swift.readLine() },
        writeOutput: @escaping (String) -> Void = { text in print(text, terminator: "") },
        writeErrorOutput: @escaping (String) -> Void = { text in
            if let data = text.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
        }
    ) {
        self.audioSystem = audioSystem
        self.strings = LocalizedStrings(language: language)
        self.readInput = readInput
        self.readConfirmationKey = Self.readConfirmationKeyFromStandardInput
        self.writeOutput = writeOutput
        self.flushOutput = { fflush(stdout) }
        self.writeErrorOutput = writeErrorOutput
    }

    init(
        audioSystem: AudioSystem,
        language: AppLanguage = .current(),
        readInput: @escaping () -> String? = { Swift.readLine() },
        readConfirmationKey: @escaping () -> ConfirmationKey?,
        writeOutput: @escaping (String) -> Void = { text in print(text, terminator: "") },
        flushOutput: @escaping () -> Void = { fflush(stdout) },
        writeErrorOutput: @escaping (String) -> Void = { text in
            if let data = text.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
        }
    ) {
        self.audioSystem = audioSystem
        self.strings = LocalizedStrings(language: language)
        self.readInput = readInput
        self.readConfirmationKey = readConfirmationKey
        self.writeOutput = writeOutput
        self.flushOutput = flushOutput
        self.writeErrorOutput = writeErrorOutput
    }

    public func run(arguments: [String]) -> Int32 {
        do {
            try runThrowing(arguments: arguments)
            return 0
        } catch SelectSoundCommandError.cancelled {
            writeLine(strings.cancelled)
            return 0
        } catch {
            writeErrorLine(strings.error(message(for: error)))
            return 1
        }
    }

    private func runThrowing(arguments: [String]) throws {
        if arguments.count == 1 {
            switch arguments[0] {
            case "--help", "-h":
                writeOutput(strings.help)
                return
            case "--version":
                writeLine("select-sound \(AppVersion.current)")
                return
            default:
                throw SelectSoundCommandError.invalidArgument(arguments[0])
            }
        }

        guard arguments.isEmpty else {
            throw SelectSoundCommandError.invalidArgument(arguments[0])
        }

        let inputDevices = try audioSystem.inputDevices()
        let outputDevices = try audioSystem.outputDevices()
        guard !inputDevices.isEmpty else {
            throw SelectSoundCommandError.noDevices(.input)
        }
        guard !outputDevices.isEmpty else {
            throw SelectSoundCommandError.noDevices(.output)
        }

        let currentInput = try audioSystem.defaultInputDevice()
        let currentOutput = try audioSystem.defaultOutputDevice()

        let selectedInput = try selectDevice(
            direction: .input,
            devices: inputDevices,
            currentDevice: currentInput
        )
        let selectedOutput = try selectDevice(
            direction: .output,
            devices: outputDevices,
            currentDevice: currentOutput
        )

        guard try confirm(
            selectedInput: selectedInput,
            inputDevices: inputDevices,
            selectedOutput: selectedOutput,
            outputDevices: outputDevices
        ) else {
            throw SelectSoundCommandError.cancelled
        }

        try apply(selectedInput: selectedInput, selectedOutput: selectedOutput)
    }

    private func selectDevice(
        direction: DeviceDirection,
        devices: [AudioDevice],
        currentDevice: AudioDevice?
    ) throws -> AudioDevice {
        let orderedDevices = ordered(devices: devices, currentDevice: currentDevice)
        let selectableCurrentDevice = currentDevice.flatMap { current in
            orderedDevices.first(withUID: current.uid)
        }

        while true {
            writeLine(strings.listTitle(direction))
            for (index, device) in orderedDevices.enumerated() {
                var line = "  \(index + 1). \(displayName(for: device, among: orderedDevices))"
                if selectableCurrentDevice?.uid == device.uid {
                    line += " (\(strings.currentMarker))"
                }
                writeLine(line)
            }
            writePrompt(strings.prompt(hasCurrentDevice: selectableCurrentDevice != nil))

            guard let rawInput = readInput() else {
                throw SelectSoundCommandError.cancelled
            }

            let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if input.lowercased() == "q" {
                throw SelectSoundCommandError.cancelled
            }

            if input.isEmpty {
                if let selectableCurrentDevice {
                    return selectableCurrentDevice
                }
                writeLine(strings.currentDeviceUnavailable)
                continue
            }

            if let selection = Int(input),
               orderedDevices.indices.contains(selection - 1) {
                return orderedDevices[selection - 1]
            }

            writeLine(strings.invalidSelection)
        }
    }

    private func confirm(
        selectedInput: AudioDevice,
        inputDevices: [AudioDevice],
        selectedOutput: AudioDevice,
        outputDevices: [AudioDevice]
    ) throws -> Bool {
        writeLine(strings.confirmationTitle)
        writeLine("\(strings.inputLabel): \(displayName(for: selectedInput, among: inputDevices))")
        writeLine("\(strings.outputLabel): \(displayName(for: selectedOutput, among: outputDevices))")
        writePrompt(strings.confirmationPrompt)

        while true {
            guard let key = readConfirmationKey() else {
                writeLine()
                return false
            }

            switch key {
            case .enter:
                writeLine()
                return true
            case .escape:
                writeLine()
                return false
            case .other:
                continue
            }
        }
    }

    private func apply(selectedInput: AudioDevice, selectedOutput: AudioDevice) throws {
        let originalInput = try audioSystem.defaultInputDevice()
        let originalOutput = try audioSystem.defaultOutputDevice()

        let latestInputs = try audioSystem.inputDevices()
        let latestOutputs = try audioSystem.outputDevices()

        guard let freshInput = latestInputs.first(withUID: selectedInput.uid) else {
            throw SelectSoundCommandError.selectedDeviceUnavailable(.input, selectedInput)
        }
        guard let freshOutput = latestOutputs.first(withUID: selectedOutput.uid) else {
            throw SelectSoundCommandError.selectedDeviceUnavailable(.output, selectedOutput)
        }

        if originalInput?.uid == freshInput.uid, originalOutput?.uid == freshOutput.uid {
            writeLine(strings.noChanges)
            return
        }

        var changedDevices: [(direction: DeviceDirection, original: AudioDevice?)] = []

        do {
            if originalInput?.uid != freshInput.uid {
                try audioSystem.setDefaultInputDevice(freshInput)
                changedDevices.append((.input, originalInput))
            }

            if originalOutput?.uid != freshOutput.uid {
                try audioSystem.setDefaultOutputDevice(freshOutput)
                changedDevices.append((.output, originalOutput))
            }
        } catch {
            let rollbackFailures = rollback(changedDevices: changedDevices)
            throw SelectSoundCommandError.applyFailed(cause: error, rollbackFailures: rollbackFailures)
        }

        writeLine(strings.appliedTitle)
        writeLine("\(strings.inputLabel): \(displayName(for: freshInput, among: latestInputs))")
        writeLine("\(strings.outputLabel): \(displayName(for: freshOutput, among: latestOutputs))")
    }

    private func rollback(changedDevices: [(direction: DeviceDirection, original: AudioDevice?)]) -> [String] {
        var failures: [String] = []

        for changedDevice in changedDevices.reversed() {
            guard let original = changedDevice.original else {
                failures.append("No original \(strings.deviceName(changedDevice.direction)) was available")
                continue
            }

            do {
                switch changedDevice.direction {
                case .input:
                    try audioSystem.setDefaultInputDevice(original)
                case .output:
                    try audioSystem.setDefaultOutputDevice(original)
                }
            } catch {
                failures.append("\(strings.deviceName(changedDevice.direction)): \(String(describing: error))")
            }
        }

        return failures
    }

    private func ordered(devices: [AudioDevice], currentDevice: AudioDevice?) -> [AudioDevice] {
        let sortedDevices = devices.sorted {
            let leftName = $0.name.localizedCaseInsensitiveCompare($1.name)
            if leftName == .orderedSame {
                return $0.uid < $1.uid
            }
            return leftName == .orderedAscending
        }

        guard let currentDevice,
              let current = sortedDevices.first(withUID: currentDevice.uid) else {
            return sortedDevices
        }

        return [current] + sortedDevices.filter { $0.uid != current.uid }
    }

    private func displayName(for device: AudioDevice, among devices: [AudioDevice]) -> String {
        let duplicates = devices.filter { $0.name == device.name }
        guard duplicates.count > 1 else {
            return device.name
        }
        return "\(device.name) (\(strings.duplicateSuffix(uid: device.uid)))"
    }

    private func message(for error: Error) -> String {
        switch error {
        case SelectSoundCommandError.invalidArgument(let argument):
            return strings.unknownArgument(argument)
        case SelectSoundCommandError.noDevices(let direction):
            return strings.noDevices(direction)
        case SelectSoundCommandError.selectedDeviceUnavailable(let direction, let device):
            return strings.selectedDeviceUnavailable(direction, name: device.name)
        case SelectSoundCommandError.applyFailed(let cause, let rollbackFailures):
            return strings.applyFailed(cause: String(describing: cause), rollbackFailures: rollbackFailures)
        case SelectSoundCommandError.cancelled:
            return strings.cancelled
        default:
            return String(describing: error)
        }
    }

    private func writeLine(_ line: String = "") {
        writeOutput("\(line)\n")
    }

    private func writePrompt(_ prompt: String) {
        writeOutput(prompt)
        flushOutput()
    }

    private func writeErrorLine(_ line: String) {
        writeErrorOutput("\(line)\n")
    }

    private static func readConfirmationKeyFromStandardInput() -> ConfirmationKey? {
        let fileDescriptor = STDIN_FILENO

        guard isatty(fileDescriptor) == 1 else {
            return readConfirmationKey(from: fileDescriptor)
        }

        var originalAttributes = termios()
        guard tcgetattr(fileDescriptor, &originalAttributes) == 0 else {
            return readConfirmationKey(from: fileDescriptor)
        }

        var rawAttributes = originalAttributes
        rawAttributes.c_lflag &= ~tcflag_t(ICANON)
        rawAttributes.c_lflag &= ~tcflag_t(ECHO)
        withUnsafeMutableBytes(of: &rawAttributes.c_cc) { controlCharacters in
            controlCharacters[Int(VMIN)] = 1
            controlCharacters[Int(VTIME)] = 0
        }

        guard tcsetattr(fileDescriptor, TCSANOW, &rawAttributes) == 0 else {
            return readConfirmationKey(from: fileDescriptor)
        }
        defer {
            _ = tcsetattr(fileDescriptor, TCSANOW, &originalAttributes)
        }

        return readConfirmationKey(from: fileDescriptor)
    }

    private static func readConfirmationKey(from fileDescriptor: Int32) -> ConfirmationKey? {
        guard let byte = readByte(from: fileDescriptor) else {
            return nil
        }

        let key = ConfirmationKey(byte: byte)
        guard key == .escape else {
            return key
        }

        if hasPendingInput(on: fileDescriptor, timeoutMilliseconds: 25) {
            drainPendingInput(from: fileDescriptor)
            return .other
        }

        return .escape
    }

    private static func readByte(from fileDescriptor: Int32) -> UInt8? {
        var byte: UInt8 = 0
        let bytesRead = Darwin.read(fileDescriptor, &byte, 1)
        guard bytesRead == 1 else {
            return nil
        }
        return byte
    }

    private static func drainPendingInput(from fileDescriptor: Int32) {
        while hasPendingInput(on: fileDescriptor, timeoutMilliseconds: 0) {
            guard readByte(from: fileDescriptor) != nil else {
                return
            }
        }
    }

    private static func hasPendingInput(on fileDescriptor: Int32, timeoutMilliseconds: Int32) -> Bool {
        var descriptor = pollfd(fd: fileDescriptor, events: Int16(POLLIN), revents: 0)
        let result = poll(&descriptor, nfds_t(1), timeoutMilliseconds)
        return result > 0 && (descriptor.revents & Int16(POLLIN)) != 0
    }
}
