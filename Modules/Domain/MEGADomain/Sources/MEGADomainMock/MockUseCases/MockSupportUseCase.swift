import MEGADomain

public final class MockSupportUseCase: SupportUseCaseProtocol {
    let createSupportTicketResult: Result<Void, GenericErrorEntity>
    
    public var messages = [Message]()
    
    public enum Message: Equatable {
        case createSupportTicket(message: String)
    }

    public init(createSupportTicketResult: Result<Void, GenericErrorEntity> = .failure(GenericErrorEntity())) {
        self.createSupportTicketResult = createSupportTicketResult
    }

    public func createSupportTicket(
        withMessage message: String
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            continuation.resume(with: createSupportTicketResult)
        }
        messages.append(.createSupportTicket(message: message))
    }
}
