import MEGADesignToken
import MEGAL10n

struct ChatRoomsTopRowViewState: Identifiable {
    let id: String
    let image: UIImage
    let description: String
    let rightDetail: String?
    let hasDivider: Bool
    let action: (() -> Void)
    
    init(
        id: String,
        image: UIImage,
        description: String,
        rightDetail: String? = nil,
        hasDivider: Bool,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.image = image
        self.description = description
        self.rightDetail = rightDetail
        self.action = action
        self.hasDivider = hasDivider
    }
}

extension ChatRoomsTopRowViewState {
    static func contactsOnMega(
        designTokenEnabled: Bool,
        action: @escaping () -> Void
    ) -> Self {
        ChatRoomsTopRowViewState(
            id: "contacts",
            image: designTokenEnabled ? UIImage.inviteToChatDesignToken : UIImage.inviteToChat,
            description: Strings.Localizable.inviteContactNow,
            hasDivider: false,
            action: action
        )
    }
    
    static func archivedChatsViewState(
        count: UInt,
        action: @escaping () -> Void
    ) -> Self {
        ChatRoomsTopRowViewState(
            id: "archived",
            image: UIImage(resource: .archiveChat),
            description: Strings.Localizable.archivedChats,
            rightDetail: "\(count)",
            hasDivider: true,
            action: action
        )
    }
}
