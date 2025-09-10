import Photos
import UIKit

class PhotoHelper {
    static let shared = PhotoHelper()
    
    private init() {}
    
    // MARK: - Fetch PHAsset by original filename
    func fetchAsset(named filename: String) -> PHAsset? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "filename == %@", "\(filename).png")
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        return fetchResult.firstObject
    }
    
    // MARK: - Get UIImage from PHAsset
    func getImage(from asset: PHAsset, targetSize: CGSize = CGSize(width: 160, height: 160)) -> UIImage? {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        
        var resultImage: UIImage? = nil
        imageManager.requestImage(for: asset,
                                  targetSize: targetSize,
                                  contentMode: .aspectFit,
                                  options: requestOptions) { image, _ in
            resultImage = image
        }
        return resultImage
    }
    
    // MARK: - Save UIImage to Photo Library
    func saveImageToLibrary(_ image: UIImage, completion: ((Bool, Error?) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion?(false, nil)
                return
            }
            
            var placeholder: PHObjectPlaceholder?
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                placeholder = request.placeholderForCreatedAsset
            }) { success, error in
                DispatchQueue.main.async {
                    completion?(success, error)
                }
            }
        }
    }
    
    // MARK: - Generate thumbnail from UIImage
    func generateThumbnail(from image: UIImage, maxSize: CGFloat = 160) -> UIImage? {
        let aspectRatio = image.size.width / image.size.height
        var newSize: CGSize
        if aspectRatio > 1 {
            newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return thumbnail
    }
    
    // MARK: - Convert UIImage to PNG Data
    func imageToData(_ image: UIImage) -> Data? {
        return image.pngData()
    }
    
    // MARK: - Save UIImage to custom app folder
    func saveImageToDocuments(_ image: UIImage, folderName: String, fileName: String) -> URL? {
        let folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        
        let fileURL = folderURL.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ Failed to save image to documents: \(error)")
            return nil
        }
    }
    
    // MARK: - Fetch all images from a folder
    func fetchImages(fromFolder folderName: String) -> [UIImage] {
        let folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName)
        guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var images: [UIImage] = []
        for fileURL in files {
            if let data = try? Data(contentsOf: fileURL),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        return images
    }
}

