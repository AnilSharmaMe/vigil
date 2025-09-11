import SwiftUI
import PhotosUI
import CoreLocation
import UserNotifications

struct ContentView: View {
    // MARK: - States
    @State private var image: UIImage? = nil                     // Recognition image
    @State private var personToAdd: UIImage? = nil               // Add Person preview

    @State private var showCamera = false
    @State private var showRecognitionOptions = false
    @State private var showRecognitionPicker = false
    @State private var showAddPersonPicker = false

    @State private var recognitionPickerItem: PhotosPickerItem? = nil
    @State private var addPersonItem: PhotosPickerItem? = nil

    @State private var isComparing = false
    @State private var matches: [FaceMatch] = []
    @State private var resultMessage: String? = nil
    @State private var glowAnimation = false

    @StateObject private var locationManager = LocationManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                // MARK: - Tagline
                Text("Identify. Verify. Protect.")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                // MARK: - Logo
                Image("app_logo") // Replace with your asset name
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                // MARK: - Recognition Image Preview
                if let recognitionImage = image {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: recognitionImage)
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
                    }
                }

                // MARK: - Add Person Preview Flow
                if let person = personToAdd {
                    VStack(spacing: 16) {
                        Text("Add this person to detection list?")
                            .font(.headline)

                        Image(uiImage: person)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 4)

                        HStack(spacing: 16) {
                            Button(action: { personToAdd = nil }) {
                                Text("Cancel")
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button(action: { savePersonToFolder(image: person) }) {
                                Text("Add")
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }

                // MARK: - Action Buttons (only when no recognition image or person to add)
                if image == nil && personToAdd == nil {
                    VStack(spacing: 16) {
                        // Start Recognition
                        Button(action: { showRecognitionOptions.toggle() }) {
                            actionButton(title: "Start Recognition", icon: "scope", colors: [Color.cyan.opacity(0.6), Color.cyan.opacity(0.3)], glow: true)
                        }
                        .onAppear { glowAnimation = true }

                        if showRecognitionOptions {
                            VStack(spacing: 10) {
                                Button(action: { showCamera = true; showRecognitionOptions = false }) {
                                    actionButton(title: "Pick from Camera", icon: "camera.fill", colors: [Color.blue.opacity(0.5)], glow: false, isChild: true)
                                        .padding(.leading, 20)
                                }
                                Button(action: { showRecognitionPicker = true; showRecognitionOptions = false }) {
                                    actionButton(title: "Pick from Gallery", icon: "photo.fill.on.rectangle.fill", colors: [Color.orange.opacity(0.5)], glow: false, isChild: true)
                                        .padding(.leading, 20)
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Add Person
                        Button(action: { showAddPersonPicker = true }) {
                            actionButton(title: "Add Person in detection list", icon: "photo.fill", colors: [Color.purple.opacity(0.6), Color.purple.opacity(0.3)], glow: true)
                        }
                    }
                }

                // MARK: - Compare Faces Button
                if let recognitionImage = image, personToAdd == nil {
                    Button(action: { runFaceComparison(for: recognitionImage) }) {
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

        // MARK: - Camera Sheet
        .sheet(isPresented: $showCamera) {
            CameraView(image: $image, flashOn: .constant(false))
        }

        // MARK: - Recognition Picker
        .photosPicker(isPresented: $showRecognitionPicker, selection: $recognitionPickerItem, matching: .images)
        .onChange(of: recognitionPickerItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run { image = uiImage }
                }
            }
        }

        // MARK: - Add Person Picker
        .photosPicker(isPresented: $showAddPersonPicker, selection: $addPersonItem, matching: .images)
        .onChange(of: addPersonItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let alignedFace = WantedPersonServiceManager.shared.alignFace(from: uiImage) ?? uiImage
                    await MainActor.run {
                        personToAdd = alignedFace
                        image = nil // Prevent recognition flow showing Compare Faces
                    }
                }
            }
        }
        .onAppear { NotificationManager.shared.requestPermission() }
    }

    // MARK: - Helpers
    private func actionButton(title: String, icon: String, colors: [Color], glow: Bool, isChild: Bool = false) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: isChild ? 16 : 20)
                .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .frame(height: isChild ? 50 : 55)
                .shadow(color: colors.first!.opacity(0.35), radius: glow ? 12 : 5, x: 0, y: 3)
                .animation(glow ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: glow)

            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(title)
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
            }
        }
    }

    private func clearImage() {
        image = nil
        recognitionPickerItem = nil
        personToAdd = nil
        addPersonItem = nil
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

    private func savePersonToFolder(image selectedImage: UIImage) {
        let name = "Person_\(Date().timeIntervalSince1970)"
        let folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        let imageURL = folderURL.appendingPathComponent("face.jpg")
        if let data = selectedImage.jpegData(compressionQuality: 0.9) {
            try? data.write(to: imageURL)
        }

        if let alignedFace = WantedPersonServiceManager.shared.alignFace(from: selectedImage),
           let embedding = FaceEmbedding.shared?.embedding(for: alignedFace) {
            let normalized = WantedPersonServiceManager.shared.normalize(embedding)
            _ = EmbeddingStore.shared.save(normalized, image: alignedFace, category: .userCustom)
            print("✅ Saved person with folder: \(name)")
        } else {
            print("⚠️ Could not generate embedding")
        }

        personToAdd = nil
    }
}

