@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGAPresentation
import MEGAPresentationMock
import Testing

struct NodeActionViewModelTestSuite {
    
    @Suite("Calls addToDestination")
    struct AddToDestination {
        
        @Suite("When Feature Flag is off")
        struct FeatureFlagOffTests {
            
            private let sut = AddToDestination.makeSUT(featureFlagAddToEnabled: false)
            private static func arguments() -> [(DisplayMode, Bool)] {
                [true, false]
                    .flatMap { isFromSharedItem in DisplayMode.allCases.map({ ($0, isFromSharedItem) }) }
            }
                        
            @Test("Always return .none destination for all displayModes and isFromSharedItem flag", arguments: arguments())
            func addToDestination(displayMode: DisplayMode, isFromSharedItem: Bool) {
                #expect(sut.addToDestination(nodes: [], from: displayMode, isFromSharedItem: isFromSharedItem) == .none)
            }
        }
        
        @Suite("When Feature Flag is on")
        struct FeatureFlagOnTests {
            let sut = AddToDestination.makeSUT(featureFlagAddToEnabled: true)

            @Test("Always return .none destination if isFromSharedItem equals true, regardless of DisplayMode", arguments: DisplayMode.allCases)
            func addToDestinationWhenSharedItemIsTrue(displayMode: DisplayMode) {
                #expect(sut.addToDestination(nodes: .png, from: displayMode, isFromSharedItem: true) == .none)
            }
            
            @Suite("When Display Mode is CloudDrive")
            struct DisplayModeIsCloudDrive {
                private let displayMode: DisplayMode = .cloudDrive
                private let sut = AddToDestination.makeSUT(featureFlagAddToEnabled: true)

                @Test("When all nodes are visual media and at least one node is an image, destination should be .albums", arguments: [
                    .png,
                    .pngAndJpg,
                    .png + .mp4
                ])
                func oneOrMoreImage(nodes: [NodeEntity]) {
                    #expect(sut.addToDestination(nodes: nodes, from: displayMode, isFromSharedItem: false) == .albums)
                }
                
                @Test("When all nodes are video files, destination should be .albumsAndVideos", arguments: [
                    [NodeEntity].mp4,
                    .mp4AndMov
                ])
                func allVideo(nodes: [NodeEntity]) {
                    #expect(sut.addToDestination(nodes: nodes, from: displayMode, isFromSharedItem: false) == .albumsAndVideos)
                }
                
                @Test("When there is at least one non-visual-media node, destination should be .none", arguments: [
                    [NodeEntity].nonAudioVisual,
                    .mp4 + .nonAudioVisual
                ])
                func containsNonVisualMedia(nodes: [NodeEntity]) {
                    #expect(sut.addToDestination(nodes: nodes, from: displayMode, isFromSharedItem: false) == .none)
                }
            }
            
            @Suite("When Display Mode is PhotosTimeline")
            struct DisplayModeIsPhotosTimeline {
                
                private let sut = AddToDestination.makeSUT(featureFlagAddToEnabled: true)
                private let displayMode: DisplayMode = .photosTimeline
                
                @Test("When all nodes are visual media, destination should always be .albums", arguments: [
                    [NodeEntity].pngAndJpg,
                    .png + .mp4,
                    .mp4AndMov
                ])
                func allAreVisualMedia(nodes: [NodeEntity]) {
                    #expect(sut.addToDestination(nodes: nodes, from: displayMode, isFromSharedItem: false) == .albums)
                }
                
                @Test("When there is at least one non-visual-media node, destination should be .none", arguments: [
                    [NodeEntity].nonAudioVisual,
                    [NodeEntity].nonAudioVisual + .mp4
                ])
                func containsNonVisualMedia(nodes: [NodeEntity]) {
                    #expect(sut.addToDestination(nodes: nodes, from: displayMode, isFromSharedItem: false) == .none)
                }
            }
            
            @Suite("When Display Mode is unsupported")
            struct DisplayModeIsUnsupported {
                private let sut = AddToDestination.makeSUT(featureFlagAddToEnabled: true)
                private static let unsupportedDisplayModes: [DisplayMode] = DisplayMode
                    .allCases
                    .filter { [.cloudDrive, .photosTimeline].notContains($0) }
                
                @Test("Always return .none destination", arguments: unsupportedDisplayModes)
                func unsupportedDisplayMode(displayMode: DisplayMode) {
                    #expect(sut.addToDestination(nodes: .mp4, from: displayMode, isFromSharedItem: false) == .none)
                }
            }
        }
                
        private static func makeSUT(
            accountUseCase: some AccountUseCaseProtocol = MockAccountUseCase(),
            featureFlagAddToEnabled: Bool = false
        ) -> NodeActionViewModel {
            NodeActionViewModelTestSuite.makeSUT(
                featureFlagList: [.addToAlbumAndPlaylists: featureFlagAddToEnabled]
            )
        }
    }
    
    private static func makeSUT(
        accountUseCase: some AccountUseCaseProtocol = MockAccountUseCase(),
        systemGeneratedNodeUseCase: some SystemGeneratedNodeUseCaseProtocol = MockSystemGeneratedNodeUseCase(nodesForLocation: [:]),
        sensitiveNodeUseCase: some SensitiveNodeUseCaseProtocol = MockSensitiveNodeUseCase(),
        maxDetermineSensitivityTasks: Int = 10,
        featureFlagList: [FeatureFlagKey: Bool] = [:]
    ) -> NodeActionViewModel {
        NodeActionViewModel(
            accountUseCase: accountUseCase,
            systemGeneratedNodeUseCase: systemGeneratedNodeUseCase,
            sensitiveNodeUseCase: sensitiveNodeUseCase,
            maxDetermineSensitivityTasks: maxDetermineSensitivityTasks,
            featureFlagProvider: MockFeatureFlagProvider(list: featureFlagList))
    }
}

extension [NodeEntity] {
    static let png = [NodeEntity(name: "file.png", isFile: true)]
    static let pngAndJpg = [NodeEntity(name: "file.png", isFile: true), NodeEntity(name: "file.jpg", isFile: true)]
    static let mp4 = [NodeEntity(name: "file.mp4", isFile: true)]
    static let mp4AndMov = [NodeEntity(name: "file.mp4", isFile: true), NodeEntity(name: "file.mov", isFile: true)]
    static let nonAudioVisual = [NodeEntity(name: "document.pdf", isFile: true), NodeEntity(name: "Folder", isFile: false, isFolder: true)]
}

extension DisplayMode {
    static var allCases: [DisplayMode] {
        [.unknown, .cloudDrive, .rubbishBin, .sharedItem, .nodeInfo, .nodeVersions, .folderLink, .nodeInsideFolderLink, .recents, .publicLinkTransfers, .transfers, .transfersFailed, .chatAttachment, .chatSharedFiles, .previewDocument, .textEditor, .backup, .mediaDiscovery, .photosFavouriteAlbum, .photosAlbum, .photosTimeline, .previewPdfPage, .albumLink, .videoPlaylistContent]
    }
}