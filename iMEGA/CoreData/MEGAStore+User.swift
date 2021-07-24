import Foundation

extension MEGAStore {
    func updateUserNicknames(by names:[(handle: MEGAHandle, nickname: String)]) {
        guard let context = stack.newBackgroundContext() else { return }
        
        context.performAndWait {
            for name in names {
                if let user = fetchUser(withUserHandle: name.handle, context: context), user.nickname != name.nickname {
                    user.nickname = name.nickname
                } else { // user does not exsist in database yet. Delegate the task to main context
                    let handle = name.handle
                    let nickname = name.nickname
                    DispatchQueue.main.async {
                        if let user = self.fetchUser(withUserHandle: handle) {
                            user.nickname = nickname
                            self.save(self.stack.viewContext)
                        } else {
                            self.insertUser(withUserHandle: handle, firstname: nil, lastname: nil, nickname: nickname, email: nil)
                        }
                    }
                }
            }
            
            save(context)
        }
    }
}
