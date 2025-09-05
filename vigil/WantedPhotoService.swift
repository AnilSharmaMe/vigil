import Foundation
import SwiftSoup
import UIKit
import Vision

class WantedPhotoService {
    static let shared = WantedPhotoService()
    private let baseUrl = "https://www.crimestoppersvic.com.au/help-solve-crime/wanted-persons/"
    
    private init() {
        createFolderIfNeeded(folder: EmbeddingStore.imagesDirectory)
        createFolderIfNeeded(folder: Self.comparisonFolder)
    }

    // MARK: - Comparison faces folder
    static let comparisonFolder: URL = {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ComparisonFaces")
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }()

    // MARK: - Public: refresh wanted persons
    func refreshWantedPersons(pages: Int = 20) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.fetchPersonPageUrls(pages: pages) { personPageUrls in
                self.fetchImageUrls(from: personPageUrls) { imageUrls in
                    self.saveImageEmbeddings(urls: imageUrls)
                }
            }
        }
    }

    // MARK: - Step 1: Fetch all person page URLs
    private func fetchPersonPageUrls(pages: Int, completion: @escaping (Set<String>) -> Void) {
        var personPageUrls = Set<String>()
        let group = DispatchGroup()

        for page in 1...pages {
            group.enter()
            let urlStr = baseUrl + "\(page)"
            guard let url = URL(string: urlStr) else { group.leave(); continue }

            URLSession.shared.dataTask(with: url) { data, _, error in
                defer { group.leave() }
                guard let data = data, error == nil,
                      let html = String(data: data, encoding: .utf8) else { return }

                do {
                    let doc = try SwiftSoup.parse(html)
                    let links = try doc.select("a[href]")
                    for link in links.array() {
                        if let href = try? link.attr("href"),
                           href.starts(with: "https://www.crimestoppersvic.com.au/wanted_persons/") {
                            personPageUrls.insert(href)
                        }
                    }
                } catch {
                    print("⚠️ SwiftSoup parse error: \(error)")
                }
            }.resume()
        }

        group.notify(queue: .main) {
            print("✅ Found \(personPageUrls.count) person pages")
            completion(personPageUrls)
        }
    }

    // MARK: - Step 2: Fetch image URLs from pages
    private func fetchImageUrls(from personPageUrls: Set<String>, completion: @escaping (Set<String>) -> Void) {
        var imageUrls = Set<String>()
        let group = DispatchGroup()

        for urlStr in personPageUrls {
            guard let url = URL(string: urlStr) else { continue }
            group.enter()

            URLSession.shared.dataTask(with: url) { data, _, error in
                defer { group.leave() }
                guard let data = data, error == nil,
                      let html = String(data: data, encoding: .utf8) else { return }

                do {
                    let doc = try SwiftSoup.parse(html)
                    if let meta = try doc.select("meta[property=og:image]").first(),
                       let imageUrl = try? meta.attr("content") {
                        imageUrls.insert(imageUrl)
                    }
                } catch {
                    print("⚠️ SwiftSoup parse error: \(error)")
                }
            }.resume()
        }

        group.notify(queue: .main) {
            print("✅ Found \(imageUrls.count) wanted-person images")
            completion(imageUrls)
        }
    }

    // MARK: - Step 3: Download, align, save images & embeddings
    private func saveImageEmbeddings(urls: Set<String>) {
        let group = DispatchGroup()

        for urlStr in urls {
            guard let url = URL(string: urlStr) else { continue }
            group.enter()

            URLSession.shared.dataTask(with: url) { data, _, error in
                defer { group.leave() }
                guard let data = data, error == nil,
                      let image = UIImage(data: data)?.fixedOrientation() else {
                    print("❌ Failed to download image: \(urlStr)")
                    return
                }

                // Align face
                guard let face = self.alignFace(from: image) else {
                    print("⚠️ No valid face in: \(urlStr)")
                    return
                }

                // Generate embedding
                guard let embedding = FaceEmbedding.shared?.embedding(for: face) else {
                    print("❌ Failed to generate embedding for: \(urlStr)")
                    return
                }

                let normalized = self.normalize(embedding)

                // Save embedding (duplicates skipped internally)
                if let savedURL = EmbeddingStore.shared.save(normalized, image: face) {
                    print("✅ Saved embedding & face image at: \(savedURL.path)")
                } else {
                    print("⚠️ Duplicate face detected, skipping: \(urlStr)")
                }
            }.resume()
        }

        group.notify(queue: .main) {
            print("✅ All \(urls.count) images processed, faces saved, embeddings generated.")
        }
    }

    // MARK: - Face alignment
    func alignFace(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let semaphore = DispatchSemaphore(value: 0)
        var aligned: UIImage?
        
        let request = VNDetectFaceLandmarksRequest { request, _ in
            defer { semaphore.signal() }
            
            guard let face = request.results?.first as? VNFaceObservation,
                  let landmarks = face.landmarks,
                  let leftEye = landmarks.leftEye?.normalizedPoints.first,
                  let rightEye = landmarks.rightEye?.normalizedPoints.first else {
                return
            }
            
            let width = CGFloat(cgImage.width)
            let height = CGFloat(cgImage.height)
            let left = CGPoint(x: leftEye.x * width, y: (1 - leftEye.y) * height)
            let right = CGPoint(x: rightEye.x * width, y: (1 - rightEye.y) * height)
            
            let dx = right.x - left.x
            let dy = right.y - left.y
            let angle = atan2(dy, dx)
            
            guard let rotated = image.rotated(by: -angle)?.fixedOrientation() else { return }
            aligned = FaceCompare.shared.cropFirstFace(from: rotated)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        semaphore.wait()
        return aligned
    }

    // MARK: - Save upright comparison face
    private func saveComparisonImage(_ image: UIImage) -> URL? {
        let filename = UUID().uuidString + ".jpg"
        let fileURL = Self.comparisonFolder.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ Failed to save comparison image: \(error)")
            return nil
        }
    }

    // MARK: - Normalize embedding
    private func normalize(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        return vector.map { $0 / (norm + 1e-10) }
    }

    // MARK: - Cosine similarity helper
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

    // MARK: - Folder helper
    private func createFolderIfNeeded(folder: URL) {
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }
}

// MARK: - UIImage helpers
extension UIImage {
    /// Rotate and return a new image
    func rotated(by radians: CGFloat) -> UIImage? {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size

        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.translateBy(x: rotatedSize.width/2, y: rotatedSize.height/2)
        context.rotate(by: radians)
        draw(in: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height))
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage
    }

    /// Fix orientation issues (EXIF)
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}

