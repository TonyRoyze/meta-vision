import Foundation
import LiteRTLM

actor GemmaVerifier {
    private var engine: Engine?
    private let fileManager = FileManager.default

    var isConfigured: Bool {
        fileManager.fileExists(atPath: Self.modelURL.path)
    }

    func installModel(from sourceURL: URL) throws {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let directory = Self.modelURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: Self.modelURL.path) {
            try fileManager.removeItem(at: Self.modelURL)
        }
        try fileManager.copyItem(at: sourceURL, to: Self.modelURL)
        engine = nil
    }

    func verify(ocrText: String) async throws -> String {
        guard isConfigured else { throw GemmaError.modelNotInstalled }
        let activeEngine = try await loadEngine()
        let config = ConversationConfig(
            systemMessage: Message("""
            You verify OCR for a blind or low-vision reader. Correct only obvious OCR errors, preserve all facts and reading order, and never invent missing text. Return only the corrected document text. Mark uncertain words with [uncertain].
            """)
        )
        let conversation = try await activeEngine.createConversation(with: config)
        let response = try await conversation.sendMessage(
            Message("Verify this OCR text:\n\n\(ocrText)")
        )
        let verified = response.toString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !verified.isEmpty else { throw GemmaError.emptyResponse }
        return verified
    }

    func summarize(_ text: String) async throws -> String {
        guard isConfigured else { throw GemmaError.modelNotInstalled }
        let activeEngine = try await loadEngine()
        let config = ConversationConfig(
            systemMessage: Message("Summarize documents faithfully for a blind or low-vision reader. Do not invent facts. Return only a concise summary.")
        )
        let conversation = try await activeEngine.createConversation(with: config)
        let response = try await conversation.sendMessage(Message(text))
        let summary = response.toString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { throw GemmaError.emptyResponse }
        return summary
    }

    private func loadEngine() async throws -> Engine {
        if let engine { return engine }
        try fileManager.createDirectory(at: Self.cacheURL, withIntermediateDirectories: true)
        let config = try EngineConfig(
            modelPath: Self.modelURL.path,
            backend: .gpu,
            maxNumTokens: 2048,
            cacheDir: Self.cacheURL.path
        )
        let newEngine = Engine(engineConfig: config)
        try await newEngine.initialize()
        engine = newEngine
        return newEngine
    }

    private static let modelURL: URL = {
        URL.applicationSupportDirectory
            .appending(path: "MetaVision", directoryHint: .isDirectory)
            .appending(path: "gemma.litertlm")
    }()

    private static let cacheURL: URL = {
        URL.cachesDirectory.appending(path: "Gemma", directoryHint: .isDirectory)
    }()
}

enum GemmaError: LocalizedError {
    case modelNotInstalled
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled:
            "Import a compatible Gemma .litertlm model in Settings before reading a document."
        case .emptyResponse:
            "Gemma could not verify the recognized text. Please try again."
        }
    }
}
