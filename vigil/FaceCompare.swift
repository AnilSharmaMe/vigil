import UIKit
import Vision

struct FaceMatch: Identifiable {
    let id = UUID()
    let key: String
    let similarity: Float
    let image: UIImage
}

class FaceCompare {
    static let shared = FaceCompare()
    private init() {}

    var matches: [FaceMatch] = []
    var isProcessing = false
    var resultMessage: String?

    func compareFaces(image: UIImage, threshold: Float = 0.8) {
        guard let alignedFace = alignFace(from: image.withFixedOrientation()),
              let embedding = FaceEmbedding.shared?.embedding(for: alignedFace) else {
            resultMessage = "❌ No face detected or embedding failed"
            return
        }

        _ = EmbeddingStore.shared.saveComparisonImage(alignedFace)

        isProcessing = true
        matches = []

        var foundMatches: [FaceMatch] = []
        let categories: [EmbeddingCategory] = [.regular, .retail, .unsolved]

        for category in categories {
            let store = EmbeddingStore.shared.loadAll(category: category)
            for (key, stored) in store {
                let similarity = cosineSimilarity(embedding, stored.embedding)
                if similarity >= threshold,
                   let storedImage = UIImage(contentsOfFile: category.folder.appendingPathComponent(stored.imageFilename).path)?.withFixedOrientation() {
                    foundMatches.append(FaceMatch(key: key, similarity: similarity, image: storedImage))
                }
            }
        }

        matches = foundMatches.sorted { $0.similarity > $1.similarity }
        resultMessage = foundMatches.isEmpty ? "❌ No matches found" : "✅ Matches found: \(foundMatches.count)"
        isProcessing = false
    }

    func alignFace(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        var aligned: UIImage?
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNDetectFaceLandmarksRequest { request, _ in
            defer { semaphore.signal() }
            guard let face = request.results?.first as? VNFaceObservation,
                  let landmarks = face.landmarks,
                  let leftEye = landmarks.leftEye?.normalizedPoints.first,
                  let rightEye = landmarks.rightEye?.normalizedPoints.first else { return }

            let width = CGFloat(cgImage.width)
            let height = CGFloat(cgImage.height)
            let left = CGPoint(x: leftEye.x * width, y: (1-leftEye.y)*height)
            let right = CGPoint(x: rightEye.x * width, y: (1-rightEye.y)*height)
            let angle = atan2(right.y-left.y, right.x-left.x)

            if let rotated = image.rotatedImage(by: -angle)?.withFixedOrientation() {
                aligned = self.cropFirstFace(from: rotated)
            }
        }

        try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        semaphore.wait()
        return aligned
    }

    func cropFirstFace(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        guard let face = request.results?.first as? VNFaceObservation else { return nil }

        var rect = CGRect(
            x: face.boundingBox.origin.x * CGFloat(cgImage.width),
            y: (1-face.boundingBox.origin.y-face.boundingBox.height) * CGFloat(cgImage.height),
            width: face.boundingBox.width * CGFloat(cgImage.width),
            height: face.boundingBox.height * CGFloat(cgImage.height)
        )

        let sizeDiff = max(rect.width, rect.height) - min(rect.width, rect.height)
        if rect.width > rect.height { rect.origin.y -= sizeDiff/2; rect.size.height = rect.width }
        else { rect.origin.x -= sizeDiff/2; rect.size.width = rect.height }

        rect.origin.x = max(rect.origin.x, 0)
        rect.origin.y = max(rect.origin.y, 0)
        rect.size.width = min(rect.size.width, CGFloat(cgImage.width)-rect.origin.x)
        rect.size.height = min(rect.size.height, CGFloat(cgImage.height)-rect.origin.y)

        return cgImage.cropping(to: rect).map { UIImage(cgImage: $0).withFixedOrientation() }
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        var dot: Float = 0, normA: Float = 0, normB: Float = 0
        for i in 0..<a.count { dot += a[i]*b[i]; normA += a[i]*a[i]; normB += b[i]*b[i] }
        return dot / (sqrt(normA)*sqrt(normB)+1e-6)
    }
}

extension UIImage {
    func withFixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
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
        let rotated = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotated
    }
}

