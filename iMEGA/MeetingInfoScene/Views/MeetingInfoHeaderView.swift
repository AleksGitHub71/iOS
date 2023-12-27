import SwiftUI

struct MeetingInfoHeaderView: View {
    @EnvironmentObject private var viewModel: MeetingInfoViewModel
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme

    private enum Constants {
        static let avatarViewSize = CGSize(width: 40, height: 40)
    }
    
    var body: some View {
        VStack {
            Divider()
            HStack {
                if let chatRoomAvatarViewModel = viewModel.chatRoomAvatarViewModel {
                    ChatRoomAvatarView(
                        viewModel: chatRoomAvatarViewModel,
                        size: Constants.avatarViewSize
                    )
                }
                
                VStack(alignment: .leading) {
                    Text(viewModel.scheduledMeeting.title)
                        .font(.subheadline)
                    Text(viewModel.subtitle)
                        .font(.caption)
                        .foregroundColor(Color(UIColor.lightGray))
                }
                Spacer()
            }
            Divider()
        }
        .background(colorScheme == .dark ? MEGAAppColor.Black._1C1C1E.color : MEGAAppColor.White._FFFFFF.color)
    }
}
