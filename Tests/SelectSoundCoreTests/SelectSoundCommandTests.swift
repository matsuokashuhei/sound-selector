import XCTest
@testable import SelectSoundCore

final class SelectSoundCommandTests: XCTestCase {
    func testKeepsCurrentDevicesWhenUserPressesEnterAndReportsNoChanges() {
        let fake = FakeAudioSystem()

        let result = runCommand(fake: fake, input: ["", ""], confirmationKeys: [.enter])

        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.stdout.contains("No changes."))
        XCTAssertEqual(fake.setInputHistory, [])
        XCTAssertEqual(fake.setOutputHistory, [])
    }

    func testAppliesSelectedInputAndOutputAfterEnterConfirmation() {
        let fake = FakeAudioSystem()

        let result = runCommand(fake: fake, input: ["2", "2"], confirmationKeys: [.enter])

        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.stdout.contains("Applied devices:"))
        XCTAssertEqual(fake.defaultInput?.uid, "input-2")
        XCTAssertEqual(fake.defaultOutput?.uid, "output-2")
        XCTAssertEqual(fake.setInputHistory, ["input-2"])
        XCTAssertEqual(fake.setOutputHistory, ["output-2"])
    }

    func testInvalidSelectionRepromptsOnSameList() {
        let fake = FakeAudioSystem()

        let result = runCommand(fake: fake, input: ["99", "2", ""], confirmationKeys: [.enter])

        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.stdout.contains("Invalid selection. Try again."))
        XCTAssertEqual(fake.defaultInput?.uid, "input-2")
        XCTAssertEqual(fake.defaultOutput?.uid, "output-1")
    }

    func testConfirmationCancelDoesNotApplyChanges() {
        let fake = FakeAudioSystem()

        let result = runCommand(fake: fake, input: ["2", "2"], confirmationKeys: [.escape])

        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.stdout.contains("Cancelled."))
        XCTAssertEqual(fake.defaultInput?.uid, "input-1")
        XCTAssertEqual(fake.defaultOutput?.uid, "output-1")
        XCTAssertEqual(fake.setInputHistory, [])
        XCTAssertEqual(fake.setOutputHistory, [])
    }

    func testConfirmationIgnoresOtherKeysUntilEnterOrEscape() {
        let fake = FakeAudioSystem()

        let result = runCommand(fake: fake, input: ["2", "2"], confirmationKeys: [.other, .enter])

        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.stdout.contains("Applied devices:"))
        XCTAssertEqual(fake.defaultInput?.uid, "input-2")
        XCTAssertEqual(fake.defaultOutput?.uid, "output-2")
        XCTAssertEqual(fake.setInputHistory, ["input-2"])
        XCTAssertEqual(fake.setOutputHistory, ["output-2"])
    }

    func testBuiltInOptionAppliesBuiltInDevicesWithoutPrompting() {
        let fake = FakeAudioSystem()
        fake.defaultInput = fake.inputs[1]
        fake.defaultOutput = fake.outputs[1]

        let result = runCommand(fake: fake, input: [], arguments: ["--built-in"])

        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.stdout.contains("Applied devices:"))
        XCTAssertFalse(result.stdout.contains("Select an audio input device:"))
        XCTAssertFalse(result.stdout.contains("Selected devices:"))
        XCTAssertEqual(fake.defaultInput?.uid, "input-1")
        XCTAssertEqual(fake.defaultOutput?.uid, "output-1")
        XCTAssertEqual(fake.setInputHistory, ["input-1"])
        XCTAssertEqual(fake.setOutputHistory, ["output-1"])
    }

    func testBuiltInShortOptionAppliesBuiltInDevicesWithoutPrompting() {
        let fake = FakeAudioSystem()
        fake.defaultInput = fake.inputs[1]
        fake.defaultOutput = fake.outputs[1]

        let result = runCommand(fake: fake, input: [], arguments: ["-b"])

        XCTAssertEqual(result.code, 0)
        XCTAssertEqual(fake.defaultInput?.uid, "input-1")
        XCTAssertEqual(fake.defaultOutput?.uid, "output-1")
        XCTAssertEqual(fake.setInputHistory, ["input-1"])
        XCTAssertEqual(fake.setOutputHistory, ["output-1"])
    }

    func testBuiltInOptionErrorsWhenBuiltInInputIsMissing() {
        let fake = FakeAudioSystem()
        fake.inputs = [
            AudioDevice(id: 2, uid: "input-2", name: "USB Microphone", isBuiltIn: false)
        ]
        fake.defaultInput = fake.inputs[0]

        let result = runCommand(fake: fake, input: [], arguments: ["--built-in"])

        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.stderr.contains("No built-in audio input device found."))
        XCTAssertEqual(fake.setInputHistory, [])
        XCTAssertEqual(fake.setOutputHistory, [])
    }

    func testBuiltInOptionErrorsWhenBuiltInOutputIsMissing() {
        let fake = FakeAudioSystem()
        fake.outputs = [
            AudioDevice(id: 12, uid: "output-2", name: "USB Speakers", isBuiltIn: false)
        ]
        fake.defaultOutput = fake.outputs[0]

        let result = runCommand(fake: fake, input: [], arguments: ["--built-in"])

        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.stderr.contains("No built-in audio output device found."))
        XCTAssertEqual(fake.setInputHistory, [])
        XCTAssertEqual(fake.setOutputHistory, [])
    }

    func testConfirmationPromptIsFlushedBeforeWaitingForKey() {
        let fake = FakeAudioSystem()
        var remainingInput = ["", ""]
        var remainingConfirmationKeys: [ConfirmationKey] = [.escape]
        var events: [String] = []
        let confirmationPrompt = LocalizedStrings(language: .english).confirmationPrompt

        let command = SelectSoundCommand(
            audioSystem: fake,
            language: .english,
            readInput: {
                events.append("readInput")
                return remainingInput.removeFirst()
            },
            readConfirmationKey: {
                events.append("readConfirmationKey")
                return remainingConfirmationKeys.removeFirst()
            },
            writeOutput: { text in
                if text == confirmationPrompt {
                    events.append("confirmationPrompt")
                }
            },
            flushOutput: {
                events.append("flushOutput")
            },
            writeErrorOutput: { _ in }
        )

        XCTAssertEqual(command.run(arguments: []), 0)
        guard let promptIndex = events.firstIndex(of: "confirmationPrompt"),
              let flushIndex = events[promptIndex...].firstIndex(of: "flushOutput"),
              let readKeyIndex = events.firstIndex(of: "readConfirmationKey") else {
            XCTFail("Expected confirmation prompt, flush, and key read events")
            return
        }

        XCTAssertLessThan(promptIndex, flushIndex)
        XCTAssertLessThan(flushIndex, readKeyIndex)
    }

    func testConfirmationKeyMapsOnlyEnterAndEscape() {
        XCTAssertEqual(ConfirmationKey(byte: 10), .enter)
        XCTAssertEqual(ConfirmationKey(byte: 13), .enter)
        XCTAssertEqual(ConfirmationKey(byte: 27), .escape)
        XCTAssertEqual(ConfirmationKey(byte: 49), .other)
        XCTAssertEqual(ConfirmationKey(byte: 111), .other)
        XCTAssertEqual(ConfirmationKey(byte: 107), .other)
    }

    func testErrorsWhenInputDevicesAreMissing() {
        let fake = FakeAudioSystem()
        fake.inputs = []
        fake.defaultInput = nil

        let result = runCommand(fake: fake, input: [])

        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.stderr.contains("No selectable audio input devices found."))
    }

    func testRollsBackInputWhenOutputApplyFails() {
        let fake = FakeAudioSystem()
        fake.outputError = FakeAudioError.failed

        let result = runCommand(fake: fake, input: ["2", "2"], confirmationKeys: [.enter])

        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.stderr.contains("Could not apply the selected devices"))
        XCTAssertEqual(fake.defaultInput?.uid, "input-1")
        XCTAssertEqual(fake.defaultOutput?.uid, "output-1")
        XCTAssertEqual(fake.setInputHistory, ["input-2", "input-1"])
        XCTAssertEqual(fake.setOutputHistory, ["output-2"])
    }

    func testDuplicateNamesIncludeUIDs() {
        let fake = FakeAudioSystem()
        fake.inputs = [
            AudioDevice(id: 1, uid: "input-1", name: "USB Audio"),
            AudioDevice(id: 3, uid: "input-3", name: "USB Audio")
        ]
        fake.defaultInput = fake.inputs[0]

        let result = runCommand(fake: fake, input: ["", ""], confirmationKeys: [.enter])

        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.stdout.contains("USB Audio (UID: input-1)"))
        XCTAssertTrue(result.stdout.contains("USB Audio (UID: input-3)"))
    }

    func testVersionDoesNotTouchAudioSystem() {
        let fake = FakeAudioSystem()

        let result = runCommand(fake: fake, input: [], arguments: ["--version"])

        XCTAssertEqual(result.code, 0)
        XCTAssertEqual(result.stdout, "audio-selector 0.1.4\n")
        XCTAssertEqual(fake.inputDevicesCalls, 0)
        XCTAssertEqual(fake.outputDevicesCalls, 0)
    }

    func testHelpUsesAudioSelectorCommandName() {
        let fake = FakeAudioSystem()

        let result = runCommand(fake: fake, input: [], arguments: ["--help"])

        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.stdout.contains("audio-selector --version"))
        XCTAssertTrue(result.stdout.contains("audio-selector --built-in"))
        XCTAssertTrue(result.stdout.contains("audio-selector -b"))
        XCTAssertEqual(fake.inputDevicesCalls, 0)
        XCTAssertEqual(fake.outputDevicesCalls, 0)
    }

    private func runCommand(
        fake: FakeAudioSystem,
        input: [String],
        confirmationKeys: [ConfirmationKey] = [],
        arguments: [String] = []
    ) -> (code: Int32, stdout: String, stderr: String) {
        var remainingInput = input
        var remainingConfirmationKeys = confirmationKeys
        var stdout = ""
        var stderr = ""
        let command = SelectSoundCommand(
            audioSystem: fake,
            language: .english,
            readInput: {
                guard !remainingInput.isEmpty else {
                    return nil
                }
                return remainingInput.removeFirst()
            },
            readConfirmationKey: {
                guard !remainingConfirmationKeys.isEmpty else {
                    return nil
                }
                return remainingConfirmationKeys.removeFirst()
            },
            writeOutput: { stdout += $0 },
            flushOutput: {},
            writeErrorOutput: { stderr += $0 }
        )

        let code = command.run(arguments: arguments)
        return (code, stdout, stderr)
    }
}

private enum FakeAudioError: Error {
    case failed
}

private final class FakeAudioSystem: AudioSystem {
    var inputs = [
        AudioDevice(id: 1, uid: "input-1", name: "Built-in Microphone", isBuiltIn: true),
        AudioDevice(id: 2, uid: "input-2", name: "USB Microphone", isBuiltIn: false)
    ]
    var outputs = [
        AudioDevice(id: 11, uid: "output-1", name: "Built-in Speakers", isBuiltIn: true),
        AudioDevice(id: 12, uid: "output-2", name: "USB Speakers", isBuiltIn: false)
    ]
    var defaultInput: AudioDevice?
    var defaultOutput: AudioDevice?
    var inputError: Error?
    var outputError: Error?
    var setInputHistory: [String] = []
    var setOutputHistory: [String] = []
    var inputDevicesCalls = 0
    var outputDevicesCalls = 0

    init() {
        defaultInput = inputs[0]
        defaultOutput = outputs[0]
    }

    func inputDevices() throws -> [AudioDevice] {
        inputDevicesCalls += 1
        return inputs
    }

    func outputDevices() throws -> [AudioDevice] {
        outputDevicesCalls += 1
        return outputs
    }

    func defaultInputDevice() throws -> AudioDevice? {
        defaultInput
    }

    func defaultOutputDevice() throws -> AudioDevice? {
        defaultOutput
    }

    func setDefaultInputDevice(_ device: AudioDevice) throws {
        setInputHistory.append(device.uid)
        if let inputError {
            throw inputError
        }
        defaultInput = device
    }

    func setDefaultOutputDevice(_ device: AudioDevice) throws {
        setOutputHistory.append(device.uid)
        if let outputError {
            throw outputError
        }
        defaultOutput = device
    }
}
