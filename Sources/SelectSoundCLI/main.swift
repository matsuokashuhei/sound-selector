import Darwin
import SelectSoundCore

signal(SIGINT) { _ in
    let message = "\n"
    message.withCString { pointer in
        _ = Darwin.write(STDOUT_FILENO, pointer, strlen(pointer))
    }
    Darwin._exit(0)
}

let command = SelectSoundCommand(audioSystem: CoreAudioAudioSystem())
let exitCode = command.run(arguments: Array(CommandLine.arguments.dropFirst()))
Darwin.exit(exitCode)
