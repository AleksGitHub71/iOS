import MEGADomain
import MEGAL10n

final class MainTabBarCallsRouter: MainTabBarCallsRouting {
    
    private lazy var callWaitingRoomDialog = CallWaitingRoomUsersDialog()
    private var screenRecordingAlert: UIAlertController?
    private var baseViewController: UIViewController
    private var shouldCheckPendingWaitingRoomNotification: Bool = false

    init(baseViewController: UIViewController) {
        self.baseViewController = baseViewController
    }
    
    func showOneUserWaitingRoomDialog(for username: String, chatName: String, isCallUIVisible: Bool, shouldUpdateDialog: Bool, admitAction: @escaping () -> Void, denyAction: @escaping () -> Void) {
        guard screenRecordingAlert == nil else {
            shouldCheckPendingWaitingRoomNotification = true
            return
        }
        
        guard screenRecordingAlert == nil, let presenter = baseViewController.presenterViewController() else { return }

        callWaitingRoomDialog.showAlertForOneUser(isCallUIVisible: isCallUIVisible, named: username, chatName: chatName, presenterViewController: presenter, isDialogUpdateMandatory: shouldUpdateDialog) {
            admitAction()
        } denyAction: {
            denyAction()
        }
    }
    
    func showSeveralUsersWaitingRoomDialog(for participantsCount: Int, chatName: String, isCallUIVisible: Bool, shouldUpdateDialog: Bool, admitAction: @escaping () -> Void, seeWaitingRoomAction: @escaping () -> Void) {
        guard screenRecordingAlert == nil else {
            shouldCheckPendingWaitingRoomNotification = true
            return
        }
        
        guard screenRecordingAlert == nil, let presenter = baseViewController.presenterViewController() else { return }
                        
        callWaitingRoomDialog.showAlertForSeveralUsers(isCallUIVisible: isCallUIVisible, count: participantsCount, chatName: chatName, presenterViewController: presenter, isDialogUpdateMandatory: shouldUpdateDialog) {
            admitAction()
        } seeWaitingRoomAction: {
            seeWaitingRoomAction()
        }
    }
    
    func dismissWaitingRoomDialog(animated: Bool = true) {
        callWaitingRoomDialog.dismiss(animated: animated)
    }
    
    func showConfirmDenyAction(for username: String, isCallUIVisible: Bool, confirmDenyAction: @escaping () -> Void, cancelDenyAction: @escaping () -> Void) {
        guard screenRecordingAlert == nil, let presenter = baseViewController.presenterViewController() else { return }

        callWaitingRoomDialog.showAlertForConfirmDeny(isCallUIVisible: isCallUIVisible, named: username, presenterViewController: presenter, confirmAction: confirmDenyAction, cancelAction: cancelDenyAction)
    }
    
    func showParticipantsJoinedTheCall(message: String) {
        SVProgressHUD.showSuccess(withStatus: message)
    }
    
    func showWaitingRoomListFor(call: CallEntity, in chatRoom: ChatRoomEntity) {
        let isSpeakerEnabled = AVAudioSession.sharedInstance().isOutputEqualToPortType(.builtInSpeaker)
        MeetingContainerRouter(presenter: baseViewController,
                               chatRoom: chatRoom,
                               call: call,
                               isSpeakerEnabled: isSpeakerEnabled,
                               selectWaitingRoomList: true)
        .start()
    }
    
    private func dismissAlertController(completion: @escaping () -> Void) {
        guard let presentedViewController = baseViewController.presenterViewController()?.presentedViewController,
              presentedViewController.isKind(of: UIAlertController.self) else {
            completion()
            return
        }
        shouldCheckPendingWaitingRoomNotification = true
        presentedViewController.dismiss(animated: true) {
            completion()
        }
    }
    
    func showScreenRecordingAlert(isCallUIVisible: Bool, acceptAction: @escaping (Bool) -> Void, learnMoreAction: @escaping () -> Void, leaveCallAction: @escaping () -> Void) {
        guard let presenter = baseViewController.presenterViewController() else { return }

        dismissAlertController { [weak self] in
            let alert = UIAlertController(
                title: Strings.Localizable.Calls.ScreenRecording.Alert.title,
                message: Strings.Localizable.Calls.ScreenRecording.Alert.message,
                preferredStyle: .alert
            )
            
            let preferredAction = UIAlertAction(
                title: Strings.Localizable.Calls.ScreenRecording.Alert.Action.accept,
                style: .default
            ) { [weak self] _ in
                guard let self else { return }
                acceptAction(shouldCheckPendingWaitingRoomNotification)
                screenRecordingAlert = nil
                shouldCheckPendingWaitingRoomNotification = false
            }
            
            alert.addAction(preferredAction)
            
            alert.preferredAction = preferredAction
            
            alert.addAction(
                UIAlertAction(
                    title: Strings.Localizable.Calls.ScreenRecording.Alert.Action.learnMore,
                    style: .default
                ) { [weak self] _ in
                    learnMoreAction()
                    self?.screenRecordingAlert = nil
                }
            )
            
            alert.addAction(
                UIAlertAction(
                    title: Strings.Localizable.Calls.ScreenRecording.Alert.Action.leave,
                    style: .default
                ) { [weak self] _ in
                    leaveCallAction()
                    self?.screenRecordingAlert = nil
                }
            )
            
            if isCallUIVisible {
                alert.overrideUserInterfaceStyle = .dark
            }

            self?.screenRecordingAlert = alert
            
            presenter.present(alert, animated: true)
        }
    }
    
    func showScreenRecordingNotification(started: Bool, username: String) {
        let statusMessage = started ?
        Strings.Localizable.Calls.ScreenRecording.Notification.Recording.started(username) :
        Strings.Localizable.Calls.ScreenRecording.Notification.Recording.stopped(username)
        
        SVProgressHUD.showSuccess(withStatus: statusMessage)
    }
    
    func navigateToPrivacyPolice() {
        if let url = URL(string: "https://mega.io/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    func dismissCallUI() {
        guard let meetingContainerViewController = baseViewController.presentedViewController as? MeetingContainerViewController else { return }
        meetingContainerViewController.leaveCallFromScreenRecordingAlert()
    }
}
