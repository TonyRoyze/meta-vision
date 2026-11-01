import Combine
import CoreGraphics
import UIKit

protocol GlassesCaptureProviding: Sendable {
    var deviceName: String { get }

    func connect() async throws
    func captureImage() async throws -> CGImage
}

@MainActor
final class GlassesConnectionViewModel: ObservableObject {
    @Published private(set) var state: GlassesConnectionState = .disconnected

    private let provider: any GlassesCaptureProviding
    private var connectionTask: Task<Void, Never>?

    init() {
        self.provider = MockGlassesCaptureProvider()
    }

    init(provider: any GlassesCaptureProviding) {
        self.provider = provider
    }

    func connect() {
        guard state.canConnect else { return }
        state = .connecting
        let provider = provider
        connectionTask = Task { [weak self] in
            do {
                try await provider.connect()
                try Task.checkCancellation()
                self?.state = .connected(deviceName: provider.deviceName)
            } catch is CancellationError {
                self?.state = .disconnected
            } catch {
                self?.state = .failed(error.localizedDescription)
            }
        }
    }

    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
        state = .disconnected
    }
}

enum GlassesConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(deviceName: String)
    case failed(String)

    var title: String {
        switch self {
        case .disconnected: "Not connected"
        case .connecting: "Looking for glasses…"
        case .connected(let deviceName): deviceName
        case .failed: "Connection failed"
        }
    }

    var detail: String {
        switch self {
        case .disconnected: "Connect Meta Ray-Bans for hands-free capture."
        case .connecting: "Keep your glasses nearby and powered on."
        case .connected: "Ready for the future glasses capture adapter."
        case .failed(let message): message
        }
    }

    var symbolName: String {
        switch self {
        case .disconnected: "eyeglasses"
        case .connecting: "antenna.radiowaves.left.and.right"
        case .connected: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var canConnect: Bool {
        switch self {
        case .disconnected, .failed: true
        case .connecting, .connected: false
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Development provider that keeps the glasses connection and capture seam runnable
/// without claiming to communicate with physical Meta glasses.
struct MockGlassesCaptureProvider: GlassesCaptureProviding {
    let deviceName = "Demo Ray-Ban glasses"

    func connect() async throws {
        try await Task.sleep(for: .milliseconds(650))
    }

    @MainActor
    func captureImage() async throws -> CGImage {
        try await Task.sleep(for: .milliseconds(500))

        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 14
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 54, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph,
            ]
            let text = "Community Library\n\nYour books are due Friday, August 21. Please return them at the front desk or renew them online.\n\nOpening hours: 9 AM to 6 PM."
            text.draw(
                in: CGRect(x: 90, y: 120, width: 1020, height: 1200),
                withAttributes: attributes
            )
        }

        guard let cgImage = image.cgImage else {
            throw CaptureError.imageCreationFailed
        }
        return cgImage
    }
}

enum CaptureError: LocalizedError {
    case imageCreationFailed

    var errorDescription: String? {
        "The glasses did not return a usable image."
    }
}
