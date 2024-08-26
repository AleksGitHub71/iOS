import MEGASwift

public protocol SessionUpdateUseCaseProtocol: Sendable {
    func monitorOnSessionUpdate() -> AnyAsyncThrowingSequence<ChatSessionEntity, any Error>
}

public struct SessionUpdateUseCase<T: SessionUpdateRepositoryProtocol>: SessionUpdateUseCaseProtocol {
    private let repository: T
    
    public init(repository: T) {
        self.repository = repository
    }

    public func monitorOnSessionUpdate() -> AnyAsyncThrowingSequence<ChatSessionEntity, any Error> {
        repository.sessionUpdate
            .eraseToAnyAsyncThrowingSequence()
    }
}