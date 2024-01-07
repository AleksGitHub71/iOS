import SwiftUI

struct ScheduleMeetingCreationOptionSelectionView: View {
    let name: String
    let isSelected: Bool
    let tapAction: () -> Void
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Image(systemName: "checkmark")
                .foregroundColor(MEGAAppColor.Chat.chatMeetingFrequencySelectionTickMark.color)
                .font(.system(.footnote).bold())
                .opacity(isSelected ? 1.0 : 0.0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            tapAction()
        }
    }
}
