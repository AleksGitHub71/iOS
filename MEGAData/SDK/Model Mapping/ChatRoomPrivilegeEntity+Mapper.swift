import MEGADomain

extension ChatRoomPrivilegeEntity {
    func toChatRoomParticipantPrivilege() -> ChatRoomParticipantPrivilege {
        switch self {
        case .unknown:
            return .unknown
        case .removed:
            return .removed
        case .readOnly:
            return .readOnly
        case .standard:
            return .standard
        case .moderator:
            return .moderator
        }
    }
    
    func toMEGAChatRoomPrivilege() -> MEGAChatRoomPrivilege {
        switch self {
        case .unknown:
            return .unknown
        case .removed:
            return .rm
        case .readOnly:
            return .ro
        case .standard:
            return .standard
        case .moderator:
            return .moderator
        }
    }
}

extension ChatRoomParticipantPrivilege {
    func toChatRoomPrivilegeEntity() -> ChatRoomPrivilegeEntity {
        switch self {
        case .unknown:
            return .unknown
        case .removed:
            return .removed
        case .readOnly:
            return .readOnly
        case .standard:
            return .standard
        case .moderator:
            return .moderator
        }
    }
}
