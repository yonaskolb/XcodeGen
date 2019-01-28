import Foundation

// https://gist.github.com/kristopherjohnson/543687c763cd6e524c91

/// Find first differing character between two strings
///
/// :param: s1 First String
/// :param: s2 Second String
///
/// :returns: .DifferenceAtIndex(i) or .NoDifference
public func firstDifferenceBetweenStrings(_ s1: String, _ s2: String) -> FirstDifferenceResult {
    let len1 = s1.count
    let len2 = s2.count

    let lenMin = min(len1, len2)

    for i in 0..<lenMin {
        if (s1 as NSString).character(at: i) != (s2 as NSString).character(at: i) {
            return .DifferenceAtIndex(i)
        }
    }

    if len1 < len2 {
        return .DifferenceAtIndex(len1)
    }

    if len2 < len1 {
        return .DifferenceAtIndex(len2)
    }

    return .NoDifference
}

/// Create a formatted String representation of difference between strings
///
/// :param: s1 First string
/// :param: s2 Second string
///
/// :returns: a string, possibly containing significant whitespace and newlines
public func prettyFirstDifferenceBetweenStrings(_ s1: String, _ s2: String, previewPrefixLength: Int = 25, previewSuffixLength: Int = 25) -> String {
    let firstDifferenceResult = firstDifferenceBetweenStrings(s1, s2)

    func diffString(at index: Int, _ s1: String, _ s2: String) -> String {
        let markerArrow = "\u{2b06}" // "⬆"
        let ellipsis = "\u{2026}" // "…"

        /// Given a string and a range, return a string representing that substring.
        ///
        /// If the range starts at a position other than 0, an ellipsis
        /// will be included at the beginning.
        ///
        /// If the range ends before the actual end of the string,
        /// an ellipsis is added at the end.
        func windowSubstring(_ s: String, _ range: NSRange) -> String {
            let validRange = NSMakeRange(range.location, min(range.length, s.count - range.location))
            let substring = (s as NSString).substring(with: validRange)

            let prefix = range.location > 0 ? ellipsis : ""
            let suffix = (s.count - range.location > range.length) ? ellipsis : ""

            return "\(prefix)\(substring)\(suffix)"
        }

        // Show this many characters before and after the first difference
        let windowLength = previewPrefixLength + 1 + previewSuffixLength

        let windowIndex = max(index - previewPrefixLength, 0)
        let windowRange = NSMakeRange(windowIndex, windowLength)

        let sub1 = windowSubstring(s1, windowRange)
        let sub2 = windowSubstring(s2, windowRange)

        let markerPosition = min(previewSuffixLength, index) + (windowIndex > 0 ? 1 : 0)

        let markerPrefix = String(repeating: " ", count: markerPosition)
        let markerLine = "\(markerPrefix)\(markerArrow)"

        return "Difference at index \(index):\n\(sub1)\n\(sub2)\n\(markerLine)"
    }

    switch firstDifferenceResult {
    case .NoDifference: return "No difference"
    case let .DifferenceAtIndex(index): return diffString(at: index, s1, s2)
    }
}

/// Result type for firstDifferenceBetweenStrings()
public enum FirstDifferenceResult {
    /// Strings are identical
    case NoDifference

    /// Strings differ at the specified index.
    ///
    /// This could mean that characters at the specified index are different,
    /// or that one string is longer than the other
    case DifferenceAtIndex(Int)
}
