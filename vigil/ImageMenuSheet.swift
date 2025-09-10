import SwiftUI


// MARK: - Modern Bottom Sheet
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
                    Text("Capture Photo")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.cyan)
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
                .background(Color.cyan.opacity(0.8))
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
