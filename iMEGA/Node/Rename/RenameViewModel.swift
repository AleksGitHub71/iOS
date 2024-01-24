import DeviceCenter
import MEGADomain
import MEGAL10n
import MEGAPresentation

protocol RenameViewRouting: Routing {
    func renamingFinished(with result: Result<Void, any Error>)
}

struct RenameViewModel {
    private let router: any RenameViewRouting
    private let renameEntity: RenameActionEntity
    private let renameUseCase: any RenameUseCaseProtocol
    
    init(
        router: any RenameViewRouting,
        renameEntity: RenameActionEntity,
        renameUseCase: any RenameUseCaseProtocol
    ) {
        self.router = router
        self.renameEntity = renameEntity
        self.renameUseCase = renameUseCase
    }
    
    private func performRenaming(newName: String) async -> Result<Void, any Error> {
        switch renameEntity.actionType {
        case .device(let deviceId, _):
            return await renameEntityIfNeeded(deviceId, newName: newName, renameAction: renameUseCase.renameDevice)
        }
    }

    private func renameEntityIfNeeded<T>(_ identifier: T?, newName: String, renameAction: (T, String) async throws -> Void) async -> Result<Void, any Error> {
        guard let id = identifier else { return .failure(GenericErrorEntity()) }
        do {
            try await renameAction(id, newName)
            return .success
        } catch {
            return .failure(error)
        }
    }
    
    func rename(_ newName: String) async {
        let result = await performRenaming(newName: newName)
        router.renamingFinished(with: result)
    }
    
    func isDuplicated(_ text: String) -> Bool {
        renameEntity.otherNamesInContext.contains(text)
    }
    
    func containsInvalidChars(_ text: String) -> Bool {
        let invalidCharacterSet = CharacterSet(charactersIn: "|*/:<>?\"\\")
        return text.rangeOfCharacter(from: invalidCharacterSet) != nil
    }
    
    func isNewNameWithinMaxLength(_ newName: String) -> Bool {
        switch renameEntity.actionType {
        case .device(_, let maxCharacters):
            return newName.count <= maxCharacters
        }
    }
    
    func textfieldText() -> String {
        renameEntity.oldName
    }
    
    func textfieldPlaceHolder() -> String {
        renameEntity.alertPlaceholder
    }
    
    func alertTitle(text: String) -> String {
        if containsInvalidChars(text) {
            return renameEntity.alertTitles[.invalidCharacters] ?? ""
        } else if isDuplicated(text) {
            return renameEntity.alertTitles[.duplicatedName] ?? ""
        } else if !isNewNameWithinMaxLength(text) {
            return renameEntity.alertTitles[.nameTooLong] ?? ""
        }
        
        return renameEntity.alertTitles[.none] ?? ""
    }
    
    func alertMessage(text: String) -> String {
        if isDuplicated(text) || !isNewNameWithinMaxLength(text) {
            return renameEntity.alertMessage[.duplicatedName] ?? ""
        } else {
            return renameEntity.alertMessage[.none] ?? ""
        }
    }
    
    func alertTextsColor(text: String) -> UIColor {
        containsInvalidChars(text) || isDuplicated(text) || !isNewNameWithinMaxLength(text) ? MEGAAppColor.Red._FF3B30.uiColor : UIColor.label
    }
    
    func isActionButtonEnabled(text: String) -> Bool {
        !(
            text.isEmpty ||
            containsInvalidChars(text) ||
            isDuplicated(text) ||
            !isNewNameWithinMaxLength(text)
        )
    }
}
