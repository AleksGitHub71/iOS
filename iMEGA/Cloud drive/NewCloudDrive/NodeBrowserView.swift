import MEGADesignToken
import MEGAL10n
import MEGASwiftUI
import Search
import SwiftUI

// Temporary colors catering for backward-compatibility with non-semantic color system
// To be removed when Semantic Color is fully released . Ticket is [SAO-1482]
fileprivate extension UIColor {
    static let barButtonTextColor = UIColor(
        dynamicProvider: {
            $0.userInterfaceStyle == .light
            ? UIColor.gray515151
            : UIColor.grayD1D1D1
        }
    )
}

struct NodeBrowserView: View {
    
    @StateObject var viewModel: NodeBrowserViewModel

    var body: some View {
        content
            .noInternetViewModifier(viewModel: viewModel.noInternetViewModel)
            .ignoresSafeArea(.keyboard)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    leftToolbarContent
                }
                
                toolbarNavigationTitle
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    rightToolbarContent
                }
            }.navigationBarBackButtonHidden(viewModel.hidesBackButton)
    }
    
    private var content: some View {
        VStack {
            if let warningViewModel = viewModel.warningViewModel {
                WarningView(viewModel: warningViewModel)
            }
            if let mediaDiscoveryViewModel = viewModel.viewModeAwareMediaDiscoveryViewModel {
                MediaDiscoveryContentView(viewModel: mediaDiscoveryViewModel)
            } else {
                SearchResultsView(viewModel: viewModel.searchResultsViewModel)
                    .environment(\.editMode, $viewModel.editMode)
            }
        }
        .background()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onViewAppear() }
        .onDisappear { viewModel.onViewDisappear() }
        .onLoad { await viewModel.onLoadTask() }
    }

    @ToolbarContentBuilder
    private var toolbarContentEditing: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(
                action: { viewModel.selectAll() },
                label: { Image(.selectAllItems) }
            )
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(Strings.Localizable.cancel) { viewModel.stopEditing() }
        }

        ToolbarItem(placement: .principal) {
            Text(viewModel.title).font(.headline)
        }
    }

    @ViewBuilder
    private var leftToolbarContent: some View {
        switch viewModel.viewState {
        case .editing:
            Button(
                action: { viewModel.selectAll() },
                label: { Image(.selectAllItems) }
            )
        case .regular(let isBackButtonShown):
            if isBackButtonShown {
                EmptyView()
            } else {
                MyAvatarIconView(
                    viewModel: .init(
                        avatarObserver: viewModel.avatarViewModel,
                        onAvatarTapped: { viewModel.openUserProfile() }
                    )
                )
            }
        }
    }
    
    @ViewBuilder
    private var rightToolbarContent: some View {
        switch viewModel.viewState {
        case .editing:
            Button(Strings.Localizable.cancel) { viewModel.stopEditing() }
                .foregroundStyle(isDesignTokenEnabled ? TokenColors.Icon.primary.swiftUI : UIColor.barButtonTextColor.swiftUI)
        case .regular:
            viewModel.contextMenuViewFactory?.makeAddMenuWithButtonView()
            viewModel.contextMenuViewFactory?.makeContextMenuWithButtonView()
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarNavigationTitle: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(viewModel.title)
                .font(.headline)
                .lineLimit(1)
        }
    }
}
