import SwiftUI
import PhotosUI
import UIKit

struct FacePickerView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var matchResult: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("Select Photo")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .onChange(of: selectedItem) { newItem in
                loadImage(from: newItem)
            }
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
            }
            
            Button("Compare Faces") {
                if let image = selectedImage {
                    FaceCompare.shared.compareFaces(image: image)
                    matchResult = FaceCompare.shared.resultMessage ?? "Processing..."
                }
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Text(matchResult)
                .padding()
        }
        .padding()
    }
    
    // MARK: - Load UIImage safely from PhotosPickerItem
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return } // safe unwrap
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data)?.withFixedOrientation() {
                    selectedImage = image
                }
            } catch {
                print("❌ Failed to load image from picker: \(error)")
            }
        }
    }
}
