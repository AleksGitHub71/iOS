import XCTest
@testable import MEGA

class NodeActionBuilderTests: XCTestCase {
    
    var actions: [NodeAction] = []
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super .tearDown()
        actions.removeAll()
    }
    
    //MARK: - Private methods
    
    func isEqual(nodeActionTypes types: [MegaNodeActionType]) -> Bool {
        guard actions.count == types.count else {
            return false
        }
        let actionTypes = actions.map{ $0.type }
        return actionTypes == types
    }
    
    // MARK: - Cloud Drive tests
    
    func testCloudDriveNodeMediaFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsMediaFile(true)
            .setIsFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .saveToPhotos, .download, .shareLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeMediaFileExported() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsMediaFile(true)
            .setIsFile(true)
            .setIsExported(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .saveToPhotos, .download, .manageLink, .removeLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeFolder() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsFile(false)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .shareLink, .shareFolder, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeFolderExported() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsFile(false)
            .setIsExported(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .manageLink, .removeLink, .shareFolder, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeFolderShared() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsFile(false)
            .setIsOutshare(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .shareLink, .manageShare, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeFolderSharedExported() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsFile(false)
            .setIsOutshare(true)
            .setIsExported(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .manageLink, .removeLink, .manageShare, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .shareLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeExportedFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setIsExported(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .manageLink, .removeLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeTextFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsEditableTextFile(true)
            .setIsFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.editTextFile, .info, .favourite, .label, .download, .shareLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeTextFileExported() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsEditableTextFile(true)
            .setIsFile(true)
            .setIsExported(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.editTextFile, .info, .favourite, .label, .download, .manageLink, .removeLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeWithNoVersion() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setVersionCount(0)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .shareLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveNodeWithMultiVersions() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setVersionCount(2)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .viewVersions, .favourite, .label, .download, .shareLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testCloudDriveTextFileNodeWithMultiVersions() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsEditableTextFile(true)
            .setIsFile(true)
            .setVersionCount(2)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.editTextFile, .info, .viewVersions, .favourite, .label, .download, .shareLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testFileFolderNodeDoNotShowInfoAction() {
        actions = NodeActionBuilder()
            .setDisplayMode(.nodeInfo)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download]))
    }
    
    func testCloudDriveTakedownNode() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setIsTakedown(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .disputeTakedown, .rename, .moveToRubbishBin]))
    }
    
    //MARK: - Rubbish Bin
    func testRubbishBinNodeRestorableFolder() {
        actions = NodeActionBuilder()
            .setDisplayMode(.rubbishBin)
            .setAccessLevel(.accessOwner)
            .setIsFile(false)
            .setIsRestorable(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.restore, .info, .remove]))
    }
    
    func testRubbishBinNodeUnrestorableFolder() {
        actions = NodeActionBuilder()
            .setDisplayMode(.rubbishBin)
            .setAccessLevel(.accessOwner)
            .setIsFile(false)
            .setIsRestorable(false)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .remove]))
    }
    
    func testRubbishBinNodeRestorableFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.rubbishBin)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setIsRestorable(true)
            .setIsInVersionsView(false)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.restore, .info, .remove]))
    }
    
    func testRubbishBinNodeUnrestorableFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.rubbishBin)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setIsRestorable(false)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .remove]))
    }
    
    func testRubbishBinNodeVersionPreview() {
        actions = NodeActionBuilder()
            .setDisplayMode(.rubbishBin)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setIsRestorable(true)
            .setIsInVersionsView(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info]))
    }
    
    func testRubbishBinTakedownNode() {
        actions = NodeActionBuilder()
            .setDisplayMode(.rubbishBin)
            .setIsTakedown(true)
            .build()
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .disputeTakedown, .rename, .remove]))
    }
    
    //MARK: - Recent Items tests
    
    func testRecentNodeNoVersion() {
        actions = NodeActionBuilder()
            .setDisplayMode(.recents)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setVersionCount(0)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .shareLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testRecentNodeWithMultiVersion() {
        actions = NodeActionBuilder()
            .setDisplayMode(.recents)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setVersionCount(2)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .viewVersions, .favourite, .label, .download, .shareLink, .exportFile, .sendToChat, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    // MARK: - Shared Items tests
    
    func testIncomingFullSharedFolder() {
        actions = NodeActionBuilder()
            .setDisplayMode(.sharedItem)
            .setAccessLevel(.accessFull)
            .setIsFile(false)
            .setisIncomingShareChildView(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .rename, .copy, .leaveSharing]))
    }
    
    func testIncomingFullSharedFolderTextFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.sharedItem)
            .setAccessLevel(.accessFull)
            .setIsEditableTextFile(true)
            .setIsFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.editTextFile, .info, .favourite, .label, .download, .rename, .copy, .move, .moveToRubbishBin]))
    }
    
    func testIncomingFullSharedFolderNodeNoVersion() {
        actions = NodeActionBuilder()
            .setDisplayMode(.sharedItem)
            .setAccessLevel(.accessFull)
            .setIsFile(true)
            .setVersionCount(0)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .rename, .copy, .move, .moveToRubbishBin]))
    }
    
    func testIncomingFullSharedFolderNodeWithMultiVersion() {
        actions = NodeActionBuilder()
            .setDisplayMode(.sharedItem)
            .setAccessLevel(.accessFull)
            .setIsFile(true)
            .setVersionCount(2)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .viewVersions, .favourite, .label, .download, .rename, .copy, .move, .moveToRubbishBin]))
    }
    
    func testIncomingReadAndReadWriteSharedFolder() {
        actions = NodeActionBuilder()
            .setDisplayMode(.sharedItem)
            .setAccessLevel(.accessReadWrite)
            .setIsFile(false)
            .setisIncomingShareChildView(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .download, .copy, .leaveSharing]))
    }
    
    func testIncomingReadAndReadWriteSharedFolderTextFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.sharedItem)
            .setAccessLevel(.accessReadWrite)
            .setIsEditableTextFile(true)
            .setIsFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.editTextFile, .info, .download, .copy]))
    }
    
    func testIncomingReadAndReadWriteSharedFolderNodeNoVersion() {
        actions = NodeActionBuilder()
            .setDisplayMode(.sharedItem)
            .setAccessLevel(.accessReadWrite)
            .setIsFile(true)
            .setVersionCount(0)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .download, .copy]))
    }
    
    func testIncomingReadAndReadWriteSharedFolderNodeWithMultiVersion() {
        actions = NodeActionBuilder()
            .setDisplayMode(.sharedItem)
            .setAccessLevel(.accessReadWrite)
            .setIsFile(true)
            .setVersionCount(2)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .viewVersions, .download, .copy]))
    }
    
    func testOutgoingSharedFolder() {
        actions = NodeActionBuilder()
            .setDisplayMode(.sharedItem)
            .setAccessLevel(.accessOwner)
            .setIsFile(false)
            .setIsOutshare(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .shareLink, .manageShare, .rename, .copy, .removeSharing]))
    }
    
    func testOutgoingSharedFolderExported() {
        actions = NodeActionBuilder()
            .setDisplayMode(.sharedItem)
            .setAccessLevel(.accessOwner)
            .setIsFile(false)
            .setIsOutshare(true)
            .setIsExported(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .manageLink, .removeLink, .manageShare, .rename, .copy, .removeSharing]))
    }
    
    // MARK: - Links tests
    
    func testFileMediaLink() {
        actions = NodeActionBuilder()
            .setDisplayMode(.fileLink)
            .setIsFile(true)
            .setIsMediaFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download, .shareLink, .sendToChat, .saveToPhotos]))
    }
    
    func testFileLink() {
        actions = NodeActionBuilder()
            .setDisplayMode(.fileLink)
            .setIsFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download, .shareLink, .sendToChat]))
    }
    
    func testFolderLinkList() {
        actions = NodeActionBuilder()
            .setDisplayMode(.folderLink)
            .setIsFile(false)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download, .select, .shareLink, .sendToChat, .sort, .thumbnail]))
    }
    
    func testFolderLinkThumbnail() {
        actions = NodeActionBuilder()
            .setDisplayMode(.folderLink)
            .setIsFile(false)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download, .select, .shareLink, .sendToChat, .sort, .thumbnail]))
    }
    
    func testFolderLinkChildMediaFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.nodeInsideFolderLink)
            .setIsFile(true)
            .setIsMediaFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download, .saveToPhotos]))
    }
    
    func testFolderLinkChildFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.nodeInsideFolderLink)
            .setIsFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download]))
    }
    
    func testFileLinkArrayWithPublicLink() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.files, selectedNodeCount: 2)
            .setLinkedNodeCount(2)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .removeLink, .exportFile, .sendToChat, .move, .copy, .moveToRubbishBin]))
    }
    
    func testFolderLinkArrayWithPublicLink() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.folders, selectedNodeCount: 2)
            .setLinkedNodeCount(2)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .removeLink, .shareFolder, .move, .copy, .moveToRubbishBin]))
    }
    
    func testFileAndFolderLinkArrayWithPublicLink() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.filesAndFolders, selectedNodeCount: 2)
            .setLinkedNodeCount(2)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .removeLink, .move, .copy, .moveToRubbishBin]))
    }
    
    func testFileLinkArrayWithoutPublicLink() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.files, selectedNodeCount: 2)
            .setLinkedNodeCount(0)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .exportFile, .sendToChat, .move, .copy, .moveToRubbishBin]))
    }
    
    func testFolderLinkArrayWithoutPublicLink() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.folders, selectedNodeCount: 2)
            .setLinkedNodeCount(0)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .shareFolder, .move, .copy, .moveToRubbishBin]))
    }
    
    func testFileAndFolderLinkArrayWithoutPublicLink() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.filesAndFolders, selectedNodeCount: 2)
            .setLinkedNodeCount(0)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .move, .copy, .moveToRubbishBin]))
    }
    
    // MARK: - Text Editor
    
    func testTextEditorAcessUnknown() {
        actions = NodeActionBuilder()
            .setDisplayMode(.textEditor)
            .setAccessLevel(.accessUnknown)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .import, .exportFile, .sendToChat]))
    }
    
    func testTextEditorAcessRead() {
        actions = NodeActionBuilder()
            .setDisplayMode(.textEditor)
            .setAccessLevel(.accessRead)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .import, .exportFile, .sendToChat]))
    }
    
    func testTextEditorAcessReadWrite() {
        actions = NodeActionBuilder()
            .setDisplayMode(.textEditor)
            .setAccessLevel(.accessReadWrite)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.editTextFile, .download, .import, .exportFile, .sendToChat]))
    }
    
    func testTextEditorAcessFull() {
        actions = NodeActionBuilder()
            .setDisplayMode(.textEditor)
            .setAccessLevel(.accessFull)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.editTextFile, .download, .import, .exportFile, .sendToChat]))
    }
    
    func testTextEditorAcessOwner() {
        actions = NodeActionBuilder()
            .setDisplayMode(.textEditor)
            .setAccessLevel(.accessOwner)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.editTextFile, .download, .shareLink, .exportFile, .sendToChat]))
    }
    
    // MARK: - Preview Documents
    
    func testDocumentPreviewFileLink() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .setIsLink(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download, .shareLink, .sendToChat]))
    }
    
    func testDocumentPreviewPdfPageViewLink() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .setIsPdf(true)
            .setIsPageView(true)
            .setIsLink(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download, .shareLink, .sendToChat, .search, .pdfThumbnailView]))
    }
    
    func testDocumentPreviewPdfThumbnailLink() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .setIsPdf(true)
            .setIsLink(true)
            .setIsPageView(false)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download, .shareLink, .sendToChat, .search, .pdfPageView]))
    }
    
    func testPreviewDocument() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .sendToChat]))
    }
    
    func testPreviewDocumentOwner() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .setAccessLevel(.accessOwner)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .exportFile, .sendToChat]))
    }
    
    func testPreviewPdfPageViewDocument() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .setIsPdf(true)
            .setIsPageView(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .sendToChat, .search, .pdfThumbnailView]))
    }
    
    func testPreviewPdfPageViewDocumentLink() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .setIsPdf(true)
            .setIsPageView(true)
            .setIsLink(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download, .shareLink, .sendToChat, .search, .pdfThumbnailView]))
    }
    
    func testPreviewPdfPageViewDocumentOwner() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .setIsPdf(true)
            .setIsPageView(true)
            .setAccessLevel(.accessOwner)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .exportFile, .sendToChat, .search, .pdfThumbnailView]))
    }
    
    func testPreviewPdfThumbnailDocument() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .setIsPdf(true)
            .setIsPageView(false)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .sendToChat, .search, .pdfPageView]))
    }
    
    func testPreviewPdfThumbnailDocumentLink() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .setIsPdf(true)
            .setIsPageView(false)
            .setIsLink(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.import, .download, .shareLink, .sendToChat, .search, .pdfPageView]))
    }
    
    func testPreviewPdfThumbnailDocumentOwner() {
        actions = NodeActionBuilder()
            .setDisplayMode(.previewDocument)
            .setIsPdf(true)
            .setIsPageView(false)
            .setAccessLevel(.accessOwner)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .exportFile, .sendToChat, .search, .pdfPageView]))
    }
    
    // MARK: - Chat tests
    
    func testChatSharedMediaFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.chatSharedFiles)
            .setIsFile(true)
            .setIsMediaFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.forward, .download, .exportFile, .saveToPhotos, .import]))
    }
    
    func testChatSharedMediaFile_accessOwner() {
        actions = NodeActionBuilder()
            .setDisplayMode(.chatSharedFiles)
            .setIsFile(true)
            .setIsMediaFile(true)
            .setAccessLevel(.accessOwner)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.forward, .download, .exportFile, .saveToPhotos]))
    }
    
    func testChatSharedFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.chatSharedFiles)
            .setIsFile(true)
            .setIsMediaFile(false)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.forward, .download, .exportFile, .import]))
    }
    
    func testChatSharedFile_accessOwner() {
        actions = NodeActionBuilder()
            .setDisplayMode(.chatSharedFiles)
            .setIsFile(true)
            .setIsMediaFile(false)
            .setAccessLevel(.accessOwner)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.forward, .download, .exportFile]))
    }
    
    func testChatAttachmentMediaFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.chatAttachment)
            .setIsFile(true)
            .setIsMediaFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.forward, .download, .exportFile, .saveToPhotos, .import]))
    }
    
    func testChatAttachmentMediaFile_accessOwner() {
        actions = NodeActionBuilder()
            .setDisplayMode(.chatAttachment)
            .setIsFile(true)
            .setIsMediaFile(true)
            .setAccessLevel(.accessOwner)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.forward, .download, .exportFile, .saveToPhotos]))
    }
    
    func testChatAttachmentFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.chatAttachment)
            .setIsFile(true)
            .setIsMediaFile(false)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.forward, .download, .exportFile, .import]))
    }
    
    func testChatAttachmentFile_accessOwner() {
        actions = NodeActionBuilder()
            .setDisplayMode(.chatAttachment)
            .setIsFile(true)
            .setIsMediaFile(false)
            .setAccessLevel(.accessOwner)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.forward, .download, .exportFile]))
    }
    
    // MARK: - Versions tests
    
    func testNodeVersionChildMediaFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.nodeVersions)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setIsMediaFile(true)
            .setIsChildVersion(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.saveToPhotos, .download, .exportFile, .revertVersion, .remove]))
    }
    
    func testNodeVersionMediaFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.nodeVersions)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setIsMediaFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.saveToPhotos, .download, .exportFile, .remove]))
    }
    
    func testNodeVersionChildFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.nodeVersions)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .setIsChildVersion(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .exportFile, .revertVersion, .remove]))
    }
    
    func testNodeVersionFile() {
        actions = NodeActionBuilder()
            .setDisplayMode(.nodeVersions)
            .setAccessLevel(.accessOwner)
            .setIsFile(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .exportFile, .remove]))
    }
    
    
    // MARK: - Versions in Incoming Shared Items tests
    
    func testNodeVersionFileIncomingFullSharedFolder() {
        actions = NodeActionBuilder()
            .setDisplayMode(.nodeVersions)
            .setAccessLevel(.accessFull)
            .setIsFile(true)
            .setIsChildVersion(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .revertVersion, .remove]))
    }
    
    func testNodeVersionFileIncomingReadWriteSharedFolder() {
        actions = NodeActionBuilder()
            .setDisplayMode(.nodeVersions)
            .setAccessLevel(.accessReadWrite)
            .setIsFile(true)
            .setIsChildVersion(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .revertVersion]))
    }
    
    func testNodeVersionFileIncomingReadOnlySharedFolder() {
        actions = NodeActionBuilder()
            .setDisplayMode(.nodeVersions)
            .setAccessLevel(.accessRead)
            .setIsFile(true)
            .setIsChildVersion(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download]))
    }
    
    func testMultiselectFiles_noLinkedNodes() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.files, selectedNodeCount: 2)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .exportFile, .sendToChat, .move, .copy, .moveToRubbishBin]))
    }
    
    func testMultiselectFiles_allLinkedNodes() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.files, selectedNodeCount: 2)
            .setLinkedNodeCount(2)
            .setIsAllLinkedNode(true)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .manageLink, .removeLink, .exportFile, .sendToChat, .move, .copy, .moveToRubbishBin]))
    }
    
    func testMultiselectFiles_withSomeLinkedNodes() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.files, selectedNodeCount: 2)
            .setLinkedNodeCount(2)
            .setIsAllLinkedNode(false)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .removeLink, .exportFile, .sendToChat, .move, .copy, .moveToRubbishBin]))
    }
    
    func testMultiselectFolders_noLinkedNodes() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.folders, selectedNodeCount: 2)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .shareFolder, .move, .copy, .moveToRubbishBin]))
    }
    
    func testMultiselectFolders_allLinkedNodes() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.folders, selectedNodeCount: 2)
            .setLinkedNodeCount(2)
            .setIsAllLinkedNode(true)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .manageLink, .removeLink, .shareFolder, .move, .copy, .moveToRubbishBin]))
    }
    
    func testMultiselectFolders_withSomeLinkedNodes() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.folders, selectedNodeCount: 2)
            .setLinkedNodeCount(2)
            .setIsAllLinkedNode(false)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .removeLink, .shareFolder, .move, .copy, .moveToRubbishBin]))
    }
    
    func testMultiselectFilesAndFolders_noLinkedNodes() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.filesAndFolders, selectedNodeCount: 2)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .move, .copy, .moveToRubbishBin]))
    }
    
    func testMultiselectFilesAndFolders_allLinkedNodes() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.filesAndFolders, selectedNodeCount: 2)
            .setLinkedNodeCount(2)
            .setIsAllLinkedNode(true)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .manageLink, .removeLink, .move, .copy, .moveToRubbishBin]))
    }
    
    func testMultiselectFilesAndFolders_withSomeLinkedNodes() {
        actions = NodeActionBuilder()
            .setNodeSelectionType(.filesAndFolders, selectedNodeCount: 2)
            .setLinkedNodeCount(2)
            .setIsAllLinkedNode(false)
            .multiselectBuild()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.download, .shareLink, .removeLink, .move, .copy, .moveToRubbishBin]))
    }
    
    func testExportedNodeActions_nodeExported() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .setIsExported(true)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .manageLink, .removeLink, .shareFolder, .rename, .move, .copy, .moveToRubbishBin]))
    }
    
    func testExportedNodeActions_nodeNotExported() {
        actions = NodeActionBuilder()
            .setDisplayMode(.cloudDrive)
            .setAccessLevel(.accessOwner)
            .build()
        
        XCTAssertTrue(isEqual(nodeActionTypes: [.info, .favourite, .label, .download, .shareLink, .shareFolder, .rename, .move, .copy, .moveToRubbishBin]))
    }
}
