
extension MEGASdk {
    @objc var isGuestAccount: Bool {
        guard let email = MEGASdkManager.sharedMEGASdk().myUser?.email else {
            return true
        }
        
        return email.isEmpty
    }
    
    @objc func visibleContacts() -> [MEGAUser] {
        let contactsArray = MEGASdkManager.sharedMEGASdk().contacts()
        let contactsArraySize = contactsArray.size.intValue
        var visibleContactsArray: [MEGAUser] = []
        var i = 0
        while i < contactsArraySize {
            let user = contactsArray.user(at: i)!
            if user.visibility.rawValue == MEGAUserVisibility.visible.rawValue {
                visibleContactsArray.append(user)
            }
            i += 1
        }
        
        return visibleContactsArray
    }
    
    
    /// An async way to check if the current account is logged in or not.
    /// - Parameters:
    ///   - completion: Callback closure upon completion. The completion closure will be called from an arbitrary background thread.
    @objc(isLoggedInWithCompletion:)
    func isLoggedIn(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            completion(self.isLoggedIn() != 0)
        }
    }
    
    /// An async way to check if there are pending transfers.
    /// - Parameters:
    ///   - completion: Callback closure upon completion. The completion closure will be called from an arbitrary background thread.
    @objc(areTherePendingTransfersWithCompletion:)
    func areTherePendingTransfers(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            completion(MEGASdkManager.sharedMEGASdk().transfers.size.intValue > 0 ||
                       MEGASdkManager.sharedMEGASdkFolder().transfers.size.intValue > 0)
        }
    }
}
