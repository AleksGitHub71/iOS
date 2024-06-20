@testable import MEGA
import MEGAAnalyticsiOS
import MEGADomain
import MEGADomainMock
import MEGAPresentation
import MEGAPresentationMock

extension MeetingContainerViewModel {
    
    convenience init(
        router: some MeetingContainerRouting = MockMeetingContainerRouter(),
        chatRoom: ChatRoomEntity = ChatRoomEntity(),
        callUseCase: some CallUseCaseProtocol = MockCallUseCase(call: CallEntity()),
        chatRoomUseCase: some ChatRoomUseCaseProtocol = MockChatRoomUseCase(),
        chatUseCase: some ChatUseCaseProtocol = MockChatUseCase(),
        scheduledMeetingUseCase: some ScheduledMeetingUseCaseProtocol = MockScheduledMeetingUseCase(),
        accountUseCase: any AccountUseCaseProtocol = MockAccountUseCase(currentUser: UserEntity(handle: 100), isGuest: false, isLoggedIn: true),
        authUseCase: some AuthUseCaseProtocol = MockAuthUseCase(),
        noUserJoinedUseCase: some MeetingNoUserJoinedUseCaseProtocol = MockMeetingNoUserJoinedUseCase(),
        analyticsEventUseCase: some AnalyticsEventUseCaseProtocol =  MockAnalyticsEventUseCase(),
        megaHandleUseCase: some MEGAHandleUseCaseProtocol = MockMEGAHandleUseCase(),
        callManager: some CallManagerProtocol = MockCallManager(),
        tracker: some AnalyticsTracking = MockTracker(),
        featureFlag: some FeatureFlagProviderProtocol = MockFeatureFlagProvider(list: [:]),
        isTesting: Bool = true
    ) {
        self.init(
            router: router,
            chatRoom: chatRoom,
            callUseCase: callUseCase,
            chatRoomUseCase: chatRoomUseCase,
            chatUseCase: chatUseCase,
            scheduledMeetingUseCase: scheduledMeetingUseCase,
            accountUseCase: accountUseCase,
            authUseCase: authUseCase,
            noUserJoinedUseCase: noUserJoinedUseCase,
            analyticsEventUseCase: analyticsEventUseCase,
            megaHandleUseCase: megaHandleUseCase,
            callManager: callManager,
            tracker: tracker,
            featureFlagProvider: featureFlag
        )
    }
}
