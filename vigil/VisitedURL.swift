import Foundation

struct VisitedURLInfo: Codable {
    let timestamp: TimeInterval
    let hasFace: Bool
}

class VisitedURLStore {
    static let shared = VisitedURLStore()
    private let fileURL: URL
    private var visitedUrls: [String: VisitedURLInfo] = [:]

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("VisitedURLs.json")
        loadFromDisk()
    }

    func wasVisitedRecently(_ url: String, ignoreDays: Int = 14) -> Bool {
        guard let info = visitedUrls[url] else { return false }
        let interval = Date().timeIntervalSince1970 - info.timestamp
        return interval < Double(ignoreDays) * 24 * 60 * 60
    }

    func markURL(_ url: String, hasFace: Bool) {
        visitedUrls[url] = VisitedURLInfo(timestamp: Date().timeIntervalSince1970, hasFace: hasFace)
        saveToDisk()
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(visitedUrls)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to save visited URLs: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: VisitedURLInfo].self, from: data) else { return }
        visitedUrls = decoded
    }
}

