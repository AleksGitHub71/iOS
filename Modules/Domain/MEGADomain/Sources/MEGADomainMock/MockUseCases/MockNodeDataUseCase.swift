import MEGADomain

public final class MockNodeDataUseCase: NodeUseCaseProtocol {
    private let nodeAccessLevelVariable: NodeAccessTypeEntity
    public var labelStringToReturn: String
    private let filesAndFolders: (Int, Int)
    public var versions: Bool
    public var downloadedToReturn: Bool
    public var inRubbishBinToReturn: Bool
    private var nodes: [NodeEntity]
    private var nodeEntity: NodeEntity?
    
    public var isMultimediaFileNode_CalledTimes = 0
    
    public init(nodeAccessLevelVariable: NodeAccessTypeEntity = .unknown,
                labelString: String = "",
                filesAndFolders: (Int, Int) = (0, 0),
                versions: Bool = false,
                downloaded: Bool = false,
                inRubbishBin: Bool = false,
                nodes: [NodeEntity] = [],
                node: NodeEntity? = nil) {
        self.nodeAccessLevelVariable = nodeAccessLevelVariable
        self.labelStringToReturn = labelString
        self.filesAndFolders = filesAndFolders
        self.versions = versions
        self.downloadedToReturn = downloaded
        self.inRubbishBinToReturn = inRubbishBin
        self.nodes = nodes
        self.nodeEntity = node
    }
    
    public func nodeAccessLevel(nodeHandle: HandleEntity) -> NodeAccessTypeEntity {
        return nodeAccessLevelVariable
    }
    
    public func nodeAccessLevelAsync(nodeHandle: HandleEntity) async -> NodeAccessTypeEntity {
        nodeAccessLevelVariable
    }
    
    public func downloadToOffline(nodeHandle: HandleEntity) { }
    
    public func labelString(label: NodeLabelTypeEntity) -> String {
        labelStringToReturn
    }
    
    public func getFilesAndFolders(nodeHandle: HandleEntity) -> (childFileCount: Int, childFolderCount: Int) {
        filesAndFolders
    }
    
    public func hasVersions(nodeHandle: HandleEntity) -> Bool {
        versions
    }
    
    public func isDownloaded(nodeHandle: HandleEntity) -> Bool {
        downloadedToReturn
    }
    
    public func isInRubbishBin(nodeHandle: HandleEntity) -> Bool {
        inRubbishBinToReturn
    }
    
    public func nodeForHandle(_ handle: HandleEntity) -> NodeEntity? {
        nodes.first {
            $0.handle == handle
        }
    }
    
    public func parentForHandle(_ handle: HandleEntity) -> NodeEntity? {
        nodeEntity
    }
    
    public func parentsForHandle(_ handle: HandleEntity) async -> [NodeEntity]? {
        nil
    }
    
    public func childrenNames(of node: NodeEntity) -> [String]? {
        nil
    }
}
