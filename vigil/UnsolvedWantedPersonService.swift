import Foundation
import SwiftSoup
import UIKit
import Vision

class UnsolvedWantedPersonService {
    static let shared = UnsolvedWantedPersonService()

    private let baseUrl = "https://www.crimestoppersvic.com.au/help-solve-crime/unsolved-cases/"

    private init() {
        createFolderIfNeeded(folder: EmbeddingStore.unknownWantedImagesDirectory)
    }

    // MARK: - Public API
    func refreshWantedUnknownPersons(pages: Int = 20, saveTo folder: URL = EmbeddingStore.unknownWantedImagesDirectory) {
        createFolderIfNeeded(folder: folder)
        DispatchQueue.global(qos: .userInitiated).async {
            self.fetchPersonPageUrls(pages: pages) { personPageUrls in
                self.fetchImageUrls(from: personPageUrls) { imageUrls in
                    self.saveImageEmbeddings(urls: imageUrls, to: folder)
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
            print("✅ Found \(personPageUrls.count) unknown person pages")
            completion(personPageUrls)
        }
    }

    // MARK: - Step 2: Extract image URLs
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
            print("✅ Found \(imageUrls.count) unknown-person images")
            completion(imageUrls)
        }
    }

    // MARK: - Step 3: Align & Save Embeddings to Folder
    private func saveImageEmbeddings(urls: Set<String>, to folder: URL) {
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

                guard let face = self.alignFace(from: image) else {
                    print("⚠️ No valid face in: \(urlStr)")
                    return
                }

                guard let embedding = FaceEmbedding.shared?.embedding(for: face) else {
                    print("❌ Failed to generate embedding for: \(urlStr)")
                    return
                }

                let normalized = self.normalize(embedding)

                if let savedURL = EmbeddingStore.shared.save(normalized, image: face, to: folder) {
                    print("✅ Saved embedding & face image at: \(savedURL.path)")
                } else {
                    print("⚠️ Duplicate face detected, skipping: \(urlStr)")
                }
            }.resume()
        }

        group.notify(queue: .main) {
            print("✅ All \(urls.count) images processed.")
        }
    }

    // MARK: - Face Alignment
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

    // MARK: - Normalize embedding
    private func normalize(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        return vector.map { $0 / (norm + 1e-10) }
    }

    // MARK: - Folder helper
    private func createFolderIfNeeded(folder: URL) {
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }
}

