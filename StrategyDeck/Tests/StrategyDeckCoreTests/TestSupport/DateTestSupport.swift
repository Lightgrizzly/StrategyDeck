import Foundation

/// `JSONCoding`'s `.iso8601` date strategy has whole-second resolution, so a
/// sub-second `Date()` never round-trips equal through it. Any test that
/// asserts full struct equality on a model with `Date` fields after an
/// encode/decode round trip should build its fixture from this instead of
/// `Date()` directly.
extension Date {
    static func wholeSecondForTesting() -> Date {
        Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
    }
}
