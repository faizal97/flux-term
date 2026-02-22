import Foundation
import SwiftTerm

struct DetectedURL {
    let url: URL
    let startCol: Int
    let endCol: Int
    let row: Int
}

enum URLDetector {
    private static let urlPattern: NSRegularExpression = {
        let pattern = #"https?://[^\s<>\"'\])]+"#
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

    static func detectURLs(in terminal: Terminal) -> [DetectedURL] {
        var results: [DetectedURL] = []

        for row in 0..<terminal.rows {
            guard let line = terminal.getLine(row: row) else { continue }
            let text = line.translateToString()
            let sanitized = text.replacingOccurrences(of: "\u{0000}", with: " ")
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            let matches = urlPattern.matches(in: sanitized, options: [], range: range)
            for match in matches {
                guard let swiftRange = Range(match.range, in: sanitized) else { continue }
                let urlString = String(sanitized[swiftRange])
                guard let url = URL(string: urlString) else { continue }

                let startCol = sanitized.distance(from: sanitized.startIndex, to: swiftRange.lowerBound)
                let endCol = max(startCol, sanitized.distance(from: sanitized.startIndex, to: swiftRange.upperBound) - 1)
                results.append(DetectedURL(url: url, startCol: startCol, endCol: endCol, row: row))
            }
        }

        return results
    }

    static func urlAt(col: Int, row: Int, in urls: [DetectedURL]) -> DetectedURL? {
        urls.first { item in
            item.row == row && col >= item.startCol && col <= item.endCol
        }
    }
}
