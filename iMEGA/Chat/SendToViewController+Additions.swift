import MEGAL10n
import UIKit

extension SendToViewController {

    @objc func showSuccessMessage() {
        guard let nodes else {
            SVProgressHUD.showSuccess(withStatus: Strings.Localizable.sharedSuccessfully)
            return
        }
        
        var statusMessage = ""
        let selectedChatCount = Int(selectedChatCount())
        let nodesCount = nodes.count
        
        if selectedChatCount == 1 {
            statusMessage = Strings.Localizable.Chat.Message.filesSentToAChat(nodesCount)
        } else {
            statusMessage = nodesCount == 1 ?
                Strings.Localizable.Chat.Message.fileSentToMultipleChats(selectedChatCount) :
                Strings.Localizable.Chat.Message.filesSent(nodesCount)
        }
        
        SVProgressHUD.showSuccess(withStatus: statusMessage)
    }
    
    @objc
    func syncSelectionState(for section: Int,
                            dataSourceArray: NSMutableArray,
                            item: AnyObject,
                            isSelected: Bool) {
        if let chatListItem = item as? MEGAChatListItem {
            let indexOfItem = dataSourceArray.indexOfObject { obj, _, _ in
                if let tempChatListItem = obj as? MEGAChatListItem {
                    return tempChatListItem.chatId == chatListItem.chatId
                } else {
                    return false
                }
            }
            if indexOfItem != NSNotFound {
                let indexPath = IndexPath(row: indexOfItem, section: section)
                changeSelection(for: indexPath, isSelected: isSelected)
            }
        } else {
            let indexOfItem = dataSourceArray.index(of: item)
            if indexOfItem != NSNotFound {
                let indexPath = IndexPath(row: indexOfItem, section: section)
                changeSelection(for: indexPath, isSelected: isSelected)
            }
        }
    }
    
    private func changeSelection(for indexPath: IndexPath, isSelected: Bool) {
        if isSelected {
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        } else {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
