public protocol SaveMediaToPhotosUseCaseProtocol {
    func saveToPhotos(nodes: [NodeEntity]) async throws
    func saveToPhotosChatNode(handle: HandleEntity, messageId: HandleEntity, chatId: HandleEntity, completion: @escaping (Result<Void, SaveMediaToPhotosErrorEntity>) -> Void)
    func saveToPhotos(fileLink: FileLinkEntity, completion: @escaping (Result<Void, SaveMediaToPhotosErrorEntity>) -> Void)
}
        
public struct SaveMediaToPhotosUseCase<T: DownloadFileRepositoryProtocol, U: FileCacheRepositoryProtocol, V: NodeRepositoryProtocol, W: ChatNodeRepositoryProtocol, X: DownloadChatRepositoryProtocol>: SaveMediaToPhotosUseCaseProtocol {
    private let downloadFileRepository: T
    private let fileCacheRepository: U
    private let nodeRepository: V
    private let chatNodeRepository: W
    private let downloadChatRepository: X

    public init(
        downloadFileRepository: T,
        fileCacheRepository: U,
        nodeRepository: V,
        chatNodeRepository: W,
        downloadChatRepository: X
    ) {
        self.downloadFileRepository = downloadFileRepository
        self.fileCacheRepository = fileCacheRepository
        self.nodeRepository = nodeRepository
        self.chatNodeRepository = chatNodeRepository
        self.downloadChatRepository = downloadChatRepository
    }
    
    private func saveToPhotos(node: NodeEntity) async throws {
        do {
            let tempUrl = fileCacheRepository.tempFileURL(for: node)
            try _ = await downloadFileRepository.download(nodeHandle: node.handle, to: tempUrl, metaData: .saveInPhotos)
        } catch TransferErrorEntity.download {
            throw SaveMediaToPhotosErrorEntity.fileDownloadInProgress
        } catch TransferErrorEntity.cancelled {
            throw SaveMediaToPhotosErrorEntity.cancelled
        } catch {
            throw SaveMediaToPhotosErrorEntity.downloadFailed
        }
    }
    
    public func saveToPhotos(nodes: [NodeEntity]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            guard taskGroup.isCancelled == false else {
                throw TransferErrorEntity.generic
            }
            
            nodes.forEach { node in
                taskGroup.addTask {
                    try await saveToPhotos(node: node)
                }
            }
            
            try await taskGroup.waitForAll()
        }
    }
    
    public func saveToPhotosChatNode(handle: HandleEntity, messageId: HandleEntity, chatId: HandleEntity, completion: @escaping (Result<Void, SaveMediaToPhotosErrorEntity>) -> Void) {
        guard let node = chatNodeRepository.chatNode(handle: handle, messageId: messageId, chatId: chatId) else {
            completion(.failure(.nodeNotFound))
            return
        }
        
        let tempUrl = fileCacheRepository.tempFileURL(for: node)
        
        downloadChatRepository.downloadChat(nodeHandle: handle, messageId: messageId, chatId: chatId, to: tempUrl, metaData: .saveInPhotos) { result in
            switch result {
            case .success:
                completion(.success)
            case .failure(let error):
                completion(.failure(error == TransferErrorEntity.cancelled ? .cancelled : .downloadFailed))
            }
        }
    }
    
    public func saveToPhotos(fileLink: FileLinkEntity, completion: @escaping (Result<Void, SaveMediaToPhotosErrorEntity>) -> Void) {
        nodeRepository.nodeFor(fileLink: fileLink) { result in
            switch result {
            case .success(let node):
                downloadFileRepository.downloadFileLink(fileLink, named: node.name, to: fileCacheRepository.base64HandleTempFolder(for: node.base64Handle), metaData: .saveInPhotos, startFirst: true, start: nil, update: nil) { result in
                    switch result {
                    case .success:
                        completion(.success)
                    case .failure(let error):
                        completion(.failure(error == TransferErrorEntity.cancelled ? .cancelled : .downloadFailed))
                    }
                }
            case .failure:
                completion(.failure(.nodeNotFound))
            }
        }
    }
}
