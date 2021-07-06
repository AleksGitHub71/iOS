
import UIKit
import MediaPlayer

class MeetingQuickActionView: UIView {
    
    struct Properties {
        let iconTintColor: StateColor
        let backgroundColor: StateColor
        
        struct StateColor {
            var normal: UIColor
            var selected: UIColor
        }
    }
    
    @IBOutlet weak fileprivate var circularView: CircularView!
    @IBOutlet weak fileprivate var iconImageView: UIImageView!
    @IBOutlet weak fileprivate var nameLabel: UILabel!
    @IBOutlet weak fileprivate var button: UIButton!

    var icon: UIImage? {
        didSet {
            iconImageView.image = icon
        }
    }
    
    var name: String? {
        didSet {
            nameLabel.text = name
        }
    }
    
    var properties: Properties? {
        didSet {
            updateUI()
        }
    }

    var isSelected: Bool = false {
        didSet {
            updateUI()
        }
    }
    
    var disabled: Bool = false {
        didSet {
            updateUI()
        }
    }
    
    private func updateUI() {
        guard let properties = properties else {
            return
        }
        
        circularView.backgroundColor = !disabled && isSelected ? properties.backgroundColor.selected : properties.backgroundColor.normal
        iconImageView.tintColor = !disabled && isSelected ? properties.iconTintColor.selected : disabled ? properties.iconTintColor.normal.withAlphaComponent(0.25) : properties.iconTintColor.normal
    }
}

final class MeetingSpeakerQuickActionView: MeetingQuickActionView {
    
    convenience init(circularView: CircularView?, iconImageView: UIImageView?, nameLabel: UILabel?, button: UIButton?) {
        self.init()
        self.circularView = circularView
        self.iconImageView = iconImageView
        self.iconImageView.image = UIImage(named: "speakerMeetingAction")
        self.iconImageView.contentMode = .scaleAspectFit
        self.nameLabel = nameLabel
        self.button = button
    }
        
    func selectedAudioPortUpdated(_ selectedAudioPort: AudioPort, isBluetoothRouteAvailable: Bool) {
        switch selectedAudioPort {
        case .builtInReceiver, .headphones, .builtInSpeaker:
            iconImageView.image = UIImage(named: "speakerMeetingAction")
            isSelected = !(selectedAudioPort == .builtInReceiver)
        default:
            if isBluetoothRouteAvailable {
                iconImageView.image = UIImage(named: "audioSourceMeetingAction")
                isSelected = true
            } else {
                iconImageView.image = UIImage(named: "speakerMeetingAction")
                isSelected = false
            }
        }
    }

    func addRoutingView() {
        guard subviews.filter({ $0 is AVRoutePickerView }).count == 0 else {
            return
        }
        
        let routerPickerView = AVRoutePickerView()
        routerPickerView.tintColor = .clear
        routerPickerView.activeTintColor = .clear
        wrap(routerPickerView)
    }
    
    func removeRoutingView() {
        guard let routePickerView = subviews.filter({ $0 is AVRoutePickerView }).first as? AVRoutePickerView else {
            return
        }
        
        routePickerView.removeFromSuperview()
    }
}
