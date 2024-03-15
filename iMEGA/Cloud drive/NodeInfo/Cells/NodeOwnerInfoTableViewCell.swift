import MEGAChatSdk
import MEGAL10n
import UIKit

class NodeOwnerInfoTableViewCell: UITableViewCell {
    @IBOutlet weak var nameLabel: MEGALabel!
    @IBOutlet weak var emailLabel: MEGALabel!
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var onlineStatusView: RoundedView!
    @IBOutlet weak var contactVerifiedImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        updateAppearance()
        registerForTraitChanges()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard #unavailable(iOS 17.0), traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        updateAppearance()
    }
    
    private func registerForTraitChanges() {
        guard #available(iOS 17.0, *) else { return }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.updateAppearance()
        }
    }

    private func updateAppearance() {
        backgroundColor = UIColor.mnz_tertiaryBackground(traitCollection)
    }
    
    func configure(
        user: MEGAUser,
        shouldDisplayUserVerifiedIcon: Bool
    ) {
        emailLabel.textColor = UIColor.label
        emailLabel.text = user.email
        
        let userDisplayName = user.mnz_displayName ?? ""
        nameLabel.attributedText = createOwnerAttributedString(string: Strings.Localizable.CloudDrive.NodeInfo.owner(userDisplayName as Any),
                                                               highligthedString: userDisplayName,
                                                               normalAttributes: [.foregroundColor: UIColor.mnz_secondaryGray(for: traitCollection),
                                                                                  .font: UIFont.preferredFont(style: .body, weight: .bold)],
                                                               highlightedAttributes: [.foregroundColor: UIColor.label,
                                                                                       .font: UIFont.preferredFont(style: .body, weight: .semibold)])
        
        avatarImageView.mnz_setImage(forUserHandle: user.handle, name: userDisplayName)
        
        onlineStatusView.backgroundColor = UIColor.color(withChatStatus: MEGAChatSdk.shared.userOnlineStatus(user.handle))
        onlineStatusView.layer.cornerRadius = onlineStatusView.frame.height / 2

        contactVerifiedImageView.isHidden = !shouldDisplayUserVerifiedIcon
    }
    
    func createOwnerAttributedString(string: String,
                                     highligthedString: String,
                                     normalAttributes: [NSAttributedString.Key: Any],
                                     highlightedAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        
        let ownerAttributedString = NSMutableAttributedString(string: string, attributes: normalAttributes)
        ownerAttributedString.addAttributes(highlightedAttributes, range: (string as NSString).range(of: highligthedString))
        return ownerAttributedString
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        avatarImageView.image = nil
        nameLabel.text = ""
        emailLabel.text = ""
    }
}
