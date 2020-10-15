
struct AddToChatMenu: Codable {
    enum MenuNameKey: String {
        case photos = "Photos"
        case file = "File"
        case voice = "Voice"
        case video = "Video"
        case contact = "Contact"
        case scanDoc = "Scan Document"
        case startGroup = "Start Group"
        case location = "Location"
        case voiceClip = "Voice Clip"
    }
    
    let nameKey: String
    let imageKey: String
    let dynamicKey: Bool
    
    static func menus() -> [AddToChatMenu]? {
        if let fileURL = Bundle.main.url(forResource: "AddToChatMenus",   withExtension: "plist")  {
            do {
                let propertyListDecoder = PropertyListDecoder()
                let data = try Data(contentsOf: fileURL)
                return try propertyListDecoder.decode([AddToChatMenu].self, from: data)
            } catch {
                MEGALogDebug(error.localizedDescription)
            }
        }
        
        return nil
    }
    
    var menuNameKey: MenuNameKey? {
        switch nameKey {
        case MenuNameKey.photos.rawValue:
            return .photos
        case MenuNameKey.file.rawValue:
            return .file
        case MenuNameKey.voice.rawValue:
            return .voice
        case MenuNameKey.video.rawValue:
            return .video
        case MenuNameKey.contact.rawValue:
            return .contact
        case MenuNameKey.scanDoc.rawValue:
            return .scanDoc
        case MenuNameKey.startGroup.rawValue:
            return .startGroup
        case MenuNameKey.location.rawValue:
            return .location
        case MenuNameKey.voiceClip.rawValue:
            return .voiceClip
        default:
            return nil
        }
    }
}
