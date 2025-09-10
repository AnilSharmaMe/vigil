import SwiftUI
import PhotosUI
import CoreLocation
import UserNotifications

struct ContentView: View {
    @State private var image: UIImage? = nil
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showImageMenu = false
    @State private var isComparing = false
    @State private var matches: [FaceMatch] = []
    @State private var resultMessage: String? = nil
    @State private var glowAnimation = false
    @StateObject private var locationManager = LocationManager()

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

                // MARK: - Action Buttons (when no image)
                if image == nil {
                    VStack(spacing: 16) {
                        Button(action: { showImageMenu = true }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(colors: [Color.cyan.opacity(0.6), Color.cyan.opacity(0.3)],
                                                       startPoint: .leading,
                                                       endPoint: .trailing)
                                    )
                                    .frame(height: 55)
                                    .shadow(color: Color.cyan.opacity(0.5), radius: glowAnimation ? 15 : 6)
                                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: glowAnimation)

                                HStack(spacing: 12) {
                                    Image(systemName: "scope")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Start Recognition")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .onAppear { glowAnimation = true }
                        .sheet(isPresented: $showImageMenu) {
                            ImageMenuSheet(showCamera: $showCamera,
                                           showGallery: $showGallery,
                                           isPresented: $showImageMenu)
                        }

                        Button(action: { showGallery = true }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(colors: [Color.purple.opacity(0.6), Color.purple.opacity(0.3)],
                                                       startPoint: .leading,
                                                       endPoint: .trailing)
                                    )
                                    .frame(height: 55)
                                    .shadow(color: Color.purple.opacity(0.5), radius: glowAnimation ? 15 : 6)
                                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: glowAnimation)

                                HStack(spacing: 12) {
                                    Image(systemName: "photo.fill")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Add Person in detection list")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .onAppear { glowAnimation = true }
                    }
                }

                // MARK: - Compare Faces Button
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

                        // MARK: - Notify Users Button
                        Button(action: { notifyUsers() }) {
                            Text("Notify Nearby Users")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Netra")
            .navigationBarTitleDisplayMode(.inline)
        }
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
        .onAppear { NotificationManager.shared.requestPermission() }
    }

    // MARK: - Helper Methods
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

    private func notifyUsers() {
        guard let match = matches.first else { return }
        let lat = locationManager.location?.coordinate.latitude ?? 0
        let lng = locationManager.location?.coordinate.longitude ?? 0
        print("Sending notification for match at location: (\(lat), \(lng))")
        NotificationManager.shared.sendMatchNotification(with: match)
    }
    
    private func savePersonToFolder() {
            guard let selectedImage = image else { return }
            let name = folderName.isEmpty ? "Person_\(Date().timeIntervalSince1970)" : folderName

            // Create folder
            let folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }

            // Save image
            let imageURL = folderURL.appendingPathComponent("face.jpg")
            if let data = selectedImage.jpegData(compressionQuality: 0.9) {
                try? data.write(to: imageURL)
            }

            // Generate embedding
            if let alignedFace = WantedPersonServiceManager.shared.alignFace(from: selectedImage),
               let embedding = FaceEmbedding.shared?.embedding(for: alignedFace) {
                let normalized = WantedPersonServiceManager.shared.normalize(embedding)
                _ = EmbeddingStore.shared.save(normalized, image: alignedFace, folder: folderURL)
                print("✅ Saved person with folder: \(name)")
            } else {
                print("⚠️ Could not generate embedding")
            }

            // Reset
            clearImage()
        }

}

