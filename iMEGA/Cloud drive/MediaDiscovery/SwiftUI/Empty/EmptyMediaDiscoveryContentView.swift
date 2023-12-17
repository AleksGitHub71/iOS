import MEGAL10n
import MEGASwiftUI
import SwiftUI

struct EmptyMediaDiscoveryContentView: View {
    let image: UIImage
    let title: String
    let menuActionHandler: (EmptyMediaDiscoveryContentMenuAction) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            centreContent
            Spacer()
            actionContent
        }
    }
    
    @ViewBuilder
    var centreContent: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .frame(width: 120, height: 120)
            Text(title)
                .font(.body)
        }
    }
    
    @ViewBuilder
    var actionContent: some View {
        VStack {
            Menu(content: {
                ForEach(EmptyMediaDiscoveryContentMenuAction.allCases.reversed()) { menuItem in
                    Button(
                        action: { menuActionHandler(menuItem) },
                        label: { Label { Text(menuItem.title) } icon: { menuItem.menuIcon } }
                    )
                }
            }, label: {
                Text(Strings.Localizable.addFiles)
                    .font(.body.weight(.semibold))
                    .foregroundColor(Color.white)
                    .frame(width: 288, height: 50)
            })
            .background(Color.turquoise)
            .cornerRadius(8, corners: .allCorners)
            .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
        }
        .padding(.bottom, 35)
    }
}

private extension EmptyMediaDiscoveryContentMenuAction {
     var title: String {
        switch self {
        case .choosePhotoVideo:
            return Strings.Localizable.choosePhotoVideo
        case .capturePhotoVideo:
            return Strings.Localizable.capturePhotoVideo
        }
    }
    
    var menuIcon: Image? {
        switch self {
        case .choosePhotoVideo:
            return Image(.saveToPhotos)
        case .capturePhotoVideo:
            return Image(.capture)
        }
    }
}

#Preview {
    EmptyMediaDiscoveryContentView(
        image: UIImage.folderEmptyState,
        title: Strings.Localizable.emptyFolder,
        menuActionHandler: { _ in })
    .previewLayout(.device)
}
