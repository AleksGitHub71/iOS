import MEGAL10n
import MEGASwiftUI
import Search
import SwiftUI

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
        .designTokenBackground(isDesignTokenEnabled, legacyColor: Color(UIColor.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onViewAppear() }
        .onDisappear { viewModel.onViewDisappear() }
        .onLoad { viewModel.onLoadTask() }
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
