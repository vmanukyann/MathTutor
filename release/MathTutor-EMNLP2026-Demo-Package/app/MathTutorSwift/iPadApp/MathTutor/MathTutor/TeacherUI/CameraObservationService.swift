@preconcurrency import AVFoundation
import Combine
import ObjectiveC
import UIKit

struct CapturedCameraFrame: Sendable {
    let data: Data
    let originalWidth: Int
    let originalHeight: Int
    let outputWidth: Int
    let outputHeight: Int
    let originalBytes: Int
    let jpegQuality: Double
    let preset: String
    let capturedAt: Date
    let source: String

    func ageMilliseconds(now: Date = Date()) -> Int {
        max(0, Int(now.timeIntervalSince(capturedAt) * 1_000))
    }
}

private struct CameraCompressionPreset {
    let name: String
    let maximumDimension: CGFloat
    let jpegQuality: Double

    static var active: CameraCompressionPreset {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["MATHTUTOR_CAMERA_PRESET"] {
        case "1024":
            return CameraCompressionPreset(
                name: "1024_q065",
                maximumDimension: 1_024,
                jpegQuality: 0.65
            )
        case "896":
            return CameraCompressionPreset(
                name: "896_q065",
                maximumDimension: 896,
                jpegQuality: 0.65
            )
        default:
            break
        }
        #endif
        return CameraCompressionPreset(
            name: "1280_q068",
            maximumDimension: 1_280,
            jpegQuality: 0.68
        )
    }
}

@MainActor
final class CameraObservationService: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var authorizationDenied = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "MathTutor.camera.video")
    private var latestPreparedFrame: CapturedCameraFrame?

    func start() async {
        #if targetEnvironment(simulator)
        configureAndStart()
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            granted ? configureAndStart() : (authorizationDenied = true)
        default:
            authorizationDenied = true
        }
        #endif
    }

    func stop() {
        guard session.isRunning else { return }
        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
            Task { @MainActor in self.isRunning = false }
        }
    }

    func freshPreparedFrame(maxAgeMilliseconds: Int = 900) -> CapturedCameraFrame? {
        guard let latestPreparedFrame,
              latestPreparedFrame.ageMilliseconds() <= maxAgeMilliseconds else {
            return nil
        }
        return latestPreparedFrame
    }

    func captureFrame(
        preferPreparedFrame: Bool = true,
        maxPreparedFrameAgeMilliseconds: Int = 900
    ) async throws -> CapturedCameraFrame {
        if preferPreparedFrame,
           let frame = freshPreparedFrame(maxAgeMilliseconds: maxPreparedFrameAgeMilliseconds) {
            return frame
        }

        let preset = CameraCompressionPreset.active
        #if targetEnvironment(simulator)
        guard !session.outputs.isEmpty else {
            return simulatedPaperFrame(preset: preset)
        }
        #endif

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate(preset: preset) { result in
                continuation.resume(with: result)
            }
            objc_setAssociatedObject(
                photoOutput,
                UUID().uuidString,
                delegate,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .speed
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configureAndStart() {
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        if session.inputs.isEmpty {
            guard let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
            else {
                #if targetEnvironment(simulator)
                authorizationDenied = false
                isRunning = true
                session.commitConfiguration()
                return
                #else
                authorizationDenied = true
                session.commitConfiguration()
                return
                #endif
            }
            session.addInput(input)
        }

        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .speed
        }

        if !session.outputs.contains(videoOutput), session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        }

        session.commitConfiguration()

        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            Task { @MainActor in self.isRunning = true }
        }
    }

    #if targetEnvironment(simulator)
    private func simulatedPaperFrame(
        preset: CameraCompressionPreset
    ) -> CapturedCameraFrame {
        let size = CGSize(width: 900, height: 700)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(red: 0.96, green: 0.95, blue: 0.90, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor(red: 0.82, green: 0.80, blue: 0.70, alpha: 1).setStroke()
            for x in stride(from: 0, through: size.width, by: 36) {
                context.cgContext.move(to: CGPoint(x: x, y: 0))
                context.cgContext.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: 36) {
                context.cgContext.move(to: CGPoint(x: 0, y: y))
                context.cgContext.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.cgContext.setLineWidth(1)
            context.cgContext.strokePath()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .semibold),
                .foregroundColor: UIColor(red: 0.13, green: 0.14, blue: 0.13, alpha: 1)
            ]
            let lines = ["3(x + 2)", "= 3x + 3·2", "= 3x + 6"]
            for (index, line) in lines.enumerated() {
                line.draw(
                    at: CGPoint(x: 260, y: 230 + CGFloat(index * 74)),
                    withAttributes: attributes
                )
            }
        }
        let data = image.jpegData(compressionQuality: preset.jpegQuality) ?? Data()
        return CapturedCameraFrame(
            data: data,
            originalWidth: Int(size.width),
            originalHeight: Int(size.height),
            outputWidth: Int(size.width),
            outputHeight: Int(size.height),
            originalBytes: data.count,
            jpegQuality: preset.jpegQuality,
            preset: preset.name,
            capturedAt: Date(),
            source: "simulator"
        )
    }
    #endif

}

private enum PreparedCameraFrameBuilder {
    private static let lock = NSLock()
    private static let ciContext = CIContext()
    private static var lastPreparedFrameAt = Date.distantPast
    private static let framePreparationInterval: TimeInterval = 0.35

    static func frame(from sampleBuffer: CMSampleBuffer) -> CapturedCameraFrame? {
        let now = Date()
        lock.lock()
        let shouldPrepare = now.timeIntervalSince(lastPreparedFrameAt) >= framePreparationInterval
        if shouldPrepare {
            lastPreparedFrameAt = now
        }
        lock.unlock()
        guard shouldPrepare,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let preset = CameraCompressionPreset.active
        let baseImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        guard let cgImage = ciContext.createCGImage(baseImage, from: baseImage.extent) else {
            return nil
        }
        let scale = min(
            1,
            preset.maximumDimension / max(baseImage.extent.width, baseImage.extent.height)
        )
        let outputSize = CGSize(
            width: max(1, floor(baseImage.extent.width * scale)),
            height: max(1, floor(baseImage.extent.height * scale))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let image = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: outputSize))
        }
        guard let data = image.jpegData(compressionQuality: preset.jpegQuality) else {
            return nil
        }
        return CapturedCameraFrame(
            data: data,
            originalWidth: Int(baseImage.extent.width),
            originalHeight: Int(baseImage.extent.height),
            outputWidth: Int(outputSize.width),
            outputHeight: Int(outputSize.height),
            originalBytes: CVPixelBufferGetDataSize(pixelBuffer),
            jpegQuality: preset.jpegQuality,
            preset: preset.name,
            capturedAt: now,
            source: "prepared_video"
        )
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let preset: CameraCompressionPreset
    private let completion: (Result<CapturedCameraFrame, Error>) -> Void

    init(
        preset: CameraCompressionPreset,
        completion: @escaping (Result<CapturedCameraFrame, Error>) -> Void
    ) {
        self.preset = preset
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            completion(.failure(CameraError.emptyFrame))
            return
        }

        let maximumSize = CGSize(
            width: preset.maximumDimension,
            height: preset.maximumDimension
        )
        let resized = image.preparingThumbnail(of: maximumSize) ?? image
        guard let compressed = resized.jpegData(
            compressionQuality: preset.jpegQuality
        ) else {
            completion(.failure(CameraError.emptyFrame))
            return
        }
        completion(.success(CapturedCameraFrame(
            data: compressed,
            originalWidth: image.cgImage?.width ?? Int(image.size.width * image.scale),
            originalHeight: image.cgImage?.height ?? Int(image.size.height * image.scale),
            outputWidth: resized.cgImage?.width ?? Int(resized.size.width * resized.scale),
            outputHeight: resized.cgImage?.height ?? Int(resized.size.height * resized.scale),
            originalBytes: data.count,
            jpegQuality: preset.jpegQuality,
            preset: preset.name,
            capturedAt: Date(),
            source: "photo_capture"
        )))
    }
}

extension CameraObservationService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let frame = PreparedCameraFrameBuilder.frame(from: sampleBuffer) else {
            return
        }
        Task { @MainActor [weak self] in
            self?.latestPreparedFrame = frame
        }
    }
}

enum CameraError: Error {
    case emptyFrame
}
