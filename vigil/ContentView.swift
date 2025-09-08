import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var image: UIImage? = nil
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showImageMenu = false
    @State private var isComparing = false
    @State private var matches: [FaceMatch] = []
    @State private var resultMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // MARK: - Image Display
                ZStack(alignment: .topTrailing) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 4)

                        // Remove photo overlay
                        Button(action: { clearImage() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(8)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No image selected")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
                        .shadow(radius: 2)
                    }
                }

                // MARK: - Select Image Button
                if image == nil {
                    Button(action: { showImageMenu = true }) {
                        HStack {
                            Image(systemName: "photo.fill.on.rectangle.fill")
                                .font(.headline)
                            Text("Select Image")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(radius: 4)
                    }
                    .sheet(isPresented: $showImageMenu) {
                        ImageMenuSheet(showCamera: $showCamera,
                                       showGallery: $showGallery,
                                       isPresented: $showImageMenu)
                    }
                }

                // MARK: - Compare Button
                if let image {
                    Button(action: { runFaceComparison(for: image) }) {
                        if isComparing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Compare Faces")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(colors: [Color.green.opacity(0.7), Color.green.opacity(0.4)],
                                                   startPoint: .leading,
                                                   endPoint: .trailing)
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .transition(.opacity)
                }

                // MARK: - Result Message
                if let resultMessage {
                    Text(resultMessage)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }

                // MARK: - Matches List
                if !matches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Matches")
                            .font(.headline)

                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(matches) { match in
                                    HStack(spacing: 12) {
                                        Image(uiImage: match.image)
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        .frame(maxHeight: 200)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Netra")
            .navigationBarTitleDisplayMode(.inline)
        }
        // MARK: - Sheets and Pickers
        .sheet(isPresented: $showCamera) {
            CameraView(image: $image, flashOn: .constant(false))
        }
        .photosPicker(isPresented: $showGallery, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run { image = uiImage }
                }
            }
        }
    }

    // MARK: - Functions
    private func clearImage() {
        image = nil
        selectedItem = nil
        resultMessage = nil
        matches = []
    }

    private func runFaceComparison(for image: UIImage) {
        isComparing = true
        FaceCompare.shared.compareFaces(image: image)
        matches = FaceCompare.shared.matches
        resultMessage = FaceCompare.shared.resultMessage
        isComparing = false
    }
}

// MARK: - Bottom Sheet for Image Selection
struct ImageMenuSheet: View {
    @Binding var showCamera: Bool
    @Binding var showGallery: Bool
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Spacer()

            Button {
                showCamera = true
                isPresented = false
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Take Photo")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.4)],
                                   startPoint: .leading,
                                   endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                showGallery = true
                isPresented = false
            } label: {
                HStack {
                    Image(systemName: "photo.fill")
                    Text("Pick from Gallery")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.3)],
                                   startPoint: .leading,
                                   endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button("Cancel") {
                isPresented = false
            }
            .foregroundColor(.red)
            .padding(.top)

            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
        .background(Color(.systemBackground))
    }
}

