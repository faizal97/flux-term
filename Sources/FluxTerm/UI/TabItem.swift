import Foundation

final class TabItem {
    let id: UUID
    var title: String
    var hasCustomTitle: Bool
    let terminalVC: TerminalViewController

    init(
        id: UUID = UUID(),
        title: String = "FluxTerm",
        hasCustomTitle: Bool = false,
        terminalVC: TerminalViewController
    ) {
        self.id = id
        self.title = title
        self.hasCustomTitle = hasCustomTitle
        self.terminalVC = terminalVC
    }
}
