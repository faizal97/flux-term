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
        let topVisibleRow = terminal.getTopVisibleRow()

        for viewportRow in 0..<terminal.rows {
            guard let line = terminal.getLine(row: viewportRow) else { continue }
            let text = line.translateToString(skipNullCellsFollowingWide: true)
            let sanitized = text.replacingOccurrences(of: "\u{0000}", with: " ")
            let columnMap = buildColumnMap(for: line)
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            let matches = urlPattern.matches(in: sanitized, options: [], range: range)
            for match in matches {
                guard let swiftRange = Range(match.range, in: sanitized) else { continue }
                let urlString = String(sanitized[swiftRange])
                guard let url = URL(string: urlString) else { continue }

                let charStart = sanitized.distance(from: sanitized.startIndex, to: swiftRange.lowerBound)
                let charEnd = sanitized.distance(from: sanitized.startIndex, to: swiftRange.upperBound) - 1
                let startCol = charStart < columnMap.count ? columnMap[charStart] : charStart
                let endCol = max(startCol, charEnd < columnMap.count ? columnMap[charEnd] : charEnd)
                let bufferRow = topVisibleRow + viewportRow
                results.append(DetectedURL(url: url, startCol: startCol, endCol: endCol, row: bufferRow))
            }
        }

        return results
    }

    /// Builds a mapping from string character index to terminal column position.
    /// Each entry columnMap[i] gives the terminal column for the i-th character
    /// produced by translateToString(skipNullCellsFollowingWide: true).
    /// Wide characters (CJK, emoji) occupy 2 columns but produce 1 character,
    /// so subsequent characters map to higher column numbers than their string index.
    private static func buildColumnMap(for line: BufferLine) -> [Int] {
        var map: [Int] = []
        let nullChar = Character(UnicodeScalar(0))
        var idx = 0
        let limit = line.count

        while idx < limit {
            // Skip null placeholder cells that follow wide characters
            // (mirrors translateToString's skipNullCellsFollowingWide logic)
            if idx > 0 && line[idx].getCharacter() == nullChar && line.getWidth(index: idx - 1) == 2 {
                idx += 1
                continue
            }

            // idx IS the terminal column for this character
            map.append(idx)

            let w = line.getWidth(index: idx)
            if w == 2 {
                let nextIdx = idx + 1
                if nextIdx < limit && line[nextIdx].getCharacter() == nullChar {
                    idx += 2
                    continue
                }
            }
            idx += 1
        }

        return map
    }

    static func urlAt(col: Int, row: Int, in urls: [DetectedURL]) -> DetectedURL? {
        urls.first { item in
            item.row == row && col >= item.startCol && col <= item.endCol
        }
    }
}
