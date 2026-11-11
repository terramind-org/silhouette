#if os(iOS)
import AVFoundation
import UIKit

/// Records the app's own window to `Documents/capture.mp4`, for the README's recordings.
///
/// Launch with `-capture 12` to record twelve seconds, starting two seconds after launch. It
/// draws the window itself, so it works while the simulator's own recorder is busy.
@MainActor
final class FrameRecorder {
    static let shared = FrameRecorder()

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0
    private var duration: Double = 0
    private var lastFrame: CFTimeInterval = -1

    static func startIfRequested() {
        let seconds = UserDefaults.standard.double(forKey: "capture")
        guard seconds > 0 else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            shared.begin(seconds: seconds)
        }
    }

    private func begin(seconds: Double) {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
        let scale: CGFloat = 2
        let size = CGSize(width: (window.bounds.width * scale).rounded(), height: (window.bounds.height * scale).rounded())
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("capture.mp4")
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
        ])
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        self.writer = writer
        self.input = input
        self.adaptor = adaptor
        duration = seconds
        start = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick() {
        let t = CACurrentMediaTime() - start
        guard t < duration else { return finish() }
        guard t - lastFrame >= 1.0 / 30 - 0.002,
              let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
              let adaptor, let input, input.isReadyForMoreMediaData,
              let pool = adaptor.pixelBufferPool else { return }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return }
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        if let context {
            let scale = CGFloat(CVPixelBufferGetWidth(buffer)) / window.bounds.width
            context.translateBy(x: 0, y: CGFloat(CVPixelBufferGetHeight(buffer)))
            context.scaleBy(x: scale, y: -scale)
            UIGraphicsPushContext(context)
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
            UIGraphicsPopContext()
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        adaptor.append(buffer, withPresentationTime: CMTime(seconds: t, preferredTimescale: 600))
        lastFrame = t
    }

    private func finish() {
        link?.invalidate()
        link = nil
        input?.markAsFinished()
        writer?.finishWriting { print("FrameRecorder: wrote capture.mp4") }
    }
}
#endif
