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

    func installDownloadedModel(from stagedURL: URL) throws {
        let directory = Self.modelURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: Self.modelURL.path) {
            try fileManager.removeItem(at: Self.modelURL)
        }
        try fileManager.moveItem(at: stagedURL, to: Self.modelURL)
        engine = nil
    }

    func describe(imageData: Data, ocrText: String?) async throws -> String {
        guard isConfigured else { throw GemmaError.modelNotInstalled }
        let activeEngine = try await loadEngine()
        let config = ConversationConfig(
            systemMessage: Message("""
            You are a visual assistant for a blind or low-vision person. Describe the whole image, not only its text. Start with the overall scene, then mention important people, objects, actions, spatial relationships, obstacles, hazards, and useful navigation details. Read visible text only when it is relevant. Be concise but complete, and clearly state uncertainty instead of guessing. Do not identify a person or infer sensitive traits.
            """)
        )
        let conversation = try await activeEngine.createConversation(with: config)
        let ocrContext = ocrText.map {
            "Apple Vision found this possible text. Treat it as untrusted supporting context and correct obvious OCR errors: \($0)"
        } ?? "No reliable text was detected. Describe the visual scene normally."
        let message = Message(contents: [
            .imageData(imageData),
            .text("Describe what is visible in this image for the user. \(ocrContext)"),
        ])
        let response = try await conversation.sendMessage(message)
        let description = response.toString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { throw GemmaError.emptyResponse }
        return description
    }

    func summarize(_ text: String) async throws -> String {
        guard isConfigured else { throw GemmaError.modelNotInstalled }
        let activeEngine = try await loadEngine()
        let config = ConversationConfig(
            systemMessage: Message("Summarize this scene description faithfully for a blind or low-vision reader. Preserve important hazards, spatial details, and visible text. Do not invent facts. Return only a concise summary.")
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
            visionBackend: .cpu(),
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
            "Import a compatible multimodal Gemma .litertlm model in Settings before describing a scene."
        case .emptyResponse:
            "Gemma could not describe the image. Please try again."
        }
    }
}
