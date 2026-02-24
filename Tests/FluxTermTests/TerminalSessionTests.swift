import XCTest
@testable import FluxTerm

final class TerminalSessionTests: XCTestCase {

    // MARK: - resolveShell tests

    func testResolveShellUsesEnvShellWhenValid() {
        let shell = TerminalSession.resolveShell(
            environment: ["SHELL": "/bin/zsh"],
            isExecutable: { _ in true }
        )
        XCTAssertEqual(shell, "/bin/zsh")
    }

    func testResolveShellFallsBackWhenEnvShellInvalid() {
        let shell = TerminalSession.resolveShell(
            environment: ["SHELL": "/nonexistent/shell"],
            isExecutable: { path in
                ["/bin/zsh", "/bin/bash", "/bin/sh"].contains(path)
            }
        )
        XCTAssertEqual(shell, "/bin/zsh")
    }

    func testResolveShellFallsBackWhenEnvShellEmpty() {
        let shell = TerminalSession.resolveShell(
            environment: ["SHELL": ""],
            isExecutable: { path in
                ["/bin/zsh", "/bin/bash", "/bin/sh"].contains(path)
            }
        )
        XCTAssertEqual(shell, "/bin/zsh")
    }

    func testResolveShellFallsBackWhenEnvShellMissing() {
        let shell = TerminalSession.resolveShell(
            environment: [:],
            isExecutable: { path in
                ["/bin/zsh", "/bin/bash", "/bin/sh"].contains(path)
            }
        )
        XCTAssertEqual(shell, "/bin/zsh")
    }

    func testResolveShellFallsBackToBashWhenZshUnavailable() {
        let shell = TerminalSession.resolveShell(
            environment: ["SHELL": "/nonexistent/shell"],
            isExecutable: { path in
                ["/bin/bash", "/bin/sh"].contains(path)
            }
        )
        XCTAssertEqual(shell, "/bin/bash")
    }

    func testResolveShellFallsBackToShWhenOthersUnavailable() {
        let shell = TerminalSession.resolveShell(
            environment: ["SHELL": "/nonexistent/shell"],
            isExecutable: { path in
                path == "/bin/sh"
            }
        )
        XCTAssertEqual(shell, "/bin/sh")
    }

    func testResolveShellReturnsNilWhenNoShellAvailable() {
        let shell = TerminalSession.resolveShell(
            environment: ["SHELL": "/nonexistent/shell"],
            isExecutable: { _ in false }
        )
        XCTAssertNil(shell)
    }

    func testResolveShellDoesNotDuplicateEnvShellInFallbacks() {
        // If $SHELL is /bin/zsh, don't check /bin/zsh twice
        var checkedPaths: [String] = []
        _ = TerminalSession.resolveShell(
            environment: ["SHELL": "/bin/zsh"],
            isExecutable: { path in
                checkedPaths.append(path)
                return path == "/bin/zsh"
            }
        )

        // /bin/zsh should appear only once (from $SHELL, not duplicated in fallbacks)
        XCTAssertEqual(checkedPaths.filter { $0 == "/bin/zsh" }.count, 1)
    }
}
