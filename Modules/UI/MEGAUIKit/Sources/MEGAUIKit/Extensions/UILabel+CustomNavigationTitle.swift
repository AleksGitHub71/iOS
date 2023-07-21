import UIKit

public extension UILabel {
    @objc func customNavigationBarLabel(title: String, subtitle: String?, color: UIColor = UIColor.label) -> UILabel {
        let label = UILabel()
        label.numberOfLines = (subtitle != nil) ? 2 : 1
        label.lineBreakMode = .byTruncatingTail
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        
        let attributedTitleString = NSMutableAttributedString(string: title, attributes: [
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline),
            .foregroundColor: color
        ])
        
        guard let subtitle = subtitle, subtitle.count != 0 else {
            label.attributedText = attributedTitleString
            return label
        }
        
        let subtitleString = String(format: "\n%@", subtitle)
        let attributedSubtitleString = NSMutableAttributedString(string: subtitleString, attributes: [
            NSAttributedString.Key.font: UIFont.preferredFont(style: .caption1, weight: .semibold),
            .foregroundColor: color.withAlphaComponent(0.8)
        ])
        
        attributedTitleString.append(attributedSubtitleString)
        label.attributedText = attributedTitleString
        return label
    }
}
