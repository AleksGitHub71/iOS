import ContentLibraries
import MEGADomain
import MEGARepo
import MEGASDKRepo

extension AppDelegate {
    
    @objc func initialiseModules() {
        ContentLibraries.configuration = .init(
            sensitiveNodeUseCase: makeSensitiveNodeUseCase(),
            nodeUseCase: makeNodeUseCase()
        )
    }
    
    private func makeSensitiveNodeUseCase() -> some SensitiveNodeUseCaseProtocol {
        SensitiveNodeUseCase(
          nodeRepository: NodeRepository.newRepo,
          accountUseCase: AccountUseCase(repository: AccountRepository.newRepo))
    }
    
    private func makeNodeUseCase() -> some NodeUseCaseProtocol {
        NodeUseCase(
            nodeDataRepository: NodeDataRepository.newRepo,
            nodeValidationRepository: NodeValidationRepository.newRepo,
            nodeRepository: NodeRepository.newRepo
        )
    }
}
