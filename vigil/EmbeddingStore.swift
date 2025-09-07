import Foundation
import UIKit

/// Represents one embedding + its associated face image
struct StoredEmbedding: Codable {
    let embedding: [Float]
    let imageFilename: String
}

/// Categories for embeddings
enum EmbeddingCategory {
    case regular
    case retail
    case unsolved

    var folder: URL {
        switch self {
        case .regular: return EmbeddingStore.imagesDirectory
        case .retail: return EmbeddingStore.retailImagesDirectory
        case .unsolved: return EmbeddingStore.unknownWantedImagesDirectory
        }
    }

    var jsonFile: URL {
        switch self {
        case .regular: return EmbeddingStore.imagesFile
        case .retail: return EmbeddingStore.retailImagesFile
        case .unsolved: return EmbeddingStore.unknownImagesFile
        }
    }
}

/// Storage for embeddings with images, avoiding duplicates, separate per category
class EmbeddingStore {
    static let shared = EmbeddingStore()

    private var stores: [EmbeddingCategory: [String: StoredEmbedding]] = [:]

    private init() {
        // Initialize folders
        [EmbeddingCategory.regular, .retail, .unsolved].forEach {
            createFolderIfNeeded(folder: $0.folder)
        }
        createFolderIfNeeded(folder: EmbeddingStore.comparisonDirectory)

        // Load embeddings for all categories
        [EmbeddingCategory.regular, .retail, .unsolved].forEach {
            stores[$0] = loadFromDisk(for: $0)
        }
    }

    // MARK: - Save embedding + face image
    @discardableResult
    func save(_ embedding: [Float], image: UIImage, category: EmbeddingCategory) -> URL? {
        createFolderIfNeeded(folder: category.folder)

        // Avoid duplicates
        let store = stores[category] ?? [:]
        if store.values.contains(where: { cosineSimilarity($0.embedding, embedding) > 0.99 }) {
            print("⚠️ Similar face already exists in \(category), skipping save.")
            return nil
        }

        // Save image
        let imageFilename = UUID().uuidString + ".jpg"
        let url = category.folder.appendingPathComponent(imageFilename)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        do {
            try data.write(to: url)
        } catch {
            print("❌ Failed to save image: \(error)")
            return nil
        }

        // Save embedding reference
        let key = UUID().uuidString
        var updatedStore = store
        updatedStore[key] = StoredEmbedding(embedding: embedding, imageFilename: imageFilename)
        stores[category] = updatedStore
        saveToDisk(store: updatedStore, category: category)

        print("✅ Saved embedding & image for \(category) at: \(url.path)")
        return url
    }

    // MARK: - Load image for a key
    func loadImage(for key: String, category: EmbeddingCategory) -> UIImage? {
        guard let stored = stores[category]?[key] else { return nil }
        let url = category.folder.appendingPathComponent(stored.imageFilename)
        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Load all embeddings for a category
    func loadAll(category: EmbeddingCategory) -> [String: StoredEmbedding] {
        return stores[category] ?? [:]
    }

    // MARK: - Save comparison image
    @discardableResult
    func saveComparisonImage(_ image: UIImage, to folder: URL? = nil) -> URL? {
        let targetFolder = folder ?? EmbeddingStore.comparisonDirectory
        createFolderIfNeeded(folder: targetFolder)
        let filename = UUID().uuidString + ".jpg"
        let fileURL = targetFolder.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        do {
            try data.write(to: fileURL)
            print("✅ Saved comparison image at: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Failed to save comparison image: \(error)")
            return nil
        }
    }

    // MARK: - File handling
    private func saveToDisk(store: [String: StoredEmbedding], category: EmbeddingCategory) {
        do {
            let data = try JSONEncoder().encode(store)
            try data.write(to: category.jsonFile)
        } catch {
            print("❌ Failed to save embeddings for \(category): \(error)")
        }
    }

    private func loadFromDisk(for category: EmbeddingCategory) -> [String: StoredEmbedding] {
        guard let data = try? Data(contentsOf: category.jsonFile) else { return [:] }
        if let decoded = try? JSONDecoder().decode([String: StoredEmbedding].self, from: data) {
            return decoded
        }
        return [:]
    }

    // MARK: - Folder helpers
    private func createFolderIfNeeded(folder: URL) {
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    // MARK: - Cosine similarity
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        return dot / (sqrt(normA) * sqrt(normB) + 1e-10)
    }

    // MARK: - Directories
    static let imagesFile = documentsURL().appendingPathComponent("WantedFaces.json")
    static let retailImagesFile = documentsURL().appendingPathComponent("RetailWantedFaces.json")
    static let unknownImagesFile = documentsURL().appendingPathComponent("UnknownWantedFaces.json")

    static let imagesDirectory: URL = documentsURL().appendingPathComponent("WantedFaces")
    static let retailImagesDirectory: URL = documentsURL().appendingPathComponent("RetailWantedFaces")
    static let unknownWantedImagesDirectory: URL = documentsURL().appendingPathComponent("UnknownWantedFaces")
    static let comparisonDirectory: URL = documentsURL().appendingPathComponent("ComparisonFaces")

    private static func documentsURL() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

