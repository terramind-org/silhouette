import Foundation
import os

/// Writes a sample to paste, from real data, for a ``Skeleton`` that has none.
///
/// The template keeps your data's shape, its keys, its lengths and its types, and replaces every
/// value, so it is safe to paste into source.
enum SampleTemplate {
    static let logger = Logger(subsystem: "Silhouette", category: "Skeleton")

    static func describe(_ value: Any, depth: Int = 0) -> String {
        let indent = String(repeating: "    ", count: depth + 1)
        let closing = String(repeating: "    ", count: depth)
        let mirror = Mirror(reflecting: value)

        switch value {
        case let string as String:
            return "\"" + ShapeScrubber.scrub(string: string) + "\""
        case let bool as Bool:
            return bool ? "true" : "false"
        case is Int, is Int8, is Int16, is Int32, is Int64, is UInt, is UInt8, is UInt16, is UInt32, is UInt64:
            return "\(ShapeScrubber.scrub(number: NSNumber(value: Double("\(value)") ?? 0)).intValue)"
        case let double as Double:
            return "\(ShapeScrubber.scrub(number: NSNumber(value: double)).doubleValue)"
        case let float as Float:
            return "\(ShapeScrubber.scrub(number: NSNumber(value: Double(float))).doubleValue)"
        case is Date:
            return ".now"
        case let url as URL:
            return "URL(string: \"\(url.scheme ?? "https")://example.com\")!"
        case is UUID:
            return "UUID()"
        default:
            break
        }

        switch mirror.displayStyle {
        case .optional:
            guard let child = mirror.children.first else { return "nil" }
            return describe(child.value, depth: depth)
        case .collection, .set:
            let items = mirror.children.prefix(3).map { indent + describe($0.value, depth: depth + 1) }
            return items.isEmpty ? "[]" : "[\n" + items.joined(separator: ",\n") + "\n" + closing + "]"
        case .dictionary:
            let items = mirror.children.prefix(3).compactMap { child -> String? in
                let pair = Mirror(reflecting: child.value).children.map(\.value)
                guard pair.count == 2 else { return nil }
                return indent + describe(pair[0], depth: depth + 1) + ": " + describe(pair[1], depth: depth + 1)
            }
            return items.isEmpty ? "[:]" : "[\n" + items.joined(separator: ",\n") + "\n" + closing + "]"
        case .enum:
            if let child = mirror.children.first {
                return ".\(child.label ?? "case")(\(describe(child.value, depth: depth)))"
            }
            return ".\(value)"
        case .tuple:
            return "(" + mirror.children.map { describe($0.value, depth: depth) }.joined(separator: ", ") + ")"
        case .struct, .class:
            let name = String(describing: type(of: value))
            let fields = mirror.children.compactMap { child -> String? in
                guard let label = child.label else { return nil }
                return indent + label.trimmingCharacters(in: CharacterSet(charactersIn: "_")) + ": " + describe(child.value, depth: depth + 1)
            }
            return fields.isEmpty ? "\(name)()" : "\(name)(\n" + fields.joined(separator: ",\n") + "\n" + closing + ")"
        default:
            return "\(value)"
        }
    }

    @MainActor private static var warned: Set<String> = []

    /// Logs a sample to paste, once per type, in debug builds.
    @MainActor
    static func logMissingSample<Value>(for value: Value) {
        #if DEBUG
        let key = String(reflecting: Value.self)
        guard warned.insert(key).inserted else { return }
        logger.notice("""
        Skeleton<\(key, privacy: .public)> has no sample, so its first skeleton was three placeholder lines. \
        Paste this as its sample:
        \(describe(value), privacy: .public)
        """)
        #endif
    }

    @MainActor
    static func warnNothingToMeasure<Value>(_ type: Value.Type) {
        #if DEBUG
        let key = "empty." + String(reflecting: Value.self)
        guard warned.insert(key).inserted else { return }
        logger.warning("Skeleton<\(String(reflecting: Value.self), privacy: .public)> had nothing to measure, so it drew three placeholder lines. Pass a sample, or an id so the shape is remembered.")
        #endif
    }
}
