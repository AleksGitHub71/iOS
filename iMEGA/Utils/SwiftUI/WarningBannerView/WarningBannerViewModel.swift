import MEGAL10n
import MEGAPresentation

enum WarningBannerType: CustomStringConvertible, Equatable {
    case noInternetConnection
    case limitedPhotoAccess
    case contactsNotVerified
    case contactNotVerifiedSharedFolder(String)
    case backupStatusError(String)
    case fullStorageOverQuota
    
    /// The `Severity` enum defines the levels of severity for warnings or alerts displayed in the app.
    ///
    /// This enum is used to categorise different warnings, which influences the different banners' style.
    /// The severity level determines how urgent or important a warning is, and different severity levels
    /// will result in different background colors and icon styles for the warning banners.
    enum Severity {
        case critical
        case warning
    }
    
    var title: String? {
        switch self {
        case .fullStorageOverQuota: Strings.Localizable.Account.Storage.Banner.FullStorageOverQuotaBanner.title
        default: nil
        }
    }
    
    var iconName: String? {
        switch self {
        case .fullStorageOverQuota: "fullStorageAlert"
        default: nil
        }
    }
    
    var actionText: String? {
        switch self {
        case .fullStorageOverQuota: Strings.Localizable.Account.Storage.Banner.FullStorageOverQuotaBanner.button
        default: nil
        }
    }
    
    var severity: Severity {
        switch self {
        case .fullStorageOverQuota: .critical
        default: .warning
        }
    }

    var description: String {
        switch self {
        case .noInternetConnection:
            return Strings.Localizable.General.noIntenerConnection
        case .limitedPhotoAccess:
            return Strings.Localizable.CameraUploads.Warning.limitedAccessToPhotoMessage
        case .contactsNotVerified:
            return Strings.Localizable.ShareFolder.contactsNotVerified
        case .contactNotVerifiedSharedFolder(let nodeName):
            return Strings.Localizable.SharedItems.ContactVerification.contactNotVerifiedBannerMessage(nodeName)
        case .backupStatusError(let errorMessage):
            return errorMessage
        case .fullStorageOverQuota:
            return Strings.Localizable.Account.Storage.Banner.FullStorageOverQuotaBanner.description
        }
    }
}

@objc final class WarningBannerViewModel: NSObject, ObservableObject {
    let warningType: WarningBannerType
    let router: (any WarningBannerViewRouting)?
    let isShowCloseButton: Bool
    var hideWarningViewAction: (() -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?
    @Published var isHideWarningView: Bool = false
    
    let applyNewDesign: Bool
    
    init(warningType: WarningBannerType,
         router: (any WarningBannerViewRouting)? = nil,
         isShowCloseButton: Bool = false,
         hideWarningViewAction: (() -> Void)? = nil,
         onHeightChange: ((CGFloat) -> Void)? = nil) {
        self.warningType = warningType
        self.router = router
        self.isShowCloseButton = isShowCloseButton
        self.hideWarningViewAction = hideWarningViewAction
        self.onHeightChange = onHeightChange
        
        self.applyNewDesign = warningType == .fullStorageOverQuota
    }
    
    func tapAction() {
        switch warningType {
        case .limitedPhotoAccess:
            router?.goToSettings()
        default: break
        }
    }
    
    func closeAction() {
        isHideWarningView = true
        hideWarningViewAction?()
    }
}
