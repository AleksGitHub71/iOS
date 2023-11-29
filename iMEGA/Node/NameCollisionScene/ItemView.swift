import MEGASwiftUI
import SwiftUI

struct ItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    var name: String
    var size: String?
    var date: String?
    var imageUrl: URL?
    var imagePlaceholder: MEGAFileTypeResource
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            (Image(contentsOfFile: imageUrl?.path) ?? Image(imagePlaceholder))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40.0, height: 40.0)
                .clipped()
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .foregroundColor(.primary)
                    .font(.subheadline.bold())
                if let date = date {
                    Text(date)
                        .foregroundColor(.primary)
                        .font(.caption)
                }
                if let size = size {
                    Text(size)
                        .foregroundColor(.primary)
                        .font(.caption)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(colorScheme == .dark ? Color(Colors.General.Black._2c2c2e.name) : Color.white)
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(colorScheme == .dark ? Color(UIColor.grayEBEBF5).opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}
