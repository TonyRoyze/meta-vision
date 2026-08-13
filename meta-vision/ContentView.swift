import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ReadingViewModel()

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
