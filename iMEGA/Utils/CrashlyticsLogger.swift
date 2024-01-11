import FirebaseCrashlytics

@objc
final class CrashlyticsLogger: NSObject {
    static let shared = CrashlyticsLogger()
    private lazy var loggerQueue = DispatchQueue(label: "CrashlyticsLogger")
    
    /// The category of the issue we want to keep track of
    @objc enum LogCategory: Int, RawRepresentable {
        
        case general
        case audioPlayer
        case tranfersWidget
        var rawValue: String {
            switch self {
            case .general: "General"
            case .audioPlayer: "Audio Player"
            case .tranfersWidget: "Transfers Widget"
            }
        }
    }
    
    @objc static func log(_ msg: String) {
        Crashlytics.crashlytics().log(msg)
    }
    
    /// Convenient method to log a message with a category, file and function name.
    /// - Parameters:
    ///   - category: The category of the log message.
    ///   - msg: The message to log.
    ///   - file: The file when the log message is called, caller should not pass this parameter.
    ///   - function: The caller function when the log message is called, caller should not pass this parameter.
    @objc(logWithCategory:msg:file:function:)
    static func log(category: LogCategory, _ msg: String, _ file: String = #file, _ function: String = #function) {
        shared.log(category: category, msg, file, function)
    }
    
    private func log(category: LogCategory, _ msg: String, _ file: String, _ function: String) {
        loggerQueue.async {
            let file = file.components(separatedBy: "/").last ?? ""
            let msg = "[\(category.rawValue)] \(file).\(function): \(msg)"
            Crashlytics.crashlytics().log(msg)
    #if DEBUG
            print("\(msg)")
    #endif
        }
    }
}
