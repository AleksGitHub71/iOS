import UIKit

@objc protocol ChatNotificationControlCellProtocol {
    weak var nameLabel: UILabel? { get }
    weak var notificationsSwitch: UISwitch? { get }
    weak var iconImageView: UIImageView? { get }
}

@objc class ChatNotificationControl: PushNotificationControl {
    // MARK:- Interface methods.

    @objc func configure(cell: ChatNotificationControlCellProtocol, chatId: Int64) {
        cell.nameLabel?.text = "Chat Notifications".localized()
        
        cell.notificationsSwitch?.isEnabled = isNotificationSettingsLoaded()
        cell.notificationsSwitch?.setOn(!isChatDNDEnabled(chatId: chatId), animated: false)
        cell.iconImageView?.image = #imageLiteral(resourceName: "chatNotifications")
    }
    
    @objc func isChatDNDEnabled(chatId: Int64) -> Bool {
        guard let pushNotificationSettings = pushNotificationSettings else {
            return false
        }
        
        return pushNotificationSettings.isChatDndEnabled(forChatId: chatId)
    }
    
    @objc func turnOnDND(chatId: Int64, sender: UIView) {
        let alertController = DNDTurnOnOption.alertController(delegate: self, identifier: chatId)
        show(alertController: alertController, sender: sender)
    }
    
    @objc func turnOffDND(chatId: Int64) {
        updatePushNotificationSettings {
            self.pushNotificationSettings?.setChatEnabled(true, forChatId: chatId)
        }
    }
    
    @objc func timeRemainingForDNDDeactivationString(chatId: Int64) -> String? {
        if isChatDNDEnabled(chatId: chatId) == false {
            return nil
        }
        
        let chatDNDTime = chatDND(chatId: chatId)
        return string(from: chatDNDTime)
    }
}

// MARK:- Private methods extension.

extension ChatNotificationControl {

    private func chatDND(chatId: Int64) -> Int64 {
        guard let pushNotificationSettings = pushNotificationSettings else {
            return -1;
        }
        
        return pushNotificationSettings.timestamp(forChatId: chatId)
    }
    
    private func turnOnDND(chatId: Int64, option: DNDTurnOnOption) {
        updatePushNotificationSettings {
            if option == .forever {
                self.pushNotificationSettings?.setChatEnabled(false, forChatId: chatId)
            } else {
                self.pushNotificationSettings?.setChatDndForChatId(chatId,
                                                                   untilTimestamp: dndTimeInterval(dndTurnOnOption: option))
            }
        }
    }
}

// MARK:- DNDTurnOnAlertControllerAction extension

extension ChatNotificationControl: DNDTurnOnAlertControllerAction {
  
    var cancelAction: ((UIAlertAction) -> Void)? {
        return { _ in
            self.delegate?.tableView?.reloadData()
        }
    }
    
    func action(for dndTurnOnOption: DNDTurnOnOption, identifier: Int64?) -> (((UIAlertAction) -> Void)?) {
        return { _ in
            guard let chatId = identifier else { return }
            self.turnOnDND(chatId: chatId, option: dndTurnOnOption)
        }
    }
}
