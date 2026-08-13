import Foundation

struct ReadingRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let capturedAt: Date

    init(id: UUID = UUID(), text: String, capturedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.capturedAt = capturedAt
    }

    var title: String {
        text.split(separator: "\n").first.map(String.init) ?? "Reading"
    }
}

@MainActor
final class ReadingHistoryStore {
    private let defaults: UserDefaults
    private let key = "readingHistory"
    private let maximumCount = 20

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [ReadingRecord] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ReadingRecord].self, from: data)) ?? []
    }

    func add(text: String, to records: [ReadingRecord]) -> [ReadingRecord] {
        let updated = Array(([ReadingRecord(text: text)] + records).prefix(maximumCount))
        save(updated)
        return updated
    }

    func delete(at offsets: IndexSet, from records: [ReadingRecord]) -> [ReadingRecord] {
        var updated = records
        for index in offsets.sorted(by: >) {
            updated.remove(at: index)
        }
        save(updated)
        return updated
    }

    private func save(_ records: [ReadingRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }
}
