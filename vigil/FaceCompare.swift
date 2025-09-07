import UIKit
import Vision

struct FaceMatch: Identifiable {
    let id = UUID()
    let key: String
    let similarity: Float   // Higher = better match (0..1)
    let image: UIImage
}

class FaceCompare {
    static let shared = FaceCompare()
    private init() {}

    var matches: [FaceMatch] = []
    var isProcessing = false
    var resultMessage: String?

    // MARK: - Compare faces using cosine similarity across all categories
    func compareFaces(image: UIImage, threshold: Float = 0.8) {
        let fixedImage = image.withFixedOrientation()

        guard let alignedFace = alignFace(from: fixedImage),
              let faceEmbedding = FaceEmbedding.shared,
              let capturedEmbedding = faceEmbedding.embedding(for: alignedFace) else {
            self.resultMessage = "❌ No face detected or embedding failed"
            return
        }

        // Save upright comparison face
        _ = EmbeddingStore.shared.saveComparisonImage(alignedFace)

        self.isProcessing = true
        self.matches = []

        var foundMatches: [FaceMatch] = []

        // Compare against all categories
        let allCategories: [EmbeddingCategory] = [.regular, .retail, .unsolved]
        for category in allCategories {
            let store = EmbeddingStore.shared.loadAll(category: category)
            for (key, stored) in store {
                let similarity = cosineSimilarity(capturedEmbedding, stored.embedding)
                if similarity >= threshold,
                   let storedImage = loadImage(for: key, category: category) {
                    foundMatches.append(FaceMatch(key: key, similarity: similarity, image: storedImage))
                }
            }
        }

        // Sort matches by descending similarity
        self.matches = foundMatches.sorted { $0.similarity > $1.similarity }

        self.resultMessage = foundMatches.isEmpty
            ? "❌ No matches found"
            : "✅ Matches found: \(foundMatches.count)"
        self.isProcessing = false
        print("✅ Comparison complete. Highest similarity: \(self.matches.first?.similarity ?? 0), total matches: \(foundMatches.count), threshold: \(threshold)")
    }

    // MARK: - Load stored image for a specific category
    private func loadImage(for key: String, category: EmbeddingCategory) -> UIImage? {
        guard let stored = EmbeddingStore.shared.loadAll(category: category)[key] else { return nil }
        let url = category.folder.appendingPathComponent(stored.imageFilename)
        return UIImage(contentsOfFile: url.path)?.withFixedOrientation()
    }

    // MARK: - Align face using eyes
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

            guard let rotated = image.rotated(by: -angle)?.withFixedOrientation() else { return }

            aligned = self.cropFirstFace(from: rotated)?.withFixedOrientation()
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        semaphore.wait()
        return aligned
    }

    // MARK: - Crop first detected face (square)
    public func cropFirstFace(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let face = request.results?.first as? VNFaceObservation else { return nil }

            let boundingBox = face.boundingBox
            let width = CGFloat(cgImage.width)
            let height = CGFloat(cgImage.height)

            var rect = CGRect(
                x: boundingBox.origin.x * width,
                y: (1 - boundingBox.origin.y - boundingBox.size.height) * height,
                width: boundingBox.size.width * width,
                height: boundingBox.size.height * height
            )

            // Make square
            if rect.width > rect.height {
                let diff = rect.width - rect.height
                rect.origin.y -= diff / 2
                rect.size.height = rect.width
            } else {
                let diff = rect.height - rect.width
                rect.origin.x -= diff / 2
                rect.size.width = rect.height
            }

            // Clamp to bounds
            rect.origin.x = max(rect.origin.x, 0)
            rect.origin.y = max(rect.origin.y, 0)
            rect.size.width = min(rect.size.width, width - rect.origin.x)
            rect.size.height = min(rect.size.height, height - rect.origin.y)

            if let faceCg = cgImage.cropping(to: rect) {
                return UIImage(cgImage: faceCg).withFixedOrientation()
            }
        } catch {
            print("❌ Face detection error:", error)
        }
        return nil
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
        return dot / (sqrt(normA) * sqrt(normB) + 1e-6)
    }
}

// MARK: - UIImage helpers
extension UIImage {
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
}

