import Foundation
import UIKit

/// Represents one embedding + its associated face image
struct StoredEmbedding: Codable {
    let embedding: [Float]
    let imageFilename: String
}

/// Storage for embeddings with images, avoiding duplicates
class EmbeddingStore {
    static let shared = EmbeddingStore()
    
    private var store: [String: StoredEmbedding] = [:]
    
    private init() {
        loadFromDisk()
        createFolderIfNeeded(folder: Self.imagesDirectory)
        createFolderIfNeeded(folder: Self.comparisonDirectory)
    }
    
    // MARK: - Save embedding + face image
    @discardableResult
    func save(_ embedding: [Float], image: UIImage) -> URL? {
        // 1️⃣ Avoid duplicates: check if a similar embedding already exists
        if store.values.contains(where: { cosineSimilarity($0.embedding, embedding) > 0.99 }) {
            print("⚠️ Similar face already exists, skipping save.")
            return nil
        }
        
        // 2️⃣ Generate a unique filename for this image
        let imageFilename = UUID().uuidString + ".jpg"
        let url = Self.imagesDirectory.appendingPathComponent(imageFilename)
        
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        do {
            try data.write(to: url)
        } catch {
            print("❌ Failed to save image: \(error)")
            return nil
        }
        
        // 3️⃣ Save embedding + image reference
        let key = UUID().uuidString
        store[key] = StoredEmbedding(embedding: embedding, imageFilename: imageFilename)
        saveToDisk()
        print("✅ Saved new face embedding and image at: \(url.path)")
        return url
    }
    
    // MARK: - Save comparison image (no embedding)
    @discardableResult
    func saveComparisonImage(_ image: UIImage) -> URL? {
        createFolderIfNeeded(folder: Self.comparisonDirectory)
        
        let filename = UUID().uuidString + ".jpg"
        let fileURL = Self.comparisonDirectory.appendingPathComponent(filename)
        
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

    // MARK: - Load
    func loadAll() -> [String: StoredEmbedding] {
        return store
    }
    
    func exists(key: String) -> Bool {
        return store[key] != nil
    }
    
    func loadImage(for key: String) -> UIImage? {
        guard let stored = store[key] else { return nil }
        let url = Self.imagesDirectory.appendingPathComponent(stored.imageFilename)
        return UIImage(contentsOfFile: url.path)
    }
    
    // MARK: - File handling
    private static let embeddingsFile: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("embeddings.json")
    }()
    
    static let imagesDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("WantedFaces")
    }()
    
    static let comparisonDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("ComparisonFaces")
    }()
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(store)
            try data.write(to: Self.embeddingsFile)
        } catch {
            print("❌ Failed to save embeddings: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: Self.embeddingsFile) else { return }
        if let decoded = try? JSONDecoder().decode([String: StoredEmbedding].self, from: data) {
            store = decoded
        }
    }
    
    private func createFolderIfNeeded(folder: URL) {
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Embedding similarity
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
}

