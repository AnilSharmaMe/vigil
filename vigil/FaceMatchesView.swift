import SwiftUI

struct FaceMatchView: View {
    let match: FaceMatch
    var body: some View {
        VStack {
            // Face image with rounded corners and border
            Image(uiImage: match.image)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 2) // ✅ Use Color instead of UIColor
                )

            // Key / Name label
            Text(match.key)
                .font(.caption)
                .lineLimit(1)
            
            // Similarity percentage
            Text(String(format: "%.2f%%", match.similarity * 100))
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(4)
    }
}


