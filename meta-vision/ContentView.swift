import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ReadingViewModel()
    @State private var isShowingHistory = false
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    connectionCard
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
                    .accessibilityHint("Shows recent documents read on this device")

                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
            }
        }
        .task {
            await viewModel.connect()
        }
        .alert("Something went wrong", isPresented: $viewModel.isShowingError) {
            Button("Try again") {
                viewModel.retry()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
        .sheet(isPresented: $isShowingHistory) {
            historyView
        }
        .sheet(isPresented: $isShowingSettings) {
            settingsView
        }
    }

    private var historyView: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty {
                    ContentUnavailableView(
                        "No recent readings",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Documents you read will appear here and stay on this device.")
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
            .navigationTitle("Recent readings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingHistory = false }
                }
            }
        }
    }

    private var settingsView: some View {
        NavigationStack {
            Form {
                Section("Speech") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Speaking speed", systemImage: "speaker.wave.2")
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
                    }

                    Button("Preview voice") {
                        viewModel.previewVoice()
                    }
                }

                Section("Privacy") {
                    Label("OCR and reading history stay on this device.", systemImage: "lock.shield")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingSettings = false }
                }
            }
        }
    }

    private var connectionCard: some View {
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
        Button {
            viewModel.readDocument()
        } label: {
            VStack(spacing: 10) {
                if viewModel.status.isBusy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 34, weight: .semibold))
                }

                Text(viewModel.status.isBusy ? viewModel.status.actionTitle : "Read this")
                    .font(.title2.bold())
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .foregroundStyle(.white)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canRead)
        .opacity(viewModel.canRead || viewModel.status.isBusy ? 1 : 0.55)
        .accessibilityHint("Captures a document using the connected glasses and reads it aloud")
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recognized text")
                    .font(.headline)
                Spacer()
                if !viewModel.recognizedText.isEmpty {
                    Text("On device")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Text(viewModel.recognizedText.isEmpty
                 ? "Captured text will appear here."
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

#Preview {
    ContentView()
}
