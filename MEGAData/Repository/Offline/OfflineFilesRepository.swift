import Foundation

class OfflineFilesRepository: OfflineFilesRepositoryProtocol {
    
    private let store: MEGAStore
    
    init(store: MEGAStore) {
        self.store = store
    }
    
    func offlineFiles() -> [OfflineFileEntity] {
        guard let offlineNodes = store.fetchOfflineNodes(MEGAQuickAccessWidgetMaxDisplayItems as NSNumber, inRootFolder: true) else {
            return []
        }
        
        return offlineNodes.map {
            OfflineFileEntity(with: $0)
        }
    }
    
    func offlineFile(for base64Handle: MEGABase64Handle) -> OfflineFileEntity? {
        if let offlineNode = store.offlineNode(withHandle: base64Handle) {
            return OfflineFileEntity(with: offlineNode)
        } else {
            return nil
        }
    }
}
