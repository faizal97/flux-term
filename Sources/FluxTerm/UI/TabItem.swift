import Foundation

final class TabItem {
    let id: UUID
    var title: String
    let terminalVC: TerminalViewController

    init(
        id: UUID = UUID(),
        title: String = "FluxTerm",
        terminalVC: TerminalViewController
    ) {
        self.id = id
        self.title = title
        self.terminalVC = terminalVC
    }
}
