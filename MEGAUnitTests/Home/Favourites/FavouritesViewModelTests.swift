import XCTest
@testable import MEGA

final class FavouritesViewModelTests: XCTestCase {
    
    let mockFavouritesRouter = MockFavouritesRouter()
    
    func testAction_viewWillAppear() {
        let mockFavouriteNodesUC = MockFavouriteNodesUseCase()
        
        let viewModel = FavouritesViewModel(router: mockFavouritesRouter,
                                            favouritesUseCase: mockFavouriteNodesUC)
        
        mockFavouriteNodesUC.getAllFavouriteNodes { [weak self] result in
            switch result {
            case .success(let nodeEntities):
                let nodes = nodeEntities.map { NodeModel(nodeEntity: $0) }
                self?.test(viewModel: viewModel,
                     action: .viewWillAppear,
                     expectedCommands: [.showFavouritesNodes(nodes)])
                
            case .failure: break
            }
        }
    }
    
    func testAction_viewWillDisappear() {
        let mockFavouritesRouter = MockFavouritesRouter()
        let mockFavouriteNodesUC = MockFavouriteNodesUseCase()
        
        let viewModel = FavouritesViewModel(router: mockFavouritesRouter,
                                            favouritesUseCase: mockFavouriteNodesUC)
        test(viewModel: viewModel,
             action: .viewWillDisappear,
             expectedCommands: [])
    }
    
    func testAction_didSelectRow() {
        let mockFavouritesRouter = MockFavouritesRouter()
        let mockFavouriteNodesUC = MockFavouriteNodesUseCase()
        
        let viewModel = FavouritesViewModel(router: mockFavouritesRouter,
                                            favouritesUseCase: mockFavouriteNodesUC)
        
        let mockNodeModel = NodeModel(nodeEntity: NodeEntity())
        test(viewModel: viewModel,
             action: .didSelectRow(mockNodeModel.handle),
             expectedCommands: [])
        XCTAssertEqual(mockFavouritesRouter.openNode_calledTimes, 1)
    }
}
