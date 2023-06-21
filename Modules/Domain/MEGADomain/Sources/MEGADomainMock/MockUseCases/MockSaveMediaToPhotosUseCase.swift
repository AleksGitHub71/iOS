import MEGADomain

public struct MockSaveMediaToPhotosUseCase: SaveMediaToPhotosUseCaseProtocol {
    private let saveToPhotosResult: Result<Void, SaveMediaToPhotosErrorEntity>
    
    public init(saveToPhotosResult: Result<Void, SaveMediaToPhotosErrorEntity> = .failure(.nodeNotFound)) {
        self.saveToPhotosResult = saveToPhotosResult
    }
    
    public func saveToPhotos(nodes: [NodeEntity]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            continuation.resume(with: saveToPhotosResult)
        }
    }
    
    public func saveToPhotosChatNode(handle: HandleEntity, messageId: HandleEntity,
                                     chatId: HandleEntity,
                                     completion: @escaping (Result<Void, SaveMediaToPhotosErrorEntity>) -> Void) {
        completion(saveToPhotosResult)
    }
    
    public func saveToPhotos(fileLink: FileLinkEntity,
                             completion: @escaping (Result<Void, SaveMediaToPhotosErrorEntity>) -> Void) {
        completion(saveToPhotosResult)
    }
}
