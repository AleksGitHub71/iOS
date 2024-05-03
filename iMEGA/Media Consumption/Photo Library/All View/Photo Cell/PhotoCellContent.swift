import MEGADesignToken
import MEGASwiftUI
import SwiftUI

struct PhotoCellContent: View {
    @ObservedObject var viewModel: PhotoCellViewModel
    var isSelfSizing = true
    
    private var tap: some Gesture { TapGesture().onEnded { _ in
        viewModel.select()
    }}
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            image()
            /// An overlayView to enhance visual selection thumbnail image. Requested by designers to not use design tokens for this one.
                .overlay(Color.black000000.opacity(isDesignTokenEnabled && viewModel.isSelected ? 0.2 : 0.0))
            
            checkMarkView
                .offset(x: -5, y: -5)
                .opacity(viewModel.shouldShowEditState ? 1 : 0)
        }
        .favorite(viewModel.shouldShowFavorite)
        .videoDuration(PhotoCellVideoDurationViewModel(isVideo: viewModel.isVideo, duration: viewModel.duration, scaleFactor: viewModel.currentZoomScaleFactor))
        .opacity(viewModel.shouldApplyContentOpacity ? 0.4 : 1)
        .gesture(viewModel.editMode.isEditing ? tap : nil)
        .task { await viewModel.startLoadingThumbnail() }
    }
    
    private var checkMarkView: some View {
        if isDesignTokenEnabled {
            CheckMarkView(
                markedSelected: viewModel.isSelected,
                foregroundColor: viewModel.isSelected ? TokenColors.Support.success.swiftUI : TokenColors.Icon.onColor.swiftUI
            )
        } else {
            CheckMarkView(
                markedSelected: viewModel.isSelected,
                foregroundColor: viewModel.isSelected ? MEGAAppColor.Green._34C759.color : MEGAAppColor.Photos.photoSelectionBorder.color
            )
        }
    }
    
    @ViewBuilder
    private func image() -> some View {
        if isSelfSizing {
            PhotoCellImage(container: viewModel.thumbnailContainer,
                           aspectRatio: viewModel.currentZoomScaleFactor == .one ? nil : 1)
        } else {
            Color.clear
                .overlay(PhotoCellImage(container: viewModel.thumbnailContainer))
        }
    }
}
