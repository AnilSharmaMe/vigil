import Foundation
import UIKit

class EmbeddingStore {
    static let shared = EmbeddingStore()
    private var stores: [EmbeddingCategory: [String: StoredEmbedding]] = [:]

    private init() {
        [EmbeddingCategory.regular, .retail, .unsolved].forEach { createFolderIfNeeded(folder: $0.folder) }
        createFolderIfNeeded(folder: EmbeddingStore.comparisonDirectory)
        [EmbeddingCategory.regular, .retail, .unsolved].forEach { stores[$0] = loadFromDisk(for: $0) }
    }

    @discardableResult
    func save(_ embedding: [Float], image: UIImage, category: EmbeddingCategory) -> URL? {
        createFolderIfNeeded(folder: category.folder)
        let store = stores[category] ?? [:]
        if store.values.contains(where: { cosineSimilarity($0.embedding, embedding) > 0.99 }) { return nil }
        let imageFilename = UUID().uuidString + ".jpg"
        let url = category.folder.appendingPathComponent(imageFilename)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        do { try data.write(to: url) } catch { return nil }
        let key = UUID().uuidString
        var updatedStore = store
        updatedStore[key] = StoredEmbedding(embedding: embedding, imageFilename: imageFilename)
        stores[category] = updatedStore
        saveToDisk(store: updatedStore, category: category)
        return url
    }

    func loadAll(category: EmbeddingCategory) -> [String: StoredEmbedding] { stores[category] ?? [:] }

    @discardableResult
    func saveComparisonImage(_ image: UIImage, to folder: URL? = nil) -> URL? {
        let targetFolder = folder ?? EmbeddingStore.comparisonDirectory
        createFolderIfNeeded(folder: targetFolder)
        let filename = UUID().uuidString + ".jpg"
        let fileURL = targetFolder.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        try? data.write(to: fileURL)
        return fileURL
    }

    private func saveToDisk(store: [String: StoredEmbedding], category: EmbeddingCategory) {
        if let data = try? JSONEncoder().encode(store) { try? data.write(to: category.jsonFile) }
    }

    private func loadFromDisk(for category: EmbeddingCategory) -> [String: StoredEmbedding] {
        guard let data = try? Data(contentsOf: category.jsonFile),
              let decoded = try? JSONDecoder().decode([String: StoredEmbedding].self, from: data) else { return [:] }
        return decoded
    }

    private func createFolderIfNeeded(folder: URL) {
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        var dot: Float = 0, normA: Float = 0, normB: Float = 0
        for i in 0..<a.count { dot += a[i]*b[i]; normA += a[i]*a[i]; normB += b[i]*b[i] }
        return dot / (sqrt(normA)*sqrt(normB)+1e-10)
    }

    static let imagesFile = documentsURL().appendingPathComponent("WantedFaces.json")
    static let retailImagesFile = documentsURL().appendingPathComponent("RetailWantedFaces.json")
    static let unknownImagesFile = documentsURL().appendingPathComponent("UnknownWantedFaces.json")
    static let userCustomFile = documentsURL().appendingPathComponent("UserCustomFaces.json")

    static let imagesDirectory = documentsURL().appendingPathComponent("WantedFaces")
    static let retailImagesDirectory = documentsURL().appendingPathComponent("RetailWantedFaces")
    static let unknownWantedImagesDirectory = documentsURL().appendingPathComponent("UnknownWantedFaces")
    static let comparisonDirectory = documentsURL().appendingPathComponent("ComparisonFaces")
    static let userCustomDirectory = documentsURL().appendingPathComponent("UserCustomFaces")

    private static func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

