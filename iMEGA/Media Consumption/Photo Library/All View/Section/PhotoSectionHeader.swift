import MEGADesignToken
import MEGASwiftUI
import SwiftUI

struct PhotoSectionHeader<T: PhotoDateSection>: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let section: T
    
    private var backgroundColor: Color {
        if isDesignTokenEnabled {
            colorScheme == .light ? TokenColors.Background.surface1.swiftUI : TokenColors.Background.surface2.swiftUI
        } else {
            .clear
        }
    }

    var body: some View {
        HStack {
            Text(section.attributedTitle)
                .foregroundStyle(isDesignTokenEnabled ? TokenColors.Text.primary.swiftUI : colorScheme == .light ? .black : .white)
                .padding(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 20))
                .padding(EdgeInsets(top: 15, leading: 8, bottom: 20, trailing: 8))

            Spacer()
        }
    }
}
