import Foundation
import SwiftSoup
import UIKit
import Vision

enum WantedPersonCategory {
    case unsolved
    case regular
    case retail

    var embeddingCategory: EmbeddingCategory {
        switch self {
        case .unsolved: return .unsolved
        case .regular: return .regular
        case .retail: return .retail
        }
    }
}

class WantedPersonServiceManager {
    static let shared = WantedPersonServiceManager()
    private init() {}

    // MARK: - Public API
    /// Refresh wanted persons for a specific category
    func refresh(category: WantedPersonCategory,
                 pages: Int = 20,
                 includeComparisonFolder: Bool = false) {
        
        let targetFolder = category.embeddingCategory.folder
        createFolderIfNeeded(folder: targetFolder)
        
        var comparisonFolder: URL?
        if includeComparisonFolder {
            comparisonFolder = EmbeddingStore.comparisonDirectory
            createFolderIfNeeded(folder: comparisonFolder!)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.fetchPersonPageUrls(category: category, pages: pages) { personPageUrls in
                self.fetchImageUrls(from: personPageUrls) { imageUrls in
                    self.saveImageEmbeddings(urls: imageUrls,
                                             category: category.embeddingCategory,
                                             comparisonFolder: comparisonFolder)
                }
            }
        }
    }

    // MARK: - Folder helper
    private func createFolderIfNeeded(folder: URL) {
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    // MARK: - Step 1: Fetch person page URLs
    private func fetchPersonPageUrls(category: WantedPersonCategory,
                                     pages: Int,
                                     completion: @escaping (Set<String>) -> Void) {
        let baseUrl: String
        switch category {
        case .unsolved:
            baseUrl = "https://www.crimestoppersvic.com.au/help-solve-crime/unsolved-cases/"
        case .regular:
            baseUrl = "https://www.crimestoppersvic.com.au/help-solve-crime/wanted-persons/"
        case .retail:
            baseUrl = "https://www.crimestoppersvic.com.au/help-solve-crime/wanted-persons/retail-crime/"
        }

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
                           href.starts(with: "https://www.crimestoppersvic.com.au/") {
                            personPageUrls.insert(href)
                        }
                    }
                } catch {
                    print("⚠️ SwiftSoup parse error: \(error)")
                }
            }.resume()
        }

        group.notify(queue: .main) {
            print("✅ Found \(personPageUrls.count) \(category) pages")
            completion(personPageUrls)
        }
    }

    // MARK: - Step 2: Fetch image URLs
    private func fetchImageUrls(from personPageUrls: Set<String>,
                                completion: @escaping (Set<String>) -> Void) {
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
            print("✅ Found \(imageUrls.count) images")
            completion(imageUrls)
        }
    }

    // MARK: - Step 3: Download, align, generate embeddings
    private func saveImageEmbeddings(urls: Set<String>,
                                     category: EmbeddingCategory,
                                     comparisonFolder: URL?) {
        let group = DispatchGroup()

        for urlStr in urls {
            guard let url = URL(string: urlStr) else { continue }
            group.enter()

            URLSession.shared.dataTask(with: url) { data, _, error in
                defer { group.leave() }
                guard let data = data, error == nil,
                      let image = UIImage(data: data)?.withFixedOrientation() else {
                    print("❌ Failed to download image: \(urlStr)")
                    return
                }

                guard let face = self.alignFace(from: image) else {
                    print("⚠️ No valid face in: \(urlStr)")
                    return
                }

                guard let embedding = FaceEmbedding.shared?.embedding(for: face) else {
                    print("❌ Failed to generate embedding for: \(urlStr)")
                    return
                }

                let normalized = self.normalize(embedding)

                if let savedURL = EmbeddingStore.shared.save(normalized, image: face, category: category) {
                    if let compFolder = comparisonFolder {
                        _ = EmbeddingStore.shared.saveComparisonImage(face, to: compFolder)
                    }
                } else {
                    print("⚠️ Duplicate face detected, skipping: \(urlStr)")
                }
            }.resume()
        }

        group.notify(queue: .main) {
            print("✅ All \(urls.count) images processed for category \(category)")
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
                  let rightEye = landmarks.rightEye?.normalizedPoints.first else { return }

            let width = CGFloat(cgImage.width)
            let height = CGFloat(cgImage.height)

            let left = CGPoint(x: leftEye.x * width, y: (1 - leftEye.y) * height)
            let right = CGPoint(x: rightEye.x * width, y: (1 - rightEye.y) * height)

            let dx = right.x - left.x
            let dy = right.y - left.y
            let angle = atan2(dy, dx)

            guard let rotated = image.rotatedImage(by: -angle)?.withFixedOrientation() else { return }

            aligned = FaceCompare.shared.cropFirstFace(from: rotated)?.withFixedOrientation()
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        semaphore.wait()
        return aligned
    }

    // MARK: - Normalize embedding
    private func normalize(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        return vector.map { $0 / (norm + 1e-10) }
    }
}

// MARK: - UIImage helpers
extension UIImage {
    func withFixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }

    func rotatedImage(by radians: CGFloat) -> UIImage? {
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
}

