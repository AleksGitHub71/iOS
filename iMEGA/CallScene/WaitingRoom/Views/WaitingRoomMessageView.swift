import MEGADesignToken
import SwiftUI

struct WaitingRoomMessageView: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(
                isDesignTokenEnabled ?
                    TokenColors.Text.colorInverse.swiftUI :
                    Color(.black000000)
            )
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                isDesignTokenEnabled ?
                    TokenColors.Background.inverse.swiftUI :
                    Color(.whiteFFFFFF)
            )
            .cornerRadius(44)
    }
}

#Preview {
    WaitingRoomMessageView(title: "Wait for host to let you in")
        .padding(20)
        .background(Color(.black000000))
        .previewLayout(.sizeThatFits)
}
