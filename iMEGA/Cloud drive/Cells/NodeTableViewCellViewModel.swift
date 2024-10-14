import Combine
import Foundation
import MEGADomain
import MEGAPresentation
import MEGASwift

@MainActor
@objc final class NodeTableViewCellViewModel: NSObject {
    
    @Published private(set) var isSensitive: Bool = false
    @Published private(set) var thumbnail: UIImage?
    let hasThumbnail: Bool
    
    private let nodes: [NodeEntity]
    private let shouldApplySensitiveBehaviour: Bool
    private let sensitiveNodeUseCase: any SensitiveNodeUseCaseProtocol
    private let thumbnailUseCase: any ThumbnailUseCaseProtocol
    private let nodeIconUseCase: any NodeIconUsecaseProtocol
    private let accountUseCase: any AccountUseCaseProtocol
    private let featureFlagProvider: any FeatureFlagProviderProtocol
    private var task: Task<Void, Never>?
    
    init(nodes: [NodeEntity],
         shouldApplySensitiveBehaviour: Bool,
         sensitiveNodeUseCase: some SensitiveNodeUseCaseProtocol,
         thumbnailUseCase: some ThumbnailUseCaseProtocol,
         nodeIconUseCase: some NodeIconUsecaseProtocol,
         accountUseCase: some AccountUseCaseProtocol,
         featureFlagProvider: some FeatureFlagProviderProtocol = DIContainer.featureFlagProvider) {
        
        self.nodes = nodes
        self.hasThumbnail = [
            nodes.count == 1,
            nodes.first?.hasThumbnail ?? false
        ].allSatisfy { $0 }
        self.shouldApplySensitiveBehaviour = shouldApplySensitiveBehaviour
        self.sensitiveNodeUseCase = sensitiveNodeUseCase
        self.thumbnailUseCase = thumbnailUseCase
        self.nodeIconUseCase = nodeIconUseCase
        self.accountUseCase = accountUseCase
        self.featureFlagProvider = featureFlagProvider
    }
    
    deinit {
        task?.cancel()
        task = nil
    }
    
    @discardableResult
    func configureCell() -> Task<Void, Never> {
        self.task?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await applySensitiveConfiguration(for: nodes)
            await loadThumbnail()
        }
        self.task = task
        return task
    }
    
    private nonisolated func loadThumbnail() async {
        guard let node = nodes.first else {
            return
        }
        
        guard hasThumbnail else {
            await setThumbnailImage(UIImage(data: nodeIconUseCase.iconData(for: node)))
            return
        }
        
        do {
            let thumbnailEntity: ThumbnailEntity
            if let cached = thumbnailUseCase.cachedThumbnail(for: node, type: .thumbnail) {
                thumbnailEntity = cached
            } else {
                await setThumbnailImage(UIImage(data: nodeIconUseCase.iconData(for: node)))
                thumbnailEntity = try await thumbnailUseCase.loadThumbnail(for: node, type: .thumbnail)
            }
            
            let imagePath = if #available(iOS 16.0, *) {
                thumbnailEntity.url.path()
            } else {
                thumbnailEntity.url.path
            }
            await setThumbnailImage(UIImage(contentsOfFile: imagePath))
        } catch {
            MEGALogError("[ItemCollectionViewCellViewModel] Error loading thumbnail: \(error)")
        }
    }
    
    private func applySensitiveConfiguration(for nodes: [NodeEntity]) async {
        guard featureFlagProvider.isFeatureFlagEnabled(for: .hiddenNodes),
              shouldApplySensitiveBehaviour,
              accountUseCase.hasValidProOrUnexpiredBusinessAccount() else {
            await setIsSensitive(false)
            return
        }
        
        guard nodes.count == 1,
              let node = nodes.first else {
            await setIsSensitive(false)
            return
        }
        
        guard !node.isMarkedSensitive else {
            await setIsSensitive(true)
            return
        }
        
        do {
            await setIsSensitive(try sensitiveNodeUseCase.isInheritingSensitivity(node: node))
        } catch {
            MEGALogError("[\(type(of: self))] Error checking if node is inheriting sensitivity: \(error)")
        }
    }
    
    private func setThumbnailImage(_ newImage: UIImage?) async {
        guard !Task.isCancelled else { return }
        thumbnail = newImage
    }
    
    private func setIsSensitive(_ newValue: Bool) async {
        guard !Task.isCancelled else { return }
        isSensitive = newValue
    }
}
