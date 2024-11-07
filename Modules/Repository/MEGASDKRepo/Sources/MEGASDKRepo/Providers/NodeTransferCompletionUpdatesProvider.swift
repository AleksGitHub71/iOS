import MEGADomain
import MEGASdk
import MEGASwift

public protocol NodeTransferCompletionUpdatesProviderProtocol: Sendable {
    /// Node updates from `MEGATransferDelegate` `onTransferFinish` as an `AnyAsyncSequence`
    ///
    /// - Returns: `AnyAsyncSequence` that will call sdk.add on creation and sdk.remove onTermination of `AsyncStream`.
    /// It will yield  completed `TransferEntity` items until sequence terminated
    var nodeTransferUpdates: AnyAsyncSequence<TransferEntity> { get }
}

public struct NodeTransferCompletionUpdatesProvider: NodeTransferCompletionUpdatesProviderProtocol {
    public var nodeTransferUpdates: AnyAsyncSequence<TransferEntity> {
        AsyncStream { continuation in
            let delegate = NodeTransferDelegate {
                continuation.yield($0)
            }
            
            continuation.onTermination = { _ in
                sdk.remove(delegate)
                sharedFolderSdk?.remove(delegate)
            }
            sdk.add(delegate)
            sharedFolderSdk?.add(delegate)
        }
        .eraseToAnyAsyncSequence()
    }
    
    private let sdk: MEGASdk
    private let sharedFolderSdk: MEGASdk?
    
    public init(sdk: MEGASdk, sharedFolderSdk: MEGASdk? = nil) {
        self.sdk = sdk
        self.sharedFolderSdk = sharedFolderSdk
    }
}

private final class NodeTransferDelegate: NSObject, MEGATransferDelegate, Sendable {
    private let onTransferFinish: @Sendable (TransferEntity) -> Void
    
    init(onTransferFinish: @Sendable @escaping (TransferEntity) -> Void) {
        self.onTransferFinish = onTransferFinish
        super.init()
    }
    
    func onTransferFinish(_ api: MEGASdk, transfer: MEGATransfer, error: MEGAError) {
        guard error.type == .apiOk else { return }
        
        onTransferFinish(transfer.toTransferEntity())
    }
}
