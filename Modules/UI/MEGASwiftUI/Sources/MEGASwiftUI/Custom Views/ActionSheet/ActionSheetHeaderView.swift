import SwiftUI

public struct ActionSheetHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    let iconName: String?
    let title: String
    let detailImageName: String?
    let subtitle: String
    let subtitleColor: UIColor
    
    public init(iconName: String? = nil, title: String, detailImageName: String? = nil, subtitle: String, subtitleColor: UIColor) {
        self.iconName = iconName
        self.title = title
        self.detailImageName = detailImageName
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
    }

    public var body: some View {
        HStack {
            if let iconName {
                Image(iconName)
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                HStack {
                    if let detailImageName, !detailImageName.isEmpty {
                        Image(detailImageName)
                            .renderingMode(.template)
                            .foregroundColor(Color(subtitleColor))
                            .frame(width: 12, height: 12)
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color(subtitleColor))
                }
            }
            Spacer()
        }
    }
}
