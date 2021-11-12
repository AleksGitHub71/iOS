// MARK: - Use case protocol -
protocol TransfersUseCaseProtocol {
    func transfers(filteringUserTransfers: Bool) -> [TransferEntity]
    func downloadTransfers(filteringUserTransfers: Bool) -> [TransferEntity]
    func uploadTransfers(filteringUserTransfers: Bool) -> [TransferEntity]
    func completedTransfers(filteringUserTransfers: Bool) -> [TransferEntity]
}

// MARK: - Use case implementation -
struct TransfersUseCase: TransfersUseCaseProtocol {
    
    private let repo: TransfersRepositoryProtocol
    
    init(repo: TransfersRepositoryProtocol) {
        self.repo = repo
    }
    
    func transfers(filteringUserTransfers: Bool) -> [TransferEntity] {
        let transfers = repo.transfers()
        if filteringUserTransfers {
            return filterUserTransfers(transfers)
        } else {
            return transfers
        }
    }

    func downloadTransfers(filteringUserTransfers: Bool) -> [TransferEntity] {
        let transfers = repo.downloadTransfers()
        if filteringUserTransfers {
            return filterUserTransfers(transfers)
        } else {
            return transfers
        }
    }
    
    func uploadTransfers(filteringUserTransfers: Bool) -> [TransferEntity] {
        let transfers = repo.uploadTransfers()
        if filteringUserTransfers {
            return filterUserTransfers(transfers)
        } else {
            return transfers
        }
    }
    
    func completedTransfers(filteringUserTransfers: Bool) -> [TransferEntity] {
        let transfers = repo.completedTransfers()
        if filteringUserTransfers {
            return filterUserTransfers(transfers)
        } else {
            return transfers
        }
    }
    
    private func filterUserTransfers(_ transfers: [TransferEntity]) -> [TransferEntity] {
        transfers.filter {
            $0.type == .upload || $0.path?.hasPrefix(Helper.relativePathForOffline()) ?? false
        }
    }
}
