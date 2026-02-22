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
    var terminal: Terminal!
    var process: LocalProcess!
    weak var delegate: TerminalSessionDelegate?

    init(cols: Int = 80, rows: Int = 24) {
        let options = TerminalOptions(
            cols: cols,
            rows: rows,
            termName: "xterm-256color",
            scrollback: 10000
        )
        terminal = Terminal(delegate: self, options: options)
        process = LocalProcess(delegate: self)
    }

    func start() {
        let shell = detectShell()
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

    private func detectShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], !shell.isEmpty {
            return shell
        }
        return "/bin/zsh"
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
