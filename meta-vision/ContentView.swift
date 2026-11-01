import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = ReadingViewModel()
    @StateObject private var glassesConnection = GlassesConnectionViewModel()
    @StateObject private var modelDownloader = ModelDownloader()
    @State private var isShowingHistory = false
    @State private var isShowingSettings = false
    @State private var isShowingCamera = false
    @State private var isImportingGemma = false
    @State private var modelURL = "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true"
    @State private var huggingFaceToken = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    glassesConnectionCard
                    processingStatusCard
                    readButton
                    transcriptCard
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Meta Vision")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("History", systemImage: "clock.arrow.circlepath") {
                        isShowingHistory = true
                    }
                    .accessibilityHint("Shows recent scene descriptions saved on this device")

                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
            }
        }
        .alert("Something went wrong", isPresented: $viewModel.isShowingError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
        .sheet(isPresented: $isShowingHistory) {
            historyView
        }
        .sheet(isPresented: $isShowingSettings) {
            settingsView
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                isShowingCamera = false
                viewModel.processCapturedImage(image)
            } onCancel: {
                isShowingCamera = false
            } onError: { error in
                isShowingCamera = false
                viewModel.reportCameraError(error)
            }
            .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: .metaVisionQuickCaptureRequested)) { _ in
            beginQuickCapture()
        }
        .fileImporter(
            isPresented: $isImportingGemma,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await viewModel.installGemmaModel(from: url) }
        }
    }

    private var historyView: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty {
                    ContentUnavailableView(
                        "No recent descriptions",
                        systemImage: "camera.metering.multispot",
                        description: Text("Scenes you describe will appear here and stay on this device.")
                    )
                } else {
                    List {
                        ForEach(viewModel.history) { record in
                            Button {
                                viewModel.open(record)
                                isShowingHistory = false
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(record.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(record.capturedAt, format: .dateTime.month().day().hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: viewModel.deleteHistory)
                    }
                }
            }
            .navigationTitle("Recent descriptions")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingHistory = false }
                }
            }
        }
    }

    private var settingsView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Gemma")
                        .font(.title2.weight(.bold))
                        .padding(.horizontal, 4)

                    settingsCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.isGemmaConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(viewModel.isGemmaConfigured ? .green : .orange)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("On-device model")
                                        .font(.headline)
                                    Text(viewModel.isGemmaConfigured ? "Ready to describe locally" : "Not installed")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 8)
                            }

                            Button {
                                isImportingGemma = true
                            } label: {
                                Label(viewModel.isGemmaConfigured ? "Replace Gemma model" : "Import Gemma model", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }

                    settingsCard {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 14) {
                                TextField("Direct .litertlm URL", text: $modelURL, axis: .vertical)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                                    .textFieldStyle(.roundedBorder)

                                SecureField("Hugging Face read token (optional)", text: $huggingFaceToken)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)

                                if modelDownloader.isDownloading {
                                    ProgressView(value: modelDownloader.progress) {
                                        Text("Downloading Gemma")
                                            .font(.subheadline.weight(.semibold))
                                    } currentValueLabel: {
                                        if modelDownloader.expectedBytes > 0 {
                                            Text("\(modelDownloader.downloadedBytes.formatted(.byteCount(style: .file))) of \(modelDownloader.expectedBytes.formatted(.byteCount(style: .file)))")
                                                .font(.caption)
                                        }
                                    }

                                    Button("Cancel download", role: .destructive) {
                                        modelDownloader.cancel()
                                    }
                                    .buttonStyle(.bordered)
                                } else {
                                    Button("Download and install", action: downloadGemmaModel)
                                        .buttonStyle(.borderedProminent)
                                }

                                Text("The recommended Gemma 4 E2B model is about 2.6 GB. Keep the app open and use Wi-Fi. A token is only needed for gated or private repositories.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 12)
                        } label: {
                            Label("Download from Hugging Face", systemImage: "arrow.down.circle")
                                .font(.headline)
                        }
                    }

                    Text("Select a compatible Gemma .litertlm model downloaded from Google AI Edge. It is copied into the app and runs locally.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    settingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Speech", systemImage: "speaker.wave.2")
                                .font(.headline)

                            HStack {
                                Text("Speaking speed")
                                Spacer()
                                Text(viewModel.speechRate, format: .number.precision(.fractionLength(2)))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }

                            Slider(value: $viewModel.speechRate, in: 0.30...0.60, step: 0.05) {
                                Text("Speaking speed")
                            } minimumValueLabel: {
                                Image(systemName: "tortoise")
                            } maximumValueLabel: {
                                Image(systemName: "hare")
                            }

                            Button("Preview voice", action: viewModel.previewVoice)
                                .buttonStyle(.bordered)
                        }
                    }

                    settingsCard {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Privacy")
                                    .font(.headline)
                                Text("Images are processed on-device; description history stays on this device.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollIndicators(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingSettings = false }
                }
            }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func downloadGemmaModel() {
        let token = huggingFaceToken
        huggingFaceToken = ""
        do {
            try modelDownloader.start(urlString: modelURL, huggingFaceToken: token) { result in
                switch result {
                case .success(let url):
                    Task { await viewModel.installDownloadedGemmaModel(from: url) }
                case .failure(let error) where error is CancellationError:
                    break
                case .failure(let error):
                    viewModel.reportModelDownloadError(error)
                }
            }
        } catch {
            viewModel.reportModelDownloadError(error)
        }
    }

    private var glassesConnectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: glassesConnection.state.symbolName)
                    .font(.title2)
                    .foregroundStyle(glassesConnection.state.isConnected ? .green : Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(
                        (glassesConnection.state.isConnected ? Color.green : Color.accentColor).opacity(0.14),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Meta Ray-Bans")
                            .font(.headline)
                        Text("PROTOTYPE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .foregroundStyle(.secondary)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                    Text(glassesConnection.state.title)
                        .font(.subheadline.weight(.semibold))
                    Text(glassesConnection.state.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Button {
                if glassesConnection.state.isConnected {
                    glassesConnection.disconnect()
                } else {
                    glassesConnection.connect()
                }
            } label: {
                if glassesConnection.state == .connecting {
                    HStack {
                        ProgressView()
                        Text("Connecting…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label(
                        glassesConnection.state.isConnected ? "Disconnect" : "Connect glasses",
                        systemImage: glassesConnection.state.isConnected ? "xmark.circle" : "link"
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(glassesConnection.state == .connecting)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var processingStatusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: viewModel.status.symbolName)
                .font(.title2)
                .foregroundStyle(viewModel.status.tint)
                .frame(width: 44, height: 44)
                .background(viewModel.status.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.status.title)
                    .font(.headline)
                Text(viewModel.status.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private var readButton: some View {
        Button(action: beginQuickCapture) {
            VStack(spacing: 10) {
                if viewModel.status.isBusy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 34, weight: .semibold))
                }

                Text(viewModel.status.isBusy
                     ? viewModel.status.actionTitle
                     : viewModel.isGemmaConfigured ? "Describe this" : "Set up Gemma")
                    .font(.title2.bold())
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .foregroundStyle(.white)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canRead)
        .opacity(viewModel.canRead || viewModel.status.isBusy ? 1 : 0.55)
        .accessibilityHint(viewModel.isGemmaConfigured
                           ? "Immediately captures with the iPhone camera and describes the scene"
                           : "Opens Settings to import an on-device Gemma model")
    }

    private func beginQuickCapture() {
        guard viewModel.canRead, !isShowingCamera else { return }
        if !viewModel.isGemmaConfigured {
            isShowingSettings = true
        } else if UIImagePickerController.isSourceTypeAvailable(.camera) {
            isShowingCamera = true
        } else {
            viewModel.reportCameraUnavailable()
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Image description")
                    .font(.headline)
                Spacer()
                if !viewModel.recognizedText.isEmpty {
                    Text("On device")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Text(viewModel.recognizedText.isEmpty
                 ? "A description of the captured scene will appear here."
                 : viewModel.recognizedText)
                .font(.body)
                .foregroundStyle(viewModel.recognizedText.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if !viewModel.recognizedText.isEmpty {
                Divider()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        readingControls
                    }
                    VStack(spacing: 12) {
                        readingControls
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var readingControls: some View {
        controlButton("Repeat", systemImage: "repeat", action: viewModel.repeatText)
        controlButton("Summarize", systemImage: "text.quote", action: viewModel.summarize)
        controlButton("Stop", systemImage: "stop.fill", action: viewModel.stopSpeaking)
    }

    private func controlButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

extension Notification.Name {
    /// Shared entry point for future App Intent, Action button, Back Tap, and Shortcut triggers.
    static let metaVisionQuickCaptureRequested = Notification.Name("MetaVisionQuickCaptureRequested")
}

#Preview {
    ContentView()
}
