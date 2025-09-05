import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var image: UIImage? = nil
    @State private var isUploading = false
    @State private var uploadResult: String? = nil
    @State private var matches: [FaceMatch] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                imageSection
                cameraButton
                galleryPicker
                compareButton
                resultSection
                matchesSection
                Spacer()
            }
            .padding()
            .navigationTitle("Face Compare")
        }
    }
}

private extension ContentView {
    @ViewBuilder
    var imageSection: some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 4)
        } else {
            Text("No image selected")
                .foregroundStyle(.secondary)
        }
    }

    var cameraButton: some View {
        Button(action: { showCamera = true }) {
            Label("Take Photo", systemImage: "camera")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: $image)
        }
    }

    var galleryPicker: some View {
        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
            Label("Pick from Gallery", systemImage: "photo")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.indigo)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onChange(of: selectedItem) { newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run { image = uiImage }
                }
            }
        }
    }

    var compareButton: some View {
        Group {
            if let image = image {
                Button {
                    Task { await runFaceComparison(for: image) }
                } label: {
                    if isUploading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Compare Faces", systemImage: "arrow.up.circle")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    @ViewBuilder
    var resultSection: some View {
        if let result = uploadResult {
            Text(result)
                .foregroundStyle(.secondary)
                .padding()
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    var matchesSection: some View {
        if !matches.isEmpty {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(matches) { match in
                        HStack(spacing: 12) {
                            Image(uiImage: match.image)
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(radius: 2)
                            VStack(alignment: .leading) {
                                Text(match.key).font(.headline)
                                Text("Similarity: \(String(format: "%.2f", match.similarity))")
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)))
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
        }
    }

    func runFaceComparison(for image: UIImage) async {
        await MainActor.run { isUploading = true }
        FaceCompare.shared.compareFaces(image: image)
        await MainActor.run {
            matches = FaceCompare.shared.matches
            uploadResult = FaceCompare.shared.resultMessage
            isUploading = false
        }
    }
}

