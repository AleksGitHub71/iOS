struct ContextAction {
    let type: ContextAction.Category
    let icon: String
    let title: String
    
    enum Category {
        case rename
        case deletePlaylist
    }
}
