import SwiftUI

struct WarningView: View {
    @ObservedObject var viewModel: WarningViewModel
    
    var body: some View {
        ZStack {
            Color.bannerWarningBackground
                .edgesIgnoringSafeArea(.all)
            
            HStack {
                Text(viewModel.warningType.description)
                    .font(.caption2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(Color.bannerWarningText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 5))
                    .onTapGesture {
                        viewModel.tapAction()
                    }
                
                if viewModel.isShowCloseButton {
                    Spacer()
                    warningCloseButton
                }
            }
        }
        .frame(height: viewModel.isHideWarningView ? 0 : nil)
        .opacity(viewModel.isHideWarningView ? 0 : 1)
    }

    private var warningCloseButton: some View {
        Button {
            viewModel.closeAction()
        } label: {
            Image(.closeCircle)
                .padding()
        }
    }
}
