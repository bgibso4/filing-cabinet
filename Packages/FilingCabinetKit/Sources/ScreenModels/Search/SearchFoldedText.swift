import Foundation

extension SearchMatch {
    /// A scan's text, folded line by line once (E3): its non-blank lines, trimmed, and their folds joined by "\n", with
    /// where each line starts, so a `memmem` offset leads straight to its original line.
    package struct FoldedText: Sendable {
        /// The text as read, to tell when it changes.
        package let original: String
        /// The first non-blank line, trimmed; "" without text.
        var firstLine: String { lines.first ?? "" }

        private let lines: [String]
        private let bytes: [UInt8]
        /// Where each line starts in `bytes`, ascending.
        private let starts: [Int]

        package init(_ original: String) {
            self.original = original
            lines = original.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            var bytes: [UInt8] = []
            var starts: [Int] = []
            for line in lines {
                if !bytes.isEmpty { bytes.append(UInt8(ascii: "\n")) }
                starts.append(bytes.count)
                bytes += Folded.fold(line)
            }
            self.bytes = bytes
            self.starts = starts
        }

        /// Where the term's fold first starts. A term holds no newline, so a match never spans two lines.
        func offset(of term: Folded) -> Int? {
            SearchMatch.offset(of: term.bytes, in: bytes)
        }

        /// The original line holding folded `offset`.
        func line(containing offset: Int) -> String {
            // The last line starting at or before the offset.
            var low = 0
            var high = starts.count - 1
            while low < high {
                let middle = (low + high + 1) / 2
                if starts[middle] <= offset { low = middle } else { high = middle - 1 }
            }
            return lines[low]
        }
    }
}
