import MEGADesignToken
import SwiftUI

struct ShareAttachmentCellView: View {
    @StateObject var viewModel: ShareAttachmentCellViewModel
    
    var body: some View {
        GeometryReader { geo in
            HStack {
                Image(viewModel.fileIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.height * 0.80, height: geo.size.height * 0.80)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        TextField("", text: $viewModel.fileName)
                            .font(.system(size: 15))
                            .autocorrectionDisabled()
                            .foregroundColor(foregroundColor)
                            .fixedSize()
                            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification),
                                       perform: { notif in
                                guard let field = notif.object as? UITextField else { return }
                                field.selectedTextRange = field.textRange(from: field.beginningOfDocument,
                                                                          to: field.endOfDocument)
                            })
                            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification),
                                       perform: { _ in
                                viewModel.saveNewFileName()
                            })
                        
                        Text(viewModel.fileExtension)
                            .font(.system(size: 15))
                            .foregroundColor(foregroundColorFileExtension)
                            .fixedSize()
                    }
                }
                .onAppear {
                    UIScrollView.appearance().bounces = false
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 10)
        }
        .frame(height: 60)
        .background(backgroundColor)
    }
    
    var foregroundColor: Color {
        if isDesignTokenEnabled {
            TokenColors.Text.primary.swiftUI
        } else {
            Color(UIColor.label)
        }
    }
    
    var foregroundColorFileExtension: Color {
        isDesignTokenEnabled
        ? TokenColors.Text.secondary.swiftUI
        : Color(UIColor.gray8E8E93)
    }
    
    var backgroundColor: Color {
        if isDesignTokenEnabled {
            TokenColors.Background.page.swiftUI
        } else {
            Color(UIColor.cellBackground)
        }
    }
}
