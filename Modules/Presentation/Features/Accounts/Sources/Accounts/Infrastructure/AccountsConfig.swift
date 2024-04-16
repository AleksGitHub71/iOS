import SwiftUI
import UIKit

/// Any configuration needed for account module assets, behaviour or styling
public struct AccountsConfig {
    
    public let onboardingViewAssets: OnboardingViewAssets
    
    public init(
        onboardingViewAssets: AccountsConfig.OnboardingViewAssets
    ) {
        self.onboardingViewAssets = onboardingViewAssets
    }
    
    public struct OnboardingViewAssets {
        public let storageImage: UIImage?
        public let fileSharingImage: UIImage?
        public let backupImage: UIImage?
        public let vpnImage: UIImage?
        public let meetingsImage: UIImage?
        public let onboardingHeaderImage: UIImage?
        
        public let primaryTextColor: Color
        public let primaryGrayTextColor: Color
        public let secondaryTextColor: Color
        public let subMessageBackgroundColor: Color
        public let headerForegroundSelectedColor: Color
        public let headerForegroundUnSelectedColor: Color
        public let headerBackgroundColor: Color
        public let headerStrokeColor: Color
        public let backgroundColor: Color
        public let currentPlanTagColor: Color
        public let recommededPlanTagColor: Color
        
        public init(
            storageImage: UIImage? = nil,
            fileSharingImage: UIImage? = nil,
            backupImage: UIImage? = nil,
            vpnImage: UIImage? = nil,
            meetingsImage: UIImage? = nil,
            onboardingHeaderImage: UIImage? = nil,
            primaryTextColor: Color,
            primaryGrayTextColor: Color,
            secondaryTextColor: Color,
            subMessageBackgroundColor: Color,
            headerForegroundSelectedColor: Color,
            headerForegroundUnSelectedColor: Color,
            headerBackgroundColor: Color,
            headerStrokeColor: Color,
            backgroundColor: Color,
            currentPlanTagColor: Color,
            recommededPlanTagColor: Color
        ) {
            self.storageImage = storageImage
            self.fileSharingImage = fileSharingImage
            self.backupImage = backupImage
            self.vpnImage = vpnImage
            self.meetingsImage = meetingsImage
            self.onboardingHeaderImage = onboardingHeaderImage
            self.primaryGrayTextColor = primaryGrayTextColor
            self.primaryTextColor = primaryTextColor
            self.secondaryTextColor = secondaryTextColor
            self.subMessageBackgroundColor = subMessageBackgroundColor
            self.headerForegroundSelectedColor = headerForegroundSelectedColor
            self.headerForegroundUnSelectedColor = headerForegroundUnSelectedColor
            self.headerBackgroundColor = headerBackgroundColor
            self.headerStrokeColor = headerStrokeColor
            self.backgroundColor = backgroundColor
            self.currentPlanTagColor = currentPlanTagColor
            self.recommededPlanTagColor = recommededPlanTagColor
        }
    }
}
