import Foundation

public struct EventEntity: Sendable {
    public let type: EventType?
    public let text: String?
    public let reason: ReasonError?
    public let storageState: StorageState?
    public let description: String?
    public let number: Int
    
    public init(
        type: EventEntity.EventType? = nil,
        text: String? = nil,
        reason: EventEntity.ReasonError? = nil,
        storageState: EventEntity.StorageState? = nil,
        description: String? = nil,
        number: Int
    ) {
        self.type = type
        self.text = text
        self.reason = reason
        self.storageState = storageState
        self.description = description
        self.number = number
    }
    
    public enum EventType: Sendable {
        case commitDB
        case accountConfirmation
        case changeToHttps
        case disconnect
        case accountBlocked
        case storage
        case nodesCurrent
        case mediaInfoReady
        case storageSumChanged
        case businessStatus
        case keyModified
        case miscFlagsReady
        case syncsDisabled
        case syncsRestored
        case reqStatProgress
        case reloading
        case fatalError
        case upgradeSecurity
        case downgradeAttack
        case confirmUserEmail
        case creditCardExpiry
    }

    public enum ReasonError: Sendable {
        case unknown
        case noError
        case failureUnserializeNode
        case dbIOFailure
        case dbFull
        case dbIndexOverflow
    }
    
    public enum StorageState: Sendable {
        case green
        case orange
        case red
        case change
        case paywall
    }
    
    public func isStorageCapacityEvent() -> Bool {
        type == .storage &&
        (storageStatus == .noStorageProblems ||
         storageStatus == .almostFull ||
         storageStatus == .full)
    }
    
    public var storageStatus: StorageStatusEntity? {
        switch storageState {
        case .green: .noStorageProblems
        case .orange: .almostFull
        case .red: .full
        case .paywall: .paywall
        case .change: .pendingChange
        default: nil
        }
    }
}

/// Represents the storage state of an account.
public enum StorageStatusEntity: Sendable {
    /// There are no storage problems.
    /// The account has enough space and no issues have been detected.
    case noStorageProblems
    
    /// The account is almost full.
    /// There is limited storage available, and the user should consider freeing up space soon.
    case almostFull
    
    /// The account is full.
    /// No more uploads are allowed as the storage has reached its capacity.
    case full
    
    /// There is a possible significant change in the storage state.
    /// It's necessary to retrieve the updated account details to verify the storage status.
    case pendingChange
    
    /// The account has been full for an extended period.
    /// Most actions are now restricted, and the user must address the over-quota issue.
    case paywall
}

/// Represents the transfer state of an account.
public enum TransferStatusEntity: Sendable {
    /// There are no transfer problems.
    /// The account has enough transfer quota and no issues have been detected.
    case noTransferProblems

    /// The transfer quota is almost full.
    /// There is limited transfer quota remaining, and the user should consider reducing usage soon.
    case almostFull

    /// The transfer quota is full.
    /// No more transfers are allowed as the quota has been fully consumed.
    case full
}
