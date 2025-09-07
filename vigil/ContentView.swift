import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var flashOn = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var image: UIImage? = nil
    @State private var isUploading = false
    @State private var uploadResult: String? = nil
    @State private var matches: [FaceMatch] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    imageCard
                    resultSection
                    matchesSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Netra")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCamera) {
                CameraView(image: $image, flashOn: $flashOn)
            }
        }
    }
    
    // MARK: - Image Card
    private var imageCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .frame(minHeight: 250)
                .shadow(radius: 4)
            
            if let image {
                ZStack(alignment: .bottom) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    HStack(spacing: 16) {
                        Button(action: { clearImage() }) {
                            Label("Remove", systemImage: "xmark.circle.fill")
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { Task { await runFaceComparison(for: image) } }) {
                            if isUploading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Label("Compare", systemImage: "faceid")
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                }
                .padding(8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundColor(.gray.opacity(0.6))
                    Text("Tap to select image")
                        .foregroundColor(.gray)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 250)
                .contentShape(Rectangle())
                .onTapGesture {
                    showImagePicker()
                }
            }
        }
    }
    
    // MARK: - Show Image Picker
    private func showImagePicker() {
        let actionSheet = UIAlertController(title: "Choose Image", message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default) { _ in showCamera = true })
        actionSheet.addAction(UIAlertAction(title: "Gallery", style: .default) { _ in
            // Trigger PhotosPicker by updating selectedItem
            selectedItem = nil
        })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        rootVC.present(actionSheet, animated: true)
    }
    
    // MARK: - Result Section
    @ViewBuilder
    private var resultSection: some View {
        if let result = uploadResult {
            Text(result)
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))
                .foregroundColor(.green)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Matches Section
    @ViewBuilder
    private var matchesSection: some View {
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Matches")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                LazyVStack(spacing: 12) {
                    ForEach(matches) { match in
                        HStack(spacing: 12) {
                            Image(uiImage: match.image)
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(radius: 2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(match.key)
                                    .font(.headline)
                                Text("Similarity: \(String(format: "%.2f", match.similarity))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                    }
                }
            }
        }
    }
    
    // MARK: - Functions
    private func runFaceComparison(for image: UIImage) async {
        await MainActor.run { isUploading = true }
        FaceCompare.shared.compareFaces(image: image)
        await MainActor.run {
            matches = FaceCompare.shared.matches
            uploadResult = FaceCompare.shared.resultMessage
            isUploading = false
        }
    }
    
    private func clearImage() {
        image = nil
        selectedItem = nil
        uploadResult = nil
        matches = []
    }
}

