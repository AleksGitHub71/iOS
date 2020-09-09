
import UIKit

@objc enum MegaAvatarViewMode: Int {
    case single
    case multiple
}

class MegaAvatarView: UIView {
    
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var firstPeerAvatarImageView: UIImageView!
    @IBOutlet weak var secondPeerAvatarImageView: UIImageView!
    
    private var customView: UIView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        customInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        customInit()
    }
    
    func customInit() {
        customView = Bundle.init(for: type(of: self)).loadNibNamed("MegaAvatarView", owner: self, options: nil)?.first as? UIView
        if let view = customView {
            addSubview(view)
            view.frame = bounds
        }
        
        firstPeerAvatarImageView.layer.masksToBounds = true
        firstPeerAvatarImageView.layer.borderWidth = 1
        firstPeerAvatarImageView.layer.borderColor = UIColor.mnz_background()?.cgColor
        firstPeerAvatarImageView.layer.cornerRadius = firstPeerAvatarImageView.bounds.width / 2
        
        if #available(iOS 11.0, *) {
            avatarImageView.accessibilityIgnoresInvertColors            = true
            firstPeerAvatarImageView.accessibilityIgnoresInvertColors   = true
            secondPeerAvatarImageView.accessibilityIgnoresInvertColors  = true
        }
    }
    
    @objc func configure(mode: MegaAvatarViewMode) {
        switch mode {
        case .single:
            avatarImageView.isHidden            = false
            firstPeerAvatarImageView.isHidden   = true
            secondPeerAvatarImageView.isHidden  = true
        case .multiple:
            avatarImageView.isHidden            = true
            firstPeerAvatarImageView.isHidden   = false
            secondPeerAvatarImageView.isHidden  = false
        }
    }
    
    @objc func setup(for chatRoom: MEGAChatRoom) {
        if chatRoom.peerCount == 0 {
            avatarImageView.image = UIImage.init(forName: chatRoom.title?.uppercased(),
                                                 size: avatarImageView.frame.size,
                                                 backgroundColor: UIColor.mnz_secondaryGray(for: traitCollection),
                                                 backgroundGradientColor: UIColor.mnz_grayDBDBDB(),
                                                 textColor: UIColor.white,
                                                 font: UIFont.systemFont(ofSize: avatarImageView.frame.size.width/2.0)
            )
            configure(mode: .single)
        } else {
            let firstPeerHandle = chatRoom.peerHandle(at: 0)
            let firstPeerName = chatRoom.userDisplayName(forUserHandle: firstPeerHandle)
            if chatRoom.peerCount == 1 {
                avatarImageView.mnz_setImage(forUserHandle: firstPeerHandle, name: firstPeerName)
                configure(mode: .single)
            } else {
                let secondPeerHandle = chatRoom.peerHandle(at: 1)
                let secondPeerName = chatRoom.userDisplayName(forUserHandle: secondPeerHandle)
                firstPeerAvatarImageView.mnz_setImage(forUserHandle: firstPeerHandle, name: firstPeerName)
                secondPeerAvatarImageView.mnz_setImage(forUserHandle: secondPeerHandle, name: secondPeerName)
                configure(mode: .multiple)
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                updateAppearance()
            }
        }
    }
    
    func updateAppearance() {
        firstPeerAvatarImageView.layer.borderColor = UIColor.mnz_background()?.cgColor
    }
}
