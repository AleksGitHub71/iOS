import SwiftUI

struct QASettingsView: View {
    
    enum Constants {
        static let appUpdatesHeaderText = "APP UPDATES"
        static let featureListHeaderText = "FEATURE LIST"
        static let checkForUpdateText = "Check for updates"
        static let fingerprintVerificationHeaderText = "SDK SECURE FLAG"
        static let fingerprintVerificationFooterText = "To toggle secure flag: logout user > on onboarding screen > tap 5 times"
        static let fingerprintVerificationText = "Share secure flag: "
        static let cellDarkBackgroundColor = Color(Colors.General.Black._1c1c1e.name)
        static let cellLightBackgroundColor = Color.white
    }
    
    let viewModel: QASettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            Section(header: Text(Constants.appUpdatesHeaderText)) {
                Button {
                    viewModel.checkForUpdate()
                } label: {
                    Text(Constants.checkForUpdateText)
                }
                .listRowBackground(listRowBackgroundColor)
            }            
            
            Section(header: Text(Constants.featureListHeaderText)) {
                FeatureFlagView()
                    .listRowBackground(listRowBackgroundColor)
            }

            Section(header: Text(Constants.fingerprintVerificationHeaderText),
                    footer: Text(Constants.fingerprintVerificationFooterText)) {
                Text(Constants.fingerprintVerificationText + viewModel.fingerprintVerificationFlagStatus())
            }
        }
        .listStyle(.grouped)
        .padding(.top)
        .background(backgroundColor)
    }
    
    private var listRowBackgroundColor: Color {
        colorScheme == .dark ? Constants.cellDarkBackgroundColor : Constants.cellLightBackgroundColor
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? .black : Color(Colors.General.White.f7F7F7.name)
    }
}
