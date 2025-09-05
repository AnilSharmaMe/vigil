import Photos
import UIKit

class PhotoHelper {
    static let shared = PhotoHelper()
    
    private init() {}
    
    /// Fetch PHAsset by original filename
    func fetchAsset(named filename: String) -> PHAsset? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "filename == %@", "\(filename).png")
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        return fetchResult.firstObject
    }
    
    /// Get UIImage from PHAsset
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
}

