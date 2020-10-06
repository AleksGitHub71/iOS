import UIKit
import PanModal
import ISEmojiView

class ReactionPickerViewController: UIViewController {
    
    var message: ChatMessage?

    private var emojiInputView: EmojiView {
        let keyboardSettings = KeyboardSettings(bottomType: .categories)
        keyboardSettings.countOfRecentsEmojis = 20
        keyboardSettings.updateRecentEmojiImmediately = true
        let emojiView = EmojiView(keyboardSettings: keyboardSettings)
        emojiView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 300)
        emojiView.delegate = self
        
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        view.addSubview(emojiView)
        return emojiView
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emojiInputView.autoPinEdgesToSuperviewSafeArea()
        preferredContentSize = CGSize(width: 400, height: 300)

        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
    }
    
}

// MARK: - Pan Modal Presentable

extension ReactionPickerViewController: PanModalPresentable {
    var panScrollable: UIScrollView? {
        return nil
    }
    
    var showDragIndicator: Bool {
        return false
    }

    var longFormHeight: PanModalHeight {
           return .contentHeight(300)
       }
    
    var anchorModalToLongForm: Bool {
        return true
    }
}

extension ReactionPickerViewController: EmojiViewDelegate {
    
      // MARK: - EmojiViewDelegate
      
      func emojiViewDidSelectEmoji(_ emoji: String, emojiView: EmojiView) {
        let megaMessage = message?.message
        MEGASdkManager.sharedMEGAChatSdk()?.addReaction(forChat: message?.chatRoom.chatId ?? 0, messageId: megaMessage?.messageId ?? 0, reaction: emoji)
        dismiss(animated: true, completion: nil)
      }
      
      func emojiViewDidPressChangeKeyboardButton(_ emojiView: EmojiView) {
      
      }
      
      func emojiViewDidPressDeleteBackwardButton(_ emojiView: EmojiView) {
        dismiss(animated: true, completion: nil)
      }
      
      func emojiViewDidPressDismissKeyboardButton(_ emojiView: EmojiView) {
        dismiss(animated: true, completion: nil)
      }
}
