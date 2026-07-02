import AppKit

// Headless CLI mode for testing ASR without the GUI:
//   OpenFlow --transcribe /path/to/audio.wav
// Downloads the model if needed, prints the transcript, exits.
let args = CommandLine.arguments
if args.count >= 3, args[1] == "--transcribe" {
    runTranscribeCLI(path: args[2])
    // runTranscribeCLI never returns (calls dispatchMain / exit)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
