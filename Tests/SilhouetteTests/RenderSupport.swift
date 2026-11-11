import CoreGraphics
import SwiftUI
import XCTest
@testable import Silhouette

/// Renders a view offscreen and reads back its pixels.
@MainActor
struct Rendered {
    let image: CGImage
    let scale: CGFloat
    private let bytes: [UInt8]

    init<V: View>(_ view: V, size: CGSize, scale: CGFloat = 2, colorScheme: ColorScheme = .light) throws {
        let renderer = ImageRenderer(content: view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, colorScheme))
        renderer.scale = scale
        renderer.isOpaque = false
        guard let cg = renderer.cgImage else { throw XCTSkip("ImageRenderer produced no image") }
        image = cg
        self.scale = scale
        let width = cg.width, height = cg.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let ctx = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = data
    }

    /// Alpha at a point, in points from the top left, 0...1.
    func alpha(at point: CGPoint) -> Double {
        let x = Int(point.x * scale), y = Int(point.y * scale)
        guard x >= 0, y >= 0, x < image.width, y < image.height else { return 0 }
        return Double(bytes[(y * image.width + x) * 4 + 3]) / 255
    }

    /// Whether each row, in points, has any covered pixel.
    func coveredRows(threshold: Double = 0.5) -> [Bool] {
        (0..<Int(Double(image.height) / scale)).map { row in
            (0..<Int(Double(image.width) / scale)).contains { alpha(at: CGPoint(x: Double($0) + 0.5, y: Double(row) + 0.5)) > threshold }
        }
    }

    /// The covered width of a row, in points.
    func coveredWidth(row: CGFloat, threshold: Double = 0.5) -> CGFloat {
        let xs = (0..<Int(Double(image.width) / scale)).filter { alpha(at: CGPoint(x: Double($0) + 0.5, y: row)) > threshold }
        guard let first = xs.first, let last = xs.last else { return 0 }
        return CGFloat(last - first + 1)
    }

    /// Runs of covered rows: each a range of rows in points.
    func bands(threshold: Double = 0.5) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var start: Int?
        for (i, covered) in coveredRows(threshold: threshold).enumerated() {
            if covered, start == nil { start = i }
            if !covered, let s = start { result.append(s..<i); start = nil }
        }
        if let s = start { result.append(s..<coveredRows(threshold: threshold).count) }
        return result
    }
}
