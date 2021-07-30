
import Foundation

typealias MEGAChatResultDelegateCompletion = (_ api: MEGAChatSdk, _ chatId: MEGAHandle, _ newState: MEGAChatConnection) -> Void

class MEGAChatResultDelegate: NSObject, MEGAChatDelegate {
    let completion: MEGAChatResultDelegateCompletion
    
    init(completion: @escaping MEGAChatResultDelegateCompletion) {
        self.completion = completion
    }
    
    func onChatConnectionStateUpdate(_ api: MEGAChatSdk!, chatId: UInt64, newState: Int32) {
        guard let intNewState = MEGAChatConnection(rawValue: Int(newState)) else {
            return
        }
        completion(api, chatId, intNewState)
    }
}
