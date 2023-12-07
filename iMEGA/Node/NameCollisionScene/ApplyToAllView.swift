import SwiftUI

struct ApplyToAllView: View {
    @Environment(\.colorScheme) private var colorScheme

    var text: String
    @Binding var applyToAllSelected: Bool
    
    private enum Constants {
        static let applyToAllIconSize: CGFloat = 22
    }
    
    var body: some View {
        HStack {
            Divider()
            HStack {
                Text(text)
                    .font(.body)
                Spacer()
                Image(applyToAllSelected ? Asset.Images.Login.checkBoxSelected.name : Asset.Images.Login.checkBoxUnselected.name)
                    .resizable()
                    .frame(width: Constants.applyToAllIconSize, height: Constants.applyToAllIconSize)
            }
            Divider()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? Color(MEGAAppColor.Black._2C2C2E.uiColor) : Color.white)
        .onTapGesture {
            applyToAllSelected.toggle()
        }
    }
}
