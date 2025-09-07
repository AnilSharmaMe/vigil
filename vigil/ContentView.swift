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
        ZStack {
            NavigationStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Title + Tagline
                    Text("Netra")
                        .font(.largeTitle.bold())
                    Text("Your first layer of safety.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal])

                ScrollView {
                    VStack(spacing: 24) {
                        imageSection
                        actionButtons
                        resultSection
                        matchesSection
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $image, flashOn: $flashOn)
            }

            // Floating logo watermark
            VStack {
                HStack {
                    Spacer()
                    Image("logo") // Make sure logo is in Assets.xcassets
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .opacity(0.3)
                        .padding()
                }
                Spacer()
            }
        }
    }

    // MARK: - Subviews

    private var imageSection: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 4)
                    .transition(.opacity)
                    .animation(.easeInOut, value: image)

                Button {
                    clearImage()
                } label: {
                    Label("Remove Photo", systemImage: "xmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No image selected")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white).shadow(radius: 3))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Text("Choose an Image")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            cameraButton
            galleryPicker
            compareButton
        }
    }

    private var cameraButton: some View {
        Button(action: { showCamera = true }) {
            Label("Take Photo", systemImage: "camera")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var galleryPicker: some View {
        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
            Label("Pick from Gallery", systemImage: "photo")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.indigo)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                do {
                    if let data = try await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run { image = uiImage }
                    }
                } catch {
                    print("Error loading image: \(error)")
                }
            }
        }
    }

    @ViewBuilder
    private var compareButton: some View {
        if let image {
            Button {
                Task { await runFaceComparison(for: image) }
            } label: {
                if isUploading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
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
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let result = uploadResult {
            Text(result)
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))
                .foregroundColor(.green)
                .multilineTextAlignment(.center)
        } else {
            EmptyView()
        }
    }

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
        } else {
            EmptyView()
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

//// MARK: - CameraView with Flash Button Integrated
//
//struct CameraView: View {
//    @Binding var image: UIImage?
//    @Binding var flashOn: Bool
//    @Environment(\.dismiss) private var dismiss
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea() // Camera preview placeholder
//
//            VStack {
//                HStack {
//                    Spacer()
//                    // Flash toggle button
//                    Button {
//                        flashOn.toggle()
//                    } label: {
//                        Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
//                            .foregroundColor(flashOn ? .yellow : .white)
//                            .padding()
//                            .background(Color.black.opacity(0.7))
//                            .clipShape(Circle())
//                    }
//                    .padding()
//                }
//                Spacer()
//            }
//
//            VStack {
//                Spacer()
//                Button(action: {
//                    // Simulate capturing an image
//                    image = UIImage(systemName: "person.crop.circle")
//                    dismiss()
//                }) {
//                    Circle()
//                        .fill(Color.white)
//                        .frame(width: 70, height: 70)
//                        .shadow(radius: 4)
//                }
//                .padding(.bottom, 40)
//            }
//        }
//    }
//}

