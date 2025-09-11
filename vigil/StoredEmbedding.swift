import Foundation
import UIKit

struct StoredEmbedding: Codable {
    let embedding: [Float]
    let imageFilename: String
}

enum EmbeddingCategory {
    case regular
    case retail
    case unsolved
    case userCustom

    var folder: URL {
        switch self {
        case .regular: return EmbeddingStore.imagesDirectory
        case .retail: return EmbeddingStore.retailImagesDirectory
        case .unsolved: return EmbeddingStore.unknownWantedImagesDirectory
        case .userCustom: return EmbeddingStore.userCustomDirectory
        }
    }

    var jsonFile: URL {
        switch self {
        case .regular: return EmbeddingStore.imagesFile
        case .retail: return EmbeddingStore.retailImagesFile
        case .unsolved: return EmbeddingStore.unknownImagesFile
        case .userCustom: return EmbeddingStore.userCustomFile
        }
    }
}
