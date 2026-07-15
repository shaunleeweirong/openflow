import AppKit

// Headless CLI mode for testing ASR without the GUI:
//   OpenFlow --transcribe /path/to/audio.wav
// Downloads the model if needed, prints the transcript, exits.
let args = CommandLine.arguments
if args.count >= 3, args[1] == "--transcribe" {
    runTranscribeCLI(path: args[2])
    // runTranscribeCLI never returns (calls dispatchMain / exit)
}
if args.count >= 3, args[1] == "--enhance" {
    if #available(macOS 26, *) {
        runEnhanceCLI(text: args[2]) // never returns
    } else {
        FileHandle.standardError.write("ERROR: --enhance requires macOS 26\n".data(using: .utf8)!)
        exit(1)
    }
}
if args.count >= 3, args[1] == "--bench" {
    if #available(macOS 26, *) {
        let iterations = args.count >= 4 ? (Int(args[3]) ?? 5) : 5
        let gap = args.count >= 5 ? (Double(args[4]) ?? 0) : 0
        runEnhanceBenchCLI(text: args[2], iterations: iterations, gapSeconds: gap) // never returns
    } else {
        FileHandle.standardError.write("ERROR: --bench requires macOS 26\n".data(using: .utf8)!)
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
