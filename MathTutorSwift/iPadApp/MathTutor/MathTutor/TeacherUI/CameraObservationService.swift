@preconcurrency import AVFoundation
import Combine
import ObjectiveC
import UIKit

@MainActor
final class CameraObservationService: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var authorizationDenied = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()

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

    func captureFrame() async throws -> Data {
        #if targetEnvironment(simulator)
        guard !session.outputs.isEmpty else {
            return simulatedPaperFrame()
        }
        #endif

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate { result in
                continuation.resume(with: result)
            }
            objc_setAssociatedObject(
                photoOutput,
                UUID().uuidString,
                delegate,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            photoOutput.capturePhoto(
                with: AVCapturePhotoSettings(),
                delegate: delegate
            )
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

        if session.outputs.isEmpty, session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()

        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            Task { @MainActor in self.isRunning = true }
        }
    }

    #if targetEnvironment(simulator)
    private func simulatedPaperFrame() -> Data {
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
        return image.pngData() ?? Data()
    }
    #endif
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
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

        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.emptyFrame))
            return
        }

        completion(.success(data))
    }
}

enum CameraError: Error {
    case emptyFrame
}
