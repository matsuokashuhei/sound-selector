import XCTest

final class ReleaseSmokeScriptTests: XCTestCase {
    func testFixtureFailsWhenBuiltInInputIsMissing() throws {
        let result = try runSmokeScript(fixture: "no-built-in-input")

        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.json.contains("\"ok\" : false"))
        XCTAssertTrue(result.json.contains("No built-in audio input device found."))
    }

    func testFixtureFailsWhenExternalDeviceReselectsInput() throws {
        let result = try runSmokeScript(fixture: "external-reselection")

        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.json.contains("\"ok\" : false"))
        XCTAssertTrue(result.json.contains("OpenMeet by Shokz"))
        XCTAssertTrue(result.json.contains("\"restore\""))
        XCTAssertTrue(result.json.contains("\"ok\" : true"))
    }

    func testFixtureSuccessWritesReleaseSmokeJson() throws {
        let result = try runSmokeScript(fixture: "success")

        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.json.contains("\"ok\" : true"))
        XCTAssertTrue(result.json.contains("\"before\""))
        XCTAssertTrue(result.json.contains("\"after\""))
        XCTAssertTrue(result.json.contains("\"restore\""))
        XCTAssertTrue(result.json.contains("\"audioSelectorExitCode\" : 0"))
    }

    private func runSmokeScript(fixture: String) throws -> (code: Int32, json: String) {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let outputURL = tempDirectory.appendingPathComponent("release-smoke.json")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            smokeScriptURL.path,
            "--fixture",
            fixture,
            "--output",
            outputURL.path
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let json = try String(contentsOf: outputURL, encoding: .utf8)
        return (process.terminationStatus, json)
    }

    private var smokeScriptURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/release-smoke-audio.sh")
    }
}
