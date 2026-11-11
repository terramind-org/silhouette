import Foundation

/// Remembers the shape each ``Skeleton`` showed, so its next skeleton is exact.
///
/// Within a launch it keeps the real data last shown under each id. Across launches it keeps
/// only the layout: for `Codable` data, a copy with every letter, digit and number replaced by
/// a placeholder of the same length, in `UserDefaults`. Call ``forgetSkeletonShapes()`` on
/// sign-out so the next person on the device doesn't see the outline of the last one's data.
@MainActor
enum SkeletonMemory {
    private static var session: [String: Any] = [:]
    static let defaultsPrefix = "silhouette.shape."
    static var defaults: UserDefaults = .standard

    static func remember<Value>(_ value: Value, id: String) {
        session[id] = value
    }

    static func lastShown<Value>(id: String, as type: Value.Type) -> Value? {
        session[id] as? Value
    }

    static func remembered<Value: Decodable>(id: String, as type: Value.Type) -> Value? {
        guard let data = defaults.data(forKey: defaultsPrefix + id) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    static func forget() {
        session.removeAll()
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(defaultsPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Clears every remembered skeleton shape, in memory and on disk. Call it on sign-out.
@MainActor
public func forgetSkeletonShapes() {
    SkeletonMemory.forget()
}

/// Keeps the layout of a value and drops its content.
///
/// Letters become a letter of the same width, digits `0`, numbers keep their digit count, and
/// spaces and punctuation stay, so text wraps where the real text did and numbers take the same
/// width.
enum ShapeScrubber {
    static func scrub<Value: Encodable>(_ value: Value) throws -> Data {
        let encoded = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: encoded, options: [.fragmentsAllowed])
        let scrubbed = scrub(object: object)
        return try JSONSerialization.data(withJSONObject: scrubbed, options: [.fragmentsAllowed])
    }

    static func scrub(object: Any) -> Any {
        switch object {
        case let dict as [String: Any]:
            return dict.mapValues { scrub(object: $0) }
        case let array as [Any]:
            return array.map { scrub(object: $0) }
        case let string as String:
            return scrub(string: string)
        case let number as NSNumber:
            // Booleans are NSNumbers too; keep them.
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number }
            return scrub(number: number)
        default:
            return object
        }
    }

    static func scrub(string: String) -> String {
        String(string.map { c -> Character in
            if c.isNumber { return "0" }
            if c.isLetter { return stand(in: c) }
            return c
        })
    }

    /// A letter of about the same width in the system font, so remembered text wraps where the
    /// real text did: narrow letters stay narrow, wide ones wide, and nothing stays readable.
    static func stand(in c: Character) -> Character {
        for (letters, stand) in widths where letters.contains(c) { return stand }
        return c.isUppercase ? "N" : "a"
    }

    private static let widths: [(Set<Character>, Character)] = [
        (Set("ijl"), "l"), (Set("frt"), "t"), (Set("acekszvxy"), "a"), (Set("bdghnopqu"), "n"),
        (Set("m"), "m"), (Set("w"), "w"),
        (Set("IJ"), "I"), (Set("EFLSTZ"), "E"), (Set("M"), "M"), (Set("W"), "W"),
        (Set("ABCDGHKNOPQRUVXY"), "N"),
    ]

    static func scrub(number: NSNumber) -> NSNumber {
        let value = number.doubleValue
        guard value.isFinite else { return 0 }
        let isInteger = value.rounded() == value
        let digits = max(1, String(Int(abs(value.rounded(.towardZero)))).count)
        let magnitude = Double(String(repeating: "8", count: digits)) ?? 8
        let sign: Double = value < 0 ? -1 : 1
        if isInteger { return NSNumber(value: sign * magnitude) }
        return NSNumber(value: sign * (magnitude + 0.88))
    }
}
