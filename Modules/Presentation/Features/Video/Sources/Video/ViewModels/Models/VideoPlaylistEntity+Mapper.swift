import MEGADomain
import MEGAL10n
import MEGASwiftUI

extension VideoPlaylistEntity {
    
    func toVideoPlaylistCellPreviewEntity(thumbnailContainers: [any ImageContaining], videosCount: Int, durationText: String) -> VideoPlaylistCellPreviewEntity {
        VideoPlaylistCellPreviewEntity(
            imageContainers: thumbnailContainers,
            count: countText(videosCount: videosCount),
            duration: durationText,
            title: name,
            isExported: isLinkShared,
            type: type
        )
    }
    
    private func countText(videosCount count: Int) -> String {
        if count == 0 {
            Strings.Localizable.Videos.Tab.Playlist.Content.PlaylistCell.Subtitle.emptyPlaylist
        } else if count == 1 {
            "\(count)" + " " + Strings.Localizable.video
        } else {
            "\(count)" + " " + Strings.Localizable.videos
        }
    }
}
