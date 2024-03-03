import MEGADesignToken
import MEGAL10n
import SwiftUI

struct SlideShowOptionDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: SlideShowOptionCellViewModel
    @Binding var isShowing: Bool
    
    private var navBarButtonTintColor: Color {
        if isDesignTokenEnabled {
            TokenColors.Text.primary.swiftUI
        } else {
            colorScheme == .dark ? MEGAAppColor.Gray._D1D1D1.color : MEGAAppColor.Gray._515151.color
        }
    }
    
    var body: some View {
        ZStack {
            backgroundColor
            VStack(spacing: 0) {
                navigationBar
                    .background(isDesignTokenEnabled ? TokenColors.Background.surface1.swiftUI : backgroundColor)
                listView()
            }
        }
    }
    
    var navBarButton: some View {
        Button {
            isShowing.toggle()
        } label: {
            Text(Strings.Localizable.cancel)
                .font(.body)
                .foregroundColor(navBarButtonTintColor)
                .padding()
                .contentShape(Rectangle())
        }
    }
    
    var navigationBar: some View {
        Text(viewModel.title)
            .font(.body.bold())
            .foregroundStyle(isDesignTokenEnabled ? TokenColors.Text.primary.swiftUI : .primary)
            .frame(maxWidth: .infinity, minHeight: 60.0)
            .overlay(
                HStack {
                    Spacer()
                    navBarButton
                }
            )
    }
    
    @ViewBuilder func listView() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Divider()
                ForEach(viewModel.children, id: \.self.id) { item in
                    SlideShowOptionDetailCellView(viewModel: item)
                        .onTapGesture {
                            viewModel.didSelectChild(item)
                            withAnimation(.easeOut(duration: 1)) {
                                isShowing.toggle()
                            }
                        }
                    Divider().padding(.leading, item.id == viewModel.children.last?.id ? 0 : 16)
                }
                Divider()
            }
        }
        .background(isDesignTokenEnabled ? TokenColors.Background.page.swiftUI : backgroundColor)
    }
    
    private var backgroundColor: Color {
        switch colorScheme {
        case .dark: return MEGAAppColor.Black._1C1C1E.color
        default: return MEGAAppColor.White._F7F7F7.color
        }
    }
}
