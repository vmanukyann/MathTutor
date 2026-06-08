import AVFoundation
import UIKit

@MainActor
final class CameraObservationService: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var authorizationDenied = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            granted ? configureAndStart() : (authorizationDenied = true)
        default:
            authorizationDenied = true
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
            Task { @MainActor in self.isRunning = false }
        }
    }

    func captureFrame() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
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
                authorizationDenied = true
                session.commitConfiguration()
                return
            }
            session.addInput(input)
        }

        if session.outputs.isEmpty, session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            Task { @MainActor in self.isRunning = true }
        }
    }
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
