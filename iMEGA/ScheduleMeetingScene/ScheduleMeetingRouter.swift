import Combine
import MEGADomain
import SwiftUI

final class ScheduleMeetingRouter {
    private(set) var presenter: UINavigationController
    private(set) weak var baseViewController: UINavigationController?
    private let viewConfiguration: any ScheduleMeetingViewConfigurable
    private var occurrenceUpdatePromise: Future<ScheduledMeetingOccurrenceEntity, Never>.Promise?
    private var meetingUpdatePromise: Future<ScheduledMeetingEntity, Never>.Promise?

    init(
        presenter: UINavigationController,
        viewConfiguration: any ScheduleMeetingViewConfigurable
    ) {
        self.presenter = presenter
        self.viewConfiguration = viewConfiguration
    }
    
    func onOccurrenceUpdate() -> AnyPublisher<ScheduledMeetingOccurrenceEntity, Never> {
        Future { [weak self] in
            guard let self else { return }
            occurrenceUpdatePromise = $0
        }.eraseToAnyPublisher()
    }
    
    func onMeetingUpdate() -> AnyPublisher<ScheduledMeetingEntity, Never> {
        Future { [weak self] in
            guard let self else { return }
            meetingUpdatePromise = $0
        }.eraseToAnyPublisher()
    }
    
    func build() -> UINavigationController {
        let viewModel = ScheduleMeetingViewModel(
            router: self,
            viewConfiguration: viewConfiguration,
            accountUseCase: AccountUseCase(repository: AccountRepository.newRepo)
        )

        let viewController = ScheduleMeetingViewController(viewModel: viewModel)
        let navigation = MEGANavigationController(rootViewController: viewController)
        
        baseViewController = navigation
        
        return navigation
    }
    
    func start() {
        presenter.present(build(), animated: true)
    }
}

extension ScheduleMeetingRouter: ScheduleMeetingRouting {
    func showSpinner() {
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.show()
    }
    
    func hideSpinner() {
        SVProgressHUD.dismiss()
    }
    
    @MainActor
    func dismiss(animated: Bool) async {
        await withCheckedContinuation { continuation in
            presenter.dismiss(animated: animated) {
                continuation.resume()
            }
        }
    }
    
    @MainActor
    func showSuccess(message: String) {
        SVProgressHUD.showSuccess(withStatus: message)
    }
    
    func showMeetingInfo(for scheduledMeeting: ScheduledMeetingEntity) {
        MeetingInfoRouter(presenter: self.presenter, scheduledMeeting: scheduledMeeting).start()
    }
    
    func updated(occurrence: ScheduledMeetingOccurrenceEntity) {
        guard let occurrenceUpdatePromise else { return }
        occurrenceUpdatePromise(.success(occurrence))
        self.occurrenceUpdatePromise = nil
    }
    
    func updated(meeting: ScheduledMeetingEntity) {
        guard let meetingUpdatePromise else { return }
        meetingUpdatePromise(.success(meeting))
        self.meetingUpdatePromise = nil
    }
    
    func showAddParticipants(alreadySelectedUsers: [UserEntity], newSelectedUsers: @escaping (([UserEntity]?) -> Void)) {
        let storyboard = UIStoryboard(name: "Contacts", bundle: nil)
        let contactsNavigationController = storyboard.instantiateViewController(withIdentifier: "ContactsNavigationControllerID") as! UINavigationController
        let contactController = contactsNavigationController.viewControllers.first as! ContactsViewController
        contactController.contactsMode = .scheduleMeeting
        contactController.chatOptionType = .meeting
        contactController.userSelected = { users in
            newSelectedUsers(users?.compactMap { $0.toUserEntity() })
        }
        
        baseViewController?.present(contactsNavigationController, animated: true) {
            contactController.selectUsers(alreadySelectedUsers.compactMap { $0.toMEGAUser() })
        }
    }
    
    @MainActor
    func showRecurrenceOptionsView(rules: ScheduledMeetingRulesEntity, startDate: Date) -> AnyPublisher<ScheduledMeetingRulesEntity, Never>? {
        guard let baseViewController else { return nil }
        let router = ScheduleMeetingCreationRecurrenceOptionsRouter(presenter: baseViewController, rules: rules, startDate: startDate)
        router.start()
        return router.$rules.eraseToAnyPublisher()
    }
    
    @MainActor
    func showEndRecurrenceOptionsView(rules: ScheduledMeetingRulesEntity, startDate: Date) -> AnyPublisher<ScheduledMeetingRulesEntity, Never>? {
        guard let baseViewController else { return nil }
        let router = ScheduleMeetingEndRecurrenceOptionsRouter(presenter: baseViewController, rules: rules, startDate: startDate)
        router.start()
        return router.$rules.eraseToAnyPublisher()
    }
}
 
