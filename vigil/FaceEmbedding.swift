import CoreML
import UIKit

class FaceEmbedding {
    static let shared = FaceEmbedding()
    
    // Replace `ArcFace` with your actual CoreML class name
    private let model: ArcFace
    
    private init?() {
            do {
                let config = MLModelConfiguration()
                self.model = try ArcFace(configuration: config)
            } catch {
                print("❌ Failed to load ArcFace model: \(error)")
                return nil  // ✅ allowed because initializer is failable
            }
    }
    
    // MARK: - Convert UIImage → MLMultiArray (1x3x112x112)
    private func preprocess(_ image: UIImage) -> MLMultiArray? {
        guard let cgImage = image.fixedOrientation().cgImage else { return nil }
        
        let width = 112
        let height = 112
        
        // Resize image
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 1.0)
        UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let finalImage = resized?.cgImage else { return nil }
        
        // Prepare pixel data
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(finalImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixelData = context.data else { return nil }
        let ptr = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Create MLMultiArray
        guard let array = try? MLMultiArray(shape: [1, 3, 112, 112], dataType: .float32) else { return nil }
        
        // Fill array in [1,3,112,112] (RGB)
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let r = Float(ptr[idx]) / 255.0
                let g = Float(ptr[idx + 1]) / 255.0
                let b = Float(ptr[idx + 2]) / 255.0
                
                array[[0, 0, NSNumber(value: y), NSNumber(value: x)]] = NSNumber(value: r)
                array[[0, 1, NSNumber(value: y), NSNumber(value: x)]] = NSNumber(value: g)
                array[[0, 2, NSNumber(value: y), NSNumber(value: x)]] = NSNumber(value: b)
            }
        }
        return array
    }
    
    // MARK: - Extract embedding
    func embedding(for image: UIImage) -> [Float]? {
        guard let mlArray = preprocess(image) else { return nil }
        guard let output = try? model.prediction(x_1: mlArray) else { return nil }
        
        let varArray = output.var_657
        var vector = [Float](repeating: 0, count: varArray.count)
        for i in 0..<varArray.count {
            vector[i] = varArray[i].floatValue
        }
        
        return l2Normalize(vector)
    }
    
    // MARK: - L2 Normalize
    private func l2Normalize(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
    
    // MARK: - Euclidean distance
    func euclideanDistance(_ v1: [Float], _ v2: [Float]) -> Float {
        precondition(v1.count == v2.count, "Vectors must have same length")
        return sqrt(zip(v1, v2).map { ($0 - $1) * ($0 - $1) }.reduce(0, +))
    }
}


