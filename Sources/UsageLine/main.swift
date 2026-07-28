import AppKit
import Foundation

// UsageLine is a one-shot installer, not a background app: launch it once,
// it installs (or confirms) the Claude Code statusLine hook, then quits.
// From then on Claude Code's own terminal shows "5h 22% · 7d 2%" forever —
// no process of ours needs to keep running for that. See install-hook.sh
// for the actual install logic; this file only shells out to it and turns
// a failure into a native alert (success is silent on purpose).

NSApplication.shared.setActivationPolicy(.accessory)

/// Runs the bundled install-hook.sh once. Returns nil on success, or an
/// error message to show the user on failure.
func runBundledInstaller() -> String? {
    guard let scriptPath = Bundle.main.path(forResource: "install-hook.sh", ofType: nil) else {
        return "No se encontró install-hook.sh dentro de la app."
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [scriptPath]

    let errorPipe = Pipe()
    process.standardError = errorPipe
    process.standardOutput = Pipe() // discarded: success is silent by design

    do {
        try process.run()
    } catch {
        return "No se pudo ejecutar el instalador: \(error.localizedDescription)"
    }
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "El instalador terminó con un error." : text
    }
    return nil
}

if let message = runBundledInstaller() {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "No se pudo instalar el hook de Claude Code"
    alert.informativeText = message
    alert.runModal()
}

exit(0)
