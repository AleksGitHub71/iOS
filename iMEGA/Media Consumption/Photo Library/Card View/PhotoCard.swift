import SwiftUI

struct PhotoCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let badgeTitle: String?
    private let content: Content
    
    @ObservedObject var viewModel: PhotoCardViewModel
    
    init(viewModel: PhotoCardViewModel, badgeTitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.viewModel = viewModel
        self.badgeTitle = badgeTitle
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CardImage(container: viewModel.thumbnailContainer)
                    .position(x: proxy.size.width / CGFloat(2),
                              y: proxy.size.height / CGFloat(2))
                
                VStack {
                    content
                        .photoCardTitle()
                    
                    Spacer()
                    
                    if let title = badgeTitle {
                        NumberBadge(title: title)
                            .photoCardNumber()
                    }
                }
            }
            .background(Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.whiteF7F7F7))
        }
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onAppear {
            viewModel.loadThumbnail()
        }
    }
}
