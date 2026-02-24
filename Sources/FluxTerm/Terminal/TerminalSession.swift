import AppKit
import SwiftTerm

protocol TerminalSessionDelegate: AnyObject {
    func terminalSession(_ session: TerminalSession, didReceiveData data: ArraySlice<UInt8>)
    func terminalSession(_ session: TerminalSession, titleDidChange title: String)
    func terminalSession(_ session: TerminalSession, didScrollTo yDisp: Int)
    func terminalSessionBufferActivated(_ session: TerminalSession)
    func terminalSessionDidTerminate(_ session: TerminalSession, exitCode: Int32?)
}

final class TerminalSession: TerminalDelegate, LocalProcessDelegate {
    enum ShellError: Error, LocalizedError {
        case noValidShell(tried: [String])

        var errorDescription: String? {
            switch self {
            case .noValidShell(let tried):
                return "No valid shell found. Tried: \(tried.joined(separator: ", "))"
            }
        }
    }

    private let initialCols: Int
    private let initialRows: Int

    lazy var terminal: Terminal = {
        let options = TerminalOptions(
            cols: initialCols,
            rows: initialRows,
            termName: "xterm-256color",
            scrollback: 10000
        )
        return Terminal(delegate: self, options: options)
    }()

    lazy var process: LocalProcess = {
        LocalProcess(delegate: self)
    }()

    weak var delegate: TerminalSessionDelegate?
    private var hasStarted = false

    init(cols: Int = 80, rows: Int = 24) {
        initialCols = cols
        initialRows = rows
    }

    func start() throws {
        guard !hasStarted else { return }
        hasStarted = true

        guard let shell = Self.resolveShell() else {
            throw ShellError.noValidShell(tried: [
                ProcessInfo.processInfo.environment["SHELL"] ?? "(unset)",
                "/bin/zsh", "/bin/bash", "/bin/sh"
            ])
        }
        let shellName = (shell as NSString).lastPathComponent
        process.startProcess(executable: shell, args: [], environment: nil, execName: "-\(shellName)")
    }

    func resize(cols: Int, rows: Int) {
        terminal.resize(cols: cols, rows: rows)
        var size = getWindowSize()
        if process.running {
            _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)
        }
    }

    func sendInput(_ data: ArraySlice<UInt8>) {
        process.send(data: data)
    }

    func sendInput(_ text: String) {
        let bytes = Array(text.utf8)
        sendInput(bytes[...])
    }

    /// Resolves a valid shell executable path.
    ///
    /// Checks `$SHELL` from the environment first, then falls back through
    /// `/bin/zsh`, `/bin/bash`, `/bin/sh`.
    static func resolveShell(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> String? {
        let envShell = environment["SHELL"].flatMap { $0.isEmpty ? nil : $0 }
        let fallbacks = ["/bin/zsh", "/bin/bash", "/bin/sh"]

        var candidates: [String] = []
        if let envShell {
            candidates.append(envShell)
        }
        for fallback in fallbacks where fallback != envShell {
            candidates.append(fallback)
        }

        return candidates.first(where: isExecutable)
    }

    func send(source: Terminal, data: ArraySlice<UInt8>) {
        process.send(data: data)
    }

    func setTerminalTitle(source: Terminal, title: String) {
        delegate?.terminalSession(self, titleDidChange: title)
    }

    func bell(source: Terminal) {
        NSSound.beep()
    }

    func scrolled(source: Terminal, yDisp: Int) {
        delegate?.terminalSession(self, didScrollTo: yDisp)
    }

    func bufferActivated(source: Terminal) {
        delegate?.terminalSessionBufferActivated(self)
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        terminal.feed(buffer: slice)
        delegate?.terminalSession(self, didReceiveData: slice)
    }

    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        delegate?.terminalSessionDidTerminate(self, exitCode: exitCode)
    }

    func getWindowSize() -> winsize {
        winsize(
            ws_row: UInt16(terminal.rows),
            ws_col: UInt16(terminal.cols),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
    }
}
