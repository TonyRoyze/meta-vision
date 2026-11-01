@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> QuickCameraViewController {
        QuickCameraViewController(
            onCapture: onCapture,
            onCancel: onCancel,
            onError: onError
        )
    }

    func updateUIViewController(_ uiViewController: QuickCameraViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: QuickCameraViewController, coordinator: ()) {
        uiViewController.stopCaptureSession()
    }
}

final class QuickCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.metavision.camera-session", qos: .userInitiated)
    private let onCapture: (UIImage) -> Void
    private let onCancel: () -> Void
    private let onError: (Error) -> Void
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasConfiguredSession = false
    private var hasRequestedPhoto = false
    private var hasFinished = false

    init(
        onCapture: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onCapture = onCapture
        self.onCancel = onCancel
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        installOverlay()
        requestCameraAccessAndStart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func stopCaptureSession() {
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    private func installOverlay() {
        let status = UILabel()
        status.translatesAutoresizingMaskIntoConstraints = false
        status.text = "Capturing scene…"
        status.textColor = .white
        status.font = .preferredFont(forTextStyle: .headline)
        status.backgroundColor = UIColor.black.withAlphaComponent(0.62)
        status.layer.cornerRadius = 14
        status.layer.masksToBounds = true
        status.textAlignment = .center
        status.accessibilityLabel = "Camera open. Capturing scene now."

        let cancel = UIButton(type: .system)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.configuration = .filled()
        cancel.configuration?.title = "Cancel"
        cancel.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.65)
        cancel.configuration?.baseForegroundColor = .white
        cancel.addTarget(self, action: #selector(cancelCapture), for: .touchUpInside)

        view.addSubview(status)
        view.addSubview(cancel)
        NSLayoutConstraint.activate([
            status.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            status.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -34),
            status.widthAnchor.constraint(greaterThanOrEqualToConstant: 190),
            status.heightAnchor.constraint(equalToConstant: 48),
            cancel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            cancel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
        ])
    }

    private func requestCameraAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndStart()
                    } else {
                        self?.finish(with: CameraError.permissionDenied)
                    }
                }
            }
        case .denied, .restricted:
            finish(with: CameraError.permissionDenied)
        @unknown default:
            finish(with: CameraError.unavailable)
        }
    }

    private func configureAndStart() {
        guard !hasConfiguredSession else { return }
        hasConfiguredSession = true

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                guard let camera = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back
                ) else {
                    throw CameraError.unavailable
                }
                let input = try AVCaptureDeviceInput(device: camera)

                captureSession.beginConfiguration()
                captureSession.sessionPreset = .photo
                guard captureSession.canAddInput(input), captureSession.canAddOutput(photoOutput) else {
                    captureSession.commitConfiguration()
                    throw CameraError.configurationFailed
                }
                captureSession.addInput(input)
                captureSession.addOutput(photoOutput)
                photoOutput.maxPhotoQualityPrioritization = .speed
                captureSession.commitConfiguration()
                captureSession.startRunning()

                DispatchQueue.main.async { [weak self] in
                    self?.captureImmediately()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.finish(with: error)
                }
            }
        }
    }

    private func captureImmediately() {
        guard !hasRequestedPhoto, !hasFinished else { return }
        hasRequestedPhoto = true
        UIAccessibility.post(notification: .announcement, argument: "Capturing scene")
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .speed
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            finish(with: error)
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            finish(with: CaptureError.imageCreationFailed)
            return
        }
        finish(with: image)
    }

    @objc private func cancelCapture() {
        guard !hasFinished else { return }
        hasFinished = true
        stopCaptureSession()
        onCancel()
    }

    private func finish(with image: UIImage) {
        guard !hasFinished else { return }
        hasFinished = true
        stopCaptureSession()
        onCapture(image)
    }

    private func finish(with error: Error) {
        guard !hasFinished else { return }
        hasFinished = true
        stopCaptureSession()
        onError(error)
    }
}
