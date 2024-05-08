import MEGADesignToken
import MEGAL10n
import UIKit

class MeetingInviteParticipantTableViewCell: UITableViewCell {
    @IBOutlet private weak var inviteLabel: UILabel!
    @IBOutlet private weak var inviteIcon: UIImageView!

    var cellTappedHandler: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        inviteLabel.text = Strings.Localizable.Meetings.Panel.inviteParticipants
        inviteIcon.image = UIColor.isDesignTokenEnabled() ? .inviteToChatDesignToken : .inviteContactGray
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:))))
    }
    
    @objc func viewTapped(_ gesture: UITapGestureRecognizer) {
        cellTappedHandler?()
    }
}
