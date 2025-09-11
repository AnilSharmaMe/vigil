import SwiftUI
import PhotosUI
import CoreLocation
import UserNotifications

struct ContentView: View {
    // MARK: - States
    @State private var image: UIImage? = nil                     // Recognition image
    @State private var personToAdd: UIImage? = nil               // Add Person preview

    @State private var showCamera = false
    @State private var showRecognitionMenu = false
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
            VStack(spacing: 24) {
                
                // MARK: - Logo & Tagline
                VStack(spacing: 6) {
                    Image("app_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .shadow(radius: 6)
                    
                    Text("Identify • Verify • Protect")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)
                
                // MARK: - Image / Person Preview
                ZStack(alignment: .topLeading) {
                    if let imageToShow = personToAdd ?? image {
                        Image(uiImage: imageToShow)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 4)
                            .overlay(alignment: .topLeading) {
                                Text(personToAdd != nil ? "New Person" : "Recognition Image")
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                            .overlay(alignment: .topTrailing) {
                                Button(action: { clearImage() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .padding(8)
                            }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 70, height: 70)
                                .foregroundColor(.gray.opacity(0.4))
                            Text("No image selected")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6)))
                        .shadow(radius: 2)
                    }
                }
                
                // MARK: - Add Person Flow
                if let person = personToAdd {
                    VStack(spacing: 12) {
                        Text("Add this person to detection list?")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            Button(action: { personToAdd = nil }) {
                                Text("Cancel")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                            
                            Button(action: { savePersonToFolder(image: person) }) {
                                Text("Add")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                // MARK: - Action Buttons (only when no selection active)
                if image == nil && personToAdd == nil {
                    VStack(spacing: 16) {
                        Button(action: { showRecognitionMenu = true }) {
                            actionButton(title: "Start Recognition", icon: "scope", colors: [Color.cyan, Color.blue], glow: true)
                        }
                        .confirmationDialog("Start Recognition", isPresented: $showRecognitionMenu, titleVisibility: .visible) {
                            Button("Pick from Camera", action: { showCamera = true })
                            Button("Pick from Gallery", action: { showRecognitionPicker = true })
                            Button("Cancel", role: .cancel) {}
                        }
                        
                        Button(action: { showAddPersonPicker = true }) {
                            actionButton(title: "Add Person in detection list", icon: "person.crop.circle.badge.plus", colors: [Color.purple, Color.pink], glow: true)
                        }
                    }
                }
                
                // MARK: - Compare Faces (Recognition flow)
                if let recognitionImage = image, personToAdd == nil {
                    Button(action: { runFaceComparison(for: recognitionImage) }) {
                        if isComparing {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Compare Faces")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(colors: [Color.green, Color.teal],
                                                           startPoint: .leading,
                                                           endPoint: .trailing))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                // MARK: - Result Message
                if let resultMessage {
                    Text(resultMessage)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.green.opacity(0.15)))
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }
                
                // MARK: - Matches List
                if !matches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Matches")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(matches) { match in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 12) {
                                            Image(uiImage: match.image)
                                                .resizable()
                                                .frame(width: 60, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(match.key)
                                                    .font(.subheadline)
                                                similarityBar(value: match.similarity)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        
                        Button(action: { notifyUsers() }) {
                            Label("Notify Nearby Users", systemImage: "bell.circle.fill")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Netra")
            .navigationBarTitleDisplayMode(.inline)
        }
        
        // MARK: - Sheets
        .sheet(isPresented: $showCamera) {
            CameraView(image: $image, flashOn: .constant(false))
        }
        .photosPicker(isPresented: $showRecognitionPicker, selection: $recognitionPickerItem, matching: .images)
        .onChange(of: recognitionPickerItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run { image = uiImage }
                }
            }
        }
        .photosPicker(isPresented: $showAddPersonPicker, selection: $addPersonItem, matching: .images)
        .onChange(of: addPersonItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let alignedFace = WantedPersonServiceManager.shared.alignFace(from: uiImage) ?? uiImage
                    await MainActor.run {
                        personToAdd = alignedFace
                        image = nil
                    }
                }
            }
        }
        .onAppear { NotificationManager.shared.requestPermission() }
    }
    
    // MARK: - UI Helpers
    private func actionButton(title: String, icon: String, colors: [Color], glow: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
            Text(title)
                .font(.headline)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, minHeight: 55)
        .background(
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(Capsule())
        .shadow(color: colors.first!.opacity(glow ? 0.6 : 0.3), radius: glow ? 12 : 6)
    }
    
    private func similarityBar(value: Float) -> some View {
        let percent = min(max(value, 0), 1)
        let color: Color = percent > 0.7 ? .green : (percent > 0.4 ? .orange : .red)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(percent))
            }
        }
        .frame(height: 6)
    }
    
    // MARK: - Logic Helpers
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

