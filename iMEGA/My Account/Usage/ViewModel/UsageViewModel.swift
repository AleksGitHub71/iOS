import MEGADomain
import MEGAPresentation

enum StorageType {
    case cloud, backups, rubbishBin, incomingShares
}

enum UsageAction: ActionType {
    case loadRootNodeStorage
    case loadBackupStorage
    case loadRubbishBinStorage
    case loadIncomingSharedStorage
    case loadStorageDetails
    case loadTransferDetails
}

final class UsageViewModel: ViewModelType {
    var invokeCommand: ((Command) -> Void)?
    
    private let accountUseCase: any AccountUseCaseProtocol
    var accountType: AccountTypeEntity?
    
    enum Command: CommandType, Equatable {
        case loaded(StorageType, Int64)
        case loadedStorage(used: Int64, max: Int64)
        case loadedTransfer(used: Int64, max: Int64)
        case startLoading(StorageType)
    }
    
    init(accountUseCase: some AccountUseCaseProtocol) {
        self.accountUseCase = accountUseCase
    }
    
    func dispatch(_ action: UsageAction) {
        switch action {
        case .loadRootNodeStorage: updateRootNodeStorageUsed()
        case .loadBackupStorage: updateBackupNodeStorageUsed()
        case .loadRubbishBinStorage: updateRubbishBinStorageUsed()
        case .loadIncomingSharedStorage: updateIncomingSharesStorageUsed()
        case .loadStorageDetails: loadStorageDetails()
        case .loadTransferDetails: loadTransferDetails()
        }
    }
    
    @MainActor
    private func loadDetails(commandType: UsageViewModel.Command) {
        invokeCommand?(commandType)
    }
    
    private func loadStorageDetails() {
        Task {
            await loadDetails(
                commandType: .loadedStorage(
                    used: accountUseCase.currentAccountDetails?.storageUsed ?? 0,
                    max: accountUseCase.currentAccountDetails?.storageMax ?? 0
                )
            )
        }
    }
    
    private func loadTransferDetails() {
        Task {
            await loadDetails(
                commandType: .loadedTransfer(
                    used: accountUseCase.currentAccountDetails?.transferUsed ?? 0,
                    max: accountUseCase.currentAccountDetails?.transferMax ?? 0
                )
            )
        }
    }
    
    @MainActor
    private func updateStorageUsedAsync(for type: StorageType, storageUsedAsync: @escaping () async throws -> Int64) async {
        invokeCommand?(.startLoading(type))
        do {
            let storageSize = try await storageUsedAsync()
            invokeCommand?(.loaded(type, storageSize))
        } catch {
            invokeCommand?(.loaded(type, 0))
        }
    }
    
    @MainActor
    private func updateStorageUsed(for type: StorageType, storageUsedFunction: () -> Int64) {
        invokeCommand?(.startLoading(type))
        let storageSize = storageUsedFunction()
        invokeCommand?(.loaded(type, storageSize))
    }
    
    private func updateBackupNodeStorageUsed() {
        Task {
            await updateStorageUsedAsync(
                for: .backups,
                storageUsedAsync: accountUseCase.backupStorageUsed
            )
        }
    }
    
    private func updateRootNodeStorageUsed() {
        Task {
            await updateStorageUsed(
                for: .cloud,
                storageUsedFunction: accountUseCase.rootStorageUsed
            )
        }
    }

    private func updateRubbishBinStorageUsed() {
        Task {
            await updateStorageUsed(
                for: .rubbishBin,
                storageUsedFunction: accountUseCase.rubbishBinStorageUsed
            )
        }
    }

    private func updateIncomingSharesStorageUsed() {
        Task {
            await updateStorageUsed(
                for: .incomingShares,
                storageUsedFunction: accountUseCase.incomingSharesStorageUsed
            )
        }
    }
    
    var isBusinessAccount: Bool {
        accountUseCase.isAccountType(.business)
    }
    
    var isProFlexiAccount: Bool {
        accountUseCase.isAccountType(.proFlexi)
    }
    
    var isFreeAccount: Bool {
        accountUseCase.isAccountType(.free)
    }
}
