import MEGADesignToken
import MEGAL10n

extension ContactTableViewCell {
    @objc func updateAppearance() {
        backgroundColor = UIColor.mnz_background()
        if UIColor.isDesignTokenEnabled() {
            nameLabel.textColor = TokenColors.Text.primary
            shareLabel?.textColor = TokenColors.Text.secondary
            permissionsLabel?.textColor = TokenColors.Text.primary
            
            contactDetailsButton?.tintColor = TokenColors.Icon.secondary
            nameLabel.textColor = TokenColors.Text.primary
            shareLabel?.textColor = TokenColors.Text.secondary
            permissionsLabel?.textColor = TokenColors.Text.primary
        } else {
            nameLabel.textColor = UIColor.label
            shareLabel?.textColor = UIColor.mnz_subtitles(for: traitCollection)
            permissionsLabel?.textColor = UIColor.mnz_tertiaryGray(for: traitCollection)
            
            nameLabel.textColor = UIColor.label
            shareLabel?.textColor = UIColor.mnz_subtitles(for: traitCollection)
            permissionsLabel?.textColor = UIColor.mnz_tertiaryGray(for: traitCollection)
        }
    }
    
    @objc func updateNewViewAppearance() {
        if UIColor.isDesignTokenEnabled() {
            contactNewLabel.textColor = TokenColors.Text.success
            contactNewLabelView.backgroundColor = TokenColors.Notifications.notificationSuccess
        } else {
            contactNewLabel.textColor = UIColor.mnz_whiteFFFFFF()
            contactNewLabelView.backgroundColor = UIColor.mnz_turquoise(for: traitCollection)
        }
    }
    
    @objc func onlineStatusBackgroundColor(_ status: MEGAChatStatus) -> UIColor {
        switch status {
        case .online: UIColor.isDesignTokenEnabled() ? TokenColors.Indicator.green : MEGAAppColor.Chat.chatStatusOnline.uiColor
        case .offline: UIColor.isDesignTokenEnabled() ? TokenColors.Icon.disabled : MEGAAppColor.Chat.chatStatusOffline.uiColor
        case .away: UIColor.isDesignTokenEnabled() ? TokenColors.Indicator.yellow : MEGAAppColor.Chat.chatStatusAway.uiColor
        case .busy: UIColor.isDesignTokenEnabled() ? TokenColors.Indicator.pink : MEGAAppColor.Chat.chatStatusBusy.uiColor
        default: .clear
        }
    }
    
    @objc func configureCellForContactsModeChatStartConversation(_ option: ContactsStartConversation) {
        permissionsImageView.isHidden = true
        
        switch option {
        case .newGroupChat:
            nameLabel.text = Strings.Localizable.newGroupChat
            avatarImageView.image = UIColor.isDesignTokenEnabled() ? UIImage.groupChatToken : UIImage.createGroup
        case .newMeeting:
            nameLabel.text = Strings.Localizable.Meetings.Create.newMeeting
            avatarImageView.image = UIColor.isDesignTokenEnabled() ? UIImage.newMeetingToken : UIImage.newMeeting
        case .joinMeeting:
            nameLabel.text = Strings.Localizable.Meetings.Link.LoggedInUser.joinButtonText
            avatarImageView.image = UIColor.isDesignTokenEnabled() ? UIImage.joinMeetingToken : UIImage.joinMeeting
        @unknown default: break
        }
        
        shareLabel.isHidden = true
    }
}
