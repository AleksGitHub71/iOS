import MEGADesignToken
import MEGAL10n

class ActionSheetCell: UITableViewCell {

    func configureCell(action: BaseAction) {
        NSLayoutConstraint.activate([heightAnchor.constraint(greaterThanOrEqualToConstant: 60.0)])
        textLabel?.text = action.title
        detailTextLabel?.text = action.detail
        if let badge = action.badgeModel {
            accessoryView = newFeatureBadgeView(badge)
        } else {
            accessoryView = action.accessoryView
        }
        if action.syncIconAndTextColor {
            imageView?.image = action.image?.withRenderingMode(.alwaysTemplate)
            // [MEET-3972] adjust and sync image tint to text color for iPad
            imageView?.tintColor = textLabel?.textColor
        } else {
            imageView?.image = action.image
        }
        // [MEET-3972] action item to toggle call layout is disabled
        // when user is sharing his/her screen
        contentView.alpha = action.enabled ? 1.0 : 0.5
        if UIColor.isDesignTokenEnabled() {
            textLabel?.textColor = TokenColors.Text.primary
            detailTextLabel?.textColor = TokenColors.Text.secondary
            backgroundColor = TokenColors.Background.surface1
        }
        
        switch action.style {
        case .cancel, .destructive:
            textLabel?.textColor = UIColor.isDesignTokenEnabled() ? TokenColors.Support.error : .mnz_red(for: traitCollection)
            imageView?.tintColor = UIColor.isDesignTokenEnabled() ? TokenColors.Support.error : .mnz_red(for: traitCollection)
        default: break
        }
    }
    
    func newFeatureBadgeView(_ badge: Badge) -> UIView {
        let badgeView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        badgeView.backgroundColor = badge.backgroundColor
        badgeView.layer.cornerRadius = 10
        
        let badgeLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 15))
        badgeLabel.textColor = badge.foregroundColor
        badgeLabel.font = UIFont.preferredFont(style: .caption2, weight: .medium)
        badgeLabel.text = badge.title
        badgeLabel.textAlignment = .center
        
        badgeView.addSubview(badgeLabel)
        badgeLabel.center = badgeView.center
        
        return badgeView
    }
}
