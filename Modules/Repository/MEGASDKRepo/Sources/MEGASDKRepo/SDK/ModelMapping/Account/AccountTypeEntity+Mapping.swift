import MEGADomain
import MEGASdk

extension MEGAAccountType {
    public func toAccountTypeEntity() -> AccountTypeEntity {
        switch self {
        case .free:
            return .free
        case .proI:
            return .proI
        case .proII:
            return .proII
        case .proIII:
            return .proIII
        case .lite:
            return .lite
        case .business:
            return .business
        case .proFlexi:
            return .proFlexi
        case .starter:
            return .starter
        case .basic:
            return .basic
        case .essential:
            return .essential
        @unknown default:
            return .free
        }
    }
}

extension AccountTypeEntity {
    public func toMEGAAccountType() -> MEGAAccountType {
        switch self {
        case .free:
            return .free
        case .proI:
            return .proI
        case .proII:
            return .proII
        case .proIII:
            return .proIII
        case .lite:
            return .lite
        case .business:
            return .business
        case .proFlexi:
            return .proFlexi
        case .starter:
            return .starter
        case .basic:
            return .basic
        case .essential:
            return .essential
        }
    }
    
    public func toAccountTypeDisplayName() -> String {
        let accountType = toMEGAAccountType()
        return MEGAAccountDetails.string(for: accountType) ?? ""
    }
}
