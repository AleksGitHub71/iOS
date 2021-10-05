import Foundation

enum PreferenceKeyEntity: String {
    case dontShowAgainAddPhoneNumber
    case backupHeartbeatRegistrationId
    case lastPSARequestTimestamp
    case launchTab
    case lastDateTurnOnNotificationsShowed
    case timesTurnOnNotificationsShowed
    case launchTabSelected
    case launchTabSuggested
    case offlineLogOutWarningDismissed
    case showRecents
    case lastRequestedVersionForRating
    case firstRun = "FirstRun"
    case hasUpdatedBackupToFixExistingBackupNameStorageIssue
}
