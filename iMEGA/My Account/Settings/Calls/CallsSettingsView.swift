import MEGADesignToken
import MEGAPresentation
import SwiftUI

struct CallsSettingsView: View {
    @State var viewModel: CallsSettingsViewModel
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundView: some View {
        if isDesignTokenEnabled {
            TokenColors.Background.page.swiftUI.edgesIgnoringSafeArea([.horizontal, .bottom])
        } else if colorScheme == .dark {
            Color.black.edgesIgnoringSafeArea([.horizontal, .bottom])
        } else {
            Color(.whiteF7F7F7).edgesIgnoringSafeArea([.horizontal, .bottom])
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                CallsSettingsSoundNotificationsView(isOn: $viewModel.callsSoundNotificationPreference, parentGeometry: geometry)
            }
            .edgesIgnoringSafeArea(.horizontal)
            .padding(.top)
            .background(backgroundView)
        }
    }
}
