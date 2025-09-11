import UIKit
import Vision

class WantedPersonServiceManager {
    static let shared = WantedPersonServiceManager()
    private init() {}

    // MARK: - Align face (reuse FaceCompare logic)
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
    
    // MARK: - Crop first detected face (square)
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
        
        // Make square
        let sizeDiff = max(rect.width, rect.height) - min(rect.width, rect.height)
        if rect.width > rect.height { rect.origin.y -= sizeDiff/2; rect.size.height = rect.width }
        else { rect.origin.x -= sizeDiff/2; rect.size.width = rect.height }
        
        rect.origin.x = max(rect.origin.x, 0)
        rect.origin.y = max(rect.origin.y, 0)
        rect.size.width = min(rect.size.width, CGFloat(cgImage.width)-rect.origin.x)
        rect.size.height = min(rect.size.height, CGFloat(cgImage.height)-rect.origin.y)
        
        return cgImage.cropping(to: rect).map { UIImage(cgImage: $0).withFixedOrientation() }
    }
    
    // MARK: - Normalize embedding to unit vector
    func normalize(_ embedding: [Float]) -> [Float] {
        let norm = sqrt(embedding.reduce(0) { $0 + $1*$1 })
        return norm > 0 ? embedding.map { $0 / norm } : embedding
    }
    
    // MARK: - Save person embedding and image
    func savePerson(_ embedding: [Float], image: UIImage, category: EmbeddingCategory = .userCustom) -> Bool {
        let normalized = normalize(embedding)
        let savedURL = EmbeddingStore.shared.save(normalized, image: image, category: category)
        return savedURL != nil
    }
    
    // MARK: - Refresh embeddings for a category
    func refresh(category: EmbeddingCategory) {
        print("Refreshing embeddings for category: \(category)")
        // Example: reload embeddings from storage
        _ = EmbeddingStore.shared.loadAll(category: category)
    }
}

