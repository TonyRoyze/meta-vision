import Combine
import Foundation

@MainActor
final class ModelDownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published private(set) var isDownloading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var downloadedBytes: Int64 = 0
    @Published private(set) var expectedBytes: Int64 = 0

    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var completion: ((Result<URL, Error>) -> Void)?

    func start(
        urlString: String,
        huggingFaceToken: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) throws {
        guard !isDownloading else { return }
        guard let url = Self.downloadURL(from: urlString) else {
            throw ModelDownloadError.invalidURL
        }
        let host = url.host?.lowercased()
        guard url.scheme == "https", host == "huggingface.co" || host?.hasSuffix(".huggingface.co") == true else {
            throw ModelDownloadError.unsupportedHost
        }
        guard url.pathExtension.lowercased() == "litertlm" else {
            throw ModelDownloadError.invalidModelFile
        }

        var request = URLRequest(url: url)
        if !huggingFaceToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(
                "Bearer \(huggingFaceToken.trimmingCharacters(in: .whitespacesAndNewlines))",
                forHTTPHeaderField: "Authorization"
            )
        }

        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)

        self.session = session
        self.completion = completion
        progress = 0
        downloadedBytes = 0
        expectedBytes = 0
        isDownloading = true
        task = session.downloadTask(with: request)
        task?.resume()
    }

    func cancel() {
        task?.cancel()
        finish(.failure(CancellationError()))
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor [weak self] in
            self?.downloadedBytes = totalBytesWritten
            self?.expectedBytes = max(0, totalBytesExpectedToWrite)
            if totalBytesExpectedToWrite > 0 {
                self?.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) else {
                throw ModelDownloadError.serverRejected(
                    (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
                )
            }

            let values = try location.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) > 1_000_000 else {
                throw ModelDownloadError.invalidModelFile
            }

            let directory = URL.cachesDirectory
                .appending(path: "ModelDownloads", directoryHint: .isDirectory)
            let stagedURL = directory.appending(path: "gemma-download.litertlm")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: stagedURL.path) {
                try FileManager.default.removeItem(at: stagedURL)
            }
            try FileManager.default.moveItem(at: location, to: stagedURL)

            Task { @MainActor [weak self] in
                self?.finish(.success(stagedURL))
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.finish(.failure(error))
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        Task { @MainActor [weak self] in
            guard self?.isDownloading == true else { return }
            self?.finish(.failure(error))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        let callback = completion
        completion = nil
        task = nil
        session?.invalidateAndCancel()
        session = nil
        isDownloading = false
        callback?(result)
    }

    private static func downloadURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let direct = trimmed.replacingOccurrences(of: "/blob/", with: "/resolve/")
        return URL(string: direct)
    }
}

enum ModelDownloadError: LocalizedError {
    case invalidURL
    case unsupportedHost
    case serverRejected(Int)
    case invalidModelFile

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Enter a valid Hugging Face model file URL."
        case .unsupportedHost:
            "For safety, model downloads must come from huggingface.co."
        case .serverRejected(let status):
            status == 401 || status == 403
                ? "Hugging Face denied access. Accept the model license and enter a read token."
                : "Hugging Face returned HTTP \(status)."
        case .invalidModelFile:
            "The downloaded file is not a valid LiteRT-LM model. Check that the URL points directly to a .litertlm file."
        }
    }
}
